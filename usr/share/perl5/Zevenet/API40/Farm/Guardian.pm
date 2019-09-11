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

use Zevenet::FarmGuardian;
use Zevenet::Farm::Core;

my $eload;
if ( eval { require Zevenet::ELoad; } )
{
	$eload = 1;
}

sub getZapiFG
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $fg_name = shift;

	my $fg = &getFGObject( $fg_name );
	my $out = {
				'name'        => $fg_name,
				'description' => $fg->{ description },
				'command'     => $fg->{ command },
				'farms'       => $fg->{ farms },
				'log'         => $fg->{ log } // 'false',
				'interval'    => $fg->{ interval } + 0,
				'cut_conns'   => $fg->{ cut_conns },
				'template'    => $fg->{ template },
	};

	return $out;
}

sub getZapiFGList
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my @out;
	my @list = &getFGList();

	foreach my $fg_name ( @list )
	{
		my $fg = &getZapiFG( $fg_name );
		push @out, $fg;
	}

	return \@out;
}

# first, it checks is exists and later look for in both lists, template and config
#  GET /monitoring/fg/<fg_name>
sub get_farmguardian
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $fg_name = shift;

	my $desc = "Retrive the farm guardian $fg_name";

	unless ( &getFGExists( $fg_name ) )
	{
		my $msg = "The farm guardian $fg_name has not been found.";
		return &httpErrorResponse( code => 404, desc => $desc, msg => $msg );
	}

	my $out = &getZapiFG( $fg_name );
	my $body = { description => $desc, params => $out };

	return &httpResponse( { code => 200, body => $body } );
}

#  GET /monitoring/fg
sub list_farmguardian
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $fg   = &getZapiFGList();
	my $desc = "List farm guardian checks and templates";

	return &httpResponse(
					 { code => 200, body => { description => $desc, params => $fg } } );
}

#  POST /monitoring/fg
sub create_farmguardian
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $json_obj = shift;
	my $fg_name  = $json_obj->{ name };
	my $desc     = "Create a farm guardian $fg_name";

	if ( &getFGExistsConfig( $fg_name ) )
	{
		my $msg = "The farm guardian $fg_name already exists.";
		return &httpErrorResponse( code => 400, desc => $desc, msg => $msg );
	}

	if ( &getFGExistsTemplate( $fg_name ) )
	{
		my $msg =
		  "The farm guardian $fg_name is a template, select another name, please";
		return &httpErrorResponse( code => 400, desc => $desc, msg => $msg );
	}

	my $params = {
				   "name" => {
							   'non_blank'    => 'true',
							   'required'     => 'true',
							   'valid_format' => 'fg_name',
				   },
				   "copy_from" => {
									'valid_format' => 'fg_name',
				   },
	};

	# Check allowed parameters
	my $error_msg = &checkZAPIParams( $json_obj, $params );
	return &httpErrorResponse( code => 400, desc => $desc, msg => $error_msg )
	  if ( $error_msg );

	if ( exists $json_obj->{ copy_from }
		 and not &getFGExists( $json_obj->{ copy_from } ) )
	{
		my $msg = "The parent farm guardian $json_obj->{ copy_from } does not exist.";
		return &httpErrorResponse( code => 400, desc => $desc, msg => $msg );
	}

	if ( not exists $json_obj->{ copy_from } ) { &createFGBlank( $fg_name ); }
	elsif ( &getFGExistsTemplate( $json_obj->{ copy_from } ) )
	{
		&createFGTemplate( $fg_name, $json_obj->{ copy_from } );
	}
	else { &createFGConfig( $fg_name, $json_obj->{ copy_from } ); }

	my $out = &getZapiFG( $fg_name );
	if ( $out )
	{
		my $msg = "The farm guardian $fg_name has been created successfully.";
		my $body = {
					 description => $desc,
					 params      => $out,
					 message     => $msg,
		};
		return &httpResponse( { code => 200, body => $body } );
	}
	else
	{
		my $msg = "The farm guardian $fg_name could not be created";
		return &httpErrorResponse( code => 400, desc => $desc, msg => $msg );
	}
}

