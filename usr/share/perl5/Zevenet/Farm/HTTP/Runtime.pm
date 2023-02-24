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

=begin nd
Function: getHTTPFarmBackendStatusSocket

	Get status of a HTTP farm and its backends when using zproxy.

Parameters:
	farmname - Farm name

Returns:
	hash  - return the outpout of a call to zproxy API

=cut

sub getHTTPFarmBackendStatusSocket    # ($farm_name)
{
	&zenlog( __FILE__ . q{:} . __LINE__ . q{:} . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my ( $farm_name ) = @_;
	my $status;

	require Zevenet::Farm::HTTP::Config;
	my $socket_file = &getHTTPFarmSocket( $farm_name );

	my $call = {
				 method   => "GET",
				 protocol => "http",
				 socket   => $socket_file,
				 host     => "localhost",
				 path     => "/listener/0/",
				 json     => 3,
	};
	require Zevenet::HTTPClient;
	my $resp = &runHTTPRequest( $call );

	if ( $resp->{ code } ne 0 )
	{
		&zenlog( "Error retrieving farm $farm_name status and its backend(s)",
				 "warning", "FARMS" );
		&zenlog(
				 "Error: "
				   . $resp->{ code }
				   . ", Desc: "
				   . $resp->{ desc }
				   . ", API Msg: "
				   . $resp->{ return }->{ body },
				 "warning",
				 "FARMS"
		);
	}
	else
	{
		$status = $resp->{ return }->{ body };
	}
	return $status;
}

=begin nd
Function: setHTTPFarmBackendStatusSocket

	Set status of a HTTP farm backends using zproxy control socket API.

Parameters:
	params_ref - Hash ref of params

Returns:
	error_ref - Hash ref with error code.

Variable: $params_ref

	A hashref that maps parameters to send.

	$params_ref->{ farm_name } - Farm name
	$params_ref->{ service } - Service name
	$params_ref->{ backend_id } - Backend Id
	$params_ref->{ socket_file } - Socket file path. Optional
	$params_ref->{ status } - Status to Set. Possible values "active, "disabled".

Variable: $error_ref

	A hashref that maps error code and description

	$error_ref->{ code } - Integer. Error code
	$error_ref->{ desc } - String. Description of the error.

=cut

sub setHTTPFarmBackendStatusSocket    # ($params_ref)
{
	&zenlog( __FILE__ . q{:} . __LINE__ . q{:} . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my ( $params_ref ) = @_;
	my $error_ref;

	if (
		 not defined $params_ref->{ status }
		 or (     $params_ref->{ status } ne "active"
			  and $params_ref->{ status } ne "disabled" )
	  )
	{
		$error_ref->{ code } = -1;
		$error_ref->{ desc } = "status param not valid";
	}

	my $socket_file;
	if ( not defined $params_ref->{ socket_file } )
	{
		require Zevenet::Farm::HTTP::Config;
		$socket_file = &getHTTPFarmSocket( $params_ref->{ farm_name } );
	}
	else
	{
		$socket_file = $params_ref->{ socket_file };
	}

	my $socket_request_params = {
								  method   => "PATCH",
								  data     => { "status" => $params_ref->{ status } },
								  protocol => "http",
								  socket   => $socket_file,
								  host     => "localhost",
								  path     => "/listener/0/service/"
									. $params_ref->{ service }
									. "/backend/"
									. $params_ref->{ backend_id }
									. "/status",
								  json => 3,
	};
	require Zevenet::HTTPClient;
	$error_ref = &runHTTPRequest( $socket_request_params );
	if ( $error_ref->{ code } ne 0 )
	{
		&zenlog(
			"Can not set status '$params_ref->{ status }' to Backend '$params_ref->{ backend_id }' in service '$params_ref->{ service }' on Farm '$params_ref->{ farm_name }': "
			  . $error_ref->{ desc },
			"debug", "LSLB"
		);
		$error_ref->{ code } = 1;
	}
	delete $error_ref->{ return } if defined $error_ref->{ return };
	return $error_ref;

}

1;
