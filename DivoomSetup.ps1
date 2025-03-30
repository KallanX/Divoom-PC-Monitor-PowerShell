# Function to format and display device list
function Format-DeviceList {
    param (
        [Parameter(Mandatory=$true)]
        [Array]$Devices
    )

    $i = 1
    foreach ($device in $Devices) {
        Write-Host "Device $($i):" -ForegroundColor Cyan
        Write-Host "---------" -ForegroundColor Cyan
        Write-Output "  Device Name     : $($device.DeviceName)"
        Write-Output "  Device ID       : $($device.DeviceId)"
        Write-Output "  Private IP      : $($device.DevicePrivateIP)"
        Write-Output "  MAC Address     : $($device.DeviceMac)"
        Write-Output "  Hardware Version: $($device.Hardware)"
        Write-Output "`n"  # New line for better readability
        $i++
    }
}

# Function to get user selection from a list of devices
function Get-UserSelection {
    param (
        [Parameter(Mandatory=$true)]
        [Array]$Devices
    )

    $deviceCount = $Devices.Length
    do {
        $selection = Read-Host "Please select a device number"
        $isValid = $selection -as [int] -and $selection -ge 1 -and $selection -le $deviceCount
        if (-not $isValid) {
            Write-Output "Invalid selection. Please enter a number between 1 and $deviceCount."
        }
    } until ($isValid)

    Write-Host "`n------------------------------`n"

    return $Devices[$selection - 1], $($selection - 1)
}

# Get device list from the network
$response = Invoke-RestMethod -Uri "https://app.divoom-gz.com/Device/ReturnSameLANDevice"
$deviceList = $response.DeviceList

# If the device list is empty, exit the script
if ($deviceList.Length -eq 0) {
    Write-Host "No devices found on the network. Please make sure the device is connected to the same network as the PC." -ForegroundColor Red
    exit
}

Format-DeviceList -Devices $deviceList
$selectedDevice, $arrayIndex = Get-UserSelection -Devices $deviceList

# Save the selected device ID and IP address to the .env file
$DeviceID = $($selectedDevice.DeviceId)
$DeviceIP = $($selectedDevice.DevicePrivateIP)

# Function to format and display LCD list
function Format-LcdList {
    param (
        [Parameter(Mandatory=$true)]
        [Array]$Lcds
    )

    $i = 0
    foreach ($lcd in $Lcds) {
        Write-Host "Lcd $($i + 1):" -ForegroundColor Cyan
        Write-Host "------" -ForegroundColor Cyan
        Write-Output "  Array Index     : $($i)"
        Write-Output "  Clock ID        : $($lcd.LcdClockId)"
        Write-Output "  Image Pixel ID  : $($lcd.ClockImagePixelId)"
        if ($lcd.LcdClockId -eq 625) {
            Write-Output "  Description     : Divoom PC Monitor"
        }
        Write-Output "`n"
        $i++
    }
}

$response = Invoke-RestMethod -Uri "https://app.divoom-gz.com/Channel/Get5LcdInfoV2?DeviceType=LCD&DeviceId=$($DeviceID)"
$lcdIndependenceList = $response.LcdIndependenceList

if ($null -eq $lcdIndependenceList -or $lcdIndependenceList.Count -eq 0) {
    # If no LCD independence list is found, return None
    Write-Host "No LCD Independence found. Assuming Pixoo64 or similar device." -ForegroundColor Yellow
    Write-Host "Setting LCD Independence to 0." -ForegroundColor Yellow
    $lcdIndependence = 0
}

