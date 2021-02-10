<#PSScriptInfo

.DESCRIPTION Azure Automation runbook script to tag an standalone SAP HANA DB.

.VERSION 0.0.2

.GUID a1d371a7-7248-4af5-9735-4bbf1485e7e8

.AUTHOR Goran Condric

.COMPANYNAME Microsoft

.COPYRIGHT (c) 2020 Microsoft . All rights reserved.

.TAGS Azure Automation SAP HANA Tag Standalone System Runbook

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
$SAPHANASID             = $SAPHANASID.Trim()
$SAPHANAINstanceNumber  = $SAPHANAINstanceNumber.Trim()

# Check if resource group exists. If $False exit
Confirm-AzResoureceGroupExist -ResourceGroupName $ResourceGroupName 

# Check if VM. If $False exit
Confirm-AzVMExist -ResourceGroupName $ResourceGroupName -VMName $VMName

# Tag standalone SAP HANA on ONE VM
New-AzSAPStandaloneHANATags -ResourceGroupName $ResourceGroupName -VMName $VMName -SAPHANASID $SAPHANASID -SAPHANAINstanceNumber $SAPHANAINstanceNumber

Write-WithTime "Standalone SAP HANA use case."
Write-WithTime "Tagging of VM '$VMName' in resource group '$ResourceGroupName' with tags: SAPHANASID='$SAPHANASID';  SAPHANAINstanceNumber='$SAPHANAINstanceNumber'; SAPDBMSType='HANA' done."
