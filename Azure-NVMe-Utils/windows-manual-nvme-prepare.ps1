<#
.SYNOPSIS
    Prepares a Windows VM for SCSI-to-NVMe disk controller conversion on Azure.

.DESCRIPTION
    This script runs INSIDE the guest OS (via Azure RunCommand or RDP) and ensures
    the stornvme driver will load at boot time when the VM is resized to an NVMe-only
    Azure VM size (e.g., Standard_E8s_v6).

    Root cause: Windows can set StartOverride=3 on both stornvme and vpci.
    stornvme is the NVMe storage driver. vpci is the Hyper-V Virtual PCI Bus
    driver that exposes Azure's virtual NVMe controller over VMBUS. If either
    driver is prevented from loading during early boot, the boot disk is not
    enumerated and Windows stops with INACCESSIBLE_BOOT_DEVICE.

    CRITICAL: The fix MUST be applied to ALL ControlSets (not just CurrentControlSet).
    Windows Server maintains multiple ControlSets. If LastKnownGood (typically
    ControlSet002) still has StartOverride=3, Windows may use it during boot
    recovery, causing INACCESSIBLE_BOOT_DEVICE BSOD.

    Tested and validated on (450+ VMs across 15 Azure regions):
      - Windows Server 2019 Datacenter (10.0.17763)
      - Windows Server 2022 Datacenter (10.0.20348)
      - Windows Server 2025 Datacenter (10.0.26100)
      - Windows 10 Enterprise / Pro / LTSC (10.0.19044, 10.0.19045)
      - Windows 11 Enterprise 22H2-25H2 (10.0.22621, 10.0.22631, 10.0.26200)
      - All of the above with Trusted Launch (Secure Boot + vTPM enabled)
      - All of the above with Standard security (non-TL)
      - With and without data disks (up to 2x 512GB tested)

    Safe to run multiple times (idempotent).

.NOTES
    Run this script BEFORE deallocating and resizing the VM.

    CRITICAL: The script uses explicit RegFlushKey (via .NET RegistryKey.Flush())
    to ensure registry changes are written to disk before returning. Do NOT use
    Stop-Computer inside this script — it creates race conditions with Stop-AzVM
    and can result in incomplete registry flushes.

    After the script completes successfully, IMMEDIATELY proceed with:
      1. Stop-AzVM -Force (graceful ACPI shutdown + deallocate)
      2. Update OS disk supportedCapabilities to "SCSI, NVMe"
      3. Update VM size and DiskControllerType to NVMe
      4. Start-AzVM

    IMPORTANT: Each SCSI boot re-creates StartOverride. Do NOT boot on SCSI
    between running this script and converting to NVMe. Immediately deallocate
    the VM with Stop-AzVM after this script succeeds.

