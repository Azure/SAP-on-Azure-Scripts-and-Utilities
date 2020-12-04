<#

.SYNOPSIS
    Check HANA System Configuration

.DESCRIPTION
    The script will check the configuration of a VM for running SAP HANA

.LINK
    https://github.com/Azure/SAP-on-Azure-Scripts-and-Utilities

.NOTES
    v1.0 - Initial version

#>
<#
Copyright (c) Microsoft Corporation.
Licensed under the MIT license.
#>

#Requires -Modules Posh-SSH
#Requires -Modules Az.Compute
#Requires -Modules Az.Network
#Requires -Modules Az.NetAppFiles
#Requires -Version 5.1

# TODO
## ssh keys instead of user/password
## HLI config
## md raids

param(
    #Azure Subscription Name
    [Parameter(Mandatory=$True)][string]$SubscriptionName,
    #Azure Resource Group Name
    [Parameter(Mandatory=$True)][string]$ResourceGroupName,
    #Azure VM Name
    [Parameter(Mandatory=$True)][string]$AzVMname,
    #hostname or IP address used for SSH connection
    [Parameter(Mandatory=$True)][string]$vm_hostname,
    #Azure NetApp Files ResourceGroup
    [string]$ANFResourceGroupName,
    #Azure NetApp Files Account Name
    [string]$ANFAccountName,
    #Username used to logon
    [Parameter(Mandatory=$True)][string]$vm_username,
    #Password used to logon
    [System.Security.SecureString][Parameter(Mandatory=$true)]$vm_password,
    #HANA ScaleUp or ScaleOut
    [ValidateSet('ScaleUp','ScaleOut')][string]$hanadeployment="ScaleUp",
    #HANA Storage Option
    [ValidateSet('Premium','UltraDisk','ANF')][string]$hanastoragetype="Ultra",
    #HighAvailability Check
    [boolean]$highavailability=$false,
    #ssh port
    [string]$sshport = "22",
    #create logfile
    [boolean]$createlogfile=$true,
    #QualityCheck Configfile
    [string]$ConfigFileName = "QualityCheck.json",
    #FastConnect - already connected to Azure
    [boolean]$fastconnect = $true
)



function CalculateKernelVersion {
    Param (
        [string] $kernelversion
    )

    # Linux Kernel Version consist of - and .
    # this module generates a number to compare different kernel versions

    $kversion = $kernelversion.Replace("-",".")
    $kversionarray = $kversion.split(".")

    $kversionnumber = [int]$kversionarray[0]*100000 + [int]$kversionarray[1]*10000 + [int]$kversionarray[2]*1000 + [int]$kversionarray[3]*100 + [int]$kversionarray[4]*10

    return $kversionnumber
}

function Get-RandomAlphanumericString {
	Param (
        [int] $length = 8
	)

    # create a random alphanumeric string for file names
    return (Write-Output ( -join ((0x30..0x39) + ( 0x41..0x5A) + ( 0x61..0x7A) | Get-Random -Count $length  | ForEach-Object {[char]$_}) ))
}

function RemoveLineCarriage {

    param ([string]$object)

    $result = [System.String] $object;
    $result = $result -replace "`t","";
	$result = $result -replace "`n","";
	$result = $result -replace "`r","";
	$result = $result -replace " ;",";";
	$result = $result -replace "; ",";";
	
	return $result
}

function RunOSCommand {
    param (
        [object]$p
    )

    if ($p.RootRequired) {
        # if root required sudo is added to the command
        $command = "echo $p_password | sudo -S " + $p.ProcessingCommand
    }
    else {
        # otherwise command will be used without sudo
        $command = $p.ProcessingCommand
    }

    try {
        # run the SSH command
        $result = Invoke-SSHCommand -Command $command -SessionId 0
    }
    catch {
        WriteOutput -output "Something went wrong" -type "STATUS-RED"
    }

    # Output contains the text from the SSH session
    $result = $result.Output

    # postprocessing can interpret / modify the output for further processing
    if (($p.PostProcessingCommand -ne "") -or ($p.PostProcessingCommand)) {

        $command = $p.PostProcessingCommand
        $command = $command -replace "PARAMETER",$result
        $result = Invoke-Expression $command

    }

    return $result
}

function WriteOutputToFile {
    param (
        [string]$outputstring
    )
    
    # send string to log file
    $outputstring >> $global:logfilename

}

