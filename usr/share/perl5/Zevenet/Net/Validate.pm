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
use Zevenet::Core;

=begin nd
Function: getNetIpFormat

	It gets an IP and it retuns the same IP with the format that system uses for
	the binary choosed

Parameters:
	ip - String with the ipv6
	bin - It is the binary for the format

Returns:
	String - It is the IPv6 with the format of the binary parameter.

=cut

sub getNetIpFormat
{
	my $ip  = shift;
	my $bin = shift;

	require Net::IPv6Addr;
	my $x = Net::IPv6Addr->new( $ip );

	if ( $bin eq 'netstat' )
	{
		return $x->to_string_compressed();
	}
	else
	{
		&zenlog(
				 "The bin '$bin' is not recoignized. The ip '$ip' couldn't be converted",
				 "error", "networking" );
	}

	return $ip;
}

=begin nd
Function: getProtoTransport

	It returns the protocols of layer 4 that use a profile or another protocol.

Parameters:
	profile or protocol - This parameter accepts a load balancer profile (for l4
	it returns the default one when the farm is created): "http", "https", "l4xnat", "gslb";
	or another protocol: "tcp", "udp", "sctp", "amanda", "tftp", "netbios-ns",
	"snmp", "ftp", "irc", "pptp", "sane", "all", "sip" or "h323"

Returns:
	Array ref - It the list of transport protocols that use the passed protocol. The
		possible values are "udp", "tcp" or "sctp"
=cut

