<#

.SYNOPSIS
    SAP on Azure Quality Check

.DESCRIPTION
    The script will check the configuration of VMs running SAP software for Azure best practice

.LINK
    https://github.com/Azure/SAP-on-Azure-Scripts-and-Utilities

		   
						
					 
											   
#>
<#
Copyright (c) Microsoft Corporation.
Licensed under the MIT license.
#>

#Requires -Version 7.1

[CmdletBinding()]
param (
        # GUI
        [Parameter(Mandatory=$true, ParameterSetName='GUI')]
        [switch]$GUI,
        # Run multiple QC at once
        [Parameter(Mandatory=$true, ParameterSetName='MultiRun')]
        [switch]$MultiRun,
        # only run on VM guest OS
        [Parameter(Mandatory=$true, ParameterSetName='runlocally')]
        [switch]$RunLocally,
        [Parameter(Mandatory=$true, ParameterSetName='UserPassword')]
        [switch]$LogonWithUserPassword,
        [Parameter(Mandatory=$true, ParameterSetName='UserPasswordSSHKey')]
        [switch]$LogonWithUserPasswordSSHKey,
        [Parameter(Mandatory=$true, ParameterSetName='UserPasswordSSHKeyPassphrase')]
        [switch]$LogonWithUserPasswordSSHKeyPassphrase,
        [Parameter(Mandatory=$true, ParameterSetName='UserPasswordAzureKeyvault')]
        [switch]$LogonWithUserPasswordAzureKeyvault,
        [Parameter(Mandatory=$true, ParameterSetName='UserPasswordAzureKeyvaultSSHKey')]
        [switch]$LogonWithUserPasswordAzureKeyvaultSSHKey,
        [Parameter(Mandatory=$true, ParameterSetName='UserAsRootSSHKey')]
        [switch]$LogonAsRootSSHKey,
        [Parameter(Mandatory=$true, ParameterSetName='UserAsRootAzureKeyvaultSSHKey')]
        [switch]$LogonAsRootAzureKeyvaultSSHKey,
        [Parameter(Mandatory=$true, ParameterSetName='UserSSHKey')]
        [switch]$LogonWithUserSSHKey,

        # VM Operating System
        [Parameter(Mandatory=$true, ParameterSetName='runlocally')]
        [Parameter(Mandatory=$true, ParameterSetName='UserPassword')]
        [Parameter(Mandatory=$true, ParameterSetName='UserPasswordSSHKeyPassphrase')]
        [Parameter(Mandatory=$true, ParameterSetName='UserPasswordAzureKeyvault')]
        [Parameter(Mandatory=$true, ParameterSetName='UserPasswordAzureKeyvaultSSHKey')]
        [Parameter(Mandatory=$true, ParameterSetName='UserSSHKey')]
        [Parameter(Mandatory=$true, ParameterSetName='UserAsRootSSHKey')]
        [Parameter(Mandatory=$true, ParameterSetName='UserAsRootAzureKeyvaultSSHKey')]
        [Parameter(Mandatory=$true, ParameterSetName='UserPasswordSSHKey')]
        [ValidateSet("Windows", "SUSE", "RedHat", "OracleLinux",IgnoreCase = $false)]
        [string]$VMOperatingSystem,
        # Database running SAP
        [Parameter(Mandatory=$true, ParameterSetName='runlocally')]
        [Parameter(Mandatory=$true, ParameterSetName='UserPassword')]
        [Parameter(Mandatory=$true, ParameterSetName='UserPasswordSSHKey')]
        [Parameter(Mandatory=$true, ParameterSetName='UserPasswordSSHKeyPassphrase')]
        [Parameter(Mandatory=$true, ParameterSetName='UserPasswordAzureKeyvault')]
        [Parameter(Mandatory=$true, ParameterSetName='UserPasswordAzureKeyvaultSSHKey')]
        [Parameter(Mandatory=$true, ParameterSetName='UserAsRootSSHKey')]
        [Parameter(Mandatory=$true, ParameterSetName='UserAsRootAzureKeyvaultSSHKey')]
        [Parameter(Mandatory=$true, ParameterSetName='UserSSHKey')]
        [ValidateSet("HANA","Oracle","MSSQL","Db2","ASE",IgnoreCase = $false)]
        [string]$VMDatabase,
        # Which component to check
        [Parameter(Mandatory=$true, ParameterSetName='runlocally')]
        [Parameter(Mandatory=$true, ParameterSetName='UserPassword')]
        [Parameter(Mandatory=$true, ParameterSetName='UserPasswordSSHKey')]
        [Parameter(Mandatory=$true, ParameterSetName='UserPasswordSSHKeyPassphrase')]
        [Parameter(Mandatory=$true, ParameterSetName='UserPasswordAzureKeyvault')]
        [Parameter(Mandatory=$true, ParameterSetName='UserPasswordAzureKeyvaultSSHKey')]
        [Parameter(Mandatory=$true, ParameterSetName='UserAsRootSSHKey')]
        [Parameter(Mandatory=$true, ParameterSetName='UserAsRootAzureKeyvaultSSHKey')]
        [Parameter(Mandatory=$true, ParameterSetName='UserSSHKey')]
        [ValidateSet("DB", "ASCS", "APP",IgnoreCase = $false)]
        [string]$VMRole,
        # VM Resource Group Name
        [Parameter(Mandatory=$true, ParameterSetName='UserPassword')]
        [Parameter(Mandatory=$true, ParameterSetName='UserPasswordSSHKey')]
        [Parameter(Mandatory=$true, ParameterSetName='UserPasswordSSHKeyPassphrase')]
        [Parameter(Mandatory=$true, ParameterSetName='UserPasswordAzureKeyvault')]
        [Parameter(Mandatory=$true, ParameterSetName='UserPasswordAzureKeyvaultSSHKey')]
        [Parameter(Mandatory=$true, ParameterSetName='UserAsRootSSHKey')]
        [Parameter(Mandatory=$true, ParameterSetName='UserAsRootAzureKeyvaultSSHKey')]
        [Parameter(Mandatory=$true, ParameterSetName='UserSSHKey')]
        [string]$AzVMResourceGroup,
        # Azure VM Name
        [Parameter(Mandatory=$true, ParameterSetName='UserPassword')]
        [Parameter(Mandatory=$true, ParameterSetName='UserPasswordSSHKey')]
        [Parameter(Mandatory=$true, ParameterSetName='UserPasswordSSHKeyPassphrase')]
        [Parameter(Mandatory=$true, ParameterSetName='UserPasswordAzureKeyvault')]
        [Parameter(Mandatory=$true, ParameterSetName='UserPasswordAzureKeyvaultSSHKey')]
        [Parameter(Mandatory=$true, ParameterSetName='UserAsRootSSHKey')]
        [Parameter(Mandatory=$true, ParameterSetName='UserAsRootAzureKeyvaultSSHKey')]
        [Parameter(Mandatory=$true, ParameterSetName='UserSSHKey')]
        [string]$AzVMName,
        # VM Hostname or IP address (used to connect)
        [Parameter(Mandatory=$true, ParameterSetName='UserPassword')]
        [Parameter(Mandatory=$true, ParameterSetName='UserPasswordSSHKey')]
        [Parameter(Mandatory=$true, ParameterSetName='UserPasswordSSHKeyPassphrase')]
        [Parameter(Mandatory=$true, ParameterSetName='UserPasswordAzureKeyvault')]
        [Parameter(Mandatory=$true, ParameterSetName='UserPasswordAzureKeyvaultSSHKey')]
        [Parameter(Mandatory=$true, ParameterSetName='UserAsRootSSHKey')]
        [Parameter(Mandatory=$true, ParameterSetName='UserAsRootAzureKeyvaultSSHKey')]
        [Parameter(Mandatory=$true, ParameterSetName='UserSSHKey')]
        [string]$VMHostname,
        # VM Username
        [Parameter(Mandatory=$true, ParameterSetName='UserPassword')]
        [Parameter(Mandatory=$true, ParameterSetName='UserPasswordSSHKey')]
        [Parameter(Mandatory=$true, ParameterSetName='UserPasswordSSHKeyPassphrase')]
        [Parameter(Mandatory=$true, ParameterSetName='UserPasswordAzureKeyvault')]
        [Parameter(Mandatory=$true, ParameterSetName='UserPasswordAzureKeyvaultSSHKey')]
        [Parameter(Mandatory=$true, ParameterSetName='UserAsRootSSHKey')]
        [Parameter(Mandatory=$true, ParameterSetName='UserAsRootAzureKeyvaultSSHKey')]
        [Parameter(Mandatory=$true, ParameterSetName='UserSSHKey')]
        [string]$VMUsername,
        # VM Password
        [Parameter(Mandatory=$true, ParameterSetName='UserPassword')]
        [Parameter(Mandatory=$true, ParameterSetName='UserPasswordSSHKey')]
        [Parameter(Mandatory=$true, ParameterSetName='UserPasswordSSHKeyPassphrase')]
        [System.Security.SecureString]$VMPassword,
        # VM Connection Port (Linux SSH Port)
        [Parameter(ParameterSetName='UserPassword')]
        [Parameter(ParameterSetName='UserPasswordSSHKey')]
        [Parameter(ParameterSetName='UserPasswordSSHKeyPassphrase')]
        [Parameter(ParameterSetName='UserPasswordAzureKeyvault')]
        [Parameter(ParameterSetName='UserPasswordAzureKeyvaultSSHKey')]
        [Parameter(ParameterSetName='UserAsRootSSHKey')]
        [Parameter(ParameterSetName='UserAsRootAzureKeyvaultSSHKey')]
        [Parameter(ParameterSetName='UserSSHKey')]
        [string]$VMConnectionPort="22",
        # Run HA checks
        [Parameter(ParameterSetName='runlocally')]
        [Parameter(ParameterSetName='UserPassword')]
        [Parameter(ParameterSetName='UserPasswordSSHKey')]
        [Parameter(ParameterSetName='UserPasswordSSHKeyPassphrase')]
        [Parameter(ParameterSetName='UserPasswordAzureKeyvault')]
        [Parameter(ParameterSetName='UserPasswordAzureKeyvaultSSHKey')]
        [Parameter(ParameterSetName='UserAsRootSSHKey')]
        [Parameter(ParameterSetName='UserAsRootAzureKeyvaultSSHKey')]
        [Parameter(ParameterSetName='UserSSHKey')]
        [boolean]$HighAvailability=$false,
        # ConfigFile that contains the checks to be executed
        [Parameter(ParameterSetName='runlocally')]
        [Parameter(ParameterSetName='UserPassword')]
        [Parameter(ParameterSetName='UserPasswordSSHKey')]
        [Parameter(ParameterSetName='UserPasswordSSHKeyPassphrase')]
        [Parameter(ParameterSetName='UserPasswordAzureKeyvault')]
        [Parameter(ParameterSetName='UserPasswordAzureKeyvaultSSHKey')]
        [Parameter(ParameterSetName='UserAsRootSSHKey')]
        [Parameter(ParameterSetName='UserAsRootAzureKeyvaultSSHKey')]
        [Parameter(ParameterSetName='UserSSHKey')]
        [string]$ConfigFileName="QualityCheck.json",
        # SAP SID, for HANA DB SID
        [Parameter(ParameterSetName='runlocally')]
        [Parameter(ParameterSetName='UserPassword')]
        [Parameter(ParameterSetName='UserPasswordSSHKey')]
        [Parameter(ParameterSetName='UserPasswordSSHKeyPassphrase')]
        [Parameter(ParameterSetName='UserPasswordAzureKeyvault')]
        [Parameter(ParameterSetName='UserPasswordAzureKeyvaultSSHKey')]
        [Parameter(ParameterSetName='UserAsRootSSHKey')]
        [Parameter(ParameterSetName='UserAsRootAzureKeyvaultSSHKey')]
        [Parameter(ParameterSetName='UserSSHKey')]
        [string]$SID,
        # HANA Data Directories
        [Parameter(ParameterSetName='runlocally')]
        [Parameter(ParameterSetName='UserPassword')]
        [Parameter(ParameterSetName='UserPasswordSSHKey')]
        [Parameter(ParameterSetName='UserPasswordSSHKeyPassphrase')]
        [Parameter(ParameterSetName='UserPasswordAzureKeyvault')]
        [Parameter(ParameterSetName='UserPasswordAzureKeyvaultSSHKey')]
        [Parameter(ParameterSetName='UserAsRootSSHKey')]
        [Parameter(ParameterSetName='UserAsRootAzureKeyvaultSSHKey')]
        [Parameter(ParameterSetName='UserSSHKey')]
        [string[]]$DBDataDir="/hana/data",
        # HANA Log Directories
        [Parameter(ParameterSetName='runlocally')]
        [Parameter(ParameterSetName='UserPassword')]
        [Parameter(ParameterSetName='UserPasswordSSHKey')]
        [Parameter(ParameterSetName='UserPasswordSSHKeyPassphrase')]
        [Parameter(ParameterSetName='UserPasswordAzureKeyvault')]
        [Parameter(ParameterSetName='UserPasswordAzureKeyvaultSSHKey')]
        [Parameter(ParameterSetName='UserAsRootSSHKey')]
        [Parameter(ParameterSetName='UserAsRootAzureKeyvaultSSHKey')]
        [Parameter(ParameterSetName='UserSSHKey')]
        [string[]]$DBLogDir="/hana/log",
        # HANA Shared Directory
        [Parameter(ParameterSetName='runlocally')]
        [Parameter(ParameterSetName='UserPassword')]
        [Parameter(ParameterSetName='UserPasswordSSHKey')]
        [Parameter(ParameterSetName='UserPasswordSSHKeyPassphrase')]
        [Parameter(ParameterSetName='UserPasswordAzureKeyvault')]
        [Parameter(ParameterSetName='UserPasswordAzureKeyvaultSSHKey')]
        [Parameter(ParameterSetName='UserAsRootSSHKey')]
        [Parameter(ParameterSetName='UserAsRootAzureKeyvaultSSHKey')]
        [Parameter(ParameterSetName='UserSSHKey')]
        [string]$DBSharedDir="/hana/shared",
        # SSH Keys
        [Parameter(Mandatory=$true, ParameterSetName='UserPasswordSSHKey')]
        [Parameter(Mandatory=$true, ParameterSetName='UserPasswordSSHKeyPassphrase')]
        [Parameter(Mandatory=$true, ParameterSetName='UserAsRootSSHKey')]
        [Parameter(Mandatory=$true, ParameterSetName='UserSSHKey')]
        [string]$SSHKey,
        # SSH Key Passphrase
        [Parameter(Mandatory=$true, ParameterSetName='UserPasswordSSHKeyPassphrase')]
        [System.Security.SecureString]$SSHKeyPassphrase,
        # Keyvault Resource Group
        [Parameter(Mandatory=$true, ParameterSetName='UserPasswordAzureKeyvault')]
        [Parameter(Mandatory=$true, ParameterSetName='UserPasswordAzureKeyvaultSSHKey')]
        [Parameter(Mandatory=$true, ParameterSetName='UserAsRootAzureKeyvaultSSHKey')]
        [string]$KeyVaultResourceGroup,
        # Keyvault Name
        [Parameter(Mandatory=$true, ParameterSetName='UserPasswordAzureKeyvault')]
        [Parameter(Mandatory=$true, ParameterSetName='UserPasswordAzureKeyvaultSSHKey')]
        [Parameter(Mandatory=$true, ParameterSetName='UserAsRootAzureKeyvaultSSHKey')]
        [string]$KeyVaultName,
        # Keyvault Entry
        [Parameter(Mandatory=$true, ParameterSetName='UserPasswordAzureKeyvault')]
        [Parameter(Mandatory=$true, ParameterSetName='UserPasswordAzureKeyvaultSSHKey')]
        [Parameter(Mandatory=$true, ParameterSetName='UserAsRootAzureKeyvaultSSHKey')]
        [string]$KeyVaultEntry,
        # ANF Resource Group
        [Parameter(ParameterSetName='UserPassword')]
        [Parameter(ParameterSetName='UserPasswordSSHKey')]
        [Parameter(ParameterSetName='UserPasswordSSHKeyPassphrase')]
        [Parameter(ParameterSetName='UserPasswordAzureKeyvault')]
        [Parameter(ParameterSetName='UserPasswordAzureKeyvaultSSHKey')]
        [Parameter(ParameterSetName='UserAsRootSSHKey')]
        [Parameter(ParameterSetName='UserAsRootAzureKeyvaultSSHKey')]
        [Parameter(ParameterSetName='UserSSHKey')]
        [string]$ANFResourceGroup,
        # ANF Account Name
        [Parameter(ParameterSetName='UserPassword')]
        [Parameter(ParameterSetName='UserPasswordSSHKey')]
        [Parameter(ParameterSetName='UserPasswordSSHKeyPassphrase')]
        [Parameter(ParameterSetName='UserPasswordAzureKeyvault')]
        [Parameter(ParameterSetName='UserPasswordAzureKeyvaultSSHKey')]
        [Parameter(ParameterSetName='UserAsRootSSHKey')]
        [Parameter(ParameterSetName='UserAsRootAzureKeyvaultSSHKey')]
        [Parameter(ParameterSetName='UserSSHKey')]
        [string]$ANFAccountName,
        # Hardwaretype (VM or HLI)
        [Parameter(ParameterSetName='UserPassword')]
        [Parameter(ParameterSetName='UserPasswordSSHKey')]
        [Parameter(ParameterSetName='UserPasswordSSHKeyPassphrase')]
        [Parameter(ParameterSetName='UserPasswordAzureKeyvault')]
        [Parameter(ParameterSetName='UserPasswordAzureKeyvaultSSHKey')]
        [Parameter(ParameterSetName='UserAsRootSSHKey')]
        [Parameter(ParameterSetName='UserAsRootAzureKeyvaultSSHKey')]
        [Parameter(ParameterSetName='UserSSHKey')]
        [string]$Hardwaretype="VM",
        # HANA Deployment Model
        [Parameter(ParameterSetName='runlocally')]
        [Parameter(ParameterSetName='UserPassword')]
        [Parameter(ParameterSetName='UserPasswordSSHKey')]
        [Parameter(ParameterSetName='UserPasswordSSHKeyPassphrase')]
        [Parameter(ParameterSetName='UserPasswordAzureKeyvault')]
        [Parameter(ParameterSetName='UserPasswordAzureKeyvaultSSHKey')]
        [Parameter(ParameterSetName='UserAsRootSSHKey')]
        [Parameter(ParameterSetName='UserAsRootAzureKeyvaultSSHKey')]
        [Parameter(ParameterSetName='UserSSHKey')]
        [string][ValidateSet("OLTP","OLAP","OLTP-ScaleOut","OLAP-ScaleOut",IgnoreCase = $false)]$HANADeployment="OLTP",
        # High Availability Agent
        [Parameter(ParameterSetName='runlocally')]
        [Parameter(ParameterSetName='UserPassword')]
        [Parameter(ParameterSetName='UserPasswordSSHKey')]
        [Parameter(ParameterSetName='UserPasswordSSHKeyPassphrase')]
        [Parameter(ParameterSetName='UserPasswordAzureKeyvault')]
        [Parameter(ParameterSetName='UserPasswordAzureKeyvaultSSHKey')]
        [Parameter(ParameterSetName='UserAsRootSSHKey')]
        [Parameter(ParameterSetName='UserAsRootAzureKeyvaultSSHKey')]
        [Parameter(ParameterSetName='UserSSHKey')]
        [string][ValidateSet("SBD","FencingAgent","WCF",IgnoreCase = $false)]$HighAvailabilityAgent="SBD",
        # Run multiple QC at once
        [Parameter(Mandatory=$true, ParameterSetName='MultiRun')]
        [string]$ImportFile,
        # add JSON output in addition to HTML file
        [switch]$AddJSONFile
)


# defining script version
$scriptversion = 2024011901

function LoadHTMLHeader {

$script:_HTMLHeader = @"
<style>

    h1 {

        font-family: Arial, Helvetica, sans-serif;
        color: #e68a00;
        font-size: 28px;

    }

    
    h2 {

        font-family: Arial, Helvetica, sans-serif;
        color: #000099;
        font-size: 16px;

    }

    body {
        font-family: Arial, Helvetica, sans-serif;
    }
    
    
    table {
        font-size: 12px;
        border: 0px; 
        font-family: Lucida Console, monospace;
    } 
    
    td {
        padding: 4px;
        margin: 0px;
        border: 0;
        white-space: pre;
        vertical-align: top;
    }
    
    th {
        background: #395870;
        background: linear-gradient(#49708f, #293f50);
        color: #fff;
        font-size: 11px;
        text-transform: uppercase;
        padding: 10px 15px;
        vertical-align: middle;
        vertical-align: top;
    }

    tbody tr:nth-child(even) {
        background: #f0f0f2;
    }

    #CreationDate {
        font-family: Arial, Helvetica, sans-serif;
        color: #ff3300;
        font-size: 12px;
    }

    #Code {
        font-family: Courier New, monospace;
        font-size: 12px;
    }

    .StatusError {
        color: #ff0000;
    }
    
    .StatusWarning {
        color: #ffa500;
    }

    .StatusOK {
        color: #008000;
    }

    .StatusInfo {
        color: #0026ff;
    }

