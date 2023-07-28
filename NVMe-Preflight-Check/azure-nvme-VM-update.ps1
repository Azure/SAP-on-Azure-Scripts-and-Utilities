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

[CmdletBinding()]
param (
    # Subscription ID
    [Parameter(Mandatory=$true)][string]$subscription_id,
    # Resource Group
    [Parameter(Mandatory=$true)][string]$resource_group_name,
    # VM Name
    [Parameter(Mandatory=$true)][string]$vm_name,
    # Disk Controller Type
    [ValidateSet("NVMe", "SCSI")][string]$disk_controller_change_to="NVMe",
    # New VM Size
    [Parameter(Mandatory=$true)][string]$vm_size_change_to,
    # Start VM after update
    [bool]$start_vm_after_update = $true
)

# RunLog function for more detailed data during execution
function WriteRunLog {
    [CmdletBinding()]
    param (
        [string]$message,
        [string]$category="INFO"
    )

    switch ($category) {
        "INFO"      {   $_prestring = "INFO     - "
                        $_color = "Green" }
        "WARNING"   {   $_prestring = "WARNING  - "
                        $_color = "Yellow" }
        "ERROR"     {   $_prestring = "ERROR    - "
                        $_color = "Red" }
    }
    $_runlog_row = "" | Select-Object "Log"
    $_runlog_row.Log = [string]$_prestring + [string]$message
    $script:_runlog += $_runlog_row
    if (-not $RunLocally) {
        Write-Host ($_prestring + $message) -ForegroundColor $_color
    }
}


# check if connected to Azure
$_SubscriptionInfo = Get-AzSubscription -SubscriptionId $subscription_id

# if $_SubscritpionInfo then it got subscriptions
if ($_SubscriptionInfo)
{

    $_ContextInfo = Get-AzContext

    if ($_ContextInfo.Subscription -eq $subscription_id) {
        # connected to correct context
        WriteRunLog -category "INFO" -message "Already connected to correct Azure context"
    }
    else {
        # setting context to correct subscription
        Set-AzContext -Subscription $subscription_id
    }
}
else {
    WriteRunLog -category "ERROR" -message "Please connect to Azure using the Connect-AzAccount command, if you are connected use the Select-AzSubscription command to set the correct context"
    exit
}

# Getting OS disk name
$os_disk_name = (Get-AzVM -ResourceGroupName $resource_group_name -Name $vm_name).StorageProfile.OsDisk.Name

if ($os_disk_name) {
    # found OS Disk
    WriteRunLog -category "INFO" -message "OS Disk found"
}
else 
{
    WriteRunLog -category "ERROR" -message "Please check the OS Disk"
}

# gettting Access Token for Web ARM request
$access_token = (Get-AzAccessToken).Token

if ($access_token) {
    # Access token valid
    WriteRunLog -category "INFO" -message "Access token generated"
}
else {
    WriteRunLog -category "ERROR" -message "Problems creating access token"
}

# generating URI for the OS disk update
$uri = 'https://management.azure.com/subscriptions/{0}/resourceGroups/{1}/providers/Microsoft.Compute/disks/{2}?api-version=2023-04-02' -f $subscription_id, $resource_group_name, $os_disk_name

# auth header for web request
$auth_header = @{
  'Content-Type'  = 'application/json'
  'Authorization' = 'Bearer ' + $access_token
}

# body for SCSI/NVMe enabled OS Disk
$body_nvmescsi = @'
{
    "properties": {
        "supportedCapabilities": {
            "diskControllerTypes":"SCSI, NVMe"
        }
    }
}
'@

# body for SCSI enabled OS Disk
$body_scsi = @'
{
    "properties": {
        "supportedCapabilities": {
            "diskControllerTypes":"SCSI"
        }
    }
}
'@

$_vminfo = Get-AzVM -ResourceGroupName $resource_group_name -Name $vm_name -Status

if ($_vminfo.Statuses[1].Code -eq "PowerState/deallocated") {
    # VM is already stopped
    WriteRunLog -category "INFO" -message "VM is stopped and deallocated"
}
else {
    #Stop and deallocate the VM
    WriteRunLog -category "INFO" -message "Stopping VM"
    Stop-AzVM -ResourceGroupName $resource_group_name -Name $vm_name -Force
}

if ($disk_controller_change_to -eq "NVMe") {
    #Add NVMe supported capabilities to the OS disk
    WriteRunLog -category "INFO" -message "Setting OS Disk to SCSI/NVMe"
    $Update_Supported_Capabilities = (Invoke-WebRequest -uri $uri -Method PATCH -body $body_nvmescsi -Headers $auth_header | ConvertFrom-Json)
}
else {
    #Add NVMe supported capabilities to the OS disk
    WriteRunLog -category "INFO" -message "Setting OS Disk to SCSI"
    $Update_Supported_Capabilities = (Invoke-WebRequest -uri $uri -Method PATCH -body $body_scsi -Headers $auth_header | ConvertFrom-Json)
}

# Get VM configuration
WriteRunLog -category "INFO" -message "Getting VM config to prepare new config"
$vm = Get-AzVM -ResourceGroupName $resource_group_name -Name $vm_name

# Set new VM size
WriteRunLog -category "INFO" -message "Setting new VM size"
$vm.HardwareProfile.VmSize = $vm_size_change_to

# Set new Controller type for VM
WriteRunLog -category "INFO" -message "Setting disk controller for VM"
$vm.StorageProfile.DiskControllerType = $disk_controller_change_to

# Update the VM
WriteRunLog -category "INFO" -message "Updating the VM configuration"
Update-AzVM -ResourceGroupName $resource_group_name -VM $vm

if ($start_vm_after_update) {
    # Start the VM
    WriteRunLog -category "INFO" -message "Starting VM"
    Start-AzVM -ResourceGroupName $resource_group_name -Name $vm_name
}
else {
    # Do not start VM
    WriteRunLog -category "INFO" -message "Not starting VM"
}