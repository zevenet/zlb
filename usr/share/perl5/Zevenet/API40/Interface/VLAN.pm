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

my $eload;
if ( eval { require Zevenet::ELoad; } )
{
	$eload = 1;
}

#  POST /interfaces/vlan Create a new vlan network interface
sub new_vlan    # ( $json_obj )
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $json_obj = shift;

	require Zevenet::Net::Util;
	require Zevenet::Net::Validate;
	require Zevenet::Net::Interface;

	my $desc = "Add a vlan interface";

	# validate VLAN NAME
	my $nic_re      = &getValidFormat( 'nic_interface' );
	my $vlan_tag_re = &getValidFormat( 'vlan_tag' );

	my $params = &getZAPIModel( "vlan-create.json" );

	# Check allowed parameters
	my $error_msg = &checkZAPIParams( $json_obj, $params, $desc );
	return &httpErrorResponse( code => 400, desc => $desc, msg => $error_msg )
	  if ( $error_msg );

	my $dhcp_flag =
	  ( exists $json_obj->{ dhcp } and $json_obj->{ dhcp } ne "false" );
	my $ip_mand = ( exists $json_obj->{ ip } and exists $json_obj->{ netmask } );
	my $ip_opt = (
				        exists $json_obj->{ ip }
					 or exists $json_obj->{ netmask }
					 or exists $json_obj->{ gateway }
	);
	unless ( ( $dhcp_flag and !$ip_opt ) or ( !$dhcp_flag and $ip_mand ) )
	{
		my $msg =
		  "It is mandatory set an 'ip' and its 'netmask' or enabling the 'dhcp'. It is not allow to send 'ip', 'netmask' or 'gateway' when 'dhcp' is true.";
		&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
	}

	# Check if interface already exists
	my $if_ref = &getInterfaceConfig( $json_obj->{ name } );
	if ( $if_ref )
	{
		my $msg = "VLAN network interface $json_obj->{ name } already exists.";
		&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
	}

	# vlan_name = pather_name + . + vlan_tag
	# size < 16: size = pather_name.vlan_tag:virtual_name
	if ( length $json_obj->{ name } > 13 )
	{
		my $msg = "VLAN interface name has a maximum length of 13 characters";
		&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
	}

	if ( $json_obj->{ name } !~ /^($nic_re)\.($vlan_tag_re)$/ )
	{
		my $msg = "Interface name is not valid";
		&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
	}

	$json_obj->{ parent } = $1;
	$json_obj->{ tag }    = $2;

	# validate PARENT
	my $if_parent = &getInterfaceConfig( $json_obj->{ parent } );
	unless ( defined $if_parent )
	{
		my $msg = "The parent interface $json_obj->{ parent } doesn't exist";
		&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
	}

	# check that nic interface is no slave of a bonding
	my $is_slave;

	for my $if_ref ( &getInterfaceTypeList( 'nic' ) )
	{
		if ( $if_ref->{ name } eq $json_obj->{ parent } )
		{
			$is_slave = $if_ref->{ is_slave };
			last;
		}
	}

	if ( $is_slave eq 'true' )
	{
		my $msg = "It is not possible create a VLAN interface from a NIC slave.";
		&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
	}

	# validate VLAN TAG
	unless ( $json_obj->{ tag } >= 1 && $json_obj->{ tag } <= 4094 )
	{
		my $msg = "The VLAN tag must be in the range 1-4094, both included";
		&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
	}

	## Validates all creation parameters, now check the setting parameters

	# setup parameters of vlan
	my $socket = IO::Socket::INET->new( Proto => 'udp' );

	$if_ref = {
				name   => $json_obj->{ name },
				dev    => $json_obj->{ parent },
				status => $if_parent->{ status },
				vlan   => $json_obj->{ tag },
				dhcp   => $json_obj->{ dhcp } // 'false',
				mac    => $socket->if_hwaddr( $json_obj->{ parent } ),
	};
	$if_ref->{ mac } = lc $json_obj->{ mac }
	  if ( $eload && exists $json_obj->{ mac } );

	if ( exists $json_obj->{ ip } )
	{
		$json_obj->{ ip_v } = ipversion( $json_obj->{ ip } );

		if ( !&validateNetmask( $json_obj->{ netmask }, $json_obj->{ ip_v } ) )
		{
			my $msg = "The netmask is not valid";
			&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
		}

		# check if network exists in other interface
		if ( $json_obj->{ ip } or $json_obj->{ netmask } )
		{
			my $if_used = &checkNetworkExists( $json_obj->{ ip }, $json_obj->{ netmask } );
			if ( $if_used )
			{
				my $msg = "The network already exists in the interface $if_used.";
				&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
			}
		}

		$if_ref->{ addr }    = $json_obj->{ ip };
		$if_ref->{ mask }    = $json_obj->{ netmask };
		$if_ref->{ gateway } = $json_obj->{ gateway } // '';
		$if_ref->{ ip_v }    = &ipversion( $json_obj->{ ip } );
		$if_ref->{ net } =
		  &getAddressNetwork( $if_ref->{ addr }, $if_ref->{ mask }, $if_ref->{ ip_v } );

		# Make sure the address, mask and gateway belong to the same stack
		if ( $if_ref->{ addr } )
		{
			my $ip_v = &ipversion( $if_ref->{ addr } );
			my $gw_v = &ipversion( $if_ref->{ gateway } );

			my $mask_v =
			    ( $ip_v == 4 && &getValidFormat( 'IPv4_mask', $if_ref->{ mask } ) ) ? 4
			  : ( $ip_v == 6 && &getValidFormat( 'IPv6_mask', $if_ref->{ mask } ) ) ? 6
			  :                                                                       '';

			if ( $ip_v ne $mask_v
				 || ( $if_ref->{ gateway } && $ip_v ne $gw_v ) )
			{
				my $msg = "Invalid IP stack version match.";
				&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
			}
		}

		if ( $if_ref->{ gateway } )
		{
			unless (
				&validateGateway( $if_ref->{ addr }, $if_ref->{ mask }, $if_ref->{ gateway } ) )
			{
				my $msg = "Gateway does not belong to the interface subnet.";
				&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
			}
		}
	}

	# creating
	if ( &createVlan( $if_ref ) )
	{
		my $msg = "The $json_obj->{ name } vlan network interface can't be created";
		&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
	}

	# configuring
	if ( $dhcp_flag )
	{
		my $func = ( $json_obj->{ dhcp } eq 'true' ) ? "enableDHCP" : "disableDHCP";
		my $err = &eload(
						  module => 'Zevenet::Net::DHCP',
						  func   => $func,
						  args   => [$if_ref],
		);

		if ( $err )
		{
			my $msg = "The $json_obj->{ name } vlan network interface can't be configured";
			&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
		}
	}
	else
	{
		if ( &setVlan( $if_ref, $json_obj ) )
		{
			my $msg = "The $json_obj->{ name } vlan network interface can't be configured";
			&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
		}
	}

	my $body = {
				description => $desc,
				params      => &get_vlan_struct( $json_obj->{ name } ),
				message => "The $json_obj->{ name } VLAN has been created successfully."
	};

	&httpResponse( { code => 201, body => $body } );
}

