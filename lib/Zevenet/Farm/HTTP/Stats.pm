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
if ( eval { require Zevenet::ELoad; } ) { $eload = 1; }

=begin nd
Function: getHTTPBackendEstConns

	Get all ESTABLISHED connections for a backend

Parameters:
	farmname - Farm name
	ip_backend - IP backend
	port_backend - backend port
	netstat - Conntrack -L output

Returns:
	array - Return all ESTABLISHED conntrack lines for the backend

BUG:
	it is possible filter using farm Vip and port too. If a backend if defined in more than a farm, here it appers all them

=cut
sub getHTTPBackendEstConns     # ($farm_name,$ip_backend,$port_backend,@netstat)
{
	my ( $farm_name, $ip_backend, $port_backend, @netstat ) = @_;

	return
	  &getNetstatFilter(
		"tcp",
		"",
		"\.*ESTABLISHED src=\.* dst=.* sport=\.* dport=$port_backend \.*src=$ip_backend \.*",
		"",
		@netstat
	  );
}

=begin nd
Function: getHTTPFarmEstConns

	Get all ESTABLISHED connections for a farm

Parameters:
	farmname - Farm name
	netstat - Conntrack -L output

Returns:
	array - Return all ESTABLISHED conntrack lines for a farm

=cut
sub getHTTPFarmEstConns    # ($farm_name,@netstat)
{
	my ( $farm_name, @netstat ) = @_;

	my $vip      = &getFarmVip( "vip",  $farm_name );
	my $vip_port = &getFarmVip( "vipp", $farm_name );

	return &getNetstatFilter(
		"tcp", "",

		".* ESTABLISHED src=.* dst=$vip sport=.* dport=$vip_port src=.*",
		"", @netstat
	);
}

=begin nd
Function: getHTTPBackendSYNConns

	Get all SYN connections for a backend

Parameters:
	farmname - Farm name
	ip_backend - IP backend
	port_backend - backend port
	netstat - Conntrack -L output

Returns:
	array - Return all SYN conntrack lines for a backend of a farm

BUG:
	it is possible filter using farm Vip and port too. If a backend if defined in more than a farm, here it appers all them

=cut
sub getHTTPBackendSYNConns  # ($farm_name, $ip_backend, $port_backend, @netstat)
{
	my ( $farm_name, $ip_backend, $port_backend, @netstat ) = @_;

	return
	  &getNetstatFilter( "tcp", "",
				"\.*SYN\.* src=\.* dst=$ip_backend sport=\.* dport=$port_backend\.*",
				"", @netstat );
}

=begin nd
Function: getHTTPFarmSYNConns

	Get all SYN connections for a farm

Parameters:
	farmname - Farm name
	netstat - Conntrack -L output

Returns:
	array - Return all SYN conntrack lines for a farm

=cut
sub getHTTPFarmSYNConns     # ($farm_name, @netstat)
{
	my ( $farm_name, @netstat ) = @_;

	my $vip      = &getFarmVip( "vip",  $farm_name );
	my $vip_port = &getFarmVip( "vipp", $farm_name );

	return
	  &getNetstatFilter( "tcp", "",
					   "\.* SYN\.* src=\.* dst=$vip \.* dport=$vip_port \.* src=\.*",
					   "", @netstat );
}




=begin nd
Function: getHTTPFarmBackendsStats

	This function is the same than getHTTPFarmBackendsStatus_old but return a hash with http farm information
	This function take data from pounctl and it gives hash format

Parameters:
	farmname - Farm name

Returns:
	hash ref - hash with backend farm stats

		backends =>
		[
			{
				"id" = $backend_id		# it is the index in the backend array too
				"ip" = $backend_ip
				"port" = $backend_port
				"status" = $backend_status
				"established" = $established_connections
			}
		]

		sessions =>
		[
			{
				"client" = $client_id 		# it is the index in the session array too
				"id" = $session_id		# id associated to a bacckend, it can change depend of session type
				"backends" = $backend_id
			}
		]

FIXME:
		Put output format same format than "GET /stats/farms/BasekitHTTP"

