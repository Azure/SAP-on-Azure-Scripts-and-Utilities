<#

.SYNOPSIS
    SAP on Azure Quality Check

.DESCRIPTION
    The script will check the configuration of VMs running SAP software for Azure best practice

.LINK
    https://github.com/Azure/SAP-on-Azure-Scripts-and-Utilities

.NOTES
    v1.0 -  Initial version
    v2.0 -  fixing some typos
            adding some additional checks for non-supported VM types
    v3.0 -  rewriting code
            changing how modules are checked because of different modules types (sometimes Get-InstalledModule doesn't come back with correct result)

#>
<#
Copyright (c) Microsoft Corporation.
Licensed under the MIT license.
#>


#Requires -Version 7.1
#Requires -Module Az.Compute
#Requires -Module Az.Network
#Requires -Module Az.NetAppFiles
#Requires -Modules @{ ModuleName="Posh-SSH"; ModuleVersion="3.0.0" }


[CmdletBinding()]
param (
    # VM Operating System
    [Parameter(Mandatory=$true)][string][ValidateSet("Windows", "SUSE", "RedHat", "OracleLinux")]$VMOperatingSystem,
    # Database running SAP
    [Parameter(Mandatory=$true)][string][ValidateSet("HANA","Oracle","MSSQL","Db2","ASE")]$VMDatabase,
    # Which component to check
    [Parameter(Mandatory=$true)][string][ValidateSet("DB", "ASCS", "APP")]$VMRole,
    # VM Resource Group Name
    [Parameter(Mandatory=$true)][string]$AzVMResourceGroup,
    # Azure VM Name
    [Parameter(Mandatory=$true)][string]$AzVMName,
    # VM Hostname or IP address (used to connect)
    [Parameter(Mandatory=$true)][string]$VMHostname,
    # VM Username
    [Parameter(Mandatory=$true)][string]$VMUsername,
    # VM Password
    [Parameter(Mandatory=$true)][System.Security.SecureString]$VMPassword,
    # SSH Keys
    [string]$SSHKey,
    # VM Connection Port (Linux SSH Port)
    [string]$VMConnectionPort="22",
    # Run HA checks
    [boolean]$HighAvailability=$false,
    # ConfigFile that contains the checks to be executed
    [string]$ConfigFileName="QualityCheck.json",
    # HANA Data Directories
    [string[]]$DBDataDir="/hana/data",
    # HANA Log Directories
    [string[]]$DBLogDir="/hana/log",
    # HANA Shared Directory
    [string]$DBSharedDir="/hana/shared",
    # ANF Resource Group
    [string]$ANFResourceGroup,
    # ANF Account Name
    [string]$ANFAccountName,
    # Hardwaretype (VM or HLI)
    [string]$Hardwaretype="VM",
    # HANA Deployment Model
    [string][ValidateSet("OLTP","OLAP","OLTP-ScaleOut","OLAP-ScaleOut")]$HANADeployment="OLTP",
    # High Availability Agent
    [string][ValidateSet("SBD","FencingAgent","WCF")]$HighAvailabilityAgent="SBD"
)


# defining script version
$scriptversion = 2022021101
function LoadHTMLHeader {

$script:_HTMLHeader = @"
<style>

    h1 {

        font-family: Arial, Helvetica, sans-serif;
        color: #e68a00;
        font-size: 28px;

    }

    
    h2 {

        font-family: Arial, Helvetica, sans-serif;
        color: #000099;
        font-size: 16px;

    }

    body {
        font-family: Arial, Helvetica, sans-serif;
    }
    
    
    table {
        font-size: 12px;
        border: 0px; 
        font-family: Lucida Console, monospace;
    } 
    
    td {
        padding: 4px;
        margin: 0px;
        border: 0;
        white-space: pre;
        vertical-align: top;
    }
    
    th {
        background: #395870;
        background: linear-gradient(#49708f, #293f50);
        color: #fff;
        font-size: 11px;
        text-transform: uppercase;
        padding: 10px 15px;
        vertical-align: middle;
        vertical-align: top;
    }

    tbody tr:nth-child(even) {
        background: #f0f0f2;
    }

    #CreationDate {
        font-family: Arial, Helvetica, sans-serif;
        color: #ff3300;
        font-size: 12px;
    }

    #Code {
        font-family: Courier New, monospace;
        font-size: 12px;
    }

    .StatusError {
        color: #ff0000;
    }
    
    .StatusWarning {
        color: #ffa500;
    }

    .StatusOK {
        color: #008000;
    }

    .StatusInfo {
        color: #0026ff;
    }

</style>
"@


    $script:_Content  = "<h1>SAP on Azure Quality Check</h1><h2>Use the links to jump to the sections:</h2>"

}


# CheckRequiredModules - checking for installed Modules and their versions
function CheckRequiredModules {

    # looping through modules in json file
    foreach ($_requiredmodule in $_jsonconfig.PowerShellPrerequisits) {

        # check if module is available
        $_modules = Get-Module -ListAvailable -Name $_requiredmodule.ModuleName
        if ($_modules)
        {
            # module installed, checking for version
            Write-Host "Module" $_requiredmodule.ModuleName "installed"
            $_foundmoduleversion = 0

            foreach ($_module in $_modules) {

                $_requiredmoduleversion = [version]$_requiredmodule.Version
                if ($_module.Version -ge $_requiredmoduleversion) {
                    # found a module version equal or greater then required version
                    $_foundmoduleversion = 1
                    break
                }

            }

            # check if loop found the required version
            if ($_foundmoduleversion -eq 0) {
                # required module version not found
                Write-Host "Please install" $_requiredmodule.ModuleName "with version greater than" $_requiredmodule.Version
                exit
            }

        }
        else {
            # Get-Module didn't come back with a result
            Write-Host "Please install" $_requiredmodule.ModuleName "with version greater than" $_requiredmodule.Version
            exit
        }
    }
}

# function creates an object out of sgmap string
# each text column is return as a part of the object
function ConvertFrom-String_sgmap {

    [CmdletBinding()]
    param (
        [object]$p
    )

    # create empty array
    $_output = @()
    
    # replace characters between numbers with a ','
    $_x = $p.Trim() -replace '\s+',','
    
    # create a table object
    $_x | Foreach-Object {
	    $_output += $_ | ConvertFrom-Csv -Header P1,P2,P3,P4,P5,P6,P7
    }

    # return object
    return $_output
}

# convert a df text output to object
function ConvertFrom-String_df {

    [CmdletBinding()]
    param (
        [object]$p
    )

    # create empty array
    $_output = @()

    # replace all characters with ','
    $_x = $p.Trim() -replace '\s+',','
    
    # create a table object
    $_x | Foreach-Object {
	    $_output += $_ | ConvertFrom-Csv -Header Filesystem,Size,Used,Free,UsedPercent,Mountpoint
    }

    # return object
    return $_output
}

# convert findmnt output to filesystem object
function ConvertFrom-String_findmnt {

    [CmdletBinding()]
    param (
        [object]$p
    )

    # create empty object
    $_output = @()
    
    # replace all characters with ','
    $_x = $p.Trim() -replace '\s+',','

    # create table object
    $_x | Foreach-Object {
	    $_output += $_ | ConvertFrom-Csv -Header target,source,fstype,options
    }

    # return object
    return $_output
}


# check if TCP connectivity is available (firewall rules allow access to system)
function CheckTCPConnectivity {

    if ($VMOperatingSystem -eq "Windows") {

    }
    else {

        try {

        # create a TCP connection to VM using specified port
        $_testresult = New-Object System.Net.Sockets.TcpClient($VMHostname, $VMConnectionPort)
        }
        catch {
            Write-Host "Error connecting to $AzVMName using $VMHostname, please check network connection and firewall rules"
            exit
        }

    }
}

# create a connection to the system
function ConnectVM {
    
    if ($VMOperatingSystem -eq "Windows") {
        # Connect to Windows

        # New-PSSession in the future

    }
    else {
        
        # create a pasword hash that will be used to connect when using sudo commands
        $script:_ClearTextPassword = ConvertFrom-SecureString -SecureString $VMPassword -AsPlainText

        # create credentials object
        $script:_credentials = New-Object System.Management.Automation.PSCredential ($VMUsername, $VMPassword);
        
        # check if SSH Keys are used
        if ($SSHKey.Length -eq 0) {
            # connecting to linux without SSH keys
            $script:_sshsession = New-SSHSession -ComputerName $VMHostname -Credential $_credentials -Port $VMConnectionPort -AcceptKey -ConnectionTimeout 5 -ErrorAction SilentlyContinue
        }
        else {
            # connecting to linux with SSH keys
            $script:_sshsession = New-SSHSession -ComputerName $VMHostname -Credential $_credentials -Port $VMConnectionPort -KeyFile $SSHKey -AcceptKey -ConnectionTimeout 5 -ErrorAction SilentlyContinue
        }

        # check if connection is successful (user/password/sshkeys correct)
        if ($script:_sshsession.Connected -eq $true) {
            # return SSH session ID for later use
            return $script:_sshsession.SessionId
        }
        else {
            # not able to connect
            Write-Host "Please check your credentials, unable to logon"
            exit 
        }
        
    }

}

