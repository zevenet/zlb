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
use Zevenet::Config;

my $eload;
if ( eval { require Zevenet::ELoad; } )
{
	$eload = 1;
}

my $configdir = &getGlobalConfiguration( 'configdir' );

=begin nd
Function: _runFarmStart

	Run a farm

Parameters:
	farm_name - Farm name
	writeconf - write this change in configuration status "writeconf" for true or omit it for false

Returns:
	Integer - return 0 on success or different of 0 on failure

=cut

sub _runFarmStart    # ($farm_name, $writeconf)
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my ( $farm_name, $writeconf ) = @_;

	# The parameter expect "undef" to not write it
	$writeconf = undef if ( $writeconf eq 'false' );

	require Zevenet::Farm::Base;

	my $status = -1;

	# finish the function if the farm is already up
	if ( &getFarmStatus( $farm_name ) eq "up" )
	{
		zenlog( "Farm $farm_name already up", "info", "FARMS" );
		return 0;
	}

	# check if the ip exists in any interface
	my $ip = &getFarmVip( "vip", $farm_name );
	require Zevenet::Net::Interface;
	if ( !&getIpAddressExists( $ip ) )
	{
		&zenlog( "The virtual interface $ip is not defined in any interface." );
		return $status;
	}

	my $farm_type     = &getFarmType( $farm_name );
	my $farm_filename = &getFarmFile( $farm_name );

	&zenlog( "Starting farm $farm_name with type $farm_type", "info", "FARMS" );

	if ( $farm_type eq "http" || $farm_type eq "https" )
	{
		require Zevenet::Farm::HTTP::Action;
		$status = &_runHTTPFarmStart( $farm_name, $writeconf );
	}
	elsif ( $farm_type eq "datalink" )
	{
		require Zevenet::Farm::Datalink::Action;
		$status = &_runDatalinkFarmStart( $farm_name, $writeconf );
	}
	elsif ( $farm_type eq "l4xnat" )
	{
		require Zevenet::Farm::L4xNAT::Action;
		$status = &startL4Farm( $farm_name, $writeconf );
	}
	elsif ( $farm_type eq "gslb" && $eload )
	{
		$status = &eload(
						  module => 'Zevenet::Farm::GSLB::Action',
						  func   => '_runGSLBFarmStart',
						  args   => [$farm_name, $writeconf],
		);
	}

	&setFarmNoRestart( $farm_name );

	return $status;
}

=begin nd
Function: runFarmStart

	Run a farm completely a farm. Run farm, its farmguardian and ipds rules

Parameters:
	farm_name - Farm name
	writeconf - write this change in configuration status "writeconf" for true or omit it for false

Returns:
	Integer - return 0 on success or different of 0 on failure

NOTE:
	Generic function

=cut

sub runFarmStart    # ($farm_name, $writeconf)
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my ( $farm_name, $writeconf ) = @_;

	my $status = &_runFarmStart( $farm_name, $writeconf );

	return -1 if ( $status != 0 );

	require Zevenet::FarmGuardian;
	&runFarmGuardianStart( $farm_name, "" );

	if ( $eload )
	{
		&eload(
				module => 'Zevenet::IPDS::Base',
				func   => 'runIPDSStartByFarm',
				args   => [$farm_name],
		);

		require Zevenet::Farm::Config;
		&reloadFarmsSourceAddressByFarm( $farm_name );

		&eload(
				module => 'Zevenet::Cluster',
				func   => 'zClusterFarmUp',
				args   => [$farm_name],
		);
	}

	return $status;
}

=begin nd
Function: runFarmStop

	Stop a farm completely a farm. Stop the farm, its farmguardian and ipds rules

Parameters:
	farm_name - Farm name
	writeconf - write this change in configuration status "writeconf" for true or omit it for false

Returns:
	Integer - return 0 on success or different of 0 on failure

NOTE:
	Generic function

=cut

sub runFarmStop    # ($farm_name, $writeconf)
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my ( $farm_name, $writeconf ) = @_;

	if ( $eload )
	{
		&eload(
				module => 'Zevenet::Cluster',
				func   => 'zClusterFarmDown',
				args   => [$farm_name],
		);

		# stop ipds rules
		&eload(
				module => 'Zevenet::IPDS::Base',
				func   => 'runIPDSStopByFarm',
				args   => [$farm_name],
		);
	}

	require Zevenet::FarmGuardian;
	&runFGFarmStop( $farm_name );

	my $status = &_runFarmStop( $farm_name, $writeconf );

	return $status;
}

