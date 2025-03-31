# Changelog

# Version 2025033101
* FIX: getent hosts for ANF had the wrong hostname in the search

# Version 2025022801
* UPDATE: change script to be valid for 120 days instead of 60 days
* FIX: if NIC was not in same RG the HA check for secondary IP would fail

# Version 2024122301
* NEW: Detection for Azure Files shares
* FIX: New NFS volume detection for AFS/ANF
* UPDATE: reordering some columns for easier consumption of report
* UPDATE: adding fixed parameter values to some functions

# Version 2024121601
* FIX: fixing a situation where the VG is not identified correct

# Version 2024121001
* NEW: adding more debugging messages

# Version 2024120501
* NEW: add support for new Mv3 High Memory SKUs
* NEW: support for new category "Features", Features are used to dynamically run checks, e.g. for Antivirus Solutions
* NEW: initial checks for Microsoft Defender for Linux
* FIX: in GUI the IP address for multi-interface or multi-IP interfaces was not shown
* FIX: customers with multiple subscriptions/tenants had long run times, getting Azure Context before checking subscription to avoid long run times
* UPDATE: removing fixed setting "Agent" for Red Hat High Availability as SBD is also supported -> checks for SBD Red Hat coming soon
* UPDATE: NVMe device identification changed (LUN-ID) from MSFT_NVMe* to /sys/block/nvme0n*
* UPDATE: Checks for Load Balancers are only done on inbound load balancers (outgoing internet load balancers excluded)

# Version 2024112801
* NEW: add support for Mv3 Very High Memory segment with missing High Memory SKUs
  
# Version 2024091002
* NEW: add support for Mv3 High Memory segment

# Version 2024091001
* FIX: Linux multiline prompts with caused problems when running commands

# Version 2024082202
* FIX: adding a minimum latency for the SSH streams

# Version 2024082201
* FIX: Test-Connection for latency test had a wrong entry

# Version 2024082001
* FIX: QualityCheck.json VM list had a structure issue

# Version 2024081402
* FIX: change using -ignore-case in to -i grep to ignore case sensitivity
* FIX: add loadbalancer details in new line

# Version 2024081401
* NEW: added support for Fasv6 and Famsv6, look for SAP Note 1928533 for final certification
* FIX: change pacemaker commands when using grep to ignore case sensitivity

# Version 2024081302
* FIX: Update the load-balancer checks to show the correct and verbose output in error scenarios.

# Version 2024081301
* NEW: Parameter -DetailedDebugFile added, creates a debug log for better diagnostics
* NEW: adding a ping to get latency to server, required to fix SSH Stream timings
* NEW: support for NVMe
* NEW: script stops when file systems provided are invalid (DBDataDir, DBLogDir, DBSharedDir)
* NEW: added support for Dsv6, Ddsv6, Dasv6, Ddasv6, Esv6, Edsv6, Easv6, Eadsv6, look for SAP Note 1928533 for final certification
* NEW: added support for NVMe enabled Mv3 instances
* UPDATE: move to Posh-SSH 3.2.0
* FIX: SSH Stream updated to check for data available and have sleep timings as SSH stream are running async
* FIX: in RedHat cases the OS disk might run LVM, fixing issue where LVM is not detected

# Version 2024060301
* FIX: update on Db2 command
* FIX: find if sudo worked
* FIX: remove sudo

# Version 2024052301
* FIX: solving issue with first line of result being the command
* UPDATE: increase buffer size for SSH Stream
* NEW: add PowerShell module versions to HTML file

# Version 2024042301
* NEW: add HANA support for Standard_M176ds_4_v3
* NEW: add subscription ID to limit the number of requests when checking available subscriptions and avoid a potential timeout when too many subscriptions exist

# Version 2024040502
* FIX: add a backup path for Azure NetApp Files throughput detection if the mounted file system is a subdirectory on the NFS share

# Version 2024040501
* UPDATE: add SAP HANA Standard Sizing to M416ms_v2 instances
* NEW: add dynamic results
* UPDATE: add a backup path for Azure NetApp Files throughput detection if the mounted file system is a subdirectory on the NFS share

# Version 2024031302
* NEW: OS checks related to kernel configuration kernel.shmmni.
* NEW: Instance memory check for DB2
* Updated DB2 and oracle check to compare the memory value instead of logging the memory size.

