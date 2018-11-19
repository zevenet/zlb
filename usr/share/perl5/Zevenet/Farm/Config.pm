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

=begin nd
Function: setFarmBlacklistTime

	Configure check time for resurected back-end. It is a farm paramter.

Parameters:
	checktime - time for resurrected checks
	farmname - Farm name

Returns:
	Integer - Error code: 0 on success, or -1 on failure.

See Also:
	zapi/v3/put_http.cgi
	zapi/v2/put_http.cgi
	zapi/v2/put_tcp.cgi
=cut
sub setFarmBlacklistTime    # ($blacklist_time,$farm_name)
{
	my ( $blacklist_time, $farm_name ) = @_;

	my $farm_type = &getFarmType( $farm_name );
	my $output    = -1;

	if ( $farm_type eq "http" || $farm_type eq "https" )
	{
		require Zevenet::Farm::HTTP::Config;
		$output = &setHTTPFarmBlacklistTime( $blacklist_time, $farm_name );
	}

	return $output;
}

=begin nd
Function: getFarmBlacklistTime

	Return time for resurrected checks for a farm.

Parameters:
	farmname - Farm name

Returns:
	integer - seconds for check or -1 on failure.

See Also:
	zapi/v3/put_http.cgi
	zapi/v2/put_http.cgi
	zapi/v2/put_tcp.cgi
=cut
sub getFarmBlacklistTime    # ($farm_name)
{
	my ( $farm_name ) = @_;

	my $farm_type      = &getFarmType( $farm_name );
	my $blacklist_time = -1;

	if ( $farm_type eq "http" || $farm_type eq "https" )
	{
		require Zevenet::Farm::HTTP::Config;
		$blacklist_time = &getHTTPFarmBlacklistTime( $farm_name );
	}

	return $blacklist_time;
}

=begin nd
Function: setFarmSessionType

	Configure type of persistence

Parameters:
	session - type of session: nothing, HEADER, URL, COOKIE, PARAM, BASIC or IP, for HTTP farms; none or ip, for l4xnat farms
	farmname - Farm name

Returns:
	Integer - Error code: 0 on success, or -1 on failure.

See Also:
	zapi/v3/put_l4.cgi
	zapi/v2/put_l4.cgi
=cut
sub setFarmSessionType    # ($session,$farm_name)
{
	my ( $session, $farm_name ) = @_;

	my $farm_type = &getFarmType( $farm_name );
	my $output    = -1;

	if ( $farm_type eq "http" || $farm_type eq "https" )
	{
		require Zevenet::Farm::HTTP::Config;
		$output = &setHTTPFarmSessionType( $session, $farm_name );
	}
	elsif ( $farm_type eq "l4xnat" )
	{
		require Zevenet::Farm::L4xNAT::Config;
		$output = &setL4FarmSessionType( $session, $farm_name );
	}

	return $output;
}

=begin nd
Function: getFarmSessionType

	NOT USED. Return the type of session persistence for a farm.

Parameters:
	farmname - Farm name

Returns:
	scalar - type of persistence or -1 on failure.

Bugs:
	NOT USED
=cut
sub getFarmSessionType    # ($farm_name)
{
	my ( $farm_name ) = @_;

	my $farm_type = &getFarmType( $farm_name );
	my $output    = -1;

	if ( $farm_type eq "http" || $farm_type eq "https" )
	{
		require Zevenet::Farm::HTTP::Config;
		$output = &getHTTPFarmSessionType( $farm_name );
	}
	elsif ( $farm_type eq "l4xnat" )
	{
		require Zevenet::Farm::L4xNAT::Config;
		$output = &getL4FarmSessionType( $farm_name );
	}

	return $output;
}

=begin nd
Function: setFarmTimeout

	Asign a timeout value to a farm

Parameters:
	timeout - Time out in seconds
	farmname - Farm name

Returns:
	Integer - Error code: 0 on success, or -1 on failure.