#  PUT /monitoring/fg/<fg_name>
sub modify_farmguardian
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $json_obj = shift;
	my $fgname   = shift;

	my $desc = "Modify farm guardian $fgname";

	unless ( &getFGExists( $fgname ) )
	{
		my $msg = "The farm guardian $fgname does not exist.";
		return &httpErrorResponse( code => 400, desc => $desc, msg => $msg );
	}

	my $params = {
				   "description" => {
									  'non_blank' => 'true',
				   },
				   "command" => {
								  'non_blank' => 'true',
				   },
				   "log" => {
							  'valid_format' => 'boolean',
				   },
				   "interval" => {
								   'valid_format' => 'natural_num',
				   },
				   "cut_conns" => {
									'valid_format' => 'boolean',
				   },
				   "force" => {
								'valid_format' => 'boolean',
				   },
	};

	# Check allowed parameters
	my $error_msg = &checkZAPIParams( $json_obj, $params );
	return &httpErrorResponse( code => 400, desc => $desc, msg => $error_msg )
	  if ( $error_msg );

	my @run_farms = @{ &getFGRunningFarms( $fgname ) };
	my $run_farms;
	$run_farms = join ( ', ', @run_farms ) if @run_farms;

	# avoid modifying some parameters of a template
	if ( &getFGExistsTemplate( $fgname ) )
	{
		if ( exists $json_obj->{ 'description' } or exists $json_obj->{ 'command' } )
		{
			my $msg =
			  "It is not allow to modify the parameters 'description' or 'command' in a template.";
			return &httpErrorResponse( code => 400, desc => $desc, msg => $msg );
		}
	}

	# check if farm guardian is running
	if (     $run_farms
		 and not exists $json_obj->{ force }
		 and $json_obj->{ force } ne 'true' )
	{
		if ( exists $json_obj->{ command } )
		{
			my $error_msg =
			  "Farm guardian $fgname is running in: $run_farms. To apply, send parameter 'force'";
			&httpErrorResponse( code => 400, desc => $desc, msg => $error_msg );
		}
	}

	delete $json_obj->{ force };
	my $error = &setFGObject( $fgname, $json_obj );

	if ( not $error )
	{
		# sync with cluster
		if ( $eload )
		{
			&eload(
					module => 'Zevenet::Cluster',
					func   => 'runZClusterRemoteManager',
					args   => ['fg', 'restart', $fgname],
			);
		}

		# no error found, return successful response
		my $msg =
		  "Success, some parameters have been changed in farm guardian $fgname.";
		my $out = &getZapiFG( $fgname );
		my $body = { description => $desc, params => $out, message => $msg, };

		&httpResponse( { code => 200, body => $body } );
	}
	else
	{
		my $msg = "Modifying farm guardian $fgname.";
		my $body = { description => $desc, message => $msg, };

		&httpResponse( { code => 400, body => $body } );
	}
}

#  DELETE /monitoring/fg/<fg_name>
sub delete_farmguardian
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $fg_name = shift;

	my $desc = "Delete the farm guardian $fg_name";

	unless ( &getFGExists( $fg_name ) )
	{
		my $msg = "The farm guardian $fg_name does not exist";
		return &httpErrorResponse( code => 404, desc => $desc, msg => $msg );
	}

	my @running_farms = @{ &getFGRunningFarms( $fg_name ) };
	if ( @running_farms )
	{
		my $farm_str = join ( ', ', @running_farms );
		my $msg =
		  "It is not possible delete farm guardian $fg_name because it is running in: $farm_str";
		return &httpErrorResponse( code => 400, desc => $desc, msg => $msg );
	}

	&delFGObject( $fg_name );

	if ( !&getFGExists( $fg_name ) )
	{
		# sync with cluster
		if ( $eload )
		{
			&eload(
					module => 'Zevenet::Cluster',
					func   => 'runZClusterRemoteManager',
					args   => ['fg', 'stop', $fg_name],
			);
		}

		my $msg = "$fg_name has been deleted successfully.";
		my $body = {
					 description => $desc,
					 success     => "true",
					 message     => $msg,
		};
		return &httpResponse( { code => 200, body => $body } );
	}
	else
	{
		my $msg = "Deleting the farm guardian $fg_name.";
		return &httpErrorResponse( code => 400, desc => $desc, msg => $msg );
	}
}

