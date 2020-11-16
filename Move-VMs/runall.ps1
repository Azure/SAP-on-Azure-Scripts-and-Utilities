#$SubscriptionName           = "My-Subscription"
$ResourceGroupName = "PROTO-NOEU-SAPPROT_DEMO-WOO"
$TargetResourceGroupName = "PROTO-WEEU-SAPPROT_DEMO-WOO"
$storageAccountName = "protoweeumigratedisks"
$Location = "westeurope"

#.\Export-Disks.ps1 -SubscriptionName $SubscriptionName -ResourceGroupName $ResourceGroupName -TargetResourceGroupName $TargetResourceGroupName -storageAccountName $storageAccountName -Location $Location -ExportManifest "export.json"

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