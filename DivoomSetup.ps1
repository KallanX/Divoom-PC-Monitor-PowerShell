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
    
    return $Devices[$selection - 1]
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
$selectedDevice = Get-UserSelection -Devices $deviceList

# Save the selected device ID and IP address to the .env file
$DeviceID = $($selectedDevice.DeviceId)
$DeviceIP = $($selectedDevice.DevicePrivateIP)

# Function to format and display LCD list
function Format-LcdList {
    param (
        [Parameter(Mandatory=$true)]
        [Array]$Lcds
    )

    $i = 1
    foreach ($lcd in $Lcds) {
        Write-Host "Lcd $($i):" -ForegroundColor Cyan
        Write-Host "------" -ForegroundColor Cyan
        Write-Output "  Select Index    : $($lcd.LcdSelectIndex)"
        Write-Output "  Clock ID        : $($lcd.LcdClockId)"
        Write-Output "  Image Pixel ID  : $($lcd.ClockImagePixelId)"
        Write-Output "`n"  # New line for better readability
        $i++
    }
}

$response = Invoke-RestMethod -Uri "https://app.divoom-gz.com/Channel/Get5LcdInfoV2?DeviceType=LCD&DeviceId=$($DeviceID)"
$lcdIndependence = $response.LcdIndependence
$lcdIndependenceList = $response.LcdIndependenceList

foreach ($independence in $lcdIndependenceList) {
    $lcdList = $independence.LcdList
    Format-LcdList -Lcds $lcdList
}

$selectedLcd = Get-UserSelection -Devices $lcdList

# Save the selected Index and Clock ID to the .env file
$LcdIndex = $($selectedLcd.LcdSelectIndex)
$LcdClockId = $($selectedLcd.LcdClockId)

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
