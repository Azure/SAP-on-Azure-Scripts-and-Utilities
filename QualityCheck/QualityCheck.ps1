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
#$scriptversion = 3


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




</style>
"@


    $script:_Content  = "<h1>SAP on Azure Quality Check</h1><h2>Use the links to jump to the section:</h2>"

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
            }

        }
        else {
            # Get-Module didn't come back with a result
            Write-Host "Please install" $_requiredmodule.ModuleName "with version greater than" $_requiredmodule.Version
        }
    }
}

function CheckTCPConnectivity {

    if ($VMOperatingSystem -eq "Windows") {

    }
    else {
        # Linux Systems
        $_testresult = Test-NetConnection -ComputerName $VMHostname -Port $VMConnectionPort
        if ($_testresult.TcpTestSucceeded -eq $true) {
            Write-Host "Successfully connected"
        }
        else {
            Write-Host "Error connecting, please check network connection"
        }
    }
}

function ConnectVM {
    
    if ($VMOperatingSystem -eq "Windows") {
        # Connect to Windows

        # New-PSSession in the future

    }
    else {
        
        
        $script:_ClearTextPassword = ConvertFrom-SecureString -SecureString $VMPassword -AsPlainText
        $script:_credentials = New-Object System.Management.Automation.PSCredential ($VMUsername, $VMPassword);
        $script:_sshsession = New-SSHSession -ComputerName $VMHostname -Credential $_credentials -Port $VMConnectionPort -AcceptKey -ConnectionTimeout 5

        $_sshsession.SessionId
    }

}

function CollectScriptParameters {

    $_outputarray = @()

    $_outputarray_row = "" | Select-Object Parameter,Value
    $_outputarray_row.Parameter = "Operating System"
    $_outputarray_row.Value = $VMOperatingSystem
    $_outputarray += $_outputarray_row

    $_outputarray_row = "" | Select-Object Parameter,Value
    $_outputarray_row.Parameter = "Database"
    $_outputarray_row.Value = $VMDatabase
    $_outputarray += $_outputarray_row

    $_outputarray_row = "" | Select-Object Parameter,Value
    $_outputarray_row.Parameter = "VM Role"
    $_outputarray_row.Value = $VMRole
    $_outputarray += $_outputarray_row

    $_outputarray_row = "" | Select-Object Parameter,Value
    $_outputarray_row.Parameter = "Azure Resource Group"
    $_outputarray_row.Value = $AzVMResourceGroup
    $_outputarray += $_outputarray_row

    $_outputarray_row = "" | Select-Object Parameter,Value
    $_outputarray_row.Parameter = "Azure VM Name"
    $_outputarray_row.Value = $AzVMName
    $_outputarray += $_outputarray_row

    $_outputarray_row = "" | Select-Object Parameter,Value
    $_outputarray_row.Parameter = "VM Hostname / IP Address"
    $_outputarray_row.Value = $VMHostname
    $_outputarray += $_outputarray_row

    $_outputarray_row = "" | Select-Object Parameter,Value
    $_outputarray_row.Parameter = "VM Username"
    $_outputarray_row.Value = $VMUsername
    $_outputarray += $_outputarray_row

    $_outputarray_row = "" | Select-Object Parameter,Value
    $_outputarray_row.Parameter = "Hardware Type"
    $_outputarray_row.Value = $Hardwaretype
    $_outputarray += $_outputarray_row

    $_outputarray_row = "" | Select-Object Parameter,Value
    $_outputarray_row.Parameter = "High Availability Check"
    $_outputarray_row.Value = $HighAvailability
    $_outputarray += $_outputarray_row

    $_outputarray_row = "" | Select-Object Parameter,Value
    $_outputarray_row.Parameter = "Quality Check Config File"
    $_outputarray_row.Value = $ConfigFileName
    $_outputarray += $_outputarray_row

    if ($VMDatabase -eq "HANA") {
        $_outputarray_row = "" | Select-Object Parameter,Value
        $_outputarray_row.Parameter = "SAP HANA Scenario"
        $_outputarray_row.Value = $HANADeployment
        $_outputarray += $_outputarray_row    
    }

    if ($HighAvailability -eq $true) {
        $_outputarray_row = "" | Select-Object Parameter,Value
        $_outputarray_row.Parameter = "Fencing Mechansim"
        $_outputarray_row.Value = $HighAvailabilityAgent
        $_outputarray += $_outputarray_row    
    }

    $_outputarray = $_outputarray | ConvertTo-Html -Property * -Fragment -PreContent "<br><h2 id=""ScriptParameter"">Script Parameters</h2>Here are the parameters handed over to the script"
    $_outputarray = $_outputarray.Replace("::","<br/>")

    $script:_Content += "<a href=""#ScriptParameter"">Script Parameter</a><br>"

    $_outputarray



}

