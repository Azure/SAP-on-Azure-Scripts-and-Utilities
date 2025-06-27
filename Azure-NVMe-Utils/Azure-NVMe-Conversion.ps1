<#

    .SYNOPSIS
        Convert Virtual Machines from SCSI to NVMe controller

    .DESCRIPTION
        The script helps converting Azure Virtual Machines from SCSI to NVMe controller.
        This will change the way how disks are presented inside the operating systems.
        The script will check if the VM is running Windows or Linux and will run the necessary commands to prepare the operating system for the conversion when specifying the -FixOperatingSystemSettings switch.

    .PARAMETER ResourceGroupName:
        Name of the resource group where the VM is located
    .PARAMETER VMName:
        Name of the VM to be converted
    .PARAMETER NewControllerType:
        Type of controller to be used (NVMe or SCSI)
    .PARAMETER VMSize:
        Size of the VM to be used
    .PARAMETER StartVM:
        Start the VM after conversion
    .PARAMETER WriteLogfile:
        Write log file to disk
    .PARAMETER IgnoreSKUCheck:
        Ignore SKU check for availability in region/zone
    .PARAMETER IgnoreWindowsVersionCheck:
        Ignore Windows version check
    .PARAMETER FixOperatingSystemSettings:
        Fix operating system settings
    .PARAMETER IgnoreAzureModuleCheck:
        Do not check if the Azure module is installed and the version is correct
    .PARAMETER IgnoreOSCheck:
        Do not check if the operating system is supported for NVMe conversion

    .INPUTS
        None.
    
    .OUTPUTS
        Log file with the results of the script execution
        The log file will be written to the current directory with the name Azure-NVMe-Conversion-<VMName>-<timestamp>.log when the -WriteLogfile switch is used

    .EXAMPLE
        PS> .\Azure-NVMe-Conversion.ps1 -ResourceGroupName "myResourceGroup" -VMName "myVM" -NewControllerType NVMe -VMSize "Standard_E4bds_v5" -StartVM -WriteLogfile

    .LINK
        https://github.com/Azure/SAP-on-Azure-Scripts-and-Utilities
 
#>

<#
    Copyright (c) Microsoft Corporation.
    Licensed under the MIT license.
#>


[CmdletBinding()]
param (
    # Resource Group
    [Parameter(Mandatory=$true)][string]$ResourceGroupName,
    # VM Name
    [Parameter(Mandatory=$true)][string]$VMName,
    # Disk Controller Type
    [ValidateSet("NVMe", "SCSI")][string]$NewControllerType="NVMe",
    # New VM Size
    [Parameter(Mandatory=$true)][string]$VMSize,
    # Start VM after update
    [switch]$StartVM,
    # Write Log File
    [switch]$WriteLogfile,
    # Ignore Check if SKU is available in the region/zone
    [switch]$IgnoreSKUCheck,
    # Ignore Windows Operating System Version Check
    [switch]$IgnoreWindowsVersionCheck,
    # Fix operating system settings
    [switch]$FixOperatingSystemSettings,
    # Ignore Azure Module Check
    [switch]$IgnoreAzureModuleCheck,
    # Ignore Operating System Check
    [switch]$IgnoreOSCheck,
    # SleepSeconds after VM Update
    [int]$SleepSeconds=15
)

# function to write log messages
function WriteRunLog {
    [CmdletBinding()]
    param (
        # Message to write to log
        [string]$message,
        # Category of the message
        [string]$category="INFO"
    )

    # getting offset seconds to start time 
    $_offset = ((Get-Date) - $script:_starttime).ToString("mm\:ss")

    switch ($category) {
        "INFO"      {   $_prestring = "INFO      - "
                        $_color = "Green" }
        "WARNING"   {   $_prestring = "WARNING   - "
                        $_color = "Yellow" }
        "ERROR"     {   $_prestring = "ERROR     - "
                        $_color = "Red" }
        "IMPORTANT" {   $_prestring = "IMPORTANT - "
                        $_color = "Blue" }

                    }
    $_runlog_row = "" | Select-Object "Log"
    $_runlog_row.Log = [string]$_offset + " - " + [string]$_prestring + [string]$message
    $script:_runlog += $_runlog_row
    Write-Host $_runlog_row.Log -ForegroundColor $_color

    if ($WriteLogfile -and $script:_logfile) {
        $_runlog_row.Log | Out-File -FilePath $script:_logfile -Append
    }
}

function CheckInstalledModules {
    [CmdletBinding()]
    param (
        # Module Name    
        [string]$ModuleName,
        # Minimum Module Version
        [version]$ModuleVersion
    )

    $_module = Get-Module -ListAvailable -Name $ModuleName
    if (-not ($_module)) {
        WriteRunLog -message "Module $ModuleName is not installed. Please install the module and run the script again." -category "ERROR"
        WriteRunLog -message "Usage this command to install the module:" -category "ERROR"
        WriteRunLog -message "   Install-Module -Name $ModuleName -Force" -category "ERROR"
        exit
    }

    if ($ModuleVersion -and ($_module | Where-Object {$_.Version -gt $ModuleVersion}).Count -eq 0) {
        WriteRunLog -message "Module $ModuleName is installed but the version is lower than required. Please update the module and run the script again." -category "ERROR"
        WriteRunLog -message "Usage this command to update the module:" -category "ERROR"
        WriteRunLog -message "   Update-Module -Name $ModuleName" -category "ERROR"
        exit
    }
    else {
        WriteRunLog -message "Module $ModuleName is installed and the version is correct."
    }
}

