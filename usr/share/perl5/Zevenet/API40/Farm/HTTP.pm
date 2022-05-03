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

use Zevenet::API40::HTTP;

require Zevenet::Farm::Base;
require Zevenet::Farm::HTTP::Config;

# POST	/farms/<>/addheader
sub add_addheader    # ( $json_obj, $farmname )
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $json_obj = shift;
	my $farmname = shift;

	my $desc = "Add addheader directive.";

	# Check that the farm exists
	if ( !&getFarmExists( $farmname ) )
	{
		my $msg = "The farm '$farmname' does not exist.";
		return &httpErrorResponse( code => 404, desc => $desc, msg => $msg );
	}

	if ( &getFarmType( $farmname ) !~ /http/ )
	{
		my $msg = "This feature is only for HTTP profiles.";
		return &httpErrorResponse( code => 400, desc => $desc, msg => $msg );
	}

	my $params = &getZAPIModel( "farm_http_header_request_add-create.json" );

	# Check allowed parameters
	my $error_msg = &checkZAPIParams( $json_obj, $params, $desc );
	return &httpErrorResponse( code => 400, desc => $desc, msg => $error_msg )
	  if ( $error_msg );

	# check if the header is already added
	foreach my $header ( @{ &getHTTPAddReqHeader( $farmname ) } )
	{
		if ( $header->{ header } eq $json_obj->{ header } )
		{
			my $msg = "The header is already added.";
			return &httpErrorResponse( code => 400, desc => $desc, msg => $msg );
		}
	}

	unless ( &addHTTPAddheader( $farmname, $json_obj->{ header } ) )
	{
		# success
		my $message = "Added a new item to the addheader list";
		my $body = {
					 description => $desc,
					 success     => "true",
					 message     => $message,
		};

		if ( &getFarmStatus( $farmname ) ne 'down' )
		{
			require Zevenet::Farm::Action;
			if ( &getGlobalConfiguration( 'proxy_ng' ) ne 'true' )
			{
				&setFarmRestart( $farmname );
				$body->{ status } = 'needed restart';
			}
			else
			{
				require Zevenet::Farm::HTTP::Config;
				my $config_error = &getHTTPFarmConfigErrorMessage( $farmname );
				if ( $config_error ne "" )
				{
					$body->{ warning } = "Farm '$farmname' config error: $config_error";
				}
				else
				{
					&runFarmReload( $farmname );
					&eload(
							module => 'Zevenet::Cluster',
							func   => 'runZClusterRemoteManager',
							args   => ['farm', 'reload', $farmname],
					) if ( $eload );
				}
			}
		}

		return &httpResponse( { code => 200, body => $body } );
	}

	# error
	my $msg = "Error adding a new addheader";
	return &httpErrorResponse( code => 400, desc => $desc, msg => $msg );
}

# PUT	/farms/<>/addheader/<id>
sub modify_addheader    # ( $json_obj, $farmname, $index )
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $json_obj = shift;
	my $farmname = shift;
	my $index    = shift;

	my $desc = "Modify an addheader directive.";

	# Check that the farm exists
	if ( !&getFarmExists( $farmname ) )
	{
		my $msg = "The farm '$farmname' does not exist.";
		return &httpErrorResponse( code => 404, desc => $desc, msg => $msg );
	}

	if ( &getFarmType( $farmname ) !~ /http/ )
	{
		my $msg = "This feature is only for HTTP profiles.";
		return &httpErrorResponse( code => 400, desc => $desc, msg => $msg );
	}

	my $params = &getZAPIModel( "farm_http_header_request_add-modify.json" );

	# Check allowed parameters
	my $error_msg = &checkZAPIParams( $json_obj, $params, $desc );
	return &httpErrorResponse( code => 400, desc => $desc, msg => $error_msg )
	  if ( $error_msg );

	my @directives = @{ &getHTTPAddReqHeader( $farmname ) };

	# check if the header exists
	if ( ( scalar @directives ) < $index + 1 )
	{
		my $msg = "The header with index $index not found.";
		return &httpErrorResponse( code => 400, desc => $desc, msg => $msg );
	}

	# check if the header is already added
	foreach my $header ( @directives )
	{
		if ( $header->{ header } eq $json_obj->{ header } )
		{
			my $msg = "The header is already added.";
			return &httpErrorResponse( code => 400, desc => $desc, msg => $msg );
		}
	}

	unless ( &modifyHTTPAddheader( $farmname, $json_obj->{ header }, $index ) )
	{
		# success
		my $message = "Modified an item from the addheader list";
		my $body = {
					 description => $desc,
					 success     => "true",
					 message     => $message,
		};

		if ( &getFarmStatus( $farmname ) ne 'down' )
		{
			require Zevenet::Farm::Action;
			if ( &getGlobalConfiguration( 'proxy_ng' ) ne 'true' )
			{
				&setFarmRestart( $farmname );
				$body->{ status } = 'needed restart';
			}
			else
			{
				require Zevenet::Farm::HTTP::Config;
				my $config_error = &getHTTPFarmConfigErrorMessage( $farmname );
				if ( $config_error ne "" )
				{
					$body->{ warning } = "Farm '$farmname' config error: $config_error";
				}
				else
				{
					&runFarmReload( $farmname );
					&eload(
							module => 'Zevenet::Cluster',
							func   => 'runZClusterRemoteManager',
							args   => ['farm', 'reload', $farmname],
					) if ( $eload );
				}
			}
		}

		return &httpResponse( { code => 200, body => $body } );
	}

	# error
	my $msg = "Error modifying an addheader";
	return &httpErrorResponse( code => 400, desc => $desc, msg => $msg );
}

