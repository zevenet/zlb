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

#  POST /addvlan/<interface> Create a new vlan network interface
sub new_vlan    # ( $json_obj )
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $json_obj = shift;

	require Zevenet::Net::Util;
	require Zevenet::Net::Validate;

	my $desc = "Add a vlan interface";

	# validate VLAN NAME
	my $nic_re      = &getValidFormat( 'nic_interface' );
	my $vlan_tag_re = &getValidFormat( 'vlan_tag' );

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
	my $parent_exist = &ifexist( $json_obj->{ parent } );

	unless ( $parent_exist eq "true" || $parent_exist eq "created" )
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
		my $msg = "The vlan tag must be in the range 1-4094, both included";
		&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
	}

	# validate IP
	unless ( defined ( $json_obj->{ ip } )
			 && &getValidFormat( 'IPv4_addr', $json_obj->{ ip } ) )
	{
		my $msg = "IP Address is not valid.";
		&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
	}

	$json_obj->{ ip_v } = ipversion( $json_obj->{ ip } );

	# Check if interface already exists
	my $if_ref = &getInterfaceConfig( $json_obj->{ name }, $json_obj->{ ip_v } );

	if ( $if_ref )
	{
		my $msg = "Vlan network interface $json_obj->{ name } already exists.";
		&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
	}

	# FIXME: Check IPv6 compatibility
	# Check new IP address is not in use
	my @activeips = &listallips();

	for my $ip ( @activeips )
	{
		if ( $ip eq $json_obj->{ ip } )
		{
			my $msg = "IP Address $json_obj->{ip} is already in use.";
			&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
		}
	}

	# Check netmask errors
	if (
		 $json_obj->{ ip_v } == 4
		 && ( $json_obj->{ netmask } == undef
			  || !&getValidFormat( 'IPv4_mask', $json_obj->{ ip } ) )
	  )
	{
		my $msg = "Netmask parameter not valid";
		&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
	}

	## Check netmask errors for IPv6
#if ( $json_obj->{ ip_v } == 6 && ( $json_obj->{netmask} !~ /^\d+$/ || $json_obj->{netmask} > 128 || $json_obj->{netmask} < 0 ) )
#{
#	my $msg = "Netmask Address $json_obj->{netmask} structure is not ok. Must be numeric [0-128].";
#	&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
#}

	# Check gateway errors
	if ( exists $json_obj->{ gateway } )
	{
		unless ( defined ( $json_obj->{ gateway } )
				 && &getValidFormat( 'IPv4_mask', $json_obj->{ gateway } ) )
		{
			my $msg = "Invalid gateway address.";
			&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
		}
	}

	# setup parameters of vlan
	my $socket = IO::Socket::INET->new( Proto => 'udp' );

	$if_ref = {
				name    => $json_obj->{ name },
				dev     => $json_obj->{ parent },
				status  => "up",
				vlan    => $json_obj->{ tag },
				addr    => $json_obj->{ ip },
				mask    => $json_obj->{ netmask },
				gateway => $json_obj->{ gateway } // '',
				ip_v    => &ipversion( $json_obj->{ ip } ),
				mac     => $socket->if_hwaddr( $if_ref->{ dev } ),
	};

	if ( $if_ref->{ gateway } )
	{
		unless (
			&validateGateway( $if_ref->{ addr }, $if_ref->{ mask }, $if_ref->{ gateway } ) )
		{
			my $msg = "The gateway is not valid for the network.";
			&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
		}
	}

	require Zevenet::Net::Core;
	require Zevenet::Net::Route;
	require Zevenet::Net::Interface;

	eval {
		&zenlog( "new_vlan: $if_ref->{name}", "info", "NETWORK" );
		die if &createIf( $if_ref );
		&writeRoutes( $if_ref->{ name } );
		die if &addIp( $if_ref );

		my $state = &upIf( $if_ref, 'writeconf' );

		if ( $state == 0 )
		{
			$if_ref->{ status } = "up";
			&applyRoutes( "local", $if_ref );
		}

		&setInterfaceConfig( $if_ref ) or die;
	};

	if ( $@ )
	{
		my $msg = "The $json_obj->{ name } vlan network interface can't be created";
		&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
	}

	my $body = {
				 description => $desc,
				 params      => {
							 name    => $if_ref->{ name },
							 ip      => $if_ref->{ addr },
							 netmask => $if_ref->{ mask },
							 gateway => $if_ref->{ gateway },
							 mac     => $if_ref->{ mac },
				 },
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

	my @child = &getInterfaceChild( $vlan );
	if ( @child )
	{
		my $child_string = join ( ', ', @child );
		my $msg =
		  "Before of removing $vlan interface, delete de virtual interfaces: $child_string.";
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
		my $msg = "The VLAN interface $vlan can't be deleted";
		&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
	}

	my $message = "The VLAN interface $vlan has been deleted.";
	my $body = {
				 description => $desc,
				 success     => "true",
				 message     => $message,
	};

	&httpResponse( { code => 200, body => $body } );
}

