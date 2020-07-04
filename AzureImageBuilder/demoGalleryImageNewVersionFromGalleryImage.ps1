
. .\create-Shared-Custom-Image.ps1
. .\check-Image-Build-Status.ps1

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
$customImageID = "/subscriptions/[SubscriptionID]/resourceGroups/SharedImages/providers/Microsoft.Compute/galleries/CorpImageGalleryEMEA/images/NETWEAVER/versions/1.0.0"

#Need the double quotes if there are more than one Additional Region
$additionalRegion = "westeurope"",""uksouth"

$imageDefName = "NETWEAVER" 
$templateFileName = "SLESNetWeaverServerImagFromSharedImageGallery.json"

$OsType = "Linux"
$VersionName = "1.0.1"

$suffix = New-Guid
$imageDefNameTemp = $imageDefName + "-" + $suffix 

if(!(Test-Path $templateFileName -PathType Leaf))
{
    Write-Error "The ARM template '" $templateFileName +"' could not be found"
    exit
}

# select subscription
$Subscription = Get-AzSubscription -SubscriptionName $SubscriptionName
if (-Not $Subscription) {
    Write-Host -ForegroundColor Red -BackgroundColor White "Sorry, it seems you are not connected to Azure or don't have access to the subscription. Please use Connect-AzAccount to connect."
    exit
}

$res = Get-AzResource -ResourceId $customImageID -ErrorAction SilentlyContinue
if (!$res) {
    Write-Host -ForegroundColor Red -BackgroundColor White "The image '" + $customImageID + "' does not exist or is not accessible for this account"
    exit
}

$azg = Get-AzGallery -ResourceGroupName $ResourceGroupName -Name $GalleryName -ErrorAction SilentlyContinue
if (!$azg) {
    Write-Host -ForegroundColor Red -BackgroundColor White "The Azure Shared Image Gallery '" + $galleryName + "' does not exist or is not accessible for this account"
    exit
}

$VerbosePreference = "Continue"

$succeeded = $true
Write-Host "Starting the image creation"
if ($VerbosePreference -eq "Continue") {
    $succeeded = New-SharedCustomImage -SubscriptionName $subscriptionName -Region $region -ResourceGroupName $ResourceGroupName  -GalleryName $galleryName -ImageDefinitionName $imageDefNameTemp -OsType $OsType -SourceImageID $customImageID -AdditionalRegion $additionalRegion -Publisher $Publisher -Offer $Offer -SKU $SKU -VersionName $VersionName -TemplateFileName $templateFileName -Verbose 
}
else {
    $succeeded = New-SharedCustomImage  -SubscriptionName $subscriptionName -Region $region -ResourceGroupName $ResourceGroupName  -GalleryName $galleryName -ImageDefinitionName $imageDefNameTemp -OsType $OsType  -SourceImageID $customImageID -AdditionalRegion $additionalRegion -Publisher $Publisher -Offer $Offer -SKU $SKU -VersionName $VersionName -TemplateFileName $templateFileName
}
    
$status = ""