function WriteOutput {
    param (
        [object]$output,
        [string]$type="INFO",
        [boolean]$addspaces=$false
    )
    
    # function formats the output for the script adding error or ok messages incl colored output
    switch ($type) {
        "STATUS-GREEN" { 
            $outputstring = " OK    - " + $output
            Write-Host -ForegroundColor Green $outputstring
            WriteOutputToFile -outputstring $outputstring
        }
        "STATUS-RED" { 
            $outputstring = " ERROR - " + $output
            Write-Host -ForegroundColor Red $outputstring
            WriteOutputToFile -outputstring $outputstring
        }
        "STATUS-RED-DESCRIPTION" { 
            $outputstring = "         " + $output
            Write-Host -ForegroundColor Red $outputstring
            WriteOutputToFile -outputstring $outputstring
        }
        "INFO" { 
            $outputstring = $output
            foreach ($line in $outputstring) {
                if ($addspaces) {
                    Write-Host ("   " + $line)
                    WriteOutputToFile -outputstring ("   " + $line)
                }
                else {
                    Write-Host $line
                    WriteOutputToFile -outputstring $line
                }
            }
        }
        Default {}
    }

}

function WriteOutputHeader {
    param (
        [string]$output,
        [string]$type="INFO"
    )
    
    # Writing output with sections
    WriteOutput -output "--------------------------------------------"
    WriteOutput -output $output -type $type
    WriteOutput -output "--------------------------------------------"

}

function ConvertSizeStringToNumber {
    param (
        [string]$inputsize
    )

    # convert a text value with sizing characters (gigabyte, megabyte, terabyte) to a real number for comparison

    # remove symbols occuring in Red Hat distributions
    $inputsize = $inputsize.Replace('<','')
    $inputsize = $inputsize.Replace('>','')
    
    # get length of string
    $length = $inputsize.Length

    # based on last char value the multiplier is defined, output is GB
    switch ($inputsize.Substring($length-1,1)) {
        "m" {
            $multiplier = 1/1024
        }    
        "g" {
            $multiplier = 1
        }
        "t" {
            $multiplier = 1024
        }
    }

    # return size in GB
    [int]$size = $inputsize.Substring(0,($inputsize.Length - 3)) * $multiplier

    $size
}

# defining script version
$scriptversion = 1

# defining variables
$OutputArray = @()
[string]$global:vmtype = ""
[string]$global:hostname =""
[string]$global:distribution = ""
[string]$global:fencingsolutionsbd = $false
[string]$global:fencingsolutionagent = $false
[string]$global:logfilename = Get-RandomAlphanumericString


# validating parameters
# for ANF scenarios the resource group and account name is required to query the performance tier later
if ($hanastoragetype -eq "ANF") {

    $found = 0

    if (!$ANFResourceGroupName) {
        WriteOutput -output "For ANF deployments please specify the ANFResourceGroupName parameter" -type "STATUS-RED"
        $ANFResourceGroupName = Read-Host -Prompt "Please enter your ANF Resource Group Name: "
    }
    if (!$ANFAccountName) {
        WriteOutput -output "For ANF deployments please specify the ANFAccountName parameter" -type "STATUS-RED"
        $ANFAccountName = Read-Host -Prompt "Please enter your ANF Account Name: "
    }
}


# first create secure credential store
$p_Password = ConvertFrom-SecureString -SecureString $vm_password
$Credential = New-Object System.Management.Automation.PSCredential ($vm_username, $vm_password);

# load config from file
# create full path for config file name
$ConfigFileName = $PSScriptRoot + "\" + $ConfigFileName
# load json config file
try {
    $ConfigFileHandle = Get-Content -raw -path $ConfigFileName -ErrorAction Stop
    $ConfigFile = $ConfigFileHandle | ConvertFrom-Json
}
catch {
    WriteOutput -output "Can't load config file, please check config file" -type "STATUS-RED"
    exit 13
}

# download online version
# and compare it with version numbers in files to see if there is a newer version available on GitHub
$ConfigFileUpdateURL = "https://raw.githubusercontent.com/Azure/SAP-on-Azure-Scripts-and-Utilities/master/QualityCheck/version.json"
try {
    $OnlineFileVersion = (Invoke-WebRequest -Uri $ConfigFileUpdateURL -UseBasicParsing -ErrorAction SilentlyContinue).Content  | ConvertFrom-Json

    if ($OnlineFileVersion.RepositoryVersion -gt $ConfigFile.Version) {
        WriteOutputHeader -output "There is a newer QualityCheck.json available on GitHub, please consider downloading it" -type "STATUS-RED"
        Start-Sleep -Seconds 3
    }

    if ($OnlineFileVersion.ScriptVersion -gt $scriptversion) {
        WriteOutputHeader -output "There is a newer QualityCheck.ps1 available on GitHub, please consider downloading it" -type "STATUS-RED"
        Start-Sleep -Seconds 3
    }

}
catch {
    WriteOutput -output "Can't connect to GitHub to check version" -type "INFO"
}


# cleanup SSH Trusted Hosts
Get-SSHTrustedHost | Remove-SSHTrustedHost -ErrorAction Continue  | Out-Null
Get-SSHSession | Remove-SSHSession  -ErrorAction Continue | Out-Null

# let's get started ...
# connecting to Azure

