<#
.SYNOPSIS
    Convert Azure Virtual Machines between SCSI and NVMe disk controller,
    with full support for Windows VMs migrating from a size with local temp disk
    to a size without (e.g. E8bds_v5 -> E8as_v7), which requires VM recreation.

.DESCRIPTION
    Combines NVMe conversion with the Microsoft-documented migration path for
    Windows VMs moving between local-disk and diskless VM sizes.

    Two execution paths:

    PATH A  -  RESIZE  (Update-AzVM)
      Used when: Linux VM (always), or Windows VM staying in the same disk category
                 (disk->disk or diskless->diskless). Can be forced with -ForcePathA.
      Steps: OS prep -> stop -> update OS disk capabilities -> resize -> start.

    PATH B  -  RECREATE  (snapshot -> new VM)
      Used when: Windows VM where source and target are in different disk architecture
                 categories. Azure blocks direct resize for all three cross-category
                 combinations on Windows (platform restriction):
                   - SCSI temp disk (v5/older, e.g. E8bds_v5) -> NVMe temp disk (v6/v7, e.g. E8ads_v7)
                   - Any size with temp disk -> diskless (e.g. E8as_v7)
                   - Diskless -> any size with temp disk
                 Linux VMs are not affected and always use PATH A.

      Disk architecture categories:
                   scsi-temp : MaxResourceVolumeMB > 0  (reliable for all sizes, incl. older
                               sizes like B2ms/D2s_v3 that predate the 'd' naming convention)
                   nvme-temp : MaxResourceVolumeMB = 0 AND name has 'd'  (v6 and v7)
                   diskless  : MaxResourceVolumeMB = 0 AND name has no 'd'

      PATH B is triggered whenever source and target are in different categories.
      Can be forced with -ForcePathB (e.g. to test recreation on a Windows VM
      that would otherwise qualify for PATH A).
      Steps: pagefile migration -> stop -> snapshot OS disk (safety backup)
             -> delete VM shell -> recreate VM reusing original OS disk + NICs + data disks
             -> start -> delete snapshot.

    Path selection logic:
      Auto   : PATH B when Windows + source and target are in different disk architecture
               categories (scsi-temp, nvme-temp, or diskless). Linux always uses PATH A.
      -ForcePathA : Always use resize, even when the script would select PATH B.
                    Use only if you are certain the platform allows it.
      -ForcePathB : Always use recreation, even when PATH A would suffice.

.PARAMETER ResourceGroupName
    Name of the Resource Group where the VM is located.
.PARAMETER VMName
    Name of the VM to convert.
.PARAMETER NewControllerType
    Target disk controller type: NVMe or SCSI. Default: NVMe.
.PARAMETER VMSize
    Target VM size (e.g. Standard_E8as_v7). Required.
.PARAMETER StartVM
    Start the VM automatically after conversion (resize path only;
    recreation path always starts the VM via New-AzVM).
.PARAMETER WriteLogfile
    Write a log file to the current directory.
.PARAMETER IgnoreSKUCheck
    Skip SKU availability and capability checks.
.PARAMETER IgnoreWindowsVersionCheck
    Skip the Windows OS version check (>= 2019 required for NVMe).
.PARAMETER FixOperatingSystemSettings
    Automatically fix OS settings via RunCommand:
      - Windows: set stornvme to Boot, remove StartOverride.
      - Windows: migrate pagefile from D:\ to C:\ when needed.
    Without this switch the script checks and warns but does not fix.
.PARAMETER IgnoreAzureModuleCheck
    Skip the Az module version check.
.PARAMETER IgnoreOSCheck
    Skip all OS-level checks (no RunCommand executed).
.PARAMETER SkipPagefileFix
    Skip pagefile migration even when a disk mismatch is detected.
    Use when the pagefile was already migrated manually.
.PARAMETER ForcePathA
    Force PATH A (resize via Update-AzVM) even when the script would normally select
    PATH B. On Windows, Azure blocks direct resize between disk and diskless sizes
    in both directions. Use only if you are certain the platform allows it.

.PARAMETER ForcePathB
    Force PATH B (VM recreation) even when PATH A would normally be used.
    Useful for testing, or for cases where you prefer recreation over resize.

.PARAMETER KeepSnapshot
    Keep the OS disk snapshot after recreation (useful as a rollback point).
    Default: snapshot is deleted once the new VM is created successfully.
.PARAMETER NVMEDiskInitScriptLocation
    Folder on the VM where NVMeTempDiskInit.ps1 and Wait-ForDrive-D.ps1.snippet.txt
    are written during STEP 1c. Default: C:\AdminScripts
.PARAMETER NVMEDiskInitScriptSkip
    Skip installation of the NVMe temp disk startup script and scheduled task (STEP 1c).
    Use when the task is already present from a previous run, or when you prefer to
    manage temp disk initialization yourself.
.PARAMETER EnableAcceleratedNetworking
    Enable Accelerated Networking on all NICs, if the target VM size supports it.
    Has no effect if the target size does not support it (a warning is logged instead).
    Use this when the target size supports Accelerated Networking and you want it
    enabled automatically during the conversion.
.PARAMETER Force
    Skip the confirmation prompt before deleting and recreating the VM (PATH B).
    Use in automated/unattended pipelines where interactive prompts are not possible.
    Error-condition prompts (e.g. pagefile warnings, OS check failures) are unaffected.
.PARAMETER SleepSeconds
    Seconds to wait before starting the VM after resize. Default: 15.

.EXAMPLE
    # Full conversion: NVMe + resize to diskless + auto pagefile fix
    .\AzureVM-NVME-and-localdisk-Conversion.ps1 `
        -ResourceGroupName "myRG" -VMName "myVM" `
        -NewControllerType NVMe -VMSize "Standard_E8as_v7" `
        -FixOperatingSystemSettings `
        -StartVM -WriteLogfile

.EXAMPLE
    # Rollback: revert to SCSI + original size (resize path)
    .\AzureVM-NVME-and-localdisk-Conversion.ps1 `
        -ResourceGroupName "myRG" -VMName "myVM" `
        -NewControllerType SCSI -VMSize "Standard_E8bds_v5" `
        -StartVM -WriteLogfile

.LINK
    https://learn.microsoft.com/en-us/azure/virtual-machines/azure-vms-no-temp-disk
    https://github.com/Azure/SAP-on-Azure-Scripts-and-Utilities/tree/main/Azure-NVMe-Utils
#>

[CmdletBinding()]
param (
    [Parameter(Mandatory=$true)][string]  $ResourceGroupName,
    [Parameter(Mandatory=$true)][string]  $VMName,
    [ValidateSet("NVMe","SCSI")]
    [string]  $NewControllerType = "NVMe",
    [Parameter(Mandatory=$true)][string]  $VMSize,
    [switch]  $StartVM,
    [switch]  $WriteLogfile,
    [switch]  $IgnoreSKUCheck,
    [switch]  $IgnoreWindowsVersionCheck,
    [switch]  $FixOperatingSystemSettings,
    [switch]  $IgnoreAzureModuleCheck,
    [switch]  $IgnoreOSCheck,
    [switch]  $SkipPagefileFix,
    [switch]  $KeepSnapshot,
    [switch]  $ForcePathA,
    [switch]  $ForcePathB,
    [int]     $SleepSeconds = 15,
    [string]  $NVMEDiskInitScriptLocation = "C:\AdminScripts",
    [switch]  $NVMEDiskInitScriptSkip,
    [switch]  $EnableAcceleratedNetworking,
    [switch]  $Force
)

$ErrorActionPreference = "Stop"

# Normalise controller type casing  -  ValidateSet is case-insensitive on input
# but preserves what the user typed, which breaks -eq comparisons later.
$NewControllerType = switch ($NewControllerType.ToUpper()) {
    "NVME" { "NVMe" }
    "SCSI" { "SCSI" }
    default { $NewControllerType }
}

##############################################################################################################
# Logging
##############################################################################################################

$script:_starttime = Get-Date
$script:_logfile   = "AzureVM-NVME-and-localdisk-Conversion-$($VMName)-$((Get-Date).ToString('yyyyMMdd-HHmmss')).log"

function WriteLog {
    [CmdletBinding()]
    param(
        [string]$Message,
        [ValidateSet("INFO","WARNING","ERROR","IMPORTANT")][string]$Category = "INFO"
    )
    $colors   = @{ INFO="Green"; WARNING="Yellow"; ERROR="Red"; IMPORTANT="Cyan" }
    $prefixes = @{ INFO="INFO      - "; WARNING="WARNING   - "; ERROR="ERROR     - "; IMPORTANT="IMPORTANT - " }
    $offset   = ((Get-Date) - $script:_starttime).ToString("mm\:ss")
    $entry    = "$offset - $($prefixes[$Category])$Message"
    Write-Host $entry -ForegroundColor $colors[$Category]
    if ($WriteLogfile -and $script:_logfile) {
        $entry | Out-File -FilePath $script:_logfile -Append -Encoding utf8
    }
}

function AskToContinue {
    param([string]$Message)
    WriteLog $Message "IMPORTANT"
    $answer = Read-Host "Continue? (Y/N)"
    if ($answer -notin @("Y","y")) {
        WriteLog "Script aborted by user." "ERROR"
        exit 1
    }
}

function WaitForVMPowerState {
    param(
        [string]$ExpectedState,
        [int]$TimeoutSeconds = 300,
        [int]$PollInterval   = 15
    )
    WriteLog "Waiting for VM power state: '$ExpectedState' (timeout: ${TimeoutSeconds}s)..."
    $sw = [Diagnostics.Stopwatch]::StartNew()
    while ($sw.Elapsed.TotalSeconds -lt $TimeoutSeconds) {
        try {
            $status = Get-AzVM -ResourceGroupName $ResourceGroupName -Name $VMName -Status -ErrorAction SilentlyContinue
            if ($status) {
                $power = ($status.Statuses | Where-Object { $_.Code -like 'PowerState*' }).Code
                if ($power -eq $ExpectedState) {
                    WriteLog "VM reached power state: $ExpectedState"
                    return $true
                }
                WriteLog "  Current: $power  -  waiting..."
            }
        } catch {
            WriteLog "  Error retrieving status: $_  -  retrying..." "WARNING"
        }
        Start-Sleep -Seconds $PollInterval
    }
    WriteLog "Timeout waiting for power state '$ExpectedState'." "ERROR"
    return $false
}

function Invoke-RunCommand {
    param(
        [string]$ScriptString,
        [string]$CommandId   = "RunPowerShellScript",
        [string]$Description = "RunCommand"
    )
    WriteLog "Executing RunCommand: $Description..."
    try {
        $result = Invoke-AzVMRunCommand `
            -ResourceGroupName $ResourceGroupName `
            -VMName            $VMName `
            -CommandId         $CommandId `
            -ScriptString      $ScriptString
        return ($result.Value | ForEach-Object { $_.Message }) -split "`n"
    } catch {
        WriteLog "Error executing RunCommand ($Description): $_" "ERROR"
        throw
    }
}

