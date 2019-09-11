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
use Zevenet::Farm::Core;

my $configdir = &getGlobalConfiguration( 'configdir' );
my $eload;
if ( eval { require Zevenet::ELoad; } )
{
	$eload = 1;
}

=begin nd
Function: getFarmVip

	Returns farm vip or farm port

Parameters:
	tag - requested parameter. The options are "vip" for virtual ip or "vipp" for virtual port
	farmname - Farm name

Returns:
	Scalar - return vip or port of farm or -1 on failure

See Also:
	setFarmVirtualConf
=cut

sub getFarmVip    # ($info,$farm_name)
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my ( $info, $farm_name ) = @_;

	my $farm_type = &getFarmType( $farm_name );
	my $output    = -1;

	if ( $farm_type eq "http" || $farm_type eq "https" )
	{
		require Zevenet::Farm::HTTP::Config;
		$output = &getHTTPFarmVip( $info, $farm_name );
	}
	elsif ( $farm_type eq "l4xnat" )
	{
		require Zevenet::Farm::L4xNAT::Config;
		$output = &getL4FarmParam( $info, $farm_name );
	}
	elsif ( $farm_type eq "datalink" )
	{
		require Zevenet::Farm::Datalink::Config;
		$output = &getDatalinkFarmVip( $info, $farm_name );
	}
	elsif ( $farm_type eq "gslb" && $eload )
	{
		$output = &eload(
						  module => 'Zevenet::Farm::GSLB::Config',
						  func   => 'getGSLBFarmVip',
						  args   => [$info, $farm_name],
		);
	}

	return $output;
}

=begin nd
Function: getFarmStatus

	Return farm status checking if pid file exists

Parameters:
	farmname - Farm name

Returns:
	String - "down", "up" or -1 on failure

NOTE:
	Generic function

=cut

sub getFarmStatus    # ($farm_name)
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $farm_name = shift;

	my $output = -1;
	return $output if !defined ( $farm_name );    # farm name cannot be empty

	my $farm_type = &getFarmType( $farm_name );
	my $piddir    = &getGlobalConfiguration( 'piddir' );

	if ( $farm_type eq "l4xnat" )
	{
		require Zevenet::Farm::L4xNAT::Config;
		return &getL4FarmStatus( $farm_name );
	}
	elsif ( $farm_type eq "datalink" )
	{
		require Zevenet::Farm::Datalink::Config;
		return &getDatalinkFarmStatus( $farm_name );
	}
	elsif ( $farm_type =~ /http/ )
	{
		require Zevenet::Farm::HTTP::Config;
		return &getHTTPFarmStatus( $farm_name );
	}
	elsif ( $farm_type eq "gslb" && $eload )
	{
		$output = &eload(
						  module => 'Zevenet::Farm::GSLB::Config',
						  func   => 'getGSLBFarmStatus',
						  args   => [$farm_name],
		);
	}

	return $output;
}

=begin nd
Function: getFarmVipStatus

	Return a vip status depend on the backends:

	down = The farm is not running
	needed restart = The farm is up but it is pending of a restart action
	critical = The farm is up and all backends are unreachable or maintenance
	problem = The farm is up and there are some backend unreachable, but
		almost a backend is in up status
	maintenance = The farm is up and there are backends in up status, but
		almost a backend is in maintenance mode.
	up = The farm is up and all the backends are working success.

Parameters:
	farmname - Farm name

Returns:
	String - "needed restart", "critical", "problem", "maintenance", "up", "down" or -1 on failure

NOTE:
	Generic function

=cut

sub getFarmVipStatus    # ($farm_name)
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $farm_name = shift;

	my $output     = -1;
	my $farmStatus = &getFarmStatus( $farm_name );
	return $output if !defined ( $farm_name );    # farm name cannot be empty

	$output = "problem";

	require Zevenet::Lock;

	if ( $farmStatus eq "down" )
	{
		return "down";
	}
	elsif ( &getLockStatus( $farm_name ) )
	{
		return "needed restart";
	}
	elsif ( $farmStatus ne "up" )
	{
		return -1;
	}

	# types: "http", "https", "datalink", "l4xnat", "gslb" or 1
	my $type = &getFarmType( $farm_name );

	my $backends;
	my $up_flag;             # almost one backend is not reachable
	my $down_flag;           # almost one backend is not reachable
	my $maintenance_flag;    # almost one backend is not reachable

	require Zevenet::Farm::Backend;

	# HTTP, optimized for many services
	if ( $type =~ /http/ )
	{
		require Zevenet::Farm::HTTP::Stats;
		my $stats = &getHTTPFarmBackendsStats( $farm_name );
		$backends = $stats->{ backends };
	}

	# GSLB
	elsif ( $type eq "gslb" && $eload )
	{
		my $stats = &eload(
							module => 'Zevenet::Farm::GSLB::Stats',
							func   => 'getGSLBFarmBackendsStats',
							args   => [$farm_name],
		);
		$backends = $stats->{ backends };
	}
	else
	{
		$backends = &getFarmServers( $farm_name );
	}

	# checking status
	foreach my $be ( @{ $backends } )
	{
		$up_flag          = 1 if $be->{ 'status' } eq "up";
		$maintenance_flag = 1 if $be->{ 'status' } eq "maintenance";
		$down_flag        = 1
		  if ( $be->{ 'status' } eq "down" || $be->{ 'status' } eq "fgDOWN" );

		# if there is a backend up and another down, the status is 'problem'
		last if ( $down_flag and $up_flag );
	}

	# check if redirect exists when there are not backends
	if ( $type =~ /http/ )
	{
		require Zevenet::Farm::HTTP::Service;
		foreach my $srv ( &getHTTPFarmServices( $farm_name ) )
		{
			if ( &getHTTPFarmVS( $farm_name, $srv, 'redirect' ) )
			{
				$up_flag = 1;
				last;
			}
		}
	}

	# Decision logic
	if ( !$up_flag )
	{
		$output = "critical";
	}
	elsif ( $down_flag )
	{
		$output = "problem";
	}
	elsif ( $maintenance_flag )
	{
		$output = "maintenance";
	}
	else
	{
		$output = "up";
	}

	return $output;
}

