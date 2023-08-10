#!/usr/bin/perl

# Title:       SBD Timeout Configuration Check
# Description: Compares the stonith timeout to the SBD wait times
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
use constant MAX_WATCHDOG => 120;
use constant MIN_TOTEM_TOKEN => 5000;

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
	"META_LINK_TID=http://www.suse.com/support/kb/doc.php?id=7011346",
	"META_LINK_MISC=http://www.suse.com/support/kb/doc.php?id=7009485"
);




my $TOTEM_TOKEN = 0;
my $SBD_MSGWAIT = 0;
my $SBD_WATCHDOG = 0;
my $STONITH_TIMEOUT = 60;

##############################################################################
# Local Function Definitions
##############################################################################

sub getTotemToken {
	SDP::Core::printDebug('> getTotemToken', 'BEGIN');
	my $RCODE = 0;
	my $FILE_OPEN = 'ha.txt';
	my $SECTION = 'corosync.conf';
	my @CONTENT = ();

	if ( SDP::Core::getSection($FILE_OPEN, $SECTION, \@CONTENT) ) {
		foreach $_ (@CONTENT) {
			next if ( m/^\s*$/ ); # Skip blank lines
			s/\s*//g; # remove all white space
			if ( /token:(.*)/i ) {
				$TOTEM_TOKEN = $1;
				SDP::Core::printDebug("  TOKEN", $TOTEM_TOKEN);
				last;
			}
		}
	} else {
		SDP::Core::updateStatus(STATUS_ERROR, "ERROR: getTotemToken(): Cannot find \"$SECTION\" section in $FILE_OPEN");
	}
	SDP::Core::printDebug("< getTotemToken", "Returns: $RCODE");
	return $RCODE;
}

sub getSBDwaits {
	SDP::Core::printDebug('> getSBDwaits', 'BEGIN');
	my $RCODE = 0;
	my $FILE_OPEN = 'ha.txt';
	my $SECTION = 'sbd -d .* dump';
	my @CONTENT = ();

	if ( SDP::Core::getSection($FILE_OPEN, $SECTION, \@CONTENT) ) {
		foreach $_ (@CONTENT) {
			next if ( m/^\s*$/ ); # Skip blank lines
			s/\s*//g; # remove all white space
			if ( /Timeout.*watchdog.*:/i ) {
				(undef, $SBD_WATCHDOG) = split(/:/, $_);
				SDP::Core::printDebug("  WATCHDOG", $SBD_WATCHDOG);
				$RCODE++;
			} elsif ( /Timeout.*msgwait.*:/i ) {
				(undef, $SBD_MSGWAIT) = split(/:/, $_);
				SDP::Core::printDebug("  MSGWAIT", $SBD_MSGWAIT);
				$RCODE++;
			}
			last if ( $RCODE > 1 ); # use the first sbd dump values found, regardless of the number of sbd partitions
		}
	} else {
		SDP::Core::updateStatus(STATUS_ERROR, "ERROR: getSBDwaits(): Cannot find \"$SECTION\" section in $FILE_OPEN");
	}
	SDP::Core::updateStatus(STATUS_ERROR, "ERROR: getSBDwaits(): Invalid SBD Metadata, Skipping") if ( $SBD_WATCHDOG == 0 && $SBD_MSGWAIT == 0 );
	SDP::Core::printDebug("< getSBDwaits", "Returns: $RCODE");
	return $RCODE;
}

