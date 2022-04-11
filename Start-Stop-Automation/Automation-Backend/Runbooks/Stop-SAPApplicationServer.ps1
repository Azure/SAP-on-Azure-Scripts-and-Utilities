<#PSScriptInfo

.DESCRIPTION Azure Automation runbook script to stop an SAP Application Server.

.VERSION 0.0.2

.GUID 4f6a5d1a-6693-48dd-9b72-496c36500e7d

.AUTHOR Goran Condric

.COMPANYNAME Microsoft

.COPYRIGHT (c) 2020 Microsoft . All rights reserved.

.TAGS Azure Automation SAP Application Server stop Runbook

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
    [Parameter(Mandatory = $True)]
    [ValidateNotNullOrEmpty()]        
    [string] $ResourceGroupName,
           
    [Parameter(Mandatory = $True)]
    [ValidateNotNullOrEmpty()]        
    [string] $VMName,

    [Parameter(Mandatory = $False)] 
    [int] $SAPSoftShutdownTimeInSeconds = "300",

    [Parameter(Mandatory=$False)] 
    [bool] $ConvertDisksToStandard =  $False,
    
    [Parameter(Mandatory=$False)] 
    [bool] $PrintExecutionCommand = $False,

    [Parameter(Mandatory=$false, HelpMessage="Subscription ID. If null, the current subscription of automation account is used instead.")] 
    [ValidateLength(36,36)]
    [string] $SubscriptionId
)

$ResourceGroupName  = $ResourceGroupName.Trim()
$VMName             = $VMName.Trim()

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

# get start time
$StartTime = Get-Date

$SAPApplicationServerData = Get-AzSAPApplicationInstanceData -ResourceGroupName $ResourceGroupName -VMName $VMName  

# Stop SAP Application Server
Stop-AzSAPApplicationServer -ResourceGroupName $ResourceGroupName -VMName $VMName -SoftShutdownTimeInSeconds $SAPSoftShutdownTimeInSeconds -PrintExecutionCommand $PrintExecutionCommand 

# Stop VM
Stop-AzVMAndPrintStatus -ResourceGroupName $ResourceGroupName -VMName $VMName

####################################
# Convert the disks to Standard_LRS
####################################
if($ConvertDisksToStandard){
    ConvertTo-AzVMManagedDisksToStandard -ResourceGroupName $ResourceGroupName -VMName $VMName
}

# Get end time
$EndTime = Get-Date
$ElapsedTime = $EndTime - $StartTime

Write-Output ""
Write-Output "Job succesfully finished."
Write-Output ""

Write-Output "SUMMARY:"
Write-Output "  - SAP Application Server with SAP SID '$($SAPApplicationServerData.SAPSID)' and instance number '$($SAPApplicationServerData.SAPApplicationInstanceNumber)' on VM '$VMName' and Azure resource group '$ResourceGroupName' stopped."
Write-Output "  - Virtual machine(s) stopped."
If($ConvertDisksToStandard){
    Write-Output "  - All disks set to 'Standard_LRS' type."
}else{
    Write-Output "  - All disks types are NOT changed."
}
Write-Output ""

Write-Output "[INFO] Total time : $($ElapsedTime.Days) days, $($ElapsedTime.Hours) hours,  $($ElapsedTime.Minutes) minutes, $($ElapsedTime.Seconds) seconds, $($ElapsedTime.Seconds) milliseconds."