sub delete_interface_vlan    # ( $vlan )
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $vlan = shift;

	my $desc = "Delete VLAN interface";
	my $ip_v = 4;

	require Zevenet::Net::Interface;

	my $if_ref = &getInterfaceConfig( $vlan, $ip_v );

	# validate VLAN interface
	if ( !$if_ref )
	{
		my $msg = "The VLAN interface $vlan doesn't exist.";
		&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
	}

	if ( $eload )
	{
		my $msg = &eload(
						  module => 'Zevenet::Net::Ext',
						  func   => 'isManagementIP',
						  args   => [$if_ref->{ addr }],
		);
		if ( $msg ne "" )
		{
			$msg = "The interface cannot be modified. $msg";
			return &httpErrorResponse( code => 400, desc => $desc, msg => $msg );
		}
		my $zcl_conf = &eload( module => 'Zevenet::Cluster',
							   func   => 'getZClusterConfig', );
		if ( defined $zcl_conf->{ _ }->{ track_interface } )
		{
			my @track_interface = split ( /\s/, $zcl_conf->{ _ }->{ track_interface } );
			if ( grep { $_ eq $if_ref->{ name } } @track_interface )
			{
				$msg =
				  "The interface $if_ref->{ name } cannot be modified because it is been tracked by the cluster.
						If you still want to modify it, remove it from the cluster track interface list.";
				return &httpErrorResponse( code => 400, desc => $desc, msg => $msg );
			}
		}
	}

	# check if some farm is using this ip
	require Zevenet::Farm::Base;
	my @farms = &getFarmListByVip( $if_ref->{ addr } );
	if ( @farms )
	{
		my $str = join ( ', ', @farms );
		my $msg = "This interface is being used as vip in the farm(s): $str.";
		return &httpErrorResponse( code => 400, desc => $desc, msg => $msg );
	}

	if ( $eload )
	{
		# check if some VPN is using this ip
		my $vpns = &eload(
						   module => 'Zevenet::VPN::Util',
						   func   => 'getVPNByIp',
						   args   => [$if_ref->{ addr }],
		);
		if ( @{ $vpns } )
		{
			my $str = join ( ', ', @{ $vpns } );
			my $msg = "This interface is being used as Local Gateway in VPN(s): $str";
			return &httpErrorResponse( code => 400, desc => $desc, msg => $msg );
		}
		$vpns = &eload(
						module => 'Zevenet::VPN::Util',
						func   => 'getVPNByNet',
						args   => [$if_ref->{ net }],
		);
		if ( @{ $vpns } )
		{
			my $str = join ( ', ', @{ $vpns } );
			my $msg = "This interface is being used as Local Network in VPN(s): $str";
			return &httpErrorResponse( code => 400, desc => $desc, msg => $msg );
		}

	}

	my @child = &getInterfaceChild( $vlan );
	if ( @child )
	{
		my $child_string = join ( ', ', @child );
		my $msg =
		  "Before removing $vlan interface, delete the virtual interfaces: $child_string.";
		&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
	}

	require Zevenet::Net::Core;
	require Zevenet::Net::Route;

	eval {
		die if &delRoutes( "local", $if_ref );
		die if &downIf( $if_ref, 'writeconf' );
		die if &delIf( $if_ref );
	};

	if ( $@ )
	{
		&zenlog( "Module failed: $@", "error", "net" );
		my $msg = "The VLAN interface $vlan can't be deleted";
		&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
	}

	my $message = "The VLAN interface $vlan has been deleted.";
	my $body = {
				 description => $desc,
				 message     => $message,
	};

	&httpResponse( { code => 200, body => $body } );
}