sub getProtoTransport
{
	&zenlog( __FILE__ . q{:} . __LINE__ . q{:} . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $profile = shift;

	my $proto = [];
	my $all = ["tcp", "udp", "sctp"];

	# profiles
	if ( $profile eq "gslb" )
	{
		$proto = ["tcp", "udp"];
	}
	elsif ( $profile eq "l4xnat" )
	{
		$proto = ["tcp"];    # default protocol when a l4xnat farm is created
	}

	# protocols
	elsif ( $profile =~ /^(?:tcp|udp|sctp)$/ )
	{
		$proto = [$profile];
	}

	# udp
	elsif ( $profile =~ /^(?:amanda|tftp|netbios-ns|snmp)$/ )
	{
		$proto = ["udp"];
	}

	# tcp
	elsif ( $profile =~ /^(?:ftp|irc|pptp|sane|https?)$/ )
	{
		$proto = ["tcp"];
	}

	# mix
	elsif ( $profile eq "all" )
	{
		$proto = $all;
	}
	elsif ( $profile eq "sip" )
	{
		$proto = ["tcp", "udp"];
	}
	elsif ( $profile eq "h323" )
	{
		$proto = ["tcp", "udp"];
	}
	else
	{
		&zenlog(
				 "The funct 'getProfileProto' does not understand the parameter '$profile'",
				 "error", "networking" );
	}

	return $proto;
}

=begin nd
Function: validatePortKernelSpace

	It checks if the IP, port and protocol are used in some l4xnat farm.
	This function does the following actions to validate that the protocol
	is not used:
	* Remove the incoming farmname from the farm list
	* Check only with l4xnat farms
	* Check with farms with up status
	* Check that farms contain the same VIP
	* There is not collision with multiport

Parameters:
	vip - virtual IP
	port - It accepts multiport string format
	proto - it is an array reference with the list of protocols to check in the port. The protocols can be 'sctp', 'udp', 'tcp' or 'all'
	farmname - It is the farm that is being modified, if this parameter is passed, the configuration of this farm is ignored to avoid checking with itself. This parameter is optional

Returns:
	Integer - It returns 1 if the incoming info is valid, or 0 if there is another farm with that networking information
=cut

sub validatePortKernelSpace
{
	&zenlog( __FILE__ . q{:} . __LINE__ . q{:} . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my ( $ip, $port, $proto, $farmname ) = @_;

	# get l4 farms
	require Zevenet::Farm::Base;
	require Zevenet::Arrays;
	my @farm_list = &getFarmListByVip( $ip );
	return 1 if not @farm_list;

	@farm_list = grep { not /^$farmname$/ } @farm_list if defined $farmname;
	return 1 if not @farm_list;

	# check intervals
	my $port_list = &getMultiporExpanded( $port );

	foreach my $farm ( @farm_list )
	{
		next if ( &getFarmType( $farm ) ne 'l4xnat' );
		next if ( &getFarmStatus( $farm ) ne 'up' );

		# check protocol collision
		my $f_proto = &getProtoTransport( &getL4FarmParam( 'proto', $farm ) );
		next if ( not &getArrayCollision( $proto, $f_proto ) );

		my $f_port = &getFarmVip( 'vipp', $farm );

		# check if farm is all ports
		if ( $port eq '*' or $f_port eq '*' )
		{
			&zenlog( "Port collision with farm '$farm' for using all ports",
					 "warning", "net" );
			return 0;
		}

		# check port collision
		my $f_port_list = &getMultiporExpanded( $f_port );
		my $col = &getArrayCollision( $f_port_list, $port_list );
		if ( defined $col )
		{
			&zenlog( "Port collision ($col) with farm '$farm'", "warning", "net" );
			return 0;
		}
	}

	return 1;
}

=begin nd
Function: getMultiporExpanded

	It returns the list of ports that a multiport string contains.

Parameters:
	port - multiport port

Returns:
	Array ref - It is the list of ports used by the farm
=cut

sub getMultiporExpanded
{
	&zenlog( __FILE__ . q{:} . __LINE__ . q{:} . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $port       = shift;
	my @total_port = ();
	if ( $port ne '*' )
	{
		foreach my $p ( split ( ',', $port ) )
		{
			my ( $init, $end ) = split ( ':', $p );
			if ( defined $end )
			{
				push @total_port, ( $init .. $end );
			}
			else
			{
				push @total_port, $init;
			}
		}
	}
	return \@total_port;
}

=begin nd
Function: getMultiportRegex

	It creates a regular expression to look for a list of ports.
	It expands the l4xnat port format (':' for ranges and ',' for listing ports).

Parameters:
	port - port or multiport

Returns:
	String - Regular expression
=cut

sub getMultiportRegex
{
	&zenlog( __FILE__ . q{:} . __LINE__ . q{:} . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $port = shift;
	my $reg  = $port;

	if ( $port eq '*' )
	{
		$reg = '\d+';
	}
	elsif ( $port =~ /[:,]/ )
	{
		my $total_port = &getMultiporExpanded( $port );
		$reg = '(?:' . join ( '|', @{ $total_port } ) . ')';
	}

	return $reg;
}

=begin nd
Function: validatePortUserSpace

	It validates if the port is being used for some process in the user space

Parameters:
	ip - IP address. If the IP is '0.0.0.0', it checks that other farm or process are not using the port
	port - TCP port number. It accepts l4xnat multport format: intervals (55:66,70), all ports (*).
	protocol - It is an array reference with the protocols to check ("udp", "tcp" and "sctp"), if some of them is used, the function returns 0.
	farmname - If the configuration is set in this farm, the check is ignored and true. This parameters is optional.
	process - It is the process name to ignore. It is used when a process wants to be modified with all IPs parameter. The services to ignore are: "cherokee", "sshd" and "snmp"

Returns:
	Integer - It returns '1' if the port and IP are valid to be used or '0' if the port and IP are already applied in the system

=cut

sub validatePortUserSpace
{
	&zenlog( __FILE__ . q{:} . __LINE__ . q{:} . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my ( $ip, $port, $proto, $farmname, $process ) = @_;

	my $override;

	# skip if the running farm is itself
	if ( defined $farmname )
	{
		require Zevenet::Farm::Base;

		my $type = &getFarmType( $farmname );
		if ( $type =~ /http|gslb/ )
		{
			my $cur_vip  = &getFarmVip( 'vip',  $farmname );
			my $cur_port = &getFarmVip( 'vipp', $farmname );

			if (     &getFarmStatus( $farmname ) eq 'up'
				 and $cur_vip eq $ip
				 and $cur_port eq $port )
			{
				&zenlog( "The networking configuration matches with the own farm",
						 "debug", "networking" );
				return 1;
			}
		}
		elsif ( $type eq "l4xnat" )
		{
			$override = 1;
		}
	}

	my $netstat = &getGlobalConfiguration( 'netstat_bin' );

	my $f_ipversion = ( &ipversion( $ip ) == 6 ) ? "6" : "4";
	$ip = &getNetIpFormat( $ip, 'netstat' ) if ( $f_ipversion eq '6' );

	my $f       = "lpnW";
	my $f_proto = "";

	foreach my $p ( @{ $proto } )
	{
		# it is not supported in the system
		if   ( $p eq 'sctp' ) { next; }
		else                  { $f_proto .= "--$p "; }
	}

	my $cmd = "$netstat -$f_ipversion -${f} ${f_proto} ";
	my @out = @{ &logAndGet( $cmd, 'array' ) };
	shift @out;
	shift @out;

	if ( defined $process )
	{
		my $filter = '^\s*(?:[^\s]+\s+){5,6}\d+\/' . $process;
		@out = grep { not /$filter/ } @out;
		return 1 if ( not @out );
	}

	# This code was modified for a bugfix. There was a issue when a l4 farm
	# is set and some management interface is set to use all the interfaces
	# my $ip_reg = ( $ip eq '0.0.0.0' ) ? '[^\s]+' : "(?:0.0.0.0|::1|$ip)";

	my $ip_reg;
	if ( defined $override and $override )
	{
		# L4xnat overrides the user space daemons that are listening on all interfaces
		$ip_reg = ( $ip eq '0.0.0.0' ) ? '[^\s]+' : "(?:$ip)";
	}
	else
	{
		# L4xnat farms does not override the user space daemons
		$ip_reg = ( $ip eq '0.0.0.0' ) ? '[^\s]+' : "(?:0.0.0.0|::1|$ip)";
	}

	my $port_reg = &getMultiportRegex( $port );

	my $filter = '^\s*(?:[^\s]+\s+){3,3}' . $ip_reg . ':' . $port_reg . '\s';
	@out = grep { /$filter/ } @out;
	if ( @out )
	{
		&zenlog( "The ip '$ip' and the port '$port' are being used for some process",
				 "warning", "networking" );
		return 0;
	}

	return 1;
}

=begin nd
Function: validatePort

	It checks if an IP and a port (checking the protocol) are already configured in the system.
	This is used to validate that more than one process or farm are not running with the same
	networking configuration.

	It checks the information with the "netstat" command, if the port is not found it will look for
	between the l4xnat farms (that are up).

	If this function is called with more than one protocol. It will recall itself recursively
	for each one.

Parameters:
	ip - IP address. If the IP is '0.0.0.0', it checks that other farm or process are not using the port
	port - TCP port number. It accepts l4xnat multport format: intervals (55:66,70), all ports (*).
	protocol - It is an array reference with the protocols to check, if some of them is used, the function returns 0. The accepted protocols are: 'all' (no one is checked), sctp, tcp and udp
	farmname - If the configuration is set in this farm, the check is ignored and true. This parameters is optional.
	process - It is the process name to ignore. It is used when a process wants to be modified with all IPs parameter. The services to ignore are: "cherokee", "sshd" and "snmp"

Returns:
	Integer - It returns '1' if the port and IP are valid to be used or '0' if the port and IP are already applied in the system

See Also:
	<getFarmProto> <getProfileProto>

=cut

sub validatePort
{
	&zenlog( __FILE__ . q{:} . __LINE__ . q{:} . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my ( $ip, $port, $proto, $farmname, $process ) = @_;

	# validate inputs
	$ip = '0.0.0.0' if $ip eq '*';
	if ( not defined $proto and not defined $farmname )
	{
		&zenlog(
			  "Check port needs the protocol to validate the ip '$ip' and the port '$port'",
			  "error", "networking" );
		return 0;
	}

	if ( not defined $proto )
	{
		$proto = &getFarmType( $farmname );
		if ( $proto eq 'l4xnat' )
		{
			require Zevenet::Farm::L4xNAT::Config;
			$proto = &getL4FarmParam( 'proto', $farmname );
		}
	}
	$proto = &getProtoTransport( $proto );

	return 0
	  if ( not &validatePortUserSpace( $ip, $port, $proto, $farmname, $process ) );

	return 0 if ( not &validatePortKernelSpace( $ip, $port, $proto, $farmname ) );

	# TODO: add check for avoiding collision with datalink VIPs

	return 1;
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

sub ipisok    # ($checkip, $version)
{
	&zenlog( __FILE__ . q{:} . __LINE__ . q{:} . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $checkip = shift;
	my $version = shift;
	my $return  = "false";

	require Data::Validate::IP;
	Data::Validate::IP->import();

	if ( not $version or $version != 6 )
	{
		if ( is_ipv4( $checkip ) )
		{
			$return = "true";
		}
	}

	if ( not $version or $version != 4 )
	{
		if ( is_ipv6( $checkip ) )
		{
			$return = "true";
		}
	}

	return $return;
}

=begin nd
Function: validIpAndNet

	Validate if the input is a valid IP or networking segement

Parameters:
	ip - IP address or IP network segment. ipv4 or ipv6

Returns:
	integer - 1 if the input is a valid IP or 0 if it is not valid

=cut

sub validIpAndNet
{
	my $ip = shift;

	use NetAddr::IP;
	my $out = NetAddr::IP->new( $ip );

	return ( defined $out ) ? 1 : 0;
}

=begin nd
Function: ipversion

	IP version number of an input IP address

Parameters:
	ip - ip to get the version

Returns:
	scalar - 4 for ipv4, 6 for ipv6, 0 if unknown

=cut

sub ipversion    # ($checkip)
{
	&zenlog( __FILE__ . q{:} . __LINE__ . q{:} . ( caller ( 0 ) )[3] . "( @_ )",
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
Function: validateGateway

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

sub validateGateway    # ($ip, $mask, $ip2)
{
	&zenlog( __FILE__ . q{:} . __LINE__ . q{:} . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my ( $ip, $mask, $ip2 ) = @_;

	require NetAddr::IP;

	my $addr1 = NetAddr::IP->new( $ip,  $mask );
	my $addr2 = NetAddr::IP->new( $ip2, $mask );

	return (     defined $addr1
			 and defined $addr2
			 and ( $addr1->network() eq $addr2->network() ) ) ? 1 : 0;
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

sub ifexist    # ($nif)
{
	&zenlog( __FILE__ . q{:} . __LINE__ . q{:} . ( caller ( 0 ) )[3] . "( @_ )",
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

		if ( $status eq "up" or -e "$configdir/if_$nif\_conf" )
		{
			return "true";
		}

		return "created";
	}

	return "false";
}

=begin nd
Function: checkNetworkExists

	Check if a network exists in other interface

Parameters:
	ip - A ip in the network segment
	mask - mask of the network segment
	exception - This parameter is optional, if it is sent, that interface will not be checked.
		It is used to exclude the interface that is been changed
	duplicateNetwork - This parameter is optional, if it is sent, defines duplicated network is enabled or disabled.

Returns:
	String - interface name where the checked network exists

	v3.2/interface/vlan, v3.2/interface/nic, v3.2/interface/bonding
=cut

sub checkNetworkExists
{
	&zenlog( __FILE__ . q{:} . __LINE__ . q{:} . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my ( $net, $mask, $exception, $duplicated ) = @_;

	#if duplicated network is allowed then don't check if network exists.
	if ( defined $duplicated )
	{
		return "" if $duplicated eq "true";
	}
	else
	{
		require Zevenet::Config;
		return "" if ( &getGlobalConfiguration( "duplicated_net" ) eq "true" );
	}

	require Zevenet::Net::Interface;
	require NetAddr::IP;

	my $net1 = NetAddr::IP->new( $net, $mask );
	my @interfaces;

	my @system_interfaces = &getInterfaceList();
	my $params = ["name", "addr", "mask"];
	foreach my $if_name ( @system_interfaces )
	{
		next if ( &getInterfaceType( $if_name ) !~ /^(?:nic|bond|vlan|gre)$/ );
		my $output_if = &getInterfaceConfigParam( $if_name, $params );
		$output_if = &getSystemInterface( $if_name ) if ( !$output_if );
		push ( @interfaces, $output_if );
	}

	my $found = 0;
	foreach my $if_ref ( @interfaces )
	{
		# if it is the same net pass
		next if defined $exception and $if_ref->{ name } eq $exception;
		next if not $if_ref->{ addr };

		# found
		my $net2 = NetAddr::IP->new( $if_ref->{ addr }, $if_ref->{ mask } );

		eval {
			if ( $net1->contains( $net2 ) or $net2->contains( $net1 ) )
			{
				$found = 1;
			}
		};
		return $if_ref->{ name } if ( $found );
	}

	return "";
}

=begin nd
Function: checkDuplicateNetworkExists

	Check if duplicate network exists in the interfaces

Parameters:

Returns:
	String - interface name where the checked network exists

	v3.2/interface/vlan, v3.2/interface/nic, v3.2/interface/bonding
=cut

sub checkDuplicateNetworkExists
{
	&zenlog( __FILE__ . q{:} . __LINE__ . q{:} . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );

	#if duplicated network is not allowed then don't check if network exists.
	require Zevenet::Config;
	return "" if ( &getGlobalConfiguration( "duplicated_net" ) eq "false" );

	require Zevenet::Net::Interface;
	require NetAddr::IP;

	my @interfaces = &getInterfaceTypeList( 'nic' );
	push @interfaces, &getInterfaceTypeList( 'bond' );
	push @interfaces, &getInterfaceTypeList( 'vlan' );

	foreach my $if_ref ( @interfaces )
	{
		my $iface = &checkNetworkExists(
										 $if_ref->{ addr },
										 $if_ref->{ mask },
										 $if_ref->{ name },
										 "false"
		);
		return $iface if ( $iface ne "" );
	}

	return "";
}

=begin nd
Function: validBackendStack

	Check if an IP is in the same networking segment that a list of backend

Parameters:
	backend_array - It is an array with the backend configuration
	ip - A ip is going to be compared with the backends IPs

Returns:
	Integer - Returns 1 if the ip is valid or 0 if it is not in the same networking segment

=cut

sub validBackendStack
{
	&zenlog( __FILE__ . q{:} . __LINE__ . q{:} . ( caller ( 0 ) )[3] . "( @_ )",
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

	return ( not $ipv_mismatch );
}

=begin nd
Function: validateNetmask

	It validates if a netmask is valid for IPv4 or IPv6

Parameters:
	netmask - Netmask to check
	ip_version - it is optionally, it accepts '4' or '6' for the ip versions.
		If no value is passed, it checks if the netmask is valid in some of the ip version

Returns:
	Integer - Returns 1 on success or 0 on failure

=cut

sub validateNetmask
{
	my $mask      = shift;
	my $ipversion = shift // 0;
	my $success   = 0;
	my $ip        = "127.0.0.1";

	if ( $ipversion == 0 or $ipversion == 6 )
	{
		return 1 if ( $mask =~ /^\d+$/ and $mask <= 64 );
	}
	if ( $ipversion == 0 or $ipversion == 4 )
	{
		if ( $mask =~ /^\d+$/ )
		{
			$success = 1 if $mask <= 32;
		}
		else
		{
			require Net::Netmask;
			my $block = Net::Netmask->new2( $ip, $mask );
			$success = 1 if defined $block;
		}
	}

	return $success;
}

1;
