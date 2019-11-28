# Availability Zone Latency Test

## Availability Zones

[Availability Zones](https://docs.microsoft.com/en-us/azure/availability-zones/az-overview) provide different datacenter with independent cooling, power and network within one Azure Region.

Every Azure Subscription gets three zones, it is important to understand that we mix the real datacenters with the assigned zones every time you create a new subscription.

To learn more about SAP and Availability Zones visit our [documentation](https://docs.microsoft.com/en-us/azure/virtual-machines/workloads/sap/sap-ha-availability-zones).

## Latency Test

As Azure regions consist of multiple datacenters in an area the network latency between the different zones might differ.

To provide an easy way of testing you can use this script.

**requirements:**

* Azure Subscription
* Core quota assigned to the subscription incl zone deployment (we recommend to use D8s_v3 or bigger, so at least 24 cores required)
* possibility to connect to the VMs using SSH (Public IP addresses or existing VNET with private IP addresses)
* PowerShell 5.1 or newer
* PowerShell modules Posh-SSH and Az

### What the script does

The script creates three VMs, one in each zone and then runs qperf to test the latency and throughput. Depending on your parameters the environment will be deleted after your test or kept for further usage.

We use qperf as it utilizes TCP and UDP traffic. ICMP traffic is not prioritized in Azure, therefor it is required to use TCP or UDP to get propper results.

### Sample Output

        Region:  westeurope
        VM Type:  Standard_D8s_v3
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

```
Based on the output you can decide which zones to use.
