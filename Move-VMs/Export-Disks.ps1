<#

.SYNOPSIS
    Creates snapshots of all VMs in a resource group and an export manifest

.DESCRIPTION
    The script will snapshot all VMs and their disks. The script will also create an export manifest

.PARAMETER ResourceGroup
    The resourcegroup containing the VMs

.PARAMETER TargetResourceGroup
    The resourcegroup to contain the VHDs

.PARAMETER StorageAccountName 
    The name of the storage account to contain the VHDs

.PARAMETER Location 
    The location for the storage account
 
.PARAMETER ExportManifest
    The export manifest file name

.EXAMPLE
    \Export-Disks.ps1 -SubscriptionName AG-GE-CE-KIMFORSS-SAP -ResourceGroupName PROTO-NOEU-SAPPROT_DEMO-WOO -TargetResourceGroupName PROTO-WEEU-SAPPROT_DEMO-WOO -storageAccountName protoweeumigratedisks -Location westeurope -ExportManifest export.json

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
    #The resourcegroup that contains the VMs
    [Parameter(Mandatory = $true)][string]$ResourceGroupName,
    #The resourcegroup to contain  the VHDs
    [Parameter(Mandatory = $true)][string]$TargetResourceGroupName,
    [Parameter(Mandatory = $true)][string]$Location, 
    [Parameter(Mandatory = $true)][string]$storageAccountName,
    [Parameter(Mandatory = $true)][string]$ExportManifest = "export.json"

)

$useAzCopy = 1

# select subscription
$Subscription = Get-AzSubscription -SubscriptionName $SubscriptionName
if (-Not $Subscription) {
    Write-Host -ForegroundColor Red -BackgroundColor White "Sorry, it seems you are not connected to Azure or don't have access to the subscription. Please use Connect-AzAccount to connect."
    exit
}

Select-AzSubscription -Subscription $SubscriptionName -Force

Get-AzResourceGroup -Name $ResourceGroupName -ErrorVariable notPresent -ErrorAction SilentlyContinue
if ($notPresent) {
    exit
}

#Name of the storage container where the downloaded VHD will be stored
$storageContainerName = "disks"

$rgSnap = Get-AzResourceGroup -Name $TargetResourceGroupName -ErrorVariable snapnotPresent -ErrorAction SilentlyContinue
if ($snapnotPresent) {
    Write-Host "Creating the resource group :" $TargetResourceGroupName
    $rgSnap = New-AzResourceGroup -Name $TargetResourceGroupName -Location $Location 
    $account = New-AzStorageAccount -ResourceGroupName $TargetResourceGroupName -Name $storageAccountName  -SkuName "Standard_LRS" -Location $Location 
    New-AzStorageContainer -Name $storageContainerName -Context $account.Context -Permission Container  
}
else {
    $account = Get-AzStorageAccount -ResourceGroupName $TargetResourceGroupName -Name $storageAccountName -ErrorVariable saPresent -ErrorAction SilentlyContinue
    if ($saPresent) {
        $account = New-AzStorageAccount -ResourceGroupName $TargetResourceGroupName -Name $storageAccountName  -SkuName "Standard_LRS" -Location $rgSnap.Location 
        New-AzStorageContainer -Name $storageContainerName -Context $account.Context -Permission Container  
    }
        
}


$storageAccountKey = (Get-AzStorageAccountKey -ResourceGroupName $TargetResourceGroupName -AccountName $storageAccountName) | Where-Object { $_.KeyName -eq "key1" }

#Provide Shared Access Signature (SAS) expiry duration in seconds e.g. 3600.
#Know more about SAS here: https://docs.microsoft.com/en-us/Az.Storage/storage-dotnet-shared-access-signature-part-1
$sasExpiryDuration = "3600"

#Create the context of the storage account where the underlying VHD of the managed disk will be copied
$destinationContext = New-AzStorageContext -StorageAccountName $storageAccountName -StorageAccountKey $storageAccountKey.Value

$containerURL = $destinationContext.BlobEndPoint

$Info = @()

