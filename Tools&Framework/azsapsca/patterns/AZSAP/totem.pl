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
	PROPERTY_NAME_CLASS."=HAE",
	PROPERTY_NAME_CATEGORY."=Database",
	PROPERTY_NAME_COMPONENT."=Resource",
	PROPERTY_NAME_PATTERN_ID."=$PATTERN_ID",
	PROPERTY_NAME_PRIMARY_LINK."=META_LINK_TID",
	PROPERTY_NAME_OVERALL."=$GSTATUS",
	PROPERTY_NAME_OVERALL_INFO."=None",
	"META_LINK_TID=http://www.suse.com/support/kb/doc.php?id=7012121"
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

	if ( SDP::Core::getSection($FILE_OPEN, $SECTION, \@CONTENT) ) {
		foreach $_ (@CONTENT) {
			next if ( m/^\s*$/ ); # Skip blank lines
			if ( /^\s*rrp_mode:\s+(.*)/ ) {
				$RRP_MODE = $1;
			} elsif ( /\sringnumber:/ ) {
				$RRP_RINGS++;
			}
		}
		if ( $RRP_RINGS > 1 ) {
			if ( $RRP_MODE =~ m/active/ ) {
				SDP::Core::updateStatus(STATUS_ERROR, "Valid: rrp_mode=$RRP_MODE for $RRP_RINGS rings");
			} elsif ( $RRP_MODE =~ m/passive/ ) {
				SDP::Core::updateStatus(STATUS_ERROR, "Valid: rrp_mode=$RRP_MODE for $RRP_RINGS rings");
			} else {
				SDP::Core::updateStatus(STATUS_WARNING, "Invalid: rrp_mode=$RRP_MODE for $RRP_RINGS rings, should be rrp_mode=active/passive");
			}
		} elsif ( $RRP_RINGS == 1 ) {
			if ( $RRP_MODE =~ m/none/ ) {
				SDP::Core::updateStatus(STATUS_ERROR, "Valid: rrp_mode=$RRP_MODE for $RRP_RINGS ring");
			} else {
				SDP::Core::updateStatus(STATUS_WARNING, "Invalid: rrp_mode=$RRP_MODE for $RRP_RINGS ring, should be rrp_mode=none");
			}
		} else {
			SDP::Core::updateStatus(STATUS_ERROR, "No rrp rings found");
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
