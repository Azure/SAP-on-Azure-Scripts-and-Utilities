# Rename Azure Virtual Machine

**requirements:**

- Azure Subscription
- PowerShell 5.1 or newer
- PowerShell module Az

## What the script does

    The script deletes the VM and recreates it using the new name preserving networking and storage configuration.  The script will snapshot each disk, create a new disk from the snapshot, and create the new VM with the new disks attached.

    There is no need to reinstall the operating system.

    IMPORTANT: the script does not preserve VM extensions.

    The script can optionally delete the obsolete resources. If you choose not to delete them the script will create you an PowerShell file "removeresources.ps1" that you can use later to remove them

### Example

```PowerShell
$SubscriptionName = "[YOURSUBSCRIPRION]"
$ResourceGroupName = "prod-we-tf2-rg"
$VirtualMachineName = "TF1-db03"
$NewVirtualMachineName = "TF1-db01"
# By setting $DeleteVM = $true the script will delete the obsolete resoures. Use this with caution
$DeleteVM = $false

# This defines what the the new name will be for each disk
$diskList = @{ }
$diskList.Add("TF1-db03-data2", "TF1-db01-data1")
$diskList.Add("TF1-db03-data2", "TF1-db01-data2")
$diskList.Add("TF1-db03-log",   "TF1-db01-log")

./Rename-VM.ps1 -SubscriptionName $SubscriptionName -ResourceGroupName $ResourceGroupName   -VirtualMachineName $VirtualMachineName -NewVirtualMachineName $NewVirtualMachineName -DiskMap $diskList -Verbose -DeleteVM $DeleteVM
 ```
