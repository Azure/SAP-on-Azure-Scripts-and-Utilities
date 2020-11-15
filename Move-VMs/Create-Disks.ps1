<#

.SYNOPSIS
    Creates snapshots of all VMs in a resource group and an export manifest

.DESCRIPTION
    The script will snapshot all VMs and their disks. The script will also create an export manifest

.PARAMETER ResourceGroup
    The resourcegroup containing the VMs

.PARAMETER StorageAccountName 
    The name of the storage account to contain the VHDs

.PARAMETER ExportManifest
    The export manifest file name


.EXAMPLE
    ./Create-Disks.ps1 -ResourceGroup App1  -ExportManifest manifestName

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
    [Parameter(Mandatory = $true)][string]$SubscriptionName,
    #Provide the name of your resource group where Managed Disks will be created. 
    [Parameter(Mandatory = $true)][string]$ResourceGroupName,
    [Parameter(Mandatory = $true)][string]$StorageAccountName,
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

$storageAccountId = (Get-AzStorageAccount -Name $StorageAccountName -ResourceGroupName $ResourceGroupName).Id
 
$VMs = Get-Content $ExportManifest | Out-String | ConvertFrom-Json 

foreach ($vm in $VMs) {
    foreach ($disk in $vm.Disks) {
        $sourceVHDURI = "https://" + $StorageAccountName + ".blob.core.windows.net/disks/" + $disk.Name +".vhd"
        Write-Host "Processing: " $sourceVHDURI
        #Provide the size of the disks in GB. It should be greater than the VHD file size.
        $diskSize = $disk.Size
        Write-Host $diskSize

        #Provide the storage type for Managed Disk. Premium_LRS or Standard_LRS.
        $storageType = $disk.SKU
        Write-Host $storageType

        $diskConfig = New-AzDiskConfig -AccountType $storageType -Location $rg.Location -CreateOption Import -StorageAccountId $storageAccountId -SourceUri $sourceVHDURI
        New-AzDisk -Disk $diskConfig -ResourceGroupName $resourceGroupName -DiskName $disk.NewName

    }
}
