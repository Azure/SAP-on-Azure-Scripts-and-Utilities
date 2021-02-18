function Write-WithTime {
    <#
    .SYNOPSIS 
    Formats messages includign the time stamp.
    
    .DESCRIPTION
    Formats messages includign the time stamp.
    
    .PARAMETER Message 
    Specify the the text Message.
    
    .PARAMETER Level 
    Specifiy severity level. Deafult is "Info". Optional parameter. 
    
    .PARAMETER Colour 
    Specifiy Colour  of message. Deafult is "NONE". Optional parameter. 
    
    .EXAMPLE     
    $VMName = "myVM"
    Write-WithTime "Virtual Machine '$VMName' is alreaday running."
 #> 
    
    [CmdletBinding()]
    param(            
        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()]        
        [string]$Message,
                  
        [string]$Level = "INFO"        
    )
    
    BEGIN {}
        
    PROCESS {
        try {   
            $DateAndTime = Get-Date -Format g
    
            $FormatedMessage = "[$DateAndTime] [$Level] $Message"

            Write-Output $FormatedMessage
            
        }
        catch {
            Write-Error  $_.Exception.Message
        }
    
    }
    
    END {}
}
    
function Get-AzVMManagedDisksType {
    <#
    .SYNOPSIS 
    List the disk and disk types attached to the VM.
    
    .DESCRIPTION
    List the disk and disk types attached to the VM.
    
    .PARAMETER ResourceGroupName 
    Resource Group Name of the VM.
    
    .PARAMETER VMName 
    VM name. 
    
    
    .EXAMPLE 
    # List all disk with disk type of the VM  'PR1-DB' in Azure resource group 'SAP-PR1-RG' .
    $ResourceGroupName = "SAP-PR1-RG"
    $VirtualMachineName = "PR1-DB"
    Get-AzVMManagedDisksType -ResourceGroupName $ResourceGroupName -VMName $VirtualMachineName
 #> 
 
    [CmdletBinding()]
    param(
        
        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()]        
        [string]$ResourceGroupName,
              
        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()]        
        [string] $VMName
     
    )

    BEGIN {}
    
    PROCESS {
        try {   
            
            $obj = New-Object -TypeName psobject

            $VM = Get-AzVM -ResourceGroupName $ResourceGroupName -Name $VMName

            $OSDisk = $VM.StorageProfile.OsDisk 
            $OSDiskName = $OSDisk.Name
            $OSDiskAllProperties = Get-AzDisk -ResourceGroupName $ResourceGroupName -DiskName $OSDiskName
            $OSDiskType = $OSDiskAllProperties.Sku.Name

            $obj | add-member  -NotePropertyName "DiskName" -NotePropertyValue $OSDiskName 
            $obj | add-member  -NotePropertyName "DiskType" -NotePropertyValue $OSDiskType
            $obj | add-member  -NotePropertyName "DiskRole" -NotePropertyValue "OSDisk"
            Write-Output $obj

            $DataDisks = $VM.StorageProfile.DataDisks
            $DataDisksNames = $DataDisks.Name

            foreach ($DataDiskName in $DataDisksNames) {
                $obj = New-Object -TypeName psobject
                $DataDiskAllProperties = Get-AzDisk -ResourceGroupName $ResourceGroupName -DiskName $DataDiskName
                $obj | add-member  -NotePropertyName "DiskName" -NotePropertyValue $DataDiskName 
                $obj | add-member  -NotePropertyName "DiskType" -NotePropertyValue $DataDiskAllProperties.Sku.Name
                $obj | add-member  -NotePropertyName "DiskRole" -NotePropertyValue "DataDisk"
                Write-Output $obj
            }

        }
        catch {
            Write-Error  $_.Exception.Message
        }

    }

    END {}
}

function Start-AzVMTagAndCheckVMStatus {
    <#
    .SYNOPSIS 
    Starts the VM(s) with a certain tag.
    
    .DESCRIPTION
    Starts the VM(s) with a certain SAP Instance type tag.
    The expected types are:
    - SAP_ASCS
    - SAP_SCS
    - SAP_DVEBMGS
    - DBMS
    - SAP_D
    - SAP_J
    
    .PARAMETER SAPVMs 
    List of VM resources. This collection is a list of VMs with same 'SAPSID' tag.
    
    .PARAMETER SAPInstanceType 
    One of the SAP Instance types:
    - SAP_ASCS
    - SAP_SCS
    - SAP_DVEBMGS
    - DBMS
    - SAP_D
    - SAP_J
    
    .EXAMPLE 
    # Get all the VMS with SAPSID tag 'PR1', and start ALL SAP ABAP application servers 'SAP_D'
    $SAPSID = "PR1"
    $tags = @{"SAPSystemSID"=$SAPSID}
    $SAPVMs = Get-AzResource -ResourceType "Microsoft.Compute/virtualMachines"  -Tag $tags
    Start-AzVMTagAndCheckVMStatus -SAPVMs $SAPVMs -SAPInstanceType "SAP_D"

 #>
    [CmdletBinding()]
    param(
        
        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()] 
        $SAPVMs,

        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()] 
        [string] $SAPInstanceType        
    )

    BEGIN {}
    
    PROCESS {
        try {                                       
            $SAPInstanceSpecificVMResources = $SAPVMs | Where-Object { $_.SAPInstanceType -EQ $SAPInstanceType }                    
            #Write-Output " "            

            if ($SAPInstanceSpecificVMResources -eq $null) {
                Switch ($SAPInstanceType) {
                    "SAP_ASCS" { Write-WithTime "No SAP Central Service Instance 'ASCS' VMs found in VMs Tags." }
                    "SAP_SCS" { Write-WithTime "No SAP Central Service Instance 'SCS' Instance VMs found in VMs Tags." }
                    "SAP_DVEBMGS" { Write-WithTime "No SAP ABAP Central Instance 'DVEBMGS' VM found in VMs Tags." }
                    "SAP_DBMS" { Write-WithTime "No SAP DBMS Instance VMs found in VMs Tags." }
                    "SAP_D" { Write-WithTime "No SAP SAP ABAP Application Server 'D' Instance VM found in VMs Tags." }
                    "SAP_J" { Write-WithTime "No SAP Java Application Server Instance 'J' found in VMs Tags." }   
                    Default {
                        Write-WithTime "Specified SAP Instance Type '$SAPInstanceType' is not existing."
                        Write-WithTime "Use one of these SAP instance types: 'SAP_ASCS', 'SAP_SCS', 'SAP_DVEBMGS', 'SAP_D', 'SAP_J', 'DBMS'."
                    }           
                }
            }
            else {
                Switch ($SAPInstanceType) {
                    "SAP_ASCS" { Write-WithTime   "Starting SAP Central Service Instance 'ASCS' VMs ..." }
                    "SAP_SCS" { Write-WithTime   "Starting Central Service Instance 'SCS' Instance VMs ..." }
                    "SAP_DVEBMGS" { Write-WithTime   "Starting SAP ABAP Central Instance 'DVEBMGS' VM ..." }
                    "SAP_DBMS" { Write-WithTime   "Starting SAP DBMS Instance VMs ..." }
                    "SAP_D" { Write-WithTime   "Starting SAP ABAP Application Server Instance 'D' VM ..." }
                    "SAP_J" { Write-WithTime   "Starting SAP Java Application Server Instance 'J' VMs ..." }   
                    Default {
                        Write-WithTime "Specified SAP Instance Type '$SAPInstanceType' is not existing."
                        Write-WithTime "Use one of these SAP instance types: 'SAP_ASCS', 'SAP_SCS', 'SAP_DVEBMGS', 'SAP_D', 'SAP_J', 'DBMS'."
                    }             
                }
            }


            ForEach ($VMResource in $SAPInstanceSpecificVMResources) {                
                $VMName = $VMResource.VMName
                $ResourceGroupName = $VMResource.ResourceGroupName

                $VMIsRunning = Test-AzVMIsStarted -ResourceGroupName  $ResourceGroupName -VMName $VMName

                if ($VMIsRunning -eq $False) {
                    # Start VM
                    Write-Output "Starting VM '$VMName' in Azure Resource Group '$ResourceGroupName' ..."
                    Start-AzVM  -ResourceGroupName $ResourceGroupName -Name $VMName -WarningAction "SilentlyContinue"

                    $VM = Get-AzVM -ResourceGroupName $ResourceGroupName -Name $VMName -Status
                    $VMStatus = $VM.Statuses[1].DisplayStatus
                    #Write-Output ""
                    Write-Output "Virtual Machine '$VMName' status: $VMStatus"
                    
                    Start-Sleep 60   
                }
                else {
                    Write-WithTime "Virtual Machine '$VMName' is alreaday running."
                }

            }

            Write-Output " "
            
        }
        catch {
            Write-Error  $_.Exception.Message
        }
    }

    END {}
}


function Stop-AzVMTagAndCheckVMStatus {
    <#
    .SYNOPSIS 
    Stops the VM(s) with a certain tag.
    
    .DESCRIPTION
    Stops the VM(s) with a certain SAP Instance type tag.
    The expected types are:
    - SAP_ASCS
    - SAP_SCS
    - SAP_DVEBMGS
    - DBMS
    - SAP_D
    - SAP_J
    
    .PARAMETER SAPVMs 
    List of VM resources. This collection is a list of VMs with same 'SAPSID' tag.
    
    .PARAMETER SAPInstanceType 
    One of the SAP Instance types:
    - SAP_ASCS
    - SAP_SCS
    - SAP_DVEBMGS
    - DBMS
    - SAP_D
    - SAP_J
    
    .EXAMPLE 
    # Get all the VMS with SAPSID tag 'PR1', and start ALL SAP ABAP application servers 'SAP_D'
    $SAPSID = "PR1"
    $tags = @{"SAPSystemSID"=$SAPSID}
    $SAPVMs = Get-AzResource -ResourceType "Microsoft.Compute/virtualMachines"  -Tag $tags
    Stop-AzVMTagAndCheckVMStatus -SAPVMs $SAPVMs -SAPInstanceType "SAP_D"

 #>
    [CmdletBinding()]
    param(
        
        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()] 
        $SAPVMs,

        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()] 
        [string] $SAPInstanceType        
    )

    BEGIN {}
    
    PROCESS {
        try {   

            $SAPInstanceSpecificVMResources = $SAPVMs | Where-Object { $_.SAPInstanceType -EQ $SAPInstanceType }                    
                        
            if ($SAPInstanceSpecificVMResources -eq $null) {
                Switch ($SAPInstanceType) {
                    "SAP_ASCS" { Write-WithTime "No SAP Central Service Instance 'ASCS' VMs found in VMs Tags." }
                    "SAP_SCS" { Write-WithTime "No SAP Central Service Instance 'SCS' Instance VMs found in VMs Tags." }
                    "SAP_DVEBMGS" { Write-WithTime "No SAP ABAP Central Instance 'DVEBMGS' VM found in VMs Tags ..." }
                    "SAP_DBMS" { Write-WithTime "No SAP DBMS Instance VMs found in VMs Tags ..." }
                    "SAP_D" { Write-WithTime "No SAP SAP ABAP Application Server 'D' Instance VM found in VMs Tags." }
                    "SAP_J" { Write-WithTime "No SAP Java Application Server Instance 'J' found in VMs Tags." }   
                    Default {
                        Write-WithTime "Specified SAP Instance Type '$SAPInstanceType' is not existing."
                        Write-WithTime "Use one of these SAP instance types: 'SAP_ASCS', 'SAP_SCS', 'SAP_DVEBMGS', 'SAP_D', 'SAP_J', 'DBMS'."
                    }             
                }
            }
            else {
                Switch ($SAPInstanceType) {
                    "SAP_ASCS" { Write-WithTime   "Stopping SAP Central Service Instance 'ASCS' VMs ..." }
                    "SAP_SCS" { Write-WithTime   "Stopping SAP Central Service Instance 'SCS' VMs ..." }
                    "SAP_DVEBMGS" { Write-WithTime   "Stopping SAP ABAP Central Instance 'DVEBMG' VM ..." }
                    "SAP_DBMS" { Write-WithTime   "Stopping SAP DBMS Instance VMs ..." }
                    "SAP_D" { Write-WithTime   "Stopping SAP ABAP Application Server 'D' Instance VMs ..." }
                    "SAP_J" { Write-WithTime   "Stopping SAP Java Application Server Instance 'J' VMs ..." }   
                    Default {
                        Write-WithTime "Specified SAP Instance Type '$SAPInstanceType' is not existing."
                        Write-WithTime "Use one of these SAP instance types: 'SAP_ASCS', 'SAP_SCS', 'SAP_DVEBMGS', 'SAP_D', 'SAP_J', 'DBMS'."
                    }               
                }
            }
                      
            ForEach ($VMResource in $SAPInstanceSpecificVMResources) {                
                $VMName = $VMResource.VMName
                $ResourceGroupName = $VMResource.ResourceGroupName

                #$VMIsRunning = Test-AzVMIsStarted -ResourceGroupName  $ResourceGroupName -VMName $VMName

                #if ($VMIsRunning -eq $False) {
                # Stop VM
                Write-Output "Stopping VM '$VMName' in Azure Resource Group '$ResourceGroupName' ..."
                Stop-AzVM  -ResourceGroupName $ResourceGroupName -Name $VMName -WarningAction "SilentlyContinue" -Force

                $VM = Get-AzVM -ResourceGroupName $ResourceGroupName -Name $VMName -Status
                $VMStatus = $VM.Statuses[1].DisplayStatus
                #Write-Output ""
                Write-Output "Virtual Machine '$VMName' status: $VMStatus"   
                #}
                #else {
                #Write-WithTime "Virtual Machine '$VMName' is alreaday running."
                #}

            }

            #Write-Output " "
            
        }
        catch {
            Write-Error  $_.Exception.Message
        }
    }

    END {}
}

function Get-AzSAPInstances {
    <#
    .SYNOPSIS 
    Get ALL VMs with same SAPSID tag.
    
    .DESCRIPTION
    Get ALL VMs with same SAPSID tag.
    For each VM it will display:
    - SAPSID
    - Azure Resource Group Name
    - VM Name
    - SAP Instance Type
    - OS type
    
    .PARAMETER SAPSID 
    SAP system SID.    
    
    .EXAMPLE 
    # specify SAP SID 'PR1'
    $SAPSID = "PR1"
    
    # Collect SAP VM instances with the same Tag
    $SAPInstances = Get-AzSAPInstances -SAPSID $SAPSID

    # List all collected instances
    $SAPInstances

 #>

    [CmdletBinding()]
    param(        
        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()] 
        $SAPSID         
    )

    BEGIN {}
    
    PROCESS {
        try {   
                      
            $tags = @{"SAPSystemSID" = $SAPSID }
            $SAPVMs = Get-AzResource -ResourceType "Microsoft.Compute/virtualMachines"  -Tag $tags

            foreach ($VMResource in $SAPVMs) {
                $obj = New-Object -TypeName psobject

                $OSType = Get-AzVMOSType -VMName $VMResource.Name -ResourceGroupName $VMResource.ResourceGroupName  
               
                $obj | add-member  -NotePropertyName "SAPSID" -NotePropertyValue $SAPSID  
                $obj | add-member  -NotePropertyName "ResourceGroupName" -NotePropertyValue $VMResource.ResourceGroupName  
                $obj | add-member  -NotePropertyName "VMName" -NotePropertyValue $VMResource.Name                  
                $obj | add-member  -NotePropertyName "SAPInstanceType"   -NotePropertyValue $VMResource.Tags.Item("SAPInstanceType")
                $obj | add-member  -NotePropertyName "OSType"   -NotePropertyValue $OSType 

                #Return formated object
                Write-Output $obj                                                
            }                       
        }
        catch {
            Write-Error  $_.Exception.Message
        }
    }

    END {}
}
function Get-AzSAPApplicationInstances {
    <#
    .SYNOPSIS 
    Get ALL VMs with same SAPSID tag, that runs applictaion layer.
    
    .DESCRIPTION
   Get ALL VMs with same SAPSID tag, that runs applictaion layer.
    For each VM it will display:
    - SAPSID
    - Azure Resource Group Name
    - VM Name
    - SAP Instance Type
    - OS type
    
    .PARAMETER SAPSID 
    SAP system SID.    
    
    .EXAMPLE 
    # specify SAP SID 'PR1'
    $SAPSID = "PR1"
    
    # Collect SAP VM instances with the same Tag
    $SAPInstances = Get-AzSAPApplicationInstances -SAPSID $SAPSID

    # List all collected instances
    $SAPInstances

 #>

    [CmdletBinding()]
    param(        
        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()] 
        $SAPSID         
    )

    BEGIN {}
    
    PROCESS {
        try {   
                      
            $tags = @{"SAPSystemSID" = $SAPSID }
            $SAPVMs = Get-AzResource -ResourceType "Microsoft.Compute/virtualMachines"  -Tag $tags

            $SAPApplicationInstances = $SAPVMs | Where-Object { ($_.Tags.Item("SAPApplicationInstanceType") -EQ 'SAP_D') -or ($_.Tags.Item("SAPApplicationInstanceType") -EQ 'SAP_ASCS') -or ($_.Tags.Item("SAPApplicationInstanceType") -EQ 'SAP_SCS') -or ($_.Tags.Item("SAPApplicationInstanceType") -EQ 'SAP_DVEBMGS') }          


            foreach ($VMResource in $SAPApplicationInstances) {
                $obj = New-Object -TypeName psobject
                                
                $OSType = Get-AzVMOSType -VMName $VMResource.Name -ResourceGroupName $VMResource.ResourceGroupName  
               
                $obj | add-member  -NotePropertyName "SAPSID" -NotePropertyValue $SAPSID  
                $obj | add-member  -NotePropertyName "ResourceGroupName" -NotePropertyValue $VMResource.ResourceGroupName  
                $obj | add-member  -NotePropertyName "VMName" -NotePropertyValue $VMResource.Name                                  
                $obj | add-member  -NotePropertyName "OSType"   -NotePropertyValue $OSType 
                $obj | add-member  -NotePropertyName "SAPInstanceType"   -NotePropertyValue $VMResource.Tags.Item("SAPApplicationInstanceType") 

                #Return formated object
                Write-Output $obj
                                                
            }           
            
        }
        catch {
            Write-Error  $_.Exception.Message
        }
    }

    END {}
}

function Test-AzVMIsStarted {
    <#
    .SYNOPSIS 
    Checks if VM is started.
    
    .DESCRIPTION
    Checks if VM is started.
    If VM reachs status 'VM running', it will return $True, otherwise it will return $False
    
    .PARAMETER ResourceGroupName 
    VM Azure Resource Group Name.    
    
    .PARAMETER VMName 
    VM Name.    
    
    .EXAMPLE 
    Test-AzVMIsStarted -ResourceGroupName "PR1-RG" -VMName "PR1-DB"
 #>

    [CmdletBinding()]
    param(
        
        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()]        
        [string]$ResourceGroupName,
              
        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()]        
        [string] $VMName

        
    )

    BEGIN {}
    
    PROCESS {
        try {   
            
            $VM = Get-AzVM -ResourceGroupName $ResourceGroupName -Name $VMName -Status

            $VMStatus = $VMStatus = $VM.Statuses[1].DisplayStatus
                        
            if ($VMStatus -eq "VM running") {                    
                return $True                
            }
            else {
                return $False

            }
        }
        catch {
            Write-Error  $_.Exception.Message
        }

    }
    END {}
}

function Get-AzVMOSType {
    <#
    .SYNOPSIS 
   Get-AzVMOSType gets the VM OS type.
    
    .DESCRIPTION
    Get-AzVMOSType gets the VM OS type, as a return value.
    
    .PARAMETER ResourceGroupName 
    VM Azure Resource Group Name.    
    
    .PARAMETER VMName 
    VM Name.    
    
    .EXAMPLE 
    $OSType = Get-AzVMOSType -ResourceGroupName "PR1-RG" -VMName "PR1-DB"
 #>

    [CmdletBinding()]
    param(
        
        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()] 
        [string] $VMName,

        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()] 
        [string] $ResourceGroupName
        
    )

    BEGIN {}
    
    PROCESS {
        try {   
            $VM = Get-AzVM -ResourceGroupName  $ResourceGroupName -Name $VMName

            Write-Output $VM.StorageProfile.OsDisk.OsType
                        
        }
        catch {
            Write-Error  $_.Exception.Message
        }

    }

    END {}
}


# NOT needed anymore
function Get-AzSAPHANAParametersFromTags {
    <#
    .SYNOPSIS 
    Get SAP HANA parameters from DBMS VM tags.
    
    .DESCRIPTION
    Get SAP HANA parameters from DBMS VM tags. It returns an object with:[SAPHANADBSID;SAPHANAInstanceNumber,SAPHANAResourceGroupName,SAPHANAVMName]      
    .PARAMETER SAPVMs 
    List of SAP VMs. Get all VMs bound by SAPSID with Get-AzSAPInstances          
    
    .EXAMPLE 
    $SAPSID = "PR1"
    Get-AzSAPHANAParametersFromTags -SAPSID $SAPSID
 #>

    [CmdletBinding()]
    param(        
        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()] 
        $SAPSID        
    )

    BEGIN {}
    
    PROCESS {
        try {               
            $tags = @{"SAPSystemSID" = $SAPSID }
            $VMResources = Get-AzResource -ResourceType "Microsoft.Compute/virtualMachines"  -Tag $tags
            $HANAVMResource = $VMResources | Where-Object { $_.Tags.Item("SAPInstanceType") -EQ "SAP_DBMS" }

            $SAPHANADBSID = $HANAVMResource.Tags.Item("SAPHANADBSID")
            $SAPHANAInstanceNumber = $HANAVMResource.Tags.Item("SAPHANAInstanceNumber")
            $SAPHANAResourceGroupName = $HANAVMResource.ResourceGroupName
            $SAPHANAVMName = $HANAVMResource.Name

            $obj = New-Object -TypeName psobject
            $obj | add-member  -NotePropertyName "SAPHANADBSID" -NotePropertyValue $SAPHANADBSID
            $obj | add-member  -NotePropertyName "SAPHANAInstanceNumber" -NotePropertyValue $SAPHANAInstanceNumber
            $obj | add-member  -NotePropertyName "SAPHANAResourceGroupName" -NotePropertyValue $SAPHANAResourceGroupName
            $obj | add-member  -NotePropertyName "SAPHANAVMName" -NotePropertyValue $SAPHANAVMName
            Write-Output $obj
                        
        }
        catch {
            Write-Error  $_.Exception.Message
        }

    }

    END {}
}

function Get-AzHANADBStatus {
    <#
    .SYNOPSIS 
    Get SAP HANA DB status.
    
    .DESCRIPTION
    Get SAP HANA DB status.

    .PARAMETER VMName 
    VM name where HANA is installed. 

    .PARAMETER ResourceGroupName 
    Resource Group Name of the HANA VM.
    
    .PARAMETER HANADBSID 
    SAP HANA SID 
    
    .PARAMETER HANAInstanceNumber 
    SAP HANA Instance Number  

    .PARAMETER PrintExecutionCommand 
    If set to $True, it will print execution command.
    
    .EXAMPLE     
    Get-AzHANADBStatus  -ResourceGroupName "PR1-RG"  -VMName "PR1-DB" -HANADBSID "PR1"  -HANAInstanceNumber 0
 #>
    [CmdletBinding()]
    param(
        
        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()] 
        [string] $VMName,

        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()] 
        [string] $ResourceGroupName,

        [Parameter(Mandatory = $True, HelpMessage = "HANA DB SID")] 
        [string] $HANADBSID,

        [Parameter(Mandatory = $True, HelpMessage = "HANA Instance Number")] 
        [string] $HANAInstanceNumber,

        [Parameter(Mandatory = $False)] 
        [bool] $PrintExecutionCommand = $False        

    )

    BEGIN {}
    
    PROCESS {
        try {   
            Write-Output "HANA DBMS '$HANADBSID' status:"

            $SAPSidUser = $HANADBSID.ToLower() + "adm"
            $SAPSIDUpper = $HANADBSID.ToUpper()
            $SAPControlPath = "/usr/sap/$SAPSIDUpper/SYS/exe/hdb/sapcontrol"            
            
            $Command = "su --login $SAPSidUser -c '$SAPControlPath -prot NI_HTTP -nr $HANAInstanceNumber -function GetSystemInstanceList'"

            if ($PrintExecutionCommand -eq $True) {
                Write-Output "Executing command '$Command' "
            }
                        
            $Command | Out-File "command.txt"

            $ret = Invoke-AzVMRunCommand -ResourceGroupName $ResourceGroupName -VMName $VMName  -CommandId RunShellScript  -ScriptPath command.txt
            $ret.Value[0].Message

            Start-Sleep 5            
        }
        catch {
            Write-Error  $_.Exception.Message
        }

    }

    END {}
}


function Get-AzSQLServerDBStatus {
    <#
    .SYNOPSIS 
    Get SQL Server DB status.
    
    .DESCRIPTION
    Get SQL Server DB status.

    .PARAMETER VMName 
    VM name where SQL Server is installed. 

    .PARAMETER ResourceGroupName 
    Resource Group Name of the SQL Server VM.
    
    .PARAMETER DBSIDName 
    SAP Database SID Name
    
    .PARAMETER DBInstanceName 
    SQL Server DB Instance Name

    .PARAMETER PrintExecutionCommand 
    If set to $True, it will print execution command.
    
    .EXAMPLE  
    #Get status of default SQL Server Instance   
    Get-AzSQLServerDBStatus  -VMName pr1-db -ResourceGroupName gor-shared-disk-east-us -DBSIDName PR1 -PrintExecutionCommand $true

    .EXAMPLE  
    #Get status of default SQL Server Instance   
    Get-AzSQLServerDBStatus  -VMName pr1-db -ResourceGroupName gor-shared-disk-east-us -DBSIDName PR1 -DBInstanceName PR1 -PrintExecutionCommand $true
 #>
    [CmdletBinding()]
    param(
        
        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()] 
        [string] $VMName,

        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()] 
        [string] $ResourceGroupName,

        [Parameter(Mandatory = $True, HelpMessage = "SQL Server DB SID")] 
        [string] $DBSIDName,

        [Parameter(Mandatory = $False, HelpMessage = "SQL Server DB Instance Name")] 
        [string] $DBInstanceName = "",

        [Parameter(Mandatory = $False)] 
        [bool] $PrintExecutionCommand = $False        

    )

    BEGIN {}
    
    PROCESS {
        try {   
            Write-Output "SQL Server DBMS '$DBSIDName' status:"
            
            $Command   = "cd  'C:\Program Files\SAP\hostctrl\exe\' ; .\saphostctrl.exe -function GetDatabaseStatus -dbname $DBSIDName -dbtype mss -dbinstance $DBInstanceName"                        

            if ($PrintExecutionCommand -eq $True) {
                Write-Output "Executing command '$Command' "
            }
                        
            $Command | Out-File "command.txt"

            $ret = Invoke-AzVMRunCommand -ResourceGroupName $ResourceGroupName -VMName $VMName  -CommandId RunPowerShellScript -ScriptPath command.txt
            $ret.Value[0].Message

            Start-Sleep 10            
        }
        catch {
            Write-Error  $_.Exception.Message
        }

    }

    END {}
}


