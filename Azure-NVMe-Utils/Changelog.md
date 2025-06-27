# Changelog

This file contains the change log for the PowerShell script.

## Version 2025062701

* add new parameter IgnoreOSCheck, this will not check if VM is running and if the OS is ready to convert
* in CloudShell the AccessToken is now a SecureString, converting it for REST call

## Version 2025052601

* add message for v6 SKUs
* add fix for resource disk size comparison
* update the module check to include individual modules instead of "Az"
* add version number and version check