# select subscription
if ($fastconnect -eq $false) {

    $Subscription = Get-AzSubscription -SubscriptionName $SubscriptionName
    if (-Not $Subscription) {
        Write-Host -ForegroundColor Red -BackgroundColor White "Sorry, it seems you are not connected to Azure or don't have access to the subscription. Please use Connect-AzAccount to connect."
        exit 10
    }

    Select-AzSubscription -Subscription $SubscriptionName -Force

}

# check if VM is running
$vm = Get-AzVM -ResourceGroupName $ResourceGroupName -Name $AzVMname -Status -ErrorAction SilentlyContinue
if (!$vm) {
    WriteOutput -output "VM can't be found, please check parameters" -type "STATUS-RED"
    exit 11
}
else {
    if ($vm.Statuses[1].Code -eq "PowerState/running") {
        WriteOutput -output "VM is running" -type "STATUS-GREEN"
    }
    else {
        WriteOutput -output "VM is not running, please start the VM" -type "STATUS-RED"
        exit 11
    }
}

## create SSH stream 
try {
    $SessionSSH = New-SSHSession -ComputerName $vm_hostname -Port $sshport -Credential $Credential -AcceptKey -ErrorAction SilentlyContinue 
}
catch {
    WriteOutput -output "It seems there is a problem with SSH module, at the moment only Powershell 5.1 is supported, we are working on a version that supports Powershell 7" -type "STATUS-RED"
}

if ($SessionSSH.Connected -ne $true) {
    Write-Host "Not Connected"
    exit 12
}


###################################################
WriteOutputHeader -output "Starting VM Info Collect"
###################################################

# lets collect some basic information from VM
foreach ($CollectInfo in $ConfigFile.GeneralCollectVMInformation) {
    $result = RunOSCommand -p $CollectInfo
    
    # preparing output
    $output = @()
    $output = "" | Select-Object Description,Result,Status
    $output.Description = $CollectInfo.Description
    $output.Result = $result

    $OutputArray += $output
    WriteOutput -output $CollectInfo.Description
    #WriteOutput -output ("   " + $result)
    WriteOutput -output $result -addspaces $true
}

###################################################
WriteOutputHeader -output "Ending VM Info Collect"
###################################################

###################################################
WriteOutputHeader -output "Starting General Checks"
###################################################

foreach ($check in $configFile.Checks.General) {
    $result = RunOSCommand -p $check

    if ($result -eq $check.ExpectedOutput) {
        WriteOutput -output $check.Description -type "STATUS-GREEN"
    }
    else {
        WriteOutput -output $check.Description -type "STATUS-RED"
        WriteOutput -output $check.HelpMessage -type "STATUS-RED-DESCRIPTION"

    }

    $OutputArray += $output

}

# running OS specific checks
foreach ($check in $configFile.Checks.$global:distribution) {
    $result = RunOSCommand -p $check

    if ($result -eq $check.ExpectedOutput) {
        WriteOutput -output $check.Description -type "STATUS-GREEN"
    }
    else {
        WriteOutput -output $check.Description -type "STATUS-RED"
        WriteOutput -output $check.HelpMessage -type "STATUS-RED-DESCRIPTION"

    }

    $OutputArray += $output

}


###################################################
WriteOutputHeader -output "Ending General Checks"
###################################################

###################################################
WriteOutputHeader -output "Starting Linux Distribuation Checks"
###################################################

WriteOutput -output ("Linux Distribution is " + $global:distribution) -type "STATUS-GREEN"

# get Kernel version
$command = "uname -r"
try {
    $kernelversion = (Invoke-SSHCommand -Command $command -SessionId 0).Output
}
catch {
    WriteOutput -output "Something went wrong" -type "STATUS-RED"
}

# calculate comparable kernel version value
$calculatedkernelversion = CalculateKernelVersion -kernelversion $kernelversion

foreach ($check in $configFile.KnownIssues.$global:distribution.Kernel) {

    # calculate min and max version number
    $calculatedkernelversionmin = CalculateKernelVersion -kernelversion $check.MinVersion
    $calculatedkernelversionmax = CalculateKernelVersion -kernelversion $check.MaxVersion

    # check if there is a known kernel issue
    if (($calculatedkernelversion -ge $calculatedkernelversionmin) -and ($calculatedkernelversion -le $calculatedkernelversionmax))
    {
        WriteOutput -output ("There might be a known issue related to your kernel version, please check " + $check.Description) -type "STATUS-RED"
    }
    
}

###################################################
WriteOutputHeader -output "Ending Linux Distribuation Checks"
###################################################

###################################################
WriteOutputHeader -output "Starting OS Checks for Storage"
###################################################