function Get-AzDBMSStatus {
    <#
    .SYNOPSIS 
    Get DB status.
    
    .DESCRIPTION
    Get DB status.

    .PARAMETER SAPSID 
    SAP SID. 

    .PARAMETER SAPSIDDBMSVMs 
    Collection of DB VMs
        
    .PARAMETER PrintExecutionCommand 
    If set to $True, it will print execution command.
    
    .EXAMPLE     
    $SAPSIDDBMSVMs  = Get-AzSAPDBMSInstances -SAPSID "PR2"
    Get-AzDBMSStatus -SAPSIDDBMSVMs $SAPSIDDBMSVMs
 #>
    [CmdletBinding()]
    param(                    

        [Parameter(Mandatory = $True)]         
        $SAPSIDDBMSVMs,

        [Parameter(Mandatory = $False)] 
        [bool] $PrintExecutionCommand = $False 
    )

    BEGIN {}
    
    PROCESS {
        try {   
            Switch ($SAPSIDDBMSVMs.SAPDBMSType) {

                "HANA" {                    
                    # Get SAP HANA status                    
                    Get-AzHANADBStatus  -ResourceGroupName $SAPSIDDBMSVMs.ResourceGroupName -VMName $SAPSIDDBMSVMs.VMName -HANADBSID $SAPSIDDBMSVMs.SAPHANASID  -HANAInstanceNumber $SAPSIDDBMSVMs.SAPHANAInstanceNumber -PrintExecutionCommand $PrintExecutionCommand                                                    
                }

                "SQLServer" {
                    # Get SQL Server status
                    Get-AzSQLServerDBStatus -ResourceGroupName $SAPSIDDBMSVMs.ResourceGroupName -VMName $SAPSIDDBMSVMs.VMName  -DBSIDName $SAPSIDDBMSVMs.SAPSID -DBInstanceName $SAPSIDDBMSVMs.DBInstanceName -PrintExecutionCommand $PrintExecutionCommand
                }

                "Sybase" {
                    # Not yet Implemented
                    Write-WithTime "Getting Sybase DBMS status is not yet implenented."
                }

                "MaxDB" {
                    # Not yet Implemented
                    Write-WithTime "Getting MaxDB DBMS status is not yet implenented."
                }

                "Oracle" {
                    # Not yet Implemented
                    Write-WithTime "Getting Oracle DBMS status is not yet implenented."
                }

                "IBMDB2" {
                    # Not yet Implemented
                    Write-WithTime "Getting IBMDB2 DBMS status is not yet implenented."
                }

                default {
                    Write-WithTime "Couldn't find any supported DBMS type. Please check on DB VM '$($SAPSIDDBMSVMs.VMName)', Tag 'SAPDBMSType'. It must have value like: 'HANA', 'SQLServer', 'Sybase', 'MaxDB' , 'Oracle', 'IBMDB2'. Current 'SAPDBMSType' Tag value is '$($SAPSIDDBMSVMs.SAPDBMSType)'"
                }
            }    
        }
        catch {
            Write-Error  $_.Exception.Message
        }

    }

    END {}
}

function Stop-AzHANADB {
    <#
    .SYNOPSIS 
    Stop SAP HANA DB.
    
    .DESCRIPTION
    Stop SAP HANA DB.

    .PARAMETER VMName 
    VM name where HANA is installed. 

    .PARAMETER ResourceGroupName 
    Resource Group Name of the HANA VM.
    
    .PARAMETER HANADBSID 
    SAP HANA SID     

    .PARAMETER PrintExecutionCommand 
    If set to $True, it will print execution command.
    
    .EXAMPLE     
    Stop-AzHANADB  -ResourceGroupName "PR1-RG"  -VMName "PR1-DB" -HANADBSID "PR1" -SAPHANAInstanceNumber 0
 #>

    [CmdletBinding()]
    param(
        
        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()] 
        [string] $VMName,

        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()] 
        [string] $ResourceGroupName,

        [Parameter(Mandatory = $True, HelpMessage = "HANA DB SID")] 
        [string] $HANADBSID,

        [Parameter(Mandatory=$True, HelpMessage="HANA Instance Number")] 
        [string] $SAPHANAInstanceNumber,

        [Parameter(Mandatory = $False)] 
        [bool] $PrintExecutionCommand = $False

    )

    BEGIN {}
    
    PROCESS {
        try {   
            Write-Output "Stopping SAP HANA DBMS '$HANADBSID' ... "

            $SAPSidUser = $HANADBSID.ToLower() + "adm"            
            $SAPSIDUpper = $HANADBSID.ToUpper()
            $SAPControlPath = "/usr/sap/$SAPSIDUpper/SYS/exe/hdb/sapcontrol"  
            
            # HDB wrapper aproach
            #$Command = "su --login $SAPSidUser -c 'HDB stop'"            

            # Execute stop 
            $Command = "su --login $SAPSidUser -c '$SAPControlPath -prot NI_HTTP -nr $SAPHANAInstanceNumber -function Stop 400'"

            if ($PrintExecutionCommand -eq $True) {
                Write-Output "Executing command '$Command' "
            }
            
            $Command | Out-File "command.txt"

            $ret = Invoke-AzVMRunCommand -ResourceGroupName $ResourceGroupName -VMName $VMName  -CommandId RunShellScript  -ScriptPath command.txt
            $ret.Value[0].Message

            Start-Sleep 20
            
            # Wait for 600 sec -deafult value
            $Command = "su --login $SAPSidUser -c '$SAPControlPath -prot NI_HTTP -nr $SAPHANAInstanceNumber -function WaitforStopped 600 2'"            
            
            if ($PrintExecutionCommand -eq $True) {
                Write-Output "Executing command '$Command' "
            }
            
            $Command | Out-File "command.txt"

            $ret = Invoke-AzVMRunCommand -ResourceGroupName $ResourceGroupName -VMName $VMName  -CommandId RunShellScript  -ScriptPath command.txt
            $ret.Value[0].Message

            Start-Sleep 60  

            Write-Output "SAP HANA DB '$HANADBSID' is stopped."          
        }
        catch {
            Write-Error  $_.Exception.Message
        }

    }

    END {}
}

function Start-AzHANADB {
    <#
    .SYNOPSIS 
    Start SAP HANA DB.
    
    .DESCRIPTION
    Start SAP HANA DB.

    .PARAMETER VMName 
    VM name where HANA is installed. 

    .PARAMETER ResourceGroupName 
    Resource Group Name of the HANA VM.
    
    .PARAMETER SAPHANAInstanceNumber 
    SAP HANA SID     

    .PARAMETER PrintExecutionCommand 
    If set to $True, it will print execution command.
    
    .EXAMPLE     
    Start-AzHANADB  -ResourceGroupName "PR1-RG"  -VMName "PR1-DB" -HANADBSID "PR1" -SAPHANAInstanceNumber 0
 #>

    [CmdletBinding()]
    param(
        
        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()] 
        [string] $VMName,

        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()] 
        [string] $ResourceGroupName,

        [Parameter(Mandatory = $True, HelpMessage = "HANA DB SID")] 
        [string] $HANADBSID,

        [Parameter(Mandatory=$True, HelpMessage="HANA Instance Number")] 
        [ValidateLength(1, 2)]
        [string] $SAPHANAInstanceNumber,

        [Parameter(Mandatory = $False)] 
        [bool] $PrintExecutionCommand = $False        

    )

    BEGIN {}
    
    PROCESS {
        try {   
            Write-Output "Starting SAP HANA DBMS '$HANADBSID' ... "

            $SAPSidUser = $HANADBSID.ToLower() + "adm"
            
            $SAPSIDUpper = $HANADBSID.ToUpper()
            $SAPControlPath = "/usr/sap/$SAPSIDUpper/SYS/exe/hdb/sapcontrol"            
            
            $Command = "su --login $SAPSidUser -c '$SAPControlPath -prot NI_HTTP -nr $SAPHANAInstanceNumber -function StartWait 2700 2'"

            #$Command = "su --login $SAPSidUser -c 'HDB start'"            
            
            if ($PrintExecutionCommand -eq $True) {
                Write-Output "Executing command '$Command' "
            }
            
            $Command | Out-File "command.txt"

            $ret = Invoke-AzVMRunCommand -ResourceGroupName $ResourceGroupName -VMName $VMName  -CommandId RunShellScript  -ScriptPath command.txt
            $ret.Value[0].Message

            Start-Sleep 20            
        }
        catch {
            Write-Error  $_.Exception.Message
        }

    }

    END {}
}

function Start-AzSQLServerDB {
    <#
    .SYNOPSIS 
    Start SQL Server DB status.
    
    .DESCRIPTION
    Get SQL Server DB status.

    .PARAMETER VMName 
    VM name where SQL Server is installed. 

    .PARAMETER ResourceGroupName 
    Resource Group Name of the SQL Server VM.
    
    .PARAMETER DBSIDName 
    SAP Database SID Name    
    
    .PARAMETER DBInstanceName 
    SQL Server DB Instance Name

    .PARAMETER PrintExecutionCommand 
    If set to $True, it will print execution command.
    
    .EXAMPLE     
    # Start default SQL Server Instance
    Start-AzSQLServerDB -VMName pr1-db -ResourceGroupName gor-shared-disk-east-us -DBSIDName PR1 -DBInstanceName -PrintExecutionCommand $true

    .EXAMPLE   
    # Start named SQL Server Instance  
    Start-AzSQLServerDB -VMName pr1-db -ResourceGroupName gor-shared-disk-east-us -DBSIDName PR1 -DBInstanceName PR1 -PrintExecutionCommand $true
 #>
    [CmdletBinding()]
    param(
        
        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()] 
        [string] $VMName,

        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()] 
        [string] $ResourceGroupName,

        [Parameter(Mandatory = $True, HelpMessage = "SQL Server DB SID")] 
        [string] $DBSIDName,

        [Parameter(Mandatory = $False, HelpMessage = "SQL Server DB Instance Name")] 
        [string] $DBInstanceName = "",

        [Parameter(Mandatory = $False)] 
        [bool] $PrintExecutionCommand = $False        

    )

    BEGIN {}
    
    PROCESS {
        try {   
            Write-Output "Starting SQL Server DBMS '$DBSIDName' ..."
            
            $Command   = "cd  'C:\Program Files\SAP\hostctrl\exe\' ; .\saphostctrl.exe -function StartDatabase -dbname $DBSIDName -dbtype mss -dbinstance $DBInstanceName"                        

            if ($PrintExecutionCommand -eq $True) {
                Write-Output "Executing command '$Command' "
            }
                        
            $Command | Out-File "command.txt"

            $ret = Invoke-AzVMRunCommand -ResourceGroupName $ResourceGroupName -VMName $VMName  -CommandId RunPowerShellScript -ScriptPath command.txt
            $ret.Value[0].Message

            Start-Sleep 10            
        }
        catch {
            Write-Error  $_.Exception.Message
        }

    }

    END {}
}


function Stop-AzSQLServerDB {
    <#
    .SYNOPSIS 
    Stop SQL Server DB status.
    
    .DESCRIPTION
    Stop SQL Server DB status.

    .PARAMETER VMName 
    VM name where SQL Server is installed. 

    .PARAMETER ResourceGroupName 
    Resource Group Name of the SQL Server VM.
    
    .PARAMETER DBSIDName 
    SAP Database SID Name     

    .PARAMETER DBInstanceName 
    SQL Server DB Instance Name

    .PARAMETER PrintExecutionCommand 
    If set to $True, it will print execution command.
    
    .EXAMPLE     
    # Stop default SQL Server Instance
    Stop-AzSQLServerDB -VMName pr1-db -ResourceGroupName gor-shared-disk-east-us -DBSIDName PR1 -DBInstanceName

    .EXAMPLE     
    # Stop default SQL Server Instance
    Stop-AzSQLServerDB -VMName pr1-db -ResourceGroupName gor-shared-disk-east-us -DBSIDName PR1 -DBInstanceName PR1
 #>
    [CmdletBinding()]
    param(
        
        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()] 
        [string] $VMName,

        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()] 
        [string] $ResourceGroupName,

        [Parameter(Mandatory = $True, HelpMessage = "SQL Server DB SID")] 
        [string] $DBSIDName,

        [Parameter(Mandatory = $False, HelpMessage = "SQL Server DB Instance Name")] 
        [string] $DBInstanceName = "",

        [Parameter(Mandatory = $False)] 
        [bool] $PrintExecutionCommand = $False        

    )

    BEGIN {}
    
    PROCESS {
        try {   
            Write-Output "Stopping SQL Server DBMS '$DBSIDName'  ... :"
            
            $Command   = "cd  'C:\Program Files\SAP\hostctrl\exe\' ; .\saphostctrl.exe -function StopDatabase -dbname $DBSIDName -dbtype mss -dbinstance $DBInstanceName"                        

            if ($PrintExecutionCommand -eq $True) {
                Write-Output "Executing command '$Command' "
            }
                        
            $Command | Out-File "command.txt"

            $ret = Invoke-AzVMRunCommand -ResourceGroupName $ResourceGroupName -VMName $VMName  -CommandId RunPowerShellScript -ScriptPath command.txt
            $ret.Value[0].Message

            Start-Sleep 10            
        }
        catch {
            Write-Error  $_.Exception.Message
        }

    }

    END {}
}





function Start-AzDBMS {
    <#
    .SYNOPSIS 
    Start DBMS.
    
    .DESCRIPTION
    Start DBMS.

    .PARAMETER SAPSID 
    SAP SID. 

    .PARAMETER DatabaseType 
    Database Type. Allowed values are: "HANA","SQLServer","MaxDB","Sybase","Oracle","IBMDB2" 

    .PARAMETER PrintExecutionCommand 
    If set to $True, it will print execution command.
    
    .EXAMPLE     
    Start-AzDBMS -SAPSID "PR1" -DatabaseType "HANA"
 #>
    [CmdletBinding()]
    param(        
        [Parameter(Mandatory = $True)]         
        $SAPSIDDBMSVMs,

        [Parameter(Mandatory = $False)] 
        [bool] $PrintExecutionCommand = $False 
    )

    BEGIN {}
    
    PROCESS {
        try {   
            Switch ($SAPSIDDBMSVMs.SAPDBMSType) {

                "HANA" {
                    # Start SAP HANA DB                    
                    Start-AzHANADB -ResourceGroupName $SAPSIDDBMSVMs.ResourceGroupName -VMName $SAPSIDDBMSVMs.VMName  -HANADBSID $SAPSIDDBMSVMs.SAPHANASID  -SAPHANAInstanceNumber $SAPSIDDBMSVMs.SAPHANAInstanceNumber -PrintExecutionCommand $PrintExecutionCommand
                }

                "SQLServer" {                    
                    # Start SQL Server DB                    
                    Start-AzSQLServerDB  -ResourceGroupName $SAPSIDDBMSVMs.ResourceGroupName -VMName $SAPSIDDBMSVMs.VMName  -DBSIDName $SAPSIDDBMSVMs.SAPSID -DBInstanceName $SAPSIDDBMSVMs.DBInstanceName  -PrintExecutionCommand $PrintExecutionCommand
                }

                "Sybase" {
                    # Not yet Implemented
                    Write-WithTime "Start of SAP Sybase is not yet implemented. Relying on automatic SAP Sybase start."
                    write-host ""
                    Write-WithTime "Waiting for 3 min for DBMS auto start."
                    Start-Sleep 180
                }

                "MaxDB" {
                    # Not yet Implemented
                    Write-WithTime "Start of SAP MaxDB is not yet implemented. Relying on automatic SAP MaxDB start."
                    write-host ""
                    Write-WithTime "Waiting for 3 min for DBMS auto start."
                    Start-Sleep 180
                }

                "Oracle" {
                    # Not yet Implemented
                    Write-WithTime "Start of Oracle is not yet implemented. Relying on automatic Oracle start."
                    write-host ""
                    Write-WithTime "Waiting for 3 min for DBMS auto start."
                    Start-Sleep 180
                }

                "IBMDB2" {
                    # Not yet Implemented
                    Write-WithTime "Start of IBM DB2 is not yet implemented. Relying on automatic IBM DB2 start."
                    write-host ""
                    Write-WithTime "Waiting for 3 min for DBMS autostart."
                    Start-Sleep 180
                }
            }    
        }
        catch {
            Write-Error  $_.Exception.Message
        }
    }

    END {}
}

function Stop-AzDBMS {
    <#
    .SYNOPSIS 
    Start DBMS.
    
    .DESCRIPTION
    Start DBMS.

    .PARAMETER SAPSID 
    SAP SID. 

    .PARAMETER DatabaseType 
    Database Type. Allowed values are: "HANA","SQLServer","MaxDB","Sybase","Oracle","IBMDB2" 

    .PARAMETER PrintExecutionCommand 
    If set to $True, it will print execution command.
    
    .EXAMPLE     
    Stop-AzDBMS -SAPSID "PR1" -DatabaseType "HANA"
 #>
    [CmdletBinding()]
    param(        
        [Parameter(Mandatory = $True)]         
        $SAPSIDDBMSVMs,

        [Parameter(Mandatory = $False)] 
        [bool] $PrintExecutionCommand = $False 

    )

    BEGIN {}
    
    PROCESS {
        try {   
            Switch ($SAPSIDDBMSVMs.SAPDBMSType) {

                "HANA" {                                        
                    # Stop SAP HANA DBMS                        
                    Stop-AzHANADB -ResourceGroupName $SAPSIDDBMSVMs.ResourceGroupName -VMName $SAPSIDDBMSVMs.VMName -HANADBSID $SAPSIDDBMSVMs.SAPHANASID -SAPHANAInstanceNumber $SAPSIDDBMSVMs.SAPHANAInstanceNumber -PrintExecutionCommand $PrintExecutionCommand
                }

                "SQLServer" {
                    # Start SQL Server DB                    
                    Stop-AzSQLServerDB  -ResourceGroupName $SAPSIDDBMSVMs.ResourceGroupName -VMName $SAPSIDDBMSVMs.VMName  -DBSIDName $SAPSIDDBMSVMs.SAPSID  -DBInstanceName $SAPSIDDBMSVMs.DBInstanceName  -PrintExecutionCommand $PrintExecutionCommand
                }

                "Sybase" {
                    # Not yet Implemented
                    Write-WithTime "Stop of SAP Sybase is not yet implemented."                     
                }

                "MaxDB" {
                    # Not yet Implemented
                    Write-WithTime "Stop of SAP MaxDB is not yet implemented."                    
                }

                "Oracle" {
                    # Not yet Implemented
                    Write-WithTime "Stop of Oracle is not yet implemented."                    
                }

                "IBMDB2" {
                    # Not yet Implemented
                    Write-WithTime "Stop of IBM DB2 is not yet implemented."                    
                }
            }    
        }
        catch {
            Write-Error  $_.Exception.Message
        }

    }

    END {}
}

function Get-AzONESAPApplicationInstance {
    <#
    .SYNOPSIS 
    Get one SAPSID Instance.
    
    .DESCRIPTION
    Get one SAPSID Instance. Returned object has [VMName;SAPInstanceNumber;SAPInstanceType]
        
    .PARAMETER SAPSID 
    SAP SID     
    
    .EXAMPLE     
    Get-AzONESAPApplicationInstance -SAPSID "PR1"
 #>

    [CmdletBinding()]
    param(
        
        [Parameter(Mandatory = $True)]         
        $SAPSIDApplicationVMs,

        [Parameter(Mandatory = $False)] 
        [bool] $PrintExecutionCommand = $False          
    )

    BEGIN {}
    
    PROCESS {
        try {                         
            $SAPSID = $SAPSIDApplicationVMs[0].SAPSID
            $VMName = $SAPSIDApplicationVMs[0].VMName
            $ResourceGroupName = $SAPSIDApplicationVMs[0].ResourceGroupName
            $SAPApplicationInstanceNumber = $SAPSIDApplicationVMs[0].SAPApplicationInstanceNumber
            $SAPInstanceType = $SAPSIDApplicationVMs[0].SAPInstanceType
            $OSType = Get-AzVMOSType -VMName $VMName -ResourceGroupName $ResourceGroupName

            if ($OSType -eq "Windows") {                
                #$SAPSIDPassword = Get-AzVMTagValue -ResourceGroupName $ResourceGroupName  -VMName $VMName  -KeyName "SAPSIDPassword"  
                $SIDADMUser = $SAPSID.Trim().ToLower() + "adm"
                $SAPSIDCredentials = Get-AzAutomationSAPPSCredential -CredentialName  $SIDADMUser  
                $SAPSIDPassword = $SAPSIDCredentials.Password
                $PathToSAPControl = Get-AzVMTagValue -ResourceGroupName $ResourceGroupName  -VMName $VMName  -KeyName "PathToSAPControl"  
            }

            $obj = New-Object -TypeName psobject

            $obj | add-member  -NotePropertyName "SAPSID"                       -NotePropertyValue $SAPSID  
            $obj | add-member  -NotePropertyName "VMName"                       -NotePropertyValue $VMName  
            $obj | add-member  -NotePropertyName "ResourceGroupName"            -NotePropertyValue $ResourceGroupName  
            $obj | add-member  -NotePropertyName "SAPApplicationInstanceNumber" -NotePropertyValue $SAPApplicationInstanceNumber
            $obj | add-member  -NotePropertyName "SAPInstanceType"              -NotePropertyValue $SAPInstanceType
            $obj | add-member  -NotePropertyName "OSType"                       -NotePropertyValue $OSType 

            if ($OSType -eq "Windows") {
                $obj | add-member  -NotePropertyName "SAPSIDPassword"           -NotePropertyValue $SAPSIDPassword
                $obj | add-member  -NotePropertyName "PathToSAPControl"         -NotePropertyValue $PathToSAPControl               
            }

            #Return formated object
            Write-Output $obj                                    
        }
        catch {
            Write-Error  $_.Exception.Message
        }
    }

    END {}
}


function Get-AzSAPSystemStatusLinux {
    <#
    .SYNOPSIS 
    Get SAP System Status on Linux.
    
    .DESCRIPTION
    Get SAP System Status on Linux.

    .PARAMETER VMName 
    VM name where SAP instance is installed. 

    .PARAMETER ResourceGroupName 
    Resource Group Name of the SAP instance VM.        

    .PARAMETER InstanceNumberToConnect 
    SAP Instance Number to Connect    

    .PARAMETER SAPSID 
    SAP SID    

    .PARAMETER PrintExecutionCommand 
    If set to $True, it will print execution command.
    
    .EXAMPLE     
    Get-AzSAPSystemStatusLinux  -ResourceGroupName "PR1-RG"  -VMName "PR1-DB" -SAPSID "PR1" -InstanceNumberToConnect 1 
 #>

    [CmdletBinding()]
    param(
        
        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()] 
        [string] $VMName,

        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()] 
        [string] $ResourceGroupName,

        [Parameter(Mandatory = $True)]
        [ValidateLength(1, 2)]
        [string] $InstanceNumberToConnect,

        [Parameter(Mandatory = $True, HelpMessage = "SAP System <SID>. 3 characters , starts with letter.")] 
        [ValidateLength(3, 3)]
        [string] $SAPSID,

        [Parameter(Mandatory = $False)] 
        [bool] $PrintExecutionCommand = $False
       
    )

    BEGIN {}
    
    PROCESS {
        try {   
            Write-Output "SAP System '$SAPSID' Status:"

            $SAPSidUser = $SAPSID.ToLower() + "adm"            
            $Command = "su --login $SAPSidUser -c 'sapcontrol -nr $InstanceNumberToConnect -function GetSystemInstanceList'"
            
            if ($PrintExecutionCommand -eq $True) {
                Write-Output "Executing command '$Command' "
            }

            $Command | Out-File "command.txt"

            $ret = Invoke-AzVMRunCommand -ResourceGroupName $ResourceGroupName -VMName $VMName  -CommandId RunShellScript  -ScriptPath command.txt
            $ret.Value[0].Message

            #Write-Output "Waiting for 5 sec  ..."
            Start-Sleep 5            
        }
        catch {
            Write-Error  $_.Exception.Message
        }
    }

    END {}
}
function Get-AzSAPSystemStatusWindows {
    <#
    .SYNOPSIS 
    Get SAP System Status on Windows.
    
    .DESCRIPTION
    Get SAP System Status on Windows.

    .PARAMETER VMName 
    VM name where SAP instance is installed. 

    .PARAMETER ResourceGroupName 
    Resource Group Name of the SAP instance VM.        

    .PARAMETER InstanceNumberToConnect 
    SAP Instance Number to Connect    

    .PARAMETER PathToSAPControl 
    Full path to SAP Control executable.        

    .PARAMETER SAPSID 
    SAP SID    

    .PARAMETER SAPSidPwd 
    SAP <sid>adm user password

    .PARAMETER PrintExecutionCommand 
    If set to $True, it will print execution command.
    
    .EXAMPLE     
    Get-AzSAPSystemStatusWindows  -ResourceGroupName "PR1-RG"  -VMName "PR1-DB" -SAPSID "PR1" -InstanceNumberToConnect 1 -PathToSAPControl "C:\usr\sap\PR2\ASCS00\exe\sapcontrol.exe" -SAPSidPwd "MyPassword12"
 #>

    [CmdletBinding()]
    param(
        
        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()] 
        [string] $VMName,

        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()] 
        [string] $ResourceGroupName,

        [Parameter(Mandatory = $True)]
        [ValidateLength(1, 2)] 
        [string] $InstanceNumberToConnect,

        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()] 
        [string] $PathToSAPControl,

        [Parameter(Mandatory = $True, HelpMessage = "SAP System <SID>. 3 characters , starts with letter.")] 
        [ValidateLength(3, 3)]
        [string] $SAPSID,

        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()] 
        [string] $SAPSidPwd,        

        [Parameter(Mandatory = $False)] 
        [bool] $PrintExecutionCommand = $False       
    )

    BEGIN {}
    
    PROCESS {
        try {   
            $SAPSidUser = $SAPSID.ToLower() + "adm"            

            Write-Output "SAP System '$SAPSID' Status:"            
            $Command        = "$PathToSAPControl -nr $InstanceNumberToConnect -user $SAPSidUser $SAPSidPwd  -function GetSystemInstanceList"
            $CommandToPrint = "$PathToSAPControl -nr $InstanceNumberToConnect -user $SAPSidUser '***pwd***' -function GetSystemInstanceList"
            
            if ($PrintExecutionCommand -eq $True) {
                Write-Output "Executing command '$CommandToPrint' "
            }

            $Command | Out-File "command.txt"

            $ret = Invoke-AzVMRunCommand -ResourceGroupName $ResourceGroupName -VMName $VMName  -CommandId RunPowerShellScript -ScriptPath command.txt
            $ret.Value[0].Message

            #Write-Output "Waiting for 5 sec  ..."
            Start-Sleep 5            
        }
        catch {
            Write-Error  $_.Exception.Message
        }
    }

    END {}
}

function Get-AzSAPSystemStatus {
    <#
    .SYNOPSIS 
    Get SAP System Status.
    
    .DESCRIPTION
    Get SAP System Status. Module will automaticaly recognize Windows or Linux OS.
    
    .PARAMETER SAPSID 
    SAP SID    

    .PARAMETER PrintExecutionCommand 
    If set to $True, it will print execution command.

    .EXAMPLE     
    $SAPSIDApplicationVMs  = Get-AzSAPApplicationInstances -SAPSID "SP1"
    Get-AzSAPSystemStatus  -SAPSIDApplicationVMs  $SAPSIDApplicationVMs
 #>

    [CmdletBinding()]
    param(       
        [Parameter(Mandatory = $True)]         
        $SAPSIDApplicationVMs,

        [Parameter(Mandatory = $False)] 
        [bool] $PrintExecutionCommand = $False   
    )

    BEGIN {}
    
    PROCESS {
        try {                       
            $ONESAPInstance = Get-AzONESAPApplicationInstance -SAPSIDApplicationVMs $SAPSIDApplicationVMs           

            if ($ONESAPInstance.OSType -eq "Linux") {
                Get-AzSAPSystemStatusLinux  -ResourceGroupName $ONESAPInstance.ResourceGroupName -VMName $ONESAPInstance.VMName -InstanceNumberToConnect $ONESAPInstance.SAPApplicationInstanceNumber -SAPSID $ONESAPInstance.SAPSID -PrintExecutionCommand $PrintExecutionCommand                            
            }
            elseif ($ONESAPInstance.OSType -eq "Windows") {
                Get-AzSAPSystemStatusWindows  -ResourceGroupName $ONESAPInstance.ResourceGroupName -VMName $ONESAPInstance.VMName -InstanceNumberToConnect $ONESAPInstance.SAPApplicationInstanceNumber -SAPSID $ONESAPInstance.SAPSID -PathToSAPControl $ONESAPInstance.PathToSAPControl -SAPSidPwd  $ONESAPInstance.SAPSIDPassword   -PrintExecutionCommand $PrintExecutionCommand

            }           
        }
        catch {
            Write-Error  $_.Exception.Message
        }
    }

    END {}
}


