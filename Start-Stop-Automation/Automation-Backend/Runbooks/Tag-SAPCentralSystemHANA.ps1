<#PSScriptInfo

.DESCRIPTION Azure Automation runbook script to tag an SAP central system with HANA DB.

.VERSION 0.0.2

.GUID c8510bd5-6930-4907-b19e-19c3749e3b2a

.AUTHOR Goran Condric

.COMPANYNAME Microsoft

.COPYRIGHT (c) 2020 Microsoft . All rights reserved.

.TAGS Azure Automation SAP HANA Tag Central System Runbook

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
    
[Parameter(Mandatory=$True)]
[ValidateNotNullOrEmpty()] 
[string] $ResourceGroupName,

[Parameter(Mandatory=$True)]
[ValidateNotNullOrEmpty()] 
[string] $VMName,

[Parameter(Mandatory=$True, HelpMessage="SAP System <SID>. 3 characters , starts with letter.")] 
[ValidateLength(3,3)]
[string] $SAPSID,

[Parameter(Mandatory=$True, HelpMessage="SAP Instance Number - any instance")] 
[ValidateLength(1, 2)]
[string] $SAPApplicationInstanceNumber,

[Parameter(Mandatory=$True, HelpMessage="SAP HANA <SID>. 3 characters , starts with letter.")] 
[ValidateLength(3,3)]
[string] $SAPHANASID,

[Parameter(Mandatory=$True, HelpMessage="HANA Instance Number")] 
[ValidateLength(1, 2)]
[string] $SAPHANAINstanceNumber

)

# Connect to Azure
$connection = Get-AutomationConnection -Name AzureRunAsConnection
Add-AzAccount  -ServicePrincipal -Tenant $connection.TenantID -ApplicationId $connection.ApplicationID -CertificateThumbprint $connection.CertificateThumbprint 

$ResourceGroupName      = $ResourceGroupName.Trim()
$VMName                 = $VMName.Trim()
$SAPSID                 = $SAPSID.Trim()
$SAPHANASID             = $SAPHANASID.Trim()
$SAPHANAINstanceNumber  = $SAPHANAINstanceNumber.Trim()

# Check if resource group exists. If $False exit
Confirm-AzResoureceGroupExist -ResourceGroupName $ResourceGroupName 

# Check if VM. If $False exit
Confirm-AzVMExist -ResourceGroupName $ResourceGroupName -VMName $VMName

# Tag SAP Central system with HANA on ONE VM
New-AzSAPSystemHANAAndASCSTags -ResourceGroupName $ResourceGroupName -VMName $VMName -SAPSID $SAPSID -SAPApplicationInstanceNumber $SAPApplicationInstanceNumber -SAPHANASID $SAPHANASID -SAPHANAINstanceNumber $SAPHANAINstanceNumber

Write-WithTime "Tagging of VM '$VMName' in resource group '$ResourceGroupName' with tags: SAPSID='$SAPSID' ; SAPApplicationInstanceNumber='$SAPApplicationInstanceNumber'; SAPApplicationInstanceType='SAP_ASCS' ; SAPHANASID='$SAPHANASID';  SAPHANAINstanceNumber='$SAPHANAINstanceNumber'; SAPDBMSType='HANA' done."