foreach ($check in $configFile.Checks.Storage.$hanastoragetype) {
    $result = RunOSCommand -p $check

    if ($result -eq $check.ExpectedOutput) {
        WriteOutput -output ($check.ProcessingCommand) -type "STATUS-GREEN"
    }
    else {
        WriteOutput -output ($check.ProcessingCommand + " " + $check.ErrorMessage) -type "STATUS-RED"
        WriteOutput -output ("found:    " + $result) -type "STATUS-RED-DESCRIPTION"
        WriteOutput -output ("expected: " + $check.ExpectedOutput) -type "STATUS-RED-DESCRIPTION"
        WriteOutput -output $check.HelpMessage -type "STATUS-RED-DESCRIPTION"

    }

    $OutputArray += $output

}

###################################################
WriteOutputHeader -output "Ending OS Checks for Storage"
###################################################



###################################################
WriteOutputHeader -output "Starting Storage Checks"
###################################################

#
#  (Azure Metadata Service) <-> (sg_map for LUN ID) <-> (lvm report) <-> (mounts)
#

# load config for VM type
foreach ($diskconfig in $ConfigFile.VMDiskConfig) {
    if ($vmtype -eq $diskconfig.VMType) {
        break
    }
}


# get LVM config
$command = "echo $p_password | sudo -S lvm fullreport --reportformat json"
try {
    $lvmconfig = (Invoke-SSHCommand -Command $command -SessionId 0).Output | ConvertFrom-Json
}
catch {
    WriteOutput -output "Something went wrong" -type "STATUS-RED"
}

# get mount points
$command = "echo $p_password | sudo -S findmnt -r -n"
try {
    $findmnt = (Invoke-SSHCommand -Command $command -SessionId 0).Output | ConvertFrom-String -Delimiter ' ' -PropertyNames target,source,fstype,options
}
catch {
    WriteOutput -output "Something went wrong" -type "STATUS-RED"
}

# get LUN IDs for devices
$command = "echo $p_password | sudo -S sg_map -x"
try {
    $diskmapping = (Invoke-SSHCommand -Command $command -SessionId 0).Output | ConvertFrom-String
}
catch {
    WriteOutput -output "Something went wrong" -type "STATUS-RED"
}

# get Azure Disk Config
$command = "echo $p_password | sudo -S curl --noproxy * -H Metadata:true 'http://169.254.169.254/metadata/instance/compute/storageProfile?api-version=2019-08-15'"
try {
    $azurediskconfig = (Invoke-SSHCommand -Command $command -SessionId 0).Output | ConvertFrom-Json
}
catch {
    WriteOutput -output "Something went wrong" -type "STATUS-RED"
}

