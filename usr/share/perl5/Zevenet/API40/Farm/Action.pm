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

my $eload;
if ( eval { require Zevenet::ELoad; } )
{
	$eload = 1;
}

# PUT /farms/<farmname>/actions Set an action in a Farm
sub farm_actions    # ( $json_obj, $farmname )
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $json_obj = shift;
	my $farmname = shift;

	require Zevenet::Farm::Action;
	require Zevenet::Farm::Base;

	my $desc = "Farm actions";

	my $params = {
				   "action" => {
								 'values'    => ['stop', 'start', 'restart'],
								 'non_blank' => 'true',
								 'required'  => 'true',
				   },
	};

	# validate FARM NAME
	if ( !&getFarmExists( $farmname ) )
	{
		my $msg = "The farmname $farmname does not exist.";
		&httpErrorResponse( code => 404, desc => $desc, msg => $msg );
	}

	if ( &getFarmType( $farmname ) =~ /http/ )
	{
		require Zevenet::Farm::HTTP::Config;
		my $err_msg = &getHTTPFarmConfigErrorMessage( $farmname );

		if ( $err_msg )
		{
			&httpErrorResponse( code => 400, desc => $desc, msg => $err_msg );
		}
	}

	# Check allowed parameters
	my $error_msg = &checkZAPIParams( $json_obj, $params );
	return &httpErrorResponse( code => 400, desc => $desc, msg => $error_msg )
	  if ( $error_msg );

	if ( $json_obj->{ action } eq "stop" )
	{
		my $status = &runFarmStop( $farmname, "true" );

		if ( $status != 0 )
		{
			my $msg = "Error trying to set the action stop in farm $farmname.";
			&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
		}
	}
	elsif ( $json_obj->{ action } eq "start" )
	{
		require Zevenet::Net::Interface;

		# check if the ip exists in any interface
		my $ip = &getFarmVip( "vip", $farmname );

		if ( !&getIpAddressExists( $ip ) )
		{
			my $msg = "The virtual ip $ip is not defined in any interface.";
			&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
		}

		my $status = &runFarmStart( $farmname, "true" );

		if ( $status )
		{
			my $msg = "Error trying to set the action start in farm $farmname.";
			&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
		}
	}
	elsif ( $json_obj->{ action } eq "restart" )
	{
		my $status = &runFarmStop( $farmname, "true" );

		if ( $status )
		{
			my $msg =
			  "Error trying to stop the farm in the action restart in farm $farmname.";
			&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
		}

		require Zevenet::Net::Interface;

		# check if the ip exists in any interface
		my $ip = &getFarmVip( "vip", $farmname );

		if ( !&getIpAddressExists( $ip ) )
		{
			my $msg = "The virtual ip $ip is not defined in any interface.";
			&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
		}

		$status = &runFarmStart( $farmname, "true" );

		if ( $status )
		{
			my $msg =
			  "ZAPI error, trying to start the farm in the action restart in farm $farmname.";
			&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
		}
	}

	&zenlog(
		"Success, the action $json_obj->{ action } has been performed in farm $farmname.",
		"info", "FARMS"
	);

	&eload(
			module => 'Zevenet::Cluster',
			func   => 'runZClusterRemoteManager',
			args   => ['farm', $json_obj->{ action }, $farmname],
	) if ( $eload );

	my $body = {
				 description => "Set a new action in $farmname",
				 params      => {
							 "action" => $json_obj->{ action },
							 "status" => &getFarmVipStatus( $farmname ),
				 },
	};

	&httpResponse( { code => 200, body => $body } );
}

