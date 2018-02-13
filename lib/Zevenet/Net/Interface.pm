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

=begin nd
Variable: $if_ref

	Reference to a hash representation of a network interface.
	It can be found dereferenced and used as a (%iface or %interface) hash.

	$if_ref->{ name }     - Interface name.
	$if_ref->{ addr }     - IP address. Empty if not configured.
	$if_ref->{ mask }     - Network mask. Empty if not configured.
	$if_ref->{ gateway }  - Interface gateway. Empty if not configured.
	$if_ref->{ status }   - 'up' for enabled, or 'down' for disabled.
	$if_ref->{ ip_v }     - IP version, 4 or 6.
	$if_ref->{ dev }      - Name without VLAN or Virtual part (same as NIC or Bonding)
	$if_ref->{ vini }     - Part of the name corresponding to a Virtual interface. Can be empty.
	$if_ref->{ vlan }     - Part of the name corresponding to a VLAN interface. Can be empty.
	$if_ref->{ mac }      - Interface hardware address.
	$if_ref->{ type }     - Interface type: nic, bond, vlan, virtual.
	$if_ref->{ parent }   - Interface which this interface is based/depends on.
	$if_ref->{ float }    - Floating interface selected for this interface. For routing interfaces only.
	$if_ref->{ is_slave } - Whether the NIC interface is a member of a Bonding interface. For NIC interfaces only.

See also:
	<getInterfaceConfig>, <setInterfaceConfig>, <getSystemInterface>
=cut

=begin nd
Function: getInterfaceConfig

	Get a hash reference with the stored configuration of a network interface.

Parameters:
	if_name - Interface name.
	ip_version - Interface stack or IP version. 4 or 6 (Default: 4).

Returns:
	scalar - Reference to a network interface hash ($if_ref). undef if the network interface was not found.

Bugs:
	The configuration file exists but there isn't the requested stack.

See Also:
	<$if_ref>

	zcluster-manager, zenbui.pl, zapi/v?/interface.cgi, zcluster_functions.cgi, networking_functions_ext
=cut

