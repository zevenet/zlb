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

include 'Zevenet::Farm::Base';
include 'Zevenet::Farm::Config';
include 'Zevenet::Farm::HTTP::Service::Ext';
include 'Zevenet::Farm::HTTP::Service';

# POST	/farms/<>/service/<>/replacerequestheader/<>
sub add_serviceReplaceRequestHeader    # ( $json_obj, $farmname )
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );

	my $json_obj = shift;
	my $farmname = shift;
	my $service  = shift;

	my $type = "Request";
	return &add_serviceReplaceHeader( $json_obj, $farmname, $service, $type );
}

# POST	/farms/<>/service/<>/replaceresponseheader/<>
sub add_serviceReplaceResponseHeader    # ( $json_obj, $farmname )
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );

	my $json_obj = shift;
	my $farmname = shift;
	my $service  = shift;

	my $type = "Response";
	return &add_serviceReplaceHeader( $json_obj, $farmname, $service, $type );
}

sub add_serviceReplaceHeader    # ( $json_obj, $farmname, $type )
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $json_obj = shift;
	my $farmname = shift;
	my $service  = shift;
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

	# check if the header is already added
	foreach my $header (
					  @{ &getHTTPServiceReplaceHeaders( $farmname, $service, $type ) } )
	{
		if (    $header->{ header } eq $json_obj->{ header }
			 && $header->{ match } eq $json_obj->{ match } )
		{
			my $msg = "The header is already added.";
			return &httpErrorResponse( code => 400, desc => $desc, msg => $msg );
		}
	}

	my $params =
	  &getZAPIModel(
				  "farm_http_service_header_" . lc ( $type ) . "_replace-create.json" );

	# Check allowed parameters
	my $error_msg = &checkZAPIParams( $json_obj, $params, $desc );
	return &httpErrorResponse( code => 400, desc => $desc, msg => $error_msg )
	  if ( $error_msg );

	$json_obj->{ type } = $type;

	unless (
			 &addHTTPServiceReplaceHeaders(
											$farmname,
											$service,
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

			require Zevenet::Farm::HTTP::Config;
			my $config_error = &getHTTPFarmConfigErrorMessage( $farmname );
			if ( $config_error ne "" )
			{
				$body->{ warning } = "Farm '$farmname' config error: $config_error";
			}
			else
			{
				include 'Zevenet::Farm::Action';
				&runFarmReload( $farmname );
				&eload(
						module => 'Zevenet::Cluster',
						func   => 'runZClusterRemoteManager',
						args   => ['farm', 'reload', $farmname],
				) if ( $eload );
			}
		}

		return &httpResponse( { code => 200, body => $body } );
	}

	# error
	my $msg = "Error adding a new ReplaceHeader";
	return &httpErrorResponse( code => 400, desc => $desc, msg => $msg );
}

# PUT	/farms/<>/service/<>/replacerequestheader/<>
sub modify_serviceReplaceRequestHeader
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );

	my $json_obj = shift;
	my $farmname = shift;
	my $service  = shift;
	my $index    = shift;

	my $type = "Request";
	return &modify_serviceReplaceHeader( $json_obj, $farmname, $service, $type,
										 $index );
}

# PUT	/farms/<>/service/<>/replaceresponseheader/<>
sub modify_serviceReplaceResponseHeader
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );

	my $json_obj = shift;
	my $farmname = shift;
	my $service  = shift;
	my $index    = shift;

	my $type = "Response";
	return &modify_serviceReplaceHeader( $json_obj, $farmname, $service, $type,
										 $index );
}

sub modify_serviceReplaceHeader # ( $json_obj, $farmname, $service, $type, $index )
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $json_obj = shift;
	my $farmname = shift;
	my $service  = shift;
	my $type     = shift;
	my $index    = shift;

	my $desc = "Modify replaceHeader directive.";

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
	  &getZAPIModel(
				  "farm_http_service_header_" . lc ( $type ) . "_replace-modify.json" );

	# Check allowed parameters
	my $error_msg = &checkZAPIParams( $json_obj, $params, $desc );
	return &httpErrorResponse( code => 400, desc => $desc, msg => $error_msg )
	  if ( $error_msg );

	my @headers = @{ &getHTTPServiceReplaceHeaders( $farmname, $service, $type ) };

	# check index value
	if ( ( scalar @headers ) < $index + 1 )
	{
		my $msg = "The index has not been found.";
		return &httpErrorResponse( code => 400, desc => $desc, msg => $msg );
	}

	# check if the header is already added
	if (    @headers[$index]->{ header } ne $json_obj->{ header }
		 && @headers[$index]->{ match } ne $json_obj->{ match } )
	{
		foreach my $header ( @headers )
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
			&modifyHTTPServiceReplaceHeaders(
											 $farmname,
											 $service,
											 $type,
											 $json_obj->{ header }  // $header->{ header },
											 $json_obj->{ match }   // $header->{ match },
											 $json_obj->{ replace } // $header->{ replace },
											 $index
			)
	  )
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
			include 'Zevenet::Farm::Action';
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
	my $msg = "Error modifying a replaceheader";
	return &httpErrorResponse( code => 400, desc => $desc, msg => $msg );
}

