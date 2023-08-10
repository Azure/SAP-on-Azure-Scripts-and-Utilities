# Operational Best Practices

# Introduction

This is a collection of hints for managing (mostly) Linux systems. These have resulted from our experience with Linux in Azure, but most are applicable to any scenario.

# Linux Administration Practices

1. The Microsoft documentation for SAP on Azure is a great baseline for configurations.  We recommend using those settings and operations unless there is a very good reason not to.  When these deviations are made, it’s useful to keep a log of them, and why this deviation was made.

1.	For network volumes, it’s best to use the Linux automounter, rather than the fstab.  This is documented in the Microsoft SAP on Azure documentation.

1.	Do not use “sudo su - “ to change to root - use the sudo "command".  Also, make sure that the sudo command is logging everything that is done.

1.	Administrators should log into the VMs as their own personal user IDs and use “sudo <command>” to do administrative activities

# Terminal Sessions

1.	Within terminal sessions, it is useful to use headings, colors, etc. to differentiate various environments, SIDs, etc..  Without that, it is very easy to become confused as to which system you are working with.

1.	The tmux program is useful for working with multiple sessions within a single SSH login.  With this tool, it's possible to start long-running sessions, disconnect from ssh and reconnect later.

1.	Review system log files for errors regularly.  A monitoring system such as Azure Log Analytics or Splunk can help with automated identification of issues or unexpected messages.



# Linux Command Shell

1. Make sure you are actually using the shell that you think you have.  
You can use this command to print the shell name: 
```bash
echo "$SHELL"
```

	There are differences between bash, sh, csh, ksh, etc. that can impact shell scripts and your terminal experience.  You can change your login shell using the chsh command.

1. Shell scripts should start with a line like this to make sure the desired shell processor is used:
	
```bash
#!/bin/bash
```

1. Review the command completion and editing commands for your shell.  Proper use of these features can improve your terminal experience dramatically.

# NFS Management

1.	Use the "chatter +i <mountpoint>" command for any NFS mount points.  This this makes the mount point “immutable”, and will make sure that files are not written to the local volume that should be on the NFS volume.

1.	If any changes are made to the fstab, do the following:

	* mount -a # this mounts all volumes in the fstab, and will allow you to make sure you haven't typed anything wrong in the fstab
	* reboot the VM
	* make sure that all of your volumes are mounted

1.	It is ok to mount subdirectories of an NFS volume.  However, when you do that, never delete the mounted subdirectory – this will cause all mounts of the subdirectory to fail, or to be left in an inconsistent state.

1.	Never use the “umount -l” command.  This is meant to be used when you are going to reboot the machine very soon.  However, it’s much better to find the processes that are using a volume to be unmounted using the fuser command, and kill those (or remediate as appropriate).