#  DELETE	/farms/<>/addheader/<>
sub del_addheader
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $farmname = shift;
	my $index    = shift;

	my $desc = "Delete addheader directive.";

	# Check that the farm exists
	if ( !&getFarmExists( $farmname ) )
	{
		my $msg = "The farm '$farmname' does not exist.";
		return &httpErrorResponse( code => 404, desc => $desc, msg => $msg );
	}

	if ( &getFarmType( $farmname ) !~ /http/ )
	{
		my $msg = "This feature is only for HTTP profiles.";
		return &httpErrorResponse( code => 400, desc => $desc, msg => $msg );
	}

	# check if the header is already added
	if ( ( scalar @{ &getHTTPAddReqHeader( $farmname ) } ) < $index + 1 )
	{
		my $msg = "The index has not been found.";
		return &httpErrorResponse( code => 400, desc => $desc, msg => $msg );
	}

	unless ( &delHTTPAddheader( $farmname, $index ) )
	{
		# success
		my $message = "The addheader $index was deleted successfully";
		my $body = {
					 description => $desc,
					 success     => "true",
					 message     => $message,
		};

		if ( &getFarmStatus( $farmname ) ne 'down' )
		{
			require Zevenet::Farm::Action;
			if ( &getGlobalConfiguration( 'proxy_ng' ) ne 'true' )
			{
				&setFarmRestart( $farmname );
				$body->{ status } = 'needed restart';
			}
			else
			{
				require Zevenet::Farm::HTTP::Config;
				my $config_error = &getHTTPFarmConfigErrorMessage( $farmname );
				if ( $config_error ne "" )
				{
					$body->{ warning } = "Farm '$farmname' config error: $config_error";
				}
				else
				{
					&runFarmReload( $farmname );
					&eload(
							module => 'Zevenet::Cluster',
							func   => 'runZClusterRemoteManager',
							args   => ['farm', 'reload', $farmname],
					) if ( $eload );
				}
			}
		}

		return &httpResponse( { code => 200, body => $body } );
	}

	# error
	my $msg = "Error deleting the addheader $index";
	return &httpErrorResponse( code => 400, desc => $desc, msg => $msg );
}

# POST	/farms/<>/headremove
sub add_headremove    # ( $json_obj, $farmname )
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $json_obj = shift;
	my $farmname = shift;

	my $desc = "Add headremove directive.";

	# Check that the farm exists
	if ( !&getFarmExists( $farmname ) )
	{
		my $msg = "The farm '$farmname' does not exist.";
		return &httpErrorResponse( code => 404, desc => $desc, msg => $msg );
	}

	if ( &getFarmType( $farmname ) !~ /http/ )
	{
		my $msg = "This feature is only for HTTP profiles.";
		return &httpErrorResponse( code => 400, desc => $desc, msg => $msg );
	}

	my $params = &getZAPIModel( "farm_http_header_request_remove-create.json" );

	# Check allowed parameters
	my $error_msg = &checkZAPIParams( $json_obj, $params, $desc );
	return &httpErrorResponse( code => 400, desc => $desc, msg => $error_msg )
	  if ( $error_msg );

	# check if the header is already added
	foreach my $header ( @{ &getHTTPRemReqHeader( $farmname ) } )
	{
		if ( $header->{ pattern } eq $json_obj->{ pattern } )
		{
			my $msg = "The pattern is already added.";
			return &httpErrorResponse( code => 400, desc => $desc, msg => $msg );
		}
	}

	unless ( &addHTTPHeadremove( $farmname, $json_obj->{ pattern } ) )
	{
		# success
		my $message = "Added a new item to the headremove list";
		my $body = {
					 description => $desc,
					 success     => "true",
					 message     => $message,
		};

		if ( &getFarmStatus( $farmname ) ne 'down' )
		{
			require Zevenet::Farm::Action;
			if ( &getGlobalConfiguration( 'proxy_ng' ) ne 'true' )
			{
				&setFarmRestart( $farmname );
				$body->{ status } = 'needed restart';
			}
			else
			{
				require Zevenet::Farm::HTTP::Config;
				my $config_error = &getHTTPFarmConfigErrorMessage( $farmname );
				if ( $config_error ne "" )
				{
					$body->{ warning } = "Farm '$farmname' config error: $config_error";
				}
				else
				{
					&runFarmReload( $farmname );
					&eload(
							module => 'Zevenet::Cluster',
							func   => 'runZClusterRemoteManager',
							args   => ['farm', 'reload', $farmname],
					) if ( $eload );
				}
			}
		}

		return &httpResponse( { code => 200, body => $body } );
	}

	# error
	my $msg = "Error adding a new headremove";
	return &httpErrorResponse( code => 400, desc => $desc, msg => $msg );
}