#  DELETE	/farms/<>/service/<>/replacerequestheader/<>
sub del_serviceReplaceRequestHeader
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );

	my $farmname = shift;
	my $service  = shift;
	my $index    = shift;

	my $type = "Request";
	return &del_serviceReplaceheader( $farmname, $service, $index, $type );
}

#  DELETE	/farms/<>/service/<>/replaceresponseheader/<>
sub del_serviceReplaceResponseHeader
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );

	my $farmname = shift;
	my $service  = shift;
	my $index    = shift;

	my $type = "Response";
	return &del_serviceReplaceheader( $farmname, $service, $index, $type );
}

sub del_serviceReplaceheader
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $farmname = shift;
	my $service  = shift;
	my $index    = shift;
	my $type     = shift;

	my $desc = "Delete a replace header directive.";

	# Check that the farm exists
	if ( !&getFarmExists( $farmname ) )
	{
		my $msg = "The farm '$farmname' does not exist.";
		return &httpErrorResponse( code => 404, desc => $desc, msg => $msg );
	}

	# check index value
	if (
		 ( scalar @{ &getHTTPServiceReplaceHeaders( $farmname, $service, $type ) } ) <
		 $index + 1 )
	{
		my $msg = "The index has not been found.";
		return &httpErrorResponse( code => 400, desc => $desc, msg => $msg );
	}

	unless ( &delHTTPServiceReplaceHeaders( $farmname, $service, $index, $type ) )
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
			include 'Zevenet::Farm::Action';
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
	my $msg = "Error deleting the response header $index in service $service";
	return &httpErrorResponse( code => 400, desc => $desc, msg => $msg );
}

# PUT	/farms/<>/service/<>/replacerequestheader/<>/actions
sub move_serviceReplaceRequestHeader
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );

	my $json_obj = shift;
	my $farmname = shift;
	my $service  = shift;
	my $index    = shift;

	my $type  = "Request";
	my $regex = '^\s*ReplaceHeader\s+Request\s+(.+)';
	return
	  &move_serviceReplaceHeader( $json_obj, $type, $regex, $farmname,
								  $service, $index );
}

# PUT	/farms/<>/service/<>/replaceresponseheader/<>/actions
sub move_serviceReplaceResponseHeader
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );

	my $json_obj = shift;
	my $farmname = shift;
	my $service  = shift;
	my $index    = shift;

	my $type  = "Response";
	my $regex = '^\s*ReplaceHeader\s+Response\s+(.+)';
	return
	  &move_serviceReplaceHeader( $json_obj, $type, $regex, $farmname,
								  $service, $index );
}

sub move_serviceReplaceHeader # ( $json_obj, $type, $regex, $farmname, $service, $index )
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );

	my $json_obj = shift;
	my $type     = shift;
	my $regex    = shift;
	my $farmname = shift;
	my $service  = shift;
	my $index    = shift;

	my $desc = "Move replaceHeader";

	# validate FARM NAME
	if ( !&getFarmExists( $farmname ) )
	{
		my $msg = "The farmname $farmname does not exist.";
		return &httpErrorResponse( code => 404, desc => $desc, msg => $msg );
	}

	my @headers = @{ &getHTTPServiceReplaceHeaders( $farmname, $service, $type ) };

	my $params =
	  &getZAPIModel(
					"farm_http_service_header_" . lc ( $type ) . "_replace-move.json" );
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

	my $err =
	  &moveServiceHeader( $farmname, $service, $regex, $json_obj->{ position },
						  $index );

	my $msg = "Header was moved successfully.";
	my $body = { description => $desc, params => $json_obj, message => $msg };

	return &httpResponse( { code => 200, body => $body } );
}

# POST	/farms/<>/service/<>/rewriteurl
sub add_serviceRewriteUrl    # ( $json_obj, $farmname, $service )
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $json_obj = shift;
	my $farmname = shift;
	my $service  = shift;

	my $desc = "Add a RewriteUrl.";

	if ( &getGlobalConfiguration( 'proxy_ng' ) ne 'true' )
	{
		my $msg = "RewriteUrl is only available for zproxy.";
		return &httpErrorResponse( code => 404, desc => $desc, msg => $msg );
	}

	# Check that the farm exists
	if ( !&getFarmExists( $farmname ) )
	{
		my $msg = "The farm '$farmname' does not exist.";
		return &httpErrorResponse( code => 404, desc => $desc, msg => $msg );
	}

	my $params = &getZAPIModel( "farm_http_service_url_rewrite-create.json" );

	# Check allowed parameters
	my $error_msg = &checkZAPIParams( $json_obj, $params, $desc );
	return &httpErrorResponse( code => 400, desc => $desc, msg => $error_msg )
	  if ( $error_msg );

	# check if the pattern is already added
	foreach my $header ( @{ &getHTTPServiceRewriteUrl( $farmname, $service ) } )
	{
		if ( $header->{ pattern } eq $json_obj->{ pattern } )
		{
			my $msg = "The pattern is already added.";
			return &httpErrorResponse( code => 400, desc => $desc, msg => $msg );
		}
	}

	unless (
			 &addHTTPServiceRewriteUrl(
										$farmname,
										$service,
										$json_obj->{ pattern },
										$json_obj->{ replace },
										$json_obj->{ last }
			 )
	  )
	{
		# success
		my $message = "Added a new rewrite url";
		my $body = {
					 description => $desc,
					 success     => "true",
					 message     => $message,
		};

		if ( &getFarmStatus( $farmname ) ne 'down' )
		{

			require Zevenet::Farm::HTTP::Config;
			my $config_error = &getHTTPFarmConfigErrorMessage( $farmname );
			if ( $config_error ne "" )
			{
				$body->{ warning } = "Farm '$farmname' config error: $config_error";
			}
			else
			{
				include 'Zevenet::Farm::Action';
				&runFarmReload( $farmname );
				&eload(
						module => 'Zevenet::Cluster',
						func   => 'runZClusterRemoteManager',
						args   => ['farm', 'reload', $farmname],
				) if ( $eload );
			}
		}

		return &httpResponse( { code => 200, body => $body } );
	}

	# error
	my $msg = "Error adding a new RewriteUrl";
	return &httpErrorResponse( code => 400, desc => $desc, msg => $msg );
}

