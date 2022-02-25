<#

.SYNOPSIS
    Map logical zones of different subscriptions

.DESCRIPTION
    The script will map the logical zones of multiple subscriptions with each other.

.LINK
    https://github.com/Azure/SAP-on-Azure-Scripts-and-Utilities

#>
<#
Copyright (c) Microsoft Corporation.
Licensed under the MIT license.
#>

#requires -version 7.1
#requires -modules Az

[CmdletBinding()]
param (
    [parameter(Mandatory=$true)][string]$subscriptionId,
    [parameter(Mandatory=$true)][string[]]$subscriptionPeers,
    [parameter(Mandatory=$true)][string]$region
)

# create JSON object for web request with subscriptions
$subscriptionPeersParameter = "" | Select-Object location,subscriptionIds
$subscriptionPeersParameter.location = $region
$subscriptionPeersParameter.subscriptionIds = @()

foreach ($subscription in $subscriptionPeers) {
    $subscriptionPeersParameter.subscriptionIds += "subscriptions/" + $subscription
}

$subscriptionPeersJson = $subscriptionPeersParameter | ConvertTo-Json


# Get Azure Context

try {
    $azContext = Get-AzContext
}
catch {
    Write-Host "An error occurred:"
    Write-Host "Please check if you are logged on to Azure, you can use Connect-AzAccount to log in"
}

# get access token for REST call
$azProfile = [Microsoft.Azure.Commands.Common.Authentication.Abstractions.AzureRmProfileProvider]::Instance.Profile
$profileClient = New-Object -TypeName Microsoft.Azure.Commands.ResourceManager.Common.RMProfileClient -ArgumentList ($azProfile)
$token = $profileClient.AcquireAccessToken($azContext.Subscription.TenantId)
$authHeader = @{
    'Content-Type'='application/json'
    'Authorization'='Bearer ' + $token.AccessToken
}

$feature = Get-AzProviderFeature -ProviderNamespace Microsoft.Resources -FeatureName AvailabilityZonePeering

if ($feature.RegistrationState -eq "Registered") {
    # feature registered
    # continuing
}
else {
    Write-Host "Feature not registered"
    Write-Host "Please register feature using:"
    Write-Host "Register-AzProviderFeature -FeatureName AvailabilityZonePeering -ProviderNamespace Microsoft.Resources"
    exit
}


# create parameter
$param = @{
    Uri = "https://management.azure.com/subscriptions/${subscriptionId}/providers/Microsoft.Resources/checkZonePeers/?api-version=2020-01-01";
    Method = 'Post';
    Body = $subscriptionPeersJson;
    Headers = $authHeader
}


# Invoke the REST API
$response = Invoke-RestMethod @param

# Output
Write-Host ""
Write-Host "SubscriptionId:" $response.subscriptionId
Write-Host ""
foreach ($i in $response.availabilityZonePeers.availabilityZone) {
    foreach ($zone in $response.availabilityZonePeers[$i-1].peers ) {
        Write-Host "Zone $i matches zone" $zone.availabilityZone "in" $zone.subscriptionId
    }
    Write-Host ""
}

