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
Function: setSshForCluster

	Modify SSH configuration to allow SSH connections for cluster

Parameters:
	String - IP remote node.

Returns:
	Interger - It returns the code error

=cut

sub setSshForCluster
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $remote_ip = shift;
	my $type      = shift;

	my $sshFile = &getGlobalConfiguration( 'sshConf' );
	my $output  = 1;

	if ( !-e $sshFile )
	{
		&zenlog( "SSH configuration file doesn't exist.", "error", "AZURE" );
		return -1;
	}

	require Zevenet::Lock;
	my $cat = &getGlobalConfiguration( 'cat_bin' );

	if ( $type eq 'delete'
		 && grep ( /Match Address ${remote_ip}/, `$cat $sshFile` ) )
	{

		&ztielock( \my @file, "$sshFile" );
		my $cont = 0;

		foreach my $line ( @file )
		{
			if ( $line =~ /Match Address ${remote_ip}/ )
			{
				my $start = $cont - 1;
				splice ( @file, $start, 4 );
				$output = 0;
			}
			$cont++;
		}
		untie @file;
	}
	elsif ( $type eq 'add' )
	{
		my $sshConf =
		  "\nMatch Address $remote_ip\n\tPermitRootLogin yes\n\tPasswordAuthentication yes";

		&ztielock( \my @currentConf, "$sshFile" );
		push @currentConf, $sshConf;
		untie @currentConf;
	}

	# restart service to apply changes
	my $cmd = &getGlobalConfiguration( 'sshService' ) . " restart";
	$output = &logAndRun( $cmd );

	return $output;
}

=begin nd
Function: setSshRemoteForCluster 

	Set the SSH configuration in remote node for cluster

Parameters:
	remote ip - Remote Ip of a remote load balancer
	password - Remote password of a remote load balancer
	local ip - Local IP

Returns:
	String - It returns the session cookie

=cut

sub setSshRemoteForCluster
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $remote_ip = shift;
	my $password  = shift;
	my $local_ip  = shift;

	my $cookie = &getRemoteSession( $remote_ip, $password );

	if ( !$cookie )
	{
		&zenlog( "It is not possible get the SESSION_ID", "error", "AZURE" );
		return -1;
	}

	my $code = &remoteSshCall( $remote_ip, $cookie, $local_ip );

	return $code;
}

=begin nd
Function: getRemoteSession 

	Get SESSION_ID of a session with a remote load balancer 

Parameters:
	ip - Remote Ip of a load balancer
	password - Remote password of a load balancer

Returns:
	String - It returns the session cookie

=cut

sub getRemoteSession
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $remote_ip = shift;
	my $password  = shift;

	my $curl = &getGlobalConfiguration( 'curl_bin' );

	use MIME::Base64;
	include 'Zevenet::System::HTTP';
	my $auth  = encode_base64( "root:$password", '' );
	my $ports = &getHttpServerPort();
	my $port  = ref ( $ports ) eq 'ARRAY' ? @$ports[0] : $ports;

	my $url     = "https://$remote_ip:$port/zapi/v4.0/zapi.cgi/session";
	my $fcookie = "/tmp/remote_cookie";
	my $headers =
	  "-H 'Content-Type: application/json' -H 'Authorization: Basic $auth'";

	my $cmd =
	  "$curl -X POST -s -f -k $url --connect-timeout 2 --cookie-jar $fcookie -d '{}' $headers";
	my $error = &logAndRun( $cmd );

	if ( $error )
	{
		&zenlog( "It is not possible to open a remote session", "error", "AZURE" );
		return -1;
	}

	if ( !-e $fcookie )
	{
		&zenlog( "The remote cookie cannot be obtained", "error", "AZURE" );
		return -1;
	}

	my $cookie_file_lock = &openlock( $fcookie, '<' );
	my $cat = &getGlobalConfiguration( 'cat_bin' );

	my @match = grep /CGISESSID\t(.+)/, `$cat $fcookie`;
	$match[0] =~ /CGISESSID\t([a-z0-9]+)/;
	my $cookie = $1;

	close $cookie_file_lock;
	unlink $fcookie;

	if ( !$cookie )
	{
		&zenlog( "The remote cookie has not been received", "error", "AZURE" );
		return -1;
	}

	return $cookie;
}

=begin nd
Function: remoteSshCall 

	Call to remote load balancer to set the SSH configuration

