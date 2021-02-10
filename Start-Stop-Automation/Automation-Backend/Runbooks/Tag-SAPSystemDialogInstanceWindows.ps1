<#PSScriptInfo

.DESCRIPTION Azure Automation runbook script to tag an standalone SAP Dialog Instance on Windows VM.

.VERSION 0.0.2

.GUID 7f9ea05a-93dd-4f2b-9ef0-08d1fedbaff5

.AUTHOR Goran Condric

.COMPANYNAME Microsoft

.COPYRIGHT (c) 2020 Microsoft . All rights reserved.

.TAGS Azure Automation SAP Dialog Instance Windows Tag Standalone Runbook

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
[string] $SAPDialogInstanceNumber,

[Parameter(Mandatory=$True)]
[ValidateNotNullOrEmpty()] 
[string] $PathToSAPControl,

[Parameter(Mandatory=$True)]
[ValidateNotNullOrEmpty()] 
[string] $SAPsidadmUserPassword,

[Parameter(Mandatory=$True)]
[ValidateNotNullOrEmpty()] 
[string] $AutomationAccountResourceGroupName,

[Parameter(Mandatory=$True)]
[ValidateNotNullOrEmpty()] 
[string] $AutomationAccountName

)

# Connect to Azure
$connection = Get-AutomationConnection -Name AzureRunAsConnection
Add-AzAccount  -ServicePrincipal -Tenant $connection.TenantID -ApplicationId $connection.ApplicationID -CertificateThumbprint $connection.CertificateThumbprint 

$ResourceGroupName                  = $ResourceGroupName.Trim()
$VMName                             = $VMName.Trim()
$SAPSID                             = $SAPSID.Trim()
$SAPDialogInstanceNumber            = $SAPDialogInstanceNumber.Trim()
$PathToSAPControl                   = $PathToSAPControl.Trim()
$SAPsidadmUserPassword              = $SAPsidadmUserPassword.Trim()
$AutomationAccountResourceGroupName = $AutomationAccountResourceGroupName.Trim()
$AutomationAccountName              = $AutomationAccountName.Trim()

# Check if resource group exists. If $False exit
Confirm-AzResoureceGroupExist -ResourceGroupName $ResourceGroupName 

# Check if VM. If $False exit
Confirm-AzVMExist -ResourceGroupName $ResourceGroupName -VMName $VMName

# Check if resource group exists. If $False exit
Confirm-AzResoureceGroupExist -ResourceGroupName $AutomationAccountResourceGroupName 

# Tag Windows ASCS VM
New-AzSAPSystemSAPDialogInstanceApplicationServerWindowsTags   -ResourceGroupName $ResourceGroupName -VMName $VMName -SAPSID $SAPSID -SAPApplicationInstanceNumber $SAPDialogInstanceNumber -SAPsidadmUserPassword $SAPsidadmUserPassword -PathToSAPControl  $PathToSAPControl -AutomationAccountResourceGroupName $AutomationAccountResourceGroupName -AutomationAccountName $AutomationAccountName

Write-WithTime "Tagging of VM '$VMName' in resource group '$ResourceGroupName' with tags: SAPSID='$SAPSID' ; SAPApplicationInstanceNumber='$SAPDialogInstanceNumber' ; SAPApplicationInstanceType='SAP_D' ; PathToSAPControl=$PathToSAPControl done."

