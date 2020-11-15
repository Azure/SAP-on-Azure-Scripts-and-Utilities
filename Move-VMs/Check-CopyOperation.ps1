<#

.SYNOPSIS
    Creates snapshots of all VMs in a resource group and an export manifest

.DESCRIPTION
    The script will snapshot all VMs and their disks. The script will also create an export manifest


 .PARAMETER StorageAccountName 
    The name of the storage account that contains the VHDs


.PARAMETER ExportManifest
    The export manifest file name


.EXAMPLE
    ./Check-CopyOperation.ps1 -StorageAccountName stgAccount -ExportManifest manifestName

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
    #The name of the storage account that contains the VHDs
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

$VMs = Get-Content $ExportManifest | Out-String | ConvertFrom-Json 

$storageAccountKey = (Get-AzStorageAccountKey -ResourceGroupName $TargetResourceGroupName -AccountName $storageAccountName) | Where-Object { $_.KeyName -eq "key1" }

#Create the context of the storage account where the underlying VHD of the managed disk will be copied
$context = New-AzStorageContext -StorageAccountName $storageAccountName -StorageAccountKey $storageAccountKey.Value

$StatusText
foreach ($vm in $VMs) {
    foreach ($disk in $vm.Disks) {
        $sourceVHDURI = $disk.Name +".vhd"
        Write-Host "Checking: " $sourceVHDURI
        $status = Get-AzStorageBlobCopyState -Blob $sourceVHDURI -Container "disks" -Context $context

        Write-Host "Status" : $status.Status

        if($status.Status -ne "Success")
        {
            $StatusText= "Some copy oprations are still in progress, please wait and run this again before proceeding to the next step" 
        }

    }
}

Write-Host $StatusText