sub getInterfaceConfig    # \%iface ($if_name, $ip_version)
{
	my ( $if_name, $ip_version ) = @_;

	my $if_line;
	my $if_status;
	my $configdir       = &getGlobalConfiguration( 'configdir' );
	my $config_filename = "$configdir/if_${if_name}_conf";

	$ip_version = 4 if !$ip_version;

	if ( open my $file, '<', "$config_filename" )
	{
		my @lines = grep { !/^(\s*#|$)/ } <$file>;

		for my $line ( @lines )
		{
			my ( undef, $ip ) = split ';', $line;
			my $line_ipversion;

			if ( defined $ip )
			{
				$line_ipversion =
				    ( $ip =~ /:/ )  ? 6
				  : ( $ip =~ /\./ ) ? 4
				  :                   undef;
			}

			if ( defined $line_ipversion && $ip_version == $line_ipversion && !$if_line )
			{
				$if_line = $line;
			}
			elsif ( $line =~ /^status=/ )
			{
				$if_status = $line;
				$if_status =~ s/^status=//;
				chomp $if_status;
			}
		}
		close $file;
	}

	# includes !$if_status to avoid warning
	if ( !$if_line && ( !$if_status || $if_status !~ /up/ ) )
	{
		return undef;
	}

	chomp ( $if_line );
	my @if_params = split ( ';', $if_line );

	# Example: eth0;10.0.0.5;255.255.255.0;up;10.0.0.1;

	require IO::Socket;
	my $socket = IO::Socket::INET->new( Proto => 'udp' );

	my %iface;

	$iface{ name }    = shift @if_params // $if_name;
	$iface{ addr }    = shift @if_params;
	$iface{ mask }    = shift @if_params;
	$iface{ gateway } = shift @if_params;                            # optional
	$iface{ status }  = $if_status;
	$iface{ ip_v }    = ( $iface{ addr } =~ /:/ ) ? '6' : '4';
	$iface{ dev }     = $if_name;
	$iface{ vini }    = undef;
	$iface{ vlan }    = undef;
	$iface{ mac }     = undef;
	$iface{ type }    = &getInterfaceType( $if_name );
	$iface{ parent }  = &getParentInterfaceName( $iface{ name } );

	if ( $iface{ dev } =~ /:/ )
	{
		( $iface{ dev }, $iface{ vini } ) = split ':', $iface{ dev };
	}

	if ( !$iface{ name } )
	{
		$iface{ name } = $if_name;
	}

	if ( $iface{ dev } =~ /./ )
	{
		# dot must be escaped
		( $iface{ dev }, $iface{ vlan } ) = split '\.', $iface{ dev };
	}

	$iface{ mac } = $socket->if_hwaddr( $iface{ dev } );

	# Interfaces without ip do not get HW addr via socket,
	# in those cases get the MAC from the OS.
	unless ( $iface{ mac } )
	{
		open my $fh, '<', "/sys/class/net/$if_name/address";
		chomp ( $iface{ mac } = <$fh> );
		close $fh;
	}

	# complex check to avoid warnings
	if (
		 (
		      !exists ( $iface{ vini } )
		   || !defined ( $iface{ vini } )
		   || $iface{ vini } eq ''
		 )
		 && $iface{ addr }
	  )
	{
		require Config::Tiny;
		my $float = Config::Tiny->read( &getGlobalConfiguration( 'floatfile' ) );

		$iface{ float } = $float->{ _ }->{ $iface{ name } } // '';
	}

	if ( $iface{ type } eq 'nic' && eval { require Zevenet::Net::Bonding; } )
	{
		$iface{ is_slave } =
		  ( grep { $iface{ name } eq $_ } &getAllBondsSlaves ) ? 'true' : 'false';
	}

	return \%iface;
}

=begin nd
Function: setInterfaceConfig

	Store a network interface configuration.

Parameters:
	if_ref - Reference to a network interface hash.

Returns:
	boolean - 1 on success, or 0 on failure.

See Also:
	<getInterfaceConfig>, <setInterfaceUp>, zevenet, zenbui.pl, zapi/v?/interface.cgi
=cut

# returns 1 if it was successful
# returns 0 if it wasn't successful
sub setInterfaceConfig    # $bool ($if_ref)
{
	my $if_ref = shift;

	if ( ref $if_ref ne 'HASH' )
	{
		&zenlog( "Input parameter is not a hash reference" );
		return undef;
	}

	&zenlog( "setInterfaceConfig: " . Dumper $if_ref) if &debug() > 2;
	my @if_params = ( 'name', 'addr', 'mask', 'gateway' );

	my $if_line         = join ( ';', @{ $if_ref }{ @if_params } ) . ';';
	my $configdir       = &getGlobalConfiguration( 'configdir' );
	my $config_filename = "$configdir/if_$$if_ref{ name }_conf";

	if ( $if_ref->{ addr } && !$if_ref->{ ip_v } )
	{
		$if_ref->{ ip_v } = &ipversion( $if_ref->{ addr } );
	}

	if ( !-f $config_filename )
	{
		open my $fh, '>', $config_filename;
		print $fh "status=up\n";
		close $fh;
	}

	# Example: eth0;10.0.0.5;255.255.255.0;up;10.0.0.1;
	require Tie::File;

	if ( tie my @file_lines, 'Tie::File', "$config_filename" )
	{
		require Zevenet::Net::Validate;
		my $ip_line_found;

		for my $line ( @file_lines )
		{
			# skip commented and empty lines
			if ( grep { /^(\s*#|$)/ } $line )
			{
				next;
			}

			my ( undef, $ip ) = split ';', $line;

			if ( $$if_ref{ ip_v } eq &ipversion( $ip ) && !$ip_line_found )
			{
				# replace line
				$line          = $if_line;
				$ip_line_found = 'true';
			}
			elsif ( $line =~ /^status=/ )
			{
				$line = "status=$$if_ref{status}";
			}
		}

		if ( !$ip_line_found )
		{
			push ( @file_lines, $if_line );
		}

		untie @file_lines;
	}
	else
	{
		&zenlog( "$config_filename: $!" );

		# returns zero on failure
		return 0;
	}

	# returns a true value on success
	return 1;
}

=begin nd
Function: getDevVlanVini

	Get a hash reference with the interface name divided into: dev, vlan, vini.

Parameters:
	if_name - Interface name.

Returns:
	Reference to a hash with:
	dev - NIC or Bonding part of the interface name.
	vlan - VLAN part of the interface name.
	vini - Virtual interface part of the interface name.

See Also:
	<getParentInterfaceName>, <getSystemInterfaceList>, <getSystemInterface>, zapi/v2/interface.cgi
=cut

sub getDevVlanVini    # ($if_name)
{
	my %if;
	$if{ dev } = shift;

	if ( $if{ dev } =~ /:/ )
	{
		( $if{ dev }, $if{ vini } ) = split ':', $if{ dev };
	}

	if ( $if{ dev } =~ /\./ )    # dot must be escaped
	{
		( $if{ dev }, $if{ vlan } ) = split '\.', $if{ dev };
	}

	return \%if;
}

=begin nd
Function: getConfigInterfaceList

	Get a reference to an array of all the interfaces saved in files.

Parameters:
	none - .

Returns:
	scalar - reference to array of configured interfaces.

See Also:
	zenloadbalanacer, zcluster-manager, <getIfacesFromIf>,
	<getActiveInterfaceList>, <getSystemInterfaceList>, <getFloatInterfaceForAddress>
=cut

sub getConfigInterfaceList
{
	my @configured_interfaces;
	my $configdir = &getGlobalConfiguration( 'configdir' );

	if ( opendir my $dir, "$configdir" )
	{
		for my $filename ( readdir $dir )
		{
			if ( $filename =~ /if_(.+)_conf/ )
			{
				my $if_name = $1;
				my $if_ref;

				$if_ref = &getInterfaceConfig( $if_name, 4 );
				if ( $$if_ref{ addr } )
				{
					push @configured_interfaces, $if_ref;
				}

				$if_ref = &getInterfaceConfig( $if_name, 6 );
				if ( $$if_ref{ addr } )
				{
					push @configured_interfaces, $if_ref;
				}
			}
		}

		closedir $dir;
	}
	else
	{
		&zenlog( "Error reading directory $configdir: $!" );
	}

	return \@configured_interfaces;
}

=begin nd
Function: getInterfaceSystemStatus

	Get the status of an network interface in the system.

Parameters:
	if_ref - Reference to a network interface hash.

Returns:
	scalar - 'up' or 'down'.

See Also:
	<getActiveInterfaceList>, <getSystemInterfaceList>, <getInterfaceTypeList>, zapi/v?/interface.cgi,
=cut

sub getInterfaceSystemStatus    # ($if_ref)
{
	my $if_ref = shift;

	my $parent_if_name = &getParentInterfaceName( $if_ref->{ name } );
	my $status_if_name = $if_ref->{ name };

	if ( $if_ref->{ vini } ne '' )    # vini
	{
		$status_if_name = $parent_if_name;
	}

	my $ip_bin    = &getGlobalConfiguration( 'ip_bin' );
	my $ip_output = `$ip_bin link show $status_if_name`;
	$ip_output =~ / state (\w+) /;
	my $if_status = lc $1;

	if ( $if_status !~ /^(?:up|down)$/ )    # if not up or down, ex: UNKNOWN
	{
		my ( $flags ) = $ip_output =~ /<(.+)>/;
		my @flags = split ( ',', $flags );

		if ( grep ( /^UP$/, @flags ) )
		{
			$if_status = 'up';
		}
		else
		{
			$if_status = 'down';
		}
	}

	# Set as down vinis not available
	$ip_output = `$ip_bin addr show $status_if_name`;

	if ( $ip_output !~ /$$if_ref{ addr }/ && $if_ref->{ vini } ne '' )
	{
		$$if_ref{ status } = 'down';
		return $$if_ref{ status };
	}

	unless ( $if_ref->{ vini } ne '' && $if_ref->{ status } eq 'down' )    # vini
	{
		$if_ref->{ status } = $if_status;
	}

	return $if_ref->{ status } if $if_ref->{ status } eq 'down';

	my $parent_if_ref = &getInterfaceConfig( $parent_if_name, $if_ref->{ ip_v } );

	# vlans do not require the parent interface to be configured
	if ( !$parent_if_name || !$parent_if_ref )
	{
		return $if_ref->{ status };
	}

	return &getInterfaceSystemStatus( $parent_if_ref );
}

=begin nd
Function: getParentInterfaceName

	Get the parent interface name.

Parameters:
	if_name - Interface name.

Returns:
	string - Parent interface name or undef if there is no parent interface (NIC and Bonding).

See Also:
	<getInterfaceConfig>, <getSystemInterface>, zevenet, zapi/v?/interface.cgi
=cut

sub getParentInterfaceName    # ($if_name)
{
	my $if_name = shift;

	my $if_ref = &getDevVlanVini( $if_name );
	my $parent_if_name;

	my $is_vlan    = defined $if_ref->{ vlan } && length $if_ref->{ vlan };
	my $is_virtual = defined $if_ref->{ vini } && length $if_ref->{ vini };

	# child interface: eth0.100:virtual => eth0.100
	if ( $is_virtual && $is_vlan )
	{
		$parent_if_name = "$$if_ref{dev}.$$if_ref{vlan}";
	}

	# child interface: eth0:virtual => eth0
	elsif ( $is_virtual && !$is_vlan )
	{
		$parent_if_name = $if_ref->{ dev };
	}

	# child interface: eth0.100 => eth0
	elsif ( !$is_virtual && $is_vlan )
	{
		$parent_if_name = $if_ref->{ dev };
	}

	# child interface: eth0 => undef
	elsif ( !$is_virtual && !$is_vlan )
	{
		$parent_if_name = undef;
	}

	return $parent_if_name;
}

=begin nd
Function: getActiveInterfaceList

	Get a reference to a list of all running (up) and configured network interfaces.

Parameters:
	none - .

Returns:
	scalar - reference to an array of network interface hashrefs.

See Also:
	Zapi v3: post.cgi, put.cgi, system.cgi
=cut

sub getActiveInterfaceList
{
	my @configured_interfaces = @{ &getConfigInterfaceList() };

	# sort list
	@configured_interfaces =
	  sort { $a->{ name } cmp $b->{ name } } @configured_interfaces;

	# apply device status heritage
	$_->{ status } = &getInterfaceSystemStatus( $_ ) for @configured_interfaces;

	# discard interfaces down
	@configured_interfaces = grep { $_->{ status } eq 'up' } @configured_interfaces;

	# find maximun lengths for padding
	my $max_dev_length;
	my $max_ip_length;

	for my $iface ( @configured_interfaces )
	{
		if ( $iface->{ status } == 'up' )
		{
			my $dev_length = length $iface->{ name };
			$max_dev_length = $dev_length if $dev_length > $max_dev_length;

			my $ip_length = length $iface->{ addr };
			$max_ip_length = $ip_length if $ip_length > $max_ip_length;
		}
	}

	# make padding
	for my $iface ( @configured_interfaces )
	{
		my $dev_ip_padded = sprintf ( "%-${max_dev_length}s -> %-${max_ip_length}s",
									  $$iface{ name }, $$iface{ addr } );
		$dev_ip_padded =~ s/ +$//;
		$dev_ip_padded =~ s/ /&nbsp;/g;

		$iface->{ dev_ip_padded } = $dev_ip_padded;
	}

	return \@configured_interfaces;
}

=begin nd
Function: getSystemInterfaceList

	Get a reference to a list with all the interfaces, configured and not configured.

Parameters:
	none - .

Returns:
	scalar - reference to an array with configured and system network interfaces.

See Also:
	zapi/v?/interface.cgi, zapi/v3/cluster.cgi
=cut

sub getSystemInterfaceList
{
	use IO::Interface qw(:flags);

	my @interfaces;    # output
	my @configured_interfaces = @{ &getConfigInterfaceList() };

	my $socket = IO::Socket::INET->new( Proto => 'udp' );
	my @system_interfaces = &getInterfaceList();

	## Build system device "tree"
	for my $if_name ( @system_interfaces )    # list of interface names
	{
		# ignore loopback device, ipv6 tunnel, vlans and vinis
		next if $if_name =~ /^lo$|^sit\d+$/;
		next if $if_name =~ /\./;
		next if $if_name =~ /:/;

		my %if_parts = %{ &getDevVlanVini( $if_name ) };

		my $if_ref;
		my $if_flags = $socket->if_flags( $if_name );

		# run for IPv4 and IPv6
		for my $ip_stack ( 4, 6 )
		{
			$if_ref = &getInterfaceConfig( $if_name, $ip_stack );

			if ( !$$if_ref{ addr } )
			{
				# populate not configured interface
				$$if_ref{ status } = ( $if_flags & IFF_UP ) ? "up" : "down";
				$$if_ref{ mac }    = $socket->if_hwaddr( $if_name );
				$$if_ref{ name }   = $if_name;
				$$if_ref{ addr }   = '';
				$$if_ref{ mask }   = '';
				$$if_ref{ dev }    = $if_parts{ dev };
				$$if_ref{ vlan }   = $if_parts{ vlan };
				$$if_ref{ vini }   = $if_parts{ vini };
				$$if_ref{ ip_v }   = $ip_stack;
				$$if_ref{ type }   = &getInterfaceType( $if_name );
			}

			if ( !( $if_flags & IFF_RUNNING ) && ( $if_flags & IFF_UP ) )
			{
				$$if_ref{ link } = "off";
			}

			# add interface to the list
			push ( @interfaces, $if_ref );

			# add vlans
			for my $vlan_if_conf ( @configured_interfaces )
			{
				next if $$vlan_if_conf{ dev } ne $$if_ref{ dev };
				next if $$vlan_if_conf{ vlan } eq '';
				next if $$vlan_if_conf{ vini } ne '';

				if ( $$vlan_if_conf{ ip_v } == $ip_stack )
				{
					push ( @interfaces, $vlan_if_conf );

					# add vini of vlan
					for my $vini_if_conf ( @configured_interfaces )
					{
						next if $$vini_if_conf{ dev } ne $$if_ref{ dev };
						next if $$vini_if_conf{ vlan } ne $$vlan_if_conf{ vlan };
						next if $$vini_if_conf{ vini } eq '';

						if ( $$vini_if_conf{ ip_v } == $ip_stack )
						{
							push ( @interfaces, $vini_if_conf );
						}
					}
				}
			}

			# add vini of nic
			for my $vini_if_conf ( @configured_interfaces )
			{
				next if $$vini_if_conf{ dev } ne $$if_ref{ dev };
				next if $$vini_if_conf{ vlan } ne '';
				next if $$vini_if_conf{ vini } eq '';

				if ( $$vini_if_conf{ ip_v } == $ip_stack )
				{
					push ( @interfaces, $vini_if_conf );
				}
			}
		}
	}

	@interfaces = sort { $a->{ name } cmp $b->{ name } } @interfaces;
	$_->{ status } = &getInterfaceSystemStatus( $_ ) for @interfaces;

	return \@interfaces;
}

=begin nd
Function: getSystemInterface

	Get a reference to a network interface hash from the system configuration, not the stored configuration.

Parameters:
	if_name - Interface name.

Returns:
	scalar - reference to a network interface hash as is on the system or undef if not found.

See Also:
	<getInterfaceConfig>, <setInterfaceConfig>
=cut

sub getSystemInterface    # ($if_name)
{
	my $if_ref = {};
	$$if_ref{ name } = shift;

	use IO::Interface qw(:flags);

	my %if_parts = %{ &getDevVlanVini( $$if_ref{ name } ) };
	my $socket   = IO::Socket::INET->new( Proto => 'udp' );
	my $if_flags = $socket->if_flags( $$if_ref{ name } );

	$$if_ref{ mac } = $socket->if_hwaddr( $$if_ref{ name } );

	return undef if not $$if_ref{ mac };
	$$if_ref{ status } = ( $if_flags & IFF_UP ) ? "up" : "down";
	$$if_ref{ addr }   = '';
	$$if_ref{ mask }   = '';
	$$if_ref{ dev }    = $if_parts{ dev };
	$$if_ref{ vlan }   = $if_parts{ vlan };
	$$if_ref{ vini }   = $if_parts{ vini };
	$$if_ref{ type }   = &getInterfaceType( $$if_ref{ name } );
	$$if_ref{ parent } = &getParentInterfaceName( $$if_ref{ name } );

	if ( $$if_ref{ type } eq 'nic' )
	{
		my @bond_slaves;

		if ( eval { require Zevenet::Net::Bonding; } )
		{
			@bond_slaves = &getAllBondsSlaves();
		}

		$$if_ref{ is_slave } =
		  ( grep { $$if_ref{ name } eq $_ } @bond_slaves ) ? 'true' : 'false';
	}

	return $if_ref;
}

=begin nd
Function: getInterfaceType

	Get the type of a network interface from its name using linux 'hints'.

	Original source code in bash:
	http://stackoverflow.com/questions/4475420/detect-network-connection-type-in-linux

	Translated to perl and adapted by Zevenet

	Interface types: nic, virtual, vlan, bond, dummy or lo.

Parameters:
	if_name - Interface name.

Returns:
	scalar - Interface type: nic, virtual, vlan, bond, dummy or lo.

See Also:
	
=cut

# Source in bash translated to perl:
# http://stackoverflow.com/questions/4475420/detect-network-connection-type-in-linux
#
# Interface types: nic, virtual, vlan, bond
sub getInterfaceType
{
	my $if_name = shift;

	my $type;

	return undef if $if_name eq '' || !defined $if_name;

	# interfaz for cluster when is in maintenance mode
	return 'dummy' if $if_name eq 'cl_maintenance';

	if ( !-d "/sys/class/net/$if_name" )
	{
		my ( $parent_if ) = split ( ':', $if_name );
		my $quoted_if     = quotemeta $if_name;
		my $ip_bin        = &getGlobalConfiguration( 'ip_bin' );
		my $found =
		  grep ( /inet .+ $quoted_if$/, `$ip_bin addr show $parent_if 2>/dev/null` );

		if ( !$found )
		{
			my $configdir = &getGlobalConfiguration( 'configdir' );
			$found = ( -f "$configdir/if_${if_name}_conf" && $if_name =~ /^.+\:.+$/ );
		}

		if ( $found )
		{
			return 'virtual';
		}
		else
		{
			return undef;
		}
	}

	my $code;    # read type code
	{
		my $if_type_filename = "/sys/class/net/$if_name/type";

		open ( my $type_file, '<', $if_type_filename )
		  or die "Could not open file $if_type_filename: $!";
		chomp ( $code = <$type_file> );
		close $type_file;
	}

	if ( $code == 1 )
	{
		$type = 'nic';

		# Ethernet, may also be wireless, ...
		if ( -f "/proc/net/vlan/$if_name" )
		{
			$type = 'vlan';
		}
		elsif ( -d "/sys/class/net/$if_name/bonding" )
		{
			$type = 'bond';
		}

#elsif ( -d "/sys/class/net/$if_name/wireless" || -l "/sys/class/net/$if_name/phy80211" )
#{
#	$type = 'wlan';
#}
#elsif ( -d "/sys/class/net/$if_name/bridge" )
#{
#	$type = 'bridge';
#}
#elsif ( -f "/sys/class/net/$if_name/tun_flags" )
#{
#	$type = 'tap';
#}
#elsif ( -d "/sys/devices/virtual/net/$if_name" )
#{
#	$type = 'dummy' if $if_name =~ /^dummy/;
#}
	}
	elsif ( $code == 24 )
	{
		$type = 'nic';    # firewire ;; # IEEE 1394 IPv4 - RFC 2734
	}
	elsif ( $code == 32 )
	{
		if ( -d "/sys/class/net/$if_name/bonding" )
		{
			$type = 'bond';
		}

		#elsif ( -d "/sys/class/net/$if_name/create_child" )
		#{
		#	$type = 'ib';
		#}
		#else
		#{
		#	$type = 'ibchild';
		#}
	}

	#elsif ( $code == 512 ) { $type = 'ppp'; }
	#elsif ( $code == 768 )
	#{
	#	$type = 'ipip';    # IPIP tunnel
	#}
	#elsif ( $code == 769 )
	#{
	#	$type = 'ip6tnl';    # IP6IP6 tunnel
	#}
	elsif ( $code == 772 ) { $type = 'lo'; }

	#elsif ( $code == 776 )
	#{
	#	$type = 'sit';       # sit0 device - IPv6-in-IPv4
	#}
	#elsif ( $code == 778 )
	#{
	#	$type = 'gre';       # GRE over IP
	#}
	#elsif ( $code == 783 )
	#{
	#	$type = 'irda';      # Linux-IrDA
	#}
	#elsif ( $code == 801 )   { $type = 'wlan_aux'; }
	#elsif ( $code == 65534 ) { $type = 'tun'; }

	# The following case statement still has to be replaced by something
	# which does not rely on the interface names.
	# case $if_name in
	# 	ippp*|isdn*) type=isdn;;
	# 	mip6mnha*)   type=mip6mnha;;
	# esac

	return $type if defined $type;

	my $msg = "Could not recognize the type of the interface $if_name.";

	&zenlog( $msg );
	die ( $msg );    # This should not happen
}

=begin nd
Function: getInterfaceTypeList

	Get a list of hashrefs with interfaces of a single type.

	Types supported are: nic, bond, vlan and virtual.

Parameters:
	list_type - Network interface type.

Returns:
	list - list of network interfaces hashrefs.

See Also:
	
=cut

sub getInterfaceTypeList
{
	my $list_type = shift;

	my @interfaces;

	if ( $list_type =~ /^(?:nic|bond|vlan)$/ )
	{
		my @system_interfaces = sort &getInterfaceList();

		for my $if_name ( @system_interfaces )
		{
			if ( $list_type eq &getInterfaceType( $if_name ) )
			{
				my $output_if = &getInterfaceConfig( $if_name );

				if ( !$output_if || !$output_if->{ mac } )
				{
					$output_if = &getSystemInterface( $if_name );
				}

				push ( @interfaces, $output_if );
			}
		}
	}
	elsif ( $list_type eq 'virtual' )
	{
		require Zevenet::Validate;

		opendir my $conf_dir, &getGlobalConfiguration( 'configdir' );
		my $virt_if_re = &getValidFormat( 'virt_interface' );

		for my $file_name ( sort readdir $conf_dir )
		{
			if ( $file_name =~ /^if_($virt_if_re)_conf$/ )
			{
				my $iface = &getInterfaceConfig( $1 );
				$iface->{ status } = &getInterfaceSystemStatus( $iface );
				push ( @interfaces, $iface );
			}
		}
	}
	else
	{
		my $msg = "Interface type '$list_type' is not supported.";
		&zenlog( $msg );
		die ( $msg );
	}

	return @interfaces;
}

=begin nd
Function: getAppendInterfaces

	Get vlans or virtual interfaces configured from a interface.
	If the interface is a nic or bonding, this function return the virtual interfaces
	create from the VLANs, for example: eth0.2:virt

Parameters:
	ifaceName - Interface name.
	type - Interface type: vlan or virtual.

Returns:
	scalar - reference to an array of interfaces names.

See Also:
	
=cut

# Get vlan or virtual interfaces appended from a interface
sub getAppendInterfaces    # ( $iface_name, $type )
{
	my ( $if_parent, $type ) = @_;
	my @output = ();

	my @list = &getInterfaceList();

	my $vlan_tag    = &getValidFormat( 'vlan_tag' );
	my $virtual_tag = &getValidFormat( 'virtual_tag' );

	foreach my $if ( @list )
	{
		if ( $type eq 'vlan' )
		{
			push @output, $if if ( $if =~ /^$if_parent\.$vlan_tag$/ );
		}

		if ( $type eq 'virtual' )
		{
			push @output, $if if ( $if =~ /^$if_parent(?:\.$vlan_tag)?\:$virtual_tag$/ );
		}
	}

	return \@output;
}

=begin nd
Function: getInterfaceList

	Return a list of all network interfaces detected in the system.

Parameters:
	None.

Returns:
	array - list of network interface names.
	array empty - if no network interface is detected.

See Also:
	<listActiveInterfaces>
=cut

sub getInterfaceList
{
	my @if_list = ();

	#Get link interfaces
	push @if_list, &getLinkNameList();

	#Get virtual interfaces
	push @if_list, &getVirtualInterfaceNameList();

	return @if_list;
}

=begin nd
Function: getVirtualInterfaceNameList

	Get a list of the virtual interfaces names.

Parameters:
	none - .

Returns:
	list - Every virtual interface name.
=cut

sub getVirtualInterfaceNameList
{
	require Zevenet::Validate;

	opendir ( my $conf_dir, &getGlobalConfiguration( 'configdir' ) );
	my $virt_if_re = &getValidFormat( 'virt_interface' );

	my @filenames = grep { s/^if_($virt_if_re)_conf$/$1/ } readdir ( $conf_dir );

	closedir ( $conf_dir );

	return @filenames;
}

=begin nd
Function: getLinkInterfaceNameList

	Get a list of the link interfaces names.

Parameters:
	none - .

Returns:
	list - Every link interface name.
=cut

sub getLinkNameList
{
	my $sys_net_dir = getGlobalConfiguration( 'sys_net_dir' );

	# Get link interfaces (nic, bond and vlan)
	opendir ( my $if_dir, $sys_net_dir );
	my @if_list = grep { -l "$sys_net_dir/$_" } readdir $if_dir;
	closedir $if_dir;

	return @if_list;
}

=begin nd
Function: getIpAddressExists

	Return if a IP exists in some configurated interface

Parameters:
	IP - IP address

Returns:
	Integer - 0 if it doesn't exist or 1 if the IP already exists

=cut

sub getIpAddressExists
{
	my $ip     = shift;
	my $output = 0;

	foreach my $if_ref ( @{ &getConfigInterfaceList() } )
	{
		if ( $if_ref->{ addr } = $ip )
		{
			$output = 1;
			last;
		}
	}

	return $output;
}

=begin nd
Function: getInterfaceChild

	Show the interfaces that depends directly of the interface.
	From a nic, bonding and VLANs interfaces depend the virtual interfaces.
	From a virtual interface depends the floating itnerfaces.

Parameters:
	ifaceName - Interface name.

Returns:
	scalar - Array of interfaces names.

FIXME: rename me, this function is used to check if the interface has some interfaces
 that depends of it. It is useful to avoid that corrupts the child interface

See Also:

=cut

sub getInterfaceChild
{
	my $if_name     = shift;
	my @output      = ();
	my $if_ref      = &getInterfaceConfig( $if_name );
	my $virtual_tag = &getValidFormat( 'virtual_tag' );

	# show floating interfaces used by this virtual interface
	if ( $if_ref->{ 'type' } eq 'virtual' )
	{
		require Config::Tiny;
		my $float = Config::Tiny->read( &getGlobalConfiguration( 'floatfile' ) );

		foreach my $iface ( keys %{ $float->{ _ } } )
		{
			push @output, $iface if ( $float->{ _ }->{ $iface } eq $if_name );
		}
	}

	# the other type of interfaces can have virtual interfaces as child
	# vlan, bond and nic
	else
	{
		push @output,
		  grep ( /^$if_name:$virtual_tag$/, &getVirtualInterfaceNameList() );
	}

	return @output;
}

1;
