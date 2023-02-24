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


sub delete_interface_nic    # ( $nic )
{
	&zenlog( __FILE__ . q{:} . __LINE__ . q{:} . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $nic = shift;

	require Zevenet::Net::Core;
	require Zevenet::Net::Route;
	require Zevenet::Net::Interface;

	my $desc   = "Delete nic interface";
	my $ip_v   = 4;
	my $if_ref = &getInterfaceConfig( $nic, $ip_v );

	if ( not $if_ref )
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

	# check if some farm is using this ip
	require Zevenet::Farm::Base;
	my @farms = &getFarmListByVip( $if_ref->{ addr } );
	if ( @farms )
	{
		my $str = join ( ', ', @farms );
		my $msg = "This interface is being used as vip in the farm(s): $str.";
		&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
	}
	eval {
		if (    &delRoutes( "local", $if_ref )
			 or &delIf( $if_ref ) )
		{
			my $msg = "The configuration for the network interface $nic can't be deleted.";
			&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
		}
	};

	if ( $@ )
	{
		&zenlog( "Module failed: $@", 'error', 'net' );
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
	return;
}

# GET /interfaces Get params of the interfaces
sub get_nic_list    # ()
{
	&zenlog( __FILE__ . q{:} . __LINE__ . q{:} . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	require Zevenet::Net::Interface;

	my $desc         = "List NIC interfaces";
	my $nic_list_ref = &get_nic_list_struct();

	my $body = {
				 description => $desc,
				 interfaces  => $nic_list_ref,
	};

	&httpResponse( { code => 200, body => $body } );

	return;
}

sub get_nic    # ()
{
	&zenlog( __FILE__ . q{:} . __LINE__ . q{:} . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $nic = shift;

	require Zevenet::Net::Interface;

	my $desc      = "Show NIC interface";
	my $interface = &get_nic_struct( $nic );

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
	return;
}

sub actions_interface_nic    # ( $json_obj, $nic )
{
	&zenlog( __FILE__ . q{:} . __LINE__ . q{:} . ( caller ( 0 ) )[3] . "( @_ )",
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
	my $params = &getZAPIModel( "nic-action.json" );

	# Check allowed parameters
	my $error_msg = &checkZAPIParams( $json_obj, $params, $desc );
	if ( $error_msg )
	{
		&httpErrorResponse( code => 400, desc => $desc, msg => $error_msg );
	}

	my $if_ref = &getInterfaceConfig( $nic, $ip_v );

	# validate action parameter
	if ( $json_obj->{ action } eq "up" )
	{
		require Zevenet::Net::Core;
		require Zevenet::Net::Route;

		# Delete routes in case that it is not a vini
		if ( $if_ref->{ addr } )
		{
			&delRoutes( "local", $if_ref ) if $if_ref;
		}

		&addIp( $if_ref ) if $if_ref;

		my $state = &upIf( $if_ref, 'writeconf' );

		if ( not $state )
		{
			require Zevenet::Net::Util;
			&applyRoutes( "local", $if_ref ) if $if_ref->{ addr };

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
		require Zevenet::Net::Core;
		my $state = &downIf( $if_ref, 'writeconf' );

		if ( $state )
		{
			my $msg = "The interface $nic could not be set DOWN";
			&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
		}
	}

	my $msg = "The $nic NIC is $json_obj->{ action }";
	my $body = {
				 description => $desc,
				 params      => { action => $json_obj->{ action } },
				 message     => $msg
	};

	&httpResponse( { code => 200, body => $body } );
	return;
}

sub modify_interface_nic    # ( $json_obj, $nic )
{
	&zenlog( __FILE__ . q{:} . __LINE__ . q{:} . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $json_obj = shift;
	my $nic      = shift;

	require Zevenet::Net::Interface;
	require Zevenet::Net::Core;
	require Zevenet::Net::Route;
	require Zevenet::Net::Validate;

	my $desc = "Configure NIC interface";

	# validate NIC NAME
	my $type = &getInterfaceType( $nic );

	unless ( $type eq 'nic' )
	{
		my $msg = "NIC interface not found.";
		&httpErrorResponse( code => 404, desc => $desc, msg => $msg );
	}
	my $params = &getZAPIModel( "nic-modify.json" );

	# Check allowed parameters
	my $error_msg = &checkZAPIParams( $json_obj, $params, $desc );
	if ( $error_msg )
	{
		&httpErrorResponse( code => 400, desc => $desc, msg => $error_msg );
	}

	# Delete old interface configuration
	my $if_ref = &getInterfaceConfig( $nic ) // &getSystemInterface( $nic );

	# Ignore the dhcp parameter if it is equal to the configured one
	delete $json_obj->{ dhcp }
	  if ( exists $json_obj->{ dhcp }
		   and $json_obj->{ dhcp } eq $if_ref->{ dhcp } );

	my @child = &getInterfaceChild( $nic );

	if ( exists $json_obj->{ dhcp } )
	{
		# only allow dhcp when no other parameter was sent
		if ( $json_obj->{ dhcp } eq 'true' )
		{
			if (    exists $json_obj->{ ip }
				 or exists $json_obj->{ netmask }
				 or exists $json_obj->{ gateway } )
			{
				my $msg =
				  "It is not possible set 'ip', 'netmask' or 'gateway' while 'dhcp' is going to be set up.";
				&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
			}
		}
		elsif ( not exists $json_obj->{ ip } )
		{
			if ( @child )
			{
				my $msg =
				  "This interface has appending some virtual interfaces, please, set up a new 'ip' in the current networking range.";
				&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
			}
		}
	}

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

	# Make sure the address, mask and gateway belong to the same stack
	if ( $new_if->{ addr } )
	{
		my $ip_v = &ipversion( $new_if->{ addr } );
		my $gw_v = &ipversion( $new_if->{ gateway } );

		if ( not &validateNetmask( $json_obj->{ netmask }, $ip_v ) )
		{
			my $msg = "The netmask is not valid";
			&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
		}

		if ( $new_if->{ gateway } and $ip_v ne $gw_v )
		{
			my $msg = "Invalid IP stack version match.";
			&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
		}
	}

	if ( exists $json_obj->{ ip } or exists $json_obj->{ netmask } )
	{
		# check ip and netmask are configured
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

	# check if network exists in other interface
	if ( $json_obj->{ ip } or $json_obj->{ netmask } )
	{
		my $if_used = &checkNetworkExists( $new_if->{ addr }, $new_if->{ mask }, $nic );
		if ( $if_used )
		{
			my $msg = "The network already exists in the interface $if_used.";
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

	# check if some farm is using this ip
	my @farms;
	my $vpns_localgw;
	@{ $vpns_localgw } = ();
	my $vpns_localnet;
	@{ $vpns_localnet } = ();
	my $warning_msg;

	if (    exists $json_obj->{ ip }
		 or ( exists $json_obj->{ dhcp } )
		 or ( exists $json_obj->{ netmask } ) )
	{
		if ( exists $json_obj->{ ip }
			 or ( exists $json_obj->{ dhcp } ) )
		{
			require Zevenet::Farm::Base;
			@farms = &getFarmListByVip( $if_ref->{ addr } );
		}

		# check if its a new network and a vpn using old network
		if ( exists $json_obj->{ ip } or exists $json_obj->{ netmask } )
		{
			# check if network is changed
			my $mask = $json_obj->{ netmask } // $if_ref->{ mask };
			if (
				 not &validateGateway( $if_ref->{ addr }, $if_ref->{ mask }, $json_obj->{ ip } )
				 or $if_ref->{ mask } ne $mask )
			{
				my $net = NetAddr::IP->new( $if_ref->{ addr }, $if_ref->{ mask } )->cidr();
			}
		}

		if ( @farms or @{ $vpns_localgw } or @{ $vpns_localnet } )
		{
			if (     not exists $json_obj->{ ip }
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
				&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
			}
		}
	}

	# END CHECKS

	if ( $if_ref->{ addr } )
	{
		# remove custom routes
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
	$if_ref->{ ip_v } = &ipversion( $if_ref->{ addr } );
	$if_ref->{ net } =
	  &getAddressNetwork( $if_ref->{ addr }, $if_ref->{ mask }, $if_ref->{ ip_v } );
	$if_ref->{ dhcp } = $json_obj->{ dhcp } if exists $json_obj->{ dhcp };

	# set DHCP
	my $set_flag        = 1;
	my $nic_config_file = "";
	if ( exists $json_obj->{ dhcp } )
	{
		if ( $json_obj->{ dhcp } eq "true" )
		{
			require Zevenet::Lock;
			$nic_config_file =
			  &getGlobalConfiguration( 'configdir' ) . "/if_$if_ref->{ name }_conf";
			&lockResource( $nic_config_file, "l" );
		}

		my $func = ( $json_obj->{ dhcp } eq 'true' ) ? "enableDHCP" : "disableDHCP";

		if (    $json_obj->{ dhcp } eq 'false' and not exists $json_obj->{ ip }
			 or $json_obj->{ dhcp } eq 'true' )
		{
			$set_flag = 0;
		}
	}
	if ( not &setInterfaceConfig( $if_ref ) )
	{
		if ( $json_obj->{ dhcp } eq "true" )
		{
			require Zevenet::Lock;
			&lockResource( $nic_config_file, "ud" );
		}
		my $msg = "Errors found trying to modify interface $nic";
		&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
	}

	# Free the resource
	if ( $json_obj->{ dhcp } eq "true" )
	{
		require Zevenet::Lock;
		&lockResource( $nic_config_file, "ud" );
	}

	# set up
	if (     $if_ref->{ addr }
		 and $if_ref->{ mask }
		 and $set_flag )
	{
		eval {
			# Add new IP, netmask and gateway
			# sometimes there are expected errors pending to be controlled
			&addIp( $if_ref );

			# Writing new parameters in configuration file
			&writeRoutes( $if_ref->{ name } );

			# Put the interface up
			my $previous_status = $if_ref->{ status };

			if ( $previous_status eq "up" )
			{
				if ( &upIf( $if_ref, 'writeconf' ) == 0 )
				{
					$if_ref->{ status } = "up";
					&applyRoutes( "local", $if_ref );
					if ( $if_ref->{ ip_v } eq "4" )
					{
						my $if_gw = &getGlobalConfiguration( 'defaultgwif' );
						if ( $if_ref->{ name } eq $if_gw )
						{
							my $defaultgw = &getGlobalConfiguration( 'defaultgw' );
							&applyRoutes( "global", $if_ref, $defaultgw );
						}
					}
					elsif ( $if_ref->{ ip_v } eq "6" )
					{
						my $if_gw = &getGlobalConfiguration( 'defaultgwif6' );
						if ( $if_ref->{ name } eq $if_gw )
						{
							my $defaultgw = &getGlobalConfiguration( 'defaultgw6' );
							&applyRoutes( "global", $if_ref, $defaultgw );
						}
					}
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

			# modify netmask on all dependent interfaces
			if ( exists $json_obj->{ netmask } )
			{
				foreach my $appending ( &getInterfaceChild( $nic ) )
				{
					my $app_config = &getInterfaceConfig( $appending );
					&delRoutes( "local", $app_config );
					&downIf( $app_config );
					$app_config->{ mask } = $json_obj->{ netmask };
					&setInterfaceConfig( $app_config );
				}
			}

			# put all dependent interfaces up
			require Zevenet::Net::Util;
			if ( &setIfacesUp( $nic, "vini" ) )
			{
				my $msg = "Errors found trying to modify interface $nic";
				&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
			}

			# change farm vip,
			if ( @farms )
			{
				require Zevenet::Farm::Config;
				&setAllFarmByVip( $json_obj->{ ip }, \@farms );
				&reloadFarmsSourceAddress();
			}
		};

		if ( $@ )
		{
			&zenlog( "Module failed: $@", "error", "net" );
			my $msg = "Errors found trying to modify interface $nic";
			&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
		}
	}

	my $iface_out = &get_nic_struct( $nic );
	my $body = {
				 description => $desc,
				 params      => $iface_out,
				 message     => "The $nic NIC has been updated successfully."
	};
	$body->{ warning } = $warning_msg if ( $warning_msg );

	&httpResponse( { code => 200, body => $body } );
	return;
}

1;
