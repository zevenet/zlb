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

sub delete_interface_nic    # ( $nic )
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $nic = shift;

	require Zevenet::Net::Core;
	require Zevenet::Net::Route;
	require Zevenet::Net::Interface;

	my $desc   = "Delete nic interface";
	my $ip_v   = 4;
	my $if_ref = &getInterfaceConfig( $nic, $ip_v );

	if ( !$if_ref )
	{
		my $msg = "There is no configuration for the network interface.";
		&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
	}

	# not delete the interface if it has some vlan configured
	my @child = &getInterfaceChild( $nic );
	if ( @child )
	{
		my $child_string = join ( ', ', @child );
		my $msg =
		  "It is not possible to delete $nic because there are virtual interfaces using it: $child_string.";
		&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
	}

	eval {
		die if &delRoutes( "local", $if_ref );
		die if &delIf( $if_ref );
	};

	if ( $@ )
	{
		my $msg = "The configuration for the network interface $nic can't be deleted.";
		&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
	}

	my $message =
	  "The configuration for the network interface $nic has been deleted.";
	my $body = {
				 description => $desc,
				 success     => "true",
				 message     => $message,
	};

	&httpResponse( { code => 200, body => $body } );
}

# GET /interfaces Get params of the interfaces
sub get_nic_list    # ()
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	require Zevenet::Net::Interface;

	my $desc  = "List NIC interfaces";
	my @vlans = &getInterfaceTypeList( 'vlan' );
	my @output_list;

	# get cluster interface
	my $cluster_if;

	if ( $eload )
	{
		my $zcl_conf = &eload( module => 'Zevenet::Cluster',
							   func   => 'getZClusterConfig', );
		$cluster_if = $zcl_conf->{ _ }->{ interface };
	}

	for my $if_ref ( &getInterfaceTypeList( 'nic' ) )
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
		};

		$if_conf->{ is_slave } = $if_ref->{ is_slave } if $eload;
		$if_conf->{ is_cluster } = 'true' if $cluster_if eq $if_ref->{ name };

		# include 'has_vlan'
		for my $vlan_ref ( @vlans )
		{
			if ( $vlan_ref->{ parent } eq $if_ref->{ name } )
			{
				$if_conf->{ has_vlan } = 'true';
				last;
			}
		}

		$if_conf->{ has_vlan } = 'false' unless $if_conf->{ has_vlan };

		push @output_list, $if_conf;
	}

	my $body = {
				 description => $desc,
				 interfaces  => \@output_list,
	};

	&httpResponse( { code => 200, body => $body } );
}

sub get_nic    # ()
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $nic = shift;

	require Zevenet::Net::Interface;

	my $desc = "Show NIC interface";
	my $interface;

	for my $if_ref ( &getInterfaceTypeList( 'nic' ) )
	{
		next unless $if_ref->{ name } eq $nic;

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

		$interface->{ is_slave } = $if_ref->{ is_slave } if $eload;
	}

	unless ( $interface )
	{
		my $msg = "Nic interface not found.";
		&httpErrorResponse( code => 404, desc => $desc, msg => $msg );
	}

	my $body = {
				 description => $desc,
				 interface   => $interface,
	};

	&httpResponse( { code => 200, body => $body } );
}

