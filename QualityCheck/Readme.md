# Quality Check for SAP on Azure

Current Version: V2

## Disclaimer

THE SCRIPTS ARE PROVIDED AS IS WITHOUT WARRANTY OF ANY KIND, EITHER EXPRESS OR IMPLIED, INCLUDING ANY IMPLIED WARRANTIES OF FITNESS FOR A PARTICULAR PURPOSE, MERCHANTABILITY, OR NON-INFRINGEMENT.

## Description

When installing SAP on Azure please follow our guidelines available [here](https://docs.microsoft.com/en-us/azure/virtual-machines/workloads/sap/get-started).
Please pay close attention to the storage layout for HANA systems available [here](https://docs.microsoft.com/en-us/azure/virtual-machines/workloads/sap/hana-vm-operations-storage).

The certified SAP HANA on Azure instances are available in the [Certified And Supported SAP HANA Hardware Directory](https://www.sap.com/dmc/exp/2014-09-02-hana-hardware/enEN/#/solutions?filters=iaas;ve:24)

## How does it work

Quality Check is a script that runs on Windows and Linux and connects to Azure and your SAP system.
It will query your system for required parameters and match it with Microsoft's best practice.

## What's required

* PowerShell 7.1 (PowerShell 5.1 works as well, version 7.1 or newer strongly recommended), you can download Powershell [here](https://aka.ms/powershell-release?tag=stable)
* Az Powershell Module (Az.Compute, Az.Network, Az.NetAppFiles, Az.Account)
* Posh-SSH Module available through PowerShell Gallery, thanks to [darkoperator](https://github.com/darkoperator/Posh-SSH)

To install the required modules you can use

```powershell
Install-Module Az -Force
Install-Module Az.NetAppFiles -Force
Install-Module Posh-SSH -Force
```

## How to run it

Download the PowerShell Script and put it into your preferred folder.
When downloading from GitHub please make sure you download the raw file.

Start PowerShell, install the requirements and then connect to Azure using

```powershell
Connect-AzAccount
```

also check if you selected the correct Context and Subscription.
For more help about Azure Powershell and how to connect please visit [this](https://github.com/Azure/azure-powershell) website.

Then simply run the script.

### Sample Commands

```powershell
. 'QualityCheck.ps1' -ResourceGroupName <ResourceGroupName for VMs> -SubscriptionName <subscription name> -AzVMname <Azure VM name> -vm_hostname <IP address or DNS name> -vm_username <OS user> -hanadeployment <ScaleUp or ScaleOut> -hanastoragetype <Premium or UltraDisk or ANF> -highavailability <$true or $false>
```

### Sample Output

### Full Help

```powershell
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

## What will be checked

### General

| *Check ID*            | VM-0001 |
|:----------------------|:--------|
| *Type*                | PowerShell |
| *Command*             | if (($_jsonconfig.SupportedVMs.$_VMType.$VMRole.SupportedDB -contains $VMDatabase) -eq $true) {1} else {0} |
| *Description*         | Is the VM Type support for SAP on Azure in this scenario |
| *OS*                  | SUSE, RedHat, OracleLinux |
| *VM Role*             | DB, ASCS, APP |
| *Database*            | HANA, Db2, Oracle, MSSQL |
| *High Availability*   | yes/no |
| *Expected Value*      | supported |
| *SAP Note*            | [1928533](https://launchpad.support.sap.com/#/notes/1928533) |
| *Microsoft link*      |  |
| *added/modified*      | initial version |  

| *Check ID*            | VM-0002 |
|:----------------------|:--------|
| *Type*                | PowerShell |
| *Command*             | if (($_jsonconfig.SupportedVMs.$_VMType.$VMRole.HANAScenario.$HANADeployment -like '*Sizing') -eq $true) {1} else {0}" |
| *Description*         | Is the VM Type support for the specified HANA workload |
| *OS*                  | SUSE, RedHat |
| *VM Role*             | DB |
| *Database*            | HANA |
| *High Availability*   | no/yes (SBD/FencingAgent) |
| *Expected Value*      | supported |
| *SAP Note*            | [1928533](https://launchpad.support.sap.com/#/notes/1928533) |
| *Microsoft link*      | SAP HANA Certified Hardware Directory, link [here](https://www.sap.com/dmc/exp/2014-09-02-hana-hardware/enEN/#/solutions?filters=iaas;ve:24) |
| *added/modified*      | initial version |

| *Check ID*            | VM-0003 |
|:----------------------|:--------|
| *Type*                | PowerShell |
| *Command*             | if (($_jsonconfig.SupportedOSDBCombinations.$VMDatabase.$VMRole -contains $VMOperatingSystem) -eq $true) {1} else {0} |
| *Description*         | Is OS/DB combination supported for SAP on Azure |
| *OS*                  | SUSE, RedHat, OracleLinux, Windows |
| *VM Role*             | DB, ASCS, APP |
| *Database*            | HANA, Db2, Oracle, MSSQL |
| *High Availability*   | no/yes (SBD/FencingAgent) |
| *Expected Value*      | supported |
| *SAP Note*            | [1928533](https://launchpad.support.sap.com/#/notes/1928533) |
| *Microsoft link*      | |
| *added/modified*      | initial version |

| *Check ID*            | VM-0004 |
|:----------------------|:--------|
| *Type*                | PowerShell |
| *Command*             | if (($script:_NetworkInterfaces | Where-Object { $_.AcceleratedNetworking -eq $false } | Measure-Object).Count -eq 0) { 'OK' } else { 'ERROR'} |
| *Description*         | Check if Accelerated Networking is enabled on all interfaces |
| *OS*                  | SUSE, RedHat, OracleLinux, Windows |
| *VM Role*             | DB, ASCS, APP |
| *Database*            | HANA, Db2, Oracle, MSSQL |
| *High Availability*   | no/yes (SBD/FencingAgent) |
| *Expected Value*      | supported |
| *SAP Note*            | [1928533](https://launchpad.support.sap.com/#/notes/1928533) |
| *Microsoft link*      | |
| *added/modified*      | initial version |

| *Check ID*            | OS-0001 |
|:----------------------|:--------|
| *Type*                | OS |
| *Command*             | systemctl &#124; grep fstrim &#124; grep active &#124; wc -l |
| *Description*         | fstrim disabled |
| *OS*                  | SLES, RedHat, OracleLinux |
| *VM Role*             | DB |
| *Database*            | HANA |
| *High Availability*   | n/a |
| *Expected Value*      | fstrim should be disabled |
| *SAP Note*            | |
| *Microsoft link*      | |
| *added/modified*      | initial version |

### ASCS

| *Check ID*            | ASCS-NET-0001 |
|:----------------------|:--------|
| *Type*                | OS |
| *Command*             | sysctl net.ipv4.tcp_timestamps |
| *Description*         | Timestamp parameter for HA Load Balancers |
| *OS*                  | SUSE, RedHat |
| *VM Role*             | ASCS |
| *Database*            | HANA, Db2, Oracle |
| *High Availability*   | yes (SBD/FencingAgent) |
| *Expected Value*      | 0 |
| *SAP Note*            | [2382421](https://launchpad.support.sap.com/#/notes/2382421) |
| *Microsoft link*      | multiple links, e.g. [here](https://docs.microsoft.com/en-us/azure/virtual-machines/workloads/sap/high-availability-guide-suse-nfs-azure-files) for SUSE and [here](https://docs.microsoft.com/en-us/azure/virtual-machines/workloads/sap/high-availability-guide-rhel-nfs-azure-files) for RedHat |
| *added/modified*      | initial version |  

### Database General

| *Check ID*            | DB-NET-0001 |
|:----------------------|:--------|
| *Type*                | OS |
| *Command*             | sysctl net.ipv4.tcp_timestamps |
| *Description*         | Timestamp parameter for HA Load Balancers |
| *OS*                  | SUSE, RedHat |
| *VM Role*             | DB |
| *Database*            | HANA, Db2 |
| *High Availability*   | yes (SBD/FencingAgent) |
| *Expected Value*      | 0 |
| *SAP Note*            | [2382421](https://launchpad.support.sap.com/#/notes/2382421) |
| *Microsoft link*      | multiple docs sites, e.g. [here](https://docs.microsoft.com/en-us/azure/virtual-machines/workloads/sap/high-availability-guide-suse-nfs-azure-files) |
| *added/modified*      | initial version |

### HANA

| *Check ID*            | HDB-OS-0001 |
|:----------------------|:--------|
| *Type*                | OS |
| *Command*             | sysctl net.ipv4.ip_local_port_range |
| *Description*         | Optimizing the Network Configuration on HANA- and OS-Level |
| *OS*                  | SUSE, RedHat |
| *VM Role*             | DB |
| *Database*            | HANA |
| *High Availability*   | no/yes (SBD/FencingAgent) |
| *Expected Value*      | 9000 65499 |
| *SAP Note*            | [2382421](https://launchpad.support.sap.com/#/notes/2382421) |
| *Microsoft link*      | |
| *added/modified*      | initial version |  

| *Check ID*            | HDB-OS-0002 |
|:----------------------|:--------|
| *Type*                | OS |
| *Command*             | free &#124; grep Swap &#124; awk '{print $2}' |
| *Description*         | swap space |
| *OS*                  | SUSE, RedHat |
| *VM Role*             | DB |
| *Database*            | HANA |
| *High Availability*   | no/yes (SBD/FencingAgent) |
| *Expected Value*      | 2GB |
| *SAP Note*            | [1999997](https://launchpad.support.sap.com/#/notes/1999997) |
| *Microsoft link*      | |
| *added/modified*      | initial version | 

| *Check ID*            | HDB-ANF-0001 |
|:----------------------|:--------|
| *Type*                | OS |
| *Command*             | sysctl net.core.rmem_max |
| *Description*         | OS parameter for ANF performance |
| *OS*                  | SUSE, RedHat |
| *VM Role*             | DB |
| *Database*            | HANA |
| *High Availability*   | no/yes (SBD/FencingAgent) |
| *Expected Value*      | 16777216 |
| *SAP Note*            | |
| *Microsoft link*      | multiple docs sites, e.g. [here](https://docs.microsoft.com/en-us/azure/virtual-machines/workloads/sap/sap-hana-scale-out-standby-netapp-files-suse) |
| *added/modified*      | initial version |

| *Check ID*            | HDB-ANF-0002 |
|:----------------------|:--------|
| *Type*                | OS |
| *Command*             | sysctl net.core.wmem_max |
| *Description*         | OS parameter for ANF performance |
| *OS*                  | SUSE, RedHat |
| *VM Role*             | DB |
| *Database*            | HANA |
| *High Availability*   | no/yes (SBD/FencingAgent) |
| *Expected Value*      | 16777216 |
| *SAP Note*            | |
| *Microsoft link*      | multiple docs sites, e.g. [here](https://docs.microsoft.com/en-us/azure/virtual-machines/workloads/sap/sap-hana-scale-out-standby-netapp-files-suse) |
| *added/modified*      | initial version |

| *Check ID*            | HDB-ANF-0003 |
|:----------------------|:--------|
| *Type*                | OS |
| *Command*             | sysctl net.core.rmem_default |
| *Description*         | OS parameter for ANF performance |
| *OS*                  | SUSE, RedHat |
| *VM Role*             | DB |
| *Database*            | HANA |
| *High Availability*   | no/yes (SBD/FencingAgent) |
| *Expected Value*      | 16777216 |
| *SAP Note*            | |
| *Microsoft link*      | multiple docs sites, e.g. [here](https://docs.microsoft.com/en-us/azure/virtual-machines/workloads/sap/sap-hana-scale-out-standby-netapp-files-suse) |
| *added/modified*      | initial version |

| *Check ID*            | HDB-ANF-0004 |
|:----------------------|:--------|
| *Type*                | OS |
| *Command*             | sysctl net.core.wmem_default |
| *Description*         | OS parameter for ANF performance |
| *OS*                  | SUSE, RedHat |
| *VM Role*             | DB |
| *Database*            | HANA |
| *High Availability*   | no/yes (SBD/FencingAgent) |
| *Expected Value*      | 16777216 |
| *SAP Note*            | |
| *Microsoft link*      | multiple docs sites, e.g. [here](https://docs.microsoft.com/en-us/azure/virtual-machines/workloads/sap/sap-hana-scale-out-standby-netapp-files-suse) |
| *added/modified*      | initial version |

| *Check ID*            | HDB-ANF-0005 |
|:----------------------|:--------|
| *Type*                | OS |
| *Command*             | sysctl net.core.optmem_max |
| *Description*         | OS parameter for ANF performance |
| *OS*                  | SUSE, RedHat |
| *VM Role*             | DB |
| *Database*            | HANA |
| *High Availability*   | no/yes (SBD/FencingAgent) |
| *Expected Value*      | 16777216 |
| *SAP Note*            | |
| *Microsoft link*      | multiple docs sites, e.g. [here](https://docs.microsoft.com/en-us/azure/virtual-machines/workloads/sap/sap-hana-scale-out-standby-netapp-files-suse) |
| *added/modified*      | initial version |

| *Check ID*            | HDB-ANF-0006 |
|:----------------------|:--------|
| *Type*                | OS |
| *Command*             | sysctl net.ipv4.tcp_rmem |
| *Description*         | OS parameter for ANF performance |
| *OS*                  | SUSE, RedHat |
| *VM Role*             | DB |
| *Database*            | HANA |
| *High Availability*   | no/yes (SBD/FencingAgent) |
| *Expected Value*      | 65536 16777216 16777216 |
| *SAP Note*            | |
| *Microsoft link*      | multiple docs sites, e.g. [here](https://docs.microsoft.com/en-us/azure/virtual-machines/workloads/sap/sap-hana-scale-out-standby-netapp-files-suse) |
| *added/modified*      | initial version |

| *Check ID*            | HDB-ANF-0007 |
|:----------------------|:--------|
| *Type*                | OS |
| *Command*             | sysctl net.ipv4.tcp_wmem |
| *Description*         | OS parameter for ANF performance |
| *OS*                  | SUSE, RedHat |
| *VM Role*             | DB |
| *Database*            | HANA |
| *High Availability*   | no/yes (SBD/FencingAgent) |
| *Expected Value*      | 65536 16777216 16777216 |
| *SAP Note*            | |
| *Microsoft link*      | multiple docs sites, e.g. [here](https://docs.microsoft.com/en-us/azure/virtual-machines/workloads/sap/sap-hana-scale-out-standby-netapp-files-suse) |
| *added/modified*      | initial version |

| *Check ID*            | HDB-ANF-0008 |
|:----------------------|:--------|
| *Type*                | OS |
| *Command*             | sysctl net.core.netdev_max_backlog |
| *Description*         | OS parameter for ANF performance |
| *OS*                  | SUSE, RedHat |
| *VM Role*             | DB |
| *Database*            | HANA |
| *High Availability*   | no/yes (SBD/FencingAgent) |
| *Expected Value*      | 300000 |
| *SAP Note*            | |
| *Microsoft link*      | multiple docs sites, e.g. [here](https://docs.microsoft.com/en-us/azure/virtual-machines/workloads/sap/sap-hana-scale-out-standby-netapp-files-suse) |
| *added/modified*      | initial version |

| *Check ID*            | HDB-ANF-0009 |
|:----------------------|:--------|
| *Type*                | OS |
| *Command*             | sysctl net.ipv4.tcp_slow_start_after_idle |
| *Description*         | OS parameter for ANF performance |
| *OS*                  | SUSE, RedHat |
| *VM Role*             | DB |
| *Database*            | HANA |
| *High Availability*   | no/yes (SBD/FencingAgent) |
| *Expected Value*      | 0 |
| *SAP Note*            | |
| *Microsoft link*      | multiple docs sites, e.g. [here](https://docs.microsoft.com/en-us/azure/virtual-machines/workloads/sap/sap-hana-scale-out-standby-netapp-files-suse) |
| *added/modified*      | initial version |

| *Check ID*            | HDB-ANF-0010 |
|:----------------------|:--------|
| *Type*                | OS |
| *Command*             | sysctl net.ipv4.tcp_moderate_rcvbuf |
| *Description*         | OS parameter for ANF performance |
| *OS*                  | SUSE, RedHat |
| *VM Role*             | DB |
| *Database*            | HANA |
| *High Availability*   | no/yes (SBD/FencingAgent) |
| *Expected Value*      | 1 |
| *SAP Note*            | |
| *Microsoft link*      | multiple docs sites, e.g. [here](https://docs.microsoft.com/en-us/azure/virtual-machines/workloads/sap/sap-hana-scale-out-standby-netapp-files-suse) |
| *added/modified*      | initial version |

| *Check ID*            | HDB-ANF-0011 |
|:----------------------|:--------|
| *Type*                | OS |
| *Command*             | sysctl net.ipv4.tcp_window_scaling |
| *Description*         | OS parameter for ANF performance |
| *OS*                  | SUSE, RedHat |
| *VM Role*             | DB |
| *Database*            | HANA |
| *High Availability*   | no/yes (SBD/FencingAgent) |
| *Expected Value*      | 1 |
| *SAP Note*            | |
| *Microsoft link*      | multiple docs sites, e.g. [here](https://docs.microsoft.com/en-us/azure/virtual-machines/workloads/sap/sap-hana-scale-out-standby-netapp-files-suse) |
| *added/modified*      | initial version |

| *Check ID*            | HDB-ANF-0012 |
|:----------------------|:--------|
| *Type*                | OS |
| *Command*             | sysctl net.ipv4.tcp_timestamps |
| *Description*         | OS parameter for ANF performance |
| *OS*                  | SUSE, RedHat |
| *VM Role*             | DB |
| *Database*            | HANA (Scale-Out) |
| *High Availability*   | no |
| *Expected Value*      | 1 |
| *SAP Note*            | |
| *Microsoft link*      | multiple docs sites, e.g. [here](https://docs.microsoft.com/en-us/azure/virtual-machines/workloads/sap/sap-hana-scale-out-standby-netapp-files-suse) |
| *added/modified*      | initial version |

| *Check ID*            | HDB-ANF-0013 |
|:----------------------|:--------|
| *Type*                | OS |
| *Command*             | sysctl net.ipv4.tcp_timestamps |
| *Description*         | OS parameter for ANF performance |
| *OS*                  | SUSE, RedHat |
| *VM Role*             | DB |
| *Database*            | HANA (Scale-Out) |
| *High Availability*   | yes (SBD/FencingAgent) |
| *Expected Value*      | 0 |
| *SAP Note*            | |
| *Microsoft link*      | multiple docs sites, e.g. [here](https://docs.microsoft.com/en-us/azure/virtual-machines/workloads/sap/sap-hana-scale-out-standby-netapp-files-suse) |
| *added/modified*      | initial version |

| *Check ID*            | HDB-ANF-0014 |
|:----------------------|:--------|
| *Type*                | OS |
| *Command*             | sysctl net.ipv4.tcp_sack |
| *Description*         | OS parameter for ANF performance |
| *OS*                  | SUSE, RedHat |
| *VM Role*             | DB |
| *Database*            | HANA |
| *High Availability*   | no/yes (SBD/FencingAgent) |
| *Expected Value*      | 1 |
| *SAP Note*            | |
| *Microsoft link*      | multiple docs sites, e.g. [here](https://docs.microsoft.com/en-us/azure/virtual-machines/workloads/sap/sap-hana-scale-out-standby-netapp-files-suse) |
| *added/modified*      | initial version |

| *Check ID*            | HDB-ANF-0015 |
|:----------------------|:--------|
| *Type*                | OS |
| *Command*             | sysctl ipv6.conf.all.disable_ipv6 |
| *Description*         | OS parameter for ANF performance |
| *OS*                  | SUSE, RedHat |
| *VM Role*             | DB |
| *Database*            | HANA |
| *High Availability*   | no/yes (SBD/FencingAgent) |
| *Expected Value*      | 1 |
| *SAP Note*            | |
| *Microsoft link*      | multiple docs sites, e.g. [here](https://docs.microsoft.com/en-us/azure/virtual-machines/workloads/sap/sap-hana-scale-out-standby-netapp-files-suse) |
| *added/modified*      | initial version |

| *Check ID*            | HDB-ANF-0016 |
|:----------------------|:--------|
| *Type*                | OS |
| *Command*             | sysctl net.ipv4.tcp_max_syn_backlog |
| *Description*         | OS parameter for ANF performance |
| *OS*                  | SUSE, RedHat |
| *VM Role*             | DB |
| *Database*            | HANA |
| *High Availability*   | no/yes (SBD/FencingAgent) |
| *Expected Value*      | 16348 |
| *SAP Note*            | |
| *Microsoft link*      | multiple docs sites, e.g. [here](https://docs.microsoft.com/en-us/azure/virtual-machines/workloads/sap/sap-hana-scale-out-standby-netapp-files-suse) |
| *added/modified*      | initial version |

| *Check ID*            | HDB-ANF-0017 |
|:----------------------|:--------|
| *Type*                | OS |
| *Command*             | sysctl net.ipv4.ip_local_port_range |
| *Description*         | OS parameter for ANF performance |
| *OS*                  | SUSE, RedHat |
| *VM Role*             | DB |
| *Database*            | HANA |
| *High Availability*   | no/yes (SBD/FencingAgent) |
| *Expected Value*      | 9000 65499 |
| *SAP Note*            | |
| *Microsoft link*      | multiple docs sites, e.g. [here](https://docs.microsoft.com/en-us/azure/virtual-machines/workloads/sap/sap-hana-scale-out-standby-netapp-files-suse) |
| *added/modified*      | initial version |

| *Check ID*            | HDB-ANF-0018 |
|:----------------------|:--------|
| *Type*                | OS |
| *Command*             | sysctl net.ipv4.conf.all.rp_filter |
| *Description*         | OS parameter for ANF performance |
| *OS*                  | SUSE, RedHat |
| *VM Role*             | DB |
| *Database*            | HANA |
| *High Availability*   | no/yes (SBD/FencingAgent) |
| *Expected Value*      | 0 |
| *SAP Note*            | |
| *Microsoft link*      | multiple docs sites, e.g. [here](https://docs.microsoft.com/en-us/azure/virtual-machines/workloads/sap/sap-hana-scale-out-standby-netapp-files-suse) |
| *added/modified*      | initial version |

| *Check ID*            | HDB-ANF-0019 |
|:----------------------|:--------|
| *Type*                | OS |
| *Command*             | sysctl sunrpc.tcp_slot_table_entries |
| *Description*         | OS parameter for ANF performance |
| *OS*                  | SUSE, RedHat |
| *VM Role*             | DB |
| *Database*            | HANA |
| *High Availability*   | no/yes (SBD/FencingAgent) |
| *Expected Value*      | 128 |
| *SAP Note*            | |
| *Microsoft link*      | multiple docs sites, e.g. [here](https://docs.microsoft.com/en-us/azure/virtual-machines/workloads/sap/sap-hana-scale-out-standby-netapp-files-suse) |
| *added/modified*      | initial version |

| *Check ID*            | HDB-ANF-0020 |
|:----------------------|:--------|
| *Type*                | OS |
| *Command*             | sysctl vm.swappiness |
| *Description*         | OS parameter for ANF performance |
| *OS*                  | SUSE, RedHat |
| *VM Role*             | DB |
| *Database*            | HANA |
| *High Availability*   | no/yes (SBD/FencingAgent) |
| *Expected Value*      | 10 |
| *SAP Note*            | |
| *Microsoft link*      | multiple docs sites, e.g. [here](https://docs.microsoft.com/en-us/azure/virtual-machines/workloads/sap/sap-hana-scale-out-standby-netapp-files-suse) |
| *added/modified*      | initial version |

| *Check ID*            | HDB-ANF-0021 |
|:----------------------|:--------|
| *Type*                | OS |
| *Command*             | cat /etc/modprobe.d/* &#124; grep tcp_max_slot_table_entries |
| *Description*         | OS parameter for ANF performance |
| *OS*                  | SUSE, RedHat |
| *VM Role*             | DB |
| *Database*            | HANA |
| *High Availability*   | no/yes (SBD/FencingAgent) |
| *Expected Value*      | options sunrpc tcp_max_slot_table_entries=128 |
| *SAP Note*            | |
| *Microsoft link*      | multiple docs sites, e.g. [here](https://docs.microsoft.com/en-us/azure/virtual-machines/workloads/sap/sap-hana-scale-out-standby-netapp-files-suse) |
| *added/modified*      | initial version |

| *Check ID*            | HDB-RH-0001 |
|:----------------------|:--------|
| *Type*                | OS |
| *Command*             | tuned-adm active |
| *Description*         | OS parameter for ANF performance |
| *OS*                  | RedHat |
| *VM Role*             | DB |
| *Database*            | HANA |
| *High Availability*   | no/yes (SBD/FencingAgent) |
| *Expected Value*      | Current active profile: sap-hana |
| *SAP Note*            | |
| *Microsoft link*      | multiple docs sites, e.g. [here](https://docs.microsoft.com/en-us/azure/virtual-machines/workloads/sap/sap-hana-scale-out-standby-netapp-files-suse) |
| *added/modified*      | initial version |

| *Check ID*            | HDB-HA-SLE-0001 |
|:----------------------|:--------|
| *Type*                | OS |
| *Command*             | crm configure show &#124; grep 'PREFER_SITE_TAKEOVER=true' &#124; wc -l |
| *Description*         | SAP HANA Automatic Site Takeover |
| *OS*                  | SUSE |
| *VM Role*             | DB |
| *Database*            | HANA |
| *High Availability*   | yes (SBD/FencingAgent) |
| *Expected Value*      | 1 |
| *SAP Note*            | |
| *Microsoft link*      | multiple docs sites, e.g. [here](https://docs.microsoft.com/en-us/azure/virtual-machines/workloads/sap/sap-hana-high-availability) |
| *added/modified*      | initial version |

| *Check ID*            | HDB-HA-SLE-0002 |
|:----------------------|:--------|
| *Type*                | OS |
| *Command*             | crm configure show &#124; grep 'AUTOMATED_REGISTER=true' &#124; wc -l |
| *Description*         | SAP HANA Automated Register |
| *OS*                  | SUSE |
| *VM Role*             | DB |
| *Database*            | HANA |
| *High Availability*   | yes (SBD/FencingAgent) |
| *Expected Value*      | 1 |
| *SAP Note*            | |
| *Microsoft link*      | multiple docs sites, e.g. [here](https://docs.microsoft.com/en-us/azure/virtual-machines/workloads/sap/sap-hana-high-availability) |
| *added/modified*      | initial version |

| *Check ID*            | HDB-HA-SLE-0003 |
|:----------------------|:--------|
| *Type*                | OS |
| *Command*             | crm configure show &#124; grep 'stonith-enabled=true' &#124; wc -l |
| *Description*         | Pacemaker Stonith enabled |
| *OS*                  | SUSE |
| *VM Role*             | DB |
| *Database*            | HANA |
| *High Availability*   | yes (SBD/FencingAgent) |
| *Expected Value*      | 1 |
| *SAP Note*            | |
| *Microsoft link*      | multiple docs sites, e.g. [here](https://docs.microsoft.com/en-us/azure/virtual-machines/workloads/sap/sap-hana-high-availability) |
| *added/modified*      | initial version |

| *Check ID*            | HDB-HA-SLE-0004 |
|:----------------------|:--------|
| *Type*                | OS |
| *Command*             | crm configure show &#124; grep 'stonith-timeout=144' &#124; wc -l |
| *Description*         | Pacemaker Stonith timeout |
| *OS*                  | SUSE |
| *VM Role*             | DB |
| *Database*            | HANA |
| *High Availability*   | yes (SBD) |
| *Expected Value*      | stonith-timeout=144 |
| *SAP Note*            | |
| *Microsoft link*      | multiple docs sites, e.g. [here](https://docs.microsoft.com/en-us/azure/virtual-machines/workloads/sap/sap-hana-high-availability) |
| *added/modified*      | initial version |

| *Check ID*            | HDB-HA-SLE-0005 |
|:----------------------|:--------|
| *Type*                | OS |
| *Command*             | crm corosync get totem.token |
| *Description*         | Pacemaker corosync token |
| *OS*                  | SUSE |
| *VM Role*             | DB |
| *Database*            | HANA |
| *High Availability*   | yes (SBD/FencingAgent) |
| *Expected Value*      | 30000 |
| *SAP Note*            | |
| *Microsoft link*      | multiple docs sites, e.g. [here](https://docs.microsoft.com/en-us/azure/virtual-machines/workloads/sap/sap-hana-high-availability) |
| *added/modified*      | initial version |

| *Check ID*            | HDB-HA-SLE-0006 |
|:----------------------|:--------|
| *Type*                | OS |
| *Command*             | crm corosync get totem.token_retransmits_before_loss_const |
| *Description*         | Pacemaker totem.token_retransmits_before_loss_const |
| *OS*                  | SUSE |
| *VM Role*             | DB |
| *Database*            | HANA |
| *High Availability*   | yes (SBD/FencingAgent) |
| *Expected Value*      | 10 |
| *SAP Note*            | |
| *Microsoft link*      | multiple docs sites, e.g. [here](https://docs.microsoft.com/en-us/azure/virtual-machines/workloads/sap/sap-hana-high-availability) |
| *added/modified*      | initial version |

| *Check ID*            | HDB-HA-SLE-0007 |
|:----------------------|:--------|
| *Type*                | OS |
| *Command*             | crm corosync get totem.join |
| *Description*         | Pacemaker corosync join |
| *OS*                  | SUSE |
| *VM Role*             | DB |
| *Database*            | HANA |
| *High Availability*   | yes (SBD/FencingAgent) |
| *Expected Value*      | 60 |
| *SAP Note*            | |
| *Microsoft link*      | multiple docs sites, e.g. [here](https://docs.microsoft.com/en-us/azure/virtual-machines/workloads/sap/sap-hana-high-availability) |
| *added/modified*      | initial version |

| *Check ID*            | HDB-HA-SLE-0008 |
|:----------------------|:--------|
| *Type*                | OS |
| *Command*             | crm corosync get totem.consensus |
| *Description*         | Pacemaker corosync consensus |
| *OS*                  | SUSE |
| *VM Role*             | DB |
| *Database*            | HANA |
| *High Availability*   | yes (SBD/FencingAgent) |
| *Expected Value*      | 36000 |
| *SAP Note*            | |
| *Microsoft link*      | multiple docs sites, e.g. [here](https://docs.microsoft.com/en-us/azure/virtual-machines/workloads/sap/sap-hana-high-availability) |
| *added/modified*      | initial version |

| *Check ID*            | HDB-HA-SLE-0009 |
|:----------------------|:--------|
| *Type*                | OS |
| *Command*             | crm corosync get totem.max_messages |
| *Description*         | Pacemaker corosync max_messages |
| *OS*                  | SUSE |
| *VM Role*             | DB |
| *Database*            | HANA |
| *High Availability*   | yes (SBD/FencingAgent) |
| *Expected Value*      | 20 |
| *SAP Note*            | |
| *Microsoft link*      | multiple docs sites, e.g. [here](https://docs.microsoft.com/en-us/azure/virtual-machines/workloads/sap/sap-hana-high-availability) |
| *added/modified*      | initial version |

| *Check ID*            | HDB-HA-SLE-0010 |
|:----------------------|:--------|
| *Type*                | OS |
| *Command*             | crm corosync get quorum.expected_votes |
| *Description*         | Pacemaker corosync expected_votes |
| *OS*                  | SUSE |
| *VM Role*             | DB |
| *Database*            | HANA |
| *High Availability*   | yes (SBD/FencingAgent) |
| *Expected Value*      | 2 |
| *SAP Note*            | |
| *Microsoft link*      | multiple docs sites, e.g. [here](https://docs.microsoft.com/en-us/azure/virtual-machines/workloads/sap/sap-hana-high-availability) |
| *added/modified*      | initial version |

| *Check ID*            | HDB-HA-SLE-0011 |
|:----------------------|:--------|
| *Type*                | OS |
| *Command*             | crm corosync get quorum.two_node |
| *Description*         | Pacemaker corosync two_node |
| *OS*                  | SUSE |
| *VM Role*             | DB |
| *Database*            | HANA |
| *High Availability*   | yes (SBD/FencingAgent) |
| *Expected Value*      | 1 |
| *SAP Note*            | |
| *Microsoft link*      | multiple docs sites, e.g. [here](https://docs.microsoft.com/en-us/azure/virtual-machines/workloads/sap/sap-hana-high-availability) |
| *added/modified*      | initial version |

| *Check ID*            | HDB-HA-SLE-0012 |
|:----------------------|:--------|
| *Type*                | OS |
| *Command*             | see json, complex command, command loops through sbdconfig and queries sbd devices for correct values |
| *Description*         | Pacemaker watchdog timeout |
| *OS*                  | SUSE |
| *VM Role*             | DB |
| *Database*            | HANA |
| *High Availability*   | yes (SBD) |
| *Expected Value*      | Timeout (watchdog) : 60 |
| *SAP Note*            | |
| *Microsoft link*      | multiple docs sites, e.g. [here](https://docs.microsoft.com/en-us/azure/virtual-machines/workloads/sap/sap-hana-high-availability) |
| *added/modified*      | initial version |

| *Check ID*            | HDB-HA-SLE-0013 |
|:----------------------|:--------|
| *Type*                | OS |
| *Command*             | see json, complex command, command loops through sbdconfig and queries sbd devices for correct values |
| *Description*         | Pacemaker msgwait timeout |
| *OS*                  | SUSE |
| *VM Role*             | DB |
| *Database*            | HANA |
| *High Availability*   | yes (SBD) |
| *Expected Value*      | Timeout (msgwait) : 120 |
| *SAP Note*            | |
| *Microsoft link*      | multiple docs sites, e.g. [here](https://docs.microsoft.com/en-us/azure/virtual-machines/workloads/sap/sap-hana-high-availability) |
| *added/modified*      | initial version |

| *Check ID*            | HDB-HA-SLE-0014 |
|:----------------------|:--------|
| *Type*                | OS |
| *Command*             | crm configure show &#124; grep 'concurrent-fencing: true' &#124; wc -l |
| *Description*         | Pacemaker concurrent fencing |
| *OS*                  | SUSE |
| *VM Role*             | DB |
| *Database*            | HANA |
| *High Availability*   | yes (FencingAgent) |
| *Expected Value*      | concurrent-fencing: true |
| *SAP Note*            | |
| *Microsoft link*      | multiple docs sites, e.g. [here](https://docs.microsoft.com/en-us/azure/virtual-machines/workloads/sap/sap-hana-high-availability) |
| *added/modified*      | initial version |

| *Check ID*            | HDB-HA-SLE-0015 |
|:----------------------|:--------|
| *Type*                | OS |
| *Command*             | crm config show &#124; grep 'stonith:fence_azure_arm' &#124; wc -l |
| *Description*         | Pacemaker number of fence_azure_arm instances |
| *OS*                  | SUSE |
| *VM Role*             | DB |
| *Database*            | HANA |
| *High Availability*   | yes (FencingAgent) |
| *Expected Value*      | 1 |
| *SAP Note*            | |
| *Microsoft link*      | multiple docs sites, e.g. [here](https://docs.microsoft.com/en-us/azure/virtual-machines/workloads/sap/sap-hana-high-availability) |
| *added/modified*      | initial version |

| *Check ID*            | HDB-HA-SLE-0016 |
|:----------------------|:--------|
| *Type*                | OS |
| *Command*             | crm configure show &#124; grep 'stonith-timeout=900' &#124; wc -l |
| *Description*         | Pacemaker Stonith timeout |
| *OS*                  | SUSE |
| *VM Role*             | DB |
| *Database*            | HANA |
| *High Availability*   | yes (FencingAgent) |
| *Expected Value*      | stonith-timeout=900 |
| *SAP Note*            | |
| *Microsoft link*      | multiple docs sites, e.g. [here](https://docs.microsoft.com/en-us/azure/virtual-machines/workloads/sap/sap-hana-high-availability) |
| *added/modified*      | initial version |

| *Check ID*            | HDB-HA-RH-0001 |
|:----------------------|:--------|
| *Type*                | OS |
| *Command*             | pcs config show &#124; grep 'PREFER_SITE_TAKEOVER=true' &#124; wc -l |
| *Description*         | SAP HANA Automatic Site Takeover |
| *OS*                  | RedHat |
| *VM Role*             | DB |
| *Database*            | HANA |
| *High Availability*   | yes (FencingAgent) |
| *Expected Value*      | PREFER_SITE_TAKEOVER=true |
| *SAP Note*            | |
| *Microsoft link*      | multiple docs sites, e.g. [here](https://docs.microsoft.com/en-us/azure/virtual-machines/workloads/sap/sap-hana-high-availability-rhel) |
| *added/modified*      | initial version |

| *Check ID*            | HDB-HA-RH-0002 |
|:----------------------|:--------|
| *Type*                | OS |
| *Command*             | pcs config show &#124; grep 'AUTOMATED_REGISTER=true' &#124; wc -l |
| *Description*         | SAP HANA Automated Register |
| *OS*                  | RedHat |
| *VM Role*             | DB |
| *Database*            | HANA |
| *High Availability*   | yes (FencingAgent) |
| *Expected Value*      | AUTOMATED_REGISTER=true |
| *SAP Note*            | |
| *Microsoft link*      | multiple docs sites, e.g. [here](https://docs.microsoft.com/en-us/azure/virtual-machines/workloads/sap/sap-hana-high-availability-rhel) |
| *added/modified*      | initial version |

| *Check ID*            | HDB-HA-RH-0003 |
|:----------------------|:--------|
| *Type*                | OS |
| *Command*             | pcs config show &#124; grep 'stonith-enabled: true' &#124; wc -l |
| *Description*         | Pacemaker Stonith |
| *OS*                  | RedHat |
| *VM Role*             | DB |
| *Database*            | HANA |
| *High Availability*   | yes (FencingAgent) |
| *Expected Value*      | stonith-enabled=true |
| *SAP Note*            | |
| *Microsoft link*      | multiple docs sites, e.g. [here](https://docs.microsoft.com/en-us/azure/virtual-machines/workloads/sap/sap-hana-high-availability-rhel) |
| *added/modified*      | initial version |

| *Check ID*            | HDB-HA-RH-0004 |
|:----------------------|:--------|
| *Type*                | OS |
| *Command*             | cat /etc/corosync/corosync.conf &#124; xargs &#124; grep 'token: 30000 ' &#124; wc -l |
| *Description*         | Pacemaker corosync token |
| *OS*                  | RedHat |
| *VM Role*             | DB |
| *Database*            | HANA |
| *High Availability*   | yes (FencingAgent) |
| *Expected Value*      | token: 30000 |
| *SAP Note*            | |
| *Microsoft link*      | multiple docs sites, e.g. [here](https://docs.microsoft.com/en-us/azure/virtual-machines/workloads/sap/sap-hana-high-availability-rhel) |
| *added/modified*      | initial version |

| *Check ID*            | HDB-HA-RH-0005 |
|:----------------------|:--------|
| *Type*                | OS |
| *Command*             | pcs quorum status &#124; xargs &#124; grep 'Expected votes: 2' &#124; wc -l |
| *Description*         | Pacemaker expected_votes |
| *OS*                  | RedHat |
| *VM Role*             | DB |
| *Database*            | HANA |
| *High Availability*   | yes (FencingAgent) |
| *Expected Value*      | Expected votes: 2 |
| *SAP Note*            | |
| *Microsoft link*      | multiple docs sites, e.g. [here](https://docs.microsoft.com/en-us/azure/virtual-machines/workloads/sap/sap-hana-high-availability-rhel) |
| *added/modified*      | initial version |

| *Check ID*            | HDB-HA-RH-0006 |
|:----------------------|:--------|
| *Type*                | OS |
| *Command*             | pcs config show &#124; grep 'concurrent-fencing: true' &#124; wc -l |
| *Description*         | Pacemaker concurrent-fencing |
| *OS*                  | RedHat |
| *VM Role*             | DB |
| *Database*            | HANA |
| *High Availability*   | yes (FencingAgent) |
| *Expected Value*      | concurrent-fencing: true |
| *SAP Note*            | |
| *Microsoft link*      | multiple docs sites, e.g. [here](https://docs.microsoft.com/en-us/azure/virtual-machines/workloads/sap/sap-hana-high-availability-rhel) |
| *added/modified*      | initial version |

| *Check ID*            | HDB-HA-LB-0001 |
|:----------------------|:--------|
| *Type*                | PowerShell |
| *Command*             | see code, complex command, checks all load balancers for timeout 30 |
| *Description*         | Load Balancer Idle Timeout |
| *OS*                  | SLES, RedHat |
| *VM Role*             | DB |
| *Database*            | HANA |
| *High Availability*   | no/yes (SBD/FencingAgent) |
| *Expected Value*      | Idle Timeout 30 |
| *SAP Note*            | |
| *Microsoft link*      | multiple docs sites, e.g. [here](https://docs.microsoft.com/en-us/azure/virtual-machines/workloads/sap/sap-hana-high-availability-rhel) |
| *added/modified*      | initial version |

| *Check ID*            | HDB-HA-LB-0002 |
|:----------------------|:--------|
| *Type*                | PowerShell |
| *Command*             | see code, complex command, checks all load balancers for floating IP enabled |
| *Description*         | Load Balancer Floating IP |
| *OS*                  | SLES, RedHat |
| *VM Role*             | DB |
| *Database*            | HANA |
| *High Availability*   | no/yes (SBD/FencingAgent) |
| *Expected Value*      | floating IP: true |
| *SAP Note*            | |
| *Microsoft link*      | multiple docs sites, e.g. [here](https://docs.microsoft.com/en-us/azure/virtual-machines/workloads/sap/sap-hana-high-availability-rhel) |
| *added/modified*      | initial version |

| *Check ID*            | HDB-HA-LB-0003 |
|:----------------------|:--------|
| *Type*                | PowerShell |
| *Command*             | see code, complex command, checks all load balancers for HA Ports enabled |
| *Description*         | Load Balancer Floating IP |
| *OS*                  | SLES, RedHat |
| *VM Role*             | DB |
| *Database*            | HANA |
| *High Availability*   | no/yes (SBD/FencingAgent) |
| *Expected Value*      | HA Ports: enabled |
| *SAP Note*            | |
| *Microsoft link*      | multiple docs sites, e.g. [here](https://docs.microsoft.com/en-us/azure/virtual-machines/workloads/sap/sap-hana-high-availability-rhel) |
| *added/modified*      | initial version |

| *Check ID*            | HDB-OS-SLES-0001 |
|:----------------------|:--------|
| *Type*                | PowerShell |
| *Command*             | using PowerShell function to determinate the Kernel Version and compare it |
| *Description*         | Backup fails for HANA on SLES 12.4 |
| *OS*                  | SLES |
| *VM Role*             | DB |
| *Database*            | HANA |
| *High Availability*   | no/yes (SBD/FencingAgent) |
| *Expected Value*      | Kernel version higher than 4.12.14-95.37.1 |
| *SAP Note*            | [2814271](https://launchpad.support.sap.com/#/notes/2814271) |
| *Microsoft link*      | |
| *added/modified*      | initial version |

| *Check ID*            | HDB-OS-SLES-0002 |
|:----------------------|:--------|
| *Type*                | PowerShell |
| *Command*             | using PowerShell function to determinate the Kernel Version and compare it |
| *Description*         | Backup fails for HANA on SLES 12.5 |
| *OS*                  | SLES |
| *VM Role*             | DB |
| *Database*            | HANA |
| *High Availability*   | no/yes (SBD/FencingAgent) |
| *Expected Value*      | Kernel version higher than 4.12.14-122.7.1 |
| *SAP Note*            | [2814271](https://launchpad.support.sap.com/#/notes/2814271) |
| *Microsoft link*      | |
| *added/modified*      | initial version |

| *Check ID*            | HDB-OS-SLES-0003 |
|:----------------------|:--------|
| *Type*                | PowerShell |
| *Command*             | using PowerShell function to determinate the Kernel Version and compare it |
| *Description*         | Backup fails for HANA on SLES 15 |
| *OS*                  | SLES |
| *VM Role*             | DB |
| *Database*            | HANA |
| *High Availability*   | no/yes (SBD/FencingAgent) |
| *Expected Value*      | Kernel version higher than 4.12.14-150.38.1 |
| *SAP Note*            | [2814271](https://launchpad.support.sap.com/#/notes/2814271) |
| *Microsoft link*      | |
| *added/modified*      | initial version |

| *Check ID*            | HDB-OS-SLES-0004 |
|:----------------------|:--------|
| *Type*                | PowerShell |
| *Command*             | using PowerShell function to determinate the Kernel Version and compare it |
| *Description*         | Backup fails for HANA on SLES 15.1 |
| *OS*                  | SLES |
| *VM Role*             | DB |
| *Database*            | HANA |
| *High Availability*   | no/yes (SBD/FencingAgent) |
| *Expected Value*      | Kernel version higher than 4.12.14-150.38.1 |
| *SAP Note*            | [2814271](https://launchpad.support.sap.com/#/notes/2814271) |
| *Microsoft link*      | |
| *added/modified*      | initial version |

| *Check ID*            | HDB-OS-SLES-0005 |
|:----------------------|:--------|
| *Type*                | PowerShell |
| *Command*             | using PowerShell function to determinate the Kernel Version and compare it |
| *Description*         | blk-mq issue when too many outstanding disk I/O in SLES 12.4 |
| *OS*                  | SLES |
| *VM Role*             | DB |
| *Database*            | HANA |
| *High Availability*   | no/yes (SBD/FencingAgent) |
| *Expected Value*      | Kernel version higher than 4.12.14-95.xx, set hv_storvsc.storvsc_ringbuffer_size=131072 and hv_storvsc.storvsc_vcpus_per_sub_channel=1024 in sysctl |
| *SAP Note*            | [2814271](https://launchpad.support.sap.com/#/notes/2814271) |
| *Microsoft link*      | |
| *added/modified*      | initial version |

### Application Server

| *Check ID*            | APP-OS-0001 |
|:----------------------|:--------|
| *Type*                | OS |
| *Command*             | sysctl net.ipv4.tcp_keepalive_time |
| *Description*         | IPv4 keepalive timer, optimize for faster reconnect after ASCS failover |
| *OS*                  | SLES, RedHat, OracleLinux |
| *VM Role*             | DB |
| *Database*            | HANA |
| *High Availability*   | n/a |
| *Expected Value*      | net.ipv4.tcp_keepalive_time = 120 |
| *SAP Note*            | |
| *Microsoft link*      | |
| *added/modified*      | initial version |

| *Check ID*            | APP-OS-0002 |
|:----------------------|:--------|
| *Type*                | OS |
| *Command*             | sysctl net.ipv4.tcp_retries2 |
| *Description*         | IPv4 keepalive timer, optimize for faster reconnect after ASCS failover |
| *OS*                  | SLES, RedHat, OracleLinux |
| *VM Role*             | DB |
| *Database*            | HANA |
| *High Availability*   | n/a |
| *Expected Value*      | net.ipv4.tcp_retries2 = 3 |
| *SAP Note*            | |
| *Microsoft link*      | |
| *added/modified*      | initial version |

| *Check ID*            | APP-OS-0003 |
|:----------------------|:--------|
| *Type*                | OS |
| *Command*             | sysctl net.ipv4.tcp_retries2 |
| *Description*         | IPv4 tcp_retries2, optimize for faster reconnect after ASCS failover |
| *OS*                  | SLES, RedHat, OracleLinux |
| *VM Role*             | DB |
| *Database*            | HANA |
| *High Availability*   | n/a |
| *Expected Value*      | net.ipv4.tcp_keepalive_intvl = 75 |
| *SAP Note*            | |
| *Microsoft link*      | |
| *added/modified*      | initial version |

| *Check ID*            | APP-OS-0004 |
|:----------------------|:--------|
| *Type*                | OS |
| *Command*             | sysctl net.ipv4.tcp_keepalive_probes |
| *Description*         | IPv4 tcp_keepalive_probes, optimize for faster reconnect after ASCS failover |
| *OS*                  | SLES, RedHat, OracleLinux |
| *VM Role*             | DB |
| *Database*            | HANA |
| *High Availability*   | n/a |
| *Expected Value*      | net.ipv4.tcp_keepalive_probes = 9 |
| *SAP Note*            | |
| *Microsoft link*      | |
| *added/modified*      | initial version |

| *Check ID*            | APP-OS-0005 |
|:----------------------|:--------|
| *Type*                | OS |
| *Command*             | sysctl net.ipv4.tcp_tw_recycle |
| *Description*         | IPv4 tcp_tw_recycle, optimize for faster reconnect after ASCS failover |
| *OS*                  | SLES, RedHat, OracleLinux |
| *VM Role*             | DB |
| *Database*            | HANA |
| *High Availability*   | n/a |
| *Expected Value*      | net.ipv4.tcp_tw_recycle = 0 |
| *SAP Note*            | |
| *Microsoft link*      | |
| *added/modified*      | initial version |

| *Check ID*            | APP-OS-0006 |
|:----------------------|:--------|
| *Type*                | OS |
| *Command*             | sysctl net.ipv4.tcp_tw_reuse |
| *Description*         | IPv4 tcp_tw_recycle, optimize for faster reconnect after ASCS failover |
| *OS*                  | SLES, RedHat, OracleLinux |
| *VM Role*             | DB |
| *Database*            | HANA |
| *High Availability*   | n/a |
| *Expected Value*      | net.ipv4.tcp_tw_reuse = 0 |
| *SAP Note*            | |
| *Microsoft link*      | |
| *added/modified*      | initial version |

| *Check ID*            | APP-OS-0007 |
|:----------------------|:--------|
| *Type*                | OS |
| *Command*             | sysctl tcp_retries1 |
| *Description*         | IPv4 tcp_retries1, optimize for faster reconnect after ASCS failover |
| *OS*                  | SLES, RedHat, OracleLinux |
| *VM Role*             | DB |
| *Database*            | HANA |
| *High Availability*   | n/a |
| *Expected Value*      | net.ipv4.tcp_retries1 = 3 |
| *SAP Note*            | |
| *Microsoft link*      | |
| *added/modified*      | initial version |