See Also:
	zapi/v3/put_http.cgi
	zapi/v2/put_http.cgi
	zapi/v2/put_tcp.cgi
=cut
sub setFarmTimeout    # ($timeout,$farm_name)
{
	my ( $timeout, $farm_name ) = @_;

	my $farm_type = &getFarmType( $farm_name );
	my $output    = -1;

	&zenlog( "setting 'Timeout $timeout' for $farm_name farm $farm_type" );

	if ( $farm_type eq "http" || $farm_type eq "https" )
	{
		require Zevenet::Farm::HTTP::Config;
		$output = &setHTTPFarmTimeout( $timeout, $farm_name );
	}

	return $output;
}

=begin nd
Function: getFarmTimeout

	Return the farm time out

Parameters:
	farmname - Farm name

Returns:
	Integer - Return time out, or -1 on failure.

See Also:
	zapi/v3/get_http.cgi
	zapi/v2/get_http.cgi
	zapi/v2/get_tcp.cgi
=cut
sub getFarmTimeout    # ($farm_name)
{
	my ( $farm_name ) = @_;

	my $farm_type = &getFarmType( $farm_name );
	my $output    = -1;

	if ( $farm_type eq "http" || $farm_type eq "https" )
	{
		require Zevenet::Farm::HTTP::Config;
		$output = &getHTTPFarmTimeout( $farm_name );
	}

	return $output;
}

=begin nd
Function: setFarmAlgorithm

	Set the load balancing algorithm to a farm.

	Supports farm types: TCP, Datalink, L4xNAT.

Parameters:
	algorithm - Type of balancing mode
	farmname - Farm name

Returns:
	none - .

FIXME:
	set a return value, and do error control

See Also:
	zapi/v3/put_l4.cgi
	zapi/v3/put_datalink.cgi
	zapi/v2/put_l4.cgi
	zapi/v2/put_datalink.cgi
	zapi/v2/put_tcp.cgi
=cut
sub setFarmAlgorithm    # ($algorithm,$farm_name)
{
	my ( $algorithm, $farm_name ) = @_;

	my $farm_type = &getFarmType( $farm_name );
	my $output    = -1;

	&zenlog( "setting 'Algorithm $algorithm' for $farm_name farm $farm_type" );

	if ( $farm_type eq "datalink" )
	{
		require Zevenet::Farm::Datalink::Config;
		$output = &setDatalinkFarmAlgorithm( $algorithm, $farm_name );
	}
	elsif ( $farm_type eq "l4xnat" )
	{
		require Zevenet::Farm::L4xNAT::Config;
		$output = &setL4FarmAlgorithm( $algorithm, $farm_name );
	}

	return $output;
}

=begin nd
Function: getFarmAlgorithm

	Get type of balancing algorithm. 

	Supports farm types: Datalink, L4xNAT.

Parameters:
	farmname - Farm name

Returns:
	scalar - return a string with type of balancing algorithm or -1 on failure

See Also:
	<_runDatalinkFarmStart>
	<runL4FarmRestart>, <_runL4FarmRestart>, <sendL4ConfChange>
	l4sd

	zapi/v3/get_l4.cgi
	zapi/v3/get_datalink.cgi

	zapi/v2/get_l4.cgi
	zapi/v2/get_datalink.cgi
=cut
sub getFarmAlgorithm    # ($farm_name)
{
	my ( $farm_name ) = @_;

	my $farm_type = &getFarmType( $farm_name );
	my $algorithm = -1;

	if ( $farm_type eq "datalink" )
	{
		require Zevenet::Farm::Datalink::Config;
		$algorithm = &getDatalinkFarmAlgorithm( $farm_name );
	}
	elsif ( $farm_type eq "l4xnat" )
	{
		require Zevenet::Farm::L4xNAT::Config;
		$algorithm = &getL4FarmAlgorithm( $farm_name );
	}

	return $algorithm;
}

=begin nd
Function: setFarmPersistence

	Set client persistence to a farm

	Supports farm types: L4xNAT.

