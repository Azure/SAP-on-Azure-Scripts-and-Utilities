$SID = "S40"
$region = "westeurope"

$subscriptionID = "[SUBSCRIPTIONID]"

$KeyVaultID = "/subscriptions/[SUBSCRIPTIONID]/resourceGroups/sharedservices/providers/Microsoft.KeyVault/vaults/kfomainvault"

#If you want to use a marketplace image $xxxxxImageID needs to be an empty string
#Custom image ID
$AppServerImageID = "/subscriptions/[SUBSCRIPTIONID]/resourceGroups/[IMAGEGALLERYRGNAME]/providers/Microsoft.Compute/galleries/CorpImageGallery/images/[IMAGENAME]/versions/0.24089.43435"
$AppServerImageID = ""
$ASCSServerImageID = ""
$HanaServerImageID = ""

Add-Type -TypeDefinition @"
   public enum DBType
   {
      AnyDB,
      HanaDev,
      HanaProd
   }
"@

[DBType]$Database = [DBType]::HanaDev

#How many ASCS Servers are needed
$NumberOfASCSServers = 2
#Marketplace Template Information for the ASCS Server
#If ImageID is provided then these fields will be ignored
$ASCSPublisher = "suse"
$ASCSOffer = "sles-15-sp1"
$ASCSSKU = "gen1"
$ASCSSKUVersion = "latest"
#VM Size for the ASCS server
$ASCSVMSize = "Standard_D2s_v3"

#How many Application Servers are needed
$NumberOfAppServers = 2
#Marketplace Template Information for the Application Server
#If ImageID is provided then these fields will be ignored
$AppPublisher = "suse"
$AppOffer = "sles-15-sp1"
$AppSKU = "gen1"
$AppSKUVersion = "latest"
#VM Size for the application server
$AppVMSize = "Standard_D4s_v3"

#How many DB Servers are needed
$NumberOfDatabaseServers = 2
#Marketplace Template Information for the Database Server
#If ImageID is provided then these fields will be ignored
$DBPublisher = "suse"
$DBOffer = "sles-15-sp1"
$DBSKU = "gen1"
$DBSKUVersion = "latest"
#VM Size for the database server
$DBVMSize = "Standard_E16s_v3"

#Is High Availability required
$SAPHA = $true

if ($SAPHA) {
    if ($NumberOfASCSServers -lt 2) {
        $NumberOfASCSServers = 2
    }

    if ($NumberOfAppServers -lt 2) {
        $NumberOfAppServers = 2
    }
 
    if ($NumberOfDBServers -lt 2) {
        $NumberOfDBServers = 2
    }
}

$curDirName = Split-Path $pwd -Leaf  
if ($curDirName.ToLower() -ne "landscapes") {
    Write-Host "Please run the script from the landscapes folder"
    exit 
}

$dbTemplateFilePath = ""
$DBServerImage = "hanaProdVM"
$AppServerImage = "AppVM"
$ASCSServerImage = "ASCSVM"

#Create the folder for the new landscape
New-Item -Path $SID -ItemType Directory -ErrorAction SilentlyContinue
$s = Get-Location

$templateFilePath = [System.String]::Format('{0}\{1}\ppgavset.parameters.json', $s, $SID)

#Copying the availability and proximity placement group template parameter file

Copy-Item ..\baseInfrastructure\ppgavset.parameters.json $SID

#Modifying the availability and proximity placement group template parameter file
(Get-Content $templateFilePath).replace('[SID]', $SID) | Set-Content $templateFilePath
(Get-Content $templateFilePath).replace('[LOCATION]', $region) | Set-Content $templateFilePath

#Database template parameter file

