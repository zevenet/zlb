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

my $configdir = &getGlobalConfiguration('configdir');

=begin nd
Function: getFarmVip

	Returns farm vip or farm port

Parameters:
	tag - requested parameter. The options are "vip" for virtual ip or "vipp" for virtual port
	farmname - Farm name

Returns:
	Scalar - return vip or port of farm or -1 on failure

Bugs:
	WARNING: vipps parameter is only used in tcp farms. Soon this parameter will be obsolete.

See Also:
	setFarmVirtualConf
=cut
sub getFarmVip    # ($info,$farm_name)
{
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
		$output = &getL4FarmVip( $info, $farm_name );
	}
	elsif ( $farm_type eq "datalink" )
	{
		require Zevenet::Farm::Datalink::Config;
		$output = &getDatalinkFarmVip( $info, $farm_name );
	}
	elsif ( $farm_type eq "gslb" )
	{
		if ( eval { require Zevenet::Farm::GSLB::Config; } )
		{
			$output = &getGSLBFarmVip( $info, $farm_name );
		}
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
	my $farm_name = shift;

	my $output = -1;
	return $output if !defined ( $farm_name );    # farm name cannot be empty

	my $farm_type = &getFarmType( $farm_name );
	my $piddir = &getGlobalConfiguration('piddir');

	# for every farm type but datalink or l4xnat
	if ( $farm_type ne "datalink" && $farm_type ne "l4xnat" )
	{
		my $pid = &getFarmPid( $farm_name );
		my $running_pid;
		$running_pid = kill ( 0, $pid ) if $pid ne "-";

		if ( $pid ne "-" && $running_pid )
		{
			$output = "up";
		}
		else
		{
			if ( $pid ne "-" && !$running_pid )
			{
				unlink &getGSLBFarmPidFile( $farm_name ) if ( $farm_type eq 'gslb' );
				unlink "$piddir\/$farm_name\_pound.pid"  if ( $farm_type =~ /http/ );
			}

			$output = "down";
		}
	}
	else
	{
		# Only for datalink and l4xnat
		if ( -e "$piddir\/$farm_name\_$farm_type.pid" )
		{
			$output = "up";
		}
		else
		{
			$output = "down";
		}
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
	my $farm_name = shift;

	my $output = -1;
	my $farmStatus = &getFarmStatus( $farm_name );
	return $output if !defined ( $farm_name );    # farm name cannot be empty

	$output = "problem";
	if ( &getFarmLock( $farm_name ) != -1 )
	{
		return "needed restart";
	}
	elsif ( $farmStatus eq "down" )
	{
		return "down";
	}
	elsif ( $farmStatus ne "up" )
	{
		return -1;
	}

	# types: "http", "https", "datalink", "l4xnat", "gslb" or 1
	my $type = &getFarmType( $farm_name );

	my $backends;
	my $up_flag;		# almost one backend is not reachable
	my $down_flag; 	# almost one backend is not reachable
	my $maintenance_flag; 	# almost one backend is not reachable

	# Profile without services
	if ( $type eq "datalink" || $type eq "l4xnat" )
	{
		require Zevenet::Farm::Config;
		$backends = &getFarmBackends( $farm_name );
	}
	# Profiles with services
	elsif ( $type eq "gslb" )
	{
		require Zevenet::Farm::GSLB::Stats;
		my $stats = &getGSLBFarmBackendsStats($farm_name);
		$backends = $stats->{ backends };
	}
	# Profiles with services
	elsif ( $type =~ /http/ )
	{
		require Zevenet::Farm::HTTP::Stats;
		my $stats = &getHTTPFarmBackendsStats($farm_name);
		$backends = $stats->{ backends };
	}

	# checking status
	foreach my $be ( @{$backends} )
	{
		$up_flag = 1 if $be->{ 'status' } eq "up";
		$maintenance_flag = 1 if $be->{ 'status' } eq "maintenance";
		$down_flag = 1 if $be->{ 'status' } eq "down";

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
	if( !$up_flag )
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
	my $farm_name = shift;

	my $farm_type = &getFarmType( $farm_name );
	my $output    = -1;

	if ( $farm_type eq "http" || $farm_type eq "https" )
	{
		require Zevenet::Farm::HTTP::Config;
		$output = &getHTTPFarmPid( $farm_name );
	}
	elsif ( $farm_type eq "gslb" )
	{
		if ( eval { require Zevenet::Farm::GSLB::Config; } )
		{
			$output = &getGSLBFarmPid( $farm_name );
		}
	}

	return $output;
}

=begin nd
Function: getFarmLock

	Check if a farm is locked.

	A locked farm needs to be restarted to apply the latest changes.

Parameters:
	farmname - Farm name

Returns:
	Scalar - Return content of lock file if it is locked or -1 the farm is not locked

NOTE:
	Generic function
=cut
sub getFarmLock    # ($farm_name)
{
	my $farm_name = shift;

	my $output = -1;
	my $lockfile = "/tmp/$farm_name.lock";

	if ( -e $lockfile )
	{
		open( my $fh, '<', $lockfile );
		read $fh, $output, 255;
		close $fh;
	}

	return $output;
}

=begin nd
Function: setFarmLock

	Set the lock status to "on" or "off"
	If the new status in "on" it's possible to set a message inside.

	A locked farm needs to be restarted to apply the latest changes.

Parameters:
	farmname - Farm name
	status - This parameter can value "on" or "off"
	message - Text for lock file

Returns:
	none - No returned value

NOTE:
	Generic function
=cut
sub setFarmLock    # ($farm_name, $status, $msg)
{
	my ( $farm_name, $status, $msg ) = @_;

	my $lockfile = "/tmp/$farm_name.lock";
	my $lockstatus = &getFarmLock( $farm_name );

	if ( $status eq "on" && $lockstatus == -1 )
	{
		open my $fh, '>', $lockfile;
		print $fh "$msg";
		close $fh;
	}

	if ( $status eq "off" )
	{
		unlink( $lockfile ) if -e $lockfile;
	}
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
	my $farm_name = shift;

	my $farm_type = &getFarmType( $farm_name );
	my $output    = "down";

	if ( $farm_type eq "http" || $farm_type eq "https" )
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
		$output = &getL4FarmBootStatus( $farm_name );
	}
	elsif ( $farm_type eq "gslb" )
	{
		if ( eval { require Zevenet::Farm::GSLB::Config; } )
		{
			$output = &getGSLBFarmBootStatus( $farm_name );
		}
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
	my $farm_name = shift;

	my $farm_type     = &getFarmType( $farm_name );
	my $farm_filename = &getFarmFile( $farm_name );
	my $output        = -1;

	if ( $farm_type eq "l4xnat" )
	{
		open FI, "<", "$configdir/$farm_filename";
		my $first = "true";
		while ( my $line = <FI> )
		{
			if ( $line ne "" && $first eq "true" )
			{
				$first = "false";
				my @line = split ( "\;", $line );
				$output = $line[1];
			}
		}
		close FI;
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
	my $type    = shift;    # input value

	my $counter = 0;        # return value

	foreach my $farm_name ( &getFarmNameList() )
	{
		# count if requested farm type and running
		my $current_type = &getFarmType( $farm_name );
		my $current_status = &getFarmStatus( $farm_name );

		if ( $current_type eq $type && $current_status eq 'up' )
		{
			$counter++;
		}
	}

	#~ &zenlog( "getNumberOfFarmTypeRunning: $type -> $counter" );  ########

	return $counter;
}

1;
