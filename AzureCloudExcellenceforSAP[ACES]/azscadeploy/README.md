# azscadeploy

## Deploy an sca in azure with Terraform and Ansible

To deploy SCA, do the following.  It is convenient to use cloudshell bash for this:

```bash
git clone https://github.com/rsponholtz/azscadeploy.git
cd azscadeploy
./scadeploy.sh
```


to remove, do

```bash
terraform destroy 
```

to ssh to your VM, do

```bash
ssh -i pkey.out azureuser@`cat scaIP.txt`
```

you can generate a supportconfig file on your SUSE virtual machines by doing

```bash
hana1:~ # supportconfig
```

This puts the supportconfig output file in /var/log/scc_<hostname>...txz.  You'll need to transfer this file to your sca machines for analysis.  An efficient way to do this is to use a storage account in Azure.  You'll want to create a storage account with a blob container, and generate a shared access signature for your storage account.  After installing [azcopy](https://docs.microsoft.com/en-us/azure/storage/common/storage-use-azcopy-v10), you can upload your supportconfig to the storage account like this:

```bash
azcopy cp "/var/log/scc_hana*.txz" "https://<storage-account-name>.blob.core.windows.net/supportconfigs?sp=rfaeddl&st=2021-09-28T23:22:28Z&se=2022-09-19T07:22:28Z&spr=https&sv=2020-08-04&sr=c&sig=JEQF%2DIdp5Wz0DkbjQDJUv%2Bw6zzn%2HGFUEhhvxaHHGvP%2BM%3D"
```

The next step will be getting the supportconfig file to your SCA appliance.  If it's in your storage account, you can download it using azcopy - this will be the most efficient mechanism.  azcopy should be pre-installed on your SCA vm.  Alternatively, you can upload supportconfig files to your VM with

```bash
scp <supportconfig file> -i pkey.out azureuser:<your ip address>:~/
```

to run the supportconfig analyzer on your supportconfig file, do

```bash
scatool scc_<your file name>.txz
```

This will output a HTML file that you will have to download or put into your storage account for viewing.

## Development of new SCA patterns

To start developing new patterns, you should fork the Azure SCA pattern repo (https://github.com/rsponholtz/azsapsca.git), and then clone your repo to your own SCA appliance.  Develop new pattern tests, commit to your repo, and then submit them as pull requests.

There is a program for testing individual SCA patterns called "pat" which is located in /usr/bin/pat.  There is an error in this program though, so sudo to root, copy to your home directory and edit the script.  Find the section that looks like this:

```bash
[[ ! -x $PATFULL ]] && { ((ERR_MODE++)); ((RET_FAT++)); }
if grep
 $PATFULL &>/dev/null
then
        ((RET_FAT++))
        ((ERR_DOS++))
fi
```

and comment out all of these lines with the ***#*** character.

For testing of pattern rules, you need to move one or more supportconfig archive files onto your SCA appliance, and then extract them into the /var/log/archives directory.

Then use the pat program to test a pattern test like this - I'm using the cli-ban.pl pattern in this example:

```bash
cp /usr/lib/sca/patterns/local/cli-ban.pl .
./pat cli-ban.pl
```

you should get an output that looks like this:

```
##########################################################################
# PAT - SCA Pattern Tester v1.0.11
##########################################################################
Archive Directory:      /var/log/archives
Pattern Directory:      /usr/lib/sca/patterns
SCA Library Directory:  /usr/lib/sca
Perl Libraries:         :/usr/lib/sca/perl/

Running: /root/cli-ban.pl  -p /var/log/archives/scc_hana1_211108_2323
META_CLASS=AZSAP|META_CATEGORY=Database|META_COMPONENT=Resource|PATTERN_ID=cli-ban.pl|PRIMARY_LINK=META_LINK_TID|OVERALL=0|OVERALL_INFO=No cli-ban or cli-prefer location constraints found |META_LINK_TID=https://docs.microsoft.com/en-us/azure/virtual-machines/workloads/sap/high-availability-guide-suse-pacemaker#cluster-installation
Returns: 0, Overall: 0
--------------------------------------------------------------------------


##[ Summary ]#############################################################

Archive Directory:     /var/log/archives
SCA Library Directory: /usr/lib/sca
Archive(s) Tested:     1
Pattern Tested:        /root/cli-ban.pl
  Fatal: 0, Err: 0, Ign: 0, Cri: 0, Wrn: 0, Pro: 0, Rec: 0, Good: 1

##########################################################################
```

When a pattern is complete you can put it in the library of patterns on your own SCA at /var/lib/sca/patterns/local, and you should submit the pattern as a pull request on this repo.

## Pattern samples

Let's look at the pattern checks you can create.  It is possible to write these patterns in perl, bash or python with the built-in libraries, and you could use anything else as long as you can parse the supportconfig files and create the correct output.  

While there is not any documentation on the support libraries for SCA analysis, you can use [the source code](https://github.com/openSUSE/sca-patterns-base.git.

This is a pattern written in perl.  It checks whether there are any cli-ban or cli-prefer location constraints in the cluster configuration.

```perl
#!/usr/bin/perl

# Title:      CLI-ban check
# Description: Checks cluster setup for any cli-ban or cli-prefer constraints
# Modified:    2021 Oct 28

use strict;
use warnings;
use SDP::Core;
use SDP::SUSE;

@PATTERN_RESULTS = (
        PROPERTY_NAME_CLASS."=AZSAP",
        PROPERTY_NAME_CATEGORY."=Database",
        PROPERTY_NAME_COMPONENT."=Resource",
        PROPERTY_NAME_PATTERN_ID."=$PATTERN_ID",
        PROPERTY_NAME_PRIMARY_LINK."=META_LINK_TID",
        PROPERTY_NAME_OVERALL."=$GSTATUS",
        PROPERTY_NAME_OVERALL_INFO."=None",
        "META_LINK_TID=https://docs.microsoft.com/en-us/azure/virtual-machines/workloads/sap/high-availability-guide-suse-pacemaker#cluster-installation"
);


sub checkCliBanConfiguration {
        SDP::Core::printDebug('> checkCliBanConfiguration', 'BEGIN');
        my $RCODE = 0;
        my $FILE_OPEN = 'ha.txt';
        my $SECTION = 'crm configure show';
        my @CONTENT = ();
        my $CONSTRAINT_COUNT = 0;

        if ( SDP::Core::getSection($FILE_OPEN, $SECTION, \@CONTENT) ) {
                foreach $_ (@CONTENT) {
                        next if ( m/^\s*$/ ); # Skip blank lines
                        if ( /cli-ban/i ) {
                            SDP::Core::printDebug('cli-ban location constraint', "Found");
                            $CONSTRAINT_COUNT++;
                        } elsif  ( /cli-prefer/i ) {
                            SDP::Core::printDebug('cli-prefer location constraint', "Found");
                            $CONSTRAINT_COUNT++;
                        }
                }
                if ( $CONSTRAINT_COUNT > 0 ) {
                    SDP::Core::updateStatus(STATUS_WARNING, "Found: cli-ban or cli-prefer location constraints");
                } else {
                    SDP::Core::updateStatus(STATUS_SUCCESS, "No cli-ban or cli-prefer location constraints found ")
                }

        } else {
                SDP::Core::updateStatus(STATUS_ERROR, "ERROR: checkCliBanConfiguration(): Cannot find \"$SECTION\" section in $FILE_OPEN");
        }
        SDP::Core::printDebug("< checkCliBanConfiguration", "Returns: $RCODE");
        return $RCODE;
}

SDP::Core::processOptions();
        checkCliBanConfiguration();
SDP::Core::printPatternResults();

exit;
```

Here is an example of another pattern in python.  This pattern simply checks whether tcp_timestamps is turned off (i.e. value zero):

```python
#!/usr/bin/python3

# Title:       Check for tcp timestamp value
# Description: make sure tcp timestamp value is correct
# Modified:    2021 Nov 3
#
import os
import Core

META_CLASS = "AZSAP"
META_CATEGORY = "Kernel"
META_COMPONENT = "Network"
PATTERN_ID = os.path.basename(__file__)
PRIMARY_LINK = "META_LINK_TID"
OVERALL = Core.WARN
OVERALL_INFO = "NOT SET"
OTHER_LINKS = "META_LINK_TID=https://docs.microsoft.com/en-us/azure/virtual-machines/workloads/sap/sap-hana-high-availability#manual-deployment"

Core.init(META_CLASS, META_CATEGORY, META_COMPONENT, PATTERN_ID, PRIMARY_LINK, OVERALL, OVERALL_INFO, OTHER_LINKS)

try:
    fileOpen = "env.txt"
    section = "/sbin/sysctl -a"
    VALUE = -1
    content = {}

    if Core.getSection(fileOpen, section, content):
        for line in content:
            if "net.ipv4.tcp_timestamps" in content[line]:
                RP_LIST = content[line].split('=')
                VALUE = int(RP_LIST[1].strip())

    if (VALUE == 0):
        Core.updateStatus(Core.SUCC , "tcp_timestamps is correctly zero");
    else:
        Core.updateStatus(Core.CRIT, "tcp_timestamps should be zero");

except Exception as error:
        Core.updateStatus(Core.ERROR, "Outside the network scope: " + str(error))

Core.printPatternResults()
```
