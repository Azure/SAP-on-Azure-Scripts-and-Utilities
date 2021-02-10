
<#PSScriptInfo

.DESCRIPTION Azure Automation Runbook Script to stop an SAP system.

.VERSION 0.0.4

.GUID e67257ff-d964-4403-8e39-7a5d47f725b3

.AUTHOR Goran Condric

.COMPANYNAME Microsoft

.COPYRIGHT (c) 2020 Microsoft . All rights reserved.

.TAGS Azure Automation SAP System Stop Runbook

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
[int] $SoftShutdownTimeInSeconds = "300",

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

$SAPSID = $SAPSID.Trim()

# Connect to Azure
$connection = Get-AutomationConnection -Name AzureRunAsConnection
Add-AzAccount  -ServicePrincipal -Tenant $connection.TenantID -ApplicationId $connection.ApplicationID -CertificateThumbprint $connection.CertificateThumbprint 

# get start time
$StartTime = Get-Date

$SAPSID  = $SAPSID.Trim()

#Test if Tag 'SAPSystemSID' with value $SAPSID exist. If not exit
Test-AzSAPSIDTagExist -SAPSID $SAPSID

# Get SAP Appplication VMs
$SAPSIDApplicationVMs  = Get-AzSAPApplicationInstances -SAPSID $SAPSID

Write-Output ""

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

###################
# Stop SAP
###################

# Get SAP System Status
Write-Output ""
Get-AzSAPSystemStatus -SAPSIDApplicationVMs $SAPSIDApplicationVMs -PrintExecutionCommand $PrintExecutionCommand 

# Stop SAP system
Write-Output ""
Stop-AzSAPSystem  -SAPSIDApplicationVMs $SAPSIDApplicationVMs -SoftShutdownTimeInSeconds $SoftShutdownTimeInSeconds -PrintExecutionCommand $PrintExecutionCommand  

# Get SAP System Status
Write-Output ""
Get-AzSAPSystemStatus -SAPSIDApplicationVMs $SAPSIDApplicationVMs -PrintExecutionCommand $PrintExecutionCommand 

###################
# Stop DBMS
###################

# get DBMS Status
Write-Output ""
Get-AzDBMSStatus -SAPSIDDBMSVMs $SAPSIDDBMSVMs -PrintExecutionCommand $PrintExecutionCommand

# Stop DBMS
Write-Output ""
Stop-AzDBMS -SAPSIDDBMSVMs $SAPSIDDBMSVMs -PrintExecutionCommand $PrintExecutionCommand

# get DBMS Status
Write-Output ""
Get-AzDBMSStatus -SAPSIDDBMSVMs $SAPSIDDBMSVMs -PrintExecutionCommand $PrintExecutionCommand

###################
# Stop VMs
###################

Write-WithTime "Stopping VMs ...."

# Stop ABAP Application Servers (Dialog Instances) VMs
Write-Output ""
Stop-AzVMTagAndCheckVMStatus -SAPVMs $SAPSIDApplicationVMs -SAPInstanceType "SAP_D"

# Stop Java Application Servers VMs
Write-Output ""
Stop-AzVMTagAndCheckVMStatus -SAPVMs $SAPSIDApplicationVMs -SAPInstanceType "SAP_J"

# Stop ABAP ASCS Instance VMs
Write-Output ""
Stop-AzVMTagAndCheckVMStatus -SAPVMs $SAPSIDApplicationVMs -SAPInstanceType "SAP_ASCS"

# Stop ABAP DVEBMGS Instance VM
Stop-AzVMTagAndCheckVMStatus -SAPVMs $SAPSIDApplicationVMs -SAPInstanceType "SAP_DVEBMGS"

# Stop Java SCS Instance VMs
Write-Output ""
Stop-AzVMTagAndCheckVMStatus -SAPVMs $SAPSIDApplicationVMs -SAPInstanceType "SAP_SCS"

# Stop DBMS VMs
Write-Output ""
Stop-AzVMTagAndCheckVMStatus -SAPVMs $SAPSIDDBMSVMs -SAPInstanceType "SAP_DBMS"

####################################
# Convert the disks to Standard_LRS
####################################

if($ConvertDisksToStandard){
    Convert-AzALLSAPSystemVMsCollectionManagedDisksToStandard -SAPSIDApplicationVMs $SAPSIDApplicationVMs -SAPSIDDBMSVMs $SAPSIDDBMSVMs
}

# Get end time
$EndTime = Get-Date
$ElapsedTime = $EndTime - $StartTime

Write-Output ""
Write-Output "Job succesfully finished."
Write-Output ""

Write-Output "SUMMARY:"
If($ConvertDisksToStandard){
    Write-Output "  - All disks set to 'Standard_LRS' type."
}else{
    Write-Output "  - All disks types are NOT changed."
}
Write-Output "  - Virtual machine(s) stopped."
Write-Output "  - DBMS stopped."
Write-Output "  - SAP system '$SAPSID' stopped."
Write-Output ""


Write-Output "[INFO] Total time : $($ElapsedTime.Days) days, $($ElapsedTime.Hours) hours,  $($ElapsedTime.Minutes) minutes, $($ElapsedTime.Seconds) seconds, $($ElapsedTime.Seconds) milliseconds."