# PUT	/farms/<>/headremove/<id>
sub modify_headremove    # ( $json_obj, $farmname, $index )
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $json_obj = shift;
	my $farmname = shift;
	my $index    = shift;

	my $desc = "Modify an headremove directive.";

	# Check that the farm exists
	if ( !&getFarmExists( $farmname ) )
	{
		my $msg = "The farm '$farmname' does not exist.";
		return &httpErrorResponse( code => 404, desc => $desc, msg => $msg );
	}

	if ( &getFarmType( $farmname ) !~ /http/ )
	{
		my $msg = "This feature is only for HTTP profiles.";
		return &httpErrorResponse( code => 400, desc => $desc, msg => $msg );
	}

	my $params = &getZAPIModel( "farm_http_header_request_remove-modify.json" );

	# Check allowed parameters
	my $error_msg = &checkZAPIParams( $json_obj, $params, $desc );
	return &httpErrorResponse( code => 400, desc => $desc, msg => $error_msg )
	  if ( $error_msg );

	my @directives = @{ &getHTTPRemReqHeader( $farmname ) };

	# check if the header exists
	if ( ( scalar @directives ) < $index + 1 )
	{
		my $msg = "The header with index $index not found.";
		return &httpErrorResponse( code => 400, desc => $desc, msg => $msg );
	}

	# check if the new pattern is already added
	foreach my $header ( @directives )
	{
		if ( $header->{ pattern } eq $json_obj->{ pattern } )
		{
			my $msg = "The pattern is already added.";
			return &httpErrorResponse( code => 400, desc => $desc, msg => $msg );
		}
	}

	unless ( &modifyHTTPHeadremove( $farmname, $json_obj->{ pattern }, $index ) )
	{
		# success
		my $message = "Modified an item from the headremove list";
		my $body = {
					 description => $desc,
					 success     => "true",
					 message     => $message,
		};

		if ( &getFarmStatus( $farmname ) ne 'down' )
		{
			require Zevenet::Farm::Action;
			if ( &getGlobalConfiguration( 'proxy_ng' ) ne 'true' )
			{
				&setFarmRestart( $farmname );
				$body->{ status } = 'needed restart';
			}
			else
			{
				require Zevenet::Farm::HTTP::Config;
				my $config_error = &getHTTPFarmConfigErrorMessage( $farmname );
				if ( $config_error ne "" )
				{
					$body->{ warning } = "Farm '$farmname' config error: $config_error";
				}
				else
				{
					&runFarmReload( $farmname );
					&eload(
							module => 'Zevenet::Cluster',
							func   => 'runZClusterRemoteManager',
							args   => ['farm', 'reload', $farmname],
					) if ( $eload );
				}
			}
		}

		return &httpResponse( { code => 200, body => $body } );
	}

	# error
	my $msg = "Error modifying an headremove";
	return &httpErrorResponse( code => 400, desc => $desc, msg => $msg );
}

#  DELETE	/farms/<>/addheader/<>
sub del_headremove
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $farmname = shift;
	my $index    = shift;

	my $desc = "Delete headremove directive.";

	# Check that the farm exists
	if ( !&getFarmExists( $farmname ) )
	{
		my $msg = "The farm '$farmname' does not exist.";
		return &httpErrorResponse( code => 404, desc => $desc, msg => $msg );
	}

	if ( &getFarmType( $farmname ) !~ /http/ )
	{
		my $msg = "This feature is only for HTTP profiles.";
		return &httpErrorResponse( code => 400, desc => $desc, msg => $msg );
	}

	# check if the headremove is already added
	if ( ( scalar @{ &getHTTPRemReqHeader( $farmname ) } ) < $index + 1 )
	{
		my $msg = "The index has not been found.";
		return &httpErrorResponse( code => 400, desc => $desc, msg => $msg );
	}

	unless ( &delHTTPHeadremove( $farmname, $index ) )
	{
		# success
		my $message = "The headremove $index was deleted successfully";
		my $body = {
					 description => $desc,
					 success     => "true",
					 message     => $message,
		};

		if ( &getFarmStatus( $farmname ) ne 'down' )
		{
			require Zevenet::Farm::Action;
			if ( &getGlobalConfiguration( 'proxy_ng' ) ne 'true' )
			{
				&setFarmRestart( $farmname );
				$body->{ status } = 'needed restart';
			}
			else
			{
				require Zevenet::Farm::HTTP::Config;
				my $config_error = &getHTTPFarmConfigErrorMessage( $farmname );
				if ( $config_error ne "" )
				{
					$body->{ warning } = "Farm '$farmname' config error: $config_error";
				}
				else
				{
					&runFarmReload( $farmname );
					&eload(
							module => 'Zevenet::Cluster',
							func   => 'runZClusterRemoteManager',
							args   => ['farm', 'reload', $farmname],
					) if ( $eload );
				}
			}
		}

		return &httpResponse( { code => 200, body => $body } );
	}

	# error
	my $msg = "Error deleting the headremove $index";
	return &httpErrorResponse( code => 400, desc => $desc, msg => $msg );
}