function Start-AzSAPSystemLinux {
    <#
    .SYNOPSIS 
    Start SAP System on Linux.
    
    .DESCRIPTION
    Start SAP System on Linux.

    .PARAMETER VMName 
    VM name where SAP instance is installed. 

    .PARAMETER ResourceGroupName 
    Resource Group Name of the SAP instance VM.        

    .PARAMETER InstanceNumberToConnect 
    SAP Instance Number to Connect    

    .PARAMETER SAPSID 
    SAP SID    

    .PARAMETER WaitForStartTimeInSeconds
    Number of seconds to wait for SAP system to start.
    .PARAMETER PrintExecutionCommand 
    If set to $True, it will print execution command.
    
    .EXAMPLE     
    Start-AzSAPSystemLinux  -ResourceGroupName "PR1-RG"  -VMName "PR1-DB" -SAPSID "PR1" -InstanceNumberToConnect 1 
 #>

    [CmdletBinding()]
    param(
        
        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()] 
        [string] $VMName,

        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()] 
        [string] $ResourceGroupName,

        [Parameter(Mandatory = $True)]
        [ValidateLength(1, 2)]
        [string] $InstanceNumberToConnect,

        [Parameter(Mandatory = $True, HelpMessage = "SAP System <SID>. 3 characters , starts with letter.")] 
        [ValidateLength(3, 3)]
        [string] $SAPSID,

        [Parameter(Mandatory = $False)] 
        [int] $WaitForStartTimeInSeconds = 600,

        [Parameter(Mandatory = $False)] 
        [bool] $PrintExecutionCommand = $False
    )

    BEGIN {}
    
    PROCESS {
        try {   
            $SAPSidUser = $SAPSID.ToLower() + "adm"
            #$SAPSIDUpper =  $SAPSID.ToUpper()
            
            Write-Output "Starting SAP '$SAPSID' System ..."

            $Command = "su --login $SAPSidUser -c 'sapcontrol -nr $InstanceNumberToConnect -function StartSystem'"
            
            if ($PrintExecutionCommand -eq $True) {
                Write-Output "Executing command '$Command' "
            }

            $Command | Out-File "command.txt"

            $ret = Invoke-AzVMRunCommand -ResourceGroupName $ResourceGroupName -VMName $VMName  -CommandId RunShellScript  -ScriptPath command.txt

            $ret.Value[0].Message

            Write-Output " "
            Write-Output "Waiting $WaitForStartTimeInSeconds seconds for SAP system '$SAPSID' to start ..."
            Start-Sleep $WaitForStartTimeInSeconds            
        }
        catch {
            Write-Error  $_.Exception.Message
        }

    }

    END {}
}


function Start-AzSAPSystemWindows {
    <#
    .SYNOPSIS 
    Get SAP System Status on Windows.
    
    .DESCRIPTION
    Get SAP System Status on Windows.

    .PARAMETER VMName 
    VM name where SAP instance is installed. 

    .PARAMETER ResourceGroupName 
    Resource Group Name of the SAP instance VM.        

    .PARAMETER InstanceNumberToConnect 
    SAP Instance Number to Connect    

    .PARAMETER PathToSAPControl 
    Full path to SAP Control executable.        

    .PARAMETER SAPSID 
    SAP SID    

    .PARAMETER SAPSidPwd 
    SAP <sid>adm user password

    .PARAMETER WaitForStartTimeInSeconds
    Number of seconds to wait for SAP system to start.

    .PARAMETER PrintExecutionCommand 
    If set to $True, it will print execution command.
    
    .EXAMPLE     
    Start-AzSAPSystemWindows  -ResourceGroupName "PR1-RG"  -VMName "PR1-DB" -SAPSID "PR1" -InstanceNumberToConnect 1 -PathToSAPControl "C:\usr\sap\PR2\ASCS00\exe\sapcontrol.exe" -SAPSidPwd "MyPassword12"
 #>

    [CmdletBinding()]
    param(
        
        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()] 
        [string] $VMName,

        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()] 
        [string] $ResourceGroupName,

        [Parameter(Mandatory = $True)]
        [ValidateLength(1, 2)]
        [string] $InstanceNumberToConnect,

        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()] 
        [string] $PathToSAPControl,

        [Parameter(Mandatory = $True, HelpMessage = "SAP System <SID>. 3 characters , starts with letter.")] 
        [ValidateLength(3, 3)]
        [string] $SAPSID,

        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()] 
        [string] $SAPSidPwd,     
        
        [Parameter(Mandatory = $False)] 
        [int] $WaitForStartTimeInSeconds = 600,

        [Parameter(Mandatory = $False)] 
        [bool] $PrintExecutionCommand = $False
       
    )

    BEGIN {}
    
    PROCESS {
        try {   
            $SAPSidUser = $SAPSID.ToLower() + "adm"            

            Write-Output "Starting SAP '$SAPSID' System ..."           
            $Command        = "$PathToSAPControl -nr $InstanceNumberToConnect -user $SAPSidUser $SAPSidPwd  -function StartSystem"
            $CommandToPrint = "$PathToSAPControl -nr $InstanceNumberToConnect -user $SAPSidUser '***pwd***' -function StartSystem"
            
            if ($PrintExecutionCommand -eq $True) {
                Write-Output "Executing command '$CommandToPrint' "
            }

            $Command | Out-File "command.txt"

            $ret = Invoke-AzVMRunCommand -ResourceGroupName $ResourceGroupName -VMName $VMName  -CommandId RunPowerShellScript -ScriptPath command.txt
            $ret.Value[0].Message

            Write-Output " "
            Write-Output "Waiting $WaitForStartTimeInSeconds seconds for SAP system '$SAPSID' to start ..."
            Start-Sleep $WaitForStartTimeInSeconds    
        }
        catch {
            Write-Error  $_.Exception.Message
        }
    }

    END {}
}

function Start-AzSAPSystem {
    <#
    .SYNOPSIS 
    Start SAP System.
    
    .DESCRIPTION
    Start SAP System. Module will automaticaly recognize Windows or Linux OS.
    
    .PARAMETER SAPSID 
    SAP SID    

    .PARAMETER WaitForStartTimeInSeconds
    Number of seconds to wait for SAP system to start.

    .EXAMPLE     
    Start-AzSAPSystem -SAPSID "PR1" 
 #>

    [CmdletBinding()]
    param(       
        [Parameter(Mandatory = $True)]         
        $SAPSIDApplicationVMs,

        [Parameter(Mandatory = $False)] 
        [int] $WaitForStartTimeInSeconds = 600,

        [Parameter(Mandatory = $False)] 
        [bool] $PrintExecutionCommand = $False        
    )

    BEGIN {}
    
    PROCESS {
        try {   
            # get one / any SAP instance            
            $ONESAPInstance = Get-AzONESAPApplicationInstance -SAPSIDApplicationVMs $SAPSIDApplicationVMs

            if ($ONESAPInstance.OSType -eq "Linux") {                  
                Start-AzSAPSystemLinux    -ResourceGroupName $ONESAPInstance.ResourceGroupName -VMName $ONESAPInstance.VMName -InstanceNumberToConnect $ONESAPInstance.SAPApplicationInstanceNumber -SAPSID $ONESAPInstance.SAPSID -WaitForStartTimeInSeconds $WaitForStartTimeInSeconds -PrintExecutionCommand $PrintExecutionCommand                            
            }
            elseif ($ONESAPInstance.OSType -eq "Windows") {                
                Start-AzSAPSystemWindows  -ResourceGroupName $ONESAPInstance.ResourceGroupName -VMName $ONESAPInstance.VMName -InstanceNumberToConnect $ONESAPInstance.SAPApplicationInstanceNumber -SAPSID $ONESAPInstance.SAPSID -WaitForStartTimeInSeconds $WaitForStartTimeInSeconds -PathToSAPControl $ONESAPInstance.PathToSAPControl -SAPSidPwd  $ONESAPInstance.SAPSIDPassword  -PrintExecutionCommand $PrintExecutionCommand
            }           
        }
        catch {
            Write-Error  $_.Exception.Message
        }
    }

    END {}
}

function Stop-AzSAPSystemLinux {
    <#
    .SYNOPSIS 
    Stop SAP System on Linux.
    
    .DESCRIPTION
    Stop SAP System on Linux.

    .PARAMETER VMName 
    VM name where SAP instance is installed. 

    .PARAMETER ResourceGroupName 
    Resource Group Name of the SAP instance VM.        

    .PARAMETER InstanceNumberToConnect 
    SAP Instance Number to Connect    

    .PARAMETER SAPSID 
    SAP SID    

    .PARAMETER SoftShutdownTimeInSeconds
    Soft shutdown time for SAP system to stop.

    .PARAMETER PrintExecutionCommand 
    If set to $True, it will print execution command.
    
    .EXAMPLE     
    Stop-AzSAPSystemLinux  -ResourceGroupName "PR1-RG"  -VMName "PR1-DB" -SAPSID "PR1" -InstanceNumberToConnect 1 
 #>


    [CmdletBinding()]
    param(
        
        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()] 
        [string] $VMName,

        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()] 
        [string] $ResourceGroupName,

        [Parameter(Mandatory = $True)]
        [ValidateLength(1, 2)]
        [string] $InstanceNumberToConnect,

        [Parameter(Mandatory = $True, HelpMessage = "SAP System <SID>. 3 characters , starts with letter.")] 
        [ValidateLength(3, 3)]
        [string] $SAPSID,

        [Parameter(Mandatory = $False)] 
        [int] $SoftShutdownTimeInSeconds = "600",

        [Parameter(Mandatory = $False)] 
        [bool] $PrintExecutionCommand = $False

    )

    BEGIN {}
    
    PROCESS {
        try {   
            $SAPSidUser = $SAPSID.ToLower() + "adm"            

            # Stop SAP ABAP Application Server
            Write-Output "Stopping SAP '$SAPSID' System ..."

            $Command = "su --login $SAPSidUser -c 'sapcontrol -nr $InstanceNumberToConnect -function StopSystem ALL $SoftShutdownTimeInSeconds $SoftShutdownTimeInSeconds'"
            
            if ($PrintExecutionCommand -eq $True) {
                Write-Output "Executing command '$Command' "
            }

            $Command | Out-File "command.txt"

            $ret = Invoke-AzVMRunCommand -ResourceGroupName $ResourceGroupName -VMName $VMName  -CommandId RunShellScript  -ScriptPath command.txt

            $ret.Value[0].Message            

            Write-Output " "
            Write-Output "Waiting $SoftShutdownTimeInSeconds seconds for SAP system '$SAPSID' to stop ..."
            Start-Sleep ($SoftShutdownTimeInSeconds + 30)
        }
        catch {
            Write-Error  $_.Exception.Message
        }

    }

    END {}
}

function Stop-AzSAPSystemWindows {
    <#
        .SYNOPSIS 
        Stop SAP System on Windows.
        
        .DESCRIPTION
        Stop SAP System Windows.
    
        .PARAMETER VMName 
        VM name where SAP instance is installed. 
    
        .PARAMETER ResourceGroupName 
        Resource Group Name of the SAP instance VM.        
    
        .PARAMETER InstanceNumberToConnect 
        SAP Instance Number to Connect    
    
        .PARAMETER PathToSAPControl 
        Full path to SAP Control executable.        
    
        .PARAMETER SAPSID 
        SAP SID    
    
        .PARAMETER SAPSidPwd 
        SAP <sid>adm user password
    
        .PARAMETER SoftShutdownTimeInSeconds
        Soft shutdown time for SAP system to stop.
    
        .PARAMETER PrintExecutionCommand 
        If set to $True, it will print execution command.
        
        .EXAMPLE     
        Stop-AzSAPSystemWindows  -ResourceGroupName "PR1-RG"  -VMName "PR1-DB" -SAPSID "PR1" -InstanceNumberToConnect 1 -PathToSAPControl "C:\usr\sap\PR2\ASCS00\exe\sapcontrol.exe" -SAPSidPwd "MyPassword12"
     #>
    
    [CmdletBinding()]
    param(
            
        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()] 
        [string] $VMName,
    
        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()] 
        [string] $ResourceGroupName,
    
        [Parameter(Mandatory = $True)]
        [ValidateLength(1, 2)]
        [string] $InstanceNumberToConnect,
    
        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()] 
        [string] $PathToSAPControl,
    
        [Parameter(Mandatory = $True, HelpMessage = "SAP System <SID>. 3 characters , starts with letter.")] 
        [ValidateLength(3, 3)]
        [string] $SAPSID,
    
        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()] 
        [string] $SAPSidPwd,     
            
        [Parameter(Mandatory = $False)] 
        [int] $SoftShutdownTimeInSeconds = 600,
    
        [Parameter(Mandatory = $False)] 
        [bool] $PrintExecutionCommand = $False
           
    )
    
    BEGIN {}
        
    PROCESS {
        try {   
            $SAPSidUser = $SAPSID.ToLower() + "adm"            
    
            Write-Output "Stopping SAP '$SAPSID' System ..."           
            $Command        = "$PathToSAPControl -nr $InstanceNumberToConnect -user $SAPSidUser $SAPSidPwd -function StopSystem ALL $SoftShutdownTimeInSeconds $SoftShutdownTimeInSeconds"
            $CommandToPrint = "$PathToSAPControl -nr $InstanceNumberToConnect -user $SAPSidUser '***pwd****' -function StopSystem ALL $SoftShutdownTimeInSeconds $SoftShutdownTimeInSeconds"
                
            if ($PrintExecutionCommand -eq $True) {
                Write-Output "Executing command '$CommandToPrint' "
            }
    
            $Command | Out-File "command.txt"
    
            $ret = Invoke-AzVMRunCommand -ResourceGroupName $ResourceGroupName -VMName $VMName  -CommandId RunPowerShellScript -ScriptPath command.txt
            $ret.Value[0].Message
    
            Write-Output " "
            Write-Output "Waiting $SoftShutdownTimeInSeconds seconds for SAP system '$SAPSID' to stop ..."
            Start-Sleep ($SoftShutdownTimeInSeconds + 30)
        }
        catch {
            Write-Error  $_.Exception.Message
        }
    }
    
    END {}
}
    
function Stop-AzSAPSystem {
    <#
        .SYNOPSIS 
        Stop SAP System.
        
        .DESCRIPTION
        Stop SAP System. Module will automaticaly recognize Windows or Linux OS.
        
        .PARAMETER SAPSID 
        SAP SID    
    
        .PARAMETER SoftShutdownTimeInSeconds
        Soft shutdown time for SAP system to stop.
    
        .EXAMPLE     
        Stop-AzSAPSystem -SAPSID "PR1" 
     #>
    
    [CmdletBinding()]
    param(       
        [Parameter(Mandatory = $True)]         
        $SAPSIDApplicationVMs,
    
        [Parameter(Mandatory = $False)] 
        [int] $SoftShutdownTimeInSeconds = 600,
    
        [Parameter(Mandatory = $False)] 
        [bool] $PrintExecutionCommand = $False        
    )
    
    BEGIN {}
        
    PROCESS {
        try {   
            # get one / any SAP instance                        
            $ONESAPInstance = Get-AzONESAPApplicationInstance -SAPSIDApplicationVMs $SAPSIDApplicationVMs 
                
            if ($ONESAPInstance.OSType -eq "Linux") {                
                Stop-AzSAPSystemLinux    -ResourceGroupName $ONESAPInstance.ResourceGroupName -VMName $ONESAPInstance.VMName -InstanceNumberToConnect $ONESAPInstance.SAPApplicationInstanceNumber -SAPSID $ONESAPInstance.SAPSID -SoftShutdownTimeInSeconds $SoftShutdownTimeInSeconds -PrintExecutionCommand $PrintExecutionCommand                            
            }
            elseif ($ONESAPInstance.OSType -eq "Windows") {                
                Stop-AzSAPSystemWindows  -ResourceGroupName $ONESAPInstance.ResourceGroupName -VMName $ONESAPInstance.VMName -InstanceNumberToConnect $ONESAPInstance.SAPApplicationInstanceNumber -SAPSID $ONESAPInstance.SAPSID -SoftShutdownTimeInSeconds $SoftShutdownTimeInSeconds -PathToSAPControl $ONESAPInstance.PathToSAPControl -SAPSidPwd  $ONESAPInstance.SAPSIDPassword  -PrintExecutionCommand $PrintExecutionCommand
            }           
        }
        catch {
            Write-Error  $_.Exception.Message
        }
    }
    
    END {}
}
    
function Get-AzVMTags {
    <#
    .SYNOPSIS 
    Gets Key/Value pair tags objects.
    
    .DESCRIPTION
    Gets Key/Value pair tags objects.
    
    .PARAMETER ResourceGroupName 
    ResourceGroupName.    
    
    .PARAMETER VMName 
    VMName.    

    .EXAMPLE 
    Get-AzVMTags

 #>
    [CmdletBinding()]
    param(        
        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()]        
        [string]$ResourceGroupName,
              
        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()]        
        [string] $VMName
    )

    BEGIN {}
    
    PROCESS {
        try {   
                      
            $VM = Get-AzVM -ResourceGroupName $ResourceGroupName -VMName $VMName
            $Tags = $VM.Tags
            
            foreach ($Tag in $Tags.GetEnumerator()) {
                $obj = New-Object -TypeName psobject
                $obj | add-member  -NotePropertyName "Key"   -NotePropertyValue $Tag.Key  
                $obj | add-member  -NotePropertyName "Value" -NotePropertyValue $Tag.Value  
                 
                #Return formated object
                Write-Output $obj                
            }                                                                                             
        }
        catch {
            Write-Error  $_.Exception.Message
        }
    }

    END {}
}

function Get-AzVMTagValue {
    <#
    .SYNOPSIS 
    Gets Value of Key tag for specified VM.
    
    .DESCRIPTION
    Gets Value of Key tag for specified VM. If key do not exist, empty string is returned.
    
    .PARAMETER ResourceGroupName 
    ResourceGroupName.    
    
    .PARAMETER VMName 
    VMName.   

    .PARAMETER KeyName 
    KeyName.   

    .EXAMPLE
    Get-AzVMTagValue -ResourceGroupName "gor-linux-eastus2-2" -VMName "pr2-ascs"  -KeyName "PathToSAPControl"      

 #>
    [CmdletBinding()]
    param(        
        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()]        
        [string]$ResourceGroupName,
              
        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()]        
        [string] $VMName,

        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()]        
        [string] $KeyName
    )

    BEGIN {}
    
    PROCESS {
        try {                         
            $VMTags = Get-AzVMTags -ResourceGroupName $ResourceGroupName -VMName $VMName 
            
            $TagWithSpecificKey = $VMTags | Where-Object Key -EQ $KeyName
                        
            $ValueOfTheTag = $TagWithSpecificKey.Value

            Write-Output $ValueOfTheTag                                                                                    
        }
        catch {
            Write-Error  $_.Exception.Message
        }
    }

    END {}
}
function Get-AzSAPDBMSInstances {
    <#
       .SYNOPSIS 
       Get ALL VMs with same SAPSID tag, that runs DBMS layer.
                   
       .DESCRIPTION
       Get ALL VMs with same SAPSID tag, that runs DBMS layer.
       For each VM it will display:
                   - SAPSID
                   - SAP Instance Type [DBMS]
                   - SAPDBMSType
                   - SAPHANASID (for HANA)
                   - SAPHANAInstanceNumber (for HANA)
                   - Azure Resource Group Name
                   - VM Name                
                   - OS type
   
                   
                   .PARAMETER SAPSID 
                   SAP system SID.    
                   
                   .EXAMPLE 
                   # specify SAP SID 'PR1'
                   $SAPSID = "PR1"
                   
                   # Collect SAP VM instances with the same Tag
                   $SAPDBMSInstance = Get-AzSAPDBMSInstances -SAPSID $SAPSID
               
                   # List all collected instances
                   $SAPDBMSInstance
               
                #>
               
    [CmdletBinding()]
    param(        
        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()] 
        $SAPSID         
    )
               
    BEGIN {}
                   
    PROCESS {
        try {   
                                     
            $tags = @{"SAPSystemSID" = $SAPSID }
            $SAPVMs = Get-AzResource -ResourceType "Microsoft.Compute/virtualMachines"  -Tag $tags
   
            foreach ($VMResource in $SAPVMs) {
                   
                $VMTags = Get-AzVMTags -ResourceGroupName $VMResource.ResourceGroupName -VMName $VMResource.Name 
   
                #Check if VM is DBMS host
                $IsDBMSHost = $false                
                
                # If 'SAPDBMSType' Tag exist, then VM is DBMS VM
                $SAPDBMSTypeTag = $VMTags | Where-Object Key -EQ "SAPDBMSType"
                if ($SAPDBMSTypeTag -ne $Null) {                    
                    $IsDBMSHost = $True
                }
   
                if ($IsDBMSHost) {
                    $obj = New-Object -TypeName psobject
                       
                    $OSType = Get-AzVMOSType -VMName $VMResource.Name -ResourceGroupName $VMResource.ResourceGroupName  
                                      
                       
                    $obj | add-member  -NotePropertyName "SAPSID" -NotePropertyValue $SAPSID  
   
                    # Get DBMS type
                    $SAPDBMSTypeTag = $VMTags | Where-Object Key -EQ "SAPDBMSType"  
                    $SAPDBMSType = $SAPDBMSTypeTag.Value
   
                    If ($SAPDBMSType -eq "HANA") {
                        # Get HANA SID
                        $SAPHANASIDTag = $VMTags | Where-Object Key -EQ "SAPHANASID"  
                        $SAPHANASID = $SAPHANASIDTag.Value
                        $obj | add-member  -NotePropertyName "SAPHANASID" -NotePropertyValue $SAPHANASID 
                           
                        # Get SAPHANAInstanceNumber
                        $SAPHANAInstanceNumberTag = $VMTags | Where-Object Key -EQ "SAPHANAInstanceNumber"  
                        $SAPHANAInstanceNumber = $SAPHANAInstanceNumberTag.Value
                        $obj | add-member  -NotePropertyName "SAPHANAInstanceNumber" -NotePropertyValue $SAPHANAInstanceNumber                         
   
                    }elseif ($SAPDBMSType -eq "SQLServer") {
                        $SQLServerInstanceNameTag = $VMTags | Where-Object Key -EQ "DBInstanceName"  
                        $SQLServerInstanceName = $SQLServerInstanceNameTag.Value
                        $obj | add-member  -NotePropertyName "DBInstanceName" -NotePropertyValue $SQLServerInstanceName                         
                    }
   
                    $obj | add-member  -NotePropertyName "SAPInstanceType" -NotePropertyValue "SAP_DBMS"  
                    $obj | add-member  -NotePropertyName "SAPDBMSType" -NotePropertyValue $SAPDBMSType                      
                    $obj | add-member  -NotePropertyName "ResourceGroupName" -NotePropertyValue $VMResource.ResourceGroupName                 
                    $obj | add-member  -NotePropertyName "VMName" -NotePropertyValue $VMResource.Name                    
                    $obj | add-member  -NotePropertyName "OSType"   -NotePropertyValue $OSType
   
                    #Return formated object
                    Write-Output $obj                
                }
            }                                                                                                                   
        }
        catch {
            Write-Error  $_.Exception.Message
        }
    }
               
    END {}
}


function Get-AzSAPHANAInstances {
    <#
       .SYNOPSIS 
       Get ALL VMs with same SAPHANASID tag, that runs DBMS layer.
                   
       .DESCRIPTION
       Get ALL VMs with same SAPSID tag, that runs DBMS layer.
       For each VM it will display:
                   - SAP Instance Type [DBMS]
                   - SAPDBMSType
                   - SAPHANASID (for HANA)
                   - SAPHANAInstanceNumber (for HANA)
                   - Azure Resource Group Name
                   - VM Name                
                   - OS type
   
                   
        .PARAMETER SAPHANASID 
        SAP HANA SID.    
                   
        .EXAMPLE 
        # specify SAP HANA SID 'CE1'
        $SAPSID = "CE1"
                   
        # Collect SAP VM instances with the same Tag
        $SAPDBMSInstance = Get-AzSAPHANAInstances -SAPSID $SAPSID
               
        # List all collected instances
        $SAPDBMSInstance
               
#>
               
    [CmdletBinding()]
    param(        
        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()] 
        $SAPHANASID         
    )
               
    BEGIN {}
                   
    PROCESS {
        try {   
                                     
            $tags = @{"SAPHANASID" = $SAPHANASID }
            $SAPVMs = Get-AzResource -ResourceType "Microsoft.Compute/virtualMachines"  -Tag $tags
   
            foreach ($VMResource in $SAPVMs) {
                   
                $VMTags = Get-AzVMTags -ResourceGroupName $VMResource.ResourceGroupName -VMName $VMResource.Name 
                        
                $obj = New-Object -TypeName psobject
                       
                $OSType = Get-AzVMOSType -VMName $VMResource.Name -ResourceGroupName $VMResource.ResourceGroupName  
                                                                                              
                $SAPDBMSType = "HANA"
                    
                $obj | add-member  -NotePropertyName "SAPHANASID" -NotePropertyValue $SAPHANASID 
                           
                # Get SAPHANAInstanceNumber
                $SAPHANAInstanceNumberTag = $VMTags | Where-Object Key -EQ "SAPHANAInstanceNumber"  
                $SAPHANAInstanceNumber = $SAPHANAInstanceNumberTag.Value

                $obj | add-member  -NotePropertyName "SAPHANAInstanceNumber" -NotePropertyValue $SAPHANAInstanceNumber                                                
                $obj | add-member  -NotePropertyName "SAPInstanceType" -NotePropertyValue "SAP_DBMS"  
                $obj | add-member  -NotePropertyName "SAPDBMSType" -NotePropertyValue $SAPDBMSType                      
                $obj | add-member  -NotePropertyName "ResourceGroupName" -NotePropertyValue $VMResource.ResourceGroupName                 
                $obj | add-member  -NotePropertyName "VMName" -NotePropertyValue $VMResource.Name                    
                $obj | add-member  -NotePropertyName "OSType"   -NotePropertyValue $OSType
   
                #Return formated object
                Write-Output $obj                
            }                                                                                                                               
        }
        catch {
            Write-Error  $_.Exception.Message
        }
    }
               
    END {}
}
function Get-AzSAPApplicationInstances {
    <#
    .SYNOPSIS 
    Get ALL VMs with same SAPSID tag, that runs application layer.
                                
    .DESCRIPTION
    Get ALL VMs with same SAPSID tag, that runs application layer.
    For each VM it will display:
        - SAPSID
        - SAP Instance Type
        - SAP Application Instance Number 
        - Azure Resource Group Name
        - VM Name
        - OS type
                                
    .PARAMETER SAPSID 
    SAP system SID.    
                                
    .EXAMPLE 
    # specify SAP SID 'PR1'
    $SAPSID = "PR1"
                                
    # Collect SAP VM instances with the same Tag
    $SAPApplicationInstances = Get-AzSAPApplicationInstances -SAPSID $SAPSID
                            
    # List all collected instances
    $SAPApplicationInstances
                            
#>
                            
    [CmdletBinding()]
    param(        
        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()] 
        $SAPSID         
    )
                            
    BEGIN {}
                                
    PROCESS {
        try {   
                                                  
            $tags = @{"SAPSystemSID" = $SAPSID }
            $SAPVMs = Get-AzResource -ResourceType "Microsoft.Compute/virtualMachines"  -Tag $tags
                
            foreach ($VMResource in $SAPVMs) {
                                
                $VMTags = Get-AzVMTags -ResourceGroupName $VMResource.ResourceGroupName -VMName $VMResource.Name 
                
                $SAPApplicationInstanceTypeTag = $VMTags | Where-Object Key -EQ "SAPApplicationInstanceType"
                if ($SAPApplicationInstanceTypeTag -ne $Null) {                    
                    # it is application SAP instance
                    
                    $obj = New-Object -TypeName psobject
                    
                    # Get 'SAPApplicationInstanceType'
                    $SAPApplicationInstanceType = $SAPApplicationInstanceTypeTag.Value

                    # Get 'SAPApplicationInstanceNumber'
                    $SAPApplicationInstanceNumberTag = $VMTags | Where-Object Key -EQ "SAPApplicationInstanceNumber"
                    $SAPApplicationInstanceNumber = $SAPApplicationInstanceNumberTag.Value                    

                    $OSType = Get-AzVMOSType -VMName $VMResource.Name -ResourceGroupName $VMResource.ResourceGroupName                                                         
                    #Write-Host "OSType: $OSType"
                    $obj | add-member  -NotePropertyName "SAPSID" -NotePropertyValue $SAPSID  

                    $obj | add-member  -NotePropertyName "SAPInstanceType" -NotePropertyValue $SAPApplicationInstanceType
                    $obj | add-member  -NotePropertyName "SAPApplicationInstanceNumber" -NotePropertyValue $SAPApplicationInstanceNumber

                    $obj | add-member  -NotePropertyName "ResourceGroupName" -NotePropertyValue $VMResource.ResourceGroupName                 
                    $obj | add-member  -NotePropertyName "VMName" -NotePropertyValue $VMResource.Name                    
                    $obj | add-member  -NotePropertyName "OSType"   -NotePropertyValue $OSType

                    #Return formated object
                    Write-Output $obj  
                }                                                
            }                                                                                                                   
        }
        catch {
            Write-Error  $_.Exception.Message
        }
    }
                            
    END {}
}

