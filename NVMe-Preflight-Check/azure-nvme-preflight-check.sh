#!/bin/bash

########################################################################
#   Copyright (c) Microsoft Corporation.
#   Licensed under the MIT license.
########################################################################
#
#   azure-nvme-preflight-check.sh
#
#   The script checks if the requirements to switch to NVMe enabled
#   virtual machines are met
#
########################################################################


########################################################################
# function check_NVME_initrd
#
# function checks if NVMe driver is already part of initrd
# if NVMe driver is not part of initrd the operating system is not able
# to start
#
# TODO add more distributions like
# - Oracle Linux
# - ???
########################################################################
check_NVMe_initrd () {

    find_distro=`cat /etc/os-release |sed -n 's|^ID="\([a-z]\{4\}\).*|\1|p'`  

    if [ -f /etc/redhat-release ] ; then
        # Distribution is Red hat
        lsinitrd /boot/initramfs-$(uname -r).img|grep nvme > /dev/null 2>&1
        if [ $? -ne 0 ]; then
            # NVMe module is not loaded in initrd/initramfs
            echo -e "ERROR  NVMe Module is not loaded in the initramfs image."
            echo -e "\t- Please run the following command on your instance to recreate initramfs:"
            echo -e '\t# sudo dracut -f -v'
        else
            echo -e "OK     NVMe Module loaded in initramfs image."
        fi
    
    elif [[ "${find_distro}" == "sles" ]] ; then
        # Distribution is SUSE Linux
        lsinitrd /boot/initrd-$(uname -r)|grep nvme > /dev/null 2>&1
        if [ $? -ne 0 ]; then
            # NVMe module is not loaded in initrd/initramfs
            echo -e "ERROR  NVMe Module is not loaded in the initramfs image."
            echo -e "\t- Please run the following command on your instance to recreate initramfs:"
            echo -e '\t# sudo dracut -f -v'
        else
            echo -e "OK     NVMe Module loaded in initramfs image."
        fi
        
    elif [ -f /etc/debian_version ] ; then
        # Distribution is debian based means Debian/Ubuntu
        lsinitramfs /boot/initrd.img-$(uname -r)|grep nvme > /dev/null 2>&1
        if [ $? -ne 0 ]; then
            # NVMe module is not loaded in initrd/initramfs
            echo -e "ERROR  NVMe Module is not loaded in the initramfs image."
            echo -e "\t- Please run the following command on your instance to recreate initramfs:"
            echo -e '\t# sudo update-initramfs -c -k all'
        else
            echo -e "OK     NVMe Module loaded in initramfs image."
        fi

    else 
        echo -e "\n\nUnsupported OS for this script."
        echo -e "\n\n------------------------------------------------"
        exit 1
    fi

}
########################################################################


