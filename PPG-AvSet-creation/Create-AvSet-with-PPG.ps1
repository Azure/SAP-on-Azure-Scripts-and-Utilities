<#

.SYNOPSIS

    Create an Availability Set which is associated with a Proximity Placement Group

.DESCRIPTION

    This script creates both a Proximity Placement Group and an Availability Set if they do not
    already exist. During the creation of the Availability Set it will be associated with the 
    Proximity Placement Group.
    
.EXAMPLE

    .\Create-AvSet-with-PPG.ps1 -SubscriptionName "mysubscription" -region westeurope -ResourceGroupName test-rg -newAvailabilitySetName AvSet1 -newProximityPlacementGroupName PPG1

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

param(

    #Azure Subscription Name
    [Parameter(Mandatory = $true)][string]$SubscriptionName,
    #Azure Region, use Get-AzLocation to get region names
    [Parameter(Mandatory = $true)][string]$region,
    #Resource Group Name that will be created
    [Parameter(Mandatory = $true)][string]$ResourceGroupName, 
    #Name of new Availability Set
    [Parameter(Mandatory = $true)][string]$newAvailabilitySetName, 
    #Name of new Proximity Placement Group
    [Parameter(Mandatory = $true)][string]$newProximityPlacementGroupName,
    #Number of Fault Domains
    [int]$AvailabilitySetFaultDomains = 3,
    #Number of Fault Domains
    [int]$AvailabilitySetUpdateDomains = 5

    
)

# select subscription

$Subscription = Get-AzSubscription -SubscriptionName $SubscriptionName

if (-Not $Subscription) {
    Write-Host -ForegroundColor Red -BackgroundColor White "Sorry, it seems you are not connected to Azure or don't have access to the subscription. Please use Connect-AzAccount to connect."
    exit

}

Select-AzSubscription -Subscription $SubscriptionName -Force

# Create PPG if it does not exist

Write-Host -ForegroundColor green "Checking if the Proximity Placement Group exists"
$ppg = Get-AzProximityPlacementGroup `
    -ResourceGroupName $ResourceGroupName `
    -Name $newProximityPlacementGroupName `
    -ErrorAction Ignore

if (-Not $ppg) {
    Write-Host -ForegroundColor green "Proximity Placement Group not found, now creating the Proximity Placement Group"
    $ppg = New-AzProximityPlacementGroup `
        -ResourceGroupName $ResourceGroupName `
        -Name $newProximityPlacementGroupName `
        -Location $region

}

# Create a new Availability Set if it does not exist

Write-Host -ForegroundColor green "Checking if the Availability Set exists"
$AvailSet = Get-AzAvailabilitySet `
    -ResourceGroupName $ResourceGroupName `
    -Name $newAvailabilitySetName `
    -ErrorAction Ignore
if (-Not $AvailSet) {
    Write-Host -ForegroundColor green "Availability Set not found, now creating and associating it with the Proximity Placement Group"
    $AvailSet = New-AzAvailabilitySet `
        -Location $region `
        -Name $newAvailabilitySetName `
        -ResourceGroupName $ResourceGroupName `
        -ProximityPlacementGroupId $ppg.Id `
        -PlatformFaultDomainCount $AvailabilitySetFaultDomains `
        -PlatformUpdateDomainCount $AvailabilitySetUpdateDomains `
        -Sku Aligned
}
# Display Availability Set with Proximity Placement Group Association

Write-Host -ForegroundColor green "Displaying the Availability Set with the Proximity Placement Group association"
Write-Host -ForegroundColor yellow $AvailSet.Name $AvailSet.ProximityPlacementGroup.Id

