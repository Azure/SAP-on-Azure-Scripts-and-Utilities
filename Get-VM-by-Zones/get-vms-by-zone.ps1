<#

.SYNOPSIS
    Shows VM availability in zones for a certain region

.DESCRIPTION
    The script will show all VMs available in zones in a certain region, including the zone number associated to the subscription

.PARAMETER Region
    The Azure region name

.EXAMPLE
    ./Get-VMs-by-Zone.ps1 -Region westeurope

    Example output:

        VM Type       Zone 1 Zone 2 Zone 3
        -------       ------ ------ ------
        E16_v3        X      X      X
        E16-4s_v3     X      X      X
        E16-8s_v3     X      X      X
        E16s_v3       X      X      X
        E2_v3         X      X      X
        E20_v3        X      X      X
        E20s_v3       X      X      X
        E2s_v3        X      X      X
        E32_v3        X      X      X
        E32-16s_v3    X      X      X
        E32-8s_v3     X      X      X
        E32s_v3       X      X      X
        E4_v3         X      X      X
        E4-2s_v3      X      X      X
        E48_v3        X      X      X
        E48s_v3       X      X      X
        E4s_v3        X      X      X
        E64_v3        X      X      X
        E64-16s_v3    X      X      X
        E64-32s_v3    X      X      X
        E64i_v3       X      X      X
        E64is_v3      X      X      X
        E64s_v3       X      X      X
        E8_v3         X      X      X
        E8-2s_v3      X      X      X
        E8-4s_v3      X      X      X
        E8s_v3        X      X      X
        M128          X      X      X
        M128-32ms     X      X      X
        M128-64ms     X      X      X
        M128m         X      X      X
        M128ms        X      X      X
        M128s         X      X      X
        M16-4ms       X      X      X
        M16-8ms       X      X      X
        M16ms         X      X      X
        M208ms_v2     X             X
        M208s_v2      X             X
        M32-16ms      X      X      X
        M32-8ms       X      X      X
        M32ls         X      X      X
        M32ms         X      X      X
        M32ts         X      X      X
        M416ms_v2     X             X
        M416s_v2      X             X
        M64           X      X      X
        M64-16ms      X      X      X
        M64-32ms      X      X      X
        M64ls         X      X      X
        M64m          X      X      X
        M64ms         X      X      X
        M64s          X      X      X
        M8-2ms        X      X      X
        M8-4ms        X      X      X
        M8ms          X      X      X




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
    [string]$region = "westeurope", 
    #VM Types, use one or multiple series, e.g. "D,E,M"
    [string[]]$vmseries = "D,E,M"
)


# select subscription
$Subscription = Get-AzSubscription -SubscriptionName $SubscriptionName
if (-Not $Subscription) {
    Write-Host -ForegroundColor Red -BackgroundColor White "Sorry, it seems you are not connected to Azure or don't have access to the subscription. Please use Connect-AzAccount to connect."
    exit
}

Select-AzSubscription -Subscription $SubscriptionName -Force

$output = @()

$vms = Get-AzComputeResourceSku | where { $_.Locations.Contains($region) } | where { $_.ResourceType.Contains("virtualMachines") };

#    $vmseries = @("M","D")

foreach ($vm in $vms) {
    $vmtype = $vm.Name.replace("Standard_", $null)
    
    if ($vmseries -match $vmtype.substring(0, 1)) {
        $zone1 = ""
        $zone2 = ""
        $zone3 = ""
        $outputtemp = New-Object -TypeName PSObject

        foreach ($zone in $vm.locationinfo.zones) {

            switch ($zone) {
                1 { $zone1 = "X" }
                2 { $zone2 = "X" }
                3 { $zone3 = "X" }
            }

        }

        $outputtemp | Add-Member -MemberType NoteProperty -Name "VM Type" -Value $vmtype
        $outputtemp | Add-Member -MemberType NoteProperty -Name "Zone 1" -Value $zone1
        $outputtemp | Add-Member -MemberType NoteProperty -Name "Zone 2" -Value $zone2
        $outputtemp | Add-Member -MemberType NoteProperty -Name "Zone 3" -Value $zone3

        $output += $outputtemp

    }
}

$output | Sort-Object -property "VM Type" | Format-Table
