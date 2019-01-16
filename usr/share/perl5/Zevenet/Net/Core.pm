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

my $ip_bin = &getGlobalConfiguration( 'ip_bin' );
my $eload;
if ( eval { require Zevenet::ELoad; } )
{
	$eload = 1;
}

=begin nd
Function: createIf

	Create VLAN network interface

Parameters:
	if_ref - Network interface hash reference.

Returns:
	integer - ip command return code.

See Also:
	zevenet, <setInterfaceUp>, zapi/v?/interface.cgi
=cut

# create network interface
sub createIf    # ($if_ref)
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $if_ref = shift;

	my $status = 0;

	if ( defined $$if_ref{ vlan } && $$if_ref{ vlan } ne '' )
	{
		&zenlog( "Creating vlan $$if_ref{name}", "info", "NETWORK" );

		my $ip_cmd =
		  "$ip_bin link add link $$if_ref{dev} name $$if_ref{name} type vlan id $$if_ref{vlan}";
		$status = &logAndRun( $ip_cmd );
	}

	return $status;
}

=begin nd
Function: upIf

	Bring up network interface in system and optionally in configuration file

Parameters:
	if_ref - network interface hash reference.
	writeconf - true value to apply change in interface configuration file. Optional.

Returns:
	integer - return code of ip command.

See Also:
	<downIf>
=cut

# up network interface
sub upIf    # ($if_ref, $writeconf)
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my ( $if_ref, $writeconf ) = @_;

	my $configdir = &getGlobalConfiguration( 'configdir' );
	my $status    = 0;
	$if_ref->{ status } = 'up';

	my $ip_cmd = "$ip_bin link set dev $$if_ref{name} up";

	$status = &logAndRun( $ip_cmd );

	# not check virtual interfaces
	if ( $if_ref->{ type } ne "virtual" )
	{
   #check if link is up after ip link up; checks /sys/class/net/$$if_ref{name}/operstate
		my $status_if = `cat /sys/class/net/$$if_ref{name}/operstate`;
		&zenlog( "Link status for $$if_ref{name} is $status_if", "info", "NETWORK" );
		&zenlog( "Waiting link up for $$if_ref{name}",           "info", "NETWORK" );
		my $iter = 6;

		while ( $status_if =~ /down/ && $iter > 0 )
		{
			$status_if = `cat /sys/class/net/$$if_ref{name}/operstate`;
			if ( $status_if !~ /down/ )
			{
				&zenlog( "Link up for $$if_ref{name}", "info", "NETWORK" );
				last;
			}
			$iter--;
			sleep 1;
		}

		if ( $iter == 0 )
		{
			$status = 1;
			&zenlog( "No link up for $$if_ref{name}", "warning", "NETWORK" );
			&downIf( { name => $if_ref->{ name } }, '' );
		}
	}

	if ( $writeconf )
	{
		my $file = "$configdir/if_$$if_ref{name}_conf";

		if ( -f $file )
		{
			require Tie::File;

			my $found = 0;
			tie my @if_lines, 'Tie::File', "$file";
			for my $line ( @if_lines )
			{
				if ( $line =~ /^status=/ )
				{
					$line  = "status=up";
					$found = 1;
					last;
				}
			}

			unshift ( @if_lines, 'status=up' ) if !$found;
			untie @if_lines;
		}
		else
		{
			open ( my $fh, '>', $file );
			print { $fh } "status=up\n";
			close $fh;
		}
	}

	return $status;
}

=begin nd
Function: downIf

	Bring down network interface in system and optionally in configuration file

Parameters:
	if_ref - network interface hash reference.

Returns:
	integer - return code of ip command.
	writeconf - true value to apply change in interface configuration file. Optional.

See Also:
	<upIf>, <stopIf>, zapi/v?/interface.cgi
=cut

# down network interface in system and configuration file
sub downIf    # ($if_ref, $writeconf)
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my ( $if_ref, $writeconf ) = @_;

	if ( ref $if_ref ne 'HASH' )
	{
		&zenlog( "Wrong argument putting down the interface", "error", "NETWORK" );
		return -1;
	}

	my $ip_cmd;

	# For Eth and Vlan
	if ( $$if_ref{ vini } eq '' )
	{
		$ip_cmd = "$ip_bin link set dev $$if_ref{name} down";
	}

	# For Vini
	else
	{
		my ( $routed_iface ) = split ( ":", $$if_ref{ name } );

		$ip_cmd = "$ip_bin addr del $$if_ref{addr}/$$if_ref{mask} dev $routed_iface";
	}

	my $status = &logAndRun( $ip_cmd );

	# Set down status in configuration file
	if ( $writeconf )
	{
		my $configdir = &getGlobalConfiguration( 'configdir' );
		my $file      = "$configdir/if_$$if_ref{name}_conf";

		require Tie::File;
		tie my @if_lines, 'Tie::File', "$file";

		for my $line ( @if_lines )
		{
			if ( $line =~ /^status=/ )
			{
				$line = "status=down";
				last;
			}
		}
		untie @if_lines;
	}

	return $status;
}

