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
Function: startL4Farm

	Run a l4xnat farm

Parameters:
	farm_name - Farm name
	writeconf - write this change in configuration status "writeconf" for true or omit it for false

Returns:
	Integer - return 0 on success or different of 0 on failure

=cut

sub startL4Farm    # ($farm_name)
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );

	my $farm_name = shift;
	my $writeconf = shift;

	&zlog( "Starting farm $farm_name" ) if &debug == 2;

	my $status = 0;

	&zenlog( "startL4Farm << farm_name:$farm_name" )
	  if &debug;

	$status = &startNLBFarm( $farm_name, $writeconf );
	if ( $status != 0 )
	{
		return $status;
	}

	doL4FarmRules( "start", $farm_name );

	# Enable IP forwarding
	require Zevenet::Net::Util;
	&setIpForward( 'true' );

	return $status;
}

=begin nd
Function: stopL4Farm

	Stop a l4xnat farm

Parameters:
	farm_name - Farm name
	writeconf - write this change in configuration status "writeconf" for true or omit it for false

Returns:
	Integer - return 0 on success or other value on failure

=cut

sub stopL4Farm    # ($farm_name)
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );

	my $farm_name = shift;
	my $writeconf = shift;
	my $pidfile   = &getL4FarmPidFile( $farm_name );

	require Zevenet::Farm::Core;

	&zlog( "Stopping farm $farm_name" ) if &debug > 2;

	doL4FarmRules( "stop", $farm_name );

	my $pid = &getNLBPid();
	if ( $pid <= 0 )
	{
		return 0;
	}

	my $status = &stopNLBFarm( $farm_name, $writeconf );

	unlink "$pidfile" if ( -e "$pidfile" );

	return $status;
}

=begin nd
Function: setL4NewFarmName

	Function that renames a farm

Parameters:
	farmname - Farm name
	newfarmname - New farm name

Returns:
	Integer - return 0 on success or <> 0 on failure

=cut

sub setL4NewFarmName    # ($farm_name, $new_farm_name)
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $farm_name     = shift;
	my $new_farm_name = shift;
	my $output        = 0;

	require Tie::File;

	my $output = &setL4FarmParam( 'name', "$new_farm_name", $farm_name );

	unlink "$configdir\/${farm_name}_l4xnat.cfg";

	return $output;
}

=begin nd
Function: startNLB

	Launch the nftlb daemon and create the PID file. Do
	nothing if already is launched.

Parameters:
	none

Returns:
	Integer - return PID on success or <= 0 on failure

=cut

sub startNLB    # ()
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $nftlbd     = &getGlobalConfiguration( 'zbindir' ) . "/nftlbd";
	my $pidof      = &getGlobalConfiguration( 'pidof' );
	my $nlbpidfile = &getNLBPidFile();
	my $nlbpid     = &getNLBPid();

	if ( $nlbpid eq "-1" )
	{
		&logAndRun( "$nftlbd start" );

		#required to wait at startup to ensure the process is up
		sleep 1;

		$nlbpid = `$pidof nftlb`;
		if ( $nlbpid eq "" )
		{
			return -1;
		}

		open my $fd, '>', "$nlbpidfile";
		print $fd "$nlbpid";
		close $fd;
	}

	return $nlbpid;
}

=begin nd
Function: stopNLB

	Stop the nftlb daemon. Do nothing if is already stopped.

Parameters:
	none

Returns:
	Integer - return PID on success or <= 0 on failure

=cut

sub stopNLB    # ()
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );

	my $nftlbd     = &getGlobalConfiguration( 'zbindir' ) . "/nftlbd";
	my $pidof      = &getGlobalConfiguration( 'pidof' );
	my $nlbpidfile = &getNLBPidFile();
	my $nlbpid     = &getNLBPid();

	if ( $nlbpid ne "-1" )
	{
		&logAndRun( "$nftlbd stop" );
	}

	return $nlbpid;
}

=begin nd
Function: loadNLBFarm

	Load farm configuration in nftlb

Parameters:
	farm_name - farm name configuration to be loaded

Returns:
	Integer - 0 on success or -1 on failure

=cut

sub loadNLBFarm    # ($farm_name)
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $farm_name = shift;

	require Zevenet::Farm::Core;
	require Zevenet::Farm::L4xNAT::Config;

	my $farmfile = &getFarmFile( $farm_name );

	return -1 if ( !-e "$configdir/$farmfile" );

	my $out = &httpNLBRequest(
							   {
								 farm       => $farm_name,
								 configfile => "$configdir/$farmfile",
								 method     => "POST",
								 uri        => "/farms",
								 body       => qq(\@$configdir/$farmfile)
							   }
	);

	return $out;
}

=begin nd
Function: startNLBFarm

	Start a new farm in nftlb

Parameters:
	farm_name - farm name to be started
	writeconf - write this change in configuration status "writeconf" for true or omit it for false

Returns:
	Integer - 0 on success or -1 on failure

=cut

sub startNLBFarm    # ($farm_name)
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $farm_name = shift;
	my $writeconf = shift;

	#	require Zevenet::Farm::Core;
	require Zevenet::Farm::L4xNAT::Config;

	my $out = &loadNLBFarm( $farm_name );
	if ( $out != 0 )
	{
		return $out;
	}

	&setL4FarmParam( ( $writeconf ) ? 'bootstatus' : 'status', "up", $farm_name );

	my $pidfile = &getL4FarmPidFile( $farm_name );

	if ( !-e "$pidfile" )
	{
		open my $fi, '>', "$pidfile";
		close $fi;
	}

	return $out;
}

=begin nd
Function: stopNLBFarm

	Stop an existing farm in nftlb

Parameters:
	farm_name - farm name to be started
	writeconf - write this change in configuration status "writeconf" for true or omit it for false

Returns:
	Integer - 0 on success or -1 on failure

=cut

sub stopNLBFarm    # ($farm_name)
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $farm_name = shift;
	my $writeconf = shift;

	require Zevenet::Farm::Core;

	my $farmfile = &getFarmFile( $farm_name );

	my $out = &setL4FarmParam( ( $writeconf ) ? 'bootstatus' : 'status',
							   "down", $farm_name );

	return $out;
}

=begin nd
Function: getNLBPid

	Return the nftlb pid

Parameters:
	none

Returns:
	Integer - PID if successful or -1 on failure

=cut

sub getNLBPid
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );

	my $nlbpidfile = &getNLBPidFile();
	my $nlbpid     = -1;

	if ( !-f "$nlbpidfile" )
	{
		return -1;
	}

	open my $fd, '<', "$nlbpidfile";
	$nlbpid = <$fd>;
	close $fd;

	if ( $nlbpid eq "" )
	{
		return -1;
	}

	return $nlbpid;
}

=begin nd
Function: getNLBPidFile

	Return the nftlb pid file

Parameters:
	none

Returns:
	String - Pid file path or -1 on failure

=cut

sub getNLBPidFile
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );

	my $piddir     = &getGlobalConfiguration( 'piddir' );
	my $nlbpidfile = "$piddir/nftlb.pid";

	return $nlbpidfile;
}

=begin nd
Function: getL4FarmPidFile

	Return the farm pid file

Parameters:
	farm_name - Name of the given farm

Returns:
	String - Pid file path or -1 on failure

=cut

sub getL4FarmPidFile
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my ( $farm_name ) = @_;

	my $piddir  = &getGlobalConfiguration( 'piddir' );
	my $pidfile = "$piddir/$farm_name\_l4xnat.pid";

	return $pidfile;
}

1;
