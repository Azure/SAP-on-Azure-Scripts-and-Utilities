<#

.SYNOPSIS
    Moves a VM into an Availability Zone

.DESCRIPTION
    The script deletes the VM and recreates it preserving networking and storage configuration.  THe script will snapshot each disk, create a new disk from the 
    snapshot, and create the new VM with the new disks attached.  

    There is no need to reinstall the operating system.

    IMPORTANT: the script does not VM extensions or any identities assigned to the Virtual Machine.  Also, the script will not work for VMs with public IP addresses.

.EXAMPLE
    ./Move-VM-to-AvZone.ps1 -SubscriptionName testsubscription -ResourceGroupName test-rg -VirtualMachineName vm1 -newAvailabilityZoneNumber 2 

.LINK
    https://github.com/Azure/SAP-on-Azure-Scripts-and-Utilities

.NOTES
    v0.1 - Initial version

#>

#Requires -Modules Az.Compute
#Requires -Modules Az.Network
#Requires -Version 5.1

param(
    #Azure Subscription Name
    [Parameter(Mandatory = $true)][string]$SubscriptionName,
    #Resource Group Name that will be created
    [Parameter(Mandatory = $true)][string]$ResourceGroupName, 
    #Virtual Machine name
    [Parameter(Mandatory = $true)][string]$VirtualMachineName,
    #Number of Availability Zone
    [Parameter(Mandatory = $true)][string]$newAvailabilityZoneNumber
)

# select subscription
Write-Verbose "setting azure subscription"
$Subscription = Get-AzSubscription -SubscriptionName $SubscriptionName
if (-Not $Subscription) {
    Write-Host -ForegroundColor Red -BackgroundColor White "Sorry, it seems you are not connected to Azure or don't have access to the subscription. Please use Connect-AzAccount to connect."
    exit
}


Select-AzSubscription -Subscription $SubscriptionName -Force

# Get the details of the VM to be moved to the Availability Set
Write-Verbose  ""
Write-Verbose  "getting VM config"
	
$destzone = [int]$newAvailabilityZoneNumber

Write-Verbose $destzone
if($destzone -lt 1 -or $destzone -gt 3)
{
    Write-Host -ForegroundColor Red "Sorry, the value for avalability zones is 1,2 or 3" 
    exit
}

$originalVM = Get-AzVM -ResourceGroupName $ResourceGroupName -Name $VirtualMachineName

# We don't support moving machines with public IPs, since those are zone specific.  check for that here.
foreach ($nic in $originalVM.NetworkProfile.NetworkInterfaces) {
    $thenic = $nic.id
    $nicname = $thenic.substring($thenic.LastIndexOf("/") + 1)
    $othernic = Get-AzNetworkInterface -Name $nicname -ResourceGroupName $ResourceGroupName 
    foreach ($ipc in $othernic.IpConfigurations) {
        $pip = $ipc.PublicIpAddress
        if ($pip) { 
            Write-Host -ForegroundColor Red "Sorry, machines with public IPs are not supported by this script" 
            exit
        }
    }
}

[string]$osType = $originalVM.StorageProfile.OsDisk.OsType
[string]$location = $originalVM.Location
[string]$storageType = $originalVM.StorageProfile.OsDisk.ManagedDisk.StorageAccountType

$tags = $originalVM.Tags
    
#  Shutdown or remove the original VM
#  Stop-AzVM -ResourceGroupName $ResourceGroupName -Name $VirtualMachineName -force
Write-Verbose  "removing existing VM"
Remove-AzVM -ResourceGroupName $ResourceGroupName -Name $VirtualMachineName -force

#  Create the basic configuration for the replacement VM
$newVM = New-AzVMConfig -VMName $VirtualMachineName -VMSize $originalVM.HardwareProfile.VmSize -zone $destzone -Tags $tags
       
#  Snap and copy the os disk
Write-Verbose  "snapshotting disks"
$snapshotcfg = New-AzSnapshotConfig -Location $location -CreateOption copy -SourceResourceId $originalVM.StorageProfile.OsDisk.ManagedDisk.Id
$osdiskname = $originalVM.StorageProfile.OsDisk.Name
$snapshotName = $osdiskname + "-snap"
$snapshot = New-AzSnapshot -Snapshot $snapshotcfg -SnapshotName $snapshotName -ResourceGroupName $ResourceGroupName
$newdiskConfig = New-AzDiskConfig -AccountType $storageType -Location $location -CreateOption Copy -SourceResourceId $snapshot.Id -zone $destzone
$newdiskName = $osdiskname + "-z" + $destzone
$newdisk = New-AzDisk -Disk $newdiskConfig -ResourceGroupName $ResourceGroupName -DiskName $newdiskName

	
Write-Verbose  ("new disk info {0}" -f $newdisk.ManagedDisk.Id)
Write-Verbose  ("newdisk {0}" -f $newdisk )
Write-Verbose  ("newdisk.manageddisk {0}" -f $newdisk.ManagedDisk)
Write-Verbose  ("newdisk.manageddisk.id {0}" -f $newdisk.ManagedDisk.Id)
Write-Verbose  ("the newdisk value is {0}" -f $newdisk)
Write-Verbose  ("the newdisk.Id value is {0}" -f $newdisk.Id)
if ($osType -eq "Linux") {
    Write-Verbose "OS Type is Linux"
    Set-AzVMOSDisk -VM $newVM -CreateOption Attach  -ManagedDiskId $newdisk.Id -Name $newdisk.Name  -Linux
}
if ($osType -eq "Windows") {
    Write-Verbose "OS Type is Windows"
    Set-AzVMOSDisk -VM $newVM -CreateOption Attach  -ManagedDiskId $newdisk.Id -Name $newdisk.Name  -Windows		
}

# Snapshot & copy all of the drives
foreach ($disk in $originalVM.StorageProfile.DataDisks) {
    #snapshot & copy the data disk
    $snapshotcfg = New-AzSnapshotConfig -Location $location -CreateOption copy -SourceResourceId $disk.ManagedDisk.Id

    $snapshotName = $disk.Name + "-snap"		      
    $snapshot = New-AzSnapshot -Snapshot $snapshotcfg -SnapshotName $snapshotName -ResourceGroupName $ResourceGroupName
    [string]$thisdiskStorageType = $disk.StorageAccountType
    $diskName = $disk.Name + "-z" + $destzone
    $diskConfig = New-AzDiskConfig -AccountType $storageType -Location $location -CreateOption Copy -SourceResourceId $snapshot.Id -zone $destzone
    $newdisk = New-AzDisk -Disk $diskConfig -ResourceGroupName $ResourceGroupName -DiskName $diskName

    Add-AzVMDataDisk -VM $newVM `
	       -Name $newdisk.Name `
	       -ManagedDiskId $newdisk.Id `
	       -Caching $disk.Caching `
	       -Lun $disk.Lun `
	       -DiskSizeInGB $newdisk.DiskSizeGB `
	       -CreateOption Attach

}

foreach ($nic in $originalVM.NetworkProfile.NetworkInterfaces) {
    if ($nic.Primary -eq "True") {
        Add-AzVMNetworkInterface `
            -VM $newVM `
            -Id $nic.Id -Primary
    }
    else {
        Add-AzVMNetworkInterface `
            -VM $newVM `
            -Id $nic.Id
    }
}
Write-Verbose  "creating zonal VM"
New-AzVM  -ResourceGroupName $ResourceGroupName -Location $originalVM.Location -VM $newVM -DisableBginfoExtension -zone $destzone
    



