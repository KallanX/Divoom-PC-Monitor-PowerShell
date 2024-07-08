# This script is used to setup a task scheduler to run the DivoomPCMonitor.ps1 script at system startup.
param(
    [alias("rm")]
    [switch]$RemoveTask
)

# Remove the task scheduler if -RemoveTask switch is used
if ($RemoveTask) {
    $taskName = "DivoomPCMonitor"
    try {
        Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
        Write-Host "Task scheduler removed. Task name: $taskName" -ForegroundColor Green
    } catch {
        Write-Host "Failed to remove task scheduler. Error: $_" -ForegroundColor Red
    }
    exit
}

# Check for config.env file, quit if it doesn't exist
if (-not (Test-Path -Path ".\config.env")) {
    Write-Host "config.env file not found. Please run DivoomSetup.ps1 to create the config.env file." -ForegroundColor Red
    exit
}

# Gather command line arguments
$IntervalInSeconds = Read-Host "Enter the interval in seconds to update the system information (default: 30)"
if (-not $IntervalInSeconds) { $IntervalInSeconds = 30 }
$Debug = Read-Host "Enable Debug for logging? (Y/N)"
$DebugFlag = if ($Debug.ToUpper() -eq "Y") { $true } else { $false }

# Get the full path to the DivoomPCMonitor.ps1 script
$scriptPath = Join-Path -Path $PSScriptRoot -ChildPath "DivoomPCMonitor.ps1"
Write-Host "DivoomPCMonitor.ps1 script path: $scriptPath"

# Get the current user's domain and username
$userDomain = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name

# Setup the task scheduler to run DivoomPCMonitor.ps1 at user logon
$taskName = "DivoomPCMonitor"
if ($DebugFlag) {
    $taskAction = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument "-WindowStyle Hidden -ExecutionPolicy Bypass -File `"$scriptPath`" -IntervalInSeconds $IntervalInSeconds -Debug"
} else {
    $taskAction = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument "-WindowStyle Hidden -ExecutionPolicy Bypass -File `"$scriptPath`" -IntervalInSeconds $IntervalInSeconds"
}
$taskTrigger = New-ScheduledTaskTrigger -AtLogon -User $userDomain
$taskPrincipal = New-ScheduledTaskPrincipal -UserId $userDomain -LogonType Interactive -RunLevel Highest
$taskSettings = New-ScheduledTaskSettingsSet -MultipleInstances IgnoreNew -RunOnlyIfNetworkAvailable -RestartCount 5 -RestartInterval (New-TimeSpan -Minutes 1) -ExecutionTimeLimit ([TimeSpan]::Zero)

# Check if the task already exists
$taskExists = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue

if ($taskExists) {
    Write-Host "Task '$taskName' already exists. Removing existing task..." -ForegroundColor Yellow
    Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
}

# Register the task scheduler
try {
    Register-ScheduledTask -TaskName $taskName -Action $taskAction -Trigger $taskTrigger -Principal $taskPrincipal -Settings $taskSettings
    Write-Host "Task scheduler setup complete." -ForegroundColor Green
    Write-Host "Task name: $taskName" -ForegroundColor Cyan
} catch {
    Write-Host "Failed to setup task scheduler. Error: $_" -ForegroundColor Red
    exit
}

# Prompt user to run the task
$runTask = Read-Host "Do you want to run the task now? (Y/N)"
if ($runTask.ToUpper() -eq "Y") {
    Write-Host "Running task '$taskName'..." -ForegroundColor Cyan
    Start-ScheduledTask -TaskName $taskName

    # Check if the task is running
    $taskStatus = Get-ScheduledTask -TaskName $taskName | Select-Object -ExpandProperty State
    if ($taskStatus -eq "Running") {
        Write-Host "Task '$taskName' is running." -ForegroundColor Green
    } else {
        Write-Host "Task '$taskName' is not running." -ForegroundColor Red
    }
}