Parameters:
	persistence - Type of persitence
	farmname - Farm name

Returns:
	scalar - Error code: 0 on success or -1 on failure

BUG:
	Obsolete, only used in tcp farms
=cut
sub setFarmPersistence    # ($persistence,$farm_name)
{
	my ( $persistence, $farm_name ) = @_;

	my $farm_type = &getFarmType( $farm_name );
	my $output    = -1;

	if ( $farm_type eq "l4xnat" )
	{
		require Zevenet::Farm::L4xNAT::Config;
		$output = &setL4FarmPersistence( $persistence, $farm_name );
	}

	return $output;
}

=begin nd
Function: getFarmPersistence

	Get type of persistence session for a farm

Parameters:
	farmname - Farm name

Returns:
	Scalar - persistence type or -1 on failure

BUG
	DUPLICATED, use for l4 farms getFarmSessionType
	obsolete for tcp farms
=cut
sub getFarmPersistence    # ($farm_name)
{
	my ( $farm_name ) = @_;

	my $farm_type   = &getFarmType( $farm_name );
	my $persistence = -1;

	if ( $farm_type eq "l4xnat" )
	{
		require Zevenet::Farm::L4xNAT::Config;
		$persistence = &getL4FarmPersistence( $farm_name );
	}

	return $persistence;
}

=begin nd
Function: setFarmMaxClientTime

	Set the maximum time for a client

Parameters:
	maximumTO - Maximum client time
	farmname - Farm name

Returns:
	Integer - Error code: 0 on success, or -1 on failure.
=cut
sub setFarmMaxClientTime    # ($max_client_time,$track,$farm_name)
{
	my ( $max_client_time, $track, $farm_name ) = @_;

	my $farm_type = &getFarmType( $farm_name );
	my $output    = -1;

	&zenlog(
		"setting 'MaxClientTime $max_client_time $track' for $farm_name farm $farm_type"
	);

	if ( $farm_type eq "http" || $farm_type eq "https" )
	{
		require Zevenet::Farm::HTTP::Config;
		$output = &setHTTPFarmMaxClientTime( $track, $farm_name );
	}
	elsif ( $farm_type eq "l4xnat" )
	{
		require Zevenet::Farm::L4xNAT::Config;
		$output = &setL4FarmMaxClientTime( $track, $farm_name );
	}

	return $output;
}

=begin nd
Function: getFarmMaxClientTime

	Return the maximum time for a client

Parameters:
	farmname - Farm name

Returns:
	Integer - Return maximum time, or -1 on failure.
=cut
sub getFarmMaxClientTime    # ($farm_name)
{
	my ( $farm_name ) = @_;

	my $farm_type = &getFarmType( $farm_name );
	my @max_client_time;

	if ( $farm_type eq "http" || $farm_type eq "https" )
	{
		require Zevenet::Farm::HTTP::Config;
		@max_client_time = &getHTTPFarmMaxClientTime( $farm_name );
	}
	elsif ( $farm_type eq "l4xnat" )
	{
		require Zevenet::Farm::L4xNAT::Config;
		@max_client_time = &getL4FarmMaxClientTime( $farm_name );
	}

	return @max_client_time;
}

=begin nd
Function: setFarmMaxConn

	set the max conn of a farm

Parameters:
	maxiConns - Maximum number of allowed connections
	farmname - Farm name

Returns:
	Integer - always return 0

BUG:
	Not used in zapi v3. It is used "setFarmMaxClientTime"
=cut
sub setFarmMaxConn    # ($max_connections,$farm_name)
{
	my ( $max_connections, $farm_name ) = @_;

	my $farm_type     = &getFarmType( $farm_name );
	my $farm_filename = &getFarmFile( $farm_name );
	my $output        = -1;

	&zenlog( "setting 'MaxConn $max_connections' for $farm_name farm $farm_type" );

	if ( $farm_type eq "http" || $farm_type eq "https" )
	{
		require Zevenet::Farm::HTTP::Config;
		$output = &setHTTPFarmMaxConn( $max_connections, $farm_name );
	}

	return $output;
}

