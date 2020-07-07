<#

.SYNOPSIS

    Create an Managed Image

.DESCRIPTION

    This script creates a managed image in Azure.
    
.EXAMPLE

    .\Create-Custom-Linux-Shared-Image.ps1 -SubscriptionName "mysubscription" -region westeurope -ResourceGroupName test-gallery-rg  -GalleryName ContosoGallery -ImageDefinitionName MyImage -TemplateFileName "AIBTemplate.json" -Publisher "Contoso" -Offer "Contoso-App" -SKU "baseApp" -AdditionalRegion northeurope

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
function New-SharedCustomImage {
    [OutputType([Bool])]
    param(
        #Azure Region, use Get-AzLocation to get region names
        [Parameter(Mandatory = $true)][string]$Region,
        #Resource Group Name 
        [Parameter(Mandatory = $true)][string]$ResourceGroupName, 
        #Name of Image Gallery
        [Parameter(Mandatory = $true)][string]$GalleryName,
        #Image Definition Name
        [Parameter(Mandatory = $true)][string]$ImageDefinitionName,
        #VersionName
        [Parameter(Mandatory = $true)][string]$VersionName,
        #OsType
        [Parameter(Mandatory = $true)][string]$OSType,
        #Template
        [Parameter(Mandatory = $true)][string]$TemplateFileName,
        #Publisher
        [Parameter(Mandatory = $true)][string]$Publisher,
        #Offer Name
        [Parameter(Mandatory = $true)][string]$Offer,
        #SKU Name
        [Parameter(Mandatory = $true)][string]$SKU,
        #Additional Region(s)
        [Parameter(Mandatory = $true)][string]$AdditionalRegion,
        #SourceImageID
        [Parameter(Mandatory = $false)][string]$SourceImageID

    
    
    )

    $suffix = (Get-Date).ToString("yyyyMMddHHmm")
    $runOutputName = $ImageDefinitionName + $suffix

    $vNetName = "aib-vnet"
    $idenityName = "aibIdentity"

    # $rg = Get-AzResourceGroup -Name $ResourceGroupName -Location $Region -ErrorVariable notPresent -ErrorAction SilentlyContinue
    # if ($notPresent) {
    #     Write-Host "Creating the resource group :" $ResourceGroupName
    #     $rg = New-AzResourceGroup -Name $ResourceGroupName -Location $Region 
    # }
    # else {
    # }

    $uID = New-AzUserAssignedIdentity -ResourceGroupName $ResourceGroupName -Name $idenityName -ErrorAction SilentlyContinue
    # get the user-identity properties
    $idenityNameResourceId = $uID.Id
    $idenityNamePrincipalId = $uID.PrincipalId

    $subNetId = ""
    $vnetCheck = Get-AzVirtualNetwork -Name $vNetName -ResourceGroupName $ResourceGroupName -ErrorAction SilentlyContinue
    if (!$vnetCheck) {
        $errorInfo = "Virtual network '" + $vNetName + "' does not exist in resource group '" + $ResourceGroupName + "'. Creating it"
        Write-Host $errorInfo
        return $false
    }
    else {
        $subNetId = [System.String]::Format('{0}/subnets/subNet', $vnetCheck.Id)
    }

    $gid = Get-AzGalleryImageDefinition -ResourceGroupName $ResourceGroupName -GalleryName $GalleryName -Name $ImageDefinitionName -ErrorAction SilentlyContinue
    if (!$gid) {

        Write-Host "Creating the Image Definition"

        $imageDef = New-AzGalleryImageDefinition -ResourceGroupName $ResourceGroupName -Location $Region -GalleryName $GalleryName -Name $ImageDefinitionName -Publisher $Publisher -Offer $Offer -sku $SKU -OsType $OSType -OsState Generalized
        $imageDefID = $imageDef.Id
        $statusText = [System.String]::Format('Image ID: {0}', $imageDefID)
        Write-Verbose $statusText
    }
    else {
        $imageDefID = $gid.Id
    }

    $version = [System.String]::Format('{0}/versions/{1}', $imageDefID, $VersionName)
    $templateSourceFilePath = [System.String]::Format('.\\{0}', $TemplateFileName)
    $templateFilePath = [System.String]::Format('Temp\\{0}{1}.json', $TemplateFileName.Replace(".json", "") , $suffix)
    
    Copy-Item -Path $templateSourceFilePath -Destination $templateFilePath

    (Get-Content $templateFilePath).replace('<location>', $Region) | Set-Content $templateFilePath
    (Get-Content $templateFilePath).replace('<region1>', $Region) | Set-Content $templateFilePath
    (Get-Content $templateFilePath).replace('<region2>', $AdditionalRegion) | Set-Content $templateFilePath
    (Get-Content $templateFilePath).replace('<galleryImageId>', $version) | Set-Content $templateFilePath
    (Get-Content $templateFilePath).replace('<runOutputName>', $runOutputName) | Set-Content $templateFilePath
    (Get-Content $templateFilePath).replace('<imageTemplateName>', $ImageDefinitionName) | Set-Content $templateFilePath
    (Get-Content $templateFilePath).replace('<subnetID>', $subNetId) | Set-Content $templateFilePath
    (Get-Content $templateFilePath).replace('<resourceGroupName>', $ResourceGroupName) | Set-Content $templateFilePath
    (Get-Content $templateFilePath).replace('<imgBuilderId>', $idenityNameResourceId) | Set-Content $templateFilePath
    (Get-Content $templateFilePath).replace('<customImageId>', $SourceImageID) | Set-Content $templateFilePath
    (Get-Content $templateFilePath).replace('<json>', $TemplateFileName.Replace(".", "_")) | Set-Content $templateFilePath


    $returnValue = $false
    $res = New-AzResourceGroupDeployment -ResourceGroupName $ResourceGroupName -TemplateFile $templateFilePath -Verbose 

    if ($Res.ProvisioningState -eq "Succeeded") { 
        $foo = Invoke-AzResourceAction -ResourceName $ImageDefinitionName -ResourceGroupName $ResourceGroupName -ResourceType Microsoft.VirtualMachineImages/imageTemplates -ApiVersion '2020-02-14' -Action Run -Verbose -Force
        $returnValue = $true

    }
    else {
        $returnValue = $false
        Write-Error "The deployment failed"
        $res = Get-AzResource -ResourceType "Microsoft.VirtualMachineImages/imageTemplates" -Name $ImageDefinitionName
        $foo = Remove-AzResource -ResourceId $res.ResourceId -Force
    }

    $returnValue
}
