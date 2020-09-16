# Cost Management Dashboard
This cost management dashboard is an addon to the Azure Cost Management API, you will be able to drill into your Azure costs and analyze them based on your tags.

# Disclaimer
THE SCRIPTS ARE PROVIDED AS IS WITHOUT WARRANTY OF ANY KIND, EITHER EXPRESS OR IMPLIED, INCLUDING ANY IMPLIED WARRANTIES OF FITNESS FOR A PARTICULAR PURPOSE, MERCHANTABILITY, OR NON-INFRINGEMENT.

# Getting Started
## Requirements
To use the cost management dashboard you are required to have following information
* run Excel and PowerBI on your PC
* Azure Cost Management API PowerBI key
* access to your Azure Subscription incl permissions for Cost Management API

## How to deploy the Cost Management Dashboard
1. Download all files from this site
2. Update the metadata files (Excel Files)
3. Start the PowerBI Template
4. Enter the required data (PowerBI parameters)
5. Refresh data to perform a first test
6. Update the PowerBI Theme
7. Publish your Report if you want to make it accessible to others

## Starting PowerBI for the first time
When opening the template for the first time you will get a screen to fill out your connection details:

![Starting PowerBI](readme-images/github-template-getting-started.jpg)

* Enrollment ID: can be found on your EA Portal
* Months - Usage: number of month to download, we recommend to start with 2
* Months - Summary: number of month to download, we recommend to start with 12
* Months - Budgets: number of month to download, we recommend to start with 12
* Months - Reservations: number of month to download, we recommend to start with 36
* Azure Advisor: local path to CSV file downloaded from Azure Advisor
* Azure Subscriptions: local path to Excel file about Azure Subscriptions
* Subscription Metadata: local path to Excel file with Subscription Metadata
* Price Sheet Validation: local path to your Microsoft pricesheet

# Questions
if you have questions please open an issue on the GitHub site

# Sample Screenshots
![Home](readme-images/home.jpg)

Home Screen

![Summary](readme-images/summary.jpg)

Summary page

![Applications](readme-images/applications.jpg)

Applications view

![Meter (Details)](readme-images/meter-detail.jpg)

Meter details

![Networking](readme-images/networking.jpg)

Networking

![cost center](readme-images/costcenter.jpg)

Cost Center

![reservations](readme-images/reserverations.jpg)

Reserverations

![regions](readme-images/regions.jpg)

Regions

![price sheet](readme-images/price-sheet.jpg)

Price Sheet

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