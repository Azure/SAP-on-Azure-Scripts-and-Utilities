### ⚠️ Important Notice: New Version Available ⚠️

**A new version of Quality Check called "Configuration Checks" is now available!**

🔗 **[Access the new Configuration Checks tool here](https://github.com/Azure/sap-automation-qa)**

**⏰ End of Support:** This QualityCheck tool will no longer be supported after **June 30, 2026**. Please migrate to the new Configuration Checks solution to continue receiving updates, bug fixes, and support.

**Why switch?** The new Configuration Checks tool offers enhanced features, better performance, and ongoing development support.

# Quality Check for SAP workloads on Azure

QualityCheck is an open-source tool to validate SAP on Azure installations. It connects to Azure Resource Manager and the operating system and validates the system configurations against Microsoft's best practise.
Running it regulary will always keep your system up to date.

QualityCheck supports SUSE, RedHat and Oracle Linux as well as HANA, Db2, ASE and Oracle Database configurations.

You can execute QualityCheck for database, ASCS and app servers.

We are continouasly improving the tool and will add e.g. support for Windows and MSSQL in the near future.

> If you have additional ideas on what to check please open an issue.

When installing SAP on Azure please follow our guidelines available [here](https://docs.microsoft.com/en-us/azure/virtual-machines/workloads/sap/get-started).
Please pay close attention to the storage layout for HANA systems available [here](https://docs.microsoft.com/en-us/azure/virtual-machines/workloads/sap/hana-vm-operations-storage).

The certified SAP HANA on Azure instances are available in the [Certified And Supported SAP HANA Hardware Directory](https://www.sap.com/dmc/exp/2014-09-02-hana-hardware/enEN/#/solutions?filters=iaas;ve:24)

Change Log is available [here](changelog.md)

## How does it work

Quality Check is a script that runs on Windows and Linux and connects to Azure and your SAP system.
It will query your system for required parameters and match it with Microsoft's best practice.

![qualitycheck-connect](images/qualitycheck-connect.jpg)

> There is no need to install any software on the SAP on Azure operating system.
>
> The commands are query only and don't change anything on the destination system.

## What's required on jumpbox

* PowerShell 7.2 or newer, you can download Powershell [here](https://aka.ms/powershell-release?tag=stable)
* Azure Az Powershell Module (Az.Compute, Az.Network, Az.NetAppFiles, Az.Account)
* Posh-SSH Module available through PowerShell Gallery, thanks to [darkoperator](https://github.com/darkoperator/Posh-SSH)

## Getting Started on jumpbox

A jumpbox could be a special VM to access your SAP system or your local machine, we'll just call ist jumpbox.

1. Install PowerShell 7.2 or newer
    * Windows

        To install Powershell on Windows use the link below, after installation search for "PowerShell 7" from the Start Menu

        [https://docs.microsoft.com/en-us/powershell/scripting/install/installing-powershell-on-windows](https://docs.microsoft.com/en-us/powershell/scripting/install/installing-powershell-on-windows)

    * Linux

        Download PowerShell 7 using the link and installation guide below.

        [https://docs.microsoft.com/en-us/powershell/scripting/install/installing-powershell-on-linux](https://docs.microsoft.com/en-us/powershell/scripting/install/installing-powershell-on-linux)

        After installing PowerShell start it using the command pwsh

        ```bash
        pwsh
        ```

        Due to license constraints Microsoft doesn't provide PowerShell for SUSE operating systems.

    * Mac

        Download and install PowerShell 7 on Mac using the link bwlow.

        [https://docs.microsoft.com/en-us/powershell/scripting/install/installing-powershell-on-macos](https://docs.microsoft.com/en-us/powershell/scripting/install/installing-powershell-on-macos)

2. After starting PowerShell you need to install the required PowerShell modules using:

    ```powershell
    Install-Module Az -Force
    Install-Module Az.NetAppFiles -Force
    Install-Module Posh-SSH -Force
    ```

    > Note that Install-Module Az -Force may take over 15 minutes to complete

3. Set the Execution Policy to unrestricted (we are working on signing the script)

    ```powershell
    Set-ExecutionPolicy Unrestricted
    ```

4. Sign in to Azure Resource Manager using

    ```powershell
    Connect-AzAccount
    ```

5. Connect to the correct subscription (see [here](https://docs.microsoft.com/en-us/powershell/module/servicemanagement/azure.service/select-azuresubscription?view=azuresmps-4.0.0) for details)

    ```powershell
    Select-AzSubscription -SubscriptionName 'your-subscription-name'
    ```

    OR

    ```powershell
    Select-AzSubscription -SubscriptionId 'your-subscription-id'
    ```

6. Download the script

    * Option 1: Clone the GitHub repo using

        ```bash
        git clone https://github.com/Azure/SAP-on-Azure-Scripts-and-Utilities.git
        ```

    * Option 2: Download the required script files using wget or curl

        ```bash
        wget https://raw.githubusercontent.com/Azure/SAP-on-Azure-Scripts-and-Utilities/main/QualityCheck/QualityCheck.ps1
        wget https://raw.githubusercontent.com/Azure/SAP-on-Azure-Scripts-and-Utilities/main/QualityCheck/QualityCheck.json
        ```

    * Option 3: Download ZIP file from GitHub and extract it on your jumpbox

        You can directly download the latest ZIP file [here](https://github.com/Azure/SAP-on-Azure-Scripts-and-Utilities/archive/refs/heads/main.zip)

### Sample Commands

#### Use the GUI

```powershell
.\QualityCheck.ps1 -GUI
```

#### User Quality Check MultiRun

You can run check multiple systems at the same time by providing a csv file (separated with semicolon) using the Excel template.

As of now only User/Password authentication is supported and it needs to be the same password for all VMs that you want to check at one time.

After exporting it to a csv file you can start Quality Check using

```powershell
.\QualityCheck.ps1  -MultiRun -ImportFile filename.csv
```

If a check fails it will continue with the next entry.

#### Logon with Username and Password

```powershell
.\QualityCheck.ps1 -LogonWithUserPassword -VMOperatingSystem Windows,SUSE,RedHat,OracleLinux -VMDatabase HANA,Oracle,MSSQL,Db2,ASE -VMRole DB,ASCS,APP -AzVMResourceGroup resourcegroupname -AzVMName AzureVMName -VMHostname hostname or ip address -VMUsername username [-HighAvailability $true or $false] [-VMConnectionPort 22>] [-DBDataDir /hana/data] [-DBLogDir /hana/log] [-DBSharedDir /hana/shared] [-ANFResourceGroup resourcegroup-for-anf] [-ANFAccountName anf-account-name] [-Hardwaretype VM] [-HANADeployment OLTP,OLAP,OLTP-ScaleOut,OLAP-ScaleOut] [-HighAvailabilityAgent SBD,FencingAgent]
```

#### Login with SSH Keys (no password required for sudo)

```powershell
.\QualityCheck.ps1 -LogonWithUserSSHKey -VMOperatingSystem Windows,SUSE,RedHat,OracleLinux -VMDatabase HANA,Oracle,MSSQL,Db2,ASE -VMRole DB,ASCS,APP -AzVMResourceGroup resourcegroupname -AzVMName AzureVMName -VMHostname hostname or ip address -VMUsername username [-HighAvailability $true or $false] [-VMConnectionPort 22>] [-DBDataDir /hana/data] [-DBLogDir /hana/log] [-DBSharedDir /hana/shared] [-ANFResourceGroup resourcegroup-for-anf] [-ANFAccountName anf-account-name] [-Hardwaretype VM] [-HANADeployment OLTP,OLAP,OLTP-ScaleOut,OLAP-ScaleOut] [-HighAvailabilityAgent SBD,FencingAgent] -SSHKey Path-To-SSH-Key-File
```
#### Login with SSH Keys (password required for sudo)

```powershell
.\QualityCheck.ps1 -LogonWithUserPasswordSSHKey -VMOperatingSystem Windows,SUSE,RedHat,OracleLinux -VMDatabase HANA,Oracle,MSSQL,Db2,ASE -VMRole DB,ASCS,APP -AzVMResourceGroup resourcegroupname -AzVMName AzureVMName -VMHostname hostname or ip address -VMUsername username [-HighAvailability $true or $false] [-VMConnectionPort 22>] [-DBDataDir /hana/data] [-DBLogDir /hana/log] [-DBSharedDir /hana/shared] [-ANFResourceGroup resourcegroup-for-anf] [-ANFAccountName anf-account-name] [-Hardwaretype VM] [-HANADeployment OLTP,OLAP,OLTP-ScaleOut,OLAP-ScaleOut] [-HighAvailabilityAgent SBD,FencingAgent] -SSHKey Path-To-SSH-Key-File
```

#### Login with SSH Keys and Passphrase (no password required for sudo, but a passphrase for SSH keys)

```powershell
.\QualityCheck.ps1 -LogonWithUserPasswordSSHKeyPassphrase -VMOperatingSystem Windows,SUSE,RedHat,OracleLinux -VMDatabase HANA,Oracle,MSSQL,Db2,ASE -VMRole DB,ASCS,APP -AzVMResourceGroup resourcegroupname -AzVMName AzureVMName -VMHostname hostname or ip address -VMUsername username [-HighAvailability $true or $false] [-VMConnectionPort 22>] [-DBDataDir /hana/data] [-DBLogDir /hana/log] [-DBSharedDir /hana/shared] [-ANFResourceGroup resourcegroup-for-anf] [-ANFAccountName anf-account-name] [-Hardwaretype VM] [-HANADeployment OLTP,OLAP,OLTP-ScaleOut,OLAP-ScaleOut] [-HighAvailabilityAgent SBD,FencingAgent] -SSHKey Path-To-SSH-Key-File
```

If you receive SSH key error, please generate the key using this command:

```bash
ssh-keygen -m PEM -t rsa -b 4096
```

* For Security warning message type "R" to run the script
* Then enter guest OS password

### Sample Output

You can access a sample output file [here](https://htmlpreview.github.io/?https://raw.githubusercontent.com/Azure/SAP-on-Azure-Scripts-and-Utilities/main/QualityCheck/sample/hana-sample.html)

### Full Help

```powershell
get-help .\QualityCheck.ps1 -detailed
```

## Disclaimer

THE SCRIPTS ARE PROVIDED AS IS WITHOUT WARRANTY OF ANY KIND, EITHER EXPRESS OR IMPLIED, INCLUDING ANY IMPLIED WARRANTIES OF FITNESS FOR A PARTICULAR PURPOSE, MERCHANTABILITY, OR NON-INFRINGEMENT.