function CollectVMInformation {

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

                    $_outputarray_row = "" | Select-Object CheckID, Description, Output
                    $_outputarray_row.CheckID = $_CollectVMInformationCheck.CheckID
                    $_outputarray_row.Description = $_CollectVMInformationCheck.Description
                    $_outputarray_row.Output = $_output -join ';;:;;'

                    $_outputarray += $_outputarray_row
                }
            }
        }
    }

    $_outputarray = $_outputarray | ConvertTo-Html -Property * -Fragment -PreContent "<br><h2 id=""VMInfo"">Collect VM Information</h2>This section collects basic information of the VM"
    $_outputarray = $_outputarray.Replace(";;:;;","<br/>")

    return $_outputarray

}

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
                    #$_outputarray_row.CheckID = $_CollectVMInformationCheck.CheckID
                    #$_outputarray_row.Description = $_CollectVMInformationCheck.Description
                    $_outputarray_row.Output = $_output -join ';;:;;'
                    #$_outputarray_row.Output = $_output

                    $_outputarray += $_outputarray_row
                }
            }

        $_htmllink = "additionalinfo" + $_counter
        $_description = $_CollectVMInformationCheck.Description
        $_outputarray = $_outputarray | ConvertTo-Html -Property * -Fragment -PreContent "<br><h2 id=""$_htmllink"">$_description</h2>"
        $script:_Content += "<a href=""#$_htmllink"">$_description</a><br>"
        $_outputarray = $_outputarray.Replace(";;:;;","<br/>")

        $_counter += 1
        $_outputarray_total += $_outputarray

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


    if ($p.CommandType -eq "OS") {
    
        if ($VMOperatingSystem -eq "Windows") {
            # Windows
        }
        else {
            # Linux

            if ($p.RootRequired) {
                $_command = "echo $_ClearTextPassword | sudo -S " + $p.ProcessingCommand
                # $_command = "sudo -S <<< $_ClearTextPassword " + $p.ProcessingCommand
            }
            else {
                $_command = $p.ProcessingCommand
            }

            $_result = Invoke-SSHCommand -Command $_command -SessionId $script:_SessionID
            $_result = $_result.Output
        
            if (($p.PostProcessingCommand -ne "") -or ($p.PostProcessingCommand)) {
        
                $_command = $p.PostProcessingCommand
                $_command = $_command -replace "PARAMETER",$_result
                $_result = Invoke-Expression $_command
        
            }
        
            return $_result
        }
    }

    if ($p.CommandType -eq "PowerShell") {

        $_command =  $p.ProcessingCommand 
        
        $_result = Invoke-Expression $_command

        if (($p.PostProcessingCommand -ne "") -or ($p.PostProcessingCommand)) {
        
            $_command = $p.PostProcessingCommand
            $_command = $_command -replace "PARAMETER",$_result
            $_result = Invoke-Expression $_command
    
        }

        return $_result
    }
}

function CheckAzureConnectivity {

    $_VMinfo = Get-AzVM -ResourceGroupName $AzVMResourceGroup -Name $AzVMName -ErrorAction SilentlyContinue

    if ($_VMinfo) {

        # connected to Azure

    }
    else {

        Write-Host "Please connect to Azure using the Connect-AzAccount command, if you are connected use the Select-AzSubscription command to set the correct context"
        exit

    }

}

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

    $_performancetype = switch ($tier) {
        Premium_LRS { 'P' }
        UltraSSD_LRS { 'U' }
        Standard_LRS { 'S' }
        StandardSSD_LRS { 'E' }
        Default {}
    }

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

        # collect LVM configuration
        $_command = PrepareCommand -Command "lvm fullreport --reportformat json" 
        $script:_lvmconfig = RunCommand -p $_command | ConvertFrom-Json

        $_command = PrepareCommand -Command "sg_map -x" -CommandType "OS"
        $script:_diskmapping = RunCommand -p $_command | ConvertFrom-String

        $_command = PrepareCommand -Command "curl --noproxy '*' -H Metadata:true 'http://169.254.169.254/metadata/instance/compute/storageProfile?api-version=2019-08-15'"
        $script:_azurediskconfig = RunCommand -p $_command | ConvertFrom-Json

        $_command = PrepareCommand -Command "Get-AzDisk -ResourceGroupName $AzVMResourceGroup" -CommandType "PowerShell"
        $script:_AzureDiskDetails = RunCommand -p $_command

        $script:_AzureDisks = @()

        if ($VMGeneration -eq "Gen1") {
            $script:_DataDiskSCSIControllerID = 5
        }
        else {
            $script:_DataDiskSCSIControllerID = 1
        }

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
        $_AzureDisk_row.DeviceName = "/dev/sda"
        $_AzureDisk_row.VolumeGroup = ($script:_lvmconfig.report | Where-Object {$_.pv.pv_name -eq $_AzureDisk_row.DeviceName}).vg.vg_name

        $script:_AzureDisks += $_AzureDisk_row

        foreach ($_datadisk in $script:_azurediskconfig.dataDisks) {
            $_AzureDisk_row = "" | Select-Object LUNID, Name, DeviceName, VolumeGroup, Size, DiskType, IOPS, MBPS, PerformanceTier, StorageType, Caching, WriteAccelerator

            $_AzureDisk_row.LUNID = $_datadisk.lun
            $_AzureDisk_row.Name = $_datadisk.name
            $_AzureDisk_row.Size = $_datadisk.DiskSizeGB
            $_AzureDisk_row.StorageType = $_datadisk.managedDisk.storageAccountType
            $_AzureDisk_row.Caching = $_datadisk.caching
            $_AzureDisk_row.WriteAccelerator = $_datadisk.writeAcceleratorEnabled

            $_AzureDisk_row.DeviceName = ($script:_diskmapping | Where-Object { ($_.P5 -eq $_datadisk.lun) -and ($_.P2 -eq $script:_DataDiskSCSIControllerID) }).P7
            $_AzureDisk_row.VolumeGroup = ($script:_lvmconfig.report | Where-Object {$_.pv.pv_name -eq $_AzureDisk_row.DeviceName}).vg.vg_name

            $_AzureDisk_row.IOPS = ($_AzureDiskDetails | Where-Object { $_.Name -eq $_datadisk.name }).DiskIOPSReadWrite
            $_AzureDisk_row.MBPS = ($_AzureDiskDetails | Where-Object { $_.Name -eq $_datadisk.name }).DiskMBpsReadWrite
            $_AzureDisk_row.PerformanceTier = ($_AzureDiskDetails | Where-Object { $_.Name -eq $_datadisk.name }).Tier

            $_AzureDisk_row.DiskType = CalculateDiskTypeSKU -size $_datadisk.DiskSizeGB -tier $_datadisk.managedDisk.storageAccountType

            $script:_AzureDisks += $_AzureDisk_row

        }

    }
    
    $script:_AzureDisksOutput = $script:_AzureDisks | ConvertTo-Html -Property * -Fragment -PreContent "<br><h2 id=""VMStorage"">Collect VM Storage Information</h2>This table contains the disks directly attached to the VM"

    $script:_Content += "<a href=""#VMStorage"">VM Storage</a><br>"

    return $script:_AzureDisksOutput

}

