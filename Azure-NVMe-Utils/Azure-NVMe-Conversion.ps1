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
        exit 1
    }

    if ($ModuleVersion -and ($_module | Where-Object {$_.Version -ge $ModuleVersion}).Count -eq 0) {
        WriteRunLog -message "Module $ModuleName is installed but the version is lower than required. Please update the module and run the script again." -category "ERROR"
        WriteRunLog -message "Usage this command to update the module:" -category "ERROR"
        WriteRunLog -message "   Update-Module -Name $ModuleName" -category "ERROR"
        exit 1
    }
    else {
        WriteRunLog -message "Module $ModuleName is installed and the version is correct."
    }
}

function Test-ActionPattern {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)][string]$Action,
        [Parameter(Mandatory=$true)][string]$Pattern
    )

    $regex = "^" + [regex]::Escape($Pattern).Replace("\*", ".*") + "$"
    return $Action -match $regex
}

function Get-EffectivePermissions {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)][string]$Scope
    )

    try {
        $permissionPath = "$Scope/providers/Microsoft.Authorization/permissions?api-version=2022-04-01"
        $response = Invoke-AzureOperation -Operation "Query effective permissions" -ScriptBlock {
            Invoke-AzRestMethod -Path $permissionPath -Method GET -ErrorAction Stop
        }
        if ($response.StatusCode -lt 200 -or $response.StatusCode -ge 300) {
            throw "Permissions API returned HTTP $($response.StatusCode)"
        }
        $content = $response.Content | ConvertFrom-Json
        return @($content.value)
    }
    catch {
        WriteRunLog -message "Unable to query effective Azure permissions at scope $Scope" -category "ERROR"
        WriteRunLog -message $_.Exception.Message -category "ERROR"
        WriteRunLog -message "The identity must be able to read Microsoft.Authorization/permissions at this scope." -category "IMPORTANT"
        exit 1
    }
}

function Test-EffectivePermission {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)][object[]]$PermissionSets,
        [Parameter(Mandatory=$true)][string]$Action
    )

    foreach ($permissionSet in $PermissionSets) {
        $allowed = @($permissionSet.actions | Where-Object {
            Test-ActionPattern -Action $Action -Pattern $_
        }).Count -gt 0
        $excluded = @($permissionSet.notActions | Where-Object {
            Test-ActionPattern -Action $Action -Pattern $_
        }).Count -gt 0

        if ($allowed -and -not $excluded) {
            return $true
        }
    }
    return $false
}

function Assert-EffectivePermissions {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)][string]$ScopeName,
        [Parameter(Mandatory=$true)][string]$Scope,
        [Parameter(Mandatory=$true)][string[]]$RequiredActions
    )

    WriteRunLog -message "Checking effective Azure permissions on $ScopeName"
    $permissionSets = Get-EffectivePermissions -Scope $Scope
    $missingActions = @()

    foreach ($action in $RequiredActions) {
        if (Test-EffectivePermission -PermissionSets $permissionSets -Action $action) {
            WriteRunLog -message "  [PASS] $action"
        }
        else {
            WriteRunLog -message "  [FAIL] $action" -category "ERROR"
            $missingActions += $action
        }
    }

    if ($missingActions.Count -gt 0) {
        WriteRunLog -message "The current identity lacks required permissions on $ScopeName." -category "ERROR"
        WriteRunLog -message "Scope: $Scope" -category "ERROR"
        WriteRunLog -message ("Missing actions: " + ($missingActions -join ", ")) -category "ERROR"
        exit 1
    }
}

function Invoke-AzureOperation {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)][string]$Operation,
        [Parameter(Mandatory=$true)][scriptblock]$ScriptBlock,
        [int]$MaxAttempts = 3,
        [int]$RetryDelaySeconds = 5
    )

    for ($attempt = 1; $attempt -le $MaxAttempts; $attempt++) {
        try {
            return & $ScriptBlock
        }
        catch {
            if ($attempt -ge $MaxAttempts) {
                WriteRunLog -message "$Operation failed after $MaxAttempts attempts" -category "ERROR"
                throw
            }
            WriteRunLog -message "$Operation failed on attempt $attempt/${MaxAttempts}: $($_.Exception.Message)" -category "WARNING"
            WriteRunLog -message "Retrying in $RetryDelaySeconds seconds..."
            Start-Sleep -Seconds $RetryDelaySeconds
        }
    }
}

