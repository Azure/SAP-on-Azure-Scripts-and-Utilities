<#PSScriptInfo

.DESCRIPTION Azure Automation Runbook Script to start an SAP system.

.VERSION 0.0.4

.GUID d1b72758-4395-4316-bebd-905fe3319ffe

.AUTHOR Goran Condric

.COMPANYNAME Microsoft

.COPYRIGHT (c) 2020 Microsoft . All rights reserved.

.TAGS Azure Automation SAP System Start Runbook

.LICENSEURI

.PROJECTURI

.ICONURI

.EXTERNALMODULEDEPENDENCIES SAPAzurePowerShellModules

.REQUIREDSCRIPTS

.EXTERNALSCRIPTDEPENDENCIES

.RELEASENOTES
0.0.1: - Add initial version
0.0.3: - Add dedpendencies to SAPAzurePowerShellModules module
0.0.4: - Add functionality for Java systems
#>

#Requires -Module SAPAzurePowerShellModules

Param(
    
    [Parameter(Mandatory=$True, HelpMessage="SAP System <SID>. 3 characters , starts with letter.")] 
    [ValidateLength(3,3)]
    [string] $SAPSID,

    [Parameter(Mandatory=$False)] 
    [int] $WaitForStartTimeInSeconds = "600",

    [Parameter(Mandatory=$False)] 
    [bool] $ConvertDisksToPremium =  $False,

    [Parameter(Mandatory=$False)] 
    [bool] $PrintExecutionCommand = $False,

    [Parameter(Mandatory=$false, HelpMessage="Subscription ID. If null, the current subscription of automation account is used instead.")] 
    [ValidateLength(36,36)]
    [string] $SubscriptionId
)

# Deprecated due to using System Managed Identity
#$connection = Get-AutomationConnection -Name AzureRunAsConnection
#Add-AzAccount  -ServicePrincipal -Tenant $connection.TenantID -ApplicationId $connection.ApplicationID -CertificateThumbprint $connection.CertificateThumbprint 

# Connect to Azure with Automation Account system-assigned managed identity
# Ensure that you do not inherit an AZ Context in your runbook
Disable-AzContextAutosave -Scope Process | out-null

# Connect using Managed Service Identity
try {
	$AzureContext = (Connect-AzAccount -Identity -WarningAction Ignore).context
}
catch{
	Write-Output "There is no system-assigned user identity. Aborting."; 
	Write-Error  $_.Exception.Message
	exit
}

if ($SubscriptionId){
	$SubscriptionId = $SubscriptionId.trim()
	Select-AzSubscription -SubscriptionId $SubscriptionId -ErrorVariable -notPresent  -ErrorAction SilentlyContinue -Tenant $AzureContext.Tenant
}

# get start time
$StartTime = Get-Date

$SAPSID = $SAPSID.Trim()

#Test if Tag 'SAPSystemSID' with value $SAPSID exist. If not exit
Test-AzSAPSIDTagExist -SAPSID $SAPSID

# Get SAP Appplication VMs
$SAPSIDApplicationVMs  = Get-AzSAPApplicationInstances -SAPSID $SAPSID

# List SAP Application layer VM
Write-Output ""
Write-WithTime "SAP Application layer VMs:"
Show-AzSAPSIDVMApplicationInstances -SAPVMs $SAPSIDApplicationVMs

# Get DBMS VMs
$SAPSIDDBMSVMs  = Get-AzSAPDBMSInstances -SAPSID $SAPSID

# List SAP DBMS layer VM(s)
Write-Output ""
Write-WithTime "SAP DBMS layer VM(s):"
Show-AzSAPSIDVMDBMSInstances -SAPVMs $SAPSIDDBMSVMs


####################################
# Convert the disks to Premium_LRS
####################################
if($ConvertDisksToPremium){
    Convert-AzALLSAPSystemVMsCollectionManagedDisksToPremium -SAPSIDApplicationVMs $SAPSIDApplicationVMs -SAPSIDDBMSVMs $SAPSIDDBMSVMs
}

###################
# Start VMs
###################

Write-WithTime "Starting VM(s) ..."

# Start ABAP ASCS VMs
Write-Output ""
Start-AzVMTagAndCheckVMStatus -SAPVMs $SAPSIDApplicationVMs -SAPInstanceType "SAP_ASCS"

# Start Java SCS VMs
Write-Output ""
Start-AzVMTagAndCheckVMStatus -SAPVMs $SAPSIDApplicationVMs -SAPInstanceType "SAP_SCS"

# Start ABAP SAP_DVEBMGS VM
Write-Output ""
Start-AzVMTagAndCheckVMStatus -SAPVMs $SAPSIDApplicationVMs -SAPInstanceType "SAP_DVEBMGS"

# Start DBMS VMs
Write-Output ""
Start-AzVMTagAndCheckVMStatus -SAPVMs $SAPSIDDBMSVMs -SAPInstanceType "SAP_DBMS"

# Start ABAP Dialog Instances (Application Servers) VMs
Write-Output ""
Start-AzVMTagAndCheckVMStatus -SAPVMs $SAPSIDApplicationVMs -SAPInstanceType "SAP_D"

# Start Java Application Server Instances VMs
Write-Output ""
Start-AzVMTagAndCheckVMStatus -SAPVMs $SAPSIDApplicationVMs -SAPInstanceType "SAP_J"

###################
# Start DBMS
###################

# Get DBMS Type
$DatabaseType = $SAPSIDDBMSVMs.DBMSType

# get DBMS Status
Write-Output ""
Get-AzDBMSStatus -SAPSIDDBMSVMs $SAPSIDDBMSVMs -PrintExecutionCommand $PrintExecutionCommand

# Start DBMS
Write-Output ""
Start-AzDBMS -SAPSIDDBMSVMs $SAPSIDDBMSVMs -PrintExecutionCommand $PrintExecutionCommand

# get DBMS Status
Write-Output ""
Get-AzDBMSStatus -SAPSIDDBMSVMs $SAPSIDDBMSVMs -PrintExecutionCommand $PrintExecutionCommand

###################
# Start SAP
###################

# Get SAP System Status
Write-Output ""
Get-AzSAPSystemStatus -SAPSIDApplicationVMs $SAPSIDApplicationVMs -PrintExecutionCommand $PrintExecutionCommand 

# Start SAP system
Write-Output ""
Start-AzSAPSystem  -SAPSIDApplicationVMs $SAPSIDApplicationVMs -WaitForStartTimeInSeconds $WaitForStartTimeInSeconds -PrintExecutionCommand $PrintExecutionCommand 

# Get SAP System Status
Write-Output ""
Get-AzSAPSystemStatus -SAPSIDApplicationVMs $SAPSIDApplicationVMs -PrintExecutionCommand $PrintExecutionCommand 

# get end time
$EndTime = Get-Date
$ElapsedTime = $EndTime - $StartTime#

###################
# SUMMARY
###################

Write-Output ""
Write-Output "Job succesfully finished."
Write-Output ""

Write-Output "SUMMARY:"
If($ConvertDisksToPremium){
    Write-Output "  - All disks set to 'Premium_LRS' type."
}else{
    Write-Output "  - All disks types are NOT changed."
}
Write-Output "  - Virtual machine(s) are started."
Write-Output "  - DBMS started."    
Write-Output "  - SAP system '$SAPSID' started."
Write-Output ""

Write-Output "[INFO] Total time : $($ElapsedTime.Days) days, $($ElapsedTime.Hours) hours,  $($ElapsedTime.Minutes) minutes, $($ElapsedTime.Seconds) seconds, $($ElapsedTime.Seconds) milliseconds."