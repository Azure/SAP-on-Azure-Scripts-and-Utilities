# Quality Check for SAP on Azure
Current Version: V1

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