# collect script parameters and put them into a table object
function CollectScriptParameters {

    # create empty array
    $_outputarray = @()

    # each section is a separate line in the report

    # Operating System
    $_outputarray_row = "" | Select-Object Parameter,Value
    $_outputarray_row.Parameter = "Operating System"
    $_outputarray_row.Value = $VMOperatingSystem
    $_outputarray += $_outputarray_row

    # Database Type
    $_outputarray_row = "" | Select-Object Parameter,Value
    $_outputarray_row.Parameter = "Database"
    $_outputarray_row.Value = $VMDatabase
    $_outputarray += $_outputarray_row

    # VM Role (DB/ASCS/APP)
    $_outputarray_row = "" | Select-Object Parameter,Value
    $_outputarray_row.Parameter = "VM Role"
    $_outputarray_row.Value = $VMRole
    $_outputarray += $_outputarray_row

    # Azure Resource Group Name
    $_outputarray_row = "" | Select-Object Parameter,Value
    $_outputarray_row.Parameter = "Azure Resource Group"
    $_outputarray_row.Value = $AzVMResourceGroup
    $_outputarray += $_outputarray_row

    # Azure VM Name
    $_outputarray_row = "" | Select-Object Parameter,Value
    $_outputarray_row.Parameter = "Azure VM Name"
    $_outputarray_row.Value = $AzVMName
    $_outputarray += $_outputarray_row

    # Hostname or IP Address
    $_outputarray_row = "" | Select-Object Parameter,Value
    $_outputarray_row.Parameter = "VM Hostname / IP Address"
    $_outputarray_row.Value = $VMHostname
    $_outputarray += $_outputarray_row

    # VM Username used to log on
    $_outputarray_row = "" | Select-Object Parameter,Value
    $_outputarray_row.Parameter = "VM Username"
    $_outputarray_row.Value = $VMUsername
    $_outputarray += $_outputarray_row

    # Hardware Type (VM/HLI)
    $_outputarray_row = "" | Select-Object Parameter,Value
    $_outputarray_row.Parameter = "Hardware Type"
    $_outputarray_row.Value = $Hardwaretype
    $_outputarray += $_outputarray_row

    # High Availability Yes/No
    $_outputarray_row = "" | Select-Object Parameter,Value
    $_outputarray_row.Parameter = "High Availability Check"
    $_outputarray_row.Value = $HighAvailability
    $_outputarray += $_outputarray_row

    # if HANA, then HANA Scenario
    if ($VMDatabase -eq "HANA") {
        $_outputarray_row = "" | Select-Object Parameter,Value
        $_outputarray_row.Parameter = "SAP HANA Scenario"
        $_outputarray_row.Value = $HANADeployment
        $_outputarray += $_outputarray_row    
    }

    # if High Availbility, then HA Fencing mechanism
    if ($HighAvailability -eq $true) {
        $_outputarray_row = "" | Select-Object Parameter,Value
        $_outputarray_row.Parameter = "Fencing Mechansim"
        $_outputarray_row.Value = $HighAvailabilityAgent
        $_outputarray += $_outputarray_row    
    }

    # convert the output to HTML
    $_outputarray = $_outputarray | ConvertTo-Html -Property * -Fragment -PreContent "<br><h2 id=""ScriptParameter"">Script Parameters</h2>Here are the parameters handed over to the script"
    $_outputarray = $_outputarray.Replace("::","<br/>")

    # add link to index of HTML file
    $script:_Content += "<a href=""#ScriptParameter"">Script Parameter</a><br>"

    $_outputarray



}

function CollectVMInformation {

    # create empty array
    $_outputarray = @()

    # looping through VM checks
    foreach ($_CollectVMInformationCheck in $_jsonconfig.VMCollectInformation) {

        # check if CollechtVMInformation tasks needs to be executed against this OS and database
        if ( $_CollectVMInformationCheck.OS.Contains($VMOperatingSystem) -and `
          $_CollectVMInformationCheck.DB.Contains($VMDatabase) -and `
          $_CollectVMInformationCheck.Role.Contains($VMRole) -and `
          ($_CollectVMInformationCheck.OSVersion.Contains("all") -or $_CollectVMInformationCheck.OSVersion.Contains($VMOSRelease)) -and `
          $_CollectVMInformationCheck.Hardwaretype.Contains($Hardwaretype)) {

            # check if check applies to HA or not and if HA check for HA-Agent
            if (($_CollectVMInformationCheck.HighAvailability.Contains($HighAvailability)) -or (($_CollectVMInformationCheck.HighAvailability.Contains($HighAvailability)) -and ($_CollectVMInformationCheck.HighAvailabilityAgent.Contains($HighAvailabilityAgent)))) {

                # Write-Host "Running Check" $_CollectVMInformationCheck.Description
                $_output = RunCommand -p $_CollectVMInformationCheck

                # check if result should be shown in report
                if ($_CollectVMInformationCheck.ShowInReport) {

                    # create a new empty object per line
                    $_outputarray_row = "" | Select-Object CheckID, Description, Output
                    $_outputarray_row.CheckID = $_CollectVMInformationCheck.CheckID
                    $_outputarray_row.Description = $_CollectVMInformationCheck.Description
                    $_outputarray_row.Output = $_output -join ';;:;;'

                    # add line to outputarray
                    $_outputarray += $_outputarray_row
                }
            }
        }
    }

    # create HTML output
    $_outputarray = $_outputarray | ConvertTo-Html -Property * -Fragment -PreContent "<br><h2 id=""VMInfo"">Collect VM Information</h2>This section collects basic information of the VM"
    $_outputarray = $_outputarray.Replace(";;:;;","<br/>")

    return $_outputarray

}

# collect additional VM infos
function CollectVMInformationAdditional {

    $_outputarray_total = @()
    $_counter = 0

    # looping through VM checks
    foreach ($_CollectVMInformationCheck in $_jsonconfig.VMCollectInformationAdditional) {

        $_outputarray = @()

        # check if CollechtVMInformation tasks needs to be executed against this OS and database
        if ( $_CollectVMInformationCheck.OS.Contains($VMOperatingSystem) -and `
          $_CollectVMInformationCheck.DB.Contains($VMDatabase) -and `
          $_CollectVMInformationCheck.Role.Contains($VMRole) -and `
          ( $_CollectVMInformationCheck.OSVersion.Contains("all") -or $_CollectVMInformationCheck.OSVersion.Contains($VMOSRelease)) -and `
          $_CollectVMInformationCheck.Hardwaretype.Contains($Hardwaretype)) {

            # check if check applies to HA or not and if HA check for HA-Agent
            if (($_CollectVMInformationCheck.HighAvailability.Contains($HighAvailability)) -or (($_CollectVMInformationCheck.HighAvailability.Contains($HighAvailability)) -and ($_CollectVMInformationCheck.HighAvailabilityAgent.Contains($HighAvailabilityAgent)))) {

                # Write-Host "Running Check" $_CollectVMInformationCheck.Description
                $_output = RunCommand -p $_CollectVMInformationCheck

                # check if result should be shown in report
                if ($_CollectVMInformationCheck.ShowInReport) {

                    $_outputarray_row = "" | Select-Object Output
                    $_outputarray_row.Output = $_output -join ';;:;;'

                    $_outputarray += $_outputarray_row

                    $_htmllink = "additionalinfo" + $_counter
                    $_description = $_CollectVMInformationCheck.Description
                    $_outputarray = $_outputarray | ConvertTo-Html -Property * -Fragment -PreContent "<br><h2 id=""$_htmllink"">$_description</h2>"
                    $script:_Content += "<a href=""#$_htmllink"">$_description</a><br>"
                    $_outputarray = $_outputarray.Replace(";;:;;","<br/>")
        
                    $_counter += 1
                    $_outputarray_total += $_outputarray
        
                }
            }
        }
    }

    return $_outputarray_total

}


# Run an OS command
function RunCommand {

    [CmdletBinding()]
    param (
        [object]$p
    )

    # command needs to run inside OS
    if ($p.CommandType -eq "OS") {
    
        if ($VMOperatingSystem -eq "Windows") {
            # Windows
        }
        else {
            # Linux

            # root permissions required?
            if (($p.RootRequired) -and ($VMUsername -ne "root")) {
                # add sudo to the command
                $_command = "echo '$_ClearTextPassword' | sudo -E -S " + $p.ProcessingCommand
            }
            else {
                # command will be used without sudo
                $_command = $p.ProcessingCommand
            }

            # run the command
            $_result = Invoke-SSHCommand -Command $_command -SessionId $script:_SessionID
            # just store theoutput of the command in $_result
            $_result = $_result.Output
        
            # if postprocessingcommand is defined in JSON
            if (($p.PostProcessingCommand -ne "") -or ($p.PostProcessingCommand)) {
        
                # run postprocessing command
                $_command = $p.PostProcessingCommand
                $_command = $_command -replace "PARAMETER",$_result
                $_result = Invoke-Expression $_command
        
            }
        
            # store the result in script variable to access it for alternative output in JSON
            $script:_CommandResult = $_result

            # return result
            return $_result
        }
    }

    # command is a PowerShell command (e.g. query Azure resources)
    if ($p.CommandType -eq "PowerShell") {

        # set command
        $_command =  $p.ProcessingCommand 
        
        # run command
        $_result = Invoke-Expression $_command

        # if postprocessingcommand is defined in JSON
        if (($p.PostProcessingCommand -ne "") -or ($p.PostProcessingCommand)) {
        
            # run postprocessing command
            $_command = $p.PostProcessingCommand
            $_command = $_command -replace "PARAMETER",$_result
            $_result = Invoke-Expression $_command
    
        }

        # return result
        return $_result
    }
}