if ($succeeded) {
    $cont = $true
    
    Write-Host "Checking the build process"
    
    while ($cont) {
        if ($VerbosePreference -eq "Continue") {
            $status = Get-ImageBuildStatus  -galleryName $galleryName -imageDefNameToCheck $imageDefNameTemp -Verbose
        }
        else {
            $status = Get-ImageBuildStatus  -galleryName $galleryName -imageDefNameToCheck $imageDefNameTemp
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

$imageID = (Get-AzGalleryImageVersion -ResourceGroupName $ResourceGroupName -GalleryName $galleryName -GalleryImageDefinitionName $imageDefNameTemp -GalleryImageVersionName $VersionName).Id

if ($null -ne $imageID) {
    Write-Host "Create a temporary VM"
    $vmName = "tempVM"
    $nicName = "tempVM-nic"
    $imageName = "tempVM-img"
    
    $region1 = @{Name = 'West Europe'; ReplicaCount = 1 }
    $region2 = @{Name = 'North Europe'; ReplicaCount = 2 }
    
    $targetRegions = @($region1, $region2)

    $user = "azureadm"
    $password = "sddr!AA2241afd1234"

    $VMLocalAdminSecurePassword = ConvertTo-SecureString $password -AsPlainText -Force
    $VMSize = "Standard_DS3"

    $vNetName = "aib-vnet"
    $subNetId = ""
    $vnetCheck = Get-AzVirtualNetwork -Name $vNetName -ResourceGroupName $ResourceGroupName -ErrorAction SilentlyContinue
    if ($vnetCheck) {
        $subNetId = [System.String]::Format('{0}/subnets/subNet', $vnetCheck.Id)
    }

    $cred = New-Object System.Management.Automation.PSCredential ($user, $VMLocalAdminSecurePassword);

    $NIC = New-AzNetworkInterface -Name $nicName -ResourceGroupName $ResourceGroupName -Location $region -SubnetId $subNetId

    $VirtualMachine = New-AzVMConfig -VMName $vmName -VMSize $VMSize
    if("Linux" -eq $OsType)
    {
        $VirtualMachine = Set-AzVMOperatingSystem -VM $VirtualMachine -Linux  -Credential $cred -ComputerName "tempvm"
    }
    else {
        $VirtualMachine = Set-AzVMOperatingSystem -VM $VirtualMachine -Windows  -Credential $cred -ComputerName "tempvm"
    }
    $VirtualMachine = Add-AzVMNetworkInterface -VM $VirtualMachine -Id $NIC.Id
    $VirtualMachine = Set-AzVMSourceImage -VM $VirtualMachine -Id $imageID

    $vm = New-AzVM -ResourceGroupName $ResourceGroupName -Location $region -VM $VirtualMachine -Verbose
    
    Stop-AzVM -ResourceGroupName $ResourceGroupName -Name $vmName -Force
    Set-AzVm -ResourceGroupName $ResourceGroupName -Name $vmName -Generalized
    
    $vm = Get-AzVM -Name $vmName -ResourceGroupName $ResourceGroupName
    $osDisk = $vm.StorageProfile.OsDisk
    
    $image = New-AzImageConfig -Location $region -SourceVirtualMachineId $vm.Id
    if ($VerbosePreference -eq "Continue") {
        $img = New-AzImage -Image $image -ImageName $imageName -ResourceGroupName $ResourceGroupName -Verbose
    }
    else {
        $img = New-AzImage -Image $image -ImageName $imageName -ResourceGroupName $ResourceGroupName
    }

    Remove-AzVM -Id $vm.Id -Force
    Remove-AzResource -ResourceId $osDisk.ManagedDisk.Id -Force
    Remove-AzResource -ResourceId $nic.Id -Force

    if ($VerbosePreference -eq "Continue") {
        New-AzGalleryImageVersion -ResourceGroupName $ResourceGroupName -GalleryName $galleryName -GalleryImageDefinitionName $imageDefName -Name $VersionName -SourceImageId $img.Id -Location $region -TargetRegion $targetRegions -Verbose
    }
    else {
        New-AzGalleryImageVersion -ResourceGroupName $ResourceGroupName -GalleryName $galleryName -GalleryImageDefinitionName $imageDefName -Name $VersionName -SourceImageId $img.Id -Location $region -TargetRegion $targetRegions 
    }
    $foo = Remove-AzResource -ResourceId $imageID -Force
    $res = Get-AzResource -ResourceType "Microsoft.VirtualMachineImages/imageTemplates" -Name $imageDefNameTemp -ErrorAction SilentlyContinue
    if ($res) {
        $foo = Remove-AzResource -ResourceId $res.ResourceId -Force
    }

    $foo = Remove-AzResource -ResourceId $img.Id -Force

    if ($VerbosePreference -eq "Continue") {
        Remove-AzGalleryImageDefinition -ResourceGroupName $ResourceGroupName -GalleryName $galleryName -Name $imageDefNameTemp -Verbose
    }
    else {
        Remove-AzGalleryImageDefinition -ResourceGroupName $ResourceGroupName -GalleryName $galleryName -Name $imageDefNameTemp
    }


}
