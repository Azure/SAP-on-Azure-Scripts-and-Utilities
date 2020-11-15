<#

.SYNOPSIS
    Creates all the VMs specified in the export manifest

.DESCRIPTION
    Creates all the VMs specified in the export manifest

.PARAMETER ResourceGroup
    The resourcegroup to contain the VMs

.PARAMETER ExportManifest
    The export manifest file name

.EXAMPLE
    ./Create-VMs.ps1 -ResourceGroup App1  -ExportManifest manifestName

.LINK
    https://github.com/Azure/SAP-on-Azure-Scripts-and-Utilities

.NOTES
    v0.1 - Initial version
#>

<#
Copyright (c) Microsoft Corporation.
Licensed under the MIT license.
#>


param(
    #Azure Subscription Name
    [Parameter(Mandatory = $true)][string]$SubscriptionName = "AG-GE-CE-KIMFORSS-SAP",
    #Provide the name of your resource group where Managed Disks will be created. 
    [Parameter(Mandatory = $true)][string]$ResourceGroupName = "PROTO-WEEU-SAPPROT_DEMO-WOO-SNAP",
    [Parameter(Mandatory = $true)][string]$ExportManifest = "export.json"
)
# select subscription
$Subscription = Get-AzSubscription -SubscriptionName $SubscriptionName
if (-Not $Subscription) {
    Write-Host -ForegroundColor Red -BackgroundColor White "Sorry, it seems you are not connected to Azure or don't have access to the subscription. Please use Connect-AzAccount to connect."
    exit
}

Select-AzSubscription -Subscription $SubscriptionName -Force

$rg = Get-AzResourceGroup -Name $ResourceGroupName -ErrorVariable notPresent -ErrorAction SilentlyContinue
if ($notPresent) {
    exit

}
 
$VMs = Get-Content $ExportManifest | Out-String | ConvertFrom-Json 

foreach ($vm in $VMs) {
    $newVM = New-AzVMConfig -VMName $vm.Name -VMSize $vm.Size 

    if ($null -ne $vm.avset_ID) {
        $newVM.AvailabilitySetReference.Id = $vm.avset_ID
    }
    
    if ($null -ne $vm.ppg_ID) {
        $newVM.ProximityPlacementGroup = $vm.ppg_ID
    }
    
    $nicName = $vm.Name + "-nic"

    $disk2 = Get-AzDisk -ResourceGroupName $ResourceGroupName -DiskName $vm.OsDisk.Replace("*.vhd", "")
    if ("Linux" -eq $vm.OsType) {
        Set-AzVMOSDisk -VM $newVM -CreateOption Attach  -ManagedDiskId $disk2.Id -Name $vm.OsDisk  -Linux
    }
    else {
        Set-AzVMOSDisk -VM $newVM -CreateOption Attach  -ManagedDiskId $disk2.Id -Name $vm.OsDisk  -Windows
    }

    $nic = New-AzNetworkInterface -Name $nicName -ResourceGroupName $ResourceGroupName -Location $rg.Location -SubnetId $vm.subnet 

    if ($null -ne $vm.IP) {
        $nic.IpConfigurations[0].PrivateIpAddress = $vm.IP
        $nic.IpConfigurations[0].PrivateIpAllocationMethod = "static"
    }

    Add-AzVMNetworkInterface -VM $newVM -Id $nic.Id -Primary 

    foreach ($disk in $vm.Disks) {
        if ($vm.OsDisk -ne $disk.NewName) {
            $disk2 = Get-AzDisk -ResourceGroupName $ResourceGroupName -DiskName $disk.NewName
            Add-AzVMDataDisk -VM $newVM -Name $disk.NewName  -ManagedDiskId $disk2.Id -Caching $disk.Caching -Lun $disk.Lun -DiskSizeInGB $disk.Size -CreateOption Attach
        }
    }

    New-AzVM  -ResourceGroupName $ResourceGroupName -Location $rg.Location -VM $newVM -DisableBginfoExtension 
}
