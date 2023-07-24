<#

.SYNOPSIS
    SAP on Azure NVMe conversion

.DESCRIPTION
    The script converts a VM from SCSI to NVMe controller

.LINK
    https://github.com/Azure/SAP-on-Azure-Scripts-and-Utilities

#>
<#
Copyright (c) Microsoft Corporation.
Licensed under the MIT license.
#>

#Requires -Version 7.1

$subscription_id = '232b6759-a961-4fb7-88c0-757472230e6c'
$resource_group_name = 'we-nvme-vm1'
$vm_name = 'we-nvme-vm1'
$disk_controller_change_to = 'NVMe'
#$disk_controller_change_to = 'SCSI'
$vm_size_change_to = 'Standard_E32bds_v5'
#$vm_size_change_to = 'Standard_E32ds_v5'


$os_disk_name = (Get-AzVM -ResourceGroupName $resource_group_name -Name $vm_name).StorageProfile.OsDisk.Name

# $uri = 'https://management.azure.com/subscriptions/{0}/resourceGroups/{1}/providers/Microsoft.Compute/disks/{2}?api-version=2022-07-02' -f $subscription_id, $resource_group_name, $os_disk_name
$uri = 'https://management.azure.com/subscriptions/{0}/resourceGroups/{1}/providers/Microsoft.Compute/disks/{2}?api-version=2023-04-02' -f $subscription_id, $resource_group_name, $os_disk_name

$access_token = (Get-AzAccessToken).Token

$auth_header = @{

  'Content-Type'  = 'application/json'

  'Authorization' = 'Bearer ' + $access_token
                                                    }
$body = @'
          {
"properties": {

"supportedCapabilities": {

  "diskControllerTypes":"SCSI, NVMe"

    }
    }
    }
'@

$get_supported_capabilities = (Invoke-WebRequest -uri $uri -Method Get -Headers $auth_header | ConvertFrom-Json).properties.supportedCapabilities

#Stop and deallocate the VM

Stop-AzVM -ResourceGroupName $resource_group_name -Name $vm_name -Force

#Add NVMe supported capabilities to the OS disk

$Update_Supported_Capabilities = (Invoke-WebRequest -uri $uri -Method PATCH -body $body -Headers $auth_header | ConvertFrom-Json)

#Get VM configuration

$vm = Get-AzVM -ResourceGroupName $resource_group_name -Name $vm_name

#Build a configuration with updated VM size

$vm.HardwareProfile.VmSize = $vm_size_change_to

#Build a configuration with updated disk controller type

$vm.StorageProfile.DiskControllerType = $disk_controller_change_to

#Change the VM size and VM’s disk controller type

Update-AzVM -ResourceGroupName $resource_group_name -VM $vm
#Start the VM

Start-AzVM -ResourceGroupName $resource_group_name -Name $vm_name