# Version 2024031301
* NEW: moving from Invoke-SSHCommand to Invoke-SSHStreamShellCommand for easier management of SSH sessions and to avoid using passwords on commands in JSON through variables
* NEW: ProcessingCommandOutput in JSON can be used to run an OS command for showing the result, e.g. for sbd device checking 
* NEW: check for SUSE Linux Kernel because of note https://www.suse.com/de-de/support/kb/doc/?id=000021035
* UPDATE: update to SBD msgwait and watchdog to also include results of the outputs
* UPDATE: moving some Information Collection checks directly to code for better analysis
* UPDATE: moving from crm configure show for concurrent-fencing to crm_attribute
* UPDATE: removing autofs entries from findmnt as they are mentioned twice
* FIX: list of file systems included header, removed
* FIX: update for Load Balancer SKU to reflect the correct Load Balancer SKU type
* FIX: changing log messages for disks without volume groups from WARNING to INFO

# Version 2024031201
* FIX: missing updated version numbers in JSON and PS1 file

# Version 2024031101
* NEW: Switch DetailedLog for more logs on the commands run
* FIX: range sometimes doesn't provide correct result
* FIX: HDB-OS-SLES-0006 is only for RedHat and is renamed to HDB-OS-RHEL-0008
* FIX: moving back to echo instead of printf as there are issues on newer distributions
* FIX: when using SSH Keys with root user a wrong if statement was taken

# Version 2024022201
* NEW: add parameter OutputDirName to change the path for HTML and JSON files
* UPDATE: add Version of Quality Check to JSON file

# Version 2024022101
* UPDATE: adding additional parameters to JSON output

# Version 2024022002
* FIX: remove cd/dvd drive from lsscsi output
* NEW: add an error if the script version is older than 60 days

# Version 2024022001
* FIX: Fixing issue for HDB-OS-SLES-0006 and HDB-OS-SLES-0012 as they don't apply to Non-HA scenarios and only apply to RedHat (SUSE doesn't use pcs command)
* FIX: Fixing Azure Disk output summary not shown in report
* FIX: Sector size for Premium SSD V2 not shown for /hana/data directory
* FIX: Check if disk configuration is supported not shown for direct file systems (/dev/sdX)
* FIX: HDB-FS-0016 added error category
* FIX: moving from echo to printf for sudo commands to avoid cases on newer kernels
* FIX: removing the sudo output from stderr as newer kernel versions show errors during execution, even if there is no error
* FIX: fixing the search IOPS and MBPS for direct file systems (/dev/sdX)
* UPDATE: update to Readme.md

# Version 2024021501
* NEW: the HADR dump for DB2 systems
* NEW: Db2 database PEER_WINDOW and HADR_TIMEOUT checks for SUSE and RHEL

# Version 2024020601
* UPDATE: moving to newer versions of Azure networking module due to Loadbalancer ProbeThreshold requirement
* NEW: the reference architecture has been updated with a new parameter for load balancers, ProbeThreshold

# Version 2024012501
* NEW: HANA SrHook Configuration collection check
* NEW: Oracle database HugePage_Total collection check

# Version 2024012202
* NEW: Windows, SQL Server, application servers and Windows Cluster Parameter validation
* NEW: Oracle database and application servers
* NEW: Db2 database and application servers

# Version 2024011701
* NEW: DB2 checks for storage stripe size.
* Log OS command failures. 
* Add Azure Fence Agent Configuration and OS HA checks

# Version 2024011201
* NEW: parameter AddJSONFile available to send output to HTML + JSON file for automatic analysis of files
* NEW: possibility to have multiple SAP Notes
    * ```"SAPNote": ["123123", "234234"]```
* NEW: possibility to have multiple Links to documentation
    * ```"MicrosoftDocs": ["https://azure.microsoft.com", "https://www.microsoft.com"]```
* UPDATE: starting to move cluster checks to ranges, e.g. stonith-timeout
* UPDATE: adding a lot of links and SAP notes to the checks

# Version 2024010301
* NEW: check for multiple valid result
    * ```"ExpectedResult": { "Type": "multi", "Values": ["net.ipv4.tcp_tw_reuse = 0", "net.ipv4.tcp_tw_reuse = 2"] } ```
    * Type is defined as "multi" and Values contains the possible results
