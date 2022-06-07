# Azure Deployment Checklist for SAP

# Introduction:

The ACES Deployment Checklist for SAP is a program management utility to
track customer SAP Migrations against conformance to Best Practices.
Best Practice is defined as a tried and tested approach to safeguard SAP
migrations to Azure and reduce risk to our customers. The Deployment
checklist was initially created based on lessons learnt from early SAP
to Azure migrations.

MSFT published the deployment checklist here: [SAP workload planning and
deployment checklist - Azure Virtual Machines \| Microsoft
Docs](https://docs.microsoft.com/en-us/azure/virtual-machines/workloads/sap/sap-deployment-checklist)

As part of the ACES, the documented checklist was used as a baseline to
create a conformance tracker, with scoring against expected
deliverables. This allows customers and partners an 'at-a-glance' view
of how their project is tracking against published best practices.

![image](https://user-images.githubusercontent.com/24598299/171528609-43cddd20-bdbe-435b-8260-90d5eedbd5d0.png)


# Prerequisites

To gain the best possible benefit from the ACES Deployment Checklist,
there are a few considerations to plan and implement before using the
checklist in customer projects.

## Project Phases and Milestones

The deployment Checklist utilizes phases. These phases do not always map
1:1 with customer projects. When planning your safeguarding engagement
with your customer, it is very important to map the project milestones
to the deployment checklist phases.

![image](https://user-images.githubusercontent.com/24598299/171529222-f0dc6e06-76c5-4ac4-a7ce-02feaaca31e7.png)


## Engagement Model

The Safeguarding process is a shared responsibility between the Azure
Global SAP Deployment Engineering team and the Customer Success Unit.
The recommended engagement model is for the Deployment Engineering PM
and the SAP CSA to work together and review the checklist at its current
version and identify areas that are not applicable or not relevant to
our specific customer project. For example, if your customer is
deploying S/4HANA on Azure, with nor Oracle in the landscape, then
references to Oracle can be marked at 'Not Applicable' in the checklist.

During early phases in the project, especially during reviews of
designs, migration approaches and sizing approaches, it is recommended
to **update scoring at once a month**.

It has worked well on early engagement where the tracker was
demonstrated to customers and SI's so that they understand how this
project management utility can help them identify areas where they veer
away from best practices, and also highlights potential risks to their
project.

## Interactive Scoring

Scoring each expected deliverable against best practices, should not be
done in isolation (i.e. just between Engineering and CSU), but should
rather incorporate efforts between MSFT, Customer and Parter.

## Identify and Communicate Gaps

Please note that the checklist is a living document and tool, and it is
likely that there might be some gaps in the framework. Specific customer
projects and solutions might not all be covered in the checklist. Please
be conscious of this fact, and if any gaps are identified, please note
that you have full autonomy to add those. For example, if your customer
is deploying ANF, and there are no best practises to score or consider,
then please add those deliverables or considerations to the checklist.
Also ensure that the SAP Deployment Engineering PM feeds back these gaps
so that they can be incorporated in future versions.

# Scoring: Practical Examples

The checklist scores expected deliverables, configurations and
considerations (these are referred to as checklist line items) across
various phases of a SAP to Azure Migration. Each line item can be scored
as follows:

**Fully Conformant** -- Matches expectations fully. No deviation from
best practice and decisions have been endorsed by MSFT, the Customer,
and the partner.

For example:

![image](https://user-images.githubusercontent.com/24598299/171528691-879a7868-ee39-400a-990f-3ef594a38e6a.png)

**Partially Conformant** -- the line item matches to some extend best
practises or recommendations but require further investigations and
potentially require more information to mark the item as fully
conformant. In some cases, lines can also be marked partially conformant
if conscious decision are made to veer away from suggested
recommendations

For example:

![image](https://user-images.githubusercontent.com/24598299/171528711-15e37c8a-e0c0-46f3-a00e-158b95931554.png)

**Non-Conformant** -- line items can be marked non-conformant if a
deliverable or recommendation is omitted or not adhered to. When marking
items as non-conformant, please ensure to use the 'Comments' column to
record any decisions that are scored non-conformant.

For example:

![image](https://user-images.githubusercontent.com/24598299/171528730-6c0f93f7-4816-4275-8d4b-833cb154ca0e.png)

**Not Applicable** -- line items could be marked not-applicable if they
are not relevant to the customer specific project or solution. Items
marked as Not Applicable, does not influence the overall conformance
score in the Project Management Dashboard.

For Example:

![image](https://user-images.githubusercontent.com/24598299/171528749-9ed5715d-0c34-424e-ae03-cca8eb352812.png)
