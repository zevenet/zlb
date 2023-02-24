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
use Zevenet::Log;

=begin nd
Function: execHTTRrequest

	Execute a http request.
	Load environment proxy variables.
	The function has a default timeout, this parameter can be overwrite.

Parameters:
	params - hash with parameters. The possible keys are:
		$method, http method for the request: PUT, POST, DELETE, GET... GET is put by default
		$url
		\@headers, extra headers for the request. Not implemented
		\@json, json object with request parameters
		$file, file to write the output
		$timeout, rewrite the timeout option. 3 seconds by default

Returns:
	hash ref - 	{
					error, 0 or 1
					content, response body
					json, json object decoded
					http_code, code of the request
				}

=cut

sub execHTTRequest
{
	&zenlog( __FILE__ . q{:} . __LINE__ . q{:} . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );

	# enable one:
	# return &execHTTRequestModule(@_);
	return &execHTTRequestCmd( @_ );
}

sub execHTTRequestModule
{
	&zenlog( __FILE__ . q{:} . __LINE__ . q{:} . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $params = shift;

	require LWP::UserAgent;

	my $out->{ error } = 1;

	if ( not $params->{ url } )
	{
		&zenlog( "url has not been found", 'error' );
		return $out;
	}

	$params->{ method }  //= 'GET';    # by default
	$params->{ timeout } //= 3;        # by default

	my $ua = LWP::UserAgent->new(
								  agent    => '',
								  ssl_opts => {
												verify_hostname => 0,
												SSL_verify_mode => 0x00
								  }
	);

	$ua->env_proxy;
	$ua->timeout( $params->{ timeout } );

	my $request = HTTP::Request->new( $params->{ method } => $params->{ url } );

	# add json body
	if ( $params->{ json } )
	{
		require JSON;
		$request->content_type( 'application/json' );
		$request->content( JSON::encode_json( $params->{ json } ) );
	}

	# execute the request
	my $response = $ua->request( $request );

	if ( $response->code =~ /^2/ )
	{
		$out->{ error } = 0;
		if ( defined $params->{ file } )
		{
			require Zevenet::Lock;
			my $fh = &openlock( $params->{ file }, 'w' );
			print $fh $response->content();
			close $fh;
		}

		require JSON;
		eval { $out->{ json } = JSON::decode_json( $response->content() ); };
	}

	{
		my $mem_string = `grep RSS /proc/$$/status`;

		chomp ( $mem_string );
		$mem_string =~ s/:.\s+/: /;

		print "\n\nMemory: $mem_string\n\n";
	}

	return $out;
}

sub execHTTRequestCmd
{
	&zenlog( __FILE__ . q{:} . __LINE__ . q{:} . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $params = shift;

	my $out->{ error } = 1;

	if ( not $params->{ url } )
	{
		&zenlog( "url has not been found", 'error' );
		return $out;
	}

	$params->{ method }  //= 'GET';    # by default
	$params->{ timeout } //= 3;        # by default

	my $method  = "-X $params->{method}";
	my $timeout = "--connect-timeout $params->{timeout}";

	# add json body
	my $json = "";
	if ( $params->{ json } )
	{
		require JSON;
		$json = "-H 'Content-Type: application/json' --data '"
		  . JSON::encode_json( $params->{ json } ) . "'";
	}

	# execute the request
	my $request = "curl -s $timeout $method $json $params->{url} 2>/dev/null";
	&zenlog( "$request" );

	my $response = `$request`;
	$out->{ error } = $?;

	if ( not $out->{ error } )
	{
		$out->{ error } = 0;
		if ( defined $params->{ file } )
		{
			require Zevenet::Lock;
			my $fh = &openlock( $params->{ file }, 'w' );
			print $fh $response;
			close $fh;
		}

		require JSON;
		eval { $out->{ json } = JSON::decode_json( $response ); };
	}

	return $out;
}

=begin nd
Function: runHTTPRequest

	Execute an http request.

Parameters:
	request_ref - Hash ref with request parameters.
Returns:
	error_ref - Hash ref with values.

Variable: $request_ref.
	$request_ref->{ env_proxy } - True, use env proxy settings. Default false.
	$request_ref->{ agent } - Agent string proxy settings. Default Empty
	$request_ref->{ timeout } - Timeout to use for the request. Default 3
	$request_ref->{ method } - Http method for the request. Default GET
	$request_ref->{ protocol } - Protocol to use for the request. Default "http"
	$request_ref->{ host } - Host to use for the request.
	$request_ref->{ port } - Port to use for the request.
	$request_ref->{ path } - Path to use for the request. Default "/"
	$request_ref->{ auth } - $auth_ref to auth the request.
	$request_ref->{ json } - 0, no encode no decode, 1 encode request, 2 decode response, 3 encode and decode 
	$request_ref->{ headers } - Hash ref of headers
	$request_ref->{ data } - String of data when json is false, hash of data when json is true 
	$request_ref->{ socket } - Path to socket file.

Variable: $auth_ref.
	$auth_ref->{ realm } - Realm provided by the auth server
	$auth_ref->{ user } - user to auth
	$auth_ref->{ password } - password to auth

Variable: $error_ref.
	$error_ref->{ code } - Error code. 0 when successful.
	$error_ref->{ desc } - Error description.
	$error_ref->{ return } - $http_reponse_ref.

Variable: $http_response_ref.
	$http_response_ref->{ code } - http code
	$http_response_ref->{ body } - http response content. String if json is true, hash of data when json is true.
	$http_response_ref->{ headers } - Hash ref of response headers. 
	$http_response_ref->{ request } - $http_request_ref reported by the server. 

Variable: $http_request_ref.
	$http_request_ref->{ method } - method used in request
	$http_request_ref->{ url } - url used in request
	$http_request_ref->{ data } - data used in request
	$http_request_ref->{ headers } - Hash ref of headers used in request

=cut

sub runHTTPRequest    # ( $request_ref )
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $request_ref = shift;
	my $error_ref;
	my $url;

	$request_ref->{ method }    //= 'GET';
	$request_ref->{ protocol }  //= 'http';
	$request_ref->{ timeout }   //= 3;
	$request_ref->{ env_proxy } //= 0;
	$request_ref->{ path }      //= "/";
	$request_ref->{ agent }     //= "";
	$request_ref->{ json }      //= 0;

	$error_ref->{ code } = 1;
	if ( not $request_ref->{ host } )
	{
		my $msg = "Host not defined";
		$error_ref->{ code } = 2;
		$error_ref->{ desc } = $msg;
		return $error_ref;
	}

	require LWP::UserAgent;

	if ( $request_ref->{ socket } )
	{
		if ( not -S $request_ref->{ socket } )
		{
			my $msg = "Socket file '$request_ref->{ socket }' not found";
			$error_ref->{ code } = 5;
			$error_ref->{ desc } = $msg;
			return $error_ref;
		}
		if ( $request_ref->{ protocol } eq "https" )
		{
			my $msg = "Socket with HTTPS not implemented";
			$error_ref->{ code } = 4;
			$error_ref->{ desc } = $msg;
			return $error_ref;
		}
		else
		{
			require LWP::Protocol::http::SocketUnixAlt;
			LWP::Protocol::implementor( http => 'LWP::Protocol::http::SocketUnixAlt' );
		}
	}

	my $ua = LWP::UserAgent->new;

	$ua->agent( $request_ref->{ agent } );
	$ua->env_proxy if $request_ref->{ env_proxy };
	$ua->timeout( $request_ref->{ timeout } );
	if ( $request_ref->{ protocol } eq "https" )
	{
		$ua->ssl_opts( verify_hostname => 0, SSL_verify_mode => 0x00 );
	}
	if ( $request_ref->{ auth } )
	{
		if ( not $request_ref->{ port } )
		{
			$request_ref->{ port } = 80  if $request_ref->{ protocol } eq "http";
			$request_ref->{ port } = 443 if $request_ref->{ protocol } eq "https";
		}

		$ua->credentials(
						  "$request_ref->{ host }:$request_ref->{ port }",
						  $request_ref->{ auth }->{ realm },
						  $request_ref->{ auth }->{ user },
						  $request_ref->{ auth }->{ password }
		);
	}

	if ( $request_ref->{ headers } )
	{
		foreach my $request_header ( keys %{ $request_ref->{ headers } } )
		{
			$ua->default_header(
							$request_header => $request_ref->{ headers }->{ $request_header } );
		}
	}

	my $port;
	$port = ":$request_ref->{ port }" if $request_ref->{ port };
	if ( $request_ref->{ socket } )
	{
		$url =
		    $request_ref->{ protocol } . ":"
		  . $request_ref->{ socket } . "/"
		  . $request_ref->{ path };
	}
	else
	{

		$url =
		    $request_ref->{ protocol } . "://"
		  . $request_ref->{ host }
		  . $port
		  . $request_ref->{ path };

	}

	my $request = HTTP::Request->new( $request_ref->{ method } => "$url" );

	if ( $request_ref->{ json } == 1 or $request_ref->{ json } == 3 )
	{
		$request->content_type( 'application/json' );
	}

	if ( $request_ref->{ data } )
	{
		if ( $request_ref->{ json } == 1 or $request_ref->{ json } == 3 )

		{
			require JSON;
			eval { $request->content( JSON::encode_json( $request_ref->{ data } ) ); };
			if ( $@ )
			{
				my $msg = "Request Data is not in json format";
				$error_ref->{ code } = 2;
				$error_ref->{ desc } = $msg;
				return $error_ref;
			}
		}
		else
		{
			$request->content( $request_ref->{ data } );
		}
	}

	my $response = $ua->request( $request );

	$error_ref->{ return }->{ code } = $response->code;
	$error_ref->{ return }->{ body } = $response->content();

	$error_ref->{ return }->{ request }->{ method } = $response->request()->method;
	$error_ref->{ return }->{ request }->{ url } =
	  $response->request()->uri->as_string;
	$error_ref->{ return }->{ request }->{ data } = $response->request()->content();
	my @request_headers = $response->request()->headers()->header_field_names;
	foreach my $header ( @request_headers )
	{
		$error_ref->{ return }->{ request }->{ headers }->{ $header } =
		  $response->request()->headers()->header( $header );
	}

	my @response_headers = $response->headers()->header_field_names;
	foreach my $header ( @response_headers )
	{
		$error_ref->{ return }->{ headers }->{ $header } =
		  $response->headers()->header( $header );
	}

	if ( $request_ref->{ json } == 2 or $request_ref->{ json } == 3 )
	{
		require JSON;
		eval {
			$error_ref->{ return }->{ body } = JSON::decode_json( $response->content() );
		};
		if ( $@ )
		{
			my $msg = "Response body is not in json format";
			$error_ref->{ code } = 3;
			$error_ref->{ desc } = $msg;
			return $error_ref;
		}
	}

	if ( not $response->is_success )
	{
		my $msg = "Request is not succesful";
		$error_ref->{ code } = 1;
		$error_ref->{ desc } = $msg;
		return $error_ref;
	}

	$error_ref->{ code } = 0;
	return $error_ref;
}

1;