#Get a list of all VM's in resource group
$VMs = (Get-AzResource -ResourceGroupName $ResourceGroupName -ResourceType Microsoft.Compute/virtualMachines).Name
foreach ($vmName in $VMs) {

    $VMInfo = new-object PSObject
    $Disks = @()

    $VMInfo | add-member -MemberType NoteProperty -Name "Name" -Value $vmName

    $tempVM = Get-AzVM -Name $vmName -ResourceGroupName $ResourceGroupName 
    if ($tempVM) {
        Write-Host "Processing " $vmName
        
        $disk = $tempVM.StorageProfile.OsDisk

        $VMInfo | add-member -MemberType NoteProperty -Name "Size" -Value $tempVM.HardwareProfile.VmSize
        $VMInfo | add-member -MemberType NoteProperty -Name "OsDisk" -Value $disk.Name
        $VMInfo | add-member -MemberType NoteProperty -Name "OsType" -Value $tempVM.StorageProfile.OsDisk.OsType
        $VMInfo | add-member -MemberType NoteProperty -Name "ppg_ID" -Value $tempVM.ProximityPlacementGroup.Id
        $VMInfo | add-member -MemberType NoteProperty -Name "avset_ID" -Value $tempVM.AvailabilitySetReference.Id
        $VMInfo | add-member -MemberType NoteProperty -Name "Zone" -Value $tempVM.Zones[0]
        $VMInfo | add-member -MemberType NoteProperty -Name "Tag_keys" -Value $tempVM.Tags.Keys
        $VMInfo | add-member -MemberType NoteProperty -Name "Tag_values" -Value $tempVM.Tags.Values

        $nic = Get-AzNetworkInterface -Name $tempVM.NetworkProfile.NetworkInterfaces[0].Id.Split("/")[8] -ResourceGroupName $ResourceGroupName
        $VMInfo | add-member -MemberType NoteProperty -Name "subnet" -Value  $nic.IpConfigurations[0].Subnet.Id
        $VMInfo | add-member -MemberType NoteProperty -Name "IP" -Value  $nic.IpConfigurations[0].PrivateIpAddress
        

        
        $disk2 = Get-AzDisk -ResourceGroupName $ResourceGroupName -DiskName $disk.Name 
        $DiskInfo = new-object PSObject
        $DiskInfo | add-member -MemberType NoteProperty -Name "Name" -Value $disk.Name
        $DiskInfo | add-member -MemberType NoteProperty -Name "NewName" -Value $disk.Name
        $DiskInfo | add-member -MemberType NoteProperty -Name "Size" -Value $disk2.DiskSizeGB
        $DiskInfo | add-member -MemberType NoteProperty -Name "SKU" -Value $disk2.Sku.Name
        $DiskInfo | add-member -MemberType NoteProperty -Name "WriteAcceleratorEnabled" -Value $disk2.WriteAcceleratorEnabled

        $Disks += $DiskInfo

        #Provide the name of the destination VHD file to which the VHD of the managed disk will be copied.
        $destinationVHDFileName = $disk.Name + ".vhd"
        try {
            #Stop-AzVM -Name $vmName -ResourceGroupName $ResourceGroupName 

            #Generate the SAS for the managed disk 
            $sas = Grant-AzDiskAccess -ResourceGroupName $ResourceGroupName -DiskName $disk.Name -DurationInSecond $sasExpiryDuration -Access Read 

            #Copy the VHD of the managed disk to the storage account
            if ($useAzCopy -eq 1) {
                $blobSASURI = New-AzStorageBlobSASToken -Context $destinationContext -ExpiryTime(get-date).AddSeconds($sasExpiryDuration) -Container $storageContainerName -Blob $destinationVHDFileName -Permission rw
                $blobURL = $containerURL + $storageContainerName + "/" + $destinationVHDFileName + $blobSASURI
                .\azcopy cp $sas.AccessSAS $blobURL
            }
            else {
                Start-AzStorageBlobCopy -AbsoluteUri $sas.AccessSAS -DestContainer $storageContainerName -DestContext $destinationContext -DestBlob $destinationVHDFileName
            }

            # Snapshot & copy all of the drives
            foreach ($disk in $tempVM.StorageProfile.DataDisks) {
                #snapshot & copy the data disk
                if ($disk.ManagedDisk.StorageAccountType -ne "UltraSSD_LRS") {
                    $sas = Grant-AzDiskAccess -ResourceGroupName $ResourceGroupName -DiskName $disk.Name -DurationInSecond $sasExpiryDuration -Access Read 

                    $destinationVHDFileName = $disk.Name + ".vhd"
                
                    Start-AzStorageBlobCopy -AbsoluteUri $sas.AccessSAS -DestContainer $storageContainerName -DestContext $destinationContext -DestBlob $destinationVHDFileName

                    $disk2 = Get-AzDisk -ResourceGroupName $ResourceGroupName -DiskName $disk.Name 
                    $DiskInfo = new-object PSObject
                    $DiskInfo | add-member -MemberType NoteProperty -Name "Name" -Value $disk.Name
                    $DiskInfo | add-member -MemberType NoteProperty -Name "NewName" -Value $disk.Name
                    $DiskInfo | add-member -MemberType NoteProperty -Name "Size" -Value $disk2.DiskSizeGB
                    $DiskInfo | add-member -MemberType NoteProperty -Name "SKU" -Value $disk2.Sku.Name
                    $DiskInfo | add-member -MemberType NoteProperty -Name "Caching" -Value $disk.Caching
                    $DiskInfo | add-member -MemberType NoteProperty -Name "Lun" -Value $disk.Lun
                    $DiskInfo | add-member -MemberType NoteProperty -Name "WriteAcceleratorEnabled" -Value $disk.WriteAcceleratorEnabled

                    $Disks += $DiskInfo
                }
            }

            $VMInfo | add-member -MemberType NoteProperty -Name "Disks" -Value $Disks

            $Info += $VMInfo
            $stop = $false

            if ($stop) {
                break
            }
            
        }
        catch {
            Write-Host error
        }
    }
}        

Write-Output $Info 
$Info | ConvertTo-Json -Depth 5 | Out-File $ExportManifest -Force
