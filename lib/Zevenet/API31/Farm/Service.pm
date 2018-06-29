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
use Zevenet::Farm::Core;

# POST
sub new_farm_service    # ( $json_obj, $farmname )
{
	my $json_obj = shift;
	my $farmname = shift;

	require Zevenet::Farm::Service;

	my $desc = "New service";

	# Check if the farm exists
	if ( &getFarmFile( $farmname ) == -1 )
	{
		my $msg = "The farmname $farmname does not exists.";
		&httpErrorResponse( code => 404, desc => $desc, msg => $msg );
	}

	# check if the service exists
	if ( grep ( /^$json_obj->{id}$/, &getFarmServices( $farmname ) ) )
	{
		my $msg = "Error, the service $json_obj->{id} already exists.";
		&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
	}

	my $type = &getFarmType( $farmname );

	# validate farm profile
	if ( $type eq "gslb" )
	{
		require Zevenet::ELoad;
		&eload( module => 'Zevenet::API31::Farm::GSLB', func => 'new_gslb_farm_service', args => [ $json_obj, $farmname ] );
	}
	elsif ( $type !~ /^https?$/ )
	{
		my $msg = "The farm profile $type does not support services.";
		&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
	}

	# HTTP profile
	require Zevenet::Farm::Base;
	require Zevenet::Farm::HTTP::Service;

	# validate new service name
	# FIXME: validate service name
	if ( $json_obj->{ id } eq '' )
	{
		my $msg = "Invalid service name, please insert a valid value.";
		&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
	}

	my $result = &setFarmHTTPNewService( $farmname, $json_obj->{ id } );

	# check if a service with such name already exists
	if ( $result == 1 )
	{
		my $msg = "Service name " . $json_obj->{ id } . " already exists.";
		&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
	}

	# check if the service name was empty
	if ( $result == 2 )
	{
		my $msg = "The service name can't be empty.";
		&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
	}

	# check if the service name has invalid characters
	if ( $result == 3 )
	{
		my $msg =
		  "Service name is not valid, only allowed numbers, letters and hyphens.";
		&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
	}

	# Return 0 on success
	if ( $result )
	{
		my $msg =
		  "Error creating the service $json_obj->{ id }.";
		&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
	}

	# no error found, return successful response
	&zenlog(
		"ZAPI success, a new service has been created in farm $farmname with id $json_obj->{id}."
	);

	my $body = {
				 description => $desc,
				 params      => { id => $json_obj->{ id } },
	};

	if ( &getFarmStatus( $farmname ) eq 'up' )
	{
		require Zevenet::Farm::Action;

		&setFarmRestart( $farmname );
		$body->{ status } = 'needed restart';
	}

	&httpResponse( { code => 201, body => $body } );
}

# GET

#GET /farms/<name>/services/<service>
sub farm_services
{
	my ( $farmname, $servicename ) = @_;

	require Zevenet::Farm::Config;
	require Zevenet::Farm::HTTP::Service;

	my $desc = "Get services of a farm";
	my $service;

	# Check if the farm exists
	if ( &getFarmFile( $farmname ) eq '-1' )
	{
		my $msg = "The farmname $farmname does not exist.";
		&httpErrorResponse( code => 404, desc => $desc, msg => $msg );
	}

	my $type = &getFarmType( $farmname );

	# check the farm type is supported
	if ( $type !~ /http/i )
	{
		my $msg = "This functionality only is available for HTTP farms.";
		&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
	}

	my @services = &getHTTPFarmServices( $farmname );

	# check if the service is available
	if ( !grep { $servicename eq $_ } @services )
	{
		my $msg = "The required service does not exist.";
		&httpErrorResponse( code => 404, desc => $desc, msg => $msg );
	}

	# no error found, return successful response
	my $service = &getServiceStruct( $farmname, $servicename );

	foreach my $be ( @{ $service->{ backends } } )
	{
		$be->{ status } = "up" if $be->{ status } eq "undefined";
	}

	my $body = {
				 description => $desc,
				 params    => $service,
	};

	&httpResponse( { code => 200, body => $body } );
}

# PUT

