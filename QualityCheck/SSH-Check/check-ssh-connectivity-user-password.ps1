<#
.SYNOPSIS
    SAP on Azure Quality Check - SSH check
.DESCRIPTION
    Script is used to check if SSH connectivity is working and which errors occur
.LINK
    https://github.com/Azure/SAP-on-Azure-Scripts-and-Utilities
#>
<#
Copyright (c) Microsoft Corporation.
Licensed under the MIT license.
#>

#Requires -Version 7.1
#Requires -Modules @{ ModuleName="Posh-SSH"; ModuleVersion="3.0.0" }

[CmdletBinding()]
param (
    [parameter(Mandatory=$true)][string]$IPorHostname,
    [int]$SSHPort=22
)

# getting credentials for SSH user/password
$cred = Get-Credential

# test TCP connectivity
try {
    $tcpconnectivity = New-Object System.Net.Sockets.TcpClient($IPorHostname, $SSHPort)
    if ($tcpconnectivity.Connected) {
        # connected
        Write-Host "TCP port open to $IPorHostname" -ForegroundColor Green
    }
    else {
        Write-Host "TCP port not reachable for $IPorHostname" -ForegroundColor Red
        exit
    }
}
catch {
    Write-Host "TCP port not reachable for $IPorHostname" -ForegroundColor Red
    Write-Host $_
    exit
}
# connect using SSH
try {
    $sshsession = New-SSHSession -ComputerName $IPorHostname -Credential $cred -Port $SSHPort -AcceptKey
    if ($sshsession.Connected -eq $true) {
        Write-Host "connected to $IPorHostname" -ForegroundColor Green
        Remove-SSHSession $sshsession.SessionId
    }
    else {
        Write-Host "unable to connect to $IPorHostname" -ForegroundColor Red
        exit
    }
}
catch {
    Write-Host "unable to connect to $IPorHostname" -ForegroundColor Red
    Write-Host $_
    exit
}

Write-Host "Script completed successfully" -ForegroundColor Green