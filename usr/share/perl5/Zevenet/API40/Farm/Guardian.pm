#!/usr/bin/perl
###############################################################################
#
#    ZEVENET Software License
#    This file is part of the ZEVENET Load Balancer software package.
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
use warnings;
use Zevenet::FarmGuardian;
use Zevenet::Farm::Core;


sub getZapiFG
{
	&zenlog( __FILE__ . q{:} . __LINE__ . q{:} . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $fg_name = shift;

	my $fg = &getFGObject( $fg_name );
	my $out = {
				'name'          => $fg_name,
				'backend_alias' => $fg->{ backend_alias } // 'false',
				'description'   => $fg->{ description },
				'command'       => $fg->{ command },
				'farms'         => $fg->{ farms },
				'log'           => $fg->{ log } // 'false',
				'interval'      => $fg->{ interval } + 0,
				'cut_conns'     => $fg->{ cut_conns },
				'template'      => $fg->{ template },
				'timeout'       => ( $fg->{ timeout } // $fg->{ interval } ) + 0,
	};

	return $out;
}

sub getZapiFGList
{
	&zenlog( __FILE__ . q{:} . __LINE__ . q{:} . ( caller ( 0 ) )[3] . "( @_ )",
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
	&zenlog( __FILE__ . q{:} . __LINE__ . q{:} . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $fg_name = shift;

	my $desc = "Retrive the farm guardian '$fg_name'";

	unless ( &getFGExists( $fg_name ) )
	{
		my $msg = "The farm guardian '$fg_name' has not been found.";
		&httpErrorResponse( code => 404, desc => $desc, msg => $msg );
	}

	my $out = &getZapiFG( $fg_name );
	my $body = { description => $desc, params => $out };

	&httpResponse( { code => 200, body => $body } );
	return;
}

#  GET /monitoring/fg
sub list_farmguardian
{
	&zenlog( __FILE__ . q{:} . __LINE__ . q{:} . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $fg   = &getZapiFGList();
	my $desc = "List farm guardian checks and templates";

	&httpResponse(
				   { code => 200, body => { description => $desc, params => $fg } } );
	return;
}

#  POST /monitoring/fg
sub create_farmguardian
{
	&zenlog( __FILE__ . q{:} . __LINE__ . q{:} . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $json_obj = shift;
	my $fg_name  = $json_obj->{ name };
	my $desc     = "Create a farm guardian '$fg_name'";

	if ( &getFGExistsConfig( $fg_name ) )
	{
		my $msg = "The farm guardian '$fg_name' already exists.";
		&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
	}

	if ( &getFGExistsTemplate( $fg_name ) )
	{
		my $msg =
		  "The farm guardian '$fg_name' is a template, select another name, please";
		&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
	}

	my $params = &getZAPIModel( "farmguardian-create.json" );

	# Check allowed parameters
	my $error_msg = &checkZAPIParams( $json_obj, $params, $desc );
	if ( $error_msg )
	{
		&httpErrorResponse( code => 400, desc => $desc, msg => $error_msg );
	}

	if ( exists $json_obj->{ copy_from }
		 and not &getFGExists( $json_obj->{ copy_from } ) )
	{
		my $msg = "The parent farm guardian '$json_obj->{ copy_from }' does not exist.";
		&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
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
		my $msg = "The farm guardian '$fg_name' has been created successfully.";
		my $body = {
					 description => $desc,
					 params      => $out,
					 message     => $msg,
		};
		&httpResponse( { code => 200, body => $body } );
	}
	else
	{
		my $msg = "The farm guardian '$fg_name' could not be created";
		&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
	}
	return;
}

#  PUT /monitoring/fg/<fg_name>
sub modify_farmguardian
{
	&zenlog( __FILE__ . q{:} . __LINE__ . q{:} . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $json_obj = shift;
	my $fgname   = shift;

	my $desc = "Modify farm guardian '$fgname'";

	unless ( &getFGExists( $fgname ) )
	{
		my $msg = "The farm guardian '$fgname' does not exist.";
		&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
	}

	my $params = &getZAPIModel( "farmguardian-modify.json" );

	# Check allowed parameters
	my $error_msg = &checkZAPIParams( $json_obj, $params, $desc );
	if ( $error_msg )
	{
		&httpErrorResponse( code => 400, desc => $desc, msg => $error_msg );
	}

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
			&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
		}
	}

	# check if farm guardian is running
	if (     $run_farms
		 and not exists $json_obj->{ force }
		 and $json_obj->{ force } ne 'true' )
	{
		if ( exists $json_obj->{ command } or exists $json_obj->{ backend_alias } )
		{
			my $error_msg =
			  "Farm guardian '$fgname' is running in: '$run_farms'. To apply, send parameter 'force'";
			&httpErrorResponse( code => 400, desc => $desc, msg => $error_msg );
		}
	}

	delete $json_obj->{ force };
	my $error = &setFGObject( $fgname, $json_obj );

	if ( not $error )
	{
		# no error found, return successful response
		my $msg =
		  "Success, some parameters have been changed in farm guardian '$fgname'.";
		my $out = &getZapiFG( $fgname );
		my $body = { description => $desc, params => $out, message => $msg, };

		&httpResponse( { code => 200, body => $body } );
	}
	else
	{
		my $msg = "Modifying farm guardian '$fgname'.";
		my $body = { description => $desc, message => $msg, };

		&httpResponse( { code => 400, body => $body } );
	}
	return;
}

#  DELETE /monitoring/fg/<fg_name>
sub delete_farmguardian
{
	&zenlog( __FILE__ . q{:} . __LINE__ . q{:} . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $fg_name = shift;

	my $desc = "Delete the farm guardian '$fg_name'";

	unless ( &getFGExists( $fg_name ) )
	{
		my $msg = "The farm guardian $fg_name does not exist";
		&httpErrorResponse( code => 404, desc => $desc, msg => $msg );
	}

	my @running_farms = @{ &getFGRunningFarms( $fg_name ) };
	if ( @running_farms )
	{
		my $farm_str = join ( ', ', @running_farms );
		my $msg =
		  "It is not possible delete farm guardian '$fg_name' because it is running in: '$farm_str'";
		&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
	}

	&delFGObject( $fg_name );

	if ( not &getFGExists( $fg_name ) )
	{
		my $msg = "$fg_name has been deleted successfully.";
		my $body = {
					 description => $desc,
					 success     => "true",
					 message     => $msg,
		};
		&httpResponse( { code => 200, body => $body } );
	}
	else
	{
		my $msg = "Deleting the farm guardian '$fg_name'.";
		&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
	}
	return;
}

#  POST /farms/<farm>(/services/<service>)?/fg
sub add_farmguardian_farm
{
	&zenlog( __FILE__ . q{:} . __LINE__ . q{:} . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $json_obj = shift;
	my $farm     = shift;
	my $srv      = shift;

	my $srv_message =
	  ( $srv ) ? "service '$srv' in the farm '$farm'" : "farm '$farm'";

	my $desc = "Add the farm guardian '$json_obj->{ name }' to the '$srv_message'";

	require Zevenet::Farm::Service;

	# Check if it exists
	if ( not &getFarmExists( $farm ) )
	{
		my $msg = "The farm '$farm' does not exist";
		&httpErrorResponse( code => 404, desc => $desc, msg => $msg );
	}

	my $params = &getZAPIModel( "farmguardian_to_farm-add.json" );

	# Check allowed parameters
	my $error_msg = &checkZAPIParams( $json_obj, $params, $desc );
	if ( $error_msg )
	{
		&httpErrorResponse( code => 400, desc => $desc, msg => $error_msg );
	}

	# Check if it exists
	if ( not &getFGExists( $json_obj->{ name } ) )
	{
		my $msg = "The farmguardian '$json_obj->{ name }' does not exist";
		&httpErrorResponse( code => 404, desc => $desc, msg => $msg );
	}

	# Check if it exists
	if ( $srv and not grep { /^$srv$/ } &getFarmServices( $farm ) )
	{
		my $msg = "The service '$srv' does not exist";
		&httpErrorResponse( code => 404, desc => $desc, msg => $msg );
	}

	# check if another fg is applied to the farm
	my $fg_old = &getFGFarm( $farm, $srv );
	if ( $fg_old )
	{
		my $msg = "The '$srv_message' has already linked a farm guardian";
		&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
	}

	# link the check with the farm_service
	my $farm_tag = $farm;
	$farm_tag = "${farm}_$srv" if $srv;

	# check if the farm guardian is already applied to the farm
	my $fg_obj = &getFGObject( $json_obj->{ name } );
	if ( grep { /^$farm_tag$/ } @{ $fg_obj->{ farms } } )
	{
		my $msg = "'$json_obj->{ name }' is already applied in the '$srv_message'";
		&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
	}

	# check farm type
	my $type = &getFarmType( $farm );
	if ( $type =~ /http|gslb/ and not $srv )
	{
		my $msg = "The farm guardian expects a service";
		&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
	}

	my $output = &linkFGFarm( $json_obj->{ name }, $farm, $srv );

	# check result and return success or failure
	if ( not $output )
	{
		my $msg =
		  "Success, The farm guardian '$json_obj->{ name }' was added to the '$srv_message'";
		my $body = {
					 description => $desc,
					 message     => $msg,
					 status      => &getFarmVipStatus( $farm ),
		};
		&httpResponse( { code => 200, body => $body } );
	}
	else
	{
		my $msg =
		  "There was an error trying to add '$json_obj->{ name }' to the '$srv_message'";
		&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
	}
	return;
}

#  DELETE /farms/<farm>(/services/<service>)?/fg/<fg_name>
sub rem_farmguardian_farm
{
	&zenlog( __FILE__ . q{:} . __LINE__ . q{:} . ( caller ( 0 ) )[3] . "( @_ )",
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

	my $srv_message =
	  ( $srv ) ? "service '$srv' in the farm '$farm'" : "farm '$farm'";
	my $desc = "Remove the farm guardian '$fgname' from the '$srv_message'";

	require Zevenet::Farm::Service;

	# Check if it exists
	if ( not &getFarmExists( $farm ) )
	{
		my $msg = "The farm '$farm' does not exist";
		&httpErrorResponse( code => 404, desc => $desc, msg => $msg );
	}

	# Check if it exists
	if ( not &getFGExists( $fgname ) )
	{
		my $msg = "The farmguardian '$fgname' does not exist";
		&httpErrorResponse( code => 404, desc => $desc, msg => $msg );
	}

	# Check if it exists
	if ( $srv and not grep { /^$srv$/ } &getFarmServices( $farm ) )
	{
		my $msg = "The service '$srv' does not exist";
		&httpErrorResponse( code => 404, desc => $desc, msg => $msg );
	}

	# link the check with the farm_service
	my $farm_tag = $farm;
	$farm_tag = "${farm}_$srv" if $srv;

	# check if the farm guardian is already applied to the farm
	my $fg_obj = &getFGObject( $fgname );
	if ( not grep { /^$farm_tag$/ } @{ $fg_obj->{ farms } } )
	{
		my $msg = "The farm guardian '$fgname' is not applied to the '$srv_message'";
		&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
	}

	&unlinkFGFarm( $fgname, $farm, $srv );

	# check output
	$fg_obj = &getFGObject( $fgname );
	if ( grep { /^$farm_tag$/ } @{ $fg_obj->{ farms } } or &getFGPidFarm( $farm ) )
	{
		my $msg = "Error removing '$fgname' from the '$srv_message'";
		&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
	}
	else
	{
		require Zevenet::Farm::Base;

		my $msg = "Success, '$fgname' was removed from the '$srv_message'";
		my $body = {
					 description => $desc,
					 message     => $msg,
					 status      => &getFarmVipStatus( $farm ),
		};
		&httpResponse( { code => 200, body => $body } );
	}
	return;
}

1;

