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
    [string] $SAPHANASID,

    [Parameter(Mandatory=$false, HelpMessage="Subscription ID. If null, the current subscription of automation account is used instead.")] 
    [ValidateLength(36,36)]
    [string] $SubscriptionId
)

# Deprecated due to using System Managed Identity
#$connection = Get-AutomationConnection -Name AzureRunAsConnection
#Add-AzAccount  -ServicePrincipal -Tenant $connection.TenantID -ApplicationId $connection.ApplicationID -CertificateThumbprint $connection.CertificateThumbprint 

# Connect to Azure with Automation Account system-assigned managed identity
# Ensure that you do not inherit an AZ Context in your runbook
Disable-AzContextAutosave -Scope Process | out-null

# Connect using Managed Service Identity
try {
	$AzureContext = (Connect-AzAccount -Identity -WarningAction Ignore).context
}
catch{
	Write-Output "There is no system-assigned user identity. Aborting."; 
	Write-Error  $_.Exception.Message
	exit
}

if ($SubscriptionId){
	$SubscriptionId = $SubscriptionId.trim()
	Select-AzSubscription -SubscriptionId $SubscriptionId -ErrorVariable -notPresent  -ErrorAction SilentlyContinue -Tenant $AzureContext.Tenant
}

$SAPHANASID  = $SAPHANASID.Trim()

#Test if Tag 'SAPHANASID' with value $SAPHANASID exist. If not exit
Test-AzSAPHANASIDTagExist -SAPHANASID $SAPHANASID

# Get DBMS VMs
$SAPSIDDBMSVMs  = Get-AzSAPHANAInstances -SAPHANASID $SAPHANASID

# List SAP DBMS layer VM(s)
Write-Output ""
Write-WithTime "SAP HANA DBMS VM(s):"
Show-AzSAPSIDVMDBMSInstances -SAPVMs $SAPSIDDBMSVMs