sub actions_interface_nic    # ( $json_obj, $nic )
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $json_obj = shift;
	my $nic      = shift;

	require Zevenet::Net::Interface;

	my $desc = "Action on nic interface";
	my $ip_v = 4;

	# validate NIC
	unless ( grep { $nic eq $_->{ name } } &getInterfaceTypeList( 'nic' ) )
	{
		my $msg = "Nic interface not found";
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
		require Zevenet::Net::Core;
		require Zevenet::Net::Route;

		my $if_ref = &getInterfaceConfig( $nic, $ip_v );

		# Delete routes in case that it is not a vini
		&delRoutes( "local", $if_ref ) if $if_ref;

		&addIp( $if_ref ) if $if_ref;

		my $state = &upIf( { name => $nic }, 'writeconf' );

		if ( !$state )
		{
			require Zevenet::Net::Util;

			&applyRoutes( "local", $if_ref ) if $if_ref;

			# put all dependant interfaces up
			&setIfacesUp( $nic, "vlan" );
			&setIfacesUp( $nic, "vini" ) if $if_ref;
		}
		else
		{
			my $msg = "The interface $nic could not be set UP";
			&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
		}
	}
	elsif ( $json_obj->{ action } eq "down" )
	{
		my $if_ref = &getInterfaceConfig( $nic, $ip_v );
		require Zevenet::Net::Core;

		my $state = &downIf( $if_ref, 'writeconf' );

		if ( $state )
		{
			my $msg = "The interface $nic could not be set DOWN";
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

sub modify_interface_nic    # ( $json_obj, $nic )
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $json_obj = shift;
	my $nic      = shift;

	require Zevenet::Net::Interface;
	require Zevenet::Net::Core;
	require Zevenet::Net::Route;

	my $desc = "Configure nic interface";
	my $ip_v = 4;

	# validate NIC NAME
	my @system_interfaces = &getInterfaceList();
	my $type              = &getInterfaceType( $nic );

	unless ( grep ( { $nic eq $_ } @system_interfaces ) && $type eq 'nic' )
	{
		my $msg = "Nic interface not found.";
		&httpErrorResponse( code => 404, desc => $desc, msg => $msg );
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
				 && &getValidFormat( 'IPv4_addr', $json_obj->{ ip } )
				 || $json_obj->{ ip } eq '' )
		{
			my $msg = "IP Address is not valid.";
			&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
		}
	}

   #not modify gateway or netmask if exists a virtual interface using this interface
	if ( exists $json_obj->{ netmask } )
	{
		my @child = &getInterfaceChild( $nic );
		if ( @child )
		{
			my $child_string = join ( ', ', @child );
			my $msg =
			  "It is not possible to modify $nic because there are virtual interfaces using it: $child_string.";
			&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
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

	# Check gateway errors
	if ( exists $json_obj->{ gateway } )
	{
		unless ( defined ( $json_obj->{ gateway } )
				 && &getValidFormat( 'IPv4_addr', $json_obj->{ gateway } )
				 || $json_obj->{ gateway } eq '' )
		{
			my $msg = "Gateway Address $json_obj->{gateway} structure is not ok.";
			&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
		}
	}

	# Delete old interface configuration
	my $if_ref = &getInterfaceConfig( $nic, $ip_v );

	# check if network is correct
	my $new_if;
	if ( $if_ref )
	{
		$new_if = {
					addr    => $json_obj->{ ip }      // $if_ref->{ addr },
					mask    => $json_obj->{ netmask } // $if_ref->{ mask },
					gateway => $json_obj->{ gateway } // $if_ref->{ gateway },
		};
	}
	else
	{
		$new_if = {
					addr    => $json_obj->{ ip },
					mask    => $json_obj->{ netmask },
					gateway => $json_obj->{ gateway } // undef,
		};
	}

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

	# check if ip exists in other interface
	if ( $json_obj->{ ip } )
	{
		if ( ( ( $json_obj->{ ip } ne $if_ref->{ addr } ) && $if_ref->{ addr } )
			 || !$if_ref->{ addr } )
		{
			require Zevenet::Net::Util;
			if ( grep ( /^$json_obj->{ ip }$/, &listallips() ) )
			{
				my $msg = "The IP address is already in use for other interface.";
				&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
			}
		}
	}

	if ( $if_ref->{ addr } )
	{
		# Delete old IP and Netmask from system to replace it
		&delIp( $if_ref->{ name }, $if_ref->{ addr }, $if_ref->{ mask } );

		# Remove routes if the interface has its own route table: nic and vlan
		&delRoutes( "local", $if_ref );

		$if_ref = undef;
	}

	# Setup new interface configuration structure
	$if_ref = &getInterfaceConfig( $nic ) // &getSystemInterface( $nic );
	$if_ref->{ addr }    = $json_obj->{ ip }      if exists $json_obj->{ ip };
	$if_ref->{ mask }    = $json_obj->{ netmask } if exists $json_obj->{ netmask };
	$if_ref->{ gateway } = $json_obj->{ gateway } if exists $json_obj->{ gateway };
	$if_ref->{ ip_v }    = 4;

	unless ( $if_ref->{ addr } && $if_ref->{ mask } )
	{
		my $msg = "Cannot configure the interface without address or without netmask.";
		&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
	}

	eval {
		# Add new IP, netmask and gateway
		# sometimes there are expected errors pending to be controlled
		&addIp( $if_ref );

		# Writing new parameters in configuration file
		&writeRoutes( $if_ref->{ name } );

		&setInterfaceConfig( $if_ref ) or die;

		# Put the interface up
		my $previous_status = $if_ref->{ status };
		if ( $previous_status eq "up" )
		{
			if ( &upIf( $if_ref, 'writeconf' ) == 0 )
			{
				$if_ref->{ status } = "up";
				&applyRoutes( "local", $if_ref );
			}
			else
			{
				$if_ref->{ status } = $previous_status;
			}
		}

		# if the GW is changed, change it in all appending virtual interfaces
		if ( exists $json_obj->{ gateway } )
		{
			foreach my $appending ( &getInterfaceChild( $nic ) )
			{
				my $app_config = &getInterfaceConfig( $appending );
				$app_config->{ gateway } = $json_obj->{ gateway };
				&setInterfaceConfig( $app_config );
			}
		}

		# put all dependant interfaces up
		require Zevenet::Net::Util;
		&setIfacesUp( $nic, "vini" );
	};

	if ( $@ )
	{
		my $msg = "Errors found trying to modify interface $nic";
		&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
	}

	my $body = {
				 description => $desc,
				 params      => $json_obj,
	};

	&httpResponse( { code => 200, body => $body } );
}

1;