function CollectLVMGroups {

    $script:_lvmgroups = @()

    foreach ($_lvmgroup in $script:_lvmconfig.report) {

        $_lvmgroup_row = "" | Select-Object Name,Disks,LogicalVolumes,Totalsize,TotalIOPS,TotalMBPS

        $_lvmgroup_row.Name = $_lvmgroup.vg.vg_name
        $_lvmgroup_row.Disks = $_lvmgroup.vg.pv_count
        $_lvmgroup_row.LogicalVolumes = $_lvmgroup.vg.lv_count
        $_lvmgroup_row.Totalsize = $_lvmgroup.vg.vg_size
        $_lvmgroup_row.TotalIOPS = ($script:_AzureDisks | Where-Object { $_.VolumeGroup -eq $_lvmgroup.vg.vg_name } | Measure-Object -Property IOPS -Sum).Sum
        $_lvmgroup_row.TotalMBPS = ($script:_AzureDisks | Where-Object { $_.VolumeGroup -eq $_lvmgroup.vg.vg_name } | Measure-Object -Property MBPS -Sum).Sum

        $script:_lvmgroups += $_lvmgroup_row

    }

    $script:_lvmgroupsOutput = $script:_lvmgroups | ConvertTo-Html -Property * -Fragment -PreContent "<br><h2 id=""LVMGroups"">Collect LVM Groups Information</h2>"

    $script:_Content += "<a href=""#LVMGroups"">LVM Groups</a><br>"

    return $script:_lvmgroupsOutput

}

function CollectLVMVolummes {

    $script:_lvmvolumes = @()

    foreach ($_lvmgroup in $script:_lvmconfig.report) {

        if ($_lvmgroup.vg.vg_name -ne "rootvg") {
            foreach ($_lvmvolume in $_lvmgroup.lv) {
                        
                $_lvmvolume_row = "" | Select-Object Name,VGName,LVPath,DMPath,Layout,Size,Stripesize,Stripes
                $_lvmvolume_row.Name = $_lvmvolume.lv_name
                $_lvmvolume_row.VGName = $_lvmgroup.vg.vg_name
                $_lvmvolume_row.LVPath = $_lvmvolume.lv_path
                $_lvmvolume_row.DMPath = $_lvmvolume.lv_dm_path
                $_lvmvolume_row.Layout = $_lvmvolume.lv_layout
                $_lvmvolume_row.Size = $_lvmvolume.lv_size
                $_lvmvolume_row.StripeSize = $_lvmgroup.seg.stripe_size
                $_lvmvolume_row.Stripes = $_lvmgroup.seg.stripes

                $script:_lvmvolumes += $_lvmvolume_row

            }
        }
    }

    $script:_lvmvolumesOutput = $script:_lvmvolumes | ConvertTo-Html -Property * -Fragment -PreContent "<br><h2 id=""LVMVolumes"">Collect LVM Volume Information</h2>"

    $script:_Content += "<a href=""#LVMVolumes"">LVM Volumes</a><br>"

    return $script:_lvmvolumesOutput


}

