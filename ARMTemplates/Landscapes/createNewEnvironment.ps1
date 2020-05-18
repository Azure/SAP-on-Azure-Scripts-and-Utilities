$SID = "S40"
$region = "westeurope"

$subscriptionID = "[SUBSCRIPTIONID]"

if ($subscriptionID -eq "[SUBSCRIPTIONID]") {
    Write-Error -Message "Please update the subscription ID"
}

#Change $Verbose to $true for verbose output
$Verbose = $false
$VerboseFlag = ""

if ($Verbose) {
    $VerboseFlag = " -Verbose "
}

#Shared resources
$virtualNetworkResourceGroupName = "demo-vnet-rg"
$virtualNetworkName = "demo-vnet"
$dbsubnetName = "db-snet"
$appsubnetName = "app-snet"
$appASG = "sap-app-asg"
$dbASG = "sap-db-asg"
$keyVaultName = "sap-kv"
$adminUserName = "demoadmin"
$keyVaultSecretName = "mypassword"
$diagnosticLogStorageAccount = "sapstoragekfo"

$hasPublicIP = $false
$setDNS = $false
$WebDispatch = $false
#Set MountDisks to false if you don't want to create the LVM and mount the disks
$mountDisks = $true

#Get the Key Vault id
$kv = Get-AzKeyVault -VaultName $keyVaultName

if ($null -eq $kv) {
    Write-Error -Message "The key vault '" + $keyVaultName + "' does not exist"
    exit
}
$KeyVaultID = $kv.ResourceId

Add-Type -TypeDefinition @"
   public enum DBType
   {
      AnyDB,
      HanaDev,
      HanaProd
   }
"@

[DBType]$Database = [DBType]::HanaProd

#How many ASCS Servers are needed
$NumberOfASCSServers = 2
#Marketplace Template Information for the ASCS Server
#If imageID is provided then these fields will be ignored
$ASCSPublisher = "suse"
$ASCSOffer = "sles-sap-15-sp1"
$ASCSSKU = "gen1"
$ASCSSKUVersion = "latest"
#If you want to use a marketplace image $xxxxximageID needs to be an empty string
#Custom image ID
$ASCSServerimageID = ""
#VM Size for the ASCS server
$ASCSVMSize = "Standard_D2s_v3"

#How many Application Servers are needed
$NumberOfAppServers = 2
#Marketplace Template Information for the Application Server
#If imageID is provided then these fields will be ignored
$AppPublisher = "suse"
$AppOffer = "sles-sap-15-sp1"
$AppSKU = "gen1"
$AppSKUVersion = "latest"

# Comment this out if you want to use Windows
# $AppPublisher = "MicrosoftWindowsServer"
# $AppOffer = "WindowsServer"
# $AppSKU = "2016-Datacenter"
# $AppSKUVersion = "latest"
$AppServerimageID = ""

#VM Size for the application server
$AppVMSize = "Standard_D4s_v3"

#How many DB Servers are needed
$NumberOfDatabaseServers = 2
#Marketplace Template Information for the Database Server

#If imageID is provided then these fields will be ignored
$DBPublisher = "suse"
$DBOffer = "sles-sap-15-sp1"
$DBSKU = "gen1"
$DBSKUVersion = "latest"
#VM Size for the database server
#If you want to use a marketplace image $xxxxximageID needs to be an empty string
#Custom image ID
$DBServerimageID = ""
$DBVMSize = "Standard_M64s"

#This only applies for AnyDB
$DBSize = "51200"

#Is High Availability required
$SAPHA = $true

