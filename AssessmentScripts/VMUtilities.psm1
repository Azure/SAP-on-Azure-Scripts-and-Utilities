Write-Host "Loading functions"
function Get-VMInfo {
    <#
    .SYNOPSIS
        Return the information of a virtual machine.

    .DESCRIPTION
        Return the information of a virtual machine.

    .PARAMETER VirtualMachineName
        This is the name of the Virtual Machine.

    .PARAMETER ResourceGroupName
        This is the name of the resource group .

    .EXAMPLE 

    #
    #
    # Import the module
    Import-Module "./VMUtilities.psd1"
    Get-VMInfo -ResourceGroupName test-rg -VirtualMachineName vm1 

    .EXAMPLE

    #
    # Import the module
    Import-Module "./VMUtilities.psd1"
    $ResourceGroupName="MyResourceGroup"

    #Get a list of all VM's in a resource group
    $VMs=(Get-AzResource -ResourceGroupName $ResourceGroupName -ResourceType Microsoft.Compute/virtualMachines).Name
    foreach ($vmName in $VMs)
    {
        Write-Host ""

        Get-VMInfo -VirtualMachineName $vmName -ResourceGroupName $ResourceGroupName
    }


    .EXAMPLE

    #
    # Import the module
    Import-Module "./VMUtilities.psd1"
    $ResourceGroupName="MyResourceGroup"

    #Get a list of all VM's with a specific tag
    $VMs=(Get-AzResource -ResourceGroupName $ResourceGroupName -Tag @{ System="SAP" } -ResourceType Microsoft.Compute/virtualMachines).Name
    foreach ($vmName in $VMs)
    {
        Write-Host ""

        Get-VMInfo -VirtualMachineName $vmName -ResourceGroupName $ResourceGroupName
    }

.LINK
    https://github.com/Azure/SAP-on-Azure-Scripts-and-Utilities

.NOTES
    v0.1 - Initial version

.

    #>
    <#
Copyright (c) Microsoft Corporation.
Licensed under the MIT license.
#>

    [cmdletbinding()]
    Param (
        #Resource Group Name that will be created
        [Parameter(Mandatory = $true)][string]$ResourceGroupName, 
        #Virtual Machine name
        [Parameter(Mandatory = $true)][string]$VirtualMachineName
    )

    $VMInfo = new-object PSObject

    $VMInfo | add-member -MemberType NoteProperty -Name "Name" -Value $VirtualMachineName
    $VMInfo | add-member -MemberType NoteProperty -Name "Resourcegroup" -Value $ResourceGroupName
        
    Write-Host -ForegroundColor Yellow 'Getting the virtual machine information for virtual machine:' $VirtualMachineName
    $tempVM = Get-AzVM -Name $VirtualMachineName -ResourceGroupName $ResourceGroupName
    if ($tempVM) {

        $VMInfo | add-member -MemberType NoteProperty -Name "Operating System" -Value $tempVM.StorageProfile.OsDisk.OsType
        $VMInfo | add-member -MemberType NoteProperty -Name "Location" -Value $tempVM.Location
        if ($tempVM.Zones) {
            $VMInfo | add-member -MemberType NoteProperty -Name "Zone" -Value $tempVM.Zones[0]
        }
        else {
            $VMInfo | add-member -MemberType NoteProperty -Name "Zone" -Value "None"
        }

            
        $VMInfo | add-member -MemberType NoteProperty -Name "Size" -Value $tempVM.HardwareProfile.VmSize
            
        if ($tempVM.AvailabilitySetReference) {
            $avSetInfo = Get-AzResource -ResourceId $tempVM.AvailabilitySetReference.Id 
            $VMInfo | add-member -MemberType NoteProperty -Name "AvailabilitySet" -Value $avSetInfo.Name
        }
        else {
            $VMInfo | add-member -MemberType NoteProperty -Name "AvailabilitySet" -Value "None"
        }
            
        if ($tempVM.ProximityPlacementGroup) {
            $ppgInfo = Get-AzResource -ResourceId $tempVM.ProximityPlacementGroup.Id
            $VMInfo | add-member -MemberType NoteProperty -Name "ProximityPlacementGroup" -Value $ppgInfo.Name
        }
        else {
            $VMInfo | add-member -MemberType NoteProperty -Name "ProximityPlacementGroup" -Value "None"    
        }
            
        $networkStatus = Get-NetworkInfo -VirtualMachineName $VirtualMachineName -ResourceGroupName $ResourceGroupName
        $VMInfo | add-member  -MemberType NoteProperty -Name "Private IP" -Value $networkStatus."Private IP"
        $VMInfo | add-member  -MemberType NoteProperty -Name "Public IP" -Value $networkStatus."Public IP"
        $VMInfo | add-member  -MemberType NoteProperty -Name "VNet" -Value $networkStatus.VNet
        $VMInfo | add-member  -MemberType NoteProperty -Name "Subnet" -Value $networkStatus.Subnet
        $VMInfo | add-member  -MemberType NoteProperty -Name "Accelerated Networking" -Value $networkStatus."Accelerated Networking"

        $colocationStatus = DiskColocationStatus -VirtualMachineName $VirtualMachineName -ResourceGroupName $ResourceGroupName
        $VMInfo | add-member -MemberType NoteProperty -Name "Disk Colocation" -Value $colocationStatus
    }
    else {
        Write-Error "Virtual machine " $VirtualMachineName " was not found in resource group " $ResourceGroupName
    }
    return $VMInfo
}
function Get-DiskInfo {
    <#
    .SYNOPSIS
        Return the disk information of a virtual machine.

    .DESCRIPTION
        Return the disk information of a virtual machine.

    .PARAMETER VirtualMachineName
        This is the name of the Virtual Machine.

    .PARAMETER ResourceGroupName
        This is the name of the resource group .

    .EXAMPLE 

    #
    #
    # Import the module
    Import-Module "./VMUtilities.psd1"
    Get-DiskInfo -ResourceGroupName test-rg -VirtualMachineName vm1 

    .EXAMPLE

    #
    # Import the module
    Import-Module "./VMUtilities.psd1"
    $ResourceGroupName="MyResourceGroup"

    #Get a list of all VM's in a resource group
    $VMs=(Get-AzResource -ResourceGroupName $ResourceGroupName -ResourceType Microsoft.Compute/virtualMachines).Name
    foreach ($vmName in $VMs)
    {
        Write-Host ""

        Get-DiskInfo -VirtualMachineName $vmName -ResourceGroupName $ResourceGroupName
    }


    .EXAMPLE

    #
    # Import the module
    Import-Module "./VMUtilities.psd1"
    $ResourceGroupName="MyResourceGroup"

    #Get a list of all VM's with a specific tag
    $VMs=(Get-AzResource -ResourceGroupName $ResourceGroupName -Tag @{ System="SAP" } -ResourceType Microsoft.Compute/virtualMachines).Name
    foreach ($vmName in $VMs)
    {
        Write-Host ""

        Get-DiskInfo -VirtualMachineName $vmName -ResourceGroupName $ResourceGroupName
    }
    
.LINK
    https://github.com/Azure/SAP-on-Azure-Scripts-and-Utilities

.NOTES
    v0.1 - Initial version

.

    #>
    <#
Copyright (c) Microsoft Corporation.
Licensed under the MIT license.
#>
    [cmdletbinding()]
    Param (
        #Resource Group Name that will be created
        [Parameter(Mandatory = $true)][string]$ResourceGroupName, 
        #Virtual Machine name
        [Parameter(Mandatory = $true)][string]$VirtualMachineName
    )
    
    $Disks = @()

    #Get the Virtual machine

    $tempVM = Get-AzVM -Name $VirtualMachineName -ResourceGroupName $ResourceGroupName
    if ($tempVM) {
        $disk = $tempVM.StorageProfile.OsDisk

        if ($disk) {
            #Create an object and add the Virtual Machines properties to it
            $Disk_Temp = new-object PSObject
            $Disk_Temp | add-member -MemberType NoteProperty -Name "VMName" -Value $VirtualMachineName
            $Disk_Temp | add-member -MemberType NoteProperty -Name "Disk Name" -Value $disk.Name
            $Disk_Temp | add-member -MemberType NoteProperty -Name "Lun" -Value $null
            $Disk_Temp | add-member -MemberType NoteProperty -Name "Caching" -Value $disk.Caching
            $Disk_Temp | add-member -MemberType NoteProperty -Name "OSDisk" -Value $true
            $Disk_Temp | add-member -MemberType NoteProperty -Name "WriteAcceleratorEnabled" -Value $disk.WriteAcceleratorEnabled
            
            $disk2 = Get-AzDisk -ResourceGroupName $ResourceGroupName -DiskName $disk.Name 
            if ($disk2) {

                $sku = $disk2.Sku.Name
                $skuPrefix = $sku.Substring(0, $sku.IndexOf('_'))
                $prefix = "S"

                switch ($skuPrefix) {
                    "StandardSSD" {
                        $prefix = "E"
                        break;
                    }
                    "Premium" {
                        $prefix = "P"
                        break;
                    }
                    "UltraSSD" {
                        $prefix = "U"
                        break;
                    }
                }

                $diskType = Get-DiskType($disk2.DiskSizeGB)
                $dType = [string]($prefix + $diskType)
                
                $Disk_Temp | add-member -MemberType NoteProperty -Name "Size In GB" -Value $disk2.DiskSizeGB
                $Disk_Temp | add-member -MemberType NoteProperty -Name "Type" -Value $dType
                $Disk_Temp | add-member -MemberType NoteProperty -Name "SKU" -Value $disk2.Sku.Name
                if ($disk2.Zones) {
                    $Disk_Temp | add-member -MemberType NoteProperty -Name "Zone" -Value $disk2.Zones[0]
                }
                else {
                    $Disk_Temp | add-member -MemberType NoteProperty -Name "Zone" -Value $false
                }
                $Disks += $Disk_Temp
            }

        }
        foreach ($dataDisk in $tempVM.StorageProfile.DataDisks) {
            $Disk_Temp = new-object PSObject
            $Disk_Temp | add-member -MemberType NoteProperty -Name "VMName" -Value $VirtualMachineName
            $Disk_Temp | add-member -MemberType NoteProperty -Name "Disk Name" -Value $dataDisk.Name
            $Disk_Temp | add-member -MemberType NoteProperty -Name "Lun" -Value $dataDisk.Lun
            
            $Disk_Temp | add-member -MemberType NoteProperty -Name "Caching" -Value $dataDisk.Caching
            $Disk_Temp | add-member -MemberType NoteProperty -Name "OSDisk" -Value $false
            $Disk_Temp | add-member -MemberType NoteProperty -Name "WriteAcceleratorEnabled" -Value $dataDisk.WriteAcceleratorEnabled

            $disk2 = Get-AzDisk -ResourceGroupName $ResourceGroupName -DiskName $disk.Name 
            if ($disk2) {

                $sku = $disk2.Sku.Name
                $skuPrefix = $sku.Substring(0, $sku.IndexOf('_'))
                $prefix = "S"

                switch ($skuPrefix) {
                    "StandardSSD" {
                        $prefix = "E"
                        break;
                    }
                    "Premium" {
                        $prefix = "P"
                        break;
                    }
                    "UltraSSD" {
                        $prefix = "U"
                        break;
                    }
                }

                $diskType = Get-DiskType($disk2.DiskSizeGB)
                $dType = [string]($prefix + $diskType)
                
                $Disk_Temp | add-member -MemberType NoteProperty -Name "Size In GB" -Value $disk2.DiskSizeGB
                $Disk_Temp | add-member -MemberType NoteProperty -Name "Type" -Value $dType
                $Disk_Temp | add-member -MemberType NoteProperty -Name "SKU" -Value $disk2.Sku.Name
                if ($disk2.Zones) {
                    $Disk_Temp | add-member -MemberType NoteProperty -Name "Zone" -Value $disk2.Zones[0]
                }
                else {
                    $Disk_Temp | add-member -MemberType NoteProperty -Name "Zone" -Value $false
                }

                $Disks += $Disk_Temp
            }

        }
    
    }
    else {
        $status = "Virtual machine " + $VirtualMachineName + " was not found"
        Write-Error $status
    }
    return $Disks    
}
function Get-DiskType {
    <#
    .SYNOPSIS
        Return the type of disk based on the size.

    .DESCRIPTION
        This functions returns the type of disk.

    .PARAMETER diskSizeInGB
        This is the size of the disk.

    .EXAMPLE
       Get-DiskType(255)

    .LINK
        For more info see: https://docs.microsoft.com/en-us/azure/virtual-machines/windows/disks-types

    #>
    [cmdletbinding()]
    Param (
        [int]$diskSizeInGB
    )
    $diskType = "4"
    if ($diskSizeInGB -le 32) {
        $diskType = "4 (32)"
    }
    elseif ($diskSizeInGB -le 64) {
        $diskType = "6 (64)"
    }
    elseif ($diskSizeInGB -le 128) {
        $diskType = "10 (128)"
    }
    elseif ($diskSizeInGB -le 256) {
        $diskType = "15 (256)"
    }
    elseif ($diskSizeInGB -le 512) {
        $diskType = "20 (512)"
    }
    elseif ($diskSizeInGB -le 1024) {
        $diskType = "30 (1024)"
    }
    elseif ($diskSizeInGB -le 2048) {
        $diskType = "40 (2048)"
    }
    elseif ($diskSizeInGB -le 4096) {
        $diskType = "50 (4096)"
    }
    elseif ($diskSizeInGB -le 8192) {
        $diskType = "60 (8192)"
    }

    return  $diskType


}


