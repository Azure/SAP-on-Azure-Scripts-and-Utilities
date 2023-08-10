<#

.SYNOPSIS

    Check the image build status

.DESCRIPTION

    This script checks the image build status.
    
.EXAMPLE

    .\check-Image-Build-Status.ps1 -SubscriptionName "mysubscription" -region westeurope -ResourceGroupName test-rg -newAvailabilitySetName AvSet1 -newProximityPlacementGroupName PPG1

.LINK

    https://github.com/Azure/SAP-on-Azure-Scripts-and-Utilities

.NOTES

    v0.1 - Initial version

#>
<#
Copyright (c) Microsoft Corporation.
Licensed under the MIT license.
#>

#Requires -Modules Az.Compute
#Requires -Version 5.1
function Get-ImageBuildStatus {
    [OutputType([string])]

    param(

        #Name of Image Gallery
        [Parameter(Mandatory = $true)][string]$galleryName,
        #Name of Image Definition
        [Parameter(Mandatory = $true)][string]$imageDefNameToCheck
    )

    ### Update context
    $currentAzureContext = Get-AzContext

    ### Get instance profile
    $azureRmProfile = [Microsoft.Azure.Commands.Common.Authentication.Abstractions.AzureRmProfileProvider]::Instance.Profile
    $profileClient = New-Object Microsoft.Azure.Commands.ResourceManager.Common.RMProfileClient($azureRmProfile)
    
    Write-Verbose ("Tenant: {0}" -f $currentAzureContext.Subscription.Name)
 
    ### Get token  
    $token = $profileClient.AcquireAccessToken($currentAzureContext.Tenant.TenantId)
    $accessToken = $token.AccessToken

    $managementEp = $currentAzureContext.Environment.ResourceManagerUrl

    $urlBuildStatus = [System.String]::Format("{0}subscriptions/{1}/resourceGroups/$ResourceGroupName/providers/Microsoft.VirtualMachineImages/imageTemplates/{2}?api-version=2020-02-14", $managementEp, $currentAzureContext.Subscription.Id, $imageDefNameToCheck)

    $buildStatusResult = Invoke-WebRequest -Method GET  -Uri $urlBuildStatus -UseBasicParsing -Headers  @{"Authorization" = ("Bearer " + $accessToken) } -ContentType application/json 
    $buildJsonStatus = $buildStatusResult.Content

    $obj = ConvertFrom-JSON $buildJsonStatus
    Write-Host "Provisioning status: ("$obj.properties.lastRunStatus.runState") -" $obj.properties.lastRunStatus.runSubState

    if ($obj.properties.lastRunStatus.runState -eq "Failed") {
        Write-Error $obj.properties.lastRunStatus.message
        $URL = $obj.properties.lastRunStatus.message.Substring($obj.properties.lastRunStatus.message.IndexOf("build log location: ") + 20)
        $URL = $URL.SubString(0, $Url.IndexOf("OperationId") - 2)

        $OperationID = $obj.properties.lastRunStatus.message.SubString($obj.properties.lastRunStatus.message.IndexOf("OperationId") + 13) 
        $OperationID = $OperationID.SubString(0, $OperationID.IndexOf("."))

    }

    return $obj.properties.lastRunStatus.runState
}