=begin nd
Function: _runFarmStop

	Stop a farm

Parameters:
	farm_name - Farm name
	writeconf - write this change in configuration status "writeconf" for true or omit it for false

Returns:
	Integer - return 0 on success or different of 0 on failure

=cut

sub _runFarmStop    # ($farm_name, $writeconf)
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my ( $farm_name, $writeconf ) = @_;

	# The parameter expect "undef" to not write it
	$writeconf = undef if ( $writeconf eq 'false' );

	require Zevenet::Farm::Base;
	my $status = &getFarmStatus( $farm_name );
	if ( $status eq "down" )
	{
		return 0;
	}

	my $farm_filename = &getFarmFile( $farm_name );
	if ( $farm_filename eq '-1' )
	{
		return -1;
	}

	my $farm_type = &getFarmType( $farm_name );
	$status = $farm_type;

	&zenlog( "Stopping farm $farm_name with type $farm_type", "info", "FARMS" );

	if ( $farm_type =~ /http/ )
	{
		require Zevenet::Farm::HTTP::Action;
		$status = &_runHTTPFarmStop( $farm_name, $writeconf );
	}
	elsif ( $farm_type eq "datalink" )
	{
		require Zevenet::Farm::Datalink::Action;
		$status = &_runDatalinkFarmStop( $farm_name, $writeconf );
	}
	elsif ( $farm_type eq "l4xnat" )
	{
		require Zevenet::Farm::L4xNAT::Action;
		$status = &stopL4Farm( $farm_name, $writeconf );
	}
	elsif ( $farm_type eq "gslb" && $eload )
	{
		$status = &eload(
						  module => 'Zevenet::Farm::GSLB::Action',
						  func   => '_runGSLBFarmStop',
						  args   => [$farm_name, $writeconf],
		);
	}

	&setFarmNoRestart( $farm_name );

	return $status;
}

=begin nd
Function: runFarmDelete

	Delete a farm

Parameters:
	farmname - Farm name

Returns:
	String - farm name

NOTE:
	Generic function

=cut

sub runFarmDelete    # ($farm_name)
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $farm_name = shift;

	require Zevenet::Netfilter;

	# global variables
	my $basedir   = &getGlobalConfiguration( 'basedir' );
	my $configdir = &getGlobalConfiguration( 'configdir' );
	my $rrdap_dir = &getGlobalConfiguration( 'rrdap_dir' );
	my $logdir    = &getGlobalConfiguration( 'logdir' );
	my $rrd_dir   = &getGlobalConfiguration( 'rrd_dir' );

	if ( $eload )
	{
		#delete IPDS rules
		&eload(
				module => 'Zevenet::IPDS::Base',
				func   => 'runIPDSDeleteByFarm',
				args   => [$farm_name],
		);

		#delete from RBAC
		&eload(
				module => 'Zevenet::RBAC::Group::Config',
				func   => 'delRBACResource',
				args   => [$farm_name, 'farms'],
		);
	}

	# stop and unlink farmguardian
	require Zevenet::FarmGuardian;
	&delFGFarm( $farm_name );

	my $farm_type = &getFarmType( $farm_name );
	my $status    = 1;

	&zenlog( "running 'Delete' for $farm_name", "info", "FARMS" );

	if ( $farm_type eq "gslb" )
	{
		require File::Path;
		File::Path->import( 'rmtree' );

		$status = 0
		  if rmtree( ["$configdir/$farm_name\_gslb.cfg"] );
	}
	else
	{
		$status = 0
		  if unlink glob ( "$configdir/$farm_name\_*\.cfg" );

		if ( $farm_type eq "http" || $farm_type eq "https" )
		{
			unlink glob ( "$configdir/$farm_name\_*\.html" );

			# For HTTPS farms only
			my $dhfile = "$configdir\/$farm_name\_dh2048.pem";
			unlink ( "$dhfile" ) if -e "$dhfile";
		}
		elsif ( $farm_type eq "datalink" )
		{
			# delete cron task to check backends
			require Tie::File;
			tie my @filelines, 'Tie::File', "/etc/cron.d/zevenet";
			@filelines = grep !/\# \_\_$farm_name\_\_/, @filelines;
			untie @filelines;
		}
		elsif ( $farm_type eq "l4xnat" )
		{
			require Zevenet::Farm::L4xNAT::Factory;
			&runL4FarmDelete( $farm_name );
		}
	}

	unlink glob ( "$configdir/$farm_name\_*\.conf" );

	require Zevenet::RRD;

	&delGraph( $farm_name, "farm" );

	return $status;
}

