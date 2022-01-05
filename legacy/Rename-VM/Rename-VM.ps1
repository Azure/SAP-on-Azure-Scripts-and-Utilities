<#

.SYNOPSIS
    Renames a VM

.DESCRIPTION
    The script deletes the VM and recreates it preserving networking and storage configuration.  THe script will snapshot each disk, create a new disk from the 
    snapshot, and create the new VM with the new disks attached.  

    There is no need to reinstall the operating system.

    IMPORTANT: the script does not VM extensions or any identities assigned to the Virtual Machine.  Also, the script will not work for VMs with public IP addresses.

.EXAMPLE
    ./Rename-VM.ps1 -SubscriptionName testsubscription -ResourceGroupName test-rg -VirtualMachineName vm1 -NewVirtualMachineName vm2 -Diskmapping diskmap

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
    #New Virtual Machine name
    [Parameter(Mandatory = $true)][string]$NewVirtualMachineName,
    #Disk mapping
    [Parameter(Mandatory = $true)][hashtable]$diskmap,
    #Delete Old Items
    [Parameter(Mandatory = $false)][bool]$DeleteVM = $false
)

# select subscription
Write-Verbose "setting azure subscription"
$Subscription = Get-AzSubscription -SubscriptionName $SubscriptionName
if (-Not $Subscription) {
    Write-Host -ForegroundColor Red -BackgroundColor White "Sorry, it seems you are not connected to Azure or don't have access to the subscription. Please use Connect-AzAccount to connect."
    exit
}

Select-AzSubscription -Subscription $SubscriptionName -Force

# Get the details of the VM 
Write-Verbose  ""
Write-Verbose  "getting VM config"
	
$originalVM = Get-AzVM -ResourceGroupName $ResourceGroupName -Name $VirtualMachineName
$Resources = New-Object -TypeName "System.Collections.ArrayList"

$diskErrors = $false
# Validate the disk mapping
foreach ($disk in $originalVM.StorageProfile.DataDisks) {
    if (-Not $diskmap.ContainsKey($disk.Name)) {
        Write-Warning -Message ("Disk: " + $disk.name + " does not exist in the disk map.")
        $diskErrors = $true
    }   
}

$targetVM = Get-AzVM -ResourceGroupName $ResourceGroupName -Name $NewVirtualMachineName -ErrorAction SilentlyContinue

if ($targetVM) {
    Write-Warning  -Message ("Virtual Machine: " + $NewVirtualMachineName + " already exists.")
    exit
} 

if ($diskErrors) {
    exit
}

$Resources = New-Object -TypeName "System.Collections.ArrayList"

$IPConfig = $null 
$thenic = $null 
$Newnics = New-Object -TypeName "System.Collections.ArrayList"
foreach ($nic in $originalVM.NetworkProfile.NetworkInterfaces) {
    $thenic = $nic.id
    $nicname = $thenic.substring($thenic.LastIndexOf("/") + 1)
    $othernic = Get-AzNetworkInterface -Name $nicname -ResourceGroupName $ResourceGroupName 
    $IPConfig = $othernic.IpConfigurations
    $newNic = New-AzNetworkInterface -Name ($NewVirtualMachineName + "-nic") -ResourceGroupName $ResourceGroupName  -IpConfiguration $IPconfig -Location $originalVM.Location
    $Newnics.Add($newNic.Id)

}

[string]$osType = $originalVM.StorageProfile.OsDisk.OsType
[string]$location = $originalVM.Location
[string]$storageType = $originalVM.StorageProfile.OsDisk.ManagedDisk.StorageAccountType

$tags = $originalVM.Tags
    
#  Shutdown or remove the original VM
#  Stop-AzVM -ResourceGroupName $ResourceGroupName -Name $VirtualMachineName -force
if ($DeleteVM) {
    Write-Verbose  "removing existing VM"
    Remove-AzVM -ResourceGroupName $ResourceGroupName -Name $VirtualMachineName -force
}
else {
    $Resources.Add([string]$originalVM.Id)
    $Resources.Add([string]$thenic)
}

#  Create the basic configuration for the replacement VM
$newVM = New-AzVMConfig -VMName $NewVirtualMachineName -VMSize $originalVM.HardwareProfile.VmSize  -Tags $tags -AvailabilitySetId $originalVM.AvailabilitySetReference.Id -Zone $originalVM.Zones -ProximityPlacementGroupId $originalVM.ProximityPlacementGroup.Id
       
#  Snap and copy the os disk
Write-Verbose  "snapshotting disks"
$snapshotcfg = New-AzSnapshotConfig -Location $location -CreateOption copy -SourceResourceId $originalVM.StorageProfile.OsDisk.ManagedDisk.Id
$Resources.Add($originalVM.StorageProfile.OsDisk.ManagedDisk.Id)
$osdiskname = $originalVM.StorageProfile.OsDisk.Name
$snapshotName = $osdiskname + "-snap"
$snapshot = New-AzSnapshot -Snapshot $snapshotcfg -SnapshotName $snapshotName -ResourceGroupName $ResourceGroupName
$newdiskConfig = New-AzDiskConfig -AccountType $storageType -Location $location -CreateOption Copy -SourceResourceId $snapshot.Id 
$Resources.Add([string]$snapshot.Id)
$newdiskName = $NewVirtualMachineName + "-osdisk"
$newdisk = New-AzDisk -Disk $newdiskConfig -ResourceGroupName $ResourceGroupName -DiskName $newdiskName
	
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
    $Resources.Add([string]$disk.ManagedDisk.Id)
    $Resources.Add([string]$snapshot.Id)
    
    [string]$thisdiskStorageType = $disk.ManagedDisk.StorageAccountType
    $diskName = $diskmap[$disk.Name]
    $diskConfig = New-AzDiskConfig -SkuName $thisdiskStorageType -Location $location -CreateOption Copy -SourceResourceId $snapshot.Id
    $newdisk = New-AzDisk -Disk $diskConfig -ResourceGroupName $ResourceGroupName -DiskName $diskName

    Add-AzVMDataDisk -VM $newVM `
	       -Name $diskName `
	       -ManagedDiskId $newdisk.Id `
	       -Caching $disk.Caching `
	       -Lun $disk.Lun `
	       -DiskSizeInGB $newdisk.DiskSizeGB `
	       -CreateOption Attach

}

# Adding the network card(s)
$nicCount = 0
foreach ($nic in $Newnics) {
    if ($nicCount -eq 0) {
        Add-AzVMNetworkInterface `
            -VM $newVM `
            -Id $nic -Primary
    }
    else {
        {
            Add-AzVMNetworkInterface `
                -VM $newVM `
                -Id $nic

        }
    }
    $nicCount = $nicCount + 1 
}

Write-Verbose  "Creating the new VM"
New-AzVM  -ResourceGroupName $ResourceGroupName -Location $originalVM.Location -VM $newVM -DisableBginfoExtension 
Write-Host ("The new Virtual Machine " + $NewVirtualMachineName + " is created")

if ($DeleteVM) {
    $confirmation = Read-Host "Are you sure you want to delete the old Virtual Machine info? y/n?"
    if ($confirmation -eq 'y') {
        foreach ($Resource in $Resources) {
            Write-Host ("Removing " + $Resource)
            Remove-AzResource -ResourceId $Resource -Force
        }
    }
}
else {
    Set-Content -Path ".\removeresources.ps1" -Value "# This script can be used to delete the unused resources" -Force
    foreach ($resource in $Resources) {
        Add-Content -Path ".\removeresources.ps1" -Value ("Remove-AzResource -ResourceId " + $resource)
    }
}