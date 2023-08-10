
<#PSScriptInfo

.DESCRIPTION Azure Automation Runbook Script to stop an SAP system.

.VERSION 0.0.4

.GUID e67257ff-d964-4403-8e39-7a5d47f725b3

.AUTHOR Goran Condric

.COMPANYNAME Microsoft

.COPYRIGHT (c) 2020 Microsoft . All rights reserved.

.TAGS Azure Automation SAP System Stop Runbook

.LICENSEURI

.PROJECTURI

.ICONURI

.EXTERNALMODULEDEPENDENCIES SAPAzurePowerShellModules

.REQUIREDSCRIPTS

.EXTERNALSCRIPTDEPENDENCIES

.RELEASENOTES
0.0.1: - Add initial version
0.0.3: - Add dedpendencies to SAPAzurePowerShellModules module
0.0.4: - Add functionality for Java systems
#>

#Requires -Module SAPAzurePowerShellModules

Param(
    
    [Parameter(Mandatory=$True, HelpMessage="SAP System <SID>. 3 characters , starts with letter.")] 
    [ValidateLength(3,3)]
    [string] $SAPSID,

    [Parameter(Mandatory=$False)] 
    [int] $SoftShutdownTimeInSeconds = "300",

    [Parameter(Mandatory=$False)] 
    [bool] $ConvertDisksToStandard =  $False,

    [Parameter(Mandatory=$False)] 
    [bool] $PrintExecutionCommand = $False,

    [Parameter(Mandatory=$false, HelpMessage="Subscription ID. If null, the current subscription of automation account is used instead.")] 
    [ValidateLength(36,36)]
    [string] $SubscriptionId,
    
    [Parameter(Mandatory=$False, HelpMessage="Identifier of user calling the runbook")] 
    [string] $User = "",
    
    [Parameter(Mandatory=$False, HelpMessage="URL of hook, e.g. logicApp with SAS token")] 
    [string] $PostProcessingHook = ""
)
try {
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

	$SAPSID = $SAPSID.Trim()

	# Connect to Azure
	$connection = Get-AutomationConnection -Name AzureRunAsConnection
	Add-AzAccount  -ServicePrincipal -Tenant $connection.TenantID -ApplicationId $connection.ApplicationID -CertificateThumbprint $connection.CertificateThumbprint 

	# get start time
	$StartTime = Get-Date

	$SAPSID  = $SAPSID.Trim()

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

	###################
	# Stop SAP
	###################

	# Get SAP System Status
	Write-Output ""
	Get-AzSAPSystemStatus -SAPSIDApplicationVMs $SAPSIDApplicationVMs -PrintExecutionCommand $PrintExecutionCommand 

	# Stop SAP system
	Write-Output ""
	Stop-AzSAPSystem  -SAPSIDApplicationVMs $SAPSIDApplicationVMs -SoftShutdownTimeInSeconds $SoftShutdownTimeInSeconds -PrintExecutionCommand $PrintExecutionCommand  

	# Get SAP System Status
	Write-Output ""
	Get-AzSAPSystemStatus -SAPSIDApplicationVMs $SAPSIDApplicationVMs -PrintExecutionCommand $PrintExecutionCommand 

	###################
	# Stop DBMS
	###################

	# get DBMS Status
	Write-Output ""
	Get-AzDBMSStatus -SAPSIDDBMSVMs $SAPSIDDBMSVMs -PrintExecutionCommand $PrintExecutionCommand

	# Stop DBMS
	Write-Output ""
	Stop-AzDBMS -SAPSIDDBMSVMs $SAPSIDDBMSVMs -PrintExecutionCommand $PrintExecutionCommand

	# get DBMS Status
	Write-Output ""
	Get-AzDBMSStatus -SAPSIDDBMSVMs $SAPSIDDBMSVMs -PrintExecutionCommand $PrintExecutionCommand

	###################
	# Stop VMs
	###################

	Write-WithTime "Stopping VMs ...."

	# Stop ABAP Application Servers (Dialog Instances) VMs
	Write-Output ""
	Stop-AzVMTagAndCheckVMStatus -SAPVMs $SAPSIDApplicationVMs -SAPInstanceType "SAP_D"

	# Stop Java Application Servers VMs
	Write-Output ""
	Stop-AzVMTagAndCheckVMStatus -SAPVMs $SAPSIDApplicationVMs -SAPInstanceType "SAP_J"

	# Stop ABAP ASCS Instance VMs
	Write-Output ""
	Stop-AzVMTagAndCheckVMStatus -SAPVMs $SAPSIDApplicationVMs -SAPInstanceType "SAP_ASCS"

	# Stop ABAP DVEBMGS Instance VM
	Stop-AzVMTagAndCheckVMStatus -SAPVMs $SAPSIDApplicationVMs -SAPInstanceType "SAP_DVEBMGS"

	# Stop Java SCS Instance VMs
	Write-Output ""
	Stop-AzVMTagAndCheckVMStatus -SAPVMs $SAPSIDApplicationVMs -SAPInstanceType "SAP_SCS"

	# Stop DBMS VMs
	Write-Output ""
	Stop-AzVMTagAndCheckVMStatus -SAPVMs $SAPSIDDBMSVMs -SAPInstanceType "SAP_DBMS"

	####################################
	# Convert the disks to Standard_LRS
	####################################

	if($ConvertDisksToStandard){
	    Convert-AzALLSAPSystemVMsCollectionManagedDisksToStandard -SAPSIDApplicationVMs $SAPSIDApplicationVMs -SAPSIDDBMSVMs $SAPSIDDBMSVMs
	}

	# Get end time
	$EndTime = Get-Date
	$ElapsedTime = $EndTime - $StartTime

	Write-Output ""
	Write-Output "Job succesfully finished."
	Write-Output ""

	Write-Output "SUMMARY:"
	If($ConvertDisksToStandard){
	    Write-Output "  - All disks set to 'Standard_LRS' type."
	}else{
	    Write-Output "  - All disks types are NOT changed."
	}
	Write-Output "  - Virtual machine(s) stopped."
	Write-Output "  - DBMS stopped."
	Write-Output "  - SAP system '$SAPSID' stopped."
	Write-Output ""


	Write-Output "[INFO] Total time : $($ElapsedTime.Days) days, $($ElapsedTime.Hours) hours,  $($ElapsedTime.Minutes) minutes, $($ElapsedTime.Seconds) seconds, $($ElapsedTime.Seconds) milliseconds."
	
	###################
    	# POST-PROCESSING
    	###################
    
    	If($PostProcessingHook){
       	     $body = @{
		    sid = $SAPSID
		    totalRuntime = "$($ElapsedTime.Hours)h$($ElapsedTime.Minutes)m$($ElapsedTime.Seconds)s"
		    status = "successfully"
		    user = $User
		    msg = "stopped"
	    }
	    Invoke-RestMethod -Method 'Post' -Uri $PostProcessingHook -Body ($body|ConvertTo-Json) -ContentType "application/json"
    	}
	Else{
	    Write-Output "No webhook defined."
    	}
}
catch {
    If($PostProcessingHook){
        $body = @{
                sid = $SAPSID
                totalRuntime = "$($ElapsedTime.Hours)h$($ElapsedTime.Minutes)m$($ElapsedTime.Seconds)s"
                status = "Stop SAP failed"
                user = $User
                msg = $_.ErrorDetails
            }
        Invoke-RestMethod -Method 'Post' -Uri $PostProcessingHook -Body ($body|ConvertTo-Json) -ContentType "application/json"
    }Else{
        Write-Output "No webhook defined."
    }
}
