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

use Zevenet::Farm::Backend::Maintenance;

my $eload;
if ( eval { require Zevenet::ELoad; } ) { $eload = 1; }

=begin nd
Function: getFarmServers

	List all farm backends and theirs configuration

Parameters:
	farmname - Farm name
	service - service backends related (optional)

Returns:
	array ref - list of backends

FIXME:
	changes output to hash format

=cut
sub getFarmServers    # ($farm_name, $service)
{
	&zenlog(__FILE__ . ":" . __LINE__ . ":" . (caller(0))[3] . "( @_ )", "debug", "PROFILING" );
	my ( $farm_name, $service ) = @_;

	my $farm_type = &getFarmType( $farm_name );
	my $servers;

	if ( $farm_type =~ /http/ )
	{
		require Zevenet::Farm::HTTP::Backend;
		$servers = &getHTTPFarmBackends( $farm_name, $service );
	}
	elsif ( $farm_type eq "l4xnat" )
	{
		require Zevenet::Farm::L4xNAT::Backend;
		$servers = &getL4FarmServers( $farm_name );
	}
	elsif ( $farm_type eq "datalink" )
	{
		require Zevenet::Farm::Datalink::Backend;
		$servers = &getDatalinkFarmBackends( $farm_name );
	}
	elsif ( $farm_type eq "gslb" && $eload )
	{
		$servers = &eload(
						  module => 'Zevenet::Farm::GSLB::Backend',
						  func   => 'getGSLBFarmBackends',
						  args   => [$farm_name, $service],
		);
	}

	return $servers;
}

=begin nd
Function: setFarmServer

	Add a new Backend

Parameters:
	id - Backend id, if this id doesn't exist, it will create a new backend
	ip - Real server ip
	port | iface - Real server port or interface if the farm is datalink
	max - parameter for l4xnat farm
	weight - The higher the weight, the more request will go to this backend.
	priority -  The lower the priority, the most preferred is the backend.
	timeout - HTTP farm parameter
	farmname - Farm name
	service - service name. For HTTP farms

Returns:
	Scalar - Error code: undef on success or -1 on error

FIXME:
	Use a hash
	max parameter is only used by tcp farms

=cut
sub setFarmServer # $output ($ids,$rip,$port|$iface,$max,$weight,$priority,$timeout,$farm_name,$service)
{
	&zenlog(__FILE__ . ":" . __LINE__ . ":" . (caller(0))[3] . "( @_ )", "debug", "PROFILING" );
	my (
		 $ids,      $rip,     $port,      $max, $weight,
		 $priority, $timeout, $farm_name, $service
	) = @_;

	my $farm_type = &getFarmType( $farm_name );
	my $output    = -1;

	&zenlog(
		"setting 'Server $ids $rip $port max $max weight $weight prio $priority timeout $timeout' for $farm_name farm $farm_type", "info", "FARMS"
	);

	if ( $farm_type eq "datalink" )
	{
		require Zevenet::Farm::Datalink::Backend;
		$output =
		  &setDatalinkFarmServer( $ids, $rip, $port, $weight, $priority, $farm_name );
	}
	elsif ( $farm_type eq "l4xnat" )
	{
		require Zevenet::Farm::L4xNAT::Backend;
		$output = &setL4FarmServer( $ids, $rip, $port, $weight, $priority, $farm_name, $max );
	}
	elsif ( $farm_type eq "http" || $farm_type eq "https" )
	{
		require Zevenet::Farm::HTTP::Backend;
		$output =
		  &setHTTPFarmServer( $ids, $rip, $port, $priority, $timeout, $farm_name,
							  $service, );
	}

	# FIXME: include setGSLBFarmNewBackend

	return $output;
}

=begin nd
Function: runFarmServerDelete

	Delete a Backend

Parameters:
	id - Backend id, if this id doesn't exist, it will create a new backend
	farmname - Farm name
	service - service name. For HTTP farms

Returns:
	Scalar - Error code: undef on success or -1 on error

=cut
sub runFarmServerDelete    # ($ids,$farm_name,$service)
{
	&zenlog(__FILE__ . ":" . __LINE__ . ":" . (caller(0))[3] . "( @_ )", "debug", "PROFILING" );
	my ( $ids, $farm_name, $service ) = @_;

	my $farm_type = &getFarmType( $farm_name );
	my $output    = -1;

	&zenlog( "running 'ServerDelete $ids' for $farm_name farm $farm_type", "info", "FARMS" );

	if ( $farm_type eq "datalink" )
	{
		require Zevenet::Farm::Datalink::Backend;
		$output = &runDatalinkFarmServerDelete( $ids, $farm_name );
	}
	elsif ( $farm_type eq "l4xnat" )
	{
		require Zevenet::Farm::L4xNAT::Backend;
		$output = &runL4FarmServerDelete( $ids, $farm_name );
	}
	elsif ( $farm_type eq "http" || $farm_type eq "https" )
	{
		require Zevenet::Farm::HTTP::Backend;
		$output = &runHTTPFarmServerDelete( $ids, $farm_name, $service );
	}
	elsif ( $farm_type eq "gslb" && $eload )
	{
		$output = &eload(
						  module => 'Zevenet::Farm::GSLB::Backend',
						  func   => 'runGSLBFarmServerDelete',
						  args   => [$ids, $farm_name, $service],
		);
	}

	return $output;
}

1;