if (($hanastoragetype -eq "Premium") -or ($hanastoragetype -eq "UltraDisk")) {

    # check disk config
    foreach ($volume in $ConfigFile.GeneralConfig.SAPHANA.Volumes) {

        $found = $false
        # find physical volume for mounted path
        #foreach ($filesystem in $findmnt.filesystems[0].children) {
        foreach ($filesystem in $findmnt) {
            if ($volume.Path -eq $filesystem.target) {
                $found = $true
                break
            }
        }

        if (!$found) {
            WriteOutput ("File System " + $volume.Path + " not mounted") -type "STATUS-RED"
        }
        else {

            # find VG/LV for file system
            foreach ($lvm in $lvmconfig.report) {
                if (($filesystem.source -eq $lvm.lv.lv_dm_path) -or ($filesystem.source -eq $lvm.lv.lv_path)) {
                    break
                }
            }

            # get VM disk config from config file
            foreach ($vmdiskconfig in $ConfigFile.VMDiskConfig) {
                if ($vmdiskconfig.VMType -eq $vmtype) {
                    break
                }
            }

            $lvstriped = $lvm.seg.segtype
            $lvstripesize = $lvm.seg.stripe_size
            $lvstripes = $lvm.seg.data_stripes

            # check if xfs
            if ($filesystem.fstype -eq "xfs") {
                WriteOutput -output ("Filesystem " + $volume.Path + " has file system xfs") -type "STATUS-GREEN"
            }
            else {
                WriteOutput -output ("Filesystem " + $volume.Path + " is not formated with xfs") -type "STATUS-RED"
            }

            $stripesize = $ConfigFile.GeneralConfig.SAPHANA.StripeSizes.($volume.Description)


            if (($hanastoragetype -eq "Premium") -and (($volume.Description -eq "HANA Data") -or ($volume.Description -eq "HANA Log"))){
                # check if volume is striped
                if ($lvstriped -eq "striped") {
                    # ok, volume is striped
                    WriteOutput -output ("Filesystem " + $volume.Path + " is striped") -type "STATUS-GREEN"
                }
                else {
                    # error, volume is not striped
                    WriteOutput -output ("Filesystem " + $volume.Path + " is NOT striped") -type "STATUS-RED"
                }

                # check stripe size
                switch ($lvstripesize) {
                    $stripesize {  
                        # ok - stripe size meets newest recommendations
                        WriteOutput -output ("Filesystem " + $volume.Path + " has stripe size of " + $stripesize) -type "STATUS-GREEN"
                    }
                    Default {
                        # error - stripe size doesn' meet recommendations
                        WriteOutput -output ("Filesystem " + $volume.Path + " has a wrong stripe size") -type "STATUS-RED"
                        WriteOutput -output ("Skipping Disk Layout check as there where different disk types used") -type "STATUS-RED"
                    }
                }
            }

            # check pv size and pv count to meet requirements
            $pvcheck = 0
            $pvcount = 0
            $pvsize = ConvertSizeStringToNumber -inputsize ($lvm.pv[0].pv_used)
            foreach ($pv in $lvm.pv) {
                if ($pv.dev_size -ne $lvm.pv[0].dev_size) {
                    $pvcheck = 1
                }
                $pvcount += 1
            }

            switch ($pvcheck) {
                0 { 
                    # everything is fine, all PVs have same size
                    WriteOutput -output ("Filesystem " + $volume.Path + " has same disk type for all disks") -type "STATUS-GREEN"

                    # test disk layout
                    $diskconfigok = 0
                    foreach ($disklayout in $diskconfig.DiskConfig.$hanastoragetype) {
                        
                        # set disk size and count based on Log or Data Disk
                        switch ($volume.Description) {
                            "HANA Data" {
                                $disksize = $disklayout.DataDiskSize
                                $diskcount = $disklayout.DataDiskCount

                            }
                            "HANA Log" {
                                $disksize = $disklayout.LogDiskSize
                                $diskcount = $disklayout.LogDiskCount
                            }
                            "HANA Shared" {
                                $disksize = $disklayout.SharedDiskSize
                                $diskcount = $disklayout.SharedDiskCount
                            }
                        }
                        
                        if (($pvcount -ge $diskcount) -and ($pvsize -ge $disksize)) {
                            $diskconfigok = 1
                        }
                    }

                    switch ($diskconfigok) {
                        0 { 
                            # no certified disk configuration found
                            WriteOutput -output ("Filesystem " + $volume.Path + " has no supported configuration") -type "STATUS-RED"
                        }
                        1 {
                            # disk config ok
                            WriteOutput -output ("Filesystem " + $volume.Path + " has a certified disk layout") -type "STATUS-GREEN"
                        }
                    }
                }
                1 {
                    # error, at least one PV has different size
                    WriteOutput -output ("Filesystem " + $volume.Path + " has different disk type for disks") -type "STATUS-RED"
                }
            }

            # check for write accelerator settings
            foreach ($physicaldisk in $lvm.pv) {

                # search LUN ID
                foreach ($LUNID in $diskmapping) {
                    if ($LUNID.P7 -eq $physicaldisk.pv_name) {
                        $matchinglun = $LUNID.P5
                        break
                    }
                }

                # match the Azure Disk
                foreach ($azuredisk in $azurediskconfig.dataDisks) {
                    if ($azuredisk.lun -eq $matchinglun) {
                        break
                    }
                }

                # Premium Disks require Write Accelerator
                if (($hanastoragetype -eq "Premium") -and ($volume.Description -eq "HANA Log")) {
                    if ($azuredisk.writeAcceleratorEnabled -eq $true) {
                        # write accelerator enabled
                        WriteOutput -output ("Filesystem " + $volume.Path + " - Disk " + $azuredisk.name + " (" + $LUNID.P7 + ") has Write Accelerator enabled") -type "STATUS-GREEN"
                    }
                    else {
                        # write accelerator enabled
                        WriteOutput -output ("Filesystem " + $volume.Path + " - Disk " + $azuredisk.name + " (" + $LUNID.P7 + ") has Write Accelerator disabled") -type "STATUS-RED"
                    }
                }


                # Getting UltraDisk parameters
                if ($hanastoragetype -eq "UltraDisk") {

                    # set the value for comparison of IOPS and MBPS based on file system
                    switch ($volume.Description) {
                        "HANA Data" {
                            $UltraDiskIOPS = $disklayout.DataDiskIOPS
                            $UltraDiskMBPS = $disklayout.DataDiskMBPS
                        }
                        "HANA Log" {
                            $UltraDiskIOPS = $disklayout.LogDiskIOPS
                            $UltraDiskMBPS = $disklayout.LogDiskMBPS
                        }
                        "HANA Shared" {
                            $UltraDiskIOPS = $disklayout.SharedDiskIOPS
                            $UltraDiskMBPS = $disklayout.SharedDiskMBPS
                        }

                    }

                    # Get Azure Ultra Disk Configuration
                    $UltraDisk = Get-AzDisk -DiskName $azuredisk.name -ResourceGroupName $ResourceGroupName

                    if ($UltraDisk.DiskIOPSReadWrite -ge $UltraDiskIOPS) {
                        # Disk IOPS OK
                        WriteOutput -output ("Filesystem " + $volume.Path + " - Disk " + $azuredisk.name + " (" + $LUNID.P7 + ") has required IOPS") -type "STATUS-GREEN"
                    }
                    else {
                        # Disk IOPS Error
                        WriteOutput -output ("Filesystem " + $volume.Path + " - Disk " + $azuredisk.name + " (" + $LUNID.P7 + ") doesn't have required IOPS (" + $UltraDiskIOPS + ")") -type "STATUS-RED"
                    }

                    if ($UltraDisk.DiskMBpsReadWrite -ge $UltraDiskMBPS) {
                        # Disk MBPS OK
                        WriteOutput -output ("Filesystem " + $volume.Path + " - Disk " + $azuredisk.name + " (" + $LUNID.P7 + ") has required MBPS") -type "STATUS-GREEN"
                    }
                    else {
                        # Disk MBPS Error
                        WriteOutput -output ("Filesystem " + $volume.Path + " - Disk " + $azuredisk.name + " (" + $LUNID.P7 + ") doesn't have required MBPS (" + $UltraDiskMBPS + ")") -type "STATUS-RED"
                    }
                }
            }
        }
    }
}