# POST	/farms/<>/addheader
sub add_addResponseheader    # ( $json_obj, $farmname )
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $json_obj = shift;
	my $farmname = shift;

	my $desc = "Add a header to the backend repsonse.";

	# Check that the farm exists
	if ( !&getFarmExists( $farmname ) )
	{
		my $msg = "The farm '$farmname' does not exist.";
		return &httpErrorResponse( code => 404, desc => $desc, msg => $msg );
	}

	if ( &getFarmType( $farmname ) !~ /http/ )
	{
		my $msg = "This feature is only for HTTP profiles.";
		return &httpErrorResponse( code => 400, desc => $desc, msg => $msg );
	}

	my $params = &getZAPIModel( "farm_http_header_response_add-create.json" );

	# Check allowed parameters
	my $error_msg = &checkZAPIParams( $json_obj, $params, $desc );
	return &httpErrorResponse( code => 400, desc => $desc, msg => $error_msg )
	  if ( $error_msg );

	# check if the header is already added
	foreach my $header ( @{ &getHTTPAddRespHeader( $farmname ) } )
	{
		if ( $header->{ header } eq $json_obj->{ header } )
		{
			my $msg = "The header is already added.";
			return &httpErrorResponse( code => 400, desc => $desc, msg => $msg );
		}
	}

	unless ( &addHTTPAddRespheader( $farmname, $json_obj->{ header } ) )
	{
		# success
		my $message = "Added a new header to the backend response";
		my $body = {
					 description => $desc,
					 success     => "true",
					 message     => $message,
		};

		if ( &getFarmStatus( $farmname ) ne 'down' )
		{
			require Zevenet::Farm::Action;
			if ( &getGlobalConfiguration( 'proxy_ng' ) ne 'true' )
			{
				&setFarmRestart( $farmname );
				$body->{ status } = 'needed restart';
			}
			else
			{
				require Zevenet::Farm::HTTP::Config;
				my $config_error = &getHTTPFarmConfigErrorMessage( $farmname );
				if ( $config_error ne "" )
				{
					$body->{ warning } = "Farm '$farmname' config error: $config_error";
				}
				else
				{
					&runFarmReload( $farmname );
					&eload(
							module => 'Zevenet::Cluster',
							func   => 'runZClusterRemoteManager',
							args   => ['farm', 'reload', $farmname],
					) if ( $eload );
				}
			}
		}

		return &httpResponse( { code => 200, body => $body } );
	}

	# error
	my $msg = "Error adding a new response header";
	return &httpErrorResponse( code => 400, desc => $desc, msg => $msg );
}

# PUT	/farms/<>/addresponseheader/<id>
sub modify_addResponseheader    # ( $json_obj, $farmname, $index )
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $json_obj = shift;
	my $farmname = shift;
	my $index    = shift;

	my $desc = "Modify an addresponseheader directive.";

	# Check that the farm exists
	if ( !&getFarmExists( $farmname ) )
	{
		my $msg = "The farm '$farmname' does not exist.";
		return &httpErrorResponse( code => 404, desc => $desc, msg => $msg );
	}

	if ( &getFarmType( $farmname ) !~ /http/ )
	{
		my $msg = "This feature is only for HTTP profiles.";
		return &httpErrorResponse( code => 400, desc => $desc, msg => $msg );
	}

	my $params = &getZAPIModel( "farm_http_header_response_add-modify.json" );

	# Check allowed parameters
	my $error_msg = &checkZAPIParams( $json_obj, $params, $desc );
	return &httpErrorResponse( code => 400, desc => $desc, msg => $error_msg )
	  if ( $error_msg );

	my @directives = @{ &getHTTPAddRespHeader( $farmname ) };

	# check if the header exists
	if ( ( scalar @directives ) < $index + 1 )
	{
		my $msg = "The header with index $index not found.";
		return &httpErrorResponse( code => 400, desc => $desc, msg => $msg );
	}

	# check if the header is already added
	foreach my $header ( @directives )
	{
		if ( $header->{ header } eq $json_obj->{ header } )
		{
			my $msg = "The header is already added.";
			return &httpErrorResponse( code => 400, desc => $desc, msg => $msg );
		}
	}

	unless ( &modifyHTTPAddRespheader( $farmname, $json_obj->{ header }, $index ) )
	{
		# success
		my $message = "Modified an item from the addresponseheader list";
		my $body = {
					 description => $desc,
					 success     => "true",
					 message     => $message,
		};

		if ( &getFarmStatus( $farmname ) ne 'down' )
		{
			require Zevenet::Farm::Action;
			if ( &getGlobalConfiguration( 'proxy_ng' ) ne 'true' )
			{
				&setFarmRestart( $farmname );
				$body->{ status } = 'needed restart';
			}
			else
			{
				require Zevenet::Farm::HTTP::Config;
				my $config_error = &getHTTPFarmConfigErrorMessage( $farmname );
				if ( $config_error ne "" )
				{
					$body->{ warning } = "Farm '$farmname' config error: $config_error";
				}
				else
				{
					&runFarmReload( $farmname );
					&eload(
							module => 'Zevenet::Cluster',
							func   => 'runZClusterRemoteManager',
							args   => ['farm', 'reload', $farmname],
					) if ( $eload );
				}
			}
		}

		return &httpResponse( { code => 200, body => $body } );
	}

	# error
	my $msg = "Error modifying an addresponseheader";
	return &httpErrorResponse( code => 400, desc => $desc, msg => $msg );
}

#  DELETE	/farms/<>/addresponseheader/<>
sub del_addResponseheader
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $farmname = shift;
	my $index    = shift;

	my $desc = "Delete a header previously added to the backend response.";

	# Check that the farm exists
	if ( !&getFarmExists( $farmname ) )
	{
		my $msg = "The farm '$farmname' does not exist.";
		return &httpErrorResponse( code => 404, desc => $desc, msg => $msg );
	}

	if ( &getFarmType( $farmname ) !~ /http/ )
	{
		my $msg = "This feature is only for HTTP profiles.";
		return &httpErrorResponse( code => 400, desc => $desc, msg => $msg );
	}

	# check if the header is already added
	if ( ( scalar @{ &getHTTPAddRespHeader( $farmname ) } ) < $index + 1 )
	{
		my $msg = "The index has not been found.";
		return &httpErrorResponse( code => 400, desc => $desc, msg => $msg );
	}

	unless ( &delHTTPAddRespheader( $farmname, $index ) )
	{
		# success
		my $message = "The header $index was deleted successfully";
		my $body = {
					 description => $desc,
					 success     => "true",
					 message     => $message,
		};

		if ( &getFarmStatus( $farmname ) ne 'down' )
		{
			require Zevenet::Farm::Action;
			if ( &getGlobalConfiguration( 'proxy_ng' ) ne 'true' )
			{
				&setFarmRestart( $farmname );
				$body->{ status } = 'needed restart';
			}
			else
			{
				require Zevenet::Farm::HTTP::Config;
				my $config_error = &getHTTPFarmConfigErrorMessage( $farmname );
				if ( $config_error ne "" )
				{
					$body->{ warning } = "Farm '$farmname' config error: $config_error";
				}
				else
				{
					&runFarmReload( $farmname );
					&eload(
							module => 'Zevenet::Cluster',
							func   => 'runZClusterRemoteManager',
							args   => ['farm', 'reload', $farmname],
					) if ( $eload );
				}
			}
		}

		return &httpResponse( { code => 200, body => $body } );
	}

	# error
	my $msg = "Error deleting the response header $index";
	return &httpErrorResponse( code => 400, desc => $desc, msg => $msg );
}