=begin nd
Function: getFarmMaxConn

	Returns farm max connections

Parameters:
	none - .

Returns:
	Integer - always return 0

BUG:
	It is only used in tcp, for http farms profile does nothing
=cut
sub getFarmMaxConn    # ($farm_name)
{
	my $farm_name = shift;

	my $farm_type = &getFarmType( $farm_name );
	my $output    = -1;

	if ( $farm_type eq "http" || $farm_type eq "https" )
	{
		require Zevenet::Farm::HTTP::Config;
		$output = &getHTTPFarmMaxConn( $farm_name );
	}

	return $output;
}

=begin nd
Function: setFarmVirtualConf

	Set farm virtual IP and virtual PORT		

Parameters:
	vip - virtual ip
	port - virtual port
	farmname - Farm name

Returns:
	Integer - return 0 on success or other value on failure

See Also:
	To get values use getFarmVip.
=cut
sub setFarmVirtualConf    # ($vip,$vip_port,$farm_name)
{
	my ( $vip, $vip_port, $farm_name ) = @_;

	my $farm_type = &getFarmType( $farm_name );
	my $stat      = -1;

	&zenlog(
			 "setting 'VirtualConf $vip $vip_port' for $farm_name farm $farm_type" );

	if ( $farm_type eq "http" || $farm_type eq "https" )
	{
		require Zevenet::Farm::HTTP::Config;
		$stat = &setHTTPFarmVirtualConf( $vip, $vip_port, $farm_name );
	}
	elsif ( $farm_type eq "datalink" )
	{
		require Zevenet::Farm::Datalink::Config;
		$stat = &setDatalinkFarmVirtualConf( $vip, $vip_port, $farm_name );
	}
	elsif ( $farm_type eq "l4xnat" )
	{
		require Zevenet::Farm::L4xNAT::Config;
		$stat = &setL4FarmVirtualConf( $vip, $vip_port, $farm_name );
	}
	elsif ( $farm_type eq "gslb" )
	{
		if ( eval { require Zevenet::Farm::GSLB::Config; } )
		{
			$stat = &setGSLBFarmVirtualConf( $vip, $vip_port, $farm_name );
		}
	}

	return $stat;
}

=begin nd
Function: getFarmConfigIsOK

	Function that check if the config file is OK.

Parameters:
	farmname - Farm name

Returns:
	scalar - return 0 on success or different on failure
=cut
sub getFarmConfigIsOK    # ($farm_name)
{
	my ( $farm_name ) = @_;

	my $farm_type = &getFarmType( $farm_name );
	my $output    = -1;

	if ( $farm_type eq "http" || $farm_type eq "https" )
	{
		require Zevenet::Farm::HTTP::Config;
		$output = &getHTTPFarmConfigIsOK( $farm_name );
	}
	elsif ( $farm_type eq "gslb" )
	{
		if ( eval { require Zevenet::Farm::GSLB::Validate; } )
		{
			$output = &getGSLBFarmConfigIsOK( $farm_name );
		}
	}

	return $output;
}

=begin nd
Function: checkFarmnameOK

	Checks the farmname has correct characters (number, letters and lowercases)

Parameters:
	farmname - Farm name

Returns:
	Integer - return 0 on success or -1 on failure

FIXME:
	Use check_function.cgi regexp instead.

	WARNING: Only used in HTTP function setFarmHTTPNewService.

NOTE:
	Generic function.
=cut
sub checkFarmnameOK    # ($farm_name)
{
	my $farm_name = shift;

	return ( $farm_name =~ /^[a-zA-Z0-9\-]+$/ )
	  ? 0
	  : -1;
}

=begin nd
Function: getFarmVS

	Return virtual server parameter

Parameters:
	farmname - Farm name
	service - Service name
	tag - Indicate which field will be returned

Returns:
	Integer - The requested parameter value
