<#

.SYNOPSIS
    Creates VMs and tests latency between VMs

.DESCRIPTION
    The script creates VMs in Zone 1, 2 and 3, installing qperf on it and testing latency between VMs

.PARAMETER Region
    The Azure region name

.EXAMPLE
    ./AvZone-Latency-Test.ps1 -Region westeurope

    Example output:

        Region:  westeurope
        VM Type:  Standard_E8s_v3
        Latency:
                 ----------------------------------------------
                 |    zone 1    |    zone 2    |    zone 3    |
        -------------------------------------------------------
        | zone 1 |              |        xx us |        xx us |
        | zone 2 |        xx us |              |        xx us |
        | zone 3 |        xx us |        xx us |              |
        -------------------------------------------------------

        Bandwidth:
                 ----------------------------------------------
                 |    zone 1    |    zone 2    |    zone 3    |
        -------------------------------------------------------
        | zone 1 |              |   xxx MB/sec |   xxx MB/sec |
        | zone 2 |   xxx MB/sec |              |   xxx MB/sec |
        | zone 3 |   xxx MB/sec |   xxx MB/sec |              |
        -------------------------------------------------------

.LINK
    https://github.com/Azure/SAP-on-Azure-Scripts-and-Utilities

.NOTES
    v0.1 - Initial version
    v0.2 - adding usage of existing VNET
    v0.3 - switching from variables to parameters
         - adding documentation
         - adding logon check

#>
<#
Copyright (c) Microsoft Corporation.
Licensed under the MIT license.
#>

#Requires -Modules Posh-SSH
#Requires -Modules Az.Compute
#Requires -Version 5.1

