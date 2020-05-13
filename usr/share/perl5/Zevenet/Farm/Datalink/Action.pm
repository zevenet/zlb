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

require Zevenet::Net::Route;

my $configdir = &getGlobalConfiguration( 'configdir' );

=begin nd
Function: _runDatalinkFarmStart

	Run a datalink farm

Parameters:
	farm_name - Farm name
	writeconf - write this change in configuration status "writeconf" for true or omit it for false

Returns:
	Integer - Error code: return 0 on success or different of 0 on failure

=cut

sub _runDatalinkFarmStart    # ($farm_name, $writeconf)
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my ( $farm_name, $writeconf ) = @_;

	require Tie::File;
	require Zevenet::Net::Util;
	require Zevenet::Farm::Datalink::Config;
	require Zevenet::Farm::Datalink::Backend;

	my $status;

	if ( $writeconf )
	{
		&setDatalinkFarmBootStatus( $farm_name, "up" );
	}

	# include cron task to check backends
	my $cron_tag  = "# __${farm_name}__";
	my $cron_file = &getGlobalConfiguration( "cron_conf" );

	tie my @cron_file, 'Tie::File', $cron_file;
	if ( !grep ( /$cron_tag/, @cron_file ) )
	{
		my $libexec_path = &getGlobalConfiguration( 'libexec_dir' );
		push ( @cron_file,
			   "* * * * *	root	$libexec_path/check_uplink $farm_name $cron_tag" );
	}
	untie @cron_file;

	# Apply changes online
	# Set default uplinks as gateways
	my $iface  = &getDatalinkFarmInterface( $farm_name );
	my $ip_bin = &getGlobalConfiguration( 'ip_bin' );

	my $cmd_params = "default table table_$iface";
	if ( &isRoute( $cmd_params ) )
	{
		&logAndRun( "$ip_bin route del $cmd_params" );
	}

	my $backends  = &getDatalinkFarmBackends( $farm_name );
	my $algorithm = &getDatalinkFarmAlgorithm( $farm_name );
	my $routes    = "";

	if ( $algorithm eq "weight" )
	{
		foreach my $serv ( @{ $backends } )
		{
			my $weight = 1;

			if ( $serv->{ weight } ne "" )
			{
				$weight = $serv->{ weight };
			}
			$routes =
			  "$routes nexthop via $serv->{ ip } dev $serv->{ interface } weight $weight";
		}
	}

	if ( $algorithm eq "prio" )
	{
		my $bestprio = 100;
		foreach my $serv ( @{ $backends } )
		{
			if (    $serv->{ priority } > 0
				 && $serv->{ priority } < 10
				 && $serv->{ priority } < $bestprio )
			{
				$routes   = "nexthop via $serv->{ ip } dev $serv->{ interface } weight 1";
				$bestprio = $serv->{ priority };
			}
		}
	}

	if ( $routes ne "" )
	{
		my $ip_command =
		  "$ip_bin route add default scope global table table_$iface $routes";

		$status = &logAndRun( "$ip_command" );
	}
	else
	{
		$status = 0;
	}

	# Set policies to the local network
	my $ip = &iponif( $iface );

	if ( $ip && $ip =~ /\./ )
	{
		use Net::IPv4Addr qw(ipv4_network);    # Does not support 'require'

		my $ipmask = &maskonif( $iface );
		my ( $net, $mask ) = ipv4_network( "$ip / $ipmask" );

		if ( !$net or !$mask )
		{
			&zenlog( "Interface $iface has to be up to boot the farm $farm_name" );
			return -1;
		}

		&zenlog( "Adding rules for $farm_name", "debug", "DSLB" );

		my $rule = {
					 table => "table_$iface",
					 type  => 'farm-datalink',
					 from  => "$net/$mask",
		};
		&setRule( 'add', $rule );
	}

	# Enable IP forwarding
	&setIpForward( "true" );

	# Enable active datalink file
	my $piddir = &getGlobalConfiguration( 'piddir' );
	open my $fd, '>', "$piddir\/$farm_name\_datalink.pid";
	close $fd;

	return $status;
}

=begin nd
Function: _runDatalinkFarmStop

	Stop a datalink farm

Parameters:
	farm_name - Farm name
	writeconf - write this change in configuration status "writeconf" for true or omit it for false

Returns:
	Integer - Error code: return 0 on success or -1 on failure

=cut

sub _runDatalinkFarmStop    # ($farm_name,$writeconf)
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my ( $farm_name, $writeconf ) = @_;

	require Tie::File;
	require Zevenet::Net::Util;
	require Zevenet::Farm::Datalink::Config;

	my $status = 0;

	if ( $writeconf )
	{
		$status = &setDatalinkFarmBootStatus( $farm_name, "down" );
	}

	# delete cron task to check backends
	my $cron_tag  = "# __${farm_name}__";
	my $cron_path = &getGlobalConfiguration( "cron_conf" );

	tie my @cron_file, 'Tie::File', $cron_path;
	@cron_file = grep !/$cron_tag/, @cron_file;
	untie @cron_file;

	my $iface  = &getDatalinkFarmInterface( $farm_name );
	my $ip_bin = &getGlobalConfiguration( 'ip_bin' );

	# Disable policies to the local network
	my $ip = &iponif( $iface );

	if ( $ip && $ip =~ /\./ )
	{
		my $ipmask = &maskonif( $iface );
		my ( $net, $mask ) = ipv4_network( "$ip / $ipmask" );

		&zenlog( "removing rules for $farm_name", "debug", "DSLB" );

		my $rule = {
					 table => "table_$iface",
					 type  => 'farm-datalink',
					 from  => "$net/$mask",
		};
		&setRule( 'del', $rule );
	}

	# Disable default uplink gateways
	my $cmd_params = "default table table_$iface";
	if ( &isRoute( $cmd_params ) )
	{
		&logAndRun( "$ip_bin route del $cmd_params" );
	}

	# Disable active datalink file
	my $piddir = &getGlobalConfiguration( 'piddir' );
	unlink ( "$piddir\/$farm_name\_datalink.pid" );

	if ( -e "$piddir\/$farm_name\_datalink.pid" )
	{
		$status = -1;
	}

	return $status;
}

=begin nd
Function: copyDatalinkFarm

	Function that does a copy of a farm configuration.
	If the flag has the value 'del', the old farm will be deleted.

Parameters:
	farmname - Farm name
	newfarmname - New farm name
	flag - It expets a 'del' string to delete the old farm. It is used to copy or rename the farm.

Returns:
	Integer - Error code: return 0 on success or -1 on failure

=cut

sub copyDatalinkFarm    # ($farm_name,$new_farm_name)
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my ( $farm_name, $new_farm_name, $rm ) = @_;

	require Tie::File;
	use File::Copy qw(copy);

	my $farm_filename = &getFarmFile( $farm_name );
	my $newffile      = "$new_farm_name\_datalink.cfg";
	my $output        = -1;

	my $piddir = &getGlobalConfiguration( 'piddir' );
	copy( "$configdir\/$farm_filename", "$configdir\/$newffile" );
	copy( "$piddir\/$farm_name\_datalink.pid",
		  "$piddir\/$new_farm_name\_datalink.pid" );
	$output = $?;

	tie my @configfile, 'Tie::File', "$configdir\/$newffile";

	for ( @configfile )
	{
		s/^$farm_name\;/$new_farm_name\;/g;
	}
	untie @configfile;

	if ( $rm eq 'del' )
	{
		unlink "$configdir\/$farm_filename";
		unlink "$piddir\/$farm_name\_datalink.pid";
	}

	return $output;
}

1;