* NEW: check for valid result range
    * ```"ExpectedResult": { "Type": "range", "low": 2, "high": 5 } ```
    * Type is defined as "range" and the parameters low and high define the range including the values itself
* single results have been unchanged
    * ```"ExpectedResult": "2"```
* UPDATE: link to SAP notes has been updated to "me.sap.com" instead of "launchpad.support.sap.com"


# Version 2023120402
* fixing issue with VMs that have more than 26 disks (/dev/sda to /dev/sdz), and disk names have 4 characters (e.g. /dev/sdaa) for OS disk / rootvg

# Version 2023120401
* fixing issue with VMs that have more than 26 disks (/dev/sda to /dev/sdz), and disk names have 4 characters (e.g. /dev/sdaa)

## Version 2023113001
* adding check for number of extensions on VM
* check to identify whether the secondary IP is enabled on Primary NIC
* adding check to identify the security type of VM (Standard/Trusted/)
* identify whether the VM is deployed on VMSS flex
* adding check to find the probe interval for a load balancer
* check to know whether microsoft defender is installed on the VM running Windows OS
* updated the GUI to take the ANF parameters as input
* updated the logic to get the pacemaker corosync consensus
* updated the command to get the pacemaker concurrent fencing

## Version 2023112102

* with Az.NetAppFiles 0.13 the field for throughput was changed, taking the max value of the old and the new field in module

## Version 2023112101

* add support in all checks for Premium SSD v2
* add support for new M416s_8_v2 instance
* add support for new Mv3 instances
* fix a typo in the description of cluster checks (mix of 60 and 120 seconds, only description incorrect)
* add additional checks for kernel issues related to accelerated networking

## Version 2023061301

* adding support for ASE
* adding support for Premium SSD v2
* adding Premium SSD v2 check for disk block size
* adding E20a(d)s_v5 VM type
* updating API version for metadata service from 2021-11-01 to 2021-12-13
* updating view of checks, additional infos are now shown at the end of the table, easier to view results on smaller resolutions
* updating DBDataDir and DBLogDir to always refer to variables on script level
* fixing a problem where the script continues to run, even if VM is not found in Azure
* fixing spelling in readme.md
* fixing a problem with the number of stripes shown in LVM volume information
* fixing a problem where SSH logon doesn't work after host was reinstalled or has new SSH keys
* disabling the "breaking change" warning message for the script

## Version 2023032301

* fixing an issue where the script continues to run when sudo permission check fails
* adding SUSE Kernel check for SLES 15 SP2 and SP4 causing kernel panic (Mellanox driver issue)
* adding text searchable for GUI resource group

## Version 2023032201

* fixing an issue with ANF volumes when mounted using DNS names instead of IP addresses
* changing the way how ANF volume names are detected
* moving from ANF volume name to ANF creation token which is the export path, volume name and export path can be different
* adding execution date and time to the beginning of the report
* fixing an issue where MultiRun wouldn't run
* fixing a typo in load balancer
* fixing an issue where checks were executed even if they are not desired for this system (HA/non-HA issue)
* fixing a typo for Oracle in GUI (Oracle/ORACLE)

## Version 2022082301

* adding support for M420ixs_v2 and M832ixs_v2 (limited GA)
* adding support for Da(d)s_v5 and Ea(d)s_v5
* fix: script not stopping when not able to logon to VM
* fix: checking if global.ini exists (option -SID) and adding fallback path
* fix: /hana/data not checking for LVM or /dev/sd device like with /hana/log

## Version 2022072701

* adding automatic detection for fencing machanism based on configured SBD_DEVICE, if no device configured then it is Fencing Agent

## Version 2022072601

* adding SID parameter
* based on SID the script will autodetect which file systems are used by HANA database

## Version 2022072101

* fixing issue where links to Microsoft documentation are missing
* fixing issue with LoginWithUserSSHKey, specifying a dummy password

## Version 2022072001

* adding Logon option -UserSSHKey for users that don't require a password, just the SSH key

## Version 2022071302

* adding support to run multiple quality checks in one run, only supported with user/password authentication as of now

## Version 2022071301

* adding check for supported storage configuration on HANA Data and HANA Log

## Version 2022071202

* adding first version of GUI option with user/password authentication
* adding description for accelerated networking VMs with only one NIC allowed for accelerated networking

## Version 2022071201

* fixing SSH Key logon issues