# PUT	/farms/<>/service/<>/rewriteurl/<>
sub modify_serviceRewriteUrl    # ( $json_obj, $farmname, $service, $index )
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $json_obj = shift;
	my $farmname = shift;
	my $service  = shift;
	my $index    = shift;

	my $desc = "Modify a RewriteUrl.";

	if ( &getGlobalConfiguration( 'proxy_ng' ) ne 'true' )
	{
		my $msg = "RewriteUrl is only available for zproxy.";
		return &httpErrorResponse( code => 404, desc => $desc, msg => $msg );
	}

	# Check that the farm exists
	if ( !&getFarmExists( $farmname ) )
	{
		my $msg = "The farm '$farmname' does not exist.";
		return &httpErrorResponse( code => 404, desc => $desc, msg => $msg );
	}

	my $params = &getZAPIModel( "farm_http_service_url_rewrite-modify.json" );

	# Check allowed parameters
	my $error_msg = &checkZAPIParams( $json_obj, $params, $desc );
	return &httpErrorResponse( code => 400, desc => $desc, msg => $error_msg )
	  if ( $error_msg );

	my @directives = @{ &getHTTPServiceRewriteUrl( $farmname, $service ) };

	# check index value
	if ( ( scalar @directives ) < $index + 1 )
	{
		my $msg = "The index has not been found.";
		return &httpErrorResponse( code => 400, desc => $desc, msg => $msg );
	}

	if ( @directives[$index]->{ pattern } ne $json_obj->{ pattern } )
	{
		# check if the header is already added
		foreach my $header ( @directives )
		{
			if ( $header->{ pattern } eq $json_obj->{ pattern } )
			{
				my $msg = "The pattern is already added.";
				return &httpErrorResponse( code => 400, desc => $desc, msg => $msg );
			}
		}
	}

	my $directive = @directives[$index];

	unless (
			&modifyHTTPServiceRewriteUrl(
										  $farmname,
										  $service,
										  $json_obj->{ pattern } // $directive->{ pattern },
										  $json_obj->{ replace } // $directive->{ replace },
										  $json_obj->{ last }    // $directive->{ last },
										  $index
			)
	  )
	{
		# success
		my $message = "Modify a new rewrite url";
		my $body = {
					 description => $desc,
					 success     => "true",
					 message     => $message,
		};

		if ( &getFarmStatus( $farmname ) ne 'down' )
		{
			require Zevenet::Farm::HTTP::Config;
			my $config_error = &getHTTPFarmConfigErrorMessage( $farmname );
			if ( $config_error ne "" )
			{
				$body->{ warning } = "Farm '$farmname' config error: $config_error";
			}
			else
			{
				include 'Zevenet::Farm::Action';
				&runFarmReload( $farmname );
				&eload(
						module => 'Zevenet::Cluster',
						func   => 'runZClusterRemoteManager',
						args   => ['farm', 'reload', $farmname],
				) if ( $eload );
			}
		}

		return &httpResponse( { code => 200, body => $body } );
	}

	# error
	my $msg = "Error adding a new RewriteUrl";
	return &httpErrorResponse( code => 400, desc => $desc, msg => $msg );
}

