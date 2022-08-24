<#PSScriptInfo

.DESCRIPTION Azure Automation runbook script to start an SAP Application Server.

.VERSION 0.0.2

.GUID ec9a6f30-b5ab-4ab0-bb29-0a6c072bdd26

.AUTHOR Goran Condric

.COMPANYNAME Microsoft

.COPYRIGHT (c) 2020 Microsoft . All rights reserved.

.TAGS Azure Automation SAP Application Server Start Runbook

.LICENSEURI

.PROJECTURI

.ICONURI

.EXTERNALMODULEDEPENDENCIES SAPAzurePowerShellModules

.REQUIREDSCRIPTS

.EXTERNALSCRIPTDEPENDENCIES

.RELEASENOTES
0.0.1: - Add initial version
0.0.2: - Add dedpendencies to SAPAzurePowerShellModules module

#>

#Requires -Module SAPAzurePowerShellModules

Param(
    [Parameter(Mandatory = $True)]
     [ValidateNotNullOrEmpty()]        
     [string] $ResourceGroupName,
           
     [Parameter(Mandatory = $True)]
     [ValidateNotNullOrEmpty()]        
     [string] $VMName,

    [Parameter(Mandatory = $False)] 
    [int] $SAPApplicationServerWaitTime = "300",

    [Parameter(Mandatory=$False)] 
    [bool] $ConvertDisksToPremium =  $False,

    [Parameter(Mandatory=$False)] 
    [bool] $PrintExecutionCommand = $False,

    [Parameter(Mandatory=$false, HelpMessage="Subscription ID. If null, the current subscription of automation account is used instead.")] 
    [ValidateLength(36,36)]
    [string] $SubscriptionId
)

$ResourceGroupName  = $ResourceGroupName.Trim()
$VMName             = $VMName.Trim()

# Connect to Azure
$connection = Get-AutomationConnection -Name AzureRunAsConnection
Add-AzAccount  -ServicePrincipal -Tenant $connection.TenantID -ApplicationId $connection.ApplicationID -CertificateThumbprint $connection.CertificateThumbprint 

# get start time
$StartTime = Get-Date

# Check if resource group exists. If $False exit
Confirm-AzResoureceGroupExist -ResourceGroupName $ResourceGroupName 

# Check if VM. If $False exit
Confirm-AzVMExist -ResourceGroupName $ResourceGroupName -VMName $VMName

# Get SAP Application Server data
$SAPApplicationServerData = Get-AzSAPApplicationInstanceData -ResourceGroupName $ResourceGroupName -VMName $VMName  

####################################
# Convert the disks to Premium_LRS
####################################
if($ConvertDisksToPremium){
    ConvertTo-AzVMManagedDisksToPremium -ResourceGroupName  $ResourceGroupName -VMName  $VMName    
}

# Start Azure VM
Start-AzVMAndPrintStatus  -ResourceGroupName $ResourceGroupName -VMName $VMName

# Start SAP Application Server
Start-AzSAPApplicationServer  -ResourceGroupName $ResourceGroupName -VMName $VMName -WaitTime $SAPApplicationServerWaitTime -PrintExecutionCommand $PrintExecutionCommand 

# Get end time
$EndTime = Get-Date
$ElapsedTime = $EndTime - $StartTime

Write-Output ""
Write-Output "Job succesfully finished."
Write-Output ""

Write-Output "SUMMARY:"
If($ConvertDisksToPremium){
    Write-Output "  - All disks set to 'Premium_LRS' type."
}else{
    Write-Output "  - All disks types are NOT changed."
}
Write-Output "  - Virtual machine(s) started."
Write-Output "  - SAP Application Server with SAP SID '$($SAPApplicationServerData.SAPSID)' and instance number '$($SAPApplicationServerData.SAPApplicationInstanceNumber)' on VM '$VMName' and Azure resource group '$ResourceGroupName' started."
Write-Output ""

Write-Output "[INFO] Total time : $($ElapsedTime.Days) days, $($ElapsedTime.Hours) hours,  $($ElapsedTime.Minutes) minutes, $($ElapsedTime.Seconds) seconds, $($ElapsedTime.Seconds) milliseconds."