function AskToContinue {
    [CmdletBinding()]
    param (
        # Message to ask for confirmation
        [string]$message
    )

    WriteRunLog -message $message -category "IMPORTANT"
    $_answer = Read-Host "Do you want to continue? (Y/N)"
    if ($_answer -ne "Y" -and $_answer -ne "y") {
        WriteRunLog -message "Script execution aborted by user" -category "ERROR"
        exit
    }
}


function CheckForNewerVersion {

    # download online version
    # and compare it with version numbers in files to see if there is a newer version available on GitHub
    $ConfigFileUpdateURL = "https://raw.githubusercontent.com/Azure/SAP-on-Azure-Scripts-and-Utilities/main/Azure-NVMe-Utils/version.json"
    try {
        $OnlineFileVersion = (Invoke-WebRequest -Uri $ConfigFileUpdateURL -UseBasicParsing -ErrorAction SilentlyContinue).Content  | ConvertFrom-Json

        if ($OnlineFileVersion.Version -gt $script:_version) {
            WriteRunLog -category "WARNING" -message "There is a newer version of Azure-NVMe-Utils available on GitHub, please consider downloading it"
            WriteRunLog -category "WARNING" -message "You can download it on https://github.com/Azure/SAP-on-Azure-Scripts-and-Utilities/tree/main/Azure-NVMe-Utils"
            WriteRunLog -category "WARNING" -message "Script will continue"
            Start-Sleep -Seconds 3
        }

    }
    catch {
        WriteRunLog -category "WARNING" -message "Can't connect to GitHub to check version"
    }
    if (-not $RunLocally) {
        WriteRunLog -category "INFO" -message "Script Version $script:_version"
    }

    #$_scriptdate = [DateTime]::ParseExact($scriptversion, 'yyyyMMddHH', (Get-Culture))
    #$_currentDate_minus120 = (Get-Date).AddDays(-120)

    #if ($_scriptdate -lt $_currentDate_minus120) {
    #    WriteRunLog -category "ERROR" -message "You are running a script version that is older than 120 days, please update"
    #}

}


##############################################################################################################
# Main Script
##############################################################################################################

$_version = "2025062703" # version of the script

# creating variable for log file
$script:_runlog = @()
$script:_starttime = Get-Date
WriteRunLog -message "Starting script Azure-NVMe-Conversion.ps1"
WriteRunLog -message "Script started at $script:_starttime"
WriteRunLog -message "Script version: $_version"
$script:_logfile = "Azure-NVMe-Conversion-$($VMName)-$((Get-Date).ToString('yyyyMMdd-HHmmss')).log"
if ($WriteLogfile) {
    WriteRunLog -message "Log file will be written to $script:_logfile"
}

# 
WriteRunLog -message "Script parameters:"
foreach ($key in $MyInvocation.BoundParameters.keys)
{
    $value = (get-variable $key).Value 
    WriteRunLog -message "  $key -> $value"
}

CheckForNewerVersion

# Check if breaking change warning is enabled
$_breakingchangewarning = Get-AzConfig -DisplayBreakingChangeWarning
if ($_breakingchangewarning.Value -eq $true) {
    Update-AzConfig -DisplayBreakingChangeWarning $false
}

# Check module versions
#CheckInstalledModules -ModuleName "Az" -ModuleVersion "11.0"
if (-not $IgnoreAzureModuleCheck) {
    CheckInstalledModules -ModuleName "Az.Compute" -ModuleVersion "9.0"
    CheckInstalledModules -ModuleName "Az.Accounts" -ModuleVersion "4.0"
    CheckInstalledModules -ModuleName "Az.Resources" -ModuleVersion "7.0"
}
else {
    WriteRunLog -message "Skipping Azure module check"
}

# Getting Azure Context
try {
    $_AzureContext = Get-AzContext
    if (!$_AzureContext) {
        WriteRunLog -message "Azure Context not found" -category "ERROR"
        WriteRunLog -message "Please login to Azure using Connect-AzAccount" -category "ERROR"
        exit
    }
    WriteRunLog -message "Connected to Azure subscription name: $($_AzureContext.Subscription.Name)"
    WriteRunLog -message "Connected to Azure subscription ID: $($_AzureContext.Subscription.Id)"

} catch {
    WriteRunLog -message "Error getting Azure Context" -category "ERROR"
    WriteRunLog $_.Exception.Message "ERROR"
    exit
}

# Get VM
try {
    $_VM = Get-AzVM -ResourceGroupName $ResourceGroupName -Name $VMName
    if (-not $_VM) {
        WriteRunLog -message "VM $VMName not found in Resource Group $ResourceGroupName" -category "ERROR"
        exit
    }
    WriteRunLog -message "VM $VMName found in Resource Group $ResourceGroupName"
} catch {
    WriteRunLog -message "Error getting VM $VMName" -category "ERROR"
    WriteRunLog $_.Exception.Message "ERROR"
    exit
}

# storing original VM Size
$script:_original_vm_size = $_VM.HardwareProfile.VmSize