Parameters:
	remote ip - Remote Ip of a remote load balancer
	cookie - SESSION_ID with the remote load balancer
	local ip - Local IP

Returns:
	String - It returns the error code

=cut

sub remoteSshCall
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $remote_ip = shift;
	my $cookie    = shift;
	my $local_ip  = shift;

	include 'Zevenet::System::HTTP';
	my $curl  = &getGlobalConfiguration( 'curl_bin' );
	my $ports = &getHttpServerPort();
	my $port  = ref ( $ports ) eq 'ARRAY' ? @$ports[0] : $ports;

	my $url = "https://$remote_ip:$port/zapi/v4.0/zapi.cgi/azure/ssh";
	my $headers =
	  "-H 'Content-Type: application/json' -H 'Cookie: CGISESSID=$cookie'";

	my $cmd =
	  "$curl -X PUT -s -f -k $url $headers --connect-timeout 2 -d '{\"remote_ip\": \"$local_ip\"}'";
	my $error = &logAndRun( $cmd );

	if ( $error )
	{
		&zenlog( "It is not possible to modify the remote node SSH", "error", "AZURE" );
		return -1;
	}

	return $error;
}

=begin nd
Function: getInstanceGroup

        Get group name

Parameters:
        none -

Returns:
        String - The group name

=cut

sub getInstanceGroup
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );

	my $wget          = &getGlobalConfiguration( 'wget' );
	my $cloud_address = &getGlobalConfiguration( 'cloud_address_metadata' );

	my $group = &logAndGet(
		"$wget --header=\"Metadata: true\" -q -O - -T 5 \"http://$cloud_address/metadata/instance/compute/resourceGroupName?api-version=2019-08-15&format=text\""
	);

	return $group;
}

=begin nd
Function: getInstanceName

        Get instance name

Parameters:
        none -

Returns:
        String - The instance name

=cut

sub getInstanceName
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );

	my $wget          = &getGlobalConfiguration( 'wget' );
	my $cloud_address = &getGlobalConfiguration( 'cloud_address_metadata' );

	my $instance_name = &logAndGet(
		"$wget --header=\"Metadata: true\" -q -O - -T 5 \"http://$cloud_address/metadata/instance/compute/name?api-version=2019-08-15&format=text\""
	);

	return $instance_name;
}

=begin nd
Function: reassignInterfaces 

	Reassign interfaces of the remote node to this node

Parameters:
	none -

Returns:
	Interger - It returns the code error

=cut

sub reassignInterfaces
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );

	include 'Zevenet::Cluster';
	my $az                   = &getGlobalConfiguration( 'az_bin' );
	my $remote_instance_name = &getZClusterRemoteHost();
	my $remote_ip = &getZClusterConfig()->{ $remote_instance_name }->{ ip };

	my $query = &logAndGet(
		"$az vm list-ip-addresses --query \"[?contains(virtualMachine.network.privateIpAddresses, '$remote_ip')].virtualMachine.resourceGroup\""
	);

	require JSON::XS;
	my $json = eval { JSON::XS::decode_json( $query ) };
	my $remote_instance_group = @{ $json }[0];

	my $instance_name  = &getInstanceName();
	my $instance_group = &getInstanceGroup();
	my $error          = 0;

	if ( $instance_name && $remote_instance_name )
	{
		## Remote networks interfaces
		my @remote_network_ifaces =
		  @{ &getNetworksInterfaces( $remote_instance_name, $remote_instance_group ) };

		## Local networks interfaces
		my @local_network_ifaces =
		  @{ &getNetworksInterfaces( $instance_name, $instance_group ) };

		foreach my $network ( @remote_network_ifaces )
		{
			my $nic_group  = $network->{ resourceGroup };
			my $nic_subnet = $network->{ ipConfigurations }[0]->{ subnet }->{ id };
			my @network_iface =
			  grep { $_->{ ipConfigurations }[0]->{ subnet }->{ id } eq $nic_subnet }
			  @local_network_ifaces;

			foreach my $line ( @{ $network->{ ipConfigurations } } )
			{
				if ( !$line->{ primary } )
				{
					my $name       = $line->{ name };
					my $private_ip = $line->{ privateIpAddress };
					my $public_ip  = $line->{ publicIpAddress }->{ id };

					# This command takes around 1 minute to finish.
					my $deleted =
					  &logAndRun( "$az network nic ip-config delete --ids $line->{ id }" );
					if ( $deleted )
					{
						&zenlog( "It is not possible to change the private IP $private_ip",
								 "error", "AZURE" );
						return -1;
					}

					# This command takes around 15 seconds to finish.
					my $added = &logAndRun(
						"$az network nic ip-config create --name $name --nic-name $network_iface[0]->{ name } --private-ip-address $private_ip --public-ip-address $public_ip -g $instance_group"
					);
					if ( $added )
					{
						&zenlog( "It is not possible to change the private IP $private_ip",
								 "error", "AZURE" );
						return -1;
					}
				}
			}
		}
		return 0;
	}

	&zenlog( "It is not possible to get the instance name", "error", "AZURE" );
	return -1;
}

