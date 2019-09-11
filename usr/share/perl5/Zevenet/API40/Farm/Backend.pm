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

use Zevenet::API40::HTTP;
use Zevenet::Farm::Core;
use Zevenet::Farm::Base;
use Zevenet::Net::Validate;
use Zevenet::API40::Farm::Get;

my $eload;
if ( eval { require Zevenet::ELoad; } )
{
	$eload = 1;
}

# POST

sub new_farm_backend    # ( $json_obj, $farmname )
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $json_obj = shift;
	my $farmname = shift;

	require Zevenet::Farm::Backend;

	# Initial parameters
	my $desc = "New farm backend";

	# Check that the farm exists
	if ( !&getFarmExists( $farmname ) )
	{
		my $msg = "The farmname $farmname does not exists.";
		&httpErrorResponse( code => 404, desc => $desc, msg => $msg );
	}

	my $type = &getFarmType( $farmname );
	if ( $type ne 'datalink' and $type ne 'l4xnat' )
	{
		my $msg = "The $type farm profile has backends only in services.";
		&httpErrorResponse( code => 404, desc => $desc, msg => $msg );
	}

	my $params = {
				   "priority" => {
								   'interval' => '1,9',
				   },
				   "weight" => {
								 'interval' => '1,9',
				   },
				   "ip" => {
							 'valid_format' => 'ip_addr',
							 'non_blank'    => 'true',
							 'format_msg'   => 'expects an IP',
							 'required'     => 'true'
				   },
	};

	if ( $type eq 'l4xnat' )
	{
		$params->{ "port" } = {
								'valid_format' => 'port',
								'format_msg'   => 'expects a port or port range'
		};
		$params->{ "max_conns" } = { 'interval' => '0,' };
	}
	else
	{
		$params->{ "interface" } = {
									 'non_black' => 'true',
									 'required'  => 'true'
		};
	}

	# Check allowed parameters
	my $error_msg = &checkZAPIParams( $json_obj, $params );
	return &httpErrorResponse( code => 400, desc => $desc, msg => $error_msg )
	  if ( $error_msg );

	my $id = &getFarmBackendAvailableID( $farmname );

	# check of interface for datalink
	if ( $type eq 'datalink' )
	{
		my $msg = &validateDatalinkBackendIface( $json_obj );
		if ( $msg )
		{
			&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
		}
	}

	# Create backend
	my $status = &setFarmServer( $farmname, undef, $id, $json_obj );
	if ( $status == -1 )
	{
		my $msg = "It was not possible to create the backend";
		&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
	}
	if ( $status == -2 )
	{
		my $msg = "The IP $json_obj->{ip} is already set in farm $farmname";
		&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
	}

	&zenlog( "New backend created in farm $farmname with IP $json_obj->{ip}.",
			 "info", "FARMS", "info", "FARMS" );

	# Backend retrieval
	my $serversArray = &getFarmServers( $farmname );
	my $out_b = &getFarmServer( $serversArray, $id );

	if ( !$out_b )
	{
		my $msg = "Error when retrieving the backend created";
		&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
	}

	&getAPIFarmBackends( $out_b, $type );

	my $message = "Backend added";
	my $body = {
				 description => $desc,
				 params      => $out_b,
				 message     => $message,
				 status      => &getFarmVipStatus( $farmname ),
	};

	&eload(
			module => 'Zevenet::Cluster',
			func   => 'runZClusterRemoteManager',
			args   => ['farm', 'restart', $farmname],
	) if ( $eload );

	&httpResponse( { code => 201, body => $body } );
}