function Test-AzSAPSIDTagExist {
    <#
    .SYNOPSIS 
    Test if  Tag with 'SAPSystemSID' = '$SAPSID' exist. If not, exit.
    
    .DESCRIPTION
   Test if  Tag with 'SAPSystemSID' = '$SAPSID' exist. If not, exit.
    
    .PARAMETER SAPSID 
    SAP system SID.    
    
    .EXAMPLE 
    # specify SAP SID 'PR1'
    $SAPSID = "PR1"
    
    # test if SAPSIDSystem Tag with $SAPSID value exist
    Test-AzSAPSIDTagExist -SAPSID $SAPSID

    # List all collected instances
    $SAPInstances

 #>

    [CmdletBinding()]
    param(        
        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()] 
        $SAPSID         
    )

    BEGIN {}
    
    PROCESS {
        try {   
                      
            $tags = @{"SAPSystemSID" = $SAPSID }
            $SAPVMs = Get-AzResource -ResourceType "Microsoft.Compute/virtualMachines"  -Tag $tags

            if ($SAPVMs -eq $null) {
                Write-Output "Cannot find VMs with Tag 'SAPSystemSID' = '$SAPSID'"
                Write-Output "Exiting runbook."

                exit
            }
            else {
                Write-Output "Found VMs with Tag 'SAPSystemSID' = '$SAPSID'"
            }                                                        
        }
        catch {
            Write-Error  $_.Exception.Message
        }
    }

    END {}
}

function Test-AzSAPHANASIDTagExist {
    <#
    .SYNOPSIS 
    Test if  Tag with 'SAPHANASID' = '$SAPHANASID' exist. If not, exit.
    
    .DESCRIPTION
    Test if  Tag with 'SAPHANASID' = '$SAPHANASID' exist. If not, exit.
    
    .PARAMETER SAPSID 
    SAP system SID.    
    
    .EXAMPLE 
    # specify SAP SIDHANA  'PR1'
    $SAPHANASID = "PR1"
    
    # test if SAPSIDSystem Tag with $SAPSID value exist
    Test-AzSAPHANASIDTagExist -SAPHANASID $SAPHANASID    

 #>

    [CmdletBinding()]
    param(        
        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()] 
        $SAPHANASID         
    )

    BEGIN {}
    
    PROCESS {
        try {   
                      
            $tags = @{"SAPHANASID" = $SAPHANASID }
            $SAPVMs = Get-AzResource -ResourceType "Microsoft.Compute/virtualMachines"  -Tag $tags

            if ($SAPVMs -eq $null) {
                Write-Output "Cannot find VMs with Tag 'SAPHANASID' = '$SAPHANASID'"
                Write-Output "Exiting runbook."

                exit
            }
            else {
                Write-Output "Found VMs with Tag 'SAPHANASID' = '$SAPHANASID'"
            }                                                        
        }
        catch {
            Write-Error  $_.Exception.Message
        }
    }

    END {}
}

function Show-AzSAPSIDVMApplicationInstances {
    <#
    .SYNOPSIS 
    Print the SAP VMs.
    
    .DESCRIPTION
    Print the SAP VMs.
    
    .PARAMETER SAPVMs 
    List of VM resources. This collection is a list of VMs with same 'SAPSID' tag.
    
    
    .EXAMPLE 
    $SAPSID = "PR2"
    $SAPSIDApplicationVMs = Get-AzSAPApplicationInstances -SAPSID $SAPSID
    Show-AzSAPSIDVMApplicationInstances -SAPVMs $SAPSIDApplicationVMs
 #>
    [CmdletBinding()]
    param(
        
        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()] 
        $SAPVMs
           
    )

    BEGIN {}
    
    PROCESS {
        try {   
                                               
            ForEach ($SAPVM in $SAPVMs) {
                Write-Output "SAPSID:                       $($SAPVM.SAPSID)"  
                Write-Output "SAPInstanceType:              $($SAPVM.SAPInstanceType)"  
                Write-Output "SAPApplicationInstanceNumber: $($SAPVM.SAPApplicationInstanceNumber)"  
                Write-Output "ResourceGroupName:            $($SAPVM.ResourceGroupName)"  
                Write-Output "VMName:                       $($SAPVM.VMName)"  
                Write-Output "OSType:                       $($SAPVM.OSType)"                
                Write-Output ""
            }
                            

            
            
        }
        catch {
            Write-Error  $_.Exception.Message
        }
    }

    END {}
}

function Show-AzSAPSIDVMDBMSInstances {
    <#
    .SYNOPSIS 
    Print the SAP VMs.
    
    .DESCRIPTION
    Print the SAP VMs.
    
    .PARAMETER SAPVMs 
    List of VM resources. This collection is a list of VMs with same 'SAPSID' tag.
    
    
    .EXAMPLE 
    $SAPSID = "PR2"
    $SAPSIDDBMSVMs = Get-AzSAPDBMSInstances -SAPSID $SAPSID
    Show-AzSAPSIDVMDBMSInstances -SAPVMs $SAPSIDApplicationVMs
 #>
    [CmdletBinding()]
    param(
        
        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()] 
        $SAPVMs
           
    )

    BEGIN {}
    
    PROCESS {
        try {                                                  
            ForEach ($SAPVM in $SAPVMs) {
                Write-Output "SAPSID:                       $($SAPVM.SAPSID)"  
                Write-Output "SAPInstanceType:              $($SAPVM.SAPInstanceType)"  
                Write-Output "SAPDBMSType:                  $($SAPVM.SAPDBMSType)"  
                
                if ($SAPVM.SAPDBMSType -eq "HANA") {
                    Write-Output "SAPHANASID:                   $($SAPVM.SAPHANASID)"  
                    Write-Output "SAPHANAInstanceNumber:        $($SAPVM.SAPHANAInstanceNumber)"  
                }

                Write-Output "ResourceGroupName:            $($SAPVM.ResourceGroupName)"  
                Write-Output "VMName:                       $($SAPVM.VMName)"  
                Write-Output "OSType:                       $($SAPVM.OSType)"                
                Write-Output ""
            }                                                    
        }
        catch {
            Write-Error  $_.Exception.Message
        }
    }

    END {}
}

function ConvertTo-AzVMManagedDisksToPremium {
    <#
        .SYNOPSIS 
        Convert all disks of one VM to Premium type.
        
        .DESCRIPTION
        Convert all disks of one VM to Premium type.
        
        .PARAMETER ResourceGroupName 
        VM Resource Group Name.
        
        .PARAMETER VMName 
        VM Name.
        
        .EXAMPLE 
        Convert-AzVMManagedDisksToPremium  -ResourceGroupName  "gor-linux-eastus2-2" -VMName "ts2-di1"
     #>
    
    [CmdletBinding()]
    param(
            
        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()]        
        [string]$ResourceGroupName,
                  
        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()]        
        [string] $VMName
    
            
    )
    
    BEGIN {}
        
    PROCESS {
        try {   
    
            Convert-AzVMManagedDisks -ResourceGroupName $ResourceGroupName -VMName $VMName -storageType "Premium_LRS"
    
        }
        catch {
            Write-Error  $_.Exception.Message
        }
    
    }
    
    END {}
}
    
function ConvertTo-AzVMManagedDisksToStandard {
    <#
    .SYNOPSIS 
    Convert all disks of one vM to Standard type.
            
    .DESCRIPTION
    Convert all disks of one vM to Standard type.
            
    .PARAMETER ResourceGroupName 
    VM Resource Group Name.
            
    .PARAMETER VMName 
    VM Name.
            
    .EXAMPLE 
    Convert-AzVMManagedDisksToStandard  -ResourceGroupName  "gor-linux-eastus2-2" -VMName "ts2-di1"
#>
        
    [CmdletBinding()]
    param(
                
        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()]        
        [string]$ResourceGroupName,
                      
        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()]        
        [string] $VMName
                
    )
        
    BEGIN {}
            
    PROCESS {
        try {   
        
            Convert-AzVMManagedDisks -ResourceGroupName $ResourceGroupName -VMName $VMName -storageType "Standard_LRS"                    
        
        }
        catch {
            Write-Error  $_.Exception.Message
        }
        
    }
        
    END {}
}
        
function Convert-AzVMCollectionManagedDisksToStandard {
    <#
        .SYNOPSIS 
        Convert all disks of VMs collection  to Standard type.
                
        .DESCRIPTION
        Convert all disks of VMs collection  to Standard type.
                
        .PARAMETER SAPVMs 
        VM collection.
            
        .EXAMPLE 
            
        $SAPSID = "TS1"
        $SAPSIDApplicationVMs = Get-AzSAPApplicationInstances -SAPSID $SAPSID
        Convert-AzVMCollectionManagedDisksToStandard -SAPVMs $SAPSIDApplicationVMs        
    #>
    
    [CmdletBinding()]
    param(                        
        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()]        
        $SAPVMs
    )
        
    BEGIN {}
            
    PROCESS {
        try {                               
            ForEach ($VM in $SAPVMs) {                    
                Write-Output "Converting all managed disks of VM '$($VM.VMName)' in Azure resource group '$($VM.ResourceGroupName)' to 'Standard_LRS' type .."
                ConvertTo-AzVMManagedDisksToStandard -ResourceGroupName  $VM.ResourceGroupName -VMName $VM.VMName 
                Write-Output ""
            }
        }
        catch {
            Write-Error  $_.Exception.Message
        }
        
    }
        
    END {}
}    
    
        
function Convert-AzVMCollectionManagedDisksToPremium {
    <#
        .SYNOPSIS 
        Convert all disks of VMs collection  to Premium type.
                
        .DESCRIPTION
        Convert all disks of VMs collection  to Premium type.
                
        .PARAMETER SAPVMs 
        VM collection.
            
        .EXAMPLE         
        $SAPSID = "TS1"
        $SAPSIDApplicationVMs = Get-AzSAPApplicationInstances -SAPSID $SAPSID
        Convert-AzVMCollectionManagedDisksToPremium -SAPVMs $SAPSIDApplicationVMs        
    #>
    [CmdletBinding()]
    param(                        
        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()]        
        $SAPVMs                         
    )
            
    BEGIN {}
                
    PROCESS {
        try {                               
            ForEach ($VM in $SAPVMs) {                        
                Write-Output "Converting all managed disks of VM '$($VM.VMName)' in Azure resource group '$($VM.ResourceGroupName)' to 'Premium_LRS' type .."
                ConvertTo-AzVMManagedDisksToPremium -ResourceGroupName  $VM.ResourceGroupName -VMName $VM.VMName 
                Write-Output ""
            }
        }
        catch {
            Write-Error  $_.Exception.Message
        }
            
    }
            
    END {}
}    
        
function Get-AzVMCollectionManagedDiskType {
    <#
        .SYNOPSIS 
        List all disks and disk type of VMs collection.
            
        .DESCRIPTION
        List all disks and disk type of VMs collection.
            
        .PARAMETER SAPVMs 
        VM collection.
            
        
        .EXAMPLE         
        $SAPSID = "TS1"
        $SAPSIDApplicationVMs = Get-AzSAPApplicationInstances -SAPSID $SAPSID
        Get-AzVMCollectionManagedDiskType -SAPVMs $SAPSIDApplicationVMs
    #>
    [CmdletBinding()]
    param(                        
        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()]        
        $SAPVMs
                           
    )
        
    BEGIN {}
            
    PROCESS {
        try {                               
            ForEach ($VM in $SAPVMs) {                     
                $VMIsRunning = Test-AzVMIsStarted -ResourceGroupName  $VM.ResourceGroupName -VMName $VM.VMName
            
                if ($VMIsRunning -eq $True) {                    
                    # VM is runnign. Return to the main Runbook without listing the disks                    
                    return
                }
                    
                Write-Output "'$($VM.VMName)' VM in Azure resource group '$($VM.ResourceGroupName)' disks:"
                Get-AzVMManagedDiskType -ResourceGroupName  $VM.ResourceGroupName -VMName $VM.VMName 
                Write-Output ""
            }
        }
        catch {
            Write-Error  $_.Exception.Message
        }
        
    }
        
    END {}
}    
    
function Get-AzVMManagedDiskType {
    <#
            .SYNOPSIS 
            List all disks and disk type of one VM.
            
            .DESCRIPTION
            List all disks and disk type of one VM.
            
            .PARAMETER ResourceGroupName 
            Resource Group Name.
            
            .PARAMETER VMName 
            VM Name.
    
            .EXAMPLE         
            $SAPSID = "TS1"
            $SAPSIDApplicationVMs = Get-AzSAPApplicationInstances -SAPSID $SAPSID
            Get-AzVMCollectionManagedDiskType -ResourceGroupName "MyResourceGroupName"  -VMName  "myVM1"
        
    #>
    
    [CmdletBinding()]
    param(
            
        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()]        
        [string]$ResourceGroupName,
                  
        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()]        
        [string] $VMName        
            
    )
    
    BEGIN {}
        
    PROCESS {
        try {   
    
            $VM = Get-AzVM -ResourceGroupName $ResourceGroupName -Name $VMName
    
            #OS Disk
            $OSDisk = $VM.StorageProfile.OsDisk 
            $OSDiskName = $OSDisk.Name
            $OSDiskAllProperties = Get-AzDisk -ResourceGroupName $ResourceGroupName -DiskName $OSDiskName
            Write-Output "$OSDiskName [$($OSDiskAllProperties.Sku.Name)]"
              
    
            #Data Disks
            $DataDisks = $VM.StorageProfile.DataDisks
            $DataDisksNames = $DataDisks.Name
    
            ForEach ($DataDiskName in $DataDisksNames) {
                $DataDiskAllProperties = Get-AzDisk -ResourceGroupName $ResourceGroupName -DiskName $DataDiskName
                Write-Output "$DataDiskName [$($DataDiskAllProperties.Sku.Name)]"
            }
        }
        catch {
            Write-Error  $_.Exception.Message
        }
    
    }
    
    END {}
}



##################

function Convert-AzVMManagedDisks {
    <#
        .SYNOPSIS 
        Convert all disks of one VM to Premium or Standard type.
        
        .DESCRIPTION
        Convert all disks of one vM to Standard type.
        
        .PARAMETER ResourceGroupName 
        VM Resource Group Name.
        
        .PARAMETER VMName 
        VM Name.
        
        .EXAMPLE 
        # Convert to Premium disks
        Convert-AzVMManagedDisks -ResourceGroupName  "gor-linux-eastus2-2" -VMName "ts2-di1" -storageType "Premium_LRS"
    
        .EXAMPLE 
        # Convert to Standard disks
        Convert-AzVMManagedDisks -ResourceGroupName  "gor-linux-eastus2-2" -VMName "ts2-di1" -storageType "Standard_LRS"
    
    #>
                
    [CmdletBinding()]
    param(
                        
        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()]        
        [string]$ResourceGroupName,
                  
        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()]        
        [string] $VMName,
    
        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()]        
        [string] $storageType
                        
    )
                
    BEGIN {}
                    
    PROCESS {
        try {   
                
            $VMIsRunning = Test-AzVMIsStarted -ResourceGroupName  $ResourceGroupName -VMName $VMName

            if ($VMIsRunning -eq $True) {
                Write-WithTime("VM '$VMName' in resource group '$ResourceGroupName' is running. ")
                Write-WithTime("Skipping the disk conversion for the VM '$VMName' in resource group '$ResourceGroupName'. Disks cannot be converted when VM is running. ")
                
                return
            }
            

            $VM = Get-AzVM -ResourceGroupName $ResourceGroupName -Name $VMName
    
            $OSDisk = $VM.StorageProfile.OsDisk 
            $OSDiskName = $OSDisk.Name
            $OSDiskAllProperties = Get-AzDisk -ResourceGroupName $ResourceGroupName -DiskName $OSDiskName     
                
            Write-Output "Converting OS disk $OSDiskName to '$storageType' type ..."
            $OSDiskAllProperties.Sku = [Microsoft.Azure.Management.Compute.Models.DiskSku]::new($storageType)
            $OSDiskAllProperties | Update-AzDisk  > $Null                              
            Write-Output "Done!"                
    
            $DataDisks = $VM.StorageProfile.DataDisks
            $DataDisksNames = $DataDisks.Name
    
            ForEach ($DataDiskName in $DataDisksNames) {
                Write-Output "Converting data disk $DataDiskName to '$storageType' type ..."
                $DataDiskAllProperties = Get-AzDisk -ResourceGroupName $ResourceGroupName -DiskName $DataDiskName
                $DataDiskAllProperties.Sku = [Microsoft.Azure.Management.Compute.Models.DiskSku]::new($storageType)
                $DataDiskAllProperties | Update-AzDisk  > $Null                     
                Write-Output "Done!"
            }                                        
        }
        catch {
            Write-Error  $_.Exception.Message
        }                
    }
                
    END {}
}
    
    
function Convert-AzALLSAPSystemVMsCollectionManagedDisksToPremium {
    <#
            .SYNOPSIS 
            Convert all disks of ALL SAP SID VMs  to Premium type.
                    
            .DESCRIPTION
            Convert all disks of ALL SAP SID VMs  to Premium type.
                    
            .PARAMETER SAPSIDApplicationVMs 
            Colelctions of VMs belonging to SAP apllication layer.

            .PARAMETER SAPSIDDBMSVMs 
            Colelctions of VMs belonging to SAP DBMS layer.
                
            .EXAMPLE         
            $SAPSID = "TS1"
            $SAPSIDApplicationVMs = Get-AzSAPApplicationInstances -SAPSID $SAPSID
            $SAPSIDDBMSVMs  = Get-AzSAPDBMSInstances -SAPSID $SAPSID

            Convert-AzALLSAPSystemVMsCollectionManagedDisksToPremium -SAPSIDApplicationVMs $SAPSIDApplicationVMs -SAPSIDDBMSVMs $SAPSIDDBMSVMs
        
        #>
    [CmdletBinding()]
    param(                        
        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()]        
        $SAPSIDApplicationVMs,

        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()]        
        $SAPSIDDBMSVMs                
    )
                
    BEGIN {}
                    
    PROCESS {
        try {                               
             
            Write-WithTime "SAP Application layer VMs disks:"
            Write-Output ""
            Get-AzVMCollectionManagedDiskType -SAPVMs $SAPSIDApplicationVMs

            Write-WithTime "Converting SAP Application layer VMs disks to 'Premium_LRS' ..."
            Convert-AzVMCollectionManagedDisksToPremium -SAPVMs $SAPSIDApplicationVMs
            Write-Output ""

            Write-WithTime "SAP Application layer VMs disks after conversion:"
            Write-Output ""
            Get-AzVMCollectionManagedDiskType -SAPVMs $SAPSIDApplicationVMs


            Write-WithTime "SAP DBMS layer VM(s)disks:"
            Write-Output ""
            Get-AzVMCollectionManagedDiskType -SAPVMs $SAPSIDDBMSVMs

            Write-WithTime "Converting DBMS layer VMs disks to 'Premium_LRS' ..."
            Convert-AzVMCollectionManagedDisksToPremium -SAPVMs $SAPSIDDBMSVMs
            Write-Output ""

            Write-WithTime "SAP DBMS layer VMs disks after conversion:"
            Write-Output ""
            Get-AzVMCollectionManagedDiskType -SAPVMs $SAPSIDDBMSVMs

        }
        catch {
            Write-Error  $_.Exception.Message
        }
                
    }
                
    END {}
}    

function Convert-AzALLSAPVMsCollectionManagedDisksToPremium {
    <#
            .SYNOPSIS 
            Convert all disks of ALL VMs  to Premium type.
                    
            .DESCRIPTION
            Convert all disks of ALL VMs  to Premium type.
                    
            .PARAMETER SAPSIDApplicationVMs 
            Colelctions of VMs belonging to SAP apllication layer.

            .PARAMETER SAPSIDDBMSVMs 
            Colelctions of VMs belonging to SAP DBMS layer.
                
            .EXAMPLE         
            $SAPSID = "TS1"
            $SAPVMs = Get-AzSAPApplicationInstances -SAPSID $SAPSID            

            Convert-AzALLSAPVMsCollectionManagedDisksToPremium -SAPVMs $SAPVMs
        
        #>
    [CmdletBinding()]
    param(                        
        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()]        
        $SAPVMs        
    )
                
    BEGIN {}
                    
    PROCESS {
        try {                               
             
            Write-WithTime "VMs disks:"
            Write-Output ""
            Get-AzVMCollectionManagedDiskType -SAPVMs $SAPVMs

            Write-WithTime "Converting VMs disks to 'Premium_LRS' ..."
            Convert-AzVMCollectionManagedDisksToPremium -SAPVMs $SAPVMs
            Write-Output ""

            Write-WithTime "VMs disks after conversion:"
            Write-Output ""
            Get-AzVMCollectionManagedDiskType -SAPVMs $SAPVMs          

        }
        catch {
            Write-Error  $_.Exception.Message
        }
                
    }
                
    END {}
}    

function Convert-AzALLSAPSystemVMsCollectionManagedDisksToStandard {
    <#
            .SYNOPSIS 
            Convert all disks of ALL SAP SID VMs  to Standard type.
                    
            .DESCRIPTION
            Convert all disks of ALL SAP SID VMs  to Standard type.
                    
            .PARAMETER SAPSIDApplicationVMs 
            Collrctions of VMs belonging to SAP apllication layer.

            .PARAMETER SAPSIDDBMSVMs 
            Colelctions of VMs belonging to SAP DBMS layer.
                
            .EXAMPLE         
            $SAPSID = "TS1"
            $SAPSIDApplicationVMs = Get-AzSAPApplicationInstances -SAPSID $SAPSID
            $SAPSIDDBMSVMs  = Get-AzSAPDBMSInstances -SAPSID $SAPSID

            Convert-AzALLSAPSystemVMsCollectionManagedDisksToStandard -SAPSIDApplicationVMs $SAPSIDApplicationVMs -SAPSIDDBMSVMs $SAPSIDDBMSVMs
        
        #>
    [CmdletBinding()]
    param(                        
        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()]        
        $SAPSIDApplicationVMs,

        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()]        
        $SAPSIDDBMSVMs                
    )
                
    BEGIN {}
                    
    PROCESS {
        try {                               
             
            Write-WithTime "SAP Application layer VMs disks:"
            Write-Output ""
            Get-AzVMCollectionManagedDiskType -SAPVMs $SAPSIDApplicationVMs

            Write-WithTime "Converting SAP Application layer VMs disks to 'Standard_LRS' ..."
            Convert-AzVMCollectionManagedDisksToStandard -SAPVMs $SAPSIDApplicationVMs
            Write-Output ""

            Write-WithTime "SAP Application layer VMs disks after conversion:"
            Write-Output ""
            Get-AzVMCollectionManagedDiskType -SAPVMs $SAPSIDApplicationVMs


            Write-WithTime "SAP DBMS layer VM(s)disks:"
            Write-Output ""
            Get-AzVMCollectionManagedDiskType -SAPVMs $SAPSIDDBMSVMs

            Write-WithTime "Converting DBMS layer VMs disks to 'Standard_LRS' ..."
            Convert-AzVMCollectionManagedDisksToStandard -SAPVMs $SAPSIDDBMSVMs
            Write-Output ""

            Write-WithTime "SAP DBMS layer VMs disks after conversion:"
            Write-Output ""
            Get-AzVMCollectionManagedDiskType -SAPVMs $SAPSIDDBMSVMs

        }
        catch {
            Write-Error  $_.Exception.Message
        }
                
    }
                
    END {}
}    

function Convert-AzALLSAPVMsCollectionManagedDisksToStandard {
    <#
            .SYNOPSIS 
            Convert all disks of VMs  to Standard type.
                    
            .DESCRIPTION
            Convert all disks of VMs  to Standard type.
                    
            .PARAMETER SAPSIDApplicationVMs 
            Collrctions of VMs belonging to SAP apllication layer.

            .PARAMETER SAPVMs 
            Collections of VMs .
                
            .EXAMPLE         
            $SAPSID = "TS1"
            $SAPSIDApplicationVMs = Get-AzSAPApplicationInstances -SAPSID $SAPSID            

            Convert-AzALLSAPVMsCollectionManagedDisksToStandard -SAPVMs $SAPSIDApplicationVMs 
        
        #>
    [CmdletBinding()]
    param(                        
        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()]        
        $SAPVMs
    )
                
    BEGIN {}
                    
    PROCESS {
        try {                               
             
            Write-WithTime "VMs disks:"
            Write-Output ""
            Get-AzVMCollectionManagedDiskType -SAPVMs $SAPVMs

            Write-WithTime "Converting  VMs disks to 'Standard_LRS' ..."
            Convert-AzVMCollectionManagedDisksToStandard -SAPVMs $SAPVMs
            Write-Output ""

            Write-WithTime "VMs disks after conversion:"
            Write-Output ""
            Get-AzVMCollectionManagedDiskType -SAPVMs $SAPVMs            

        }
        catch {
            Write-Error  $_.Exception.Message
        }
                
    }
                
    END {}
}    

