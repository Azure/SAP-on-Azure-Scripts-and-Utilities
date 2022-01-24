# Changelog

## Version 2022012401

* fixing IC checks for APP and ASCS servers

## Version 2022012101

* fixing a typo in fence_kdump check
* fixing a case there LVM is used on partitions instead of full disk (e.g. /dev/sdc1 instead of /dev/sdc)
* fixing IOPS check, only applies for Ultra Disk

## Version 2022011903

* adding softdog checks for SLES/SBD

## Version 2022011902

* adding fence_kdump as optional check

## Version 2022011901

* adding info and warning as errorcatory in json and ps1

## Version 2022011801

* adding ASCS HA checks

## Version 2022011101

* fixing description for CPU softlockup check HDB-OS-SLES-0005

## Version 2022011001

* added support for HANA multi disk scenario
* added support for /dev/sdX devices instead of LVM
* added section at the end for copy/paste data for further internal analysis
* added support for D(d)sv4 and E(d)sdv5
* added version number to script and json and compare values when script starts
* added error handling for SSH connectivity in case VM is down
* added the HDB-FS file system checks to documentation
* fixed a RedHat Cluster information collection command

## Version 2022010401

* Initial V2 version
* support for DB, ASCS and app servers
* HTML output for better user expierience
* every check has a unique check id
* updated check engine with more granular view (e.g. adding support for special OS releases)
* documented all checks on GitHub
* data collection engine to get better overview of system
* added support for Db2 and Oracle
* added support for Oracle Linux
* new kernel check function
* foundation for adding Windows support in the future