# check if there is connectivity to Azure using Get-AzVM command
function CheckAzureConnectivity {

    # check if connected to Azure
    $_SubscriptionInfo = Get-AzSubscription

    # if $_SubscritpionInfo then it got subscriptions
    if ($_SubscriptionInfo)
    {
        # check if connected to right subscription
        $_VMinfo = Get-AzVM -ResourceGroupName $AzVMResourceGroup -Name $AzVMName -ErrorAction SilentlyContinue

        if ($_VMinfo) {
            # connected to Azure

            $_ContextInfo = Get-AzContext

            $script:_SubscriptionID = $_ContextInfo.Subscription
            $script:_SubscriptionName = $_ContextInfo.Name
            $script:_VMName = $_VMinfo.Name
        }
        else {
            Write-Host "Unable to find resource group or VM, please check if you are connected to the correct subscription or if you had a typo"
            exit
        }
    }
    else {
        Write-Host "Please connect to Azure using the Connect-AzAccount command, if you are connected use the Select-AzSubscription command to set the correct context"
        exit
    }

}

# function to manually create an object for Run-Command function
function PrepareCommand {

    [CmdletBinding()]
    param (
        [string]$Command,
        [string]$CommandType = "OS",
        [boolean]$RootRequired = $true,
        [string]$PostProcessingCommand = ""
    )

    $_p = "" | Select-Object ProcessingCommand, CommandType, RootRequired, PostProcessingCommand
    $_p.ProcessingCommand = $Command
    $_p.CommandType = $CommandType
    $_p.RootRequired = $RootRequired
    $_p.PostProcessingCommand = $PostProcessingCommand

    return $_p
}


# Calculate Disk Name
function CalculateDiskTypeSKU {
    param (
        [int]$size,
        [string]$tier
    )

    # check which storage tier is used
    $_performancetype = switch ($tier) {
        Premium_LRS { 'P' }
        UltraSSD_LRS { 'U' }
        Standard_LRS { 'S' }
        StandardSSD_LRS { 'E' }
        Default {}
    }

    # calculate disk SKU based on size
    $_sizetype = switch ($size) {
        ({$PSItem -le 4}) {'1'; break}
        ({$PSItem -le 8}) {'2'; break}
        ({$PSItem -le 16}) {'3'; break}
        ({$PSItem -le 32}) {'4'; break}
        ({$PSItem -le 64}) {'6'; break}
        ({$PSItem -le 128}) {'10'; break}
        ({$PSItem -le 256}) {'15'; break}
        ({$PSItem -le 512}) {'20'; break}
        ({$PSItem -le 1024}) {'30'; break}
        ({$PSItem -le 2048}) {'40'; break}
        ({$PSItem -le 4096}) {'50'; break}
        ({$PSItem -le 8192}) {'60'; break}
        ({$PSItem -le 16384}) {'70'; break}
        ({$PSItem -le 32768}) {'80'; break}
        ({$PSItem -ge 32769}) {'90'; break}
    }
    
    $_disksku = $_performancetype + $_sizetype

    return $_disksku

}


# Show storage configuration of VM
function CollectVMStorage {

    if ($VMOperatingSystem -eq "Windows") {
        # future windows support
    }
    else {

        # get VM info
        $script:_VMinfo = Get-AzVM -ResourceGroupName $AzVMResourceGroup -Name $AzVMName

        # collect LVM configuration
        $_command = PrepareCommand -Command "/sbin/lvm fullreport --reportformat json" 
        $script:_lvmconfig = RunCommand -p $_command | ConvertFrom-Json

        # get sg_map output for LUN-ID to disk mapping
        $_command = PrepareCommand -Command "/usr/bin/sg_map -x" -CommandType "OS"
        $script:_diskmapping = RunCommand -p $_command
        $script:_diskmapping = ConvertFrom-String_sgmap -p $script:_diskmapping

        # get storage using metadata service
        $_command = PrepareCommand -Command "/usr/bin/curl --noproxy '*' -H Metadata:true 'http://169.254.169.254/metadata/instance/compute/storageProfile?api-version=2021-11-01'"
        $script:_azurediskconfig = RunCommand -p $_command | ConvertFrom-Json

        # get Azure Disks in Resource Group
        $_command = PrepareCommand -Command "Get-AzDisk -ResourceGroupName $AzVMResourceGroup" -CommandType "PowerShell"
        $script:_AzureDiskDetails = RunCommand -p $_command
        
        $script:_AzureDisks = @()

        # if VM is Gen1 then SCSI Controller ID is 5, otherwise it is 1 (Gen2)
        if ($VMGeneration -eq "Gen1") {
            $script:_DataDiskSCSIControllerID = 5
            $script:_OSDiskSCSIControllerID = 2
        }
        else {
            $script:_DataDiskSCSIControllerID = 1
            $script:_OSDiskSCSIControllerID = 0
        }

        # add OS Disk Infos
        $_AzureDisk_row = "" | Select-Object LUNID, Name, DeviceName, VolumeGroup, Size, DiskType, IOPS, MBPS, PerformanceTier, StorageType, Caching, WriteAccelerator
        $_AzureDisk_row.LUNID = "OsDisk"
        $_AzureDisk_row.Name = $script:_azurediskconfig.osDisk.name
        $_AzureDisk_row.Size = $script:_azurediskconfig.osDisk.DiskSizeGB
        $_AzureDisk_row.StorageType = $script:_azurediskconfig.osDisk.managedDisk.storageAccountType
        $_AzureDisk_row.Caching = $script:_azurediskconfig.osDisk.caching
        $_AzureDisk_row.WriteAccelerator = $script:_azurediskconfig.osDisk.writeAcceleratorEnabled
        $_AzureDisk_row.DiskType = CalculateDiskTypeSKU -size $script:_azurediskconfig.osDisk.DiskSizeGB -tier $script:_azurediskconfig.osDisk.managedDisk.storageAccountType
        $_AzureDisk_row.IOPS = ($script:_AzureDiskDetails | Where-Object { $_.Name -eq $script:_azurediskconfig.osDisk.name }).DiskIOPSReadWrite
        $_AzureDisk_row.MBPS = ($script:_AzureDiskDetails | Where-Object { $_.Name -eq $script:_azurediskconfig.osDisk.name }).DiskMBpsReadWrite
        $_AzureDisk_row.PerformanceTier = ($script:_AzureDiskDetails | Where-Object { $_.Name -eq $script:_azurediskconfig.osDisk.name }).Tier
        $_AzureDisk_row.DeviceName = ($script:_diskmapping | Where-Object { ($_.P5 -eq 0) -and ($_.P2 -eq $script:_OSDiskSCSIControllerID) }).P7
        $_AzureDisk_row.VolumeGroup = ($script:_lvmconfig.report | Where-Object {$_.pv.pv_name -like ($_AzureDisk_row.DeviceName + "*")}).vg.vg_name

        $script:_AzureDisks += $_AzureDisk_row

        # add datadisks to table
        foreach ($_datadisk in $script:_azurediskconfig.dataDisks) {

            # create empty object
            $_AzureDisk_row = "" | Select-Object LUNID, Name, DeviceName, VolumeGroup, Size, DiskType, IOPS, MBPS, PerformanceTier, StorageType, Caching, WriteAccelerator

            # add disk details
            $_AzureDisk_row.LUNID = $_datadisk.lun
            $_AzureDisk_row.Name = $_datadisk.name
            $_AzureDisk_row.Size = $_datadisk.DiskSizeGB
            $_AzureDisk_row.StorageType = $_datadisk.managedDisk.storageAccountType
            $_AzureDisk_row.Caching = $_datadisk.caching
            $_AzureDisk_row.WriteAccelerator = $_datadisk.writeAcceleratorEnabled

            $_AzureDisk_row.DeviceName = ($script:_diskmapping | Where-Object { ($_.P5 -eq $_datadisk.lun) -and ($_.P2 -eq $script:_DataDiskSCSIControllerID) }).P7
            # $_AzureDisk_row.VolumeGroup = ($script:_lvmconfig.report | Where-Object {$_.pv.pv_name -eq $_AzureDisk_row.DeviceName}).vg.vg_name
            $_AzureDisk_row.VolumeGroup = ($script:_lvmconfig.report | Where-Object {$_.pv.pv_name -like ($_AzureDisk_row.DeviceName + "*")}).vg[0].vg_name

            $_AzureDisk_row.IOPS = ($_AzureDiskDetails | Where-Object { $_.Name -eq $_datadisk.name }).DiskIOPSReadWrite
            $_AzureDisk_row.MBPS = ($_AzureDiskDetails | Where-Object { $_.Name -eq $_datadisk.name }).DiskMBpsReadWrite
            $_AzureDisk_row.PerformanceTier = ($_AzureDiskDetails | Where-Object { $_.Name -eq $_datadisk.name }).Tier

            $_AzureDisk_row.DiskType = CalculateDiskTypeSKU -size $_datadisk.DiskSizeGB -tier $_datadisk.managedDisk.storageAccountType

            $script:_AzureDisks += $_AzureDisk_row

        }

    }
    
    # convert output to HTML 
    $script:_AzureDisksOutput = $script:_AzureDisks | ConvertTo-Html -Property * -Fragment -PreContent "<br><h2 id=""VMStorage"">Collect VM Storage Information</h2>This table contains the disks directly attached to the VM"

    # add VM Storage to HTML index
    $script:_Content += "<a href=""#VMStorage"">VM Storage</a><br>"

    return $script:_AzureDisksOutput

}