=begin nd
Function: stopIf

	Stop network interface, this removes the IP address instead of putting the interface down.

	This is an alternative to downIf which performs better in hardware
	appliances. Because if the interface is not brought down it wont take
	time to bring the interface back up and enable the link.

Parameters:
	if_ref - network interface hash reference.

Returns:
	integer - return code of ip command.

Bugs:
	Remove VLAN interface and bring it up.

See Also:
	<downIf>

	Only used in: zevenet
=cut

# stop network interface
sub stopIf    # ($if_ref)
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $if_ref = shift;

	&zenlog( "Stopping interface $$if_ref{ name }", "info", "NETWORK" );

	my $status = 0;
	my $if     = $$if_ref{ name };

	# If $if is Vini do nothing
	if ( !$$if_ref{ vini } )
	{
		# If $if is a Interface, delete that IP
		my $ip_cmd = "$ip_bin address flush dev $$if_ref{name}";
		$status = &logAndRun( $ip_cmd );

		# If $if is a Vlan, delete Vlan
		if ( $$if_ref{ vlan } ne '' )
		{
			$ip_cmd = "$ip_bin link delete $$if_ref{name} type vlan";
			$status = &logAndRun( $ip_cmd );
		}

		#ensure Link Up
		if ( $$if_ref{ status } eq 'up' )
		{
			$ip_cmd = "$ip_bin link set dev $$if_ref{name} up";
			$status = &logAndRun( $ip_cmd );
		}

		my $rttables = &getGlobalConfiguration( 'rttables' );

		# Delete routes table
		open my $rt_fd, '<', $rttables;
		my @contents = <$rt_fd>;
		close $rt_fd;

		@contents = grep !/^...\ttable_$if$/, @contents;

		open $rt_fd, '>', $rttables;
		print $rt_fd @contents;
		close $rt_fd;
	}

	#if virtual interface
	else
	{
		my @ifphysic = split ( /:/, $if );
		my $ip = $$if_ref{ addr };

		if ( $ip =~ /\./ )
		{
			use Net::IPv4Addr qw(ipv4_network);
			my ( $net, $mask ) = ipv4_network( "$ip / $$if_ref{mask}" );
			my $cmd = "$ip_bin addr del $ip/$mask brd + dev $ifphysic[0] label $if";

			system ( "$cmd >/dev/null 2>&1" );
			&zenlog( "failed: $cmd", "info", "NETWORK" ) if $?;
		}
	}

	return $status;
}

=begin nd
Function: delIf

	Remove system and stored settings and statistics of a network interface.

Parameters:
	if_ref - network interface hash reference.

Returns:
	integer - return code ofip command.

See Also:

=cut

# delete network interface configuration and from the system
sub delIf    # ($if_ref)
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my ( $if_ref ) = @_;

	my $status;
	my $configdir = &getGlobalConfiguration( 'configdir' );
	my $file      = "$configdir/if_$$if_ref{name}\_conf";
	my $has_more_ips;

	# remove stack line
	open ( my $in_fh,  '<', "$file" );
	open ( my $out_fh, '>', "$file.new" );

	if ( $in_fh && $out_fh )
	{
		while ( my $line = <$in_fh> )
		{
			if ( $line !~ /$$if_ref{addr}/ )
			{
				print $out_fh $line;
				$has_more_ips++ if $line =~ /;/;
			}
		}

		close $in_fh;
		close $out_fh;

		rename "$file.new", "$file";

		if ( !$has_more_ips )
		{
			# remove file only if not a nic interface
			# nics need to store status even if not configured, for vlans
			if ( $$if_ref{ name } ne $$if_ref{ dev } )
			{
				unlink ( $file ) or return 1;
			}
		}
	}
	else
	{
		&zenlog( "Error opening $file: $!", "info", "NETWORK" );
		$status = 1;
	}

	if ( $status )
	{
		return $status;
	}

	# If $if is Vini do nothing
	if ( $$if_ref{ vini } eq '' )
	{
		# If $if is a Interface, delete that IP
		my $ip_cmd =
		  "$ip_bin addr del $$if_ref{addr}/$$if_ref{mask} dev $$if_ref{name}";
		$status = &logAndRun( $ip_cmd );

		# If $if is a Vlan, delete Vlan
		if ( $$if_ref{ vlan } ne '' )
		{
			$ip_cmd = "$ip_bin link delete $$if_ref{name} type vlan";
			$status = &logAndRun( $ip_cmd );
		}

		# check if alternative stack is in use
		my $ip_v_to_check = ( $$if_ref{ ip_v } == 4 ) ? 6 : 4;
		my $interface = &getInterfaceConfig( $$if_ref{ name }, $ip_v_to_check );

		if ( !$interface )
		{
			my $rttables = &getGlobalConfiguration( 'rttables' );

			# Delete routes table, complementing writeRoutes()
			open my $rt_fd, '<', $rttables;
			my @contents = <$rt_fd>;
			close $rt_fd;

			@contents = grep !/^...\ttable_$$if_ref{name}$/, @contents;

			open $rt_fd, '>', $rttables;
			print $rt_fd @contents;
			close $rt_fd;
		}
	}

	# delete graphs
	require Zevenet::RRD;
	&delGraph( $$if_ref{ name }, "iface" );

	if ( $eload )
	{
		# delete alias
		&eload(
				module => 'Zevenet::Alias',
				func   => 'delAlias',
				args   => ['interface', $$if_ref{ name }]
		);

		#delete from RBAC
		&eload(
				module => 'Zevenet::RBAC::Group::Config',
				func   => 'delRBACResource',
				args   => [$$if_ref{ name }, 'interfaces'],
		);
	}

	return $status;
}