# POST	/farms/<>/replacerequestheader
sub add_replaceRequestHeader    # ( $json_obj, $farmname )
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );

	my $json_obj = shift;
	my $farmname = shift;

	my $type = "Request";
	return &add_replaceheader( $json_obj, $farmname, $type );
}

# POST	/farms/<>/replaceresponseheader
sub add_replaceResponseHeader    # ( $json_obj, $farmname )
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );

	my $json_obj = shift;
	my $farmname = shift;

	my $type = "Response";
	return &add_replaceheader( $json_obj, $farmname, $type );
}

sub add_replaceheader            # ( $json_obj, $farmname, $type )
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $json_obj = shift;
	my $farmname = shift;
	my $type     = shift;

	my $desc = "Add a Replace Header.";

	if ( &getGlobalConfiguration( 'proxy_ng' ) ne 'true' )
	{
		my $msg = "ReplaceHeader is only available for zproxy.";
		return &httpErrorResponse( code => 404, desc => $desc, msg => $msg );
	}

	# Check that the farm exists
	if ( !&getFarmExists( $farmname ) )
	{
		my $msg = "The farm '$farmname' does not exist.";
		return &httpErrorResponse( code => 404, desc => $desc, msg => $msg );
	}

	my $params =
	  &getZAPIModel( "farm_http_header_" . lc ( $type ) . "_replace-create.json" );

	# Check allowed parameters
	my $error_msg = &checkZAPIParams( $json_obj, $params, $desc );
	return &httpErrorResponse( code => 400, desc => $desc, msg => $error_msg )
	  if ( $error_msg );

	# check if the header is already added
	foreach my $header ( @{ &getHTTPReplaceHeaders( $farmname, $type ) } )
	{
		if (    $header->{ header } eq $json_obj->{ header }
			 && $header->{ match } eq $json_obj->{ match } )
		{
			my $msg = "The header is already added.";
			return &httpErrorResponse( code => 400, desc => $desc, msg => $msg );
		}
	}

	$json_obj->{ type } = $type;

	unless (
			 &addHTTPReplaceHeaders(
									 $farmname,
									 $json_obj->{ type },
									 $json_obj->{ header },
									 $json_obj->{ match },
									 $json_obj->{ replace }
			 )
	  )
	{
		# success
		my $message = "Added a new replace header";
		my $body = {
					 description => $desc,
					 success     => "true",
					 message     => $message,
		};

		if ( &getFarmStatus( $farmname ) ne 'down' )
		{
			require Zevenet::Farm::Action;
			if ( &getGlobalConfiguration( 'proxy_ng' ) ne 'true' )
			{
				&setFarmRestart( $farmname );
				$body->{ status } = 'needed restart';
			}
			else
			{
				require Zevenet::Farm::HTTP::Config;
				my $config_error = &getHTTPFarmConfigErrorMessage( $farmname );
				if ( $config_error ne "" )
				{
					$body->{ warning } = "Farm '$farmname' config error: $config_error";
				}
				else
				{
					&runFarmReload( $farmname );
					&eload(
							module => 'Zevenet::Cluster',
							func   => 'runZClusterRemoteManager',
							args   => ['farm', 'reload', $farmname],
					) if ( $eload );
				}
			}
		}

		return &httpResponse( { code => 200, body => $body } );
	}

	# error
	my $msg = "Error adding a new replace header";
	return &httpErrorResponse( code => 400, desc => $desc, msg => $msg );
}

#  PUT	/farms/<>/replacerequestheader/<>
sub modify_replaceRequestHeader
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );

	my $json_obj = shift;
	my $farmname = shift;
	my $index    = shift;

	my $type = "Request";
	return &modify_replaceHeader( $json_obj, $farmname, $type, $index );
}

#  PUT	/farms/<>/replaceresponseheader/<>
sub modify_replaceResponseHeader
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );

	my $json_obj = shift;
	my $farmname = shift;
	my $index    = shift;

	my $type = "Response";
	return &modify_replaceHeader( $json_obj, $farmname, $type, $index );
}

