# Get VMs available in zones

## Availability Zones

[Availability Zones](https://docs.microsoft.com/en-us/azure/availability-zones/az-overview) provide different datacenter with independent cooling, power and network within one Azure Region.

Every Azure Subscription gets three zones, it is important to understand that we mix the real datacenters with the assigned zones every time you create a new subscription.

To learn more about SAP and Availability Zones visit our [documentation](https://docs.microsoft.com/en-us/azure/virtual-machines/workloads/sap/sap-ha-availability-zones).

## Get VMs

Not every zone runs every type of VM and as the zones get mixed for every subscription you can use the script to show which VM types are available in which zone.

**requirements:**

* Azure Subscription
* PowerShell 5.1 or newer
* PowerShell module Az

### Sample Output

        VM Type       Zone 1 Zone 2 Zone 3
        -------       ------ ------ ------
        E16_v3        X      X      X
        E16-4s_v3     X      X      X
        E16-8s_v3     X      X      X
        E16s_v3       X      X      X
        E2_v3         X      X      X
        E20_v3        X      X      X
        E20s_v3       X      X      X
        E2s_v3        X      X      X
        E32_v3        X      X      X
        E32-16s_v3    X      X      X
        E32-8s_v3     X      X      X
        E32s_v3       X      X      X
        E4_v3         X      X      X
        E4-2s_v3      X      X      X
        E48_v3        X      X      X
        E48s_v3       X      X      X
        E4s_v3        X      X      X
        E64_v3        X      X      X
        E64-16s_v3    X      X      X
        E64-32s_v3    X      X      X
        E64i_v3       X      X      X
        E64is_v3      X      X      X
        E64s_v3       X      X      X
        E8_v3         X      X      X
        E8-2s_v3      X      X      X
        E8-4s_v3      X      X      X
        E8s_v3        X      X      X
        M128          X      X      X
        M128-32ms     X      X      X
        M128-64ms     X      X      X
        M128m         X      X      X
        M128ms        X      X      X
        M128s         X      X      X
        M16-4ms       X      X      X
        M16-8ms       X      X      X
        M16ms         X      X      X
        M208ms_v2     X             X
        M208s_v2      X             X
        M32-16ms      X      X      X
        M32-8ms       X      X      X
        M32ls         X      X      X
        M32ms         X      X      X
        M32ts         X      X      X
        M416ms_v2     X             X
        M416s_v2      X             X
        M64           X      X      X
        M64-16ms      X      X      X
        M64-32ms      X      X      X
        M64ls         X      X      X
        M64m          X      X      X
        M64ms         X      X      X
        M64s          X      X      X
        M8-2ms        X      X      X
        M8-4ms        X      X      X
        M8ms          X      X      X
```

Based on the output you can decide which zones to use.