</style>
"@


    $script:_Content  = "<h1>SAP on Azure Quality Check</h1><h2>Execution date: $(Get-Date)</h2><br><h2>Use the links to jump to the sections:</h2>"

}


# RunLog function for more detailed data during execution
function WriteRunLog {
    [CmdletBinding()]
    param (
        [string]$message,
        [string]$category="INFO"
    )

    switch ($category) {
        "INFO"      {   $_prestring = "INFO     - "
                        $_color = "Green" }
        "WARNING"   {   $_prestring = "WARNING  - "
                        $_color = "Yellow" }
        "ERROR"     {   $_prestring = "ERROR    - "
                        $_color = "Red" }
    }
    $_runlog_row = "" | Select-Object "Log"
    $_runlog_row.Log = [string]$_prestring + [string]$message
    $script:_runlog += $_runlog_row
    if (-not $RunLocally) {
        Write-Host ($_prestring + $message) -ForegroundColor $_color
    }
}


# CheckRequiredModules - checking for installed Modules and their versions
function CheckRequiredModules {

    # checking PowerShell version
    if (($PSVersionTable.PSVersion.Major -ge 7) -and ($PSVersionTable.PSVersion.Minor -ge 1)) {
        # PowerSehll 7.1 installed
    }
    else {
        # PowerShell 7.1 or higher required
        Write-Error "Please install PowerShell 7.1 or newer"
        exit
    }
    
    
    # looping through modules in json file
    foreach ($_requiredmodule in $_jsonconfig.PowerShellPrerequisits) {

        # check if module is available
        $_modules = Get-Module -ListAvailable -Name $_requiredmodule.ModuleName
        if ($_modules)
        {
            # module installed, checking for version
            WriteRunLog -message ("Module " + $_requiredmodule.ModuleName + " installed")
            $_foundmoduleversion = 0

            foreach ($_module in $_modules) {

                $_requiredmoduleversion = [version]$_requiredmodule.Version
                if ($_module.Version -ge $_requiredmoduleversion) {
                    # found a module version equal or greater then required version
                    $_foundmoduleversion = 1
                    break
                }

            }

            # check if loop found the required version
            if ($_foundmoduleversion -eq 0) {
                # required module version not found
                WriteRunLog -category "ERROR" -message ("Please install " + $_requiredmodule.ModuleName + " with version greater than " + $_requiredmodule.Version)
                exit
            }

        }
        else {
            # Get-Module didn't come back with a result
            WriteRunLog -category "ERROR" -message ("Please install " + $_requiredmodule.ModuleName + " with version greater than " + $_requiredmodule.Version)
            exit
        }
    }
}

# function creates an object out of sgmap string
# each text column is return as a part of the object
function ConvertFrom-String_sgmap {

    [CmdletBinding()]
    param (
        [object]$p
    )

    # create empty array
    $_output = @()
    
    # replace characters between numbers with a ','
    $_x = $p.Trim() -replace '\s+',','
    
    # create a table object
    $_x | Foreach-Object {
	    $_output += $_ | ConvertFrom-Csv -Header P1,P2,P3,P4,P5,P6,P7,P8,P9,P10,P11
    }

    # return object
    return $_output
}

function ConvertFrom-String_lsscsi {

    [CmdletBinding()]
    param (
        [object]$p
    )

    # create empty array
    $_output = @()
    
    # replace characters between numbers with a ','
    $_x = $p.Trim() -replace '\s+',','
    
    # create a table object
    $_x | Foreach-Object {
	    $_output += $_ | ConvertFrom-Csv -Header P1,P2,P3,P4,P5,P6,P7,P8,P9,P10
    }

    # return object
    return $_output
}

# convert a df text output to object
function ConvertFrom-String_df {

    [CmdletBinding()]
    param (
        [object]$p
    )

    # create empty array
    $_output = @()

    # replace all characters with ','
    $_x = $p.Trim() -replace '\s+',','
    
    # create a table object
    $_x | Foreach-Object {
	    $_output += $_ | ConvertFrom-Csv -Header Filesystem,Size,Used,Free,UsedPercent,Mountpoint
    }

    # return object
    return $_output
}

# convert findmnt output to filesystem object
function ConvertFrom-String_findmnt {

    [CmdletBinding()]
    param (
        [object]$p
    )

    # create empty object
    $_output = @()
    
    # replace all characters with ','
    $_x = $p.Trim() -replace '\s+',','

    # create table object
    $_x | Foreach-Object {
	    $_output += $_ | ConvertFrom-Csv -Header target,source,fstype,options
    }

    # return object
    return $_output
}


# check if TCP connectivity is available (firewall rules allow access to system)
function CheckTCPConnectivity {

    if ($VMOperatingSystem -eq "Windows") {

    }
    else {

        try {

            # create a TCP connection to VM using specified port
            $_testresult = New-Object System.Net.Sockets.TcpClient($VMHostname, $VMConnectionPort)
            if ($_testresult.Connected) {
                # connected
                $script:_CheckTCPConnectivityResult = $true
            }
        }
        catch {
            WriteRunLog -category "ERROR" -message "Error connecting to $AzVMName using $VMHostname, please check network connection and firewall rules"
            $script:_CheckTCPConnectivityResult = $false
            exit
        }

    }
}

# create a connection to the system
function ConnectVM {
    
    if ($VMOperatingSystem -eq "Windows") {
        # Connect to Windows

        # New-PSSession in the future

    }
    else {
        
        # removing trusted host to make sure there is no error in case the host ssh keys were changed
        Get-SSHTrustedHost -HostName $VMHostname | Remove-SSHTrustedHost -ErrorAction SilentlyContinue | Out-Null
        
        if ($script:LogonWithUserPassword -or (($script:GUILogonMethod -eq "UserPassword") -and $GUI ) -or ($Script:MultiRun) ) {

            # create a pasword hash that will be used to connect when using sudo commands
            $script:_ClearTextPassword = ConvertFrom-SecureString -SecureString $VMPassword -AsPlainText

            # create credentials object
            $script:_credentials = New-Object System.Management.Automation.PSCredential ($VMUsername, $VMPassword);

            # connect to VM
            $script:_sshsession = New-SSHSession -ComputerName $VMHostname -Credential $_credentials -Port $VMConnectionPort -AcceptKey -ConnectionTimeout 5 -ErrorAction SilentlyContinue
            
        }
        

        switch ($PsCmdlet.ParameterSetName) {

            "UserPassword" {

            }
            "UserPasswordSSHKey" {

                # create a pasword hash that will be used to connect when using sudo commands
                $script:_ClearTextPassword = ConvertFrom-SecureString -SecureString $VMPassword -AsPlainText

                # create credentials object
                $_nopasswd = New-Object System.Security.SecureString
                $script:_credentials = New-Object System.Management.Automation.PSCredential ($VMUsername, $_nopasswd);

                if (-not(Test-Path -Path $SSHKey -PathType Leaf)) {
                    WriteRunLog -category "ERROR" -message "Can't find SSH Key file, please check path"
                    $script:_ConnectVMResult = $false
                }

                # connect to VM
                $script:_sshsession = New-SSHSession -ComputerName $VMHostname -Credential $_credentials -Port $VMConnectionPort -KeyFile $SSHKey -AcceptKey -ConnectionTimeout 5 -ErrorAction SilentlyContinue
                

            }
            "UserSSHKey" {

                # create credentials object
                $_nopasswd = New-Object System.Security.SecureString
                $script:_credentials = New-Object System.Management.Automation.PSCredential ($VMUsername, $_nopasswd);

                if (-not(Test-Path -Path $SSHKey -PathType Leaf)) {
                    WriteRunLog -category "ERROR" -message "Can't find SSH Key file, please check path"
                    $script:_ConnectVMResult = $false
                }

                # connect to VM
                $script:_sshsession = New-SSHSession -ComputerName $VMHostname -Credential $_credentials -Port $VMConnectionPort -KeyFile $SSHKey -AcceptKey -ConnectionTimeout 5 -ErrorAction SilentlyContinue
                

            }
            "UserPasswordSSHKeyPassphrase" {

                # create a pasword hash that will be used to connect when using sudo commands
                $script:_ClearTextPassword = ConvertFrom-SecureString -SecureString $VMPassword -AsPlainText

                # create credentials object
                $script:_credentials = New-Object System.Management.Automation.PSCredential ($VMUsername, $SSHKeyPassphrase);

                try {
                    # connect to VM
                    $script:_sshsession = New-SSHSession -ComputerName $VMHostname -Credential $_credentials -Port $VMConnectionPort -KeyFile $SSHKey -AcceptKey -ConnectionTimeout 5 -ErrorAction SilentlyContinue
                }
                catch {
                    WriteRunLog -category "ERROR" -message "Authentication failed, please check your credentials and keys."
                    WriteRunLog -category "ERROR" -message "Only old keys are supported by SSH.NET library using passphrases."
                    WriteRunLog -category "ERROR" -message "Use this command to generate a supported key: ssh-keygen -m PEM -t rsa -b 4096"
                    $script:_ConnectVMResult = $false
                }

            }
            "UserPasswordAzureKeyvault" {

                # create a pasword hash that will be used to connect when using sudo commands
                $script:_ClearTextPassword = Get-AzKeyVaultSecret -VaultName $KeyVaultName -Name $KeyVaultEntry -AsPlainText
                $VMPassword = ConvertTo-SecureString -String $script:_ClearTextPassword -AsPlainText -Force

                # create credentials object
                $script:_credentials = New-Object System.Management.Automation.PSCredential ($VMUsername, $VMPassword);

                # connect to VM
                $script:_sshsession = New-SSHSession -ComputerName $VMHostname -Credential $_credentials -Port $VMConnectionPort -AcceptKey -ConnectionTimeout 5 -ErrorAction SilentlyContinue

            }
            "UserPasswordAzureKeyvaultSSHKey" {

                # create a pasword hash that will be used to connect when using sudo commands
                $script:_ClearTextPassword = ConvertFrom-SecureString -SecureString $VMPassword -AsPlainText 

                $_keystring = Get-AzKeyVaultKey -VaultName $KeyVaultName -Name $KeyVaultEntry -AsPlainText 

                # create credentials object
                $_nopasswd = New-Object System.Security.SecureString
                $script:_credentials = New-Object System.Management.Automation.PSCredential ($VMUsername, $_nopasswd);

                # connect to VM
                $script:_sshsession = New-SSHSession -ComputerName $VMHostname -Credential $_credentials -Port $VMConnectionPort -KeyString $_keystring -AcceptKey -ConnectionTimeout 5 -ErrorAction SilentlyContinue

            }
            "UserAsRootSSHKey" {

                # create a pasword hash that will be used to connect when using sudo commands
                $script:_ClearTextPassword = ""

                # create credentials object
                $_nopasswd = New-Object System.Security.SecureString
                $script:_credentials = New-Object System.Management.Automation.PSCredential ($VMUsername, $_nopasswd);

                if (-not(Test-Path -Path $SSHKey -PathType Leaf)) {
                    WriteRunLog -category "ERROR" -message "Can't find SSH Key file, please check path"
                    $script:_ConnectVMResult = $false
                }

                # connect to VM
                $script:_sshsession = New-SSHSession -ComputerName $VMHostname -Credential $_credentials -Port $VMConnectionPort -KeyFile $SSHKey -AcceptKey -ConnectionTimeout 5 -ErrorAction SilentlyContinue
                

            }
            "UserAsRootAzureKeyvaultSSHKey" {

                $_keystring = Get-AzKeyVaultKey -VaultName $KeyVaultName -Name $KeyVaultEntry -AsPlainText

                # create credentials object
                $_nopasswd = New-Object System.Security.SecureString
                $script:_credentials = New-Object System.Management.Automation.PSCredential ($VMUsername, $_nopasswd);

                # connect to VM
                $script:_sshsession = New-SSHSession -ComputerName $VMHostname -Credential $_credentials -Port $VMConnectionPort -KeyString $_keystring -AcceptKey -ConnectionTimeout 5 -ErrorAction SilentlyContinue

            }
        }
        

        # connecting to linux with SSH keys
        # $script:_sshsession = New-SSHSession -ComputerName $VMHostname -Credential $_credentials -Port $VMConnectionPort -KeyFile $SSHKey -AcceptKey -ConnectionTimeout 5 -ErrorAction SilentlyContinue

        # check if connection is successful (user/password/sshkeys correct)
        if ($script:_sshsession.Connected -eq $true) {
            # return SSH session ID for later use
            $script:_ConnectVMResult = $true
            return $script:_sshsession.SessionId
        }
        else {
            # not able to connect
            WriteRunLog -category "ERROR" -message "SSH - Please check your credentials, unable to logon"
            $script:_ConnectVMResult = $false
            exit
        }
    }
}

# collect script parameters and put them into a table object
function CollectScriptParameters {

    # create empty array
    $_outputarray = @()

    # each section is a separate line in the report

    # Operating System
    $_outputarray_row = "" | Select-Object Parameter,Value
    $_outputarray_row.Parameter = "Operating System"
    $_outputarray_row.Value = $VMOperatingSystem
    $_outputarray += $_outputarray_row

    # Database Type
    $_outputarray_row = "" | Select-Object Parameter,Value
    $_outputarray_row.Parameter = "Database"
    $_outputarray_row.Value = $VMDatabase
    $_outputarray += $_outputarray_row

    # VM Role (DB/ASCS/APP)
    $_outputarray_row = "" | Select-Object Parameter,Value
    $_outputarray_row.Parameter = "VM Role"
    $_outputarray_row.Value = $VMRole
    $_outputarray += $_outputarray_row

    # Azure Resource Group Name
    $_outputarray_row = "" | Select-Object Parameter,Value
    $_outputarray_row.Parameter = "Azure Resource Group"
    $_outputarray_row.Value = $AzVMResourceGroup
    $_outputarray += $_outputarray_row

    # Azure VM Name
    $_outputarray_row = "" | Select-Object Parameter,Value
    $_outputarray_row.Parameter = "Azure VM Name"
    $_outputarray_row.Value = $AzVMName
    $_outputarray += $_outputarray_row

    # Hostname or IP Address
    $_outputarray_row = "" | Select-Object Parameter,Value
    $_outputarray_row.Parameter = "VM Hostname / IP Address"
    $_outputarray_row.Value = $VMHostname
    $_outputarray += $_outputarray_row

    # VM Username used to log on
    $_outputarray_row = "" | Select-Object Parameter,Value
    $_outputarray_row.Parameter = "VM Username"
    $_outputarray_row.Value = $VMUsername
    $_outputarray += $_outputarray_row

    # Hardware Type (VM/HLI)
    $_outputarray_row = "" | Select-Object Parameter,Value
    $_outputarray_row.Parameter = "Hardware Type"
    $_outputarray_row.Value = $Hardwaretype
    $_outputarray += $_outputarray_row

    # High Availability Yes/No
    $_outputarray_row = "" | Select-Object Parameter,Value
    $_outputarray_row.Parameter = "High Availability Check"
    $_outputarray_row.Value = $HighAvailability
    $_outputarray += $_outputarray_row

    # if HANA, then HANA Scenario
    if ($VMDatabase -eq "HANA") {
        $_outputarray_row = "" | Select-Object Parameter,Value
        $_outputarray_row.Parameter = "SAP HANA Scenario"
        $_outputarray_row.Value = $HANADeployment
        $_outputarray += $_outputarray_row    
    }

    # if High Availbility, then HA Fencing mechanism
    if ($HighAvailability -eq $true) {
        $_outputarray_row = "" | Select-Object Parameter,Value
        $_outputarray_row.Parameter = "Fencing Mechansim"
        $_outputarray_row.Value = $HighAvailabilityAgent
        $_outputarray += $_outputarray_row    
    }

    # convert the output to HTML
    $_outputarray = $_outputarray | ConvertTo-Html -Property * -Fragment -PreContent "<br><h2 id=""ScriptParameter"">Script Parameters</h2>Here are the parameters handed over to the script"
    $_outputarray = $_outputarray.Replace("::","<br/>")

    # add link to index of HTML file
    $script:_Content += "<a href=""#ScriptParameter"">Script Parameter</a><br>"

    $_outputarray



}

function CollectVMInformation {

    # create empty array
    $_outputarray = @()

    # looping through VM checks
    foreach ($_CollectVMInformationCheck in $_jsonconfig.VMCollectInformation) {

        # check if CollechtVMInformation tasks needs to be executed against this OS and database
        if ( $_CollectVMInformationCheck.OS.Contains($VMOperatingSystem) -and `
          $_CollectVMInformationCheck.DB.Contains($VMDatabase) -and `
          $_CollectVMInformationCheck.Role.Contains($VMRole) -and `
          ($_CollectVMInformationCheck.OSVersion.Contains("all") -or $_CollectVMInformationCheck.OSVersion.Contains($VMOSRelease)) -and `
          $_CollectVMInformationCheck.Hardwaretype.Contains($Hardwaretype)) {

            # check if check applies to HA or not and if HA check for HA-Agent
            if (($_CollectVMInformationCheck.HighAvailability.Contains($HighAvailability)) -or (($_CollectVMInformationCheck.HighAvailability.Contains($HighAvailability)) -and ($_CollectVMInformationCheck.HighAvailabilityAgent.Contains($HighAvailabilityAgent)))) {

                if ((-not $RunLocally) -or ($RunLocally -and ($_CollectVMInformationCheck.RunInLocalMode))) {

                    $_output = RunCommand -p $_CollectVMInformationCheck

                    # check if result should be shown in report
                    if ($_CollectVMInformationCheck.ShowInReport) {

                        # create a new empty object per line
                        $_outputarray_row = "" | Select-Object CheckID, Description, Output
                        $_outputarray_row.CheckID = $_CollectVMInformationCheck.CheckID
                        $_outputarray_row.Description = $_CollectVMInformationCheck.Description
                        $_outputarray_row.Output = $_output -join ';;:;;'

                        # add line to outputarray
                        $_outputarray += $_outputarray_row
                    }
                }
            }
        }
    }

    # create HTML output
    $_outputarray = $_outputarray | ConvertTo-Html -Property * -Fragment -PreContent "<br><h2 id=""VMInfo"">Collect VM Information</h2>This section collects basic information of the VM"
    $_outputarray = $_outputarray.Replace(";;:;;","<br/>")

    return $_outputarray

}

# collect additional VM infos
function CollectVMInformationAdditional {

    $_outputarray_total = @()
    $_counter = 0

    # looping through VM checks
    foreach ($_CollectVMInformationCheck in $_jsonconfig.VMCollectInformationAdditional) {

        $_outputarray = @()

        # check if CollechtVMInformation tasks needs to be executed against this OS and database
        if ( $_CollectVMInformationCheck.OS.Contains($VMOperatingSystem) -and `
          $_CollectVMInformationCheck.DB.Contains($VMDatabase) -and `
          $_CollectVMInformationCheck.Role.Contains($VMRole) -and `
          ( $_CollectVMInformationCheck.OSVersion.Contains("all") -or $_CollectVMInformationCheck.OSVersion.Contains($VMOSRelease)) -and `
          $_CollectVMInformationCheck.Hardwaretype.Contains($Hardwaretype)) {

            # check if check applies to HA or not and if HA check for HA-Agent
            if (($_CollectVMInformationCheck.HighAvailability.Contains($HighAvailability)) -or (($_CollectVMInformationCheck.HighAvailability.Contains($HighAvailability)) -and ($_CollectVMInformationCheck.HighAvailabilityAgent.Contains($HighAvailabilityAgent)))) {

                
                if ((-not $RunLocally) -or ($RunLocally -and ($_CollectVMInformationCheck.RunInLocalMode))) {

                    $_output = RunCommand -p $_CollectVMInformationCheck

                    # check if result should be shown in report
                    if ($_CollectVMInformationCheck.ShowInReport) {

                        $_outputarray_row = "" | Select-Object Output
                        $_outputarray_row.Output = $_output -join ';;:;;'

                        $_outputarray += $_outputarray_row

                        $_htmllink = "additionalinfo" + $_counter
                        $_description = $_CollectVMInformationCheck.Description
                        $_outputarray = $_outputarray | ConvertTo-Html -Property * -Fragment -PreContent "<br><h2 id=""$_htmllink"">$_description</h2>"
                        $script:_Content += "<a href=""#$_htmllink"">$_description</a><br>"
                        $_outputarray = $_outputarray.Replace(";;:;;","<br/>")
            
                        $_counter += 1
                        $_outputarray_total += $_outputarray
            
                    }
                }
            }
        }
    }

    return $_outputarray_total

}