# PUT	/farms/<>/replaceHeader/<id>
sub modify_replaceHeader    # ( $json_obj, $farmname, $type, $index )
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $json_obj = shift;
	my $farmname = shift;
	my $type     = shift;
	my $index    = shift;

	my $desc = "Modify a replaceHeader directive.";

	# Check that the farm exists
	if ( !&getFarmExists( $farmname ) )
	{
		my $msg = "The farm '$farmname' does not exist.";
		return &httpErrorResponse( code => 404, desc => $desc, msg => $msg );
	}

	if ( &getFarmType( $farmname ) !~ /http/ )
	{
		my $msg = "This feature is only for HTTP profiles.";
		return &httpErrorResponse( code => 400, desc => $desc, msg => $msg );
	}

	my $params =
	  &getZAPIModel( "farm_http_header_" . lc ( $type ) . "_replace-modify.json" );

	# Check allowed parameters
	my $error_msg = &checkZAPIParams( $json_obj, $params, $desc );
	return &httpErrorResponse( code => 400, desc => $desc, msg => $error_msg )
	  if ( $error_msg );

	my @headers = @{ &getHTTPReplaceHeaders( $farmname, $type ) };

	# check if the header exists
	if ( ( scalar @headers ) < $index + 1 )
	{
		my $msg = "The header with index $index not found.";
		return &httpErrorResponse( code => 400, desc => $desc, msg => $msg );
	}

	# check if the header is already added
	if (    @headers[$index]->{ header } ne $json_obj->{ header }
		 && @headers[$index]->{ match } ne $json_obj->{ match } )
	{
		foreach my $header ( @{ &getHTTPReplaceHeaders( $farmname, $type ) } )
		{
			if (    $header->{ header } eq $json_obj->{ header }
				 && $header->{ match } eq $json_obj->{ match } )
			{
				my $msg = "The header is already added.";
				return &httpErrorResponse( code => 400, desc => $desc, msg => $msg );
			}
		}
	}

	# Get directive data
	my $header = $headers[$index];

	unless (
			 &modifyHTTPReplaceHeaders(
										$farmname,
										$type,
										$json_obj->{ header }  // $header->{ header },
										$json_obj->{ match }   // $header->{ match },
										$json_obj->{ replace } // $header->{ replace },
										$index
			 )
	  )
	{
		# success
		my $message = "Modified an item from the replaceHeader list";
		my $body = {
					 description => $desc,
					 success     => "true",
					 message     => $message,
		};

		if ( &getFarmStatus( $farmname ) ne 'down' )
		{
			require Zevenet::Farm::Action;
			if ( &getGlobalConfiguration( 'proxy_ng' ) ne 'true' )
			{
				&setFarmRestart( $farmname );
				$body->{ status } = 'needed restart';
			}
			else
			{
				require Zevenet::Farm::HTTP::Config;
				my $config_error = &getHTTPFarmConfigErrorMessage( $farmname );
				if ( $config_error ne "" )
				{
					$body->{ warning } = "Farm '$farmname' config error: $config_error";
				}
				else
				{
					&runFarmReload( $farmname );
					&eload(
							module => 'Zevenet::Cluster',
							func   => 'runZClusterRemoteManager',
							args   => ['farm', 'reload', $farmname],
					) if ( $eload );
				}
			}
		}

		return &httpResponse( { code => 200, body => $body } );
	}

	# error
	my $msg = "Error modifying a replaceHeader";
	return &httpErrorResponse( code => 400, desc => $desc, msg => $msg );
}

#  DELETE	/farms/<>/replacerequestheader/<>
sub del_replaceRequestHeader
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );

	my $farmname = shift;
	my $index    = shift;

	my $type = "Request";
	return &del_replaceheader( $farmname, $index, $type );
}

#  DELETE	/farms/<>/replaceresponseheader/<>
sub del_replaceResponseHeader
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );

	my $farmname = shift;
	my $index    = shift;

	my $type = "Response";
	return &del_replaceheader( $farmname, $index, $type );
}

sub del_replaceheader
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $farmname = shift;
	my $index    = shift;
	my $type     = shift;

	my $desc = "Delete a replace header directive.";

	# Check that the farm exists
	if ( !&getFarmExists( $farmname ) )
	{
		my $msg = "The farm '$farmname' does not exist.";
		return &httpErrorResponse( code => 404, desc => $desc, msg => $msg );
	}

	# check if the header is already added
	if ( ( scalar @{ &getHTTPReplaceHeaders( $farmname, $type ) } ) < $index + 1 )
	{
		my $msg = "The index has not been found.";
		return &httpErrorResponse( code => 400, desc => $desc, msg => $msg );
	}

	unless ( &delHTTPReplaceHeaders( $farmname, $index, $type ) )
	{
		# success
		my $message = "The replace header $index was deleted successfully";
		my $body = {
					 description => $desc,
					 success     => "true",
					 message     => $message,
		};

		if ( &getFarmStatus( $farmname ) ne 'down' )
		{
			require Zevenet::Farm::Action;
			if ( &getGlobalConfiguration( 'proxy_ng' ) ne 'true' )
			{
				&setFarmRestart( $farmname );
				$body->{ status } = 'needed restart';
			}
			else
			{
				require Zevenet::Farm::HTTP::Config;
				my $config_error = &getHTTPFarmConfigErrorMessage( $farmname );
				if ( $config_error ne "" )
				{
					$body->{ warning } = "Farm '$farmname' config error: $config_error";
				}
				else
				{
					&runFarmReload( $farmname );
					&eload(
							module => 'Zevenet::Cluster',
							func   => 'runZClusterRemoteManager',
							args   => ['farm', 'reload', $farmname],
					) if ( $eload );
				}
			}
		}

		return &httpResponse( { code => 200, body => $body } );
	}

	# error
	my $msg = "Error deleting the response header $index";
	return &httpErrorResponse( code => 400, desc => $desc, msg => $msg );
}

