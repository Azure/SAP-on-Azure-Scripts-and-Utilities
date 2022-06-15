#!/usr/bin/perl

# Title:       Totem Configuration
# Description: Checks totem configuration in corosync.conf
# Modified:    2013 Jun 21

##############################################################################
#  Copyright (C) 2013 SUSE LLC
##############################################################################
#
#  This program is free software; you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation; version 2 of the License.
#
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#
#  You should have received a copy of the GNU General Public License
#  along with this program; if not, see <http://www.gnu.org/licenses/>.

#  Authors/Contributors:
#   Jason Record (jrecord@suse.com)

##############################################################################

##############################################################################
# Module Definition
##############################################################################

use strict;
use warnings;
use SDP::Core;
use SDP::SUSE;

##############################################################################
# Overriden (eventually or in part) from SDP::Core Module
##############################################################################

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




##############################################################################
# Local Function Definitions
##############################################################################

sub checkSBDConfiguration {
	SDP::Core::printDebug('> checkSBDConfiguration', 'BEGIN');
	my $RCODE = 0;
	my $FILE_OPEN = 'ha.txt';
	my $SECTION = '/etc/sysconfig/sbd';
	my @CONTENT = ();
	my $SBD_PACEMAKER = '';
	my $SBD_STARTMODE = '';

	if ( SDP::Core::getSection($FILE_OPEN, $SECTION, \@CONTENT) ) {
		foreach $_ (@CONTENT) {
			next if ( m/^\s*$/ ); # Skip blank lines
			if ( /SBD_PACEMAKER=(.*)/i ) {
			    $SBD_PACEMAKER = $1;
			    SDP::Core::printDebug('SBD_PACEMAKER should be yes', "Found");
			} elsif  ( /SBD_STARTMODE=(.*)/i ) {
			    $SBD_STARTMODE = $1;
			    SDP::Core::printDebug('SBD_STARTMODE should be always', "Found");
			} 
		}
                SDP::Core::updateStatus(STATUS_WARNING, "SBD_PACEMAKER should be yes") if ( $SBD_PACEMAKER =~ m/yes/i );
                SDP::Core::updateStatus(STATUS_WARNING, "SBD_STARTMODE should be always") if ( $SBD_STARTMODE =~ m/always/i );
		SDP::Core::updateStatus(STATUS_SUCCESS, "No SBD_PACEMAKER or SBD_STARTMODE problems found") if ( $GSTATUS < STATUS_ERROR );
	} else {
		SDP::Core::updateStatus(STATUS_ERROR, "ERROR: checkTotemConfiguration(): Cannot find \"$SECTION\" section in $FILE_OPEN");
	}
	SDP::Core::printDebug("< checkCliBanConfiguration", "Returns: $RCODE");
	return $RCODE;
}

##############################################################################
# Main Program Execution
##############################################################################

SDP::Core::processOptions();
	checkSBDConfiguration();
SDP::Core::printPatternResults();

exit;