sub modify_services    # ( $json_obj, $farmname, $service )
{
	my ( $json_obj, $farmname, $service ) = @_;

	require Zevenet::Farm::Base;
	require Zevenet::Farm::Config;
	require Zevenet::Farm::Service;

	my $desc = "Modify service";
	my $output_params;

	# validate FARM NAME
	if ( &getFarmFile( $farmname ) == -1 )
	{
		my $msg = "The farmname $farmname does not exist.";
		&httpErrorResponse( code => 404, desc => $desc, msg => $msg );
	}

	# validate FARM TYPE
	my $type = &getFarmType( $farmname );

	unless ( $type eq 'gslb' || $type eq 'http' || $type eq 'https' )
	{
		my $msg = "The $type farm profile does not support services.";
		&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
	}

	# validate SERVICE
	my @services = &getFarmServices( $farmname );
	my $found_service = grep { $service eq $_ } @services;

	if ( not $found_service )
	{
		my $msg = "Could not find the requested service.";
		&httpErrorResponse( code => 404, desc => $desc, msg => $msg );
	}

	# check if the farm profile gslb is supported
	if ( $type eq "gslb" )
	{
		require Zevenet::ELoad;
		&eload( module => 'Zevenet::API31::Farm::GSLB', func => 'modify_gslb_service', args => [ $json_obj, $farmname, $service ] );
	}
	elsif ( $type !~ /^https?$/ )
	{
		my $msg = "Farm profile not supported";
		&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
	}

	if ( exists $json_obj->{ vhost } )
	{
		&setFarmVS( $farmname, $service, "vs", $json_obj->{ vhost } );
	}

	if ( exists $json_obj->{ urlp } )
	{
		&setFarmVS( $farmname, $service, "urlp", $json_obj->{ urlp } );
	}

	my $redirecttype = &getFarmVS( $farmname, $service, "redirecttype" );

	if ( exists $json_obj->{ redirect } )
	{
		my $redirect = $json_obj->{ redirect };

		unless (    $redirect =~ /^http\:\/\//i
				 || $redirect =~ /^https:\/\//i
				 || $redirect eq '' )
		{
			my $msg = "Invalid redirect value.";
			&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
		}

		&setFarmVS( $farmname, $service, "redirect", $redirect );
	}

	my $redirect = &getFarmVS( $farmname, $service, "redirect" );

	if ( exists $json_obj->{ redirecttype } )
	{
		my $redirecttype = $json_obj->{ redirecttype };

		if ( $redirecttype eq "default" )
		{
			&setFarmVS( $farmname, $service, "redirect", $redirect );
		}
		elsif ( $redirecttype eq "append" )
		{
			&setFarmVS( $farmname, $service, "redirectappend", $redirect );
		}
		elsif ( exists $json_obj->{ redirect } && $json_obj->{ redirect } )
		{
			my $msg = "Invalid redirecttype value.";
			&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
		}
	}

	if ( exists $json_obj->{ leastresp } )
	{
		if ( $json_obj->{ leastresp } eq "true" )
		{
			&setFarmVS( $farmname, $service, "dynscale", $json_obj->{ leastresp } );
		}
		elsif ( $json_obj->{ leastresp } eq "false" )
		{
			&setFarmVS( $farmname, $service, "dynscale", "" );
		}
		else
		{
			my $msg = "Invalid leastresp.";
			&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
		}
	}

	if ( exists $json_obj->{ persistence } )
	{
		if ( $json_obj->{ persistence } =~ /^(|IP|BASIC|URL|PARM|COOKIE|HEADER)$/ )
		{
			my $session = $json_obj->{ persistence };
			$session = 'nothing' if $session eq "";

			my $error = &setFarmVS( $farmname, $service, "session", $session );
			if ( $error )
			{
				my $msg = "It's not possible to change the persistence parameter.";
				&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
			}
		}
	}

	my $session = &getFarmVS( $farmname, $service, "sesstype" );

	# It is necessary evaluate first session, next ttl and later persistence
	if ( exists $json_obj->{ sessionid } )
	{
		if ( $session =~ /^(URL|COOKIE|HEADER)$/ )
		{
			&setFarmVS( $farmname, $service, "sessionid", $json_obj->{ sessionid } );
		}
	}

	if ( exists $json_obj->{ ttl } )
	{
		if ( $session =~ /^(IP|BASIC|URL|PARM|COOKIE|HEADER)$/ )
		{
			if ( $json_obj->{ ttl } !~ /^\d+$/ )
			{
				my $msg = "Invalid ttl, must be numeric.";
				&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
			}

			my $error = &setFarmVS( $farmname, $service, "ttl", "$json_obj->{ttl}" );
			if ( $error )
			{
				my $msg = "Could not change the ttl parameter.";
				&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
			}
		}
	}

	if ( exists ( $json_obj->{ cookieinsert } ) )
	{
		if ( $json_obj->{ cookieinsert } eq "true" )
		{
			&setFarmVS( $farmname, $service, "cookieins", $json_obj->{ cookieinsert } );
		}
		elsif ( $json_obj->{ cookieinsert } eq "false" )
		{
			&setFarmVS( $farmname, $service, "cookieins", "" );
		}
		else
		{
			my $msg = "Invalid cookieinsert value.";
			&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
		}
	}

	my $cookieins_status = &getHTTPFarmVS( $farmname, $service, 'cookieins' );
	if ( $cookieins_status eq "true" )
	{
		if ( exists $json_obj->{ cookiedomain } )
		{
			&setFarmVS( $farmname, $service, "cookieins-domain",
						$json_obj->{ cookiedomain } );
		}

		if ( exists $json_obj->{ cookiename } )
		{
			&setFarmVS( $farmname, $service, "cookieins-name", $json_obj->{ cookiename } );
		}

		if ( exists $json_obj->{ cookiepath } )
		{
			&setFarmVS( $farmname, $service, "cookieins-path", $json_obj->{ cookiepath } );
		}

		if ( exists $json_obj->{ cookiettl } )
		{
			if ( $json_obj->{ cookiettl } eq '' )
			{
				my $msg = "Invalid cookiettl, can't be blank.";
				&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
			}

			&setFarmVS( $farmname, $service, "cookieins-ttlc", $json_obj->{ cookiettl } );
		}
	}

	if ( exists $json_obj->{ httpsb } )
	{
		if ( $json_obj->{ httpsb } ne &getFarmVS( $farmname, $service, 'httpsbackend' ) )
		{
			if ( $json_obj->{ httpsb } eq "true" )
			{
				&setFarmVS( $farmname, $service, "httpsbackend", $json_obj->{ httpsb } );
			}
			elsif ( $json_obj->{ httpsb } eq "false" )
			{
				&setFarmVS( $farmname, $service, "httpsbackend", "" );
			}
			else
			{
				my $msg = "Invalid httpsb value.";
				&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
			}
		}
	}

	# no error found, return succesful response
	$output_params = &getHTTPServiceStruct( $farmname, $service );

	&zenlog(
		"ZAPI success, some parameters have been changed in service $service in farm $farmname."
	);

	my $body = {
				 description => "Modify service $service in farm $farmname",
				 params      => $output_params,
	};

	if ( &getFarmStatus( $farmname ) eq 'up' )
	{
		require Zevenet::Farm::Action;

		&setFarmRestart( $farmname );
		$body->{ status } = 'needed restart';
		$body->{ info } =
		  "There're changes that need to be applied, stop and start farm to apply them!";
	}

	&httpResponse( { code => 200, body => $body } );
}

