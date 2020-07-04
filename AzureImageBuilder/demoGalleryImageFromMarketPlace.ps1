. .\create-Shared-Custom-Image.ps1
. .\check-Image-Build-Status.ps1
. .\create-Infrastructure

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
$imageDefName = "NETWEAVER2"
$templateFileName = "SLESNetWeaverServerImageFromMarketPlace.json"

$OsType = "Linux"
$VersionName = "1.0.0"

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


#Check for the infrastructure
$azg = Get-AzGallery -ResourceGroupName $ResourceGroupName -Name $GalleryName -ErrorAction SilentlyContinue
if (!$azg) {
    New-AIBInfrastructure  -Region $region -ResourceGroupName $ResourceGroupName  -GalleryName $galleryName 
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
    $succeeded = New-SharedCustomImage  -Region $region -ResourceGroupName $ResourceGroupName  -GalleryName $galleryName -ImageDefinitionName $imageDefName  -OsType $OsType -TemplateFileName $templateFileName -AdditionalRegion $additionalRegion -Publisher $Publisher -Offer $Offer -SKU $SKU -VersionName $VersionName -Verbose
}
else {
    $succeeded = New-SharedCustomImage  -Region $region -ResourceGroupName $ResourceGroupName  -GalleryName $galleryName -ImageDefinitionName $imageDefName  -OsType $OsType -TemplateFileName $templateFileName -AdditionalRegion $additionalRegion -Publisher $Publisher -Offer $Offer -SKU $SKU  -VersionName $VersionName
}
    
$status = ""
if ($succeeded) {
    $cont = $true
    
    
    Write-Host "Checking the build process"
    
    while ($cont) {
        if ($VerbosePreference -eq "Continue") {
            $status = Get-ImageBuildStatus -galleryName $galleryName -imageDefNameToCheck $imageDefName -Verbose
        }
        else {
            $status = Get-ImageBuildStatus -galleryName $galleryName -imageDefNameToCheck $imageDefName
        }
    
        Write-Verbose  $status
    
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