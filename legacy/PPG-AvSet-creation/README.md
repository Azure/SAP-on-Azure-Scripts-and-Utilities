
# Create Proximity Placement Group and Availability Set

## Proximity Placement Groups (PPGs)

[Proximity Placement Groups](https://docs.microsoft.com/en-us/azure/virtual-machines/windows/proximity-placement-groups) (PPG) is a contruct where Azure tries to keep multiple resources as close together as possible.

The Proximity Placement Group needs to be specified during VM creation. If you want to move an existing VM into a Proximity Placement Group it is required to recreate the virtual machine.

## Availability Sets

[Availability Sets](https://docs.microsoft.com/en-us/azure/virtual-machines/windows/manage-availability#configure-multiple-virtual-machines-in-an-availability-set-for-redundancy) is a contruct where Azure takes care that virtual machines are placed in different Fault Domains (FD).

The Availability Set needs to be specified during VM creation. If you want to move an existing VM into an Availability Set it is required to recreate the virtual machine.

**requirements:**

- Azure Subscription
- PowerShell 5.1 or newer
- PowerShell module Az

### What the script does

The script creates a proximity placement group and an availability set which will be placed in the availability set.

### Example

    .\Create-AvSet-with-PPG.ps1 -SubscriptionName "mysubscription" -region westeurope -ResourceGroupName test-rg -newAvailabilitySetName AvSet1 -newProximityPlacementGroupName "PPG1"