sub get_vlan_list    # ()
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	require Zevenet::Net::Interface;

	my $desc = "List VLAN interfaces";
	my @output_list;

	# get cluster interface
	my $cluster_if;

	if ( $eload )
	{
		my $zcl_conf = &eload( module => 'Zevenet::Cluster',
							   func   => 'getZClusterConfig', );
		$cluster_if = $zcl_conf->{ _ }->{ interface };
	}

	for my $if_ref ( &getInterfaceTypeList( 'vlan' ) )
	{
		$if_ref->{ status } = &getInterfaceSystemStatus( $if_ref );

		# Any key must cotain a value or "" but can't be null
		if ( !defined $if_ref->{ name } )    { $if_ref->{ name }    = ""; }
		if ( !defined $if_ref->{ addr } )    { $if_ref->{ addr }    = ""; }
		if ( !defined $if_ref->{ mask } )    { $if_ref->{ mask }    = ""; }
		if ( !defined $if_ref->{ gateway } ) { $if_ref->{ gateway } = ""; }
		if ( !defined $if_ref->{ status } )  { $if_ref->{ status }  = ""; }
		if ( !defined $if_ref->{ mac } )     { $if_ref->{ mac }     = ""; }

		my $if_conf = {
						name    => $if_ref->{ name },
						ip      => $if_ref->{ addr },
						netmask => $if_ref->{ mask },
						gateway => $if_ref->{ gateway },
						status  => $if_ref->{ status },
						mac     => $if_ref->{ mac },
						parent  => $if_ref->{ parent },
		};

		$if_conf->{ is_cluster } = 'true'
		  if $cluster_if && $cluster_if eq $if_ref->{ name };

		push @output_list, $if_conf;
	}

	my $body = {
				 description => $desc,
				 interfaces  => \@output_list,
	};

	&httpResponse( { code => 200, body => $body } );
}