#  POST	/farms/<>/replacerequestheader/<>/actions
sub move_replacerequestheader
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );

	my $json_obj = shift;
	my $farmname = shift;
	my $index    = shift;

	my $type  = "Request";
	my $regex = '\s*ReplaceHeader\s+Request\s+(.+)';

	return &move_replaceheader( $json_obj, $type, $regex, $farmname, $index );
}

#  POST	/farms/<>/replaceresponseheader/<>/actions
sub move_replaceresponseheader
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );

	my $json_obj = shift;
	my $farmname = shift;
	my $index    = shift;

	my $type  = "Response";
	my $regex = '\s*ReplaceHeader\s+Response\s+(.+)';

	return &move_replaceheader( $json_obj, $type, $regex, $farmname, $index );
}

sub move_replaceheader    # ( $json_obj, $type, $regex, $farmname, $index )
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );

	my $json_obj = shift;
	my $type     = shift;
	my $regex    = shift;
	my $farmname = shift;
	my $index    = shift;

	my $desc = "Move a replace header directive";

	# validate FARM NAME
	if ( !&getFarmExists( $farmname ) )
	{
		my $msg = "The farmname $farmname does not exist.";
		return &httpErrorResponse( code => 404, desc => $desc, msg => $msg );
	}

	my @headers = @{ &getHTTPReplaceHeaders( $farmname, $type ) };

	my $params =
	  &getZAPIModel( "farm_http_header_" . lc ( $type ) . "_replace-move.json" );
	$params->{ position }->{ "interval" } = "0," . scalar @headers - 1;

	# Check allowed parameters
	my $error_msg = &checkZAPIParams( $json_obj, $params, $desc );
	return &httpErrorResponse( code => 400, desc => $desc, msg => $error_msg )
	  if ( $error_msg );

	# check if the header exists
	if ( ( scalar @headers ) < $index + 1 )
	{
		my $msg = "The header with index $index not found.";
		return &httpErrorResponse( code => 400, desc => $desc, msg => $msg );
	}

	unless ( &moveHeader( $farmname, $regex, $json_obj->{ position }, $index ) )
	{
		# success
		my $msg = "Header was moved successfully.";
		my $body = { description => $desc, params => $json_obj, message => $msg };

		if ( &getFarmStatus( $farmname ) ne 'down' )
		{
			require Zevenet::Farm::Action;
			if ( &getGlobalConfiguration( 'proxy_ng' ) ne 'true' )
			{
				&setFarmRestart( $farmname );
				$body->{ status } = 'needed restart';
			}
			else
			{
				require Zevenet::Farm::HTTP::Config;
				my $config_error = &getHTTPFarmConfigErrorMessage( $farmname );
				if ( $config_error ne "" )
				{
					$body->{ warning } = "Farm '$farmname' config error: $config_error";
				}
				else
				{
					&runFarmReload( $farmname );
					&eload(
							module => 'Zevenet::Cluster',
							func   => 'runZClusterRemoteManager',
							args   => ['farm', 'reload', $farmname],
					) if ( $eload );
				}
			}
		}

		return &httpResponse( { code => 200, body => $body } );
	}

	# error
	my $msg = "Error moving a replaceHeader";
	return &httpErrorResponse( code => 400, desc => $desc, msg => $msg );
}

# POST	/farms/<>/removeresponseheader
sub add_removeResponseheader    # ( $json_obj, $farmname )
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $json_obj = shift;
	my $farmname = shift;

	my $desc = "Remove a header from the backend response.";

	# Check that the farm exists
	if ( !&getFarmExists( $farmname ) )
	{
		my $msg = "The farm '$farmname' does not exist.";
		return &httpErrorResponse( code => 404, desc => $desc, msg => $msg );
	}

	if ( &getFarmType( $farmname ) !~ /http/ )
	{
		my $msg = "This feature is only for HTTP profiles.";
		return &httpErrorResponse( code => 400, desc => $desc, msg => $msg );
	}

	my $params = &getZAPIModel( "farm_http_header_response_remove-create.json" );

	# Check allowed parameters
	my $error_msg = &checkZAPIParams( $json_obj, $params, $desc );
	return &httpErrorResponse( code => 400, desc => $desc, msg => $error_msg )
	  if ( $error_msg );

	# check if the header is already added
	foreach my $header ( @{ &getHTTPRemRespHeader( $farmname ) } )
	{
		if ( $header->{ pattern } eq $json_obj->{ pattern } )
		{
			my $msg = "The pattern is already added.";
			return &httpErrorResponse( code => 400, desc => $desc, msg => $msg );
		}
	}

	unless ( &addHTTPRemRespHeader( $farmname, $json_obj->{ pattern } ) )
	{
		# success
		my $message = "Added a patter to remove reponse headers";
		my $body = {
					 description => $desc,
					 success     => "true",
					 message     => $message,
		};

		if ( &getFarmStatus( $farmname ) ne 'down' )
		{
			require 'Zevenet::Farm::Action';
			if ( &getGlobalConfiguration( 'proxy_ng' ) ne 'true' )
			{
				&setFarmRestart( $farmname );
				$body->{ status } = 'needed restart';
			}
			else
			{
				require Zevenet::Farm::HTTP::Config;
				my $config_error = &getHTTPFarmConfigErrorMessage( $farmname );
				if ( $config_error ne "" )
				{
					$body->{ warning } = "Farm '$farmname' config error: $config_error";
				}
				else
				{
					&runFarmReload( $farmname );
					&eload(
							module => 'Zevenet::Cluster',
							func   => 'runZClusterRemoteManager',
							args   => ['farm', 'reload', $farmname],
					) if ( $eload );
				}
			}
		}

		return &httpResponse( { code => 200, body => $body } );
	}

	# error
	my $msg = "Error adding the remove pattern";
	return &httpErrorResponse( code => 400, desc => $desc, msg => $msg );
}

