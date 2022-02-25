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