# Get VM Power State
try {
    $_vminfo = Get-AzVM -ResourceGroupName $ResourceGroupName -Name $VMName -Status
    # Check if VM is running
    if (($_vminfo.Statuses[1].Code -ne "PowerState/running")) {
        if ($NewControllerType -eq "NVMe") {
            if ($IgnoreOSCheck) {
                WriteRunLog -message "Ignoring VM Power State check, proceeding with conversion" -category "WARNING"
                WriteRunLog -message "VM $VMName is not running, but OS check is ignored." -category "WARNING"
            }
            else {
                if ($FixOperatingSystemSettings) {
                    WriteRunLog -message "Fixing operating system settings is not supported with IgnoreOSCheck or when the VM is not running" -category "ERROR"
                    WriteRunLog -message "Please start the VM and run the script again when using FixOperatingSystemSettings" -category "ERROR"
                    exit
                }
            }
        }
    }
    else {
        WriteRunLog -message "VM $VMName is running"
    }
} catch {
    WriteRunLog -message "Error getting VM status" -category "ERROR"
    WriteRunLog $_.Exception.Message "ERROR"
    exit
}

# Check if VM is running Linux or Windows
if ($_VM.StorageProfile.OsDisk.OsType -eq "Windows") {
    $_os = "Windows"
    WriteRunLog -message "VM $VMName is running Windows"

    if ($_vm.StorageProfile.ImageReference.Publisher -eq "MicrosoftWindowsServer") {
        # Check Windows Version of OS
        $_osversion = $_VM.StorageProfile.ImageReference.Sku
        WriteRunLog -message "Windows Version: $_osversion"
        $_osversion_number = $_osversion -replace "[^0-9]", ""

        if (-not $IgnoreWindowsVersionCheck) {
            if ($_osversion_number -lt 2019) {
                WriteRunLog -message "Windows Version is lower than 2019. NVMe controller is only supported on Windows 2019 and higher" -category "ERROR"
                exit
            }
            else {
                WriteRunLog -message "Detected Windows Version: $($_osversion_number)"
            }
        }
        else {
            WriteRunLog -message "Ignoring Windows Version Check"
            WriteRunLog -message "Please make sure that the Windows Server 2019 or higher or Windows 10 1809 or higher is installed on the VM"
        }
    }
}
else {
    $_os = "Linux"
    WriteRunLog -message "VM $VMName is running Linux"
}

# Check if VM is running SCSI or NVMe
if ($_VM.StorageProfile.DiskControllerType -eq "SCSI") {
    WriteRunLog -message "VM $VMName is running SCSI"
    if ($NewControllerType -eq "SCSI") {
        WriteRunLog -message "VM $VMName is already running SCSI. No action required."
        WriteRunLog -message "If you want to convert to NVMe, please specify -NewControllerType NVMe"
        exit
    }
}
else {
    WriteRunLog -message "VM $VMName is running NVMe"
    if ($NewControllerType -eq "NVMe") {
        WriteRunLog -message "VM $VMName is already running NVMe. No action required."
        WriteRunLog -message "If you want to convert to SCSI, please specify -NewControllerType SCSI"
        exit
    }
}

# check if VM is running a Gen1 or Gen2 image
try {
    $_vm_osdisk = Get-AzDisk -Name $_vm.StorageProfile.OsDisk.Name
    if ($_vm_osdisk.HyperVGeneration -eq 'V1') { 
        WriteRunLog -message "VM $VMName is running a Generation 1 image" -category "ERROR"
        WriteRunLog -message "NVMe controller are only supported on Generation 2 images" -category "ERROR"
    }
}
catch {
    WriteRunLog -message "Error getting VM Generation" -category "ERROR"
    WriteRunLog $_.Exception.Message "ERROR"
    exit
}


### trusted launch is supported now
##if ($_VM.SecurityProfile.SecurityType -eq "TrustedLaunch" -and $VMSize.StartsWith("Standard_M")) {
##    WriteRunLog -message "VM $VMName is running with Trusted Launch enabled" -category "ERROR"
##    WriteRunLog -message "Trusted Launch is not supported with M-Series VMs" -category "ERROR"
##    exit
##}
##else {
##    if ($_VM.SecurityProfile.SecurityType -eq "TrustedLaunch") {
##        WriteRunLog -message "VM $VMName is running Trusted Launch"
##   }
##    else {
##        WriteRunLog -message "VM $VMName is not running Trusted Launch"
##    }
##}

# getting authentication token for REST API calls
try {
    $access_token = (Get-AzAccessToken).Token

    # Check if running in Azure Cloud Shell
    if ($env:ACC_TERM_ID) {
        WriteRunLog -message "Running in Azure Cloud Shell"
    } else {
        WriteRunLog -message "Not running in Azure Cloud Shell"
    }

    # Check if the access token is a SecureString
    # might be needed for Azure Cloud Shell
    if ($access_token.GetType().Name -eq "SecureString") {
        WriteRunLog -message "Authentication token is a SecureString"
        $_Ptr = [System.Runtime.InteropServices.Marshal]::SecureStringToCoTaskMemUnicode($access_token)
        $_result = [System.Runtime.InteropServices.Marshal]::PtrToStringUni($_Ptr)
        [System.Runtime.InteropServices.Marshal]::ZeroFreeCoTaskMemUnicode($_Ptr)
        $access_token = $_result
    } else {
        WriteRunLog -message "Authentication token is not a SecureString, no conversion needed"
    }

    WriteRunLog -message "Authentication token received"
} catch {
    WriteRunLog -message "Error getting authentication token" -category "ERROR"
    WriteRunLog $_.Exception.Message "ERROR"
    exit
}

