# automatic SAP HANA temporary file system configuration

This RPM package contains a script that automatically configures the temporary file systems required for SAP HANA Fast Restart.

The script is used to automatically change the temporary file systems, e.g. during a VM resize where the number of NUMA nodes can change.

It automatically updates the global.ini file for the system as well.


## Files in RPM

* /etc/sysconfig/set_hana_tmpfs.config
* /usr/lib/systemd/system/set_hana_tmpfs.service
* /usr/sbin/set_hana_tmpfs

## Command file parameters

```
    OPTION:
     --help           show help
     --version        show version
     --check          
     --init           create/apply/update Hana tmpfs mountpoints based on numa at boot. Output goes to messages
     --apply          create/apply/update Hana tmpfs mountpoints based on numa
     --show           check if solution can be applied
    
```

## Config File Sample

To specifcy the required paramters please look at /etc/sysconfig/set_hana_tmpfs.config parameter file, which by default contains these options:

```
#Config values

#SAP System ID:
SID="I"

# %of memeory to be used for Hana tmpfs.
HANATMPMEMSIZE="100" # % value of memory - calculated on the fly

#Add own additional mount options for mounting hanatmps
# example - ADDMNTOPTNS="uid=5000,gid=1000,mode=1770"
ADDMNTOPTNS=""

#Short disable of script
SCRACTIVE="Y"        #If Y - then script works otherwise will not do anything

#Create debugging information - if needed by author
#Debug files are created in /var/log
DEBUG="X"  # "DEBUG"
```