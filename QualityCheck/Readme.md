# Quality Check for SAP on Azure
Current Version: V1

## Disclaimer

THE SCRIPTS ARE PROVIDED AS IS WITHOUT WARRANTY OF ANY KIND, EITHER EXPRESS OR IMPLIED, INCLUDING ANY IMPLIED WARRANTIES OF FITNESS FOR A PARTICULAR PURPOSE, MERCHANTABILITY, OR NON-INFRINGEMENT.

## Description
When installing SAP HANA on Azure you have to follow guidelines available on [here](https://docs.microsoft.com/en-us/azure/virtual-machines/workloads/sap/hana-get-started)
Especially the storage layout available [here](https://docs.microsoft.com/en-us/azure/virtual-machines/workloads/sap/hana-vm-operations-storage) should be taken into consideration.

The certified SAP HANA on Azure instances are available in the [Certified And Supported SAP HANA Hardware Directory](https://www.sap.com/dmc/exp/2014-09-02-hana-hardware/enEN/#/solutions?filters=iaas;ve:24)

## How does it work
The Quality Check consists of two files
* PowerShell Script that connects to Azure Resource Manager (ARM) and to the VM using SSH
* Check repository (JSON) file that includes all checks

## What's required
* PowerShell 5.1 (we are working on PowerShell 7)
* Az Powershell Module (Az.Compute, Az.Network, Az.NetAppFiles)
* Posh-SSH Module available through PowerShell Gallery, thanks to [darkoperator](https://github.com/darkoperator/Posh-SSH)



## How to run it
Download the PowerShell Script and the JSON file, but them in the same folder and install the prerequisits.

Then simply run the script.

### Sample Commands
```
. 'QualityCheck.ps1' -ResourceGroupName <ResourceGroupName for VMs> -SubscriptionName <subscription name> -AzVMname <Azure VM name> -vm_hostname <IP address or DNS name> -vm_username <OS user> -hanadeployment <ScaleUp or ScaleOut> -hanastoragetype <Premium or UltraDisk or ANF> -highavailability <$true or $false>
```

### Sample Output

```
. 'c:\Users\pl\Desktop\QualityCheck\QualityCheck.ps1' -ResourceGroupName **** -SubscriptionName **** -AzVMname **** -vm_hostname **** -vm_username **** -hanadeployment ScaleUp -hanastoragetype Premium -highavailability $true

cmdlet QualityCheck.ps1 at command pipeline position 1
Supply values for the following parameters:
vm_password: ***********
Can't connect to GitHub to check version
 OK    - VM is running
--------------------------------------------
Starting VM Info Collect
--------------------------------------------
Hostname
   hana1
Kernel Version
   4.12.14-95.60-default
System Release
   NAME="SLES"      
   VERSION="12-SP4" 
   VERSION_ID="12.4"
   PRETTY_NAME="SUSE Linux Enterprise Server 12 SP4"
   ID="sles"
   ANSI_COLOR="0;32"
   CPE_NAME="cpe:/o:suse:sles_sap:12:sp4"
   SUSE Linux Enterprise Server 12 (x86_64)
   VERSION = 12
   PATCHLEVEL = 4
   # This file is deprecated and will be removed in a future service pack or release.
   # Please check /etc/os-release for details about this release.
Azure Hypervisor Host
   DUB211050409031
VM Type
   Standard_M32ts
Proximity Placement Group
   No PPG defined
--------------------------------------------
Ending VM Info Collect
--------------------------------------------
--------------------------------------------
Starting General Checks
--------------------------------------------
 OK    - Check if VM is supported
 OK    - Check Hostname
 OK    - Check Distribtion
 OK    - Check if sapconf profile for SAP HANA applied
--------------------------------------------
Ending General Checks
--------------------------------------------
--------------------------------------------
Starting Linux Distribuation Checks
--------------------------------------------
 OK    - Linux Distribution is SUSE
--------------------------------------------
Ending Linux Distribuation Checks
--------------------------------------------
--------------------------------------------
Starting OS Checks for Storage
--------------------------------------------
--------------------------------------------
Ending OS Checks for Storage
--------------------------------------------
--------------------------------------------
Starting Storage Checks
--------------------------------------------
 OK    - Filesystem /hana/data has file system xfs
 OK    - Filesystem /hana/data is striped
 OK    - Filesystem /hana/data has stripe size of 256.00k
 OK    - Filesystem /hana/data has same disk type for all disks
 OK    - Filesystem /hana/data has a certified disk layout
 OK    - Filesystem /hana/log has file system xfs
 OK    - Filesystem /hana/log is striped
 OK    - Filesystem /hana/log has stripe size of 64.00k
 OK    - Filesystem /hana/log has same disk type for all disks
 OK    - Filesystem /hana/log has a certified disk layout
 OK    - Filesystem /hana/log - Disk hana1_log_1 (/dev/sdg) has Write Accelerator enabled
 OK    - Filesystem /hana/log - Disk hana1_log_2 (/dev/sdh) has Write Accelerator enabled
 OK    - Filesystem /hana/log - Disk hana1_log_3 (/dev/sdi) has Write Accelerator enabled
 OK    - Filesystem /hana/shared has file system xfs
 OK    - Filesystem /hana/shared has same disk type for all disks
 OK    - Filesystem /hana/shared has a certified disk layout
--------------------------------------------
Ending Storage Checks
--------------------------------------------
--------------------------------------------
Starting High Availability Checks
--------------------------------------------
 OK    - Check pacemaker setting for PREFER_SITE_TAKEOVER=true
 OK    - Check pacemaker setting for AUTOMATED_REGISTER=true
 OK    - Check pacemaker setting for stonith-enabled=true
 OK    - Check pacemaker setting for stonith-timeout=144
 OK    - Check corosync token 30000 setting
 OK    - Check corosync token_retransmits_before_loss_const: 10 setting
 OK    - Check corosync join: 60 setting
 OK    - Check corosync consensus: 36000  setting
 OK    - Check corosync max_messages: 20 setting
 OK    - Check corosync expected_votes: 2 setting
 OK    - Check corosync two_node: 1 setting
 OK    - Check SBD watchdog timeout 60
 OK    - Check SBD msgwait timeout 120
--------------------------------------------
Ending High Availability Checks
--------------------------------------------
--------------------------------------------
Starting Networking Checks
--------------------------------------------
 OK    - Accelerated Networking Enabled for Interface hana1737
 OK    - Load Balancer hanalb is using Standard SKU
 OK    - Load Balancer hanalb idle timeout is set to 30 minutes
 OK    - Load Balancer hanalb has floatint IP enabled
 OK    - Load Balancer hanalb has HA Ports enabled
 OK    - socat installed
--------------------------------------------
Ending Networking Checks
--------------------------------------------
--------------------------------------------
Cleaning Up
--------------------------------------------
```

### Full Help
```
get-help .\QualityCheck.ps1 -detailed


NAME
    QualityCheck.ps1

SYNOPSIS
    Check HANA System Configuration


SYNTAX
    \QualityCheck.ps1 [-SubscriptionName] <String> [-ResourceGroupName] <String> [-AzVMname] <String> [-vm_hostname] <String> [[-ANFResourceGroupName] <String>] [[-ANFAccountName] <String>] [-vm_username] <String> [-vm_password] <SecureString> [[-hanadeployment] <String>] [[-hanastoragetype] <String>]      
    [[-highavailability] <Boolean>] [[-sshport] <String>] [[-createlogfile] <Boolean>] [[-ConfigFileName] <Object>] [[-fastconnect] <Object>] [<CommonParameters>]


DESCRIPTION
    The script will check the configuration of a VM for running SAP HANA


PARAMETERS
    -SubscriptionName <String>
        Azure Subscription Name

    -ResourceGroupName <String>
        Azure Resource Group Name

    -AzVMname <String>
        Azure VM Name

    -vm_hostname <String>
        hostname or IP address used for SSH connection
        
    -ANFResourceGroupName <String>
        Azure NetApp Files ResourceGroup

    -ANFAccountName <String>
        Azure NetApp Files Account Name

    -vm_username <String>
        Username used to logon

    -vm_password <SecureString>
        Password used to logon

    -hanadeployment <String>
        HANA ScaleUp or ScaleOut

    -hanastoragetype <String>
        HANA Storage Option

    -highavailability <Boolean>
        HighAvailability Check

    -sshport <String>
        ssh port

    -createlogfile <Boolean>
        create logfile

    -ConfigFileName <String>
        QualityCheck Configfile

    -fastconnect <Boolean>
        FastConnect - already connected to Azure

```

## What's next / What we think about
* use SSH keys instead of user/password
* add SAP HANA Large Instances
* add support for MD raids
* add support for ASCS clustering and app server config


## What will be checked
### VM Type
* Is VM type supported?

### OS Settings
* Is sapconf/saptune (SLES) or tuned-adm applied for SAP HANA?
* Are Azure NetApp Files (ANF) OS parameters applied?

### Linux Kernel
* Is there a known issue with a certain kernel version?

### Storage Layout
* Is the correct file system in use? (xfs)
* Is the stripe size used following the guidelines?

### High Availability
* Are you using the recommended settings for SBD/Fencing Agent settings?

### Load Balancing
* Are Load Balancer settings correct?

