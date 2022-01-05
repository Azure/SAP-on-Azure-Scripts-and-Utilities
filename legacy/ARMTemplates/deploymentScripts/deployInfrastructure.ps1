# select subscription

$ResourceGroupNameforASG = "demo-vnet-rg"
$location = "westeurope"
$subscriptionID = "80d5ed43-1465-432b-8914-5e1f68d49330"


Write-Host "Deployment started: " (Get-Date).ToString("yyyy-MM-dd HH:mm")

$Subscription = Get-AzSubscription -SubscriptionId $SubscriptionId

if (-Not $Subscription) {
    Write-Host -ForegroundColor Red -BackgroundColor White "Sorry, it seems you are not connected to Azure or don't have access to the subscription. Please use Connect-AzAccount to connect."
    exit

}

if(-not (Test-Path ..\baseInfrastructure\asg.json -PathType Leaf))
{
    Write-Host -ForegroundColor Red -BackgroundColor White "File ..\baseInfrastructure\asg.json does not exit, ensure that your working directory is correct."
    exit
}


Write-Host "Creating the resource group :" $ResourceGroupNameforASG
$rg = Get-AzResourceGroup -Name $ResourceGroupNameforASG -Location $location -ErrorAction SilentlyContinue
if(!$rg)
{
    New-AzResourceGroup -Name $ResourceGroupNameforASG -Location $location 
 }

Write-Host "Creating the application security groups"

$testRes = Test-AzResourceGroupDeployment  -ResourceGroupName $ResourceGroupNameforASG -TemplateFile ..\baseInfrastructure\asg.json -TemplateParameterFile ..\baseInfrastructure\asg.parameters.json 

if($testRes)
{
    $errStr = [System.String]::Format('The deployment would fail: {0}', $testRes.Message)
    Write-Error -Message $errStr
    exit
}

$res = New-AzResourceGroupDeployment -ResourceGroupName $ResourceGroupNameforASG -Name "Application_Security_Group_Deployment" -TemplateFile ..\baseInfrastructure\asg.json -TemplateParameterFile ..\baseInfrastructure\asg.parameters.json 

if ($res.ProvisioningState -ne "Succeeded") { 
    Write-Error -Message "The deployment failed" 
}

