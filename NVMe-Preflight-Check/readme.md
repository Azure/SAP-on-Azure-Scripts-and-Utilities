# Azure NVMe Preflight Check

Azure NVMe Preflight Check is a bash script that validates and prepares a Linux operating system before moving to NVMe enabled virtual machines.

NVMe enabled virtual machines provide higher IOPS and throughput for disk drives.

You can learn more about Azure NVMe enabled virtual machines on [https://learn.microsoft.com/en-us/azure/virtual-machines/enable-nvme-interface](https://learn.microsoft.com/en-us/azure/virtual-machines/enable-nvme-interface)

## How to run the script

```
azure-nvme-VM-update.ps1 [-subscription_id] <String> [-resource_group_name] <String>
    [-vm_name] <String> [[-disk_controller_change_to] <String>] [-vm_size_change_to] <String> [[-start_vm_after_update] <Boolean>] [[-write_logfile] <Boolean>] [-ignore_vmsku_check]
```

The script has some mandatory parameters:

| Parameter | Description |
|---|---|
| subscription_id  | Subscription ID of VM  |
| resource_group_name  | Resource Group Name for VM |
| vm_name  | Virtual Machine name |
| vm_size_change_to | New VM Size, if you want to stay with existing VM just enter the same VM type  |
| disk_controller_change_to | NVMe or SCSI |
| start_vm_after_update | true or false, default is true |
| write_logfile | also store log in file, default false |
| ignore_vmsku_check | ignore the check for VM SKU availability in region |

Note: With below below command, you can download script directly to Azure cloudshell session

Invoke-WebRequest -Uri "https://raw.githubusercontent.com/Azure/SAP-on-Azure-Scripts-and-Utilities/main/NVMe-Preflight-Check/azure-nvme-VM-update.ps1" -OutFile ".\azure-nvme-VM-update.ps1"

## Example:
./azure-nvme-VM-update.ps1 -subscription_id "<SubID>" -resource_group_name "<RGName>" -vm_name "<VMName>" -disk_controller_change_to "NVMe" -vm_size_change_to "<VM_SKU>" -start_vm_after_update <$False/$True> -write_logfile <$True/$False> -ignore_vmsku_check