sub new_service_backend    # ( $json_obj, $farmname, $service )
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $json_obj = shift;
	my $farmname = shift;
	my $service  = shift;

	# Initial parameters
	my $desc = "New service backend";

	my $params = {
				   "weight" => {
								 'interval' => '1,9',
				   },
				   "timeout" => {
								  'valid_format' => 'natural_num',
				   },
				   "ip" => {
							 'valid_format' => 'ip_addr',
							 'non_blank'    => 'true',
							 'format_msg'   => 'expects an IP',
							 'required'     => 'true',
				   },
				   "port" => {
							   'valid_format' => 'port',
							   'format_msg'   => 'expects a port',
							   'non_blank'    => 'true',
							   'required'     => 'true',
				   },
	};

	# Check that the farm exists
	if ( !&getFarmExists( $farmname ) )
	{
		my $msg = "The farmname $farmname does not exists.";
		&httpErrorResponse( code => 404, desc => $desc, msg => $msg );
	}

	# validate FARM TYPE
	my $type = &getFarmType( $farmname );

	if ( $type eq "gslb" && $eload )
	{
		&eload(
				module => 'Zevenet::API40::Farm::GSLB',
				func   => 'new_gslb_service_backend',
				args   => [$json_obj, $farmname, $service]
		);
	}
	elsif ( $type !~ /^https?$/ )
	{
		my $msg = "The $type farm profile does not support services.";
		&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
	}

	# HTTP
	require Zevenet::Farm::Config;
	require Zevenet::Farm::Backend;
	require Zevenet::Farm::HTTP::Backend;
	require Zevenet::Farm::HTTP::Service;

	# validate SERVICE
	my @services = &getHTTPFarmServices( $farmname );

	# Check if the provided service is configured in the farm
	unless ( grep ( /^$service$/, @services ) )
	{
		my $msg = "Invalid service name, please insert a valid value.";
		&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
	}

	# check if the service has configured a redirect
	if ( &getHTTPFarmVS( $farmname, $service, 'redirect' ) )
	{
		my $msg =
		  "It is not possible to create a backend when the service has a redirect configured.";
		&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
	}

	# Check allowed parameters
	my $error_msg = &checkZAPIParams( $json_obj, $params );
	return &httpErrorResponse( code => 400, desc => $desc, msg => $error_msg )
	  if ( $error_msg );

	# get an ID for the new backend
	my $id = &getHTTPFarmBackendAvailableID( $farmname, $service );

# First param ($id) is an empty string to let function autogenerate the id for the new backend
	my $status = &setHTTPFarmServer(
									 "",
									 $json_obj->{ ip },
									 $json_obj->{ port },
									 $json_obj->{ weight },
									 $json_obj->{ timeout },
									 $farmname,
									 $service,
	);

	# check if there was an error adding a new backend
	if ( $status == -1 )
	{
		my $msg = "It's not possible to create the backend with ip $json_obj->{ ip }"
		  . " and port $json_obj->{ port } for the $farmname farm";
		&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
	}

	# no error found, return successful response
	&zenlog(
		"Success, a new backend has been created in farm $farmname in service $service with IP $json_obj->{ip}.",
		"info", "FARMS"
	);

	$json_obj->{ timeout } = $json_obj->{ timeout } + 0 if $json_obj->{ timeout };

	if ( &getFarmStatus( $farmname ) eq 'up' )
	{
		require Zevenet::Farm::Action;
		&setFarmRestart( $farmname );
	}

	my $message = "Added backend to service successfully";
	my $body = {
				 description => $desc,
				 params      => @{ &getFarmServers( $farmname, $service ) }[$id],
				 message     => $message,
				 status      => &getFarmVipStatus( $farmname ),
	};

	&httpResponse( { code => 201, body => $body } );
}

# GET

#GET /farms/<name>/backends
sub backends
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $farmname = shift;

	my $desc = "List backends";
	require Zevenet::Farm::Backend;

	# Check that the farm exists
	if ( !&getFarmExists( $farmname ) )
	{
		my $msg = "The farmname $farmname does not exist.";
		&httpErrorResponse( code => 404, desc => $desc, msg => $msg );
	}

	my $type = &getFarmType( $farmname );
	if ( $type ne 'l4xnat' and $type ne 'datalink' )
	{
		my $msg =
		  "The farm $farmname with profile $type does not support this request.";
		&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
	}

	my $backends = &getFarmServers( $farmname );
	&getAPIFarmBackends( $backends, $type );

	my $body = {
				 description => $desc,
				 params      => $backends,
	};

	&httpResponse( { code => 200, body => $body } );
}

#GET /farms/<name>/services/<service>/backends
sub service_backends
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my ( $farmname, $service ) = @_;

	my $desc = "List service backends";
	my $backendstatus;

	# Check that the farm exists
	if ( !&getFarmExists( $farmname ) )
	{
		my $msg = "The farmname $farmname does not exist.";
		&httpErrorResponse( code => 404, desc => $desc, msg => $msg );
	}

	my $type = &getFarmType( $farmname );

	if ( $type eq 'gslb' && $eload )
	{
		&eload(
				module => 'Zevenet::API40::Farm::GSLB',
				func   => 'list_gslb_service_backends',
				args   => [$farmname, $service]
		);
	}

	if ( $type !~ /^https?$/ )
	{
		my $msg = "The farm profile $type does not support this request.";
		&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
	}

	# HTTP
	require Zevenet::Farm::HTTP::Service;

	my $service_ref = &getHTTPServiceStruct( $farmname, $service );

	# check if the requested service exists
	if ( $service_ref == -1 )
	{
		my $msg = "The service $service does not exist.";
		&httpErrorResponse( code => 404, desc => $desc, msg => $msg );
	}

	my $body = {
				 description => $desc,
				 params      => $service_ref->{ backends },
	};

	&httpResponse( { code => 200, body => $body } );
}

