# This document lists the steps required for creating a new deployment of a new SAP environment on Azure.

Follow the steps below

**1. Create the new resource group in Azure**

**2. Create a new folder using the SID of the environment under the "landScapes" folder in the "EAPP-SAP on Azure" repository**

**3. Copy the files required for the deployment:**
- deployLandscape.ps1
- ppgavset.parameters.json

and the parameter files for the server types you want to deploy (database and application server), for example S90.devAppVM.parameters.json and S90.hanaDevVM.parameters.json

**4. Update the deployLandcapes.ps1 file** 

- change the $ResourceGroupName variable value, for example $ResourceGroupName = "EARCS-S6-DV-NE-SAP-S04-RG"
- change the file referred to by the -TemplateParameterFile parameters (one for each server)

**5. Update the server parameter files SID.xxxx.paramater.json and change the following parameters:**

- sapSystemId, for example: "sapSystemId": {"value": "S04"}
- availabilitySetName, for example: "availabilitySetName": {"value": "EARCS-S6-DV-NE-SAP-APP-SLES-S04-AVS"}
- availabilitySetNameDB, for example: "availabilitySetNameDB": {"value": "EARCS-S6-DV-NE-SAP-DB-SLES-S04-AVS"}
- proximityPlacementGroupName, for example: "proximityPlacementGroupName": {"value": "EARCS-S6-DV-NE-SAP-S04-PPG"}

**6. Update the server parameter files SID.xxxx.paramater.json and change the following parameters:**

- sapSystemId, for example: "sapSystemId": {"value": "S04"}
- virtualMachineSize, for example: "virtualMachineSize": {"value": "Standard_E4s_v3"}
- availabilitySetName, for example: "availabilitySetName": {"value": "EARCS-S6-DV-NE-SAP-DB-SLES-S04-AVS"}
- proximityPlacementGroupName, for example: "proximityPlacementGroupName": {"value": "EARCS-S6-DV-NE-SAP-S04-PPG"}
- imageReference, for example: "imageReference": {"value": {"publisher": "suse","offer": "SLES-SAP","sku": "12-sp4","version": "latest"}}
- PrivateIP, for example: "PrivateIP": {"value":"111.222.333.444"} 

and any other parameter values unique for the deployment