sub get_vlan    # ()
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $vlan = shift;

	require Zevenet::Net::Interface;

	my $desc = "Show VLAN interface $vlan";
	my $interface;

	for my $if_ref ( &getInterfaceTypeList( 'vlan' ) )
	{
		next unless $if_ref->{ name } eq $vlan;

		$if_ref->{ status } = &getInterfaceSystemStatus( $if_ref );

		# Any key must cotain a value or "" but can't be null
		if ( !defined $if_ref->{ name } )    { $if_ref->{ name }    = ""; }
		if ( !defined $if_ref->{ addr } )    { $if_ref->{ addr }    = ""; }
		if ( !defined $if_ref->{ mask } )    { $if_ref->{ mask }    = ""; }
		if ( !defined $if_ref->{ gateway } ) { $if_ref->{ gateway } = ""; }
		if ( !defined $if_ref->{ status } )  { $if_ref->{ status }  = ""; }
		if ( !defined $if_ref->{ mac } )     { $if_ref->{ mac }     = ""; }

		$interface = {
					   name    => $if_ref->{ name },
					   ip      => $if_ref->{ addr },
					   netmask => $if_ref->{ mask },
					   gateway => $if_ref->{ gateway },
					   status  => $if_ref->{ status },
					   mac     => $if_ref->{ mac },
		};
	}

	if ( not $interface )
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

	# validate VLAN
	unless ( grep { $vlan eq $_->{ name } } &getInterfaceTypeList( 'vlan' ) )
	{
		my $msg = "VLAN interface not found";
		&httpErrorResponse( code => 404, desc => $desc, msg => $msg );
	}

	# reject not accepted parameters
	if ( grep { $_ ne 'action' } keys %$json_obj )
	{
		my $msg = "Only the parameter 'action' is accepted";
		&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
	}

	# validate action parameter
	if ( $json_obj->{ action } eq "up" )
	{
		require Zevenet::Net::Validate;
		require Zevenet::Net::Route;
		require Zevenet::Net::Core;

		my $if_ref = &getInterfaceConfig( $vlan, $ip_v );

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
		require Zevenet::Net::Core;

		my $state = &downIf( { name => $vlan }, 'writeconf' );

		if ( $state )
		{
			my $msg = "The interface could not be set DOWN";
			&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
		}
	}
	else
	{
		my $msg = "Action accepted values are: up or down";
		&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
	}

	my $body = {
				 description => $desc,
				 params      => { action => $json_obj->{ action } },
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

	my $desc   = "Modify VLAN interface";
	my $ip_v   = 4;
	my $if_ref = &getInterfaceConfig( $vlan, $ip_v );

	# Check interface errors
	unless ( $if_ref )
	{
		my $msg = "VLAN not found";
		&httpErrorResponse( code => 404, desc => $desc, msg => $msg );
	}

	#not modify gateway or netmask if exists a virtual interface using this vlan
	if ( exists $json_obj->{ netmask } )
	{
		my @child = &getInterfaceChild( $vlan );
		if ( @child )
		{
			my $child_string = join ( ', ', @child );
			my $msg =
			  "It is not possible to modify $vlan because there are virtual interfaces using it: $child_string.";
			&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
		}
	}

	unless (    exists $json_obj->{ ip }
			 || exists $json_obj->{ netmask }
			 || exists $json_obj->{ gateway } )
	{
		my $msg = "No parameter received to be configured";
		&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
	}

	# Check address errors
	if ( exists $json_obj->{ ip } )
	{
		unless ( defined ( $json_obj->{ ip } )
				 && &getValidFormat( 'IPv4_addr', $json_obj->{ ip } ) )
		{
			my $msg = "IP Address $json_obj->{ip} structure is not ok.";
			&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
		}
	}

	# check if ip exists in other interface
	if ( $json_obj->{ ip } )
	{
		if ( $json_obj->{ ip } ne $if_ref->{ addr } )
		{
			require Zevenet::Net::Util;
			if ( grep ( /^$json_obj->{ ip }$/, &listallips() ) )
			{
				my $msg = "The IP address is already in use for other interface.";
				return &httpErrorResponse( code => 400, desc => $desc, msg => $msg );
			}
		}
	}

	# Check netmask errors
	if ( exists $json_obj->{ netmask } )
	{
		unless ( defined ( $json_obj->{ netmask } )
				 && &getValidFormat( 'IPv4_mask', $json_obj->{ netmask } ) )
		{
			my $msg =
			  "Netmask Address $json_obj->{netmask} structure is not ok. Must be IPv4 structure or numeric.";
			&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
		}
	}

	## Check netmask errors for IPv6
#if ( $ip_v == 6 && ( $json_obj->{netmask} !~ /^\d+$/ || $json_obj->{netmask} > 128 || $json_obj->{netmask} < 0 ) )
#{
#	my $msg = "Netmask Address $json_obj->{netmask} structure is not ok. Must be numeric.";
#	&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
#}

	# Check gateway errors
	if ( exists $json_obj->{ gateway } )
	{
		unless (
				 exists ( $json_obj->{ gateway } )
				 && (    $json_obj->{ gateway } eq ""
					  || &getValidFormat( 'IPv4_mask', $json_obj->{ gateway } ) )
		  )
		{
			my $msg = "Gateway Address $json_obj->{gateway} structure is not ok.";
			&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
		}
	}

	my $new_if = {
				   addr    => $json_obj->{ ip }      // $if_ref->{ addr },
				   mask    => $json_obj->{ netmask } // $if_ref->{ mask },
				   gateway => $json_obj->{ gateway } // $if_ref->{ gateway },
	};

	if ( $new_if->{ gateway } )
	{
		require Zevenet::Net::Validate;
		unless (
			&validateGateway( $new_if->{ addr }, $new_if->{ mask }, $new_if->{ gateway } ) )
		{
			my $msg = "The gateway is not valid for the network.";
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

	$if_ref->{ addr }    = $json_obj->{ ip }      if exists $json_obj->{ ip };
	$if_ref->{ mask }    = $json_obj->{ netmask } if exists $json_obj->{ netmask };
	$if_ref->{ gateway } = $json_obj->{ gateway } if exists $json_obj->{ gateway };

	eval {
		# Add new IP, netmask and gateway
		die if &addIp( $if_ref );
		die if &writeRoutes( $if_ref->{ name } );

		my $state = &upIf( $if_ref, 'writeconf' );

		if ( $state == 0 )
		{
			$if_ref->{ status } = "up";
			die if &applyRoutes( "local", $if_ref );
		}

		&setInterfaceConfig( $if_ref ) or die;

		# if the GW is changed, change it in all appending virtual interfaces
		if ( exists $json_obj->{ gateway } )
		{
			foreach my $appending ( &getInterfaceChild( $vlan ) )
			{
				my $app_config = &getInterfaceConfig( $appending );
				$app_config->{ gateway } = $json_obj->{ gateway };
				&setInterfaceConfig( $app_config );
			}
		}

		# put all dependant interfaces up
		require Zevenet::Net::Util;
		&setIfacesUp( $vlan, "vini" );
	};

	if ( $@ )
	{
		my $msg = "Errors found trying to modify interface $vlan";
		&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
	}

	my $body = {
				 description => $desc,
				 params      => $json_obj,
	};

	&httpResponse( { code => 200, body => $body } );
}

1;