# Run an OS command
function RunCommand {

    [CmdletBinding()]
    param (
        [object]$p
    )

    # command needs to run inside OS
    if ($p.CommandType -eq "OS") {
    
        # check if run in local mode
        if (-not $RunLocally) {
        
            if ($VMOperatingSystem -eq "Windows") {
                # Windows
                Invoke-Expression $p.ProcessingCommand
            }
            else {
                # Linux

                # root permissions required?
                if (($p.RootRequired) -and ($VMUsername -ne "root") -and (-not $LogonWithUserSSHKey)) {
                    # add sudo to the command
                    $_command = "echo '$_ClearTextPassword' | sudo -E -S " + $p.ProcessingCommand
                }
                else {
                    if ($LogonWithUserSSHKey) {
                        if ($p.RootRequired) {
                            $_command = "sudo -E -S " + $p.ProcessingCommand
                        }
                        else {
                            $_command = $p.ProcessingCommand    
                        }
                    }
                    else {
                        # command will be used without sudo
                        $_command = $p.ProcessingCommand
                    }
                }

                if ($LogonWithUserSSHKey) {
                    if ($_command.Contains("echo '$_ClearTextPassword' | ")) {
                        Write-Host $_command
                        $_command -replace "echo '$_ClearTextPassword' | ", ""
                        Write-Host $_command
                    }
                }

                # run the command
                $_result = Invoke-SSHCommand -Command $_command -SessionId $script:_SessionID

                # if result has errors, log them
                if ($_result.ERROR -ne "")
                {
                    WriteRunLog -category "ERROR" -message ($p.CheckID + " " + $_result.Error)
                }
                # just store theoutput of the command in $_result
                $_result = $_result.Output
            
                # if postprocessingcommand is defined in JSON
                if (($p.PostProcessingCommand -ne "") -or ($p.PostProcessingCommand)) {
            
                    # run postprocessing command
                    $_command = $p.PostProcessingCommand
                    $_command = $_command -replace "PARAMETER",$_result
                    $_result = Invoke-Expression $_command
            
                }
            
                # store the result in script variable to access it for alternative output in JSON
                $script:_CommandResult = $_result

                # return result
                return $_result
            }
        }
        else {
            try {
                # run command locally
                $_result = Invoke-Expression $p.ProcessingCommand

                # if postprocessingcommand is defined in JSON
                if (($p.PostProcessingCommand -ne "") -or ($p.PostProcessingCommand)) {

                    # run postprocessing command
                    $_command = $p.PostProcessingCommand
                    $_command = $_command -replace "PARAMETER",$_result
                    $_result = Invoke-Expression $_command
                    
                }
                return $_result

            }
            catch {
                WriteRunLog -category "ERROR" -message ("Running command " + $p.ProcessingCommand)
            }
        }
    }

    # command is a PowerShell command (e.g. query Azure resources)
    if ($p.CommandType -eq "PowerShell") {

        # set command
        $_command =  $p.ProcessingCommand 
        
        # run command
        $_result = Invoke-Expression $_command

        # if postprocessingcommand is defined in JSON
        if (($p.PostProcessingCommand -ne "") -or ($p.PostProcessingCommand)) {
        
            # run postprocessing command
            $_command = $p.PostProcessingCommand
            $_command = $_command -replace "PARAMETER",$_result
            $_result = Invoke-Expression $_command
    
        }

        # return result
        return $_result
    }
}

# check if there is connectivity to Azure using Get-AzVM command
function CheckAzureConnectivity {

    # check if connected to Azure
    $_SubscriptionInfo = Get-AzSubscription

    # if $_SubscritpionInfo then it got subscriptions
    if ($_SubscriptionInfo)
    {
        # check if connected to right subscription
        $_VMinfo = Get-AzVM -ResourceGroupName $AzVMResourceGroup -Name $AzVMName -ErrorAction SilentlyContinue

        if ($_VMinfo) {
            # connected to Azure

            $_ContextInfo = Get-AzContext

            $script:_SubscriptionID = $_ContextInfo.Subscription
            $script:_SubscriptionName = $_ContextInfo.Name
            $script:_VMName = $_VMinfo.Name
            $script:_CheckAzureConnectivity = $true
        }
        else {
            WriteRunLog -category "ERROR" -message "Unable to find resource group or VM, please check if you are connected to the correct subscription or if you had a typo"
            $script:_CheckAzureConnectivity = $false
            exit
        }
    }
    else {
        WriteRunLog -category "ERROR" -message "Please connect to Azure using the Connect-AzAccount command, if you are connected use the Select-AzSubscription command to set the correct context"
        $script:_CheckAzureConnectivity = $false
        exit
    }

}

# function to manually create an object for Run-Command function
function PrepareCommand {

    [CmdletBinding()]
    param (
        [string]$Command,
        [string]$CommandType = "OS",
        [boolean]$RootRequired = $true,
        [string]$PostProcessingCommand = ""
    )

    $_p = "" | Select-Object ProcessingCommand, CommandType, RootRequired, PostProcessingCommand
    $_p.ProcessingCommand = $Command
    $_p.CommandType = $CommandType
    $_p.RootRequired = $RootRequired
    $_p.PostProcessingCommand = $PostProcessingCommand

    return $_p
}


# Calculate Disk Name
function CalculateDiskTypeSKU {
    param (
        [int]$size,
        [string]$tier,
        [int]$iops
    )

    # check which storage tier is used
    $_performancetype = switch ($tier) {
        Premium_LRS { 'P' }
        UltraSSD_LRS { 'U' }
        Standard_LRS { 'S' }
        StandardSSD_LRS { 'E' }
        PremiumV2_LRS { 'Pv2' }
        Default {}
    }

    # calculate disk SKU based on size
    $_sizetype = switch ($size) {
        ({$PSItem -le 4}) {'1'; break}
        ({$PSItem -le 8}) {'2'; break}
        ({$PSItem -le 16}) {'3'; break}
        ({$PSItem -le 32}) {'4'; break}
        ({$PSItem -le 64}) {'6'; break}
        ({$PSItem -le 128}) {'10'; break}
        ({$PSItem -le 256}) {'15'; break}
        ({$PSItem -le 512}) {'20'; break}
        ({$PSItem -le 1024}) {'30'; break}
        ({$PSItem -le 2048}) {'40'; break}
        ({$PSItem -le 4096}) {'50'; break}
        ({$PSItem -le 8192}) {'60'; break}
        ({$PSItem -le 16384}) {'70'; break}
        ({$PSItem -le 32768}) {'80'; break}
        ({$PSItem -ge 32769}) {'90'; break}
    }
    
    if ($_performancetype -eq "Pv2") {
        $_disksku = $_performancetype + "-" + $size + "GB-" + $iops + "IOPS"
    }
    else {
        $_disksku = $_performancetype + $_sizetype
    }

    return $_disksku

}


# Show storage configuration of VM
function CollectVMStorage {

    $script:_DiskPerformance = @(
        [pscustomobject]@{StorageTier="Premium_LRS";Name="P1";Size=4;MBPS=25;IOPS=120},
        [pscustomobject]@{StorageTier="Premium_LRS";Name="P2";Size=8;MBPS=25;IOPS=120},
        [pscustomobject]@{StorageTier="Premium_LRS";Name="P3";Size=16;MBPS=25;IOPS=120},
        [pscustomobject]@{StorageTier="Premium_LRS";Name="P4";Size=32;MBPS=25;IOPS=120},
        [pscustomobject]@{StorageTier="Premium_LRS";Name="P6";Size=64;MBPS=50;IOPS=240},
        [pscustomobject]@{StorageTier="Premium_LRS";Name="P10";Size=128;MBPS=100;IOPS=500},
        [pscustomobject]@{StorageTier="Premium_LRS";Name="P15";Size=256;MBPS=125;IOPS=1100},
        [pscustomobject]@{StorageTier="Premium_LRS";Name="P20";Size=512;MBPS=150;IOPS=2300},
        [pscustomobject]@{StorageTier="Premium_LRS";Name="P30";Size=1024;MBPS=200;IOPS=5000},
        [pscustomobject]@{StorageTier="Premium_LRS";Name="P40";Size=2048;MBPS=250;IOPS=7500},
        [pscustomobject]@{StorageTier="Premium_LRS";Name="P50";Size=4096;MBPS=250;IOPS=7500},
        [pscustomobject]@{StorageTier="Premium_LRS";Name="P60";Size=8192;MBPS=500;IOPS=16000},
        [pscustomobject]@{StorageTier="Premium_LRS";Name="P70";Size=16384;MBPS=750;IOPS=18000},
        [pscustomobject]@{StorageTier="Premium_LRS";Name="P80";Size=32767;MBPS=900;IOPS=20000},
        [pscustomobject]@{StorageTier="StandardSSD_LRS";Name="E1";Size=4;MBPS=60;IOPS=500},
        [pscustomobject]@{StorageTier="StandardSSD_LRS";Name="E2";Size=8;MBPS=60;IOPS=500},
        [pscustomobject]@{StorageTier="StandardSSD_LRS";Name="E3";Size=16;MBPS=60;IOPS=500},
        [pscustomobject]@{StorageTier="StandardSSD_LRS";Name="E4";Size=32;MBPS=60;IOPS=500},
        [pscustomobject]@{StorageTier="StandardSSD_LRS";Name="E6";Size=64;MBPS=60;IOPS=500},
        [pscustomobject]@{StorageTier="StandardSSD_LRS";Name="E10";Size=128;MBPS=60;IOPS=500},
        [pscustomobject]@{StorageTier="StandardSSD_LRS";Name="E15";Size=256;MBPS=60;IOPS=500},
        [pscustomobject]@{StorageTier="StandardSSD_LRS";Name="E20";Size=512;MBPS=60;IOPS=500},
        [pscustomobject]@{StorageTier="StandardSSD_LRS";Name="E30";Size=1024;MBPS=60;IOPS=500},
        [pscustomobject]@{StorageTier="StandardSSD_LRS";Name="E40";Size=2048;MBPS=60;IOPS=500},
        [pscustomobject]@{StorageTier="StandardSSD_LRS";Name="E50";Size=4096;MBPS=60;IOPS=500},
        [pscustomobject]@{StorageTier="StandardSSD_LRS";Name="E60";Size=8192;MBPS=400;IOPS=2000},
        [pscustomobject]@{StorageTier="StandardSSD_LRS";Name="E70";Size=16384;MBPS=600;IOPS=4000},
        [pscustomobject]@{StorageTier="StandardSSD_LRS";Name="E80";Size=32767;MBPS=750;IOPS=6000},
        [pscustomobject]@{StorageTier="StandardHDD_LRS";Name="S4";Size=32;MBPS=60;IOPS=500},
        [pscustomobject]@{StorageTier="StandardHDD_LRS";Name="S6";Size=64;MBPS=60;IOPS=500},
        [pscustomobject]@{StorageTier="StandardHDD_LRS";Name="S10";Size=128;MBPS=60;IOPS=500},
        [pscustomobject]@{StorageTier="StandardHDD_LRS";Name="S15";Size=256;MBPS=60;IOPS=500},
        [pscustomobject]@{StorageTier="StandardHDD_LRS";Name="S20";Size=512;MBPS=60;IOPS=500},
        [pscustomobject]@{StorageTier="StandardHDD_LRS";Name="S30";Size=1024;MBPS=60;IOPS=500},
        [pscustomobject]@{StorageTier="StandardHDD_LRS";Name="S40";Size=2048;MBPS=60;IOPS=500},
        [pscustomobject]@{StorageTier="StandardHDD_LRS";Name="S50";Size=4096;MBPS=60;IOPS=500},
        [pscustomobject]@{StorageTier="StandardHDD_LRS";Name="S60";Size=8192;MBPS=300;IOPS=1300},
        [pscustomobject]@{StorageTier="StandardHDD_LRS";Name="S70";Size=16384;MBPS=500;IOPS=2000},
        [pscustomobject]@{StorageTier="StandardHDD_LRS";Name="S80";Size=32767;MBPS=500;IOPS=2000}
    ) 

    if ($VMOperatingSystem -eq "Windows") {
        # future windows support
    }
    else {

        if (-not $RunLocally) {
            # get VM info
            $script:_VMinfo = Get-AzVM -ResourceGroupName $AzVMResourceGroup -Name $AzVMName
        }
        }

        # collect LVM configuration
        $_command = PrepareCommand -Command "/sbin/lvm fullreport --reportformat json" 
        $script:_lvmconfig = RunCommand -p $_command | ConvertFrom-Json

        # get storage using metadata service
        $_command = PrepareCommand -Command "/usr/bin/curl -s --noproxy '*' -H Metadata:true 'http://169.254.169.254/metadata/instance/compute/storageProfile?api-version=2021-12-13'"
        $script:_azurediskconfig = RunCommand -p $_command | ConvertFrom-Json

        # get device for root
        # $_command = PrepareCommand -Command "realpath /dev/disk/azure/root" -CommandType "OS"
        $_command = PrepareCommand -Command "realpath -m /dev/disk/cloud/azure_root" -CommandType "OS"
        $_rootdisk = RunCommand -p $_command
        if ($_rootdisk -eq "/dev/disk/cloud/azure_root") {
            # backup if the virtual device doesn't exist
            $_rootdisk = "/dev/sda"
        }

        # get device for resource disk
        # $_command = PrepareCommand -Command "realpath /dev/disk/azure/resource" -CommandType "OS"
        if ($script:_azurediskconfig.resourceDisk.size -gt 0) {
            $_command = PrepareCommand -Command "realpath -m /dev/disk/cloud/azure_resource" -CommandType "OS"
            $_resourcedisk = RunCommand -p $_command
            if ($_resourcedisk -eq "/dev/disk/cloud/azure_resource") {
                # backup if the virtual device doesn't exist
                $_resourcedisk = "/dev/sdb"
            }
        }
        else {
            # setting a value for systems that don't have a resource disk for lsscsi grep command
            $_resourcedisk = "/dev/noresourcedisk"
        }
        
        if (-not $RunLocally) {
            # get Azure Disks in Resource Group
            $_command = PrepareCommand -Command "Get-AzDisk -ResourceGroupName $AzVMResourceGroup" -CommandType "PowerShell"
            $script:_AzureDiskDetails = RunCommand -p $_command
        }

        $script:_AzureDisks = @()

        # add OS Disk Infos
        $_AzureDisk_row = "" | Select-Object LUNID, Name, DeviceName, VolumeGroup, Size, DiskType, IOPS, MBPS, PerformanceTier, StorageType, Caching, WriteAccelerator
        $_AzureDisk_row.LUNID = "OsDisk"
        $_AzureDisk_row.Name = $script:_azurediskconfig.osDisk.name
        $_AzureDisk_row.Size = $script:_azurediskconfig.osDisk.DiskSizeGB
        $_AzureDisk_row.StorageType = $script:_azurediskconfig.osDisk.managedDisk.storageAccountType
        $_AzureDisk_row.Caching = $script:_azurediskconfig.osDisk.caching
        $_AzureDisk_row.WriteAccelerator = $script:_azurediskconfig.osDisk.writeAcceleratorEnabled
        $_AzureDisk_row.DiskType = CalculateDiskTypeSKU -size $script:_azurediskconfig.osDisk.DiskSizeGB -tier $script:_azurediskconfig.osDisk.managedDisk.storageAccountType
        if (-not $RunLocally) {
            $_AzureDisk_row.IOPS = ($script:_AzureDiskDetails | Where-Object { $_.Name -eq $script:_azurediskconfig.osDisk.name }).DiskIOPSReadWrite
            $_AzureDisk_row.MBPS = ($script:_AzureDiskDetails | Where-Object { $_.Name -eq $script:_azurediskconfig.osDisk.name }).DiskMBpsReadWrite
            $_AzureDisk_row.PerformanceTier = ($script:_AzureDiskDetails | Where-Object { $_.Name -eq $script:_azurediskconfig.osDisk.name }).Tier
        }
        else {
            $_AzureDisk_row.IOPS = ($script:_DiskPerformance | Where-Object { ($_.Size -eq $_AzureDisk_row.Size) -and ($_.StorageTier -eq $_AzureDisk_row.StorageType) }).IOPS
            $_AzureDisk_row.MBPS = ($script:_DiskPerformance | Where-Object { ($_.Size -eq $_AzureDisk_row.Size) -and ($_.StorageTier -eq $_AzureDisk_row.StorageType) }).MBPS
        }
        # $_AzureDisk_row.DeviceName = ($script:_diskmapping | Where-Object { ($_.P5 -eq 0) -and ($_.P2 -eq $script:_OSDiskSCSIControllerID) }).P7
        $_AzureDisk_row.DeviceName = $_rootdisk
        try {
            # $_AzureDisk_row.VolumeGroup = ($script:_lvmconfig.report | Where-Object {$_.pv.pv_name -like ($_AzureDisk_row.DeviceName + "*")}).vg[0].vg_name
            $_AzureDisk_row.VolumeGroup = ($script:_lvmconfig.report | Where-Object {$_.pv.pv_name -eq ($_AzureDisk_row.DeviceName)}).vg[0].vg_name
        }
        catch {
            if (-not $RunLocally) {
                WriteRunLog -category "WARNING" -message ("Couldn't find Volume Group for device " + $_AzureDisk_row.DeviceName)
            }
            $_AzureDisk_row.VolumeGroup = "novg-" + $_AzureDisk_row.DeviceName.Replace("/dev/","") 
        }

        $script:_AzureDisks += $_AzureDisk_row

        # get sg_map output for LUN-ID to disk mapping
        $_rootdisk.Replace("/dev/","") 
        $_resourcedisk.Replace("/dev/","")
        #$_sgmap_command = "sg_map -i -x | grep Virtual | grep -v " + $_rootdisk + " | grep -v " + $_resourcedisk
        #$_command = PrepareCommand -Command $_sgmap_command -CommandType "OS"
        #$script:_diskmapping = RunCommand -p $_command
        #$script:_diskmapping = ConvertFrom-String_sgmap -p $script:_diskmapping


        $_lsscsi_command = "lsscsi | sed 's/\[//; s/\]//; s/\.//' | sed 's/:/ /g' | grep Virtual | grep -v '" + $_rootdisk + " ' | grep -v '" + $_resourcedisk + " '"
        $_command = PrepareCommand -Command $_lsscsi_command -CommandType OS
        $script:_diskmapping = RunCommand -p $_command
        $script:_diskmapping = ConvertFrom-String_lsscsi -p $script:_diskmapping

        # add datadisks to table
        foreach ($_datadisk in $script:_azurediskconfig.dataDisks) {

            # create empty object
            $_AzureDisk_row = "" | Select-Object LUNID, Name, DeviceName, VolumeGroup, Size, DiskType, IOPS, MBPS, PerformanceTier, StorageType, Caching, WriteAccelerator

            # add disk details
            $_AzureDisk_row.LUNID = $_datadisk.lun
            $_AzureDisk_row.Name = $_datadisk.name
            $_AzureDisk_row.Size = $_datadisk.DiskSizeGB
            $_AzureDisk_row.StorageType = $_datadisk.managedDisk.storageAccountType
            $_AzureDisk_row.Caching = $_datadisk.caching
            $_AzureDisk_row.WriteAccelerator = $_datadisk.writeAcceleratorEnabled

            # $_AzureDisk_row.DeviceName = ($script:_diskmapping | Where-Object { ($_.P5 -eq $_datadisk.lun) -and ($_.P2 -eq $script:_DataDiskSCSIControllerID) }).P7
            # $_AzureDisk_row.DeviceName = ($script:_diskmapping | Where-Object { ($_.P5 -eq $_datadisk.lun) }).P7
            try {
                $_AzureDisk_row.DeviceName = ($script:_diskmapping | Where-Object { ($_.P4 -eq $_datadisk.lun) }).P10
            }
            catch {
                WriteRunLog -category "WARNING" -message ("Couldn't find device name for LUN " + $_datadisk.lun)
            }
            try {
                $_AzureDisk_row.VolumeGroup = ($script:_lvmconfig.report | Where-Object {$_.pv.pv_name -like ($_AzureDisk_row.DeviceName + "*")}).vg[0].vg_name
            }
            catch {
                if (-not $RunLocally) {
                    WriteRunLog -category "WARNING" -message ("Couldn't find Volume Group for device " + $_AzureDisk_row.DeviceName)
                }
                $_AzureDisk_row.VolumeGroup = "novg-" + $_AzureDisk_row.DeviceName.Replace("/dev/","") 
            }

            if (-not $RunLocally) {
                $_AzureDisk_row.IOPS = ($script:_AzureDiskDetails | Where-Object { $_.Name -eq $_datadisk.name }).DiskIOPSReadWrite
                $_AzureDisk_row.MBPS = ($script:_AzureDiskDetails | Where-Object { $_.Name -eq $_datadisk.name }).DiskMBpsReadWrite
                $_AzureDisk_row.PerformanceTier = ($script:_AzureDiskDetails | Where-Object { $_.Name -eq $_datadisk.name }).Tier
            }
            else {
                $_AzureDisk_row.IOPS = ($script:_DiskPerformance | Where-Object { ($_.Size -eq $_AzureDisk_row.Size) -and ($_.StorageTier -eq $_AzureDisk_row.StorageType) }).IOPS
                $_AzureDisk_row.MBPS = ($script:_DiskPerformance | Where-Object { ($_.Size -eq $_AzureDisk_row.Size) -and ($_.StorageTier -eq $_AzureDisk_row.StorageType) }).MBPS
            }
    
            $_AzureDisk_row.DiskType = CalculateDiskTypeSKU -size $_datadisk.DiskSizeGB -tier $_datadisk.managedDisk.storageAccountType -iops $_AzureDisk_row.IOPS

            $script:_AzureDisks += $_AzureDisk_row

        }

    }
    