# PUT

sub modify_backends    #( $json_obj, $farmname, $id_server )
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my ( $json_obj, $farmname, $id_server ) = @_;

	my $desc = "Modify backend";

	require Zevenet::Farm::Backend;
	require Zevenet::Net::Validate;

	# Check that the farm exists
	if ( !&getFarmExists( $farmname ) )
	{
		my $msg = "The farmname $farmname does not exists.";
		&httpErrorResponse( code => 404, desc => $desc, msg => $msg );
	}

	my $type = &getFarmType( $farmname );
	if ( $type ne 'datalink' and $type ne 'l4xnat' )
	{
		my $msg = "The $type farm profile has backends only in services.";
		&httpErrorResponse( code => 404, desc => $desc, msg => $msg );
	}

	# get backends
	my $serversArray = &getFarmServers( $farmname );
	my $backend = &getFarmServer( $serversArray, $id_server );

	if ( !$backend || ref ( $backend ) ne "HASH" )
	{
		my $msg = "Could not find a backend with such id.";
		&httpErrorResponse( code => 404, desc => $desc, msg => $msg );
	}

	my $params = {
				   "priority" => {
								   'interval' => '1,9',
				   },
				   "weight" => {
								 'interval' => '1,9',
				   },
				   "ip" => {
							 'valid_format' => 'ip_addr',
							 'non_blank'    => 'true',
							 'format_msg'   => 'expects an IP'
				   },
	};

	if ( $type eq 'l4xnat' )
	{
		$params->{ "port" } = {
								'function'   => \&isValidPortNumber,
								'format_msg' => 'expects an port or port range'
		};
		$params->{ "max_conns" } = { 'interval' => '0,' };
	}
	else
	{
		$params->{ "interface" } = { 'non_black' => 'true', };
	}

	# Check allowed parameters
	my $error_msg = &checkZAPIParams( $json_obj, $params );
	return &httpErrorResponse( code => 400, desc => $desc, msg => $error_msg )
	  if ( $error_msg );

	$backend->{ ip } = $json_obj->{ ip } if exists $json_obj->{ ip };
	$backend->{ port } = $json_obj->{ port }
	  if exists $json_obj->{ port };    # l4xnat
	$backend->{ weight } = $json_obj->{ weight } if exists $json_obj->{ weight };
	$backend->{ priority } = $json_obj->{ priority }
	  if exists $json_obj->{ priority };
	$backend->{ max_conns } = $json_obj->{ max_conns }
	  if exists $json_obj->{ max_conns };    # l4xnat
	$backend->{ interface } = $json_obj->{ interface }
	  if exists $json_obj->{ interface };    # datalink

	if ( $type eq 'datalink' )
	{
		my $msg = &validateDatalinkBackendIface( $backend );
		if ( $msg )
		{
			&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
		}
	}

	my $error = &setFarmServer( $farmname, undef, $id_server, $backend );
	if ( $error == -2 )
	{
		my $msg = "The IP $json_obj->{ip} is already set in farm $farmname";
		&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
	}
	if ( $error )
	{
		my $msg = "Error trying to modify the backend $id_server.";
		&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
	}

	&zenlog(
		"Success, some parameters have been changed in the backend $id_server in farm $farmname.",
		"info", "FARMS"
	);

	my $message = "Backend modified";
	my $body = {
				 description => $desc,
				 params      => $json_obj,
				 message     => $message,
				 status      => &getFarmVipStatus( $farmname ),
	};

	&eload(
			module => 'Zevenet::Cluster',
			func   => 'runZClusterRemoteManager',
			args   => ['farm', 'restart', $farmname],
	) if ( $eload && &getFarmStatus( $farmname ) eq 'up' );

	&httpResponse( { code => 200, body => $body } );
}