# Check ANF requirements
if ($hanastoragetype -eq "ANF") {

    # get ANF Account

    try {
        $anfaccount = Get-AzNetAppFilesAccount -ResourceGroupName $ANFResourceGroupName
    }
    catch {
        WriteOutput -output "Something went wrong" -type "STATUS-RED"
    }

    # get ANF Pools
    try {
        $anfpools = Get-AzNetAppFilesPool -AccountObject $anfaccount
    }
    catch {
        WriteOutput -output "Something went wrong" -type "STATUS-RED"
    }
    # get ANF Volumes
    try {
        $anfvolumes = Get-AzNetAppFilesVolume -PoolObject $anfpools
    }
    catch {
        WriteOutput -output "Something went wrong" -type "STATUS-RED"
    }

    # check disk config
    foreach ($volume in $ConfigFile.GeneralConfig.SAPHANA.Volumes) {

        $found = $false
        # find physical volume for mounted path
        foreach ($filesystem in $findmnt.filesystems[0].children) {
            if ($volume.Path -eq $filesystem.target) {
                $found = $true
                break
            }
        }

        # Check the mount options
        if ($filesystem.options -match "vers=4.1,rsize=1048576,wsize=1048576") {
            WriteOutput -output ("File System " + $volume.Path + " - mount options OK") -type "STATUS-GREEN"
        }
        else {
            WriteOutput -output ("File System " + $volume.Path + " - please check mount options") -type "STATUS-RED"
        }

        if (!$found) {
            WriteOutput -output ("File System " + $volume.Path + " not mounted") -type "STATUS-RED"
        }
        else {
            if ($filesystem.fstype -eq "nfs4") {

                $nfspath = $filesystem.source 
                $nfsserverip = $nfspath.substring(0,$nfspath.IndexOf(":"))
                $nfsservervolume = $nfspath.substring($nfspath.IndexOf(":")+2)

                $found = $false
                foreach ($anfvolume in $anfvolumes) {
                    if ($nfsservervolume -eq $anfvolume.CreationToken) {
                        $found=$true
                        break
                    }
                }

                $anfvolumesize = $anfvolume.UsageThreshold / 1024 / 1024 / 1024
            
                switch ($volume.Description) {
                    "HANA Data" {

                        switch ($anfvolume.ServiceLevel) {
                            "Ultra" {
                                if ($anfvolumesize -gt 3200) {
                                    WriteOutput -output ("Filesystem " + $volume.Path + " supports at least 400 MB/s") -type "STATUS-GREEN"
                                }
                                else {
                                    WriteOutput -output ("Filesystem " + $volume.Path + " doesn't support 400 MB/s") -type "STATUS-RED"
                                }
                            }
                            "Premium" {
                                if ($anfvolumesize -gt 6400) {
                                    WriteOutput -output ("Filesystem " + $volume.Path + " supports at least 400 MB/s") -type "STATUS-GREEN"
                                }
                                else {
                                    WriteOutput -output ("Filesystem " + $volume.Path + " doesn't support 400 MB/s") -type "STATUS-RED"
                                }
                            }
                            "Standard" {
                                if ($anfvolumesize -gt 25600) {
                                    WriteOutput -output ("Filesystem " + $volume.Path + " supports at least 400 MB/s") -type "STATUS-GREEN"
                                }
                                else {
                                    WriteOutput -output ("Filesystem " + $volume.Path + " doesn't support 400 MB/s") -type "STATUS-RED"
                                }
                            }
                        }

                    }
                    "HANA Log" {

                        switch ($anfvolume.ServiceLevel) {
                            "Ultra" {
                                if ($anfvolumesize -gt 2000) {
                                    WriteOutput -output ("Filesystem " + $volume.Path + " supports at least 250 MB/s") -type "STATUS-GREEN"
                                }
                                else {
                                    WriteOutput -output ("Filesystem " + $volume.Path + " doesn't support 250 MB/s") -type "STATUS-RED"
                                }
                            }
                            "Premium" {
                                if ($anfvolumesize -gt 4000) {
                                    WriteOutput -output ("Filesystem " + $volume.Path + " supports at least 250 MB/s") -type "STATUS-GREEN"
                                }
                                else {
                                    WriteOutput -output ("Filesystem " + $volume.Path + " doesn't support 250 MB/s") -type "STATUS-RED"
                                }
                            }
                            "Standard" {
                                if ($anfvolumesize -gt 16000) {
                                    WriteOutput -output ("Filesystem " + $volume.Path + " supports at least 250 MB/s") -type "STATUS-GREEN"
                                }
                                else {
                                    WriteOutput -output ("Filesystem " + $volume.Path + " doesn't support 250 MB/s") -type "STATUS-RED"
                                }
                            }
                        }
                    }
                    "HANA Shared" {

                        switch ($anfvolume.ServiceLevel) {
                            "Ultra" {
                                if ($anfvolumesize -gt 512) {
                                    WriteOutput -output ("Filesystem " + $volume.Path + " supports at least 250 MB/s") -type "STATUS-GREEN"
                                }
                                else {
                                    WriteOutput -output ("Filesystem " + $volume.Path + " doesn't support 250 MB/s") -type "STATUS-RED"
                                }
                            }
                            "Premium" {
                                if ($anfvolumesize -gt 512) {
                                    WriteOutput -output ("Filesystem " + $volume.Path + " supports at least 250 MB/s") -type "STATUS-GREEN"
                                }
                                else {
                                    WriteOutput -output ("Filesystem " + $volume.Path + " doesn't support 250 MB/s") -type "STATUS-RED"
                                }
                            }
                            "Standard" {
                                if ($anfvolumesize -gt 512) {
                                    WriteOutput -output ("Filesystem " + $volume.Path + " supports at least 250 MB/s") -type "STATUS-GREEN"
                                }
                                else {
                                    WriteOutput -output ("Filesystem " + $volume.Path + " doesn't support 250 MB/s") -type "STATUS-RED"
                                }
                            }
                        }
                    }

                }
            }
            else {
                WriteOutput -output ("Filesystem " + $volume.Path + " is not NFS4") -type "STATUS-RED"
            }

            # check for multiple NICs and if NFS is mounted on eth0 or other card (NFS shouldn't be mounted on eth0)
            if ($hanadeployment -eq "ScaleOut") {

                # get IP address of mount
                $nfsipaddress = ($volume.source).Split(":")[0]

                # check if NFS mount is sent through eth0 (if yes than error because UDR is missing)
                $command = "echo $p_password | ip route get $nfsipaddress | grep eth0 | wc -l"
                try {
                    $nfsinterface = (Invoke-SSHCommand -Command $command -SessionId 0).Output
                }
                catch {
                    WriteOutput -output "Something went wrong" -type "STATUS-RED"
                }
        
                if ($nfsinterface -eq "1") {
                    WriteOutput -output ("NFS traffic for filesystem " + $volume.Path + " is sent through eth0, please create a route through separate interface") -type "STATUS-RED"  
                }
                else {
                    WriteOutput -output ("NFS traffic for filesystem " + $volume.Path + " is sent through separate interface") -type "STATUS-GREEN"
                }

            }
        }
    }
}