if ($VMOperatingSystem -eq "Windows") {
# Get information about physical disks

    $script:_datadisks = Invoke-Command -ComputerName $AzVMName -ScriptBlock  {Get-Volume }

    # create HTML output
    $_FilesystemsOutput = $script:_datadisks | Select-Object DriveLetter, FileSystemLabel, OperationalStatus, HealthStatus, @{Name="Size (GB)";Expression={[math]::Round($_.Size/1GB,2)}}, @{Name="SizeRemaining (GB)";Expression={[math]::Round($_.SizeRemaining/1GB,2)}}, AllocationUnitSize | ConvertTo-Html -Property * -Fragment -PreContent "<br><h2 id=""Logical Disks"">Logical Disks</h2>This section shows you the Logical Disks attached to the windows VM."

    # add entry in HTML index
    $script:_Content += "<a href=""#Logical Disks"">Logical Disks</a><br>"

    return $_FilesystemsOutput
#    return $_DatadisksOutput

                                    } 
else {

    # convert output to HTML 
    $script:_AzureDisksOutput = $script:_AzureDisks | ConvertTo-Html -Property * -Fragment -PreContent "<br><h2 id=""VMStorage"">Collect VM Storage Information</h2>This table contains the disks directly attached to the VM"

    # add VM Storage to HTML index
    $script:_Content += "<a href=""#VMStorage"">VM Storage</a><br>"

    return $script:_AzureDisksOutput
 

}

# get LVM groups (VGs)
function CollectLVMGroups {

if ($VMOperatingSystem -eq "Windows") {

 # Display the cluster nodes on the system
 $_winclusternodes = Invoke-Command -ComputerName $AzVMName -ScriptBlock {Get-ClusterResource}


    # create HTML output
    $_winclusternodesOutput = $_winclusternodes |Select-Object Cluster, State, OwnerGroup, OwnerNode, ResourceType, MaintenanceMode| ConvertTo-Html -Property * -Fragment -PreContent "<br><h2 id=""Cluster Nodes"">Cluster Nodes</h2>This section shows you the Windows Cluster Nodes available on the VM."

    # add entry in HTML index
    $script:_Content += "<a href=""#Cluster Nodes"">Cluster Nodes</a><br>"

    return $_winclusternodesOutput

                                     } 
else {
   # create empty object
    $script:_lvmgroups = @()

    # loop through LVM report
    foreach ($_lvmgroup in $script:_lvmconfig.report) {

        # create empty object for line
        $_lvmgroup_row = "" | Select-Object Name,Disks,LogicalVolumes,Totalsize,TotalIOPS,TotalMBPS

        # add data to object
        $_lvmgroup_row.Name = $_lvmgroup.vg.vg_name
        $_lvmgroup_row.Disks = $_lvmgroup.vg.pv_count
        $_lvmgroup_row.LogicalVolumes = $_lvmgroup.vg.lv_count
        $_lvmgroup_row.Totalsize = $_lvmgroup.vg.vg_size
        $_lvmgroup_row.TotalIOPS = ($script:_AzureDisks | Where-Object { $_.VolumeGroup -eq $_lvmgroup.vg.vg_name } | Measure-Object -Property IOPS -Sum).Sum
        $_lvmgroup_row.TotalMBPS = ($script:_AzureDisks | Where-Object { $_.VolumeGroup -eq $_lvmgroup.vg.vg_name } | Measure-Object -Property MBPS -Sum).Sum

        $script:_lvmgroups += $_lvmgroup_row

	 

    } 
                                        }
    # convert output to HTML
    $script:_lvmgroupsOutput = $script:_lvmgroups | ConvertTo-Html -Property * -Fragment -PreContent "<br><h2 id=""LVMGroups"">Collect LVM Groups Information</h2>"

    # add LVM Groups to HTML index
    $script:_Content += "<a href=""#LVMGroups"">LVM Groups</a><br>"

    return $script:_lvmgroupsOutput
 

}

# collect logical volumes
function CollectLVMVolummes {

    # create empty object
    $script:_lvmvolumes = @()

    # loop through LVM config
    foreach ($_lvmgroup in $script:_lvmconfig.report) {

        # only go for VGs that are not rootvg
        if ($_lvmgroup.vg.vg_name -ne "rootvg") {
            foreach ($_lvmvolume in $_lvmgroup.lv) {
                        
                # create empty object for data line
                $_lvmvolume_row = "" | Select-Object Name,VGName,LVPath,DMPath,Layout,Size,Stripesize,Stripes

                # add data
                $_lvmvolume_row.Name = $_lvmvolume.lv_name
                $_lvmvolume_row.VGName = $_lvmgroup.vg.vg_name
                $_lvmvolume_row.LVPath = $_lvmvolume.lv_path
                $_lvmvolume_row.DMPath = $_lvmvolume.lv_dm_path
                $_lvmvolume_row.Layout = $_lvmvolume.lv_layout
                $_lvmvolume_row.Size = $_lvmvolume.lv_size
                $_lvmvolume_row.StripeSize = $_lvmgroup.seg[0].stripe_size
                # $_lvmvolume_row.Stripes = ($_lvmgroup.seg.stripes | Measure-Object -Sum).Count
                $_lvmvolume_row.Stripes = $_lvmgroup.seg[0].stripes

                # add line to report
                $script:_lvmvolumes += $_lvmvolume_row

            }
        }
    }

    # convert output to HTML
    $script:_lvmvolumesOutput = $script:_lvmvolumes | ConvertTo-Html -Property * -Fragment -PreContent "<br><h2 id=""LVMVolumes"">Collect LVM Volume Information</h2>"

    # add entry to HTML index
    $script:_Content += "<a href=""#LVMVolumes"">LVM Volumes</a><br>"
     $script:_Content += "<a href=""#LogicalDisks"">Logical Disks</a><br>"

    return $script:_lvmvolumesOutput

}

# collect network interfaces
function CollectNetworkInterfaces {

    # get Azure VM infos
    $_VMinfo = Get-AzVM -ResourceGroupName $AzVMResourceGroup -Name $AzVMName -ErrorAction SilentlyContinue

    # create empty object for network interfaces
    $script:_NetworkInterfaces = @()

    # loop through network interfaces
    foreach ($_VMnetworkinterface in $_VMinfo.NetworkProfile.NetworkInterfaces) {

        # get details for each network interface
        $_networkinterface = Get-AzNetworkInterface -ResourceId $_VMnetworkinterface.Id

        # create empty object for each line
        $_networkinterface_row = "" | Select-Object Name,AcceleratedNetworking,IPForwarding,PrivateIP,NSG

        # add infos
        $_networkinterface_row.Name = $_networkinterface.Name
        $_networkinterface_row.AcceleratedNetworking = $_networkinterface.EnableAcceleratedNetworking
        $_networkinterface_row.IPForwarding = $_networkinterface.EnableIPForwarding
        $_networkinterface_row.NSG = $_networkinterface.NetworkSecurityGroup.Id

        # add private IP addresses for interfaces
        $_networkinterface_row.PrivateIP = ""
        foreach ($_ipconfig in $_networkinterface.IpConfigurations) {
            $_networkinterface_row.PrivateIP = $_networkinterface_row.PrivateIP + $_ipconfig.PrivateIpAddress + " "
        }

        # add output to object
        $script:_NetworkInterfaces += $_networkinterface_row

    }

    # create HTML output
    $script:_NetworkInterfacesOutput = $script:_NetworkInterfaces | ConvertTo-Html -Property * -Fragment -PreContent "<br><h2 id=""NetworkInterfaces"">Collect Network Interfaces</h2>"

    # create entry in HTML index
    $script:_Content += "<a href=""#NetworkInterfaces"">Network Interfaces</a><br>"

    return $script:_NetworkInterfacesOutput

}

# collect load balancers
function CollectLoadBalancer {

    # get Azure VM Info
    $_VMinfo = Get-AzVM -ResourceGroupName $AzVMResourceGroup -Name $AzVMName -ErrorAction SilentlyContinue

    # create empty object for load balancers
    $Script:_LoadBalancers = @()

    # loop through each network interface
    foreach ($_VMnetworkinterface in $_VMinfo.NetworkProfile.NetworkInterfaces) {

        # get network interface details
        $_networkinterface = Get-AzNetworkInterface -ResourceId $_VMnetworkinterface.Id

        # loop through IP configurations of each interface
        foreach ($_ipconfig in $_networkinterface.IpConfigurations) {
            
            # loop through each loadbalancer backend address pool of each interface IP config
            foreach ($_loadbalancerbackendpool in $_ipconfig.LoadBalancerBackendAddressPools) {

                # create empty load balancer row entry
                $_loadbalancer_row = "" | Select-Object Name,Type,IdleTimeout,FloatingIP,Protocols

                # split data from pool to (full resource string) for LB name and Resource Group
                $_loadbalancername = ($_loadbalancerbackendpool.id).Split("/")[8]
                $_loadbalancerresourcegroup = ($_loadbalancerbackendpool.id).Split("/")[4]

                # get details for load balancer
                $_loadbalancer = Get-AzLoadBalancer -Name $_loadbalancername -ResourceGroupName $_loadbalancerresourcegroup

                # add details
                $_loadbalancer_row.Name = $_loadbalancername
                $_loadbalancer_row.Type = $_loadbalancer.Sku
                $_loadbalancer_row.IdleTimeout = $_loadbalancer.LoadBalancingRules[0].IdleTimeoutInMinutes
                $_loadbalancer_row.FloatingIP = $_loadbalancer.LoadBalancingRules[0].EnableFloatingIP
                $_loadbalancer_row.Protocols = $_loadbalancer.LoadBalancingRules[0].Protocol

                # add data to table
                $Script:_LoadBalancers += $_loadbalancer_row

            }
        }
    }

    # if load balancer found
    if ($Script:_LoadBalancers) {
        $_LoadBalancerOutput = $script:_LoadBalancers | ConvertTo-Html -Property * -Fragment -PreContent "<br><h2 id=""LoadBalancers"">Collect Load Balancer</h2>"
    }
    else {
        # no load balancer found
        $_loadbalancer_row = "" | Select-Object "Description"
        $_loadbalancer_row.Description = "No load balancer assigned to network interfaces"
        
        $_LoadBalancerOutput = $_loadbalancer_row | ConvertTo-Html -Property * -Fragment -PreContent "<br><h2 id=""LoadBalancers"">Collect Load Balancer</h2>"
    }

    $script:_Content += "<a href=""#LoadBalancers"">Load Balancer</a><br>"

    return $_LoadBalancerOutput

}

# calculate a kernel version
function CalculateKernelVersion {
    Param (
        [string] $kernelversion
    )

    # Linux Kernel Version consist of - and .
    # this module generates a number to compare different kernel versions
    # reason for the module is that there is no built in kernel comparison function and the kernel names are different on distributions
    # the idea is to take ever number and multiply it with a factor, the more right you get on kernel versions, the smaller the factor is
    # e.g. a kernel 4.2.65 would generate
    # 4 * 10000000  +  2 * 100000  + 65 * 1000
    # the result is 40265000
    # this value is then used in a greater or lower than X comparison

    $_kversionarray = @()

    # replace "-" with "."
    $_kversion = $kernelversion.Replace("-",".")
    # now split every number into an array
    $_kversionarray = $_kversion.split(".")
    # calculate the kernel version number
    $_kversionnumber = [System.Int32]$_kversionarray[0] * 10000000 + [System.Int32]$_kversionarray[1] * 100000 + [System.Int32]$_kversionarray[2] * 1000 + [System.Int32]$_kversionarray[3] * 100 + [System.Int32]$_kversionarray[4] * 10

    return $_kversionnumber
}

# check for kernel version
function CheckForKernelVersion {
    Param (
        [string] $startversion,
        [string] $endversion,
        [string] $version
    )

    # this function used the calculate kernel version function to create an integer value for comparison

    # start kernel version of condition
    $_kversionnumberstart = CalculateKernelVersion -kernelversion $startversion
    # end kernel version of condition
    $_kversionnumberend = CalculateKernelVersion -kernelversion $endversion
    # used kernel version
    $_kversionnumber = CalculateKernelVersion -kernelversion $version

    # check if the kernel version applies
    if (($_kversionnumber -gt $_kversionnumberstart) -and ($_kversionnumber -lt $_kversionnumberend)) {
        # yes, condition met
        return $true
    }
    else {
        # check doesn't apply
        return $false
    }
}

# function to remove unnessecary tabs and spaces
function RemoveTabsAndSpaces {

    param (
        [string]$OriginalString
    )

    $_newstring = $OriginalString
    
    # remove tabs
    $_newstring = $_newstring -replace '\t',' '

    # remove double spaces
    while ($_newstring -contains "  ") {
        $_newstring = $_newstring -replace '  ', ' '
    }

    return $_newstring

}

# function to create a line per check, required to add e.g. docs URL or SAP note entries
function AddCheckResultEntry {

    param (
        [string]$CheckID="NoCheckID",
        [string]$Description="",
        [string]$AdditionalInfo="",
        [string]$TestResult="",
        [string]$ExptectedResult="",
        [string]$Status="",
        [string]$SAPNote="",
        [string]$MicrosoftDocs="",
        [string]$ErrorCategory=""
    )

    # create empty object per line
    if (-not $RunLocally) {
        $_Check_row = "" | Select-Object CheckID, Description, Testresult, ExpectedResult, Status, SAPNote, MicrosoftDocs, AdditionalInfo
    }
    else {
        $_Check_row = "" | Select-Object CheckID, Description, Testresult, ExpectedResult, Status, SAPNote, MicrosoftDocs, Success, VmRole, AdditionalInfo
    }

    # add infos
    $_Check_row.CheckID = $CheckID
    $_Check_row.Description = $Description
    $_Check_row.AdditionalInfo = $AdditionalInfo
    $_Check_row.Testresult = $TestResult
    $_Check_row.ExpectedResult = $ExptectedResult
    
    if ($RunLocally) {
        $_Check_row.VmRole = $VMRole
    }
    
    # taking input from JSON and adding INFO, ERROR or WARNING
    if ($Status -eq "ERROR") {
        $_Check_row.Status = $ErrorCategory
        if ($RunLocally) {
            $_Check_row.Success = $false
        }
    }
    else {
        $_Check_row.Status = $Status
        if ($RunLocally) {
            $_Check_row.Success = $true
        }
    }
    
    # if SAPNote is defined it will add the HTML code for the link
    if ($SAPNote -ne "") {
        if (-not $RunLocally) {
            $_Check_row.SAPNote = "::SAPNOTEHTML1::" + $SAPNote + "::SAPNOTEHTML2::" + $SAPNote + "::SAPNOTEHTML3::"
        }
        else {
            $_Check_row.SAPNote = "$SAPNote"
        }
    }

    # if MicrosoftDocs is defined it will add HTML code for the link
    if ($MicrosoftDocs -ne "") {
        if (-not $RunLocally) {
            $_Check_row.MicrosoftDocs = "::MSFTDOCS1::" + $MicrosoftDocs + "::MSFTDOCS2::" + "Link" + "::MSFTDOCS3::"
        }
        else {
            $_Check_row.MicrosoftDocs = "$MicrosoftDocs"
        }
    }

    # add data to checks
    $script:_Checks += $_Check_row

}