sub get_vlan_list    # ()
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	require Zevenet::Net::Interface;

	my $desc        = "List VLAN interfaces";
	my $output_list = &get_vlan_list_struct();

	my $body = {
				 description => $desc,
				 interfaces  => $output_list,
	};

	&httpResponse( { code => 200, body => $body } );
}

sub get_vlan    # ()
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $vlan = shift;

	require Zevenet::Net::Interface;

	my $desc      = "Show VLAN interface $vlan";
	my $interface = &get_vlan_struct( $vlan );

	unless ( $interface )
	{
		my $msg = "VLAN interface not found.";
		&httpErrorResponse( code => 404, desc => $desc, msg => $msg );
	}

	my $body = {
				 description => $desc,
				 interface   => $interface,
	};

	&httpResponse( { code => 200, body => $body } );
}

sub actions_interface_vlan    # ( $json_obj, $vlan )
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $json_obj = shift;
	my $vlan     = shift;

	require Zevenet::Net::Interface;

	my $desc = "Action on vlan interface";
	my $ip_v = 4;

	my $params = &getZAPIModel( "vlan-action.json" );

	# Check allowed parameters
	my $error_msg = &checkZAPIParams( $json_obj, $params, $desc );
	return &httpErrorResponse( code => 400, desc => $desc, msg => $error_msg )
	  if ( $error_msg );

	# validate VLAN
	unless ( grep { $vlan eq $_->{ name } } &getInterfaceTypeList( 'vlan' ) )
	{
		my $msg = "VLAN interface not found";
		&httpErrorResponse( code => 404, desc => $desc, msg => $msg );
	}

	my $if_ref = &getInterfaceConfig( $vlan, $ip_v );

	# validate action parameter
	if ( $json_obj->{ action } eq "up" )
	{
		require Zevenet::Net::Validate;
		require Zevenet::Net::Route;
		require Zevenet::Net::Core;

		# Create vlan if required if it doesn't exist
		my $exists = &ifexist( $if_ref->{ name } );
		if ( $exists eq "false" )
		{
			&createIf( $if_ref );
		}

		# Delete routes in case that it is not a vini
		&delRoutes( "local", $if_ref );

		# Add IP
		&addIp( $if_ref );

		# Check the parent's status before up the interface
		my $parent_if_name   = &getParentInterfaceName( $if_ref->{ name } );
		my $parent_if_status = 'up';

		if ( $parent_if_name )
		{
			my $parent_if_ref = &getSystemInterface( $parent_if_name );
			$parent_if_status = &getInterfaceSystemStatus( $parent_if_ref );
		}

		# validate PARENT INTERFACE STATUS
		unless ( $parent_if_status eq 'up' )
		{
			my $msg =
			  "The interface $if_ref->{name} has a parent interface DOWN, check the interfaces status";
			&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
		}

		my $state = &upIf( $if_ref, 'writeconf' );

		if ( !$state )
		{
			&applyRoutes( "local", $if_ref );

			# put all dependant interfaces up
			require Zevenet::Net::Util;
			&setIfacesUp( $if_ref->{ name }, "vini" );
		}
		else
		{
			my $msg = "The interface $if_ref->{ name } could not be set UP";
			&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
		}
	}
	elsif ( $json_obj->{ action } eq "down" )
	{
		if ( $eload )
		{
			my $msg = &eload(
							  module => 'Zevenet::Net::Ext',
							  func   => 'isManagementIP',
							  args   => [$if_ref->{ addr }],
			);
			if ( $msg ne "" )
			{
				$msg = "The interface cannot be stopped. $msg";
				return &httpErrorResponse( code => 400, desc => $desc, msg => $msg );
			}
			my $zcl_conf = &eload( module => 'Zevenet::Cluster',
								   func   => 'getZClusterConfig', );
			if ( defined $zcl_conf->{ _ }->{ track_interface } )
			{
				my @track_interface = split ( /\s/, $zcl_conf->{ _ }->{ track_interface } );
				if ( grep { $_ eq $if_ref->{ name } } @track_interface )
				{
					$msg =
					  "The interface $if_ref->{ name } cannot be modified because it is been tracked by the cluster.
							If you still want to modify it, remove it from the cluster track interface list.";
					return &httpErrorResponse( code => 400, desc => $desc, msg => $msg );
				}
			}
		}

		require Zevenet::Net::Core;
		my $state = &downIf( $if_ref, 'writeconf' );

		if ( $state )
		{
			my $msg = "The interface could not be set DOWN";
			&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
		}
	}

	my $body = {
				 description => $desc,
				 params      => { action => $json_obj->{ action } },
				 message     => "The $vlan VLAN is $json_obj->{ action }."
	};

	&httpResponse( { code => 200, body => $body } );
}

