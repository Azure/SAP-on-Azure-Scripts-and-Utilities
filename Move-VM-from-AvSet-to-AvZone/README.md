# Move VM to Availability Zone

## Availability Sets

[Availability Zones](https://docs.microsoft.com/en-us/azure/virtual-machines/windows/manage-availability#configure-each-application-tier-into-separate-availability-zones-or-availability-sets) is a construct that allows you to create virtual machines that are on separate physical infrastructure, to get the most application resiliency.

## Moving the VM into an Availability Set

**requirements:**

- Azure Subscription
- PowerShell 5.1 or newer
- PowerShell module Az

### What the script does

    The script deletes the VM and recreates it preserving networking and storage configuration.  The script will snapshot each disk, create a new disk from the snapshot, and create the new VM with the new disks attached.  
 
    There is no need to reinstall the operating system.

    IMPORTANT: the script does not preserve VM extensions.  Also, the script will not work for VMs with public IP addresses - if your VM does have public 
    IP addresses, the script will end before changing anything.  You should remove the Public IP, then use this script, and then re-create the public IP.

### Example

     ./Move-VM-to-AvZone.ps1 -SubscriptionName testsubscription -region westeurope -ResourceGroupName test-rg -VirtualMachineName vm1 -newAvailabilityZoneNumber 2 