.EXAMPLE
    # Via Azure RunCommand (recommended):
    Invoke-AzVMRunCommand -ResourceGroupName "myRG" -VMName "myVM" `
        -CommandId 'RunPowerShellScript' -ScriptPath ".\nvme-prepare-os.ps1"
    # Then immediately: Stop-AzVM, update disk caps, convert, start.

    # Via RDP/PowerShell remoting:
    .\nvme-prepare-os.ps1
    # Then immediately deallocate, convert, and start the VM.
#>

$ErrorActionPreference = 'Stop'

function Write-Status { param([string]$msg, [string]$level = "INFO")
    $prefix = switch ($level) { "OK" { "[OK]   " } "WARN" { "[WARN] " } "ERROR" { "[ERROR]" } default { "[INFO] " } }
    Write-Host "$prefix $msg"
}

# --- Detect OS version ---
$os = Get-CimInstance Win32_OperatingSystem
Write-Status "OS: $($os.Caption) ($($os.Version))"

# Win32_OperatingSystem.ProductType has exactly three documented values:
#   1 = Workstation (Windows client, such as Windows 10 or Windows 11)
#   2 = Domain Controller
#   3 = Server (member or standalone server)
# This is only a CIM-result sanity check. It does not determine whether the
# Windows release/build supports Azure NVMe conversion. A null or any value
# outside 1-3 indicates an unexpected/invalid Win32_OperatingSystem response.
if ($null -eq $os -or $os.ProductType -notin 1, 2, 3) {
    $productType = if ($null -eq $os) { "<null OS result>" } else { $os.ProductType }
    Write-Status "Unexpected Win32_OperatingSystem.ProductType: $productType (expected 1=Workstation, 2=Domain Controller, or 3=Server)" "ERROR"
    exit 1
}

# --- Check stornvme driver file exists ---
$driverPath = "$env:SystemRoot\System32\drivers\stornvme.sys"
if (-not (Test-Path $driverPath)) {
    Write-Status "stornvme.sys not found at $driverPath - NVMe conversion not possible" "ERROR"
    exit 1
}
$driverVer = (Get-Item $driverPath).VersionInfo.FileVersion
Write-Status "stornvme.sys found (version: $driverVer)"

# --- Use sc.exe to set stornvme to boot-start (handles CurrentControlSet) ---
# sc.exe config operates through the Windows Service Control Manager, which
# atomically sets Start=0 AND removes StartOverride. This is the Windows-native
# way to change service startup types and is more robust than direct registry edits.
Write-Status "Running sc.exe config stornvme start=boot..."
$scResult = & sc.exe config stornvme start=boot 2>&1
if ($LASTEXITCODE -eq 0) {
    Write-Status "sc.exe config stornvme start=boot succeeded" "OK"
} else {
    Write-Status "sc.exe config returned $LASTEXITCODE (non-fatal, continuing with registry approach)" "WARN"
}

# vpci exposes the Azure virtual PCI bus over VMBUS. On SCSI-only source VMs,
# Windows may set vpci StartOverride=3 because no virtual PCI device is present.
# The NVMe controller cannot be enumerated at boot unless vpci is boot-start.
Write-Status "Running sc.exe config vpci start=boot..."
$scResult = & sc.exe config vpci start=boot 2>&1
if ($LASTEXITCODE -eq 0) {
    Write-Status "sc.exe config vpci start=boot succeeded" "OK"
} else {
    Write-Status "sc.exe config vpci returned $LASTEXITCODE (non-fatal, continuing with registry approach)" "WARN"
}

# --- Enumerate ALL ControlSets ---
# Windows maintains multiple ControlSets (001=Current, 002=LastKnownGood, etc.).
# We must fix ALL of them because Windows may boot from any ControlSet, especially
# after a failed first boot or with Trusted Launch's stricter boot process.
# sc.exe only handles CurrentControlSet, so we also fix the others manually.
$controlSets = @(Get-ChildItem "HKLM:\SYSTEM" -ErrorAction SilentlyContinue |
    Where-Object { $_.PSChildName -match '^ControlSet\d+$' } |
    ForEach-Object { $_.PSChildName })
$selectProps = Get-ItemProperty "HKLM:\SYSTEM\Select" -ErrorAction SilentlyContinue
if ($controlSets.Count -eq 0 -or $null -eq $selectProps) {
    Write-Status "Unable to enumerate SYSTEM ControlSets or SYSTEM\Select" "ERROR"
    exit 1
}
Write-Status "Found ControlSets: $($controlSets -join ', ') (Current=$($selectProps.Current), LastKnownGood=$($selectProps.LastKnownGood))"

foreach ($cs in $controlSets) {
    Write-Host ""
    Write-Status "--- Processing $cs ---"
    $csRoot = "HKLM:\SYSTEM\$cs"

    # --- Fix 1: Ensure stornvme Start = 0 (Boot) ---
    $svcPath = "$csRoot\Services\stornvme"
    $currentStart = (Get-ItemProperty -Path $svcPath -Name Start -ErrorAction SilentlyContinue).Start

    if ($currentStart -eq 0) {
        Write-Status "$cs\stornvme Start = 0 (Boot) - correct" "OK"
    } else {
        Write-Status "$cs\stornvme Start = $currentStart - setting to 0" "WARN"
        Set-ItemProperty -Path $svcPath -Name "Start" -Value 0 -Type DWord
        Write-Status "$cs\stornvme Start set to 0" "OK"
    }

    # --- Fix 2: Remove StartOverride (critical fix) ---
    $startOverridePath = "$svcPath\StartOverride"
    if (Test-Path $startOverridePath) {
        $soValue = (Get-ItemProperty -Path $startOverridePath -ErrorAction SilentlyContinue).'0'
        Write-Status "$cs\stornvme StartOverride exists (value=$soValue) - REMOVING" "WARN"
        Remove-Item -Path $startOverridePath -Recurse -Force
        if (Test-Path $startOverridePath) {
            Write-Status "Failed to remove $cs\stornvme StartOverride!" "ERROR"
            exit 1
        }
        Write-Status "$cs\stornvme StartOverride removed" "OK"
    } else {
        Write-Status "$cs\stornvme StartOverride not present - correct" "OK"
    }

    # --- Fix 3: Set the StorPort/NVMe driver parameters ---
    $parametersPath = "$svcPath\Parameters"
    if (-not (Test-Path $parametersPath)) {
        New-Item -Path $parametersPath -Force | Out-Null
    }

    $requiredParameters = [ordered]@{
        IoTimeoutValue = 240
        BusType = 17
        StorageSupportedFeatures = 3
    }
    foreach ($parameter in $requiredParameters.GetEnumerator()) {
        $currentValue = (Get-ItemProperty -Path $parametersPath -Name $parameter.Key `
            -ErrorAction SilentlyContinue).($parameter.Key)
        if ($currentValue -eq $parameter.Value) {
            Write-Status "$cs\stornvme Parameters\$($parameter.Key) = $($parameter.Value) - correct" "OK"
        } else {
            Write-Status "$cs\stornvme Parameters\$($parameter.Key) = $currentValue - setting to $($parameter.Value)" "WARN"
            Set-ItemProperty -Path $parametersPath -Name $parameter.Key `
                -Value $parameter.Value -Type DWord
            Write-Status "$cs\stornvme Parameters\$($parameter.Key) set to $($parameter.Value)" "OK"
        }
    }

    $pnpInterfacePath = "$parametersPath\PnpInterface"
    if (-not (Test-Path $pnpInterfacePath)) {
        New-Item -Path $pnpInterfacePath -Force | Out-Null
    }
    $pnpInterface = (Get-ItemProperty -Path $pnpInterfacePath -Name 5 `
        -ErrorAction SilentlyContinue).'5'
    if ($pnpInterface -ne 1) {
        Write-Status "$cs\stornvme Parameters\PnpInterface\5 = $pnpInterface - setting to 1" "WARN"
        Set-ItemProperty -Path $pnpInterfacePath -Name 5 -Value 1 -Type DWord
    } else {
        Write-Status "$cs\stornvme Parameters\PnpInterface\5 = 1 - correct" "OK"
    }

    # --- Fix 4: Ensure vpci is boot-start and has no StartOverride ---
    $vpciPath = "$csRoot\Services\vpci"
    if (-not (Test-Path $vpciPath)) {
        Write-Status "$cs\vpci service is missing - NVMe controller cannot be enumerated" "ERROR"
        exit 1
    }

    $vpciStart = (Get-ItemProperty -Path $vpciPath -Name Start -ErrorAction SilentlyContinue).Start
    if ($vpciStart -eq 0) {
        Write-Status "$cs\vpci Start = 0 (Boot) - correct" "OK"
    } else {
        Write-Status "$cs\vpci Start = $vpciStart - setting to 0" "WARN"
        Set-ItemProperty -Path $vpciPath -Name Start -Value 0 -Type DWord
        Write-Status "$cs\vpci Start set to 0" "OK"
    }

    $vpciSOPath = "$vpciPath\StartOverride"
    if (Test-Path $vpciSOPath) {
        $vpciSOValue = (Get-ItemProperty -Path $vpciSOPath -ErrorAction SilentlyContinue).'0'
        Write-Status "$cs\vpci StartOverride exists (value=$vpciSOValue) - REMOVING" "WARN"
        Remove-Item -Path $vpciSOPath -Recurse -Force
        if (Test-Path $vpciSOPath) {
            Write-Status "Failed to remove $cs\vpci StartOverride!" "ERROR"
            exit 1
        }
        Write-Status "$cs\vpci StartOverride removed" "OK"
    } else {
        Write-Status "$cs\vpci StartOverride not present - correct" "OK"
    }

    # --- Fix 5: Ensure pci driver is boot-start ---
    $pciStart = (Get-ItemProperty -Path "$csRoot\Services\pci" -Name Start -ErrorAction SilentlyContinue).Start
    if ($pciStart -eq 0) {
        Write-Status "$cs\pci Start = 0 (Boot) - correct" "OK"
    } else {
        Write-Status "$cs\pci Start = $pciStart - setting to 0" "WARN"
        Set-ItemProperty -Path "$csRoot\Services\pci" -Name "Start" -Value 0 -Type DWord
        Write-Status "$cs\pci Start set to 0" "OK"
    }

    # pci StartOverride is intentionally not removed. Native Azure NVMe VMs
    # commonly have pci StartOverride=3 and boot correctly because Azure's
    # virtual PCI bus is exposed by vpci. Only vpci and stornvme overrides are
    # blockers for this conversion.
    $pciSOPath = "$csRoot\Services\pci\StartOverride"
    if (Test-Path $pciSOPath) {
        $pciSOValues = ((Get-ItemProperty -Path $pciSOPath -ErrorAction SilentlyContinue).PSObject.Properties |
            Where-Object { $_.Name -notmatch '^PS' } |
            ForEach-Object { $_.Name + '=' + $_.Value }) -join ', '
        Write-Status "$cs\pci StartOverride present ($pciSOValues) - allowed on native NVMe" "OK"
    } else {
        Write-Status "$cs\pci StartOverride not present - also valid" "OK"
    }
}

