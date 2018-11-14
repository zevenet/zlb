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

sub validCGISession    # ()
{
	require Zevenet::CGI;
	require CGI::Session;

	my $q = &getCGI();
	my $validSession = 0;

	my $session      = CGI::Session->load( $q );

	#~ &zenlog( "CGI SESSION ID: " . Dumper $session );
	#~ &zenlog( "CGI SESSION ID: " . $session->id ) if $session->id;
	#~ &zenlog( "session data: " . Dumper $session->dataref() ); # DEBUG

	if ( $session && $session->param( 'is_logged_in' ) && !$session->is_expired )
	{
		# ignore cluster localhost status to reset session expiration date
		unless ( $q->path_info eq '/system/cluster/nodes/localhost' )
		{
			$session->expire( 'is_logged_in', '+30m' );
		}

		$validSession = 1;
	}

	return $validSession;
}

sub validZapiKey    # ()
{
	require Zevenet::Zapi;

	my $validKey = 0;    # output
	my $key = "HTTP_ZAPI_KEY";

	if (
		 exists $ENV{ $key }                         # zapi key was provided
		 && &getZAPI( "status" ) eq "true"           # zapi user is enabled
		 && &getZAPI( "keyzapi" ) eq $ENV{ $key }    # matches key
	  )
	{
		$validKey = 1;
	}

	return $validKey;
}

sub getAuthorizationCredentials                     # ()
{
	my $base64_digest;
	my $username;
	my $password;

	require MIME::Base64;
	MIME::Base64->import();

	if ( exists $ENV{ HTTP_AUTHORIZATION } )
	{
		# Expected header example: 'Authorization': 'Basic aHR0cHdhdGNoOmY='
		$ENV{ HTTP_AUTHORIZATION } =~ /^Basic (.+)$/;
		$base64_digest = $1;
	}

	if ( $base64_digest )
	{
		# $decoded_digest format: "username:password"
		my $decoded_digest = decode_base64( $base64_digest );
		chomp $decoded_digest;
		( $username, $password ) = split ( ":", $decoded_digest );
	}

	return undef if !$username or !$password;
	return ( $username, $password );
}

sub authenticateCredentials    #($user,$curpasswd)
{
	my ( $user, $pass ) = @_;

	return undef if !defined $user or !defined $pass;

	require Authen::Simple::Passwd;
	Authen::Simple::Passwd->import;

	#~ use Authen::Simple::PAM;

	my $valid_credentials = 0;    # output

	my $passfile = "/etc/shadow";
	my $simple = Authen::Simple::Passwd->new( path => "$passfile" );

	#~ my $simple   = Authen::Simple::PAM->new();

	if ( $simple->authenticate( $user, $pass ) )
	{
		$valid_credentials = 1;
	}

	return $valid_credentials;
}

1;