# get LVM groups (VGs)
function CollectLVMGroups {

    # create empty object
    $script:_lvmgroups = @()

    # loop through LVM report
    foreach ($_lvmgroup in $script:_lvmconfig.report) {

        # create empty object for line
        $_lvmgroup_row = "" | Select-Object Name,Disks,LogicalVolumes,Totalsize,TotalIOPS,TotalMBPS

        # add data to object
        $_lvmgroup_row.Name = $_lvmgroup.vg.vg_name
        $_lvmgroup_row.Disks = $_lvmgroup.vg.pv_count
        $_lvmgroup_row.LogicalVolumes = $_lvmgroup.vg.lv_count
        $_lvmgroup_row.Totalsize = $_lvmgroup.vg.vg_size
        $_lvmgroup_row.TotalIOPS = ($script:_AzureDisks | Where-Object { $_.VolumeGroup -eq $_lvmgroup.vg.vg_name } | Measure-Object -Property IOPS -Sum).Sum
        $_lvmgroup_row.TotalMBPS = ($script:_AzureDisks | Where-Object { $_.VolumeGroup -eq $_lvmgroup.vg.vg_name } | Measure-Object -Property MBPS -Sum).Sum

        $script:_lvmgroups += $_lvmgroup_row

    }

    # convert output to HTML
    $script:_lvmgroupsOutput = $script:_lvmgroups | ConvertTo-Html -Property * -Fragment -PreContent "<br><h2 id=""LVMGroups"">Collect LVM Groups Information</h2>"

    # add LVM Groups to HTML index
    $script:_Content += "<a href=""#LVMGroups"">LVM Groups</a><br>"

    return $script:_lvmgroupsOutput

}

# collect logical volumes
function CollectLVMVolummes {

    # create empty object
    $script:_lvmvolumes = @()

    # loop through LVM config
    foreach ($_lvmgroup in $script:_lvmconfig.report) {

        # only go for VGs that are not rootvg
        if ($_lvmgroup.vg.vg_name -ne "rootvg") {
            foreach ($_lvmvolume in $_lvmgroup.lv) {
                        
                # create empty object for data line
                $_lvmvolume_row = "" | Select-Object Name,VGName,LVPath,DMPath,Layout,Size,Stripesize,Stripes

                # add data
                $_lvmvolume_row.Name = $_lvmvolume.lv_name
                $_lvmvolume_row.VGName = $_lvmgroup.vg.vg_name
                $_lvmvolume_row.LVPath = $_lvmvolume.lv_path
                $_lvmvolume_row.DMPath = $_lvmvolume.lv_dm_path
                $_lvmvolume_row.Layout = $_lvmvolume.lv_layout
                $_lvmvolume_row.Size = $_lvmvolume.lv_size
                $_lvmvolume_row.StripeSize = $_lvmgroup.seg[0].stripe_size
                $_lvmvolume_row.Stripes = ($_lvmgroup.seg.stripes | Measure-Object -Sum).Count

                # add line to report
                $script:_lvmvolumes += $_lvmvolume_row

            }
        }
    }

    # convert output to HTML
    $script:_lvmvolumesOutput = $script:_lvmvolumes | ConvertTo-Html -Property * -Fragment -PreContent "<br><h2 id=""LVMVolumes"">Collect LVM Volume Information</h2>"

    # add entry to HTML index
    $script:_Content += "<a href=""#LVMVolumes"">LVM Volumes</a><br>"

    return $script:_lvmvolumesOutput

}

# collect network interfaces
function CollectNetworkInterfaces {

    # get Azure VM infos
    $_VMinfo = Get-AzVM -ResourceGroupName $AzVMResourceGroup -Name $AzVMName -ErrorAction SilentlyContinue

    # create empty object for network interfaces
    $script:_NetworkInterfaces = @()

    # loop through network interfaces
    foreach ($_VMnetworkinterface in $_VMinfo.NetworkProfile.NetworkInterfaces) {

        # get details for each network interface
        $_networkinterface = Get-AzNetworkInterface -ResourceId $_VMnetworkinterface.Id

        # create empty object for each line
        $_networkinterface_row = "" | Select-Object Name,AcceleratedNetworking,IPForwarding,PrivateIP,NSG

        # add infos
        $_networkinterface_row.Name = $_networkinterface.Name
        $_networkinterface_row.AcceleratedNetworking = $_networkinterface.EnableAcceleratedNetworking
        $_networkinterface_row.IPForwarding = $_networkinterface.EnableIPForwarding
        $_networkinterface_row.NSG = $_networkinterface.NetworkSecurityGroup.Id

        # add private IP addresses for interfaces
        $_networkinterface_row.PrivateIP = ""
        foreach ($_ipconfig in $_networkinterface.IpConfigurations) {
            $_networkinterface_row.PrivateIP = $_networkinterface_row.PrivateIP + $_ipconfig.PrivateIpAddress + " "
        }

        # add output to object
        $script:_NetworkInterfaces += $_networkinterface_row

    }

    # create HTML output
    $script:_NetworkInterfacesOutput = $script:_NetworkInterfaces | ConvertTo-Html -Property * -Fragment -PreContent "<br><h2 id=""NetworkInterfaces"">Collect Network Interfaces</h2>"

    # create entry in HTML index
    $script:_Content += "<a href=""#NetworkInterfaces"">Network Interfaces</a><br>"

    return $script:_NetworkInterfacesOutput

}

# collect load balancers
function CollectLoadBalancer {

    # get Azure VM Info
    $_VMinfo = Get-AzVM -ResourceGroupName $AzVMResourceGroup -Name $AzVMName -ErrorAction SilentlyContinue

    # create empty object for load balancers
    $Script:_LoadBalancers = @()

    # loop through each network interface
    foreach ($_VMnetworkinterface in $_VMinfo.NetworkProfile.NetworkInterfaces) {

        # get network interface details
        $_networkinterface = Get-AzNetworkInterface -ResourceId $_VMnetworkinterface.Id

        # loop through IP configurations of each interface
        foreach ($_ipconfig in $_networkinterface.IpConfigurations) {
            
            # loop through each loadbalancer backend address pool of each interface IP config
            foreach ($_loadbalancerbackendpool in $_ipconfig.LoadBalancerBackendAddressPools) {

                # create empty load balancer row entry
                $_loadbalancer_row = "" | Select-Object Name,Type,IdleTimeout,FloatingIP,Protocols

                # split data from pool to (full resource string) for LB name and Resource Group
                $_loadbalancername = ($_loadbalancerbackendpool.id).Split("/")[8]
                $_loadbalancerresourcegroup = ($_loadbalancerbackendpool.id).Split("/")[4]

                # get details for load balancer
                $_loadbalancer = Get-AzLoadBalancer -Name $_loadbalancername -ResourceGroupName $_loadbalancerresourcegroup

                # add details
                $_loadbalancer_row.Name = $_loadbalancername
                $_loadbalancer_row.Type = $_loadbalancer.Sku
                $_loadbalancer_row.IdleTimeout = $_loadbalancer.LoadBalancingRules[0].IdleTimeoutInMinutes
                $_loadbalancer_row.FloatingIP = $_loadbalancer.LoadBalancingRules[0].EnableFloatingIP
                $_loadbalancer_row.Protocols = $_loadbalancer.LoadBalancingRules[0].Protocol

                # add data to table
                $Script:_LoadBalancers += $_loadbalancer_row

            }
        }
    }

    # if load balancer found
    if ($Script:_LoadBalancers) {
        $_LoadBalancerOutput = $script:_LoadBalancers | ConvertTo-Html -Property * -Fragment -PreContent "<br><h2 id=""LoadBalancers"">Collect Load Balancer</h2>"
    }
    else {
        # no load balancer found
        $_loadbalancer_row = "" | Select-Object "Description"
        $_loadbalancer_row.Description = "No load balancer assigned to network interfaeces"
        
        $_LoadBalancerOutput = $_loadbalancer_row | ConvertTo-Html -Property * -Fragment -PreContent "<br><h2 id=""LoadBalancers"">Collect Load Balancer</h2>"
    }

    $script:_Content += "<a href=""#LoadBalancers"">Load Balancer</a><br>"

    return $_LoadBalancerOutput

}

