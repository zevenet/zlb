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

#	GET	/system/users
sub get_all_users
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	require Zevenet::Zapi;

	my $desc       = "Get users";
	my $zapiStatus = &getZAPI( "status" );
	my @users = (
				  { "user" => "root", "status" => "true" },
				  { "user" => "zapi", "status" => "$zapiStatus" }
	);

	&httpResponse(
				 { code => 200, body => { description => $desc, params => \@users } } );
}

#	GET	/system/users/zapi
sub get_user
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $user = shift;

	require Zevenet::Zapi;

	my $desc = "Zapi user configuration.";

	if ( $user ne 'zapi' )
	{
		my $msg = "Actually only is available information about 'zapi' user";
		&httpErrorResponse( code => 404, desc => $desc, msg => $msg );
	}

	my $zapi = {
				 'key'    => &getZAPI( "zapikey" ),
				 'status' => &getZAPI( "status" ),
	};

	&httpResponse(
				   { code => 200, body => { description => $desc, params => $zapi } } );
}

# POST /system/users/zapi
sub set_user_zapi
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $json_obj = shift;

	require Zevenet::Zapi;
	require Zevenet::Login;

	my $desc = "Setting Zapi user configuration";

	my @requiredParams = ( "key", "status", "newpassword" );
	my $param_msg = &getValidOptParams( $json_obj, \@requiredParams );

	if ( $param_msg )
	{
		&httpErrorResponse( code => 400, desc => $desc, msg => $param_msg );
	}

	if ( !&getValidFormat( "zapi_key", $json_obj->{ 'key' } ) )
	{
		my $msg = "Error, character incorrect in key zapi.";
		&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
	}
	elsif ( !&getValidFormat( "zapi_password", $json_obj->{ 'newpassword' } ) )
	{
		my $msg = "Error, character incorrect in password zapi.";
		&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
	}
	elsif ( !&getValidFormat( "zapi_status", $json_obj->{ 'status' } ) )
	{
		my $msg = "Error, character incorrect in status zapi.";
		&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
	}

	if (    $json_obj->{ 'status' } eq 'enable'
		 && &getZAPI( "status" ) eq 'false' )
	{
		&setZAPI( "enable" );
	}
	elsif (    $json_obj->{ 'status' } eq 'disable'
			&& &getZAPI( "status" ) eq 'true' )
	{
		&setZAPI( "disable" );
	}

	if ( exists $json_obj->{ 'key' } )
	{
		&setZAPI( 'key', $json_obj->{ 'key' } );
	}

	if ( exists $json_obj->{ 'newpassword' } )
	{
		&changePassword( 'zapi',
						 $json_obj->{ 'newpassword' },
						 $json_obj->{ 'newpassword' } );
	}

	my $msg = "Settings was changed successfully.";
	my $body = { description => $desc, params => $json_obj, message => $msg };

	&httpResponse( { code => 200, body => $body } );
}

# POST /system/users/root
sub set_user
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $json_obj = shift;
	my $user     = shift;

	require Zevenet::Login;

	my $desc = "User settings.";

	my @requiredParams = ( "password", "newpassword" );
	my $param_msg =
	  &getValidReqParams( $json_obj, \@requiredParams, \@requiredParams );

	if ( $param_msg )
	{
		&httpErrorResponse( code => 400, desc => $desc, msg => $param_msg );
	}

	if ( $user ne 'root' )
	{
		my $msg = "Actually only is available to change password in root user.";
		&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
	}

	if ( !&getValidFormat( 'password', $json_obj->{ 'newpassword' } ) )
	{
		my $msg = "Character incorrect in password.";
		&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
	}
	elsif ( !&checkValidUser( $user, $json_obj->{ 'password' } ) )
	{
		my $msg = "Invalid current password.";
		&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
	}

	my $error = &changePassword( $user,
								 $json_obj->{ 'newpassword' },
								 $json_obj->{ 'newpassword' } );
	if ( $error )
	{
		my $msg = "Changing $user password.";
		&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
	}

	my $msg = "Settings was changed successfully.";
	my $body = { description => $desc, params => $json_obj, message => $msg };

	&httpResponse( { code => 200, body => $body } );
}

1;