function Get-PlacementPeerStates {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [ValidateSet("AvailabilitySet", "ProximityPlacementGroup")]
        [string]$PlacementType,
        [Parameter(Mandatory=$true)][string]$PlacementId,
        [Parameter(Mandatory=$true)][string]$CurrentVMId
    )

    try {
        $segments = $PlacementId.Trim("/").Split("/")
        $resourceGroupIndex = [Array]::IndexOf($segments, "resourceGroups")
        if ($resourceGroupIndex -lt 0 -or $resourceGroupIndex + 1 -ge $segments.Count) {
            throw "Unable to parse resource group from placement resource ID: $PlacementId"
        }
        $placementResourceGroup = $segments[$resourceGroupIndex + 1]
        $placementName = $segments[-1]

        if ($PlacementType -eq "AvailabilitySet") {
            $placement = Get-AzAvailabilitySet -ResourceGroupName $placementResourceGroup `
                -Name $placementName -ErrorAction Stop
            $references = @($placement.VirtualMachinesReferences)
        }
        else {
            $placement = Get-AzProximityPlacementGroup -ResourceGroupName $placementResourceGroup `
                -Name $placementName -ErrorAction Stop
            $references = @($placement.VirtualMachines)
        }

        $peerStates = @()
        foreach ($reference in $references) {
            if ([string]::IsNullOrWhiteSpace($reference.Id) -or
                $reference.Id -eq $CurrentVMId) {
                continue
            }

            $vmSegments = $reference.Id.Trim("/").Split("/")
            $vmResourceGroupIndex = [Array]::IndexOf($vmSegments, "resourceGroups")
            if ($vmResourceGroupIndex -lt 0 -or
                $vmResourceGroupIndex + 1 -ge $vmSegments.Count) {
                WriteRunLog -message "Unable to parse peer VM resource ID: $($reference.Id)" -category "WARNING"
                continue
            }

            $peerResourceGroup = $vmSegments[$vmResourceGroupIndex + 1]
            $peerName = $vmSegments[-1]
            try {
                $peerStatus = Invoke-AzureOperation `
                    -Operation "Query peer VM '$peerName' status" `
                    -ScriptBlock {
                        Get-AzVM -ResourceGroupName $peerResourceGroup `
                            -Name $peerName -Status -ErrorAction Stop
                    }
                $powerState = ($peerStatus.Statuses |
                    Where-Object { $_.Code -like "PowerState*" }).Code
                $peerStates += [pscustomobject]@{
                    Name = $peerName
                    ResourceGroupName = $peerResourceGroup
                    PowerState = $powerState
                }
            }
            catch {
                WriteRunLog -message "Unable to query power state for peer VM '$peerName' in resource group '$peerResourceGroup': $($_.Exception.Message)" -category "WARNING"
                $peerStates += [pscustomobject]@{
                    Name = $peerName
                    ResourceGroupName = $peerResourceGroup
                    PowerState = "Unknown"
                }
            }
        }

        return $peerStates
    }
    catch {
        WriteRunLog -message "Unable to enumerate $PlacementType members for $PlacementId" -category "WARNING"
        WriteRunLog -message $_.Exception.Message -category "WARNING"
        return @()
    }
}

function Write-StartAllocationGuidance {
    [CmdletBinding()]
    param (
        [string]$FailureMessage,
        [bool]$VMUpdateCompleted = $true
    )

    $isOverconstrained = $FailureMessage -match
        "OverconstrainedAllocationRequest|condition is too restrictive"
    $isCapacityFailure = $FailureMessage -match
        "AllocationFailed|ZonalAllocationFailed|SkuNotAvailable|capacity"
    $isQuotaFailure = $FailureMessage -match
        "quota|cores|OperationNotAllowed"

    WriteRunLog -message "START FAILURE GUIDANCE" -category "IMPORTANT"
    if ($VMUpdateCompleted) {
        WriteRunLog -message "The VM size/controller update has already completed; the VM is currently deallocated. This is an Azure allocation/start failure, not an OS preparation or NVMe boot failure." -category "IMPORTANT"
    }
    else {
        WriteRunLog -message "The VM size/controller update did not complete; the VM remains deallocated on its original size/controller. This is an Azure placement/allocation failure, not an OS preparation failure." -category "IMPORTANT"
    }

    if ($_availabilitySetId) {
        WriteRunLog -message "Availability Set '$_availabilitySetName' constrains all members to compatible cluster capacity." -category "WARNING"
        if ($_runningAvailabilitySetPeers.Count -gt 0) {
            $_peerList = ($_runningAvailabilitySetPeers | ForEach-Object {
                "$($_.Name) (resource group: $($_.ResourceGroupName))"
            }) -join ", "
            WriteRunLog -message "Stop/deallocate these running Availability Set peers first: $_peerList" -category "IMPORTANT"
        }
        else {
            WriteRunLog -message "Confirm every VM in the Availability Set is deallocated before retrying." -category "IMPORTANT"
        }
        WriteRunLog -message "After all Availability Set members are deallocated, retry the VM start so Azure can place the set on a cluster supporting '$VMSize'." -category "IMPORTANT"
    }

    if ($_ppgId) {
        WriteRunLog -message "PPG '$_ppgName' restricts placement to its current low-latency capacity scope." -category "WARNING"
        if ($_runningPpgPeers.Count -gt 0) {
            $_peerList = ($_runningPpgPeers | ForEach-Object {
                "$($_.Name) (resource group: $($_.ResourceGroupName))"
            }) -join ", "
            WriteRunLog -message "Stop/deallocate these running PPG peers first: $_peerList" -category "IMPORTANT"
        }
        else {
            WriteRunLog -message "Confirm all VMs associated with the PPG are deallocated before retrying." -category "IMPORTANT"
        }
        WriteRunLog -message "If allocation still fails, choose a target SKU available inside the PPG or temporarily remove/relax the PPG constraint, then retry." -category "IMPORTANT"
    }

    if ($isQuotaFailure) {
        WriteRunLog -message "The error indicates quota pressure. Deallocate unused VMs or request a regional/family vCPU quota increase before retrying." -category "IMPORTANT"
    }
    elseif ($isOverconstrained -or $isCapacityFailure) {
        WriteRunLog -message "The error indicates placement/capacity constraints. Retry after addressing AvSet/PPG peers; otherwise try another compatible SKU, zone, or region, or retry when capacity is available." -category "IMPORTANT"
    }
    else {
        WriteRunLog -message "Review the Azure allocation error below, resolve the reported capacity/placement constraint, and retry the start." -category "IMPORTANT"
    }

    if ($VMUpdateCompleted) {
        WriteRunLog -message "Retry start command:" -category "IMPORTANT"
        WriteRunLog -message "   Start-AzVM -ResourceGroupName `"$ResourceGroupName`" -Name `"$VMName`"" -category "IMPORTANT"
        WriteRunLog -message "Do not rerun the SCSI-to-NVMe preparation while the VM is already configured for '$NewControllerType' on '$VMSize'." -category "IMPORTANT"
    }
    else {
        WriteRunLog -message "After resolving the placement constraint, restart the VM on its original configuration:" -category "IMPORTANT"
        WriteRunLog -message "   Start-AzVM -ResourceGroupName `"$ResourceGroupName`" -Name `"$VMName`"" -category "IMPORTANT"
        $_rerunCommand = ".\Azure-NVMe-Conversion.ps1 -ResourceGroupName `"$ResourceGroupName`" -VMName `"$VMName`" -NewControllerType $NewControllerType -VMSize `"$VMSize`""
        if ($StartVM) { $_rerunCommand += " -StartVM" }
        if ($FixOperatingSystemSettings) { $_rerunCommand += " -FixOperatingSystemSettings" }
        if ($IgnoreOSCheck) { $_rerunCommand += " -IgnoreOSCheck" }
        if ($WriteLogfile) { $_rerunCommand += " -WriteLogfile" }
        WriteRunLog -message "Then rerun the conversion (the SCSI boot can recreate StartOverride):" -category "IMPORTANT"
        WriteRunLog -message "   $_rerunCommand" -category "IMPORTANT"
    }

    if ($NewControllerType -eq "NVMe" -and $VMUpdateCompleted) {
        WriteRunLog -message "Only use rollback if you decide not to resolve the allocation issue:" -category "IMPORTANT"
        WriteRunLog -message "   .\Azure-NVMe-Conversion.ps1 -ResourceGroupName `"$ResourceGroupName`" -VMName `"$VMName`" -NewControllerType SCSI -VMSize `"$script:_original_vm_size`" -StartVM" -category "IMPORTANT"
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

}


##############################################################################################################
# Main Script
##############################################################################################################

$_version = "2026082514" # version of the script

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

# Output of all script parameters for better troubleshooting and supportability of the script
WriteRunLog -message "Script parameters:"
foreach ($key in $MyInvocation.BoundParameters.keys)
{
    $value = (get-variable $key).Value 
    WriteRunLog -message "  $key -> $value"
}

# Check for newer version of the script using the version number in the file and the version number in the online file on GitHub
CheckForNewerVersion

# Suppress Az PowerShell breaking-change warnings for this process only.
# Process scope avoids changing the user's persistent CurrentUser setting and
# is safe even when the script exits early.
Update-AzConfig -DisplayBreakingChangeWarning $false -Scope Process | Out-Null

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
        exit 1
    }
    WriteRunLog -message "Connected to Azure subscription name: $($_AzureContext.Subscription.Name)"
    WriteRunLog -message "Connected to Azure subscription ID: $($_AzureContext.Subscription.Id)"

} catch {
    WriteRunLog -message "Error getting Azure Context" -category "ERROR"
    WriteRunLog $_.Exception.Message "ERROR"
    exit 1
}

# Get VM
try {
    $_VM = Invoke-AzureOperation -Operation "Get VM '$VMName'" -ScriptBlock {
        Get-AzVM -ResourceGroupName $ResourceGroupName -Name $VMName -ErrorAction Stop
    }
    if (-not $_VM) {
        WriteRunLog -message "VM $VMName not found in Resource Group $ResourceGroupName" -category "ERROR"
        exit 1
    }
    WriteRunLog -message "VM $VMName found in Resource Group $ResourceGroupName"
} catch {
    WriteRunLog -message "Error getting VM $VMName" -category "ERROR"
    WriteRunLog $_.Exception.Message "ERROR"
    exit 1
}

# storing original VM Size
$script:_original_vm_size = $_VM.HardwareProfile.VmSize

# Detailed VM/placement summary
$_currentControllerSummary = $_VM.StorageProfile.DiskControllerType
if ([string]::IsNullOrWhiteSpace($_currentControllerSummary)) {
    $_currentControllerSummary = "SCSI (implicit/default)"
}
$_securityType = $_VM.SecurityProfile.SecurityType
if ([string]::IsNullOrWhiteSpace($_securityType)) {
    $_securityType = "Standard"
}
$_zone = if ($_VM.Zones -and $_VM.Zones.Count -gt 0) {
    $_VM.Zones -join ","
} else {
    "None"
}
$_availabilitySetId = $_VM.AvailabilitySetReference.Id
$_availabilitySetName = if ($_availabilitySetId) {
    $_availabilitySetId.Split("/")[-1]
} else {
    "None"
}
$_ppgId = $_VM.ProximityPlacementGroup.Id
$_ppgName = if ($_ppgId) {
    $_ppgId.Split("/")[-1]
} else {
    "None"
}
$_imageReference = $_VM.StorageProfile.ImageReference
$_image = if ($_imageReference) {
    "$($_imageReference.Publisher):$($_imageReference.Offer):$($_imageReference.Sku):$($_imageReference.Version)"
} else {
    "Specialized/custom OS disk"
}

WriteRunLog -message "VM details:"
WriteRunLog -message "  Location / Zone: $($_VM.Location) / $_zone"
WriteRunLog -message "  Current VM size: $($_VM.HardwareProfile.VmSize)"
WriteRunLog -message "  Current disk controller: $_currentControllerSummary"
WriteRunLog -message "  Security type: $_securityType"
WriteRunLog -message "  OS type: $($_VM.StorageProfile.OsDisk.OsType)"
WriteRunLog -message "  Image: $_image"
WriteRunLog -message "  Managed data disks: $($_VM.StorageProfile.DataDisks.Count)"
WriteRunLog -message "  Availability Set: $_availabilitySetName"
WriteRunLog -message "  Proximity Placement Group: $_ppgName"

if ($_availabilitySetId) {
    WriteRunLog -message "AVAILABILITY SET WARNING: The VM is a member of Availability Set '$_availabilitySetName'. VM start or resize can fail when the target size is unavailable on the cluster hosting the Availability Set." -category "WARNING"
    WriteRunLog -message "Stop/deallocate all VMs in the Availability Set before proceeding so Azure can place the set on a cluster that supports the target VM size." -category "IMPORTANT"

    $_availabilitySetPeers = @(Get-PlacementPeerStates `
        -PlacementType "AvailabilitySet" `
        -PlacementId $_availabilitySetId `
        -CurrentVMId $_VM.Id)
    $_runningAvailabilitySetPeers = @($_availabilitySetPeers |
        Where-Object { $_.PowerState -eq "PowerState/running" })
    WriteRunLog -message "Other Availability Set VM members detected: $($_availabilitySetPeers.Count)"
    if ($_runningAvailabilitySetPeers.Count -gt 0) {
        $_runningPeerList = ($_runningAvailabilitySetPeers | ForEach-Object {
            "$($_.Name) (resource group: $($_.ResourceGroupName))"
        }) -join ", "
        WriteRunLog -message "RUNNING AVAILABILITY SET PEERS: $_runningPeerList" -category "WARNING"
        WriteRunLog -message "Stop/deallocate these running Availability Set peers before proceeding: $_runningPeerList" -category "IMPORTANT"
    }
    else {
        WriteRunLog -message "No other running Availability Set VMs were detected."
    }
}
if ($_ppgId) {
    WriteRunLog -message "PROXIMITY PLACEMENT GROUP WARNING: The VM is a member of PPG '$_ppgName'. Start or resize can fail when capacity for the target VM size is outside the current PPG scope." -category "WARNING"
    WriteRunLog -message "Confirm target-SKU capacity within the PPG or plan to relax/remove the PPG constraint before migration." -category "IMPORTANT"

    $_ppgPeers = @(Get-PlacementPeerStates `
        -PlacementType "ProximityPlacementGroup" `
        -PlacementId $_ppgId `
        -CurrentVMId $_VM.Id)
    $_runningPpgPeers = @($_ppgPeers |
        Where-Object { $_.PowerState -eq "PowerState/running" })
    WriteRunLog -message "Other PPG VM members detected: $($_ppgPeers.Count)"
    if ($_runningPpgPeers.Count -gt 0) {
        $_runningPeerList = ($_runningPpgPeers | ForEach-Object {
            "$($_.Name) (resource group: $($_.ResourceGroupName))"
        }) -join ", "
        WriteRunLog -message "RUNNING PPG PEERS: $_runningPeerList" -category "WARNING"
        WriteRunLog -message "Running PPG peers can constrain target-SKU capacity and cause start/resize failures: $_runningPeerList" -category "IMPORTANT"
    }
    else {
        WriteRunLog -message "No other running PPG VMs were detected."
    }
}

# Effective Azure RBAC permission checks. Querying the permissions endpoint is
# more reliable than checking role names because it includes inherited and
# custom roles and evaluates wildcard Actions/NotActions.
$_osDiskId = $_VM.StorageProfile.OsDisk.ManagedDisk.Id
if ([string]::IsNullOrWhiteSpace($_osDiskId)) {
    WriteRunLog -message "The VM does not reference a managed OS disk; permission validation cannot continue." -category "ERROR"
    exit 1
}

WriteRunLog -message "Azure identity: $($_AzureContext.Account.Id) ($($_AzureContext.Account.Type))"

$_requiredVMActions = @(
    "Microsoft.Compute/virtualMachines/read",
    "Microsoft.Compute/virtualMachines/write",
    "Microsoft.Compute/virtualMachines/instanceView/read",
    "Microsoft.Compute/virtualMachines/deallocate/action"
)
if ($NewControllerType -eq "NVMe") {
    $_requiredVMActions += "Microsoft.Compute/virtualMachines/runCommand/action"
}
if ($StartVM) {
    $_requiredVMActions += "Microsoft.Compute/virtualMachines/start/action"
}
if ($StartVM -and $_VM.StorageProfile.OsDisk.OsType -eq "Windows" -and
    $NewControllerType -eq "NVMe" -and $FixOperatingSystemSettings) {
    $_requiredVMActions += "Microsoft.Compute/virtualMachines/restart/action"
}

Assert-EffectivePermissions -ScopeName "virtual machine '$VMName'" `
    -Scope $_VM.Id -RequiredActions ($_requiredVMActions | Select-Object -Unique)

$_requiredDiskActions = @(
    "Microsoft.Compute/disks/read",
    "Microsoft.Compute/disks/write"
)
Assert-EffectivePermissions -ScopeName "OS disk '$($_VM.StorageProfile.OsDisk.Name)'" `
    -Scope $_osDiskId -RequiredActions $_requiredDiskActions

try {
    $_osDiskResourceGroup = $_osDiskId.Split("/")[4]
    $_osDiskDetails = Invoke-AzureOperation -Operation "Get OS disk details" -ScriptBlock {
        Get-AzDisk -ResourceGroupName $_osDiskResourceGroup `
            -DiskName $_VM.StorageProfile.OsDisk.Name -ErrorAction Stop
    }
    $_supportedDiskControllers = $_osDiskDetails.SupportedCapabilities.DiskControllerTypes
    if ([string]::IsNullOrWhiteSpace($_supportedDiskControllers)) {
        $_supportedDiskControllers = "Not reported (SCSI is the default)"
    }

    WriteRunLog -message "OS disk details:"
    WriteRunLog -message "  Name: $($_osDiskDetails.Name)"
    WriteRunLog -message "  Resource group: $_osDiskResourceGroup"
    WriteRunLog -message "  SKU: $($_osDiskDetails.Sku.Name)"
    WriteRunLog -message "  Size: $($_osDiskDetails.DiskSizeGB) GB"
    WriteRunLog -message "  Hyper-V generation: $($_osDiskDetails.HyperVGeneration)"
    WriteRunLog -message "  Supported controller types: $_supportedDiskControllers"
}
catch {
    WriteRunLog -message "Failed to read OS disk details after permission validation" -category "ERROR"
    WriteRunLog -message $_.Exception.Message -category "ERROR"
    exit 1
}

# Check if the Azure Disk Encryption for Linux is present
if ($_VM.StorageProfile.OsDisk.OsType -eq "Linux") {
    try {
        $extension = Get-AzVMExtension -ResourceGroupName $ResourceGroupName -VMName $VMName -Name "AzureDiskEncryptionForLinux" -ErrorAction Stop

        if ($extension.ProvisioningState -eq "Succeeded") {
            WriteRunLog -message "ADE for Linux extension is installed and succeeded on VM: $($extension.VMName)" -category "ERROR"
                WriteRunLog -message "Azure Disk Encryption for Linux don't support NVMe disks" -category "ERROR"
                WriteRunLog $_.Exception.Message "ERROR"
                exit 1
            } else {
                WriteRunLog -message "ADE for Linux extension is installed but provisioning state is: $($extension.ProvisioningState)" -category "ERROR"
                WriteRunLog -message "If the VM has not been encrypted remove the extension and try again"  -category "ERROR"
                WriteRunLog $_.Exception.Message "ERROR"
                exit 1
            }
        }
        catch {
            WriteRunLog -message "ADE for Linux extension is NOT installed on this VM"
        }
}

# Get VM Power State
try {
    $_vminfo = Invoke-AzureOperation -Operation "Get VM '$VMName' instance view" -ScriptBlock {
        Get-AzVM -ResourceGroupName $ResourceGroupName -Name $VMName `
            -Status -ErrorAction Stop
    }
    $_powerState = ($_vminfo.Statuses | Where-Object { $_.Code -like 'PowerState*' }).Code
    $_provisioningState = ($_vminfo.Statuses | Where-Object { $_.Code -like 'ProvisioningState*' }).Code
    $_agentStatus = if ($_vminfo.VMAgent.Statuses) {
        ($_vminfo.VMAgent.Statuses | ForEach-Object { $_.DisplayStatus }) -join ", "
    } else {
        "Not reported"
    }
    $_agentVersion = if ($_vminfo.VMAgent.VmAgentVersion) {
        $_vminfo.VMAgent.VmAgentVersion
    } else {
        "Not reported"
    }

    WriteRunLog -message "Runtime details:"
    WriteRunLog -message "  Power state: $_powerState"
    WriteRunLog -message "  Provisioning state: $_provisioningState"
    WriteRunLog -message "  VM Agent status: $_agentStatus"
    WriteRunLog -message "  VM Agent version: $_agentVersion"

    # Check if VM is running
    if ($_powerState -ne "PowerState/running") {
    #if (($_vminfo.PowerState -ne "VM running")) {
        if ($NewControllerType -eq "NVMe") {
            if ($IgnoreOSCheck) {
                WriteRunLog -message "Ignoring VM Power State check, proceeding with conversion" -category "WARNING"
                WriteRunLog -message "VM $VMName is not running, but OS check is ignored." -category "WARNING"
            }
            else {
                if ($FixOperatingSystemSettings) {
                    WriteRunLog -message "Fixing operating system settings is not supported with IgnoreOSCheck or when the VM is not running" -category "ERROR"
                    WriteRunLog -message "Please start the VM and run the script again when using FixOperatingSystemSettings" -category "ERROR"
                    exit 1
                }
            }
        }
    }
    else {
        WriteRunLog -message "VM $VMName is running"
    }

    $_agentReady = $_vminfo.VMAgent.Statuses.DisplayStatus -eq "Ready"
    if ($_agentReady) {
        WriteRunLog -message "VM Agent is running on VM $VMName"
    }
    elseif ($FixOperatingSystemSettings) {
            WriteRunLog -message "VM Agent is not running on VM $VMName" -category "ERROR"
            WriteRunLog -message "Please make sure that the VM Agent is installed and running before proceeding" -category "ERROR"
            exit 1
    }
    else {
        WriteRunLog -message "VM Agent is not ready, but guest OS preparation was not requested" -category "WARNING"
    }

    if ($_vminfo.OsName -and $_vminfo.OsVersion) {
        WriteRunLog -message "Detected OS: $($_vminfo.OsName) $($_vminfo.OsVersion)" -category "INFO"
    }
    else {
        WriteRunLog -message "Could not detect OS version from VM instance view" -category "INFO"
    }

} catch {
    WriteRunLog -message "Error getting VM status" -category "ERROR"
    WriteRunLog $_.Exception.Message "ERROR"
    exit 1
}

# Check if VM is running Linux or Windows
if ($_VM.StorageProfile.OsDisk.OsType -eq "Windows") {
    $_os = "Windows"
    WriteRunLog -message "VM $VMName is running Windows"

    if ($_vm.StorageProfile.ImageReference.Publisher -eq "MicrosoftWindowsServer") {
        # Check Windows Version of OS
        $_osversion = $_VM.StorageProfile.ImageReference.Sku
        WriteRunLog -message "Windows Version: $_osversion"
        $_osversionMatch = [regex]::Match($_osversion, "20(19|22|25)")
        $_osversion_number = if ($_osversionMatch.Success) {
            [int]$_osversionMatch.Value
        } else {
            0
        }

        if (-not $IgnoreWindowsVersionCheck) {
            if ($_osversion_number -eq 0) {
                WriteRunLog -message "Could not determine a supported Windows Server release (2019, 2022, or 2025) from image SKU '$_osversion'." -category "ERROR"
                exit 1
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

# check if VM is running a Gen1 or Gen2 image
try {
    $_diskrg = $_vm.StorageProfile.OsDisk.ManagedDisk.Id.Split("/")[4]

    $_vm_osdisk = Invoke-AzureOperation -Operation "Get OS disk generation" -ScriptBlock {
        Get-AzDisk -Name $_vm.StorageProfile.OsDisk.Name `
            -ResourceGroupName $_diskrg -ErrorAction Stop
    }
    if ($_vm_osdisk.HyperVGeneration -eq 'V1') { 
        WriteRunLog -message "VM $VMName is running a Generation 1 image" -category "ERROR"
        WriteRunLog -message "NVMe controller are only supported on Generation 2 images" -category "ERROR"
        exit 1
    }
}
catch {
    WriteRunLog -message "Error getting VM Generation" -category "ERROR"
    WriteRunLog $_.Exception.Message "ERROR"
    exit 1
}

# Check if VM is running SCSI or NVMe. Older VM models can omit the property;
# an omitted controller type is SCSI.
$_currentControllerType = $_VM.StorageProfile.DiskControllerType
if ([string]::IsNullOrWhiteSpace($_currentControllerType)) {
    $_currentControllerType = "SCSI"
}

$_controllerChangeRequired = $_currentControllerType -ne $NewControllerType
WriteRunLog -message "VM $VMName is running $_currentControllerType"

if (-not $_controllerChangeRequired -and $_VM.HardwareProfile.VmSize -eq $VMSize) {
    WriteRunLog -message "VM already has controller $NewControllerType and size $VMSize. No action required."
    exit 0
}
elseif (-not $_controllerChangeRequired) {
    WriteRunLog -message "Controller already matches; proceeding with VM size change only"
}

if (-not $IgnoreSKUCheck) {
    WriteRunLog -message "Getting available SKU resources"
    WriteRunLog -message "This might take a while ..."
    $_VMSKUs = @(Invoke-AzureOperation -Operation "Get VM SKUs in $($_vm.Location)" -ScriptBlock {
        Get-AzComputeResourceSku -Location $_vm.Location -ErrorAction Stop
    }) | Where-Object { $_.ResourceType.Contains("virtualMachines") }
    $_VMSKU = $_VMSKUs | Where-Object { $_.Name -eq $VMSize } | Select-Object -First 1

    if (-not $_VMSKU) {
        WriteRunLog -category "ERROR" -message ("VM SKU doesn't exist, please check your input: " + $VMSize)
        exit 1
    }

    # Check if VM SKU is available in the VM's zone
    if ($_VM.Zones -and $_VM.Zones.Count -gt 0) {
        $vmZone = $_VM.Zones[0]
        if (-not ($_VMSKU.LocationInfo | Where-Object { $_.Zones -contains $vmZone })) {
            WriteRunLog -message "VM SKU $VMSize is not available in zone $vmZone" -category "ERROR"
            exit 1
        }
        else {
            WriteRunLog -message "VM SKU $VMSize is available in zone $vmZone"
        }
    }

    # MaxResourceVolumeMB > 0 means the SKU has a SCSI local temporary/resource disk.
    $_originalResourceVolumeMB = [int64]((($_VMSKUs |
        Where-Object { $_.Name -eq $script:_original_vm_size } |
        Select-Object -First 1).Capabilities |
        Where-Object { $_.Name -eq "MaxResourceVolumeMB" }).Value)
    $_newResourceVolumeMB = [int64](($_VMSKU.Capabilities |
        Where-Object { $_.Name -eq "MaxResourceVolumeMB" }).Value)
    $_originalVMHasResourceDisk = $_originalResourceVolumeMB -gt 0
    $_newVMHasResourceDisk = $_newResourceVolumeMB -gt 0

    if ($_os -eq "Linux") {
        WriteRunLog -message "Skipping resource disk support check for Linux VMs"
    }
    else {
        WriteRunLog -message "Checking resource disk support for Windows VMs"
        if (($_originalVMHasResourceDisk -and -not $_newVMHasResourceDisk) -or (-not $_originalVMHasResourceDisk -and $_newVMHasResourceDisk)) {
            # for Windows we need to check if the feature VMTempDiskResizePreview in Microsoft.Compute is registered
            $_resource_provider = Get-AzProviderFeature -FeatureName VMTempDiskResizePreview -ProviderNamespace Microsoft.Compute

            if ($_resource_provider.RegistrationState -ne "Registered") {
                WriteRunLog -message "Mismatch in SCSI resource disk support between original VM size ($script:_original_vm_size) and new VM size ($VMSize)." -category "ERROR"

                WriteRunLog -message "The Azure subscription is not registered for the feature VMTempDiskResizePreview, which is required to resize Windows VMs between SCSI and NVMe resource disks." -category "ERROR"
                WriteRunLog -message "This includes resizing from a VM with a SCSI temporary disk to a VM with an NVMe temporary disk, because Azure evaluates them as different disk types." -category "ERROR"
                WriteRunLog -message "Please register the subscription for the feature using the following command and try again:" -category "ERROR"
                WriteRunLog -message "   Register-AzProviderFeature -FeatureName VMTempDiskResizePreview -ProviderNamespace Microsoft.Compute" -category "ERROR"
                WriteRunLog -message "The feature is auto-approved, script will exit, please wait 10 minutes and then try again." -category "ERROR"
                exit 1
            }
            else {
                WriteRunLog -message "The Azure subscription is registered for the feature VMTempDiskResizePreview"
            }
        }
        else {
            WriteRunLog -message "Resource disk support matches between original VM size and new VM size."
        }
    }

    # For Windows VMs, a change in SCSI resource disk support can require pagefile changes.
    if ($_originalVMHasResourceDisk -and -not $_newVMHasResourceDisk -and $_os -eq "Windows") {
        WriteRunLog -message "Original VM size $script:_original_vm_size has a SCSI resource disk, but new VM size $VMSize does not." -category "IMPORTANT"
        WriteRunLog -message "The new VM size may use NVMe local temporary disks, which Azure does not report as SCSI resource disks, or may have no local temporary disk." -category "IMPORTANT"
        WriteRunLog -message "   Please make sure to adjust your swap space / pagefile configuration after migration." -category "IMPORTANT"
        WriteRunLog -message "   Any NVMe local temporary disks will show up as RAW disks in the new VM." -category "IMPORTANT"
    }

    WriteRunLog -message "Found VM SKU - Checking for Capabilities"
    $_supported_controller = ($_VMSKU.Capabilities | Where-Object { $_.Name -eq "DiskControllerTypes" }).Value

    if ([string]::IsNullOrEmpty($_supported_controller) -and $NewControllerType -eq "NVMe") {
        WriteRunLog -message "VM SKU doesn't have supported capabilities" -category "ERROR"
        exit 1
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
                exit 1
            }
        }
        else {
            # SCSI is supported by all VM types
            WriteRunLog -message "VM supports SCSI"
        }
    }
}

# Windows Check script for NVMe
$Check_Windows_Script = @'
<#
.SYNOPSIS
    Checks if a Windows VM is ready for SCSI-to-NVMe disk controller conversion.

.DESCRIPTION
    Read-only companion to nvme-prepare-os.ps1. Runs INSIDE the guest OS (via
    Azure RunCommand or RDP) and reports whether the VM can safely convert to
    an NVMe-capable Azure VM size (e.g., Standard_D8s_v6).

    Checks performed (all ControlSets):
      - stornvme.sys driver binary exists
      - stornvme Start = 0 (Boot)
      - stornvme StartOverride absent (the key blocker for NVMe boot)
      - stornvme Parameters\IoTimeoutValue = 240 seconds
      - stornvme Parameters\BusType = 17 (NVMe)
      - stornvme Parameters\StorageSupportedFeatures = 3
      - stornvme Parameters\PnpInterface\5 = 1
      - vpci Start = 0 and StartOverride absent
      - pci Start = 0 (Boot)
      - pci StartOverride reported for information (allowed)
      - Boot driver chain (partmgr, disk, volmgr, etc.)

    Makes NO changes to the system. Safe to run at any time.

    Exit codes:
      0 = READY      (VM can be converted to NVMe as-is)
      1 = NEEDS_PREP (run nvme-prepare-os.ps1 first)
      2 = BLOCKED    (missing driver or critical issue)

.EXAMPLE
    # Via Azure RunCommand:
    Invoke-AzVMRunCommand -ResourceGroupName "myRG" -VMName "myVM" `
        -CommandId 'RunPowerShellScript' -ScriptPath ".\nvme-check-os.ps1"

    # Via RDP/PowerShell:
    .\nvme-check-os.ps1
#>

$ErrorActionPreference = 'Stop'

$pass = 0; $fail = 0; $warn = 0
$issues = @()

function Write-Status { param([string]$msg, [string]$level = "INFO")
    $prefix = switch ($level) { "PASS" { "[PASS] " } "FAIL" { "[FAIL] " } "WARN" { "[WARN] " } "OK" { "[OK]   " } default { "[INFO] " } }
    Write-Host "$prefix $msg"
}

function Add-Check { param([string]$name, [string]$result, [string]$detail = "")
    $msg = $name
    if ($detail) { $msg = $name + " - " + $detail }
    Write-Status $msg $result
    switch ($result) {
        "PASS" { $script:pass++ }
        "FAIL" { $script:fail++; $script:issues += ($name + " : " + $detail) }
        "WARN" { $script:warn++ }
    }
}

# --- OS Information ---
$os = Get-CimInstance Win32_OperatingSystem
Write-Status ("OS: " + $os.Caption + " (" + $os.Version + ")")

# Win32_OperatingSystem.ProductType has exactly three documented values:
#   1 = Workstation (Windows client, such as Windows 10 or Windows 11)
#   2 = Domain Controller
#   3 = Server (member or standalone server)
# This validates the CIM response only; it is not a Windows version/support
# check. Any other value (or a null result) is unexpected and treated as blocked.
if ($null -eq $os -or $os.ProductType -notin 1, 2, 3) {
    $productType = if ($null -eq $os) { "<null OS result>" } else { $os.ProductType }
    Write-Host ("=== RESULT: BLOCKED (unexpected ProductType=" + $productType +
        "; expected 1=Workstation, 2=Domain Controller, or 3=Server) ===")
    exit 2
}

# --- Check 1: stornvme.sys driver binary ---
$driverPath = $env:SystemRoot + "\System32\drivers\stornvme.sys"
if (Test-Path $driverPath) {
    $ver = (Get-Item $driverPath).VersionInfo.FileVersion
    Add-Check "stornvme.sys" "PASS" ("version " + $ver)
} else {
    Add-Check "stornvme.sys" "FAIL" ("not found at " + $driverPath)
    Write-Host ""
    Write-Host "=== RESULT: BLOCKED (missing stornvme.sys driver) ==="
    exit 2
}

# --- Enumerate ControlSets ---
$controlSets = @(Get-ChildItem "HKLM:\SYSTEM" -ErrorAction SilentlyContinue |
    Where-Object { $_.PSChildName -match '^ControlSet\d+$' } |
    ForEach-Object { $_.PSChildName })
$selectProps = Get-ItemProperty "HKLM:\SYSTEM\Select" -ErrorAction SilentlyContinue
if ($controlSets.Count -eq 0 -or $null -eq $selectProps) {
    Write-Host "=== RESULT: BLOCKED (unable to enumerate SYSTEM ControlSets) ==="
    exit 2
}
$csInfo = "ControlSets: " + ($controlSets -join ', ') + " (Current=" + $selectProps.Current + " LastKnownGood=" + $selectProps.LastKnownGood + ")"
Write-Status $csInfo
Write-Host ""

# --- Check 2-5: Service configuration across ALL ControlSets ---
foreach ($cs in $controlSets) {
    Write-Status ("--- " + $cs + " ---")
    $csRoot = "HKLM:\SYSTEM\" + $cs

    # stornvme Start
    $svcPath = $csRoot + "\Services\stornvme"
    $start = (Get-ItemProperty -Path $svcPath -Name Start -ErrorAction SilentlyContinue).Start
    if ($start -eq 0) {
        Add-Check ($cs + "\stornvme Start") "PASS" "0 (Boot)"
    } else {
        $startDetail = if ($null -eq $start) { "missing" } else { $start.ToString() }
        Add-Check ($cs + "\stornvme Start") "FAIL" ($startDetail + " (need 0=Boot)")
    }

    # stornvme StartOverride (the critical blocker)
    $soPath = $svcPath + "\StartOverride"
    if (Test-Path $soPath) {
        $soProps = Get-ItemProperty -Path $soPath -ErrorAction SilentlyContinue
        $soVal = $soProps.'0'
        if ($null -eq $soVal) { $soVal = "key exists" } else { $soVal = $soVal.ToString() }
        Add-Check ($cs + "\stornvme StartOverride") "FAIL" ("present (value=" + $soVal + ") overrides Start to demand-start")
    } else {
        Add-Check ($cs + "\stornvme StartOverride") "PASS" "absent"
    }

    # stornvme I/O timeout
    $parametersPath = $svcPath + "\Parameters"
    $ioTimeout = (Get-ItemProperty -Path $parametersPath -Name IoTimeoutValue -ErrorAction SilentlyContinue).IoTimeoutValue
    if ($ioTimeout -eq 240) {
        Add-Check ($cs + "\stornvme IoTimeoutValue") "PASS" "240 seconds"
    } else {
        $timeoutDetail = if ($null -eq $ioTimeout) { "missing" } else { $ioTimeout.ToString() }
        Add-Check ($cs + "\stornvme IoTimeoutValue") "FAIL" ($timeoutDetail + " (need 240)")
    }

    $busType = (Get-ItemProperty -Path $parametersPath -Name BusType -ErrorAction SilentlyContinue).BusType
    if ($busType -eq 17) {
        Add-Check ($cs + "\stornvme BusType") "PASS" "17 (NVMe)"
    } else {
        $busTypeDetail = if ($null -eq $busType) { "missing" } else { $busType.ToString() }
        Add-Check ($cs + "\stornvme BusType") "FAIL" ($busTypeDetail + " (need 17=NVMe)")
    }

    $features = (Get-ItemProperty -Path $parametersPath -Name StorageSupportedFeatures `
        -ErrorAction SilentlyContinue).StorageSupportedFeatures
    if ($features -eq 3) {
        Add-Check ($cs + "\stornvme StorageSupportedFeatures") "PASS" "3"
    } else {
        $featuresDetail = if ($null -eq $features) { "missing" } else { $features.ToString() }
        Add-Check ($cs + "\stornvme StorageSupportedFeatures") "FAIL" ($featuresDetail + " (need 3)")
    }

    $pnpInterface = (Get-ItemProperty -Path ($parametersPath + "\PnpInterface") `
        -Name 5 -ErrorAction SilentlyContinue).'5'
    if ($pnpInterface -eq 1) {
        Add-Check ($cs + "\stornvme PnpInterface\5") "PASS" "1"
    } else {
        $pnpDetail = if ($null -eq $pnpInterface) { "missing" } else { $pnpInterface.ToString() }
        Add-Check ($cs + "\stornvme PnpInterface\5") "FAIL" ($pnpDetail + " (need 1)")
    }

    # vpci exposes Azure's virtual PCI bus over VMBUS. Without it, the NVMe
    # controller never appears and stornvme has no device to bind to.
    $vpciPath = $csRoot + "\Services\vpci"
    $vpciStart = (Get-ItemProperty -Path $vpciPath -Name Start -ErrorAction SilentlyContinue).Start
    if ($vpciStart -eq 0) {
        Add-Check ($cs + "\vpci Start") "PASS" "0 (Boot)"
    } else {
        $vpciStartDetail = if ($null -eq $vpciStart) { "missing" } else { $vpciStart.ToString() }
        Add-Check ($cs + "\vpci Start") "FAIL" ($vpciStartDetail + " (need 0=Boot)")
    }

    $vpciSOPath = $vpciPath + "\StartOverride"
    if (Test-Path $vpciSOPath) {
        $vpciSOProps = Get-ItemProperty -Path $vpciSOPath -ErrorAction SilentlyContinue
        $vpciSOValue = $vpciSOProps.'0'
        if ($null -eq $vpciSOValue) { $vpciSOValue = "key exists" }
        Add-Check ($cs + "\vpci StartOverride") "FAIL" ("present (value=" + $vpciSOValue + ") blocks virtual PCI enumeration")
    } else {
        Add-Check ($cs + "\vpci StartOverride") "PASS" "absent"
    }

    # pci Start
    $pciPath = $csRoot + "\Services\pci"
    $pciStart = (Get-ItemProperty -Path $pciPath -Name Start -ErrorAction SilentlyContinue).Start
    if ($pciStart -eq 0) {
        Add-Check ($cs + "\pci Start") "PASS" "0 (Boot)"
    } else {
        $pciStartDetail = if ($null -eq $pciStart) { "missing" } else { $pciStart.ToString() }
        Add-Check ($cs + "\pci Start") "FAIL" ($pciStartDetail + " (need 0=Boot)")
    }

    # pci StartOverride
    $pciSOPath = $csRoot + "\Services\pci\StartOverride"
    if (Test-Path $pciSOPath) {
        $pciSOValues = ((Get-ItemProperty -Path $pciSOPath -ErrorAction SilentlyContinue).PSObject.Properties |
            Where-Object { $_.Name -notmatch '^PS' } |
            ForEach-Object { $_.Name + '=' + $_.Value }) -join ', '
        Add-Check ($cs + "\pci StartOverride") "PASS" ("present (" + $pciSOValues + ") - allowed")
    } else {
        Add-Check ($cs + "\pci StartOverride") "PASS" "absent"
    }
    Write-Host ""
}

# --- Check 6: Boot driver chain (CurrentControlSet only) ---
Write-Status "--- Boot Driver Chain ---"
$currentCS = "HKLM:\SYSTEM\ControlSet00" + $selectProps.Current
$bootDrivers = @("vpci", "pci", "stornvme", "partmgr", "disk", "volmgr", "volume", "volsnap", "mountmgr")
foreach ($driver in $bootDrivers) {
    $drvPath = $currentCS + "\Services\" + $driver
    if (Test-Path $drvPath) {
        $drvStart = (Get-ItemProperty -Path $drvPath -Name Start -ErrorAction SilentlyContinue).Start
        if ($drvStart -eq 0) {
            Add-Check $driver "PASS" "Start=0 (Boot)"
        } else {
            Add-Check $driver "WARN" ("Start=" + $drvStart + " (non-boot)")
        }
    } else {
        Add-Check $driver "WARN" "service not found"
    }
}

# --- Summary ---
Write-Host ""
Write-Host "=== SUMMARY ==="
Write-Status ("Checks: " + $pass + " passed, " + $fail + " failed, " + $warn + " warnings")

if ($fail -eq 0) {
    Write-Host ""
    Write-Host "=== RESULT: READY ==="
    if (-not $SuppressNextSteps) {
        Write-Host "VM can be converted to NVMe. Proceed with:"
        Write-Host "  1. Stop-AzVM -Force"
        Write-Host "  2. Update disk supportedCapabilities to SCSI, NVMe"
        Write-Host "  3. Update VM size + DiskControllerType = NVMe"
        Write-Host "  4. Start-AzVM"
    }
    exit 0
} else {
    Write-Host ""
    Write-Host "=== RESULT: NEEDS_PREP ==="
    Write-Host "Run nvme-prepare-os.ps1 before converting. Issues:"
    foreach ($issue in $issues) {
        Write-Host ("  - " + $issue)
    }
    exit 1
}
'@

$Windows_Fix_Script = @'
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
'@

# Pre-Checks completed
WriteRunLog -message "Pre-Checks completed"

# running preparation for operating systems
if ($_os -eq "Windows") {
    
    if ($NewControllerType -eq "NVMe" -and $_controllerChangeRequired) {
        WriteRunLog -message "Starting OS section"

        try {

            if (-not $IgnoreOSCheck) {

                WriteRunLog -message "Checking if operating system is prepared for NVMe migration"
                try {
                    $RunCommandResult = Invoke-AzureOperation `
                        -Operation "Run Windows NVMe readiness check" `
                        -ScriptBlock {
                            Invoke-AzVMRunCommand -ResourceGroupName $ResourceGroupName `
                                -VMName $VMName -CommandId 'RunPowerShellScript' `
                                -ScriptString ("`$SuppressNextSteps = `$true`n" + $Check_Windows_Script) `
                                -ErrorAction Stop
                        }
                }
                catch {
                    WriteRunLog -message "Failed to run command on VM '$VMName'. Please verify the VM is running and that you have the required permissions (e.g. 'Virtual Machine Contributor')." -category "ERROR"
                    WriteRunLog -message $_.Exception.Message -category "ERROR"
                    exit 1
                }

                if ($null -eq $RunCommandResult -or $null -eq $RunCommandResult.Value -or $RunCommandResult.Value.Count -eq 0) {
                    WriteRunLog -message "Run command on VM '$VMName' did not return any result. Please verify the VM is running and that you have the required permissions." -category "ERROR"
                    exit 1
                }

                $checkOutput = $RunCommandResult.Value[0].Message

                if ([string]::IsNullOrWhiteSpace($checkOutput)) {
                    WriteRunLog -message "Run command on VM '$VMName' returned an empty result. The script may not have executed successfully." -category "ERROR"
                    exit 1
                }
                # WriteRunLog -message $checkOutput

                foreach ($line in ($checkOutput -split "`n" | ForEach-Object { $_.Trim() } | Where-Object { $_ })) {
                    if ($line -match '\[FAIL\]|:FAIL|\[ERROR\]|FATAL:') {
                        WriteRunLog -message $line -category "ERROR"
                    }
                    elseif ($line -match '\[WARN\]|:WARN') {
                        WriteRunLog -message $line -category "WARNING"
                    }
                    elseif ($line -match 'RESULT:') {
                        if ($line -match 'SUCCESS|READY') {
                            WriteRunLog -message $line -category "IMPORTANT"
                        }
                        else {
                            WriteRunLog -message $line -category "ERROR"
                        }
                    }
                    else {
                        WriteRunLog -message $line -category "INFO"
                    }
                }

                if ($checkOutput -match 'RESULT: READY') {
                    WriteRunLog -message "VM $VMName is already NVMe-ready, skipping prep"
                }
                else {

                    if ($FixOperatingSystemSettings) {
                        WriteRunLog -message "Fixing operating system settings"
                        WriteRunLog -message "Running script to prepare Windows OS for NVMe migration"
                        # WriteRunLog -message "   sc.exe config stornvme start=boot"
                        # $RunCommandResult = Invoke-AzVMRunCommand -ResourceGroupName $ResourceGroupName -VMName $VMName -CommandId 'RunPowerShellScript' -ScriptString 'Start-Process -FilePath "C:\Windows\System32\sc.exe" -ArgumentList "config stornvme start=boot"'
                        try {
                            $RunCommandResult = Invoke-AzureOperation `
                                -Operation "Run Windows NVMe preparation" `
                                -ScriptBlock {
                                    Invoke-AzVMRunCommand -ResourceGroupName $ResourceGroupName `
                                        -VMName $VMName -CommandId 'RunPowerShellScript' `
                                        -ScriptString ("`$SuppressNextSteps = `$true`n" + $Windows_Fix_Script) `
                                        -ErrorAction Stop
                                }
                        }
                        catch {
                            WriteRunLog -message "Failed to run command on VM '$VMName'. Please verify the VM is running and that you have the required permissions (e.g. 'Virtual Machine Contributor')." -category "ERROR"
                            WriteRunLog -message $_.Exception.Message -category "ERROR"
                            exit 1
                        }

                        if ($null -eq $RunCommandResult -or $null -eq $RunCommandResult.Value -or $RunCommandResult.Value.Count -eq 0) {
                            WriteRunLog -message "Run command on VM '$VMName' did not return any result. Please verify the VM is running and that you have the required permissions." -category "ERROR"
                            exit 1
                        }

                        $checkOutput = $RunCommandResult.Value[0].Message

                        if ([string]::IsNullOrWhiteSpace($checkOutput)) {
                            WriteRunLog -message "Run command on VM '$VMName' returned an empty result. The script may not have executed successfully." -category "ERROR"
                            exit 1
                        }

                        foreach ($line in ($checkOutput -split "`n" | ForEach-Object { $_.Trim() } | Where-Object { $_ })) {
                            if ($line -match '\[FAIL\]|:FAIL|\[ERROR\]|FATAL:') {
                                WriteRunLog -message $line -category "ERROR"
                            }
                            elseif ($line -match '\[WARN\]|:WARN') {
                                WriteRunLog -message $line -category "WARNING"
                            }
                            elseif ($line -match 'RESULT:') {
                                if ($line -match 'SUCCESS|READY') {
                                    WriteRunLog -message $line -category "IMPORTANT"
                                }
                                else {
                                    WriteRunLog -message $line -category "ERROR"
                                }
                            }
                            else {
                                WriteRunLog -message $line -category "INFO"
                            }
                        }

                        $_prepSucceeded = ($checkOutput -match 'All checks passed across ALL ControlSets') -and
                            ($checkOutput -match 'Registry hive flushed to disk successfully|Registry flushed via individual ControlSet keys') -and
                            ($checkOutput -notmatch '\[ERROR\]|FATAL:')
                        if (-not $_prepSucceeded) {
                            WriteRunLog -message "Failed to prepare Windows OS for NVMe migration" -category "ERROR"
                            exit 1
                        }

                        # Run the independent read-only check after preparation.
                        WriteRunLog -message "Verifying Windows OS preparation"
                        try {
                            $RunCommandResult = Invoke-AzureOperation `
                                -Operation "Verify Windows NVMe preparation" `
                                -ScriptBlock {
                                    Invoke-AzVMRunCommand -ResourceGroupName $ResourceGroupName `
                                        -VMName $VMName -CommandId 'RunPowerShellScript' `
                                        -ScriptString ("`$SuppressNextSteps = `$true`n" + $Check_Windows_Script) `
                                        -ErrorAction Stop
                                }
                        }
                        catch {
                            WriteRunLog -message "Failed to verify Windows OS preparation on VM '$VMName'" -category "ERROR"
                            WriteRunLog -message $_.Exception.Message -category "ERROR"
                            exit 1
                        }

                        $verifyOutput = ($RunCommandResult.Value | ForEach-Object { $_.Message }) -join "`n"
                        foreach ($line in ($verifyOutput -split "`n" | ForEach-Object { $_.Trim() } | Where-Object { $_ })) {
                            WriteRunLog -message ("   Verification: " + $line)
                        }
                        if ($verifyOutput -notmatch 'RESULT: READY' -or $verifyOutput -match '\[FAIL\]') {
                            WriteRunLog -message "Windows OS verification failed; aborting before shutdown" -category "ERROR"
                            exit 1
                        }

                        WriteRunLog -message "Windows OS prepared and verified successfully for NVMe migration"
                        WriteRunLog -message "Shutting down the VM to complete preparation and proceed with migration"
                    }
                    else {
                        WriteRunLog -message "Windows is not ready for NVMe conversion" -category "ERROR"
                        WriteRunLog -message "Run again with -FixOperatingSystemSettings, or use -IgnoreOSCheck only after preparing and verifying the guest independently" -category "IMPORTANT"
                        exit 1
                    }
                }
            }
            else {
                WriteRunLog -message "Skipping OS Check, assuming that the operating system is ready for conversion"
                if ($FixOperatingSystemSettings) {
                    WriteRunLog -message "Fixing operating system settings not supported with skipped OS Check" -category "ERROR"
                    exit 1
                }
            }
        } catch {
            WriteRunLog -message "Error running preparation for Windows OS" -category "ERROR"
            WriteRunLog $_.Exception.Message "ERROR"
            exit 1
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
        redhat|rhel|centos|rocky|suse|sles|ol)
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
            echo "[INFO] Setting nvme_core.io_timeout to 240..."
            case "$distro" in
                ubuntu|debian)
                    sed -i 's/GRUB_CMDLINE_LINUX="/GRUB_CMDLINE_LINUX="nvme_core.io_timeout=240 /g' /etc/default/grub
                    update-grub
                    ;;
                redhat|rhel|centos|rocky|suse|sles)
                    if [ -f /etc/default/grub ]; then
                        sed -i 's/GRUB_CMDLINE_LINUX="/GRUB_CMDLINE_LINUX="nvme_core.io_timeout=240 /g' /etc/default/grub
                        grub2-mkconfig -o /boot/grub2/grub.cfg
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
                        grub2-mkconfig -o /boot/grub2/grub.cfg
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
        else
            echo "[ERROR] nvme_core.io_timeout is not set to 240."
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
            : > /etc/fstab.new
            
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
                    elif [[ "$device" =~ ^/dev/disk/azure/scsi[0-9]*/lun[0-9]* ]]; then
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

$mana_check_script = @'
#!/bin/bash
echo "=== MANA Driver Check ==="
echo ""

mana_found=false

# Check if mana module is currently loaded
if lsmod 2>/dev/null | grep -qi 'mana'; then
    echo "[LOADED] MANA kernel module is currently loaded:"
    lsmod | grep -i 'mana'
    mana_found=true
else
    echo "[NOT LOADED] MANA kernel module is not currently loaded."
fi

echo ""

# Check if mana module is available (installed but not necessarily loaded)
if modinfo mana &>/dev/null; then
    echo "[AVAILABLE] MANA module is available in the kernel:"
    modinfo mana | grep -E '^(filename|version|description|author):'
    mana_found=true
else
    echo "[NOT AVAILABLE] MANA module not found via modinfo."
fi

echo ""

# Check for MANA network interfaces via ethtool
for iface in /sys/class/net/*/; do
    iface_name=$(basename "$iface")
    if [ "$iface_name" = "lo" ]; then
        continue
    fi
    driver=$(ethtool -i "$iface_name" 2>/dev/null | grep '^driver:' | awk '{print $2}')
    if echo "$driver" | grep -qi 'mana'; then
        echo "[INTERFACE] Interface '$iface_name' is using the MANA driver."
        ethtool -i "$iface_name" 2>/dev/null
        mana_found=true
    fi
done

echo ""

# Check for MANA devices in dmesg
if dmesg 2>/dev/null | grep -qi 'mana'; then
    echo "[DMESG] MANA references found in kernel messages:"
    dmesg | grep -i 'mana' | tail -10
else
    echo "[DMESG] No MANA references found in kernel messages."
fi

echo ""
echo "=== Summary ==="
if [ "$mana_found" = true ]; then
    echo "RESULT: MANA driver IS installed/present on this system."
else
    echo "RESULT: MANA driver is NOT installed on this system."
fi
'@


$linux_fix_script = $linux_check_script.Replace("fix=false","fix=true")

        if ($NewControllerType -eq "NVMe" -and $_controllerChangeRequired) {
            if (-not $IgnoreOSCheck) {

                if ($FixOperatingSystemSettings) {
                    # Invoke the Run Command
                    $RunCommandResult = Invoke-AzureOperation `
                        -Operation "Run Linux NVMe preparation" `
                        -ScriptBlock {
                            Invoke-AzVMRunCommand -ResourceGroupName $resourceGroupName `
                                -Name $vmName -CommandId 'RunShellScript' `
                                -ScriptString $linux_fix_script -ErrorAction Stop
                        }

                }
                else {
                    # Invoke the Run Command
                    $RunCommandResult = Invoke-AzureOperation `
                        -Operation "Run Linux NVMe readiness check" `
                        -ScriptBlock {
                            Invoke-AzVMRunCommand -ResourceGroupName $resourceGroupName `
                                -Name $vmName -CommandId 'RunShellScript' `
                                -ScriptString $linux_check_script -ErrorAction Stop
                        }

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
                    WriteRunLog -message "Linux is not ready for NVMe conversion" -category "ERROR"
                    if ($FixOperatingSystemSettings) {
                        WriteRunLog -message "The attempted Linux fixes did not satisfy all readiness checks" -category "ERROR"
                    }
                    else {
                        WriteRunLog -message "Run again with -FixOperatingSystemSettings, or use -IgnoreOSCheck only after preparing and verifying the guest independently" -category "IMPORTANT"
                    }
                    exit 1
                }
            }
            else {
                WriteRunLog -message "Skipping OS Check, assuming that the operating system is ready for conversion"
                if ($FixOperatingSystemSettings) {
                    WriteRunLog -message "Fixing operating system settings not supported with skipped OS Check" -category "ERROR"
                    exit 1
                }
            }
        }
        else {
            WriteRunLog -message "No preparation required for SCSI."
        }

    } catch {
        WriteRunLog -message "Error running preparation for Linux OS" -category "ERROR"
        WriteRunLog $_.Exception.Message "ERROR"
        exit 1
    }

    # Checking for MANA driver presence on Linux VMs
    WriteRunLog -message "Checking for MANA driver presence on Linux VM"
    try {
        $RunCommandResult = Invoke-AzureOperation `
            -Operation "Check Linux MANA driver" `
            -ScriptBlock {
                Invoke-AzVMRunCommand -ResourceGroupName $resourceGroupName `
                    -Name $vmName -CommandId 'RunShellScript' `
                    -ScriptString $mana_check_script -ErrorAction Stop
            }
        $manaCheckOutput = ($RunCommandResult.Value | ForEach-Object { $_.Message }) -split "`n"
        foreach ($line in $manaCheckOutput) {
            WriteRunLog -message ("   MANA Check: " + $line)
        }
        if ($manaCheckOutput -match 'RESULT: MANA driver IS installed') {
            WriteRunLog -message "MANA driver is present on this Linux VM" -category "INFO"
        }
        else {
            WriteRunLog -message "MANA driver does not seem to be present on this Linux VM" -category "WARNING"
            WriteRunLog -message "Please check if MANA driver is required for your workload and if it is, please install the MANA driver before running the conversion" -category "IMPORTANT"
            WriteRunLog -message "You can find more information about MANA driver and installation instructions here: https://learn.microsoft.com/en-us/azure/virtual-network/accelerated-networking-mana-linux" -category "IMPORTANT"
        }
    } catch {
        WriteRunLog -message "Error checking for MANA driver on Linux VM" -category "ERROR"
        WriteRunLog $_.Exception.Message "ERROR"
    }
}

# Shutting down VM
WriteRunLog -message "Checking Power Status of VM $VMName"
try {
    $_stopvm = Invoke-AzureOperation -Operation "Stop/deallocate VM '$VMName'" -ScriptBlock {
        Stop-AzVM -ResourceGroupName $ResourceGroupName -Name $VMName `
            -Force -ErrorAction Stop
    }
    if ($_stopvm.Status -eq "Succeeded") {
        WriteRunLog -message "Stop command issued for VM $VMName"
    }
    else {      
        WriteRunLog -message "Error issuing stop command for VM $VMName" -category "ERROR"
        exit 1
    }
    WriteRunLog -message "VM $VMName stopped"
} catch {
    WriteRunLog -message "Error stopping VM $VMName" -category "ERROR"
    WriteRunLog $_.Exception.Message "ERROR"
    exit 1
}

# Checking status of VM
WriteRunLog -message "Checking if VM is stopped and deallocated"
$_vminfo = Invoke-AzureOperation -Operation "Verify VM '$VMName' is deallocated" -ScriptBlock {
    Get-AzVM -ResourceGroupName $ResourceGroupName -Name $VMName `
        -Status -ErrorAction Stop
}
if (($_vminfo.Statuses | Where-Object { $_.Code -like 'PowerState*' }).Code -ne "PowerState/deallocated") {
#if ($_vminfo.PowerState -ne "deallocated") {
    WriteRunLog -message "VM is not deallocated. Please deallocate the VM before running this script."
    WriteRunLog -message "giving it another try"
    $_stopvm = Invoke-AzureOperation -Operation "Retry stop/deallocate VM '$VMName'" -ScriptBlock {
        Stop-AzVM -ResourceGroupName $ResourceGroupName -Name $VMName `
            -Force -ErrorAction Stop
    }
    $_vminfo = Invoke-AzureOperation -Operation "Recheck VM '$VMName' deallocation" -ScriptBlock {
        Get-AzVM -ResourceGroupName $ResourceGroupName -Name $VMName `
            -Status -ErrorAction Stop
    }
    $_powerState = ($_vminfo.Statuses | Where-Object { $_.Code -like 'PowerState*' }).Code
    if ($_powerState -ne "PowerState/deallocated") {
        WriteRunLog -message "VM is not deallocated. Please check why the VM is not deallocated." -category "ERROR"
        exit 1
    }
}

$_osdisk = Invoke-AzureOperation -Operation "Get OS disk for capability update" -ScriptBlock {
    Get-AzDisk -ResourceGroupName $_diskrg `
        -Name $_VM.StorageProfile.OsDisk.Name -ErrorAction Stop
}
if (-not $_osdisk) {
    WriteRunLog -message "OS Disk not found" -category "ERROR"
    exit 1
}
else {
    WriteRunLog -message "OS Disk found: $($_osdisk.Name)"
    if ($newControllerType -eq "NVMe") {
        if ($_osdisk.SupportedCapabilities.DiskControllerTypes -match "NVMe") {
            WriteRunLog -message "OS Disk already supports NVMe, no update needed"
        }
        else {
            WriteRunLog -message "OS Disk doesn't support NVMe, updating supported capabilities to include NVMe"
            $_osdisk.SupportedCapabilities = @{ DiskControllerTypes = "SCSI, NVMe" }
            $_OSDiskUpdateResult = Invoke-AzureOperation `
                -Operation "Update OS disk supported controller types" `
                -ScriptBlock {
                    $_osdisk | Update-AzDisk -ErrorAction Stop
                }
            if ($_OSDiskUpdateResult.ProvisioningState -eq "Succeeded") {
                WriteRunLog -message "OS Disk supported capabilities updated to include NVMe"
            }
            else {
                WriteRunLog -message "Error updating OS Disk supported capabilities" -category "ERROR"
                exit 1
            }
        }
    }
    else {
        WriteRunLog -message "SCSI is supported by all disks, no update needed"
    }
}

# Update only VM size and controller. Update-AzVM serializes the complete VM
# model and can resubmit output-only diskIOPSReadWrite/diskMBpsReadWrite values
# for attached Ultra Disk or Premium SSD v2 disks, causing HTTP 409.
WriteRunLog -message "Setting new VM Size from $($_VM.HardwareProfile.VmSize) to $VMSize and Controller to $NewControllerType"
try {
    $_vmPatch = @{
        properties = @{
            hardwareProfile = @{
                vmSize = $VMSize
            }
            storageProfile = @{
                diskControllerType = $NewControllerType
            }
        }
    } | ConvertTo-Json -Depth 6

    $_vmUpdateResponse = Invoke-AzureOperation -Operation "Update VM size and disk controller" -ScriptBlock {
        Invoke-AzRestMethod -Path "$($_VM.Id)?api-version=2024-11-01" `
            -Method PATCH -Payload $_vmPatch -ErrorAction Stop
    }
    WriteRunLog -message "VM update request returned HTTP $($_vmUpdateResponse.StatusCode)"
    if ([int]$_vmUpdateResponse.StatusCode -lt 200 -or
        [int]$_vmUpdateResponse.StatusCode -ge 300) {
        throw "VM update request failed with HTTP $($_vmUpdateResponse.StatusCode): $($_vmUpdateResponse.Content)"
    }

    # VM updates can be asynchronous even when the PATCH request succeeds.
    # Poll until the requested size/controller is visible instead of treating
    # the first eventually-consistent GET as a failure.
    $_updateDeadline = (Get-Date).AddMinutes(3)
    do {
        Start-Sleep -Seconds 5
        $_VM = Invoke-AzureOperation -Operation "Verify VM configuration update" -ScriptBlock {
            Get-AzVM -ResourceGroupName $ResourceGroupName -Name $VMName -ErrorAction Stop
        }
        $_updatedControllerType = $_VM.StorageProfile.DiskControllerType
        if ([string]::IsNullOrWhiteSpace($_updatedControllerType)) {
            $_updatedControllerType = "SCSI"
        }
        $_updateComplete = ($_VM.HardwareProfile.VmSize -eq $VMSize -and
            $_updatedControllerType -eq $NewControllerType)
        if (-not $_updateComplete) {
            WriteRunLog -message "Waiting for VM update: size=$($_VM.HardwareProfile.VmSize), controller=$_updatedControllerType"
        }
    } while (-not $_updateComplete -and (Get-Date) -lt $_updateDeadline)

    if (-not $_updateComplete) {
        throw "VM update did not complete within 3 minutes: size=$($_VM.HardwareProfile.VmSize), controller=$_updatedControllerType. Check Availability Set/PPG peer state and target-SKU capacity."
    }
    WriteRunLog -message "VM $VMName updated"
} catch {
    WriteRunLog -message "Error updating VM $VMName" -category "ERROR"
    Write-StartAllocationGuidance -FailureMessage $_.Exception.Message `
        -VMUpdateCompleted $false
    WriteRunLog $_.Exception.Message "ERROR"
    exit 1
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
        $_startvm = Invoke-AzureOperation -Operation "Start VM '$VMName'" `
            -MaxAttempts 1 -ScriptBlock {
                Start-AzVM -ResourceGroupName $ResourceGroupName -Name $VMName `
                    -ErrorAction Stop
            }
        if ($_startvm.Status -eq "Succeeded") {
            WriteRunLog -message "VM $VMName start operation completed; validating guest boot"
            $_bootTimeout = 600
            $_bootElapsed = 0
            $_agentReady = $false
            do {
                Start-Sleep -Seconds 15
                $_bootElapsed += 15
                $_vminfo = Invoke-AzureOperation `
                    -Operation "Check VM '$VMName' boot status" `
                    -ScriptBlock {
                        Get-AzVM -ResourceGroupName $ResourceGroupName -Name $VMName `
                            -Status -ErrorAction Stop
                    }
                $_powerState = ($_vminfo.Statuses | Where-Object { $_.Code -like 'PowerState*' }).Code
                $_agentReady = ($_vminfo.VMAgent.Statuses | Where-Object { $_.DisplayStatus -eq "Ready" }).Count -gt 0
                WriteRunLog -message "Boot validation: power=$_powerState, agentReady=$_agentReady, elapsed=${_bootElapsed}s"
            } while (($_powerState -ne "PowerState/running" -or -not $_agentReady) -and
                $_bootElapsed -lt $_bootTimeout)

            if ($_powerState -ne "PowerState/running" -or -not $_agentReady) {
                WriteRunLog -message "VM did not reach running and guest-agent-ready within ${_bootTimeout}s" -category "ERROR"
                WriteRunLog -message "Check boot diagnostics and serial console; revert to SCSI if INACCESSIBLE_BOOT_DEVICE is present" -category "IMPORTANT"
                exit 1
            }
            WriteRunLog -message "VM $VMName boot and guest agent verified"

            # First-time NVMe device installation can restore the inbox
            # IoTimeoutValue in CurrentControlSet. Reapply the Windows settings
            # after the first successful NVMe boot and verify them again so the
            # requested 240-second timeout persists on subsequent reboots.
            if ($_os -eq "Windows" -and $NewControllerType -eq "NVMe" -and
                $_controllerChangeRequired -and $FixOperatingSystemSettings) {
                WriteRunLog -message "Reapplying Windows NVMe settings after first NVMe boot"
                $RunCommandResult = Invoke-AzureOperation `
                    -Operation "Run post-boot Windows NVMe remediation" `
                    -ScriptBlock {
                        Invoke-AzVMRunCommand -ResourceGroupName $ResourceGroupName `
                            -VMName $VMName -CommandId 'RunPowerShellScript' `
                            -ScriptString ("`$SuppressNextSteps = `$true`n" + $Windows_Fix_Script) `
                            -ErrorAction Stop
                    }
                $postBootFixOutput = ($RunCommandResult.Value | ForEach-Object { $_.Message }) -join "`n"
                foreach ($line in ($postBootFixOutput -split "`n" | ForEach-Object { $_.Trim() } | Where-Object { $_ })) {
                    WriteRunLog -message ("   Post-boot fix: " + $line)
                }
                $postBootFixOK = ($postBootFixOutput -match 'All checks passed across ALL ControlSets') -and
                    ($postBootFixOutput -match 'Registry hive flushed to disk successfully|Registry flushed via individual ControlSet keys') -and
                    ($postBootFixOutput -notmatch '\[ERROR\]|FATAL:')
                if (-not $postBootFixOK) {
                    WriteRunLog -message "Post-boot Windows NVMe remediation failed" -category "ERROR"
                    exit 1
                }

                $RunCommandResult = Invoke-AzureOperation `
                    -Operation "Verify post-boot Windows NVMe remediation" `
                    -ScriptBlock {
                        Invoke-AzVMRunCommand -ResourceGroupName $ResourceGroupName `
                            -VMName $VMName -CommandId 'RunPowerShellScript' `
                            -ScriptString ("`$SuppressNextSteps = `$true`n" + $Check_Windows_Script) `
                            -ErrorAction Stop
                    }
                $postBootCheckOutput = ($RunCommandResult.Value | ForEach-Object { $_.Message }) -join "`n"
                if ($postBootCheckOutput -notmatch 'RESULT: READY' -or
                    $postBootCheckOutput -match '\[FAIL\]') {
                    WriteRunLog -message "Post-boot Windows NVMe verification failed" -category "ERROR"
                    exit 1
                }
                WriteRunLog -message "Post-boot Windows NVMe settings verified"

                WriteRunLog -message "Restarting VM to activate and persist post-boot Windows NVMe settings"
                Invoke-AzureOperation -Operation "Restart VM '$VMName'" -ScriptBlock {
                    Restart-AzVM -ResourceGroupName $ResourceGroupName `
                        -Name $VMName -ErrorAction Stop
                } | Out-Null
                $_bootElapsed = 0
                $_agentReady = $false
                do {
                    Start-Sleep -Seconds 15
                    $_bootElapsed += 15
                    $_vminfo = Invoke-AzureOperation `
                        -Operation "Check VM '$VMName' post-fix reboot status" `
                        -ScriptBlock {
                            Get-AzVM -ResourceGroupName $ResourceGroupName `
                                -Name $VMName -Status -ErrorAction Stop
                        }
                    $_powerState = ($_vminfo.Statuses | Where-Object { $_.Code -like 'PowerState*' }).Code
                    $_agentReady = ($_vminfo.VMAgent.Statuses |
                        Where-Object { $_.DisplayStatus -eq "Ready" }).Count -gt 0
                    WriteRunLog -message "Post-fix reboot validation: power=$_powerState, agentReady=$_agentReady, elapsed=${_bootElapsed}s"
                } while (($_powerState -ne "PowerState/running" -or -not $_agentReady) -and
                    $_bootElapsed -lt $_bootTimeout)

                if ($_powerState -ne "PowerState/running" -or -not $_agentReady) {
                    WriteRunLog -message "VM did not recover after the post-fix reboot" -category "ERROR"
                    exit 1
                }

                $RunCommandResult = Invoke-AzureOperation `
                    -Operation "Verify final Windows NVMe persistence" `
                    -ScriptBlock {
                        Invoke-AzVMRunCommand -ResourceGroupName $ResourceGroupName `
                            -VMName $VMName -CommandId 'RunPowerShellScript' `
                            -ScriptString ("`$SuppressNextSteps = `$true`n" + $Check_Windows_Script) `
                            -ErrorAction Stop
                    }
                $finalWindowsCheckOutput = ($RunCommandResult.Value | ForEach-Object { $_.Message }) -join "`n"
                if ($finalWindowsCheckOutput -notmatch 'RESULT: READY' -or
                    $finalWindowsCheckOutput -match '\[FAIL\]') {
                    WriteRunLog -message "Windows NVMe settings did not persist after the post-fix reboot" -category "ERROR"
                    exit 1
                }
                WriteRunLog -message "Post-fix reboot and Windows NVMe persistence verified"
            }
        }
        else {
            WriteRunLog -message "Error starting VM $VMName" -category "ERROR"
            Write-StartAllocationGuidance -FailureMessage "Start-AzVM returned status '$($_startvm.Status)'"
            exit 1
        }
    } catch {
        WriteRunLog -message "Error starting VM $VMName" -category "ERROR"
        Write-StartAllocationGuidance -FailureMessage $_.Exception.Message
        WriteRunLog $_.Exception.Message "ERROR"
        exit 1
    }
}
else {
    WriteRunLog -message "VM $VMName is converted and remains deallocated."

    if ($_os -eq "Windows" -and $NewControllerType -eq "NVMe" -and
        $_controllerChangeRequired -and $FixOperatingSystemSettings) {
        # First NVMe device installation can restore IoTimeoutValue=10 in the
        # active ControlSet. When the script does not start the VM, print a
        # self-contained post-first-boot remediation command for the operator.
        $_manualPostBootScript = '$sets=@(Get-ChildItem "HKLM:\SYSTEM"|Where-Object PSChildName -match "^ControlSet\d+$"|ForEach-Object PSChildName);foreach($cs in $sets){$p="HKLM:\SYSTEM\$cs\Services\stornvme\Parameters";New-Item -Path $p -Force|Out-Null;Set-ItemProperty -Path $p -Name IoTimeoutValue -Value 240 -Type DWord;Set-ItemProperty -Path $p -Name BusType -Value 17 -Type DWord;Set-ItemProperty -Path $p -Name StorageSupportedFeatures -Value 3 -Type DWord;$pi="$p\PnpInterface";New-Item -Path $pi -Force|Out-Null;Set-ItemProperty -Path $pi -Name 5 -Value 1 -Type DWord;$k=[Microsoft.Win32.Registry]::LocalMachine.OpenSubKey("SYSTEM\$cs\Services\stornvme\Parameters",$false);if($k){$k.Flush();$k.Close()}}'

        WriteRunLog -message "MANUAL START AND POST-BOOT REMEDIATION REQUIRED:" -category "IMPORTANT"
        WriteRunLog -message "1. Start the converted VM:" -category "IMPORTANT"
        WriteRunLog -message ('   Start-AzVM -ResourceGroupName "' + $ResourceGroupName +
            '" -Name "' + $VMName + '"') -category "IMPORTANT"
        WriteRunLog -message "2. Wait until the VM is running and the Azure VM Agent reports Ready." -category "IMPORTANT"
        WriteRunLog -message "3. Define the post-boot remediation script:" -category "IMPORTANT"
        WriteRunLog -message ('   $postBootScript = ''' + $_manualPostBootScript + '''') -category "IMPORTANT"
        WriteRunLog -message "4. Reapply and flush the NVMe driver parameters:" -category "IMPORTANT"
        WriteRunLog -message ('   Invoke-AzVMRunCommand -ResourceGroupName "' + $ResourceGroupName +
            '" -VMName "' + $VMName +
            '" -CommandId "RunPowerShellScript" -ScriptString $postBootScript') -category "IMPORTANT"
        WriteRunLog -message "5. Restart Windows so the post-boot settings become active:" -category "IMPORTANT"
        WriteRunLog -message ('   Restart-AzVM -ResourceGroupName "' + $ResourceGroupName +
            '" -Name "' + $VMName + '"') -category "IMPORTANT"
        WriteRunLog -message "6. Verify the VM Agent is Ready and the disks report BusType NVMe." -category "IMPORTANT"
        WriteRunLog -message "The remediation sets IoTimeoutValue=240, BusType=17, StorageSupportedFeatures=3, and PnpInterface\\5=1 in every ControlSet." -category "IMPORTANT"
    }
    else {
        WriteRunLog -message "Start the converted VM when ready:" -category "IMPORTANT"
        WriteRunLog -message ('   Start-AzVM -ResourceGroupName "' + $ResourceGroupName +
            '" -Name "' + $VMName + '"') -category "IMPORTANT"
    }
}

# Info for next steps
if ($StartVM) {
    WriteRunLog -message "As the virtual machine got started using the script you can check the operating system now"
}
else {
    WriteRunLog -message "The VM remains deallocated. Follow the manual start instructions printed above." -category "IMPORTANT"
}
if ($NewControllerType -eq "NVMe") {
    WriteRunLog -message "If you have any issues after the conversion you can revert the changes by running the script with the old settings"
    WriteRunLog -message "Here is the command to revert the changes:" -category "IMPORTANT"
    WriteRunLog -message "   .\Azure-NVMe-Conversion.ps1 -ResourceGroupName $ResourceGroupName -VMName $VMName -NewControllerType SCSI -VMSize $script:_original_vm_size -StartVM"
}

# Done
WriteRunLog -message "Script ended at $(Get-Date)"
WriteRunLog -message "Exiting"
