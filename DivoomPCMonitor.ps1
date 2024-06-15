param(
    [alias("h")]
    [switch]$Help,

    [alias("i")]
    [int]$IntervalInSeconds = 30,

    [alias("v")]
    [switch]$Verbose,

    [alias("d")]
    [switch]$Debug
)

# Display help message if -Help switch is used
if ($Help) {
    Write-Host "DivoomPCMonitor.ps1 - Monitor system information on a Divoom Times Gate device"
    Write-Host "Usage: DivoomPCMonitor.ps1 [-IntervalInSeconds <int>] [-Verbose] [-Help]"
    Write-Host "  -IntervalInSeconds <int> : Interval in seconds to update the system information (default: 30)"
    Write-Host "  -Verbose                : Display verbose output on the console"
    Write-Host "  -Debug                  : Log debug information to a file"
    Write-Host "  -Help                   : Display this help message"
    exit
}

# Determine the log file path
$logFile = Join-Path -Path $env:LOCALAPPDATA -ChildPath "DivoomPCMonitor\LogFile.log"

# Ensure the directory exists
$logDir = [System.IO.Path]::GetDirectoryName($logFile)
if (-not (Test-Path -Path $logDir)) {
    New-Item -Path $logDir -ItemType Directory | Out-Null
}

# Function to log messages
function Write-LogMessage {
    param (
        [string]$message
    )
    if ($Verbose) {
        Write-Host $message
    }
    if ($Debug) {
        Add-Content -Path $logFile -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - $message"
    }
}

# Check for config.env file, quit if it doesn't exist
$configPath = Join-Path -Path $PSScriptRoot -ChildPath "config.env"
if (-not (Test-Path -Path $configPath)) {
    Write-LogMessage "config.env file not found. Please run DivoomSetup.ps1 to create the config.env file."
    exit
}

# Load the environment variables from the config.env file
$env:DeviceID = Get-Content -Path $configPath | Select-String -Pattern "DeviceID" | ForEach-Object { $_ -replace "DeviceID=", "" }
$env:DeviceIP = Get-Content -Path $configPath | Select-String -Pattern "DeviceIP" | ForEach-Object { $_ -replace "DeviceIP=", "" }
$env:LcdIndependence = Get-Content -Path $configPath | Select-String -Pattern "LcdIndependence" | ForEach-Object { $_ -replace "LcdIndependence=", "" }
$env:LcdIndex = Get-Content -Path $configPath | Select-String -Pattern "LcdIndex" | ForEach-Object { $_ -replace "LcdIndex=", "" }
$env:LcdClockId = Get-Content -Path $configPath | Select-String -Pattern "LcdClockId" | ForEach-Object { $_ -replace "LcdClockId=", "" }
$env:DriveLetters = Get-Content -Path $configPath | Select-String -Pattern "SelectedDriveLetters" | ForEach-Object { $_ -replace "SelectedDriveLetters=", "" }