sub modify_interface_vlan    # ( $json_obj, $vlan )
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $json_obj = shift;
	my $vlan     = shift;

	require Zevenet::Net::Interface;
	require Zevenet::Net::Core;
	require Zevenet::Net::Validate;
	require NetAddr::IP;

	my $desc   = "Modify VLAN interface";
	my $if_ref = &getInterfaceConfig( $vlan );
	my $old_ip = $if_ref->{ addr };

	my @farms;
	my $vpns_localgw;
	@{ $vpns_localgw } = ();
	my $vpns_localnet;
	@{ $vpns_localnet } = ();
	my $warning_msg;

	# Check interface errors
	unless ( $if_ref )
	{
		my $msg = "VLAN interface not found";
		&httpErrorResponse( code => 404, desc => $desc, msg => $msg );
	}

	my $params = &getZAPIModel( "vlan-modify.json" );

	# Check allowed parameters
	my $error_msg = &checkZAPIParams( $json_obj, $params, $desc );
	return &httpErrorResponse( code => 400, desc => $desc, msg => $error_msg )
	  if ( $error_msg );

	my @child = &getInterfaceChild( $vlan );

	my $dhcp_status = $json_obj->{ dhcp } // $if_ref->{ dhcp };

	# only allow dhcp when no other parameter was sent
	if ( $dhcp_status eq 'true' )
	{
		if (    exists $json_obj->{ ip }
			 or exists $json_obj->{ netmask }
			 or exists $json_obj->{ gateway } )
		{
			my $msg =
			  "It is not possible set 'ip', 'netmask' or 'gateway' while 'dhcp' is enabled.";
			&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
		}
	}

	if ( !exists $json_obj->{ ip } and exists $json_obj->{ dhcp } and @child )
	{
		my $msg =
		  "This interface has appending some virtual interfaces, please, set up a new 'ip' in the current networking range.";
		&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
	}

	if (    exists $json_obj->{ ip }
		 or exists $json_obj->{ netmask }
		 or exists $json_obj->{ gateway } )
	{
		my $new_if = {
					   addr    => $json_obj->{ ip }      // $if_ref->{ addr },
					   mask    => $json_obj->{ netmask } // $if_ref->{ mask },
					   gateway => $json_obj->{ gateway } // $if_ref->{ gateway },
		};

		# Make sure the address, mask and gateway belong to the same stack
		if ( $new_if->{ addr } )
		{
			my $ip_v = &ipversion( $new_if->{ addr } );
			my $gw_v = &ipversion( $new_if->{ gateway } );

			if ( !&validateNetmask( $json_obj->{ netmask }, $ip_v ) )
			{
				my $msg = "The netmask is not valid";
				&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
			}

			if ( $new_if->{ gateway } && $ip_v ne $gw_v )
			{
				my $msg = "Invalid IP stack version match.";
				&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
			}
		}

		if ( exists $json_obj->{ ip } or exists $json_obj->{ netmask } )
		{
			# check ip and netmas are configured
			unless ( $new_if->{ addr } ne "" and $new_if->{ mask } ne "" )
			{
				my $msg =
				  "The networking configuration is not valid. It needs an IP ('$new_if->{addr}') and a netmask ('$new_if->{mask}')";
				&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
			}

	   # Do not modify gateway or netmask if exists a virtual interface using this interface
			my @wrong_conf;
			foreach my $child_name ( @child )
			{
				my $child_if = &getInterfaceConfig( $child_name );
				unless (
					 &validateGateway( $child_if->{ addr }, $new_if->{ mask }, $new_if->{ addr } ) )
				{
					push @wrong_conf, $child_name;
				}
			}

			if ( @wrong_conf )
			{
				my $child_string = join ( ', ', @wrong_conf );
				my $msg =
				  "The virtual interface(s): '$child_string' will not be compatible with the new configuration.";
				&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
			}
		}

		# check if network exists in other interface
		if ( $json_obj->{ ip } or $json_obj->{ netmask } )
		{
			my $if_used =
			  &checkNetworkExists( $new_if->{ addr }, $new_if->{ mask }, $vlan );
			if ( $if_used )
			{
				my $msg = "The network already exists in the interface $if_used.";
				&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
			}
		}

		# check the gateway is in network
		if ( $new_if->{ gateway } )
		{
			unless (
				&validateGateway( $new_if->{ addr }, $new_if->{ mask }, $new_if->{ gateway } ) )
			{
				my $msg = "The gateway is not valid for the network.";
				&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
			}
		}

		# Check new IP address is not in use
		if ( $json_obj->{ ip } and ( $new_if->{ addr } ne $if_ref->{ addr } ) )
		{
			require Zevenet::Net::Util;
			my @activeips = &listallips();
			for my $ip ( @activeips )
			{
				if ( $ip eq $json_obj->{ ip } )
				{
					my $msg = "IP address $json_obj->{ip} already in use.";
					&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
				}
			}
		}
	}

	if (    exists $json_obj->{ ip }
		 or ( exists $json_obj->{ dhcp } )
		 or ( exists $json_obj->{ netmask } ) )
	{
		if ( exists $json_obj->{ ip }
			 or ( exists $json_obj->{ dhcp } ) )
		{

			if ( $eload )
			{
				my $msg = &eload(
								  module => 'Zevenet::Net::Ext',
								  func   => 'isManagementIP',
								  args   => [$if_ref->{ addr }],
				);
				if ( $msg ne "" )
				{
					$msg = "The interface cannot be modified. $msg";
					return &httpErrorResponse( code => 400, desc => $desc, msg => $msg );
				}
			}

			# check if some farm is using this ip
			require Zevenet::Farm::Base;
			@farms = &getFarmListByVip( $if_ref->{ addr } );
			$vpns_localgw = &eload(
									module => 'Zevenet::VPN::Util',
									func   => 'getVPNByIp',
									args   => [$if_ref->{ addr }],
			) if $eload;
		}

		# check if its a new network and a vpn using old network
		if ( exists $json_obj->{ ip } or exists $json_obj->{ netmask } )
		{
			# check if network is changed
			my $mask = $json_obj->{ netmask } // $if_ref->{ mask };
			if (
				   !&validateGateway( $if_ref->{ addr }, $if_ref->{ mask }, $json_obj->{ ip } )
				 or $if_ref->{ mask } ne $mask )
			{
				my $net = new NetAddr::IP( $if_ref->{ addr }, $if_ref->{ mask } )->cidr();
				$vpns_localnet = &eload(
										 module => 'Zevenet::VPN::Util',
										 func   => 'getVPNByNet',
										 args   => [$net],
				) if $eload;
			}
		}

		if ( @farms or @{ $vpns_localgw } or @{ $vpns_localnet } )
		{
			if (    !exists $json_obj->{ ip }
				 and exists $json_obj->{ dhcp }
				 and $json_obj->{ dhcp } eq 'false' )
			{
				my $str_objects;
				my $str_function;
				if ( @farms )
				{
					$str_objects  = " and farms";
					$str_function = " and farm VIP";
				}
				if ( @{ $vpns_localgw } or @{ $vpns_localnet } )
				{
					$str_objects .= " and vpns";
				}
				if ( @{ $vpns_localgw } )
				{
					$str_function .= " and Local Gateway";
				}
				if ( @{ $vpns_localnet } )
				{
					$str_function .= " and Local Network";
				}
				$str_objects  = substr ( $str_objects,  5 );
				$str_function = substr ( $str_function, 5 );

				my $msg =
				  "This interface is been used by some $str_objects, please, set up a new 'ip' in order to be used as $str_function.";
				&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
			}
			if ( $json_obj->{ force } ne 'true' )
			{
				my $str_objects;
				my $str_function;
				if ( @farms )
				{
					$str_objects = " and farms";
					$str_function = " and as farm VIP in the farm(s): " . join ( ', ', @farms );
				}
				if ( @{ $vpns_localgw } or @{ $vpns_localnet } )
				{
					$str_objects .= " and vpns";
				}
				if ( @{ $vpns_localgw } )
				{
					$str_function .=
					  " and as Local Gateway in the VPN(s): " . join ( ', ', @{ $vpns_localgw } );
				}
				if ( @{ $vpns_localnet } )
				{
					$str_function .=
					  " and as Local Network in the VPN(s): " . join ( ', ', @{ $vpns_localnet } );
				}
				$str_objects  = substr ( $str_objects,  5 );
				$str_function = substr ( $str_function, 5 );

				my $msg =
				  "The IP is being used $str_function. If you are sure, repeat with parameter 'force'. All $str_objects using this interface will be restarted.";
				return &httpErrorResponse( code => 400, desc => $desc, msg => $msg );
			}
		}
	}

	if ( exists $json_obj->{ dhcp } )
	{
		my $func = ( $json_obj->{ dhcp } eq 'true' ) ? "enableDHCP" : "disableDHCP";
		my $err = &eload(
						  module => 'Zevenet::Net::DHCP',
						  func   => $func,
						  args   => [$if_ref],
		);

		if ( $err )
		{
			my $msg = "Errors found trying to enabling dhcp for the interface $vlan";
			&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
		}
	}

	# Delete old parameters
	if ( $if_ref )
	{
		require Zevenet::Net::Core;
		require Zevenet::Net::Route;

		# Delete old IP and Netmask from system to replace it
		&delIp( $$if_ref{ name }, $$if_ref{ addr }, $$if_ref{ mask } );

		# Remove routes if the interface has its own route table: nic and vlan
		&delRoutes( "local", $if_ref );
	}

	$if_ref->{ addr } = $json_obj->{ ip } if ( exists $json_obj->{ ip } );
	$if_ref->{ mac } = lc $json_obj->{ mac }
	  if ( $eload && exists $json_obj->{ mac } );
	$if_ref->{ mask }    = $json_obj->{ netmask } if exists $json_obj->{ netmask };
	$if_ref->{ gateway } = $json_obj->{ gateway } if exists $json_obj->{ gateway };
	$if_ref->{ ip_v } = &ipversion( $if_ref->{ addr } );
	$if_ref->{ net } =
	  &getAddressNetwork( $if_ref->{ addr }, $if_ref->{ mask }, $if_ref->{ ip_v } );

	if ( $eload )
	{
		&eload(
				module => 'Zevenet::Net::Routing',
				func   => 'updateRoutingVirtualIfaces',
				args   => [$if_ref->{ parent }, $old_ip],
		);
	}

	require Zevenet::Lock;
	my $vlan_config_file =
	  &getGlobalConfiguration( 'configdir' ) . "/if_$if_ref->{ name }_conf";
	my $dhcp_flag = $json_obj->{ dhcp } // $if_ref->{ dhcp };

	if ( ( $dhcp_flag ne 'true' ) and !( $if_ref->{ addr } && $if_ref->{ mask } ) )
	{
		my $msg = "Cannot configure the interface without address or without netmask.";
		&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
	}
	elsif ( $dhcp_flag eq "true" )
	{
		&lockResource( $vlan_config_file, "l" );
	}

	require Zevenet::Net::Interface;
	if ( &setVlan( $if_ref, $json_obj ) )
	{
		#Release lock file
		&lockResource( $vlan_config_file, "ud" ) if ( $dhcp_flag eq "true" );

		my $msg = "Errors found trying to modify interface $vlan";
		&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
	}

	#Release lock file
	&lockResource( $vlan_config_file, "ud" ) if ( $dhcp_flag eq "true" );

	if ( @farms )
	{
		require Zevenet::Farm::Config;
		&setAllFarmByVip( $json_obj->{ ip }, \@farms );
		&reloadFarmsSourceAddress();
	}

	if ( @{ $vpns_localgw } )
	{
		my $error = &eload(
							module => 'Zevenet::VPN::Config',
							func   => 'setAllVPNLocalGateway',
							args   => [$json_obj->{ ip }, $vpns_localgw],
		);
		$warning_msg .= $error->{ desc } if ( $error->{ code } );
	}
	if ( @{ $vpns_localnet } )
	{
		my $net = new NetAddr::IP( $if_ref->{ net }, $if_ref->{ mask } )->cidr();
		my $error = &eload(
							module => 'Zevenet::VPN::Config',
							func   => 'setAllVPNLocalNetwork',
							args   => [$net, $vpns_localnet],
		);
		$warning_msg .= $error->{ desc } if ( $error->{ code } );
	}

	my $if_out = &get_vlan_struct( $vlan );
	my $body = {
				 description => $desc,
				 params      => $if_out,
				 message     => "The $vlan VLAN has been updated successfully"
	};
	$body->{ warning } = $warning_msg if ( $warning_msg );

	&httpResponse( { code => 200, body => $body } );
}

1;
