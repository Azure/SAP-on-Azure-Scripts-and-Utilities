# Azure Inventory Checks for SAP

# Definition

Azure Inventory Checks for SAP Workbooks provide a flexible canvas for
SAP specific Azure resource deployment and configuration checks with the
help of rich visual reports within the Azure portal. It allows you to
tap into multiple data sources from across Azure and combine them into
unified interactive experiences. It aims at providing customers/partners
with an immediately view of Azure Inventory with intelligence to
highlight configuration drift to improve the quality of SAP On Azure
deployment for operations.

# Objective

Azure Inventory Checks for SAP Workbooks is one of the tools of Azure
Health Check for SAP product being developed under the ACSS
Tools&Frameworks to provide customers/partners a single pane of glass
view on the quality of SAP deployment and to create roadmap to support
Operational excellence by collaboration. 

Azure Health Checks that are run prior to go-live, at start of support
escalations and/or tools that can be self-run by customers during
on-going operations) will provide critical and key information to
accelerate resolution of any issues prior to a customer going live or
when problems arise during operations after an SAP Azure environment is
in production. As well, optimization of internal SAP Azure support
efforts (e.g., via developed internal tools or guidance) will accelerate
troubleshooting and resolution of support issues related to SAP.

# How to use the Azure Inventory Checks for SAP

## Pre-requisites:

1.  Ensure you have permissions to save the workbook in the required
    Azure Resource Group &/or storage account.

2.  Download the workbook json from github repository or Microsoft team
    can share it on email as part of engagement process.

## How to import *Azure Inventory Checks* for SAP Workbook:

1.  Login to Azure Portal

2.  Go to Monitor -> Workbooks

![image](https://user-images.githubusercontent.com/24598299/171523610-29b28d4d-1837-462d-88ea-6db66d0dd56e.png)


3.  Create new workbook by select "+ New"

![image](https://user-images.githubusercontent.com/24598299/171523643-b9c3241e-a538-48cd-bc74-cf512fac06eb.png)


4.  Click on "Advanced Editor"

![image](https://user-images.githubusercontent.com/24598299/171523661-8e5f2145-bd09-4361-92ec-f74abe9fc8e8.png)


5.  Open the attached json as html or notepad.

Paste the json content under Gallery Template

![image](https://user-images.githubusercontent.com/24598299/171523677-a840ecce-7fcc-4b9e-bc4a-a2f6575ef6c2.png)


6.  Click "Apply"

![image](https://user-images.githubusercontent.com/24598299/171523692-f52a29ef-6008-4779-89ab-eed631aa47d3.png)


7.  Click "Done Editing"

8.  Save the workbook

![image](https://user-images.githubusercontent.com/24598299/171523712-1f5b7add-5f76-4176-adb3-a9e3c9080852.png)

![image](https://user-images.githubusercontent.com/24598299/171523724-4546f5d8-7766-4a9b-a293-cd2ce887c80a.png)

9.  Select "Done Editing"

![image](https://user-images.githubusercontent.com/24598299/171523742-0b716bb6-9180-4880-8771-8ddb268fff0a.png)


10. Select the SAP Subscription and explore the workbook content.

# How to export the data from Azure Inventory Checks for SAP

Under each tab, we have option to export the data as excel document.

![image](https://user-images.githubusercontent.com/24598299/171523771-ff1effbc-7e0a-4caf-819a-1ed0d66586bc.png)


## Compute List

1.  Go to Azure Inventory Checks workbook

2.  Select the required subscription

3.  Select Virtual Machine Compute List

4.  Right side **export** option will download the data into
    export_data.xlsx

![image](https://user-images.githubusercontent.com/24598299/171523810-12e41c13-8444-4fe7-828a-c9e94b3c5914.png)

5.  Select Compute Extensions VM+Extensions

![image](https://user-images.githubusercontent.com/24598299/171523855-c058d468-ae2d-4158-b7e8-10ba66d11738.png)

 Select VM+Extensions
![image](https://user-images.githubusercontent.com/24598299/171523897-329fe004-7b61-4b35-83e1-be0e7ad137b6.png)

6.  Select Compute + OS

> Export

7.  Select Compute + Data Disks

> Export

8.  Select Configuration Checks Accelerated Netorking

![image](https://user-images.githubusercontent.com/24598299/171523918-0d397f3b-8cdc-479a-95e8-de0cf9f1d27d.png)
 Export

9.  Select Backup Backup List (It list the VM's with failed backups)

![image](https://user-images.githubusercontent.com/24598299/171523971-e4da488b-eb21-44d1-9f3e-872bd8808d82.png)

> Export

10. Select Load Balancer

> Configuration Checks -> Load Balancer Load -> Balancer Overview
![image](https://user-images.githubusercontent.com/24598299/171524044-31370517-529c-4e8c-859d-2a242e093528.png)

> Export

11. Select Application Gateway Overview

> Configuration Checks -> Application Gateway -> Application Gateway Overview
![image](https://user-images.githubusercontent.com/24598299/171524076-9629a539-be5e-41f8-9c56-69f7565fc123.png)

> Export

12. Select ANF Resources -- ANF List

> Configuration Checks -> Azure NetApp Files -> ANF Resources ANF List
![image](https://user-images.githubusercontent.com/24598299/171524110-ede3ee0f-ea53-40c0-a0aa-560ea90c8138.png)

> Export

# Appendix

## Azure Workbooks Access Control

Access control in workbooks refers to two things:

-   Access required to read data in a workbook. This access is
    controlled by standard [Azure
    roles](https://docs.microsoft.com/en-us/azure/role-based-access-control/overview) on
    the resources used in the workbook. Workbooks do not specify or
    configure access to those resources. Users would usually get this
    access to those resources using the [Monitoring
    Reader](https://docs.microsoft.com/en-us/azure/role-based-access-control/built-in-roles#monitoring-reader) role
    on those resources.

-   Access required to save workbooks

    -   Saving workbooks requires write privileges in a resource group
        to save the workbook. These privileges are usually specified by
        the [Monitoring
        Contributor](https://docs.microsoft.com/en-us/azure/role-based-access-control/built-in-roles#monitoring-contributor) role,
        but can also be set via the *Workbooks Contributor* role.

## Standard roles with workbook-related privileges

-   [Monitoring
    Reader](https://docs.microsoft.com/en-us/azure/role-based-access-control/built-in-roles#monitoring-reader) includes
    standard /read privileges that would be used by monitoring tools
    (including workbooks) to read data from resources.

-   [Monitoring
    Contributor](https://docs.microsoft.com/en-us/azure/role-based-access-control/built-in-roles#monitoring-contributor) includes
    general /write privileges used by various monitoring tools for
    saving items (including workbooks/write privilege to save shared
    workbooks). "Workbooks Contributor" adds "workbooks/write"
    privileges to an object to save shared workbooks.

-   For custom roles:

Add microsoft.insights/workbooks/write to save workbooks. For more
details, see the [Workbook
Contributor](https://docs.microsoft.com/en-us/azure/role-based-access-control/built-in-roles#monitoring-contributor) role.