function New-AzSAPSystemHANATags {
    <#
            .SYNOPSIS 
            Set Tags on Standalone SAP HANA belonging to an SAP SID system.
                    
            .DESCRIPTION
            Set Tags on Standalone SAP HANA belonging to an SAP SID system.
                    
            .PARAMETER ResourceGroupName 
            Resource Group Name of the VM.
    
            .PARAMETER VMName 
            VM name. 

            .PARAMETER SAPSID 
            SAP system SID. 

            .PARAMETER SAPHANASID 
            SAP HANA SID. 

            .PARAMETER SAPHANAINstanceNumber 
            SAP HANA InstanceNumber. 
                
            .EXAMPLE         
           # Set Tags on Standalone HANA belonging to an SAP system
           $ResourceGroupName = "gor-linux-eastus2"
           $VMName = "ts2-db"

           New-AzSAPSystemHANATags -ResourceGroupName $ResourceGroupName -VMName $VMName -SAPSID "TS1" -SAPHANASID "TS2" -SAPHANAINstanceNumber 0         
        #>
    [CmdletBinding()]
    param(                        
        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()]        
        [string]$ResourceGroupName,
              
        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()]        
        [string] $VMName,
        
        [Parameter(Mandatory = $True, HelpMessage = "SAP System <SID>. 3 characters , starts with letter.")] 
        [ValidateLength(3, 3)]
        [string] $SAPSID,

        [Parameter(Mandatory = $True, HelpMessage = "SAP HANA <SID>. 3 characters , starts with letter.")] 
        [ValidateLength(3, 3)]
        [string] $SAPHANASID,

        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()]        
        [ValidateLength(1, 2)]
        [string] $SAPHANAInstanceNumber
    )
                
    BEGIN {}
                    
    PROCESS {
        try {                                                                               
            $SAPDBMSType = "HANA"
            
            $tags = @{"SAPSystemSID" = $SAPSID; "SAPHANASID" = $SAPHANASID; "SAPHANAINstanceNumber" = $SAPHANAInstanceNumber; "SAPDBMSType" = $SAPDBMSType; }
            
            $resource = Get-AzResource -ResourceGroupName $ResourceGroupName -ResourceName $VMName
            #New-AzTag -ResourceId $resource.id -Tag $tags            
            Update-AzTag -ResourceId $resource.id -Tag $tags -Operation Merge
        }
        catch {
            Write-Error  $_.Exception.Message
        }
                
    }
                
    END {}
}    

function New-AzSAPStandaloneHANATags {
    <#
            .SYNOPSIS 
            Set Tags on Standalone SAP HANA.
                    
            .DESCRIPTION
            Set Tags on Standalone SAP HANA.
                    
            .PARAMETER ResourceGroupName 
            Resource Group Name of the VM.
    
            .PARAMETER VMName 
            VM name. 

            .PARAMETER SAPHANASID 
            SAP HANA SID. 

            .PARAMETER SAPHANAINstanceNumber 
            SAP HANA InstanceNumber. 
                
            .EXAMPLE         
           # Set Tags on Standalone HANA belonging to an SAP system
           $ResourceGroupName = "gor-linux-eastus2"
           $VMName = "ts2-db"

           New-AzSAPHANATags -ResourceGroupName $ResourceGroupName -VMName $VMName -SAPSID "TS1" -SAPHANASID "TS2" -SAPHANAINstanceNumber 0         
        #>
    [CmdletBinding()]
    param(                        
        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()]        
        [string]$ResourceGroupName,
              
        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()]        
        [string] $VMName,
            

        [Parameter(Mandatory = $True, HelpMessage = "SAP HANA <SID>. 3 characters , starts with letter.")] 
        [ValidateLength(3, 3)]
        [string] $SAPHANASID,

        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()]
        [ValidateLength(1, 2)]     
        [string] $SAPHANAInstanceNumber
    )
                
    BEGIN {}
                    
    PROCESS {
        try {                                                                               
            $SAPDBMSType = "HANA"
            
            $tags = @{"SAPHANASID" = $SAPHANASID; "SAPHANAINstanceNumber" = $SAPHANAInstanceNumber; "SAPDBMSType" = $SAPDBMSType; }
            
            $resource = Get-AzResource -ResourceGroupName $ResourceGroupName -ResourceName $VMName
            #New-AzTag -ResourceId $resource.id -Tag $tags            
            Update-AzTag -ResourceId $resource.id -Tag $tags -Operation Merge
        }
        catch {
            Write-Error  $_.Exception.Message
        }                
    }
                
    END {}
}    

function New-AzSAPSystemHANAAndASCSTags {
    <#
            .SYNOPSIS 
            Set Tags on Standalone SAP HANA with SAP 'ASCS' instance.
                    
            .DESCRIPTION
            Set Tags on Standalone SAP HANA with SAP 'ASCS' instance. This is used with SAP Central System where complete system is isntelld on one VM, or distributed system where HANA and ASCS instance are located on the same VM
                    
            .PARAMETER ResourceGroupName 
            Resource Group Name of the VM.
    
            .PARAMETER VMName 
            VM name. 

            .PARAMETER SAPSID 
            SAP system SID. 

            .PARAMETER SAPHANASID 
            SAP HANA SID. 

            .PARAMETER SAPHANAINstanceNumber 
            SAP HANA InstanceNumber. 
                
            .PARAMETER SAPApplicationInstanceNumber 
            SAP ASCS Instance Number. 

            .EXAMPLE         
           # Set Tags on Standalone HANA belonging to an SAP system
           $ResourceGroupName = "gor-linux-eastus2"
           $VMName = "ts2-db"

           New-AzSAPSystemHANATags -ResourceGroupName $ResourceGroupName -VMName $VMName -SAPSID "TS1" -SAPHANASID "TS2" -SAPHANAINstanceNumber 0  -SAPApplicationInstanceNumber 1      
        #>
    [CmdletBinding()]
    param(                        
        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()]        
        [string]$ResourceGroupName,
              
        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()]        
        [string] $VMName,
        
        [Parameter(Mandatory = $True, HelpMessage = "SAP System <SID>. 3 characters , starts with letter.")] 
        [ValidateLength(3, 3)]
        [string] $SAPSID,

        [Parameter(Mandatory = $True, HelpMessage = "SAP HANA <SID>. 3 characters , starts with letter.")] 
        [ValidateLength(3, 3)]
        [string] $SAPHANASID,

        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()]
        [ValidateLength(1, 2)]      
        [string] $SAPHANAInstanceNumber,

        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()]
        [ValidateLength(1, 2)]    
        [string] $SAPApplicationInstanceNumber
    )
                
    BEGIN {}
                    
    PROCESS {
        try {                               
                                    
            #$DBMSInstance = $true
            $SAPDBMSType = "HANA"            
            $SAPApplicationInstanceType = "SAP_ASCS"
            
            $tags = @{"SAPSystemSID" = $SAPSID; "SAPHANASID" = $SAPHANASID; "SAPHANAINstanceNumber" = $SAPHANAInstanceNumber; "SAPDBMSType" = $SAPDBMSType; "SAPApplicationInstanceType" = $SAPApplicationInstanceType ; "SAPApplicationInstanceNumber" = $SAPApplicationInstanceNumber }
            
            $resource = Get-AzResource -ResourceGroupName $ResourceGroupName -ResourceName $VMName
            #New-AzTag -ResourceId $resource.id -Tag $tags
            Update-AzTag -ResourceId $resource.id -Tag $tags -Operation Merge            
        }
        catch {
            Write-Error  $_.Exception.Message
        }
                
    }
                
    END {}
}    

function New-AzSAPSystemASCSLinuxTags {
    <#
            .SYNOPSIS 
            Set Tags on Standalone SAP 'ASCS' instance on Linux.
                    
            .DESCRIPTION
            Set Tags on Standalone SAP 'ASCS' instance on Linux.
                    
            .PARAMETER ResourceGroupName 
            Resource Group Name of the VM.
    
            .PARAMETER VMName 
            VM name. 

            .PARAMETER SAPSID 
            SAP system SID. 
                
            .PARAMETER SAPApplicationInstanceNumber 
            SAP ASCS Instance Number. 

            .EXAMPLE         
           # Set Tags on Standalone HANA belonging to an SAP system
           $ResourceGroupName = "gor-linux-eastus2"
           $VMName = "ts2-db"

           New-AzSAPSystemASCSLinux -ResourceGroupName $ResourceGroupName -VMName $VMName -SAPSID "TS1" -SAPApplicationInstanceNumber 1      
        #>
    [CmdletBinding()]
    param(                        
        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()]        
        [string]$ResourceGroupName,
              
        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()]        
        [string] $VMName,
        
        [Parameter(Mandatory = $True, HelpMessage = "SAP System <SID>. 3 characters , starts with letter.")] 
        [ValidateLength(3, 3)]
        [string] $SAPSID,
        
        [Parameter(Mandatory = $True)]
        [ValidateLength(1, 2)]
        [string] $SAPApplicationInstanceNumber
    )
                
    BEGIN {}
                    
    PROCESS {
        try {                               
                                                         
            $SAPApplicationInstanceType = "SAP_ASCS"
            
            $tags = @{"SAPSystemSID" = $SAPSID; "SAPApplicationInstanceType" = $SAPApplicationInstanceType ; "SAPApplicationInstanceNumber" = $SAPApplicationInstanceNumber }
            
            $resource = Get-AzResource -ResourceGroupName $ResourceGroupName -ResourceName $VMName
            #New-AzTag -ResourceId $resource.id -Tag $tags
            Update-AzTag -ResourceId $resource.id -Tag $tags -Operation Merge            
        }
        catch {
            Write-Error  $_.Exception.Message
        }
                
    }
                
    END {}
}    

function New-AzSAPSystemSCSLinuxTags {
    <#
            .SYNOPSIS 
            Set Tags on Standalone SAP 'SCS' instance on Linux.
                    
            .DESCRIPTION
            Set Tags on Standalone SAP 'SCS' instance on Linux.
                    
            .PARAMETER ResourceGroupName 
            Resource Group Name of the VM.
    
            .PARAMETER VMName 
            VM name. 

            .PARAMETER SAPSID 
            SAP system SID. 
                
            .PARAMETER SAPApplicationInstanceNumber 
            SAP ASCS Instance Number. 

            .EXAMPLE         
           # Set Tags on Standalone HANA belonging to an SAP system
           $ResourceGroupName = "gor-linux-eastus2"
           $VMName = "ts2-db"

           New-AzSAPSystemSCSLinux -ResourceGroupName $ResourceGroupName -VMName $VMName -SAPSID "TS1" -SAPApplicationInstanceNumber 1      
        #>
    [CmdletBinding()]
    param(                        
        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()]        
        [string]$ResourceGroupName,
              
        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()]        
        [string] $VMName,
        
        [Parameter(Mandatory = $True, HelpMessage = "SAP System <SID>. 3 characters , starts with letter.")] 
        [ValidateLength(3, 3)]
        [string] $SAPSID,
        
        [Parameter(Mandatory = $True)]
        [ValidateLength(1, 2)]
        [string] $SAPApplicationInstanceNumber
    )
                
    BEGIN {}
                    
    PROCESS {
        try {                               
                                                         
            $SAPApplicationInstanceType = "SAP_SCS"
            
            $tags = @{"SAPSystemSID" = $SAPSID; "SAPApplicationInstanceType" = $SAPApplicationInstanceType ; "SAPApplicationInstanceNumber" = $SAPApplicationInstanceNumber }
            
            $resource = Get-AzResource -ResourceGroupName $ResourceGroupName -ResourceName $VMName
            #New-AzTag -ResourceId $resource.id -Tag $tags
            Update-AzTag -ResourceId $resource.id -Tag $tags -Operation Merge            
        }
        catch {
            Write-Error  $_.Exception.Message
        }
                
    }
                
    END {}
}    

function New-AzSAPSystemSAPDVEBMGSLinuxTags {
    <#
            .SYNOPSIS 
            Set Tags on Standalone SAP 'DVEBMGS' instance on Linux.
                    
            .DESCRIPTION
            Set Tags on Standalone SAP 'DVEBMGS' instance on Linux.
                    
            .PARAMETER ResourceGroupName 
            Resource Group Name of the VM.
    
            .PARAMETER VMName 
            VM name. 

            .PARAMETER SAPSID 
            SAP system SID. 
                
            .PARAMETER SAPApplicationInstanceNumber 
            SAP DVEBMGS Instance Number. 

            .EXAMPLE         
           # Set Tags on Standalone HANA belonging to an SAP system
           $ResourceGroupName = "gor-linux-eastus2"
           $VMName = "ts2-db"

           New-AzSAPSystemSAPDVEBMGSLinux -ResourceGroupName $ResourceGroupName -VMName $VMName -SAPSID "TS1" -SAPApplicationInstanceNumber 1          
        #>
    [CmdletBinding()]
    param(                        
        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()]        
        [string]$ResourceGroupName,
              
        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()]        
        [string] $VMName,
        
        [Parameter(Mandatory = $True, HelpMessage = "SAP System <SID>. 3 characters , starts with letter.")] 
        [ValidateLength(3, 3)]
        [string] $SAPSID,
        
        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()]
        [ValidateLength(1, 2)]    
        [string] $SAPApplicationInstanceNumber
    )
                
    BEGIN {}
                    
    PROCESS {
        try {                               
                                                         
            $SAPApplicationInstanceType = "SAP_DVEBMGS"
            
            $tags = @{"SAPSystemSID" = $SAPSID; "SAPApplicationInstanceType" = $SAPApplicationInstanceType ; "SAPApplicationInstanceNumber" = $SAPApplicationInstanceNumber }
            
            $resource = Get-AzResource -ResourceGroupName $ResourceGroupName -ResourceName $VMName
            #New-AzTag -ResourceId $resource.id -Tag $tags
            Update-AzTag -ResourceId $resource.id -Tag $tags -Operation Merge            
        }
        catch {
            Write-Error  $_.Exception.Message
        }
                
    }
                
    END {}
}    

function New-AzSAPSystemSAPDialogInstanceApplicationServerLinuxTags {
    <#
            .SYNOPSIS 
            Set Tags on Standalone SAP Dialog 'D' Instance Application Server instance on Linux.
                    
            .DESCRIPTION
            Set Tags on Standalone SAP Dialog 'D' Instance Application Server instance on Linux.
                    
            .PARAMETER ResourceGroupName 
            Resource Group Name of the VM.
    
            .PARAMETER VMName 
            VM name. 

            .PARAMETER SAPSID 
            SAP system SID. 
                
            .PARAMETER SAPApplicationInstanceNumber 
            SAP SAP Dialog 'D' Instance Application Server Instance Number. 

            .EXAMPLE         
           # Set Tags on Standalone HANA belonging to an SAP system
           $ResourceGroupName = "gor-linux-eastus2"
           $VMName = "ts2-db"

           New-AzSAPSystemSAPDialogInstanceApplicationServerLinux -ResourceGroupName $ResourceGroupName -VMName $VMName -SAPSID "TS1" -SAPApplicationInstanceNumber 1          
        #>
    [CmdletBinding()]
    param(                        
        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()]        
        [string]$ResourceGroupName,
              
        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()]        
        [string] $VMName,
        
        [Parameter(Mandatory = $True, HelpMessage = "SAP System <SID>. 3 characters , starts with letter.")] 
        [ValidateLength(3, 3)]
        [string] $SAPSID,
        
        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()]
        [ValidateLength(1, 2)]
        [string] $SAPApplicationInstanceNumber
    )
                
    BEGIN {}
                    
    PROCESS {
        try {                               
                                                         
            $SAPApplicationInstanceType = "SAP_D"
            
            $tags = @{"SAPSystemSID" = $SAPSID; "SAPApplicationInstanceType" = $SAPApplicationInstanceType ; "SAPApplicationInstanceNumber" = $SAPApplicationInstanceNumber }
            
            $resource = Get-AzResource -ResourceGroupName $ResourceGroupName -ResourceName $VMName
            #New-AzTag -ResourceId $resource.id -Tag $tags
            Update-AzTag -ResourceId $resource.id -Tag $tags -Operation Merge            
        }
        catch {
            Write-Error  $_.Exception.Message
        }
                
    }
                
    END {}
}    

function New-AzSAPSystemSAPJavaApplicationServerInstanceLinuxTags {
    <#
            .SYNOPSIS 
            Set Tags on Standalone SAP Java 'J' Instance Application Server instance on Linux.
                    
            .DESCRIPTION
            Set Tags on Standalone SAP Java 'J' Instance Application Server instance on Linux.
                    
            .PARAMETER ResourceGroupName 
            Resource Group Name of the VM.
    
            .PARAMETER VMName 
            VM name. 

            .PARAMETER SAPSID 
            SAP system SID. 
                
            .PARAMETER SAPApplicationInstanceNumber 
            SAP SAP Dialog 'D' Instance Application Server Instance Number. 

            .EXAMPLE         
           # Set Tags on Standalone HANA belonging to an SAP system
           $ResourceGroupName = "gor-linux-eastus2"
           $VMName = "ts2-db"

           New-AzSAPSystemSAPJavaApplicationServerInstanceLinuxTags -ResourceGroupName $ResourceGroupName -VMName $VMName -SAPSID "TS1" -SAPApplicationInstanceNumber 1          
        #>
    [CmdletBinding()]
    param(                        
        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()]        
        [string]$ResourceGroupName,
              
        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()]        
        [string] $VMName,
        
        [Parameter(Mandatory = $True, HelpMessage = "SAP System <SID>. 3 characters , starts with letter.")] 
        [ValidateLength(3, 3)]
        [string] $SAPSID,
        
        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()]
        [ValidateLength(1, 2)]
        [string] $SAPApplicationInstanceNumber
    )
                
    BEGIN {}
                    
    PROCESS {
        try {                               
                                                         
            $SAPApplicationInstanceType = "SAP_J"
            
            $tags = @{"SAPSystemSID" = $SAPSID; "SAPApplicationInstanceType" = $SAPApplicationInstanceType ; "SAPApplicationInstanceNumber" = $SAPApplicationInstanceNumber }
            
            $resource = Get-AzResource -ResourceGroupName $ResourceGroupName -ResourceName $VMName
            #New-AzTag -ResourceId $resource.id -Tag $tags
            Update-AzTag -ResourceId $resource.id -Tag $tags -Operation Merge            
        }
        catch {
            Write-Error  $_.Exception.Message
        }
                
    }
                
    END {}
}    

function New-AzSAPsidadmUserAutomationCredential {
    <#
            .SYNOPSIS 
           Creates new Azure Automation credentials for SAP <sid>adm user,need on Windows OS.
                    
            .DESCRIPTION
            Creates new Azure Automation credentials for SAP <sid>adm user,need on Windows OS.
                    
            .PARAMETER AutomationAccountResourceGroupName 
            Azure Automation Account Resource Group Name.
    
            .PARAMETER AutomationAccountName 
            Azure Automation Account Name. 

            .PARAMETER SAPSID 
            SAP system SID. 
                
            .PARAMETER SAPsidadmUserPassword 
            SAP <sidadm> user password.

            .EXAMPLE         
           # Set Tags on Standalone HANA belonging to an SAP system
           $ResourceGroupName = "gor-linux-eastus2"           
           New-AzSAPsidadmUserAutomationCredential -AutomationAccountResourceGroupName $ResourceGroupName -AutomationAccountName "MyAzureAutomationAccount" -SAPSID "TS1" -SAPsidadmUserPassword "MyPwd"          
        #>
    [CmdletBinding()]
    param(                        
        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()]        
        [string]$AutomationAccountResourceGroupName,
              
        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()]        
        [string] $AutomationAccountName,
        
        [Parameter(Mandatory = $True, HelpMessage = "SAP System <SID>. 3 characters , starts with letter.")] 
        [ValidateLength(3, 3)]
        [string] $SAPSID,
        
        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()]        
        [string] $SAPsidadmUserPassword
    )
                
    BEGIN {}
                    
    PROCESS {
        try {                               
                    
            $User = $SAPSID.Trim().ToLower() + "adm"
            $Password = ConvertTo-SecureString $SAPsidadmUserPassword  -AsPlainText -Force
            $Credential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $User, $Password
            New-AzAutomationCredential -AutomationAccountName $AutomationAccountName  -Name $user  -Value $Credential -ResourceGroupName $AutomationAccountResourceGroupName
            
        }
        catch {
            Write-Error  $_.Exception.Message
        }
                
    }
                
    END {}
}    

function New-AzSAPSystemASCSWindowsTags {
    <#
            .SYNOPSIS 
            Set Tags on Standalone SAP 'ASCS' instance on Windows.
                    
            .DESCRIPTION
            Set Tags on Standalone SAP 'ASCS' instance on Windows.
                    
            .PARAMETER ResourceGroupName 
            Resource Group Name of the VM.
    
            .PARAMETER VMName 
            VM name. 

            .PARAMETER SAPSID 
            SAP system SID. 
                
            .PARAMETER SAPApplicationInstanceNumber 
            SAP ASCS Instance Number. 

            .EXAMPLE         
           # Set Tags on Standalone HANA belonging to an SAP system
           $ResourceGroupName = "gor-linux-eastus2"
           $VMName = "ts2-db"

           New-AzSAPSystemASCSWindowsTags -ResourceGroupName $ResourceGroupName -VMName $VMName -SAPSID "TS1" -SAPApplicationInstanceNumber 1 -PathToSAPControl "S:\usr\sap\ASCS00\exe\sapcontrol.exe"  -AutomationAccountResourceGroupName "RG-AutomationAccount" -AutomationAccountName "my-sap-autoamtion-account" -SAPsidadmUserPassword "MyPwd374"
        #>
    [CmdletBinding()]
    param(                        
        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()]        
        [string]$ResourceGroupName,
              
        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()]        
        [string] $VMName,
        
        [Parameter(Mandatory = $True, HelpMessage = "SAP System <SID>. 3 characters , starts with letter.")] 
        [ValidateLength(3, 3)]
        [string] $SAPSID,
        
        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()]
        [ValidateLength(1, 2)]   
        [string] $SAPApplicationInstanceNumber,

        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()]        
        [string] $PathToSAPControl,

        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()]        
        [string]$AutomationAccountResourceGroupName,
              
        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()]        
        [string] $AutomationAccountName,        
        
        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()]        
        [string] $SAPsidadmUserPassword
    )
                
    BEGIN {}
                    
    PROCESS {
        try {                               
                                                         
            $SAPApplicationInstanceType = "SAP_ASCS"            

            # Create VM Tags
            Write-Output "Creating '$SAPApplicationInstanceType' Tags on VM '$VMName' in resource group '$ResourceGroupName' ...."
            $tags = @{"SAPSystemSID" = $SAPSID; "SAPApplicationInstanceType" = $SAPApplicationInstanceType ; "SAPApplicationInstanceNumber" = $SAPApplicationInstanceNumber; "PathToSAPControl" = $PathToSAPControl }
            
            $resource = Get-AzResource -ResourceGroupName $ResourceGroupName -ResourceName $VMName
            #New-AzTag -ResourceId $resource.id -Tag $tags
            Update-AzTag -ResourceId $resource.id -Tag $tags -Operation Merge

            # Create Credetnials in Azure Automation Secure Area 
            $User = $SAPSID.Trim().ToLower() + "adm"
            Write-Output "Creating  credentials in Azure automation account secure area for user '$User' ...."
            New-AzSAPsidadmUserAutomationCredential -AutomationAccountResourceGroupName $AutomationAccountResourceGroupName -AutomationAccountName $AutomationAccountName -SAPSID $SAPSID -SAPsidadmUserPassword $SAPsidadmUserPassword                                  
        }
        catch {
            Write-Error  $_.Exception.Message
        }
                
    }
                
    END {}
}    

function New-AzSAPSystemSCSWindowsTags {
    <#
            .SYNOPSIS 
            Set Tags on Standalone SAP Java 'SCS' instance on Windows.
                    
            .DESCRIPTION
            Set Tags on Standalone SAP Java 'SCS' instance on Windows.
                    
            .PARAMETER ResourceGroupName 
            Resource Group Name of the VM.
    
            .PARAMETER VMName 
            VM name. 

            .PARAMETER SAPSID 
            SAP system SID. 
                
            .PARAMETER SAPApplicationInstanceNumber 
            SAP ASCS Instance Number. 

            .EXAMPLE         
           # Set Tags on Standalone HANA belonging to an SAP system
           $ResourceGroupName = "gor-linux-eastus2"
           $VMName = "ts2-db"
           
           New-AzSAPSystemSCSWindowsTags -ResourceGroupName $ResourceGroupName -VMName $VMName -SAPSID "TS1" -SAPApplicationInstanceNumber 1 -PathToSAPControl "S:\usr\sap\TS1\SCS01\exe\sapcontrol.exe"  -AutomationAccountResourceGroupName "RG-AutomationAccount" -AutomationAccountName "my-sap-autoamtion-account" -SAPsidadmUserPassword "MyPwd374"   
        #>
    [CmdletBinding()]
    param(                        
        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()]        
        [string]$ResourceGroupName,
              
        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()]        
        [string] $VMName,
        
        [Parameter(Mandatory = $True, HelpMessage = "SAP System <SID>. 3 characters , starts with letter.")] 
        [ValidateLength(3, 3)]
        [string] $SAPSID,
        
        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()]
        [ValidateLength(1, 2)]   
        [string] $SAPApplicationInstanceNumber,

        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()]        
        [string] $PathToSAPControl,

        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()]        
        [string]$AutomationAccountResourceGroupName,
              
        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()]        
        [string] $AutomationAccountName,        
        
        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()]        
        [string] $SAPsidadmUserPassword
    )
                
    BEGIN {}
                    
    PROCESS {
        try {                               
                                                         
            $SAPApplicationInstanceType = "SAP_SCS"            

            # Create VM Tags
            Write-Output "Creating '$SAPApplicationInstanceType' Tags on VM '$VMName' in resource group '$ResourceGroupName' ...."
            $tags = @{"SAPSystemSID" = $SAPSID; "SAPApplicationInstanceType" = $SAPApplicationInstanceType ; "SAPApplicationInstanceNumber" = $SAPApplicationInstanceNumber; "PathToSAPControl" = $PathToSAPControl }
            
            $resource = Get-AzResource -ResourceGroupName $ResourceGroupName -ResourceName $VMName
            #New-AzTag -ResourceId $resource.id -Tag $tags
            Update-AzTag -ResourceId $resource.id -Tag $tags -Operation Merge

            # Create Credetnials in Azure Automation Secure Area 
            $User = $SAPSID.Trim().ToLower() + "adm"
            Write-Output "Creating  credentials in Azure automation account secure area for user '$User' ...."
            New-AzSAPsidadmUserAutomationCredential -AutomationAccountResourceGroupName $AutomationAccountResourceGroupName -AutomationAccountName $AutomationAccountName -SAPSID $SAPSID -SAPsidadmUserPassword $SAPsidadmUserPassword                                  
        }
        catch {
            Write-Error  $_.Exception.Message
        }
                
    }
                
    END {}
}    
function New-AzSAPSystemDVEBMGSWindowsTags {
    <#
            .SYNOPSIS 
            Set Tags on Standalone SAP 'DVEBMGS' instance on Windows.
                    
            .DESCRIPTION
            Set Tags on Standalone SAP 'DVEBMGS' instance on Windows.
                    
            .PARAMETER ResourceGroupName 
            Resource Group Name of the VM.
    
            .PARAMETER VMName 
            VM name. 

            .PARAMETER SAPSID 
            SAP system SID. 
                
            .PARAMETER SAPApplicationInstanceNumber 
            SAP DVEBMGS Instance Number. 

            .EXAMPLE         
           # Set Tags on Standalone HANA belonging to an SAP system
           $ResourceGroupName = "gor-linux-eastus2"
           $VMName = "ts2-db"

           New-AzSAPSystemDVEBMGSWindows -ResourceGroupName $ResourceGroupName -VMName $VMName -SAPSID "TS1" -SAPApplicationInstanceNumber 1 -PathToSAPControl "S:\usr\sap\TS1\J01\exe\sapcontrol.exe" -AutomationAccountResourceGroupName "rg-autom-account"  -AutomationAccountName "sap-automat-acc" -SAPsidadmUserPassword "MyPass789j$&"         
        #>
    [CmdletBinding()]
    param(                        
        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()]        
        [string]$ResourceGroupName,
              
        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()]        
        [string] $VMName,
        
        [Parameter(Mandatory = $True, HelpMessage = "SAP System <SID>. 3 characters , starts with letter.")] 
        [ValidateLength(3, 3)]
        [string] $SAPSID,
        
        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()]
        [ValidateLength(1, 2)]
        [string] $SAPApplicationInstanceNumber,

        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()]        
        [string] $PathToSAPControl,

        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()]        
        [string]$AutomationAccountResourceGroupName,
              
        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()]        
        [string] $AutomationAccountName,        
        
        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()]        
        [string] $SAPsidadmUserPassword
    )
                
    BEGIN {}
                    
    PROCESS {
        try {                               
                                                         
            $SAPApplicationInstanceType = "SAP_DVEBMGS"            

            # Create VM Tags
            Write-Output "Creating '$SAPApplicationInstanceType' Tags on VM '$VMName' in resource group '$ResourceGroupName' ...."
            $tags = @{"SAPSystemSID" = $SAPSID; "SAPApplicationInstanceType" = $SAPApplicationInstanceType ; "SAPApplicationInstanceNumber" = $SAPApplicationInstanceNumber; "PathToSAPControl" = $PathToSAPControl }
            
            $resource = Get-AzResource -ResourceGroupName $ResourceGroupName -ResourceName $VMName
            #New-AzTag -ResourceId $resource.id -Tag $tags
            Update-AzTag -ResourceId $resource.id -Tag $tags -Operation Merge

            # Create Credetnials in Azure Automation Secure Area 
            $User = $SAPSID.Trim().ToLower() + "adm"
            Write-Output "Creating  credentials in Azure automation account secure area for user '$User' ...."
            New-AzSAPsidadmUserAutomationCredential -AutomationAccountResourceGroupName $AutomationAccountResourceGroupName -AutomationAccountName $AutomationAccountName -SAPSID $SAPSID -SAPsidadmUserPassword $SAPsidadmUserPassword          
            
            
        }
        catch {
            Write-Error  $_.Exception.Message
        }
                
    }
                
    END {}
}    