sub getSTONITHwait {
	SDP::Core::printDebug('> getSTONITHwait', 'BEGIN');
	my $RCODE = 0;
	my $FILE_OPEN = 'ha.txt';
	my $SECTION = 'cibadmin -Q';
	my @CONTENT = ();
	my $HA_DOWN = 0;

	if ( SDP::Core::getSection($FILE_OPEN, $SECTION, \@CONTENT) ) {
		foreach $_ (@CONTENT) {
			next if ( m/^\s*$/ ); # Skip blank lines
			if ( /CIB failed.*connection failed/ ) {
				SDP::Core::printDebug('WARNING', "CIB Connection Failed, Checking cib.xml");
				$HA_DOWN = 1;
				last;
			}
			if ( /nvpair.*name=.*stonith-timeout.*value="(.*)"/ ) {
				$STONITH_TIMEOUT = $1;
				SDP::Core::printDebug("  CIB STONITH TIMEOUT", $STONITH_TIMEOUT);
				$RCODE++;
				last;
			}
		}
	} else {
		SDP::Core::updateStatus(STATUS_ERROR, "ERROR: getSTONITHwait(): Cannot find \"$SECTION\" section in $FILE_OPEN");
	}
	if ( $HA_DOWN ) {
		$SECTION = '/cib.xml$';
		if ( SDP::Core::getSection($FILE_OPEN, $SECTION, \@CONTENT) ) {
			foreach $_ (@CONTENT) {
				next if ( m/^\s*$/ ); # Skip blank lines
				if ( /nvpair.*name=.*stonith-timeout.*value="(.*)"/ ) {
					$STONITH_TIMEOUT = $1;
					SDP::Core::printDebug("  CIB.XML STONITH TIMEOUT", $STONITH_TIMEOUT);
					$RCODE++;
					last;
				}
			}
		} else {
			SDP::Core::updateStatus(STATUS_ERROR, "ERROR: getSTONITHwait(): Cannot find \"$SECTION\" section in $FILE_OPEN");
		}
	}
	if ( $RCODE ) {
		$STONITH_TIMEOUT =~ s/\D*//g;
	} else {
		SDP::Core::printDebug("  DEFAULT STONITH TIMEOUT", $STONITH_TIMEOUT);
	}
	SDP::Core::printDebug("< getSTONITHwait", "Returns: $RCODE");
	return $RCODE;
}

##############################################################################
# Main Program Execution
##############################################################################

SDP::Core::processOptions();
	getTotemToken();
	getSBDwaits();
	getSTONITHwait();
	my $CALC_STONITH_TIMEOUT = $SBD_MSGWAIT + ($SBD_MSGWAIT / 100 * 20);
	SDP::Core::printDebug("  WD/MW/STO", "$SBD_WATCHDOG/$SBD_MSGWAIT/$STONITH_TIMEOUT");
	SDP::Core::printDebug("  CALCULATED STO", $CALC_STONITH_TIMEOUT);
	SDP::Core::updateStatus(STATUS_CRITICAL, "Detected risk to SBD operations: Watchdog Timeout is $SBD_WATCHDOG, should be 60") if ( $SBD_WATCHDOG != 60 );
	SDP::Core::updateStatus(STATUS_CRITICAL, "Detected risk to SBD operations: Message Wait is SBD_MSGWAIT should be 120") if ( $SBD_MSGWAIT != 120 );
	SDP::Core::updateStatus(STATUS_WARNING, "The stonith-timeout may be insufficient for SBD operations") if ( $STONITH_TIMEOUT < $CALC_STONITH_TIMEOUT );
	SDP::Core::updateStatus(STATUS_CRITICAL, "Detected risk to SBD operations: Watchdog Timeout exceeds Message Wait") if ( $SBD_WATCHDOG >= $SBD_MSGWAIT );
	SDP::Core::updateStatus(STATUS_CRITICAL, "Detected risk to SBD operations: Message Wait exceeds STONITH Timeout") if ( $SBD_MSGWAIT >= $STONITH_TIMEOUT );
	SDP::Core::updateStatus(STATUS_WARNING, "Detected risk to SBD operations: Watchdog Timeout exceeds " . MAX_WATCHDOG) if ( $SBD_WATCHDOG > MAX_WATCHDOG );
	SDP::Core::updateStatus(STATUS_WARNING, "Detected risk to SBD operations: Totem Token is $TOTEM_TOKEN, less than recommended " . MIN_TOTEM_TOKEN) if ( $TOTEM_TOKEN < MIN_TOTEM_TOKEN );
	SDP::Core::updateStatus(STATUS_SUCCESS, "No SBD operation risks found, checked watchdog timeout and message wait") if ( $GSTATUS < STATUS_ERROR );
SDP::Core::printPatternResults();

exit;


