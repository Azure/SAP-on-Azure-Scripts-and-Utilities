<#PSScriptInfo

.DESCRIPTION Azure Automation runbook script to tag an standalone SAP Dialog Instance on Linux VM.

.VERSION 0.0.2

.GUID e9b1eb93-2fe1-4b37-bb2b-319cec9e801c

.AUTHOR Goran Condric

.COMPANYNAME Microsoft

.COPYRIGHT (c) 2020 Microsoft . All rights reserved.

.TAGS Azure Automation SAP Dialog Instance Linux Tag Standalone Runbook

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

[Parameter(Mandatory=$True, HelpMessage="SAP ASCS Instance Number")]
[ValidateLength(1, 2)]
[string] $SAPDialogInstanceNumber

)

# Connect to Azure
$connection = Get-AutomationConnection -Name AzureRunAsConnection
Add-AzAccount  -ServicePrincipal -Tenant $connection.TenantID -ApplicationId $connection.ApplicationID -CertificateThumbprint $connection.CertificateThumbprint 

$ResourceGroupName          = $ResourceGroupName.Trim()
$VMName                     = $VMName.Trim()
$SAPSID                     = $SAPSID.Trim()
$SAPDialogInstanceNumber    = $SAPDialogInstanceNumber.Trim()

# Check if resource group exists. If $False exit
Confirm-AzResoureceGroupExist -ResourceGroupName $ResourceGroupName 

# Check if VM. If $False exit
Confirm-AzVMExist -ResourceGroupName $ResourceGroupName -VMName $VMName

# Tag ASCS VM
New-AzSAPSystemSAPDialogInstanceApplicationServerLinuxTags -ResourceGroupName $ResourceGroupName -VMName $VMName -SAPSID $SAPSID -SAPApplicationInstanceNumber $SAPDialogInstanceNumber

Write-WithTime "Tagging of VM '$VMName' in resource group '$ResourceGroupName' with tags: SAPSID='$SAPSID' ; SAPApplicationInstanceNumber='$SAPDialogInstanceNumber' ; SAPApplicationInstanceType='SAP_D' done."