function New-AzSAPSystemSAPDialogInstanceApplicationServerWindowsTags {
    <#
            .SYNOPSIS 
            Set Tags on Standalone Dialog Instance Application Server instance on Windows.
                    
            .DESCRIPTION
            Set Tags on Standalone Dialog Instance Application Server instance on Windows.
                    
            .PARAMETER ResourceGroupName 
            Resource Group Name of the VM.
    
            .PARAMETER VMName 
            VM name. 

            .PARAMETER SAPSID 
            SAP system SID. 
                
            .PARAMETER SAPApplicationInstanceNumber 
            SAP 'D' Dialog Instance Application Server Instance Number. 

            .EXAMPLE         
           # Set Tags on Standalone HANA belonging to an SAP system
           $ResourceGroupName = "gor-eastus2"
           $VMName = "ts2-di0"
            
           New-AzSAPSystemSAPDialogInstanceApplicationServerWindowsTags  -ResourceGroupName $ResourceGroupName -VMName $VMName -SAPSID "TS1" -SAPApplicationInstanceNumber 1 -PathToSAPControl "S:\usr\sap\TS1\J01\exe\sapcontrol.exe" -AutomationAccountResourceGroupName "rg-autom-account"  -AutomationAccountName "sap-automat-acc" -SAPsidadmUserPassword "MyPass789j$&"    
        #>
    [CmdletBinding()]
    param(                        
        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()]        
        [string]$ResourceGroupName,
              
        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()]        
        [string] $VMName,
        
        [Parameter(Mandatory = $True, HelpMessage = "SAP System <SID>. 3 characters , starts with letter.")] 
        [ValidateLength(3, 3)]
        [string] $SAPSID,
        
        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()]
        [ValidateLength(1, 2)]
        [string] $SAPApplicationInstanceNumber,

        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()]        
        [string] $PathToSAPControl,

        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()]        
        [string]$AutomationAccountResourceGroupName,
              
        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()]        
        [string] $AutomationAccountName,        
        
        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()]        
        [string] $SAPsidadmUserPassword
    )
                
    BEGIN {}
                    
    PROCESS {
        try {                               
                                                         
            $SAPApplicationInstanceType = "SAP_D"            

            # Create VM Tags
            Write-Output "Creating '$SAPApplicationInstanceType' Tags on VM '$VMName' in resource group '$ResourceGroupName' ...."
            $tags = @{"SAPSystemSID" = $SAPSID; "SAPApplicationInstanceType" = $SAPApplicationInstanceType ; "SAPApplicationInstanceNumber" = $SAPApplicationInstanceNumber; "PathToSAPControl" = $PathToSAPControl }
            
            $resource = Get-AzResource -ResourceGroupName $ResourceGroupName -ResourceName $VMName
            #New-AzTag -ResourceId $resource.id -Tag $tags
            Update-AzTag -ResourceId $resource.id -Tag $tags -Operation Merge

            # Create Credetnials in Azure Automation Secure Area 
            $User = $SAPSID.Trim().ToLower() + "adm"
            Write-Output "Creating  credentials in Azure automation account secure area for user '$User' ...."
            New-AzSAPsidadmUserAutomationCredential -AutomationAccountResourceGroupName $AutomationAccountResourceGroupName -AutomationAccountName $AutomationAccountName -SAPSID $SAPSID -SAPsidadmUserPassword $SAPsidadmUserPassword                                  
        }
        catch {
            Write-Error  $_.Exception.Message
        }
                
    }
                
    END {}
}    

function New-AzSAPSystemSAPJavaApplicationServerInstanceWindowsTags {
    <#
            .SYNOPSIS 
            Set Tags on Standalone JavaApplication Server instance on Windows.
                    
            .DESCRIPTION
            Set Tags on Standalone Java Application Server instance on Windows.
                    
            .PARAMETER ResourceGroupName 
            Resource Group Name of the VM.
    
            .PARAMETER VMName 
            VM name. 

            .PARAMETER SAPSID 
            SAP system SID. 
                
            .PARAMETER SAPApplicationInstanceNumber 
            SAP 'J' Java Application Server Instance Number. 

            .EXAMPLE         
           # Set Tags on Standalone HANA belonging to an SAP system
           $ResourceGroupName = "gor-eastus2"
           $VMName = "ts2-di0"

           New-AzSAPSystemSAPJavaApplicationServerInstanceWindowsTags  -ResourceGroupName $ResourceGroupName -VMName $VMName -SAPSID "TS1" -SAPApplicationInstanceNumber 1 -PathToSAPControl "S:\usr\sap\AB1\J01\exe\sapcontrol.exe" -AutomationAccountResourceGroupName "rg-autom-account"  -AutomationAccountName "sap-automat-acc" -SAPsidadmUserPassword "MyPass789j$&"
        #>
    [CmdletBinding()]
    param(                        
        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()]        
        [string]$ResourceGroupName,
              
        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()]        
        [string] $VMName,
        
        [Parameter(Mandatory = $True, HelpMessage = "SAP System <SID>. 3 characters , starts with letter.")] 
        [ValidateLength(3, 3)]
        [string] $SAPSID,
        
        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()]
        [ValidateLength(1, 2)]
        [string] $SAPApplicationInstanceNumber,

        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()]        
        [string] $PathToSAPControl,

        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()]        
        [string]$AutomationAccountResourceGroupName,
              
        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()]        
        [string] $AutomationAccountName,        
        
        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()]        
        [string] $SAPsidadmUserPassword
    )
                
    BEGIN {}
                    
    PROCESS {
        try {                               
                                                         
            $SAPApplicationInstanceType = "SAP_J"            

            # Create VM Tags
            Write-Output "Creating '$SAPApplicationInstanceType' Tags on VM '$VMName' in resource group '$ResourceGroupName' ...."
            $tags = @{"SAPSystemSID" = $SAPSID; "SAPApplicationInstanceType" = $SAPApplicationInstanceType ; "SAPApplicationInstanceNumber" = $SAPApplicationInstanceNumber; "PathToSAPControl" = $PathToSAPControl }
            
            $resource = Get-AzResource -ResourceGroupName $ResourceGroupName -ResourceName $VMName
            #New-AzTag -ResourceId $resource.id -Tag $tags
            Update-AzTag -ResourceId $resource.id -Tag $tags -Operation Merge

            # Create Credetnials in Azure Automation Secure Area 
            $User = $SAPSID.Trim().ToLower() + "adm"
            Write-Output "Creating  credentials in Azure automation account secure area for user '$User' ...."
            New-AzSAPsidadmUserAutomationCredential -AutomationAccountResourceGroupName $AutomationAccountResourceGroupName -AutomationAccountName $AutomationAccountName -SAPSID $SAPSID -SAPsidadmUserPassword $SAPsidadmUserPassword                                  
        }
        catch {
            Write-Error  $_.Exception.Message
        }
                
    }
                
    END {}
}    

function New-AzSAPStandaloneSQLServerTags {
    <#
            .SYNOPSIS 
            Set Tags on Standalone SAP SQL Server.
                    
            .DESCRIPTION
            Set Tags on Standalone SAP SQL Server in distributed SAP installation.
                    
            .PARAMETER ResourceGroupName 
            Resource Group Name of the VM.
    
            .PARAMETER VMName 
            VM name. 

            .PARAMETER SAPSID, 
            SAPSID. 

            .PARAMETER DBInstanceName 
            SQL Server DB Instance Name. Empty string is deafult SQL Server instance. 
                
            .EXAMPLE         
           # Set Tags on Standalone HANA belonging to an SAP system
           $ResourceGroupName = "gor-linux-eastus2"
           $VMName = "ts2-db"

           New-AzSAPStandaloneSQLServerTags -ResourceGroupName $ResourceGroupName -VMName $VMName -SAPSID "TS1" -DBInstanceName $DBInstanceName 
        #>
    [CmdletBinding()]
    param(                        
        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()]        
        [string] $ResourceGroupName,
              
        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()]        
        [string] $VMName,
            
        [Parameter(Mandatory=$True, HelpMessage="SAP System <SID>. 3 characters , starts with letter.")] 
        [ValidateLength(3,3)]
        [string] $SAPSID,

        [Parameter(Mandatory=$false, HelpMessage="SQL Server DB Instance Name. Empty string is deafult SQL instance name.")] 
        [string] $DBInstanceName = ""
    )
                
    BEGIN {}
                    
    PROCESS {
        try {                                                                               
            $SAPDBMSType = "SQLServer"
            
            $tags = @{"SAPSystemSID" = $SAPSID; "DBInstanceName" = $DBInstanceName; "SAPDBMSType" = $SAPDBMSType; }
            
            $resource = Get-AzResource -ResourceGroupName $ResourceGroupName -ResourceName $VMName
            #New-AzTag -ResourceId $resource.id -Tag $tags            
            Update-AzTag -ResourceId $resource.id -Tag $tags -Operation Merge
        }
        catch {
            Write-Error  $_.Exception.Message
        }
                
    }
                
    END {}
}    

function New-AzSAPCentralSystemSQLServerTags {
    <#
            .SYNOPSIS 
            Set Tags on Standalone SAP 'ASCS' instance on Windows.
                    
            .DESCRIPTION
            Set Tags on Standalone SAP 'ASCS' instance on Windows.
                    
            .PARAMETER ResourceGroupName 
            Resource Group Name of the VM.
    
            .PARAMETER VMName 
            VM name. 

            .PARAMETER SAPSID 
            SAP system SID. 
                
            .PARAMETER SAPApplicationInstanceNumber 
            SAP ASCS Instance Number. 

            .PARAMETER DBInstanceName 
            SQL Server DB Instance Name. Empty string is deafult SQL Server instance. 

            .EXAMPLE         
           # Set Tags on Standalone HANA belonging to an SAP system
           $ResourceGroupName = "gor-linux-eastus2"
           $VMName = "ts2-db"

           New-AzSAPCentralSystemSQLServerTags -ResourceGroupName $ResourceGroupName -VMName $VMName -SAPSID "TS1" -SAPApplicationInstanceNumber 1  -DBInstanceName TS1   
        #>
    [CmdletBinding()]
    param(                        
        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()]        
        [string]$ResourceGroupName,
              
        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()]        
        [string] $VMName,
        
        [Parameter(Mandatory = $True, HelpMessage = "SAP System <SID>. 3 characters , starts with letter.")] 
        [ValidateLength(3, 3)]
        [string] $SAPSID,
        
        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()]
        [ValidateLength(1, 2)]   
        [string] $SAPApplicationInstanceNumber,

        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()]        
        [string] $PathToSAPControl,

        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()]        
        [string]$AutomationAccountResourceGroupName,

        [Parameter(Mandatory=$false, HelpMessage="SQL Server DB Instance Name. Empty string is deafult SQL instance name.")] 
        [string] $DBInstanceName = "",
              
        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()]        
        [string] $AutomationAccountName,        
        
        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()]        
        [string] $SAPsidadmUserPassword
    )
                
    BEGIN {}
                    
    PROCESS {
        try {                               
                                                         
            $SAPApplicationInstanceType = "SAP_ASCS"      
            $SAPDBMSType = "SQLServer"                     

            # Create VM Tags
            Write-Output "Creating '$SAPApplicationInstanceType' Tags on VM '$VMName' in resource group '$ResourceGroupName' ...."
            $tags = @{"SAPSystemSID" = $SAPSID; "SAPApplicationInstanceType" = $SAPApplicationInstanceType ; "SAPApplicationInstanceNumber" = $SAPApplicationInstanceNumber; "PathToSAPControl" = $PathToSAPControl ; "DBInstanceName" = $DBInstanceName; "SAPDBMSType" = $SAPDBMSType; }
            
            $resource = Get-AzResource -ResourceGroupName $ResourceGroupName -ResourceName $VMName

            #New-AzTag -ResourceId $resource.id -Tag $tags            
            Update-AzTag -ResourceId $resource.id -Tag $tags -Operation Merge

            # Create Credetnials in Azure Automation Secure Area 
            $User = $SAPSID.Trim().ToLower() + "adm"
            Write-Output "Creating  credentials in Azure automation account secure area for user '$User' ...."
            New-AzSAPsidadmUserAutomationCredential -AutomationAccountResourceGroupName $AutomationAccountResourceGroupName -AutomationAccountName $AutomationAccountName -SAPSID $SAPSID -SAPsidadmUserPassword $SAPsidadmUserPassword                                  
        }
        catch {
            Write-Error  $_.Exception.Message
        }
                
    }
                
    END {}
}    


function Get-AzAutomationSAPPSCredential {
    <#
            .SYNOPSIS 
            Get Azure Automation Account credential user name and password.
                    
            .DESCRIPTION
            Get Azure Automation Account credential user name and password.
                    
            .PARAMETER CredentialName 
            Credential Name.
    
            .EXAMPLE                
           Get-AzAutomationSAPPSCredential -CredentialName "pr1adm"  
        #>
    [CmdletBinding()]
    param(                        
        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()]        
        [string] $CredentialName
      
    )
                
    BEGIN {}
                    
    PROCESS {
        try {                               
                                                         
            $myCredential = Get-AutomationPSCredential -Name $CredentialName
            $userName = $myCredential.UserName
            $securePassword = $myCredential.Password
            $password = $myCredential.GetNetworkCredential().Password

            write-output "user name: $userName"
            write-output "password : $password"

            $obj = New-Object -TypeName psobject
            

            $obj | add-member  -NotePropertyName "UserName" -NotePropertyValue $userName 
            $obj | add-member  -NotePropertyName "Password" -NotePropertyValue $password
            
            Write-Output $obj
        }
        catch {
            Write-Error  $_.Exception.Message
        }
                
    }
                
    END {}
}    

function Stop-AzSAPApplicationServerLinux {
    <#
        .SYNOPSIS 
        Stop SAP Application server on Linux.
                    
        .DESCRIPTION
        Stop SAP Application server on Linux.
                    
        .PARAMETER ResourceGroupName 
        Resource Group Name of the SAP instance VM.        

        .PARAMETER VMName 
        VM name where SAP instance is installed.             

        .PARAMETER SAPInstanceNumber 
        SAP Instance Number to Connect    

        .PARAMETER SAPSID 
        SAP SID  

        .PARAMETER SoftShutdownTimeInSeconds
        Soft shutdown time for SAP system to stop.

        .EXAMPLE                
        Stop-AzSAPApplicationServerLinux -ResourceGroupName "myRG" -VMName SAPApServerVM -SAPInstanceNumber 0 -SAPSID "TS2" -SoftShutdownTimeInSeconds 180
    #>

    [CmdletBinding()]
    param(
        
        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()] 
        [string] $ResourceGroupName,

        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()] 
        [string] $VMName,        

        [Parameter(Mandatory = $True)]
        [ValidateRange(0, 99)]
        [ValidateLength(1, 2)]
        [string] $SAPInstanceNumber,

        [Parameter(Mandatory = $True, HelpMessage = "SAP System <SID>. 3 characters , starts with letter.")] 
        [ValidateLength(3, 3)]
        [string] $SAPSID,

        [Parameter(Mandatory = $False)] 
        [int] $SoftShutdownTimeInSeconds = "300",

        [Parameter(Mandatory = $False)] 
        [bool] $PrintExecutionCommand = $False
    )

    BEGIN {}
    
    PROCESS {
        try {   
            $SAPSidUser = $SAPSID.ToLower() + "adm"            

            # Stop SAP ABAP Application Server
            Write-WithTime "Stopping SAP SID '$SAPSID' ABAP application server with instance number '$SAPInstanceNumber' on VM '$VMName' , with application time out $SoftShutdownTimeInSeconds seconds ..."

            $Command = "su --login $SAPSidUser -c 'sapcontrol -nr $SAPInstanceNumber -function Stop $SoftShutdownTimeInSeconds $SoftShutdownTimeInSeconds'"
            
            if ($PrintExecutionCommand -eq $True) {
                Write-Output "Executing command '$Command' "
            }

            $Command | Out-File "command.txt"

            $ret = Invoke-AzVMRunCommand -ResourceGroupName $ResourceGroupName -VMName $VMName  -CommandId RunShellScript  -ScriptPath command.txt

            $ret.Value[0].Message

            [int] $SleepTime = $SoftShutdownTimeInSeconds + 60

            Write-WithTime "Waiting  $SoftShutdownTimeInSeconds seconds for SAP application server with SAP SID '$SAPSID' and instance number '$SAPInstanceNumber' to stop  ..."
            Start-Sleep $SleepTime

            Write-WithTime "SAP Application server with SAP SID '$SAPSID' and instance number '$SAPInstanceNumber' on VM '$VMName' and Azure resource group '$ResourceGroupName' stopped."
        }
        catch {
            Write-Error  $_.Exception.Message
        }

    }

    END {}
}

function Stop-AzSAPApplicationServerWindows {
    <#
        .SYNOPSIS 
        Stop SAP Application server on Linux.
                    
        .DESCRIPTION
        Stop SAP Application server on Linux.
                    
        .PARAMETER ResourceGroupName 
        Resource Group Name of the SAP instance VM.        

        .PARAMETER VMName 
        VM name where SAP instance is installed.             

        .PARAMETER SAPInstanceNumber 
        SAP Instance Number to Connect    

        .PARAMETER SAPSID 
        SAP SID  

        .PARAMETER SoftShutdownTimeInSeconds
        Soft shutdown time for SAP system to stop.

        .EXAMPLE                
        Stop-AzSAPApplicationServerLinux -ResourceGroupName "myRG" -VMName SAPApServerVM -SAPSID "TS2"  -SAPInstanceNumber 0  -PathToSAPControl "C:\usr\sap\PR2\D00\exe\sapcontrol.exe" -SAPSidPwd "Mypwd36" -SoftShutdownTimeInSeconds 180
    #>

    [CmdletBinding()]
    param(
        
        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()] 
        [string] $ResourceGroupName,

        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()] 
        [string] $VMName,        

        [Parameter(Mandatory = $True, HelpMessage = "SAP System <SID>. 3 characters , starts with letter.")] 
        [ValidateLength(3, 3)]
        [string] $SAPSID,

        [Parameter(Mandatory = $True)]
        [ValidateLength(1, 2)] 
        [string] $SAPInstanceNumber,

        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()] 
        [string] $SAPSidPwd,    

        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()] 
        [string] $PathToSAPControl,

        [Parameter(Mandatory = $False)] 
        [int] $SoftShutdownTimeInSeconds = "300",

        [Parameter(Mandatory = $False)] 
        [bool] $PrintExecutionCommand = $False
    )

    BEGIN {}
    
    PROCESS {
        try {   
            $SAPSidUser = $SAPSID.ToLower() + "adm"            

            # Stop SAP ABAP Application Server
            Write-WithTime "Stopping SAP SID '$SAPSID' ABAP application server with instance number '$SAPInstanceNumber' on VM '$VMName' , with application time out $SoftShutdownTimeInSeconds seconds ..."
            
            $Command       = "$PathToSAPControl -nr $SAPInstanceNumber -user $SAPSidUser $SAPSidPwd -function Stop $SoftShutdownTimeInSeconds $SoftShutdownTimeInSeconds"
            $CommandToPrint = "$PathToSAPControl -nr $SAPInstanceNumber -user $SAPSidUser '***pwd****' -function Stop $SoftShutdownTimeInSeconds $SoftShutdownTimeInSeconds"

            if ($PrintExecutionCommand -eq $True) {
                Write-Output "Executing command '$CommandToPrint' "
            }

            $Command | Out-File "command.txt"

            $ret = Invoke-AzVMRunCommand -ResourceGroupName $ResourceGroupName -VMName $VMName  -CommandId RunPowerShellScript -ScriptPath command.txt

            $ret.Value[0].Message

            [int] $SleepTime = $SoftShutdownTimeInSeconds + 60

            Write-WithTime "Waiting  $SoftShutdownTimeInSeconds seconds for SAP application server with SAP SID '$SAPSID' and instance number '$SAPInstanceNumber' to stop  ..."
            Start-Sleep $SleepTime

            Write-WithTime "SAP Application server with SAP SID '$SAPSID' and instance number '$SAPInstanceNumber' on VM '$VMName' and Azure resource group '$ResourceGroupName' stopped."
        }
        catch {
            Write-Error  $_.Exception.Message
        }

    }

    END {}
}


function Start-AzSAPApplicationServerLinux {
    <#
        .SYNOPSIS 
        Start SAP Application server on Linux.
                    
        .DESCRIPTION
        Start SAP Application server on Linux.
                    
        .PARAMETER ResourceGroupName 
        Resource Group Name of the SAP instance VM.        

        .PARAMETER VMName 
        VM name where SAP instance is installed.             

        .PARAMETER SAPInstanceNumber 
        SAP Instance Number to Connect    

        .PARAMETER SAPSID 
        SAP SID  

        .PARAMETER WaitTime
        WaitTime for SAP application server to start.

        .EXAMPLE                
        Start-AzSAPApplicationServerLinux -ResourceGroupName "myRG" -VMName SAPApServerVM -SAPInstanceNumber 0 -SAPSID "TS2" -WaitTime 180
    #>

    [CmdletBinding()]
    param(
        
        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()] 
        [string] $VMName,

        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()] 
        [string] $ResourceGroupName,

        [Parameter(Mandatory = $True)]
        [ValidateLength(1, 2)]        
        [string] $SAPInstanceNumber,

        [Parameter(Mandatory = $True, HelpMessage = "SAP System <SID>. 3 characters , starts with letter.")] 
        [ValidateLength(3, 3)]
        [string] $SAPSID,

        [Parameter(Mandatory = $False)] 
        [int] $WaitTime = "300",

        [Parameter(Mandatory = $False)] 
        [bool] $PrintExecutionCommand = $False
    )

    BEGIN {}
    
    PROCESS {
        try {   
            $SAPSidUser = $SAPSID.ToLower() + "adm"            

            # Stop SAP ABAP Application Server
            Write-WithTime "Starting SAP SID '$SAPSID' ABAP application server with instance number '$SAPInstanceNumber' on VM '$VMName' , with wait time $WaitTime seconds ..."

            $Command = "su --login $SAPSidUser -c 'sapcontrol -nr $SAPInstanceNumber -function Start'"            
            
            if ($PrintExecutionCommand -eq $True) {
                Write-Output "Executing command '$Command' "
            }

            $Command | Out-File "command.txt"

            $ret = Invoke-AzVMRunCommand -ResourceGroupName $ResourceGroupName -VMName $VMName  -CommandId RunShellScript  -ScriptPath command.txt

            $ret.Value[0].Message            
            
            Write-WithTime "Waiting $WaitTime seconds for SAP application server with SAP SID '$SAPSID' and instance number '$SAPInstanceNumber' to start  ..."

            Start-Sleep $WaitTime

            Write-WithTime "SAP Application server with SAP SID '$SAPSID' and instance number '$SAPInstanceNumber' on VM '$VMName' and Azure resource group '$ResourceGroupName' started."
        }
        catch {
            Write-Error  $_.Exception.Message
        }

    }

    END {}
}


function Start-AzSAPApplicationServerWindows {
   <#
        .SYNOPSIS 
        Start SAP Application server on Windows.
                    
        .DESCRIPTION
        Start SAP Application server on  Windows.
                    
        .PARAMETER ResourceGroupName 
        Resource Group Name of the SAP instance VM.        

        .PARAMETER VMName 
        VM name where SAP instance is installed.   
        
        .PARAMETER SAPSID 
        SAP SID 

        .PARAMETER SAPInstanceNumber 
        SAP Instance Number to Connect    

        .PARAMETER SAPSidPwd 
        SAP <sid>adm user password

        .PARAMETER PathToSAPControl 
        Full path to SAP Control executable.        

        .PARAMETER SoftShutdownTimeInSeconds
        Soft shutdown time for SAP system to stop.

        .EXAMPLE                
        Start-AzSAPApplicationServerWindows -ResourceGroupName "myRG" -VMName SAPApServerVM -SAPSID "TS2" -SAPInstanceNumber 0  -PathToSAPControl "C:\usr\sap\PR2\D00\exe\sapcontrol.exe" -SAPSidPwd "Mypwd36" -SoftShutdownTimeInSeconds 180
    #>

    [CmdletBinding()]
    param(
        
        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()] 
        [string] $VMName,

        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()] 
        [string] $ResourceGroupName,

        [Parameter(Mandatory = $True, HelpMessage = "SAP System <SID>. 3 characters , starts with letter.")] 
        [ValidateLength(3, 3)]
        [string] $SAPSID,

        [Parameter(Mandatory = $True)]
        [ValidateLength(1, 2)] 
        [string] $SAPInstanceNumber,        

        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()] 
        [string] $SAPSidPwd,    

        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()] 
        [string] $PathToSAPControl,

        [Parameter(Mandatory = $False)] 
        [int] $WaitTime = "300",

        [Parameter(Mandatory = $False)] 
        [bool] $PrintExecutionCommand = $False
    ) 

    BEGIN {}
    
    PROCESS {
        try {   
            $SAPSidUser = $SAPSID.ToLower() + "adm"            

            # Start SAP ABAP Application Server
            Write-WithTime "Starting SAP SID '$SAPSID' ABAP application server with instance number '$SAPInstanceNumber' on VM '$VMName' , with wait time $WaitTime seconds ..."
            
            $Command        = "$PathToSAPControl -nr $SAPInstanceNumber -user $SAPSidUser $SAPSidPwd -function Start"
            $CommandToPrint = "$PathToSAPControl -nr $SAPInstanceNumber -user $SAPSidUser '***pwd***' -function Start"
            
            if ($PrintExecutionCommand -eq $True) {
                Write-Output "Executing command '$CommandToPrint' "
            }

            $Command | Out-File "command.txt"

            $ret = Invoke-AzVMRunCommand -ResourceGroupName $ResourceGroupName -VMName $VMName  -CommandId RunPowerShellScript -ScriptPath command.txt

            $ret.Value[0].Message            
            
            Write-WithTime "Waiting $WaitTime seconds for SAP application server with SAP SID '$SAPSID' and instance number '$SAPInstanceNumber' to start  ..."

            Start-Sleep $WaitTime

            Write-WithTime "SAP Application server with SAP SID '$SAPSID' and instance number '$SAPInstanceNumber' on VM '$VMName' and Azure resource group '$ResourceGroupName' started."
        }
        catch {
            Write-Error  $_.Exception.Message
        }

    }

    END {}
}