# run the quality checks (compare expectations with real values)
function RunQualityCheck {

    # add empty object for all checks done
    $script:_Checks = @()

    # add empty storage type object (will be filled to know if check applies)
    $script:_StorageType = @()

    # adding premium storage for app and ASCS nodes
    if ($VMRole -eq "ASCS" -or $VMRole -eq "APP") {
        $script:_StorageType += "Premium_LRS"
    }

    # adding premium storage for app and ASCS nodes
    if ($VMRole -eq "DB" -and $VMDatabase -ne "HANA") {
        $script:_StorageType += "Premium_LRS"
    }

    # STORAGE CHECKS SAP HANA
    # checking for data disks
    if (($VMDatabase -eq "HANA") -and ($VMRole -eq "DB")) {

        if ($SID) {

            WriteRunLog -message "Searching for directories for SID $SID" -category "INFO"

            # get directory for /hana/shared by checking /usr/sap/SID/HDB00 directory
            $_command = PrepareCommand -Command "if [ -d /usr/sap/$SID/HDB?? ]; then echo 0; else echo 1; fi"
            $_hanashared_exists = RunCommand -p $_command

            if ($_hanashared_exists -eq "0") {
                $_command = PrepareCommand -Command "findmnt -T /usr/sap/$SID/HDB?? | tail -n +2" -CommandType "OS" -RootRequired $true
                $script:_persistance_hanashared = RunCommand -p $_command
                try {
                    $script:_persistance_hanashared = ConvertFrom-String_findmnt -p $script:_persistance_hanashared
                    $_hanashared_filesystems = $script:_persistance_hanashared.target
                }
                catch {
                    WriteRunLog -message "couldn't find directory for SID $SID" -category "WARNING"
                }

                WriteRunLog -message "checking for HANA global.ini" -category "INFO"
                $_command = PrepareCommand -Command "if test -f /usr/sap/$SID/SYS/global/hdb/custom/config/global.ini; then echo 0; else echo 1; fi" -CommandType "OS" -RootRequired $true
                $_globalini_exists = RunCommand -p $_command
                
                if ($_globalini_exists -eq "0") {

                    WriteRunLog -message "found HANA global.ini" -category "INFO"

                    try {
                        # global.ini file exists, getting data

                        # check config from global.ini
                        $_command = PrepareCommand -Command "cat /usr/sap/$SID/SYS/global/hdb/custom/config/global.ini | grep basepath_datavolumes" -CommandType "OS" -RootRequired $true
                        $script:_persistance_datavolumes = RunCommand -p $_command

                        # check config from global.ini
                        $_command = PrepareCommand -Command "cat /usr/sap/$SID/SYS/global/hdb/custom/config/global.ini | grep basepath_logvolumes" -CommandType "OS" -RootRequired $true
                        $script:_persistance_logvolumes = RunCommand -p $_command
                
                        # convert output from global.ini and split it, everything in [1] is the path
                        $script:_persistance_datavolumes = ($script:_persistance_datavolumes.Split("=")[1]) -Replace " "
                        $script:_persistance_logvolumes = ($script:_persistance_logvolumes.Split("=")[1]) -Replace " "
                    }
                    catch {
                        # set default paths
                        $script:_persistance_datavolumes = "/hana/data/" + $SID
                        $script:_persistance_logvolumes = "/hana/log/" + $SID
                        $script:_persistance_hanashared = "/hana/shared/" + $SID
                    }

                }
                else {
                    # set default paths
                    WriteRunLog -message "HANA global.ini not found, fallback paths" -category "WARNING"
                    $script:_persistance_datavolumes = "/hana/data"
                    $script:_persistance_logvolumes = "/hana/log"
                    $script:_persistance_hanashared = "/hana/shared"
                }

                # get all files for /hana/data
                $_commandstring = "find $_persistance_datavolumes -type f"
                $_command = PrepareCommand -Command $($_commandstring) -CommandType "OS" -RootRequired $true
                $script:_persistance_datavolumes_files = RunCommand -p $_command

                # get all files for /hana/log
                $_commandstring = "find $_persistance_logvolumes -type f"
                $_command = PrepareCommand -Command $($_commandstring) -CommandType "OS" -RootRequired $true
                $script:_persistance_logvolumes_files = RunCommand -p $_command

                # loop through all files and get the file systems they are using
                $_datavolumes_filesystems = @()
                foreach ($_datavolumes_file in $script:_persistance_datavolumes_files) {
                    $_command = PrepareCommand -Command "findmnt -T $_datavolumes_file | tail -n +2" -CommandType "OS" -RootRequired $true
                    $_findmnt_temp = RunCommand -p $_command
                    $_findmnt_temp = ConvertFrom-String_findmnt -p $_findmnt_temp
                    $_datavolumes_filesystems += $_findmnt_temp.target
                }

                # loop through all files and get the file systems they are using
                $_logvolumes_filesystems = @()
                foreach ($_logvolumes_file in $script:_persistance_logvolumes_files) {
                    $_command = PrepareCommand -Command "findmnt -T $_logvolumes_file | tail -n +2" -CommandType "OS" -RootRequired $true
                    $_findmnt_temp = RunCommand -p $_command
                    $_findmnt_temp = ConvertFrom-String_findmnt -p $_findmnt_temp
                    $_logvolumes_filesystems += $_findmnt_temp.target
                }

                # create a list of all file systems used (unique values)
                $_datavolumes_filesystems = $_datavolumes_filesystems | Select-Object -Unique
                $_logvolumes_filesystems = $_logvolumes_filesystems | Select-Object -Unique
                
                # add log entries
                WriteRunLog -message ("Found shared filesystem for SID " + $SID)
                WriteRunLog -message "$_hanashared_filesystems" -category "INFO"
                WriteRunLog -message ("Found data filesystems for SID " + $SID) -category "INFO"
                WriteRunLog -message "$_datavolumes_filesystems" -category "INFO"
                WriteRunLog -message ("Found log filesystems for SID " + $SID) -category "INFO"
                WriteRunLog -message "$_logvolumes_filesystems" -category "INFO"
                WriteRunLog -message "Setting new values for DBDataDir and DBLogDir" -category "INFO"
            
                # setting new script variables
                $script:DBDataDir = $_datavolumes_filesystems
                $script:DBLogDir = $_logvolumes_filesystems
                $script:DBSharedDir = $_hanashared_filesystems
            }
            else {
                WriteRunLog -message "Can't find /usr/sap/$SID" -category "WARNING"
                WriteRunLog -message "Continuing with default directories" -category "WARNING"
            }

        }

        # adding Premium_LRS as default disk type for script use
        $script:_StorageType += "Premium_LRS"

        # default URL for HANA storage documentation
        $_saphanastorageurl = "https://docs.microsoft.com/en-us/azure/virtual-machines/workloads/sap/hana-vm-operations-storage"

        ## getting file system for /hana/data
        $_filesystem_hana = ($script:_filesystems | Where-Object {$_.Target -in $script:DBDataDir})
        if ($_filesystem_hana.Source.StartsWith("/dev/sd")) {
            $_filesystem_hana_type = "direct"
        }
        else {
            $_filesystem_hana_type = "lvm"
        }

        if ( ($_filesystem_hana.fstype | Select-Object -Unique) -in @('xfs','nfs','nfs4')) {
            AddCheckResultEntry -CheckID "HDB-FS-0001" -Description "SAP HANA Data: File System" -TestResult $_filesystem_hana.fstype -ExptectedResult "xfs, nfs or nfs4" -Status "OK"  -MicrosoftDocs $_saphanastorageurl -SAPNote "2972496"
        }
        else {
            AddCheckResultEntry -CheckID "HDB-FS-0001" -Description "SAP HANA Data: File System" -TestResult $_filesystem_hana.fstype -ExptectedResult "xfs, nfs or nfs4" -Status "ERROR"  -MicrosoftDocs $_saphanastorageurl -SAPNote "2972496" -ErrorCategory "ERROR"
        }

        if ( (($script:_filesystems | Where-Object {$_.target -in $script:DBDataDir}).MaxMBPS | Measure-Object -Sum).Sum -ge $_jsonconfig.HANAStorageRequirements.HANADataMBPS) {
            AddCheckResultEntry -CheckID "HDB-FS-0002" -Description "SAP HANA Data: Disk Performance" -TestResult ($script:_filesystems | Where-Object {$_.target -eq $script:DBDataDir}).MaxMBPS -ExptectedResult ">= 400 MByte/s" -Status "OK"  -MicrosoftDocs $_saphanastorageurl
        }
        else {
            AddCheckResultEntry -CheckID "HDB-FS-0002" -Description "SAP HANA Data: Disk Performance" -TestResult ($script:_filesystems | Where-Object {$_.target -eq $script:DBDataDir}).MaxMBPS -ExptectedResult ">= 400 MByte/s" -Status "ERROR"  -MicrosoftDocs $_saphanastorageurl -ErrorCategory "ERROR"
        }

        if ($_filesystem_hana.fstype -eq 'xfs') {

            # getting disks for /hana/data
            if ($_filesystem_hana_type -eq "lvm") {
                $_AzureDisks_hana = ($_AzureDisks | Where-Object {$_.VolumeGroup -in $_filesystem_hana.vg})
            }
            else {
                $_AzureDisks_for_hanadata_filesystems = $script:_filesystems | Where-Object {$_.target -in $script:DBDataDir}
                $_AzureDisks_hana = ($_AzureDisks | Where-Object { $_.DeviceName -in $_AzureDisks_for_hanadata_filesystems.Source})
            }

            $_FirstDisk = $_AzureDisks_hana[0]

            # checking if IOPS need to be checked (Ultra Disk)
            if ($_FirstDisk.StorageType -eq "UltraSSD_LRS") {
                if ( ($_filesystem_hana.fstype | Select-Object -Unique) -in @('xfs')) {
                    if ( (($script:_filesystems | Where-Object {$_.target -in $script:DBDataDir}).MaxIOPS | Measure-Object -Sum).Sum -ge $_jsonconfig.HANAStorageRequirements.HANADataIOPS) {
                        AddCheckResultEntry -CheckID "HDB-FS-0003" -Description "SAP HANA Data: Disk Performance" -TestResult ($script:_filesystems | Where-Object {$_.target -eq $script:DBDataDir}).MaxIOPS -ExptectedResult ">= 7000 IOPS" -Status "OK"  -MicrosoftDocs $_saphanastorageurl
                    }
                    else {
                        AddCheckResultEntry -CheckID "HDB-FS-0003" -Description "SAP HANA Data: Disk Performance" -TestResult ($script:_filesystems | Where-Object {$_.target -eq $script:DBDataDir}).MaxIOPS -ExptectedResult ">= 7000 IOPS" -Status "ERROR"  -MicrosoftDocs $_saphanastorageurl -ErrorCategory "ERROR"
                    }
                }
            }

            # check if stripe size check required (no of disks greater than 1 in VG) and disk type is LVM
            if (($_AzureDisks_hana.count -gt 1) -and ($_filesystem_hana_type -eq "lvm")) {
                $_HANAStripeSize = $_jsonconfig.HANAStorageRequirements.HANADataStripeSize

                if ($_filesystem_hana.StripeSize -eq $_HANAStripeSize) {
                    # stripe size correct
                    AddCheckResultEntry -CheckID "HDB-FS-0004" -Description "SAP HANA Data: stripe size" -AdditionalInfo ("Disk " + $_FirstDisk.name) -TestResult $_filesystem_hana.StripeSize -ExptectedResult $_HANAStripeSize -Status "OK" -MicrosoftDocs $_saphanastorageurl
                }
                else {
                    # Wrong Disk Type
                    AddCheckResultEntry -CheckID "HDB-FS-0004" -Description "SAP HANA Data: stripe size" -AdditionalInfo ("Disk " + $_FirstDisk.name) -TestResult $_filesystem_hana.StripeSize -ExptectedResult $_HANAStripeSize -Status "ERROR" -MicrosoftDocs $_saphanastorageurl -ErrorCategory "ERROR"
                }
            }

            # if LVM is used check for same disk type as multiple volumes might be used
            if ($_filesystem_hana_type -eq "lvm") {
                foreach ($_AzureDisk_hana in $_AzureDisks_hana) {

                    if ($_AzureDisk_hana.Disktype -eq $_FirstDisk.Disktype) {
                        # disk type correct
                        AddCheckResultEntry -CheckID "HDB-FS-0005" -Description "SAP HANA Data: same disk type" -AdditionalInfo ("Disk " + $_AzureDisk_hana.name) -TestResult $_AzureDisk_hana.Disktype -ExptectedResult $_FirstDisk.Disktype -Status "OK" -MicrosoftDocs $_saphanastorageurl
                    }
                    else {
                        # Wrong Disk Type
                        AddCheckResultEntry -CheckID "HDB-FS-0005" -Description "SAP HANA Data: same disk type" -AdditionalInfo ("Disk " + $_AzureDisk_hana.name) -TestResult $_AzureDisk_hana.Disktype -ExptectedResult $_FirstDisk.Disktype -Status "ERROR" -MicrosoftDocs $_saphanastorageurl -ErrorCategory "ERROR"

                    }

                    if ($_AzureDisk_hana.PERFORMANCETIER -eq $_FirstDisk.PERFORMANCETIER) {
                        # disk type correct
                        AddCheckResultEntry -CheckID "HDB-FS-0006" -Description "SAP HANA Data: same disk performance type" -AdditionalInfo ("Disk " + $_AzureDisk_hana.name) -TestResult $_AzureDisk_hana.Disktype -ExptectedResult $_FirstDisk.Disktype -Status "OK" -MicrosoftDocs $_saphanastorageurl

                    }
                    else {
                        # Wrong Disk Type
                        AddCheckResultEntry -CheckID "HDB-FS-0006" -Description "SAP HANA Data: same disk performance type" -AdditionalInfo ("Disk " + $_AzureDisk_hana.name) -TestResult $_AzureDisk_hana.Disktype -ExptectedResult $_FirstDisk.Disktype -Status "ERROR" -MicrosoftDocs $_saphanastorageurl -ErrorCategory "ERROR"
                    }

                    # setting storage type for later checks
                    $script:_StorageType += $_AzureDisk_hana.StorageType

                    # check if storage type is supported
                    if ($_jsonconfig.SupportedVMs.$_VMType.$VMRole.HANAStorageTypeData -contains $_AzureDisk_hana.StorageType) {
                        # storage type is supported for HANA
                        AddCheckResultEntry -CheckID "HDB-FS-0015" -Description "SAP HANA Data: storage type supported" -AdditionalInfo ("Storage Type " + $_AzureDisk_hana.StorageType) -TestResult "Supported" -ExptectedResult "Supported" -Status "OK" -MicrosoftDocs $_saphanastorageurl

                    }
                    else {
                        # Wrong Disk Type
                        AddCheckResultEntry -CheckID "HDB-FS-0015" -Description "SAP HANA Data: storage type supported" -AdditionalInfo ("Storage Type " + $_AzureDisk_hana.StorageType) -TestResult "Unsupported" -ExptectedResult "Supported" -Status "ERROR" -MicrosoftDocs $_saphanastorageurl
                    }

                    # check Premium SSD v2 sector size
                    if ($_AzureDisk_hana.StorageType -eq "PremiumV2_LRS") {
                        $_diskdevicename_command = "/sys/block/" + $_AzureDisk_hana.DeviceName.Split("/")[2] + "/queue/logical_block_size"
                        $_sectorsize_command = PrepareCommand -Command "cat $_diskdevicename_command" -RootRequired $true -CommandType "OS"
                        $_sectorsize = RunCommand -p $_sectorsize_command

                        if ($_sectorsize -eq "4096") {
                            # sector size supported
                            AddCheckResultEntry -CheckID "HDB-FS-0017" -Description "SAP HANA Data: sector size Premium SSD V2" -AdditionalInfo "Sector size of 4096 bytes" -TestResult "4096" -ExptectedResult "4096" -Status "OK" -MicrosoftDocs $_saphanastorageurl
                        }
                        else {
                            # sector size unsupported
                            AddCheckResultEntry -CheckID "HDB-FS-0017" -Description "SAP HANA Data: sector size Premium SSD V2" -AdditionalInfo "Sector size of 512 bytes" -TestResult "512" -ExptectedResult "4096" -Status "ERROR" -MicrosoftDocs $_saphanastorageurl
                        }

                    }

                }
            }
        }
        elseif (($_filesystem_hana.fstype -eq 'nfs') -or ($_filesystem_hana.fstype -eq 'nfs4')) {

            $script:_StorageType += "ANF"

            ## /hana/data is on NFS
            
        }
        else {
            ## file system not found
        }

        ## getting file system for /hana/log
        $_filesystem_hana = ($Script:_filesystems | Where-Object {$_.Target -in $script:DBLogDir})
        if ($_filesystem_hana.Source.StartsWith("/dev/sd")) {
            $_filesystem_hana_type = "direct"
        }
        else {
            $_filesystem_hana_type = "lvm"
        }

        if ( ($_filesystem_hana.fstype | Select-Object -Unique) -in @('xfs','nfs','nfs4')) {
            AddCheckResultEntry -CheckID "HDB-FS-0007" -Description "SAP HANA Log: File System" -TestResult $_filesystem_hana.fstype -ExptectedResult "xfs, nfs or nfs4" -Status "OK"  -MicrosoftDocs $_saphanastorageurl
        }
        else {
            AddCheckResultEntry -CheckID "HDB-FS-0007" -Description "SAP HANA Log: File System" -TestResult $_filesystem_hana.fstype -ExptectedResult "xfs, nfs or nfs4" -Status "ERROR"  -MicrosoftDocs $_saphanastorageurl -ErrorCategory "ERROR"
        }

        if ( (($script:_filesystems | Where-Object {$_.target -in $script:DBLogDir}).MaxMBPS | Measure-Object -Sum).Sum -ge $_jsonconfig.HANAStorageRequirements.HANALogMBPS) {
            AddCheckResultEntry -CheckID "HDB-FS-0008" -Description "SAP HANA Log: Disk Performance" -TestResult ($script:_filesystems | Where-Object {$_.target -eq $script:DBLogDir}).MaxMBPS -ExptectedResult ">= 250 MByte/s" -Status "OK"  -MicrosoftDocs $_saphanastorageurl
        }
        else {
            AddCheckResultEntry -CheckID "HDB-FS-0008" -Description "SAP HANA Log: Disk Performance" -TestResult ($script:_filesystems | Where-Object {$_.target -eq $script:DBLogDir}).MaxMBPS -ExptectedResult ">= 250 MByte/s" -Status "ERROR"  -MicrosoftDocs $_saphanastorageurl -ErrorCategory "ERROR"
        }

        if ($_filesystem_hana.fstype -eq 'xfs') {

            ## getting disks for /hana/log
            if ($_filesystem_hana_type -eq "lvm") {
                $_AzureDisks_hana = ($_AzureDisks | Where-Object {$_.VolumeGroup -in $_filesystem_hana.vg})
            }
            else {
                $_AzureDisks_for_hanalog_filesystems = $script:_filesystems | Where-Object {$_.target -in $script:DBLogDir}
                $_AzureDisks_hana = ($_AzureDisks | Where-Object { $_.DeviceName -in $_AzureDisks_for_hanalog_filesystems.Source})
            }
            $_FirstDisk = $_AzureDisks_hana[0]

            # checking if IOPS need to be checked (Ultra Disk)
            if ($_FirstDisk.StorageType -eq "UltraSSD_LRS") {

                if ($_filesystem_hana.fstype -in @('xfs')) {
                    if ( (($script:_filesystems | Where-Object {$_.target -in $script:DBLogDir}).MaxIOPS | Measure-Object -Sum).Sum -ge $_jsonconfig.HANAStorageRequirements.HANALogIOPS) {
                        AddCheckResultEntry -CheckID "HDB-FS-0009" -Description "SAP HANA Log: Disk Performance" -TestResult ($script:_filesystems | Where-Object {$_.target -eq $script:DBLogDir}).MaxIOPS -ExptectedResult ">= 2000 IOPS" -Status "OK"  -MicrosoftDocs $_saphanastorageurl
                    }
                    else {
                        AddCheckResultEntry -CheckID "HDB-FS-0009" -Description "SAP HANA Log: Disk Performance" -TestResult ($script:_filesystems | Where-Object {$_.target -eq $script:DBLogDir}).MaxIOPS -ExptectedResult ">= 2000 IOPS" -Status "ERROR"  -MicrosoftDocs $_saphanastorageurl -ErrorCategory "ERROR"
                    }
                }

            }

            # check if stripe size check required (no of disks greater than 1 in VG)
            if (($_AzureDisks_hana.count -gt 1) -and ($_filesystem_hana_type -eq "lvm")) {
                $_HANAStripeSize = $_jsonconfig.HANAStorageRequirements.HANALogStripeSize

                if ($_filesystem_hana.StripeSize -eq $_HANAStripeSize) {
                    # stripe size correct
                    AddCheckResultEntry -CheckID "HDB-FS-0010" -Description "SAP HANA Log: stripe size" -AdditionalInfo ("Disk " + $_FirstDisk.name) -TestResult $_filesystem_hana.StripeSize -ExptectedResult $_HANAStripeSize -Status "OK" -MicrosoftDocs $_saphanastorageurl
                }
                else {
                    # Wrong Disk Type
                    AddCheckResultEntry -CheckID "HDB-FS-0010" -Description "SAP HANA Log: stripe size" -AdditionalInfo ("Disk " + $_FirstDisk.name) -TestResult $_filesystem_hana.StripeSize -ExptectedResult $_HANAStripeSize -Status "ERROR" -MicrosoftDocs $_saphanastorageurl -ErrorCategory "ERROR"
                }
            }

            foreach ($_AzureDisk_hana in $_AzureDisks_hana) {

                if ($_AzureDisk_hana.Disktype -eq $_FirstDisk.Disktype) {
                    # disk type correct
                    AddCheckResultEntry -CheckID "HDB-FS-0011" -Description "SAP HANA Log: same disk type" -AdditionalInfo ("Disk " + $_AzureDisk_hana.name) -TestResult $_AzureDisk_hana.Disktype -ExptectedResult $_FirstDisk.Disktype -Status "OK" -MicrosoftDocs $_saphanastorageurl
                }
                else {
                    # Wrong Disk Type
                    AddCheckResultEntry -CheckID "HDB-FS-0011" -Description "SAP HANA Log: same disk type" -AdditionalInfo ("Disk " + $_AzureDisk_hana.name) -TestResult $_AzureDisk_hana.Disktype -ExptectedResult $_FirstDisk.Disktype -Status "ERROR" -MicrosoftDocs $_saphanastorageurl -ErrorCategory "ERROR"

                }

                if ($_AzureDisk_hana.PERFORMANCETIER -eq $_FirstDisk.PERFORMANCETIER) {
                    # disk type correct
                    AddCheckResultEntry -CheckID "HDB-FS-0012" -Description "SAP HANA Log: same disk performance type" -AdditionalInfo ("Disk " + $_AzureDisk_hana.name) -TestResult $_AzureDisk_hana.PERFORMANCETIER -ExptectedResult $_FirstDisk.PERFORMANCETIER -Status "OK" -MicrosoftDocs $_saphanastorageurl

                }
                else {
                    # Wrong Disk Type
                    AddCheckResultEntry -CheckID "HDB-FS-0012" -Description "SAP HANA Log: same disk performance type" -AdditionalInfo ("Disk " + $_AzureDisk_hana.name) -TestResult $_AzureDisk_hana.PERFORMANCETIER -ExptectedResult $_FirstDisk.PERFORMANCETIER -Status "ERROR" -MicrosoftDocs $_saphanastorageurl -ErrorCategory "ERROR"
                }

                if ($_AzureDisk_hana.StorageType -eq "Premium_LRS") {
                    
                    # Premium Disk - Check for Write Accelerator
                    if ($_AzureDisk_hana.WriteAccelerator -eq "true") {
                        AddCheckResultEntry -CheckID "HDB-FS-0013" -Description "SAP HANA Log: Write Accelerator enabled" -AdditionalInfo ("Disk " + $_AzureDisk_hana.name) -TestResult $_AzureDisk_hana.WriteAccelerator -ExptectedResult "true" -Status "OK"  -MicrosoftDocs $_saphanastorageurl
                    }
                    else {
                        AddCheckResultEntry -CheckID "HDB-FS-0013" -Description "SAP HANA Log: Write Accelerator enabled" -AdditionalInfo ("Disk " + $_AzureDisk_hana.name) -TestResult $_AzureDisk_hana.WriteAccelerator -ExptectedResult "true" -Status "ERROR"  -MicrosoftDocs $_saphanastorageurl -ErrorCategory "ERROR"
                    }
                }
                
                # setting storage type for later checks
                $script:_StorageType += $_AzureDisk_hana.StorageType

                # check if storage type is supported
                if ($_jsonconfig.SupportedVMs.$_VMType.$VMRole.HANAStorageTypeLog -contains $_AzureDisk_hana.StorageType) {
                    # storage type is supported for HANA
                    AddCheckResultEntry -CheckID "HDB-FS-0016" -Description "SAP HANA Log: storage type supported" -AdditionalInfo ("Storage Type " + $_AzureDisk_hana.StorageType) -TestResult "Supported" -ExptectedResult "Supported" -Status "OK" -MicrosoftDocs $_saphanastorageurl

                }
                else {
                    # Wrong Disk Type
                    AddCheckResultEntry -CheckID "HDB-FS-0016" -Description "SAP HANA Log: storage type supported" -AdditionalInfo ("Storage Type " + $_AzureDisk_hana.StorageType) -TestResult "Unsupported" -ExptectedResult "Supported" -Status "ERROR" -MicrosoftDocs $_saphanastorageurl
                }

                # check Premium SSD v2 sector size
                if ($_AzureDisk_hana.StorageType -eq "PremiumV2_LRS") {
                    $_diskdevicename_command = "/sys/block/" + $_AzureDisk_hana.DeviceName.Split("/")[2] + "/queue/logical_block_size"
                    $_sectorsize_command = PrepareCommand -Command "cat $_diskdevicename_command" -RootRequired $true -CommandType "OS"
                    $_sectorsize = RunCommand -p $_sectorsize_command

                    if ($_sectorsize -eq "4096") {
                        # sector size supported
                        AddCheckResultEntry -CheckID "HDB-FS-0018" -Description "SAP HANA Data: sector size Premium SSD V2" -AdditionalInfo "Sector size of 4096 bytes" -TestResult "4096" -ExptectedResult "4096" -Status "OK" -MicrosoftDocs $_saphanastorageurl
                    }
                    else {
                        # sector size unsupported
                        AddCheckResultEntry -CheckID "HDB-FS-0018" -Description "SAP HANA Data: sector size Premium SSD V2" -AdditionalInfo "Sector size of 512 bytes" -TestResult "512" -ExptectedResult "4096" -Status "ERROR" -MicrosoftDocs $_saphanastorageurl
                    }

                }
                

            }
        }
        elseif (($_filesystem_hana.fstype -eq 'nfs') -or ($_filesystem_hana.fstype -eq 'nfs4')) {

            $script:_StorageType += "ANF"

            ## /hana/data is on NFS
            
        }
        else {
            ## file system not found
        }


        # check /hana/shared directory
        $_filesystem_hana = $_filesystems | Where-Object {$_.target -eq $script:DBSharedDir}

        if ($_filesystem_hana.fstype -in @('xfs','nfs','nfs4')) {
            AddCheckResultEntry -CheckID "HDB-FS-0014" -Description "SAP HANA Shared: File System" -TestResult $_filesystem_hana.fstype -ExptectedResult "xfs, nfs or nfs4" -Status "OK"  -MicrosoftDocs $_saphanastorageurl
        }
        else {
            AddCheckResultEntry -CheckID "HDB-FS-0014" -Description "SAP HANA Shared: File System" -TestResult $_filesystem_hana.fstype -ExptectedResult "xfs, nfs or nfs4" -Status "ERROR"  -MicrosoftDocs $_saphanastorageurl -ErrorCategory "ERROR"
        }
    }

    # STORAGE CHECKS IBM DB2
    # checking for data disks
    if (($VMDatabase -eq "Db2") -and ($VMRole -eq "DB")) {

        $_db2storagedocsurl = "https://learn.microsoft.com/en-us/azure/sap/workloads/dbms-guide-ibm"

        if ($script:DBDataDir.Contains("/hana/data")) {
            #default value is being used for DBDataDir
            #Rewrite the correct default values for DB2

            if ($SID) {
                $script:_persistance_db2datavolumes = "/db2/" + $SID + "/sapdata"
                $script:_persistance_db2logvolumes =  "/db2/" + $SID + "/log_dir"

                # get all files for /db2/SID/sapdata
                $_commandstring = "find $_persistance_db2datavolumes -type f"
                $_command = PrepareCommand -Command $($_commandstring) -CommandType "OS" -RootRequired $true
                $script:_persistance_datavolumes_files = RunCommand -p $_command

                # get all files for /db2/SID/log_dir
                $_commandstring = "find $_persistance_db2logvolumes -type f"
                $_command = PrepareCommand -Command $($_commandstring) -CommandType "OS" -RootRequired $true
                $script:_persistance_logvolumes_files = RunCommand -p $_command

                # loop through all files and get the file systems they are using
                $_datavolumes_filesystems = @()
                foreach ($_datavolumes_file in $script:_persistance_datavolumes_files) {
                    $_command = PrepareCommand -Command "findmnt -T $_datavolumes_file | tail -n +2" -CommandType "OS" -RootRequired $true
                    $_findmnt_temp = RunCommand -p $_command
                    $_findmnt_temp = ConvertFrom-String_findmnt -p $_findmnt_temp
                    $_datavolumes_filesystems += $_findmnt_temp.target
                }

                # loop through all files and get the file systems they are using
                $_logvolumes_filesystems = @()
                foreach ($_logvolumes_file in $script:_persistance_logvolumes_files) {
                    $_command = PrepareCommand -Command "findmnt -T $_logvolumes_file | tail -n +2" -CommandType "OS" -RootRequired $true
                    $_findmnt_temp = RunCommand -p $_command
                    $_findmnt_temp = ConvertFrom-String_findmnt -p $_findmnt_temp
                    $_logvolumes_filesystems += $_findmnt_temp.target
                }
                
                $script:DBDataDir = $_datavolumes_filesystems
                $script:DBLogDir = $_logvolumes_filesystems
            }
            else {
                WriteRunLog -message "SID is required parameter for running DB2 checks." -category "ERROR"
            }
        }

        ## getting file system for /db2/SID/log_dir
        $_filesystem_db2 = ($script:_filesystems | Where-Object {$_.Target -in $script:DBLogDir})
        if ($_filesystem_db2.Source.StartsWith("/dev/sd")) {
            $_filesystem_db2_type = "direct"
        }
        else {
            $_filesystem_db2_type = "lvm"
        }
        
        if($_filesystem_db2.fstype -eq 'xfs')
        {
            if ($_filesystem_db2_type -eq "lvm") {
                $_AzureDisks_db2 = ($_AzureDisks | Where-Object {$_.VolumeGroup -in $_filesystem_db2.vg})
            }
            else {
                $_AzureDisks_for_db2data_filesystems = $script:_filesystems | Where-Object {$_.target -in $script:DBLogDir}
                $_AzureDisks_db2 = ($_AzureDisks | Where-Object { $_.DeviceName -in $_AzureDisks_for_db2data_filesystems.Source})
            }
        }
        elseif (($_filesystem_db2.fstype -eq 'nfs') -or ($_filesystem_db2.fstype -eq 'nfs4')) {

            $script:_StorageType += "ANF"
            
        }
        else {
            ## file system not found
        }

        # check if stripe size check required (no of disks greater than 1 in VG)
        if (($_AzureDisks_db2.count -gt 1) -and ($_filesystem_db2_type -eq "lvm")) {
            $_DB2StripeSize = $_jsonconfig.DB2StorageRequirements.DB2LogStripeSize

            if ($_filesystem_db2.StripeSize -eq $_DB2StripeSize) {
                # stripe size correct
                AddCheckResultEntry -CheckID "DB2-RHEL-0001" -Description "IBM DB2 Log: stripe size" -TestResult $_filesystem_db2.StripeSize -ExptectedResult $_DB2StripeSize -Status "OK" -MicrosoftDocs $_db2storagedocsurl
            }
            else {
                # Wrong Disk Type
                AddCheckResultEntry -CheckID "DB2-RHEL-0001" -Description "IBM DB2 Log: stripe size" -TestResult $_filesystem_db2.StripeSize -ExptectedResult $_DB2StripeSize -Status "ERROR" -MicrosoftDocs $_db2storagedocsurl -ErrorCategory "ERROR"
            }
        }

        ## getting file system for /db2/data
        $_filesystem_db2 = ($script:_filesystems | Where-Object {$_.Target -in $script:DBDataDir})
        if ($_filesystem_db2.Source.StartsWith("/dev/sd")) {
            $_filesystem_db2_type = "direct"
        }
        else {
            $_filesystem_db2_type = "lvm"
        }
        
        if($_filesystem_db2.fstype -eq 'xfs')
        {
            if ($_filesystem_db2_type -eq "lvm") {
                $_AzureDisks_db2 = ($_AzureDisks | Where-Object {$_.VolumeGroup -in $_filesystem_db2.vg})
            }
            else {
                $_AzureDisks_for_db2data_filesystems = $script:_filesystems | Where-Object {$_.target -in $script:DBDataDir}
                $_AzureDisks_db2 = ($_AzureDisks | Where-Object { $_.DeviceName -in $_AzureDisks_for_db2data_filesystems.Source})
            }
        }
        elseif (($_filesystem_db2.fstype -eq 'nfs') -or ($_filesystem_db2.fstype -eq 'nfs4')) {

            $script:_StorageType += "ANF"
            
        }
        else {
            ## file system not found
        }

        # check if stripe size check required (no of disks greater than 1 in VG)
        if (($_AzureDisks_db2.count -gt 1) -and ($_filesystem_db2_type -eq "lvm")) {
            $_DB2StripeSize = $_jsonconfig.DB2StorageRequirements.DB2DataStripeSize

            if ($_filesystem_db2.StripeSize -eq $_DB2StripeSize) {
                # stripe size correct
                AddCheckResultEntry -CheckID "DB2-RHEL-0002" -Description "IBM DB2 Data: stripe size" -TestResult $_filesystem_db2.StripeSize -ExptectedResult $_DB2StripeSize -Status "OK" -MicrosoftDocs $_db2storagedocsurl
            }
            else {
                AddCheckResultEntry -CheckID "DB2-RHEL-0002" -Description "IBM DB2 Data: stripe size" -TestResult $_filesystem_db2.StripeSize -ExptectedResult $_DB2StripeSize -Status "ERROR" -MicrosoftDocs $_db2storagedocsurl -ErrorCategory "ERROR"
            }
        }
    }

    # remove duplicates from used storage types
    $script:_StorageType = $script:_StorageType | Select-Object -Unique

    if (($VMDatabase -eq "HANA") -and ($script:_StorageType.Length -lt 1)) {
        WriteRunLog -category "ERROR" -message  "please check your parameters, HANA directories not found"
        $script:_RunqualityCheckResult = $false
        return $false
    }


    # run checks from JSON file
    foreach ($_check in $_jsonconfig.Checks) {

        # does the check apply to this system?
        if ( $_check.OS.Contains($VMOperatingSystem) -and `
          $_check.DB.Contains($VMDatabase) -and `
          $_check.Role.Contains($VMRole) -and `
          ( $_check.OSVersion.Contains("all") -or $_check.OSVersion.Contains($VMOSRelease)) -and `
          (((Compare-Object -ReferenceObject $_check.StorageType -DifferenceObject $script:_StorageType -IncludeEqual -ExcludeDifferent) | Measure-Object ).count -gt 0) -and `
          $_check.Hardwaretype.Contains($Hardwaretype)) {

            # check if check applies to HA or not and if HA check for HA-Agent
            # if (($_check.HighAvailability.Contains($false)) -or (($_check.HighAvailability.Contains($HighAvailability)) -and ($_check.HighAvailabilityAgent.Contains($HighAvailabilityAgent)))) {
            if  (($HighAvailability -eq $false) -and ($_check.HighAvailability.Contains($HighAvailability)) -or `
                (($HighAvailability -eq $true) -and ($_check.HighAvailability.Contains($HighAvailability)) -and ($_check.HighAvailabilityAgent.Contains($HighAvailabilityAgent)))) {

                if ((-not $RunLocally) -or ($RunLocally -and ($_check.RunInLocalMode))) {

                    if (-not $RunLocally) {
                        $_Check_row = "" | Select-Object CheckID, Description, AdditionalInfo, Testresult, ExpectedResult, Status, SAPNote, MicrosoftDocs
                    }
                    else {
                        $_Check_row = "" | Select-Object CheckID, Description, AdditionalInfo, Testresult, ExpectedResult, Status, SAPNote, MicrosoftDocs, Success, VmRole
                    }

                    $_result = RunCommand -p $_check

                    $_result = RemoveTabsAndSpaces -OriginalString $_result

                    $_Check_row.CheckID = $_check.CheckID
                    $_Check_row.Description = $_check.Description
                    $_Check_row.AdditionalInfo = $_check.AdditionalInfo
                    $_Check_row.Testresult = $_result
                    # $_Check_row.ExpectedResult = $_check.ExpectedResult
                    # if multiple expected results are available the join will combine them and add a new line for each entry
                    if ($_check.ExpectedResult.GetType().Name -eq "PSCustomObject") {    
                        switch ($_check.ExpectedResult.Type) {
                            "multi" { $_Check_row.ExpectedResult = $_check.ExpectedResult.Values -join (" or{0}" -f [environment]::NewLine) }
                            "range" { $_Check_row.ExpectedResult = "from {0} to {1}" -f $_check.ExpectedResult.low, $_check.ExpectedResult.high }
                            Default { "wrong default value in JSON"}
                        }
                    }
                    else {
                        $_Check_row.ExpectedResult = $_check.ExpectedResult
                    }
                    

                    if ($RunLocally) {
                        $_Check_row.VmRole = $VMRole
                    }

                    # if ($_check.SAPNote -ne "") {
                    if (![string]::IsNullOrEmpty($_check.SAPNote)) {

                        $_SAPNotes = @()

                        foreach ($_SAPNote in $_check.SAPNote) {
                            if (-not $RunLocally) {
                                # $_Check_row.SAPNote = "::SAPNOTEHTML1::" + $_check.SAPNote + "::SAPNOTEHTML2::" + $_check.SAPNote + "::SAPNOTEHTML3::"
                                $_SAPNotes += "::SAPNOTEHTML1::" + $_SAPNote + "::SAPNOTEHTML2::" + $_SAPNote + "::SAPNOTEHTML3::"
                            }
                            else {
                                # $_Check_row.SAPNote = $_check.SAPNote
                                $_SAPNotes += $_SAPNote
                            }
                        }
                        
                        $_Check_row.SAPNote = $_SAPNotes -join ("{0}" -f [environment]::NewLine)

                    }

                    # if ($_check.MicrosoftDocs -ne "") {
                    if (![string]::IsNullOrEmpty($_check.MicrosoftDocs)) {
                        
                        $_HTMLLinks = @()
                        
                        foreach ($_HTMLLink in $_check.MicrosoftDocs) {                      
                            if (-not $RunLocally) {
                                # $_Check_row.MicrosoftDocs = "::MSFTDOCS1::" + $_check.MicrosoftDocs + "::MSFTDOCS2::" + "Link" + "::MSFTDOCS3::"
                                $_HTMLLinks += "::MSFTDOCS1::" + $_HTMLLink + "::MSFTDOCS2::" + "Link" + "::MSFTDOCS3::"
                            }
                            else {
                                # $_HTMLLinks += $_check.MicrosoftDocs
                                $_HTMLLinks += $_HTMLLink
                            }
                        }

                        $_Check_row.MicrosoftDocs = $_HTMLLinks -join ("{0}" -f [environment]::NewLine)

                    }
                    
                    # check if the expected result has multiple values or just one
                    # if ($_check.ExpectedResult.GetType().Name -eq "Object[]") {
                    if ($_check.ExpectedResult.GetType().Name -eq "PSCustomObject") {    
                        
                        switch ($_check.ExpectedResult.type) {
                            "multi" {
                                        if ($_check.ExpectedResult.Values -contains $_result) {
                                            $_Check_row.Status = "OK"
                                            if ($RunLocally) {
                                                $_Check_row.Success = $true
                                            }
                                        }
                                        else {
                                            # $_Check_row.Status = "ERROR"
                                            $_Check_row.Status = $_check.ErrorCategory
                                            if ($RunLocally) {
                                                $_Check_row.Success = $false
                                            }
                                        }
                                    }
                            "range" {
                                        if ($_result -ge $_check.ExpectedResult.low -and $_result -le $_check.ExpectedResult.high) {
                                            $_Check_row.Status = "OK"
                                            if ($RunLocally) {
                                                $_Check_row.Success = $true
                                            }
                                        }
                                        else {
                                            # $_Check_row.Status = "ERROR"
                                            $_Check_row.Status = $_check.ErrorCategory
                                            if ($RunLocally) {
                                                $_Check_row.Success = $false
                                            }
                                        }
                                    }
                            Default {
                                        $_Check_row.Status = "JSONERROR"
                                    }
                        }
                        
                    }
                    else {
                        if ($_result -eq $_check.ExpectedResult) {
                            $_Check_row.Status = "OK"
                            if ($RunLocally) {
                                $_Check_row.Success = $true
                            }
                        }
                        else {
                            # $_Check_row.Status = "ERROR"
                            $_Check_row.Status = $_check.ErrorCategory
                            if ($RunLocally) {
                                $_Check_row.Success = $false
                            }
                        }
                    }

					
                    if (($_check.ShowAlternativeRequirement) -ne "" -or ($_check.ShowAlternativeResult -ne ""))
                    {
                        if ($_check.ShowAlternativeResult -ne "") {
                            $_Check_row.Testresult = Invoke-Expression $_check.ShowAlternativeResult
                        }
                        else {
                            $_Check_row.Testresult = ""
                        }
                        if (![string]::IsNullOrEmpty($_check.ShowAlternativeRequirement)) {
                            $_Check_row.ExpectedResult = Invoke-Expression $_check.ShowAlternativeRequirement
                        }
                        else {
                            $_Check_row.ExpectedResult = ""
                        }
                    }
                
                    $script:_Checks += $_Check_row
                }
            }
        }
    }


    $_ChecksOutput = $script:_Checks | ConvertTo-Html -Property * -Fragment -PreContent "<br><h2 id=""Checks"">Check Results</h2>"

    # replace the placeholders for HTML links with HTML content
    ## SAP Part
    $_ChecksOutput = $_ChecksOutput -replace '<td>OK</td>','<td class="StatusOK">OK</td>'
    $_ChecksOutput = $_ChecksOutput -replace '<td>ERROR</td>','<td class="StatusError">ERROR</td>'
    $_ChecksOutput = $_ChecksOutput -replace '<td>WARNING</td>','<td class="StatusWarning">WARNING</td>'
    $_ChecksOutput = $_ChecksOutput -replace '<td>INFO</td>','<td class="StatusInfo">INFO</td>'
    # $_ChecksOutput = $_ChecksOutput -replace '::SAPNOTEHTML1::','<a href="https://launchpad.support.sap.com/#/notes/'
    $_ChecksOutput = $_ChecksOutput -replace '::SAPNOTEHTML1::','<a href="https://me.sap.com/notes/'
    $_ChecksOutput = $_ChecksOutput -replace '::SAPNOTEHTML2::','" target="_blank">'
    $_ChecksOutput = $_ChecksOutput -replace '::SAPNOTEHTML3::','</a>'

    ## MSFT part
    $_ChecksOutput = $_ChecksOutput -replace '::MSFTDOCS1::','<a href="'
    $_ChecksOutput = $_ChecksOutput -replace '::MSFTDOCS2::','" target="_blank">'
    $_ChecksOutput = $_ChecksOutput -replace '::MSFTDOCS3::','</a>'

    $script:_Content += "<a href=""#Checks"">Check Results</a><br>"

    return $_ChecksOutput

}

