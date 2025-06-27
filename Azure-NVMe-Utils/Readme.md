# Azure NVMe Utilities

## Overview

This repository contains a PowerShell scripts (`.ps1`) designed to simplify the conversion of Azure Virtual Machines from SCSI to NVMe and back..

## Prerequisites

- Azure Subscription and a Virtual Machine that you need to convert from SCSI to NVMe or from NVMe to SCSI
- PowerShell and Az Module installed and configured
- Appropriate permissions to execute scripts on Azure resources

## Usage

To execute the script, open PowerShell as an administrator and follow the steps:

1. Install PowerShell or run the script on Azure Cloud Shell

You can download and learn more about PowerShell on [https://aka.ms/powershell](https://aka.ms/powershell])

2. allow unsigned powershell script files

```powershell
Set-ExecutionPolicy -ExecutionPolicy Unrestricted
```

3. Connect to your Azure Account using

```powershell
Connect-AzAccount
```

4. Make sure that you are connected to your subscription, you can change the subscription using Select 

```powershell
Select-AzSubscription -Subscription xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
```

5. Download the script

You can use this PowerShell Command to download the script.

```powershell
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/Azure/SAP-on-Azure-Scripts-and-Utilities/refs/heads/main/Azure-NVMe-Utils/Azure-NVMe-Conversion.ps1" -OutFile ".\NVMe-Conversion.ps1"
```

6. Run the conversion script

```powershell
.\Azure-NVMe-Conversion.ps1
```

## Example

```powershell
# Example usage
.\Azure-NVMe-Conversion.ps1 -ResourceGroupName <your-RG> -VMName <your-VMname> -NewControllerType <NVMe/SCSI> -VMSize <new-VM-SKU> -StartVM
```

## Parameters

| Parameter                      | Description                                                                  | Required |
|--------------------------------|------------------------------------------------------------------------------|----------|
| `-ResourceGroupName`           | The Resource Group Name of your VM                                           | Yes      |
| `-VMName`                      | The name of your Virtual Machine on Azure                                    | Yes      |
| `-NewControllerType`           | The storage controller type the VM should get converted to (NVMe or SCSI)    | Yes      |
| `-VMSize`                      | Azure VM SKU you want to convert the VM to                                   | Yes      |
| `-StartVM`                     | Start the VM after conversion                                                | No       |
| `-IgnoreSKUCheck`              | Ignore the check of the VM SKU                                               | No       |
| `-IgnoreWindowsVersionCheck`   | Ignore the Windows Version check                                             | No       |
| `-FixOperatingSystemSettings`  | Automatically fix the OS settings using Azure RunCommands                    | No       |
| `-WriteLogfile`                | Create a Log File                                                            | No       |
| `-IgnoreAzureModuleCheck`      | Do not run the check for installed Azure modules                             | No       |

## Contributing

Contributions are welcome. Please submit pull requests or open issues for improvements or bug reports.

## License

This project is licensed under the MIT License. See the [LICENSE](../LICENSE) file for details.
