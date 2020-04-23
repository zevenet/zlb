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
	my ( $ip_ver ) = @_;

	require Zevenet::Net::Route;

	my $desc = "Default gateway";
	my $ip_v = ( $ip_ver == 6 ) ? 6 : 4;

	my $addr =
	  ( $ip_v == 6 ) ? &getIPv6DefaultGW() : &getDefaultGW();

	my $if_name =
	  ( $ip_v == 6 ) ? &getIPv6IfDefaultGW() : &getIfDefaultGW();

	my $body = {
				 description => $desc,
				 params      => {
							 address   => $addr,
							 interface => $if_name,
				 },
	};

	&httpResponse( { code => 200, body => $body } );
}

sub modify_gateway    # ( $json_obj )
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $json_obj = shift;
	my $ip_ver   = shift;

	require Zevenet::Net::Route;

	my $desc       = "Modify default gateway";
	my $ip_v       = ( $ip_ver == 6 ) ? 6 : 4;
	my $default_gw = ( $ip_v == 6 ) ? &getIPv6DefaultGW() : &getDefaultGW();
	my $mandatory  = 'false';
	my $ip_format  = ( $ip_v == 6 ) ? 'IPv6_addr' : 'IPv4_addr';

	# if default gateway is not configured requires address and interface
	if ( !$default_gw )
	{
		$mandatory = 'true';
	}

	my $params = {
				   "interface" => {
									'non_blank' => 'true',
									'required'  => $mandatory,
				   },
				   "address" => {
								  'valid_format' => $ip_format,
								  'non_blank'    => 'true',
								  'required'     => $mandatory,
				   },
	};

	# Check allowed parameters
	my $error_msg = &checkZAPIParams( $json_obj, $params, $desc );
	return &httpErrorResponse( code => 400, desc => $desc, msg => $error_msg )
	  if ( $error_msg );

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

	my $interface = $json_obj->{ interface };
	my $address = $json_obj->{ address } // $default_gw;

	unless ( $interface )
	{
		$interface = ( $ip_ver == 6 ) ? &getIPv6IfDefaultGW() : &getIfDefaultGW();
	}

	require Zevenet::Net::Interface;
	my $if_ref = &getInterfaceConfig( $interface );

	# check if network is correct
	require Zevenet::Net::Validate;

	unless ( &getNetValidate( $if_ref->{ addr }, $if_ref->{ mask }, $address ) )
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
	my ( $ip_ver ) = @_;

	require Zevenet::Net::Route;
	require Zevenet::Net::Interface;

	my $desc = "Remove default gateway";
	my $ip_v = ( $ip_ver == 6 ) ? 6 : 4;

	my $defaultgwif = ( $ip_v == 6 ) ? &getIPv6IfDefaultGW() : &getIfDefaultGW();
	my $if_ref      = &getInterfaceConfig( $defaultgwif );
	my $error       = &delRoutes( "global", $if_ref );

	if ( $error )
	{
		my $msg = "The default gateway hasn't been deleted";
		&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
	}

	my $addr =
	  ( $ip_v == 6 ) ? &getIPv6DefaultGW() : &getDefaultGW();

	my $if_name =
	  ( $ip_v == 6 ) ? &getIPv6IfDefaultGW() : &getIfDefaultGW();

	my $msg = "The default gateway has been deleted successfully";
	my $body = {
				 description => $desc,
				 message     => $msg,
				 params      => {
							 address   => $addr,
							 interface => $if_name,
				 },
	};

	&httpResponse( { code => 200, body => $body } );
}

1;