function Start-AzSAPApplicationServer {
    <#
    .SYNOPSIS 
    Start SAP application server running on VM.
    
    .DESCRIPTION
    Start SAP application server running on VM.
    
    .PARAMETER ResourceGroupName 
    Azure Resource Group Name    

    .PARAMETER ResourceGroupName 
    Azure VM  Name

    .PARAMETER WaitTime
    Number of seconds to wait for SAP system to start.

    .PARAMETER PrintExecutionCommand 
    If set to $True it will pring the run command. 

    .EXAMPLE     
    Start-AzSAPApplicationServer -ResourceGroupName  "AzResourceGroup"  -VMName "VMname" -WaitTime 60
 #>

    [CmdletBinding()]
    param(       
        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()] 
        [string] $ResourceGroupName,

        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()] 
        [string] $VMName,
        
        [Parameter(Mandatory = $False)] 
        [int] $WaitTime = "300",

        [Parameter(Mandatory = $False)] 
        [bool] $PrintExecutionCommand = $False        
    )

    BEGIN {}
    
    PROCESS {
        try {   
            # get SAP server datza from VM Tags            
            $SAPApplicationServerData = Get-AzSAPApplicationInstanceData -ResourceGroupName $ResourceGroupName -VMName $VMName  

            #Write-Output $SAPApplicationServerData

            if ($SAPApplicationServerData.OSType -eq "Linux") {                  
                Start-AzSAPApplicationServerLinux  -ResourceGroupName $ResourceGroupName -VMName $VMName -SAPInstanceNumber $SAPApplicationServerData.SAPApplicationInstanceNumber -SAPSID $SAPApplicationServerData.SAPSID -WaitTime $WaitTime -PrintExecutionCommand $PrintExecutionCommand                            
            }
            elseif ($SAPAPPLicationServerData.OSType -eq "Windows") {                
                Start-AzSAPApplicationServerWindows  -ResourceGroupName $ResourceGroupName -VMName $VMName -SAPSID $SAPApplicationServerData.SAPSID -SAPInstanceNumber $SAPApplicationServerData.SAPApplicationInstanceNumber  -PathToSAPControl $SAPApplicationServerData.PathToSAPControl -SAPSidPwd  $SAPApplicationServerData.SAPSIDPassword -WaitTime $WaitTime -PrintExecutionCommand $PrintExecutionCommand
            }           
        }
        catch {
            Write-Error  $_.Exception.Message
        }
    }

    END {}
}

function Stop-AzSAPApplicationServer {
    <#
    .SYNOPSIS 
    Start SAP application server running on VM.
    
    .DESCRIPTION
    Start SAP application server running on VM.
    
    .PARAMETER ResourceGroupName 
    Azure Resource Group Name    

    .PARAMETER ResourceGroupName 
    Azure VM  Name

    .PARAMETER SoftShutdownTimeInSeconds
    Soft shutdown time for SAP system to stop.

    .PARAMETER PrintExecutionCommand 
    If set to $True it will pring the run command. 

    .EXAMPLE     
    Start-AzSAPApplicationServer -ResourceGroupName  "AzResourceGroup"  -VMName "VMname" -WaitTime 60
 #>

    [CmdletBinding()]
    param(       
        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()] 
        [string] $ResourceGroupName,

        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()] 
        [string] $VMName,
        
        [Parameter(Mandatory = $False)] 
        [int] $SoftShutdownTimeInSeconds = "300",

        [Parameter(Mandatory = $False)] 
        [bool] $PrintExecutionCommand = $False        
    )

    BEGIN {}
    
    PROCESS {
        try {   
            # get SAP server data from VM Tags            
            $SAPApplicationServerData = Get-AzSAPApplicationInstanceData -ResourceGroupName $ResourceGroupName -VMName $VMName  

            #Write-Output $SAPApplicationServerData

            if ($SAPApplicationServerData.OSType -eq "Linux") {                  
                Stop-AzSAPApplicationServerLinux  -ResourceGroupName $ResourceGroupName -VMName $VMName -SAPInstanceNumber $SAPApplicationServerData.SAPApplicationInstanceNumber -SAPSID $SAPApplicationServerData.SAPSID -SoftShutdownTimeInSeconds $SoftShutdownTimeInSeconds -PrintExecutionCommand $PrintExecutionCommand                            
            }
            elseif ($SAPAPPLicationServerData.OSType -eq "Windows") {                
                Stop-AzSAPApplicationServerWindows  -ResourceGroupName $ResourceGroupName -VMName $VMName -SAPSID $SAPApplicationServerData.SAPSID -SAPInstanceNumber $SAPApplicationServerData.SAPApplicationInstanceNumber  -PathToSAPControl $SAPApplicationServerData.PathToSAPControl -SAPSidPwd  $SAPApplicationServerData.SAPSIDPassword -SoftShutdownTimeInSeconds $SoftShutdownTimeInSeconds -PrintExecutionCommand $PrintExecutionCommand
            }           
        }
        catch {
            Write-Error  $_.Exception.Message
        }
    }

    END {}
}


function Confirm-AzResoureceGroupExist {
   <#
    .SYNOPSIS 
    Check if Azure resource Group exists.
    
    .DESCRIPTION
    Check if Azure resource Group exists.
    
    .PARAMETER ResourceGroupName 
    Azure Resource Group Name        

    .EXAMPLE     
    Confirm-AzResoureceGroupExist -ResourceGroupName  "AzResourceGroupName" 
 #>

    [CmdletBinding()]
    param(
        
        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()]        
        [string] $ResourceGroupName                      
        
    )

    BEGIN {}
    
    PROCESS {
        try {               
            $RG = Get-AzResourceGroup -Name $ResourceGroupName -ErrorVariable -notPresent  -ErrorAction SilentlyContinue

            if ($RG -eq $null) {                
                Write-Error "Azure resource group '$ResourceGroupName' do not exists. Check your input parameter 'RESOURCEGROUPNAME'."   
                exit             
            }
            else {
                Write-WithTime "Azure resource group '$ResourceGroupName' exist."
            }
        }
        catch {
           
            Write-Error  $_.Exception.Message
        }

    }

    END {}
}

function Confirm-AzVMExist {
<#
    .SYNOPSIS 
    Check if Azure VM exists.
    
    .DESCRIPTION
    Check if Azure VM exists.
    
    .PARAMETER ResourceGroupName 
    Azure Resource Group Name        

    .PARAMETER VMName 
    Azure VM Name

    .EXAMPLE     
    Confirm-AzVMExist -ResourceGroupName  "AzResourceGroupName"  -VMName "MyVMName"
 #>
    [CmdletBinding()]
    param(
        
        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()]        
        [string]$ResourceGroupName,

        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()]        
        [string] $VMName                      
        
    )

    BEGIN {}
    
    PROCESS {
        try {               
            $VM = Get-AzVM -ResourceGroupName $ResourceGroupName -Name $VMName  -ErrorVariable -notPresent -ErrorAction SilentlyContinue

            if ($VM -eq $null) {                
                Write-Error "Azure virtual machine '$VMName' in Azure resource group  '$ResourceGroupName' do not exists. Check your input parameter 'VMNAME' and 'RESOURCEGROUPNAME'."   
                exit             
            }
            else {
                Write-WithTime "Azure VM '$VMName' in Azure resource group '$ResourceGroupName' exist."
            }
        }
        catch {           
            Write-Error  $_.Exception.Message
        }

    }

    END {}
}

function Get-AzSAPApplicationInstanceData {
    <#
    .SYNOPSIS 
    Get SAP Application Instance Data from tags from one VM.
    
    .DESCRIPTION
    Get SAP Application Instance Data from tags from one VM.
     
    .PARAMETER ResourceGroupName 
    Resource Group Name of the VM.
    
    .PARAMETER VMName 
    VM name. 
        
    .EXAMPLE     
    # Collect SAP VM instances with the same Tag
    $SAPAPPLicationServerData = Get-AzSAPApplicationInstanceData -ResourceGroupName "AzResourceGroup" -VMName "SAPApplicationServerVMName"    
 #>

    [CmdletBinding()]
    param(        
        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()]        
        [string]$ResourceGroupName,
           
        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()]        
        [string] $VMName
    )

    BEGIN {}
    
    PROCESS {
        try {   
                                  
            $SAPSID = Get-AzVMTagValue -ResourceGroupName $ResourceGroupName -VMName $VMName  -KeyName "SAPSystemSID"  
            if ($SAPSID -eq $null) {
                Throw "Tag 'SAPSystemSID' on VM '$VMName' in Azure resource group $ResourceGroupName not found."
            }            
            #Write-Output "SAPSID = $SAPSID"

            $SAPApplicationInstanceNumber = Get-AzVMTagValue -ResourceGroupName $ResourceGroupName -VMName $VMName  -KeyName "SAPApplicationInstanceNumber"  
            if ($SAPApplicationInstanceNumber -eq $null) {
                Throw "Tag 'SAPApplicationInstanceNumber' on VM '$VMName' in Azure resource group $ResourceGroupName not found."

            }
            #Write-Output "SAPApplicationInstanceNumber = $SAPApplicationInstanceNumber"

            $SAPApplicationInstanceType = Get-AzVMTagValue -ResourceGroupName $ResourceGroupName -VMName $VMName  -KeyName "SAPApplicationInstanceType"  
            if ($SAPApplicationInstanceType -eq $null) {
                Throw "Tag 'SAPApplicationInstanceType' on VM '$VMName' in Azure resource group $ResourceGroupName not found."
            }            
            #Write-Output "SAPApplicationInstanceType = $SAPApplicationInstanceType"

            If (-Not (Test-SAPApplicationInstanceIsApplicationServer $SAPApplicationInstanceType)) {
                Throw "SAP Instance type '$SAPApplicationInstanceType' is not an SAP application server."
            }

            $OSType = Get-AzVMOSType -VMName $VMName -ResourceGroupName $ResourceGroupName

            if ($OSType -eq "Windows") {                                
                $SIDADMUser = $SAPSID.Trim().ToLower() + "adm"
                $SAPSIDCredentials = Get-AzAutomationSAPPSCredential -CredentialName  $SIDADMUser  
                $SAPSIDPassword = $SAPSIDCredentials.Password
                $PathToSAPControl = Get-AzVMTagValue -ResourceGroupName $ResourceGroupName  -VMName $VMName  -KeyName "PathToSAPControl"  
            }

            $obj = New-Object -TypeName psobject

            $obj | add-member  -NotePropertyName "SAPSID"                       -NotePropertyValue $SAPSID  
            $obj | add-member  -NotePropertyName "VMName"                       -NotePropertyValue $VMName  
            $obj | add-member  -NotePropertyName "ResourceGroupName"            -NotePropertyValue $ResourceGroupName  
            $obj | add-member  -NotePropertyName "SAPApplicationInstanceNumber" -NotePropertyValue $SAPApplicationInstanceNumber
            $obj | add-member  -NotePropertyName "SAPInstanceType"              -NotePropertyValue $SAPApplicationInstanceType
            $obj | add-member  -NotePropertyName "OSType"                       -NotePropertyValue $OSType 

            if ($OSType -eq "Windows") {
                $obj | add-member  -NotePropertyName "SAPSIDPassword"           -NotePropertyValue $SAPSIDPassword
                $obj | add-member  -NotePropertyName "PathToSAPControl"         -NotePropertyValue $PathToSAPControl               
            }

            # Return formated object
            Write-Output $obj            
                                
        }
        catch {
            Write-Error  $_.Exception.Message
        }
    }

    END {}
}
function Test-SAPApplicationInstanceIsApplicationServer {
    <#
    .SYNOPSIS 
    If SAP Application Instance is application server['SAP_D','SAP_DVEBMGS','SAP_J'] , retruns $True. Otherwise return $False.
    
    .DESCRIPTION
   If SAP Application Instance is application server['SAP_D','SAP_DVEBMGS','SAP_J'] , retruns $True. Otherwise return $False.
    
    .PARAMETER SAPApplicationInstanceType 
    SAP ApplicationInstance Type ['SAP_D','SAP_DVEBMGS','SAP_J']  
    
    .EXAMPLE     
   Test-SAPApplicationInstanceIsApplicationServer "SAP_D"
    
 #>

    [CmdletBinding()]
    param(        
        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()]        
        [string]$SAPApplicationInstanceType
                
    )

    BEGIN {}
    
    PROCESS {
        try {   
                      
            switch ($SAPApplicationInstanceType) {
                "SAP_D" { return $True }
                "SAP_DVEBMGS" { return $True }
                "SAP_J" { return $True }
                Default { return $False }
            }
            
        }
        catch {
            Write-Error  $_.Exception.Message
        }
    }

    END {}
}

function Stop-AzVMAndPrintStatus {
    <#
    .SYNOPSIS 
    Stop Azure VM and printa status.
    
    .DESCRIPTION
    Stop Azure VM and printa status.
    
    .PARAMETER ResourceGroupName 
    VM Azure Resource Group Name.    
    
    .PARAMETER VMName 
    VM Name.    
    
    .EXAMPLE 
    Stop-AzVMAndPrintStatus -ResourceGroupName "PR1-RG" -VMName "PR1-DB"
 #>

    [CmdletBinding()]
    param(
        
        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()]        
        [string]$ResourceGroupName,
              
        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()]        
        [string] $VMName

        
    )

    BEGIN {}
    
    PROCESS {
        try {   
            
            Write-Output "Stopping VM '$VMName' in Azure Resource Group '$ResourceGroupName' ..."
            Stop-AzVM  -ResourceGroupName $ResourceGroupName -Name $VMName -WarningAction "SilentlyContinue" -Force

            $VM = Get-AzVM -ResourceGroupName $ResourceGroupName -Name $VMName -Status
            $VMStatus = $VM.Statuses[1].DisplayStatus
            Write-Output "Virtual Machine '$VMName' status: $VMStatus" 
        }
        catch {
            Write-Error  $_.Exception.Message
        }

    }
    END {}
}

function Start-AzVMAndPrintStatus {
    <#
    .SYNOPSIS 
    Start Azure VM and printa status.
    
    .DESCRIPTION
    Start Azure VM and printa status.
    
    .PARAMETER ResourceGroupName 
    VM Azure Resource Group Name.    
    
    .PARAMETER VMName 
    VM Name.  
    
    .PARAMETER SleepTimeAfterVMStart 
    Wait time in seconds after VM is started. 
    
    .EXAMPLE 
    # Start VM and wait for 60 seconds [default]
    Start-AzVMAndPrintStatus  -ResourceGroupName "PR1-RG" -VMName "PR1-DB"

    .EXAMPLE 
    # Start VM and do not wait 
    Start-AzVMAndPrintStatus  -ResourceGroupName "PR1-RG" -VMName "PR1-DB" -SleepTimeAfterVMStart 0
 #>

    [CmdletBinding()]
    param(
        
        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()]        
        [string]$ResourceGroupName,
              
        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()]        
        [string] $VMName,

        [Parameter(Mandatory = $false)]             
        [int] $SleepTimeAfterVMStart = 60

        
    )

    BEGIN {}
    
    PROCESS {
        try {   
             # Start VM
             Write-Output "Starting VM '$VMName' in Azure Resource Group '$ResourceGroupName' ..."
             Start-AzVM  -ResourceGroupName $ResourceGroupName -Name $VMName -WarningAction "SilentlyContinue"

             $VM = Get-AzVM -ResourceGroupName $ResourceGroupName -Name $VMName -Status
             $VMStatus = $VM.Statuses[1].DisplayStatus
             #Write-Output ""
             Write-Output "Virtual Machine '$VMName' status: $VMStatus"

            # Wait for $SleepTimeAfterVMStart seconds after VM is started
            Start-Sleep $SleepTimeAfterVMStart
        }
        catch {
            Write-Error  $_.Exception.Message
        }
    }
    END {}
}

########################################

# https://docs.microsoft.com/en-us/azure/load-balancer/quickstart-create-standard-load-balancer-powershell
# https://docs.microsoft.com/en-us/azure/load-balancer/upgrade-basicinternal-standard


