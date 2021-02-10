<#PSScriptInfo

.DESCRIPTION Azure Automation Runbook Script to start an SAP HANA DB.

.VERSION 0.0.2

.GUID 4b581649-fbce-441b-81a8-cc4cf393c5f7

.AUTHOR Goran Condric

.COMPANYNAME Microsoft

.COPYRIGHT (c) 2020 Microsoft . All rights reserved.

.TAGS Azure Automation SAP System Start HANA Runbook

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
    
[Parameter(Mandatory=$True, HelpMessage="SAP System <SID>. 3 characters , starts with letter.")] 
[ValidateLength(3,3)]
[string] $SAPHANASID,

[Parameter(Mandatory=$False)] 
[bool] $ConvertDisksToPremium =  $False,

[Parameter(Mandatory=$False)] 
[bool] $PrintExecutionCommand = $False

)

# Connect to Azure
$connection = Get-AutomationConnection -Name AzureRunAsConnection
Add-AzAccount  -ServicePrincipal -Tenant $connection.TenantID -ApplicationId $connection.ApplicationID -CertificateThumbprint $connection.CertificateThumbprint 

# get start time
$StartTime = Get-Date

$SAPHANASID  = $SAPHANASID.Trim()

#Test if Tag 'SAPHANASID' with value $SAPHANASID exist. If not exit
Test-AzSAPHANASIDTagExist -SAPHANASID $SAPHANASID

# Get DBMS VMs
$SAPSIDDBMSVMs  = Get-AzSAPHANAInstances -SAPHANASID $SAPHANASID

# List SAP DBMS layer VM(s)
Write-Output ""
Write-WithTime "SAP HANA DBMS VM(s):"
Show-AzSAPSIDVMDBMSInstances -SAPVMs $SAPSIDDBMSVMs

####################################
# Convert the disks to Premium_LRS
####################################
if($ConvertDisksToPremium){
    Convert-AzALLSAPVMsCollectionManagedDisksToPremium -SAPVMs $SAPSIDDBMSVMs
}

###################
# Start VMs
###################

Write-WithTime "Starting SAP HANA VM(s) ..."

# Start DBMS VMs
Write-Output ""
Start-AzVMTagAndCheckVMStatus -SAPVMs $SAPSIDDBMSVMs -SAPInstanceType "SAP_DBMS"


###################
# Start DBMS
###################

# get DBMS Status
Write-Output ""
Get-AzDBMSStatus -SAPSIDDBMSVMs $SAPSIDDBMSVMs -PrintExecutionCommand $PrintExecutionCommand

# Start DBMS
Write-Output ""
Start-AzDBMS -SAPSIDDBMSVMs $SAPSIDDBMSVMs -PrintExecutionCommand $PrintExecutionCommand

# get DBMS Status
Write-Output ""
Get-AzDBMSStatus -SAPSIDDBMSVMs $SAPSIDDBMSVMs -PrintExecutionCommand $PrintExecutionCommand


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
Write-Output "  - SAP HANA '$SAPHANASID' DBMS started."    
Write-Output ""

Write-Output "[INFO] Total time : $($ElapsedTime.Days) days, $($ElapsedTime.Hours) hours,  $($ElapsedTime.Minutes) minutes, $($ElapsedTime.Seconds) seconds, $($ElapsedTime.Seconds) milliseconds."