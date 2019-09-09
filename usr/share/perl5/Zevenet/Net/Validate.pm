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
Function: checkport

	Check if a TCP port is open in a local or remote IP.

Parameters:
	host - IP address (or hostname?).
	port - TCP port number.

Returns:
	boolean - string "true" or "false".

See Also:
	<getRandomPort>
=cut

#check if a port in a ip is up
sub checkport    # ($host, $port)
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my ( $host, $port, $farmname ) = @_;

	# check local ports;
	if ( $host eq '127.0.0.1' || $host =~ /local/ )
	{
		my $flag = system ( "netstat -putan | grep $port >/dev/null 2>&1" );
		if ( !$flag )
		{
			return "true";
		}
	}

	# check remote ports
	else
	{
		# check if it used by a l4 farm
		require Zevenet::Farm::L4xNAT::Validate;
		return "true" if ( &checkL4Port( $host, $port, $farmname ) );

		require IO::Socket;
		my $sock = IO::Socket::INET->new(
										  PeerAddr => $host,
										  PeerPort => $port,
										  Proto    => 'tcp'
		);

		if ( $sock )
		{
			close ( $sock );
			return "true";
		}
		else
		{
			return "false";
		}
	}
	return "false";
}

=begin nd
Function: ipisok

	Check if a string has a valid IP address format.

Parameters:
	checkip - IP address string.
	version - 4 or 6 to validate IPv4 or IPv6 only. Optional.

Returns:
	boolean - string "true" or "false".
=cut

#check if a ip is ok structure
sub ipisok    # ($checkip, $version)
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $checkip = shift;
	my $version = shift;
	my $return  = "false";

	require Data::Validate::IP;
	Data::Validate::IP->import();

	if ( !$version || $version != 6 )
	{
		if ( is_ipv4( $checkip ) )
		{
			$return = "true";
		}
	}

	if ( !$version || $version != 4 )
	{
		if ( is_ipv6( $checkip ) )
		{
			$return = "true";
		}
	}

	return $return;
}

=begin nd
Function: ipversion

	IP version number of an input IP address

Parameters:
	ip - ip to get the version

Returns:
	scalar - 4 for ipv4, 6 for ipv6, 0 if unknown

=cut

#check if a ip is IPv4 or IPv6
sub ipversion    # ($checkip)
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $checkip = shift;
	my $output  = "-";

	require Data::Validate::IP;
	Data::Validate::IP->import();

	if ( is_ipv4( $checkip ) )
	{
		$output = 4;
	}
	elsif ( is_ipv6( $checkip ) )
	{
		$output = 6;
	}
	else
	{
		$output = 0;
	}

	return $output;
}

=begin nd
Function: getNetValidate

	Check if the network configuration is valid. This function receive two IP
	address and a net segment and check if both address are in the segment.
	It is usefull to check if the gateway is correct or to check a new IP
	for a interface

Parameters:
	ip - IP from net segment
	netmask - Net segment
	new_ip - IP to check if it is from net segment

Returns:
	Integer - 1 if the configuration is correct or 0 on incorrect

=cut

sub getNetValidate    # ($ip, $mask, $ip2)
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my ( $ip, $mask, $ip2 ) = @_;

	require NetAddr::IP;

	my $addr1 = NetAddr::IP->new( $ip,  $mask );
	my $addr2 = NetAddr::IP->new( $ip2, $mask );

	return (    defined $addr1
			 && defined $addr2
			 && ( $addr1->network() eq $addr2->network() ) ) ? 1 : 0;
}

=begin nd
Function: ifexist

	Check if interface exist.

	Look for link interfaces, Virtual interfaces return "false".
	If the interface is IFF_RUNNING or configuration file exists return "true".
	If interface found but not IFF_RUNNING nor configutaion file exists returns "created".

Parameters:
	nif - network interface name.

Returns:
	string - "true", "false" or "created".

Bugs:
	"created"
=cut

#function check if interface exist
sub ifexist    # ($nif)
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $nif = shift;

	use IO::Interface qw(:flags);    # Needs to load with 'use'

	require IO::Socket;
	require Zevenet::Net::Interface;

	my $s          = IO::Socket::INET->new( Proto => 'udp' );
	my @interfaces = &getInterfaceList();
	my $configdir  = &getGlobalConfiguration( 'configdir' );
	my $status;

	for my $if ( @interfaces )
	{
		next if $if ne $nif;

		my $flags = $s->if_flags( $if );

		if   ( $flags & IFF_RUNNING ) { $status = "up"; }
		else                          { $status = "down"; }

		if ( $status eq "up" || -e "$configdir/if_$nif\_conf" )
		{
			return "true";
		}

		return "created";
	}

	return "false";
}

=begin nd
Function: isValidPortNumber

	Check if the input is a valid port number.

Parameters:
	port - Port number.

Returns:
	boolean - "true" or "false".

See Also:
	snmp_functions.cgi, check_functions.cgi, zapi/v3/post.cgi, zapi/v3/put.cgi
=cut

sub isValidPortNumber    # ($port)
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $port = shift;
	my $valid;

	if ( $port >= 1 && $port <= 65535 )
	{
		$valid = 'true';
	}
	else
	{
		$valid = 'false';
	}

	return $valid;
}

=begin nd
Function: checkNetworkExists

	Check if a network exists in other interface

Parameters:
	ip - A ip in the network segment
	mask - mask of the network segment
	exception - This parameter is optional, if it is sent, that interface will not be checked.
		It is used to exclude the interface that is been changed

Returns:
	String - interface name where the checked network exists

	v3.2/interface/vlan, v3.2/interface/nic, v3.2/interface/bonding
=cut

sub checkNetworkExists
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my ( $net, $mask, $exception ) = @_;

	require Zevenet::Net::Interface;
	require NetAddr::IP;

	my $net1 = NetAddr::IP->new( $net, $mask );

	my @interfaces = &getInterfaceTypeList( 'nic' );
	push @interfaces, &getInterfaceTypeList( 'bond' );
	push @interfaces, &getInterfaceTypeList( 'vlan' );

	foreach my $if_ref ( @interfaces )
	{
		# if it is the same net pass
		next if defined $exception and $if_ref->{ name } eq $exception;
		next if !$if_ref->{ addr };

		# found
		my $net2 = NetAddr::IP->new( $if_ref->{ addr }, $if_ref->{ mask } );

		eval {
			if ( $net1->contains( $net2 ) or $net2->contains( $net1 ) )
			{
				return $if_ref->{ name };
			}
		};
	}

	return "";
}

sub validBackendStack
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my ( $be_aref, $ip ) = @_;
	my $ip_stack     = &ipversion( $ip );
	my $ipv_mismatch = 0;

	# check every backend ip version
	foreach my $be ( @{ $be_aref } )
	{
		my $current_stack = &ipversion( $be->{ ip } );
		$ipv_mismatch = $current_stack ne $ip_stack;
		last if $ipv_mismatch;
	}

	return ( !$ipv_mismatch );
}

1;
