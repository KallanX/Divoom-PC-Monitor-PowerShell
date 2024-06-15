# Divoom PC Monitor - PowerShell Implementation

This repository contains a PowerShell script that interfaces with the Divoom PC Monitor application on the Divoom Times Gate to monitor system information.

## Overview

This project is a PowerShell implementation of the Divoom PC Monitor originally written in C# by DivoomDevelop. It allows users to monitor various system metrics and display them on their Divoom Times Gate.

## Features

- **System Metrics Displayed**: 
  - CPU usage percentage
  - CPU temperature
  - RAM usage
  - GPU usage (NVIDIA only)
  - GPU temperature (NVIDIA only)
  - HDD usage (dynamic drive selection based on highest usage)
- **Easy Setup**: Configuration script simplifies the setup process.
- **Scheduled Task Support**: Users can set up a scheduled task to run the monitor automatically upon login.

## Usage

1. **Configuration**: 
   - Run `DivoomSetup.ps1` to create the necessary configuration file.
   
2. **Running the Script**:
   - Execute `DivoomPCMonitor.ps1` from the command line.
   - Optionally, use `SetupTaskScheduler.ps1` to configure the script to run as a scheduled task at logon (requires admin privileges).

## Installation

1. Clone the repository:
   ```powershell
   git clone https://github.com/KallanX/Divoom-PC-Monitor-PowerShell.git
   cd Divoom-PC-Monitor-PowerShell
   ```

2. Run the setup script:
   ```powershell
   ./DivoomSetup.ps1
   ```

3. Execute the main script:
   ```powershell
   ./DivoomPCMonitor.ps1
   ```

4. (Optional) Setup Task Scheduler for automatic execution at logon (requires admin privileges):
   ```powershell
   ./SetupTaskScheduler.ps1
   ```

## Configuration

- **DivoomSetup.ps1**: This script creates a configuration file required by the main script.
- **SetupTaskScheduler.ps1**: This script sets up a scheduled task to run the monitor automatically upon user login. Requires administrative privileges.

## Notes

- **Admin Privileges**: `SetupTaskScheduler.ps1` must be run in an admin terminal.
- **GPU Support**: Currently, GPU data is supported only for NVIDIA GPUs using `nvidia-smi.exe`.
- **CPU Temperature**: The CPU temperature reading is currently inaccurate (stuck at 28°C). This is being worked on.
- **Third-party Tools**: No third-party tools are required for this script to function.

## Shortcomings

- **CPU Temperature**: Not working as expected. Currently stuck at 28°C.
- **Drive Letter Display**: Future updates will include displaying the drive letter alongside the HDD usage percentage.

## Future Improvements

- Update display elements to show the drive letter along with the HDD usage percentage.

## Author

This project was created by Keith Carichner Jr. due to the lack of a competent implementation that actually functioned and was well-written/documented.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
