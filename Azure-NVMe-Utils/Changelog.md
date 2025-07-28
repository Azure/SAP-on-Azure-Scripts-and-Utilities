# Changelog

This file contains the change log for the PowerShell script.

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
