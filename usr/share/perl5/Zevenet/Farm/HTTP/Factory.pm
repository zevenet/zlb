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
Function: runHTTPFarmCreate

	Create a HTTP farm

Parameters:
	vip - Virtual IP where the virtual service is listening
	port - Virtual port where the virtual service is listening
	farmname - Farm name
	type - Specify if farm is HTTP or HTTPS

Returns:
	Integer - return 0 on success or different of 0 on failure

=cut

sub runHTTPFarmCreate    # ( $vip, $vip_port, $farm_name, $farm_type )
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my ( $vip, $vip_port, $farm_name, $farm_type ) = @_;

	require Tie::File;
	require File::Copy;
	File::Copy->import();

	my $output = -1;

	#copy template modyfing values
	my $proxytpl        = &getGlobalConfiguration( 'proxytpl' );
	my $proxy_conf_file = "$configdir/${farm_name}_proxy.cfg";
	&zenlog( "Copying proxy template ($proxytpl) to $proxy_conf_file",
			 "info", "LSLB" );
	copy( $proxytpl, $proxy_conf_file );

	#modify strings with variables
	tie my @file, 'Tie::File', $proxy_conf_file;

	foreach my $line ( @file )
	{
		$line =~ s/\[IP\]/$vip/;
		$line =~ s/\[PORT\]/$vip_port/;
		$line =~ s/\[DESC\]/$farm_name/;
		$line =~ s/\[CONFIGDIR\]/$configdir/;
		if ( $farm_type eq "HTTPS" )
		{
			$line =~ s/ListenHTTP/ListenHTTPS/;
			$line =~ s/#Cert/Cert/;
		}
	}
	untie @file;

	#create files with personalized errors
	my $f_err;
	open $f_err, '>', "$configdir\/$farm_name\_Err414.html";
	print $f_err "Request URI is too long.\n";
	close $f_err;
	open $f_err, '>', "$configdir\/$farm_name\_Err500.html";
	print $f_err "An internal server error occurred. Please try again later.\n";
	close $f_err;
	open $f_err, '>', "$configdir\/$farm_name\_Err501.html";
	print $f_err "This method may not be used.\n";
	close $f_err;
	open $f_err, '>', "$configdir\/$farm_name\_Err503.html";
	print $f_err "The service is not available. Please try again later.\n";
	close $f_err;

	my $proxy  = &getGlobalConfiguration( 'proxy' );
	my $piddir = &getGlobalConfiguration( 'piddir' );

	#run farm
	&zenlog(
		"Running $proxy -f $configdir\/$farm_name\_proxy.cfg -p $piddir\/$farm_name\_proxy.pid",
		"info", "LSLB"
	);

	require Zevenet::System;

	&zsystem(
		"$proxy -f $configdir\/$farm_name\_proxy.cfg -p $piddir\/$farm_name\_proxy.pid 2>/dev/null"
	);
	$output = $?;

	return $output;
}

1;