=begin nd
Function: delIp

	Deletes an IP address from an interface

Parameters:
	if - Name of interface.
	ip - IP address.
	netmask - Network mask.

Returns:
	integer - ip command return code.

See Also:
	<addIp>
=cut

# Execute command line to delete an IP from an interface
sub delIp    # 	($if, $ip ,$netmask)
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my ( $if, $ip, $netmask ) = @_;

	&zenlog( "Deleting ip $ip/$netmask from interface $if", "info", "NETWORK" );

	# Vini
	if ( $if =~ /\:/ )
	{
		( $if ) = split ( /\:/, $if );
	}

	my $ip_cmd = "$ip_bin addr del $ip/$netmask dev $if";
	my $status = &logAndRun( $ip_cmd );

	return $status;
}

=begin nd
Function: addIp

	Add an IPv4 to an Interface, Vlan or Vini

Parameters:
	if_ref - network interface hash reference.

Returns:
	integer - ip command return code.

See Also:
	<delIp>, <setIfacesUp>
=cut

# Execute command line to add an IPv4 to an Interface, Vlan or Vini
sub addIp    # ($if_ref)
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my ( $if_ref ) = @_;

	&zenlog( "Adding IP $$if_ref{addr}/$$if_ref{mask} to interface $$if_ref{name}",
			 "info", "NETWORK" );

	# finish if the address is already assigned
	my $routed_iface = $$if_ref{ dev };
	$routed_iface .= ".$$if_ref{vlan}"
	  if defined $$if_ref{ vlan } && $$if_ref{ vlan } ne '';

	my $extra_params = '';
	$extra_params = 'nodad' if $$if_ref{ ip_v } == 6;

	my @ip_output = `$ip_bin -$$if_ref{ip_v} addr show dev $routed_iface`;

	if ( $$if_ref{ addr } eq "" || $$if_ref{ addr } eq "" )
	{
		return 0;
	}

	if ( grep /$$if_ref{addr}\//, @ip_output )
	{
		return 0;
	}

	my $ip_cmd;

	my $broadcast_opt = ( $$if_ref{ ip_v } == 4 ) ? 'broadcast +' : '';

	# $if is a Virtual Network Interface
	if ( defined $$if_ref{ vini } && $$if_ref{ vini } ne '' )
	{
		my ( $toif ) = split ( ':', $$if_ref{ name } );

		$ip_cmd =
		  "$ip_bin addr add $$if_ref{addr}/$$if_ref{mask} $broadcast_opt dev $toif label $$if_ref{name} $extra_params";
	}

	# $if is a Vlan
	elsif ( defined $$if_ref{ vlan } && $$if_ref{ vlan } ne '' )
	{
		$ip_cmd =
		  "$ip_bin addr add $$if_ref{addr}/$$if_ref{mask} $broadcast_opt dev $$if_ref{name} $extra_params";
	}

	# $if is a Network Interface
	else
	{
		$ip_cmd =
		  "$ip_bin addr add $$if_ref{addr}/$$if_ref{mask} $broadcast_opt dev $$if_ref{name} $extra_params";
	}

	my $status = &logAndRun( $ip_cmd );

	return $status;
}

1;
