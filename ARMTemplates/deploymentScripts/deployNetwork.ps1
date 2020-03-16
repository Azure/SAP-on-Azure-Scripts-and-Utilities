# select subscription

$ResourceGroupName = "demo-vnet-ne-rg"
$location = "northeurope"
$subscriptionID = "80d5ed43-1465-432b-8914-5e1f68d49330"


Write-Host "Deployment started: " (Get-Date).ToString("yyyy-MM-dd HH:mm")

$Subscription = Get-AzSubscription -SubscriptionId $SubscriptionId

if (-Not $Subscription) {
    Write-Host -ForegroundColor Red -BackgroundColor White "Sorry, it seems you are not connected to Azure or don't have access to the subscription. Please use Connect-AzAccount to connect."
    exit

}

if(-not (Test-Path ..\baseInfrastructure\network.json -PathType Leaf))
{
    Write-Host -ForegroundColor Red -BackgroundColor White "File ..\baseInfrastructure\network.json does not exit, ensure that your working directory is correct."
    exit
}


Write-Host "Creating the resource group :" $ResourceGroupName
$rg = Get-AzResourceGroup -Name $ResourceGroupName -Location $location -ErrorAction SilentlyContinue
if(!$rg)
{
    New-AzResourceGroup -Name $ResourceGroupName -Location $location 
 }

Write-Host "Creating the network"
$testRes = Test-AzResourceGroupDeployment -ResourceGroupName $ResourceGroupName -TemplateFile ..\baseInfrastructure\network.json -TemplateParameterFile ..\baseInfrastructure\network.parameters.json -Verbose
if($testRes)
{
    $errStr = [System.String]::Format('The deployment would fail: {0}', $testRes.Message)
    Write-Error -Message $errStr
    exit
}

$res = New-AzResourceGroupDeployment -Name "Network_Deployment" -ResourceGroupName $ResourceGroupName -TemplateFile ..\baseInfrastructure\network.json -TemplateParameterFile ..\baseInfrastructure\network.parameters.json -Verbose
if ($res.ProvisioningState -ne "Succeeded") { 
    Write-Error -Message "The deployment failed" 
}