function ParseAndLogOutput {
    param([string[]]$Lines)
    $errorCount = 0
    foreach ($line in $Lines) {
        $line = $line.Trim()
        if (-not $line) { continue }
        $lvl = if ($line -match "^ERROR")       { "ERROR"   }
               elseif ($line -match "^WARNING")  { "WARNING" }
               else                              { "INFO"    }
        WriteLog "  OS > $line" $lvl
        if ($lvl -eq "ERROR") { $errorCount++ }
    }
    return $errorCount
}

function EnsureVMRunning {
    try {
        $s = Get-AzVM -ResourceGroupName $ResourceGroupName -Name $VMName -Status -ErrorAction Stop
        $p = ($s.Statuses | Where-Object { $_.Code -like 'PowerState*' }).Code
        if ($p -ne "PowerState/running") {
            WriteLog "VM is not running ($p)  -  starting VM for RunCommand..."
            Start-AzVM -ResourceGroupName $ResourceGroupName -Name $VMName -ErrorAction Stop | Out-Null
            if (-not (WaitForVMPowerState -ExpectedState "PowerState/running" -TimeoutSeconds 360)) {
                WriteLog "VM could not be started." "ERROR"
                exit 1
            }
        }
    } catch {
        WriteLog "Error ensuring VM is running: $_" "ERROR"
        exit 1
    }
}

function Get-AzAccessTokenString {
    try {
        $token = (Get-AzAccessToken -ErrorAction Stop).Token
    } catch {
        WriteLog "Failed to retrieve Azure access token: $_" "ERROR"
        throw
    }
    if ($token.GetType().Name -eq "SecureString") {
        $ptr    = [System.Runtime.InteropServices.Marshal]::SecureStringToCoTaskMemUnicode($token)
        $result = [System.Runtime.InteropServices.Marshal]::PtrToStringUni($ptr)
        [System.Runtime.InteropServices.Marshal]::ZeroFreeCoTaskMemUnicode($ptr)
        WriteLog "Access token converted from SecureString (Cloud Shell)."
        return $result
    }
    return $token
}

function Set-OSDiskControllerTypes {
    param([string]$DiskName, [string]$DiskResourceGroup, [string]$ControllerTypes)
    $token   = Get-AzAccessTokenString
    $diskUrl = "https://management.azure.com/subscriptions/$($azCtx.Subscription.Id)" +
               "/resourceGroups/$DiskResourceGroup/providers/Microsoft.Compute/disks/$DiskName" +
               "?api-version=2023-04-02"
    $body    = @{ properties = @{ supportedCapabilities = @{ diskControllerTypes = $ControllerTypes } } } | ConvertTo-Json -Depth 5 -Compress
    $headers = @{ 'Content-Type' = 'application/json'; 'Authorization' = "Bearer $token" }
    WriteLog "Patching OS disk '$DiskName': diskControllerTypes = '$ControllerTypes'..."
    Invoke-RestMethod -Uri $diskUrl -Method PATCH -Headers $headers -Body $body | Out-Null
    WriteLog "OS disk updated."
}

function Get-DiskArchitecture {
    # Returns one of three disk architecture categories for a given VM size:
    #   'scsi-temp' : SCSI-based local temp disk. Detected by MaxResourceVolumeMB > 0.
    #                 Covers all sizes that have a local disk, including older sizes like B2ms,
    #                 D2s_v3, E4s_v3 that predate the 'd' naming convention, as well as modern
    #                 sizes like E8bds_v5, E8ds_v5 that do use the 'd' flag.
    #   'nvme-temp' : NVMe-based local temp disk (v6/v7 only). MaxResourceVolumeMB = 0 in the API
    #                 (Azure reports 0 because the disk is presented raw/unformatted on each boot),
    #                 but the size name contains 'd' (e.g. E8ads_v7, E8bds_v6).
    #                 Windows cannot use this for pagefile without extra configuration.
    #   'diskless'  : No local temp disk. MaxResourceVolumeMB = 0 AND no 'd' in name.
    #
    # PATH B (VM recreation) is required whenever source and target are in DIFFERENT categories.
    # This restriction applies to WINDOWS ONLY  -  Linux VMs always use PATH A regardless of category.
    param([string]$SizeName, $SKU)

    $_apiValue  = $null
    $_apiHasDisk = $false
    if ($SKU) {
        $_apiValue   = ($SKU.Capabilities | Where-Object { $_.Name -eq "MaxResourceVolumeMB" }).Value
        $_apiHasDisk = ($null -ne $_apiValue -and [int]$_apiValue -gt 0)
    }

    # Name parsing  -  'd' in capability letters means local disk (SCSI or NVMe depending on generation)
    $_nameHasDisk = $false
    if ($SizeName -match '_[A-Z]+\d+([a-z]+)_v\d+') {
        $_nameHasDisk = ($Matches[1] -like '*d*')
    }

    # Determine category:
    #   API > 0              -> scsi-temp  (reliable for all sizes, including older ones like B2ms,
    #                          D2s_v3, E4s_v3 that predate the 'd' naming convention entirely)
    #   API = 0, name has d  -> nvme-temp  (v6/v7: API reports 0 but disk exists as raw NVMe)
    #   API = 0, no d        -> diskless   (no local disk at all)
    #
    # The 'd' in the name is ONLY used to distinguish nvme-temp from diskless when API = 0.
    # It is NOT used to detect disk presence for older sizes, where the API value is authoritative.
    if ($_apiHasDisk) {
        $_category = 'scsi-temp'   # API confirms SCSI temp disk (all generations, all naming styles)
    } elseif ($_nameHasDisk) {
        $_category = 'nvme-temp'   # API = 0 but name has 'd' -> v6/v7 NVMe temp disk (raw on each boot)
    } else {
        $_category = 'diskless'    # API = 0 and no 'd' in name -> truly diskless
    }

    WriteLog "  $SizeName  -  MaxResourceVolumeMB='$_apiValue', name-has-d=$_nameHasDisk -> category: $_category"
    return $_category
}

##############################################################################################################
# SCRIPT START
##############################################################################################################

WriteLog "=======================================================" "IMPORTANT"
WriteLog " AzureVM-NVME-and-localdisk-Conversion.ps1" "IMPORTANT"
WriteLog "=======================================================" "IMPORTANT"
WriteLog "Parameters:"
foreach ($key in $MyInvocation.BoundParameters.Keys) {
    WriteLog "  $key -> $((Get-Variable -Name $key -ErrorAction SilentlyContinue).Value)"
}