# collect file system infos
function CollectFileSystems {

    if ($VMOperatingSystem -eq "Windows") {
        # future Windows code
    }
    else {
        # linux systems

        # run findmnt command on OS
        $_command = PrepareCommand -Command "findmnt -r -n" -CommandType "OS"
        $script:_findmnt = RunCommand -p $_command
        $script:_findmnt = ConvertFrom-String_findmnt -p $script:_findmnt 

        # run df command on OS
        $_command = PrepareCommand -Command "df -BG" -CommandType "OS"
        $script:_filesystemfree = RunCommand -p $_command 
        $script:_filesystemfree = ConvertFrom-String_df -p $script:_filesystemfree 

        # new empty object for file systems
        $script:_filesystems = @()

        # loop through df command output
        foreach ($_filesystem in $_filesystemfree) {

            # new empty object for file system entry
            $_filesystem_row = "" | Select-Object Target,Source,FSType,VG,Options,Size,Free,Used,UsedPercent,MaxMBPS,MaxIOPS,StripeSize

            $_filesystem_row.Target = $_filesystem.Mountpoint
            $_filesystem_row.Source = $_filesystem.Filesystem
            $_filesystem_row.FSType = ($script:_findmnt | Where-Object {$_.target -eq $_filesystem.Mountpoint}).fstype
            $_filesystem_row.Options = ($script:_findmnt | Where-Object {$_.target -eq $_filesystem.Mountpoint}).options
            $_filesystem_row.Size = $_filesystem.Size
            $_filesystem_row.Free = $_filesystem.Free
            $_filesystem_row.Used = $_filesystem.Used
            $_filesystem_row.UsedPercent = $_filesystem.UsedPercent
            $_filesystem_row.VG = ($script:_lvmvolumes | Where-Object { $_.dmpath -eq $_filesystem.Filesystem}).vgname
            $_filesystem_row.StripeSize = ($script:_lvmvolumes | Where-Object { $_.dmpath -eq $_filesystem.Filesystem}).stripesize

            if (($_filesystem_row.FSType -eq "nfs") -or ($_filesystem_row.FSType -eq "nfs4")) {
                # NFS ANF volumes need throughput values from ANF infos
                $_filesystem_row.MaxMBPS = ($script:_ANFVolumes | Where-Object { $_filesystem_row.Source.Equals($_.NFSAddress) }).THROUGHPUTMIBPS
                if ((($script:_ANFVolumes | Where-Object { $_filesystem_row.Source.Equals($_.NFSAddress) }).THROUGHPUTMIBPS).count -eq 0) {
                    # backup path for ANF volumes to have DNS names covered
                    # this path will just compared the volume export name
                    $_NFSmounttemp = ($_filesystem_row.Source.Split(":"))[1]
                    if (![string]::IsNullOrEmpty($_.NFSAddress)) {
                        $_filesystem_row.MaxMBPS = ($script:_ANFVolumes | Where-Object { $_NFSmounttemp.Equals(($_.NFSAddress.Split(":"))[1]) }).THROUGHPUTMIBPS
                        if ([string]::IsNullOrEmpty($_filesystem_row.MaxMBPS)) {
                            $_filesystem_row.MaxMBPS = ($script:_ANFVolumes | Where-Object { $_NFSmounttemp.StartsWith(($_.NFSAddress.Split(":"))[1]) }).THROUGHPUTMIBPS
                        }
                    }
                }
            }
            else {
                if ($_filesystem.Filesystem.StartsWith("/dev/sd")) {
                    # add IOPS and MBPS from disk infos
                    $_filesystem_row.MaxMBPS = ($script:_AzureDisks | Where-Object { $_.DeviceName -eq $_filesystem_row.Source}).MBPS
                    $_filesystem_row.MaxIOPS = ($script:_AzureDisks | Where-Object { $_.DeviceName -eq $_filesystem_row.Source}).IOPS
                }
                else {
                    # add IOPS and MBPS from LVM infos
                    $_filesystem_row.MaxMBPS = ($script:_lvmgroups | Where-Object { $_.name -eq $_filesystem_row.VG}).TotalMBPS
                    $_filesystem_row.MaxIOPS = ($script:_lvmgroups | Where-Object { $_.name -eq $_filesystem_row.VG}).TotalIOPS
                }
            }

            $script:_filesystems += $_filesystem_row

        }

    }

if ($VMOperatingSystem -eq "Windows") {
# Get information about Storage pool

    $script:_datadisks = Invoke-Command -ComputerName $AzVMName -ScriptBlock {Get-StoragePool}

    # create HTML output
    $_FilesystemsOutput = $script:_datadisks | select-object FriendlyName, OperationalStatus, HealthStatus, IsPrimordial, IsReadOnly, @{Name="Size (GB)";Expression={[math]::Round($_.Size/1GB,2)}},AllocatedSize | ConvertTo-Html -Property * -Fragment -PreContent "<br><h2 id=""Storage Pool"">Storage Pool</h2>This section shows you the Storage Pool configured on the windows VM."

    # add entry in HTML index
    $script:_Content += "<a href=""#Storage Pool"">Storage Pool</a><br>"

    return $_FilesystemsOutput
#    return $_DatadisksOutput

                                    } 
else {

    # create HTML output						
    $_FilesystemsOutput = $script:_filesystems | ConvertTo-Html -Property * -Fragment -PreContent "<br><h2 id=""Filesystems"">Filesystems</h2>This section shows you the file systems available on the VM."

    # add entry in HTML index
    $script:_Content += "<a href=""#Filesystems"">Filesystems</a><br>"

    return $_FilesystemsOutput
}

}

