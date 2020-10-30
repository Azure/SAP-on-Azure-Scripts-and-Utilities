# Cost Management Dashboard
This cost management dashboard is an addon to the Azure Cost Management API, you will be able to drill into your Azure costs and analyze them based on your tags.

# Latest Version
V3

# Disclaimer
THE SCRIPTS ARE PROVIDED AS IS WITHOUT WARRANTY OF ANY KIND, EITHER EXPRESS OR IMPLIED, INCLUDING ANY IMPLIED WARRANTIES OF FITNESS FOR A PARTICULAR PURPOSE, MERCHANTABILITY, OR NON-INFRINGEMENT.

# Getting Started
## Requirements
To use the cost management dashboard you are required to have following information
* run Excel and Power BI on your PC
* Azure Cost Management API Power BI key
* access to your Azure Subscription incl permissions for Cost Management API

## How to deploy the Cost Management Dashboard
1. Download all files from this site
2. Update the metadata files (Excel Files)
3. Read latest [release notes](Release-Notes.pdf)
4. Start the Power BI Template
5. Enter the required data (Power BI parameters)
6. Refresh data to perform a first test
7. Update the Power BI Theme
8. Publish your Report if you want to make it accessible to others

## Starting Power BI for the first time
When opening the template for the first time you will get a screen to fill out your connection details:

![Starting Power BI](readme-images/github-template-getting-started.jpg)

* Enrollment ID: can be found on your EA Portal
* Months - Usage: number of month to download, we recommend to start with 2
* Months - Summary: number of month to download, we recommend to start with 12
* Months - Budgets: number of month to download, we recommend to start with 12
* Months - Reservations: number of month to download, we recommend to start with 36
* Azure Advisor: local path to CSV file downloaded from Azure Advisor
* Azure Subscriptions: local path to Excel file about Azure Subscriptions
* Subscription Metadata: local path to Excel file with Subscription Metadata
* Price Sheet Validation: local path to your Microsoft pricesheet

## Using metadata files to map costs
The Power BI Dashboard used Azure tags to combine different types of costs.
So it is easy to see what the total costs of e.g. a VM which is combined out of Compute, Storage, Networking, Backup and other meters.
Sometimes tags change over time or you e.g. had a typo in the tags. Thats where the metadata files can help as you can map old data to new data.
As an example you might change the cost center structure for all of your Azure resources, but what about the old data? The tags and associated costs won't change for historic data.
Mapping those old tags to the new once still provides the same view on applications or resources, even if they are tagged differently.

The basic dataflow is explain in the following diagram

![FlowDiagram](readme-images/cost-management-metadata-model.jpg)

## Using Power BI workspaces
If you publish your report online please check the limits of Power BI.

The default app workspace is limited to 10GB of data. Loading more than 2 month in a big Azure enrolement could result in data bigger than 10GB.

You can use Premium capacity to get up to 100GB of data store

Manage data storage in Power BI workspaces