sub modify_service_backends    #( $json_obj, $farmname, $service, $id_server )
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my ( $json_obj, $farmname, $service, $id_server ) = @_;

	my $desc = "Modify service backend";

	my $params = {
				   "weight" => {
								 'interval' => '1,9',
				   },
				   "timeout" => {
								  'valid_format' => 'natural_num',
				   },
				   "ip" => {
							 'valid_format' => 'ip_addr',
							 'non_blank'    => 'true',
							 'format_msg'   => 'expects an IP',
				   },
				   "port" => {
							   'function'   => \&isValidPortNumber,
							   'format_msg' => 'expects a port',
							   'non_blank'  => 'true',
				   },
	};

	# Check that the farm exists
	if ( !&getFarmExists( $farmname ) )
	{
		my $msg = "The farmname $farmname does not exist.";
		&httpErrorResponse( code => 404, desc => $desc, msg => $msg );
	}

	my $type = &getFarmType( $farmname );

	if ( $type eq "gslb" && $eload )
	{
		&eload(
				module => 'Zevenet::API40::Farm::GSLB',
				func   => 'modify_gslb_service_backends',
				args   => [$json_obj, $farmname, $service, $id_server]
		);
	}
	elsif ( $type !~ /^https?$/ )
	{
		my $msg = "The $type farm profile does not support services.";
		&httpErrorResponse( code => 404, desc => $desc, msg => $msg );
	}

	# HTTP
	require Zevenet::Farm::Action;
	require Zevenet::Farm::HTTP::Config;
	require Zevenet::Farm::HTTP::Backend;
	require Zevenet::Farm::HTTP::Service;

	# validate SERVICE
	my @services = &getHTTPFarmServices( $farmname );
	my $found_service = grep { $service eq $_ } @services;

	# check if the service exists
	if ( !$found_service )
	{
		my $msg = "Could not find the requested service.";
		&httpErrorResponse( code => 404, desc => $desc, msg => $msg );
	}

	# validate BACKEND
	my $be;
	{
		my @be_list = @{ &getHTTPFarmBackends( $farmname, $service ) };
		$be = $be_list[$id_server];
	}

	# check if the backend was found
	if ( !$be )
	{
		my $msg = "Could not find a service backend with such id.";
		&httpErrorResponse( code => 404, desc => $desc, msg => $msg );
	}

	# Check allowed parameters
	my $error_msg = &checkZAPIParams( $json_obj, $params );
	return &httpErrorResponse( code => 400, desc => $desc, msg => $error_msg )
	  if ( $error_msg );

	# apply BACKEND change

	$be->{ ip }      = $json_obj->{ ip }      // $be->{ ip };
	$be->{ port }    = $json_obj->{ port }    // $be->{ port };
	$be->{ weight }  = $json_obj->{ weight }  // $be->{ weight };
	$be->{ timeout } = $json_obj->{ timeout } // $be->{ timeout };

	my $status = &setHTTPFarmServer( $id_server,
									 $be->{ ip },
									 $be->{ port },
									 $be->{ weight },
									 $be->{ timeout },
									 $farmname, $service );

	# check if there was an error modifying the backend
	if ( $status == -1 )
	{
		my $msg =
		  "It's not possible to modify the backend with IP $json_obj->{ip} in service $service.";
		&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
	}

	# no error found, return successful response
	&zenlog(
		"Success, some parameters have been changed in the backend $id_server in service $service in farm $farmname.",
		"info", "FARMS"
	);

	if ( &getFarmStatus( $farmname ) eq "up" )
	{
		&setFarmRestart( $farmname );
	}

	my $body = {
				 description => $desc,
				 params      => $json_obj,
				 message     => "Backend modified",
				 status      => &getFarmVipStatus( $farmname ),
	};

	if ( &getFarmStatus( $farmname ) eq "up" )
	{
		$body->{ info } =
		  "There're changes that need to be applied, stop and start farm to apply them!";
	}

	&httpResponse( { code => 200, body => $body } );
}

# DELETE

