<#PSScriptInfo

.DESCRIPTION Azure Automation runbook script to list SAP system instances with an SAP SID.

.VERSION 0.0.3

.GUID 3550f34f-4dfa-4a06-9007-13f3edd28774

.AUTHOR Goran Condric

.COMPANYNAME Microsoft

.COPYRIGHT (c) 2020 Microsoft . All rights reserved.

.TAGS Azure Automation SAP list SAP system instances Runbook

.LICENSEURI

.PROJECTURI

.ICONURI

.EXTERNALMODULEDEPENDENCIES

.REQUIREDSCRIPTS

.EXTERNALSCRIPTDEPENDENCIES

.RELEASENOTES
0.0.1: - Add initial version

#>

#Requires -Module SAPAzurePowerShellModules

Param(
    
    [Parameter(Mandatory=$True, HelpMessage="SAP System <SID>. 3 characters , starts with letter.")] 
    [ValidateLength(3,3)]
    [string] $SAPSID,

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

$SAPSID = $SAPSID.Trim()

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