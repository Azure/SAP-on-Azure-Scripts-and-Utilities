<#

.SYNOPSIS
    Moves a VM into a Proximity Placement Group

.DESCRIPTION
    The script deletes the VM and recreates it preserving networking and storage configuration.
    There is no need to reinstall the operating system.

    If the Proximity Placement Group doesn't exist it is created.

    IMPORTANT: the script does not preserve tags or VM extensions.

.EXAMPLE
    ./Move-VM-to-PPG.ps1 -SubscriptionName testsubscription -region westeurope -ResourceGroupName test-rg -VirtualMachineName vm1 -newProximityPlacementGroupName PPG1

.LINK
    https://github.com/Azure/SAP-on-Azure-Scripts-and-Utilities

.NOTES
    v0.1 - Initial version

#>
<#
Copyright (c) Microsoft Corporation.
Licensed under the MIT license.
#>

#Requires -Modules Az.Compute
#Requires -Version 5.1

param(
    #Azure Subscription Name
    [Parameter(Mandatory=$true)][string]$SubscriptionName,
    #Azure Region, use Get-AzLocation to get region names
    [Parameter(Mandatory=$true)][string]$region,
    #Resource Group Name that will be created
    [Parameter(Mandatory=$true)][string]$ResourceGroupName, 
    #Virtual Machine name
    [Parameter(Mandatory=$true)][string]$VirtualMachineName,
    #Name of new Proximity Placement Group
    [Parameter(Mandatory=$true)][string]$newProximityPlacementGroupName

)

	Write-Host -ForegroundColor green "ResourceGroup: $ResourceGroupName"
	Write-Host -ForegroundColor green "VM Name: $VirtualMachineName"
	Write-Host -ForegroundColor green "PPG: $newProximityPlacementGroupName"


# Get the details of the VM to be moved to PPG
    Write-Host -ForegroundColor green ""
	Write-Host -ForegroundColor green "getting VM config"
	$originalVM = Get-AzVM `
	   -ResourceGroupName $ResourceGroupName `
	   -Name $VirtualMachineName
	   
	[string]$osType = $originalVM.StorageProfile.OsDisk.OsType

# Create PPG if it does not exist
	Write-Host -ForegroundColor green "check if PPG exists"
	$ppg = Get-AzProximityPlacementGroup `
		-ResourceGroupName $ResourceGroupName `
		-Name $newProximityPlacementGroupName `
		-ErrorAction Ignore
	if (-Not $ppg) {
		Write-Host -ForegroundColor green "creating PPG"
		$ppg = New-AzProximityPlacementGroup `
			-ResourceGroupName $ResourceGroupName `
			-Name $newProximityPlacementGroupName `
			-Location $originalVM.location
	}
    
# Remove the original VM
	Write-Host -ForegroundColor green "Removing VM Config"
    Remove-AzVM -ResourceGroupName $ResourceGroupName -Name $VirtualMachineName -Force

