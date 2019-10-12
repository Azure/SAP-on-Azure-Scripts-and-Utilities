<#

.SYNOPSIS
    Moves a VM into an Availability Set

.DESCRIPTION
    The script deletes the VM and recreates it preserving networking and storage configuration.
    There is no need to reinstall the operating system.

    IMPORTANT: the script does not preserve tags or VM extensions.

.EXAMPLE
    ./Move-VM-to-AvSet.ps1 -SubscriptionName testsubscription -region westeurope -ResourceGroupName test-rg -VirtualMachineName vm1 -newAvailabilitySetName AvSet1

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
    #Name of new Availability Set
    [Parameter(Mandatory=$true)][string]$newAvailabilitySetName 

)

# select subscription
	$Subscription = Get-AzSubscription -SubscriptionName $SubscriptionName
    if (-Not $Subscription) {
        Write-Host -ForegroundColor Red -BackgroundColor White "Sorry, it seems you are not connected to Azure or don't have access to the subscription. Please use Connect-AzAccount to connect."
        exit
    }


    Select-AzSubscription -Subscription $SubscriptionName -Force



# Get the details of the VM to be moved to the Availability Set
    Write-Host -ForegroundColor green ""
	Write-Host -ForegroundColor green "getting VM config"
    $originalVM = Get-AzVM `
	   -ResourceGroupName $ResourceGroupName `
	   -Name $VirtualMachineName
	   
	[string]$osType = $originalVM.StorageProfile.OsDisk.OsType


	IF ([string]::IsNullOrWhitespace($originalVM.zones))
	{	Write-Host -ForegroundColor green "VM is not part of Availability Zone, everything OK"
	}
	else {
		Write-Host -ForegroundColor red "VM is associated to an Availability Zone, it can't be part of a Zone and a Set at the same time."
		exit
	}

# Create new availability set if it does not exist
    $availSet = Get-AzAvailabilitySet `
	   -ResourceGroupName $ResourceGroupName `
	   -Name $newAvailabilitySetName `
	   -ErrorAction Ignore
    if (-Not $availSet) {
    $availSet = New-AzAvailabilitySet `
	   -Location $originalVM.Location `
	   -Name $newAvailabilitySetName `
	   -ResourceGroupName $ResourceGroupName `
	   -PlatformFaultDomainCount 3 `
	   -PlatformUpdateDomainCount 5 `
	   -Sku Aligned
    }
    
# Remove the original VM
    Remove-AzVM -ResourceGroupName $ResourceGroupName -Name $VirtualMachineName    

# Create the basic configuration for the replacement VM
    $newVM = New-AzVMConfig `
	   -VMName $originalVM.Name `
	   -VMSize $originalVM.HardwareProfile.VmSize `
	   -AvailabilitySetId $availSet.Id


	if ($osType -eq "Linux")
	{
		Write-Host -ForegroundColor green "OS Type is Linux"
		Set-AzVMOSDisk `
		   -VM $newVM -CreateOption Attach `
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
	}

# Add Data Disks
    foreach ($disk in $originalVM.StorageProfile.DataDisks) { 
    Add-AzVMDataDisk -VM $newVM `
	   -Name $disk.Name `
	   -ManagedDiskId $disk.ManagedDisk.Id `
	   -Caching $disk.Caching `
	   -Lun $disk.Lun `
	   -DiskSizeInGB $disk.DiskSizeGB `
	   -CreateOption Attach
    }
    
# Add NIC(s) and keep the same NIC as primary
	foreach ($nic in $originalVM.NetworkProfile.NetworkInterfaces) {	
	if ($nic.Primary -eq "True")
		{
    		Add-AzVMNetworkInterface `
       		-VM $newVM `
       		-Id $nic.Id -Primary
       		}
       	else
       		{
       		  Add-AzVMNetworkInterface `
      		  -VM $newVM `
      	 	  -Id $nic.Id 
                }
  	}

# Recreate the VM
    New-AzVM `
	   -ResourceGroupName $ResourceGroupName `
	   -Location $originalVM.Location `
	   -VM $newVM `
	   -DisableBginfoExtension