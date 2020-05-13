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
		return &httpErrorResponse( code => 400, desc => $desc, msg => $msg );
	}

	eval {
		die if &delRoutes( "local", $if_ref );
		die if &delIf( $if_ref );
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
}

# GET /interfaces Get params of the interfaces
sub get_nic_list    # ()
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	require Zevenet::Net::Interface;

	my $desc         = "List NIC interfaces";
	my $nic_list_ref = &get_nic_list_struct();

	my $body = {
				 description => $desc,
				 interfaces  => $nic_list_ref,
	};

	&httpResponse( { code => 200, body => $body } );
}

sub get_nic    # ()
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
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

	my $params = {
				   "action" => {
								 'non_blank' => 'true',
								 'required'  => 'true',
								 'values'    => ['up', 'down'],
				   },
	};

	# Check allowed parameters
	my $error_msg = &checkZAPIParams( $json_obj, $params, $desc );
	return &httpErrorResponse( code => 400, desc => $desc, msg => $error_msg )
	  if ( $error_msg );

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

		if ( !$state )
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
		}

		require Zevenet::Net::Core;
		my $state = &downIf( $if_ref, 'writeconf' );

		if ( $state )
		{
			my $msg = "The interface $nic could not be set DOWN";
			&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
		}
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
	require Zevenet::Net::Validate;

	my $desc = "Configure NIC interface";

	# validate NIC NAME
	my $type = &getInterfaceType( $nic );

	unless ( $type eq 'nic' )
	{
		my $msg = "NIC interface not found.";
		&httpErrorResponse( code => 404, desc => $desc, msg => $msg );
	}

	my $params = {
				   "ip" => {
							 'valid_format' => 'ip_addr',
				   },
				   "netmask" => {
								  'valid_format' => 'ip_mask',
				   },
				   "gateway" => {
								  'valid_format' => 'ip_addr',
				   },
				   "force" => {
								'non_blank' => 'true',
								'values'    => ['true'],
				   },
	};

	if ( $eload )
	{
		$params->{ "dhcp" } = {
								'non_blank' => 'true',
								'values'    => ['true', 'false'],
		};
	}

	# Check allowed parameters
	my $error_msg = &checkZAPIParams( $json_obj, $params, $desc );
	return &httpErrorResponse( code => 400, desc => $desc, msg => $error_msg )
	  if ( $error_msg );

	# Delete old interface configuration
	my $if_ref = &getInterfaceConfig( $nic ) // &getSystemInterface( $nic );

	# check if some farm is using this ip
	my @child = &getInterfaceChild( $nic );
	my @farms;
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

		require Zevenet::Farm::Base;
		@farms = &getFarmListByVip( $if_ref->{ addr } );

		if ( @farms )
		{
			if (    !exists $json_obj->{ ip }
				 and exists $json_obj->{ dhcp }
				 and $json_obj->{ dhcp } eq 'false' )
			{
				my $msg =
				  "This interface is been used by some farms, please, set up a new 'ip' in order to be used as farm vip.";
				&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
			}
			if ( $json_obj->{ force } ne 'true' )
			{
				my $str = join ( ', ', @farms );
				my $msg =
				  "The IP is being used as farm vip in the farm(s): $str. If you are sure, repeat with parameter 'force'. All farms using this interface will be restarted.";
				return &httpErrorResponse( code => 400, desc => $desc, msg => $msg );
			}
		}
	}

	my $dhcp_status = $json_obj->{ dhcp } // $if_ref->{ dhcp };

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
		elsif ( !exists $json_obj->{ ip } )
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

		my $mask_v =
		    ( $ip_v == 4 && &getValidFormat( 'IPv4_mask', $new_if->{ mask } ) ) ? 4
		  : ( $ip_v == 6 && &getValidFormat( 'IPv6_mask', $new_if->{ mask } ) ) ? 6
		  :                                                                       '';

		if ( $ip_v ne $mask_v
			 || ( $new_if->{ gateway } && $ip_v ne $gw_v ) )
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
				  &getNetValidate( $child_if->{ addr }, $new_if->{ mask }, $new_if->{ addr } ) )
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
			 &getNetValidate( $new_if->{ addr }, $new_if->{ mask }, $new_if->{ gateway } ) )
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

	# END CHECKS

	if ( $if_ref->{ addr } )
	{
		# remove custom routes
		if ( $eload )
		{
			&eload(
					module => 'Zevenet::Net::Routing',
					func   => 'updateRoutingVirtualIfaces',
					args   => [$if_ref->{ parent }, $json_obj->{ ip }],
			);
		}

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
		my $err = &eload(
						  module => 'Zevenet::Net::DHCP',
						  func   => $func,
						  args   => [$if_ref],
		);

		if (    $json_obj->{ dhcp } eq 'false' and !exists $json_obj->{ ip }
			 or $json_obj->{ dhcp } eq 'true' )
		{
			$set_flag = 0;
		}
	}
	if ( !&setInterfaceConfig( $if_ref ) )
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
	if (     $if_ref->{ addr } && $if_ref->{ mask }
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

			# put all dependent interfaces up
			require Zevenet::Net::Util;
			&setIfacesUp( $nic, "vini" );

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
	};

	&httpResponse( { code => 200, body => $body } );
}

1;