=begin nd
Function: getFarmPid

	Returns farm PID

Parameters:
	farmname - Farm name

Returns:
	Integer - return pid of farm, '-' if pid not exist or -1 on failure

=cut

sub getFarmPid    # ($farm_name)
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $farm_name = shift;

	my $farm_type = &getFarmType( $farm_name );
	my $output    = -1;

	if ( $farm_type eq "http" || $farm_type eq "https" )
	{
		require Zevenet::Farm::HTTP::Config;
		$output = &getHTTPFarmPid( $farm_name );
	}
	elsif ( $farm_type eq "gslb" && $eload )
	{
		$output = &eload(
						  module => 'Zevenet::Farm::GSLB::Config',
						  func   => 'getGSLBFarmPid',
						  args   => [$farm_name],
		);
	}

	return $output;
}

=begin nd
Function: getFarmBootStatus

	Return the farm status at boot zevenet

Parameters:
	farmname - Farm name

Returns:
	scalar - return "down" if the farm not run at boot or "up" if the farm run at boot
=cut

sub getFarmBootStatus    # ($farm_name)
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $farm_name = shift;

	my $farm_type = &getFarmType( $farm_name );
	my $output    = "down";

	if ( $farm_type =~ /http/ )
	{
		require Zevenet::Farm::HTTP::Config;
		$output = &getHTTPFarmBootStatus( $farm_name );
	}
	elsif ( $farm_type eq "datalink" )
	{
		require Zevenet::Farm::Datalink::Config;
		$output = &getDatalinkFarmBootStatus( $farm_name );
	}
	elsif ( $farm_type eq "l4xnat" )
	{
		require Zevenet::Farm::L4xNAT::Config;
		$output = &getL4FarmParam( 'bootstatus', $farm_name );
	}
	elsif ( $farm_type eq "gslb" && $eload )
	{
		$output = &eload(
						  module => 'Zevenet::Farm::GSLB::Config',
						  func   => 'getGSLBFarmBootStatus',
						  args   => [$farm_name],
		);
	}

	return $output;
}

=begin nd
Function: getFarmProto

	Return basic transport protocol used by the farm protocol

Parameters:
	farmname - Farm name

Returns:
	String - "udp" or "tcp"

BUG:
	Gslb works with tcp protocol too

FIXME:
	Use getL4ProtocolTransportLayer to get l4xnat protocol
=cut

sub getFarmProto    # ($farm_name)
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $farm_name = shift;

	my $farm_type     = &getFarmType( $farm_name );
	my $farm_filename = &getFarmFile( $farm_name );
	my $output        = -1;

	if ( $farm_type eq "l4xnat" )
	{
		require Zevenet::Farm::L4xNAT::Config;
		$output = &getL4FarmParam( 'proto', $farm_name );
	}
	elsif ( $farm_type =~ /http/i )
	{
		$output = "TCP";
	}
	elsif ( $farm_type eq "gslb" )
	{
		$output = "UDP";
	}

	return $output;
}

=begin nd
Function: getNumberOfFarmTypeRunning

	Counter how many farms exists in a farm profile.

Parameters:
	type - Farm profile: "http", "l4xnat", "gslb" or "datalink"

Returns:
	integer- Number of farms
=cut

sub getNumberOfFarmTypeRunning
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $type = shift;    # input value

	my $counter = 0;     # return value

	foreach my $farm_name ( &getFarmNameList() )
	{
		# count if requested farm type and running
		my $current_type   = &getFarmType( $farm_name );
		my $current_status = &getFarmStatus( $farm_name );

		if ( $current_type eq $type && $current_status eq 'up' )
		{
			$counter++;
		}
	}

	#~ &zenlog( "getNumberOfFarmTypeRunning: $type -> $counter" );  ########

	return $counter;
}

=begin nd
Function: getFarmListByVip

	Returns a list of farms that have the same IP address.

Parameters:
	ip - ip address

Returns:
	Array - List of farm names
=cut

sub getFarmListByVip
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $ip  = shift;
	my @out = ();

	foreach my $farm ( &getFarmNameList() )
	{
		if ( &getFarmVip( 'vip', $farm ) eq $ip )
		{
			push @out, $farm;
		}
	}
	return @out;
}

=begin nd
Function: getFarmRunning

	Returns the farms are currently running in the system.

Parameters:
	none - .

Returns:
	Array - List of farm names
=cut

sub getFarmRunning
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my @out = ();

	foreach my $farm ( &getFarmNameList() )
	{
		if ( &getFarmStatus( $farm ) eq 'up' )
		{
			push @out, $farm;
		}
	}
	return @out;
}

1;
