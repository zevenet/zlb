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

my $eload;
if ( eval { require Zevenet::ELoad; } )
{
	$eload = 1;
}

=begin nd
Function: runFarmCreate

	Create a farm

Parameters:
	type - Farm type. The available options are: "http", "https", "datalink", "l4xnat" or "gslb"
	vip - Virtual IP where the virtual service is listening
	port - Virtual port where the virtual service is listening
	farmname - Farm name
	type - Specify if farm is HTTP or HTTPS
	iface - Inteface wich uses the VIP. This parameter is only used in datalink farms

Returns:
	Integer - return 0 on success or different of 0 on failure

FIXME:
	Use hash to pass the parameters
=cut

sub runFarmCreate    # ($farm_type,$vip,$vip_port,$farm_name,$fdev)
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my ( $farm_type, $vip, $vip_port, $farm_name, $fdev ) = @_;

	my $output        = -1;
	my $farm_filename = &getFarmFile( $farm_name );

	if ( $farm_filename != -1 )
	{
		# the farm name already exists
		$output = -2;
		return $output;
	}

	&zenlog( "running 'Create' for $farm_name farm $farm_type", "info", "LSLB" );

	if ( $farm_type =~ /^HTTPS?$/i )
	{
		require Zevenet::Farm::HTTP::Factory;
		$output = &runHTTPFarmCreate( $vip, $vip_port, $farm_name, $farm_type );
	}
	elsif ( $farm_type =~ /^DATALINK$/i )
	{
		require Zevenet::Farm::Datalink::Factory;
		$output = &runDatalinkFarmCreate( $farm_name, $vip, $fdev );
	}
	elsif ( $farm_type =~ /^L4xNAT$/i )
	{
		require Zevenet::Farm::L4xNAT::Factory;
		$output = &runL4FarmCreate( $vip, $farm_name, $vip_port );
	}
	elsif ( $farm_type =~ /^GSLB$/i )
	{
		$output = &eload(
						  module => 'Zevenet::Farm::GSLB::Factory',
						  func   => 'runGSLBFarmCreate',
						  args   => [$vip, $vip_port, $farm_name],
		) if $eload;
	}

	&eload(
			module => 'Zevenet::RBAC::Group::Config',
			func   => 'addRBACUserResource',
			args   => [$farm_name, 'farms'],
	) if $eload;

	return $output;
}

1;
