# Move VM to Availability Set

## Availability Sets

[Availability Sets](https://docs.microsoft.com/en-us/azure/virtual-machines/windows/manage-availability#configure-multiple-virtual-machines-in-an-availability-set-for-redundancy) is a contruct where Azure takes care that virtual machines are placed in different Fault Domains (FD).

The Availability Set needs to be specified during VM creation. If you want to move an existing VM into an Availability Set it is required to recreate the virtual machine.

## Moving the VM into an Availability Set

**requirements:**

- Azure Subscription
- PowerShell 5.1 or newer
- PowerShell module Az

### What the script does

The script deletes and recreates the Virtual Machine. It preserves networking and disk configuration. There is no need to reinstall the operating system.

_important: the script does not preserve tags or extensions, you need to manually add these again._

### Example

    .\Move-VM-to-AvSet.ps1 -SubscriptionName mysubscription -region westeurope -ResourceGroupName Move-VM-Test-RG -VirtualMachineName vm1 -newAvailabilitySetName AvSet1