if ($SAPHA) {
    if ($NumberOfASCSServers -lt 2) {
        $NumberOfASCSServers = 2
    }

    if ($NumberOfAppServers -lt 2) {
        $NumberOfAppServers = 2
    }
 
    if ($NumberOfDatabaseServers -lt 2) {
        $NumberOfDatabaseServers = 2
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
$WDServerImage = "WDVM"

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
switch ($Database) {
    HanaProd {
        $dbTemplateFilePath = [System.String]::Format('{0}\{1}\{1}.HanaProdVM.parameters.json', $s, $SID)
        Copy-Item "..\serverTemplates\parameterFiles\hanaProdVM.parameters.json" $dbTemplateFilePath 
        Write-Host "Using a Hana production database"
        break;
    }
    HanaDev {
        $dbTemplateFilePath = [System.String]::Format('{0}\{1}\{1}.HanaDevVM.parameters.json', $s, $SID)
        Copy-Item "..\serverTemplates\parameterFiles\hanaDevVM.parameters.json" $dbTemplateFilePath 
        Write-Host "Using a Hana development database"
        $DBServerImage = "hanaDevVM"
        break;
    }
    AnyDB {
        $dbTemplateFilePath = [System.String]::Format('{0}\{1}\{1}.anyDBProdVM.parameters.json', $s, $SID)
        Copy-Item "..\serverTemplates\parameterFiles\anyDBProdVM.parameters.json" $dbTemplateFilePath 
        Write-Host "Using Any DB"
        $DBServerImage = "anyDBProdVM"
        break;
    }
}
$dbServerName = [System.String]::Format('db')
    
$DeploymentScriptStep = [System.String]::Format('{1}Write-Host "Creating Db Server(s)"{1}$res = New-AzResourceGroupDeployment -Name "DbServer_Creation" -ResourceGroupName $ResourceGroupName -TemplateFile ..\..\servertemplates\[DBServerImage].json -TemplateParameterFile .\[SID].[DBServerImage].parameters.json {3}{1}if ($res.ProvisioningState -ne "Succeeded") {{ {1}  Write-Error -Message "The deployment failed" {1}}}{1}', $i, [Environment]::NewLine, $dbServerName, $VerboseFlag)
$DBDeploymentScript += $DeploymentScriptStep

(Get-Content $dbTemplateFilePath).replace('[SID]', $SID) | Set-Content $dbTemplateFilePath
(Get-Content $dbTemplateFilePath).replace('[KeyVaultID]', $KeyVaultID) | Set-Content $dbTemplateFilePath
(Get-Content $dbTemplateFilePath).replace('[PASSWORDSECRET]', $keyVaultSecretName) | Set-Content $dbTemplateFilePath
(Get-Content $dbTemplateFilePath).replace('[ADMINUSER]', $adminUserName) | Set-Content $dbTemplateFilePath
(Get-Content $dbTemplateFilePath).replace('[DIAGNOSTICSACCOUNT]', $diagnosticLogStorageAccount) | Set-Content $dbTemplateFilePath
(Get-Content $dbTemplateFilePath).replace('[ENVTYPE]', $EnvType) | Set-Content $dbTemplateFilePath
(Get-Content $dbTemplateFilePath).replace('[IMAGEID]', $DBServerimageID) | Set-Content $dbTemplateFilePath
(Get-Content $dbTemplateFilePath).replace('[LOCATION]', $region) | Set-Content $dbTemplateFilePath
(Get-Content $dbTemplateFilePath).replace('[SERVERNAME]', $dbServerName) | Set-Content $dbTemplateFilePath
(Get-Content $dbTemplateFilePath).replace('[PUBLISHER]', $DBPublisher) | Set-Content $dbTemplateFilePath
(Get-Content $dbTemplateFilePath).replace('[OFFER]', $DBOffer) | Set-Content $dbTemplateFilePath
(Get-Content $dbTemplateFilePath).replace('[SKU]', $DBSKU) | Set-Content $dbTemplateFilePath
(Get-Content $dbTemplateFilePath).replace('[VERSION]', $DBSKUVersion) | Set-Content $dbTemplateFilePath
(Get-Content $dbTemplateFilePath).replace('[MACHINESIZE]', $DBVMSize) | Set-Content $dbTemplateFilePath        
(Get-Content $dbTemplateFilePath).replace('[DBSIZE]', $DBSize) | Set-Content $dbTemplateFilePath        
(Get-Content $dbTemplateFilePath).replace('[VNetRG]', $virtualNetworkResourceGroupName) | Set-Content $dbTemplateFilePath        
(Get-Content $dbTemplateFilePath).replace('[VNetName]', $virtualNetworkName) | Set-Content $dbTemplateFilePath        
(Get-Content $dbTemplateFilePath).replace('[DBSubnetName]', $dbsubnetName) | Set-Content $dbTemplateFilePath        
(Get-Content $dbTemplateFilePath).replace('[DBASG]', $dbASG) | Set-Content $dbTemplateFilePath        
(Get-Content $dbTemplateFilePath).replace('"[VMCount]"', $NumberOfDatabaseServers.ToString()) | Set-Content $dbTemplateFilePath        
(Get-Content $dbTemplateFilePath).replace('"[HASPUBLICIP]"', $hasPublicIP.ToString().ToLower()) | Set-Content $dbTemplateFilePath        
(Get-Content $dbTemplateFilePath).replace('"[DNS]"', $setDNS.ToString().ToLower()) | Set-Content $dbTemplateFilePath        
(Get-Content $dbTemplateFilePath).replace('"[MOUNTDISKS]"', $mountDisks.ToString().ToLower()) | Set-Content $dbTemplateFilePath        

#Application template

$DeploymentScript = ""
$appServerName = ""
$appTemplateFilePath = [System.String]::Format('{0}\{1}\{1}.appVM.parameters.json', $s, $SID)
$appServerName = [System.String]::Format('app')
        
$DeploymentScriptStep = [System.String]::Format('{1}Write-Host "Creating App Server(s)"{1}$res = New-AzResourceGroupDeployment -Name "AppServer_Creation-{2}" -ResourceGroupName $ResourceGroupName -TemplateFile ..\..\servertemplates\[AppServerImage].json -TemplateParameterFile .\[SID].[AppServerImage].parameters.json {3}{1}if ($res.ProvisioningState -ne "Succeeded") {{ {1}  Write-Error -Message "The deployment failed" {1}}}{1}', $i, [Environment]::NewLine, $appServerName, $VerboseFlag)
$DeploymentScript += $DeploymentScriptStep

#Copying the application server template parameter file
    
Copy-Item "..\serverTemplates\parameterFiles\appVM.parameters.json" $appTemplateFilePath 
    
#Modifying the application server template parameter file
    
(Get-Content $appTemplateFilePath).replace('[SID]', $SID) | Set-Content $appTemplateFilePath
(Get-Content $appTemplateFilePath).replace('[KeyVaultID]', $KeyVaultID) | Set-Content $appTemplateFilePath
(Get-Content $appTemplateFilePath).replace('[PASSWORDSECRET]', $keyVaultSecretName) | Set-Content $appTemplateFilePath
(Get-Content $appTemplateFilePath).replace('[ADMINUSER]', $adminUserName) | Set-Content $appTemplateFilePath
(Get-Content $appTemplateFilePath).replace('[DIAGNOSTICSACCOUNT]', $diagnosticLogStorageAccount) | Set-Content $appTemplateFilePath
(Get-Content $appTemplateFilePath).replace('[ENVTYPE]', $EnvType) | Set-Content $appTemplateFilePath
(Get-Content $appTemplateFilePath).replace('[IMAGEID]', $AppServerimageID) | Set-Content $appTemplateFilePath
(Get-Content $appTemplateFilePath).replace('[LOCATION]', $region) | Set-Content $appTemplateFilePath
(Get-Content $appTemplateFilePath).replace('[SERVERNAME]', $appServerName) | Set-Content $appTemplateFilePath
(Get-Content $appTemplateFilePath).replace('[PUBLISHER]', $AppPublisher) | Set-Content $appTemplateFilePath
(Get-Content $appTemplateFilePath).replace('[OFFER]', $AppOffer) | Set-Content $appTemplateFilePath
(Get-Content $appTemplateFilePath).replace('[SKU]', $AppSKU) | Set-Content $appTemplateFilePath
(Get-Content $appTemplateFilePath).replace('[VERSION]', $AppSKUVersion) | Set-Content $appTemplateFilePath
(Get-Content $appTemplateFilePath).replace('[MACHINESIZE]', $AppVMSize) | Set-Content $appTemplateFilePath
(Get-Content $appTemplateFilePath).replace('[VNetRG]', $virtualNetworkResourceGroupName) | Set-Content $appTemplateFilePath        
(Get-Content $appTemplateFilePath).replace('[VNetName]', $virtualNetworkName) | Set-Content $appTemplateFilePath        
(Get-Content $appTemplateFilePath).replace('[AppSubnetName]', $appsubnetName) | Set-Content $appTemplateFilePath        
(Get-Content $appTemplateFilePath).replace('[APPASG]', $appASG) | Set-Content $appTemplateFilePath        
(Get-Content $appTemplateFilePath).replace('"[VMCount]"', $NumberOfAppServers.ToString()) | Set-Content $appTemplateFilePath        
(Get-Content $appTemplateFilePath).replace('"[HASPUBLICIP]"', $hasPublicIP.ToString().ToLower()) | Set-Content $appTemplateFilePath        
(Get-Content $appTemplateFilePath).replace('"[DNS]"', $setDNS.ToString().ToLower()) | Set-Content $appTemplateFilePath        
    

$ascsServerName = ""
$ASCSDeploymentScript = ""

if ($NumberOfASCSServers -gt 0) {
    $appTemplateFilePath = [System.String]::Format('{0}\{1}\{1}.ascsVM.parameters.json', $s, $SID)
    $ascsServerName = [System.String]::Format('ascs')
        
    $DeploymentScriptStep = [System.String]::Format('{1}Write-Host "Creating ASCS Server(s)"{1}$res = New-AzResourceGroupDeployment -Name "ASCSServer_Creation" -ResourceGroupName $ResourceGroupName -TemplateFile ..\..\servertemplates\[ASCSServerImage].json -TemplateParameterFile .\[SID].[ASCSServerImage].parameters.json {3}{1}if ($res.ProvisioningState -ne "Succeeded") {{ {1}  Write-Error -Message "The deployment failed" {1}}}{1}', $i, [Environment]::NewLine, $ascsServerName, $VerboseFlag)
    $ASCSDeploymentScript += $DeploymentScriptStep

    #Copying the application server template parameter file
    
    Copy-Item "..\serverTemplates\parameterFiles\ASCSVM.parameters.json" $appTemplateFilePath 
    
    #Modifying the ascs server template parameter file
    
    (Get-Content $appTemplateFilePath).replace('[SID]', $SID) | Set-Content $appTemplateFilePath
    (Get-Content $appTemplateFilePath).replace('[KeyVaultID]', $KeyVaultID) | Set-Content $appTemplateFilePath
    (Get-Content $appTemplateFilePath).replace('[PASSWORDSECRET]', $keyVaultSecretName) | Set-Content $appTemplateFilePath
    (Get-Content $appTemplateFilePath).replace('[ADMINUSER]', $adminUserName) | Set-Content $appTemplateFilePath
    (Get-Content $appTemplateFilePath).replace('[DIAGNOSTICSACCOUNT]', $diagnosticLogStorageAccount) | Set-Content $appTemplateFilePath
    (Get-Content $appTemplateFilePath).replace('[ENVTYPE]', $EnvType) | Set-Content $appTemplateFilePath
    (Get-Content $appTemplateFilePath).replace('[IMAGEID]', $ASCSServerimageID) | Set-Content $appTemplateFilePath
    (Get-Content $appTemplateFilePath).replace('[LOCATION]', $region) | Set-Content $appTemplateFilePath
    (Get-Content $appTemplateFilePath).replace('[SERVERNAME]', $ascsServerName) | Set-Content $appTemplateFilePath
    (Get-Content $appTemplateFilePath).replace('[PUBLISHER]', $ASCSPublisher) | Set-Content $appTemplateFilePath
    (Get-Content $appTemplateFilePath).replace('[OFFER]', $ASCSOffer) | Set-Content $appTemplateFilePath
    (Get-Content $appTemplateFilePath).replace('[SKU]', $ASCSSKU) | Set-Content $appTemplateFilePath
    (Get-Content $appTemplateFilePath).replace('[VERSION]', $ASCSSKUVersion) | Set-Content $appTemplateFilePath
    (Get-Content $appTemplateFilePath).replace('[MACHINESIZE]', $ASCSVMSize) | Set-Content $appTemplateFilePath
    (Get-Content $appTemplateFilePath).replace('[VNetRG]', $virtualNetworkResourceGroupName) | Set-Content $appTemplateFilePath        
    (Get-Content $appTemplateFilePath).replace('[VNetName]', $virtualNetworkName) | Set-Content $appTemplateFilePath        
    (Get-Content $appTemplateFilePath).replace('[AppSubnetName]', $appsubnetName) | Set-Content $appTemplateFilePath        
    (Get-Content $appTemplateFilePath).replace('[APPASG]', $appASG) | Set-Content $appTemplateFilePath        
    (Get-Content $appTemplateFilePath).replace('"[VMCount]"', $NumberOfASCSServers.ToString()) | Set-Content $appTemplateFilePath        
    (Get-Content $appTemplateFilePath).replace('"[HASPUBLICIP]"', $hasPublicIP.ToString().ToLower()) | Set-Content $appTemplateFilePath        
    (Get-Content $appTemplateFilePath).replace('"[DNS]"', $setDNS.ToString().ToLower()) | Set-Content $appTemplateFilePath        
}

$WDDeploymentScript = ""
if ($WebDispatch) {
    #Web Dispatch template

    $WDDeploymentScript = ""
    $wdServerName = ""
    $appTemplateFilePath = [System.String]::Format('{0}\{1}\{1}.wdVM.parameters.json', $s, $SID)
    $wdServerName = [System.String]::Format('webdisp')
        
    $DeploymentScriptStep = [System.String]::Format('{1}Write-Host "Creating Web Dispatch Server(s)"{1}$res = New-AzResourceGroupDeployment -Name "WebServer_Creation-{2}" -ResourceGroupName $ResourceGroupName -TemplateFile ..\..\servertemplates\[WDServerImage].json -TemplateParameterFile .\[SID].[WDServerImage].parameters.json {3}{1}if ($res.ProvisioningState -ne "Succeeded") {{ {1}  Write-Error -Message "The deployment failed" {1}}}{1}', $i, [Environment]::NewLine, $wdServerName, $VerboseFlag)
    $WDDeploymentScript += $DeploymentScriptStep

    #Copying the application server template parameter file
    
    Copy-Item "..\serverTemplates\parameterFiles\wdVM.parameters.json" $appTemplateFilePath 
    
    #Modifying the application server template parameter file
    
    (Get-Content $appTemplateFilePath).replace('[SID]', $SID) | Set-Content $appTemplateFilePath
    (Get-Content $appTemplateFilePath).replace('[KeyVaultID]', $KeyVaultID) | Set-Content $appTemplateFilePath
    (Get-Content $appTemplateFilePath).replace('[PASSWORDSECRET]', $keyVaultSecretName) | Set-Content $appTemplateFilePath
    (Get-Content $appTemplateFilePath).replace('[ADMINUSER]', $adminUserName) | Set-Content $appTemplateFilePath
    (Get-Content $appTemplateFilePath).replace('[DIAGNOSTICSACCOUNT]', $diagnosticLogStorageAccount) | Set-Content $appTemplateFilePath
    (Get-Content $appTemplateFilePath).replace('[ENVTYPE]', $EnvType) | Set-Content $appTemplateFilePath
    (Get-Content $appTemplateFilePath).replace('[IMAGEID]', $AppServerimageID) | Set-Content $appTemplateFilePath
    (Get-Content $appTemplateFilePath).replace('[LOCATION]', $region) | Set-Content $appTemplateFilePath
    (Get-Content $appTemplateFilePath).replace('[SERVERNAME]', $wdServerName) | Set-Content $appTemplateFilePath
    (Get-Content $appTemplateFilePath).replace('[PUBLISHER]', $AppPublisher) | Set-Content $appTemplateFilePath
    (Get-Content $appTemplateFilePath).replace('[OFFER]', $AppOffer) | Set-Content $appTemplateFilePath
    (Get-Content $appTemplateFilePath).replace('[SKU]', $AppSKU) | Set-Content $appTemplateFilePath
    (Get-Content $appTemplateFilePath).replace('[VERSION]', $AppSKUVersion) | Set-Content $appTemplateFilePath
    (Get-Content $appTemplateFilePath).replace('[MACHINESIZE]', $AppVMSize) | Set-Content $appTemplateFilePath
    (Get-Content $appTemplateFilePath).replace('[VNetRG]', $virtualNetworkResourceGroupName) | Set-Content $appTemplateFilePath        
    (Get-Content $appTemplateFilePath).replace('[VNetName]', $virtualNetworkName) | Set-Content $appTemplateFilePath        
    (Get-Content $appTemplateFilePath).replace('[AppSubnetName]', $appsubnetName) | Set-Content $appTemplateFilePath        
    (Get-Content $appTemplateFilePath).replace('[APPASG]', $appASG) | Set-Content $appTemplateFilePath        
    (Get-Content $appTemplateFilePath).replace('"[VMCount]"', $NumberOfAppServers.ToString()) | Set-Content $appTemplateFilePath        
    (Get-Content $appTemplateFilePath).replace('"[HASPUBLICIP]"', $hasPublicIP.ToString().ToLower()) | Set-Content $appTemplateFilePath        
    (Get-Content $appTemplateFilePath).replace('"[DNS]"', $setDNS.ToString().ToLower()) | Set-Content $appTemplateFilePath        
}

#Copying the deployment script
$deploymentScriptPath = [System.String]::Format('{0}\{1}\deployLandscape.ps1', $s, $SID)

Copy-Item ..\deploymentScripts\deployLandscape.ps1 $SID

#Modifying the deployment script
(Get-Content $deploymentScriptPath).replace('[AppServerDeployment]', $DeploymentScript) | Set-Content $deploymentScriptPath
(Get-Content $deploymentScriptPath).replace('[ASCSServerDeployment]', $ASCSDeploymentScript) | Set-Content $deploymentScriptPath
(Get-Content $deploymentScriptPath).replace('[DBServerDeployment]', $DBDeploymentScript) | Set-Content $deploymentScriptPath
(Get-Content $deploymentScriptPath).replace('[WDServerDeployment]', $WDDeploymentScript) | Set-Content $deploymentScriptPath
(Get-Content $deploymentScriptPath).replace('[SID]', $SID) | Set-Content $deploymentScriptPath
(Get-Content $deploymentScriptPath).replace('[DBServerImage]', $DBServerImage) | Set-Content $deploymentScriptPath
(Get-Content $deploymentScriptPath).replace('[AppServerImage]', $AppServerImage) | Set-Content $deploymentScriptPath
(Get-Content $deploymentScriptPath).replace('[ASCSServerImage]', $ASCSServerImage) | Set-Content $deploymentScriptPath
(Get-Content $deploymentScriptPath).replace('[WDServerImage]', $WDServerImage) | Set-Content $deploymentScriptPath
(Get-Content $deploymentScriptPath).replace('[SUBSCRIPTIONID]', $SubscriptionID) | Set-Content $deploymentScriptPath
(Get-Content $deploymentScriptPath).replace('[REGION]', $region) | Set-Content $deploymentScriptPath
(Get-Content $deploymentScriptPath).replace('[APPASG]', $appASG) | Set-Content $deploymentScriptPath
(Get-Content $deploymentScriptPath).replace('[DBASG]', $dbASG) | Set-Content $deploymentScriptPath
(Get-Content $deploymentScriptPath).replace('[VNetRG]', $virtualNetworkResourceGroupName) | Set-Content $deploymentScriptPath
(Get-Content $deploymentScriptPath).replace('[VNetName]', $virtualNetworkName) | Set-Content $deploymentScriptPath