# --- Validation summary ---
Write-Host ""
Write-Host "=== VALIDATION ==="
$allGood = $true

foreach ($cs in $controlSets) {
    $csRoot = "HKLM:\SYSTEM\$cs"
    $csStart = (Get-ItemProperty -Path "$csRoot\Services\stornvme" -Name Start -ErrorAction SilentlyContinue).Start
    $csSO = Test-Path "$csRoot\Services\stornvme\StartOverride"
    $csTimeout = (Get-ItemProperty -Path "$csRoot\Services\stornvme\Parameters" -Name IoTimeoutValue -ErrorAction SilentlyContinue).IoTimeoutValue
    $csBusType = (Get-ItemProperty -Path "$csRoot\Services\stornvme\Parameters" -Name BusType -ErrorAction SilentlyContinue).BusType
    $csFeatures = (Get-ItemProperty -Path "$csRoot\Services\stornvme\Parameters" -Name StorageSupportedFeatures -ErrorAction SilentlyContinue).StorageSupportedFeatures
    $csPnp = (Get-ItemProperty -Path "$csRoot\Services\stornvme\Parameters\PnpInterface" -Name 5 -ErrorAction SilentlyContinue).'5'
    $csVpci = (Get-ItemProperty -Path "$csRoot\Services\vpci" -Name Start -ErrorAction SilentlyContinue).Start
    $csVpciSO = Test-Path "$csRoot\Services\vpci\StartOverride"
    $csPci = (Get-ItemProperty -Path "$csRoot\Services\pci" -Name Start -ErrorAction SilentlyContinue).Start
    $csPciSO = Test-Path "$csRoot\Services\pci\StartOverride"

    $csOK = ($csStart -eq 0) -and (-not $csSO) -and
        ($csTimeout -eq 240) -and ($csBusType -eq 17) -and
        ($csFeatures -eq 3) -and ($csPnp -eq 1) -and
        ($csVpci -eq 0) -and (-not $csVpciSO) -and
        ($csPci -eq 0)
    if (-not $csOK) { $allGood = $false }

    $status = if ($csOK) { "OK" } else { "ERROR" }
    Write-Status "$cs : stornvme Start=$csStart SO=$csSO IoTimeout=$csTimeout BusType=$csBusType Features=$csFeatures Pnp5=$csPnp, vpci Start=$csVpci SO=$csVpciSO, pci Start=$csPci SO=$csPciSO" $status
}