$DBDeploymentScript = ""
$dbServerName = ""
for ($i = 1; $i -le $NumberOfDatabaseServers; $i++) {
    switch ($Database) {
        HanaProd {
            $dbTemplateFilePath = [System.String]::Format('{0}\{1}\{1}.HanaProdVM-{2}.parameters.json', $s, $SID, $i)
            Copy-Item "..\serverTemplates\parameterFiles\hanaProdVM.parameters.json" $dbTemplateFilePath 
            Write-Host "Using a Hana production database"
            break;
        }
        HanaDev {
            $dbTemplateFilePath = [System.String]::Format('{0}\{1}\{1}.HanaDevVM-{2}.parameters.json', $s, $SID, $i)
            Copy-Item "..\serverTemplates\parameterFiles\hanaDevVM.parameters.json" $dbTemplateFilePath 
            Write-Host "Using a Hana development database"
            $DBServerImage = "hanaDevVM"
            break;
        }
        AnyDB {
            $dbTemplateFilePath = [System.String]::Format('{0}\{1}\{1}.anyDBProdVM-{2}.parameters.json', $s, $SID, $i)
            Copy-Item "..\serverTemplates\parameterFiles\anyDBProdVM.parameters.json" $dbTemplateFilePath 
            Write-Host "Using Any DB"
            $DBServerImage = "anyDBProdVM"
            break;
        }
    }
    $dbServerName = [System.String]::Format('db-{0}', $i.ToString())
    
    $DeploymentScriptStep = [System.String]::Format('{1}Write-Host "Creating Db Server {2}"{1}$res = New-AzResourceGroupDeployment -Name "DbServer_Creation-{2}" -ResourceGroupName $ResourceGroupName -TemplateFile ..\..\servertemplates\[DBServerImage].json -TemplateParameterFile .\[SID].[DBServerImage]-{0}.parameters.json{1}if ($res.ProvisioningState -ne "Succeeded") {{ {1}  Write-Error -Message "The deployment failed" {1}}}{1}', $i, [Environment]::NewLine, $dbServerName)
    $DBDeploymentScript += $DeploymentScriptStep

    (Get-Content $dbTemplateFilePath).replace('[SID]', $SID) | Set-Content $dbTemplateFilePath
    (Get-Content $dbTemplateFilePath).replace('[KeyVaultID]', $KeyVaultID) | Set-Content $dbTemplateFilePath
    (Get-Content $dbTemplateFilePath).replace('[HanaImageID]', $HanaServerImageID) | Set-Content $dbTemplateFilePath
    (Get-Content $dbTemplateFilePath).replace('[LOCATION]', $region) | Set-Content $dbTemplateFilePath
    (Get-Content $dbTemplateFilePath).replace('[SERVERNAME]', $dbServerName) | Set-Content $dbTemplateFilePath
    (Get-Content $dbTemplateFilePath).replace('[PUBLISHER]', $DBPublisher) | Set-Content $dbTemplateFilePath
    (Get-Content $dbTemplateFilePath).replace('[OFFER]', $DBOffer) | Set-Content $dbTemplateFilePath
    (Get-Content $dbTemplateFilePath).replace('[SKU]', $DBSKU) | Set-Content $dbTemplateFilePath
    (Get-Content $dbTemplateFilePath).replace('[VERSION]', $DBSKUVersion) | Set-Content $dbTemplateFilePath
    (Get-Content $dbTemplateFilePath).replace('[MACHINESIZE]', $DBVMSize) | Set-Content $dbTemplateFilePath        
}

#Application template

$DeploymentScript = ""
$appServerName = ""
for ($i = 1; $i -le $NumberOfAppServers; $i++) {
    $appTemplateFilePath = [System.String]::Format('{0}\{1}\{1}.appVM-{2}.parameters.json', $s, $SID, $i)
    $appServerName = [System.String]::Format('app-{0}', $i.ToString())
        
    $DeploymentScriptStep = [System.String]::Format('{1}Write-Host "Creating App Server {2}"{1}$res = New-AzResourceGroupDeployment -Name "AppServer_Creation-{2}" -ResourceGroupName $ResourceGroupName -TemplateFile ..\..\servertemplates\[AppServerImage].json -TemplateParameterFile .\[SID].[AppServerImage]-{0}.parameters.json{1}if ($res.ProvisioningState -ne "Succeeded") {{ {1}  Write-Error -Message "The deployment failed" {1}}}{1}', $i, [Environment]::NewLine, $appServerName)
    $DeploymentScript += $DeploymentScriptStep

    #Copying the application server template parameter file
    
    Copy-Item "..\serverTemplates\parameterFiles\appVM.parameters.json" $appTemplateFilePath 
    
    #Modifying the application server template parameter file
    
    (Get-Content $appTemplateFilePath).replace('[SID]', $SID) | Set-Content $appTemplateFilePath
    (Get-Content $appTemplateFilePath).replace('[KeyVaultID]', $KeyVaultID) | Set-Content $appTemplateFilePath
    (Get-Content $appTemplateFilePath).replace('[ImageID]', $AppServerImageID) | Set-Content $appTemplateFilePath
    (Get-Content $appTemplateFilePath).replace('[LOCATION]', $region) | Set-Content $appTemplateFilePath
    (Get-Content $appTemplateFilePath).replace('[SERVERNAME]', $appServerName) | Set-Content $appTemplateFilePath
    (Get-Content $appTemplateFilePath).replace('[PUBLISHER]', $AppPublisher) | Set-Content $appTemplateFilePath
    (Get-Content $appTemplateFilePath).replace('[OFFER]', $AppOffer) | Set-Content $appTemplateFilePath
    (Get-Content $appTemplateFilePath).replace('[SKU]', $AppSKU) | Set-Content $appTemplateFilePath
    (Get-Content $appTemplateFilePath).replace('[VERSION]', $AppSKUVersion) | Set-Content $appTemplateFilePath
    (Get-Content $appTemplateFilePath).replace('[MACHINESIZE]', $AppVMSize) | Set-Content $appTemplateFilePath
}