Function Move-AzVMToAvailabilitySetAndOrProximityPlacementGroup {
    <#
    .SYNOPSIS
        Moves a VM into an:
    
        - Availability Set
        - Proximity Placement Group
        - Availability Set and Proximity Placement Group
        
    
    .DESCRIPTION
        The script deletes the VM and recreates it preserving networking and storage configuration.        
    
        There is no need to reinstall the operating system.
        
        IMPORTANT: The script does not preserve VM extensions.  
                   Also, the script will not work for VMs with public IP addresses.
                   Zonal VMs are not supported. 
                   VM, Availabity Set and Proximity Placement Group must be members of the same Azure resource group.
            
        IMPORTANT: SAP context
    
        You can use the script to:
    
        - Move SAP Application Servers to new Availability Set 
    
        - Move SAP Application Servers to new Availability Set and Proximity Placement Group:
    
            - It can be used in Azure Zones context, where you move SAP Application Server to Zone.
              One group of SAP Application Servers are indirectly part of Zone1 (via AvSet1 and PPGZone1), and other part of  SAP Application Servers are indirectly part of Zone2 (via AvSet2 and PPGZone2).
              First ancor VM (this is DBMS VM) is alreday deplyed in a Zone and same Proximity Placement Group
    
            - It can be used to move an SAP Application Server from current AvSet1 and PPGZone1 to AvSet2 and PPGZone2, e.g. indirectly from Zone1 to Zone2.
              First ancor VM (this is DBMS VM) is alreday deplyed in a Zone2 and same Proximity Placement Group 2 (PPGZone2).
    
            - It can be used in non-Zonal context, where group of SAP Application Servers are part of new Av Set and Proximity Placement Group, together with the SAP ASCS and DB VM that are part of one SAP SID.
    
        - Group all VMs to Proximity Placement Group
    
    .PARAMETER ResourceGroupName 
    Resource Group Name of the VM.
        
    .PARAMETER VirtualMachineName 
    Virtual Machine Name. 
    
    .PARAMETER AvailabilitySetName
    Availability Set Name.
    
    .PARAMETER ProximityPlacementGroupName
    ProximityPlacementGroupName
    
    .PARAMETER DoNotCopyTags
    Switch paramater. If specified, VM tags will NOT be copied.

    .PARAMETER NewVMSize
    If NewVMSize is specified , VM will be set to a new VM size. Otherwise, original VM size will be used. 
        
    .EXAMPLE
        # THis is example that can be used for moving (indirectly via PPG) SAP Application Servers to a desired Azure zone
        # Move VM 'VM1' to Azure Availability Set  and Proximity Placement GroupName (PPG)
        # Proximity Placement Group must alreday exist
        # Availability Set must exist and be associated to Proximity Placement Group
        # VM tags will not be copied : swicth parameter -DoNotCopyTags is set
        
        # If Av Set doesn't exist, you can create it like this:
        $Location = "eastus"
        $AzureAvailabilitySetName = "TargetAvSetZone1"
        $ResourceGroupName = "gor-Zone-Migration"
        $ProximityPlacementGroupName = "PPGZone1"
        $PlatformFaultDomainCount = 3
        $PlatformUpdateDomainCount = 2
    
        $PPG = Get-AzProximityPlacementGroup -ResourceGroupName $ResourceGroup -Name $ProximityPlacementGroupName
        New-AzAvailabilitySet -Location $Location -Name $AzureAvailabilitySetName -ResourceGroupName $ResourceGroupName -PlatformFaultDomainCount $PlatformFaultDomainCount -PlatformUpdateDomainCount $PlatformUpdateDomainCount -ProximityPlacementGroupId $PPG.Id  -Sku Aligned
    
        # Move VM
        Move-AzVMToAvailabilitySetAndOrProximityPlacementGroup -ResourceGroupName "gor-Zone-Migration" -VirtualMachineName "VM1" -AvailabilitySetName "TargetAvSetZone1" -ProximityPlacementGroupName "PPGZone1" -DoNotCopyTags
    
    
    .EXAMPLE
        # Move VM to Proximity Placement Group
        # Proximity Placement Group must alreday exist
        # VM will be set to NEW VM size, e.g. not original VM size , because 'NewVMSize' is specified
        Move-AzVMToAvailabilitySetAndOrProximityPlacementGroup -ResourceGroupName "gor-Zone-Migration" -VirtualMachineName "VM1" -ProximityPlacementGroupName "PPGZone1" -NewVMSize "Standard_E4s_v3"
 
    
    
    .EXAMPLE
        # Move VM to Azure Availability Set 
        # If Av Set doesn't exist, you can create it like this:
    
        $Location = "eastus"
        $AzureAvailabilitySetName = "TargetAvSetWithoutZone"
        $ResourceGroupName = "gor-Zone-Migration"    
        $PlatformFaultDomainCount = 3
        $PlatformUpdateDomainCount = 2
        
        New-AzAvailabilitySet -Location $Location -Name $AzureAvailabilitySetName -ResourceGroupName $ResourceGroupName -PlatformFaultDomainCount $PlatformFaultDomainCount -PlatformUpdateDomainCount $PlatformUpdateDomainCount -Sku Aligned
    
        Move-AzVMToAvailabilitySetAndOrProximityPlacementGroup -ResourceGroupName "gor-Zone-Migration" -VirtualMachineName "VM1" -AvailabilitySetName "TargetAvSetWithoutZone"
    
    .LINK
        
    
    .NOTES
        v0.1 - Initial version
    
    #>
    
    #Requires -Modules Az.Compute
    #Requires -Version 5.1
    
    
        [CmdletBinding()]
        param(
            
            [Parameter(Mandatory=$True)]
            [ValidateNotNullOrEmpty()]        
            [string] $ResourceGroupName,
                  
            [Parameter(Mandatory=$True)]
            [ValidateNotNullOrEmpty()]        
            [string] $VirtualMachineName,
    
            [Parameter(Mandatory=$False)]
            [string] $AvailabilitySetName,
    
            [Parameter(Mandatory=$False)]
            [string] $ProximityPlacementGroupName,
    
            [switch] $DoNotCopyTags,

            [Parameter(Mandatory=$False)]
            [string] $NewVMSize
        )
    
        BEGIN{
            $AvailabilitySetExist = $False
            $ProximityPlacementGroupExist = $False    
        }
        
        PROCESS{
            try{   
               
               # Zonal VM are not supported - cannot move zonal disks to non Zonal
               $IsVMZonal = Test-AzVMIsZonalVM -ResourceGroupName $ResourceGroupName -VirtualMachineName $VirtualMachineName
               if($IsVMZonal){
                    Throw "Azure Virtual Machine '$VirtualMachineName' is zonal VM. Migration of zonal VM to non-Zonal VM is not supported!"
               }
               
               Write-WithTime  "Starting Virtual Machine '$VirtualMachineName' ..."
               Start-AzVM -ResourceGroupName $ResourceGroupName -Name $VirtualMachineName -ErrorAction Stop 
               
               # Get the VM and check existance
               $originalVM = Get-AzVM -ResourceGroupName $ResourceGroupName -Name $VirtualMachineName -ErrorAction Stop                        
    
               if(($AvailabilitySetName -eq "") -and ($ProximityPlacementGroupName -eq "")){
                Write-Error "Availability Set Name and Proximity Placement Group Name are not specified. You need to specify at least one of the parameters." 
                return
               }
    
               # Proximity Placement Group must exist
               if ($ProximityPlacementGroupName -ne ""){           
                    $ppg = Get-AzProximityPlacementGroup -ResourceGroupName $ResourceGroupName -Name $ProximityPlacementGroupName -ErrorAction Stop
    
                    $ProximityPlacementGroupExist = $True
    
                    Write-Host
                    Write-WithTime "Proximity Placement Group '$ProximityPlacementGroupName' exist."
               }else{
                    Write-Host
                    Write-WithTime "Proximity Placement Group is not specified."
               }
    
               #Availabity Set Must exist
               if ($AvailabilitySetName -ne ""){           
                    $AvailabilitySet = Get-AzAvailabilitySet -ResourceGroupName $ResourceGroupName -Name $AvailabilitySetName -ErrorAction Stop
                    $AvailabilitySetExist = $True    
                    
                    Write-Host
                    Write-WithTime "Availability Set '$AvailabilitySetName' exist."           
    
                    # Check if Av Set is in the proper PPG
                    if($ProximityPlacementGroupExist){
                        if($AvailabilitySet.ProximityPlacementGroup.id -ne $ppg.Id){                    
                            Throw "Existing Availability Set '$AvailabilitySetName' is not member of Proximity Placement Group '$ProximityPlacementGroupName'. "                    
                        }
                        Write-Host
                        Write-WithTime "Availability Set '$AvailabilitySetName' is configured in appropriate Proximity Placement Group '$ProximityPlacementGroupName'."
                    }
               }else{
                    Write-Host
                    Write-WithTime "Availability Set is not specified."
               }                            
    
               # We don't support moving machines with public IPs, since those are zone specific.  
               foreach ($nic in $originalVM.NetworkProfile.NetworkInterfaces) {
                     $thenic = $nic.id
                     $nicname = $thenic.substring($thenic.LastIndexOf("/")+1)
                     $othernic = Get-AzNetworkInterface -name $nicname -ResourceGroupName $ResourceGroupName 
            
                     foreach ($ipc in $othernic.IpConfigurations) {
                         $pip = $ipc.PublicIpAddress
                         if ($pip) { 
                             Throw  "Sorry, machines with public IPs are not supported by this script"                             
                         }
                     }
               }
             
               [string] $osType      = $originalVM.StorageProfile.OsDisk.OsType
               [string] $location    = $originalVM.Location
               [string] $storageType = $originalVM.StorageProfile.OsDisk.ManagedDisk.StorageAccountType
               [string] $OSDiskName  = $originalVM.StorageProfile.OsDisk.Name

               if($NewVMSize -eq ""){
                    # if $NewVMSIze is not specified, use the orgonal VM size
                    $VMSize = $originalVM.HardwareProfile.VmSize
                }
                else{
                    # if $NewVMSIze is  specified, use it as VM size
                    $VMSize = $NewVMSize
                }
        
               # Shutdown the original VM
               Write-Host
               Write-WithTime  "Stopping Virtual Machine '$VirtualMachineName' ..."
               Stop-AzVM -ResourceGroupName $ResourceGroupName -Name $VirtualMachineName -force -ErrorAction Stop
               
               # Export original VM configuration
               Write-Host
               Export-VMConfigurationToJSONFile -VM  $originalVM           
    
               #  Create the basic configuration for the replacement VM with PPG +  Av Set           
               if(($AvailabilitySetExist) -and ($ProximityPlacementGroupExist)){
                    Write-Host
                    Write-WithTime "Configuring Virtual Machine to use Availability Set '$AvailabilitySetName' and Proximity Placement Group '$ProximityPlacementGroupName' ..."
                    $newVM = New-AzVMConfig -VMName $VirtualMachineName -VMSize $VMSize -AvailabilitySetId $AvailabilitySet.Id -ProximityPlacementGroupId $ppg.Id 
               }elseif($AvailabilitySetExist){
                    Write-Host
                    Write-WithTime "Configuring Virtual Machine to use Availability Set '$AvailabilitySetName'  ..."
                    $newVM = New-AzVMConfig -VMName $VirtualMachineName -VMSize $VMSize -AvailabilitySetId $AvailabilitySet.Id 
               }elseif($ProximityPlacementGroupExist){
                    Write-Host
                    "Configuring Virtual Machine to use Proximity Placement Group '$ProximityPlacementGroupName' ..."
                    $newVM = New-AzVMConfig -VMName $VirtualMachineName -VMSize $VMSize -ProximityPlacementGroupId $ppg.Id 
               }                        
    
               if ($osType -eq "Linux")
               {    Write-Host
                    Write-WithTime "Configuring Linux OS disk '$OSDiskName' .. "                
                    Set-AzVMOSDisk  -VM $newVM -CreateOption Attach -ManagedDiskId $originalVM.StorageProfile.OsDisk.ManagedDisk.Id -Name $OSDiskName -Linux -Caching $originalVM.StorageProfile.OsDisk.Caching > $null
           
               }elseif ($osType -eq "Windows")
               {    Write-Host
                    Write-WithTime "Configuring Windows OS disk '$OSDiskName' .. " 
                       Set-AzVMOSDisk  -VM $newVM -CreateOption Attach -ManagedDiskId $originalVM.StorageProfile.OsDisk.ManagedDisk.Id -Name $OSDiskName -Windows -Caching $originalVM.StorageProfile.OsDisk.Caching	> $null	
               }
    
               # Add Data Disks
               foreach ($disk in $originalVM.StorageProfile.DataDisks) { 
                    Write-Host
                    Write-WithTime "Adding data disk '$($disk.Name)'  to Virtual Machine '$VirtualMachineName'  ..."
                    Add-AzVMDataDisk -VM $newVM -Name $disk.Name -ManagedDiskId $disk.ManagedDisk.Id -Caching $disk.Caching -Lun $disk.Lun -DiskSizeInGB $disk.DiskSizeGB -CreateOption Attach > $null
               }
    
               # Add NIC(s) and keep the same NIC as primary
               foreach ($nic in $originalVM.NetworkProfile.NetworkInterfaces) {	              
                  Write-Host
                  Write-WithTime "Adding '$($nic.Id)' network card to Virtual Machine '$VirtualMachineName'  ..."
                  if ($nic.Primary -eq "True"){                
                    Add-AzVMNetworkInterface -VM $newVM -Id $nic.Id -Primary > $null
                     }
                     else{                
                       Add-AzVMNetworkInterface -VM $newVM -Id $nic.Id > $null
                  }
              }
                    
            if(-not $DoNotCopyTags){
                # List the VM Tags
                Write-Host
                Write-WithTime "Listing VM '$VirtualMachineName' tags: "
                Write-Host
                $originalVM.Tags
    
                # Copy the VM Tags
                Write-Host
                Write-WithTime "Copy Tags ..."
                $newVM.Tags = $originalVM.Tags
                Write-Host
                Write-WithTime "Tags copy to new VM definition done. "
    
            }else{
                Write-Host
                Write-Host "Skipping copy of VM tags:"            
                Write-Host
                $originalVM.Tags
            }
            
            # Configuring Boot Diagnostics
            if ($originalVM.DiagnosticsProfile.BootDiagnostics.Enabled) {
    
                Write-Host
                Write-WithTime "Boot diagnostic account is enabled."
                
                # Get Strage URI
                $StorageUri = $originalVM.DiagnosticsProfile.BootDiagnostics.StorageUri 
                
                if ($StorageUri -eq $null) {
    
                    Write-Host
                    Write-WithTime "Boot diagnostic URI is empty."
    
                    Write-Host
                    Write-WithTime "Skipping boot diagnostic configuration. Please configure manualy boot diagnostic after VM is moved to the Azure zone."                
    
                }else {
                    
                    $BootDiagnosticURI = $originalVM.DiagnosticsProfile.BootDiagnostics.StorageUri.Split("/")[2]
                    Write-Host
                    Write-WithTime "Boot diagnostic URI: '$BootDiagnosticURI'."
        
                    $staccName = $BootDiagnosticURI.Split(".")[0]
                    Write-Host
                    Write-WithTime "Extracted storage account name: '$staccName'"
        
                    Write-Host
                    Write-WithTime "Getting storage account '$staccName'"
                    $stacc = Get-AzStorageAccount | where-object { $_.StorageAccountName.Contains($staccName) }
                    
                    if($stacc  -eq $null ){
                        Write-Host 
                        Write-WithTime "Storage account '$staccName' used for diagonstic account on source VM do not exist. Skipping configuration of boot diagnostic on the new VM."
                    
                    }else{
    
                        Write-Host
                        Write-WithTime "Configuring storage account '$staccName' for VM boot diagnostigs in Azure resource group '$($stacc.ResourceGroupName)' on the new VM ..."
                    
                        $newVM = Set-AzVMBootDiagnostic -VM $newVM -Enable -ResourceGroupName $stacc.ResourceGroupName -StorageAccountName $staccName
    
                        Write-Host
                        Write-WithTime "Configuring storage account '$staccName' for VM boot diagnostigs done."    
                    }
                    
                }
    
    
                    #$BootDiagnosticURI = $originalVM.DiagnosticsProfile.BootDiagnostics.StorageUri.Split("/")[2]
                    #$staccName = $BootDiagnosticURI.Split(".")[0]
                    #$stacc = Get-AzStorageAccount | where-object { $_.StorageAccountName.Contains($staccName) }
                    #Write-Host
                    #Write-WithTime "Configuring storage account '$staccName' located in Azure resource group $($stacc.ResourceGroupName) for VM boot diagnostigs ..."
                    #$newVM = Set-AzVMBootDiagnostic -VM $newVM -Enable -ResourceGroupName $stacc.ResourceGroupName -StorageAccountName $staccName
            }
    
            # Remove the original VM
            Write-Host
            Write-WithTime  "Removing Virtual Machine '$VirtualMachineName' definition ..."
            Write-Host
            Remove-AzVM -ResourceGroupName $ResourceGroupName -Name $VirtualMachineName -force 
    
            Write-Host
            Write-WithTime "Recreating Virtual Machine '$VirtualMachineName'   ..."
            New-AzVM -ResourceGroupName $ResourceGroupName -Location $originalVM.Location -VM $newVM -DisableBginfoExtension 
        
            Write-WithTime "Done!"
    
            }
            catch{
               Write-Error  $_.Exception.Message           
           }
        }
    
        END {}
    }
    
    
    function Export-VMConfigurationToJSONFile {
        [CmdletBinding()]
        param(
            
            [Parameter(Mandatory=$True)]
            [ValidateNotNullOrEmpty()]        
            $VM                            
        )
    
        BEGIN{}
        
        PROCESS{
            try{   
               
               $VMName = $VM.Name
               $FileName = "$VMName.json"
    
               $VM | ConvertTo-Json -depth 100 | Out-File $FileName
    
               Write-WithTime "Virtual Machine '$VMName' configuration is exported to file '$FileName' "
    
            }
            catch{
               Write-Error  $_.Exception.Message
           }
    
        }
    
        END {}
    }
    
    function Move-AzVMToAzureZoneAndOrProximityPlacementGroup {
    <#
    .SYNOPSIS
        Moves a VM into an Azure availability zone, or move VM from one Azure zone to another Azure zone
    
    .DESCRIPTION
        The script deletes the VM and recreates it preserving networking and storage configuration.  The script will snapshot each disk, create a new Zonal disk from the snapshot, and create the new Zonal VM with the new disks attached.  
        Disk type are Standard or Premium managed disks.
    
        There is no need to reinstall the operating system.
        
        IMPORTANT: The script does not preserve VM extensions. Also, the script will not work for VMs with public IP addresses.
        
        If you specify -ProximityPlacementGroupName parameter, VM will be added to the Proximity Placement Group. Proximity Placement Group must exist.
    
        IMPORTANT: In case that there are other VMs that are part of Proximity Placement Group and the desired Zone, make sure that desired zone and PPG is the same zone where existing VMs are placed!
    
        If your VM is part of an Azure Internal Load Balancer (ILB),specify the name of Azure ILB  by using -AzureInternalLoadBalancerName parameter. 
    
        IMPORTANT: Script will check that Azure ILB is of Standard SKU Type, which is needed for the Zones. 
                   If Azure ILB is of type 'Basic', first you need to convert existing ILB to 'Standard' SKU Type.
        
        IMPORTANT: SAP High Availability context
    
        In SAP High Availability context, script is aplicable when moving for example clustered SAP ASCS/SCS cluster VMs, or DBMS cluster VMs from an Availability Set with Standard Azure ILB, to Azure Zone with Standard Azure ILB.
    
        If you want to add the VM to Proximity Placement Group, expectation is that:
           - Proximity Placement Group alreday exist
           - First ancor VM (this is DBMS VM) is alreday deplyed in a Zone and same Proximity Placement Group
    
           
    .PARAMETER ResourceGroupName 
    Resource Group Name of the VM.
        
    .PARAMETER VirtualMachineName 
    Virtual Machine Name name. 
    
    .PARAMETER AvailabilitySetName
    Availability Set Name.
    
    .PARAMETER ProximityPlacementGroupName
    ProximityPlacementGroupName
    
    .PARAMETER AzureInternalLoadBalancerName
    Azure Internal Load Balancer Name
    
    .PARAMETER DoNotCopyTags
    Switch paramater. If specified, VM tags will NOT be copied.

    .PARAMETER NewVMSize
    If NewVMSize is specified , VM will be set to a new VM size. Otherwise, original VM size will be used. 
    
    .EXAMPLE
        # Move VM 'VM1' to Azure Zone '2'
        # VM tags will not be copied : swicth parameter -DoNotCopyTags is set
    
        Move-AzVMToAzureZoneAndOrProximityPlacementGroup -ResourceGroupName SAP-SB1-ResourceGroup -VirtualMachineName VM1 -AzureZone 2 -DoNotCopyTags
    
    .EXAMPLE
        # Move VM 'VM1' to Azure Zone '2', and add to exisiting 'PPGForZone2' 
        # VM will be set to NEW VM size, e.g. not original VM size , because 'NewVMSize' is specified
        Move-AzVMToAzureZoneAndOrProximityPlacementGroup -ResourceGroupName SAP-SB1-ResourceGroup -VirtualMachineName VM1 -AzureZone 2 -ProximityPlacementGroupName PPGForZone2 -NewVMSize "Standard_E4s_v3"
        
    
    .EXAMPLE
        # This scenario is used to move higly available DB cluster nodes, SAP ASCS/SCS clsuter nodes, or file share cluster nodes
        # Move VM 'VM1' to Azure Zone '2', and add to exisiting 'PPGForZone2' , and check if Azure Internal Load Balancer 'SB1-ASCS-ILB' has 'Standard' SKU type
        Move-AzVMToAzureZoneAndOrProximityPlacementGroup -ResourceGroupName SAP-SB1-ResourceGroup -VirtualMachineName sb1-ascs-cl1 -AzureZone 2 -ProximityPlacementGroupName PPGForZone2 -AzureInternalLoadBalancerName SB1-ASCS-ILB
    
    .LINK
        
    .NOTES
        v0.1 - Initial version
    
    #>
    
    #Requires -Modules Az.Compute
    #Requires -Version 5.1
    
        [CmdletBinding()]
        param(
            
            [Parameter(Mandatory=$True)]
            [ValidateNotNullOrEmpty()]        
            [string]$ResourceGroupName,
                  
            [Parameter(Mandatory=$True)]
            [ValidateNotNullOrEmpty()]        
            [string] $VirtualMachineName,
    
            [Parameter(Mandatory=$True)]
            [string] $AzureZone,
    
            [Parameter(Mandatory=$False)]
            [string] $ProximityPlacementGroupName,
    
            [Parameter(Mandatory=$False)]
            [string] $AzureInternalLoadBalancerName,
    
            [switch] $DoNotCopyTags,

            [Parameter(Mandatory=$False)]
            [string] $NewVMSize
        )
    
        BEGIN{        
            $ProximityPlacementGroupExist = $False    
        }
        
        PROCESS{
            try{   
               
               if ($AzureInternalLoadBalancerName -ne ""){           
                    $ILB = Get-AzLoadBalancer  -Name $AzureInternalLoadBalancerName -ErrorAction Stop
    
                    if($ILB -ne $null){
                        $AzureInternalLoadBalancerNameExist = $True
                        Write-Host
                        Write-WithTime "Azure Internal Load Balancer '$AzureInternalLoadBalancerName' exist."
    
                        #check if ILB SKU for 'Standard'
                        if($ILB.Sku.Name -eq "Standard"){
                            Write-Host
                            Write-WithTime "Azure Internal Load Balancer '$AzureInternalLoadBalancerName' has expected 'Standard' SKU."
                        }
                        else{
                            Throw  "Specified Azure Internal Load BalancerName is not 'Standard' load balancer. Before proceeding convert '$AzureInternalLoadBalancerName' load balancer from 'Basic' to 'Standard' SKU type." 
                        }
                    }else{
                        Throw  "Specified Azure Internal Load BalancerName '$AzureInternalLoadBalancerName' doesn't exists. Please check your input parameter 'AzureInternalLoadBalancerName'." 
                    }
                                                   
               }else{
                    Write-Host
                    Write-WithTime "Azure Internal Load Balancer is not specified."                
               }  
               
               Write-Host
               Write-WithTime  "Starting Virtual Machine '$VirtualMachineName' ..."
               Start-AzVM -ResourceGroupName $ResourceGroupName -Name $VirtualMachineName -ErrorAction Stop 
    
               # get VM and check existance
               $originalVM = Get-AzVM -ResourceGroupName $ResourceGroupName -Name $VirtualMachineName -ErrorAction Stop   
                        
               # Proximity Placement Group must exist
               if ($ProximityPlacementGroupName -ne ""){           
                    $ppg = Get-AzProximityPlacementGroup -ResourceGroupName $ResourceGroupName -Name $ProximityPlacementGroupName -ErrorAction Stop
    
                    $ProximityPlacementGroupExist = $True
    
                    Write-Host
                    Write-WithTime "Proximity Placement Group '$ProximityPlacementGroupName' exist."    
                    
                    Write-Host
                    Write-WithTime "Starting migration of Virtual Machine '$VirtualMachineName' to Azure Zone '$AzureZone' and Proximity Placement Group '$ProximityPlacementGroupName' ..."
               }else{
                    Write-Host
                    Write-WithTime "Proximity Placement Group is not specified."
    
                    Write-Host
                    Write-WithTime "Starting migration of Virtual Machine '$VirtualMachineName' to Azure Zone '$AzureZone' ..."
               }                                                      
                    
                          
               # We don't support moving machines with public IPs, since those are zone specific.  
               foreach ($nic in $originalVM.NetworkProfile.NetworkInterfaces) {
                     $thenic = $nic.id
                     $nicname = $thenic.substring($thenic.LastIndexOf("/")+1)
                     $othernic = Get-AzNetworkInterface -name $nicname -ResourceGroupName $ResourceGroupName 
                     Write-Host
                     Write-WithTime "Found Network Card '$nicname' in Azure resource group  '$ResourceGroupName'."
            
                     foreach ($ipc in $othernic.IpConfigurations) {
                         $pip = $ipc.PublicIpAddress
                         if ($pip) { 
                             Throw  "Sorry, machines with public IPs are not supported by this script" 
                                #exit
                         }
                     }
               }
             
               [string] $osType      = $originalVM.StorageProfile.OsDisk.OsType
               [string] $location    = $originalVM.Location
               [string] $storageType = $originalVM.StorageProfile.OsDisk.ManagedDisk.StorageAccountType
               [string] $OSDiskName  = $originalVM.StorageProfile.OsDisk.Name

               if($NewVMSize -eq ""){
                    # if $NewVMSIze is not specified, use the orgonal VM size
                    $VMSize = $originalVM.HardwareProfile.VmSize
                }
                else{
                    # if $NewVMSIze is  specified, use it as VM size
                    $VMSize = $NewVMSize
                }
        
               # Shutdown the original VM
               Write-Host
               Write-WithTime  "Stopping Virtual Machine '$VirtualMachineName' ..."
               Stop-AzVM -ResourceGroupName $ResourceGroupName -Name $VirtualMachineName -force -ErrorAction Stop 
    
               # Export original VM configuration
               Write-Host
               Export-VMConfigurationToJSONFile -VM  $originalVM      
                          
               #  Create the basic configuration for the replacement VM with Zone and / or PPG
               if($ProximityPlacementGroupExist){
                    Write-Host
                    Write-WithTime "Configuring Virtual Machine to use Azure Zone '$AzureZone' and Proximity Placement Group '$ProximityPlacementGroupName' ..."
                    $newVM = New-AzVMConfig -VMName $VirtualMachineName -VMSize $VmSize -ProximityPlacementGroupId $ppg.Id -Zone $AzureZone
               }else{
                    Write-Host
                    Write-WithTime "Configuring Virtual Machine to use Azure Zone '$AzureZone' ..."
                    $newVM = New-AzVMConfig -VMName $VirtualMachineName -VMSize $VmSize -Zone $AzureZone 
               }
                            
               #  Snap and copy the os disk
               $snapshotcfg =  New-AzSnapshotConfig -Location $location -CreateOption copy -SourceResourceId $originalVM.StorageProfile.OsDisk.ManagedDisk.Id
               $osdiskname = $originalVM.StorageProfile.OsDisk.Name
               $snapshotName = $osdiskname + "-snap"
               
               Write-Host
               Write-WithTime  "Creating OS disk snapshot '$snapshotName' ..."
               $snapshot = New-AzSnapshot -Snapshot $snapshotcfg -SnapshotName $snapshotName -ResourceGroupName $ResourceGroupName
               $newdiskConfig = New-AzDiskConfig -AccountType $storageType -Location $location -CreateOption Copy -SourceResourceId $snapshot.Id -zone $AzureZone
               
               $newdiskName = $osdiskname + "-z" + $AzureZone
               Write-Host
               Write-WithTime  "Creating OS zonal disk '$newdiskName' from snapshot '$snapshotName' ..."
               $newdisk = New-AzDisk -Disk $newdiskConfig -ResourceGroupName $ResourceGroupName -DiskName $newdiskName
    
               # COnfigure new Zonal OS Disk
               if ($osType -eq "Linux")
               {
                  Write-Host
                  Write-WithTime "Configuring Linux OS disk '$newdiskName' for Virtual Machine '$VirtualMachineName'... "  
                     Set-AzVMOSDisk -VM $newVM -CreateOption Attach  -ManagedDiskId $newdisk.Id -Name $newdisk.Name  -Linux -Caching $originalVM.StorageProfile.OsDisk.Caching > $null
               }
               if ($osType -eq "Windows")
               {
                   Write-Host
                   Write-WithTime "Configuring Windows OS disk '$newdiskName' Virtual Machine '$VirtualMachineName' ... " 
                      Set-AzVMOSDisk -VM $newVM -CreateOption Attach  -ManagedDiskId $newdisk.Id -Name $newdisk.Name  -Windows -Caching $originalVM.StorageProfile.OsDisk.Caching > $null	
               }
    
               # Snapshot all of the Data disks, and add to the VM
               foreach ($disk in $originalVM.StorageProfile.DataDisks)
               {
                        #snapshot & copy the data disk
                        $snapshotcfg =  New-AzSnapshotConfig -Location $location -CreateOption copy -SourceResourceId $disk.ManagedDisk.Id
                        $snapshotName = $disk.Name + "-snap"		
                        Write-Host
                        Write-WithTime  "Creating data disk snapshot '$snapshotName' ..."      
                        $snapshot = New-AzSnapshot -Snapshot $snapshotcfg -SnapshotName $snapshotName -ResourceGroupName $ResourceGroupName
    
                        [string]$thisdiskStorageType = $disk.StorageAccountType
                        $diskName = $disk.Name + "-z" + $AzureZone
                        $diskConfig = New-AzDiskConfig -AccountType $storageType -Location $location -CreateOption Copy -SourceResourceId $snapshot.Id -zone $AzureZone
                        Write-Host 
                        Write-WithTime  "Creating zonal data disk '$diskName' from snapshot '$snapshotName' ..."
                        Write-Host 
                        $newdisk = New-AzDisk -Disk $diskConfig -ResourceGroupName $ResourceGroupName -DiskName $diskName # > $null
                        
                        Write-WithTime "Configuring data disk '$($newdisk.Name)' , LUN '$($disk.Lun)' for Virtual Machine '$VirtualMachineName' ... " 
    
                        if($disk.WriteAcceleratorEnabled) {
                            Write-Host 
                            Write-WithTime "Adding disk '$($newdisk.Name)' to new VM with enabled Write Accelerator ...  "
                               Add-AzVMDataDisk -VM $newVM -Name $newdisk.Name -ManagedDiskId $newdisk.Id -Caching $disk.Caching -Lun $disk.Lun -DiskSizeInGB $newdisk.DiskSizeGB -CreateOption Attach -WriteAccelerator  > $null	
                        }else{
                            Write-Host 
                            Write-WithTime "Adding disk '$($newdisk.Name)' to new VM ...  "
                            Add-AzVMDataDisk -VM $newVM -Name $newdisk.Name -ManagedDiskId $newdisk.Id -Caching $disk.Caching -Lun $disk.Lun -DiskSizeInGB $newdisk.DiskSizeGB -CreateOption Attach > $null	
                        }
             }
    
             # Add NIC(s) and keep the same NIC as primary
             foreach ($nic in $originalVM.NetworkProfile.NetworkInterfaces) {	              
                  Write-Host
                  Write-WithTime "Configuring '$($nic.Id)' network card to Virtual Machine '$VirtualMachineName'  ..."
                  if ($nic.Primary -eq "True"){                
                    Write-Host 
                    Write-WithTime "NIC is primary."
                    Add-AzVMNetworkInterface -VM $newVM -Id $nic.Id -Primary > $null
                     }
                     else{                
                    Write-Host 
                    Write-WithTime "NIC is secondary."
                       Add-AzVMNetworkInterface -VM $newVM -Id $nic.Id > $null
                  }
                }
    
            if(-not $DoNotCopyTags){
                # Copy the Tags
                Write-Host
                Write-WithTime "Listing VM '$VirtualMachineName' tags: "
                Write-Host
                $originalVM.Tags
        
                Write-Host
                Write-WithTime "Copy Tags ..."
                $newVM.Tags = $originalVM.Tags
                Write-Host
                Write-WithTime "Tags copy to new VM definition done. "
            }else{            
                Write-Host
                Write-Host "Skipping copy of VM tags:"            
                Write-Host
                $originalVM.Tags
            }
        
    
              #Configure Boot Diagnostic account
            if ($originalVM.DiagnosticsProfile.BootDiagnostics.Enabled) {
                Write-Host
                Write-WithTime "Boot diagnostic account is enabled."
                
                # Get Strage URI
                $StorageUri = $originalVM.DiagnosticsProfile.BootDiagnostics.StorageUri            
    
                if ($StorageUri -eq $null) {
    
                    Write-Host
                    Write-WithTime "Boot diagnostic URI is empty."
    
                    Write-Host
                    Write-WithTime "Skipping boot diagnostic configuration. Please configure manualy boot diagnostic after VM is moved to the Azure zone."                
    
                }else {
                    
                    $BootDiagnosticURI = $originalVM.DiagnosticsProfile.BootDiagnostics.StorageUri.Split("/")[2]
                    Write-Host
                    Write-WithTime "Boot diagnostic URI: '$BootDiagnosticURI'."
        
                    $staccName = $BootDiagnosticURI.Split(".")[0]
                    Write-Host
                    Write-WithTime "Extracted storage account name: '$staccName'"
        
                    Write-Host
                    Write-WithTime "Getting storage account '$staccName'"
                    $stacc = Get-AzStorageAccount | where-object { $_.StorageAccountName.Contains($staccName) }
                    
                    if($stacc  -eq $null ){
                        Write-Host 
                        Write-WithTime "Storage account '$staccName' used for diagonstic account on source VM do not exist. Skipping configuration of boot diagnostic on the new VM."
                    
                    }else{
    
                        Write-Host
                        Write-WithTime "Configuring storage account '$staccName' for VM boot diagnostigs in Azure resource group '$($stacc.ResourceGroupName)' on the new VM ..."
                    
                        $newVM = Set-AzVMBootDiagnostic -VM $newVM -Enable -ResourceGroupName $stacc.ResourceGroupName -StorageAccountName $staccName
    
                        Write-Host
                        Write-WithTime "Configuring storage account '$staccName' for VM boot diagnostigs done."    
                    }
                    
                }
            }
    
              # Remove the original VM
              Write-Host
              Write-WithTime  "Removing Virtual Machine '$VirtualMachineName' ..."
              Write-Host
              Remove-AzVM -ResourceGroupName $ResourceGroupName -Name $VirtualMachineName -force            
    
              Write-Host
              Write-WithTime "Recreating Virtual Machine '$VirtualMachineName' as zonal VM in Azure zone '$AzureZone' ..."
              New-AzVM -ResourceGroupName $ResourceGroupName -Location $originalVM.Location -VM $newVM -DisableBginfoExtension -zone $AzureZone
        
              Write-WithTime "Done!"
    
            }
            catch{
               Write-Error  $_.Exception.Message           
           }
    
        }
    
        END {}
    }
    
    
    
    
    function Test-AzVMIsZonalVM {
    <#
    .SYNOPSIS
        Check if VM is Zonal VM or not. 
    
    .DESCRIPTION
        Commanlet check if VM is Zonal VM or not, e.g. it retruns boolian $True or $False
        
    
    .EXAMPLE    
        Test-AzVMIsZonalVM -ResourceGroupName gor-Zone-Migration  -VirtualMachineName mig-c2
    
    
    .EXAMPLE
        
        $IsVMZonal = Test-AzVMIsZonalVM -ResourceGroupName gor-Zone-Migration  -VirtualMachineName mig-c2
        if($IsVMZonal){
            Write-Host "Virtutal Machine is zonal VM."
        }else{
            Write-Host "Virtutal Machine is not zonal VM."
        }
    
    .LINK
        
    
    .NOTES
        v0.1 - Initial version
    
    #>
    
    #Requires -Modules Az.Compute
    #Requires -Version 5.1
    
        [CmdletBinding()]
        param(
            
            [Parameter(Mandatory=$True)]
            [ValidateNotNullOrEmpty()]        
            [string]$ResourceGroupName,
                  
            [Parameter(Mandatory=$True)]
            [ValidateNotNullOrEmpty()]        
            [string] $VirtualMachineName
        )
    
        BEGIN{        
              
        }
        
        PROCESS{
            try{   
               
               # get VM and check existance
               $VM = Get-AzVM -ResourceGroupName $ResourceGroupName -Name $VirtualMachineName -ErrorAction Stop   
               
               $Zone = $VM.Zones
               
               if($Zone -eq $Null){
                    return $False           
               }else{
                    return $True
               }                                     
            }
            catch{
               Write-Error  $_.Exception.Message           
           }
    
        }
    
        END {}
    }
    