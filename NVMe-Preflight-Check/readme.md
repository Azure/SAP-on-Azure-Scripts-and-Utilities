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