if (-not $IgnoreSKUCheck) {
    WriteRunLog -message "Getting available SKU resources"
    WriteRunLog -message "This might take a while ..."
    $_VMSKUs = Get-AzComputeResourceSku -Location $_vm.Location | Where-Object { $_.ResourceType.Contains("virtualMachines") }
    $_VMSKU = $_VMSKUs | Where-Object { $_.Name -eq $VMSize }

    # Check if VM SKU is available in the VM's zone
    if ($_VM.Zones -and $_VM.Zones.Count -gt 0) {
        $vmZone = $_VM.Zones[0]
        if (-not ($_VMSKU.LocationInfo | Where-Object { $_.Zones -contains $vmZone })) {
            WriteRunLog -message "VM SKU $VMSize is not available in zone $vmZone" -category "ERROR"
            exit
        }
        else {
            WriteRunLog -message "VM SKU $VMSize is available in zone $vmZone"
        }
    }

    # Check if both VMs have or do not have a resource disk
    # $originalVmHasResourceDisk = ($_VMSKUs | Where-Object { $_.Name -eq $script:_original_vm_size }).Capabilities | Where-Object { $_.Name -eq "EphemeralOSDiskSupported" -and $_.Value -eq "True" }
    # $newVmHasResourceDisk = ($_VMSKU.Capabilities | Where-Object { $_.Name -eq "EphemeralOSDiskSupported" -and $_.Value -eq "True" })

    #if (($originalVmHasResourceDisk -and -not $newVmHasResourceDisk) -or (-not $originalVmHasResourceDisk -and $newVmHasResourceDisk)) {
    #    WriteRunLog -message "Mismatch in resource disk support between original VM size ($script:_original_vm_size) and new VM size ($VMSize)." -category "ERROR"
    #    exit
    #}
    #else {
    #    WriteRunLog -message "Resource disk support matches between original VM size and new VM size."
    #}

    # Check if VM SKU has supported capabilities
    $_originalVMHasResourceDisk = ($_VMSKUs | Where-Object { $_.Name -eq $script:_original_vm_size }).Capabilities | Where-Object { $_.Name -eq "MaxResourceVolumeMB" -and $_.Value -eq 0 }
    $_newVMHasResourceDisk = ($_VMSKU.Capabilities | Where-Object { $_.Name -eq "MaxResourceVolumeMB" -and $_.Value -eq 0 })

    if (($_originalVMHasResourceDisk -and -not $_newVMHasResourceDisk) -or (-not $_originalVMHasResourceDisk -and $_newVMHasResourceDisk)) {
        WriteRunLog -message "Mismatch in resource disk support between original VM size ($script:_original_vm_size) and new VM size ($VMSize)." -category "ERROR"
        WriteRunLog -message "Please check the VM sizes and their capabilities." -category "ERROR"
        WriteRunLog -message "IMPORTANT: If you try to convert to a v6 VM size (e.g. Standard_E4ds_v6 or Standard_E4ads_v6) an error might occur." -category "ERROR"
        WriteRunLog -message "We are working on a fix for this issue." -category "ERROR"
        exit
    }
    else {
        WriteRunLog -message "Resource disk support matches between original VM size and new VM size."
    }

    if ($_VMSKU) {
        WriteRunLog -message "Found VM SKU - Checking for Capabilities"
        $_supported_controller = ($_VMSKU.Capabilities | Where-Object { $_.Name -eq "DiskControllerTypes" }).Value

        if ([string]::IsNullOrEmpty($_supported_controller) -and $NewControllerType -eq "NVMe") {
            WriteRunLog -message "VM SKU doesn't have supported capabilities" -category "ERROR"
            exit
        }
        else {
            WriteRunLog -message "VM SKU has supported capabilities"
            if ($NewControllerType -eq "NVMe") {
                # NVMe destination
                if ($_supported_controller.Contains("NVMe") ) {
                    WriteRunLog -message "VM supports NVMe" 
                }
                else {
                    WriteRunLog -message "VM doesn't support NVMe" -category "ERROR"
                    exit
                }
            }
            else {
                # SCSI is supported by all VM types
                WriteRunLog -message "VM supports SCSI"
            }  
        }
    }
    else {
        WriteRunLog -category "ERROR" -message ("VM SKU doesn't exist, please check your input: " + $VMSize )
        exit
    }
}

# generate URL for OS disk update
$osdisk_url = "https://management.azure.com/subscriptions/$($_AzureContext.Subscription.Id)/resourceGroups/$ResourceGroupName/providers/Microsoft.Compute/disks/$($_vm_osdisk.Name)?api-version=2023-04-02"

# auth header for web request
$auth_header = @{
    'Content-Type'  = 'application/json'
    'Authorization' = 'Bearer ' + $access_token
  }

# body for SCSI/NVMe enabled OS Disk
$body_nvmescsi = @'
{
    "properties": {
        "supportedCapabilities": {
            "diskControllerTypes":"SCSI, NVMe"
        }
    }
}
'@

# body for SCSI enabled OS Disk
$body_scsi = @'
{
    "properties": {
        "supportedCapabilities": {
            "diskControllerTypes":"SCSI"
        }
    }
}
'@