###################################################
WriteOutputHeader -output "Ending Storage Checks"
###################################################


# check if fencing agent or sbd is used
# Fencing Agent if config includes "fence_azure_arm"
# otherwise it is SBD
if (($global:distribution -eq "RedHat") -and ($highavailability -eq $true)) {
    $command = "echo $p_password | sudo -S pcs config show | grep fence_azure_arm | wc -l"
}
if (($global:distribution -eq "SUSE") -and ($highavailability -eq $true)) {
    $command = "echo $p_password | sudo -S crm configure show | grep fence_azure_arm | wc -l"
}


# start the High Availability Checks
if ($highavailability -eq $true) {
    try {
        $fencingoutput = (Invoke-SSHCommand -Command $command -SessionId 0).Output
    }
    catch {
        WriteOutput -output "Something went wrong" -type "STATUS-RED"
    }

    ###################################################
    WriteOutputHeader -output "Starting High Availability Checks"
    ###################################################


    if ($fencingoutput -eq "1") {
        $global:fencingsolutionagent = $true
    }
    else {
        $global:fencingsolutionsbd = $true
    }

    foreach ($check in $configFile.Checks.HighAvailability.$global:distribution) {
        
        if (($global:fencingsolutionsbd -eq $check.RunForSBD) -or ($global:fencingsolutionagent -eq $check.RunForAgent)) {

            $result = RunOSCommand -p $check

            if ($result -eq $check.ExpectedOutput) {
                WriteOutput -output $check.Description -type "STATUS-GREEN"
            }
            else {
                WriteOutput -output $check.Description -type "STATUS-RED"
                WriteOutput -output $check.HelpMessage -type "STATUS-RED-DESCRIPTION"

            }

            $OutputArray += $output
        }

    }

    ###################################################
    WriteOutputHeader -output "Ending High Availability Checks"
    ###################################################
}