# Select LCD Independence
if ($lcdIndependenceList.Count -gt 1) {
    Write-Host "Multiple LCD Groups (Independence) found. Please select one:" -ForegroundColor Cyan
    $i = 1
    foreach ($independence in $lcdIndependenceList) {
        Write-Host "LCD Independence $($i): $($independence.LcdIndependence)"
        $i++
    }

    do {
        $selection = Read-Host "Please enter the LCD Independence number"
        $selectionIsValid = [int]::TryParse($selection, [ref]$selection) -and ($selection -ge 1) -and ($selection -le $lcdIndependenceList.Count)
        if (-not $selectionIsValid) {
            Write-Host "Invalid selection. Please enter a number between 1 and $($lcdIndependenceList.Count)." -ForegroundColor Red
        }
    } until ($selectionIsValid)

    Write-Host "`n------------------------------`n"

    $selectedIndependence = $lcdIndependenceList[$selection - 1]
}

if ($lcdIndependence -eq 0) {
    Write-Host "Setting LCD Index to 0." -ForegroundColor Yellow
    $LcdIndex = 0
    Write-Host "Setting LCD Clock ID to 625." -ForegroundColor Yellow
    $LcdClockId = 625
} else {
    # Get the LcdList *from the selected independence object*
    $lcdList = $selectedIndependence.LcdList
    Format-LcdList -Lcds $lcdList

    $selectedLcd, $arrayIndex = Get-UserSelection -Devices $lcdList

    # Save the selected Index and Clock ID to the .env file
    $LcdIndex = $($arrayIndex)
    $LcdClockId = $($selectedLcd.LcdClockId)
}

# Function to get all drive letters on the PC
function Get-DriveLetters {
    $drives = Get-WmiObject -Class Win32_LogicalDisk | Select-Object -ExpandProperty DeviceID
    return $drives
}

# Function to get user selection for drive letters
function Get-DriveLetterSelection {
    param (
        [Parameter(Mandatory=$true)]
        [Array]$DriveLetters
    )

    Write-Host "Available Drive Letters:" -ForegroundColor Cyan
    $DriveLetters | ForEach-Object { Write-Host $_ }

    $selection = Read-Host "Please enter the drive letter(s) you want to monitor (comma separated) or type 'all' to select all drives"
    if ($selection -eq "" -or $selection -eq "all") {
        return $DriveLetters
    } else {
        $selectedDrives = $selection.Split(",") | ForEach-Object { $_.Trim() }
        return $selectedDrives
    }
}

# Get all drive letters on the system
$driveLetters = Get-DriveLetters

# Prompt user to select drive letters
$selectedDriveLetters = Get-DriveLetterSelection -DriveLetters $driveLetters

# Save the selected drives to the config file
try {
    New-Item config.env -ItemType file -Force
    Add-Content config.env "DeviceID=$DeviceID"
    Add-Content config.env "DeviceIP=$DeviceIP"
    Add-Content config.env "LcdIndependence=$lcdIndependence"
    Add-Content config.env "LcdIndex=$LcdIndex"
    Add-Content config.env "LcdClockId=$LcdClockId"
    Add-Content config.env "SelectedDriveLetters=$($selectedDriveLetters -join ',')"
} catch {
    Write-Host "Failed to create the config file." -ForegroundColor Red
}

Write-Host "Config file created successfully." -ForegroundColor Green

Write-Host "Sending configuration to the device..." -ForegroundColor Cyan

# Send Select Clock to the Divoom Times Gate device
$PostInfo = @{
    Command = "Channel/SetClockSelectId"
    LcdIndependence = $lcdIndependence
    DeviceId = $DeviceID
    LcdIndex = $LcdIndex
    ClockId = 625
}
$ParamInfo = $PostInfo | ConvertTo-Json

Write-Host "Select Clock Data to be sent: $ParamInfo"

# Send the HTTP POST request
$ResponseInfo = Invoke-RestMethod -Uri "http://$($DeviceIP):80/post" -Method Post -Body $ParamInfo -ContentType "application/json"

Write-Host "Select Clock Response: $ResponseInfo"

# If responseinfo text is {"error_code": 0}, the command was successful
if ($ResponseInfo.error_code -eq 0) {
    Write-Host "HTTP Post - OKAY!" -ForegroundColor Green
} else {
    Write-Host "HTTP Post - ERROR!" -ForegroundColor Red
}