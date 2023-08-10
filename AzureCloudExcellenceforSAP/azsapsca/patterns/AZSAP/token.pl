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

sub checkTotemConfiguration {
	SDP::Core::printDebug('> checkTotemConfiguration', 'BEGIN');
	my $RCODE = 0;
	my $FILE_OPEN = 'ha.txt';
	my $SECTION = 'corosync.conf';
	my @CONTENT = ();
	my $RRP_MODE = 'none';
	my $RRP_RINGS = 0;
	my $TOKEN_VAL = 0;
	my $CONSENSUS_VAL = 0;


	if ( SDP::Core::getSection($FILE_OPEN, $SECTION, \@CONTENT) ) {
		foreach $_ (@CONTENT) {
			next if ( m/^\s*$/ ); # Skip blank lines
			if ( /^\s*token:\s+(.*)/ ) {
				$TOKEN_VAL = $1;
			} elsif  ( /^\s*consensus:\s+(.*)/ ) {
				$CONSENSUS_VAL = $1;
			} 
		}
		if ( $TOKEN_VAL  == 30000 ) {
		        SDP::Core::updateStatus(STATUS_SUCCESS, "Valid: cluster token=$TOKEN_VAL");
		} else {
			SDP::Core::updateStatus(STATUS_WARNING, "Invalid: token=$TOKEN_VAL, it should be 30000");
		}
	} else {
		SDP::Core::updateStatus(STATUS_ERROR, "ERROR: checkTotemConfiguration(): Cannot find \"$SECTION\" section in $FILE_OPEN");
	}
	SDP::Core::printDebug("< checkTotemConfiguration", "Returns: $RCODE");
	return $RCODE;
}

##############################################################################
# Main Program Execution
##############################################################################

SDP::Core::processOptions();
	checkTotemConfiguration();
SDP::Core::printPatternResults();

exit;