=begin nd
Function: setFarmRestart

	This function creates a file to tell that the farm needs to be restarted to apply changes

Parameters:
	farmname - Farm name

Returns:
	undef

NOTE:
	Generic function

=cut

sub setFarmRestart    # ($farm_name)
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $farm_name = shift;

	# do nothing if the farm is not running
	require Zevenet::Farm::Base;
	return if &getFarmStatus( $farm_name ) ne 'up';

	require Zevenet::Lock;
	my $lf = &getLockFile( $farm_name );
	my $fh = &openlock( $lf, 'w' );
	close $fh;
}

=begin nd
Function: setFarmNoRestart

	This function deletes the file marking the farm to be restarted to apply changes

Parameters:
	farmname - Farm name

Returns:
	none - .

NOTE:
	Generic function

=cut

sub setFarmNoRestart    # ($farm_name)
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $farm_name = shift;

	require Zevenet::Lock;
	my $lf = &getLockFile( $farm_name );
	unlink ( $lf ) if -e $lf;
}

=begin nd
Function: setNewFarmName

	Function that renames a farm. Before call this function, stop the farm.

Parameters:
	farmname - Farm name
	newfarmname - New farm name

Returns:
	Integer - return 0 on success or -1 on failure

=cut

sub setNewFarmName    # ($farm_name,$new_farm_name)
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my ( $farm_name, $new_farm_name ) = @_;

	my $rrdap_dir = &getGlobalConfiguration( 'rrdap_dir' );
	my $rrd_dir   = &getGlobalConfiguration( 'rrd_dir' );

	my $farm_type = &getFarmType( $farm_name );
	my $output    = -1;

	my $fg_status;
	my $farm_status;

	# farmguardian renaming
	require Zevenet::FarmGuardian;

	# stop farm
	&runFGFarmStop( $farm_name );

	# rename farmguardian
	&setFGFarmRename( $farm_name, $new_farm_name );

	# end of farmguardian renaming

	&zenlog( "setting 'NewFarmName $new_farm_name' for $farm_name farm $farm_type",
			 "info", "FARMS" );

	if ( $farm_type eq "http" || $farm_type eq "https" )
	{
		require Zevenet::Farm::HTTP::Action;
		$output = &setHTTPNewFarmName( $farm_name, $new_farm_name );
	}
	elsif ( $farm_type eq "datalink" )
	{
		require Zevenet::Farm::Datalink::Action;
		$output = &setDatalinkNewFarmName( $farm_name, $new_farm_name );
	}
	elsif ( $farm_type eq "l4xnat" )
	{
		require Zevenet::Farm::L4xNAT::Action;
		$output = &setL4NewFarmName( $farm_name, $new_farm_name );
	}
	elsif ( $farm_type eq "gslb" && $eload )
	{
		$output = &eload(
						  module => 'Zevenet::Farm::GSLB::Action',
						  func   => 'setGSLBNewFarmName',
						  args   => [$farm_name, $new_farm_name],
		);
	}

	# farmguardian renaming
	if ( $output == 0 and $farm_status eq 'up' )
	{
		&zenlog( "restarting farmguardian", 'info', 'FG' ) if &debug;
		&runFGFarmStart( $farm_name );
	}

	# end of farmguardian renaming

	# rename rrd
	rename ( "$rrdap_dir/$rrd_dir/$farm_name-farm.rrd",
			 "$rrdap_dir/$rrd_dir/$new_farm_name-farm.rrd" );

	# delete old graphs
	unlink ( "img/graphs/bar$farm_name.png" );

	if ( $eload )
	{
		&eload(
				module => 'Zevenet::IPDS::Base',
				func   => 'runIPDSRenameByFarm',
				args   => [$farm_name, $new_farm_name],
		);

		&eload(
				module => 'Zevenet::RBAC::Group::Config',
				func   => 'setRBACRenameByFarm',
				args   => [$farm_name, $new_farm_name],
		);
	}

	# FIXME: farmguardian files
	# FIXME: logfiles
	return $output;
}

1;