while ($true) {
    # Get the system information
    # CPU Usage
    $cpuUsage = [math]::Round((Get-Counter '\Processor(_Total)\% Processor Time').CounterSamples.CookedValue)

    # Get CPU Temperature (Convert from tenths of Kelvin to Celsius)
    $cpuTempKelvin = Get-WMIObject -Query "SELECT * FROM Win32_PerfFormattedData_Counters_ThermalZoneInformation" -Namespace "root/CIMV2" | Select-Object -ExpandProperty Temperature
    $cpuTempCelsius = [math]::Round($cpuTempKelvin - 273.15)

    # RAM Usage Percentage
    $mem = Get-WmiObject -Class Win32_OperatingSystem
    $ramUsagePercentage = [math]::Round(($mem.TotalVisibleMemorySize - $mem.FreePhysicalMemory) / $mem.TotalVisibleMemorySize * 100)

    # Run the nvidia-smi command and get the output
    $gpuInfo = & 'C:\Windows\System32\nvidia-smi.exe' --query-gpu=utilization.gpu,temperature.gpu --format=csv

    # Split the output into lines
    $gpuInfoLines = $gpuInfo -split "`n"

    # Extract the header and the data line
    $data = $gpuInfoLines[1]

    # Split the data line into individual values
    $dataValues = $data -split ','

    # Extract GPU usage and temperature values
    $gpuUsage = $dataValues[0].Trim() -replace '[^0-9]', ''
    $gpuTemp = [math]::Round($dataValues[1].Trim())

    # Initialize an array to hold the drive usage information
    $driveUsageAll = @()

    # Iterate over each drive letter
    foreach ($driveLetter in $env:DriveLetters -split ',') {
        # Get the drive percentage usage
        $drivePercentage = (Get-WmiObject -Query "SELECT * FROM Win32_PerfFormattedData_PerfDisk_LogicalDisk WHERE Name='$($driveLetter)'").PercentDiskTime

        # Add the drive letter and percentage to array as a custom object
        $driveUsageAll += [PSCustomObject]@{
            DriveLetter = $driveLetter
            UsagePercentage = [int]$drivePercentage
        }
    }

    # Sort the array by UsagePercentage in descending order
    $driveUsageAll = $driveUsageAll | Sort-Object -Property UsagePercentage -Descending

    # Check if all drives are at 0% usage
    if (($driveUsageAll | Where-Object { $_.UsagePercentage -ne 0 }).Count -eq 0) {
        # Default to C: drive
        $driveC = $driveUsageAll | Where-Object { $_.DriveLetter -eq 'C:' }
        $hddUsageName = $driveC.DriveLetter
        $hddUsagePercentage = $driveC.UsagePercentage
        Write-LogMessage "HDD Name: $($hddUsageName)"
        Write-LogMessage "HDD Usage: $($hddUsagePercentage)%"
    } else {
        # Use the top percentage for the HDD usage percentage
        $hddUsageName = $driveUsageAll[0].DriveLetter
        $hddUsagePercentage = $driveUsageAll[0].UsagePercentage
        Write-LogMessage "HDD Name: $($hddUsageName)"
        Write-LogMessage "HDD Usage: $($hddUsagePercentage)%"
    }

    # Output the system information
    $systemInfo = [PSCustomObject]@{
        CPU_Usage_Percentage = "$($cpuUsage)%"
        CPU_Temperature = "$($cpuTempCelsius)°C"
        RAM_Usage_Percentage = "$($ramUsagePercentage)%"
        GPU_Usage = "$($gpuUsage)%"
        GPU_Temperature = "$($gpuTemp)°C"
        HDD_Usage_Percentage = "$($hddUsagePercentage)%"
    }

    Write-LogMessage "System Information: $($systemInfo | ConvertTo-Json)"

    # Send the system information to the Divoom Times Gate device
    Write-LogMessage "Sending system information to the Divoom Times Gate device..."

    # Send Select Clock to the Divoom Times Gate device
    $PostInfo = @{
        LcdIndependence = $env:LcdIndependence
        Command = "Channel/SetClockSelectId"
        LcdIndex = $env:LcdIndex
        ClockId = $env:LcdClockId
    }
    $ParamInfo = $PostInfo | ConvertTo-Json

    Write-LogMessage "Select Clock Data to be sent: $ParamInfo"

    # Send the HTTP POST request
    $ResponseInfo = Invoke-RestMethod -Uri "http://$($env:DeviceIP):80/post" -Method Post -Body $ParamInfo -ContentType "application/json"

    Write-LogMessage "Select Clock Response: $ResponseInfo"

    # Define the Divoom device post structure
    $PostInfo = @{
        Command = "Device/UpdatePCParaInfo"
        ScreenList = @(
            @{
                LcdId = $env:LcdIndex
                DispData = @(
                    "$($systemInfo.CPU_Usage_Percentage)",
                    "$($systemInfo.GPU_Usage)",
                    "$($systemInfo.CPU_Temperature)",
                    "$($systemInfo.GPU_Temperature)",
                    "$($systemInfo.RAM_Usage_Percentage)",
                    "$($systemInfo.HDD_Usage_Percentage)"
                )
            }
        )
    }

    # Convert the post info to JSON
    $ParamInfo = $PostInfo | ConvertTo-Json -Depth 5

    Write-LogMessage "Data to be sent: $ParamInfo"

    # Send the HTTP POST request
    $ResponseInfo = Invoke-RestMethod -Uri "http://$($env:DeviceIP):80/post" -Method Post -Body $ParamInfo -ContentType "application/json"

    Write-LogMessage "System Information Response: $ResponseInfo"
    
    # Wait for the specified interval
    Write-LogMessage "System information updated. Waiting for $IntervalInSeconds seconds..."
    Start-Sleep -Seconds $IntervalInSeconds
}