# calculate a kernel version
function CalculateKernelVersion {
    Param (
        [string] $kernelversion
    )

    # Linux Kernel Version consist of - and .
    # this module generates a number to compare different kernel versions
    # reason for the module is that there is no built in kernel comparison function and the kernel names are different on distributions
    # the idea is to take ever number and multiply it with a factor, the more right you get on kernel versions, the smaller the factor is
    # e.g. a kernel 4.2.65 would generate
    # 4 * 10000000  +  2 * 100000  + 65 * 1000
    # the result is 40265000
    # this value is then used in a greater or lower than X comparison

    $_kversionarray = @()

    # replace "-" with "."
    $_kversion = $kernelversion.Replace("-",".")
    # now split every number into an array
    $_kversionarray = $_kversion.split(".")
    # calculate the kernel version number
    $_kversionnumber = [System.Int32]$_kversionarray[0] * 10000000 + [System.Int32]$_kversionarray[1] * 100000 + [System.Int32]$_kversionarray[2] * 1000 + [System.Int32]$_kversionarray[3] * 100 + [System.Int32]$_kversionarray[4] * 10

    return $_kversionnumber
}

# check for kernel version
function CheckForKernelVersion {
    Param (
        [string] $startversion,
        [string] $endversion,
        [string] $version
    )

    # this function used the calculate kernel version function to create an integer value for comparison

    # start kernel version of condition
    $_kversionnumberstart = CalculateKernelVersion -kernelversion $startversion
    # end kernel version of condition
    $_kversionnumberend = CalculateKernelVersion -kernelversion $endversion
    # used kernel version
    $_kversionnumber = CalculateKernelVersion -kernelversion $version

    # check if the kernel version applies
    if (($_kversionnumber -gt $_kversionnumberstart) -and ($_kversionnumber -lt $_kversionnumberend)) {
        # yes, condition met
        return $true
    }
    else {
        # check doesn't apply
        return $false
    }
}

# function to remove unnessecary tabs and spaces
function RemoveTabsAndSpaces {

    param (
        [string]$OriginalString
    )

    $_newstring = $OriginalString
    
    # remove tabs
    $_newstring = $_newstring -replace '\t',' '

    # remove double spaces
    while ($_newstring -contains "  ") {
        $_newstring = $_newstring -replace '  ', ' '
    }

    return $_newstring

}

# function to create a line per check, required to add e.g. docs URL or SAP note entries
function AddCheckResultEntry {

    param (
        [string]$CheckID="NoCheckID",
        [string]$Description="",
        [string]$AdditionalInfo="",
        [string]$TestResult="",
        [string]$ExptectedResult="",
        [string]$Status="",
        [string]$SAPNote="",
        [string]$MicrosoftDocs="",
        [string]$ErrorCategory=""
    )

    # create empty object per line
    $_Check_row = "" | Select-Object CheckID, Description, AdditionalInfo, Testresult, ExpectedResult, Status, SAPNote, MicrosoftDocs

    # add infos
    $_Check_row.CheckID = $CheckID
    $_Check_row.Description = $Description
    $_Check_row.AdditionalInfo = $AdditionalInfo
    $_Check_row.Testresult = $TestResult
    $_Check_row.ExpectedResult = $ExptectedResult
    
    #$_Check_row.Status = $Status
    
    # taking input from JSON and adding INFO, ERROR or WARNING
    if ($Status -eq "ERROR") {
        $_Check_row.Status = $ErrorCategory
    }
    else {
        $_Check_row.Status = $Status
    }
    
    # if SAPNote is defined it will add the HTML code for the link
    if ($SAPNote -ne "") {
        $_Check_row.SAPNote = "::SAPNOTEHTML1::" + $SAPNote + "::SAPNOTEHTML2::" + $SAPNote + "::SAPNOTEHTML3::"
    }

    # if MicrosoftDocs is defined it will add HTML code for the link
    if ($MicrosoftDocs -ne "") {
        $_Check_row.MicrosoftDocs = "::MSFTDOCS1::" + $MicrosoftDocs + "::MSFTDOCS2::" + "Link" + "::MSFTDOCS3::"
    }

    # add data to checks
    $script:_Checks += $_Check_row

}