# Windows Cluster Config Info
function CollectWindowsClusterInfo {

if ($VMOperatingSystem -eq "Windows") {
 
 # Display the cluster nodes on the system
 $_winclusternodes = Invoke-Command -ComputerName $AzVMName -ScriptBlock {Get-ClusterResource}


    # create HTML output
    $_winclusternodesOutput = $_winclusternodes |Select-Object Cluster, State, OwnerGroup, OwnerNode, ResourceType, MaintenanceMode| ConvertTo-Html -Property * -Fragment -PreContent "<br><h2 id=""Cluster Nodes"">Cluster Nodes</h2>This section shows you the Windows Cluster Nodes available on the VM."

    # add entry in HTML index
    $script:_Content += "<a href=""#Cluster Nodes"">Cluster Nodes</a><br>"

    return $_winclusternodesOutput
                                     }
 else {}
                                 }

# Windows Mini Filter drivers
function MiniFilterWindowsInfo {

if ($VMOperatingSystem -eq "Windows") {
 
 # Display the MiniFilter Drivers on the system
 $_winminifilters = Invoke-Command -ComputerName $AzVMName -ScriptBlock {fltmc}

    # create HTML output
    $_winminifiltersOutput =$_winminifilter  | ConvertTo-Html -Property * -Fragment -PreContent "<br><h2 id=""MiniFilter Drivers"">MiniFilter Drivers</h2>This section shows you the Windows MiniFilter attached to the Volumes on the VM."

    # add entry in HTML index
    $script:_Content += "<a href=""#Installed MiniFilter drivers"">MiniFilter Drivers</a><br>"

    return $_winminifiltersOutput
                                     }
 else {}
                                 }

# Windows HotFix Lists
function MiniFilterWindowsInfo {

if ($VMOperatingSystem -eq "Windows") {
 
 # Display the MiniFilter Drivers on the system
 $_winhotfix = Invoke-Command -ComputerName $AzVMName -ScriptBlock {Get-HotFix}

    # create HTML output
    $_winhotfixOutput =$_winhotfix  | ConvertTo-Html -Property * -Fragment -PreContent "<br><h2 id=""Windows HotFix"">Windows HotFix</h2>This section shows you the Windows HotFix Installed on the VM."

    # add entry in HTML index
    $script:_Content += "<a href=""#HotFixs"">Windows HotFix</a><br>"

    return $_winhotfixOutput
                                     }
 else {}
                                 }

# collect ANF volume information
function CollectANFVolumes {

    # if ANF parameters are defined it will query for ANF data
    if ($ANFAccountName -and $ANFResourceGroup) {

        # empty object for ANF volumes
        $script:_ANFVolumes = @()

        # get ANF Account
        $_ANFAccount = Get-AzNetAppFilesAccount -ResourceGroupName $ANFResourceGroup -Name $ANFAccountName
        if ($_ANFAccount.Count -gt 0) {
            WriteRunLog -category "INFO" -message "ANF Account $ANFAccountName found"
        }
        else {
            WriteRunLog -category "ERROR" -message "ANF Account $ANFAccountName not found"
            exit
        }
        
        # get all ANF Pools in ANF Account
        $_ANFPools = Get-AzNetAppFilesPool -ResourceGroupName $ANFResourceGroup -AccountName $_ANFAccount.Name
        if ($_ANFPools.Count -gt 0) {
            $_poolcount = $_ANFPools.Count
            WriteRunLog -category "INFO" -message "ANF Pools found: $_poolcount"
        }
        else {
            WriteRunLog -category "ERROR" -message "No ANF Pools not found"
            exit
        }

        # loop through pools
        foreach ($_ANFpool in $_ANFPools) {

            # the poolname is inside the string (ANFAccountName/ANFPoolName)
            # remove the ANF Accodunt name
            #$_ANFPoolName = $_ANFpool.Name -replace $_ANFAccount.Name,''
            # remove the '/' from the string
            #$_ANFPoolName = $_ANFPoolName -replace '/',''
            $_ANFpool_split = $_ANFpool.Name.Split("/")
            $_ANFPoolName = $_ANFpool_split[1]
            
            $_ANFVolumesInPool = Get-AzNetAppFilesVolume -ResourceGroupName $ANFResourceGroup -AccountName $ANFAccountName -PoolName $_ANFPoolName

            foreach ($_ANFVolume in $_ANFVolumesInPool) {

                $_ANFVolume_row = "" | Select-Object Name,Pool,ServiceLevel,ThroughputMibps,ProtocolTypes,NFSAddress,QoSType,Id

                $_ANFVolume_row.Id = $_ANFVolume.Id
                $_ANFVolume_row.Name = ($_ANFVolume.Name -split '/')[2]
                $_ANFVolume_row.Pool = $_ANFPoolName
                $_ANFVolume_row.ServiceLevel = $_ANFVolume.ServiceLevel
                $_ANFVolume_row.ProtocolTypes = [string]$_ANFVolume.ProtocolTypes
                # $_ANFVolume_row.ThroughputMibps = [int]$_ANFVolume.ThroughputMibps
                $_ANFVolume_row.ThroughputMibps = (([int]$_ANFVolume.ThroughputMibps, [int]$_ANFVolume.ActualThroughputMibps) | Measure-Object -Maximum).Maximum
                $_ANFVolume_row.QoSType = $_ANFPool.QosType
                # $_ANFVolume_row.NFSAddress = $_ANFVolume.MountTargets[0].IpAddress + ":/" + $_ANFVolume_row.Name
                if ($_ANFVolume.MountTargets.Count -gt 0){
                    $_ANFVolume_row.NFSAddress = $_ANFVolume.MountTargets[0].IpAddress + ":/" + $_ANFVolume.CreationToken
                }

                $Script:_ANFVolumes += $_ANFVolume_row

            }

        }

        $_linecounter = 0
        foreach ($_filesystem_row in $script:_filesystems) {

            if ($_filesystem_row.fstype -contains "nfs") {
                $script:_filesystems[$_linecounter].MaxMBPS = ($script:_ANFVolumes | Where-Object {$_.NFSAddress -eq $_filesystem_row.Source}).THROUGHPUTMIBPS
            }
            $_linecounter += 1

        }

        $_ANFVolumesOutput = $Script:_ANFVolumes | ConvertTo-Html -Property * -Fragment -PreContent "<br><h2 id=""ANF"">Azure NetApp Files</h2>" 

        $script:_Content += "<a href=""#ANF"">Azure NetApp Files</a><br>"

        return $_ANFVolumesOutput

    }
    else {
        return ""
    }
}

function CollectFooter {

    $_Footer = @()

    $_Footer_row = "" | Select-Object Parameter
    $_Footer_row.Parameter = "<subscriptionid>$script:_SubscriptionID</subscriptionid>"
    $_Footer += $_Footer_row

    $_Footer_row = "" | Select-Object Parameter
    $_Footer_row.Parameter = "<subscriptionname>$script:_SubscriptionName</subscriptionname>"
    $_Footer += $_Footer_row

    $_Footer_row = "" | Select-Object Parameter
    $_Footer_row.Parameter = "<vmname>$script:_VMName</vmname>"
    $_Footer += $_Footer_row

    $_FooterContent = $_Footer | ConvertTo-Html -Property * -Fragment -PreContent "<br><h2 id=""SupportInfo"">Info for Support Cases</h2>" 

    return $_FooterContent

}

function CheckSudoPermission {

    # Check is user is able to sudo
    
    if ($VMUsername -ne "root") {
        
        $_command = PrepareCommand -Command "id" -CommandType "OS" -RootRequired $true
        $_rootrights = RunCommand -p $_command

        if ($_rootrights.Contains("root")) {
            # everything ok
            WriteRunLog -category "INFO" -message "User can sudo"
            $script:_CheckSudo = $true
        }
        else {
            WriteRunLog -category "ERROR" -message "User not able to sudo, please check sudoers file"
            WriteRunLog -category "ERROR" -message "Output of sudo check:"
            WriteRunLog -category "ERROR" -message "$_rootrights"
            $script:_CheckSudo = $false
            exit
        }
    }

}

function CheckForNewerVersion {

    # download online version
    # and compare it with version numbers in files to see if there is a newer version available on GitHub
    $ConfigFileUpdateURL = "https://raw.githubusercontent.com/Azure/SAP-on-Azure-Scripts-and-Utilities/main/QualityCheck/version.json"
    try {
        $OnlineFileVersion = (Invoke-WebRequest -Uri $ConfigFileUpdateURL -UseBasicParsing -ErrorAction SilentlyContinue).Content  | ConvertFrom-Json

        if ($OnlineFileVersion.Version -gt $scriptversion) {
            WriteRunLog -category "WARNING" -message "There is a newer version of QualityCheck available on GitHub, please consider downloading it"
            WriteRunLog -category "WARNING" -message "You can download it on https://github.com/Azure/SAP-on-Azure-Scripts-and-Utilities/tree/main/QualityCheck"
            WriteRunLog -category "WARNING" -message "Script will continue"
            Start-Sleep -Seconds 3
        }

    }
    catch {
        WriteRunLog -category "WARNING" -message "Can't connect to GitHub to check version"
    }
    if (-not $RunLocally) {
        WriteRunLog -category "INFO" -message "Script Version $scriptversion"
    }

}

function LoadGUI {

    # define XAML code for form
[xml]$_XAML = @"
<Window x:Class="QualityCheck.MainWindow"
        xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        xmlns:d="http://schemas.microsoft.com/expression/blend/2008"
        xmlns:mc="http://schemas.openxmlformats.org/markup-compatibility/2006"
        xmlns:local="clr-namespace:QualityCheck"
        mc:Ignorable="d"
        WindowStartupLocation="CenterScreen"
        Title="SAP on Azure - Quality Check" Height="800" Width="900">
        <Grid Margin="0,0,-13,-70">
        <Grid.ColumnDefinitions>
            <ColumnDefinition Width="582*"/>
            <ColumnDefinition Width="325*"/>
        </Grid.ColumnDefinitions>
        <Button x:Name="ButtonRun" Content="Run" HorizontalAlignment="Left" Margin="109,582,0,0" VerticalAlignment="Top" Width="75" Grid.Column="1" Height="20"/>
        <ComboBox x:Name="Database" HorizontalAlignment="Left" Margin="190,40,0,0" VerticalAlignment="Top" Width="250" SelectedIndex="0" Height="22">
            <ComboBoxItem Content="HANA"/>
            <ComboBoxItem Content="MSSQL"/>
            <ComboBoxItem Content="Db2"/>
            <ComboBoxItem Content="Oracle"/>
            <ComboBoxItem Content="ASE"/>
        </ComboBox>
        <Label x:Name="LabelDatabase" Content="Database" HorizontalAlignment="Left" Margin="66,36,0,0" VerticalAlignment="Top" Height="26" Width="59"/>
        <ComboBox x:Name="OperatingSystem" HorizontalAlignment="Left" Margin="190,75,0,0" VerticalAlignment="Top" Width="250" SelectedIndex="0" Height="22">
            <ComboBoxItem Content="SUSE"/>
            <ComboBoxItem Content="RedHat"/>
            <ComboBoxItem Content="Windows"/>
            <ComboBoxItem Content="OracleLinux"/>
        </ComboBox>
        <Label x:Name="LabelOperatingSystem" Content="Operating System" HorizontalAlignment="Left" Margin="66,71,0,0" VerticalAlignment="Top" Height="26" Width="104"/>
        <CheckBox x:Name="HighAvailability" Content="HighAvailability" HorizontalAlignment="Left" Margin="190,281,0,0" VerticalAlignment="Top" IsChecked="True" Height="15" Width="102"/>
        <ComboBox x:Name="HANAScenario" HorizontalAlignment="Left" Margin="64,138,0,0" VerticalAlignment="Top" Width="120" SelectedIndex="0" Grid.Column="1" Height="22">
            <ComboBoxItem Content="OLTP"/>
            <ComboBoxItem Content="OLAP"/>
            <ComboBoxItem Content="OLTP-ScaleOut"/>
            <ComboBoxItem Content="OLAP-ScaleOut"/>
        </ComboBox>
        <Label x:Name="LabelHANAScenario" Content="HANA Scenario" HorizontalAlignment="Left" Margin="506,134,0,0" VerticalAlignment="Top" Grid.ColumnSpan="2" Height="26" Width="91"/>
        <ComboBox x:Name="Role" HorizontalAlignment="Left" Margin="190,109,0,0" VerticalAlignment="Top" Width="250" SelectedIndex="0" Height="22">
            <ComboBoxItem Content="DB"/>
            <ComboBoxItem Content="ASCS"/>
            <ComboBoxItem Content="APP"/>
        </ComboBox>
        <Label x:Name="LabelRole" Content="Role" HorizontalAlignment="Left" Margin="66,105,0,0" VerticalAlignment="Top" Height="26" Width="33"/>
        <ComboBox x:Name="ResourceGroup" HorizontalAlignment="Left" Margin="190,180,0,0" VerticalAlignment="Top" Width="250" SelectedIndex="0" Height="22" IsTextSearchEnabled="True">
        </ComboBox>
        <Label x:Name="LabelResourceGroup" Content="Resource Group" HorizontalAlignment="Left" Margin="66,176,0,0" VerticalAlignment="Top" Height="26" Width="95"/>
        <ComboBox x:Name="VM" HorizontalAlignment="Left" Margin="190,211,0,0" VerticalAlignment="Top" Width="250" SelectedIndex="0" Height="22"/>
        <Label x:Name="LabelVM" Content="VM" HorizontalAlignment="Left" Margin="66,207,0,0" VerticalAlignment="Top" Height="26" Width="28"/>
        <TextBox x:Name="SSHPort" HorizontalAlignment="Left" Height="22" Margin="64,478,0,0" TextWrapping="Wrap" Text="22" VerticalAlignment="Top" Width="120" Grid.Column="1"/>
        <Label x:Name="LabelSSHPort" Content="SSH Port" HorizontalAlignment="Left" Margin="506,476,0,0" VerticalAlignment="Top" Grid.ColumnSpan="2" Width="125" Height="26"/>
        <TextBox x:Name="Username" HorizontalAlignment="Left" Height="23" Margin="190,501,0,0" TextWrapping="Wrap" Text="" VerticalAlignment="Top" Width="120"/>
        <Label x:Name="LabelUsername" Content="Username" HorizontalAlignment="Left" Margin="66,498,0,0" VerticalAlignment="Top" Height="26" Width="63"/>
        <Label x:Name="LabelPassword" Content="Password" HorizontalAlignment="Left" Margin="66,529,0,0" VerticalAlignment="Top" Height="26" Width="60"/>
        <PasswordBox x:Name="Password" HorizontalAlignment="Left" Margin="190,532,0,0" VerticalAlignment="Top" Width="145" Height="23"/>
        <TextBox x:Name="DBDataDir" HorizontalAlignment="Left" Height="23" Margin="64,40,0,0" TextWrapping="Wrap" Text="/hana/data" VerticalAlignment="Top" Width="120" Grid.Column="1"/>
        <Label x:Name="LabelDBDataDir" Content="DB Data Directory" HorizontalAlignment="Left" Margin="506,37,0,0" VerticalAlignment="Top" Grid.ColumnSpan="2" Height="26" Width="105"/>
        <TextBox x:Name="DBLogDir" HorizontalAlignment="Left" Height="23" Margin="64,74,0,0" TextWrapping="Wrap" Text="/hana/log" VerticalAlignment="Top" Width="120" Grid.Column="1"/>
        <Label x:Name="LabelDBLogDir" Content="DB Log Directory" HorizontalAlignment="Left" Margin="506,71,0,0" VerticalAlignment="Top" Grid.ColumnSpan="2" Height="26" Width="100"/>
        <ComboBox x:Name="HardwareType" HorizontalAlignment="Left" Margin="190,140,0,0" VerticalAlignment="Top" Width="250" SelectedIndex="0" Height="22">
            <ComboBoxItem Content="VM"/>
            <ComboBoxItem Content="HLI"/>
        </ComboBox>
        <Label x:Name="LabelHardwareType" Content="Hardware Type" HorizontalAlignment="Left" Margin="66,136,0,0" VerticalAlignment="Top" Height="26" Width="89"/>
        <ComboBox x:Name="HighAvailabilityAgent" HorizontalAlignment="Left" Margin="190,311,0,0" VerticalAlignment="Top" Width="250" SelectedIndex="0" Height="22">
            <ComboBoxItem Content="SBD"/>
            <ComboBoxItem Content="FencingAgent"/>
            <ComboBoxItem Content="WindowsCluster"/>
        </ComboBox>
        <Label x:Name="LabelHighAvailabilityAgent" Content="HA Agent" HorizontalAlignment="Left" Margin="66,307,0,0" VerticalAlignment="Top" Height="26" Width="61"/>
        <TextBox x:Name="DBSharedDir" HorizontalAlignment="Left" Height="23" Margin="64,106,0,0" TextWrapping="Wrap" Text="/hana/shared" VerticalAlignment="Top" Width="120" Grid.Column="1"/>
        <Label x:Name="LabelDBSharedDir" Content="DB Shared Directory" HorizontalAlignment="Left" Margin="506,103,0,0" VerticalAlignment="Top" Grid.ColumnSpan="2" Height="26" Width="117"/>
        <TextBox x:Name="hostname" HorizontalAlignment="Left" Height="23" Margin="190,241,0,0" TextWrapping="Wrap" Text="" VerticalAlignment="Top" Width="249"/>
        <Label x:Name="LabelHostname" Content="Hostname/IP" HorizontalAlignment="Left" Margin="66,238,0,0" VerticalAlignment="Top" Height="26" Width="79"/>


        <TextBlock HorizontalAlignment="Left" Margin="66,582,0,0" TextWrapping="Wrap" Text=" If you want to find out more about SAP Quality Check " VerticalAlignment="Top" Width="477" Height="16">
            <Hyperlink NavigateUri="https://github.com/Azure/SAP-on-Azure-Scripts-and-Utilities/tree/main/QualityCheck">
                <Hyperlink.Inlines>
                    <Run Text="Click here"/>
                </Hyperlink.Inlines>
            </Hyperlink>
        </TextBlock>
        <Button x:Name="ButtonExit" Content="Exit" HorizontalAlignment="Left" Margin="22,582,0,0" VerticalAlignment="Top" Width="75" Height="20" Grid.Column="1"/>
        <ComboBox x:Name="LogonMethod" HorizontalAlignment="Left" Margin="190,463,0,0" VerticalAlignment="Top" Width="250" SelectedIndex="0" Height="22">
            <ComboBoxItem Content="UserPassword"/>
        </ComboBox>
        <Label x:Name="LabelHighAvailabilityAgent_Copy" Content="Logon Method" HorizontalAlignment="Left" Margin="66,461,0,0" VerticalAlignment="Top" Height="26" Width="89"/>
        <ComboBox x:Name="DiskType" HorizontalAlignment="Left" Margin="190,349,0,0" VerticalAlignment="Top" Width="250" SelectedIndex="0" Height="22">
            <ComboBoxItem Content="ANF"/>
            <ComboBoxItem Content="Managed Disk"/>
            <ComboBoxItem Content="xNFS"/>
            <ComboBoxItem Content="Shared Disk"/>
            <ComboBoxItem Content="File Share"/>
        </ComboBox>
        <Label x:Name="LabelDiskType" Content="Disk Type" HorizontalAlignment="Left" Margin="66,349,0,0" VerticalAlignment="Top" Height="26" Width="61"/>
        <ComboBox x:Name="ANFResourceGroup" HorizontalAlignment="Left" Margin="190,388,0,0" VerticalAlignment="Top" Width="250" SelectedIndex="0" Height="22" IsTextSearchEnabled="True"/>
        <Label x:Name="LabelANFResourceGroup" Content="ANF Resource Group" HorizontalAlignment="Left" Margin="66,384,0,0" VerticalAlignment="Top" Height="26" Width="124"/>
        <ComboBox x:Name="ANFAccountName" HorizontalAlignment="Left" Margin="190,424,0,0" VerticalAlignment="Top" Width="250" SelectedIndex="0" Height="22"/>
        <Label x:Name="LabelANFAccountName" Content="ANF Account Name" HorizontalAlignment="Left" Margin="66,420,0,0" VerticalAlignment="Top" Height="26" Width="119"/>

    </Grid>
</Window>
"@ -replace 'mc:Ignorable="d"','' -replace "x:N",'N' -replace '^<Win.*', '<Window' #-replace wird benötigt, wenn XAML aus Visual Studio kopiert wird.

    #XAML laden
    [void][System.Reflection.Assembly]::LoadWithPartialName('presentationframework')
    try{
    $_Form=[Windows.Markup.XamlReader]::Load( (New-Object System.Xml.XmlNodeReader $_XAML) )
    } catch {
    Write-Host "Windows.Markup.XamlReader konnte nicht geladen werden. Mögliche Ursache: ungültige Syntax oder fehlendes .net"
    }


    # check if connected to Azure
    $_SubscriptionInfo = Get-AzSubscription

    # if $_SubscritpionInfo then it got subscriptions
    if ($_SubscriptionInfo)
    {
        # connected
    }
    else {
        WriteRunLog -category "ERROR" -message "Please connect to Azure using the Connect-AzAccount command, if you are connected use the Select-AzSubscription command to set the correct context"
        exit
    }

    $_database = $_Form.FindName("Database")
    $_database.add_SelectionChanged(
        {
            param($sender,$args)
            $selected = $sender.SelectedItem.Content 
            if ($selected -eq "HANA") {
                $_Form.FindName("LabelHANAScenario").Visibility = "Visible"
                $_Form.FindName("HANAScenario").Visibility = "Visible"
            }
            else {
                $_Form.FindName("LabelHANAScenario").Visibility = "Hidden"
                $_Form.FindName("HANAScenario").Visibility = "Hidden"
            }
            #if ($_database.SelectionBoxItem.Equals("HANA")) {
            #    $_Form.FindName("LabelHANAScenario").Visibility = "Visible"
            #}
            #else {
            #    $_Form.FindName("LabelHANAScenario").Visibility = "Hidden"
            #}
        }
    )

    $_highavailability = $_Form.FindName("HighAvailability")
    $_highavailability.Add_Click(
        {
            param($sender,$args)
            $selected = $sender.isChecked
            if ($selected -eq $true) {
                $_Form.FindName("LabelHighAvailabilityAgent").Visibility = "Visible"
                $_Form.FindName("HighAvailabilityAgent").Visibility = "Visible"
            }
            else {
                $_Form.FindName("LabelHighAvailabilityAgent").Visibility = "Hidden"
                $_Form.FindName("HighAvailabilityAgent").Visibility = "Hidden"
            }
        }
    )

    $_disktype = $_Form.FindName("DiskType")
    $_disktype.add_SelectionChanged(
        {
            param($sender,$args)
            $selected = $sender.SelectedItem.Content
            if ($selected -eq "ANF") {
                $_Form.FindName("LabelANFResourceGroup").Visibility = "Visible"
                $_Form.FindName("LabelANFAccountName").Visibility = "Visible"
                $_Form.FindName("ANFResourceGroup").Visibility = "Visible"
                $_Form.FindName("ANFAccountName").Visibility = "Visible"
            }
            else {
                $_Form.FindName("LabelANFResourceGroup").Visibility = "Hidden"
                $_Form.FindName("LabelANFAccountName").Visibility = "Hidden"
                $_Form.FindName("ANFResourceGroup").Visibility = "Hidden"
                $_Form.FindName("ANFAccountName").Visibility = "Hidden"
            }
        }
    )

    $_ButtonExit = $_Form.FindName("ButtonExit")
    $_ButtonExit.Add_Click(
        {
            $_Form.Close()
            exit
        }
    )

    $_GUI_ResourceGroups = $_Form.FindName("ResourceGroup")

    # add resource groups
    $_ResourceGroups = Get-AzResourceGroup | Select-Object ResourceGroupName | Sort-Object
    $_GUI_ResourceGroups.ItemsSource = $_ResourceGroups.ResourceGroupName | Sort-Object
    #foreach ($_resourcegroup in $_ResourceGroups) {
    #    [void]$_GUI_ResourceGroups.Items.Add($_resourcegroup.ResourceGroupName)
    #}

    $_GUI_VMs = $_Form.FindName("VM")

    $_GUI_ResourceGroups.add_SelectionChanged(
        {
            # add VMs
            $_GUI_VMs.Items.Clear()

            $_VMs = Get-AzVM -ResourceGroupName $_GUI_ResourceGroups.Items[$_GUI_ResourceGroups.SelectedIndex]
            foreach ($_VM in $_VMs) {
                $_GUI_VMs.Items.Add($_VM.Name)
            }
        }
    )

    $_GUI_IPaddress = $_Form.FindName("hostname")

    $_GUI_VMs.add_SelectionChanged(
        {
            # get IP of first nic
            $_VM = Get-AzVM -ResourceGroupName $_GUI_ResourceGroups.Items[$_GUI_ResourceGroups.SelectedIndex] -Name $_GUI_VMs.Items[$_GUI_VMs.SelectedIndex]
            #$_NetworkInterface = Get-AzNetworkInterfaceIpConfig -NetworkInterface $_VM.NetworkProfile.NetworkInterfaces
            $_GUI_IPaddress.Text = (Get-AzNetworkInterface -resourceid  $_VM.NetworkProfile.NetworkInterfaces.Id).IpConfigurations.PrivateIpAddress
        }
    )

    $_GUI_ANFResourceGroups = $_Form.FindName("ANFResourceGroup")

    # add ANF resource group
    $_ANFResourceGroups = Get-AzResourceGroup | Select-Object ResourceGroupName | Sort-Object
    $_GUI_ANFResourceGroups.ItemsSource = $_ANFResourceGroups.ResourceGroupName | Sort-Object

    $_GUI_ANFAccountName = $_Form.FindName("ANFAccountName")

    $_GUI_ANFResourceGroups.add_SelectionChanged(
        {
            # add ANFs
            $_GUI_ANFAccountName.Items.Clear()

            $_ANFs = Get-AzNetAppFilesAccount -ResourceGroupName $_GUI_ANFResourceGroups.Items[$_GUI_ANFResourceGroups.SelectedIndex]
            foreach ($_ANF in $_ANFs) {
                $_GUI_ANFAccountName.Items.Add($_ANF.Name)
            }
        }
    )

    # add Run button
    $_ButtonRun = $_Form.FindName("ButtonRun")
    $_ButtonRun.Add_Click(
        {
            # when "RUN" button is pressed
            $_gui_password_value = $_Form.FindName("Password").Password
            $script:VMUsername = $_Form.FindName("Username").Text
            $script:VMPassword = ConvertTo-SecureString -String $_gui_password_value -AsPlainText -Force
            $script:VMHostname = $_Form.FindName("hostname").Text
            $script:VMDatabase = $_Form.FindName("Database").Items[$_Form.FindName("Database").SelectedIndex].Content
            $script:VMOperatingSystem = $_Form.FindName("OperatingSystem").Items[$_Form.FindName("OperatingSystem").SelectedIndex].Content
            $script:Hardwaretype = $_Form.FindName("HardwareType").Items[$_Form.FindName("HardwareType").SelectedIndex].Content
            $script:AzVMResourceGroup = $_Form.FindName("ResourceGroup").Items[$_Form.FindName("ResourceGroup").SelectedIndex]
            $script:AzVMName = $_Form.FindName("VM").Items[$_Form.FindName("VM").SelectedIndex]
            $script:DBDataDir = $_Form.FindName("DBDataDir").Text
            $script:DBLogDir = $_Form.FindName("DBLogDir").Text
            $script:DBSharedDir = $_Form.FindName("DBSharedDir").Text
            $script:HANADeployment = $_Form.FindName("HANAScenario").Items[$_Form.FindName("HANAScenario").SelectedIndex].Content
            $script:VMRole = $_Form.FindName("Role").Items[$_Form.FindName("Role").SelectedIndex].Content
            $script:VMConnectionPort = $_Form.FindName("SSHPort").Text
            if ($_Form.FindName("HighAvailability").isChecked) {
                $script:HighAvailability = $true
                $script:HighAvailabilityAgent = $_Form.FindName("HighAvailabilityAgent").Items[$_Form.FindName("HighAvailabilityAgent").SelectedIndex].Content
            }
            if ($_Form.FindName("DiskType").Items[$_Form.FindName("DiskType").SelectedIndex].Content -eq "ANF") {
                $script:ANFResourceGroup = $_Form.FindName("ANFResourceGroup").Items[$_Form.FindName("ANFResourceGroup").SelectedIndex]
                $script:ANFAccountName = $_Form.FindName("ANFAccountName").Items[$_Form.FindName("ANFAccountName").SelectedIndex]
            }
            else {
                $script:HighAvailability = $false
            }
            $script:GUILogonMethod = $_Form.FindName("LogonMethod").Items[$_Form.FindName("LogonMethod").SelectedIndex].Content

            $_Form.Close()
        }
    )

    #$_Form.Add_Closing({param($sender,$e)
    #    $script:_CloseButtonPressed = $true
    #})
    
    
    #show dialog
    [void]$_Form.ShowDialog()

}

