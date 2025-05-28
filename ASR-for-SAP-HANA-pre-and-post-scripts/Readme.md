# Coordinating with SAP HANA for ASR to do application consistent replications 

When using ASR to replicate an SAP HANA system, to capture application consistent snapshots, ASR needs to coordinate with HANA to quiesce database activities before the snapshot, perform the workflow to capture the storage content, then remove the database snapshot.  The coordination between HANA and ASR is done via scripts.  Below are examples to demonstrate the foundation of the interaction.  Each HANA system serves a company's unique business process and the scripts can and likely do need additional modules and functions to meet those needs.  These additional capabilities are the responsibilities of the SAP HANA administrator.

License
This project is licensed under the MIT License. See the [LICENSE](https://github.com/Azure/SAP-on-Azure-Scripts-and-Utilities/blob/main/LICENSE) file for details.