function CollectNetworkInterfaces {

    $_VMinfo = Get-AzVM -ResourceGroupName $AzVMResourceGroup -Name $AzVMName -ErrorAction SilentlyContinue

    $script:_NetworkInterfaces = @()

    foreach ($_VMnetworkinterface in $_VMinfo.NetworkProfile.NetworkInterfaces) {

        $_networkinterface = Get-AzNetworkInterface -ResourceId $_VMnetworkinterface.Id

        $_networkinterface_row = "" | Select-Object Name,AcceleratedNetworking,IPForwarding,PrivateIP,NSG

        $_networkinterface_row.Name = $_networkinterface.Name
        $_networkinterface_row.AcceleratedNetworking = $_networkinterface.EnableAcceleratedNetworking
        $_networkinterface_row.IPForwarding = $_networkinterface.EnableIPForwarding
        $_networkinterface_row.PrivateIP = ""

        foreach ($_ipconfig in $_networkinterface.IpConfigurations) {
            $_networkinterface_row.PrivateIP = $_networkinterface_row.PrivateIP + $_ipconfig.PrivateIpAddress + " "
        }

        $_networkinterface_row.NSG = $_networkinterface.NetworkSecurityGroup.Id

        $script:_NetworkInterfaces += $_networkinterface_row

    }

    $script:_NetworkInterfacesOutput = $script:_NetworkInterfaces | ConvertTo-Html -Property * -Fragment -PreContent "<br><h2 id=""NetworkInterfaces"">Collect Network Interfaces</h2>"

    $script:_Content += "<a href=""#NetworkInterfaces"">Network Interfaes</a><br>"

    return $script:_NetworkInterfacesOutput

}

function CollectLoadBalancer {

    $_VMinfo = Get-AzVM -ResourceGroupName $AzVMResourceGroup -Name $AzVMName -ErrorAction SilentlyContinue

    $Script:_LoadBalancers = @()

    foreach ($_VMnetworkinterface in $_VMinfo.NetworkProfile.NetworkInterfaces) {

        $_networkinterface = Get-AzNetworkInterface -ResourceId $_VMnetworkinterface.Id

        foreach ($_ipconfig in $_networkinterface.IpConfigurations) {
            
            foreach ($_loadbalancerbackendpool in $_ipconfig.LoadBalancerBackendAddressPools) {

                $_loadbalancer_row = "" | Select-Object Name,Type,IdleTimeout,FloatingIP,Protocols

                $_loadbalancername = ($_loadbalancerbackendpool.id).Split("/")[8]
                $_loadbalancerresourcegroup = ($_loadbalancerbackendpool.id).Split("/")[4]

                $_loadbalancer = Get-AzLoadBalancer -Name $_loadbalancername -ResourceGroupName $_loadbalancerresourcegroup

                $_loadbalancer_row.Name = $_loadbalancername
                $_loadbalancer_row.Type = $_loadbalancer.Sku
                $_loadbalancer_row.IdleTimeout = $_loadbalancer.LoadBalancingRules[0].IdleTimeoutInMinutes
                $_loadbalancer_row.FloatingIP = $_loadbalancer.LoadBalancingRules[0].EnableFloatingIP
                $_loadbalancer_row.Protocols = $_loadbalancer.LoadBalancingRules[0].Protocol

                $Script:_LoadBalancers += $_loadbalancer_row

            }
        }
    }

    if ($Script:_LoadBalancers) {
        $_LoadBalancerOutput = $script:_LoadBalancers | ConvertTo-Html -Property * -Fragment -PreContent "<br><h2 id=""LoadBalancers"">Collect Load Balancer</h2>"
    }
    else {
        $_loadbalancer_row = "" | Select-Object "Description"
        $_loadbalancer_row.Description = "No load balancer assigned to network interfaeces"
        
        $_LoadBalancerOutput = $_loadbalancer_row | ConvertTo-Html -Property * -Fragment -PreContent "<br><h2 id=""LoadBalancers"">Collect Load Balancer</h2>"
    }

    $script:_Content += "<a href=""#LoadBalancers"">Load Balancer</a><br>"

    return $_LoadBalancerOutput

}

function CalculateKernelVersion {
    Param (
        [string] $kernelversion
    )

    # Linux Kernel Version consist of - and .
    # this module generates a number to compare different kernel versions

    $_kversionarray = @()

    $_kversion = $kernelversion.Replace("-",".")
    $_kversionarray = $_kversion.split(".")
    #$_kversionarray = [System.Int32[]]$_kversionarray

    #$_kversionnumber = $_kversionarray[0]*10000000 + $_kversionarray[1]*100000 + $k_versionarray[2]*1000 + $_kversionarray[3]*100 + $_kversionarray[4]*10
    # $_kversionnumber = [System.Int32]$_kversionarray[0] + [System.Int32]$_kversionarray[1] + [System.Int32]$k_versionarray[2] + [System.Int32]$_kversionarray[3] + [System.Int32]$_kversionarray[4]
    $_kversionnumber = [System.Int32]$_kversionarray[0] * 10000000 + [System.Int32]$_kversionarray[1] * 100000 + [System.Int32]$_kversionarray[2] * 1000 + [System.Int32]$_kversionarray[3] * 100 + [System.Int32]$_kversionarray[4] * 10

    return $_kversionnumber
}