########################################################################
# function check_fstab
#
# function checks if fstab is ready to switch to NVMe VMs
# in fstab /dev/sd* or /dev/disk/azure/* is not allowed because NVMe
# enabled VMs will have new device names
# 
# the function converts the fstab file to use UUID
#
# TODO: add /dev/disk/azure
#
########################################################################
check_fstab () {
    time_stamp=$(date +%F-%H:%M:%S)
    cp /etc/fstab /etc/fstab.backup.$time_stamp
    cp /etc/fstab /etc/fstab.modified.$time_stamp

    # running replacement for /dev/sd* devices
    sed -n 's|^/dev/\(sd[a-z]*[0-9]*\).*|\1|p' </etc/fstab >/tmp/device_names   # Stores all /dev/sd* entries from fstab into a temporary file
    while read LINE; do
            # For each line in /tmp/device_names
            UUID=`ls -l /dev/disk/by-uuid | grep "$LINE" | sed -n 's/^.* \([^ ]*\) -> .*$/\1/p'` # Sets the UUID name for that device
            if [ ! -z "$UUID" ]
            then
                sed -i "s|^/dev/${LINE}|UUID=${UUID}|" /etc/fstab.modified.$time_stamp               # Changes the entry in fstab to UUID form
            fi
    done </tmp/device_names

    # running replacement for /dev/disk/azure/scsi1/lun* devices
    sed -n 's|^/dev/disk/azure/scsi1/\(lun[0-9]*\).*|\1|p' </etc/fstab >/tmp/device_names   # Stores all /dev/disk/azure/scsi1/lun* entries from fstab into a temporary file
    while read LINE; do
            # For each line in /tmp/device_names
            # first get the real device from azure device

            REALDEVICE=`realpath /dev/disk/azure/scsi1/${LINE} | sed 's+/dev/++g'`

            UUID=`ls -l /dev/disk/by-uuid | grep "$REALDEVICE" | sed -n 's/^.* \([^ ]*\) -> .*$/\1/p'` # Sets the UUID name for that device
            if [ ! -z "$UUID" ]
            then
                sed -i "s|^/dev/disk/azure/scsi1/${LINE}|UUID=${UUID}|" /etc/fstab.modified.$time_stamp               # Changes the entry in fstab to UUID form
            fi
    done </tmp/device_names



    if [ -s /tmp/device_names ]; then

        echo -e "\n\nERROR  Your fstab file contains device names. Mount the partitions using UUID's before changing an instance type to NVMe.\n"                                                         

        printf "Enter y to replace device names with UUID in /etc/fstab file to make it compatible for NVMe block device names.\nEnter n to keep the file as-is with no modification (y/n) "
        read RESPONSE;
        case "$RESPONSE" in
            [yY]|[yY][eE][sS])                                              # If answer is yes, keep the changes to /etc/fstab
                    echo "Writing changes to /etc/fstab..."
                    echo -e "\n\n***********************"
                    cp /etc/fstab.modified.$time_stamp /etc/fstab
                    echo -e "***********************"
                    echo -e "\nOriginal fstab file is stored as /etc/fstab.backup.$time_stamp"
                    rm /etc/fstab.modified.$time_stamp
                    ;;
            [nN]|[nN][oO]|"")                                               # If answer is no, or if the user just pressed Enter
                    echo -e "Aborting: Not saving changes...\nPrinting correct fstab file below:\n\n"                  # don't save the new fstab file
                    cat /etc/fstab.modified.$time_stamp
                    rm /etc/fstab.backup.$time_stamp
                    rm /etc/fstab.modified.$time_stamp
                    ;;
            *)                                                              # If answer is anything else, exit and don't save changes
                    echo "Invalid Response"                                 # to fstab
                    echo "Exiting"
                    rm /etc/fstab.backup.$time_stamp
                    rm /etc/fstab.modified.$time_stamp
                    exit 1
                    echo -e "------------------------------------------------"
                    ;;
    
        esac
        rm /tmp/device_names

    else 
        rm /etc/fstab.backup.$time_stamp
        rm /etc/fstab.modified.$time_stamp
        echo -e "\n\nOK     fstab file looks fine and does not contain any device names. "
    fi

}

########################################################################


# Main code starts from here

PATH=/bin:/sbin:/usr/bin:/usr/sbin

if [ `id -u` -ne 0 ]; then                                              # Checks to see if script is run as root
        echo -e "------------------------------------------------"
        echo -e "\nThis script must be run as root" >&2                 # If it isn't, exit with error
        echo -e "\n------------------------------------------------"
        exit 1
fi

(grep 'nvme' /boot/System.map-$(uname -r)) > /dev/null 2>&1
if [ $? -ne 0 ]
    then
    # NVMe modules is not built into the kernel
    (modinfo nvme) > /dev/null 2>&1
    if [ $? -ne 0 ]
        then
        # NVMe Module is not installed. 
        echo -e "------------------------------------------------\nERROR  NVMe Module is not available on your instance. \n\t- Please install NVMe module before changing your instance type to NVMe. Look at the following link for further guidance:"
        echo -e "\t> https://learn.microsoft.com/en-us/azure/virtual-machines/enable-nvme-interface"

    else
        echo -e "------------------------------------------------\n"
        echo -e "OK     NVMe Module is installed and available on your instance"
        check_NVMe_initrd                # Calling function to check if NVMe module is loaded in initramfs. 
    fi
else
    # NVMe modules is built into the kernel
    echo -e "------------------------------------------------\n"
    echo -e "OK     NVMe Module is installed and available on your instance"
fi

check_fstab
echo -e "\n------------------------------------------------"