param(
    #Azure Subscription Name
    [Parameter(Mandatory=$true)][string]$SubscriptionName,
    #Azure Region, use Get-AzLocation to get region names
    [string]$region = "westeurope", 
    #Resource Group Name that will be created
    [string]$ResourceGroupName = "AvZoneLatencyTest", 
    #Delete the test environment after test
    [boolean]$DestroyAfterTest = $true, 
    #Use an existing VNET, direct SSH connection to VMs required
    [boolean]$UseExistingVnet = $false, 
    #use existing VMs of a previous test
    [boolean]$UseExistingVMs = $false, 
    #use public IP addresses to connect
    [boolean]$UsePublicIPAddresses = $true, 
    # VM type, recommended Standard_D8s_v3
    [string]$VMSize = "Standard_D8s_v3", 
    #OS provider, for CentOS it is OpenLogic
    [string]$OSPublisher = "OpenLogic", 
    #OS Type
    [string]$OSOffer = "CentOS", 
    #OS Verion
    [string]$OSSku = "7.6", 
    #Latest OS image
    [string]$OSVersion = "latest", 
    #OS username
    [string]$VMLocalAdminUser = "azping", 
    #OS password
    [string]$VMLocalAdminPassword = "P@ssw0rd!", 
    #VM name prefix, 1,2,3 will be added based on zone
    [string]$VMPrefix = "azping-vm0", 
    #VM nic name
    [string]$NICPostfix = "-nic1", 
    #Public IP address postfix
    [string]$pippostfix = "-pip", 
    #Azure Network Security Group (NSG) name
    [string]$NSGName = "azping-nsg", 
    #Azure VNET name, if using existing VNET
    [string]$NetworkName = "azping-mgmt-vnet", 
    #Azure Subnet name, if using exising
    [string]$SubnetName = "default", 
    #Resource Group Name of existing VNET
    [string]$ResourceGroupNameNetwork = "azping-mgmt", 
    #Azure IP Subnet prefix if using public IP to VNET creation
    [string]$SubnetAddressPrefix = "10.1.1.0/24", 
    #Azure IP VNET prefix if using public IP to VNET creation
    [string]$VnetAddressPrefix = "10.1.1.0/24" 
)


	# select subscription
	$Subscription = Get-AzSubscription -SubscriptionName $SubscriptionName
    if (-Not $Subscription) {
        Write-Host -ForegroundColor Red -BackgroundColor White "Sorry, it seems you are not connected to Azure or don't have access to the subscription. Please use Connect-AzAccount to connect."
        exit
    }


    Select-AzSubscription -Subscription $SubscriptionName -Force

    $VMLocalAdminSecurePassword = ConvertTo-SecureString $VMLocalAdminPassword -AsPlainText -Force

    $zones = 3

    
    #create the secure credential object
	$Credential = New-Object System.Management.Automation.PSCredential ($VMLocalAdminUser, $VMLocalAdminSecurePassword);

    # initialize the arrays for outputs
    $latency = @(("","",""),("","",""),("","",""))
    $bandwidth = @(("","",""),("","",""),("","",""))

    for ($x=1; $x -le $zones; $x++) {
        for ($y=1; $y -le 3; $y++) {
            $latency[$x-1][$y-1] = "0"
            $bandwidth[$x-1][$y-1] = "0"
        }
    }

    

    if ($UseExistingVMs) {
        Write-Host "Using existing VMs" -ForegroundColor Green
    }
    else {

        # create resource group
        Write-Host -ForegroundColor Green "Creating resource group"
        $ResourceGroup = New-AzResourceGroup -Location $region -Name $ResourceGroupName
    
        # create vNET and Subnet or getting existing
	    if ($UseExistingVnet) {
            Write-Host -ForegroundColor Green "Getting existing vNET and Subnet Config"
            $Vnet = Get-AzVirtualNetwork -Name $NetworkName -ResourceGroupName $ResourceGroupNameNetwork
            $SingleSubnet = Get-AzVirtualNetworkSubnetConfig -VirtualNetwork $Vnet -Name $SubnetName
        }
        else {
            Write-Host -ForegroundColor Green "Creating vNET and Subnet"
            $SingleSubnet = New-AzVirtualNetworkSubnetConfig -Name $SubnetName -AddressPrefix $SubnetAddressPrefix
            $Vnet = New-AzVirtualNetwork -Name $NetworkName -ResourceGroupName $ResourceGroupName -Location $region -AddressPrefix $VnetAddressPrefix -Subnet $SingleSubnet
        }

        # create NSG
        Write-Host -ForegroundColor Green "Creating NSG"
        $rule1 = New-AzNetworkSecurityRuleConfig -Name ssh-rule -Description "Allow SSH" -Access Allow -Direction Inbound -Protocol Tcp -Priority 100 -SourcePortRange * -SourceAddressPrefix * -DestinationAddressPrefix * -DestinationPortRange 22
        $nsg = New-AzNetworkSecurityGroup -ResourceGroupName $ResourceGroupName -Location $region -Name $NSGName -SecurityRules $rule1

    
        # create VMs
        Write-Host -ForegroundColor Green "Creating VMs"
        For ($zone=1; $zone -le $zones; $zone++) {

            $ComputerName = $VMPrefix + $zone
            $NICName = $ComputerName + $NICPostfix
       	    $PIPName = $NICName + $pippostfix
	        $Subnet = Get-AzVirtualNetworkSubnetConfig -Name $SubnetName -VirtualNetwork $Vnet
    	    if ($UsePublicIPAddresses) {
                $PIP = New-AzPublicIpAddress -Name $PIPName -ResourceGroupName $ResourceGroupName -Location $region -Sku Standard -AllocationMethod Static -IpAddressVersion IPv4 -Zone $zone
	            $IPConfig1 = New-AzNetworkInterfaceIpConfig -Name "IPConfig-1" -Subnet $Subnet -PublicIpAddress $PIP -Primary
            }
            else {
                $IPConfig1 = New-AzNetworkInterfaceIpConfig -Name "IPConfig-1" -Subnet $Subnet -Primary
            }
    	    $NIC = New-AzNetworkInterface -Name $NicName -ResourceGroupName $ResourceGroupName -Location $region -IpConfiguration $IpConfig1 -EnableAcceleratedNetworking -NetworkSecurityGroup $nsg
	        $VirtualMachine = New-AzVMConfig -VMName $ComputerName -VMSize $VMSize
            $VirtualMachine = Set-AzVMOperatingSystem -VM $VirtualMachine -Linux -ComputerName $ComputerName -Credential $Credential
            $VirtualMachine = Add-AzVMNetworkInterface -VM $VirtualMachine -Id $NIC.Id
            $VirtualMachine = Set-AzVMSourceImage -VM $VirtualMachine -PublisherName $OSPublisher -Offer $OSOffer -Skus $OSSku -Version $OSVersion
            $vm = New-AzVM -ResourceGroupName $ResourceGroupName -Location $region -VM $VirtualMachine -zone $zone -Verbose -AsJob
                
        }

	    # waiting for VM creation jobs to finish
        "All jobs created, waiting ..."
        Get-Job | Wait-Job
	    "All jobs completed"
	    Get-AzVM -ResourceGroupName $ResourceGroupName

        # adding some time as it sometimes helps :-)
        "Waiting for three minute for all systems to come up ..."
        Start-Sleep -Seconds 180
    }

    # creating SSH sessions to VMs

    Get-SSHTrustedHost | Remove-SSHTrustedHost

    Write-Host -ForegroundColor Green "Creating SSH sessions"
    For ($zone=1; $zone -le $zones; $zone++) {
        $ComputerName = $VMPrefix + $zone
        $pipname = $VMPrefix + $zone + $NICPostfix + $pippostfix 
        $NICName = $ComputerName + $NICPostfix

        if ($UsePublicIPAddresses) {
			$pipname = $VMPrefix + $zone + $NICPostfix + $pippostfix 
			$PIP = Get-AzPublicIpAddress -Name $pipname
			$ipaddress = $PIP.IpAddress
        }
        else {
			$nic = Get-AzNetworkInterface -Name $NICName
			$networkinterfaceconfig = Get-AzNetworkInterfaceIpConfig -NetworkInterface $nic
            $ipaddress = $networkinterfaceconfig.PrivateIpAddress
        }
        $sshsession = New-SSHSession -ComputerName $ipaddress -Credential $Credential -AcceptKey -Force
    }

    $sshsessions = Get-SSHSession

    # install qperf on all VMs
    Write-Host -ForegroundColor Green "Installing qperf on all VMs"
    For ($zone=1; $zone -le $zones; $zone++) {

        $output = Invoke-SSHCommand -Command "echo $VMLocalAdminPassword | sudo -S yum -y install qperf" -SessionId $sshsessions[$zone-1].SessionId
        $output = Invoke-SSHCommand -Command "nohup qperf &" -SessionId $sshsessions[$zone-1].SessionId -TimeOut 3 -ErrorAction silentlycontinue

    }

    # run performance tests
    Write-Host -ForegroundColor Green "Running bandwidth and latency tests"
    For ($zone=1; $zone -le $zones; $zone++) {

        $vmtopingno1 = (( $zone   %3)+1)
        $vmtoping1 = $VMPrefix + (( $zone   %3)+1)
        $vmtopingno2 = ((($zone+1)%3)+1)
        $vmtoping2 = $VMPrefix + ((($zone+1)%3)+1)

        $output = Invoke-SSHCommand -Command "qperf $vmtoping1 tcp_lat" -SessionId $sshsessions[$zone-1].SessionId
        $latencytemp = [string]$output.Output[1]
        $latencytemp = $latencytemp.substring($latencytemp.IndexOf("=")+3)
        $latencytemp = $latencytemp.PadLeft(12)
        $latency[$zone -1][$vmtopingno1 -1] = $latencytemp

        $output = Invoke-SSHCommand -Command "qperf $vmtoping1 tcp_bw" -SessionId $sshsessions[$zone-1].SessionId
        $bandwidthtemp = [string]$output.Output[1]
        $bandwidthtemp = $bandwidthtemp.substring($bandwidthtemp.IndexOf("=")+3)
        $bandwidthtemp = $bandwidthtemp.PadLeft(12)
        $bandwidth[$zone -1][$vmtopingno1 -1] = $bandwidthtemp

        $output = Invoke-SSHCommand -Command "qperf $vmtoping2 tcp_lat" -SessionId $sshsessions[$zone-1].SessionId
        $latencytemp = [string]$output.Output[1]
        $latencytemp = $latencytemp.substring($latencytemp.IndexOf("=")+3)
        $latencytemp = $latencytemp.PadLeft(12)
        $latency[$zone -1][$vmtopingno2 -1] = $latencytemp

        $output = Invoke-SSHCommand -Command "qperf $vmtoping2 tcp_bw" -SessionId $sshsessions[$zone-1].SessionId
        $bandwidthtemp = [string]$output.Output[1]
        $bandwidthtemp = $bandwidthtemp.substring($bandwidthtemp.IndexOf("=")+3)
        $bandwidthtemp = $bandwidthtemp.PadLeft(12)
        $bandwidth[$zone -1][$vmtopingno2 -1] = $bandwidthtemp

    }

    
    # Print output
    Write-Host "Region: " $region
    Write-Host "VM Type: " $VMSize

    Write-Host "Latency:"

    Write-Host "         ----------------------------------------------"
    Write-Host "         |    zone 1    |    zone 2    |    zone 3    |"
    Write-Host "-------------------------------------------------------"
    Write-Host "| zone 1 |              |" $latency[0][1] "|" $latency[0][2] "|"
    Write-Host "| zone 2 |" $latency[1][0] "|              |" $latency[1][2] "|"
    Write-Host "| zone 3 |" $latency[2][0] "|" $latency[2][1] "|              |"
    Write-Host "-------------------------------------------------------"

    Write-Host ""
    Write-Host "Bandwidth:"

    Write-Host "         ----------------------------------------------"
    Write-Host "         |    zone 1    |    zone 2    |    zone 3    |"
    Write-Host "-------------------------------------------------------"
    Write-Host "| zone 1 |              |" $bandwidth[0][1] "|" $bandwidth[0][2] "|"
    Write-Host "| zone 2 |" $bandwidth[1][0] "|              |" $bandwidth[1][2] "|"
    Write-Host "| zone 3 |" $bandwidth[2][0] "|" $bandwidth[2][1] "|              |"
    Write-Host "-------------------------------------------------------"


    # Removing SSH sessions
    Write-Host -ForegroundColor Green "Removing SSH Sessions"
    For ($zone=1; $zone -le $zones; $zone++) {
        Remove-SSHSession -SessionId $sshsessions[$zone-1].SessionId
    }


    #destroy resource group
    if ($DestroyAfterTest) {
        Write-Host -ForegroundColor Green "Deleting Resource Group"
        Remove-AzResourceGroup -Name $ResourceGroupName -Force
    }
    else
    {
        Write-Host -ForegroundColor Green "Resource group will NOT be deleted"
    }