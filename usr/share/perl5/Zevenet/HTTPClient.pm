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
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );

	# enable one:
	# return &execHTTRequestModule(@_);
	return &execHTTRequestCmd( @_ );
}

sub execHTTRequestModule
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $params = shift;

	require LWP::UserAgent;

	my $out->{ error } = 1;

	if ( !$params->{ url } )
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
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $params = shift;

	my $out->{ error } = 1;

	if ( !$params->{ url } )
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

	if ( !$out->{ error } )
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

1;

