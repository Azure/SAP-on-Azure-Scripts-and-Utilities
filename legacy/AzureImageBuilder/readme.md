# **Overview**

The scripts and templates in this folder structure can be used to build custom images in Azure using Azure Image Builder.

Read more information on Azure Image Builder here: <https://docs.microsoft.com/en-us/azure/virtual-machines/windows/image-builder-overview>

## **Creating a version from a marketplace image**

You can use the script **demoGalleryImageFromMarketPlace.ps1** to build an image from a marketplace image. In the sample the json file **SLESNetWeaverServerImageFromMarketPlace** has the details of which marketplace image to use and what customization steps to perform. Change the values in the PowerShell script to reflect your environment.

```PowerShell

$subscriptionName = "MySubscription"

# location of the Shared Image Gallery
$region = "northeurope"
$ResourceGroupName = "SharedImages"
$galleryName = "CorpImageGalleryEMEA"

$Publisher = "KimmoDemoCorp"
$Offer = "SAP_App_Servers"
#To get a unique SKU name
$postFix = (Get-Random -Maximum 1000).ToString()
$SKU = "SUSE" + $postFix

#Need the double quotes if there are more than one Additional Region
$additionalRegion = "westeurope"",""uksouth"

# name of the image definition to be created, e.g. ProdImages
$imageDefName = "NETWEAVER"
$templateFileName = "SLESNetWeaverServerImageFromMarketPlace.json"

$OsType = "Linux"
$VersionName = "1.0.0"
```

## **Creating a version from a custom image**

You can use the script **demoGalleryImageFromCustomImage.ps1** to build an image from a custom virtual machine image. image. In the sample the json file **SLESNetWeaverServerImageFromManagedImage.json** has the details of image to use and what customization steps to perform.Change the values in the PowerShell script to reflect your environment.

```PowerShell
$subscriptionName = "MySubscription"

# location of the Shared Image Gallery
$region = "northeurope"

$ResourceGroupName = "SharedImages"
$galleryName = "CorpImageGalleryEMEA"

$Publisher = "KimmoDemoCorp"
$Offer = "SAP_App_Servers"
$postFix = (Get-Random -Maximum 1000).ToString()
$SKU = "SUSE" + $postFix

$customImageID = "/subscriptions/[SUBSCRIPTIONID]/resourceGroups/SharedImages/providers/Microsoft.Compute/images/Fimage"

#Need the double quotes if there are more than one Additional Region
$additionalRegion = "westeurope"",""uksouth"

# name of the image definition to be created, e.g. ProdImages
$imageDefName = "NETWEAVER"
$templateFileName = "SLESNetWeaverServerImageFromManagedImage.json"

$OsType = "Linux"
$VersionName = "0.9.9"
```

## **Creating a version from a shared image gallery image**

You can use the script **demoGalleryImageNewVersionFromGalleryImage.ps1** to build an image from a custom virtual machine image. In the sample the json file **SLESNetWeaverServerImagFromSharedImageGallery.json** has the details of image to use and what customization steps to perform. Change the values in the PowerShell script to reflect your environment.

As it is currently not possible to update image templates the script creates a temporary image template which will be for the customization process. This temporary template will be used to create the actual new version into the correct image definition.

```PowerShell
$subscriptionName = "MySubscription"

$ResourceGroupName = "SharedImages"
$galleryName = "CorpImageGalleryEMEA"
# location of the Shared Image Gallery
$region = "northeurope"

$Publisher = "KimmoDemoCorp"
$Offer = "SAP_App_Servers"
$postFix = (Get-Random -Maximum 1000).ToString()
$SKU = "SUSE" + $postFix

#Resource ID of the shared image gallery version that will be updated
$customImageID = "/subscriptions/[SUBSCRIPTIONID]/resourceGroups/SharedImages/providers/Microsoft.Compute/galleries/CorpImageGalleryEMEA/images/NETWEAVER/versions/1.0.0"

#Need the double quotes if there are more than one Additional Region
$additionalRegion = "westeurope"",""uksouth"

$imageDefName = "NETWEAVER"
$templateFileName = "SLESNetWeaverServerImagFromSharedImageGallery.json"

$OsType = "Linux"
$VersionName = "1.0.1"

```
