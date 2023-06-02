#!/usr/bin/perl
###############################################################################
#
#    ZEVENET Software License
#    This file is part of the ZEVENET Load Balancer software package.
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
use warnings;


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
	&zenlog( __FILE__ . q{:} . __LINE__ . q{:} . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my ( $farm_name, $writeconf ) = @_;

	require Zevenet::System;
	require Zevenet::Farm::HTTP::Backend;
	require Zevenet::Farm::Config;

	my $status        = -1;
	my $farm_filename = &getFarmFile( $farm_name );
	my $proxy         = &getGlobalConfiguration( 'proxy' );
	my $piddir        = &getGlobalConfiguration( 'piddir' );

	require Zevenet::Lock;
	my $lock_file = &getLockFile( $farm_name );
	my $lock_fh = &openlock( $lock_file, 'w' );

	close $lock_fh;

	&zenlog( "Checking $farm_name farm configuration", "info", "LSLB" );
	return -1 if ( &getHTTPFarmConfigIsOK( $farm_name ) );

	my $args = '';

	my $cmd;
	my $proxy_ng = &getGlobalConfiguration( "proxy_ng" );
	if ( $proxy_ng eq "false" )
	{
		$cmd =
		  "$proxy $args -f $configdir\/$farm_filename -p $piddir\/$farm_name\_proxy.pid";
	}
	elsif ( $proxy_ng eq "true" )
	{
		require Zevenet::Farm::HTTP::Config;
		my $socket_file = &getHTTPFarmSocket( $farm_name );
		$cmd =
		  "$proxy -f $configdir\/$farm_filename -C $socket_file -p $piddir\/$farm_name\_proxy.pid";
	}
	$status = &zsystem( "$cmd" );

	if ( $status )
	{
		&zenlog( "failed: $cmd", "error", "LSLB" );
		return $status;
	}

	# set backend at status before that the farm stopped
	&setHTTPFarmBackendStatus( $farm_name );
	&setHTTPFarmBootStatus( $farm_name, "up" ) if ( $writeconf );

	# load backend routing rules
	&doL7FarmRules( "start", $farm_name );

	if ( &getGlobalConfiguration( "proxy_ng" ) eq 'true' )
	{
		if ( &getGlobalConfiguration( "mark_routing_L7" ) eq 'true' )
		{
			# create L4 farm type local
			my $farm_vip   = &getFarmVip( "vip",  $farm_name );
			my $farm_vport = &getFarmVip( "vipp", $farm_name );

			my $body =
			  qq({"farms" : [ { "name" : "$farm_name", "virtual-addr" : "$farm_vip", "virtual-ports" : "$farm_vport", "mode" : "local", "state": "up" }]});

			require Zevenet::Nft;
			my $error = &httpNlbRequest(
										 {
										   farm   => $farm_name,
										   method => "PUT",
										   uri    => "/farms",
										   body   => $body
										 }
			);
			if ( $error )
			{
				&zenlog( "L4xnat Farm Type local for '$farm_name' can not be created.",
						 "warning", "LSLB" );
			}
		}

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
	&zenlog( __FILE__ . q{:} . __LINE__ . q{:} . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my ( $farm_name, $writeconf ) = @_;

	require Zevenet::FarmGuardian;
	my $time = &getGlobalConfiguration( "http_farm_stop_grace_time" );

	&runFarmGuardianStop( $farm_name, "" );

	require Zevenet::Farm::HTTP::Config;
	&setHTTPFarmBootStatus( $farm_name, "down" ) if ( $writeconf );

	require Zevenet::Farm::HTTP::Config;
	return 0 if ( &getHTTPFarmStatus( $farm_name ) eq "down" );

	my $piddir = &getGlobalConfiguration( 'piddir' );
	if ( &getHTTPFarmConfigIsOK( $farm_name ) == 0 )
	{
		my @pids = &getFarmPid( $farm_name );
		if ( not @pids )
		{
			&zenlog( "Not found pid", "warning", "LSLB" );
		}
		else
		{
			my $pid = join ( ', ', @pids );
			&zenlog( "Stopping HTTP farm $farm_name with PID $pid", "info", "LSLB" );
			kill 9, @pids;
			sleep ( $time );
		}

		if ( &getGlobalConfiguration( "proxy_ng" ) eq 'true' )
		{
			if ( &getGlobalConfiguration( "mark_routing_L7" ) eq 'true' )
			{
				# Delete L4 farm type local
				require Zevenet::Nft;
				&httpNlbRequest(
								 {
								   farm   => $farm_name,
								   method => "DELETE",
								   uri    => "/farms/" . $farm_name,
								 }
				);
			}
		}

		&doL7FarmRules( "stop", $farm_name );

		unlink ( "$piddir\/$farm_name\_proxy.pid" )
		  if -e "$piddir\/$farm_name\_proxy.pid";
		unlink ( "\/tmp\/$farm_name\_proxy.socket" )
		  if -e "\/tmp\/$farm_name\_proxy.socket";

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
Function: copyHTTPFarm

	Function that does a copy of a farm configuration.
	If the flag has the value 'del', the old farm will be deleted.

Parameters:
	farmname - Farm name
	newfarmname - New farm name
	flag - It expets a 'del' string to delete the old farm. It is used to copy or rename the farm.

Returns:
	Integer - Error code: return 0 on success or -1 on failure

=cut

sub copyHTTPFarm    # ($farm_name,$new_farm_name)
{
	&zenlog( __FILE__ . q{:} . __LINE__ . q{:} . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my ( $farm_name, $new_farm_name, $del ) = @_;

	use File::Copy qw(copy);

	my $output = 0;
	my @farm_configfiles = (
							 "$configdir\/$farm_name\_status.cfg",
							 "$configdir\/$farm_name\_proxy.cfg",
							 "$configdir\/$farm_name\_ErrWAF.html",
							 "$configdir\/$farm_name\_Err414.html",
							 "$configdir\/$farm_name\_Err500.html",
							 "$configdir\/$farm_name\_Err501.html",
							 "$configdir\/$farm_name\_Err503.html",
							 "$configdir\/$farm_name\_sessions.cfg",
	);
	my @new_farm_configfiles = (
								 "$configdir\/$new_farm_name\_status.cfg",
								 "$configdir\/$new_farm_name\_proxy.cfg",
								 "$configdir\/$new_farm_name\_ErrWAF.html",
								 "$configdir\/$new_farm_name\_Err414.html",
								 "$configdir\/$new_farm_name\_Err500.html",
								 "$configdir\/$new_farm_name\_Err501.html",
								 "$configdir\/$new_farm_name\_Err503.html",
								 "$configdir\/$new_farm_name\_sessions.cfg",
	);

	foreach my $farm_filename ( @farm_configfiles )
	{
		if ( -e "$farm_filename" )
		{
			copy( "$farm_filename", "$new_farm_configfiles[0]" ) or $output = -1;

			require Tie::File;
			tie my @configfile, 'Tie::File', "$new_farm_configfiles[0]";

			# Lines to change:
			#Name		BasekitHTTP
			#Control 	"/tmp/BasekitHTTP_proxy.socket"
			#\tErr414 "/usr/local/zevenet/config/BasekitHTTP_Err414.html"
			#\tErr500 "/usr/local/zevenet/config/BasekitHTTP_Err500.html"
			#\tErr501 "/usr/local/zevenet/config/BasekitHTTP_Err501.html"
			#\tErr503 "/usr/local/zevenet/config/BasekitHTTP_Err503.html"
			#\t#Service "BasekitHTTP"
			#NfMarks (for each backend)
			grep { s/^(\s*Name\s+"?)$farm_name/$1$new_farm_name/ } @configfile;
			grep {
				s/\tErrWAF "\/usr\/local\/zevenet\/config\/${farm_name}_ErrWAF.html"/\tErrWAF "\/usr\/local\/zevenet\/config\/${new_farm_name}_ErrWAF.html"/
			} @configfile;
			grep {
				s/\tErr414 "\/usr\/local\/zevenet\/config\/${farm_name}_Err414.html"/\tErr414 "\/usr\/local\/zevenet\/config\/${new_farm_name}_Err414.html"/
			} @configfile;
			grep {
				s/\tErr500 "\/usr\/local\/zevenet\/config\/${farm_name}_Err500.html"/\tErr500 "\/usr\/local\/zevenet\/config\/${new_farm_name}_Err500.html"/
			} @configfile;
			grep {
				s/\tErr501 "\/usr\/local\/zevenet\/config\/${farm_name}_Err501.html"/\tErr501 "\/usr\/local\/zevenet\/config\/${new_farm_name}_Err501.html"/
			} @configfile;
			grep {
				s/\tErr503 "\/usr\/local\/zevenet\/config\/${farm_name}_Err503.html"/\tErr503 "\/usr\/local\/zevenet\/config\/${new_farm_name}_Err503.html"/
			} @configfile;
			grep { s/\t#Service "$farm_name"/\t#Service "$new_farm_name"/ } @configfile;

			if ( &getGlobalConfiguration( "proxy_ng" ) eq 'true' )
			{
				# Remove old Marks
				@configfile = grep { not ( /\t\t\tNfMark\s*(.*)/ ) } @configfile;
			}
			else
			{
				grep {
					s/Control \t"\/tmp\/${farm_name}_proxy.socket"/Control \t"\/tmp\/${new_farm_name}_proxy.socket"/
				} @configfile;
			}

			untie @configfile;

			if ( &getGlobalConfiguration( "proxy_ng" ) eq 'true' )
			{
				# Add new Marks
				require Zevenet::Farm::HTTP::Backend;
				&setHTTPFarmBackendsMarks( $new_farm_name );
			}

			unlink ( "$farm_filename" ) if ( $del eq 'del' );

			&zenlog( "Configuration saved in $new_farm_configfiles[0] file",
					 "info", "LSLB" );
		}
		shift ( @new_farm_configfiles );
	}

	if ( -e "\/tmp\/$farm_name\_pound.socket" and $del eq 'del' )
	{
		unlink ( "\/tmp\/$farm_name\_pound.socket" );
	}

	if ( &getGlobalConfiguration( "proxy_ng" ) eq 'true' and $del eq 'del' )
	{
		&delMarks( $farm_name, "" );
	}

	return $output;
}

=begin nd
Function: sendL7ZproxyCmd

	Send request to Zproxy

Parameters:
	self - hash that includes hash_keys:
		farmname, it is the farm that is going to be modified
		method, HTTP verb for zproxy request
		uri,
		body, body to use in POST and PUT requests

Returns:
	HASH Object - return result of the request command
	 or
	Integer 1 on error

=cut

sub sendL7ZproxyCmd
{
	&zenlog( __FILE__ . q{:} . __LINE__ . q{:} . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $self = shift;

	if ( &getGlobalConfiguration( 'proxy_ng' ) ne 'true' )
	{
		&zenlog( "Property only available for zproxy", "error", "HTTP" );
		return 1;
	}
	if ( not defined $self->{ farm } )
	{
		&zenlog( "Missing mandatory param farm", "error", "HTTP" );
		return 1;
	}
	if ( not defined $self->{ uri } )
	{
		&zenlog( "Missing mandatory param uri", "error", "HTTP" );
		return 1;
	}

	require JSON;
	require Zevenet::Farm::HTTP::Config;

	my $method = defined $self->{ method } ? "-X $self->{ method } " : "";
	my $url = "http://localhost/$self->{ uri }";
	my $body =
	  defined $self->{ body } ? "--data-ascii '" . $self->{ body } . "' " : "";

	# i.e: curl --unix-socket /tmp/webfarm_proxy.socket  http://localhost/listener/0
	my $curl_bin = &getGlobalConfiguration( 'curl_bin' );
	my $socket   = &getHTTPFarmSocket( $self->{ farm } );
	my $cmd      = "$curl_bin " . $method . $body . "--unix-socket $socket $url";

	my $resp = &logAndGet( $cmd, 'string' );
	return 1 unless ( defined $resp and $resp ne '' );
	$resp = eval { &JSON::decode_json( $resp ) };
	if ( $@ )
	{
		&zenlog( "Decoding json: $@", "error", "HTTP" );
		return 1;
	}
	return $resp;

}

=begin nd
Function: checkFarmHTTPSystemStatus

	Checks the process and PID file on the system and fixes the inconsistency.

Parameters:
	farm_name - farm that is going to be modified
	status - Status to check. Only "down" status.
	fix - True, do the necessary changes to get the inconsistency fixed. 

Returns:
	None

=cut

sub checkFarmHTTPSystemStatus    # ($farm_name, $status, $fix)
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my ( $farm_name, $status, $fix ) = @_;
	if ( $status eq "down" )
	{
		my $pid_file = getHTTPFarmPidFile( $farm_name );
		if ( -e $pid_file )
		{
			unlink $pid_file if ( defined $fix and $fix eq "true" );
		}
		my $pgrep = &getGlobalConfiguration( "pgrep" );
		require Zevenet::Farm::Core;
		my $farm_file    = &getFarmFile( $farm_name );
		my $config_dir   = &getGlobalConfiguration( "configdir" );
		my $proxy        = &getGlobalConfiguration( "proxy" );
		my @pids_running = @{
			&logAndGet( "$pgrep -f \"$proxy (-s )?-f $config_dir/$farm_file -p $pid_file\"",
						"array" )
		};

		if ( @pids_running )
		{
			kill 9, @pids_running if ( defined $fix and $fix eq "true" );
		}
	}
	return;
}

1;
