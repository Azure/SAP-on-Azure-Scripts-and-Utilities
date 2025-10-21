function Get-AzSAPVmPostProvisionCheck {
[CmdletBinding()]
param (
    [string]$ExportPath = "C:\tmp\SAPOnAzureChecks"
)

# -------------------- helpers --------------------
function New-StatusRow {
    param([string]$checkId,[string]$desc,[string]$info,[string]$actual,[string]$expected,[string]$status)
    $cls = switch ($status) { 'OK' {'status-OK'} 'REVIEW' {'status-REVIEW'} default {'status-ERROR'} }
    "<tr class='$cls'><td>$checkId</td><td>$desc</td><td>$info</td><td>$actual</td><td>$expected</td><td>$status</td></tr>`n"
}

function Test-InRange {
    param([string]$actual,[string]$expectedCsvOrRange)
    if (-not $actual -or -not $expectedCsvOrRange) { return 'REVIEW' }
    $a = [int]$actual
    if ($expectedCsvOrRange -match '^\s*\d+\s*-\s*\d+\s*$') {
        $lo,$hi = $expectedCsvOrRange -split '\s*-\s*'
        if ($a -ge [int]$lo -and $a -le [int]$hi) { 'OK' } else { 'REVIEW' }
    } else {
        $allowed = $expectedCsvOrRange -split ',\s*'
        if ($allowed -contains "$a") { 'OK' } else { 'REVIEW' }
    }
}

function Try-IMDS {
    try {
        Invoke-RestMethod -Headers @{Metadata='true'} -Method GET -TimeoutSec 3 `
            -Uri 'http://169.254.169.254/metadata/instance?api-version=2021-02-01'
    } catch { $null }
}

function Have-Command { param([string]$name) try { $null -ne (Get-Command $name -ErrorAction Stop) } catch { $false } }

function Invoke-SqlText {
    param([string]$query,[string]$instance = 'MSSQLSERVER')
    if (-not (Have-Command 'sqlcmd')) { return $null }
    $target = if ($instance -eq 'MSSQLSERVER') { '.' } else { ".\$instance" }
    try {
        ($(
            sqlcmd -S $target -Q $query -W -h -1 2>$null
        ) | Out-String).Trim()
    } catch { $null }
}

function Get-SqlInstances {
    $reg = "HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server\Instance Names\SQL"
    if (-not (Test-Path $reg)) { return @() }
    (Get-ItemProperty $reg).PSObject.Properties |
        Where-Object { $_.Name -notmatch '^PS' } |
        ForEach-Object { $_.Name }
}

function Get-PageFileMB {
    try {
        $usages = Get-CimInstance Win32_PageFileUsage
        if ($usages) { [int]($usages | Measure-Object -Property AllocatedBaseSize -Sum).Sum } else { 0 }
    } catch { 0 }
}

function Get-FirstInt { param([string]$text) try { $m=[regex]::Match("$text",'\d+'); if($m.Success){[int]$m.Value}else{$null} } catch { $null } }

function Get-SqlServiceName {
    param([string]$instance = 'MSSQLSERVER')
    if ($instance -eq 'MSSQLSERVER') { 'MSSQLSERVER' } else { "MSSQL`$$instance" }  # service name uses $
}

function Get-SqlServiceAccount {
    param([string]$instance = 'MSSQLSERVER')
    try {
        $svcName = Get-SqlServiceName -instance $instance
        (Get-CimInstance Win32_Service -Filter "Name='$svcName'").StartName
    } catch { $null }
}

function Get-AccountSid {
    param([string]$account)
    try { ([System.Security.Principal.NTAccount]$account).Translate([System.Security.Principal.SecurityIdentifier]).Value } catch { $null }
}

function Test-LocalAdminMembership {
    param([string]$account)
    try {
        $admins = Get-LocalGroupMember -Group 'Administrators' -ErrorAction Stop
        $admins | Where-Object { $_.Name -ieq $account } | ForEach-Object { $_ } | Measure-Object | Select-Object -ExpandProperty Count
        ($admins | Where-Object { $_.Name -ieq $account }).Count -gt 0
    } catch {
        $false
    }
}

function Get-IFIStatus {
    param([string]$instance = 'MSSQLSERVER')

    # 1) Try SQL DMV (newer versions)
    $ifiVal = $null
    try {
        $ifiVal = Get-FirstInt (Invoke-SqlText -instance $instance -query @"
SET NOCOUNT ON;
SELECT ISNULL(MAX(CAST(instant_file_initialization_enabled AS int)), -1)
FROM sys.dm_server_services
WHERE servicename LIKE 'SQL Server (%' OR servicename = 'SQL Server';
"@)
    } catch { $ifiVal = $null }

    if ($ifiVal -eq 1) { return 'Enabled' }
    if ($ifiVal -eq 0) { return 'Disabled' }

    # 2) Fallback: Local Security Policy -> SeManageVolumePrivilege
    $svcAcct = Get-SqlServiceAccount -instance $instance
    if (-not $svcAcct) { return 'Unknown' }

    $svcSid = Get-AccountSid -account $svcAcct

    $tmp = Join-Path $env:TEMP "secpol_$(Get-Random).inf"
    try {
        secedit /export /cfg $tmp /quiet | Out-Null
        $line = (Select-String -Path $tmp -Pattern '^SeManageVolumePrivilege\s*=\s*(.+)$' -ErrorAction SilentlyContinue).Matches.Value
    } catch { $line = $null }
    finally { if (Test-Path $tmp) { Remove-Item $tmp -Force -ErrorAction SilentlyContinue } }

    if (-not $line) { return 'Unknown' }

    # Extract SIDs on the right-hand side
    $sids = @()
    if ($line -match '=\s*(.+)$') {
        $rhs = $Matches[1]
        $sids = ($rhs -split ',') | ForEach-Object { $_.Trim().TrimStart('*') } | Where-Object { $_ }
    }

    $adminsSid = 'S-1-5-32-544'  # Built-in Administrators
    $isSvcExplicit = ($svcSid -and ($sids -contains $svcSid))
    $isAdminsPriv  = ($sids -contains $adminsSid)
    $svcIsAdmin    = if ($isAdminsPriv) { Test-LocalAdminMembership -account $svcAcct } else { $false }

    if ($isSvcExplicit -or $svcIsAdmin) { 'Enabled' }
    else { 'Disabled' }  # If DMV was unknown and neither explicit nor via Admins, treat as disabled
}

function Import-FailoverModule {
    try { Import-Module FailoverClusters -ErrorAction Stop | Out-Null; $true } catch { $false }
}

function Get-ClusterParamValue {
    param(
        [string]$Name
    )
    if (Import-FailoverModule) {
        try {
            $p = Get-ClusterParameter -Name $Name -ErrorAction SilentlyContinue
            if ($p) { return $p.Value }
        } catch {}
    }
    try {
        if (Test-Path 'HKLM:\Cluster') {
            return (Get-ItemProperty -Path 'HKLM:\Cluster' -ErrorAction Stop).$Name
        }
    } catch {}
    return $null
}

function Get-NetworkNameParam {
    param(
        [string]$Name
    )
    if (Import-FailoverModule) {
        try {
            $vals = Get-ClusterResource |
                Where-Object ResourceType -eq 'Network Name' |
                ForEach-Object {
                    Get-ClusterParameter -InputObject $_ -Name $Name -ErrorAction SilentlyContinue
                } | Where-Object { $_ } | Select-Object -ExpandProperty Value
            if ($vals -and $vals.Count -gt 0) { return $vals[0] }
        } catch {}
    }
    try {
        if (Test-Path 'HKLM:\Cluster') {
            return (Get-ItemProperty -Path 'HKLM:\Cluster' -ErrorAction Stop).$Name
        }
    } catch {}
    return $null
}

function Get-SqlInstanceRegBase {
    param([string]$Instance)
    $mapPath = "HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server\Instance Names\SQL"
    if (-not (Test-Path $mapPath)) { return $null }
    $instKey = (Get-ItemProperty -Path $mapPath).$Instance
    if (-not $instKey) { return $null }
    "HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server\$instKey\MSSQLServer"
}

function Get-SqlListeningPorts {
    param([string]$Instance = 'MSSQLSERVER')
    try {
        $svcName = if ($Instance -eq 'MSSQLSERVER') { 'MSSQLSERVER' } else { "MSSQL`$$Instance" }
        $svc     = Get-CimInstance Win32_Service -Filter "Name='$svcName'"
        if (-not $svc -or -not $svc.ProcessId) { return @() }
        # PS 5+ (preferred)
        $ports = @()
        try {
            $ports = (Get-NetTCPConnection -State Listen -OwningProcess $svc.ProcessId -ErrorAction Stop |
                     Select-Object -ExpandProperty LocalPort -Unique | Sort-Object) 2>$null
        } catch {
            # Fallback: netstat
            $ports = (netstat -ano | Select-String "LISTENING\s+$($svc.ProcessId)$" |
                      ForEach-Object { ($_ -split '\s+')[-2] } |
                      ForEach-Object { ($_ -split ':')[-1] } |
                      Where-Object { $_ -match '^\d+$' } | Sort-Object -Unique)
        }
        $ports
    } catch { @() }
}

function Get-SqlTcpConfig {
    param([string]$Instance = 'MSSQLSERVER')
    $regBase = Get-SqlInstanceRegBase -Instance $Instance
    $tcpRoot = if ($regBase) { Join-Path $regBase 'SuperSocketNetLib\Tcp' } else { $null }
    $ipAll   = if ($tcpRoot) { Join-Path $tcpRoot 'IPAll' } else { $null }

    $enabled = $null; $port = $null; $dyn  = $null

    try { $enabled = (Get-ItemProperty -Path $tcpRoot -ErrorAction Stop).Enabled } catch {}
    try { $port    = (Get-ItemProperty -Path $ipAll   -ErrorAction Stop).'TcpPort' } catch {}
    try { $dyn     = (Get-ItemProperty -Path $ipAll   -ErrorAction Stop).'TcpDynamicPorts' } catch {}

    [pscustomobject]@{
        Enabled         = $enabled      # 1/0/NULL
        IPAllPort       = if ($port) { "$port" } else { '' }
        IPAllDynPorts   = if ($dyn)  { "$dyn"  } else { '' }
        ListeningPorts  = (Get-SqlListeningPorts -Instance $Instance)
    }
}

function Get-SqlInstanceRegBase {
    param([string]$Instance)
    $mapPath = "HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server\Instance Names\SQL"
    if (-not (Test-Path $mapPath)) { return $null }
    $instKey = (Get-ItemProperty -Path $mapPath).$Instance
    if (-not $instKey) { return $null }
    "HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server\$instKey\MSSQLServer"
}

function Get-SqlListeningPorts {
    param([string]$Instance = 'MSSQLSERVER')
    try {
        $svcName = if ($Instance -eq 'MSSQLSERVER') { 'MSSQLSERVER' } else { "MSSQL`$$Instance" }
        $svc     = Get-CimInstance Win32_Service -Filter "Name='$svcName'"
        if (-not $svc -or -not $svc.ProcessId) { return @() }

        try {
            (Get-NetTCPConnection -State Listen -OwningProcess $svc.ProcessId -ErrorAction Stop |
             Select-Object -ExpandProperty LocalPort -Unique | Sort-Object)
        } catch {
            (netstat -ano | Select-String "LISTENING\s+$($svc.ProcessId)$" |
             ForEach-Object { ($_ -split '\s+')[-2] } |
             ForEach-Object { ($_ -split ':')[-1] } |
             Where-Object { $_ -match '^\d+$' } | Sort-Object -Unique)
        }
    } catch { @() }
}

function Get-SqlTcpConfig {
    param([string]$Instance = 'MSSQLSERVER')
    $regBase = Get-SqlInstanceRegBase -Instance $Instance
    $tcpRoot = if ($regBase) { Join-Path $regBase 'SuperSocketNetLib\Tcp' } else { $null }
    $ipAll   = if ($tcpRoot) { Join-Path $tcpRoot 'IPAll' } else { $null }

    $enabled = $null; $port = $null; $dyn  = $null
    try { $enabled = (Get-ItemProperty -Path $tcpRoot -ErrorAction Stop).Enabled } catch {}
    try { $port    = (Get-ItemProperty -Path $ipAll   -ErrorAction Stop).'TcpPort' } catch {}
    try { $dyn     = (Get-ItemProperty -Path $ipAll   -ErrorAction Stop).'TcpDynamicPorts' } catch {}

    [pscustomobject]@{
        Enabled         = $enabled
        IPAllPort       = if ($port) { "$port" } else { '' }
        IPAllDynPorts   = if ($dyn)  { "$dyn"  } else { '' }
        ListeningPorts  = (Get-SqlListeningPorts -Instance $Instance)
    }
}


# -------------------- header/paths --------------------
$hostname = $env:COMPUTERNAME.ToUpper()
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$baseName = "${hostname}_SAP_VM_PostProvisioning_Report_${timestamp}"
$htmlPath = Join-Path $ExportPath "$baseName.html"
$jsonPath = Join-Path $ExportPath "$baseName.json"
if (-not (Test-Path $ExportPath)) { New-Item -Path $ExportPath -ItemType Directory -Force | Out-Null }

$htmlHeader = @"
<html><head><title>SAP on Azure VM Post Provisioning Report</title>
<style>
body { font-family: Arial; padding: 20px; }
table { border-collapse: collapse; width: 100%; margin-bottom: 30px; }
th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
th { background-color: #cce5ff; }
.status-OK { background-color: #d4edda; }
.status-ERROR { background-color: #f8d7da; }
.status-REVIEW { background-color: #fff3cd; }
.section { margin-top: 20px; }
small.muted { color: #666; }
</style></head><body>
<h1>SAP on Azure Post-Provisioning Report for $hostname</h1>
"@

# -------------------- 1. OS & Platform --------------------
$osInfo  = Get-CimInstance Win32_OperatingSystem
$csInfo  = Get-CimInstance Win32_ComputerSystem
$tzInfo  = Get-TimeZone
$domain  = if ($csInfo.PartOfDomain) { $csInfo.Domain } else { "Not Joined" }
$execUser= [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
$execTime= Get-Date -Format "yyyy-MM-dd HH:mm:ss"

try {
    $latestKB = Get-HotFix | Sort-Object InstalledOn -Descending | Select-Object -First 1
    $kbInfo   = if ($latestKB) { "$($latestKB.HotFixID) (InstalledOn: $($latestKB.InstalledOn.ToString('yyyy-MM-dd')))" } else { "Not Available" }
} catch { $kbInfo = "Not Available" }

$osDetails = @"
<div class="section">
<h2>1. OS &amp; Platform Details</h2>
<table>
<tr><th>Check</th><th>Value</th></tr>
<tr><td>Hostname</td><td>$hostname</td></tr>
<tr><td>OS</td><td>$($osInfo.Caption)</td></tr>
<tr><td>OS Version</td><td>$($osInfo.Version)</td></tr>
<tr><td>OS Edition</td><td>$($osInfo.OperatingSystemSKU)</td></tr>
<tr><td>Domain Joined</td><td>$($csInfo.PartOfDomain)</td></tr>
<tr><td>Domain Name</td><td>$domain</td></tr>
<tr><td>Timezone</td><td>$($tzInfo.DisplayName)</td></tr>
<tr><td>Executed By</td><td>$execUser</td></tr>
<tr><td>Execution Date</td><td>$execTime</td></tr>
<tr><td>Latest KB Applied</td><td>$kbInfo</td></tr>
</table>
</div>
"@

# -------------------- 2. Additional & Network --------------------
try { $wuauserv = (Get-Service -Name wuauserv -ErrorAction Stop).Status } catch { $wuauserv = "Not Found" }
$firewalls=@{}
foreach($p in @('Domain','Private','Public')){ try{ $firewalls[$p]=(Get-NetFirewallProfile -Name $p).Enabled }catch{ $firewalls[$p]='Unknown' } }
$pageMB  = Get-PageFileMB
try{ $ipcfg=Get-NetIPConfiguration | Where-Object { $_.IPv4DefaultGateway -ne $null } | Select-Object -First 1 }catch{ $ipcfg=$null }
$gateway = if ($ipcfg) { $ipcfg.IPv4DefaultGateway.NextHop } else { 'Unknown' }
$dnsList = Get-DnsClientServerAddress -AddressFamily IPv4 2>$null |
           Select-Object -ExpandProperty ServerAddresses -ErrorAction SilentlyContinue |
           Select-Object -Unique
$dnsDisplay = if ($dnsList) { ($dnsList -join ', ') } else { 'Unknown' }
$activeNic = (Get-NetAdapter | Where-Object Status -eq 'Up' | Select-Object -First 1).Name

$netInfo = @"
<div class="section">
<h2>2. Additional Configuration &amp; Network Checks</h2>
<table>
<tr><th>Check</th><th>Value</th></tr>
<tr><td>Windows Update Service</td><td>$wuauserv</td></tr>
<tr><td>Page File</td><td>$pageMB MB</td></tr>
<tr><td>Default Gateway</td><td>$gateway</td></tr>
<tr><td>DNS Servers</td><td>$dnsDisplay</td></tr>
<tr><td>Active IPv4 Interface</td><td>$activeNic</td></tr>
<tr><td>Firewall (Domain)</td><td>$($firewalls['Domain'])</td></tr>
<tr><td>Firewall (Private)</td><td>$($firewalls['Private'])</td></tr>
<tr><td>Firewall (Public)</td><td>$($firewalls['Public'])</td></tr>
</table>
</div>
"@

# -------------------- 3. SAP VM Configuration --------------------
# Make sure the module is available once
try { Import-Module FailoverClusters -ErrorAction SilentlyContinue } catch {}
# -------------------- 3. SAP VM Configuration --------------------
$sapChecks = @(
  @{ CHECKID="VM-0003"; DESCRIPTION="Windows Activation"; EXPECTED="Activated"; ADDITIONALINFO="SoftwareLicensingProduct"; SCRIPT = {
      try {
        $act = Get-CimInstance SoftwareLicensingProduct | Where-Object { $_.PartialProductKey } | Select-Object -First 1
        if ($act -and $act.LicenseStatus -eq 1) { "Activated" } else { "Not Activated" }
      } catch { "Unknown" }
  } },
  @{ CHECKID="CL-QUORUM-001"; DESCRIPTION="Cluster Quorum Resource"; EXPECTED="Cloud Witness"; ADDITIONALINFO="Get-ClusterQuorum"; SCRIPT = {
      try {
        $q = (Get-ClusterQuorum -ErrorAction Stop).QuorumResource
        if ($q) { "$q" } else { "None" }
      } catch { "None" }
  } },

  @{ CHECKID="DB-HA-WIN-003"; DESCRIPTION="SameSubnetDelay (ms)"; EXPECTED="1000-2000"; ADDITIONALINFO="Cluster parameter";
   SCRIPT = { try { $v = Get-ClusterParamValue -Name 'SameSubnetDelay'; if ($null -ne $v) {[int]$v} else {'Not Set'} } catch {'Not Set'} } },

@{ CHECKID="DB-HA-WIN-004"; DESCRIPTION="SameSubnetThreshold"; EXPECTED="20-40"; ADDITIONALINFO="Cluster parameter";
   SCRIPT = { try { $v = Get-ClusterParamValue -Name 'SameSubnetThreshold'; if ($null -ne $v) {[int]$v} else {'Not Set'} } catch {'Not Set'} } },

@{ CHECKID="DB-HA-WIN-001"; DESCRIPTION="CrossSubnetDelay (ms)"; EXPECTED="1000-4000"; ADDITIONALINFO="Cluster parameter";
   SCRIPT = { try { $v = Get-ClusterParamValue -Name 'CrossSubnetDelay'; if ($null -ne $v) {[int]$v} else {'Not Set'} } catch {'Not Set'} } },

@{ CHECKID="DB-HA-WIN-002"; DESCRIPTION="CrossSubnetThreshold"; EXPECTED="20-30"; ADDITIONALINFO="Cluster parameter";
   SCRIPT = { try { $v = Get-ClusterParamValue -Name 'CrossSubnetThreshold'; if ($null -ne $v) {[int]$v} else {'Not Set'} } catch {'Not Set'} } },

@{ CHECKID="DB-HA-WIN-006"; DESCRIPTION="HostRecordTTL (s)"; EXPECTED="300"; ADDITIONALINFO="Network Name resource parameter";
   SCRIPT = { try { $v = Get-NetworkNameParam -Name 'HostRecordTTL'; if ($null -ne $v) {[int]$v} else {'Not Set'} } catch {'Not Set'} } },

@{ CHECKID="DB-HA-WIN-007"; DESCRIPTION="RegisterAllProvidersIP"; EXPECTED="0"; ADDITIONALINFO="Network Name resource parameter";
   SCRIPT = { try { $v = Get-NetworkNameParam -Name 'RegisterAllProvidersIP'; if ($null -ne $v) {[int]$v} else {'Not Set'} } catch {'Not Set'} } }
)

$sapTableRows=""
foreach($c in $sapChecks){
  $actual=$null; try{$actual=& $c.SCRIPT}catch{$actual=$null}
  $status='REVIEW'
  if($c.CHECKID -eq 'CL-QUORUM-001'){
    if("$actual" -match 'cloud witness'){ $status='OK' } elseif("$actual" -eq 'None'){ $status='REVIEW' } else { $status='REVIEW' }
  } elseif($actual -ne $null -and $c.EXPECTED){
    if($c.EXPECTED -match '^\d+(-\d+)?(,\s*\d+)*$'){ $status=Test-InRange -actual "$actual" -expectedCsvOrRange $c.EXPECTED }
    else{ $status = if("$actual" -eq "$($c.EXPECTED)"){'OK'}else{'REVIEW'} }
  } else { $status='ERROR' }
  $sapTableRows += New-StatusRow $c.CHECKID $c.DESCRIPTION $c.ADDITIONALINFO "$actual" $c.EXPECTED $status
}

$sapSectionHtml = @"
<div class='section'>
<h2>3. SAP VM Configuration Checks</h2>
<table>
<tr><th>CHECKID</th><th>DESCRIPTION</th><th>ADDITIONALINFO</th><th>TESTRESULT</th><th>EXPECTEDRESULT</th><th>STATUS</th></tr>
$sapTableRows
</table>
</div>
"@

# -------------------- 4. SAP SQL Server Compatibility Checks --------------------
$sqlSAPChecks=""; $sqlSAPJson=@{}; $sqlRows=""
$instances=Get-SqlInstances; if(-not $instances){ $instances=@('MSSQLSERVER') }

foreach($inst in $instances){
  $instLabel = if($inst -eq 'MSSQLSERVER'){'Default'}else{$inst}

  $coll = Invoke-SqlText "SET NOCOUNT ON; SELECT SERVERPROPERTY('Collation')" $inst
  $normColl = ($coll -replace '\s*\(.*?\)','').Trim()

 $authModeRaw = Invoke-SqlText "SET NOCOUNT ON; DECLARE @a INT; EXEC xp_instance_regread N'HKEY_LOCAL_MACHINE', N'Software\Microsoft\MSSQLServer\MSSQLServer', N'LoginMode', @a OUTPUT; SELECT @a" $inst
$auth = 'Unknown'
if ($authModeRaw) {
    switch ($authModeRaw.Trim()) {
        '1' { $auth = 'Windows Authentication' }
        '2' { $auth = 'SQL & Windows Authentication' }
    }
}

  # MAXDOP (value_in_use)
  $maxdop = Get-FirstInt (Invoke-SqlText -query "SET NOCOUNT ON; SELECT CAST(value_in_use AS int) FROM sys.configurations WHERE name = 'max degree of parallelism'" -instance $inst)

  # CPU Affinity (value_in_use)
  $aff = Get-FirstInt (Invoke-SqlText -query "SET NOCOUNT ON; SELECT CAST(value_in_use AS int) FROM sys.configurations WHERE name = 'affinity mask'" -instance $inst)
  $affStatus = if ($aff -eq 0 -and $aff -ne $null) { 'Default (0)' } elseif ($aff -ne $null) { 'Configured' } else { 'Unknown' }

# Instant File Initialization (DMV first, fallback to local security policy)
$ifiStatus = Get-IFIStatus -instance $inst

  # --- CU / Build / Edition ---
  $prodRaw = Invoke-SqlText -instance $inst -query @"
SET NOCOUNT ON;
SELECT CONCAT(
  ISNULL(CAST(SERVERPROPERTY('ProductVersion') AS nvarchar(128)),''),
  '|',ISNULL(CAST(SERVERPROPERTY('ProductLevel') AS nvarchar(128)),''),
  '|',ISNULL(CAST(SERVERPROPERTY('ProductUpdateLevel') AS nvarchar(128)),''),
  '|',ISNULL(CAST(SERVERPROPERTY('ProductUpdateReference') AS nvarchar(128)),''),
  '|',ISNULL(CAST(SERVERPROPERTY('Edition') AS nvarchar(128)),'')
);
"@

  $prodVersion = $null; $prodLevel = $null; $prodUpdateLevel = $null; $prodUpdateRef = $null; $prodEdition = $null
  if ($prodRaw) {
    $parts = $prodRaw -split '\|', 5
    if ($parts.Count -ge 5) {
      $prodVersion     = $parts[0]
      $prodLevel       = $parts[1]   # RTM / SPn (older branches)
      $prodUpdateLevel = $parts[2]   # e.g., CU14
      $prodUpdateRef   = $parts[3]   # e.g., KB5029376
      $prodEdition     = $parts[4]
    }
  }

  $cuDisplay = if ($prodUpdateLevel) {
                  if ($prodUpdateRef) { "$prodUpdateLevel ($prodUpdateRef)" } else { $prodUpdateLevel }
               } elseif ($prodLevel) {
                  $prodLevel
               } else { 'Unknown' }

  $hasCU = [bool]$prodUpdateLevel

  # DB Compression (server-wide)
  $qComp = @"
SET NOCOUNT ON;
DECLARE @sql nvarchar(max) = N'';
SELECT @sql = COALESCE(@sql + N' UNION ALL ', N'') +
    N'SELECT COUNT(*) AS c FROM ' + QUOTENAME(name) + N'.sys.partitions p
      INNER JOIN ' + QUOTENAME(name) + N'.sys.tables t ON p.object_id = t.object_id
      WHERE p.data_compression > 0'
FROM sys.databases
WHERE database_id > 4 AND state = 0;

IF @sql = N'' SELECT 0 AS TotalCompressed;
ELSE BEGIN
    SET @sql = N'SELECT SUM(c) AS TotalCompressed FROM (' + @sql + N') s';
    EXEC (@sql);
END
"@
  $compCount = Get-FirstInt (Invoke-SqlText -query $qComp -instance $inst)
  $compStatus = if ($compCount -gt 0) { 'Enabled (some objects)' } elseif ($compCount -ne $null) { 'Disabled' } else { 'Unknown' }

  
  # --- Ensure LPIM and TCP variables are computed before rendering rows ---
  $lpimKb = Get-FirstInt (Invoke-SqlText -query "SET NOCOUNT ON; SELECT locked_page_allocations_kb FROM sys.dm_os_process_memory" -instance $inst)
  $lpimStatus = if ($lpimKb -gt 0) { 'Enabled (in use)' } elseif ($lpimKb -ne $null) { 'Disabled' } else { 'Unknown' }

  $tcp = Get-SqlTcpConfig -Instance $inst
  $ipAllPort = if ($tcp.IPAllPort) { $tcp.IPAllPort } elseif ($tcp.IPAllDynPorts) { "(dynamic: $($tcp.IPAllDynPorts))" } else { '(not set)' }
  $lst = if ($tcp.ListeningPorts -and $tcp.ListeningPorts.Count) { ($tcp.ListeningPorts -join ', ') } else { '(none/unknown)' }

$sqlRows += "<tr><td>$instLabel</td><td>SQL Server Collation</td><td>$coll</td><td>SQL_Latin1_General_CP850_BIN2</td><td>$([bool]($normColl -eq 'SQL_Latin1_General_CP850_BIN2'))</td></tr>"
  $sqlRows += "<tr><td>$instLabel</td><td>Authentication Mode</td><td>$auth</td><td>Windows Authentication</td><td>$([bool]($auth -eq 'Windows Authentication'))</td></tr>"
  $sqlRows += "<tr><td>$instLabel</td><td>Instant File Initialization</td><td>$ifiStatus</td><td>Enabled</td><td>$([bool]($ifiStatus -eq 'Enabled'))</td></tr>"
  $sqlRows += "<tr><td>$instLabel</td><td>Lock Pages in Memory</td><td>$lpimStatus</td><td>Enabled</td><td>$([bool]($lpimStatus -like 'Enabled*'))</td></tr>"
  $sqlRows += "<tr><td>$instLabel</td><td>MAXDOP</td><td>$maxdop</td><td>1 (SAP OLTP)</td><td>$([bool]($maxdop -eq 1))</td></tr>"
  $sqlRows += "<tr><td>$instLabel</td><td>CPU Affinity</td><td>$affStatus</td><td>Default (0)</td><td>$([bool]($aff -eq 0))</td></tr>"
  $sqlRows += "<tr><td>$instLabel</td><td>DB Compression</td><td>$compStatus</td><td>Row compression recommended</td><td>$([bool]($compStatus -like 'Enabled*'))</td></tr>"
$sqlRows += "<tr><td>$instLabel</td><td>TCP Port (configured IPAll)</td><td>$ipAllPort</td><td>Static port preferred</td><td>$([bool]($ipAllPort -match '^\d+$'))</td></tr>"
$sqlRows += "<tr><td>$instLabel</td><td>Listening Ports (runtime)</td><td>$lst</td><td>Matches configured</td><td>$([bool]($lst -match $ipAllPort))</td></tr>"

  # (moved LPIM/TCP computation earlier)


  $sqlSAPJson[$instLabel] = @{
    Collation=$normColl; CollationCompliant=($normColl -eq 'SQL_Latin1_General_CP850_BIN2')
    AuthenticationMode=$auth; AuthModeCompliant=($auth -eq 'Windows Authentication')
    IFI=$ifiStatus; IFICompliant=($ifiStatus -eq 'Enabled')
    LPIM=$lpimStatus; LPIMCompliant=($lpimStatus -like 'Enabled*'); LPIMkb=$lpimKb
    MaxDOP=$maxdop; MaxDOPCompliant=($maxdop -eq 1)
    CPUAffinity=$affStatus; CPUAffinityCompliant=($aff -eq 0)
    DBCompression=$compStatus; DBCompressionCompliant=($compStatus -like 'Enabled*'); CompressedObjectsCount=$compCount;
    ProductVersion = $prodVersion;
    ProductLevel   = $prodLevel;
    CULevel        = $prodUpdateLevel;
    CUKB           = $prodUpdateRef;
    Edition        = $prodEdition;
    HasCU          = $hasCU;
    TcpIPAllPort      = $tcp.IPAllPort;
    TcpIPAllDynPorts  = $tcp.IPAllDynPorts;
    TcpListeningPorts = @($tcp.ListeningPorts);

  }
}

if (-not $sqlRows) {
    $sqlSAPChecks = "<div class='section'><h2>4. SAP SQL Server Compatibility Checks</h2><div class='error'><small class='muted'>sqlcmd not found or SQL unreachable — skipped detailed SQL checks.</small></div></div>"
}
else {
$sqlSAPChecks = @"
<div class='section'>
<h2>4. SAP SQL Server Compatibility Checks</h2>
<table>
<tr><th>Instance</th><th>Check</th><th>Result</th><th>Expected</th><th>Compliant</th></tr>
$sqlRows
</table>
<small class='muted'>Note: MAXDOP=1 recommended for SAP OLTP; BW/analytics may differ.</small>
</div>
"@
}

# -------------------- 5. Cluster & SQL Services --------------------
$clusterHtml = @"
<div class='section'>
<h2>5. Cluster &amp; SQL Server Status</h2>
<table>
<tr><th>Component</th><th>Status</th></tr>
"@
try{
  $cluInstalled=(Get-WindowsFeature -Name Failover-Clustering -ErrorAction Stop).InstallState -eq 'Installed'
  $clusterHtml += "<tr><td>Failover Cluster Feature Installed</td><td>$cluInstalled</td></tr>"
  if($cluInstalled){
    try{ $null = Import-Module FailoverClusters -ErrorAction SilentlyContinue }catch{}
    try{ $cluster=Get-Cluster -ErrorAction Stop; $clusterActive=$true }catch{ $clusterActive=$false }
    $clusterHtml += "<tr><td>Failover Cluster Active</td><td>$clusterActive</td></tr>"
    if($clusterActive){
      $qres=(Get-ClusterQuorum).QuorumResource
      $clusterHtml += "<tr><td>Cluster Quorum Resource</td><td>$qres</td></tr>"
      $nodes = Get-ClusterNode | ForEach-Object { "$($_.Name) - $($_.State)" }
      foreach($n in $nodes){ $clusterHtml += "<tr><td colspan='2'>$n</td></tr>" }
    }
  }
}catch{ $clusterHtml += "<tr><td colspan='2'>Error retrieving cluster info</td></tr>" }
$clusterHtml += "<tr><td colspan='2'><strong>SQL Server Services</strong></td></tr>"
try{
  $sqlServices = Get-CimInstance Win32_Service | Where-Object { $_.Name -like "MSSQL$*" -or $_.Name -eq "MSSQLSERVER" }
  if($sqlServices){
    $clusterHtml += "<tr><th>Instance</th><th>State / Path</th></tr>"
    foreach($svc in $sqlServices){
      $instance = if($svc.Name -eq "MSSQLSERVER"){"Default"}else{$svc.Name -replace "MSSQL\$",""}
      $clusterHtml += "<tr><td>$instance</td><td>$($svc.State) — $($svc.PathName)</td></tr>"
    }
  }else{ $clusterHtml += "<tr><td colspan='2'>No running SQL Server services found</td></tr>" }
}catch{ $clusterHtml += "<tr><td colspan='2'>Error retrieving SQL Server services</td></tr>" }
$clusterHtml += "</table></div>"

# -------------------- 6. SQL instance config --------------------
$sqlCheckRows = "<tr><td colspan='2'><i>Note: Collation/Auth/LPIM/IFI are in Section 4.</i></td></tr>`n"
try{
  $sqlRegPath="HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server\Instance Names\SQL"
  if(Test-Path $sqlRegPath){
    $sqlInstanceMap=Get-ItemProperty -Path $sqlRegPath
    $sqlInstances = $sqlInstanceMap.PSObject.Properties | Where-Object { $_.Name -notmatch '^PS' } | ForEach-Object { $_.Name }
    foreach($inst in $sqlInstances){
      try{
        $instKey = $sqlInstanceMap.$inst
        $regBase = "HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server\$instKey\MSSQLServer"
        $sqlCheckRows += "<tr><td>Instance Name</td><td>$inst</td></tr>`n"

        # Max Server Memory (try both registry names, then T-SQL fallback)
        $maxMem = (Get-ItemProperty -Path $regBase -ErrorAction SilentlyContinue)."Max Server Memory (MB)"
        if (-not $maxMem) { $maxMem = (Get-ItemProperty -Path $regBase -ErrorAction SilentlyContinue)."MaxServerMemory" }
        if (-not $maxMem) {
            $maxMemT = Get-FirstInt (Invoke-SqlText -query "SET NOCOUNT ON; SELECT CAST(value_in_use AS int) FROM sys.configurations WHERE name='max server memory (MB)'" -instance $inst)
            if ($maxMemT -ne $null) { $maxMem = $maxMemT }
        }
        $maxMemText = if ([string]::IsNullOrEmpty("$maxMem")) { 'Not Configured' } else { "$maxMem" }
        $sqlCheckRows += "<tr><td>Max Server Memory (MB)</td><td>$maxMemText</td></tr>`n"

# TCP/IP Enabled + configured ports (IPAll) + actually listening ports
$tcp = Get-SqlTcpConfig -Instance $inst
$tcp = Get-SqlTcpConfig -Instance $inst
$ipAllPort = if ($tcp.IPAllPort) { $tcp.IPAllPort } elseif ($tcp.IPAllDynPorts) { "(dynamic: $($tcp.IPAllDynPorts))" } else { '(not set)' }
$lst = if ($tcp.ListeningPorts -and $tcp.ListeningPorts.Count) { ($tcp.ListeningPorts -join ', ') } else { '(none/unknown)' }

$tcpStatus  = switch ($tcp.Enabled) { 1 {"Enabled"} 0 {"Disabled"} default {"Unknown"} }
$sqlCheckRows += "<tr><td>TCP/IP Enabled</td><td>$tcpStatus</td></tr>`n"

$ipAllPort = if ($tcp.IPAllPort) { $tcp.IPAllPort } else { '(not set)' }
$ipAllDyn  = if ($tcp.IPAllDynPorts) { $tcp.IPAllDynPorts } else { '(not set)' }
$sqlCheckRows += "<tr><td>TCP/IP Port (IPAll)</td><td>$ipAllPort</td></tr>`n"
$sqlCheckRows += "<tr><td>TCP/IP Dynamic Ports (IPAll)</td><td>$ipAllDyn</td></tr>`n"

$lst = if ($tcp.ListeningPorts -and $tcp.ListeningPorts.Count) { ($tcp.ListeningPorts -join ', ') } else { '(none/unknown)' }
$sqlCheckRows += "<tr><td>Currently Listening Ports</td><td>$lst</td></tr>`n"


        # Trace flags
        $traceParamsPath = "$regBase\Parameters"
        $traceFlagsDisplay = "None"
        if (Test-Path $traceParamsPath) {
            $traceFlags = (Get-ItemProperty -Path $traceParamsPath).PSObject.Properties |
                Where-Object { $_.Name -like "SQLArg*" } | ForEach-Object { $_.Value }
            if ($traceFlags -and $traceFlags.Count -gt 0) { $traceFlagsDisplay = ($traceFlags -join ", ") }
        }
        $sqlCheckRows += "<tr><td>Trace Flags (Startup)</td><td>$traceFlagsDisplay</td></tr>`n"

        # Collation (show here as well)
        $coll6 = Invoke-SqlText -query "SET NOCOUNT ON; SELECT SERVERPROPERTY('Collation')" -instance $inst
        $sqlCheckRows += "<tr><td>SQL Server Collation</td><td>$coll6</td></tr>`n"
      }catch{ $sqlCheckRows += "<tr><td colspan='2'>Error reading instance [$inst]</td></tr>`n" }
    }
  }else{ $sqlCheckRows += "<tr><td colspan='2'>SQL Server not installed or registry access failed.</td></tr>`n" }
}catch{ $sqlCheckRows += "<tr><td colspan='2'>Error reading SQL registry.</td></tr>`n" }

$sqlHtmlSection = @"
<div class='section'>
<h2>6. SQL Server Configuration Checks (Registry/WMI)</h2>
<table>
<tr><th>Check</th><th>Value</th></tr>
$sqlCheckRows
</table>
</div>
"@

# -------------------- 7. Data Disk Block Size --------------------
$diskRows=""; $diskJson=@()
try{
  # Include fixed volumes whether or not they have a drive letter
  $volumes = Get-Volume | Where-Object { $_.DriveType -eq 'Fixed' }
  $cims    = Get-CimInstance Win32_Volume   # cache once

  foreach($vol in $volumes){
    $display     = if ($vol.DriveLetter) { "$($vol.DriveLetter):\" } else { $vol.Path }
    $queryPath   = if ($vol.DriveLetter) { "$($vol.DriveLetter):\" } else { $vol.Path }
    $driveLetter = $vol.DriveLetter
    $label       = $vol.FileSystemLabel
    $fs          = $vol.FileSystem

    # Expectations only for NTFS
    $expected = if ($fs -eq 'NTFS') {
        if ($vol.DriveLetter -and ($vol.DriveLetter -in @('C','D'))) { 4096 } else { 65536 }
    } else { $null }

    # Determine bytes/cluster (prefer CIM/AllocationUnitSize, fall back to fsutil)
    $block = $null
    try { $block = ($cims | Where-Object DeviceID -eq $queryPath | Select-Object -First 1).BlockSize } catch {}
    if (-not $block) { try { if ($vol.AllocationUnitSize) { $block = $vol.AllocationUnitSize } } catch {} }
    if (-not $block) {
      try{
        $fsutilOut = fsutil fsinfo ntfsinfo $queryPath 2>$null
        foreach($line in $fsutilOut){ if($line -match 'Bytes Per Cluster\s*:\s*(\d+)'){ $block=$matches[1]; break } }
      }catch{}
    }
    if (-not $block) { $block='Unknown' }

    $status = if( -not $expected -or "$block" -eq "$expected"){'OK'}else{'REVIEW'}
    $cls    = if($status -eq 'OK'){'status-OK'}else{'status-REVIEW'}

    $diskRows += "<tr class='$cls'><td>$display</td><td>$driveLetter</td><td>$label</td><td>$fs</td><td>$block</td><td>$expected</td><td>$status</td></tr>`n"
    $diskJson += @{
      Volume       = $display
      DriveLetter  = $driveLetter
      Label        = $label
      FileSystem   = $fs
      ClusterBytes = $block
      Expected     = $expected
      Status       = $status
    }
  }
}catch{
  $diskRows += "<tr class='status-ERROR'><td colspan='7'>Error retrieving disk info: $($_.Exception.Message)</td></tr>"
}

$diskCheckSection = @"
<div class='section'>
<h2>7. Data Disk Block Size Checks</h2>
<table>
<tr><th>Drive/Volume</th><th>DriveLetter</th><th>Label</th><th>FileSystem</th><th>Actual Bytes/Cluster</th><th>Expected</th><th>Status</th></tr>
$diskRows
</table>
</div>
"@

# -------------------- 8. AV & Filter Drivers --------------------
$avRows=""; $avJson=@(); $filterRows=""
$filterDrivers = Get-WmiObject Win32_SystemDriver |
    Where-Object {
        $_.State -eq 'Running' -and (
            $_.PathName -match '\\FileSystem\\' -or
            $_.Name -like '*filter*' -or
            $_.DisplayName -match 'Defender|Symantec|McAfee|Sophos|Trend|CrowdStrike|Sentinel|Bitdefender|Kaspersky'
        )
    }
try{
  $avProducts = Get-CimInstance -Namespace "root/SecurityCenter2" -ClassName AntivirusProduct -ErrorAction Stop
  if($avProducts.Count -eq 0){
    if($filterDrivers | Where-Object { $_.Name -eq 'WdFilter' }){
      $avRows += "<tr class='status-OK'><td>Microsoft Defender AV (inferred)</td><td>N/A</td><td>OK</td></tr>`n"
      $avJson += @{ Product='Microsoft Defender (inferred)'; State='N/A'; Status='OK' }
    }else{
      $avRows += "<tr class='status-ERROR'><td colspan='3'>No antivirus product detected or reported</td></tr>`n"
    }
  }else{
    foreach($av in $avProducts){
      $displayName=$av.displayName
      $productState=[Convert]::ToString($av.productState,16)
      $status = if($productState -match '^10'){'OK'}else{'REVIEW'}
      $cls = if($status -eq 'OK'){'status-OK'}else{'status-REVIEW'}
      $avRows += "<tr class='$cls'><td>$displayName</td><td>$productState</td><td>$status</td></tr>`n"
      $avJson += @{ Product=$displayName; StateHex=$productState; Status=$status }
    }
  }
}catch{
  if($filterDrivers | Where-Object { $_.Name -eq 'WdFilter' }){
    $avRows += "<tr class='status-OK'><td>Microsoft Defender AV (inferred via WdFilter)</td><td>N/A</td><td>OK</td></tr>`n"
    $avJson += @{ Product='Microsoft Defender (inferred)'; State='N/A'; Status='OK' }
  }else{
    $avRows += "<tr class='status-ERROR'><td colspan='3'>AV info not available (likely Server Core)</td></tr>`n"
  }
}
foreach($fd in $filterDrivers){ $filterRows += "<tr><td>$($fd.Name)</td><td>$($fd.DisplayName)</td><td>$($fd.State)</td></tr>`n" }
if(-not $filterRows){ $filterRows = "<tr class='status-ERROR'><td colspan='3'>No active AV-related filter drivers detected</td></tr>" }

$avCheckSection = @"
<div class='section'>
<h2>8. Antivirus &amp; Filter Driver Status</h2>
<table>
<tr><th>Antivirus Product</th><th>Product State (Hex)</th><th>Status</th></tr>
$avRows
</table>
<br/>
<table>
<tr><th>Filter Driver</th><th>Display Name</th><th>Status</th></tr>
$filterRows
</table>
</div>
"@

# -------------------- 9. Network tuning & NIC offloads --------------------
$networkTable=""; $netJson=@()
try{
  try{ $maxPort   = Get-ItemPropertyValue -Path "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters"  -Name "MaxUserPort" }catch{ $maxPort="Not Set" }
  try{ $waitDelay = Get-ItemPropertyValue -Path "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters"  -Name "TcpTimedWaitDelay" }catch{ $waitDelay="Not Set" }
  try{
    $ipv6Disabled = Get-ItemPropertyValue -Path "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip6\Parameters" -Name "DisabledComponents"
    $ipv6Status   = if($ipv6Disabled -eq 255){'Disabled'}else{'Enabled'}
  }catch{ $ipv6Status='Enabled' }

  $networkTable += "<tr><td>MaxUserPort</td><td>≥ 65000</td><td>$maxPort</td></tr>`n"
  $networkTable += "<tr><td>TcpTimedWaitDelay</td><td>≤ 30</td><td>$waitDelay</td></tr>`n"
  $networkTable += "<tr><td>IPv6 Status</td><td>Enabled (unless policy)</td><td>$ipv6Status</td></tr>`n"
  $netJson += @{ Name='MaxUserPort'; Value=$maxPort }
  $netJson += @{ Name='TcpTimedWaitDelay'; Value=$waitDelay }
  $netJson += @{ Name='IPv6'; Value=$ipv6Status }

  $activeNics = Get-NetAdapter | Where-Object { $_.Status -eq 'Up' }
  foreach($nic in $activeNics){
    $nicName=$nic.Name; $nicDesc=$nic.InterfaceDescription; $nicIdx=$nic.ifIndex
    $rscStatus = try{ $r=Get-NetAdapterRsc -Name $nicName -ErrorAction Stop; "IPv4: $($r.IPv4Enabled), IPv6: $($r.IPv6Enabled)" }catch{ 'Unknown' }
    $rssStatus = try{ (Get-NetAdapterRss -Name $nicName -ErrorAction Stop).Enabled }catch{ 'Unknown' }
    $sriov     = try{ (Get-NetAdapterSriov -Name $nicName -ErrorAction Stop).SriovSupport }catch{ 'Unknown' }

    # multiple vendor keywords for buffers
    $recvBuf = 'N/A'
    foreach($k in @('*ReceiveBufferSize','*ReceiveBuffers','*ReceiveDescriptors')) {
        try { $v=(Get-NetAdapterAdvancedProperty -Name $nicName -RegistryKeyword $k -ErrorAction Stop).RegistryValue; if($v){ $recvBuf=$v; break } } catch {}
    }
    $sendBuf = 'N/A'
    foreach($k in @('*SendBufferSize','*TransmitBufferSize','*TransmitBuffers')) {
        try { $v=(Get-NetAdapterAdvancedProperty -Name $nicName -RegistryKeyword $k -ErrorAction Stop).RegistryValue; if($v){ $sendBuf=$v; break } } catch {}
    }
    if ($recvBuf -is [array]) { $recvBuf = ($recvBuf -join ', ') }
    if ($sendBuf -is [array]) { $sendBuf = ($sendBuf -join ', ') }

    $networkTable += "<tr><td>NIC ($nicName)</td><td>$nicDesc (Index $nicIdx)</td><td>Active</td></tr>`n"
    $networkTable += "<tr><td>SR-IOV / Accelerated Networking</td><td>Supported/Enabled</td><td>$sriov</td></tr>`n"
    $networkTable += "<tr><td>RSS</td><td>Enabled</td><td>$rssStatus</td></tr>`n"
    $networkTable += "<tr><td>Receive Segment Coalescing</td><td>Offload state</td><td>$rscStatus</td></tr>`n"
    $networkTable += "<tr><td>Receive Buffer Size</td><td>Adapter advanced property</td><td>$recvBuf</td></tr>`n"
    $networkTable += "<tr><td>Send Buffer Size</td><td>Adapter advanced property</td><td>$sendBuf</td></tr>`n"

    $netJson += @{ NIC=$nicName; SRIOV=$sriov; RSS=$rssStatus; RSC=$rscStatus; ReceiveBuffer=$recvBuf; SendBuffer=$sendBuf }
  }
}catch{
  $networkTable += "<tr class='status-ERROR'><td colspan='3'>Error retrieving NIC or registry parameters</td></tr>"
}

# Power plan & time sync
$powerPlan = try{ (powercfg /GETACTIVESCHEME) -join ' ' }catch{ 'Unknown' }
$isHighPerf = if($powerPlan -match 'High performance|Ultimate performance'){'OK'}else{'REVIEW'}
$w32 = try{ (w32tm /query /status) -join '; ' }catch{ 'Unknown' }
$networkTable += "<tr class='$([string]::Format('status-{0}',$isHighPerf))'><td>Power Plan</td><td>High/Ultimate Performance</td><td>$powerPlan</td></tr>`n"
$networkTable += "<tr><td>Time Service</td><td>w32tm status</td><td>$w32</td></tr>`n"

$networkConfigSection = @"
<div class='section'>
<h2>9. Network Tuning &amp; NIC Configuration</h2>
<table>
<tr><th>Network Parameter</th><th>Expected/Info</th><th>Value</th></tr>
$networkTable
</table>
</div>
"@

# -------------------- 10. Recent Patches --------------------
try{
  $hotfixes = Get-HotFix | Sort-Object -Property InstalledOn -Descending | Select-Object -First 10
  $patchRows=""
  foreach($patch in $hotfixes){
    $installedDate = if($patch.InstalledOn -is [datetime]){ $patch.InstalledOn.ToString('yyyy-MM-dd') }else{ $patch.InstalledOn }
    $patchRows += "<tr><td>$($patch.HotFixID)</td><td>$($patch.Description)</td><td>$installedDate</td></tr>`n"
  }
  $patchSection = @"
<div class='section'>
<h2>10. Recent Windows Patches</h2>
<table>
<tr><th>KB</th><th>Description</th><th>Installed On</th></tr>
$patchRows
</table>
</div>
"@
}catch{
  $patchSection = "<div class='section'><h2>10. Recent Windows Patches</h2><p style='color:red;'>Error retrieving patch information.</p></div>"
}

# -------------------- 11. Azure (IMDS) context --------------------
$imds = Try-IMDS
$azrRows=""
if($imds){
  $vmSize  = $imds.compute.vmSize
  $location= $imds.compute.location
  $zone    = $imds.compute.zone
  $azrRows += New-StatusRow "AZR-001" "VM Size" "IMDS compute.vmSize" $vmSize "v5/v6 SKUs preferred" "REVIEW"
  $azrRows += New-StatusRow "AZR-002" "Region/Zone" "IMDS location/zone" "$location / $zone" "Deployed in target zone" ($(if($zone){'OK'}else{'REVIEW'}))
  $azrRows += New-StatusRow "AZR-003" "Accelerated Networking" "SR-IOV (guest)" (($netJson|ForEach-Object{$_.SRIOV}) -join ', ') "Supported/Enabled" "REVIEW"
  try { $osCache = $imds.compute.storageProfile.osDisk.caching } catch { $osCache = $null }
  try { $dataCache = ($imds.compute.storageProfile.dataDisks | ForEach-Object { $_.caching }) -join ', ' } catch { $dataCache = $null }
  $azrRows += New-StatusRow "AZR-004" "OS Disk Caching"  "IMDS" $osCache "ReadOnly" "REVIEW"
  $azrRows += New-StatusRow "AZR-005" "Data Disk Caching" "IMDS (per disk)" $dataCache "Pv1: Data=ReadOnly, Pv2: Data=None" "REVIEW"
}else{
  $azrRows = "<tr class='status-REVIEW'><td colspan='6'>IMDS not reachable — Azure metadata checks skipped (expected on non-Azure or restricted networks).</td></tr>"
}
$azrSection = @"
<div class='section'>
<h2>11. Azure Infrastructure Context (AZR-001 … AZR-005)</h2>
<table>
<tr><th>CHECKID</th><th>DESCRIPTION</th><th>INFO</th><th>TESTRESULT</th><th>EXPECTED</th><th>STATUS</th></tr>
$azrRows
</table>
<small class='muted'>OS caching: ReadOnly. Data caching: Pv1=ReadOnly, Pv2=None. Logs: None.</small>
</div>
"@

# -------------------- combine & write --------------------
$htmlContent = $htmlHeader + $osDetails + $netInfo + $sapSectionHtml + $sqlSAPChecks + $clusterHtml + $sqlHtmlSection + $diskCheckSection + $avCheckSection + $networkConfigSection + $patchSection + $azrSection + "</body></html>"
$htmlContent | Out-File -FilePath $htmlPath -Encoding UTF8

$jsonObject = @{
  Hostname       = $hostname
  Time           = (Get-Date)
  OS             = $osInfo.Caption
  Domain         = $domain
  WUAService     = $wuauserv
  PageFileMB     = $pageMB
  DefaultGateway = $gateway
  DNS            = $dnsList
  Firewalls      = $firewalls
  SqlSAPChecks   = $sqlSAPJson
  DiskBlockSizes = $diskJson
  Antivirus      = $avJson
  NetworkConfig  = $netJson
  PowerPlan      = $powerPlan
  TimeService    = $w32
  AzureIMDS      = if($imds){ $imds.compute }else{ $null }
}
if (-not (Have-Command 'sqlcmd')) { $jsonObject.SqlNote = 'sqlcmd not found; SQL checks limited' }

$jsonObject | ConvertTo-Json -Depth 6 | Out-File -FilePath $jsonPath -Encoding UTF8

Write-Host "Files saved:"
Write-Host "HTML: $htmlPath"
Write-Host "JSON: $jsonPath"
}

# Execute
Get-AzSAPVmPostProvisionCheck -ExportPath "C:\tmp\SAPOnAzureChecks"
