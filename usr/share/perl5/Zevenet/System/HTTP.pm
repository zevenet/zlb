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
Function: getHttpServerPort

	Get the web GUI port.

Parameters:
	none - .

Returns:
	integer - Web GUI port.

See Also:
	zapi/v3/system.cgi
=cut
sub getHttpServerPort
{
	my $gui_port;    # output

	my $confhttp = &getGlobalConfiguration( 'confhttp' );
	open my $fh, "<", "$confhttp";

	# read line matching 'server!bind!1!port = <PORT>'
	my $config_item = 'server!bind!1!port';

	while ( my $line = <$fh> )
	{
		if ( $line =~ /$config_item/ )
		{
			( undef, $gui_port ) = split ( "=", $line );
			last;
		}
	}

	#~ my @httpdconffile = <$fr>;
	close $fh;

	chomp ( $gui_port );
	$gui_port =~ s/\s//g;
	$gui_port = 444 if ( !$gui_port );

	return $gui_port;
}

=begin nd
Function: setHttpServerPort

	Set the web GUI port.

Parameters:
	httpport - Port number.

Returns:
	none - .

See Also:
	zapi/v3/system.cgi
=cut
sub setHttpServerPort
{
	my ( $httpport ) = @_;

	require Tie::File;

	my $confhttp = &getGlobalConfiguration( 'confhttp' );
	$httpport =~ s/\ //g;

	tie my @array, 'Tie::File', "$confhttp";
	@array[2] = "server!bind!1!port = $httpport\n";
	untie @array;
}

=begin nd
Function: getHttpServerIp

	Get the GUI service ip address

Parameters:
	none - .

Returns:
	scalar - GUI ip address or '*' for all local addresses

See Also:
	zapi/v3/system.cgi, zevenet
=cut
sub getHttpServerIp
{
	my $gui_ip;        # output

	my $confhttp = &getGlobalConfiguration( 'confhttp' );
	open my $fh, "<", "$confhttp";

	# read line matching 'server!bind!1!interface = <IP>'
	my $config_item = 'server!bind!1!interface';

	while ( my $line = <$fh> )
	{
		if ( $line =~ /$config_item/ )
		{
			( undef, $gui_ip ) = split ( "=", $line );
			last;
		}
	}

	close $fh;

	chomp ( $gui_ip );
	$gui_ip =~ s/\s//g;

	require Zevenet::Net::Validate;

	if ( &ipisok( $gui_ip, 4 ) ne "true" )
	{
		$gui_ip = "*";
	}

	return $gui_ip;
}

=begin nd
Function: setHttpServerIp

	Set the GUI service ip address

Parameters:
	ip - IP address.

Returns:
	none - .

See Also:
	zapi/v3/system.cgi
=cut
sub setHttpServerIp
{
	my $ip = shift;

	require Tie::File;

	my $confhttp = &getGlobalConfiguration( 'confhttp' );

	#action save ip
	tie my @array, 'Tie::File', "$confhttp";

	if ( $ip =~ /^\*$/ )
	{
		@array[1] = "#server!bind!1!interface = \n";
		&zenlog( "The interface where is running is --All interfaces--" );
	}
	else
	{
		@array[1] = "server!bind!1!interface = $ip\n";

		#~ if ( &ipversion( $ipgui ) eq "IPv6" )
		#~ {
		#~ @array[4] = "server!ipv6 = 1\n";
		#~ &zenlog(
		#~ "The interface where is running the GUI service is: $ipgui with IPv6" );
		#~ }
		#~ elsif ( &ipversion( $ipgui ) eq "IPv4" )
		#~ {
		#~ @array[4] = "server!ipv6 = 0\n";
		#~ &zenlog(
		#~ "The interface where is running the GUI service is: $ipgui with IPv4" );
		#~ }
	}
	untie @array;
}

1;