# DELETE

# DELETE /farms/<farmname>/services/<servicename> Delete a service of a Farm
sub delete_service    # ( $farmname, $service )
{
	my ( $farmname, $service ) = @_;

	my $desc = "Delete service";

	# Check if the farm exists
	if ( &getFarmFile( $farmname ) == -1 )
	{
		my $msg = "The farmname $farmname does not exists.";
		&httpErrorResponse( code => 404, desc => $desc, msg => $msg );
	}

	# check the farm type is supported
	my $type = &getFarmType( $farmname );

	if ( $type eq "gslb" )
	{
		require Zevenet::ELoad;
		&eload( module => 'Zevenet::API31::Farm::GSLB', func => 'delete_gslb_service', args => [ $farmname, $service ] );
	}
	elsif ( $type !~ /^https?$/ )
	{
		my $msg = "The farm profile $type does not support services.";
		&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
	}

	require Zevenet::Farm::Base;
	require Zevenet::Farm::HTTP::Service;

	# Check that the provided service is configured in the farm
	my @services = &getHTTPFarmServices( $farmname );
	my $found    = 0;

	foreach my $farmservice ( @services )
	{
		if ( $service eq $farmservice )
		{
			$found = 1;
			last;
		}
	}

	unless ( $found )
	{
		my $msg = "Invalid service name, please insert a valid value.";
		&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
	}

	my $error = &deleteFarmService( $farmname, $service );

	# check if the service is in use
	if ( $error == -2 )
	{
		my $msg = "The service is used by a zone.";
		&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
	}

	# check if the service could not be deleted
	if ( $error )
	{
		my $msg = "Service $service in farm $farmname hasn't been deleted.";
		&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
	}

	# no errors found, returning successful response
	&zenlog(
			 "ZAPI success, the service $service in farm $farmname has been deleted." );

	my $message = "The service $service in farm $farmname has been deleted.";
	my $body = {
				 description => $desc,
				 success     => "true",
				 message     => $message,
	};

	if ( &getFarmStatus( $farmname ) eq 'up' )
	{
		require Zevenet::Farm::Action;

		$body->{ status } = "needed restart";
		&setFarmRestart( $farmname );
	}

	&httpResponse( { code => 200, body => $body } );
}

1;
