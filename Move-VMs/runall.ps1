$SubscriptionName           = "AG-GE-CE-KIMFORSS-SAP"
$ResourceGroupName = "PROTO-NOEU-SAPPROT-ABC"
$TargetResourceGroupName = "PROTO-WEEU-SAPPROT-ABC"
$storageAccountName = "protoweeumigratedisks2"
$Location = "westeurope"

.\Export-Disks.ps1 -SubscriptionName $SubscriptionName -ResourceGroupName $ResourceGroupName -TargetResourceGroupName $TargetResourceGroupName -storageAccountName $storageAccountName -Location $Location -ExportManifest "export.json"

# .\Create-Disks.ps1 -SubscriptionName $SubscriptionName -ResourceGroupName $TargetResourceGroupName -storageAccountName $storageAccountName -ExportManifest "export.json"

# .\Create-VMs.ps1  -SubscriptionName $SubscriptionName -ResourceGroupName $TargetResourceGroupName -ExportManifest "export.json"


$VMs = Get-Content "export.json" | Out-String | ConvertFrom-Json 

$tags = @{}

foreach ($vm in $VMs) {
  for ($i = 0; $i -lt $vm.Tag_keys.Count; $i++) {
    $tags.Add($vm.Tag_keys[$i], $vm.Tag_values[$i])
  }
}

$tags