# Windows Check script for NVMe
$Check_Windows_Script = @'
$start = (Get-ItemProperty -Path HKLM:\SYSTEM\CurrentControlSet\Services\stornvme -Name Start).Start
if ($start -eq 0) {
    Write-Host "Start:OK"
}
else {
    Write-Host "Start:ERROR"
}
$startoverride = Get-ItemProperty -Path HKLM:\SYSTEM\CurrentControlSet\Services\stornvme\StartOverride -ErrorAction SilentlyContinue
if ($startoverride) {
    Write-Host "StartOverride:ERROR"
}
else {
    Write-Host "StartOverride:OK"
}
'@

# Pre-Checks completed
WriteRunLog -message "Pre-Checks completed"

# running preparation for operating systems
if ($_os -eq "Windows") {
    
    if ($NewControllerType -eq "NVMe") {
        WriteRunLog -message "Starting OS section"

        try {

            if (-not $IgnoreOSCheck) {
                if ($FixOperatingSystemSettings) {
                    WriteRunLog -message "Fixing operating system settings"
                    WriteRunLog -message "Running command to set stornvme to boot"
                    WriteRunLog -message "   sc.exe config stornvme start=boot"
                    $RunCommandResult = Invoke-AzVMRunCommand -ResourceGroupName $ResourceGroupName -VMName $VMName -CommandId 'RunPowerShellScript' -ScriptString 'Start-Process -FilePath "C:\Windows\System32\sc.exe" -ArgumentList "config stornvme start=boot"'
                }
                else {
                    if (-not $IgnoreSKUCheck) {
                        WriteRunLog -message "Collecting details from OS"
                        $_error = 0
                        $_okay = 0
                        $_scriptoutput = ""
                        $RunCommandResult = Invoke-AzVMRunCommand -ResourceGroupName $ResourceGroupName -VMName $VMName -CommandId 'RunPowerShellScript' -ScriptString $Check_Windows_Script

                        $_result = ($RunCommandResult.Value | ForEach-Object { $_.Message }) -split "`n"

                        foreach ($_line in $_result) {
                            WriteRunLog -message ("   Script output: " + $_line)
                            if ($_line.Contains("OK") -or $_line.Contains("ERROR")) {
                                $_scriptoutput += $_line + "`n"

                                if ($_line.Contains("Start:")) {
                                    if ($_line.Contains("ERROR")) {
                                        WriteRunLog -message "Start is not set to boot in the operating system" -category "ERROR"
                                        $_error++
                                    }
                                    else {
                                        WriteRunLog -message "Start is set to boot in the operating system" -category "INFO"
                                        $_okay++
                                    }
                                }

                                if ($_line.Contains("StartOverride:")) {
                                    if ($_line.Contains("ERROR")) {
                                        WriteRunLog -message "StartOverride is set in the operating system" -category "ERROR"
                                        $_error++
                                    }
                                    else {
                                        WriteRunLog -message "StartOverride does not exist" -category "INFO"
                                        $_okay++
                                    }
                                }
                            }
                        }

                        WriteRunLog -message "Windows OS Check result:"
                        WriteRunLog -message "Errors: $_error - OK: $_okay"

                        if ($_error -gt 0) {
                            WriteRunLog -message "Operating system does not seem to be ready, it might not after the conversion" -category "WARNING"
                            WriteRunLog -message "Please check the operating system settings" -category "WARNING"
                            WriteRunLog -message "If you want to continue, please use the -FixOperatingSystemSettings switch" -category "IMPORTANT"
                            WriteRunLog -message "alternative: you can run 'sc.exe config stornvme start=boot' in the operating system and continue or stop the script" -category "IMPORTANT"
                            AskToContinue -message "Do you want to continue?"
                        }
                    }
                    else {
                        WriteRunLog -message "Skipping OS Check, assuming that the operating system is ready for conversion"
                    }
                }
            }
            else {
                WriteRunLog -message "Skipping OS Check, assuming that the operating system is ready for conversion"
                if ($FixOperatingSystemSettings) {
                    WriteRunLog -message "Fixing operating system settings not supported with skipped OS Check" -category "ERROR"
                    exit
                }
            }
        } catch {
            WriteRunLog -message "Error running preparation for Windows OS" -category "ERROR"
            WriteRunLog $_.Exception.Message "ERROR"
            exit
        }
    }
    else {
        WriteRunLog -message "No preparation required for SCSI"
    }
}
else {
    WriteRunLog -message "Entering Linux OS section"

    try {

    # Define the bash script
$linux_check_script = @'
#!/bin/bash

# Set default values
fix=false
distro=""

# Function to display usage
usage() {
    echo "Usage: $0 [-fix]"
    exit 1
}

# Parse command line arguments
while [ $# -gt 0 ]; do
    case "$1" in
        -fix)
            fix=true
            ;;
        *)
            usage
            ;;
    esac
    shift
done

# Determine the Linux distribution
if [ -f /etc/os-release ]; then
    source /etc/os-release
    distro="$ID"
elif [ -f /etc/debian_version ]; then
    distro="debian"
elif [ -f /etc/SuSE-release ]; then
    distro="suse"
elif [ -f /etc/redhat-release ]; then
    distro="redhat"
elif [ -f /etc/centos-release ]; then
    distro="centos"
elif [ -f /etc/rocky-release ]; then
    distro="rocky"
else
    echo "[ERROR] Unsupported distribution."
    exit 1
fi
echo "[INFO] Operating system detected: $distro"

# Function to check if NVMe driver is in initrd/initramfs
check_nvme_driver() {
    echo "[INFO] Checking if NVMe driver is included in initrd/initramfs..."
    case "$distro" in
        ubuntu|debian)
            if lsinitramfs /boot/initrd.img-* | grep -q nvme; then
                echo "[INFO] NVMe driver found in initrd/initramfs."
            else
                echo "[WARNING] NVMe driver not found in initrd/initramfs."
                if $fix; then
                    echo "[INFO] Adding NVMe driver to initrd/initramfs..."
                    update-initramfs -u -k all
                    if lsinitramfs /boot/initrd.img-* | grep -q nvme; then
                        echo "[INFO] NVMe driver added successfully."
                    else
                        echo "[ERROR] Failed to add NVMe driver to initrd/initramfs."
                    fi
                else
                    echo "[ERROR] NVMe driver not found in initrd/initramfs."
                fi
            fi
            ;;
        redhat|centos|rocky|suse|sles|ol)
            if lsinitrd | grep -q nvme; then
                echo "[INFO] NVMe driver found in initrd/initramfs."
            else
                echo "[WARNING] NVMe driver not found in initrd/initramfs."
                if $fix; then
                    echo "[INFO] Adding NVMe driver to initrd/initramfs..."
                    mkdir -p /etc/dracut.conf.d
                    echo 'add_drivers+=" nvme nvme-core "' | sudo tee /etc/dracut.conf.d/nvme.conf > /dev/null
                    sudo dracut -f   
                    if lsinitrd | grep -q nvme; then
                        echo "[INFO] NVMe driver added successfully."
                    else
                        echo "[ERROR] Failed to add NVMe driver to initrd/initramfs."
                    fi
                else
                    echo "[ERROR] NVMe driver not found in initrd/initramfs."
                fi
            fi
            ;;
        *)
            echo "[ERROR] Unsupported distribution for NVMe driver check."
            return 1
            ;;
    esac
}

