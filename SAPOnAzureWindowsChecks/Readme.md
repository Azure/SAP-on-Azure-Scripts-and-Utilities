# SAP on Azure — Windows VM Post-Provisioning Checks (PowerShell)

A single-host, read-only assessment that inspects a Windows VM running SAP workloads on Microsoft Azure and generates a colour-coded HTML report plus a machine-readable JSON. It captures OS, networking, cluster, SQL Server, storage, AV/filter drivers and Azure IMDS context, and compares findings to thresholds embedded in the script.

> **Note:** The script currently **auto-executes** when run because it calls the function at the end with a default export path. See **Auto-run behaviour** below.

---

## Table of contents

- [What this does](#what-this-does)
- [Output](#output)
- [Prerequisites](#prerequisites)
- [Install & run](#install--run)
- [Auto-run behaviour](#auto-run-behaviour)
- [Interpreting results](#interpreting-results)
- [JSON schema (high level)](#json-schema-high-level)
- [Troubleshooting](#troubleshooting)
- [Contributing](#contributing)
- [Licence](#licence)

---

## What this does

The script defines `Get-AzSAPVmPostProvisionCheck` and emits two artefacts per run (HTML & JSON). It performs the checks below and renders pass/review/error status where applicable.

1) **OS & Platform**
   - Hostname, OS/edition/version, domain join, timezone, execution user/time, latest installed KB.

2) **Additional & Network**
   - Windows Update service, page file total MB, default gateway & DNS servers, active NIC, per-profile firewall state.

3) **SAP VM configuration (cluster defaults & name resource)**
   - Quorum resource type (Cloud Witness expected).
   - Cluster heartbeat timings: `SameSubnetDelay`, `SameSubnetThreshold`, `CrossSubnetDelay`, `CrossSubnetThreshold`.
   - Network Name resource: `HostRecordTTL`, `RegisterAllProvidersIP`.

4) **SQL Server compatibility (per instance)**
   - Collation (expects `SQL_Latin1_General_CP850_BIN2`), auth mode (Windows-only), Instant File Initialization, Lock Pages In Memory (LPIM).
   - Performance/config: `max degree of parallelism` (expects 1 for OLTP), CPU affinity (expects default 0).
   - Data compression presence (any compressed objects), product version/level/CU/KB, edition.
   - TCP configuration: IPAll (static or dynamic), runtime listening ports.

5) **Cluster & SQL Services overview**
   - Failover Clustering feature present/active, cluster nodes & quorum.
   - SQL Server services state and image paths.

6) **SQL Server configuration (registry/WMI)**
   - Max Server Memory (MB), TCP enabled, IPAll port/dynamic ports, current listening ports, startup trace flags, collation echo.

7) **Data disk block size (all fixed volumes)**
   - Reports allocation unit size/cluster bytes with expectations:
     - `C:`/`D:` (OS/Temp): **4 KB (4096)** expected.
     - Other NTFS data volumes: **64 KB (65536)** expected.

8) **Antivirus & filter drivers**
   - AV product(s) from SecurityCenter2 and/or presence of Defender filter.
   - Active filesystem/filter drivers (e.g., Defender, CrowdStrike, etc.).

9) **Network tuning & NIC offloads**
   - `MaxUserPort` (≥ 65000), `TcpTimedWaitDelay` (≤ 30), IPv6 state.
   - For each **active** NIC: SR-IOV/Accelerated Networking support, RSS, RSC, receive/transmit buffer sizes.
   - Power plan (High/Ultimate preferred) and `w32tm` time sync status.

10) **Recent Windows patches**
    - Top 10 installed hotfixes (KB, description, date).

11) **Azure IMDS context**
    - VM size, region/zone, accelerated networking flags.
    - OS disk caching, data disk caching (Pv1: ReadOnly; Pv2: None).

---

## Output

- **HTML report**: `C:\tmp\SAPOnAzureChecks\{HOST}_SAP_VM_PostProvisioning_Report_{YYYYMMDD_HHMMSS}.html`
- **JSON dump**: `C:\tmp\SAPOnAzureChecks\{HOST}_SAP_VM_PostProvisioning_Report_{YYYYMMDD_HHMMSS}.json`

Both files include the host name and a timestamp. The HTML uses green/amber/red rows to indicate **OK / REVIEW / ERROR**.

---

## Prerequisites

- PowerShell 5.1+ (Windows Server).
- `sqlcmd` in `PATH` for SQL checks (SQL Server Command Line Utilities).
- The **FailoverClusters** module for cluster visibility (falls back to registry where possible).
- Run in an elevated PowerShell session; registry, WMI, clustering and NIC advanced properties typically require admin rights.

---

## Install & run

