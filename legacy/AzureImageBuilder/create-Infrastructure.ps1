<#

.SYNOPSIS

    Create the Infrastructure required for Azure Image Builder

.DESCRIPTION

    This script creates the infrastructure required for Azure Image Builder
    
.EXAMPLE

    .\New-AIBInfrastructure.ps1 -SubscriptionName "mysubscription" -region westeurope -ResourceGroupName test-gallery-rg  -GalleryName ContosoGallery 

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
function New-AIBInfrastructure {
    [OutputType([Bool])]
    param(

        #Azure Subscription Name
        [Parameter(Mandatory = $true)][string]$SubscriptionName,
        #Azure Region, use Get-AzLocation to get region names
        [Parameter(Mandatory = $true)][string]$Region,
        #Resource Group Name 
        [Parameter(Mandatory = $true)][string]$ResourceGroupName, 
        #Name of Image Gallery
        [Parameter(Mandatory = $true)][string]$GalleryName,
        #Naming Prefix
        [Parameter(Mandatory = $true)][string]$Prefix
    )

    $Subscription = Get-AzSubscription -SubscriptionName $SubscriptionName
    if (-Not $Subscription) {
        Write-Host -ForegroundColor Red -BackgroundColor White "Sorry, it seems you are not connected to Azure or don't have access to the subscription. Please use Connect-AzAccount to connect."
        exit
    }
    
    $foo = Select-AzSubscription -Subscription $SubscriptionName 
    

    $vNetName = $Prefix+"_AIB-vnet"
    $idenityName = $Prefix+"_AIB-identity"

    $rg = Get-AzResourceGroup -Name $ResourceGroupName -Location $Region -ErrorVariable notPresent -ErrorAction SilentlyContinue
    if ($notPresent) {
        Write-Host "Creating the resource group :" $ResourceGroupName
        $rg = New-AzResourceGroup -Name $ResourceGroupName -Location $Region 
    }

    $uID = New-AzUserAssignedIdentity -ResourceGroupName $ResourceGroupName -Name $idenityName -ErrorAction SilentlyContinue
    # get the user-identity properties
    $idenityNameResourceId = $uID.Id
    $idenityNamePrincipalId = $uID.PrincipalId

    $vnetCheck = Get-AzVirtualNetwork -Name $vNetName -ResourceGroupName $ResourceGroupName -ErrorAction SilentlyContinue
    if (!$vnetCheck) {
        $errorInfo = "Virtual network '" + $vNetName + "' does not exist in resource group '" + $ResourceGroupName + "'. Creating it"
        Write-Host $errorInfo
        $aibRule = New-AzNetworkSecurityRuleConfig -Name ($Prefix+"_AIB-rule") -Description "Allow Image Builder Private Link Access to Proxy VM" -Access Allow -Protocol Tcp -Direction Inbound  -Priority 100 -SourceAddressPrefix AzureLoadBalancer -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange 60000-60001
        $networkSecurityGroup = New-AzNetworkSecurityGroup -ResourceGroupName $ResourceGroupName -Location $Region -Name ($Prefix+"_AIB-nsg") -SecurityRules $aibRule
    
        $Subnet = New-AzVirtualNetworkSubnetConfig -Name ($Prefix+"_AIB-subNet")  -AddressPrefix "10.0.0.0/28" -NetworkSecurityGroup $networkSecurityGroup -PrivateLinkServiceNetworkPoliciesFlag "Disabled"
        $vNet = New-AzVirtualNetwork -Name $vNetName -AddressPrefix "10.0.0.0/27" -Subnet $Subnet -ResourceGroupName $ResourceGroupName -Location $Region
        $vnetCheck = Get-AzVirtualNetwork -Name $vNetName   -ResourceGroupName $ResourceGroupName
    }

    $templateSourceFilePath = [System.String]::Format('.\\{0}.json', "aibRoleImageCreation")
    $templateFilePath = [System.String]::Format('Temp\\{0}{1}.json', "aibRoleImageCreation" , $suffix)
    if (-not (Test-Path .\Temp -PathType Container)) {

        $foo = New-Item 'Temp' -ItemType Directory
    }

    Copy-Item -Path $templateSourceFilePath -Destination $templateFilePath

    (Get-Content $templateFilePath).replace('<subscriptionID>', $Subscription.Id) | Set-Content $templateFilePath
    (Get-Content $templateFilePath).replace('<rgName>', $ResourceGroupName) | Set-Content $templateFilePath
    $foo = New-AzRoleDefinition -InputFile $templateFilePath -Verbose
    
    $templateSourceFilePath = [System.String]::Format('.\\{0}.json', "aibRoleNetworking")
    $templateFilePath = [System.String]::Format('Temp\\{0}{1}.json', "aibRoleNetworking" , $suffix)

    Copy-Item -Path $templateSourceFilePath -Destination $templateFilePath

    (Get-Content $templateFilePath).replace('<subscriptionID>', $Subscription.Id) | Set-Content $templateFilePath
    (Get-Content $templateFilePath).replace('<vnetRgName>', $ResourceGroupName) | Set-Content $templateFilePath

    $foo = New-AzRoleDefinition -InputFile $templateFilePath -Verbose

    $roleName = "Azure Image Builder Service Image Creation Role"
    $role = Get-AzRoleDefinition -Name $roleName

    if(!$role) {
        $roleName = "Contributor"
        $role = Get-AzRoleDefinition -Name $roleName
    }

    #Assing permissions to Azure Virtual Machine Image Builder
    $foo = New-AzRoleAssignment -ObjectId $idenityNamePrincipalId -RoleDefinitionName $rolename -Scope $rg.ResourceId 

    $roleName = "Azure Image Builder Service Networking Role"
    $role = Get-AzRoleDefinition -Name $roleName

    if(!$role) {
        $roleName = "Contributor"
        $role = Get-AzRoleDefinition -Name $roleName
    }

    #New-AzRoleAssignment -RoleDefinitionName "Azure Image Builder Service Networking Role" -Scope $rg.ResourceId -ServicePrincipalName "cf32a0cc-373c-47c9-9156-0db11f6a6dfc" -ErrorAction SilentlyContinue
    $foo = New-AzRoleAssignment -RoleDefinitionName $roleName -Scope $rg.ResourceId -ObjectId $idenityNamePrincipalId -Verbose

    $imageDefID = ""
    $azg = Get-AzGallery -ResourceGroupName $ResourceGroupName -Name $GalleryName -ErrorAction SilentlyContinue
    if (!$azg) {

        Write-Host "Creating the Image Gallery"
        #Create the Image Gallery
        $azg = New-AzGallery -ResourceGroupName $ResourceGroupName -Name $GalleryName -Location $Region

        $statusText = [System.String]::Format('Resource gallery ID: {0}', $azg.Id)
        Write-Verbose $statusText
    }
    $returnValue
}