# Function to check nvme_core.io_timeout parameter
check_nvme_timeout() {
    echo "[INFO] Checking nvme_core.io_timeout parameter..."
    if grep -q "nvme_core.io_timeout=240" /etc/default/grub /etc/grub.conf /boot/grub/grub.cfg; then
        echo "[INFO] nvme_core.io_timeout is set to 240."
    else
        echo "[WARNING] nvme_core.io_timeout is not set to 240."
        if $fix; then
            echo "[INFO] Setting nvme_core.io_timeout to 240…"
            case "$distro" in
                ubuntu|debian)
                    sed -i 's/GRUB_CMDLINE_LINUX="/GRUB_CMDLINE_LINUX="nvme_core.io_timeout=240 /g' /etc/default/grub
                    update-grub
                    ;;
                redhat|centos|rocky|suse|sles)
                    if [ -f /etc/default/grub ]; then
                        sed -i 's/GRUB_CMDLINE_LINUX="/GRUB_CMDLINE_LINUX="nvme_core.io_timeout=240 /g' /etc/default/grub
                        grub2-mkconfig -o /boot/grub2/grub
                    elif [ -f /etc/default/grub.conf ]; then
                        sed -i 's/GRUB_CMDLINE_LINUX="/GRUB_CMDLINE_LINUX="nvme_core.io_timeout=240 /g' /etc/default/grub.conf
                        grub2-mkconfig -o /boot/grub2/grub.cfg
                    else
                        echo "[ERROR] No grub config found."
                        exit 1
                    fi
                    ;;
                ol)
                    if [ -f /etc/default/grub ]; then
                        sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="/GRUB_CMDLINE_LINUX_DEFAULT="nvme_core.io_timeout=240 /g' /etc/default/grub
                        grub2-mkconfig -o /boot/grub2/grub
                    elif [ -f /etc/default/grub.conf ]; then
                        sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="/GRUB_CMDLINE_LINUX_DEFAULT="nvme_core.io_timeout=240 /g' /etc/default/grub.conf
                        grub2-mkconfig -o /boot/grub2/grub.cfg
                    else
                        echo "[ERROR] No grub config found."
                        exit 1
                    fi
                    ;;
                *)
                    echo "[ERROR] Unsupported distribution for nvme_core.io_timeout fix."
                    return 1
                    ;;
            esac
            if grep -q "nvme_core.io_timeout=240" /etc/default/grub /etc/grub.conf /boot/grub/grub.cfg; then
                echo "[INFO] nvme_core.io_timeout set successfully."
            else
                echo "[ERROR] Failed to set nvme_core.io_timeout."
            fi
        fi
    fi
}

