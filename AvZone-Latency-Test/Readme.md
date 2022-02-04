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
* PowerShell 7.1 or newer
* PowerShell modules Posh-SSH 3.0 and Az

### What the script does

The script creates three VMs, one in each zone and then runs qperf to test the latency and throughput. Depending on your parameters the environment will be deleted after your test or kept for further usage.

You can decide to use qperf or niping (SAP tool) to test the latency and bandwidth.
If you want to use niping please provide a URL to e.g. a BLOB storage which provides direct access to the niping executable.
The output for qperf and niping is the same.

In addition you will receive a list of Azure hypervisor hosts where your VM is running.

### How to run the script

#### Testing with qperf

```powershell
AvZone-Latency-Test.ps1' -SubscriptionName <your subscription name> -region <your region, e.g. northeurope>
```

#### Testing with niping

Niping is provided by SAP, please download the file to e.g. a storage account and provide a link to the file for the script.

```powershell
AvZone-Latency-Test.ps1' -SubscriptionName <your subscription name> -region <your region, e.g. northeurope> -testtool niping -nipingpath <your URL to niping linux executable>
```

### Sample Output

        Getting Hosts for virtual machines
        VM1 : AMS07XXXXXXXXXX
        VM2 : AMZ07XXXXXXXXXX
        VM3 : AMS21XXXXXXXXXX


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