function CheckForKernelVersion {
    Param (
        [string] $startversion,
        [string] $endversion,
        [string] $version
    )

    $_kversionnumberstart = CalculateKernelVersion -kernelversion $startversion
    $_kversionnumberend = CalculateKernelVersion -kernelversion $endversion
    $_kversionnumber = CalculateKernelVersion -kernelversion $version

    if (($_kversionnumber -gt $_kversionnumberstart) -and ($_kversionnumber -lt $_kversionnumberend)) {
        return $true
    }
    else {
        return $false
    }
}

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


function AddCheckResultEntry {

    param (
        [string]$CheckID="NoCheckID",
        [string]$Description="",
        [string]$AdditionalInfo="",
        [string]$TestResult="",
        [string]$ExptectedResult="",
        [string]$Status="",
        [string]$SAPNote="",
        [string]$MicrosoftDocs=""
    )

    $_Check_row = "" | Select-Object CheckID, Description, AdditionalInfo, Testresult, ExpectedResult, Status, SAPNote, MicrosoftDocs

    $_Check_row.CheckID = $CheckID
    $_Check_row.Description = $Description
    $_Check_row.AdditionalInfo = $AdditionalInfo
    $_Check_row.Testresult = $TestResult
    $_Check_row.ExpectedResult = $ExptectedResult
    $_Check_row.Status = $Status
    
    if ($SAPNote -ne "") {
        $_Check_row.SAPNote = "::SAPNOTEHTML1::" + $SAPNote + "::SAPNOTEHTML2::" + $SAPNote + "::SAPNOTEHTML3::"
    }

    if ($MicrosoftDocs -ne "") {
        $_Check_row.MicrosoftDocs = "::MSFTDOCS1::" + $MicrosoftDocs + "::MSFTDOCS2::" + "Link" + "::MSFTDOCS3::"
    }

    $script:_Checks += $_Check_row

}

