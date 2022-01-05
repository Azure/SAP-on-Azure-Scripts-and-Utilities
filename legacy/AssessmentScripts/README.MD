# Assessment Module

The scripts in this module can be used to assess an already deployed SAP landscape to validate that it is built correctly following the published guidance. The checks include virtual machine configuration, storage configuration and network configuration.

## SAP On Azure Sizing

[Disks for SAP on Azure deployments](https://docs.microsoft.com/en-us/azure/virtual-machines/workloads/sap/hana-vm-operations-storage) provide information on which disk types are supported for the different Virtual Machine types.

Generic disk guidance for Azure can be found here: [What disk types are available in Azure?](https://docs.microsoft.com/en-us/azure/virtual-machines/windows/disks-types)

**requirements:**

- Azure Subscription
- PowerShell 5.1 or newer
- PowerShell modules Posh-SSH and Az

## Assessment Tests

The module consists of different functions that can be used to assess the Virtual Machines of your SAP Landscape

## Get Virtual Machine Information

This function returns the pertinent Virtual Machine information.

| Property  | Value                                 |
| ---       | ---                                   |
| Name      | The name of the virtual machine       |
| Resourcegroup      | The name of the resource group in which the Virtual Machine is deployed       |
| Operating System      | The operating system of the Virtual Machine       |
| Zone      | The availability zone (if any) in which the Virtual Machine is deployed       |
| Size      | The Virtual Machine SKU       |
| AvailabilitySet      | The availability set (if any) in which the Virtual Machine is deployed       |
| Proximity Placement Group      | The proximity placement group set (if any) in which the Virtual Machine is deployed       |
| Private IP| The private IP of the virtual machine       |
| Public IP| The public IP of the virtual machine       |
| VNet| The name of the virtual network in which the virtual machine is deployed |
| Subnet| The name of the virtual subnet in which the virtual machine is deployed |
| Accelerated Networking| Indicates if accelerated networking is configured |
| Disk colocation|  Indicates if disk colocation is configured |

### Example

    Import the module
    Import-Module "./VMUtilities.psd1"
    Get-VMInfo -ResourceGroupName test-rg -VirtualMachineName vm1 

## Get Network information for a Virtual Machine

This function returns the network information for a Virtual Machine.

| Property  | Value                                 |
| ---       | ---                                   |
| Name      | The name of the virtual machine       |
| Private IP| The private IP of the virtual machine       |
| Public IP| The public IP of the virtual machine       |
| VNet| The name of the virtual network in which the virtual machine is deployed |
| Subnet| The name of the virtual subnet in which the virtual machine is deployed |
| Accelerated Networking| Indicates if accelerated networking is configured |

### Example
```PowerShell
    Import the module
    Import-Module "./VMUtilities.psd1"
    Get-NetworkInfo -ResourceGroupName test-rg -VirtualMachineName vm1 
```
## Get Disk information for a Virtual Machine

This function returns the disk information for a Virtual Machine.

| Property  | Value                                 |
| ---       | ---                                   |
| Name      | The name of the virtual machine       |
| Disk Name      | The name of the disk       |
| Lun      | The LUN of the disk       |
| Caching      | The setting for caching for the disk       |
| OSDisk      | Is the disk the operating system disk       |
| WriteAcceleratorEnabled      | If Write Accelerator enabled for the disk       |
| Size In GB      | The size of the disk       |
| Type      | The type of the disk       |
| SKU      | The SKU of the disk       |
| Zone      | The zone (if any) of the disk       |

### Example

```PowerShell
    Import the module
    Import-Module "./VMUtilities.psd1"
    Get-DiskInfo -ResourceGroupName test-rg -VirtualMachineName vm1 
```
## Combining the modules and persisting the output

In order to get a more comprehensive overview of the settings you can use the code snippet below. The information will be persisted in 2 .csv files in the directory specified by the $outputDiroctory variable.

### Example
```PowerShell
    Import-Module .\VMUtilities.psd1

    $ResourceGroupName = "RGName"
    $subscriptionName = "My Azure"

    $suffix = (Get-Date).ToString("yyyyddMM_HHmm")
    $outputDirectory = "c:\work\code\sap\"

    if(-not (Test-Path $outputDirectory -PathType Container))
    {
        Write-Host -ForegroundColor Red -BackgroundColor White "Folder '" $outputDirectory "' does not exit please create it."
        exit
    }

    $csvFileNameVMs = $outputDirectory + "VirtualMachines_" + $suffix + ".csv"
    $csvFileNameDisks = $outputDirectory + "Disks_" + $suffix + ".csv"

    # Create variable for combining the informationfrom multiple virtual machines
    $VMInfos = @()
    $DiskInfos = @()

    # select subscription
    $Subscription = Get-AzSubscription -SubscriptionName $SubscriptionName
    if (-Not $Subscription) {
        Write-Host -ForegroundColor Red -BackgroundColor White "Sorry, it seems you are not connected to Azure or don't have access to the subscription. Please use Connect-AzAccount to connect."
        exit
    }

    Select-AzSubscription -Subscription $SubscriptionName 

    #Get a list of all VM's with a specific tag, in this case "SAP"
    $VMs = (Get-AzResource -ResourceGroupName $ResourceGroupName -Tag @{ System = "SAP" } -ResourceType Microsoft.Compute/virtualMachines).Name
    foreach ($vmName in $VMs) {
        $VMInfo = Get-VMInfo   -VirtualMachineName $vmName -ResourceGroupName $ResourceGroupName
        $VMInfos += $VMInfo

        $Disks = Get-DiskInfo -VirtualMachineName $vmName -ResourceGroupName $ResourceGroupName
        foreach ($diskInfo in $Disks) {
            $DiskInfos += $diskInfo
        }
    }

    $status = "Virtual Machine Information"
    Write-Host  $status -ForegroundColor Yellow

    Write-Output $VMInfos | Format-Table
    #Persist the information
    $VMInfos | export-csv -Path $csvFileNameVMs -NoTypeInformation
        
    $status = "Disks attached to the virtual machines"
    Write-Host  $status -ForegroundColor Yellow
    Write-Output $DiskInfos | Format-Table
    $DiskInfos | export-csv -Path $csvFileNameDisks -NoTypeInformation
```