=cut
sub getHTTPFarmBackendsStats    # ($farm_name,@content)
{
	my ( $farm_name ) = @_;

	my $stats;
	$stats->{ 'sessions' } = [];
	$stats->{ 'backends' } = [];
	my @sessions;
	my $serviceName;
	my $hashService;
	my $firstService = 1;

	require Zevenet::Farm::Base;
	require Zevenet::Farm::HTTP::Config;
	require Zevenet::Net::ConnStats;
	require Zevenet::Farm::Stats;

	my $fvip = &getFarmVip( "vip", $farm_name );

	my $service_re = &getValidFormat( 'service' );

	#i.e. of poundctl:

	#Requests in queue: 0
	#0. http Listener 185.76.64.223:80 a
		#0. Service "HTTP" active (4)
		#0. Backend 172.16.110.13:80 active (1 0.780 sec) alive (61)
		#1. Backend 172.16.110.14:80 active (1 0.878 sec) alive (90)
		#2. Backend 172.16.110.11:80 active (1 0.852 sec) alive (99)
		#3. Backend 172.16.110.12:80 active (1 0.826 sec) alive (75)
	my @poundctl = &getHTTPFarmGlobalStatus ($farm_name);

	foreach my $line ( @poundctl )
	{
		#i.e.
		#Requests in queue: 0
		#~ if ( $line =~ /Requests in queue: (\d+)/ )
		#~ {
			#~ $stats->{ "queue" } = $1;
		#~ }

		# i.e.
		#     0. Service "HTTP" active (10)
		if ( $line =~ /(\d+)\. Service "($service_re)"/ )
		{
			$serviceName = $2;
		}

		# i.e.
		#      0. Backend 192.168.100.254:80 active (5 0.000 sec) alive (0)
		if ( $line =~ /(\d+)\. Backend (\d+\.\d+\.\d+\.\d+):(\d+) (\w+) .+ (\w+)(:? \((\d+)\))?/ )
		{
			my $backendHash = {
								id          => $1 + 0,
								ip          => $2,
								port        => $3 + 0,
								status      => $5,
								pending     => 0,
								established => $6 + 0,
								service     => $serviceName,
			};

			unless( $eload )
			{
				my @netstat = &getConntrack( "", $backendHash->{ ip }, "", "", "tcp" );
				my @established =
					&getBackendEstConns( $farm_name, $backendHash->{ ip }, $backendHash->{ port }, @netstat );
				$backendHash->{ established } = scalar @established;
			}

			# Getting real status
			my $backend_disabled = $4;
			if ( $backend_disabled eq "DISABLED" )
			{
				require Zevenet::Farm::HTTP::Backend;
				#Checkstatusfile
				$backendHash->{ "status" } =
				  &getHTTPBackendStatusFromFile( $farm_name, $backendHash->{id}, $serviceName );

				# not show fgDOWN status
				$backendHash->{ "status" } = "down" if ( $backendHash->{ "status" } eq "fgDOWN" );
			}
			elsif ( $backendHash->{ "status" } eq "alive" )
			{
				$backendHash->{ "status" } = "up";
			}
			elsif ( $backendHash->{ "status" } eq "DEAD" )
			{
				$backendHash->{ "status" } = "down";
			}

			# Getting pending connections
			my @netstat = &getConntrack( $fvip, $backendHash->{ ip }, "", "", "tcp" );
			my @synnetstatback =
				&getBackendSYNConns( $farm_name, $backendHash->{ ip }, $backendHash->{ port }, @netstat );
			my $npend = @synnetstatback;
			$backendHash->{ pending } = $npend;

			push @{ $stats->{backends} }, $backendHash;
		}

		# i.e.
		#      1. Session 107.178.194.117 -> 1
		if ( $line =~ /(\d+)\. Session (.+) \-\> (\d+)/ )
		{
			push @{ $stats->{ sessions } },
			  {
				client  => $1 + 0,
				session => $2,
				id      => $3 + 0,
				service => $serviceName,
			  };
		}

	}

	return $stats;
}


1;