#  DELETE	/farms/<>/service/<>/rewriteurl/<>
sub del_serviceRewriteUrl
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $farmname = shift;
	my $service  = shift;
	my $index    = shift;

	my $desc = "Delete a rewrite url directive.";

	# Check that the farm exists
	if ( !&getFarmExists( $farmname ) )
	{
		my $msg = "The farm '$farmname' does not exist.";
		return &httpErrorResponse( code => 404, desc => $desc, msg => $msg );
	}

	# check index value
	if (
		 ( scalar @{ &getHTTPServiceRewriteUrl( $farmname, $service ) } ) < $index + 1 )
	{
		my $msg = "The index has not been found.";
		return &httpErrorResponse( code => 400, desc => $desc, msg => $msg );
	}

	unless ( &delHTTPServiceRewriteUrl( $farmname, $service, $index ) )
	{
		# success
		my $message = "The rewrite url $index has been deleted successfully";
		my $body = {
					 description => $desc,
					 success     => "true",
					 message     => $message,
		};

		if ( &getFarmStatus( $farmname ) ne 'down' )
		{
			require Zevenet::Farm::HTTP::Config;
			my $config_error = &getHTTPFarmConfigErrorMessage( $farmname );
			if ( $config_error ne "" )
			{
				$body->{ warning } = "Farm '$farmname' config error: $config_error";
			}
			else
			{
				include 'Zevenet::Farm::Action';
				&runFarmReload( $farmname );
				&eload(
						module => 'Zevenet::Cluster',
						func   => 'runZClusterRemoteManager',
						args   => ['farm', 'reload', $farmname],
				) if ( $eload );
			}
		}

		return &httpResponse( { code => 200, body => $body } );
	}

	# error
	my $msg = "Error deleting the rewrite url $index in service $service";
	return &httpErrorResponse( code => 400, desc => $desc, msg => $msg );
}

#  POST	/farms/<>/service/<>/rewriteurl/<>/actions
sub move_serviceRewriteUrl    # ( $json_obj, $farmname, $service, $index )
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );

	my $json_obj = shift;
	my $farmname = shift;
	my $service  = shift;
	my $index    = shift;

	my $desc  = "Move rewriteUrl";
	my $regex = '(\s+)RewriteUrl\s+';

	# validate FARM NAME
	if ( !&getFarmExists( $farmname ) )
	{
		my $msg = "The farmname $farmname does not exist.";
		return &httpErrorResponse( code => 404, desc => $desc, msg => $msg );
	}

	my @headers = @{ &getHTTPServiceRewriteUrl( $farmname, $service ) };

	my $params = &getZAPIModel( "farm_http_service_url_rewrite-move.json" );
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

	my $err =
	  &moveServiceHeader( $farmname, $service, $regex, $json_obj->{ position },
						  $index );

	my $msg = "Header was moved successfully.";
	my $body = { description => $desc, params => $json_obj, message => $msg };

	return &httpResponse( { code => 200, body => $body } );
}

# POST	/farms/<>/service/<>/addrequestheader
sub add_serviceAddRequestHeader    # ( $json_obj, $farmname, $service )
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $json_obj = shift;
	my $farmname = shift;
	my $service  = shift;

	my $desc = "Add a AddHeader.";

	if ( &getGlobalConfiguration( 'proxy_ng' ) ne 'true' )
	{
		my $msg = "AddHeader is only available for zproxy.";
		return &httpErrorResponse( code => 404, desc => $desc, msg => $msg );
	}

	# Check that the farm exists
	if ( !&getFarmExists( $farmname ) )
	{
		my $msg = "The farm '$farmname' does not exist.";
		return &httpErrorResponse( code => 404, desc => $desc, msg => $msg );
	}

	my $params =
	  &getZAPIModel( "farm_http_service_header_request_add-create.json" );

	# Check allowed parameters
	my $error_msg = &checkZAPIParams( $json_obj, $params, $desc );
	return &httpErrorResponse( code => 400, desc => $desc, msg => $error_msg )
	  if ( $error_msg );

	# check if the header is already added
	foreach
	  my $header ( @{ &getHTTPServiceAddRequestHeader( $farmname, $service ) } )
	{
		if ( $header->{ header } eq $json_obj->{ header } )
		{
			my $msg = "The header is already added.";
			return &httpErrorResponse( code => 400, desc => $desc, msg => $msg );
		}
	}

	unless (
		 &addHTTPServiceAddRequestHeader( $farmname, $service, $json_obj->{ header } ) )
	{
		# success
		my $message = "Added a new add request header";
		my $body = {
					 description => $desc,
					 success     => "true",
					 message     => $message,
		};

		if ( &getFarmStatus( $farmname ) ne 'down' )
		{
			require Zevenet::Farm::HTTP::Config;
			my $config_error = &getHTTPFarmConfigErrorMessage( $farmname );
			if ( $config_error ne "" )
			{
				$body->{ warning } = "Farm '$farmname' config error: $config_error";
			}
			else
			{
				include 'Zevenet::Farm::Action';
				&runFarmReload( $farmname );
				&eload(
						module => 'Zevenet::Cluster',
						func   => 'runZClusterRemoteManager',
						args   => ['farm', 'reload', $farmname],
				) if ( $eload );
			}
		}

		return &httpResponse( { code => 200, body => $body } );
	}

	# error
	my $msg = "Error adding a new AddRequestHeader";
	return &httpErrorResponse( code => 400, desc => $desc, msg => $msg );
}

