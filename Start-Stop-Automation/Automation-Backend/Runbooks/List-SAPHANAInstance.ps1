<#PSScriptInfo

.DESCRIPTION Azure Automation runbook script to list SAP HANA instance with an SAP HANA SID.

.VERSION 0.0.3

.GUID 0461bfa0-9b6e-4520-ad6e-a1e0ba0a96ec

.AUTHOR Goran Condric

.COMPANYNAME Microsoft

.COPYRIGHT (c) 2020 Microsoft . All rights reserved.

.TAGS Azure Automation SAP list SAP HANA system instance Runbook

.LICENSEURI

.PROJECTURI

.ICONURI

.EXTERNALMODULEDEPENDENCIES

.REQUIREDSCRIPTS

.EXTERNALSCRIPTDEPENDENCIES

.RELEASENOTES
0.0.1: - Add initial version
0.0.3: - Add dedpendencies to SAPAzurePowerShellModules module
#>

#Requires -Module SAPAzurePowerShellModules

Param(
    
[Parameter(Mandatory=$True, HelpMessage="SAP HANA <SID>. 3 characters , starts with letter.")] 
[ValidateLength(3,3)]
[string] $SAPHANASID

)

# Connect to Azure
$connection = Get-AutomationConnection -Name AzureRunAsConnection
Add-AzAccount  -ServicePrincipal -Tenant $connection.TenantID -ApplicationId $connection.ApplicationID -CertificateThumbprint $connection.CertificateThumbprint 

$SAPHANASID  = $SAPHANASID.Trim()

#Test if Tag 'SAPHANASID' with value $SAPHANASID exist. If not exit
Test-AzSAPHANASIDTagExist -SAPHANASID $SAPHANASID

# Get DBMS VMs
$SAPSIDDBMSVMs  = Get-AzSAPHANAInstances -SAPHANASID $SAPHANASID

# List SAP DBMS layer VM(s)
Write-Output ""
Write-WithTime "SAP HANA DBMS VM(s):"
Show-AzSAPSIDVMDBMSInstances -SAPVMs $SAPSIDDBMSVMs