# DELETE /farms/<farmname>/backends/<backendid> Delete a backend of a Farm
sub delete_backend    # ( $farmname, $id_server )
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my ( $farmname, $id_server ) = @_;

	require Zevenet::Farm::Backend;

	my $desc = "Delete backend";

	# validate FARM NAME
	if ( !&getFarmExists( $farmname ) )
	{
		my $msg = "The farmname $farmname does not exists.";
		&httpErrorResponse( code => 404, desc => $desc, msg => $msg );
	}

	# validate FARM TYPE
	my $type = &getFarmType( $farmname );
	unless ( $type eq 'l4xnat' || $type eq 'datalink' )
	{
		my $msg = "The $type farm profile has backends only in services.";
		&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
	}

	my $backends = &getFarmServers( $farmname );
	my $exists = &getFarmServer( $backends, $id_server );

	if ( !$exists )
	{
		my $msg = "Could not find a backend with such id.";
		&httpErrorResponse( code => 404, desc => $desc, msg => $msg );
	}

	my $status = &runFarmServerDelete( $id_server, $farmname );

	if ( $status == -1 )
	{
		my $msg =
		  "It's not possible to delete the backend with ID $id_server of the $farmname farm.";
		&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
	}

	&zenlog( "Success, the backend $id_server in farm $farmname has been deleted.",
			 "info", "FARMS" );

	&eload(
			module => 'Zevenet::Cluster',
			func   => 'runZClusterRemoteManager',
			args   => ['farm', 'delete', $farmname, 'backend', $id_server],
	) if ( $eload && $type eq 'l4xnat' );

	&eload(
			module => 'Zevenet::Cluster',
			func   => 'runZClusterRemoteManager',
			args   => ['farm', 'restart', $farmname],
	) if ( $eload && $type eq 'datalink' );

	my $message = "Backend removed";
	my $body = {
				 description => $desc,
				 success     => "true",
				 message     => $message,
				 status      => &getFarmVipStatus( $farmname ),
	};

	&httpResponse( { code => 200, body => $body } );
}

#  DELETE /farms/<farmname>/services/<servicename>/backends/<backendid> Delete a backend of a Service
sub delete_service_backend    # ( $farmname, $service, $id_server )
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my ( $farmname, $service, $id_server ) = @_;

	my $desc = "Delete service backend";

	# validate FARM NAME
	if ( !&getFarmExists( $farmname ) )
	{
		my $msg = "The farmname $farmname does not exists.";
		&httpErrorResponse( code => 404, desc => $desc, msg => $msg );
	}

	# validate FARM TYPE
	my $type = &getFarmType( $farmname );

	if ( $type eq 'gslb' && $eload )
	{
		&eload(
				module => 'Zevenet::API40::Farm::GSLB',
				func   => 'delete_gslb_service_backend',
				args   => [$farmname, $service, $id_server]
		);
	}
	elsif ( $type !~ /^https?$/ )
	{
		my $msg = "The $type farm profile does not support services.";
		&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
	}

	# HTTP
	require Zevenet::Farm::Action;
	require Zevenet::Farm::HTTP::Config;
	require Zevenet::Farm::HTTP::Backend;
	require Zevenet::Farm::HTTP::Service;

	# validate SERVICE
	my @services = &getHTTPFarmServices( $farmname );

	# check if the SERVICE exists
	unless ( grep { $service eq $_ } @services )
	{
		my $msg = "Could not find the requested service.";
		&httpErrorResponse( code => 404, desc => $desc, msg => $msg );
	}

	# check if the backend id is available
	my $be_found;
	{
		my $be = &getHTTPFarmBackends( $farmname, $service );
		$be_found = defined @{ $be }[$id_server];
	}

	unless ( $be_found )
	{
		my $msg = "Could not find the requested backend.";
		&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
	}

	my $status = &runHTTPFarmServerDelete( $id_server, $farmname, $service );

	# check if there was an error deleting the backend
	if ( $status == -1 )
	{
		&zenlog( "It's not possible to delete the backend.", "info", "FARMS" );

		my $msg =
		  "Could not find the backend with ID $id_server of the $farmname farm.";
		&httpErrorResponse( code => 404, desc => $desc, msg => $msg );
	}

	# no error found, return successful response
	&zenlog(
		"Success, the backend $id_server in service $service in farm $farmname has been deleted.",
		"info", "FARMS"
	);

	if ( &getFarmStatus( $farmname ) eq 'up' )
	{
		&setFarmRestart( $farmname );
	}

	my $message = "Backend removed";
	my $body = {
				 description => $desc,
				 success     => "true",
				 message     => $message,
				 status      => &getFarmVipStatus( $farmname ),
	};

	&httpResponse( { code => 200, body => $body } );
}

sub validateDatalinkBackendIface
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $backend = shift;
	my $msg;

	require Zevenet::Net::Interface;
	my $iface_ref = &getInterfaceConfig( $backend->{ interface } );

	if ( not defined $iface_ref )
	{
		$msg = "$backend->{interface} has not been found";
	}
	elsif ( $iface_ref->{ vini } )
	{
		$msg = "It is not possible to configure vlan interface for datalink backends";
	}
	elsif (
		  !&getNetValidate( $iface_ref->{ addr }, $iface_ref->{ mask }, $backend->{ ip }
		  )
	  )
	{
		$msg =
		  "The $backend->{ ip } IP must be in the same network than the $iface_ref->{ addr } interface.";
	}

	return $msg;
}

1;