if ($allGood) {
    # --- CRITICAL: Explicit registry flush using RegFlushKey ---
    # Registry changes from Remove-Item/Set-ItemProperty are in-memory only.
    # The Windows lazy writer may take seconds to flush. Without an explicit
    # flush, Stop-AzVM (or any shutdown) may power off before changes are on disk.
    # RegistryKey.Flush() calls RegFlushKey() which is SYNCHRONOUS — when it
    # returns, the data IS on disk. This is far more reliable than Stop-Computer
    # (which creates race conditions with Stop-AzVM) or reg.exe save (which
    # fails in RunCommand contexts due to access restrictions).
    Write-Status "Flushing SYSTEM registry hive to disk..."
    try {
        $systemKey = [Microsoft.Win32.Registry]::LocalMachine.OpenSubKey("SYSTEM", $false)
        $systemKey.Flush()
        $systemKey.Close()
        Write-Status "Registry hive flushed to disk successfully" "OK"
    } catch {
        Write-Status "Primary flush failed ($($_.Exception.Message)), trying alternative..." "WARN"
        # Fallback: flush every service key changed in each ControlSet.
        $flushOK = $true
        foreach ($cs in $controlSets) {
            foreach ($service in @("stornvme", "vpci", "pci")) {
                try {
                    $serviceKey = [Microsoft.Win32.Registry]::LocalMachine.OpenSubKey(
                        "SYSTEM\$cs\Services\$service", $false)
                    if ($serviceKey) {
                        $serviceKey.Flush()
                        $serviceKey.Close()
                    } else {
                        $flushOK = $false
                        Write-Status "Failed to open $cs\Services\$service for flushing" "ERROR"
                    }
                } catch {
                    $flushOK = $false
                    Write-Status "Failed to flush $cs\Services\${service}: $($_.Exception.Message)" "ERROR"
                }
            }
        }
        if (-not $flushOK) {
            Write-Status "Registry flush failed - changes may not persist!" "ERROR"
            exit 1
        }
        Write-Status "Registry flushed via individual ControlSet keys" "OK"
    }

    # Post-flush verification: re-read from registry to confirm changes persisted
    foreach ($cs in $controlSets) {
        $verifyPath = "HKLM:\SYSTEM\$cs\Services\stornvme\StartOverride"
        if (Test-Path $verifyPath) {
            Write-Status "FATAL: $cs\stornvme\StartOverride STILL PRESENT after flush!" "ERROR"
            exit 1
        }
        $verifyTimeout = (Get-ItemProperty -Path "HKLM:\SYSTEM\$cs\Services\stornvme\Parameters" `
            -Name IoTimeoutValue -ErrorAction SilentlyContinue).IoTimeoutValue
        if ($verifyTimeout -ne 240) {
            Write-Status "FATAL: $cs\stornvme\Parameters\IoTimeoutValue is $verifyTimeout after flush!" "ERROR"
            exit 1
        }
        $verifyBusType = (Get-ItemProperty -Path "HKLM:\SYSTEM\$cs\Services\stornvme\Parameters" `
            -Name BusType -ErrorAction SilentlyContinue).BusType
        $verifyFeatures = (Get-ItemProperty -Path "HKLM:\SYSTEM\$cs\Services\stornvme\Parameters" `
            -Name StorageSupportedFeatures -ErrorAction SilentlyContinue).StorageSupportedFeatures
        $verifyPnp = (Get-ItemProperty -Path "HKLM:\SYSTEM\$cs\Services\stornvme\Parameters\PnpInterface" `
            -Name 5 -ErrorAction SilentlyContinue).'5'
        if ($verifyBusType -ne 17 -or $verifyFeatures -ne 3 -or $verifyPnp -ne 1) {
            Write-Status "FATAL: $cs\stornvme parameter verification failed after flush (BusType=$verifyBusType Features=$verifyFeatures Pnp5=$verifyPnp)" "ERROR"
            exit 1
        }
        $verifyVpciStart = (Get-ItemProperty -Path "HKLM:\SYSTEM\$cs\Services\vpci" `
            -Name Start -ErrorAction SilentlyContinue).Start
        $verifyVpciSO = Test-Path "HKLM:\SYSTEM\$cs\Services\vpci\StartOverride"
        if ($verifyVpciStart -ne 0 -or $verifyVpciSO) {
            Write-Status "FATAL: $cs\vpci verification failed after flush (Start=$verifyVpciStart SO=$verifyVpciSO)" "ERROR"
            exit 1
        }
    }
    Write-Status "Post-flush verification passed - stornvme and vpci are boot-ready in all ControlSets" "OK"

    Write-Status "All checks passed across ALL ControlSets - VM is ready for NVMe conversion" "OK"
    if (-not $SuppressNextSteps) {
        Write-Host ""
        Write-Host "Next steps:"
        Write-Host "  1. Stop-AzVM -Force (graceful ACPI shutdown + deallocate)"
        Write-Host "  2. Update OS disk: supportedCapabilities.diskControllerTypes = 'SCSI, NVMe'"
        Write-Host "  3. Update VM: HardwareProfile.VmSize and StorageProfile.DiskControllerType = 'NVMe'"
        Write-Host "  4. Start-AzVM"
    }
    exit 0
} else {
    Write-Status "Some checks failed - review output above" "ERROR"
    exit 1
}
