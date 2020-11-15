# Move VM to new region

The scripts in this folder can be used to migrate all VMs from a resource group to another region.

The migration is a 4 step process

- Export the disks
- Modify the export manifest
- Create the disks
- Create the virtual machines

**requirements:**

- Azure Subscription
- PowerShell 5.1 or newer
- PowerShell modules Posh-SSH and Az
- AzCopy executable in the same directory as the script

## Export the disks

This script will copy the managed disks to .vhd files in a storage account and create an export manifest that can be used to recreate the Virtual Machines in the new environment.

### Example

Environment variables

```PowerShell
$SubscriptionName           = "AG-GE-CE-KIMFORSS-SAP"
$ResourceGroupName          = "PROTO-NOEU-SAPPROT_DEMO-WOO"
$TargetResourceGroupName    = "PROTO-WEEU-SAPPROT_DEMO-WOO"
$storageAccountName         = "protoweeumigratedisks"
$Location                   = "westeurope"
```

Export script

```PowerShell
Export-Disks.ps1 -SubscriptionName $SubscriptionName -ResourceGroupName $ResourceGroupName -TargetResourceGroupName $TargetResourceGroupName -storageAccountName $storageAccountName -Location $Location -ExportManifest "export.json"
```

This script will initiate an asynchronous copy operation which will take some time to finish. The script below can be used to check the status of the copy operations.

```PowerShell
Check-CopyOperation.ps1 -SubscriptionName $SubscriptionName  -StorageAccountName $storageAccountName -ExportManifest "export.json"
```

The succesful completion of the copy operation will look like this:

```TEXT
Checking:  PROTO-NOEU-SAPPROT-WOO_wooanchor_z1_00lbe0-OsDisk.vhd
Status : Success
Checking:  PROTO-NOEU-SAPPROT-WOO_wooanchor_z2_02lbe0-OsDisk.vhd
Status : Success
Checking:  PROTO-NOEU-SAPPROT-WOO_wooanchor_z3_01lbe0-OsDisk.vhd
Status : Success
Checking:  PROTO-NOEU-SAPPROT-WOO_woodora_z1_00l0be0-OsDisk.vhd
Status : Success
Checking:  PROTO-NOEU-SAPPROT-WOO_woodora_z1_00l0be0-data00.vhd
Status : Success
Checking:  PROTO-NOEU-SAPPROT-WOO_woodora_z1_00l0be0-data01.vhd
Status : Success
```

## Edit the export manifest

The previous step will create an export manifest that should be updated to reflect the new environment. All fields except the Disks.Name can be changed.
The disk creation will use the Disks.NewName field to create the new disks.

The following properties must be changed if the environment is moved to a new region:

- ppg_ID
- avs_ID
- subnet
- IP

```JSON
  {
    "Name": "PROTO-NOEU-SAPPROT-WOO_woodora_z1_00l0be0",
    "Size": "Standard_D4s_v3",
    "OsDisk": "PROTO-NOEU-SAPPROT-WOO_woodora_z1_00l0be0-OsDisk.vhd",
    "ppg_ID": "/subscriptions/8d8422a3-a9c1-4fe9-b880-adcf61557c71/resourceGroups/PROTO-NOEU-SAPPROT_DEMO-WOO/providers/Microsoft.Compute/proximityPlacementGroups/PROTO-NOEU-SAPPROT-WOO_z1-ppg",
    "avset_ID": null,
    "subnet": "/subscriptions/8d8422a3-a9c1-4fe9-b880-adcf61557c71/resourceGroups/PROTO-NOEU-SAPPROTO-INFRASTRUCTURE/providers/Microsoft.Network/virtualNetworks/PROTO-NOEU-SAPPROTO-vnet/subnets/PROTO-NOEU-SAPPROTO-subnetAdmin",
    "IP": "10.6.1.40",
    "Disks": [
      {
        "Name": "PROTO-NOEU-SAPPROT-WOO_woodora_z1_00l0be0-OsDisk",
        "NewName": "PROTO-NOEU-SAPPROT-WOO_woodora_z1_00l0be0-OsDisk",
        "Size": 127,
        "SKU": "Premium_LRS"
      },
      {
        "Name": "PROTO-NOEU-SAPPROT-WOO_woodora_z1_00l0be0-data00",
        "NewName": "PROTO-NOEU-SAPPROT-WOO_woodora_z1_00l0be0-data00",
        "Size": 128,
        "SKU": "Premium_LRS",
        "Caching": "None",
        "Lun": 0
      },
      {
        "Name": "PROTO-NOEU-SAPPROT-WOO_woodora_z1_00l0be0-data01",
        "NewName": "PROTO-NOEU-SAPPROT-WOO_woodora_z1_00l0be0-data01",
        "Size": 128,
        "SKU": "Premium_LRS",
        "Caching": "None",
        "Lun": 1
      }
    ]
  }
```

## Create the managed disks

This script will create managed disks from the .vhd files.

### Example on how to create disks

```PowerShell
.\Create-Disks.ps1 -SubscriptionName $SubscriptionName -ResourceGroupName $TargetResourceGroupName -storageAccountName $storageAccountName -ExportManifest "export.json"
```

## Create the Virtual Machines

This script will create the virtual machines.

### Example on how to create the VMs

```PowerShell
.\Create-Disks.ps1 -SubscriptionName $SubscriptionName -ResourceGroupName $TargetResourceGroupName -storageAccountName $storageAccountName -ExportManifest "export.json"
```