#########
# Main module
#########

$script:_runlog = @()

$_breakingchangewarning = Get-AzConfig -DisplayBreakingChangeWarning
if ($_breakingchangewarning.Value -eq $true) {
    Update-AzConfig -DisplayBreakingChangeWarning $false
}

WriteRunLog -category "INFO" -message ("Start " + (Get-Date))

WriteRunLog -category "INFO" -message "Quality Check for SAP on Azure systems is provided under MIT license"
WriteRunLog -category "INFO" -message "see https://github.com/Azure/SAP-on-Azure-Scripts-and-Utilities/blob/main/LICENSE for details"

if ($LogonWithUserSSHKey -or $LogonAsRootSSHKey) {
    $script:VMPassword = ConvertTo-SecureString -String "dummypw" -AsPlainText -Force
}

# load json configuration
$_jsonconfig = Get-Content -Raw -Path $ConfigFileName -ErrorAction Stop | ConvertFrom-Json
if ($scriptversion -eq $_jsonconfig.Version) {
    # everything ok, script and json version match
}
else {
    WriteRunLog -category "ERROR" -message "Versions of script and json file don't match"
    exit
}

$script:_CloseButtonPressed = $false

if ($GUI) {
    if ($IsWindows) {
        LoadGUI
        if ($script:_CloseButtonPressed) {
            exit
        }
    }
    else {
        WriteRunLog -category "ERROR" -message "Sorry, GUI is only supported on Windows Systems"
        exit
    }
}

# read file in case of multiple runs
if ($MultiRun) {
    if (Test-Path -Path $ImportFile -PathType Leaf) {
        WriteRunLog -category "INFO" -message "Reading file for Quality Check runs"
        # read config file
        $_MultiRunData = Get-Content -Raw -Path $ImportFile | ConvertFrom-Csv -Delimiter ";"
        WriteRunLog -category "INFO" -message ("Read " + $_MultiRunData.Count + " entries in file")

        $script:VMPassword = read-host "Enter Password: " -asSecureString

    }
}

if (-not $MultiRun) {
    # single run
    # generate dummy structure
    $_MultiRunData = @()
    $_MultiRunData_Row = "" | Select-Object Data1
    $_MultiRunData_Row.Data1 = "onlysinglerun"
    $_MultiRunData += $_MultiRunData_Row
}

foreach ($_qcrun in $_MultiRunData) {

    if ($MultiRun) {
        # copy values to variables

        $script:_runlog = @()

        $script:VMUsername = $_qcrun.VMUsername
        $script:VMOperatingSystem = $_qcrun.VMOperatingSystem
        $script:VMDatabase = $_qcrun.VMDatabase
        $script:VMRole = $_qcrun.VMRole
        $script:VMHostname = $_qcrun.VMHostname
        $script:AzVMResourceGroup = $_qcrun.AzVMResourceGroup
        $script:AzVMName = $_qcrun.AzVMName

        if ($_qcrun.DBDataDir) {
            $script:DBDataDir = $_qcrun.DBDataDir
        }
        if ($_qcrun.DBLogDir) {
            $script:DBLogDir = $_qcrun.DBLogDir
        }
        if ($_qcrun.DBSharedDir) {
            $script:DBSharedDir = $_qcrun.DBSharedDir
        }
        if ($_qcrun.HANADeployment) {
            $script:HANADeployment = $_qcrun.HANADeployment
        }
        if ($_qcrun.ANFResourceGroup) {
            $script:ANFResourceGroup = $_qcrun.ANFResourceGroup
        }
        if ($_qcrun.ANFAccountName) {
            $script:ANFAccountName = $_qcrun.ANFAccountName
        }
        if ($_qcrun.HighAvailability -eq "TRUE") {
            $script:HighAvailability = $true
        }
        else {
            $script:HighAvailability = $false
        }
        if ($_qcrun.HighAvailabilityAgent) {
            $script:HighAvailabilityAgent = $_qcrun.HighAvailabilityAgent
        }

        switch($_qcrun.LogonMethod) {
            "UserPassword" {
                $script:GUILogonMethod = "UserPassword"
            }
            Default {
                $script:GUILogonMethod = "NoMatch"
            }
        }

    }
    else {
        # nothing to do, variables already populated

    }


    # parameter check and modification if required

    if ($VMOperatingSystem -in @("SUSE","RedHat","OracleLinux"))
    {
        #check if filesystem parameters end with /
        if ($script:DBDataDir.EndsWith("/")) {
            $script:DBDataDir = $script:DBDataDir.Substring(0,$script:DBDataDir.Length-1)
        }
        if ($script:DBLogDir.EndsWith("/")) {
            $script:DBLogDir = $script:DBLogDir.Substring(0,$script:DBLogDir.Length-1)
        }
        if ($script:DBSharedDir.EndsWith("/")) {
            $script:DBSharedDir = $script:DBSharedDir.Substring(0,$script:DBSharedDir.Length-1)
        }
    }

    if (-not $RunLocally) {

        # Check for required PowerShell modules
        CheckRequiredModules

        # Check for newer version of QualityCheck
        CheckForNewerVersion
        
        # Check Azure connectivity
        CheckAzureConnectivity
        
        # Check TCP connectivity
        CheckTCPConnectivity

        # Connect to VM
        $_SessionID = ConnectVM

        # Check if user is able to sudo
        if ($script:_ConnectVMResult) {
            CheckSudoPermission
        }
        else {
            $script:_CheckSudo = $false
        }

    }

    if ($HighAvailability) {

        # setting Fencing Agent for RH independant of customer settings as only RH is allowed
        if ($VMOperatingSystem -eq "RedHat") {
            WriteRunLog "OS is set to RedHat, HighAvailability set to FencingAgent"
            $HighAvailabilityAgent = "FencingAgent"
        }

        if ($VMOperatingSystem -eq "SUSE") {

            $_sbdcommand = PrepareCommand -Command "cat /etc/sysconfig/sbd | grep ^SBD_DEVICE | wc -l" -CommandType "OS" -RootRequired $true
            $_sbdconfig = RunCommand -p $_sbdcommand

            if ($_sbdconfig -eq "0") {
                # SBD Device config not found
                $HighAvailabilityAgent = "FencingAgent"
            }
            else {
                $HighAvailabilityAgent = "SBD"
            }
        }

    }

    # Load HTML Header
    LoadHTMLHeader

    # Collect PowerShell Parameters
    $_ParameterValues = @{}
    $_ParametersToIgnore = @("Verbose", "Debug", "ErrorAction", "WarningAction", "InformationAction", "ErrorVariable", "WarningVariable", "InformationVariable", "OutVariable", "OutBuffer", "PipelineVariable")
    foreach ($_parameter in $MyInvocation.MyCommand.Parameters.GetEnumerator()) {
        try {
            $_key = $_parameter.Key
            if($null -ne ($_value = Get-Variable -Name $_key -ValueOnly -ErrorAction Ignore)) {
                if($value -ne ($null -as $_parameter.Value.ParameterType)) {
                    $_ParameterValues[$_key] = $_value
                }
            }
            if($PSBoundParameters.ContainsKey($_key)) {
                $_ParameterValues[$_key] = $PSBoundParameters[$_key]
            }
            if (-not ($_ParametersToIgnore -contains $_key) ) {
                WriteRunLog -category "INFO" -message "Parameter $_key : $_value"
            }
        } finally {}
    }

    # Collect Script Parameters
    $_CollectScriptParameter = CollectScriptParameters

    # Collect VM info
    $_CollectVMInfo = CollectVMInformation

    # Get Azure Disks assigned to VMs
    $_CollectVMStorage = CollectVMStorage

    # Get Volume Groups - CollectVMStorage needs to run first to define variables
    $_CollectLVMGroups = CollectLVMGroups

    # Get Logical Volumes - CollectVMStorage needs to run first to define variables
    $_CollectLVMVolumes = CollectLVMVolummes

    if (-not $RunLocally) {
        # Get ANF Volume Info
        $_CollectANFVolumes = CollectANFVolumes
    }

    # Get Filesystems
    $_CollectFileSystems = CollectFileSystems

    if (-not $RunLocally) {
        # Get Network Interfaces
        $_CollectNetworkInterfaces = CollectNetworkInterfaces

        # Get Load Balancer - CollectNetworkInterfaces needs to run first to define variables
        $_CollectLoadBalancer = CollectLoadBalancer
    }

    # run Quality Check
    $_RunQualityCheck = RunQualityCheck

    # Collect VM info
    $_CollectVMInfoAdditional = CollectVMInformationAdditional

    # Collect footer for support cases
    $_CollectFooter = CollectFooter


    if (-not $RunLocally) {

        WriteRunLog -category "INFO" -message ("Creating HTML File: " + $_HTMLReportFileName)
        $_RunLogContent = $script:_runlog | ConvertTo-Html -Property * -Fragment -PreContent "<br><h2 id=""RunLog"">RunLog</h2>"

        $_HTMLReport = ConvertTo-Html -Body "$_Content $_CollectScriptParameter $_CollectVMInfo $_RunQualityCheck $_CollectFileSystems $_CollectVMStorage $_CollectLVMGroups $_CollectLVMVolumes $_CollectANFVolumes $_CollectNetworkInterfaces $_CollectLoadBalancer $_CollectVMInfoAdditional $_CollectFooter $_RunLogContent" -Head $script:_HTMLHeader -Title "Quality Check for SAP Worloads on Azure" -PostContent "<p id='CreationDate'>Creation Date: $(Get-Date)</p><p id='CreationDate'>Script Version: $scriptversion</p>"
        $_HTMLReportFileDate = $(Get-Date -Format "yyyyMMdd-HHmm")
        $_HTMLReportFileName = $AzVMName + "-" + $_HTMLReportFileDate + ".html"
        $_HTMLReport | Out-File .\$_HTMLReportFileName

        if ($AddJSONFile) {
            # adding JSONfile
            $_jsonoutput = "" | Select-Object Checks, Parameters, InformationCollection, Disks, Filesystems, RunLog

            WriteRunLog -category "INFO" -message ("Preparing JSON Output")

            $_jsonoutput.Checks = $script:_Checks
            $_jsonoutput.Parameters = $_ParameterValues
            $_jsonoutput.Disks = $script:_AzureDisks
            $_jsonoutput.Filesystems = $script:_filesystems
            $_jsonoutput.RunLog = $script:_runlog

            $_JSONReportFileName = $AzVMName + "-" + $_HTMLReportFileDate + ".json"
            $_jsonoutput = $_jsonoutput | ConvertTo-Json
            $_jsonoutput | Out-File .\$_JSONReportFileName
        }


    }
    else {
        # script running locally, convert result to JSON
        $_jsonoutput = "" | Select-Object Checks, Parameters, InformationCollection, Disks, Filesystems, RunLog

        WriteRunLog -category "INFO" -message ("Preparing JSON Output")
        WriteRunLog -category "INFO" -message ("End " + (Get-Date))

        $_jsonoutput.Checks = $script:_Checks
        $_jsonoutput.Parameters = $_ParameterValues
        $_jsonoutput.Disks = $script:_AzureDisks
        $_jsonoutput.Filesystems = $script:_filesystems
        $_jsonoutput.RunLog = $script:_runlog

        $_jsonoutput = $_jsonoutput | ConvertTo-Json

        Write-Host $_jsonoutput
        

        
    }

    if ((-not $RunLocally) -and $script:_ConnectVMResult) {
        Remove-SSHSession -SessionId $_SessionID | Out-Null
    }
}

# load report in browser for GUI runs
if ($GUI) {
    &(".\" + $_HTMLReportFileName)
}

if (-not $RunLocally) {
    WriteRunLog -category "INFO" -message ("End " + (Get-Date))
}

if ($_breakingchangewarning.Value -eq $true) {
    Update-AzConfig -DisplayBreakingChangeWarning $true
}


exit