<#PSScriptInfo

.DESCRIPTION Azure Automation runbook script to tag an standalone SAP Java Application Server Instance on Windows VM.

.VERSION 0.0.1

.GUID 781a4d78-a4fc-4030-aae7-01720c4356a0

.AUTHOR Goran Condric

.COMPANYNAME Microsoft

.COPYRIGHT (c) 2020 Microsoft . All rights reserved.

.TAGS Azure Automation SAP Java Application Server Instance Windows Tag Standalone Runbook

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

[Parameter(Mandatory=$True, HelpMessage="SAP Java Application Server Instance Number")]
[ValidateLength(1, 2)]
[string] $SAPJavaApplicationServerInstanceNumber,

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

$ResourceGroupName                                  = $ResourceGroupName.Trim()
$VMName                                             = $VMName.Trim()
$SAPSID                                             = $SAPSID.Trim()
$SAPJavaApplicationServerInstanceNumber             = $SAPJavaApplicationServerInstanceNumber.Trim()
$PathToSAPControl                                   = $PathToSAPControl.Trim()
$SAPsidadmUserPassword                              = $SAPsidadmUserPassword.Trim()
$AutomationAccountResourceGroupName                 = $AutomationAccountResourceGroupName.Trim()
$AutomationAccountName                              = $AutomationAccountName.Trim()

# Check if resource group exists. If $False exit
Confirm-AzResoureceGroupExist -ResourceGroupName $ResourceGroupName 

# Check if VM. If $False exit
Confirm-AzVMExist -ResourceGroupName $ResourceGroupName -VMName $VMName

# Check if resource group exists. If $False exit
Confirm-AzResoureceGroupExist -ResourceGroupName $AutomationAccountResourceGroupName 

# Tag Windows ASCS VM
New-AzSAPSystemSAPJavaApplicationServerInstanceWindowsTags  -ResourceGroupName $ResourceGroupName -VMName $VMName -SAPSID $SAPSID -SAPApplicationInstanceNumber $SAPJavaApplicationServerInstanceNumber -SAPsidadmUserPassword $SAPsidadmUserPassword -PathToSAPControl  $PathToSAPControl -AutomationAccountResourceGroupName $AutomationAccountResourceGroupName -AutomationAccountName $AutomationAccountName

Write-WithTime "Tagging of VM '$VMName' in resource group '$ResourceGroupName' with tags: SAPSID='$SAPSID' ; SAPApplicationInstanceNumber='$SAPJavaApplicationServerInstanceNumber' ; SAPApplicationInstanceType='SAP_J' ; PathToSAPControl=$PathToSAPControl done."

