# Base Infrastructure deployment

This folder contains the sample scripts that can be used to deploy the supporting infrastructure for the SAP deployment

## deployInfrastucture.ps1

deployInfrastucture.ps1 can be used to deploy the application security groups. Update the parameters in the script to reflect your environment. 

```PowerShell
$ResourceGroupNameforASG = "SAP-SharedNetwork"
$location = "northeurope"
$subscriptionID = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
```

The names of the groups are specified in the asg.parameters.json file

```json
{
  "$schema": "https://schema.management.azure.com/schemas/2015-01-01/deploymentParameters.json#",
  "contentVersion": "1.0.0.0",
  "parameters": {
    "location": {
      "value": "westeurope"
    },
     "applicationSecurityGroupName": {
      "value": "sap-app-asg"
    },
    "applicationSecurityGroupNameDB": {
      "value": "sap-db-asg"
    }
  }
}
```

## deployLandscape.ps1

This is a sample script that will be copied to the environment directories when. 

**Do not run the script from here**
 can be used to deploy the infrastructure for the SAP environment.
