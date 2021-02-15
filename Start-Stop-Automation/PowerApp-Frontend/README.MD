# How to get started with PowerApp for the Start/Stop solution on Azure

Find the blog on the SAP community [here](https://blogs.sap.com/2021/02/10/hey-sap-systems-my-powerapp-says-snooze-but-only-if-youre-ready-yet/).

## Prerequisites

- An Azure account with Goran’s powershell and automation account setup as well as authority to create the Azure storage account (table storage) and automation account. Azure Resource Manager requires a service principal to securely call the API. [Here](https://blog.jongallant.com/2017/11/azure-rest-apis-postman/) is the reference for Postman, which I re-created with http steps in PowerAutomate. Simply follow the service principal setup and exchange the ids in my call on cloud flow “CheckStatusOfSAPBySID” and ”Discover SAP Systems”.

- PowerPlatform account: You might consider the [community plan](https://powerapps.microsoft.com/de-de/communityplan/) if your current subscription does not contain premium connectors or you have no PowerPlatform account at all. You need that for the HTTP connection for instance. One downside would be that community resources cannot be shared, which is essential if you would like to empower anyone to use it 😉 But you might consider this enough for testing the approach for free.

- Import the PowerApp solution package “SAP-SID-Controller.zip” from our GitHub repos into the portal. It contains the cloud flows for PowerAutomate and the PowerApp itself. [Here](https://docs.microsoft.com/en-us/powerapps/maker/canvas-apps/export-import-app#importing-a-canvas-app-package) is a reference with a video on how to do that. The two remaining zip files contain the timer based cloud flows to notify users of expiring SAP claims and to stop the scheduled SAP sessions automatically. You will need to import them individually.
During the import process you will need to update connection parameters for the Azure Automation account, Table Storage, Outlook365 and Azure Resource Manager. To do that it is advisable to create them upfront so you can pick right away.
For The table stores the start times and last user, who started the system.

- SAP VMs marked with Azure Tags. Check Goran’s blog on how to set this up.

- A separate calendar in Outlook365 for your scheduled SAP systems. Don’t forget to change the script in the PowerApp.