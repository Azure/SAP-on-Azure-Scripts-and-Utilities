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
Install-Module Az.AzureNetAppFiles -Force
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

```
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
|---------------------|--------|
| *Type*                | PowerShell  |
| *Command*             | see code |
| *Description*         | check if VM type is supported for SAP on Azure |
| *OS*                  | all |
| *VM Role*             | all |
| *Database*            | all |
| *High Availability*   | all |
| *Expected Value*      | supported |
| *SAP Note*            | 1928533 |
| *added/modified*      | initial version | 

### HANA

| *Check ID*            | HDB-OS-0001 |
|---------------------|--------|
| *Type*                | OS  |
| *Command*             | sysctl net.ipv4.ip_local_port_range |
| *Description*         | |
| *OS*                  | SUSE,RH |
| *VM Role*             | DB |
| *Database*            | HANA |
| *High Availability*   | yes/no |
| *Expected Value*      | 9000-65499 |
| *SAP Note*            | 1928533 |
| *Microsoft link*      | |
| *added/modified*      | initial version |  

| *Check ID*            | HDB-ANF-0001 |
|---------------------|--------|
| *Type*                | OS  |
| *Command*             | sysctl net.core.rmem_max |
| *Description*         | OS Performance parameters for ANF scenarios |
| *OS*                  | SUSE,RH |
| *VM Role*             | DB |
| *Database*            | HANA |
| *High Availability*   | yes/no |
| *Expected Value*      | 16777216 |
| *SAP Note*            | 1928533 |
| *Microsoft link*      | |
| *added/modified*      | initial version |  

