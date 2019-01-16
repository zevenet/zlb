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

my $configdir = &getGlobalConfiguration( 'configdir' );

=begin nd
Function: loadL4FarmModules

	Load L4farm system modules

Parameters:
	none

Returns:
	Integer - 0 on success or -1 on failure

=cut

sub loadL4FarmModules
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );

	my $recent_ip_list_tot = &getGlobalConfiguration( 'recent_ip_list_tot' );
	my $recent_ip_list_hash_size =
	  &getGlobalConfiguration( 'recent_ip_list_hash_size' );

	my $ip_list_tot_str  = "";
	my $ip_list_hash_str = "";

	$ip_list_tot_str = "ip_list_tot=$recent_ip_list_tot"
	  if ( $recent_ip_list_tot ne "" );
	$ip_list_hash_str = "ip_list_hash_size=$recent_ip_list_hash_size"
	  if ( $recent_ip_list_hash_size ne "" );

	my $out = system ( '/sbin/modprobe nf_conntrack >/dev/null 2>&1' );
	$out |= system ( '/sbin/modprobe ip_conntrack >/dev/null 2>&1' );

	$out |= system ( '/sbin/rmmod xt_recent >/dev/null 2>&1' );
	$out |= system (
		"/sbin/modprobe xt_recent $ip_list_tot_str $ip_list_hash_str >/dev/null 2>&1" );

	return $out;
}

1;