# Set an action in a backend of http|https farm
# PUT /farms/<farmname>/services/<service>/backends/<backend>/maintenance
sub service_backend_maintenance # ( $json_obj, $farmname, $service, $backend_id )
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $json_obj   = shift;
	my $farmname   = shift;
	my $service    = shift;
	my $backend_id = shift;

	require Zevenet::Farm::Base;
	require Zevenet::Farm::HTTP::Config;
	require Zevenet::Farm::HTTP::Service;
	require Zevenet::Farm::HTTP::Backend;

	my $desc = "Set service backend status";

	my $params = {
				   "action" => {
								 'non_blank' => 'true',
								 'values'    => ["up", "maintenance"],
				   },
	};

	if ( $json_obj->{ action } eq 'maintenance' )
	{
		$params->{ "mode" } = {
								'non_blank' => 'true',
								'values'    => ["drain", "cut"],
		};
	}

	# Check allowed parameters
	my $error_msg = &checkZAPIParams( $json_obj, $params );
	return &httpErrorResponse( code => 400, desc => $desc, msg => $error_msg )
	  if ( $error_msg );

	# validate FARM NAME
	if ( !&getFarmExists( $farmname ) )
	{
		my $msg = "The farmname $farmname does not exists.";
		&httpErrorResponse( code => 404, desc => $desc, msg => $msg );
	}

	# validate FARM TYPE
	if ( &getFarmType( $farmname ) !~ /^https?$/ )
	{
		my $msg = "Only HTTP farm profile supports this feature.";
		&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
	}

	# validate SERVICE
	my @services = &getHTTPFarmServices( $farmname );
	my $found_service;

	foreach my $service_name ( @services )
	{
		if ( $service eq $service_name )
		{
			$found_service = 1;
			last;
		}
	}

	if ( !$found_service )
	{
		my $msg = "Could not find the requested service.";
		&httpErrorResponse( code => 404, desc => $desc, msg => $msg );
	}

	# validate BACKEND
	my $be_aref = &getHTTPFarmBackends( $farmname, $service );
	my $be = $be_aref->[$backend_id - 1];

	if ( !$be )
	{
		my $msg = "Could not find a service backend with such id.";
		&httpErrorResponse( code => 404, desc => $desc, msg => $msg );
	}

   # Do not allow to modify the maintenance status if the farm needs to be restarted
	require Zevenet::Lock;
	if ( &getLockStatus( $farmname ) )
	{
		my $msg = "The farm needs to be restarted before to apply this action.";
		&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
	}

	# validate STATUS
	if ( $json_obj->{ action } eq "maintenance" )
	{
		my $maintenance_mode = $json_obj->{ mode } // "drain";    # default

		my $status =
		  &setHTTPFarmBackendMaintenance( $farmname, $backend_id, $maintenance_mode,
										  $service );

		if ( $status )
		{
			my $msg = "Errors found trying to change status backend to maintenance";
			&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
		}
	}
	elsif ( $json_obj->{ action } eq "up" )
	{
		my $status =
		  &setHTTPFarmBackendNoMaintenance( $farmname, $backend_id, $service );

		if ( $status )
		{
			my $msg = "Errors found trying to change status backend to up";
			&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
		}
	}

	my $body = {
				 description => $desc,
				 params      => {
							 action => $json_obj->{ action },
							 farm   => {
									   status => &getFarmVipStatus( $farmname ),
							 },
				 },
	};

	&eload(
			module => 'Zevenet::Cluster',
			func   => 'runZClusterRemoteManager',
			args   => ['farm', 'restart', $farmname],
	) if ( $eload && &getFarmStatus( $farmname ) eq 'up' );

	&httpResponse( { code => 200, body => $body } );
}

# PUT backend in maintenance
# PUT /farms/<farmname>/backends/<backend>/maintenance
sub backend_maintenance    # ( $json_obj, $farmname, $backend_id )
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $json_obj   = shift;
	my $farmname   = shift;
	my $backend_id = shift;

	require Zevenet::Farm::Backend::Maintenance;
	require Zevenet::Farm::Backend;
	require Zevenet::Farm::Base;

	my $desc = "Set backend status";

	my $params = {
				   "action" => {
								 'non_blank' => 'true',
								 'values'    => ["up", "maintenance"],
				   },
	};

	if ( $json_obj->{ action } eq 'maintenance' )
	{
		$params->{ "mode" } = {
								'non_blank' => 'true',
								'values'    => ["drain", "cut"],
		};
	}

	# Check allowed parameters
	my $error_msg = &checkZAPIParams( $json_obj, $params );
	return &httpErrorResponse( code => 400, desc => $desc, msg => $error_msg )
	  if ( $error_msg );

	# validate FARM NAME
	if ( !&getFarmExists( $farmname ) )
	{
		my $msg = "The farmname $farmname does not exists.";
		&httpErrorResponse( code => 404, desc => $desc, msg => $msg );
	}

	# validate FARM TYPE
	unless ( &getFarmType( $farmname ) eq 'l4xnat' )
	{
		my $msg = "Only L4xNAT farm profile supports this feature.";
		&httpErrorResponse( code => 404, desc => $desc, msg => $msg );
	}

	# validate BACKEND
	require Zevenet::Farm::L4xNAT::Backend;

	my $backends = &getL4FarmServers( $farmname );
	my $exists = &getFarmServer( $backends, $backend_id );

	if ( !$exists )
	{
		my $msg = "Could not find a backend with such id.";
		&httpErrorResponse( code => 404, desc => $desc, msg => $msg );
	}

	# validate STATUS
	if ( $json_obj->{ action } eq "maintenance" )
	{
		my $maintenance_mode = $json_obj->{ mode } // "drain";    # default

		my $status =
		  &setFarmBackendMaintenance( $farmname, $backend_id, $maintenance_mode );

		if ( $status != 0 )
		{
			my $msg = "Errors found trying to change status backend to maintenance";
			&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
		}
	}
	elsif ( $json_obj->{ action } eq "up" )
	{
		my $status = &setFarmBackendNoMaintenance( $farmname, $backend_id );

		if ( $status )
		{
			my $msg = "Errors found trying to change status backend to up";
			&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
		}
	}

	# no error found, send successful response
	my $body = {
				 description => $desc,
				 params      => {
							 action => $json_obj->{ action },
							 farm   => {
									   status => &getFarmVipStatus( $farmname ),
							 },
				 },
	};

	&eload(
			module => 'Zevenet::Cluster',
			func   => 'runZClusterRemoteManager',
			args   => ['farm', 'restart', $farmname],
	) if ( $eload && &getFarmStatus( $farmname ) eq 'up' );

	&httpResponse( { code => 200, body => $body } );
}

1;