# run the quality checks (compare expectations with real values)
function RunQualityCheck {

    # add empty object for all checks done
    $script:_Checks = @()

    # add empty storage type object (will be filled to know if check applies)
    $script:_StorageType = @()

    # adding premium storage for app and ASCS nodes
    if ($VMRole -eq "ASCS" -or $VMRole -eq "APP") {
        $script:_StorageType += "Premium_LRS"
    }

    # adding premium storage for app and ASCS nodes
    if ($VMRole -eq "DB" -and $VMDatabase -ne "HANA") {
        $script:_StorageType += "Premium_LRS"
    }

    # STORAGE CHECKS SAP HANA
    # checking for data disks
    if (($VMDatabase -eq "HANA") -and ($VMRole -eq "DB")) {

        # adding Premium_LRS as default disk type for script use
        $script:_StorageType += "Premium_LRS"

        # default URL for HANA storage documentation
        $_saphanastorageurl = "https://docs.microsoft.com/en-us/azure/virtual-machines/workloads/sap/hana-vm-operations-storage"

        ## getting file system for /hana/data
        $_filesystem_hana = ($Script:_filesystems | Where-Object {$_.Target -in $DBDataDir})
        if ($_filesystem_hana.Source.StartsWith("/dev/sd")) {
            $_filesystem_hana_type = "direct"
        }
        else {
            $_filesystem_hana_type = "lvm"
        }

        if ( ($_filesystem_hana.fstype | Select-Object -Unique) -in @('xfs','nfs','nfs4')) {
            AddCheckResultEntry -CheckID "HDB-FS-0001" -Description "SAP HANA Data: File System" -TestResult $_filesystem_hana.fstype -ExptectedResult "xfs, nfs or nfs4" -Status "OK"  -MicrosoftDocs $_saphanastorageurl -SAPNote "2972496"
        }
        else {
            AddCheckResultEntry -CheckID "HDB-FS-0001" -Description "SAP HANA Data: File System" -TestResult $_filesystem_hana.fstype -ExptectedResult "xfs, nfs or nfs4" -Status "ERROR"  -MicrosoftDocs $_saphanastorageurl -SAPNote "2972496" -ErrorCategory "ERROR"
        }

        if ( (($script:_filesystems | Where-Object {$_.target -in $DBDataDir}).MaxMBPS | Measure-Object -Sum).Sum -ge $_jsonconfig.HANAStorageRequirements.HANADataMBPS) {
            AddCheckResultEntry -CheckID "HDB-FS-0002" -Description "SAP HANA Data: Disk Performance" -TestResult ($script:_filesystems | Where-Object {$_.target -eq $DBDataDir}).MaxMBPS -ExptectedResult ">= 400 MByte/s" -Status "OK"  -MicrosoftDocs $_saphanastorageurl
        }
        else {
            AddCheckResultEntry -CheckID "HDB-FS-0002" -Description "SAP HANA Data: Disk Performance" -TestResult ($script:_filesystems | Where-Object {$_.target -eq $DBDataDir}).MaxMBPS -ExptectedResult ">= 400 MByte/s" -Status "ERROR"  -MicrosoftDocs $_saphanastorageurl -ErrorCategory "ERROR"
        }

        if ($_filesystem_hana.fstype -eq 'xfs') {

            ## getting disks for /hana/data
            $_AzureDisks_hana = ($_AzureDisks | Where-Object {$_.VolumeGroup -in $_filesystem_hana.vg})

            $_FirstDisk = $_AzureDisks_hana[0]

            # checking if IOPS need to be checked (Ultra Disk)
            if ($_FirstDisk.StorageType -eq "UltraSSD_LRS") {
                if ( ($_filesystem_hana.fstype | Select-Object -Unique) -in @('xfs')) {
                    if ( (($script:_filesystems | Where-Object {$_.target -in $DBDataDir}).MaxIOPS | Measure-Object -Sum).Sum -ge $_jsonconfig.HANAStorageRequirements.HANADataIOPS) {
                        AddCheckResultEntry -CheckID "HDB-FS-0003" -Description "SAP HANA Data: Disk Performance" -TestResult ($script:_filesystems | Where-Object {$_.target -eq $DBDataDir}).MaxIOPS -ExptectedResult ">= 7000 IOPS" -Status "OK"  -MicrosoftDocs $_saphanastorageurl
                    }
                    else {
                        AddCheckResultEntry -CheckID "HDB-FS-0003" -Description "SAP HANA Data: Disk Performance" -TestResult ($script:_filesystems | Where-Object {$_.target -eq $DBDataDir}).MaxIOPS -ExptectedResult ">= 7000 IOPS" -Status "ERROR"  -MicrosoftDocs $_saphanastorageurl -ErrorCategory "ERROR"
                    }
                }
            }

            # check if stripe size check required (no of disks greater than 1 in VG) and disk type is LVM
            if (($_AzureDisks_hana.count -gt 1) -and ($_filesystem_hana_type -eq "lvm")) {
                $_HANAStripeSize = $_jsonconfig.HANAStorageRequirements.HANADataStripeSize

                if ($_filesystem_hana.StripeSize -eq $_HANAStripeSize) {
                    # stripe size correct
                    AddCheckResultEntry -CheckID "HDB-FS-0004" -Description "SAP HANA Data: stripe size" -AdditionalInfo ("Disk " + $_FirstDisk.name) -TestResult $_filesystem_hana.StripeSize -ExptectedResult $_HANAStripeSize -Status "OK" -MicrosoftDocs $_saphanastorageurl
                }
                else {
                    # Wrong Disk Type
                    AddCheckResultEntry -CheckID "HDB-FS-0004" -Description "SAP HANA Data: stripe size" -AdditionalInfo ("Disk " + $_FirstDisk.name) -TestResult $_filesystem_hana.StripeSize -ExptectedResult $_HANAStripeSize -Status "ERROR" -MicrosoftDocs $_saphanastorageurl -ErrorCategory "ERROR"
                }
            }

            # if LVM is used check for same disk type as multiple volumes might be used
            if ($_filesystem_hana_type -eq "lvm") {
                foreach ($_AzureDisk_hana in $_AzureDisks_hana) {

                    if ($_AzureDisk_hana.Disktype -eq $_FirstDisk.Disktype) {
                        # disk type correct
                        AddCheckResultEntry -CheckID "HDB-FS-0005" -Description "SAP HANA Data: same disk type" -AdditionalInfo ("Disk " + $_AzureDisk_hana.name) -TestResult $_AzureDisk_hana.Disktype -ExptectedResult $_FirstDisk.Disktype -Status "OK" -MicrosoftDocs $_saphanastorageurl
                    }
                    else {
                        # Wrong Disk Type
                        AddCheckResultEntry -CheckID "HDB-FS-0005" -Description "SAP HANA Data: same disk type" -AdditionalInfo ("Disk " + $_AzureDisk_hana.name) -TestResult $_AzureDisk_hana.Disktype -ExptectedResult $_FirstDisk.Disktype -Status "ERROR" -MicrosoftDocs $_saphanastorageurl -ErrorCategory "ERROR"

                    }

                    if ($_AzureDisk_hana.PERFORMANCETIER -eq $_FirstDisk.PERFORMANCETIER) {
                        # disk type correct
                        AddCheckResultEntry -CheckID "HDB-FS-0006" -Description "SAP HANA Data: same disk performance type" -AdditionalInfo ("Disk " + $_AzureDisk_hana.name) -TestResult $_AzureDisk_hana.Disktype -ExptectedResult $_FirstDisk.Disktype -Status "OK" -MicrosoftDocs $_saphanastorageurl

                    }
                    else {
                        # Wrong Disk Type
                        AddCheckResultEntry -CheckID "HDB-FS-0006" -Description "SAP HANA Data: same disk performance type" -AdditionalInfo ("Disk " + $_AzureDisk_hana.name) -TestResult $_AzureDisk_hana.Disktype -ExptectedResult $_FirstDisk.Disktype -Status "ERROR" -MicrosoftDocs $_saphanastorageurl -ErrorCategory "ERROR"
                    }

                    # setting storage type for later checks
                    $script:_StorageType += $_AzureDisk_hana.StorageType

                }
            }
        }
        elseif (($_filesystem_hana.fstype -eq 'nfs') -or ($_filesystem_hana.fstype -eq 'nfs4')) {

            $script:_StorageType += "ANF"

            ## /hana/data is on NFS
            
        }
        else {
            ## file system not found
        }

        ## getting file system for /hana/log
        $_filesystem_hana = ($Script:_filesystems | Where-Object {$_.Target -in $DBLogDir})
        if ($_filesystem_hana.Source.StartsWith("/dev/sd")) {
            $_filesystem_hana_type = "direct"
        }
        else {
            $_filesystem_hana_type = "lvm"
        }

        if ( ($_filesystem_hana.fstype | Select-Object -Unique) -in @('xfs','nfs','nfs4')) {
            AddCheckResultEntry -CheckID "HDB-FS-0007" -Description "SAP HANA Log: File System" -TestResult $_filesystem_hana.fstype -ExptectedResult "xfs, nfs or nfs4" -Status "OK"  -MicrosoftDocs $_saphanastorageurl
        }
        else {
            AddCheckResultEntry -CheckID "HDB-FS-0007" -Description "SAP HANA Log: File System" -TestResult $_filesystem_hana.fstype -ExptectedResult "xfs, nfs or nfs4" -Status "ERROR"  -MicrosoftDocs $_saphanastorageurl -ErrorCategory "ERROR"
        }

        if ( (($script:_filesystems | Where-Object {$_.target -in $DBLogDir}).MaxMBPS | Measure-Object -Sum).Sum -ge $_jsonconfig.HANAStorageRequirements.HANALogMBPS) {
            AddCheckResultEntry -CheckID "HDB-FS-0008" -Description "SAP HANA Log: Disk Performance" -TestResult ($script:_filesystems | Where-Object {$_.target -eq $DBLogDir}).MaxMBPS -ExptectedResult ">= 250 MByte/s" -Status "OK"  -MicrosoftDocs $_saphanastorageurl
        }
        else {
            AddCheckResultEntry -CheckID "HDB-FS-0008" -Description "SAP HANA Log: Disk Performance" -TestResult ($script:_filesystems | Where-Object {$_.target -eq $DBLogDir}).MaxMBPS -ExptectedResult ">= 250 MByte/s" -Status "ERROR"  -MicrosoftDocs $_saphanastorageurl -ErrorCategory "ERROR"
        }

        if ($_filesystem_hana.fstype -eq 'xfs') {

            ## getting disks for /hana/log
            if ($_filesystem_hana_type -eq "lvm") {
                $_AzureDisks_hana = ($_AzureDisks | Where-Object {$_.VolumeGroup -in $_filesystem_hana.vg})
            }
            else {
                $_AzureDisks_for_hanalog_filesystems = $script:_filesystems | Where-Object {$_.target -in $DBLogDir}
                $_AzureDisks_hana = ($_AzureDisks | Where-Object { $_.DeviceName -in $_AzureDisks_for_hanalog_filesystems.Source})
            }
            $_FirstDisk = $_AzureDisks_hana[0]

            # checking if IOPS need to be checked (Ultra Disk)
            if ($_FirstDisk.StorageType -eq "UltraSSD_LRS") {

                if ($_filesystem_hana.fstype -in @('xfs')) {
                    if ( (($script:_filesystems | Where-Object {$_.target -in $DBLogDir}).MaxIOPS | Measure-Object -Sum).Sum -ge $_jsonconfig.HANAStorageRequirements.HANALogIOPS) {
                        AddCheckResultEntry -CheckID "HDB-FS-0009" -Description "SAP HANA Log: Disk Performance" -TestResult ($script:_filesystems | Where-Object {$_.target -eq $DBLogDir}).MaxIOPS -ExptectedResult ">= 2000 IOPS" -Status "OK"  -MicrosoftDocs $_saphanastorageurl
                    }
                    else {
                        AddCheckResultEntry -CheckID "HDB-FS-0009" -Description "SAP HANA Log: Disk Performance" -TestResult ($script:_filesystems | Where-Object {$_.target -eq $DBLogDir}).MaxIOPS -ExptectedResult ">= 2000 IOPS" -Status "ERROR"  -MicrosoftDocs $_saphanastorageurl -ErrorCategory "ERROR"
                    }
                }

            }

            # check if stripe size check required (no of disks greater than 1 in VG)
            if (($_AzureDisks_hana.count -gt 1) -and ($_filesystem_hana_type -eq "lvm")) {
                $_HANAStripeSize = $_jsonconfig.HANAStorageRequirements.HANALogStripeSize

                if ($_filesystem_hana.StripeSize -eq $_HANAStripeSize) {
                    # stripe size correct
                    AddCheckResultEntry -CheckID "HDB-FS-0010" -Description "SAP HANA Log: stripe size" -AdditionalInfo ("Disk " + $_FirstDisk.name) -TestResult $_filesystem_hana.StripeSize -ExptectedResult $_HANAStripeSize -Status "OK" -MicrosoftDocs $_saphanastorageurl
                }
                else {
                    # Wrong Disk Type
                    AddCheckResultEntry -CheckID "HDB-FS-0010" -Description "SAP HANA Log: stripe size" -AdditionalInfo ("Disk " + $_FirstDisk.name) -TestResult $_filesystem_hana.StripeSize -ExptectedResult $_HANAStripeSize -Status "ERROR" -MicrosoftDocs $_saphanastorageurl -ErrorCategory "ERROR"
                }
            }

            foreach ($_AzureDisk_hana in $_AzureDisks_hana) {

                if ($_AzureDisk_hana.Disktype -eq $_FirstDisk.Disktype) {
                    # disk type correct
                    AddCheckResultEntry -CheckID "HDB-FS-0011" -Description "SAP HANA Log: same disk type" -AdditionalInfo ("Disk " + $_AzureDisk_hana.name) -TestResult $_AzureDisk_hana.Disktype -ExptectedResult $_FirstDisk.Disktype -Status "OK" -MicrosoftDocs $_saphanastorageurl
                }
                else {
                    # Wrong Disk Type
                    AddCheckResultEntry -CheckID "HDB-FS-0011" -Description "SAP HANA Log: same disk type" -AdditionalInfo ("Disk " + $_AzureDisk_hana.name) -TestResult $_AzureDisk_hana.Disktype -ExptectedResult $_FirstDisk.Disktype -Status "ERROR" -MicrosoftDocs $_saphanastorageurl -ErrorCategory "ERROR"

                }

                if ($_AzureDisk_hana.PERFORMANCETIER -eq $_FirstDisk.PERFORMANCETIER) {
                    # disk type correct
                    AddCheckResultEntry -CheckID "HDB-FS-0012" -Description "SAP HANA Log: same disk performance type" -AdditionalInfo ("Disk " + $_AzureDisk_hana.name) -TestResult $_AzureDisk_hana.PERFORMANCETIER -ExptectedResult $_FirstDisk.PERFORMANCETIER -Status "OK" -MicrosoftDocs $_saphanastorageurl

                }
                else {
                    # Wrong Disk Type
                    AddCheckResultEntry -CheckID "HDB-FS-0012" -Description "SAP HANA Log: same disk performance type" -AdditionalInfo ("Disk " + $_AzureDisk_hana.name) -TestResult $_AzureDisk_hana.PERFORMANCETIER -ExptectedResult $_FirstDisk.PERFORMANCETIER -Status "ERROR" -MicrosoftDocs $_saphanastorageurl -ErrorCategory "ERROR"
                }

                if ($_AzureDisk_hana.StorageType -eq "Premium_LRS") {
                    
                    # Premium Disk - Check for Write Accelerator
                    if ($_AzureDisk_hana.WriteAccelerator -eq "true") {
                        AddCheckResultEntry -CheckID "HDB-FS-0013" -Description "SAP HANA Log: Write Accelerator enabled" -AdditionalInfo ("Disk " + $_AzureDisk_hana.name) -TestResult $_AzureDisk_hana.WriteAccelerator -ExptectedResult "true" -Status "OK"  -MicrosoftDocs $_saphanastorageurl
                    }
                    else {
                        AddCheckResultEntry -CheckID "HDB-FS-0013" -Description "SAP HANA Log: Write Accelerator enabled" -AdditionalInfo ("Disk " + $_AzureDisk_hana.name) -TestResult $_AzureDisk_hana.WriteAccelerator -ExptectedResult "true" -Status "ERROR"  -MicrosoftDocs $_saphanastorageurl -ErrorCategory "ERROR"
                    }
                }
                
                # setting storage type for later checks
                $script:_StorageType += $_AzureDisk_hana.StorageType

            }
        }
        elseif (($_filesystem_hana.fstype -eq 'nfs') -or ($_filesystem_hana.fstype -eq 'nfs4')) {

            $script:_StorageType += "ANF"

            ## /hana/data is on NFS
            
        }
        else {
            ## file system not found
        }


        # check /hana/shared directory
        $_filesystem_hana = $_filesystems | Where-Object {$_.target -eq $DBSharedDir}

        if ($_filesystem_hana.fstype -in @('xfs','nfs','nfs4')) {
            AddCheckResultEntry -CheckID "HDB-FS-0014" -Description "SAP HANA Shared: File System" -TestResult $_filesystem_hana.fstype -ExptectedResult "xfs, nfs or nfs4" -Status "OK"  -MicrosoftDocs $_saphanastorageurl
        }
        else {
            AddCheckResultEntry -CheckID "HDB-FS-0014" -Description "SAP HANA Shared: File System" -TestResult $_filesystem_hana.fstype -ExptectedResult "xfs, nfs or nfs4" -Status "ERROR"  -MicrosoftDocs $_saphanastorageurl -ErrorCategory "ERROR"
        }
    }


    # remove duplicates from used storage types
    $script:_StorageType = $script:_StorageType | Select-Object -Unique

    if (($VMDatabase -eq "HANA") -and ($script:_StorageType.Length -lt 1)) {
        Write-Host "please check your parameters, HANA directories not found"
        exit
    }


    # run checks from JSON file
    foreach ($_check in $_jsonconfig.Checks) {

        # does the check apply to this system?
        if ( $_check.OS.Contains($VMOperatingSystem) -and `
          $_check.DB.Contains($VMDatabase) -and `
          $_check.Role.Contains($VMRole) -and `
          ( $_check.OSVersion.Contains("all") -or $_check.OSVersion.Contains($VMOSRelease)) -and `
          (((Compare-Object -ReferenceObject $_check.StorageType -DifferenceObject $script:_StorageType -IncludeEqual -ExcludeDifferent) | Measure-Object ).count -gt 0) -and `
          $_check.Hardwaretype.Contains($Hardwaretype)) {

            # check if check applies to HA or not and if HA check for HA-Agent
            if (($_check.HighAvailability.Contains($false)) -or (($_check.HighAvailability.Contains($HighAvailability)) -and ($_check.HighAvailabilityAgent.Contains($HighAvailabilityAgent)))) {

                $_Check_row = "" | Select-Object CheckID, Description, AdditionalInfo, Testresult, ExpectedResult, Status, SAPNote, MicrosoftDocs

                $_result = RunCommand -p $_check

                $_result = RemoveTabsAndSpaces -OriginalString $_result

                $_Check_row.CheckID = $_check.CheckID
                $_Check_row.Description = $_check.Description
                $_Check_row.AdditionalInfo = $_check.AdditionalInfo
                $_Check_row.Testresult = $_result
                $_Check_row.ExpectedResult = $_check.ExpectedResult

                if ($_check.SAPNote -ne "") {
                    $_Check_row.SAPNote = "::SAPNOTEHTML1::" + $_check.SAPNote + "::SAPNOTEHTML2::" + $_check.SAPNote + "::SAPNOTEHTML3::"
                }
                
                if ($_result -eq $_check.ExpectedResult) {
                    $_Check_row.Status = "OK"
                }
                else {
                    # $_Check_row.Status = "ERROR"
                    $_Check_row.Status = $_check.ErrorCategory
                }
                
                if (($_check.ShowAlternativeRequirement) -ne "" -or ($_check.ShowAlternativeResult -ne ""))
                {
                    if ($_check.ShowAlternativeResult -ne "") {
                        $_Check_row.Testresult = Invoke-Expression $_check.ShowAlternativeResult
                    }
                    else {
                        $_Check_row.Testresult = ""
                    }
                    if ($_check.ShowAlternativeRequirement -ne "") {
                        $_Check_row.ExpectedResult = Invoke-Expression $_check.ShowAlternativeRequirement
                    }
                    else {
                        $_Check_row.ExpectedResult = ""
                    }
                }
            
                $script:_Checks += $_Check_row
            }
        }
    }


    $_ChecksOutput = $script:_Checks | ConvertTo-Html -Property * -Fragment -PreContent "<br><h2 id=""Checks"">Check Results</h2>"

    # replace the placeholders for HTML links with HTML content
    ## SAP Part
    $_ChecksOutput = $_ChecksOutput -replace '<td>OK</td>','<td class="StatusOK">OK</td>'
    $_ChecksOutput = $_ChecksOutput -replace '<td>ERROR</td>','<td class="StatusError">ERROR</td>'
    $_ChecksOutput = $_ChecksOutput -replace '<td>WARNING</td>','<td class="StatusWarning">WARNING</td>'
    $_ChecksOutput = $_ChecksOutput -replace '<td>INFO</td>','<td class="StatusInfo">INFO</td>'
    $_ChecksOutput = $_ChecksOutput -replace '::SAPNOTEHTML1::','<a href="https://launchpad.support.sap.com/#/notes/'
    $_ChecksOutput = $_ChecksOutput -replace '::SAPNOTEHTML2::','" target="_blank">'
    $_ChecksOutput = $_ChecksOutput -replace '::SAPNOTEHTML3::','</a>'

    ## MSFT part
    $_ChecksOutput = $_ChecksOutput -replace '::MSFTDOCS1::','<a href="'
    $_ChecksOutput = $_ChecksOutput -replace '::MSFTDOCS2::','" target="_blank">'
    $_ChecksOutput = $_ChecksOutput -replace '::MSFTDOCS3::','</a>'

    $script:_Content += "<a href=""#Checks"">Check Results</a><br>"

    return $_ChecksOutput

}

# collect file system infos
function CollectFileSystems {

    if ($VMOperatingSystem -eq "Windows") {
        # future Windows code
    }
    else {
        # linux systems

        # run findmnt command on OS
        $_command = PrepareCommand -Command "findmnt -r -n" -CommandType "OS"
        $script:_findmnt = RunCommand -p $_command
        $script:_findmnt = ConvertFrom-String_findmnt -p $script:_findmnt 

        # run df command on OS
        $_command = PrepareCommand -Command "df -BG" -CommandType "OS"
        $script:_filesystemfree = RunCommand -p $_command 
        $script:_filesystemfree = ConvertFrom-String_df -p $script:_filesystemfree 

        # new empty object for file systems
        $script:_filesystems = @()

        # loop through df command output
        foreach ($_filesystem in $_filesystemfree) {

            # new empty object for file system entry
            $_filesystem_row = "" | Select-Object Target,Source,FSType,VG,Options,Size,Free,Used,UsedPercent,MaxMBPS,MaxIOPS,StripeSize

            $_filesystem_row.Target = $_filesystem.Mountpoint
            $_filesystem_row.Source = $_filesystem.Filesystem
            $_filesystem_row.FSType = ($script:_findmnt | Where-Object {$_.target -eq $_filesystem.Mountpoint}).fstype
            $_filesystem_row.Options = ($script:_findmnt | Where-Object {$_.target -eq $_filesystem.Mountpoint}).options
            $_filesystem_row.Size = $_filesystem.Size
            $_filesystem_row.Free = $_filesystem.Free
            $_filesystem_row.Used = $_filesystem.Used
            $_filesystem_row.UsedPercent = $_filesystem.UsedPercent
            $_filesystem_row.VG = ($script:_lvmvolumes | Where-Object { $_.dmpath -eq $_filesystem.Filesystem}).vgname
            $_filesystem_row.StripeSize = ($script:_lvmvolumes | Where-Object { $_.dmpath -eq $_filesystem.Filesystem}).stripesize

            if (($_filesystem_row.FSType -eq "nfs") -or ($_filesystem_row.FSType -eq "nfs4")) {
                # NFS ANF volumes need throughput values from ANF infos
                $_filesystem_row.MaxMBPS = ($script:_ANFVolumes | Where-Object { $_.NFSAddress -eq $_filesystem_row.Source}).THROUGHPUTMIBPS
            }
            else {
                if ($_filesystem.Filesystem.StartsWith("/dev/sd")) {
                    # add IOPS and MBPS from disk infos
                    $_filesystem_row.MaxMBPS = ($script:_AzureDisks | Where-Object { $_.DeviceName -eq $_filesystem_row.Source}).MBPS
                    $_filesystem_row.MaxIOPS = ($script:_AzureDisks | Where-Object { $_.DeviceName -eq $_filesystem_row.Source}).IOPS
                }
                else {
                    # add IOPS and MBPS from LVM infos
                    $_filesystem_row.MaxMBPS = ($script:_lvmgroups | Where-Object { $_.name -eq $_filesystem_row.VG}).TotalMBPS
                    $_filesystem_row.MaxIOPS = ($script:_lvmgroups | Where-Object { $_.name -eq $_filesystem_row.VG}).TotalIOPS
                }
            }

            $script:_filesystems += $_filesystem_row

        }

    }

    # create HTML output
    $_FilesystemsOutput = $script:_filesystems | ConvertTo-Html -Property * -Fragment -PreContent "<br><h2 id=""Filesystems"">Filesystems</h2>This section shows you the file systems available on the VM."

    # add entry in HTML index
    $script:_Content += "<a href=""#Filesystems"">Filesystems</a><br>"

    return $_FilesystemsOutput

}

# collect ANF volume information
function CollectANFVolumes {

    # if ANF parameters are defined it will query for ANF data
    if ($ANFAccountName -and $ANFResourceGroup) {

        # empty object for ANF volumes
        $script:_ANFVolumes = @()

        # get ANF Account
        $_ANFAccount = Get-AzNetAppFilesAccount -ResourceGroupName $ANFResourceGroup -Name $ANFAccountName

        # get all ANF Pools in ANF Account
        $_ANFPools = Get-AzNetAppFilesPool -ResourceGroupName $ANFResourceGroup -AccountName $_ANFAccount.Name

        # loop through pools
        foreach ($_ANFpool in $_ANFPools) {

            # the poolname is inside the string (ANFAccountName/ANFPoolName)
            # remove the ANF Accodunt name
            $_ANFPoolName = $_ANFpool.Name -replace $_ANFAccount.Name,''
            # remove the '/' from the string
            $_ANFPoolName = $_ANFPoolName -replace '/',''
            
            $_ANFVolumesInPool = Get-AzNetAppFilesVolume -ResourceGroupName $ANFResourceGroup -AccountName $ANFAccountName -PoolName $_ANFPoolName

            foreach ($_ANFVolume in $_ANFVolumesInPool) {

                $_ANFVolume_row = "" | Select-Object Name,Pool,ServiceLevel,ThroughputMibps,ProtocolTypes,NFSAddress,QoSType,Id

                $_ANFVolume_row.Id = $_ANFVolume.Id
                $_ANFVolume_row.Name = ($_ANFVolume.Name -split '/')[2]
                $_ANFVolume_row.Pool = $_ANFPoolName
                $_ANFVolume_row.ServiceLevel = $_ANFVolume.ServiceLevel
                $_ANFVolume_row.ProtocolTypes = [string]$_ANFVolume.ProtocolTypes
                $_ANFVolume_row.ThroughputMibps = [int]$_ANFVolume.ThroughputMibps
                $_ANFVolume_row.QoSType = $_ANFPool.QosType
                $_ANFVolume_row.NFSAddress = $_ANFVolume.MountTargets[0].IpAddress + ":/" + $_ANFVolume_row.Name

                $Script:_ANFVolumes += $_ANFVolume_row

            }

        }

        $_linecounter = 0
        foreach ($_filesystem_row in $script:_filesystems) {

            if ($_filesystem_row.fstype -contains "nfs") {
                $script:_filesystems[$_linecounter].MaxMBPS = ($script:_ANFVolumes | Where-Object {$_.NFSAddress -eq $_filesystem_row.Source}).THROUGHPUTMIBPS
            }
            $_linecounter += 1

        }

        $_ANFVolumesOutput = $Script:_ANFVolumes | ConvertTo-Html -Property * -Fragment -PreContent "<br><h2 id=""ANF"">Azure NetApp Files</h2>" 

        $script:_Content += "<a href=""#ANF"">Azure NetApp Files</a><br>"

        return $_ANFVolumesOutput

    }
    else {
        return ""
    }
}

function CollectFooter {

    $_Footer = @()

    $_Footer_row = "" | Select-Object Parameter
    $_Footer_row.Parameter = "<subscriptionid>$script:_SubscriptionID</subscriptionid>"
    $_Footer += $_Footer_row

    $_Footer_row = "" | Select-Object Parameter
    $_Footer_row.Parameter = "<subscriptionname>$script:_SubscriptionName</subscriptionname>"
    $_Footer += $_Footer_row

    $_Footer_row = "" | Select-Object Parameter
    $_Footer_row.Parameter = "<vmname>$script:_VMName</vmname>"
    $_Footer += $_Footer_row

    $_FooterContent = $_Footer | ConvertTo-Html -Property * -Fragment -PreContent "<br><h2 id=""SupportInfo"">Info for Support Cases</h2>" 

    return $_FooterContent

}

#########
# Main module
#########

    # load json configuration
    $_jsonconfig = Get-Content -Raw -Path $ConfigFileName -ErrorAction Stop | ConvertFrom-Json
    if ($scriptversion -eq $_jsonconfig.Version) {
        # everything ok, script and json version match
    }
    else {
        Write-Host "Versions of script and json file don't match"
        exit
    }

    # parameter check and modification if required

    if ($VMOperatingSystem -in @("SUSE","RedHat","OracleLinux"))
    {
        #check if filesystem parameters end with /
        if ($DBDataDir.EndsWith("/")) {
            $DBDataDir = $DBDataDir.Substring(0,$DBDataDir.Length-1)
        }
        if ($DBLogDir.EndsWith("/")) {
            $DBLogDir = $DBLogDir.Substring(0,$DBLogDir.Length-1)
        }
        if ($DBSharedDir.EndsWith("/")) {
            $DBSharedDir = $DBSharedDir.Substring(0,$DBSharedDir.Length-1)
        }
    }

    # Check for required PowerShell modules
    CheckRequiredModules

    # Check TCP connectivity
    CheckTCPConnectivity

    # Check Azure connectivity
    CheckAzureConnectivity

    # Connect to VM
    $_SessionID = ConnectVM

    # Load HTML Header
    LoadHTMLHeader

    # Collect Script Parameters
    $_CollectScriptParameter = CollectScriptParameters

    # Collect VM info
    $_CollectVMInfo = CollectVMInformation

    # Get Azure Disks assigned to VMs
    $_CollectVMStorage = CollectVMStorage

    # Get Volume Groups - CollectVMStorage needs to run first to define variables
    $_CollectLVMGroups = CollectLVMGroups

    # Get Logical Volumes - CollectVMStorage needs to run first to define variables
    $_CollectLVMVolumes = CollectLVMVolummes

    # Get ANF Volume Info
    $_CollectANFVolumes = CollectANFVolumes

    # Get Filesystems
    $_CollectFileSystems = CollectFileSystems

    # Get Network Interfaces
    $_CollectNetworkInterfaces = CollectNetworkInterfaces

    # Get Load Balancer - CollectNetworkInterfaces needs to run first to define variables
    $_CollectLoadBalancer = CollectLoadBalancer

    # run Quality Check
    $_RunQualityCheck = RunQualityCheck

    # Collect VM info
    $_CollectVMInfoAdditional = CollectVMInformationAdditional

    # Collect footer for support cases
    $_CollectFooter = CollectFooter


    $_HTMLReport = ConvertTo-Html -Body "$_Content $_CollectScriptParameter $_CollectVMInfo $_RunQualityCheck $_CollectFileSystems $_CollectVMStorage $_CollectLVMGroups $_CollectLVMVolumes $_CollectANFVolumes $_CollectNetworkInterfaces $_CollectLoadBalancer $_CollectVMInfoAdditional $_CollectFooter" -Head $script:_HTMLHeader -Title "SAP on Azure Quality Check" -PostContent "<p id='CreationDate'>Creation Date: $(Get-Date)</p><p id='CreationDate'>Script Version: $scriptversion</p>"
    $_HTMLReportFileName = $AzVMName + "-" + $(Get-Date -Format "yyyyMMdd-HHmm") + ".html"
    $_HTMLReport | Out-File .\$_HTMLReportFileName

    Remove-SSHSession -SessionId $_SessionID | Out-Null
    exit