#  POST /farms/<farm>(/services/<service>)?/fg
sub add_farmguardian_farm
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $json_obj = shift;
	my $farm     = shift;
	my $srv      = shift;

	my $srv_message = ( $srv ) ? "service $srv in the farm $farm" : "farm $farm";

	my $desc = "Add the farm guardian $json_obj->{ 'name' } to the $srv_message";
	my $params = {
				   "name" => {
							   'non_blank' => 'true',
							   'required'  => 'true',
				   },
	};

	require Zevenet::Farm::Service;

	# Check if it exists
	if ( !&getFarmExists( $farm ) )
	{
		my $msg = "The farm $farm does not exist";
		return &httpErrorResponse( code => 404, desc => $desc, msg => $msg );
	}

	# Check if it exists
	if ( !&getFGExists( $json_obj->{ name } ) )
	{
		my $msg = "The farmguardian $json_obj->{ name } does not exist";
		return &httpErrorResponse( code => 404, desc => $desc, msg => $msg );
	}

	# Check if it exists
	if ( $srv and !grep ( /^$srv$/, &getFarmServices( $farm ) ) )
	{
		my $msg = "The service $srv does not exist";
		return &httpErrorResponse( code => 404, desc => $desc, msg => $msg );
	}

	# check if another fg is applied to the farm
	my $fg_old = &getFGFarm( $farm, $srv );
	if ( $fg_old )
	{
		my $msg = "The $srv_message has already linked a farm guardian";
		return &httpErrorResponse( code => 400, desc => $desc, msg => $msg );
	}

	# link the check with the farm_service
	my $farm_tag = $farm;
	$farm_tag = "${farm}_$srv" if $srv;

	# Check allowed parameters
	my $error_msg = &checkZAPIParams( $json_obj, $params );
	return &httpErrorResponse( code => 400, desc => $desc, msg => $error_msg )
	  if ( $error_msg );

	# check if the farm guardian is already applied to the farm
	my $fg_obj = &getFGObject( $json_obj->{ name } );
	if ( grep ( /^$farm_tag$/, @{ $fg_obj->{ farms } } ) )
	{
		my $msg = "$json_obj->{ name } is already applied in the $srv_message";
		return &httpErrorResponse( code => 400, desc => $desc, msg => $msg );
	}

	# check farm type
	my $type = &getFarmType( $farm );
	if ( $type =~ /http|gslb/ and not $srv )
	{
		my $msg = "The farm guardian expects a service";
		return &httpErrorResponse( code => 400, desc => $desc, msg => $msg );
	}

	my $output = &linkFGFarm( $json_obj->{ name }, $farm, $srv );

	# check result and return success or failure
	if ( !$output )
	{
		# sync with cluster
		if ( $eload )
		{
			&eload(
					module => 'Zevenet::Cluster',
					func   => 'runZClusterRemoteManager',
					args   => ['fg_farm', 'start', $farm, $srv],
			);
		}

		my $msg =
		  "Success, The farm guardian $json_obj->{ 'name' } was added to the $srv_message";
		my $body = {
					 description => $desc,
					 message     => $msg,
					 status      => &getFarmVipStatus( $farm ),
		};
		return &httpResponse( { code => 200, body => $body } );
	}
	else
	{
		my $msg =
		  "There was an error trying to add $json_obj->{ 'name' } to the $srv_message";
		return &httpErrorResponse( code => 400, desc => $desc, msg => $msg );
	}

}

#  DELETE /farms/<farm>(/services/<service>)?/fg/<fg_name>
sub rem_farmguardian_farm
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $farm = shift;
	my $srv;
	my $fgname;

	if ( scalar @_ == 1 )
	{
		$fgname = shift;
	}
	else
	{
		$srv    = shift;
		$fgname = shift;
	}

	my $srv_message = ( $srv ) ? "service $srv in the farm $farm" : "farm $farm";
	my $desc = "Remove the farm guardian $fgname from the $srv_message";

	require Zevenet::Farm::Service;

	# Check if it exists
	if ( !&getFarmExists( $farm ) )
	{
		my $msg = "The farm $farm does not exist";
		return &httpErrorResponse( code => 404, desc => $desc, msg => $msg );
	}

	# Check if it exists
	if ( !&getFGExists( $fgname ) )
	{
		my $msg = "The farmguardian $fgname does not exist";
		return &httpErrorResponse( code => 404, desc => $desc, msg => $msg );
	}

	# Check if it exists
	if ( $srv and !grep ( /^$srv$/, &getFarmServices( $farm ) ) )
	{
		my $msg = "The service $srv does not exist";
		return &httpErrorResponse( code => 404, desc => $desc, msg => $msg );
	}

	# link the check with the farm_service
	my $farm_tag = $farm;
	$farm_tag = "${farm}_$srv" if $srv;

	# check if the farm guardian is already applied to the farm
	my $fg_obj = &getFGObject( $fgname );
	if ( not grep ( /^$farm_tag$/, @{ $fg_obj->{ farms } } ) )
	{
		my $msg = "The farm guardian $fgname is not applied to the $srv_message";
		return &httpErrorResponse( code => 400, desc => $desc, msg => $msg );
	}

	&unlinkFGFarm( $fgname, $farm, $srv );

	# check output
	$fg_obj = &getFGObject( $fgname );
	if ( grep ( /^$farm_tag$/, @{ $fg_obj->{ farms } } ) or &getFGPidFarm( $farm ) )
	{
		my $msg = "Error removing $fgname from the $srv_message";
		return &httpErrorResponse( code => 400, desc => $desc, msg => $msg );
	}
	else
	{
		require Zevenet::Farm::Base;

		# sync with cluster
		if ( $eload )
		{
			&eload(
					module => 'Zevenet::Cluster',
					func   => 'runZClusterRemoteManager',
					args   => ['fg_farm', 'stop', $farm, $srv],
			);
		}

		my $msg = "Success, $fgname was removed from the $srv_message";
		my $body = {
					 description => $desc,
					 message     => $msg,
					 status      => &getFarmVipStatus( $farm ),
		};
		return &httpResponse( { code => 200, body => $body } );
	}
}

1;
