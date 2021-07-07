# Windows Server Failover Cluster with Azure Shared Disk
This template will provision a base two-node Windows Server Failover Cluster with a Azure Zonal Shared Disk. The resulting cluster deployment is intended for use with SAP ASCS/SCS workloads for highly available deployments on the Azure cloud platform. The clustered SAP workloads will be provisioned by SAP setup tools and are not part of this sample.

The code here is based on the great work from Keith Meyer available here [301 Shared Disk SAP](https://github.com/robotechredmond/301-shared-disk-sap)

## Prerequisites

To successfully deploy this template, the following must already be provisioned in your subscription:

+ Azure Virtual Network with subnet defined for cluster node VMs and ILB
+ Windows Server Active Directory and AD-integrated Dynamic DNS reachable from Azure Virtual Network
+ Subnet IP address space defined in AD Sites and Services
+ Custom DNS Server Settings configured on Azure Virtual Network to point to AD-integrated Dynamic DNS servers

+ To deploy the required Azure VNET and Active Directory infrastructure, if not already in place, you may use [Active Directory Domain Controller deployment template ]("https://github.com/Azure/azure-quickstart-templates/tree/master/active-directory-new-domain-ha-2-dc) to deploy the prerequisite infrastructure.

## Deployments using availability sets

For deployments using availability sets use the [avset_template](./avset_template.json)

This template creates the following resources in the selected Azure Region:

+ Proximity Placement Group and Availability Set for Azure VMs
+ Two Azure VMs running Windows Server 2019 or Windows Server 2016 for cluster nodes.
+ Azure VM DSC Extensions to prepare and configure the Windows Server Failover Cluster
+ Azure Shared Data Disk for Data
+ Cluster Witness resources (either Cloud Witness (storage account) or Shared Disk depending on value of witnessType template parameter)
+ Internal Load Balancer to provide a listener IP Address for clustered SAP workload.
+ Azure Load Balancer for SNAT support for outbound requests.

## Deploying Sample Templates

```PowerShell
.\New-AzResourceGroupDeployment -ResourceGroupName "TEST-WEEU-CLUSTER" -TemplateFile .\avset_template.json  -name "AVset_Deployment"
```

```bash
az deployment group create --resource-group "TEST-WEEU-CLUSTER" --template-file avset_template.json --name "AvSet_Deployment"
```

Click the button below to deploy from the portal:

<a href="https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FAzure%2FSAP-on-Azure-Scripts-and-Utilities%2Fmain%2Favset_template.json" target="_blank">
    <img src="http://azuredeploy.net/deploybutton.png"/>
</a>


## Deployments using availability zones

For zonal deployents use [zonal_template](./zonal_template.json)

This template creates the following resources in the selected Azure Region:

+ Proximity Placement Group per zone
+ Two Azure VMs running Windows Server 2019 or Windows Server 2016 for cluster nodes running across two zones.
+ Azure VM DSC Extensions to prepare and configure the Windows Server Failover Cluster
+ Azure Shared Data Disk for Data
+ Cluster Witness resources (either Storage Account or Shared Disk depending on value of witnessType template parameter)
+ Internal Load Balancer to provide a listener IP Address for clustered SAP workload.
+ Azure Load Balancer for SNAT support for outbound requests.

## Deploying Sample Templates

```PowerShell
.\New-AzResourceGroupDeployment -ResourceGroupName "TEST-WEEU-CLUSTER" -TemplateFile .\zonal_template.json  -name "Zonal_Deployment"
```

```bash
az deployment group create --resource-group "TEST-WEEU-CLUSTER" --template-file zonal_template.json --name "Zonal_Deployment"
```

Click the button below to deploy from the portal:

<a href="https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FAzure%2FSAP-on-Azure-Scripts-and-Utilities%2Fmain%2Fzonal_template.json" target="_blank">
    <img src="http://azuredeploy.net/deploybutton.png"/>
</a>

## Template Deployment Notes

+ existingSubnetResourceId parameter
    + When deploying this template, you must supply a valid Azure Resource ID for an existing Virtual Network subnet on which to provision the cluster instances.  You can find the Azure Resource ID value to use by running the PowerShell cmdlet below.

    `(Get-AzVirtualNetwork -Name $(Read-Host -Prompt "Existing VNET name")).Subnets.Id`


+   Currently, Azure Shared Disk is a Preview feature and is available in a subset of Azure regions. Please review the <a href="https://docs.microsoft.com/en-us/azure/virtual-machines/windows/disks-shared-enable">official documentation</a> for more details and current status for this feature.

Tags: ``cluster, ha, shared disk, windows server 2019, ws2019``