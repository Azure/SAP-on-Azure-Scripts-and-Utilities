<#PSScriptInfo

.DESCRIPTION Azure Automation runbook script to tag an SAP central system with SQL Server DB.

.VERSION 0.0.2

.GUID 59e7987b-95b3-452c-aeea-b6605dc96657

.AUTHOR Goran Condric

.COMPANYNAME Microsoft

.COPYRIGHT (c) 2020 Microsoft . All rights reserved.

.TAGS Azure Automation SAP SQL Server Tag Central System Runbook

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

[Parameter(Mandatory=$True, HelpMessage="SAP ASCS Instance Number")]
[ValidateLength(1, 2)]
[string] $SAPASCSInstanceNumber,

[Parameter(Mandatory=$True)]
[ValidateNotNullOrEmpty()] 
[string] $PathToSAPControl,

[Parameter(Mandatory=$True)]
[ValidateNotNullOrEmpty()] 
[string] $SAPsidadmUserPassword,

[Parameter(Mandatory=$false, HelpMessage="SQL Server DB Instance Name. Empty string is deafult SQL instance name.")] 
[string] $DBInstanceName = "",

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
$SAPASCSInstanceNumber              = $SAPASCSInstanceNumber.Trim()
$PathToSAPControl                   = $PathToSAPControl.Trim()
$SAPsidadmUserPassword              = $SAPsidadmUserPassword.Trim()
$DBInstanceName                     = $DBInstanceName.Trim()
$AutomationAccountResourceGroupName = $AutomationAccountResourceGroupName.Trim()
$AutomationAccountName              = $AutomationAccountName.Trim()

# Check if resource group exists. If $False exit
Confirm-AzResoureceGroupExist -ResourceGroupName $ResourceGroupName 

# Check if VM. If $False exit
Confirm-AzVMExist -ResourceGroupName $ResourceGroupName -VMName $VMName

# Check if resource group exists. If $False exit
Confirm-AzResoureceGroupExist -ResourceGroupName $AutomationAccountResourceGroupName 

# Tag SAP Central System on Windows with SQL Server VM
New-AzSAPCentralSystemSQLServerTags -ResourceGroupName $ResourceGroupName -VMName $VMName -SAPSID $SAPSID -SAPApplicationInstanceNumber $SAPASCSInstanceNumber -SAPsidadmUserPassword $SAPsidadmUserPassword -PathToSAPControl  $PathToSAPControl -DBInstanceName $DBInstanceName -AutomationAccountResourceGroupName $AutomationAccountResourceGroupName -AutomationAccountName $AutomationAccountName

Write-WithTime "Tagging of VM '$VMName' in resource group '$ResourceGroupName' with tags: SAPSID='$SAPSID' ; SAPApplicationInstanceNumber='$SAPASCSInstanceNumber' ; SAPApplicationInstanceType='SAP_ASCS' ; PathToSAPControl=$PathToSAPControl ;  SAPDBMSType='SQLServer' ; DBInstanceName='$DBInstanceName' done."

