# AvZone Mapping

## Intro

Sometimes you need to know which logical zones map to the same physical zone.
This script will help you find out.

## Requirements

- PowerShell 7.1
- The feature AvailabilityZonePeering needs to be enabled

## Getting Started

### register the feature

To register the feature you can use Azure CLI

```azurecli
az feature show --namespace Microsoft.Resources --name AvailabilityZonePeering --subscription <subscription-name>
```

or you can use PowerShell

```powershell
Register-AzProviderFeature -FeatureName AvailabilityZonePeering -ProviderNamespace Microsoft.Resources
```

Registration can take some minutes

### run the script

Connect to Azure using

```powershell
Connect-AzAccount
```

.\avzone-mapping.ps1' -subscriptionId 232b6759-0000-0000-88c0-757472230e6c -subscriptionPeers 6488549f-1111-1111-a46e-154644e5bedd,e663cc2d-2222-2222-b636-bbd9e4c60fd9 -region eastus

You can supply one or multiple subscriptions to the subscriptionPeers parameter.

### Sample output

```powershell
.\avzone-mapping.ps1 -subscriptionId 232b6759-0000-0000-88c0-757472230e6c -subscriptionPeers 6488549f-1111-1111-a46e-154644e5bedd,e663cc2d-2222-2222-b636-bbd9e4c60fd9 -region eastus

SubscriptionId: 232b6759-0000-0000-88c0-757472230e6c

Zone 1 matches zone 2 in 6488549f-1111-1111-a46e-154644e5bedd
Zone 1 matches zone 3 in e663cc2d-2222-2222-b636-bbd9e4c60fd9

Zone 2 matches zone 3 in 6488549f-1111-1111-a46e-154644e5bedd
Zone 2 matches zone 2 in e663cc2d-2222-2222-b636-bbd9e4c60fd9

Zone 3 matches zone 1 in 6488549f-1111-1111-a46e-154644e5bedd
Zone 3 matches zone 1 in e663cc2d-2222-2222-b636-bbd9e4c60fd9
```