=cut
sub getFarmVS    # ($farm_name, $service, $tag)
{
	my ( $farm_name, $service, $tag ) = @_;

	my $output    = "";
	my $farm_type = &getFarmType( $farm_name );

	if ( $farm_type =~ /http/ )
	{
		require Zevenet::Farm::HTTP::Service;
		$output = &getHTTPFarmVS( $farm_name, $service, $tag );
	}
	elsif ( $farm_type eq "gslb" )
	{
		if ( eval { require Zevenet::Farm::GSLB::Service; } )
		{
			$output = &getGSLBFarmVS( $farm_name, $service, $tag );
		}
	}

	return $output;
}

=begin nd
Function: getFarmBackends

	Return a list with all backends

Parameters:
	farmname - Farm name
	service - Service name, required parameter to profiles: http and gslb)

Returns:
	Array ref - Each element in the array it is a hash ref to a backend.
=cut
sub getFarmBackends    # ($farm_name, $service)
{
	my ( $farm_name, $service ) = @_;

	my $output    = "";
	my $farm_type = &getFarmType( $farm_name );

	if ( $farm_type =~ /http/ )
	{
		require Zevenet::Farm::HTTP::Backend;
		$output = &getHTTPFarmBackends( $farm_name, $service );
	}
	elsif ( $farm_type eq "l4xnat" )
	{
		require Zevenet::Farm::L4xNAT::Backend;
		$output = &getL4FarmBackends( $farm_name );
	}
	elsif ( $farm_type eq "datalink" )
	{
		require Zevenet::Farm::Datalink::Backend;
		$output = &getDatalinkFarmBackends( $farm_name );
	}
	elsif ( $farm_type eq "gslb" )
	{
		if ( eval { require Zevenet::Farm::GSLB::Backend; } )
		{
			$output = &getGSLBFarmBackends( $farm_name, $service );
		}
	}

	return $output;
}

=begin nd
Function: setFarmVS

	Set values for service parameters

Parameters:
	farmname - Farm name
	service - Service name
	tag - Indicate which parameter modify
	string - value for the field "tag"

Returns:
	Integer - Error code: 0 on success or -1 on failure
=cut
sub setFarmVS    # ($farm_name,$service,$tag,$string)
{
	my ( $farm_name, $service, $tag, $string ) = @_;

	my $output    = "";
	my $farm_type = &getFarmType( $farm_name );

	if ( $farm_type =~ /http/ )
	{
		require Zevenet::Farm::HTTP::Service;
		$output = &setHTTPFarmVS( $farm_name, $service, $tag, $string );
	}
	elsif ( $farm_type eq "gslb" )
	{
		if ( eval { require Zevenet::Farm::GSLB::Service; } )
		{
			$output = &setGSLBFarmVS( $farm_name, $service, $tag, $string );
		}
	}

	return $output;
}

=begin nd
Function: setFarmName

	Set values for service parameters

Parameters:
	farmname - Farm name

Returns:
	none - .

Bugs:
	WARNING: This function is only used in zapi/v2/post.cgi, this substitution should be done without a function, so we can remove iŧ.
=cut
sub setFarmName    # ($farm_name)
{
	my $farm_name = shift;
	$farm_name =~ s/[^a-zA-Z0-9]//g;
}

=begin nd
Function: getServiceStruct

	Get a struct with all parameters of a service

Parameters:
	farmname - Farm name
	service - Farm name

Returns:
	hash ref - It is a struct with all information about a farm service

FIXME: 
	Complete with more farm profiles.
	Use it in zapi to get services from a farm
		
=cut
sub getServiceStruct
{
	my ( $farmname, $service ) = @_;

	my $output;
	my $farm_type = &getFarmType( $farmname );

	if ( $farm_type =~ /http/ )
	{
		require Zevenet::Farm::HTTP::Service;
		$output = &getHTTPServiceStruct( $farmname, $service );
	}
	else
	{
		$output = -1;
	}

	return $output;
}

1;
