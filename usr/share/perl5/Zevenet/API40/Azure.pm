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

# PUT /azure/ssh
sub modify_ssh    # ()
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $json_obj = shift;
	my $type = $json_obj->{ type } // 'add';

	my $desc = "Modify the SSH configuration for Azure";

	my $params = &getZAPIModel( "azure_ssh-modify.json" );

	# Check allowed parameters
	my $error_msg = &checkZAPIParams( $json_obj, $params, $desc );
	return &httpErrorResponse( code => 400, desc => $desc, msg => $error_msg )
	  if ( $error_msg );

	include 'Zevenet::Azure';
	my $error = &setSshForCluster( $json_obj->{ remote_ip }, $type );
	if ( $error )
	{
		my $msg = "There was a error modifying ssh.";
		return &httpErrorResponse( code => 400, desc => $desc, msg => $msg );
	}

	my $msg = "Setted ssh configuration";
	return
	  &httpResponse(
			   {
				 code => 200,
				 body => { description => $desc, params => $json_obj, message => $msg }
			   }
	  );
}

#GET /azure/credentials
sub get_credentials
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );

	my $desc = "Retrieve the Azure credentials";

	include 'Zevenet::Azure';
	my $user_data = &getCredentials();

	# my %credentials = (
	# 					id     => '',
	# 					name   => '',
	# );
	# if ( $dataCredentials )
	# {
	# 	$credentials{ id } = $dataCredentials->{ id };
	# 	$credentials{ name } = $dataCredentials->{ user }->{ name };
	# }

	return &httpResponse(
			  { code => 200, body => { description => $desc, params => $user_data } } );
}

#POST /azure/credentials
sub modify_credentials
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $json_obj = shift;

	my $desc   = "Modify the Azure credentials";
	my $params = &getZAPIModel( "azure_credentials-modify.json" );

	# Check allowed parameters
	my $error_msg = &checkZAPIParams( $json_obj, $params, $desc );
	return &httpErrorResponse( code => 400, desc => $desc, msg => $error_msg )
	  if ( $error_msg );

	include 'Zevenet::Azure';
	my $error = &setCredentials( $json_obj );

	if ( $error )
	{
		$error_msg = 'There was an error to configure the Azure credentials';
		return &httpErrorResponse( code => 400, desc => $desc, msg => $error_msg );
	}

	my $user_data = &getCredentials();

	my $msg = "Setted Azure credentials";
	return
	  &httpResponse(
			  {
				code => 200,
				body => { description => $desc, params => $user_data, message => $msg }
			  }
	  );
}

1;