###################################################
WriteOutputHeader -output "Starting Networking Checks"
###################################################


# Check if Accelerated Networking is enabled
$niccount = 0
try {
    $azurevm = Get-AzVM -name $hostname -ResourceGroupName $ResourceGroupName
}
catch {
    WriteOutput -output "Something went wrong" -type "STATUS-RED"
}

foreach ($azurevmnetworkinterface in $azurevm.NetworkProfile.NetworkInterfaces) {
    try {
        $networkinterface = Get-AzNetworkInterface -ResourceId $azurevmnetworkinterface.Id
    }
    catch {
        WriteOutput -output "Something went wrong" -type "STATUS-RED"
    }

    # check Accelerated Networking
    if ($networkinterface.EnableAcceleratedNetworking) {
        WriteOutput -output ("Accelerated Networking Enabled for Interface " + $networkinterface.Name) -type "STATUS-GREEN"
        $niccount += 1
    }

    # check if VM is part of load balancer
    foreach ($ipconfiguration in $networkinterface.IpConfigurations) {
        foreach ($loadbalancerbackendaddresspool in $ipconfiguration.LoadBalancerBackendAddressPools) {
            $loadbalancername = ($loadbalancerbackendaddresspool.id).Split("/")[8]
            $loadbalancerresourcegroup = ($loadbalancerbackendaddresspool.id).Split("/")[4]

            $loadbalancer = Get-AzLoadBalancer -Name $loadbalancername -ResourceGroupName $loadbalancerresourcegroup

            if ($loadbalancer.Sku.Name -eq "Standard") {
                WriteOutput -output ("Load Balancer " + $loadbalancer.Name + " is using Standard SKU") -type "STATUS-GREEN"
            }
            else {
                WriteOutput -output ("Load Balancer " + $loadbalancer.Name + " is not using Standard SKU, Microsoft recommends Standard SKU for best performance") -type "STATUS-RED"
            }

            if ($loadbalancer.LoadBalancingRules[0].IdleTimeoutInMinutes -eq 30) {
                WriteOutput -output ("Load Balancer " + $loadbalancer.Name + " idle timeout is set to 30 minutes") -type "STATUS-GREEN"
            }
            else {
                WriteOutput -output ("Load Balancer " + $loadbalancer.Name + " has unrecommended idle timeout, please set to 30 minutes") -type "STATUS-RED"
            }

            if ($loadbalancer.LoadBalancingRules[0].EnableFloatingIP -eq $true) {
                WriteOutput -output ("Load Balancer " + $loadbalancer.Name + " has floatint IP enabled") -type "STATUS-GREEN"
            }
            else {
                WriteOutput -output ("Load Balancer " + $loadbalancer.Name + " needs to have floating IP enabled") -type "STATUS-RED"
            }

            if ($loadbalancer.LoadBalancingRules[0].Protocol -eq "All") {
                WriteOutput -output ("Load Balancer " + $loadbalancer.Name + " has HA Ports enabled") -type "STATUS-GREEN"
            }
            else {
                WriteOutput -output ("Load Balancer " + $loadbalancer.Name + " needs to have HA Ports enabled") -type "STATUS-RED"
            }

            # check if socat installed, only if SBD device used
            if ($global:fencingsolutionsbd -eq $true) {
                # check if NFS mount is sent through eth0 (if yes than error because UDR is missing)
                $command = "echo $p_password | rpm -qi socat | grep Version | wc -l"
                try {
                    $nfsinterface = (Invoke-SSHCommand -Command $command -SessionId 0).Output
                }
                catch {
                    WriteOutput -output "Something went wrong" -type "STATUS-RED"
                }
        
                if ($nfsinterface -eq "1") {
                    WriteOutput -output ("socat installed") -type "STATUS-GREEN"
                }
                else {
                    WriteOutput -output ("socat not intalled") -type "STATUS-RED"  
                }
            }
        }
    }

}

if ($hanadeployment -eq "ScaleOut") {
    if ($niccount -lt $ConfigFile.GeneralConfig.SAPHANA.ScaleOut.NICCount) {
        WriteOutput -output "Please check number of network cards for Scale Out Configuration" -type "STATUS-RED"
    }
}

###################################################
WriteOutputHeader -output "Ending Networking Checks"
###################################################


###################################################
WriteOutputHeader -output "Cleaning Up"
###################################################
Get-SSHSession | Remove-SSHSession | Out-Null
Rename-Item $global:logfilename ($global:hostname + "-" + ((Get-Date).ToString('yyyyMMddhhmmss')) + ".txt")

# done