$_bcw = Get-AzConfig -DisplayBreakingChangeWarning | Select-Object -First 1
$_bcwWasEnabled = ($_bcw -and $_bcw.Value -eq $true)
if ($_bcwWasEnabled) { Update-AzConfig -DisplayBreakingChangeWarning $false | Out-Null }
try {

##############################################################################################################
# MODULE CHECK
##############################################################################################################

function CheckModule {
    param([string]$Name, [version]$MinVersion)
    $found = Get-Module -ListAvailable -Name $Name
    if (-not $found) {
        WriteLog "Module '$Name' not installed. Run: Install-Module -Name $Name -Force" "ERROR"; exit 1
    }
    if ($MinVersion -and (@($found | Where-Object { $_.Version -ge $MinVersion }).Count -eq 0)) {
        WriteLog "Module '$Name' requires version >= $MinVersion. Run: Update-Module -Name $Name" "ERROR"; exit 1
    }
    WriteLog "Module '$Name' OK (required >= $MinVersion)."
}

if (-not $IgnoreAzureModuleCheck) {
    CheckModule -Name "Az.Compute"   -MinVersion "11.3.0"
    CheckModule -Name "Az.Accounts"  -MinVersion "5.3.2"
    CheckModule -Name "Az.Resources" -MinVersion "7.0"
} else {
    WriteLog "Module check skipped (IgnoreAzureModuleCheck)." "WARNING"
}

##############################################################################################################
# AZURE CONTEXT + VM
##############################################################################################################

try {
    $azCtx = Get-AzContext
    if (-not $azCtx) { WriteLog "No Azure context. Run 'Connect-AzAccount' first." "ERROR"; exit 1 }
    WriteLog "Subscription: $($azCtx.Subscription.Name) ($($azCtx.Subscription.Id))"
} catch { WriteLog "Error getting Azure context: $_" "ERROR"; exit 1 }

try {
    $vm = Get-AzVM -ResourceGroupName $ResourceGroupName -Name $VMName
    WriteLog "VM found: $VMName"
} catch { WriteLog "VM '$VMName' not found in '$ResourceGroupName': $_" "ERROR"; exit 1 }

$script:_originalSize       = $vm.HardwareProfile.VmSize
$script:_originalController = $vm.StorageProfile.DiskControllerType
$_os                        = $vm.StorageProfile.OsDisk.OsType
WriteLog "Current size        : $script:_originalSize"
WriteLog "Current controller  : $script:_originalController"
WriteLog "OS                  : $_os"

# ADE check (Linux)
if ($_os -eq "Linux") {
    try {
        $ade = Get-AzVMExtension -ResourceGroupName $ResourceGroupName -VMName $VMName `
               -Name "AzureDiskEncryptionForLinux" -ErrorAction Stop
        if ($ade.ProvisioningState -eq "Succeeded") {
            WriteLog "ADE for Linux found  -  NVMe is not supported with ADE." "ERROR"; exit 1
        }
    } catch [Microsoft.Azure.Commands.Compute.Common.ComputeCloudException] {
        # 404 = extension not present - expected and safe to continue
        WriteLog "ADE for Linux not found  -  OK."
    } catch {
        # Unexpected error (permissions, network, etc.) - warn but do not block
        WriteLog "Warning: could not check ADE extension status: $_  -  proceeding." "WARNING"
    }
}

# Power state
$vmStatus   = Get-AzVM -ResourceGroupName $ResourceGroupName -Name $VMName -Status
$powerState = ($vmStatus.Statuses | Where-Object { $_.Code -like 'PowerState*' }).Code
WriteLog "Current power state : $powerState"

# Windows version
if ($_os -eq "Windows" -and $NewControllerType -eq "NVMe" -and -not $IgnoreWindowsVersionCheck) {
    $imgRef = $vm.StorageProfile.ImageReference
    if ($imgRef -and $imgRef.Publisher -eq "MicrosoftWindowsServer") {
        $skuNum = $imgRef.Sku -replace "[^0-9]", ""
        if ([int]$skuNum -lt 2019) {
            WriteLog "Windows version $skuNum < 2019. NVMe requires Windows Server 2019+." "ERROR"; exit 1
        }
        WriteLog "Windows version: $($imgRef.Sku)  -  OK."
    } else {
        WriteLog "Cannot determine Windows version (non-marketplace image)  -  assuming OK." "WARNING"
    }
} elseif ($IgnoreWindowsVersionCheck) {
    WriteLog "Windows version check skipped (IgnoreWindowsVersionCheck)." "WARNING"
}

# Generation check
try {
    $diskRg = $vm.StorageProfile.OsDisk.ManagedDisk.Id.Split("/")[4]
    $osDisk = Get-AzDisk -Name $vm.StorageProfile.OsDisk.Name -ResourceGroupName $diskRg
    if ($osDisk.HyperVGeneration -eq "V1") {
        WriteLog "Generation 1 VM  -  NVMe requires Generation 2." "ERROR"; exit 1
    }
    WriteLog "VM Generation: $($osDisk.HyperVGeneration)  -  OK."
} catch { WriteLog "Error retrieving Hyper-V Generation: $_" "ERROR"; exit 1 }

# Controller / size already correct?
$_controllerAlreadyCorrect = ($script:_originalController -eq $NewControllerType)
$_sizeAlreadyCorrect       = ($script:_originalSize -eq $VMSize)

if ($_controllerAlreadyCorrect -and $_sizeAlreadyCorrect) {
    WriteLog "VM is already $NewControllerType at size $VMSize  -  nothing to do." "WARNING"
    exit 0
}
if ($_controllerAlreadyCorrect) {
    WriteLog "Controller already $NewControllerType  -  controller update and OS driver steps will be skipped." "WARNING"
}
if ($_sizeAlreadyCorrect) {
    WriteLog "Size already $VMSize  -  only controller type will be changed." "WARNING"
}

##############################################################################################################
# SKU CHECK + LOCAL DISK DETECTION
##############################################################################################################

$_sourceDiskArch = 'diskless'   # will be set properly in SKU check
$_targetDiskArch = 'diskless'   # will be set properly in SKU check

if (-not $IgnoreSKUCheck) {
    WriteLog "Retrieving SKU capabilities (this may take a while)..."
    $allSKUs   = Get-AzComputeResourceSku -Location $vm.Location | Where-Object { $_.ResourceType -eq "virtualMachines" }
    $targetSKU = $allSKUs | Where-Object { $_.Name -eq $VMSize }               | Select-Object -First 1
    $sourceSKU = $allSKUs | Where-Object { $_.Name -eq $script:_originalSize } | Select-Object -First 1

    if (-not $targetSKU) {
        WriteLog "VM size '$VMSize' not found in region '$($vm.Location)'." "ERROR"; exit 1
    }
    if (-not $sourceSKU) {
        WriteLog "Current size '$script:_originalSize' not in SKU list  -  name-based detection only." "WARNING"
    }

    # Zone check
    $_vmZones = @($vm.Zones | Where-Object { $_ })
    if ($_vmZones.Count -gt 0) {
        $zone = $_vmZones[0]
        if (-not ($targetSKU.LocationInfo | Where-Object { $_.Zones -contains $zone })) {
            WriteLog "Size '$VMSize' not available in zone $zone." "ERROR"; exit 1
        }
        WriteLog "SKU available in zone $zone  -  OK."
    } else {
        WriteLog "VM is not zone-pinned  -  zone check skipped."
    }

    # Disk controller support check
    # Note: older SCSI-only SKUs do not list DiskControllerTypes in their capabilities at all.
    # Absence of the capability = SCSI only. Treat null/empty as "SCSI".
    $controllerTypes = ($targetSKU.Capabilities | Where-Object { $_.Name -eq "DiskControllerTypes" }).Value
    $effectiveControllerTypes = if ($controllerTypes) { $controllerTypes } else { "SCSI" }
    if (-not ($effectiveControllerTypes -like "*$NewControllerType*")) {
        WriteLog "Size '$VMSize' does not support $NewControllerType controller. Supported: $effectiveControllerTypes" "ERROR"
        if ($NewControllerType -eq "SCSI") {
            WriteLog "  Hint: '$VMSize' is NVMe-only. Use -NewControllerType NVMe instead." "ERROR"
        } elseif ($NewControllerType -eq "NVMe") {
            WriteLog "  Hint: '$VMSize' is SCSI-only. Use -NewControllerType SCSI instead." "ERROR"
        }
        exit 1
    }
    if (-not $_controllerAlreadyCorrect) {
        WriteLog "Controller check OK: $VMSize supports $effectiveControllerTypes"
    }

    # Disk architecture detection
    WriteLog "Detecting disk architecture category..."
    $_sourceDiskArch = Get-DiskArchitecture -SizeName $script:_originalSize -SKU $sourceSKU
    $_targetDiskArch = Get-DiskArchitecture -SizeName $VMSize               -SKU $targetSKU
    WriteLog "Source disk architecture: $_sourceDiskArch ($script:_originalSize)"
    WriteLog "Target disk architecture: $_targetDiskArch ($VMSize)"

} else {
    WriteLog "SKU check skipped (IgnoreSKUCheck)  -  using name-based detection only." "WARNING"
    $_sourceDiskArch = Get-DiskArchitecture -SizeName $script:_originalSize -SKU $null
    $_targetDiskArch = Get-DiskArchitecture -SizeName $VMSize               -SKU $null
    WriteLog "Source disk architecture (name-based): $_sourceDiskArch"
    WriteLog "Target disk architecture (name-based): $_targetDiskArch"
}

# Determine which execution path to use
# Path selection
# Azure blocks direct resize on Windows whenever source and target are in different
# disk architecture categories. Three categories exist:
#   scsi-temp   -  SCSI local temp disk (v5/older)
#   nvme-temp   -  NVMe local temp disk (v6/v7), raw on each boot
#   diskless    -  no local temp disk
# Any cross-category combination requires PATH B (VM recreation).
# Linux VMs are not subject to this restriction and always use PATH A.
$_crossCategory   = ($_os -eq "Windows") -and ($_sourceDiskArch -ne $_targetDiskArch)
# Pagefile fix only needed when moving away from a SCSI temp disk (where pagefile lives on D:\)
# nvme-temp disks are raw/unformatted so pagefile cannot be on D:\ in the first place
$_needPagefileFix = ($_os -eq "Windows") -and ($_sourceDiskArch -eq 'scsi-temp') -and ($_targetDiskArch -ne 'scsi-temp')

if ($_crossCategory) {
    WriteLog "Windows disk architecture change: $_sourceDiskArch -> $_targetDiskArch" "IMPORTANT"
    switch ("$_sourceDiskArch->$_targetDiskArch") {
        "scsi-temp->nvme-temp" { WriteLog "  SCSI temp disk -> NVMe temp disk (v6/v7). D:\ will reappear as raw NVMe disk." "IMPORTANT" }
        "scsi-temp->diskless"  { WriteLog "  SCSI temp disk -> diskless. D:\ will be lost." "IMPORTANT" }
        "nvme-temp->scsi-temp" { WriteLog "  NVMe temp disk (v6/v7) -> SCSI temp disk." "IMPORTANT" }
        "nvme-temp->diskless"  { WriteLog "  NVMe temp disk -> diskless. D:\ will be lost." "IMPORTANT" }
        "diskless->scsi-temp"  { WriteLog "  Diskless -> SCSI temp disk. D:\ will appear after recreation." "IMPORTANT" }
        "diskless->nvme-temp"  { WriteLog "  Diskless -> NVMe temp disk (v6/v7). D:\ will appear as raw NVMe disk." "IMPORTANT" }
    }
}

# Validate mutually exclusive overrides
if ($ForcePathA -and $ForcePathB) {
    WriteLog "-ForcePathA and -ForcePathB cannot be used together." "ERROR"
    exit 1
}

if ($ForcePathA) {
    $_useRecreationPath = $false
    if ($_crossCategory) {
        WriteLog "-ForcePathA specified  -  overriding automatic PATH B selection." "WARNING"
        WriteLog "Azure may reject resize between '$_sourceDiskArch' and '$_targetDiskArch' on Windows. Proceeding anyway." "WARNING"
    }
    WriteLog "PATH A selected: VM RESIZE (forced via -ForcePathA)." "IMPORTANT"
} elseif ($ForcePathB) {
    $_useRecreationPath = $true
    WriteLog "PATH B selected: VM RECREATION (forced via -ForcePathB)." "IMPORTANT"
} elseif ($_crossCategory) {
    $_useRecreationPath = $true
    WriteLog "====================================================================" "IMPORTANT"
    WriteLog " PATH B selected: VM RECREATION" "IMPORTANT"
    WriteLog " Azure blocks direct resize on Windows when the source and target have" "IMPORTANT"
    WriteLog " different disk architectures (scsi-temp / nvme-temp / diskless)." "IMPORTANT"
    WriteLog " This includes disk->diskless, diskless->disk, and v5->v6/v7 with temp disk." "IMPORTANT"
    WriteLog " The VM will be deleted and recreated with the same NICs and disks." "IMPORTANT"
    WriteLog " Use -ForcePathA to attempt a direct resize instead (not recommended)." "IMPORTANT"
    WriteLog "====================================================================" "IMPORTANT"
} else {
    $_useRecreationPath = $false
    WriteLog "PATH A selected: VM RESIZE (Update-AzVM)." "INFO"
}

# Accelerated networking advisory/action check (runs for both PATH A and PATH B)
# When target size supports accel networking:
#   -EnableAcceleratedNetworking specified -> will be enabled on NICs in STEP 7B.
#   Not specified -> warn if any NIC currently has it disabled.
# When target size does not support it: disabled on NICs in STEP 7B if needed.
if (-not $IgnoreSKUCheck) {
    $_accelNetCapability = ($targetSKU.Capabilities | Where-Object { $_.Name -eq "AcceleratedNetworkingEnabled" }).Value
    $_accelNetSupported  = $_accelNetCapability -eq "True"
    if ($EnableAcceleratedNetworking -and -not $_accelNetSupported) {
        WriteLog "  -EnableAcceleratedNetworking specified but target size $VMSize does not support it - flag will be ignored." "WARNING"
    } elseif ($EnableAcceleratedNetworking -and $_accelNetSupported) {
        if (-not $_useRecreationPath) {
            WriteLog "  -EnableAcceleratedNetworking specified but PATH A (resize) is selected - NICs are not modified on resize." "WARNING"
            WriteLog "    To enable AcceleratedNetworking, use the Azure Portal or re-run after conversion with -EnableAcceleratedNetworking on PATH B." "WARNING"
        } else {
            WriteLog "  -EnableAcceleratedNetworking specified - AcceleratedNetworking will be enabled on all NICs." "INFO"
        }
    } elseif ($_accelNetSupported) {
        $vm.NetworkProfile.NetworkInterfaces | ForEach-Object {
            $nicName = $_.Id.Split('/')[-1]
            $nicRg   = $_.Id.Split('/')[4]
            $nicObj  = Get-AzNetworkInterface -Name $nicName -ResourceGroupName $nicRg
            if (-not $nicObj.EnableAcceleratedNetworking) {
                WriteLog "  Advisory: NIC '$nicName' has AcceleratedNetworking disabled. Target size $VMSize supports it." "WARNING"
                WriteLog "    Enable automatically : re-run with -EnableAcceleratedNetworking" "WARNING"
                WriteLog "    Enable manually      : Azure Portal > NIC '$nicName' > Accelerated networking > Enabled" "WARNING"
            }
        }
    }
}

# Pagefile guard  -  must fix before proceeding
if ($_needPagefileFix -and -not $SkipPagefileFix) {
    if (-not $FixOperatingSystemSettings) {
        WriteLog "Source has a SCSI temp disk (D:\) and target does not  -  pagefile on D:\ must be migrated to C:\ first." "IMPORTANT"
        WriteLog "STOPPING  -  re-run with one of:" "ERROR"
        WriteLog "  -FixOperatingSystemSettings   Migrate pagefile automatically (recommended)" "ERROR"
        WriteLog "  -SkipPagefileFix              Skip if already migrated manually" "ERROR"
        exit 1
    }
}

##############################################################################################################
# STEP 1  -  NVMe DRIVER PREPARATION (Windows, controller not yet NVMe)
##############################################################################################################

if (-not $_controllerAlreadyCorrect -and $_os -eq "Windows" -and $NewControllerType -eq "NVMe" -and -not $IgnoreOSCheck) {
    WriteLog "--- STEP 1: Windows NVMe driver preparation ---" "IMPORTANT"
    EnsureVMRunning

    $checkNVMe = @'
$reg   = "HKLM:\SYSTEM\CurrentControlSet\Services\stornvme"
$start = (Get-ItemProperty -Path $reg -Name Start -ErrorAction SilentlyContinue).Start
if ($start -eq 0) { Write-Output "Start:OK" } else { Write-Output "Start:ERROR (value=$start)" }
$so = Get-ItemProperty -Path "$reg\StartOverride" -ErrorAction SilentlyContinue
if ($so) { Write-Output "StartOverride:ERROR (present)" } else { Write-Output "StartOverride:OK" }
'@

    $fixNVMe = @'
$reg = "HKLM:\SYSTEM\CurrentControlSet\Services\stornvme"
$so  = Get-ItemProperty -Path "$reg\StartOverride" -ErrorAction SilentlyContinue
if ($so) { Remove-Item -Path "$reg\StartOverride" -Force; Write-Output "INFO: StartOverride removed." }
else { Write-Output "INFO: StartOverride not present - OK." }
$sc = & sc.exe config stornvme start=boot 2>&1
Write-Output "SC: $sc"
$after = (Get-ItemProperty -Path $reg -Name Start).Start
if ($after -eq 0) { Write-Output "INFO: stornvme Start=Boot - OK." }
else { Write-Output "ERROR: stornvme Start=$after - manual check required!" }
'@

    if ($FixOperatingSystemSettings) {
        WriteLog "Fixing stornvme driver (set to Boot)..."
        $out    = Invoke-RunCommand -ScriptString $fixNVMe -Description "stornvme fix"
        $errors = ParseAndLogOutput -Lines $out
        if ($errors -gt 0) { AskToContinue "Errors in NVMe driver fix. Continue?" }
    } else {
        WriteLog "Checking stornvme driver (check only)..."
        $out    = Invoke-RunCommand -ScriptString $checkNVMe -Description "stornvme check"
        $errors = 0
        foreach ($line in $out) {
            $line = $line.Trim(); if (-not $line) { continue }
            if ($line -like "Start:ERROR*")         { WriteLog "stornvme NOT set to Boot!" "ERROR"; $errors++ }
            elseif ($line -like "Start:OK*")        { WriteLog "stornvme Start=Boot  -  OK." }
            if ($line -like "StartOverride:ERROR*") { WriteLog "StartOverride present  -  may override Boot!" "ERROR"; $errors++ }
            elseif ($line -like "StartOverride:OK*"){ WriteLog "StartOverride not present  -  OK." }
        }
        if ($errors -gt 0) {
            WriteLog "OS not ready for NVMe. Use -FixOperatingSystemSettings to fix." "WARNING"
            AskToContinue "Continue despite errors?"
        }
    }

} elseif (-not $_controllerAlreadyCorrect -and $_os -eq "Linux" -and $NewControllerType -eq "NVMe" -and -not $IgnoreOSCheck) {
    WriteLog "--- STEP 1: Linux NVMe driver preparation ---" "IMPORTANT"
    EnsureVMRunning

    $linuxScript = @'
#!/bin/bash
fix=false
if [ -f /etc/os-release ]; then source /etc/os-release; distro="$ID"; else distro="unknown"; fi
echo "[INFO] Distro: $distro"
case "$distro" in
    ubuntu|debian)
        lsinitramfs /boot/initrd.img-* 2>/dev/null | grep -q nvme && echo "[INFO] NVMe in initrd - OK." || {
            echo "[ERROR] NVMe NOT in initrd."
            $fix && { update-initramfs -u -k all; echo "[INFO] initrd updated."; }
        } ;;
    rhel|centos|rocky|almalinux|sles|suse|ol)
        lsinitrd 2>/dev/null | grep -q nvme && echo "[INFO] NVMe in initrd - OK." || {
            echo "[ERROR] NVMe NOT in initrd."
            $fix && { mkdir -p /etc/dracut.conf.d; echo 'add_drivers+=" nvme nvme-core "' > /etc/dracut.conf.d/nvme.conf; dracut -f; echo "[INFO] initrd updated."; }
        } ;;
    *) echo "[WARNING] Unknown distro - initrd check skipped." ;;
esac
grep -q "nvme_core.io_timeout=240" /etc/default/grub /etc/grub.conf /boot/grub/grub.cfg 2>/dev/null \
    && echo "[INFO] nvme_core.io_timeout=240 - OK." \
    || { echo "[ERROR] nvme_core.io_timeout=240 not set."
         $fix && { sed -i 's/GRUB_CMDLINE_LINUX="/GRUB_CMDLINE_LINUX="nvme_core.io_timeout=240 /g' /etc/default/grub
                   command -v grub2-mkconfig >/dev/null && grub2-mkconfig -o /boot/grub2/grub.cfg || update-grub
                   echo "[INFO] GRUB updated."; }
       }
grep -Eq '/dev/sd[a-z][0-9]*|/dev/disk/azure/scsi' /etc/fstab \
    && echo "[ERROR] fstab has /dev/sd* or SCSI paths - replace with UUID." \
    || echo "[INFO] fstab OK."
'@
    if ($FixOperatingSystemSettings) { $linuxScript = $linuxScript.Replace("fix=false","fix=true") }
    try {
        $out    = Invoke-RunCommand -ScriptString $linuxScript -CommandId "RunShellScript" -Description "Linux NVMe check"
        $errors = ParseAndLogOutput -Lines $out
        if ($errors -gt 0) {
            WriteLog "Linux OS check errors. Use -FixOperatingSystemSettings to fix." "WARNING"
            AskToContinue "Continue despite errors?"
        }
    } catch { WriteLog "Error in Linux RunCommand: $_" "ERROR"; exit 1 }

} elseif ($IgnoreOSCheck) {
    WriteLog "OS check skipped (IgnoreOSCheck)." "WARNING"
} else {
    WriteLog "STEP 1: No OS preparation needed ($NewControllerType, $_os)."
}

##############################################################################################################
# STEP 1b  -  PAGEFILE MIGRATION (independent of controller change)
##############################################################################################################

if ($_needPagefileFix -and -not $SkipPagefileFix -and $FixOperatingSystemSettings) {
    WriteLog "--- STEP 1b: Pagefile migration D:\ -> C:\ ---" "IMPORTANT"
    EnsureVMRunning

    $pagefileScript = @'
$existing = Get-WmiObject Win32_PageFileSetting
$cs = Get-WmiObject Win32_ComputerSystem
# Check if pagefile is already correctly set to C:\ only
$hasC  = $existing | Where-Object { $_.Name -like "C:\*" }
$hasD  = $existing | Where-Object { $_.Name -like "D:\*" }
$isAuto = $cs.AutomaticManagedPagefile
if ($hasC -and -not $hasD -and -not $isAuto) {
    Write-Output "INFO: Pagefile already configured on C:\ only - no changes needed."
    exit 0
}
if ($isAuto) {
    $cs.AutomaticManagedPagefile = $false; $cs.Put() | Out-Null
    Write-Output "INFO: Automatic managed pagefile disabled."
}
foreach ($pf in (Get-WmiObject Win32_PageFileSetting)) {
    Write-Output "INFO: Removing pagefile: $($pf.Name)"; $pf.Delete()
}
$newPF = ([WMIClass]"Win32_PageFileSetting").CreateInstance()
$newPF.Name = "C:\pagefile.sys"; $newPF.InitialSize = 0; $newPF.MaximumSize = 0
$newPF.Put() | Out-Null
Write-Output "INFO: Pagefile configured on C:\pagefile.sys (system managed)."
$dDrive = Get-PSDrive -Name D -ErrorAction SilentlyContinue
if ($dDrive) {
    $nonStd = Get-ChildItem -Path "D:\" -ErrorAction SilentlyContinue |
              Where-Object { $_.Name -notin @(
                  "pagefile.sys","swapfile.sys","hiberfil.sys",
                  "Temp","Windows",
                  "CollectGuestLogsTemp",
                  "DATALOSS_WARNING_README.txt"
              ) }
    if ($nonStd) {
        Write-Output "WARNING: The following items on D:\ will be lost after resize:"
        $nonStd | ForEach-Object { Write-Output "WARNING:   $($_.FullName)" }
    } else { Write-Output "INFO: D:\ contains only standard items - safe to proceed." }
} else { Write-Output "INFO: D:\ not present." }
Write-Output "INFO: Pagefile setting updated. Change takes effect on next boot - no reboot needed now."
'@

    try {
        $pfOut    = Invoke-RunCommand -ScriptString $pagefileScript -Description "Pagefile migration"
        $pfErrors = ParseAndLogOutput -Lines $pfOut
        $pfWarn   = $pfOut | Where-Object { $_ -like "WARNING:*" }
        if ($pfWarn)   { AskToContinue "Non-standard data found on D:\  -  it will be lost. Continue?" }
        if ($pfErrors -gt 0) { AskToContinue "Errors during pagefile migration. Continue?" }
        # No reboot needed: the registry change takes effect on next boot.
        # The VM is about to be deallocated anyway; Windows will use the new
        # pagefile setting when the resized/recreated VM starts up.
        WriteLog "Pagefile setting updated - change will activate on next boot (no reboot required now)."
    } catch { WriteLog "Error during pagefile migration: $_" "ERROR"; exit 1 }

} elseif ($_needPagefileFix -and $SkipPagefileFix) {
    WriteLog "Pagefile migration skipped (SkipPagefileFix)  -  assuming already done manually." "WARNING"
}

##############################################################################################################
# STEP 1c  -  INSTALL NVME TEMP DISK STARTUP SCRIPT (only when target is nvme-temp)
#
# On v6/v7 VMs the NVMe temp disk is presented RAW and unpartitioned on every boot.
# Windows will not automatically initialize it or assign a drive letter.
# We install a Scheduled Task that runs at SYSTEM startup to safely find and format it.
#
# IDENTIFICATION STRATEGY:
#   Uses the official Azure method (https://learn.microsoft.com/en-us/azure/virtual-machines/enable-nvme-temp-faqs):
#     Get-PhysicalDisk | where { $_.FriendlyName.contains("NVMe Direct Disk") }
#   The physical disk is correlated to a logical disk number via SerialNumber.
#   A final safety check confirms all disks are still RAW before initializing.
#
# MULTI-DISK SUPPORT:
#   Larger VM sizes (e.g. D16ads_v7 = 2 disks, D32ads_v7 = 4 disks) present multiple
#   NVMe temp disks. When more than one is found, a Windows Storage Pool with a striped
#   Virtual Disk is created so all disks appear as a single D:\ volume.
##############################################################################################################

if ($_os -eq "Windows" -and $_targetDiskArch -eq "nvme-temp" -and $_sourceDiskArch -ne "nvme-temp" -and -not $NVMEDiskInitScriptSkip) {

    WriteLog "--- STEP 1c: Installing NVMe temp disk startup task ---" "IMPORTANT"
    EnsureVMRunning

    # The initializer script content  -  will be written to $NVMEDiskInitScriptLocation\NVMeTempDiskInit.ps1
    $nvmeInitScript = @'
# ============================================================
# Azure NVMe Temp Disk Initializer - NVMeTempDiskInit.ps1
# Installed by AzureVM-NVME-and-localdisk-Conversion.ps1
# Runs at system startup via Scheduled Task.
#
# IDENTIFICATION:
#   Uses the official Azure method: Get-PhysicalDisk | where FriendlyName contains "NVMe Direct Disk"
#   Source: https://learn.microsoft.com/en-us/azure/virtual-machines/enable-nvme-temp-faqs
#
# MULTI-DISK SUPPORT:
#   Larger VM sizes (e.g. D16ads_v7, D32ads_v7) present multiple NVMe temp disks.
#   When more than one disk is found, a striped Storage Pool is created so all disks
#   appear as a single D:\ volume for maximum sequential throughput.
#   Single disk: standard GPT + NTFS partition.
#
# SAFETY:
#   Only disks that are still RAW are touched. Already-initialized disks (normal reboot
#   without host reallocation) are detected and skipped without any changes.
# ============================================================

$logFile    = "C:\Windows\Temp\NVMeTempDiskInit.log"
$maxLogSize = 500KB
$maxLogs    = 4

# Log rotation
if (Test-Path $logFile) {
    if ((Get-Item $logFile).Length -ge $maxLogSize) {
        $oldest = "$logFile.$maxLogs"
        if (Test-Path $oldest) { Remove-Item $oldest -Force }
        for ($i = $maxLogs - 1; $i -ge 1; $i--) {
            $src = "$logFile.$i"
            $dst = "$logFile.$($i + 1)"
            if (Test-Path $src) { Rename-Item $src $dst -Force }
        }
        Rename-Item $logFile "$logFile.1" -Force
    }
}

function Log { param($msg) $ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss"; "$ts  $msg" | Out-File $logFile -Append }

Log "NVMe temp disk initializer started."

# Step 1: find all NVMe temp disks using the official Azure FriendlyName method
$physDisks = @(Get-PhysicalDisk | Where-Object { $_.FriendlyName -like "*NVMe Direct Disk*" })

if ($physDisks.Count -eq 0) {
    Log "No physical disks with FriendlyName 'NVMe Direct Disk' found - VM may have no temp disk."
    exit 0
}
Log "Found $($physDisks.Count) NVMe temp disk(s):"
$physDisks | ForEach-Object { Log "  FriendlyName='$($_.FriendlyName)', Serial='$($_.SerialNumber.Trim())', Size=$([math]::Round($_.Size/1GB,1)) GB" }

# Step 2: correlate each physical disk to a logical disk via SerialNumber
$candidates = @()
foreach ($pd in $physDisks) {
    $d = Get-Disk | Where-Object { $_.SerialNumber.Trim() -eq $pd.SerialNumber.Trim() } | Select-Object -First 1
    if (-not $d) { Log "ERROR: Could not correlate physical disk '$($pd.SerialNumber.Trim())' to a logical disk. Aborting."; exit 1 }
    $candidates += $d
}

# Step 3: safety check - all disks must be RAW
# If none are RAW the pool/disk is already set up (normal reboot, no host reallocation).
$rawDisks = @($candidates | Where-Object { $_.PartitionStyle -eq "RAW" })
if ($rawDisks.Count -eq 0) {
    Log "All NVMe temp disks are already initialized - nothing to do."
    exit 0
}
if ($rawDisks.Count -ne $candidates.Count) {
    Log "WARNING: $($rawDisks.Count) of $($candidates.Count) NVMe temp disks are RAW. Partial initialization detected - aborting to be safe."
    exit 1
}
Log "All $($candidates.Count) disk(s) are RAW - proceeding with initialization."

function Set-DriveLetter {
    param($DiskNumber, $PartitionNumber, $Letter)
    $dUsed = Get-Partition | Where-Object { $_.DriveLetter -eq $Letter }
    if ($dUsed) {
        Log "WARNING: Drive letter ${Letter}: is already in use. Keeping auto-assigned letter."
        return $false
    }
    Set-Partition -DiskNumber $DiskNumber -PartitionNumber $PartitionNumber -NewDriveLetter $Letter
    return $true
}

try {
    if ($candidates.Count -eq 1) {
        # ---- Single disk: GPT + partition + NTFS ----
        $disk = $candidates[0]
        Log "Single disk mode: initializing Disk $($disk.Number) as GPT..."
        Initialize-Disk -Number $disk.Number -PartitionStyle GPT -PassThru | Out-Null
        $partition = New-Partition -DiskNumber $disk.Number -UseMaximumSize -AssignDriveLetter
        if ($partition.DriveLetter -ne "D") {
            if (Set-DriveLetter -DiskNumber $disk.Number -PartitionNumber $partition.PartitionNumber -Letter "D") {
                $partition = Get-Partition -DiskNumber $disk.Number -PartitionNumber $partition.PartitionNumber
                Log "Drive letter reassigned to D:."
            }
        }
        Log "Formatting as NTFS (label: Temporary Storage)..."
        Format-Volume -Partition $partition -FileSystem NTFS -NewFileSystemLabel "Temporary Storage" -Confirm:$false | Out-Null
        Log "SUCCESS: NVMe temp disk initialized as $($partition.DriveLetter):\"

    } else {
        # ---- Multiple disks: striped Storage Pool -> single D:\ volume ----
        $poolName  = "NVMeTempPool"
        $vdiskName = "NVMeTempDisk"
        $totalGB   = [math]::Round(($candidates | Measure-Object -Property Size -Sum).Sum / 1GB, 1)
        Log "Multi-disk mode: creating striped Storage Pool '$poolName' across $($candidates.Count) disks ($totalGB GB total)..."

        # Remove any leftover pool/vdisk with the same name (e.g. from a failed previous run)
        $existingPool = Get-StoragePool -FriendlyName $poolName -ErrorAction SilentlyContinue
        if ($existingPool) {
            Log "Removing existing storage pool '$poolName'..."
            $existingPool | Get-VirtualDisk -ErrorAction SilentlyContinue | Remove-VirtualDisk -Confirm:$false -ErrorAction SilentlyContinue
            $existingPool | Remove-StoragePool -Confirm:$false
        }

        # Create the storage pool from all NVMe temp physical disks
        $subsystem = Get-StorageSubSystem | Where-Object { $_.FriendlyName -like "Windows Storage*" } | Select-Object -First 1
        if (-not $subsystem) { Log "ERROR: Windows Storage subsystem not found - cannot create storage pool."; exit 1 }
        $pool = New-StoragePool `
            -FriendlyName        $poolName `
            -StorageSubSystemUniqueId $subsystem.UniqueId `
            -PhysicalDisks       $physDisks

        # Create a striped virtual disk (Simple = stripe, no redundancy - appropriate for temp storage)
        # NumberOfColumns = number of physical disks for full stripe width
        Log "Creating striped virtual disk (Simple/stripe, $($candidates.Count) columns)..."
        $vdisk = New-VirtualDisk `
            -StoragePoolFriendlyName $poolName `
            -FriendlyName            $vdiskName `
            -ResiliencySettingName   Simple `
            -NumberOfColumns         $candidates.Count `
            -UseMaximumSize

        # Initialize the virtual disk - may need a brief wait to surface as logical disk
        $disk = $null
        for ($i = 0; $i -lt 10 -and -not $disk; $i++) {
            $disk = $vdisk | Get-Disk -ErrorAction SilentlyContinue
            if (-not $disk) { Start-Sleep -Seconds 2 }
        }
        if (-not $disk) { Log "ERROR: Virtual disk did not surface as a logical disk after 20 seconds. Aborting."; exit 1 }
        Log "Initializing virtual disk (Disk $($disk.Number)) as GPT..."
        Initialize-Disk -Number $disk.Number -PartitionStyle GPT -PassThru | Out-Null

        $partition = New-Partition -DiskNumber $disk.Number -UseMaximumSize -AssignDriveLetter
        if ($partition.DriveLetter -ne "D") {
            if (Set-DriveLetter -DiskNumber $disk.Number -PartitionNumber $partition.PartitionNumber -Letter "D") {
                $partition = Get-Partition -DiskNumber $disk.Number -PartitionNumber $partition.PartitionNumber
                Log "Drive letter reassigned to D:."
            }
        }
        Log "Formatting striped volume as NTFS (label: Temporary Storage)..."
        Format-Volume -Partition $partition -FileSystem NTFS -NewFileSystemLabel "Temporary Storage" -Confirm:$false | Out-Null
        Log "SUCCESS: Striped NVMe temp disk pool initialized as $($partition.DriveLetter):\ ($totalGB GB, $($candidates.Count)-disk stripe)"
    }
} catch {
    Log "ERROR during disk initialization: $_"
    exit 1
}
'@

    # Full RunCommand script: writes the initializer to disk and registers a Scheduled Task
    $installCmd = @"
`$initContent = @'
$($nvmeInitScript -replace "'@", "' @")
'@
if (-not (Test-Path "$NVMEDiskInitScriptLocation")) { New-Item -ItemType Directory -Path "$NVMEDiskInitScriptLocation" -Force | Out-Null }
Set-Content -Path "$NVMEDiskInitScriptLocation\NVMeTempDiskInit.ps1" -Value `$initContent -Encoding UTF8 -Force
Write-Output "INFO: Initializer script written to $NVMEDiskInitScriptLocation\NVMeTempDiskInit.ps1"

`$action    = New-ScheduledTaskAction -Execute "powershell.exe" ``
                  -Argument "-NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -File $NVMEDiskInitScriptLocation\NVMeTempDiskInit.ps1"
# Priority 0 = highest Windows task priority (scale is 0-10, default is 7).
# Combined with no startup delay, this makes the task fire as early as possible.
# NOTE: priority alone cannot guarantee ordering between simultaneous AtStartup tasks.
# Dependent tasks (e.g. SQL tempdb init) should use the Wait-ForDrive snippet below.
`$trigger   = New-ScheduledTaskTrigger -AtStartup
`$settings  = New-ScheduledTaskSettingsSet ``
                  -ExecutionTimeLimit (New-TimeSpan -Minutes 5) ``
                  -Priority 0 ``
                  -RestartCount 2 -RestartInterval (New-TimeSpan -Minutes 1)
`$principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -RunLevel Highest

Unregister-ScheduledTask -TaskName "AzureNVMeTempDiskInit" -Confirm:`$false -ErrorAction SilentlyContinue
Register-ScheduledTask -TaskName "AzureNVMeTempDiskInit" ``
    -Action `$action -Trigger `$trigger -Settings `$settings -Principal `$principal ``
    -Description "Initializes Azure NVMe temp disk (D:) on each boot - Priority 0 (highest)" | Out-Null
Write-Output "INFO: Scheduled task 'AzureNVMeTempDiskInit' registered (Priority 0, runs at system startup as SYSTEM)."

# Write a Wait-ForDrive helper snippet so dependent startup tasks can wait for D:\ to be ready.
# Paste this at the TOP of any task that needs D:\ (e.g. SQL tempdb initializer).
# Note: all $ are backtick-escaped because this block is inside a @"..."@ here-string.
`$snippetLines = @(
    '# -----------------------------------------------------------------------',
    '# Wait for D:\ to be initialized by AzureNVMeTempDiskInit before proceeding.',
    '# Paste this at the top of any startup task that depends on D:\.',
    '# -----------------------------------------------------------------------',
    '`$maxWait = 120   # seconds to wait for D:\ before giving up',
    '`$interval = 5',
    '`$elapsed = 0',
    'while (-not (Test-Path "D:\") -and `$elapsed -lt `$maxWait) {',
    '    Start-Sleep -Seconds `$interval',
    '    `$elapsed += `$interval',
    '}',
    'if (-not (Test-Path "D:\")) {',
    '    Write-Error "D:\ not available after `$maxWait seconds. AzureNVMeTempDiskInit may have failed."',
    '    exit 1',
    '}',
    '# -----------------------------------------------------------------------'
)
`$snippetContent = `$snippetLines -join "`r`n"
[System.IO.File]::WriteAllText("$NVMEDiskInitScriptLocation\Wait-ForDrive-D.ps1.snippet.txt", `$snippetContent, [System.Text.Encoding]::UTF8)
Write-Output "INFO: Wait-ForDrive snippet written to $NVMEDiskInitScriptLocation\Wait-ForDrive-D.ps1.snippet.txt"

# The task will run automatically on first boot of the new VM.
# Do NOT run it here  -  this is still the original VM with no NVMe temp disk.
Write-Output "INFO: Task registered. It will run automatically on first boot of the new VM."
"@

    try {
        $out    = Invoke-RunCommand -ScriptString $installCmd -Description "NVMe temp disk startup task install"
        $errors = ParseAndLogOutput -Lines $out
        if ($errors -gt 0) {
            AskToContinue "Errors installing NVMe temp disk startup task. Continue?"
        } else {
            WriteLog "NVMe temp disk startup task installed successfully."
            WriteLog "D:\ will be initialized automatically on every boot of the new VM."
            WriteLog "  Task priority: 0 (highest). For dependent tasks (e.g. SQL tempdb), add" "INFO"
            WriteLog "  the Wait-ForDrive snippet: $NVMEDiskInitScriptLocation\Wait-ForDrive-D.ps1.snippet.txt" "INFO"
        }
    } catch {
        WriteLog "Error installing NVMe temp disk startup task: $_" "ERROR"
        AskToContinue "Could not install startup task. D:\ will not be auto-initialized. Continue?"
    }

} elseif ($_os -eq "Windows" -and $_targetDiskArch -eq "nvme-temp" -and $_sourceDiskArch -eq "nvme-temp") {
    WriteLog "STEP 1c: Skipped - source is already nvme-temp. Assuming startup task was installed during original conversion, or that NVMe temp disk initialization is handled differently."
} elseif ($_os -eq "Windows" -and $_targetDiskArch -eq "nvme-temp" -and $NVMEDiskInitScriptSkip) {
    WriteLog "STEP 1c: Skipped (-NVMEDiskInitScriptSkip). NVMe temp disk startup task will NOT be installed." "WARNING"
} elseif ($_os -eq "Linux" -and $_targetDiskArch -eq "nvme-temp") {
    WriteLog "STEP 1c: Linux NVMe temp disk  -  Azure Linux Agent (waagent) handles temp disk initialization automatically on v6/v7. No action needed." "INFO"
} else {
    WriteLog "STEP 1c: NVMe temp disk setup not needed (target arch: $_targetDiskArch)."
}

##############################################################################################################
# STEP 2  -  STOP VM (DEALLOCATE)
##############################################################################################################

WriteLog "--- STEP 2: Stop VM (deallocate) ---" "IMPORTANT"

try {
    Stop-AzVM -ResourceGroupName $ResourceGroupName -Name $VMName -Force | Out-Null
    if (-not (WaitForVMPowerState -ExpectedState "PowerState/deallocated" -TimeoutSeconds 360)) {
        WriteLog "VM could not be deallocated." "ERROR"; exit 1
    }
    WriteLog "VM deallocated."
} catch { WriteLog "Error stopping VM: $_" "ERROR"; exit 1 }

##############################################################################################################
# PATH A  -  RESIZE
##############################################################################################################

if (-not $_useRecreationPath) {

    # STEP 3A  -  Update OS disk controller types
    if (-not $_controllerAlreadyCorrect) {
        WriteLog "--- STEP 3A: Update OS disk diskControllerTypes ---" "IMPORTANT"
        try {
            $types = if ($NewControllerType -eq "NVMe") { "SCSI, NVMe" } else { "SCSI" }
            Set-OSDiskControllerTypes -DiskName $osDisk.Name -DiskResourceGroup $diskRg -ControllerTypes $types
        } catch { WriteLog "Error patching OS disk: $_" "ERROR"; exit 1 }
    } else {
        WriteLog "STEP 3A: Skipped  -  controller already $NewControllerType."
    }

    # STEP 4A  -  Resize VM
    WriteLog "--- STEP 4A: Resize VM ($script:_originalSize -> $VMSize, controller -> $NewControllerType) ---" "IMPORTANT"
    try {
        $vm = Get-AzVM -ResourceGroupName $ResourceGroupName -Name $VMName
        $vm.HardwareProfile.VmSize            = $VMSize
        $vm.StorageProfile.DiskControllerType = $NewControllerType
        $result = Update-AzVM -ResourceGroupName $ResourceGroupName -VM $vm
        if ($result.StatusCode -eq "OK") {
            WriteLog "VM resized to $VMSize with $NewControllerType controller."
        } else {
            WriteLog "Unexpected status: $($result.StatusCode)" "WARNING"
        }
    } catch {
        WriteLog "Error resizing VM: $_" "ERROR"
        WriteLog "ROLLBACK: -NewControllerType $script:_originalController -VMSize '$script:_originalSize'" "IMPORTANT"
        exit 1
    }

    # STEP 5A  -  Start VM
    if ($StartVM) {
        WriteLog "--- STEP 5A: Start VM ---" "IMPORTANT"
        Start-Sleep -Seconds $SleepSeconds
        try {
            $sr = Start-AzVM -ResourceGroupName $ResourceGroupName -Name $VMName
            if ($sr.Status -eq "Succeeded") { WriteLog "VM started." }
            else { WriteLog "Start status: $($sr.Status)  -  check manually." "WARNING" }
        } catch {
            WriteLog "Error starting VM: $_" "ERROR"
            WriteLog "ROLLBACK: -NewControllerType $script:_originalController -VMSize '$script:_originalSize' -StartVM" "IMPORTANT"
            exit 1
        }
    } else {
        WriteLog "VM is OFF. Add -StartVM to start automatically, or start manually." "IMPORTANT"
    }

##############################################################################################################
# PATH B  -  RECREATE
##############################################################################################################

} else {

    # STEP 3B  -  Update OS disk controller types
    WriteLog "--- STEP 3B: Update OS disk diskControllerTypes ---" "IMPORTANT"
    try {
        $types = if ($NewControllerType -eq "NVMe") { "SCSI, NVMe" } else { "SCSI" }
        Set-OSDiskControllerTypes -DiskName $osDisk.Name -DiskResourceGroup $diskRg -ControllerTypes $types
    } catch { WriteLog "Error patching OS disk: $_" "ERROR"; exit 1 }

    # STEP 4B  -  Snapshot OS disk
    $snapshotName = "$($osDisk.Name)-snap-$((Get-Date).ToString('yyyyMMddHHmmss'))"
    WriteLog "--- STEP 4B: Creating snapshot '$snapshotName' of OS disk ---" "IMPORTANT"
    try {
        $snapConfig = New-AzSnapshotConfig `
            -SourceUri        $osDisk.Id `
            -Location         $vm.Location `
            -CreateOption     Copy `
            -SkuName          Standard_LRS
        $snapshot = New-AzSnapshot `
            -ResourceGroupName $ResourceGroupName `
            -SnapshotName      $snapshotName `
            -Snapshot          $snapConfig
        WriteLog "Snapshot created: $($snapshot.Id)"
    } catch { WriteLog "Error creating snapshot: $_" "ERROR"; exit 1 }

    # STEP 5B  -  Capture VM configuration before deletion
    # The original OS disk is preserved when the VM shell is deleted and will be reattached directly.
    # The snapshot above serves as a safety backup only  -  it is NOT used for recreation.
    WriteLog "--- STEP 5B: Capturing VM configuration ---" "IMPORTANT"
    $vm = Get-AzVM -ResourceGroupName $ResourceGroupName -Name $VMName

    $_nicIds        = $vm.NetworkProfile.NetworkInterfaces | ForEach-Object { $_.Id }
    $_dataDisks     = $vm.StorageProfile.DataDisks
    # Check if target VM size supports accelerated networking
    # If not, NICs with AcceleratedNetworking=true must be updated before VM creation.
    # Accel net: targetSKU is only available when SKU check was not skipped
    if (-not $IgnoreSKUCheck) {
        $_accelNetCapability = ($targetSKU.Capabilities | Where-Object { $_.Name -eq "AcceleratedNetworkingEnabled" }).Value
        $_accelNetSupported  = $_accelNetCapability -eq "True"
    } else {
        $_accelNetSupported  = $false   # unknown without SKU data - assume not supported to be safe
        WriteLog "  Accel network : unknown (-IgnoreSKUCheck) - assuming not supported to be safe." "WARNING"
    }
    $_tags          = $vm.Tags
    $_location      = $vm.Location
    $_licenseType   = $vm.LicenseType
    $_availSetId    = if ($vm.AvailabilitySetReference) { $vm.AvailabilitySetReference.Id } else { $null }
    $_ppgId         = if ($vm.ProximityPlacementGroup)  { $vm.ProximityPlacementGroup.Id  } else { $null }
    $_zones         = $vm.Zones
    $_bootDiag      = $vm.DiagnosticsProfile
    $_identity      = $vm.Identity
    $_priority      = $vm.Priority
    $_ultraSSD      = if ($vm.AdditionalCapabilities) { $vm.AdditionalCapabilities.UltraSSDEnabled } else { $false }
    # Capture source image reference (publisher/offer/sku)  -  used to preserve VM metadata on recreation.
    # Note: not required for attach-existing-disk recreation, but preserves Azure portal display info.
    $_imageRef      = $vm.StorageProfile.ImageReference

    WriteLog "  NICs          : $($_nicIds.Count)"
    WriteLog "  Accel network : $(if ($_accelNetSupported) { 'supported by target size' } else { 'NOT supported by target size - will be disabled on NICs' })"
    WriteLog "  Data disks    : $($_dataDisks.Count)"
    WriteLog "  Tags          : $($_tags.Count)"
    WriteLog "  License type  : $(if ($_licenseType) { $_licenseType } else { 'none' })"
    WriteLog "  Avail Set     : $(if ($_availSetId)  { $_availSetId  } else { 'none' })"
    WriteLog "  PPG           : $(if ($_ppgId)        { $_ppgId       } else { 'none' })"
    WriteLog "  Zones         : $(if ($_zones)        { $_zones -join ',' } else { 'none' })"
    if ($_imageRef -and $_imageRef.Publisher) {
        WriteLog "  Source image  : $($_imageRef.Publisher) / $($_imageRef.Offer) / $($_imageRef.Sku)"
    }

    # STEP 6B  -  Delete original VM (NICs and disks are NOT deleted)
    # Safety: set DeleteOption = Detach on OS disk, data disks and NICs before removing the VM.
    # Since Azure portal 2022, VMs are created with DeleteOption = Delete by default, which means
    # Remove-AzVM would silently delete all attached resources along with the VM shell.
    WriteLog "--- STEP 6B: Setting DeleteOption = Detach on all disks and NICs ---" "IMPORTANT"
    try {
        $vm = Get-AzVM -ResourceGroupName $ResourceGroupName -Name $VMName
        $vm.StorageProfile.OsDisk.DeleteOption        = "Detach"
        foreach ($dd in $vm.StorageProfile.DataDisks) { $dd.DeleteOption = "Detach" }
        foreach ($nic in $vm.NetworkProfile.NetworkInterfaces) { $nic.DeleteOption = "Detach" }
        Update-AzVM -ResourceGroupName $ResourceGroupName -VM $vm | Out-Null
        WriteLog "Update-AzVM completed. Waiting 30 seconds for Azure to propagate the change..."
        Start-Sleep -Seconds 30
        WriteLog "Verifying DeleteOption was applied..."

        # Re-read the VM from the API and verify every resource has DeleteOption = Detach.
        # If any resource still has Delete, abort before touching the VM.
        $vmVerify  = Get-AzVM -ResourceGroupName $ResourceGroupName -Name $VMName
        $badItems  = @()
        if ($vmVerify.StorageProfile.OsDisk.DeleteOption -ne "Detach") {
            $badItems += "OS disk '$($vmVerify.StorageProfile.OsDisk.Name)' (DeleteOption=$($vmVerify.StorageProfile.OsDisk.DeleteOption))"
        }
        foreach ($dd in $vmVerify.StorageProfile.DataDisks) {
            if ($dd.DeleteOption -ne "Detach") {
                $badItems += "Data disk '$($dd.Name)' LUN $($dd.Lun) (DeleteOption=$($dd.DeleteOption))"
            }
        }
        foreach ($nic in $vmVerify.NetworkProfile.NetworkInterfaces) {
            if ($nic.DeleteOption -ne "Detach") {
                $badItems += "NIC '$($nic.Id.Split('/')[-1])' (DeleteOption=$($nic.DeleteOption))"
            }
        }
        if ($badItems.Count -gt 0) {
            WriteLog "ABORTING  -  DeleteOption was NOT set to Detach on the following resources:" "ERROR"
            foreach ($item in $badItems) { WriteLog "  $item" "ERROR" }
            WriteLog "The VM has NOT been deleted. Resolve this manually before re-running." "ERROR"
            exit 1
        }
        WriteLog "Verified: DeleteOption = Detach on OS disk, $($vmVerify.StorageProfile.DataDisks.Count) data disk(s) and $($vmVerify.NetworkProfile.NetworkInterfaces.Count) NIC(s)."
    } catch {
        WriteLog "Error setting/verifying DeleteOption: $_" "ERROR"
        WriteLog "Aborting  -  VM has NOT been deleted. No resources were changed." "ERROR"
        exit 1
    }

    WriteLog "--- STEP 6B: Deleting VM shell (disks and NICs are preserved) ---" "IMPORTANT"
    if ($Force) {
        WriteLog "The original VM '$VMName' will now be DELETED and recreated (-Force specified, skipping confirmation)." "WARNING"
    } else {
        AskToContinue "The original VM '$VMName' will now be DELETED and recreated. Continue?"
    }
    try {
        Remove-AzVM -ResourceGroupName $ResourceGroupName -Name $VMName -Force | Out-Null
        WriteLog "VM shell deleted. OS disk '$($osDisk.Name)', data disks and NICs are intact."
    } catch { WriteLog "Error deleting VM: $_" "ERROR"; exit 1 }

    # STEP 7B  -  Create new VM
    WriteLog "--- STEP 7B: Creating new VM '$VMName' (size: $VMSize, controller: $NewControllerType) ---" "IMPORTANT"
    try {
        # Base VM config.
        # NOTE: -DiskControllerType cannot be combined with -AvailabilitySetId or
        # -ProximityPlacementGroupId on New-AzVMConfig as they are in different parameter sets.
        # Solution: set DiskControllerType on StorageProfile AFTER Set-AzVMOSDisk,
        # which initialises StorageProfile ($null on a fresh config object).
        WriteLog "  Building VM config..."
        $_ppgParam      = if ($_ppgId)     { @{ ProximityPlacementGroupId = $_ppgId     } } else { @{} }
        $_availSetParam = if ($_availSetId) { @{ AvailabilitySetId        = $_availSetId } } else { @{} }
        $newVMConfig = New-AzVMConfig -VMName $VMName -VMSize $VMSize @_ppgParam @_availSetParam
        WriteLog "  VM config created (size: $VMSize$(if ($_ppgId) { ', PPG: ' + $_ppgId.Split('/')[-1] })$(if ($_availSetId) { ', AvailSet: ' + $_availSetId.Split('/')[-1] }))."

        WriteLog "  Attaching OS disk: $($osDisk.Name)..."
        # -Windows and -Linux are mutually exclusive parameter sets on Set-AzVMOSDisk.
        # Passing both (even one as $false) causes 'Parameter set cannot be resolved'.
        if ($osDisk.OsType -eq "Windows") {
            $newVMConfig = Set-AzVMOSDisk -VM $newVMConfig -ManagedDiskId $osDisk.Id -CreateOption Attach -Windows
        } else {
            $newVMConfig = Set-AzVMOSDisk -VM $newVMConfig -ManagedDiskId $osDisk.Id -CreateOption Attach -Linux
        }

        # Set DiskControllerType now that StorageProfile has been initialised by Set-AzVMOSDisk
        $newVMConfig.StorageProfile.DiskControllerType = $NewControllerType
        WriteLog "  DiskControllerType set to $NewControllerType."

        # Data disks
        if ($_dataDisks.Count -gt 0) {
            WriteLog "  Attaching $($_dataDisks.Count) data disk(s)..."
            foreach ($dd in $_dataDisks) {
                $newVMConfig = Add-AzVMDataDisk `
                    -VM            $newVMConfig `
                    -ManagedDiskId $dd.ManagedDisk.Id `
                    -Lun           $dd.Lun `
                    -CreateOption  Attach `
                    -Caching       $dd.Caching `
                    -DiskSizeInGB  $dd.DiskSizeGB
                WriteLog "    LUN $($dd.Lun): $($dd.Name) ($($dd.DiskSizeGB) GB, caching: $($dd.Caching))"
            }
        } else {
            WriteLog "  No data disks to attach."
        }

        # NICs  -  preserve primary flag
        # Accelerated networking:
        #   Target does not support it  -> disable on any NIC that has it enabled.
        #   Target supports it + -EnableAcceleratedNetworking -> enable on all NICs.
        #   Target supports it, no flag -> leave NIC setting unchanged.
        WriteLog "  Attaching $($vm.NetworkProfile.NetworkInterfaces.Count) NIC(s)..."
        foreach ($nic in $vm.NetworkProfile.NetworkInterfaces) {
            $nicName = $nic.Id.Split('/')[-1]
            $nicRg   = $nic.Id.Split('/')[4]
            $nicObj  = Get-AzNetworkInterface -Name $nicName -ResourceGroupName $nicRg
            if (-not $_accelNetSupported) {
                # Target size does not support accel net - disable if currently enabled
                if ($nicObj.EnableAcceleratedNetworking) {
                    WriteLog "    NIC: $nicName - disabling AcceleratedNetworking (not supported by $VMSize)..." "WARNING"
                    $nicObj.EnableAcceleratedNetworking = $false
                    Set-AzNetworkInterface -NetworkInterface $nicObj | Out-Null
                    WriteLog "    NIC: $nicName - AcceleratedNetworking disabled."
                } else {
                    WriteLog "    NIC: $nicName$(if ($nic.Primary) { ' (primary)' }) - AcceleratedNetworking already disabled."
                }
            } elseif ($EnableAcceleratedNetworking) {
                # Target supports it and user requested it - enable if not already on
                if (-not $nicObj.EnableAcceleratedNetworking) {
                    WriteLog "    NIC: $nicName - enabling AcceleratedNetworking (-EnableAcceleratedNetworking)..." "INFO"
                    $nicObj.EnableAcceleratedNetworking = $true
                    Set-AzNetworkInterface -NetworkInterface $nicObj | Out-Null
                    WriteLog "    NIC: $nicName - AcceleratedNetworking enabled."
                } else {
                    WriteLog "    NIC: $nicName$(if ($nic.Primary) { ' (primary)' }) - AcceleratedNetworking already enabled."
                }
            } else {
                WriteLog "    NIC: $nicName$(if ($nic.Primary) { ' (primary)' })"
            }
            $newVMConfig = Add-AzVMNetworkInterface `
                -VM      $newVMConfig `
                -Id      $nic.Id `
                -Primary:($nic.Primary -eq $true)
        }

        # Optional properties
        # Availability set and PPG already set via New-AzVMConfig above.
        if ($_zones -and $_zones.Count -gt 0) {
            $newVMConfig.Zones = $_zones
            WriteLog "  Zone(s): $($_zones -join ', ')"
        }
        if ($_licenseType) {
            $newVMConfig.LicenseType = $_licenseType
            WriteLog "  License type: $_licenseType"
        }
        if ($_bootDiag -and $_bootDiag.BootDiagnostics -and $_bootDiag.BootDiagnostics.Enabled) {
            # -StorageAccountUri was removed in newer Az.Compute versions.
            # If a storage URI is set use it; otherwise enable managed boot diagnostics (no URI needed).
            $_bootUri = $_bootDiag.BootDiagnostics.StorageUri
            if ($_bootUri) {
                $_storageAccountName = $_bootUri -replace 'https?://([^.]+).*','$1'
                $newVMConfig = Set-AzVMBootDiagnostic -VM $newVMConfig -Enable -ResourceGroupName $ResourceGroupName -StorageAccountName $_storageAccountName
                WriteLog "  Boot diagnostics: enabled (storage account: $_storageAccountName)"
            } else {
                $newVMConfig = Set-AzVMBootDiagnostic -VM $newVMConfig -Enable
                WriteLog "  Boot diagnostics: enabled (managed storage)"
            }
        }
        if ($_ultraSSD) {
            $newVMConfig.AdditionalCapabilities = [Microsoft.Azure.Management.Compute.Models.AdditionalCapabilities]@{ UltraSSDEnabled = $true }
            WriteLog "  UltraSSD: enabled"
        }
        if ($_identity) {
            $newVMConfig.Identity = $_identity
            WriteLog "  Managed identity: $($vm.Identity.Type)"
        }
        if ($_priority) {
            $newVMConfig.Priority = $_priority
            WriteLog "  Priority: $_priority"
        }
        if ($_tags -and $_tags.Count -gt 0) {
            $newVMConfig.Tags = $_tags
            WriteLog "  Tags: $($_tags.Count) tag(s) applied"
        }
        # Source image reference is intentionally NOT set on the new VM config.
        # Set-AzVMSourceImage is mutually exclusive with -CreateOption Attach:
        # attaching an existing OS disk means Azure uses that disk as-is, with no
        # image reference needed or allowed. The image info is logged in STEP 5B only.
        if ($_imageRef -and $_imageRef.Publisher) {
            WriteLog "  Source image (informational): $($_imageRef.Publisher) / $($_imageRef.Offer) / $($_imageRef.Sku)"
        }

        WriteLog "  Submitting New-AzVM request to Azure  -  this typically takes 2-3 minutes..."
        $newVM = New-AzVM `
            -ResourceGroupName $ResourceGroupName `
            -Location          $_location `
            -VM                $newVMConfig `
            -Verbose 4>&1 | Tee-Object -Variable _newAzVMOutput | ForEach-Object {
                if ($_ -is [System.Management.Automation.VerboseRecord]) {
                    WriteLog "  [Azure] $($_.Message)"
                }
            }
        $newVM = $_newAzVMOutput | Where-Object { $_ -isnot [System.Management.Automation.VerboseRecord] } | Select-Object -Last 1

        WriteLog "New VM '$VMName' created successfully." "IMPORTANT"
        WriteLog "  Provisioning state: $($newVM.StatusCode)"

        # Azure does not allow setting or changing imageReference on an existing VM -
        # any PATCH to storageProfile.imageReference returns "PropertyChangeNotAllowed".
        # The source image info is preserved on the OS disk resource itself
        # (Get-AzDisk | Select -ExpandProperty CreationData) and was logged in STEP 5B.
        if ($_imageRef -and $_imageRef.Publisher) {
            WriteLog "  Source image info is retained on the OS disk (creationData.imageReference)." "INFO"
            WriteLog "  Azure does not allow restoring imageReference on an existing VM - portal will show blank." "INFO"
        }

    } catch {
        WriteLog "Error creating new VM: $_" "ERROR"
        WriteLog "============================================================" "ERROR"
        WriteLog "IMPORTANT: The VM shell has been deleted, but all resources are intact." "ERROR"
        WriteLog "  Original OS disk : $($osDisk.Name) (RG: $diskRg)" "ERROR"
        WriteLog "  Snapshot (backup): $snapshotName  (RG: $ResourceGroupName)" "ERROR"
        WriteLog "  NICs             : $($_nicIds -join ', ')" "ERROR"
        WriteLog "Re-run this script, or recreate the VM manually:" "ERROR"
        WriteLog "  New-AzVMConfig ... | Set-AzVMOSDisk -ManagedDiskId '$($osDisk.Id)' -CreateOption Attach" "ERROR"
        WriteLog "============================================================" "ERROR"
        exit 1
    }

    # STEP 8B  -  Cleanup snapshot (unless -KeepSnapshot)
    if (-not $KeepSnapshot) {
        WriteLog "--- STEP 8B: Removing snapshot (use -KeepSnapshot to retain) ---" "IMPORTANT"
        try {
            Remove-AzSnapshot -ResourceGroupName $ResourceGroupName -SnapshotName $snapshotName -Force | Out-Null
            WriteLog "Snapshot '$snapshotName' removed."
        } catch {
            WriteLog "Non-fatal: could not remove snapshot '$snapshotName': $_" "WARNING"
            WriteLog "Remove manually when no longer needed." "WARNING"
        }
    } else {
        WriteLog "Snapshot retained: $snapshotName (ResourceGroup: $ResourceGroupName)" "IMPORTANT"
        WriteLog "Use as rollback point  -  delete manually when no longer needed." "WARNING"
    }

    WriteLog "Original OS disk '$($osDisk.Name)' is still attached to the new VM." "INFO"
    if ($KeepSnapshot) {
        WriteLog "Snapshot '$snapshotName' is retained - delete manually once the new VM is verified." "WARNING"
    }
}

##############################################################################################################
# COMPLETION
##############################################################################################################

} finally {
    # Always restore breaking change warnings regardless of how the script exits
    if ($_bcwWasEnabled) { Update-AzConfig -DisplayBreakingChangeWarning $true | Out-Null }
}

WriteLog "=======================================================" "IMPORTANT"
WriteLog " Conversion complete" "IMPORTANT"
WriteLog "=======================================================" "IMPORTANT"
WriteLog "Original size       : $script:_originalSize"
WriteLog "New size            : $VMSize"
WriteLog "Original controller : $script:_originalController"
WriteLog "New controller      : $NewControllerType"
WriteLog "Source disk arch    : $_sourceDiskArch"
WriteLog "Target disk arch    : $_targetDiskArch"
WriteLog "Execution path      : $(if ($_useRecreationPath) { 'PATH B (Recreation)' } else { 'PATH A (Resize)' })"
if ($WriteLogfile) { WriteLog "Log file            : $script:_logfile" }
WriteLog ""
if ($_useRecreationPath) {
    WriteLog "ROLLBACK options:" "IMPORTANT"
    WriteLog "  Option 1  -  Re-run this script to go back to original size/controller:" "IMPORTANT"
    WriteLog "    .\AzureVM-NVME-and-localdisk-Conversion.ps1 -ResourceGroupName '$ResourceGroupName' -VMName '$VMName' ``" "IMPORTANT"
    WriteLog "    -NewControllerType $script:_originalController -VMSize '$script:_originalSize' -IgnoreSKUCheck -StartVM" "IMPORTANT"
    WriteLog "  Option 2  -  Restore from snapshot (if -KeepSnapshot was used):" "IMPORTANT"
    WriteLog "    Create a new managed disk from snapshot '$snapshotName', then recreate the VM." "IMPORTANT"
} else {
    WriteLog "ROLLBACK command:" "IMPORTANT"
    WriteLog "  .\AzureVM-NVME-and-localdisk-Conversion.ps1 ``" "IMPORTANT"
    WriteLog "    -ResourceGroupName '$ResourceGroupName' ``" "IMPORTANT"
    WriteLog "    -VMName '$VMName' ``" "IMPORTANT"
    WriteLog "    -NewControllerType $script:_originalController ``" "IMPORTANT"
    WriteLog "    -VMSize '$script:_originalSize' ``" "IMPORTANT"
    WriteLog "    -IgnoreSKUCheck -StartVM" "IMPORTANT"
}

# Reminder about NVMe temp disk initialization for dependent startup tasks.
# Shown whenever the conversion target is nvme-temp AND the source was not already
# nvme-temp (i.e. the task was freshly installed this run, on either PATH A or PATH B).
# Suppressed when -NVMEDiskInitScriptSkip was specified.
if ($_os -eq "Windows" -and $_targetDiskArch -eq "nvme-temp" -and $_sourceDiskArch -ne "nvme-temp" -and -not $NVMEDiskInitScriptSkip) {
    WriteLog "" 
    WriteLog "=======================================================" "IMPORTANT"
    WriteLog " IMPORTANT: NVMe temp disk (D:\) initialization" "IMPORTANT"
    WriteLog "=======================================================" "IMPORTANT"
    WriteLog "The new VM size uses an NVMe-based temp disk (D:\) that is presented" "IMPORTANT"
    WriteLog "RAW and unformatted on every boot. The scheduled task 'AzureNVMeTempDiskInit'" "IMPORTANT"
    WriteLog "has been installed to initialize and format it automatically at startup." "IMPORTANT"
    WriteLog "" 
    WriteLog "If any OTHER startup tasks depend on D:\ (e.g. SQL Server tempdb):" "IMPORTANT"
    WriteLog "  Add the Wait-ForDrive snippet at the TOP of those tasks so they wait" "IMPORTANT"
    WriteLog "  until D:\ is ready before proceeding. Without this, they may fail" "IMPORTANT"
    WriteLog "  on the first boot after each host reallocation." "IMPORTANT"
    WriteLog "" 
    WriteLog "  Snippet location on the VM:" "IMPORTANT"
    WriteLog "    $NVMEDiskInitScriptLocation\Wait-ForDrive-D.ps1.snippet.txt" "IMPORTANT"
    WriteLog "" 
    WriteLog "  Snippet content (also saved to the file above):" "IMPORTANT"
    @(
        '    $maxWait = 120   # seconds to wait for D:\ before giving up',
        '    $elapsed = 0',
        '    while (-not (Test-Path "D:\") -and $elapsed -lt $maxWait)',
        '        { Start-Sleep -Seconds 5; $elapsed += 5 }',
        '    if (-not (Test-Path "D:\"))',
        '        { Write-Error "D:\ not ready"; exit 1 }'
    ) | ForEach-Object { WriteLog "    $_" "IMPORTANT" }
    WriteLog "=======================================================" "IMPORTANT"
}