function Get-DiskColocationStatus {
    <#
    .SYNOPSIS
        Return the status of disk colocation flag.

    .DESCRIPTION
        This functions returns the status of disk colocation.
        This will eventually be obsolute

    .PARAMETER VirtualMachineName
        This is the name of the Virtual Machine.

    .PARAMETER ResourceGroupName
        This is the name of the resource group .


.EXAMPLE
    ./Get-DiskInfo.ps1  -ResourceGroupName test-rg -VirtualMachineName vm1 

.LINK
    https://github.com/Azure/SAP-on-Azure-Scripts-and-Utilities

.NOTES
    v0.1 - Initial version


    #>
    [cmdletbinding()]
    Param (
        #Resource Group Name that will be used
        [Parameter(Mandatory = $true)][string]$ResourceGroupName, 
        #Virtual Machine name
        [Parameter(Mandatory = $true)][string]$VirtualMachineName
    )
    $returnValue = $false
    $keyName = '$perfOptimizationLevel'

    $tempVM = Get-AzVM -Name $VirtualMachineName -ResourceGroupName $ResourceGroupName
    if ($tempVM) {
        $tags = $tempVM.Tags
        if ($tags) {
            if ($tags.ContainsKey($keyName)) {
                $temptag = $tags[$keyName];
                if ($temptag -eq "1") {
                    $returnValue = $true
                }
            }
        }
    }
    else {
        Write-Error "Virtual machine " $VirtualMachineName " was not found in resource group " $ResourceGroupName
    }


    return  $returnValue


}
function Get-NetworkInfo {
    <#
    .SYNOPSIS
        Return the status of accelerated networking.

    .DESCRIPTION
        This functions returns the status of the accelerated networking.

    .PARAMETER VirtualMachineName
        This is the name of the Virtual Machine.

    .PARAMETER ResourceGroupName
        This is the name of the resource group .

    .EXAMPLE 

    #
    #
    # Import the module
    Import-Module "./VMUtilities.psd1"
    Get-NetworkInfo -ResourceGroupName test-rg -VirtualMachineName vm1 

    .EXAMPLE

    #
    # Import the module
    Import-Module "./VMUtilities.psd1"
    $ResourceGroupName="MyResourceGroup"

    #Get a list of all VM's in a resource group
    $VMs=(Get-AzResource -ResourceGroupName $ResourceGroupName -ResourceType Microsoft.Compute/virtualMachines).Name
    foreach ($vmName in $VMs)
    {
        Write-Host ""

        Get-NetworkInfo -VirtualMachineName $vmName -ResourceGroupName $ResourceGroupName
    }


    .EXAMPLE

    #
    # Import the module
    Import-Module "./VMUtilities.psd1"
    $ResourceGroupName="MyResourceGroup"

    #Get a list of all VM's with a specific tag
    $VMs=(Get-AzResource -ResourceGroupName $ResourceGroupName -Tag @{ System="SAP" } -ResourceType Microsoft.Compute/virtualMachines).Name
    foreach ($vmName in $VMs)
    {
        Write-Host ""

        Get-NetworkInfo -VirtualMachineName $vmName -ResourceGroupName $ResourceGroupName
    }

    https://github.com/Azure/SAP-on-Azure-Scripts-and-Utilities

.NOTES
    v0.1 - Initial version


    #>
    <#
Copyright (c) Microsoft Corporation.
Licensed under the MIT license.
#>
    [cmdletbinding()]
    Param (
        [string]$VirtualMachineName,
        [string]$ResourceGroupName
    )
    
    Write-Host -ForegroundColor Yellow 'Getting the network information for virtual machine:' $VirtualMachineName
    $tempVM = Get-AzVM -Name $VirtualMachineName -ResourceGroupName $ResourceGroupName
    if ($tempVM) {
        $NICInfo = new-object PSObject

        $nicDetails = Get-AzNetworkInterface -ResourceId $tempVM.NetworkProfile.NetworkInterfaces[0].Id
        if ([int]$nicDetails.IpConfigurations.Count -ge 0) {
            $NICInfo | add-member -MemberType NoteProperty -Name "VMName" -Value $VirtualMachineName
            $NICInfo | add-member -MemberType NoteProperty -Name "Private IP" -Value $nicDetails.IpConfigurations[0].PrivateIpAddress
            if ($nicDetails.IpConfigurations[0].PublicIpAddress.Id.Length -gt 0) {
                $PIP = Get-AzPublicIpAddress -Name $nicDetails.IpConfigurations[0].PublicIpAddress.Id.Substring($nicDetails.IpConfigurations[0].PublicIpAddress.Id.LastIndexOf("/") + 1)
                if ($PIP) {
                    $NICInfo | add-member -MemberType NoteProperty -Name "Public IP" -Value $PIP.IpAddress
                }
                else {
                    $NICInfo | add-member -MemberType NoteProperty -Name "Public IP" -Value ""
                }
            }
            else {
                $NICInfo | add-member -MemberType NoteProperty -Name "Public IP" -Value ""
            }

            $netInfo = $nicDetails.IpConfigurations[0].Subnet.Id
            $vnetName = $netInfo.Substring($netInfo.IndexOf("virtualNetworks") + 16)
            $vnetName = $vnetName.Substring(0, $vnetName.IndexOf("/"))
            $NICInfo | add-member -MemberType NoteProperty -Name "VNet" -Value $vnetName
                
            $subNetName = $netInfo.Substring( $netInfo.LastIndexOf('/') + 1)
            $NICInfo | add-member -MemberType NoteProperty -Name "Subnet" -Value $subNetName 
        }

        $NICInfo | add-member -MemberType NoteProperty -Name "Accelerated Networking" -Value $nicDetails.EnableAcceleratedNetworking
        return  $NICInfo
    }
    else {
        Write-Error "Virtual machine " $VirtualMachineName " was not found in resource group " $ResourceGroupName
    }


}


Export-ModuleMember -Function Get-DiskInfo
Export-ModuleMember -Function Get-VMInfo
Export-ModuleMember -Function Get-NetworkInfo