## Version 2022070702

* adding runtime log to HTML file
* formating of log output

## Version 2022070701

* adding parameters to HTML output
* fixing an issue with RunLocally and post processing commands
* adding storage disk types to script incl performance values for RunLocally command to calculate performance and throughput
* adding internal values in JSON output for RunLocally

## Version 2022070601

* fixing issue with OS disk not part of a VG

## Version 2022070301

* add and update SAP note 3024346, HANA with Azure NetApp Files
* add RunInLocalMode option in JSON file
* moving version history from readme.md to JSON file
* updating parameters for PowerShell script to use ParameterSets
* enabling SSH keys for different combinations incl Azure Key Vault
* add runlocally to run the script on the system itself without outside connectivity to Azure, requires PowerShell to be installed on the system and needs to run as root user
* add options for GUI, will be implemented in a future release
* removing required PowerShell modules from #requires section to be able to run in RunInLocalMode, module requirements are checked within the code

## Version 2022070101

* hotfix for OSdisk VG identification
* changing information collection sg_map to lsscsi

## Version 2022062302

* fixing a typo for HANA SLES Fencing Agent configuration

## Version 2022062301

* fixing an issue with root and resource disk causing the script not to find the correct LUN ID for data disks

## Version 2022050901

* fixing parameters

## Version 2022042501

* fixing issue when customers don't have sg3_utils installed, moving to lsscsi instead of sg_map
* adding exception handling for disks that are not used, just attached
* fixing an issue where Db2 OS/DB combination wasn't working

## Version 2022041301

* adding a check if sg_map is installed

## Version 2022041102

* adding case sensitivity to parameters

## Version 2022041101

* adding sudo check
* adding version check

## Version 2022022301

* changing naming to "Quality Check for SAP workloads on Azure"

## Version 2022022201

* adding HANA support for E(d)s_v5 instances

## Version 2022021801

* fixing concurrent fencing for SLES, thanks to @1lomeno3

## Version 2022021101

* fixing issue where passwords start with a special character

## Version 2022021002

* moving to absolute paths for all executables

## Version 2022021001

* fixing an issue when PATH doesn't include e.g. the lvm command
* fixing an issue when using root user (no sudo required)

## Version 2022020301

* fixing an issue for sudo command that don't get the environment variables
* fixing a potential issue for not finding the correct disk

## Version 2022013002

* fixing an issue for tcp_retries1 (thanks @iklema)
* APP-OS-0005 only applies to SLES 12.3 as newer versions have kernel 4.12 (thanks @iklema)
* updaing systemctl to 'systemctl list-unit-files --state=enabled' (thanks @iklema)

## Version 2022013001

* adding script version to footer
* adding more checks to analyze storage errors
* updating storage API version call

## Version 2022012701

* fixing display issue for disks showing in stripe size check

## Version 2022012601

* fixing issue for /dev/sda not being rootvg

## Version 2022012401

* fixing IC checks for APP and ASCS servers

## Version 2022012101

* fixing a typo in fence_kdump check
* fixing a case there LVM is used on partitions instead of full disk (e.g. /dev/sdc1 instead of /dev/sdc)
* fixing IOPS check, only applies for Ultra Disk

## Version 2022011903

* adding softdog checks for SLES/SBD

## Version 2022011902

* adding fence_kdump as optional check

## Version 2022011901

* adding info and warning as errorcatory in json and ps1

## Version 2022011801

* adding ASCS HA checks

## Version 2022011101

* fixing description for CPU softlockup check HDB-OS-SLES-0005

## Version 2022011001

* added support for HANA multi disk scenario
* added support for /dev/sdX devices instead of LVM
* added section at the end for copy/paste data for further internal analysis
* added support for D(d)sv4 and E(d)sdv5
* added version number to script and json and compare values when script starts
* added error handling for SSH connectivity in case VM is down
* added the HDB-FS file system checks to documentation
* fixed a RedHat Cluster information collection command

## Version 2022010401

* Initial V2 version
* support for DB, ASCS and app servers
* HTML output for better user expierience
* every check has a unique check id
* updated check engine with more granular view (e.g. adding support for special OS releases)
* documented all checks on GitHub
* data collection engine to get better overview of system
* added support for Db2 and Oracle
* added support for Oracle Linux
* new kernel check function
* foundation for adding Windows support in the future