=begin nd
Function: getNetworksInterfaces 

	Get the network interfaces of a instance

Parameters:
	name - Instance name
	group - Instance group

Returns:
	Array - It returns the networks interfaces

=cut

sub getNetworksInterfaces
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $instance_name  = shift;
	my $instance_group = shift;
	my $az             = &getGlobalConfiguration( 'az_bin' );

	my $query = &logAndGet(
		  "$az vm nic list --vm-name $instance_name --resource-group $instance_group" );

	require JSON::XS;
	my $json = eval { JSON::XS::decode_json( $query ) };
	my @network_ifaces = @{ $json };

	my $network_ids;
	foreach my $iface ( @network_ifaces )
	{
		$network_ids = $network_ids . " $iface->{ id }";
	}

	my $query2 = &logAndGet( "$az network nic show --ids $network_ids" );
	my $json2 = eval { JSON::XS::decode_json( $query2 ) };
	$json2 = [$json2] if ( ref ( $json2 ) eq 'HASH' );
	my @virtuals_ip = @{ $json2 };

	return \@virtuals_ip;
}

=begin nd
Function: disableSshCluster 

	Disable the SSH configuration for cluster

Parameters:
	none -

Returns:
	String - It returns the code error

=cut

sub disableSshCluster
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );

	include 'Zevenet::Cluster';
	require Zevenet::SystemInfo;
	my $zcl_conf  = &getZClusterConfig();
	my $remote_hn = &getZClusterRemoteHost();

	my $output = &setSshForCluster( $zcl_conf->{ $remote_hn }->{ ip }, 'delete' );

	return $output;
}

=begin nd
Function: getCredentials 

	Get Azure credentials

Returns:
	Array - It returns the logged ad sp id and name

=cut

sub getCredentials
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );

	require Config::Tiny;
	require Zevenet::Config;

	my $az = &getGlobalConfiguration( "az_bin" );

	my $account_data = &logAndGet( "$az account show" );

	require JSON::XS;
	my $account = eval { JSON::XS::decode_json( $account_data ) };

	my %credentials = (
						id   => '',
						name => '',
	);
	if ( $account )
	{
		$credentials{ id }   = $account->{ id };
		$credentials{ name } = $account->{ user }->{ name };
	}

	return \%credentials;
}

=begin nd
Function: setCredentials 

	Create an Azure Active Directory Service Principal(ad sp) with network and vm user roles.  That ad sp allow
	to manage remote and host nics and their ip configurations.

Parameters:
	json_obj - Object with Azure account user and password

Returns:
	String - It returns the code error.

=cut

sub setCredentials
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $json_obj = shift;
	my $az       = &getGlobalConfiguration( 'az_bin' );

	if ( exists ( $json_obj->{ user } ) && exists ( $json_obj->{ password } ) )
	{

		my $error =
		  &logAndRun( "$az login -u $json_obj->{ user } -p $json_obj->{ password }" );
		if ( $error )
		{
			return $error;
		}
		my $network_role = &getGlobalConfiguration( 'network_role' );
		my $vm_user_role = &getGlobalConfiguration( 'vm_user_role' );
		my $service_name = &getInstanceName() . "_service_principal";
		my $service_principal =
		  &logAndGet(
					"$az ad sp create-for-rbac -n $service_name --role \"$vm_user_role\"" );

		my $json = JSON::XS::decode_json( $service_principal );

		&logAndRun(
			"$az role assignment create --assignee $json->{ name } --role \"$network_role\""
		);

		# Time for azure
		sleep ( 10 );

		my $error =
		  &logAndRunCheck(
			"$az login --service-principal --username $json->{ name } --tenant $json->{ tenant } --password $json->{ password }"
		  );
		if ( $error )
		{
			&logAndRun( "$az logout" );
			return $error;
		}

	}

	return 0;
}

1;

