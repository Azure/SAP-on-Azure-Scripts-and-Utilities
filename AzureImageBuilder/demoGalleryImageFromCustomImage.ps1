. .\create-Shared-Custom-Image.ps1
. .\check-Image-Build-Status.ps1


$subscriptionName = "MySubscription"

# location of the Shared Image Gallery
$region = "northeurope"

$ResourceGroupName = "SharedImages"
$galleryName = "CorpImageGalleryEMEA"

$Publisher = "KimmoDemoCorp"
$Offer = "SAP_App_Servers"
$postFix = (Get-Random -Maximum 1000).ToString()
$SKU = "UBUNTU" + $postFix

$customImageID = "/subscriptions/[SubscriptionID]/resourceGroups/SharedImages/providers/Microsoft.Compute/images/foo-image"

#Need the double quotes if there are more than one Additional Region
$additionalRegion = "westeurope"",""uksouth"

# name of the image definition to be created, e.g. ProdImages
$imageDefName = "UBUNTU"
$templateFileName = "SLESNetWeaverServerImageFromManagedImage.json"

$OsType = "Linux"
$VersionName = "1.9.9"

if (!(Test-Path $templateFileName -PathType Leaf)) {
    Write-Error "The ARM template '" $templateFileName +"' could not be found"
    exit
}

# select subscription
$Subscription = Get-AzSubscription -SubscriptionName $SubscriptionName
if (-Not $Subscription) {
    Write-Host -ForegroundColor Red -BackgroundColor White "Sorry, it seems you are not connected to Azure or don't have access to the subscription. Please use Connect-AzAccount to connect."
    exit
}

$foo = Select-AzSubscription -Subscription $SubscriptionName 

$res = Get-AzResource -ResourceId $customImageID -ErrorAction SilentlyContinue
if (!$res) {
    Write-Host -ForegroundColor Red -BackgroundColor White "The image '" + $customImageID + "' does not exist or is not accessible for this account"
    exit
}

#Check for the infrastructure
$azg = Get-AzGallery -ResourceGroupName $ResourceGroupName -Name $GalleryName -ErrorAction SilentlyContinue
if (!$azg) {
    New-AIBInfrastructure -SubscriptionName $subscriptionName -Region $region -ResourceGroupName $ResourceGroupName  -GalleryName $galleryName 
}

$res = Get-AzResource -Name $imageDefName -ResourceType "Microsoft.VirtualMachineImages/imageTemplates" -ErrorAction SilentlyContinue
if ($res) {
    $message = "Resource '" + $imageDefName + "' of type 'Microsoft.VirtualMachineImages/imageTemplates' already exists. Update/Upgrade of image templates is currently not supported. Please change the name of the template you are using or remove it." 
    Write-Host $message
}

$VerbosePreference = "Continue"

$succeeded = $true
Write-Host "Starting the image creation"
if ($VerbosePreference -eq "Continue") {
    $succeeded = New-SharedCustomImage  -Region $region -ResourceGroupName $ResourceGroupName  -GalleryName $galleryName -ImageDefinitionName $imageDefName -OsType $OsType -SourceImageID $customImageID -AdditionalRegion $additionalRegion -Publisher $Publisher -Offer $Offer -SKU $SKU -VersionName $VersionName -TemplateFileName $templateFileName -Verbose 
}
else {
    $succeeded = New-SharedCustomImage -Region $region -ResourceGroupName $ResourceGroupName  -GalleryName $galleryName -ImageDefinitionName $imageDefName -OsType $OsType  -SourceImageID $customImageID -AdditionalRegion $additionalRegion -Publisher $Publisher -Offer $Offer -SKU $SKU -VersionName $VersionName -TemplateFileName $templateFileName
}
  
$status = ""
if ($succeeded) {
    $cont = $true
    
    Write-Host "Checking the build process"
    
    while ($cont) {
        if ($VerbosePreference -eq "Continue") {
            $status = Get-ImageBuildStatus  -galleryName $galleryName -imageDefName $imageDefName -Verbose
        }
        else {
            $status = Get-ImageBuildStatus  -galleryName $galleryName - $imageDefName
        }
        
        If ("Running" -eq $status) {
            Write-Host "Sleeping for 2 minutes"
            Start-Sleep -s 120    
        }
        else {
            $cont = $false
        }
    }
    
        
}

if ("Succeeded" -eq $status) {
    $image = Get-AzGalleryImageVersion -ResourceGroupName $ResourceGroupName -GalleryName $galleryName -GalleryImageDefinitionName $imageDefName -GalleryImageVersionName $VersionName -ErrorAction SilentlyContinue

    if ($null -ne $image) {
        Write-Host "Template ID to be used for deployment: " $image.Id
    }
}