# Create the basic configuration for the replacement VM
	IF ([string]::IsNullOrWhitespace($originalVM.zones))
	{	Write-Host -ForegroundColor green "Creating VM Config without Zones"
		$newVM = New-AzVMConfig `
			   -VMName $originalVM.Name `
			   -VMSize $originalVM.HardwareProfile.VmSize `
			   -ProximityPlacementGroupId $ppg.Id
		$backupVM = New-AzVMConfig `
			   -VMName $originalVM.Name `
			   -VMSize $originalVM.HardwareProfile.VmSize `
	}
	else {
		Write-Host -ForegroundColor green "Creating VM Config with Zones"
		$newVM = New-AzVMConfig `
			   -VMName $originalVM.Name `
			   -VMSize $originalVM.HardwareProfile.VmSize `
			   -ProximityPlacementGroupId $ppg.Id `
			   -zone $originalVM.zones
		$backupVM = New-AzVMConfig `
			   -VMName $originalVM.Name `
			   -VMSize $originalVM.HardwareProfile.VmSize `
			   -zone $originalVM.zones

	}

	if ($osType -eq "Linux")
	{
		Write-Host -ForegroundColor green "OS Type is Linux"
		Set-AzVMOSDisk `
		   -VM $newVM -CreateOption Attach `
		   -ManagedDiskId $originalVM.StorageProfile.OsDisk.ManagedDisk.Id `
		   -Name $originalVM.StorageProfile.OsDisk.Name `
		   -Linux
		Set-AzVMOSDisk `
		   -VM $backupVM -CreateOption Attach `
		   -ManagedDiskId $originalVM.StorageProfile.OsDisk.ManagedDisk.Id `
		   -Name $originalVM.StorageProfile.OsDisk.Name `
		   -Linux
		   
	}
	if ($osType -eq "Windows")
	{
		Write-Host -ForegroundColor green "OS Type is Windows"
		Set-AzVMOSDisk `
		   -VM $newVM -CreateOption Attach `
		   -ManagedDiskId $originalVM.StorageProfile.OsDisk.ManagedDisk.Id `
		   -Name $originalVM.StorageProfile.OsDisk.Name `
		   -Windows
		Set-AzVMOSDisk `
		   -VM $backupVM -CreateOption Attach `
		   -ManagedDiskId $originalVM.StorageProfile.OsDisk.ManagedDisk.Id `
		   -Name $originalVM.StorageProfile.OsDisk.Name `
		   -Windows
	}

# Add Data Disks
    Write-Host -ForegroundColor green "adding disks"
	foreach ($disk in $originalVM.StorageProfile.DataDisks) { 
		Add-AzVMDataDisk -VM $newVM `
		   -Name $disk.Name `
		   -ManagedDiskId $disk.ManagedDisk.Id `
		   -Caching $disk.Caching `
		   -Lun $disk.Lun `
		   -DiskSizeInGB $disk.DiskSizeGB `
		   -CreateOption Attach
		Add-AzVMDataDisk -VM $backupVM `
		   -Name $disk.Name `
		   -ManagedDiskId $disk.ManagedDisk.Id `
		   -Caching $disk.Caching `
		   -Lun $disk.Lun `
		   -DiskSizeInGB $disk.DiskSizeGB `
		   -CreateOption Attach

    }
    
# Add NIC(s) and keep the same NIC as primary
    Write-Host -ForegroundColor green "adding network interfaces"
	foreach ($nic in $originalVM.NetworkProfile.NetworkInterfaces) {	
	if ($nic.Primary -eq "True")
		{
    		Add-AzVMNetworkInterface `
				-VM $newVM `
				-Id $nic.Id -Primary
    		Add-AzVMNetworkInterface `
				-VM $backupVM `
				-Id $nic.Id -Primary

       	}
       	else
       	{
       		  Add-AzVMNetworkInterface `
				-VM $newVM `
				-Id $nic.Id 
       		  Add-AzVMNetworkInterface `
				-VM $backupVM `
				-Id $nic.Id 
        }
  	}

# Recreate the VM
	Write-Host -ForegroundColor green "Trying to create VM with PPG"
    New-AzVM `
	   -ResourceGroupName $ResourceGroupName `
	   -Location $originalVM.Location `
	   -VM $newVM `
	   -DisableBginfoExtension `
	   -erroraction 'silentlycontinue'
	if ($?)
	{
		"No error"
	} else
	{
		Write-Host -ForegroundColor green "Something went wrong, restoring original VM"

		Start-Sleep -Seconds 5
		Remove-AzVM -ResourceGroupName $ResourceGroupName -Name $VirtualMachineName -Force
		Start-Sleep 15
		
		New-AzVM `
		   -ResourceGroupName $ResourceGroupName `
		   -Location $originalVM.Location `
		   -VM $backupVM `
		   -DisableBginfoExtension
		   
		Write-Host -ForegroundColor green "Original VM has been restored as provisioning with PPG failed"
	}