function RunQualityCheck {

    $script:_Checks = @()
    $script:_StorageType = @()


    # STORAGE CHECKS SAP HANA
    # checking for data disks
    if ($VMDatabase -eq "HANA") {

        ## getting file system for /hana/data
        $_filesystem_hana = ($Script:_filesystems | Where-Object {$_.Target -in $DBDataDir})

        if ($_filesystem_hana.fstype -in @('xfs','nfs','nfs4')) {
            AddCheckResultEntry -CheckID "HDB-1001" -Description "SAP HANA Data: File System" -TestResult $_filesystem_hana.fstype -ExptectedResult "xfs, nfs or nfs4" -Status "OK"  -MicrosoftDocs $_saphanastorageurl
        }
        else {
            AddCheckResultEntry -CheckID "HDB-1001" -Description "SAP HANA Data: File System" -TestResult $_filesystem_hana.fstype -ExptectedResult "xfs, nfs or nfs4" -Status "ERROR"  -MicrosoftDocs $_saphanastorageurl
        }

        if (($script:_filesystems | Where-Object {$_.target -eq $DBDataDir}).MaxMBPS -ge $_jsonconfig.HANAStorageRequirements.HANADataMBPS) {
            AddCheckResultEntry -CheckID "HDB-1002" -Description "SAP HANA Data: Disk Performance" -TestResult ($script:_filesystems | Where-Object {$_.target -eq $DBDataDir}).MaxMBPS -ExptectedResult ">= 400 MByte/s" -Status "OK"  -MicrosoftDocs $_saphanastorageurl
        }
        else {
            AddCheckResultEntry -CheckID "HDB-1002" -Description "SAP HANA Data: Disk Performance" -TestResult ($script:_filesystems | Where-Object {$_.target -eq $DBDataDir}).MaxMBPS -ExptectedResult ">= 400 MByte/s" -Status "ERROR"  -MicrosoftDocs $_saphanastorageurl
        }

        if ($_filesystem_hana.fstype -in @('xfs')) {
            if (($script:_filesystems | Where-Object {$_.target -eq $DBDataDir}).MaxIOPS -ge $_jsonconfig.HANAStorageRequirements.HANADataIOPS) {
                AddCheckResultEntry -CheckID "HDB-1003" -Description "SAP HANA Data: Disk Performance" -TestResult ($script:_filesystems | Where-Object {$_.target -eq $DBDataDir}).MaxIOPS -ExptectedResult ">= 7000 IOPS" -Status "OK"  -MicrosoftDocs $_saphanastorageurl
            }
            else {
                AddCheckResultEntry -CheckID "HDB-1003" -Description "SAP HANA Data: Disk Performance" -TestResult ($script:_filesystems | Where-Object {$_.target -eq $DBDataDir}).MaxIOPS -ExptectedResult ">= 7000 IOPS" -Status "ERROR"  -MicrosoftDocs $_saphanastorageurl
            }
        }

        $_saphanastorageurl = "https://docs.microsoft.com/en-us/azure/virtual-machines/workloads/sap/hana-vm-operations-storage"

        if ($_filesystem_hana.fstype -eq 'xfs') {

            ## getting disks for /hana/data
            $_AzureDisks_hana = ($_AzureDisks | Where-Object {$_.VolumeGroup -in $_filesystem_hana.vg})

            $_FirstDisk = $_AzureDisks_hana[0]

            foreach ($_AzureDisk_hana in $_AzureDisks_hana) {

                if ($_AzureDisk_hana.Disktype -eq $_FirstDisk.Disktype) {
                    # disk type correct
                    AddCheckResultEntry -CheckID "HDB-1004" -Description "SAP HANA Data: same disk type" -AdditionalInfo ("Disk " + $_AzureDisk_hana.name) -TestResult $_AzureDisk_hana.Disktype -ExptectedResult $_FirstDisk.Disktype -Status "OK" -MicrosoftDocs $_saphanastorageurl
                }
                else {
                    # Wrong Disk Type
                    AddCheckResultEntry -CheckID "HDB-1004" -Description "SAP HANA Data: same disk type" -AdditionalInfo ("Disk " + $_AzureDisk_hana.name) -TestResult $_AzureDisk_hana.Disktype -ExptectedResult $_FirstDisk.Disktype -Status "ERROR" -MicrosoftDocs $_saphanastorageurl

                }

                if ($_AzureDisk_hana.PERFORMANCETIER -eq $_FirstDataDisk.PERFORMANCETIER) {
                    # disk type correct
                    AddCheckResultEntry -CheckID "HDB-1005" -Description "SAP HANA Data: same disk performance type" -AdditionalInfo ("Disk " + $_AzureDisk_hana.name) -TestResult $_AzureDisk_hana.Disktype -ExptectedResult $_FirstDisk.Disktype -Status "OK" -MicrosoftDocs $_saphanastorageurl

                }
                else {
                    # Wrong Disk Type
                    AddCheckResultEntry -CheckID "HDB-1005" -Description "SAP HANA Data: same disk performance type" -AdditionalInfo ("Disk " + $_AzureDisk_hana.name) -TestResult $_AzureDisk_hana.Disktype -ExptectedResult $_FirstDisk.Disktype -Status "ERROR" -MicrosoftDocs $_saphanastorageurl
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

        ## getting file system for /hana/log
        $_filesystem_hana = ($Script:_filesystems | Where-Object {$_.Target -in $DBLogDir})

        if ($_filesystem_hana.fstype -in @('xfs','nfs','nfs4')) {
            AddCheckResultEntry -CheckID "HDB-1006" -Description "SAP HANA Log: File System" -TestResult $_filesystem_hana.fstype -ExptectedResult "xfs, nfs or nfs4" -Status "OK"  -MicrosoftDocs $_saphanastorageurl
        }
        else {
            AddCheckResultEntry -CheckID "HDB-1006" -Description "SAP HANA Log: File System" -TestResult $_filesystem_hana.fstype -ExptectedResult "xfs, nfs or nfs4" -Status "ERROR"  -MicrosoftDocs $_saphanastorageurl
        }

        if (($script:_filesystems | Where-Object {$_.target -eq $DBLogDir}).MaxMBPS -ge $_jsonconfig.HANAStorageRequirements.HANALogMBPS) {
            AddCheckResultEntry -CheckID "HDB-1007" -Description "SAP HANA Log: Disk Performance" -TestResult ($script:_filesystems | Where-Object {$_.target -eq $DBLogDir}).MaxMBPS -ExptectedResult ">= 250 MByte/s" -Status "OK"  -MicrosoftDocs $_saphanastorageurl
        }
        else {
            AddCheckResultEntry -CheckID "HDB-1007" -Description "SAP HANA Log: Disk Performance" -TestResult ($script:_filesystems | Where-Object {$_.target -eq $DBLogDir}).MaxMBPS -ExptectedResult ">= 250 MByte/s" -Status "ERROR"  -MicrosoftDocs $_saphanastorageurl
        }

        if ($_filesystem_hana.fstype -in @('xfs')) {
            if (($script:_filesystems | Where-Object {$_.target -eq $DBLogDir}).MaxIOPS -ge $_jsonconfig.HANAStorageRequirements.HANALogIOPS) {
                AddCheckResultEntry -CheckID "HDB-1008" -Description "SAP HANA Log: Disk Performance" -TestResult ($script:_filesystems | Where-Object {$_.target -eq $DBLogDir}).MaxIOPS -ExptectedResult ">= 2000 IOPS" -Status "OK"  -MicrosoftDocs $_saphanastorageurl
            }
            else {
                AddCheckResultEntry -CheckID "HDB-1008" -Description "SAP HANA Log: Disk Performance" -TestResult ($script:_filesystems | Where-Object {$_.target -eq $DBLogDir}).MaxIOPS -ExptectedResult ">= 2000 IOPS" -Status "ERROR"  -MicrosoftDocs $_saphanastorageurl
            }
        }

        if ($_filesystem_hana.fstype -eq 'xfs') {

            ## getting disks for /hana/log
            $_AzureDisks_hana = ($_AzureDisks | Where-Object {$_.VolumeGroup -in $_filesystem_hana.vg})
            $_FirstDisk = $_AzureDisks_hana[0]

            foreach ($_AzureDisk_hana in $_AzureDisks_hana) {

                if ($_AzureDisk_hana.Disktype -eq $_FirstDisk.Disktype) {
                    # disk type correct
                    AddCheckResultEntry -CheckID "HDB-1009" -Description "SAP HANA Log: same disk type" -AdditionalInfo ("Disk " + $_AzureDisk_hana.name) -TestResult $_AzureDisk_hana.Disktype -ExptectedResult $_FirstDisk.Disktype -Status "OK" -MicrosoftDocs $_saphanastorageurl
                }
                else {
                    # Wrong Disk Type
                    AddCheckResultEntry -CheckID "HDB-1009" -Description "SAP HANA Log: same disk type" -AdditionalInfo ("Disk " + $_AzureDisk_hana.name) -TestResult $_AzureDisk_hana.Disktype -ExptectedResult $_FirstDisk.Disktype -Status "ERROR" -MicrosoftDocs $_saphanastorageurl

                }

                if ($_AzureDisk_hana.PERFORMANCETIER -eq $_FirstDisk.PERFORMANCETIER) {
                    # disk type correct
                    AddCheckResultEntry -CheckID "HDB-1010" -Description "SAP HANA Log: same disk performance type" -AdditionalInfo ("Disk " + $_AzureDisk_hana.name) -TestResult $_AzureDisk_hana.PERFORMANCETIER -ExptectedResult $_FirstDisk.PERFORMANCETIER -Status "OK" -MicrosoftDocs $_saphanastorageurl

                }
                else {
                    # Wrong Disk Type
                    AddCheckResultEntry -CheckID "HDB-1010" -Description "SAP HANA Log: same disk performance type" -AdditionalInfo ("Disk " + $_AzureDisk_hana.name) -TestResult $_AzureDisk_hana.PERFORMANCETIER -ExptectedResult $_FirstDisk.PERFORMANCETIER -Status "ERROR" -MicrosoftDocs $_saphanastorageurl
                }

                if ($_AzureDisk_hana.StorageType -eq "Premium_LRS") {
                    
                    # Premium Disk - Check for Write Accelerator
                    if ($_AzureDisks_hana.WriteAccelerator -eq "true") {
                        AddCheckResultEntry -CheckID "HDB-1011" -Description "SAP HANA Log: Write Accelerator enabled" -AdditionalInfo ("Disk " + $_AzureDisk_hana.name) -TestResult $_AzureDisk_hana.WriteAccelerator -ExptectedResult "true" -Status "OK"  -MicrosoftDocs $_saphanastorageurl
                    }
                    else {
                        AddCheckResultEntry -CheckID "HDB-1011" -Description "SAP HANA Log: Write Accelerator enabled" -AdditionalInfo ("Disk " + $_AzureDisk_hana.name) -TestResult $_AzureDisk_hana.WriteAccelerator -ExptectedResult "true" -Status "ERROR"  -MicrosoftDocs $_saphanastorageurl
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
            AddCheckResultEntry -CheckID "HDB-1012" -Description "SAP HANA Shared: File System" -TestResult $_filesystem_hana.fstype -ExptectedResult "xfs, nfs or nfs4" -Status "OK"  -MicrosoftDocs $_saphanastorageurl
        }
        else {
            AddCheckResultEntry -CheckID "HDB-1012" -Description "SAP HANA Shared: File System" -TestResult $_filesystem_hana.fstype -ExptectedResult "xfs, nfs or nfs4" -Status "ERROR"  -MicrosoftDocs $_saphanastorageurl
        }
    }


    # remove duplicates from used storage types
    $script:_StorageType = $script:_StorageType | Select-Object -Unique

    # run checks from JSON file
    foreach ($_check in $_jsonconfig.Checks) {

        # does the check apply to this system?
        if ( $_check.OS.Contains($VMOperatingSystem) -and `
          $_check.DB.Contains($VMDatabase) -and `
          $_check.Role.Contains($VMRole) -and `
          ( $_check.OSVersion.Contains("all") -or $_check.OSVersion.Contains($VMOSRelease)) -and `
          ((Compare-Object -ReferenceObject $_check.StorageType -DifferenceObject $script:_StorageType -IncludeEqual -ExcludeDifferent).count -gt 0) -and `
          $_check.Hardwaretype.Contains($Hardwaretype)) {

            # check if check applies to HA or not and if HA check for HA-Agent
            if (($_check.HighAvailability.Contains($HighAvailability)) -or (($_check.HighAvailability.Contains($HighAvailability)) -and ($_check.HighAvailabilityAgent.Contains($HighAvailabilityAgent)))) {

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
                    $_Check_row.Status = "ERROR"
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

    $_ChecksOutput = $_ChecksOutput -replace '<td>OK</td>','<td class="StatusOK">OK</td>'
    $_ChecksOutput = $_ChecksOutput -replace '<td>ERROR</td>','<td class="StatusError">ERROR</td>'
    $_ChecksOutput = $_ChecksOutput -replace '<td>WARN</td>','<td class="StatusWarning">WARN</td>'
    $_ChecksOutput = $_ChecksOutput -replace '::SAPNOTEHTML1::','<a href="https://launchpad.support.sap.com/#/notes/'
    $_ChecksOutput = $_ChecksOutput -replace '::SAPNOTEHTML2::','" target="_blank">'
    $_ChecksOutput = $_ChecksOutput -replace '::SAPNOTEHTML3::','</a>'

    $_ChecksOutput = $_ChecksOutput -replace '::MSFTDOCS1::','<a href="'
    $_ChecksOutput = $_ChecksOutput -replace '::MSFTDOCS2::','" target="_blank">'
    $_ChecksOutput = $_ChecksOutput -replace '::MSFTDOCS3::','</a>'



    $script:_Content += "<a href=""#Checks"">Check Results</a><br>"

    return $_ChecksOutput

}

function CollectFileSystems {

    if ($VMOperatingSystem -eq "Windows") {
        # future Windows code
    }
    else {

        $_command = PrepareCommand -Command "findmnt -r -n" -CommandType "OS"
        $script:_findmnt = RunCommand -p $_command | ConvertFrom-String -Delimiter ' ' -PropertyNames target,source,fstype,options

        $_command = PrepareCommand -Command "df -BG" -CommandType "OS"
        $script:_filesystemfree = RunCommand -p $_command | ConvertFrom-String -PropertyNames Filesystem,Size,Used,Free,UsedPercent,Mountpoint

        $script:_filesystems = @()

        foreach ($_filesystem in $_filesystemfree) {

            $_filesystem_row = "" | Select-Object Target,Source,FSType,VG,Options,Size,Free,Used,UsedPercent,MaxMBPS,MaxIOPS

            $_filesystem_row.Target = $_filesystem.Mountpoint
            $_filesystem_row.Source = $_filesystem.Filesystem
            $_filesystem_row.FSType = ($script:_findmnt | Where-Object {$_.target -eq $_filesystem.Mountpoint}).fstype
            $_filesystem_row.Options = ($script:_findmnt | Where-Object {$_.target -eq $_filesystem.Mountpoint}).options
            $_filesystem_row.Size = $_filesystem.Size
            $_filesystem_row.Free = $_filesystem.Free
            $_filesystem_row.Used = $_filesystem.Used
            $_filesystem_row.UsedPercent = $_filesystem.UsedPercent
            $_filesystem_row.VG = ($script:_lvmvolumes | Where-Object { $_.dmpath -eq $_filesystem.Filesystem}).vgname
            if (($_filesystem_row.FSType -eq "nfs") -or ($_filesystem_row.FSType -eq "nfs4")) {
                $_filesystem_row.MaxMBPS = ($script:_ANFVolumes | Where-Object { $_.NFSAddress -eq $_filesystem_row.Source}).THROUGHPUTMIBPS
            }
            else {
                $_filesystem_row.MaxMBPS = ($script:_lvmgroups | Where-Object { $_.name -eq $_filesystem_row.VG}).TotalMBPS
                $_filesystem_row.MaxIOPS = ($script:_lvmgroups | Where-Object { $_.name -eq $_filesystem_row.VG}).TotalIOPS
            }

            $script:_filesystems += $_filesystem_row

        }

    }

    $_FilesystemsOutput = $script:_filesystems | ConvertTo-Html -Property * -Fragment -PreContent "<br><h2 id=""Filesystems"">Filesystems</h2>This section shows you the file systems available on the VM."

    $script:_Content += "<a href=""#Filesystems"">Filesystems</a><br>"

    return $_FilesystemsOutput

}

function CollectANFVolumes {

    if ($ANFAccountName -and $ANFResourceGroup) {

        $script:_ANFVolumes = @()

        $_ANFAccount = Get-AzNetAppFilesAccount -ResourceGroupName $ANFResourceGroup -Name $ANFAccountName

        $_ANFPools = Get-AzNetAppFilesPool -ResourceGroupName $ANFResourceGroup -AccountName $_ANFAccount.Name

        $Script:_ANFVolumes = @()
        
        foreach ($_ANFpool in $_ANFPools) {

            $_ANFPoolName = $_ANFpool.Name -replace $_ANFAccount.Name,''
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


#try {

    # load json configuration
    $_jsonconfig = Get-Content -Raw -Path $ConfigFileName -ErrorAction Stop | ConvertFrom-Json

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


    $_HTMLReport = ConvertTo-Html -Body "$_Content $_CollectScriptParameter $_CollectVMInfo $_RunQualityCheck $_CollectFileSystems $_CollectVMStorage $_CollectLVMGroups $_CollectLVMVolumes $_CollectANFVolumes $_CollectNetworkInterfaces $_CollectLoadBalancer $_CollectVMInfoAdditional" -Head $script:_HTMLHeader -Title "SAP on Azure Quality Check" -PostContent "<p id='CreationDate'>Creation Date: $(Get-Date)</p>"
    $_HTMLReportFileName = $AzVMName + "-" + $(Get-Date -Format "yyyyMMdd-HHmm") + ".html"
    $_HTMLReport | Out-File .\$_HTMLReportFileName

#}
#catch {s

#}

#finally {
    # doing cleanup

    Remove-SSHSession -SessionId $_SessionID 
    exit

#}