# PUT	/farms/<>/removeresponseheader/<id>
sub modify_removeResponseheader    # ( $json_obj, $farmname )
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $json_obj = shift;
	my $farmname = shift;
	my $index    = shift;

	my $desc = "Modify a remove response header directive.";

	# Check that the farm exists
	if ( !&getFarmExists( $farmname ) )
	{
		my $msg = "The farm '$farmname' does not exist.";
		return &httpErrorResponse( code => 404, desc => $desc, msg => $msg );
	}

	if ( &getFarmType( $farmname ) !~ /http/ )
	{
		my $msg = "This feature is only for HTTP profiles.";
		return &httpErrorResponse( code => 400, desc => $desc, msg => $msg );
	}

	my $params = &getZAPIModel( "farm_http_header_response_remove-modify.json" );

	# Check allowed parameters
	my $error_msg = &checkZAPIParams( $json_obj, $params, $desc );
	return &httpErrorResponse( code => 400, desc => $desc, msg => $error_msg )
	  if ( $error_msg );

	my @directices = @{ &getHTTPRemRespHeader( $farmname ) };

	# check if the header exists
	if ( ( scalar @directices ) < $index + 1 )
	{
		my $msg = "The header with index $index not found.";
		return &httpErrorResponse( code => 400, desc => $desc, msg => $msg );
	}

	# check if the header is already added
	foreach my $header ( @directices )
	{
		if ( $header->{ pattern } eq $json_obj->{ pattern } )
		{
			my $msg = "The pattern is already added.";
			return &httpErrorResponse( code => 400, desc => $desc, msg => $msg );
		}
	}

	unless ( &modifyHTTPRemRespHeader( $farmname, $json_obj->{ header }, $index ) )
	{
		# success
		my $message = "Modified an item from the removeresponseheader list";
		my $body = {
					 description => $desc,
					 success     => "true",
					 message     => $message,
		};

		if ( &getFarmStatus( $farmname ) ne 'down' )
		{
			require 'Zevenet::Farm::Action';
			if ( &getGlobalConfiguration( 'proxy_ng' ) ne 'true' )
			{
				&setFarmRestart( $farmname );
				$body->{ status } = 'needed restart';
			}
			else
			{
				require Zevenet::Farm::HTTP::Config;
				my $config_error = &getHTTPFarmConfigErrorMessage( $farmname );
				if ( $config_error ne "" )
				{
					$body->{ warning } = "Farm '$farmname' config error: $config_error";
				}
				else
				{
					&runFarmReload( $farmname );
					&eload(
							module => 'Zevenet::Cluster',
							func   => 'runZClusterRemoteManager',
							args   => ['farm', 'reload', $farmname],
					) if ( $eload );
				}
			}
		}

		return &httpResponse( { code => 200, body => $body } );
	}

	# error
	my $msg = "Error modifying an removeresponseheader";
	return &httpErrorResponse( code => 400, desc => $desc, msg => $msg );
}

#  DELETE	/farms/<>/addheader/<>
sub del_removeResponseHeader
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $farmname = shift;
	my $index    = shift;

	my $desc = "Delete a pattern to remove response headers.";

	# Check that the farm exists
	if ( !&getFarmExists( $farmname ) )
	{
		my $msg = "The farm '$farmname' does not exist.";
		return &httpErrorResponse( code => 404, desc => $desc, msg => $msg );
	}

	if ( &getFarmType( $farmname ) !~ /http/ )
	{
		my $msg = "This feature is only for HTTP profiles.";
		return &httpErrorResponse( code => 400, desc => $desc, msg => $msg );
	}

	# check if the headremove is already added
	if ( ( scalar @{ &getHTTPRemRespHeader( $farmname ) } ) < $index + 1 )
	{
		my $msg = "The index has not been found.";
		return &httpErrorResponse( code => 400, desc => $desc, msg => $msg );
	}

	unless ( &delHTTPRemRespHeader( $farmname, $index ) )
	{
		# success
		my $message = "The pattern $index was deleted successfully";
		my $body = {
					 description => $desc,
					 success     => "true",
					 message     => $message,
		};

		if ( &getFarmStatus( $farmname ) ne 'down' )
		{
			require 'Zevenet::Farm::Action';
			if ( &getGlobalConfiguration( 'proxy_ng' ) ne 'true' )
			{
				&setFarmRestart( $farmname );
				$body->{ status } = 'needed restart';
			}
			else
			{
				require Zevenet::Farm::HTTP::Config;
				my $config_error = &getHTTPFarmConfigErrorMessage( $farmname );
				if ( $config_error ne "" )
				{
					$body->{ warning } = "Farm '$farmname' config error: $config_error";
				}
				else
				{
					&runFarmReload( $farmname );
					&eload(
							module => 'Zevenet::Cluster',
							func   => 'runZClusterRemoteManager',
							args   => ['farm', 'reload', $farmname],
					) if ( $eload );
				}
			}
		}

		return &httpResponse( { code => 200, body => $body } );
	}

	# error
	my $msg = "Error deleting the pattern $index";
	return &httpErrorResponse( code => 400, desc => $desc, msg => $msg );
}
