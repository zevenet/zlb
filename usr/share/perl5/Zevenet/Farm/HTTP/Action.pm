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
Function: _runHTTPFarmStart

	Run a HTTP farm

Parameters:
	farmname - Farm name
	writeconf - write this change in configuration status "writeconf" for true or omit it for false

Returns:
	Integer - return 0 on success or different of 0 on failure

=cut

sub _runHTTPFarmStart    # ($farm_name, $writeconf)
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my ( $farm_name, $writeconf ) = @_;

	require Zevenet::System;
	require Zevenet::Farm::HTTP::Backend;

	my $status         = -1;
	my $farm_filename  = &getFarmFile( $farm_name );
	my $pound          = &getGlobalConfiguration( 'pound' );
	my $piddir         = &getGlobalConfiguration( 'piddir' );
	my $ssyncd_enabled = &getGlobalConfiguration( 'ssyncd_enabled' );
	my $args           = ( $ssyncd_enabled eq 'true' ) ? '-s' : '';

	&zenlog( "Checking $farm_name farm configuration", "info", "LSLB" );
	return -1 if ( &getHTTPFarmConfigIsOK( $farm_name ) );

	my $cmd =
	  "$pound $args -f $configdir\/$farm_filename -p $piddir\/$farm_name\_pound.pid";
	$status = &zsystem( "$cmd" );

	if ( $status == 0 )
	{
		# set backend at status before that the farm stopped
		&setHTTPFarmBackendStatus( $farm_name );
		&setHTTPFarmBootStatus( $farm_name, "up" ) if ( $writeconf );
	}
	else
	{
		&zenlog( "failed: $cmd", "error", "LSLB" );
	}

	return $status;
}

=begin nd
Function: _runHTTPFarmStop

	Stop a HTTP farm

Parameters:
	farmname - Farm name
	writeconf - write this change in configuration status "writeconf" for true or omit it for false

Returns:
	Integer - return 0 on success or different of 0 on failure
=cut

sub _runHTTPFarmStop    # ($farm_name, $writeconf)
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my ( $farm_name, $writeconf ) = @_;

	require Zevenet::FarmGuardian;

	my $status = -1;

	&runFarmGuardianStop( $farm_name, "" );
	&setHTTPFarmBootStatus( $farm_name, "down" ) if ( $writeconf );

	if ( &getHTTPFarmConfigIsOK( $farm_name ) == 0 )
	{
		my $pid    = &getFarmPid( $farm_name );
		my $piddir = &getGlobalConfiguration( 'piddir' );

		if ( $pid eq '-' || $pid == -1 )
		{
			&zenlog( "Not found pid", "warning", "LSLB" );
		}
		else
		{
			&zenlog( "Stopping HTTP farm $farm_name with PID $pid", "info", "LSLB" );

			# Returns the number of arguments that were successfully used to signal.
			kill 15, $pid;
		}

		unlink ( "$piddir\/$farm_name\_pound.pid" )
		  if -e "$piddir\/$farm_name\_pound.pid";
		unlink ( "\/tmp\/$farm_name\_pound.socket" )
		  if -e "\/tmp\/$farm_name\_pound.socket";

		require Zevenet::Lock;
		my $lf = &getLockFile( $farm_name );
		unlink ( $lf ) if -e $lf;
	}
	else
	{
		&zenlog(
			"Farm $farm_name can't be stopped, check the logs and modify the configuration",
			"info", "LSLB"
		);
		return 1;
	}

	return 0;
}

=begin nd
Function: setHTTPNewFarmName

	Function that renames a farm. Before call this function, stop the farm.

Parameters:
	farmname - Farm name
	newfarmname - New farm name

Returns:
	Integer - return 0 on success or -1 on failure
=cut

sub setHTTPNewFarmName    # ($farm_name,$new_farm_name)
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my ( $farm_name, $new_farm_name ) = @_;

	my $output = 0;
	my @farm_configfiles = (
							 "$configdir\/$farm_name\_status.cfg",
							 "$configdir\/$farm_name\_pound.cfg",
							 "$configdir\/$farm_name\_Err414.html",
							 "$configdir\/$farm_name\_Err500.html",
							 "$configdir\/$farm_name\_Err501.html",
							 "$configdir\/$farm_name\_Err503.html",
							 "$farm_name\_guardian.conf"
	);
	my @new_farm_configfiles = (
								 "$configdir\/$new_farm_name\_status.cfg",
								 "$configdir\/$new_farm_name\_pound.cfg",
								 "$configdir\/$new_farm_name\_Err414.html",
								 "$configdir\/$new_farm_name\_Err500.html",
								 "$configdir\/$new_farm_name\_Err501.html",
								 "$configdir\/$new_farm_name\_Err503.html",
								 "$farm_name\_guardian.conf"
	);

	if ( -e "\/tmp\/$farm_name\_pound.socket" )
	{
		unlink ( "\/tmp\/$farm_name\_pound.socket" );
	}

	foreach my $farm_filename ( @farm_configfiles )
	{
		if ( -e "$farm_filename" )
		{
			require Tie::File;
			tie my @configfile, 'Tie::File', "$farm_filename";

			# Lines to change:
			#Name		BasekitHTTP
			#Control 	"/tmp/BasekitHTTP_pound.socket"
			#\tErr414 "/usr/local/zevenet/config/BasekitHTTP_Err414.html"
			#\tErr500 "/usr/local/zevenet/config/BasekitHTTP_Err500.html"
			#\tErr501 "/usr/local/zevenet/config/BasekitHTTP_Err501.html"
			#\tErr503 "/usr/local/zevenet/config/BasekitHTTP_Err503.html"
			#\t#Service "BasekitHTTP"
			grep ( s/Name\t\t$farm_name/Name\t\t$new_farm_name/, @configfile );
			grep (
				s/Control \t"\/tmp\/${farm_name}_pound.socket"/Control \t"\/tmp\/${new_farm_name}_pound.socket"/,
				@configfile );
			grep (
				s/\tErr414 "\/usr\/local\/zevenet\/config\/${farm_name}_Err414.html"/\tErr414 "\/usr\/local\/zevenet\/config\/${new_farm_name}_Err414.html"/,
				@configfile );
			grep (
				s/\tErr500 "\/usr\/local\/zevenet\/config\/${farm_name}_Err500.html"/\tErr500 "\/usr\/local\/zevenet\/config\/${new_farm_name}_Err500.html"/,
				@configfile );
			grep (
				s/\tErr501 "\/usr\/local\/zevenet\/config\/${farm_name}_Err501.html"/\tErr501 "\/usr\/local\/zevenet\/config\/${new_farm_name}_Err501.html"/,
				@configfile );
			grep (
				s/\tErr503 "\/usr\/local\/zevenet\/config\/${farm_name}_Err503.html"/\tErr503 "\/usr\/local\/zevenet\/config\/${new_farm_name}_Err503.html"/,
				@configfile );
			grep ( s/\t#Service "$farm_name"/\t#Service "$new_farm_name"/, @configfile );

			untie @configfile;

			rename ( "$farm_filename", "$new_farm_configfiles[0]" ) or $output = -1;

			&zenlog( "Configuration saved in $new_farm_configfiles[0] file",
					 "info", "LSLB" );
		}
		shift ( @new_farm_configfiles );
	}

	return $output;
}

1;
