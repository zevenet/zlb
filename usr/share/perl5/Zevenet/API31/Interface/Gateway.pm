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

sub get_gateway
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	require Zevenet::Net::Route;

	my $desc = "Default gateway";

	my $body = {
		description => $desc,
		params      => {
			address   => &getDefaultGW(),
			interface => &getIfDefaultGW(),

		},
	};

	&httpResponse( { code => 200, body => $body } );
}

sub modify_gateway    # ( $json_obj )
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $json_obj = shift;

	require Zevenet::Net::Route;

	my $desc       = "Modify default gateway";
	my $default_gw = &getDefaultGW();

	# verify ONLY ACCEPTED parameters received
	if ( grep { $_ !~ /^(?:address|interface)$/ } keys %$json_obj )
	{
		my $msg = "Parameter received not recognized";
		&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
	}

	# if default gateway is not configured requires address and interface
	if ( $default_gw )
	{
		# verify AT LEAST ONE parameter received
		unless ( exists $json_obj->{ address } || exists $json_obj->{ interface } )
		{
			my $msg = "No parameter received to be configured";
			&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
		}
	}
	else
	{
		unless ( exists $json_obj->{ address } && exists $json_obj->{ interface } )
		{
			my $msg = "Gateway requires address and interface to be configured";
			&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
		}
	}

	# validate ADDRESS
	if ( exists $json_obj->{ address } )
	{
		unless ( defined ( $json_obj->{ address } )
				 && &getValidFormat( 'IPv4_addr', $json_obj->{ address } ) )
		{
			my $msg = "Gateway address is not valid.";
			&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
		}
	}

	# validate INTERFACE
	if ( exists $json_obj->{ interface } )
	{
		require Zevenet::Net::Interface;

		my @system_interfaces = &getInterfaceList();

		unless ( grep ( { $json_obj->{ interface } eq $_ } @system_interfaces ) )
		{
			my $msg = "Gateway interface not found.";
			&httpErrorResponse( code => 404, desc => $desc, msg => $msg );
		}
	}

	my $ip_version = 4;
	my $interface  = $json_obj->{ interface } // &getIfDefaultGW();
	my $address    = $json_obj->{ address } // $default_gw;

	require Zevenet::Net::Interface;
	my $if_ref = &getInterfaceConfig( $interface, $ip_version );

	# check if network is correct
	require Zevenet::Net::Validate;
	unless ( &validateGateway( $if_ref->{ addr }, $if_ref->{ mask }, $address ) )
	{
		my $msg = "The gateway is not valid for the network.";
		&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
	}

	&zenlog( "applyRoutes interface:$interface address:$address if_ref:$if_ref",
			 "debug", "NETWORK" )
	  if &debug();

	my $error = &applyRoutes( "global", $if_ref, $address );

	if ( $error )
	{
		my $msg = "The default gateway hasn't been changed";
		&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
	}

	my $msg = "The default gateway has been changed successfully";
	my $body = {
				 description => $desc,
				 success     => "true",
				 message     => $msg,
	};

	&httpResponse( { code => 200, body => $body } );
}

sub delete_gateway
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	require Zevenet::Net::Route;
	require Zevenet::Net::Interface;

	my $desc        = "Remove default gateway";
	my $ip_version  = 4;
	my $defaultgwif = &getIfDefaultGW();
	my $if_ref      = &getInterfaceConfig( $defaultgwif, $ip_version );
	my $error       = &delRoutes( "global", $if_ref );

	if ( $error )
	{
		my $msg = "The default gateway hasn't been deleted";
		&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
	}

	my $msg = "The default gateway has been deleted successfully";
	my $body = {
		description => $desc,
		message     => $msg,
		params      => {
			address   => &getDefaultGW(),
			interface => &getIfDefaultGW(),

		},
	};

	&httpResponse( { code => 200, body => $body } );
}

1;
