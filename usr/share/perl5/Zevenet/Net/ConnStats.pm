#!/usr/bin/perl
###############################################################################
#
#    Zevenet Software License
#    This file is part of the Zevenet Load Balancer software package.
#
#    Copyright (C) 2014-today ZEVENET SL, Sevilla (Spain)
#
#    This program is free software: you can redistribute it and/or modify
#    it under the terms of the GNU Affero General Public License as
#    published by the Free Software Foundation, either version 3 of the
#    License, or any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU Affero General Public License for more details.
#
#    You should have received a copy of the GNU Affero General Public License
#    along with this program.  If not, see <http://www.gnu.org/licenses/>.
#
###############################################################################

use strict;

=begin nd
Function: getConntrack

	Get the connections list.

Parameters:
	orig_src - 
	orig_dst - 
	reply_src - 
	reply_dst - 
	protocol - 

Returns:
	list - Filtered netstat array.

See Also:
	Output to: <getNetstatFilter>

	<farm-rrd.pl>, zapi/v?/system_stats.cgi

	<getBackendEstConns>, <getFarmEstConns>, <getBackendSYNConns>, <getFarmSYNConns>

	<getL4BackendEstConns>, <getL4FarmEstConns>, <getL4BackendSYNConns>, <getL4FarmSYNConns>
	<getHTTPBackendEstConns>, <getHTTPFarmEstConns>, <getHTTPBackendTWConns>, <getHTTPBackendSYNConns>, <getHTTPFarmSYNConns>, <getGSLBFarmEstConns>
=cut
sub getConntrack    # ($orig_src, $orig_dst, $reply_src, $reply_dst, $protocol)
{
	my ( $orig_src, $orig_dst, $reply_src, $reply_dst, $protocol ) = @_;

	# remove newlines in every argument
	chomp ( $orig_src, $orig_dst, $reply_src, $reply_dst, $protocol );

	# add iptables options to every available value
	$orig_src  = "-s $orig_src"  if ( $orig_src );
	$orig_dst  = "-d $orig_dst"  if ( $orig_dst );
	$reply_src = "-r $reply_src" if ( $reply_src );
	$reply_dst = "-q $reply_dst" if ( $reply_dst );
	$protocol  = "-p $protocol"  if ( $protocol );

	my $conntrack = &getGlobalConfiguration('conntrack');
	my $conntrack_cmd =
	  "$conntrack -L $orig_src $orig_dst $reply_src $reply_dst $protocol 2>/dev/null";

	#~ &zenlog( $conntrack_cmd );
	return `$conntrack_cmd`;
}

=begin nd
Function: getNetstatFilter

	Filter conntrack output

Parameters:
	proto - Protocol: "tcp", "udp", more?
	state - State: ??
	ninfo - Ninfo: ??
	fpid - Fpid: ??
	netstat - Output from getConntrack

Returns:
	list - Filtered netstat array.

See Also:
	Input from: <getConntrack>

	<farm-rrd.pl>, zapi/v?/system_stats.cgi

	<getBackendEstConns>, <getFarmEstConns>, <getBackendSYNConns>, <getFarmSYNConns>

	<getL4BackendEstConns>, <getL4FarmEstConns>, <getL4BackendSYNConns>, <getL4FarmSYNConns>
	<getHTTPBackendEstConns>, <getHTTPFarmEstConns>, <getHTTPBackendTWConns>, <getHTTPBackendSYNConns>, <getHTTPFarmSYNConns>, <getGSLBFarmEstConns>
=cut
# Returns array execution of netstat
sub getNetstatFilter    # ($proto,$state,$ninfo,$fpid,@netstat)
{
	my ( $proto, $state, $ninfo, $fpid, @netstat ) = @_;

	my $lfpid = $fpid;
	chomp ( $lfpid );

	#print "proto $proto ninfo $ninfo state $state pid $fpid<br/>";
	if ( $lfpid )
	{
		$lfpid = "\ $lfpid\/";
	}
	if ( $proto ne "tcp" && $proto ne "udp" )
	{
		$proto = "";
	}
	my @output =
	  grep { /${proto}.*\ ${ninfo}\ .*\ ${state}.*${lfpid}/ } @netstat;

	return @output;
}

1;
