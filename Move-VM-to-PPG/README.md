# Move VM to Proximity Placement Group

## Proximity Placement Groups (PPGs)

[Proximity Placement Groups](https://docs.microsoft.com/en-us/azure/virtual-machines/windows/proximity-placement-groups) (PPG) is a contruct where Azure tries to keep multiple resources as close together as possible.

The Proximity Placement Group needs to be specified during VM creation. If you want to move an existing VM into a Proximity Placement Group it is required to recreate the virtual machine.

## Moving the VM into a Proximity Placement Group (PPG)

**requirements:**
* Azure Subscription
* PowerShell 5.1 or newer
* PowerShell module Az

### What the script does

The script deletes and recreates it. It preserves networking and disk configuration. There is no need to reinstall the operating system.
If the PPG doesn't exist it is created.

*important: the script does not preserve tags or extensions, you need to manually add these again.*

### Example

```
.\Move-VM-to-PPG.ps1 -SubscriptionName mysubscription -region westeurope -ResourceGroupName Move-VM-Test-RG -VirtualMachineName vm1 -newProximityPlacementGroupName PPG1
```