# Function to check /etc/fstab for deprecated device names
check_fstab() {
    echo "[INFO] Checking /etc/fstab for deprecated device names..."
    if grep -Eq '/dev/sd[a-z][0-9]*|/dev/disk/azure/scsi[0-9]*/lun[0-9]*' /etc/fstab; then
        if $fix; then
            echo "[WARNING] /etc/fstab contains deprecated device names."
            echo "[INFO] Replacing deprecated device names in /etc/fstab with UUIDs..."
            
            # Create a backup of the fstab file
            cp /etc/fstab /etc/fstab.bak
            
            # Use sed to replace device names with UUIDs
            while read -r line; do
                if [[ "$line" =~ ^[^#] ]]; then
                    device=$(echo "$line" | awk '{print $1}')
                    if [[ "$device" =~ ^/dev/sd[a-z][0-9]*$ ]]; then
                        uuid=$(blkid "$device" | awk -F\" '/UUID=/ {print $2}')
                        if [ -n "$uuid" ]; then
                            newline=$(echo "$line" | sed "s|$device|UUID=$uuid|g")
                            echo "[INFO] Replaced $device with UUID=$uuid"
                            echo "$newline" >> /etc/fstab.new
                        else
                            echo "[WARNING] Could not find UUID for $device.  Skipping."
                            echo "$line" >> /etc/fstab.new
                        fi
                    elif [[ "$device" =~ ^/dev/disk/azure/scsi[0-9]*/lun[0-9]*$ ]]; then
                        uuid=$(blkid "$device" | awk -F\" '/UUID=/ {print $2}')
                        if [ -n "$uuid" ]; then
                            newline=$(echo "$line" | sed "s|$device|UUID=$uuid|g")
                            echo "[INFO] Replaced $device with UUID=$uuid"
                            echo "$newline" >> /etc/fstab.new
                        else
                            echo "[WARNING] Could not find UUID for $device.  Skipping."
                            echo "$line" >> /etc/fstab.new
                        fi
                    else
                        echo "$line" >> /etc/fstab.new
                    fi
                else
                    echo "$line" >> /etc/fstab.new
                fi
            done < /etc/fstab

            # Replace the old fstab with the new fstab
            mv /etc/fstab.new /etc/fstab
            
            echo "[INFO] /etc/fstab updated with UUIDs.  Original fstab backed up to /etc/fstab.bak"
    	else 
	    echo "[ERROR] /etc/fstab contains device names causing issues switching to NVMe"
	fi
    else
        echo "[INFO] /etc/fstab does not contain deprecated device names."
    fi
}

# Run the checks
check_nvme_driver
check_nvme_timeout
check_fstab

exit 0
'@

$linux_fix_script = $linux_check_script.Replace("fix=false","fix=true")

        if ($NewControllerType -eq "NVMe") {
            if (-not $IgnoreOSCheck) {

                if ($FixOperatingSystemSettings) {
                    # Invoke the Run Command
                    $RunCommandResult = Invoke-AzVMRunCommand -ResourceGroupName $resourceGroupName -Name $vmName -CommandId 'RunShellScript' -ScriptString $linux_fix_script

                }
                else {
                    # Invoke the Run Command
                    $RunCommandResult = Invoke-AzVMRunCommand -ResourceGroupName $resourceGroupName -Name $vmName -CommandId 'RunShellScript' -ScriptString $linux_check_script

                }

                $_result = ($RunCommandResult.Value | ForEach-Object { $_.Message }) -split "`n"

                $_scriptoutput = ""
                $_error=0
                $_info=0
                $_warning=0
                foreach ($_line in $_result) {
                    if ($_line.Contains("[INFO]") -or $_line.Contains("[ERROR]") -or $_line.Contains("[WARNING]")) {
                        $_scriptoutput += $_line + "`n"
                        if ($_line.Contains("[ERROR]")) {
                            $_error++
                        }
                        if ($_line.Contains("[INFO]")) {
                            $_info++
                        }
                        if ($_line.Contains("[WARNING]")) {
                            $_warning++
                        }
                    }
                    WriteRunLog -message ("   Script output: " + $_line)
                }

                WriteRunLog -message "Errors: $_error - Warnings: $_warning - Info: $_info"

                if ($_error -gt 0) {
                    WriteRunLog -message "Operating system does not seem to be ready, it might not after the conversion" -category "WARNING"
                    WriteRunLog -message "Please check the operating system settings" -category "WARNING"
                    WriteRunLog -message "If you want to continue, please use the -FixOperatingSystemSettings switch" -category "IMPORTANT"
                    WriteRunLog -message "alternative: you can enable NVMe driver manually" -category "IMPORTANT"
                    AskToContinue -message "Do you want to continue?"
                }
            }
            else {
                WriteRunLog -message "Skipping OS Check, assuming that the operating system is ready for conversion"
                if ($FixOperatingSystemSettings) {
                    WriteRunLog -message "Fixing operating system settings not supported with skipped OS Check" -category "ERROR"
                    exit
                }
            }
        }
        else {
            WriteRunLog -message "No preparation required for SCSI."
        }

    } catch {
        WriteRunLog -message "Error running preparation for Linux OS" -category "ERROR"
        WriteRunLog $_.Exception.Message "ERROR"
        exit
    }
}

# Shutting down VM
WriteRunLog -message "Shutting down VM $VMName"
try {
    $_stopvm = Stop-AzVM -ResourceGroupName $ResourceGroupName -Name $VMName -Force
    WriteRunLog -message "VM $VMName stopped"
} catch {
    WriteRunLog -message "Error stopping VM $VMName" -category "ERROR"
    WriteRunLog $_.Exception.Message "ERROR"
    exit
}

# Checking status of VM
WriteRunLog -message "Checking if VM is stopped and deallocated"
$_vminfo = Get-AzVM -ResourceGroupName $ResourceGroupName -Name $VMName -Status
if ($_vminfo.Statuses[1].Code -ne "PowerState/deallocated") {
    WriteRunLog -message "VM is not deallocated. Please deallocate the VM before running this script."
    WriteRunLog -message "giving it another try"
    $_stopvm = Stop-AzVM -ResourceGroupName $ResourceGroupName -Name $VMName -Force
    $_vminfo = Get-AzVM -ResourceGroupName $ResourceGroupName -Name $VMName -Status
    if ($_vminfo.Statuses[1].Code -ne "PowerState/deallocated") {
        WriteRunLog -message "VM is not deallocated. Please check why the VM is not deallocated." -category "ERROR"
        exit
    }
}

# Enabling NVMe capabilities on OS disk
WriteRunLog -message "Setting OS Disk capabilities for $($_vm_osdisk.Name) to new Disk Controller Type to $NewControllerType"
try {
    WriteRunLog -message "generated URL for OS disk update:"
    WriteRunLog -message $osdisk_url
    if ($NewControllerType -eq "NVMe") {
        $_response = Invoke-RestMethod -Uri $osdisk_url -Method PATCH -Headers $auth_header -Body $body_nvmescsi
    }
    else {
        $_response = Invoke-RestMethod -Uri $osdisk_url -Method PATCH -Headers $auth_header -Body $body_scsi
    }
    WriteRunLog -message "OS Disk updated"
} catch {
    WriteRunLog -message "Error updating OS Disk" -category "ERROR"
    WriteRunLog $_.Exception.Message "ERROR"
    exit
}


# Setting new VM Size and storage controller
WriteRunLog -message "Setting new VM Size from $($_VM.HardwareProfile.VmSize) to $VMSize and Controller to $NewControllerType"
try {
    $_VM.HardwareProfile.VmSize = $VMSize
    $_VM.StorageProfile.DiskControllerType = $NewControllerType
} catch {
    WriteRunLog -message "Error updating VM Size" -category "ERROR"
    WriteRunLog $_.Exception.Message "ERROR"
    exit
}

# Update VM
WriteRunLog -message "Updating VM $VMName"
try {
    $_updatevm = Update-AzVM -ResourceGroupName $ResourceGroupName -VM $_VM
    if ($_updatevm.StatusCode -eq "OK") {
        WriteRunLog -message "VM $VMName updated"
    }
    else {
        WriteRunLog -message "Error updating VM $VMName" -category "ERROR"
        exit
    }
} catch {
    WriteRunLog -message "Error updating VM $VMName" -category "ERROR"
    WriteRunLog $_.Exception.Message "ERROR"
    exit
}

# Start VM
if ($StartVM) {
    WriteRunLog -message "Start after update enabled for VM $VMName"
    try {
        # waiting for X seconds before starting the VM - parameter SleepSeconds
        WriteRunLog -message "Waiting for $SleepSeconds seconds before starting the VM"
        Start-Sleep -Seconds $SleepSeconds
        # starting the VM
        WriteRunLog -message "Starting VM $VMName"
        $_startvm = Start-AzVM -ResourceGroupName $ResourceGroupName -Name $VMName
        if ($_startvm.Status -eq "Succeeded") {
            WriteRunLog -message "VM $VMName started"
        }
        else {
            WriteRunLog -message "Error starting VM $VMName" -category "ERROR"
            if ($NewControllerType -eq "NVMe") {
                WriteRunLog -message "If you have any issues after the conversion you can revert the changes by running the script with the old settings"
                WriteRunLog -message "Here is the command to revert the changes:" -category "IMPORTANT"
                WriteRunLog -message "   .\Azure-NVMe-Conversion.ps1 -ResourceGroupName $ResourceGroupName -VMName $VMName -NewControllerType SCSI -VMSize $script:_original_vm_size -StartVM"
            }
            exit
        }
    } catch {
        WriteRunLog -message "Error starting VM $VMName" -category "ERROR"
        if ($NewControllerType -eq "NVMe") {
            WriteRunLog -message "If you have any issues after the conversion you can revert the changes by running the script with the old settings"
            WriteRunLog -message "Here is the command to revert the changes:" -category "IMPORTANT"
            WriteRunLog -message "   .\Azure-NVMe-Conversion.ps1 -ResourceGroupName $ResourceGroupName -VMName $VMName -NewControllerType SCSI -VMSize $script:_original_vm_size -StartVM"
        }
        WriteRunLog $_.Exception.Message "ERROR"
        exit
    }
}
else {
    WriteRunLog -message "VM $VMName is stopped. Please start the VM manually."
    WriteRunLog -message "If the VM should be started automatically use -StartVM switch"
}

# Check if breaking change warning was enabled before
if ($_breakingchangewarning.Value -eq $true) {
    WriteRunLog -message "Breaking Change Warning was enabled before script execution. Enabling it again."
    Update-AzConfig -DisplayBreakingChangeWarning $true
}

# Info for next steps
if ($StartVM) {
    WriteRunLog -message "As the virtual machine got started using the script you can check the operating system now"
}
else {
    WriteRunLog -message "Please start the virtual machine manually and check the operating system" -category "IMPORTANT"
    WriteRunLog -message "You can also use -StartVM switch to start the VM automatically"
}
if ($NewControllerType -eq "NVMe") {
    WriteRunLog -message "If you have any issues after the conversion you can revert the changes by running the script with the old settings"
    WriteRunLog -message "Here is the command to revert the changes:" -category "IMPORTANT"
    WriteRunLog -message "   .\Azure-NVMe-Conversion.ps1 -ResourceGroupName $ResourceGroupName -VMName $VMName -NewControllerType SCSI -VMSize $script:_original_vm_size -StartVM"
}

# Done
WriteRunLog -message "Script ended at $(Get-Date)"
WriteRunLog -message "Exiting"