# PUT	/farms/<>/service/<>/addrequestheader/<>
sub modify_serviceAddRequestHeader  # ( $json_obj, $farmname, $service, $index )
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $json_obj = shift;
	my $farmname = shift;
	my $service  = shift;
	my $index    = shift;

	my $desc = "Modify AddHeader directive.";

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
	  &getZAPIModel( "farm_http_service_header_request_add-modify.json" );

	# Check allowed parameters
	my $error_msg = &checkZAPIParams( $json_obj, $params, $desc );
	return &httpErrorResponse( code => 400, desc => $desc, msg => $error_msg )
	  if ( $error_msg );

	my @directives = @{ &getHTTPServiceAddRequestHeader( $farmname, $service ) };

	# check index value
	if ( ( scalar @directives ) < $index + 1 )
	{
		my $msg = "The index has not been found.";
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

	unless (
			 &modifyHTTPServiceAddRequestHeader( $farmname,             $service,
												 $json_obj->{ header }, $index )
	  )
	{
		# success
		my $message = "Modify an item from the addheader list";
		my $body = {
					 description => $desc,
					 success     => "true",
					 message     => $message,
		};

		if ( &getFarmStatus( $farmname ) ne 'down' )
		{
			include 'Zevenet::Farm::Action';
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

#  DELETE	/farms/<>/service/<>/addrequestheader/<>
sub del_serviceAddRequestHeader
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $farmname = shift;
	my $service  = shift;
	my $index    = shift;

	my $desc = "Delete an add header directive.";

	# Check that the farm exists
	if ( !&getFarmExists( $farmname ) )
	{
		my $msg = "The farm '$farmname' does not exist.";
		return &httpErrorResponse( code => 404, desc => $desc, msg => $msg );
	}

	# check index value
	if (
		 ( scalar @{ &getHTTPServiceAddRequestHeader( $farmname, $service ) } ) <
		 $index + 1 )
	{
		my $msg = "The index has not been found.";
		return &httpErrorResponse( code => 400, desc => $desc, msg => $msg );
	}

	unless ( &delHTTPServiceAddRequestHeader( $farmname, $service, $index ) )
	{
		# success
		my $message = "The add request header $index has been deleted successfully";
		my $body = {
					 description => $desc,
					 success     => "true",
					 message     => $message,
		};

		if ( &getFarmStatus( $farmname ) ne 'down' )
		{
			require Zevenet::Farm::HTTP::Config;
			my $config_error = &getHTTPFarmConfigErrorMessage( $farmname );
			if ( $config_error ne "" )
			{
				$body->{ warning } = "Farm '$farmname' config error: $config_error";
			}
			else
			{
				include 'Zevenet::Farm::Action';
				&runFarmReload( $farmname );
				&eload(
						module => 'Zevenet::Cluster',
						func   => 'runZClusterRemoteManager',
						args   => ['farm', 'reload', $farmname],
				) if ( $eload );
			}
		}

		return &httpResponse( { code => 200, body => $body } );
	}

	# error
	my $msg = "Error deleting the add request header $index in service $service";
	return &httpErrorResponse( code => 400, desc => $desc, msg => $msg );
}

# POST	/farms/<>/service/<>/addresponseheader
sub add_serviceAddResponseHeader    # ( $json_obj, $farmname, $service )
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $json_obj = shift;
	my $farmname = shift;
	my $service  = shift;

	my $desc = "Add a AddResponseHeader.";

	if ( &getGlobalConfiguration( 'proxy_ng' ) ne 'true' )
	{
		my $msg = "AddResponseHeader is only available for zproxy.";
		return &httpErrorResponse( code => 404, desc => $desc, msg => $msg );
	}

	# Check that the farm exists
	if ( !&getFarmExists( $farmname ) )
	{
		my $msg = "The farm '$farmname' does not exist.";
		return &httpErrorResponse( code => 404, desc => $desc, msg => $msg );
	}

	my $params =
	  &getZAPIModel( "farm_http_service_header_response_add-create.json" );

	# Check allowed parameters
	my $error_msg = &checkZAPIParams( $json_obj, $params, $desc );
	return &httpErrorResponse( code => 400, desc => $desc, msg => $error_msg )
	  if ( $error_msg );

	# check if the header is already added
	foreach
	  my $header ( @{ &getHTTPServiceAddResponseHeader( $farmname, $service ) } )
	{
		if ( $header->{ header } eq $json_obj->{ header } )
		{
			my $msg = "The header is already added.";
			return &httpErrorResponse( code => 400, desc => $desc, msg => $msg );
		}
	}

	unless (
		&addHTTPServiceAddResponseHeader( $farmname, $service, $json_obj->{ header } ) )
	{
		# success
		my $message = "Added a new add response header";
		my $body = {
					 description => $desc,
					 success     => "true",
					 message     => $message,
		};

		if ( &getFarmStatus( $farmname ) ne 'down' )
		{
			require Zevenet::Farm::HTTP::Config;
			my $config_error = &getHTTPFarmConfigErrorMessage( $farmname );
			if ( $config_error ne "" )
			{
				$body->{ warning } = "Farm '$farmname' config error: $config_error";
			}
			else
			{
				include 'Zevenet::Farm::Action';
				&runFarmReload( $farmname );
				&eload(
						module => 'Zevenet::Cluster',
						func   => 'runZClusterRemoteManager',
						args   => ['farm', 'reload', $farmname],
				) if ( $eload );
			}
		}

		return &httpResponse( { code => 200, body => $body } );
	}

	# error
	my $msg = "Error adding a new AddResponseHeader";
	return &httpErrorResponse( code => 400, desc => $desc, msg => $msg );
}

# PUT	/farms/<>/service/<>/addresponseheader/<>
sub modify_serviceAddResponseHeader # ( $json_obj, $farmname, $service, $index )
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $json_obj = shift;
	my $farmname = shift;
	my $service  = shift;
	my $index    = shift;

	my $desc = "Modify AddResponseHeader directive.";

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
	  &getZAPIModel( "farm_http_service_header_response_add-modify.json" );

	# Check allowed parameters
	my $error_msg = &checkZAPIParams( $json_obj, $params, $desc );
	return &httpErrorResponse( code => 400, desc => $desc, msg => $error_msg )
	  if ( $error_msg );

	my @directives = @{ &getHTTPServiceAddResponseHeader( $farmname, $service ) };

	# check index value
	if ( ( scalar @directives ) < $index + 1 )
	{
		my $msg = "The index has not been found.";
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

	unless (
			 &modifyHTTPServiceAddResponseHeader( $farmname,             $service,
												  $json_obj->{ header }, $index )
	  )
	{
		# success
		my $message = "Modify an item from the addresponseheader list";
		my $body = {
					 description => $desc,
					 success     => "true",
					 message     => $message,
		};

		if ( &getFarmStatus( $farmname ) ne 'down' )
		{
			include 'Zevenet::Farm::Action';
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

#  DELETE	/farms/<>/service/<>/addrequestheader/<>
sub del_serviceAddResponseHeader
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $farmname = shift;
	my $service  = shift;
	my $index    = shift;

	my $desc = "Delete a add response header directive.";

	# Check that the farm exists
	if ( !&getFarmExists( $farmname ) )
	{
		my $msg = "The farm '$farmname' does not exist.";
		return &httpErrorResponse( code => 404, desc => $desc, msg => $msg );
	}

	# check index value
	if (
		 ( scalar @{ &getHTTPServiceAddResponseHeader( $farmname, $service ) } ) <
		 $index + 1 )
	{
		my $msg = "The index has not been found.";
		return &httpErrorResponse( code => 400, desc => $desc, msg => $msg );
	}

	unless ( &delHTTPServiceAddResponseHeader( $farmname, $service, $index ) )
	{
		# success
		my $message = "The add response header $index has been deleted successfully";
		my $body = {
					 description => $desc,
					 success     => "true",
					 message     => $message,
		};

		if ( &getFarmStatus( $farmname ) ne 'down' )
		{
			require Zevenet::Farm::HTTP::Config;
			my $config_error = &getHTTPFarmConfigErrorMessage( $farmname );
			if ( $config_error ne "" )
			{
				$body->{ warning } = "Farm '$farmname' config error: $config_error";
			}
			else
			{
				include 'Zevenet::Farm::Action';
				&runFarmReload( $farmname );
				&eload(
						module => 'Zevenet::Cluster',
						func   => 'runZClusterRemoteManager',
						args   => ['farm', 'reload', $farmname],
				) if ( $eload );
			}
		}

		return &httpResponse( { code => 200, body => $body } );
	}

	# error
	my $msg = "Error deleting the add response header $index in service $service";
	return &httpErrorResponse( code => 400, desc => $desc, msg => $msg );
}

# POST	/farms/<>/service/<>/removerequestheader
sub add_serviceRemoveRequestHeader    # ( $json_obj, $farmname, $service )
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $json_obj = shift;
	my $farmname = shift;
	my $service  = shift;

	my $desc = "Add a HeadRemove.";

	if ( &getGlobalConfiguration( 'proxy_ng' ) ne 'true' )
	{
		my $msg = "HeadRemove is only available for zproxy.";
		return &httpErrorResponse( code => 404, desc => $desc, msg => $msg );
	}

	# Check that the farm exists
	if ( !&getFarmExists( $farmname ) )
	{
		my $msg = "The farm '$farmname' does not exist.";
		return &httpErrorResponse( code => 404, desc => $desc, msg => $msg );
	}

	my $params =
	  &getZAPIModel( "farm_http_service_header_request_remove-create.json" );

	# Check allowed parameters
	my $error_msg = &checkZAPIParams( $json_obj, $params, $desc );
	return &httpErrorResponse( code => 400, desc => $desc, msg => $error_msg )
	  if ( $error_msg );

	# check if the header is already added
	foreach
	  my $header ( @{ &getHTTPServiceRemoveRequestHeader( $farmname, $service ) } )
	{
		if ( $header->{ pattern } eq $json_obj->{ pattern } )
		{
			my $msg = "The pattern is already added.";
			return &httpErrorResponse( code => 400, desc => $desc, msg => $msg );
		}
	}

	unless (
		 &addHTTPServiceRemoveRequestHeader( $farmname, $service, $json_obj->{ pattern }
		 )
	  )
	{
		# success
		my $message = "Added a new remove request header";
		my $body = {
					 description => $desc,
					 success     => "true",
					 message     => $message,
		};

		if ( &getFarmStatus( $farmname ) ne 'down' )
		{
			require Zevenet::Farm::HTTP::Config;
			my $config_error = &getHTTPFarmConfigErrorMessage( $farmname );
			if ( $config_error ne "" )
			{
				$body->{ warning } = "Farm '$farmname' config error: $config_error";
			}
			else
			{
				include 'Zevenet::Farm::Action';
				&runFarmReload( $farmname );
				&eload(
						module => 'Zevenet::Cluster',
						func   => 'runZClusterRemoteManager',
						args   => ['farm', 'reload', $farmname],
				) if ( $eload );
			}
		}

		return &httpResponse( { code => 200, body => $body } );
	}

	# error
	my $msg = "Error adding a new RemoverequestHeader";
	return &httpErrorResponse( code => 400, desc => $desc, msg => $msg );
}

# PUT	/farms/<>/service/<>/removerequestheader/<>
sub modify_serviceRemoveRequestHeader # ( $json_obj, $farmname, $service, $index )
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $json_obj = shift;
	my $farmname = shift;
	my $service  = shift;
	my $index    = shift;

	my $desc = "Modify RemoveResponseHeader directive.";

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
	  &getZAPIModel( "farm_http_service_header_request_remove-modify.json" );

	# Check allowed parameters
	my $error_msg = &checkZAPIParams( $json_obj, $params, $desc );
	return &httpErrorResponse( code => 400, desc => $desc, msg => $error_msg )
	  if ( $error_msg );

	my @directives = @{ &getHTTPServiceRemoveRequestHeader( $farmname, $service ) };

	# check index value
	if ( ( scalar @directives ) < $index + 1 )
	{
		my $msg = "The index has not been found.";
		return &httpErrorResponse( code => 400, desc => $desc, msg => $msg );
	}

	# check if the header is already added
	foreach my $header ( @directives )
	{
		if ( $header->{ pattern } eq $json_obj->{ pattern } )
		{
			my $msg = "The pattern is already added.";
			return &httpErrorResponse( code => 400, desc => $desc, msg => $msg );
		}
	}

	unless (
			 &modifyHTTPServiceRemoveRequestHeader( $farmname,              $service,
													$json_obj->{ pattern }, $index )
	  )
	{
		# success
		my $message = "Modify an item from the removeresponseheader list";
		my $body = {
					 description => $desc,
					 success     => "true",
					 message     => $message,
		};

		if ( &getFarmStatus( $farmname ) ne 'down' )
		{
			include 'Zevenet::Farm::Action';
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
	my $msg = "Error modifying a removeresponseheader";
	return &httpErrorResponse( code => 400, desc => $desc, msg => $msg );
}

#  DELETE	/farms/<>/service/<>/removerequestheader/<>
sub del_serviceRemoveRequestHeader
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $farmname = shift;
	my $service  = shift;
	my $index    = shift;

	my $desc = "Delete a remove request header directive.";

	# Check that the farm exists
	if ( !&getFarmExists( $farmname ) )
	{
		my $msg = "The farm '$farmname' does not exist.";
		return &httpErrorResponse( code => 404, desc => $desc, msg => $msg );
	}

	# check index value
	if (
		 ( scalar @{ &getHTTPServiceRemoveRequestHeader( $farmname, $service ) } ) <
		 $index + 1 )
	{
		my $msg = "The index has not been found.";
		return &httpErrorResponse( code => 400, desc => $desc, msg => $msg );
	}

	unless ( &delHTTPServiceRemoveRequestHeader( $farmname, $service, $index ) )
	{
		# success
		my $message = "The remove request header $index has been deleted successfully";
		my $body = {
					 description => $desc,
					 success     => "true",
					 message     => $message,
		};

		if ( &getFarmStatus( $farmname ) ne 'down' )
		{
			require Zevenet::Farm::HTTP::Config;
			my $config_error = &getHTTPFarmConfigErrorMessage( $farmname );
			if ( $config_error ne "" )
			{
				$body->{ warning } = "Farm '$farmname' config error: $config_error";
			}
			else
			{
				include 'Zevenet::Farm::Action';
				&runFarmReload( $farmname );
				&eload(
						module => 'Zevenet::Cluster',
						func   => 'runZClusterRemoteManager',
						args   => ['farm', 'reload', $farmname],
				) if ( $eload );
			}
		}

		return &httpResponse( { code => 200, body => $body } );
	}

	# error
	my $msg = "Error deleting the remove request header $index in service $service";
	return &httpErrorResponse( code => 400, desc => $desc, msg => $msg );
}

# POST	/farms/<>/service/<>/removeresponseheader
sub add_serviceRemoveResponseHeader    # ( $json_obj, $farmname, $service )
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $json_obj = shift;
	my $farmname = shift;
	my $service  = shift;

	my $desc = "Add a RemoveResponseHeader.";

	if ( &getGlobalConfiguration( 'proxy_ng' ) ne 'true' )
	{
		my $msg = "RemoveResponseHeader is only available for zproxy.";
		return &httpErrorResponse( code => 404, desc => $desc, msg => $msg );
	}

	# Check that the farm exists
	if ( !&getFarmExists( $farmname ) )
	{
		my $msg = "The farm '$farmname' does not exist.";
		return &httpErrorResponse( code => 404, desc => $desc, msg => $msg );
	}

	my $params =
	  &getZAPIModel( "farm_http_service_header_response_remove-create.json" );

	# Check allowed parameters
	my $error_msg = &checkZAPIParams( $json_obj, $params, $desc );
	return &httpErrorResponse( code => 400, desc => $desc, msg => $error_msg )
	  if ( $error_msg );

	# check if the header is already added
	foreach
	  my $header ( @{ &getHTTPServiceRemoveResponseHeader( $farmname, $service ) } )
	{
		if ( $header->{ pattern } eq $json_obj->{ pattern } )
		{
			my $msg = "The pattern is already added.";
			return &httpErrorResponse( code => 400, desc => $desc, msg => $msg );
		}
	}

	unless (
			 &addHTTPServiceRemoveResponseHeader( $farmname, $service,
												  $json_obj->{ pattern } )
	  )
	{
		# success
		my $message = "Added a new remove response header";
		my $body = {
					 description => $desc,
					 success     => "true",
					 message     => $message,
		};

		if ( &getFarmStatus( $farmname ) ne 'down' )
		{
			require Zevenet::Farm::HTTP::Config;
			my $config_error = &getHTTPFarmConfigErrorMessage( $farmname );
			if ( $config_error ne "" )
			{
				$body->{ warning } = "Farm '$farmname' config error: $config_error";
			}
			else
			{
				include 'Zevenet::Farm::Action';
				&runFarmReload( $farmname );
				&eload(
						module => 'Zevenet::Cluster',
						func   => 'runZClusterRemoteManager',
						args   => ['farm', 'reload', $farmname],
				) if ( $eload );
			}
		}

		return &httpResponse( { code => 200, body => $body } );
	}

	# error
	my $msg = "Error adding a new RemoveResponseHeader";
	return &httpErrorResponse( code => 400, desc => $desc, msg => $msg );
}

# PUT	/farms/<>/service/<>/removeresponseheader/<>
sub modify_serviceRemoveResponseHeader # ( $json_obj, $farmname, $service, $index )
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $json_obj = shift;
	my $farmname = shift;
	my $service  = shift;
	my $index    = shift;

	my $desc = "Modify RemoveResponseHeader directive.";

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
	  &getZAPIModel( "farm_http_service_header_response_remove-modify.json" );

	# Check allowed parameters
	my $error_msg = &checkZAPIParams( $json_obj, $params, $desc );
	return &httpErrorResponse( code => 400, desc => $desc, msg => $error_msg )
	  if ( $error_msg );

	my @directives =
	  @{ &getHTTPServiceRemoveResponseHeader( $farmname, $service ) };

	# check index value
	if ( ( scalar @directives ) < $index + 1 )
	{
		my $msg = "The index has not been found.";
		return &httpErrorResponse( code => 400, desc => $desc, msg => $msg );
	}

	# check if the header is already added
	foreach my $header ( @directives )
	{
		if ( $header->{ pattern } eq $json_obj->{ pattern } )
		{
			my $msg = "The pattern is already added.";
			return &httpErrorResponse( code => 400, desc => $desc, msg => $msg );
		}
	}

	unless (
			 &modifyHTTPServiceRemoveResponseHeader(
										 $farmname, $service, $json_obj->{ pattern }, $index
			 )
	  )
	{
		# success
		my $message = "Modify an item from the removeresponseheader list";
		my $body = {
					 description => $desc,
					 success     => "true",
					 message     => $message,
		};

		if ( &getFarmStatus( $farmname ) ne 'down' )
		{
			include 'Zevenet::Farm::Action';
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

#  DELETE	/farms/<>/service/<>/removeresponseheader/<>
sub del_serviceRemoveResponseHeader
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $farmname = shift;
	my $service  = shift;
	my $index    = shift;

	my $desc = "Delete a remove response header directive.";

	# Check that the farm exists
	if ( !&getFarmExists( $farmname ) )
	{
		my $msg = "The farm '$farmname' does not exist.";
		return &httpErrorResponse( code => 404, desc => $desc, msg => $msg );
	}

	# check index value
	if (
		 ( scalar @{ &getHTTPServiceRemoveResponseHeader( $farmname, $service ) } ) <
		 $index + 1 )
	{
		my $msg = "The index has not been found.";
		return &httpErrorResponse( code => 400, desc => $desc, msg => $msg );
	}

	unless ( &delHTTPServiceRemoveResponseHeader( $farmname, $service, $index ) )
	{
		# success
		my $message = "The remove response header $index has been deleted successfully";
		my $body = {
					 description => $desc,
					 success     => "true",
					 message     => $message,
		};

		if ( &getFarmStatus( $farmname ) ne 'down' )
		{
			require Zevenet::Farm::HTTP::Config;
			my $config_error = &getHTTPFarmConfigErrorMessage( $farmname );
			if ( $config_error ne "" )
			{
				$body->{ warning } = "Farm '$farmname' config error: $config_error";
			}
			else
			{
				include 'Zevenet::Farm::Action';
				&runFarmReload( $farmname );
				&eload(
						module => 'Zevenet::Cluster',
						func   => 'runZClusterRemoteManager',
						args   => ['farm', 'reload', $farmname],
				) if ( $eload );
			}
		}

		return &httpResponse( { code => 200, body => $body } );
	}

	# error
	my $msg =
	  "Error deleting the remove response header $index in service $service";
	return &httpErrorResponse( code => 400, desc => $desc, msg => $msg );
}

1;