[https://docs.microsoft.com/en-us/power-bi/admin/service-admin-manage-your-data-storage-in-power-bi](https://docs.microsoft.com/en-us/power-bi/admin/service-admin-manage-your-data-storage-in-power-bi)

Power BI pricing models

[https://powerbi.microsoft.com/en-us/pricing/](https://powerbi.microsoft.com/en-us/pricing/)

## Find more information

### Azure Cost Management API
You can find more information about the Azure Cost Management API on
[https://docs.microsoft.com/en-us/power-bi/connect-data/desktop-connect-azure-cost-management](https://docs.microsoft.com/en-us/power-bi/connect-data/desktop-connect-azure-cost-management)

The Azure Cost Management connector uses OAuth 2.0 for authentication with Azure and identifies users who are going to use the connector. Tokens generated in this process are valid for a specific period. Power BI preserves the token for the next login. OAuth 2.0, is a standard for the process that goes on behind the scenes to ensure the secure handling of these permissions.

### Azure Cost Consumption API v2
[https://docs.microsoft.com/en-us/rest/api/consumption/](https://docs.microsoft.com/en-us/rest/api/consumption/)

### Get Enterprise Agreement Reservation Costs and Usage
[https://docs.microsoft.com/en-us/azure/cost-management-billing/reservations/understand-reserved-instance-usage-ea](https://docs.microsoft.com/en-us/azure/cost-management-billing/reservations/understand-reserved-instance-usage-ea)

### Cost Management Connector v2
[https://docs.microsoft.com/en-us/power-bi/connect-data/desktop-connect-azure-cost-management](https://docs.microsoft.com/en-us/power-bi/connect-data/desktop-connect-azure-cost-management)

### Azure Cost Management API and Power BI
[https://docs.microsoft.com/en-us/azure/cost-management-billing/costs/analyze-cost-data-azure-cost-management-power-bi-template-appt](https://docs.microsoft.com/en-us/azure/cost-management-billing/costs/analyze-cost-data-azure-cost-management-power-bi-template-app)

### Azure Enterprise Portal
[https://docs.microsoft.com/en-us/azure/cost-management-billing/manage/ea-portal-get-started](https://docs.microsoft.com/en-us/azure/cost-management-billing/manage/ea-portal-get-started)

### Azure custom pricing
[https://docs.microsoft.com/en-us/azure/cost-management-billing/manage/ea-pricing](https://docs.microsoft.com/en-us/azure/cost-management-billing/manage/ea-pricing)

### PowerBI Themes
[https://docs.microsoft.com/en-us/power-bi/create-reports/desktop-report-themes](https://docs.microsoft.com/en-us/power-bi/create-reports/desktop-report-themes)

# Questions or need help?
if you have questions please open an issue on the GitHub site or send a mail to
Rob Wilson [rowilson@microsoft.com](rowilson@microsoft.com) or
Philipp Leitenbauer [phleiten@microsoft.com](phleiten@microsoft.com)

we can also schedule a demo.

# Sample Screenshots
## Home Screen
The home screen provides a general overview of your Azure consumption, you can drill into every detail by clicking on an entry.
Using the 30-Day and 365-Day trend you can provide a fast overview of past spending and an outlook for the next month.

![Home](readme-images/home.jpg)

## Summary page
The Monthly Summary page provides more insights into the your billing.

![Summary](readme-images/summary.jpg)

## Applications page
Based on tagging the applications will be grouped, you can e.g. create a tag per SAP landscape to inlucde Database, ASCS and App servers or you could use it to show different business units within your company.

![Applications](readme-images/applications.jpg)

## Meter Details
Drill into details on e.g. virtual machines or storage

![Meter (Details)](readme-images/meter-detail.jpg)

## Networking
Get more insights which subscription generates how much networking costs

![Networking](readme-images/networking.jpg)

## Cost Center
You are using cost centers in Azure, here you can see the costs per cost center.

![cost center](readme-images/costcenter.jpg)

## Reservations (Reserved Instances)
Reserved Instances provide the option to save costs, Reservations shows how much you send on different VM types.

![reservations](readme-images/reserverations.jpg)

## Azure Regions
Find out which region generates how much monthly usage

![regions](readme-images/regions.jpg)

## Pricesheet
Look at your companies price sheet for all your SKUs.

![price sheet](readme-images/price-sheet.jpg)

## Other pages
in addition to that there is a databricks page.

## Contributing

This project welcomes contributions and suggestions. Most contributions require you to agree to a
Contributor License Agreement (CLA) declaring that you have the right to, and actually do, grant us
the rights to use your contribution. For details, visit https://cla.opensource.microsoft.com.

When you submit a pull request, a CLA bot will automatically determine whether you need to provide
a CLA and decorate the PR appropriately (e.g., status check, comment). Simply follow the instructions
provided by the bot. You will only need to do this once across all repos using our CLA.

This project has adopted the [Microsoft Open Source Code of Conduct](https://opensource.microsoft.com/codeofconduct/).
For more information see the [Code of Conduct FAQ](https://opensource.microsoft.com/codeofconduct/faq/) or
contact [opencode@microsoft.com](mailto:opencode@microsoft.com) with any additional questions or comments.