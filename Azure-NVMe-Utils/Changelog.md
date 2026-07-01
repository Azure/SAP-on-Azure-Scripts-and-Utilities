# Changelog

This file contains the change log for the PowerShell script.

## Version 2026070101

* adding a check if Azure RunCommand was successfully executed

## Version 2026061101

* adding warning message for Windows systems when converting from tempdisk to non-tempdisk VMs for swap space configuration

## Version 2026060501

* fixing issue where script would exit during move back to SCSI

## Version 2026052501

* adding new Windows fix script to make migrations to v6 and newer possible
* adding new prepare script for Windows
* changing order for Gen1 check to be earlier
* changing the OS disk capabilities update from REST call to Update-AzDisk
* removing Get-AccessToken authentication block
* added new Azure feature VMTempDiskResizePreview to resize VMs with tempdisk to VMs without tempdisk
* adding manual preparation script for Windows

## Version 2026011301

* adding check if VM Agent is deployed for using Azure RunCommands
* add message on potential problem with Windows VMs

## Version 2025111001

* adding check for Azure Disk Encryption (Linux) thanks to @jonathanbrenes
* fixing regex to include partitions thans to @resilience777

## Version 2025093001

* Linux VMs supports tempdisk to non-tempdisk and vice-versa

## Version 2025090501

* adding resource group to Get-AzDisk in case you have the same disk name in multiple RGs/regions

## Version 2025090201

* fixing Statuses, Get-AzVM with Resource Group returns statuses, Get-AzVM without Resource Group gets PowerState

## Version 2025082601

* moving from Statuses to PowerState to check VM status

## Version 2025072801

* fixing issue for RHEL 8.X having rhel as ID instead of redhat

## Version 2025062705

* fixing an issue in bash script

## Version 2025062704

* fixing an issue where the script would not stop on Linux if there is an error during OS check

## Version 2025062703

* when using Linux and not using FixOperatingSystem the script would not stop if the OS is not ready

## Version 2025062702

* adding sleepseconds parameter
* fixing issues with new IgnoreOSCheck / FixOperatingSystem parameter combinations
* updated documentation

## Version 2025062701

* add new parameter IgnoreOSCheck, this will not check if VM is running and if the OS is ready to convert
* in CloudShell the AccessToken is now a SecureString, converting it for REST call

## Version 2025052601

* add message for v6 SKUs
* add fix for resource disk size comparison
* update the module check to include individual modules instead of "Az"
* add version number and version check