$ascsServerName = ""
$ASCSDeploymentScript = ""
for ($i = 1; $i -le $NumberOfASCSServers; $i++) {
    $appTemplateFilePath = [System.String]::Format('{0}\{1}\{1}.ascsVM-{2}.parameters.json', $s, $SID, $i)
    $ascsServerName = [System.String]::Format('ascs-{0}', $i.ToString())
        
    $DeploymentScriptStep = [System.String]::Format('{1}Write-Host "Creating ASCS Server {2}"{1}$res = New-AzResourceGroupDeployment -Name "ASCSServer_Creation-{2}" -ResourceGroupName $ResourceGroupName -TemplateFile ..\..\servertemplates\[ASCSServerImage].json -TemplateParameterFile .\[SID].[ASCSServerImage]-{0}.parameters.json{1}if ($res.ProvisioningState -ne "Succeeded") {{ {1}  Write-Error -Message "The deployment failed" {1}}}{1}', $i, [Environment]::NewLine, $ascsServerName)
    $ASCSDeploymentScript += $DeploymentScriptStep

    #Copying the application server template parameter file
    
    Copy-Item "..\serverTemplates\parameterFiles\ASCSVM.parameters.json" $appTemplateFilePath 
    
    #Modifying the application server template parameter file
    
    (Get-Content $appTemplateFilePath).replace('[SID]', $SID) | Set-Content $appTemplateFilePath
    (Get-Content $appTemplateFilePath).replace('[KeyVaultID]', $KeyVaultID) | Set-Content $appTemplateFilePath
    (Get-Content $appTemplateFilePath).replace('[ImageID]', $ASCSServerImageID) | Set-Content $appTemplateFilePath
    (Get-Content $appTemplateFilePath).replace('[LOCATION]', $region) | Set-Content $appTemplateFilePath
    (Get-Content $appTemplateFilePath).replace('[SERVERNAME]', $ascsServerName) | Set-Content $appTemplateFilePath
    (Get-Content $appTemplateFilePath).replace('[PUBLISHER]', $ASCSPublisher) | Set-Content $appTemplateFilePath
    (Get-Content $appTemplateFilePath).replace('[OFFER]', $ASCSOffer) | Set-Content $appTemplateFilePath
    (Get-Content $appTemplateFilePath).replace('[SKU]', $ASCSSKU) | Set-Content $appTemplateFilePath
    (Get-Content $appTemplateFilePath).replace('[VERSION]', $ASCSSKUVersion) | Set-Content $appTemplateFilePath
    (Get-Content $appTemplateFilePath).replace('[MACHINESIZE]', $ASCSVMSize) | Set-Content $appTemplateFilePath
}

#Copying the deployment script
$deploymentScriptPath = [System.String]::Format('{0}\{1}\deployLandscape.ps1', $s, $SID)

Copy-Item ..\deploymentScripts\deployLandscape.ps1 $SID

#Modifying the deployment script
(Get-Content $deploymentScriptPath).replace('[AppServerDeployment]', $DeploymentScript) | Set-Content $deploymentScriptPath
(Get-Content $deploymentScriptPath).replace('[ASCSServerDeployment]', $ASCSDeploymentScript) | Set-Content $deploymentScriptPath
(Get-Content $deploymentScriptPath).replace('[DBServerDeployment]', $DBDeploymentScript) | Set-Content $deploymentScriptPath
(Get-Content $deploymentScriptPath).replace('[SID]', $SID) | Set-Content $deploymentScriptPath
(Get-Content $deploymentScriptPath).replace('[DBServerImage]', $DBServerImage) | Set-Content $deploymentScriptPath
(Get-Content $deploymentScriptPath).replace('[AppServerImage]', $AppServerImage) | Set-Content $deploymentScriptPath
(Get-Content $deploymentScriptPath).replace('[ASCSServerImage]', $ASCSServerImage) | Set-Content $deploymentScriptPath
(Get-Content $deploymentScriptPath).replace('[SUBSCRIPTIONID]', $SubscriptionID) | Set-Content $deploymentScriptPath
(Get-Content $deploymentScriptPath).replace('[REGION]', $region) | Set-Content $deploymentScriptPath