1. Save the script file as `SAPChecksOnAzure.ps1` on the target VM.
2. Open **Windows PowerShell** as Administrator.
3. Run the script directly (auto-exec will generate the report to the default path):  
   ```powershell
   .\SAPChecksOnAzure.ps1
   ```
   or invoke the function yourself with a custom export folder:
   ```powershell
   # If you commented the auto-exec, dot-source and call the function:
   . .\SAPChecksOnAzure.ps1
   Get-AzSAPVmPostProvisionCheck -ExportPath "D:\Ops\Reports"
   ```

### Parameters

- `-ExportPath <string>` — Destination folder for HTML/JSON. Defaults to `C:\tmp\SAPOnAzureChecks`.

---

## Auto-run behaviour

The script ends with:
```powershell
# Execute
Get-AzSAPVmPostProvisionCheck -ExportPath "C:\tmp\SAPOnAzureChecks"
```
If you prefer to **import without executing**, comment out or remove those lines. Then dot-source and call the function with your desired parameters.

---

## Interpreting results

- **Green (OK):** Within expected range or explicitly matched the expected value.
- **Amber (REVIEW):** Present but outside the recommended range / not explicitly matched; evaluate intent (e.g., BW/analytics VM may differ from OLTP defaults).
- **Red (ERROR):** Could not retrieve or missing data where a value is required.

### Key expectations used by the report

- **SQL (OLTP defaults):** `MAXDOP = 1`, authentication **Windows-only**, **IFI** & **LPIM** enabled.
- **Storage:** OS/temp volumes at **4 KB** allocation unit; data volumes at **64 KB**.
- **Cluster:** Cloud Witness quorum; heartbeat and name-resource parameters set to SAP-friendly defaults.
- **Networking:** `MaxUserPort ≥ 65000`, `TcpTimedWaitDelay ≤ 30`, RSS enabled; Accelerated Networking supported/enabled where possible.
- **Azure:** OS disk caching **ReadOnly**; **Pv1** data **ReadOnly**, **Pv2** data **None**.

Use the JSON to feed dashboards or compliance pipelines.

---

## JSON schema (high level)

Top-level properties (non-exhaustive):
```json
{
  "Hostname": "WindowsVM",
  "Time": "2025-10-21T09:30:00Z",
  "OS": "Microsoft Windows Server ...",
  "Domain": "contoso.local",
  "WUAService": "Running",
  "PageFileMB": 16384,
  "DefaultGateway": "10.x.x.1",
  "DNS": ["10.x.x.10","10.x.x.11"],
  "Firewalls": { "Domain": true, "Private": true, "Public": false },
  "SqlSAPChecks": {
    "Default": {
      "Collation": "SQL_Latin1_General_CP850_BIN2",
      "AuthenticationMode": "Windows Authentication",
      "IFI": "Enabled",
      "LPIM": "Enabled (in use)",
      "MaxDOP": 1,
      "CPUAffinity": "Default (0)",
      "DBCompression": "Enabled (some objects)",
      "ProductVersion": "16.0.x.x",
      "CULevel": "CU14",
      "CUKB": "KB50xxxxx",
      "Edition": "Enterprise",
      "TcpIPAllPort": "1433",
      "TcpListeningPorts": [ "1433" ]
    }
  },
  "DiskBlockSizes": [
    {"Volume":"C:\\\\","ClusterBytes":4096,"Expected":4096,"Status":"OK"}
  ],
  "Antivirus": [
    {"Product":"Microsoft Defender","Status":"OK"}
  ],
  "NetworkConfig": [
    {"Name":"MaxUserPort","Value":65534}
  ],
  "PowerPlan": "High performance ...",
  "TimeService": "Leap indicator, stratum ...",
  "AzureIMDS": {
    "vmSize": "Standard_E96ds_v5",
    "location": "westeurope",
    "zone": "2"
  }
}
```

---

## Troubleshooting

- **No SQL details:** Ensure `sqlcmd` is installed and can connect locally. If absent, the JSON will include `SqlNote: "sqlcmd not found; SQL checks limited"`.
- **Cluster parameters missing:** Install the **Failover Clustering** feature and/or ensure the account can access cluster APIs (the script will fall back to registry where possible).
- **Azure IMDS empty:** Confirm IMDS is reachable (169.254.169.254) and that you are running on Azure or that network policies allow link-local metadata access.
- **Access denied errors:** Re-run in an elevated PowerShell session.

---

## Contributing

Issues and PRs are welcome. Please include:
- The generated JSON (with sensitive values redacted).
- Your Windows/SQL versions and VM size.
- A clear description of the expected vs. actual result.

---

## Licence

Add your preferred licence (e.g., MIT, Apache-2.0) here.
