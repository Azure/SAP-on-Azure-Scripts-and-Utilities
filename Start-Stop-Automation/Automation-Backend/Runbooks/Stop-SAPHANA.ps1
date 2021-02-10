<#PSScriptInfo

.DESCRIPTION Azure Automation Runbook Script to stop an SAP HANA DB.

.VERSION 0.0.3

.GUID 7e64d4d0-abb6-42d5-af93-9eeb3a1e026e

.AUTHOR Goran Condric

.COMPANYNAME Microsoft

.COPYRIGHT (c) 2020 Microsoft . All rights reserved.

.TAGS Azure Automation SAP System Stop HANA Runbook

.LICENSEURI

.PROJECTURI

.ICONURI

.EXTERNALMODULEDEPENDENCIES SAPAzurePowerShellModules

.REQUIREDSCRIPTS

.EXTERNALSCRIPTDEPENDENCIES

.RELEASENOTES
0.0.1: - Add initial version
0.0.3: - Add dedpendencies to SAPAzurePowerShellModules module
#>

#Requires -Module SAPAzurePowerShellModules

Param(
    
[Parameter(Mandatory=$True, HelpMessage="SAP System <SID>. 3 characters , starts with letter.")] 
[ValidateLength(3,3)]
[string] $SAPHANASID,

[Parameter(Mandatory=$False)] 
[bool] $ConvertDisksToStandard =  $False,

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

###################
# Stop DBMS
###################

# get DBMS Status
Write-Output ""
Get-AzDBMSStatus -SAPSIDDBMSVMs $SAPSIDDBMSVMs -PrintExecutionCommand $PrintExecutionCommand

# Start DBMS
Write-Output ""
Stop-AzDBMS -SAPSIDDBMSVMs $SAPSIDDBMSVMs -PrintExecutionCommand $PrintExecutionCommand

# get DBMS Status
Write-Output ""
Get-AzDBMSStatus -SAPSIDDBMSVMs $SAPSIDDBMSVMs -PrintExecutionCommand $PrintExecutionCommand

###################
# Stop VMs
###################

Write-WithTime "Stopping SAP HANA VM(s) ..."
Write-Output ""
Stop-AzVMTagAndCheckVMStatus -SAPVMs $SAPSIDDBMSVMs -SAPInstanceType "SAP_DBMS"

####################################
# Convert the disks to Standard_LRS
####################################
if($ConvertDisksToStandard){
    Convert-AzALLSAPVMsCollectionManagedDisksToStandard -SAPVMs $SAPSIDDBMSVMs
}

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

Write-Output "  - SAP HANA '$SAPHANASID' DBMS stopped."    
Write-Output "  - Virtual machine(s) are stopped."
If($ConvertDisksToStandard){
    Write-Output "  - All disks set to 'Standard_LRS' type."
}else{
    Write-Output "  - All disks types are NOT changed."
}
Write-Output ""

Write-Output "[INFO] Total time : $($ElapsedTime.Days) days, $($ElapsedTime.Hours) hours,  $($ElapsedTime.Minutes) minutes, $($ElapsedTime.Seconds) seconds, $($ElapsedTime.Seconds) milliseconds."