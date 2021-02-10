<#PSScriptInfo

.DESCRIPTION Azure Automation runbook script to tag an standalone SAP Java SCS Instance Linux VM.

.VERSION 0.0.1

.GUID 1300dae6-2947-4cbe-9859-242b4e494c2f

.AUTHOR Goran Condric

.COMPANYNAME Microsoft

.COPYRIGHT (c) 2020 Microsoft . All rights reserved.

.TAGS Azure Automation SAP Java SCS Instance Tag Standalone Runbook

.LICENSEURI

.PROJECTURI

.ICONURI

.EXTERNALMODULEDEPENDENCIES SAPAzurePowerShellModules

.REQUIREDSCRIPTS

.EXTERNALSCRIPTDEPENDENCIES

.RELEASENOTES
0.0.1: - Add initial version
#>

#Requires -Module SAPAzurePowerShellModules

Param(
    
[Parameter(Mandatory=$True)]
[ValidateNotNullOrEmpty()] 
[string] $ResourceGroupName,

[Parameter(Mandatory=$True)]
[ValidateNotNullOrEmpty()] 
[string] $VMName,

[Parameter(Mandatory=$True, HelpMessage="SAP System <SID>. 3 characters , starts with letter.")] 
[ValidateLength(3,3)]
[string] $SAPSID,

[Parameter(Mandatory=$True, HelpMessage="SAP Java SCS Instance Number")] 
[ValidateLength(1, 2)]
[string] $SAPSCSInstanceNumber

)

# Connect to Azure
$connection = Get-AutomationConnection -Name AzureRunAsConnection
Add-AzAccount  -ServicePrincipal -Tenant $connection.TenantID -ApplicationId $connection.ApplicationID -CertificateThumbprint $connection.CertificateThumbprint 

$ResourceGroupName      = $ResourceGroupName.Trim()
$VMName                 = $VMName.Trim()
$SAPSID                 = $SAPSID.Trim()
$SAPSCSInstanceNumber  = $SAPSCSInstanceNumber.Trim()

# Check if resource group exists. If $False exit
Confirm-AzResoureceGroupExist -ResourceGroupName $ResourceGroupName 

# Check if VM. If $False exit
Confirm-AzVMExist -ResourceGroupName $ResourceGroupName -VMName $VMName

# Tag SCS VM
New-AzSAPSystemSCSLinuxTags -ResourceGroupName $ResourceGroupName -VMName $VMName -SAPSID $SAPSID -SAPApplicationInstanceNumber $SAPSCSInstanceNumber

Write-WithTime "Tagging of VM '$VMName' in resource group '$ResourceGroupName' with tags: SAPSID='$SAPSID' ; SAPApplicationInstanceNumber='$SAPSCSInstanceNumber' ; SAPApplicationInstanceType='SAP_SCS' done."

