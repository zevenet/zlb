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

=begin nd
Function: getHTTPFarmEstConns

	Get all ESTABLISHED connections for a farm

Parameters:
	farmname - Farm name

Returns:
	array - Return all ESTABLISHED conntrack lines for a farm

=cut

sub getHTTPFarmEstConns    # ($farm_name)
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my ( $farm_name ) = @_;
	my $count = 0;

	if ( &getGlobalConfiguration( 'proxy_ng' ) eq 'true' )
	{
		require JSON;

		# curl --unix-socket /tmp/webfarm_proxy.socket  http://localhost/listener/0
		my $curl_bin = &getGlobalConfiguration( 'curl_bin' );
		my $url      = "http://localhost/listener/0";
		my $socket   = &getHTTPFarmSocket( $farm_name );
		my $cmd      = "$curl_bin --unix-socket $socket $url";
		my $resp     = &logAndGet( $cmd, 'string' );

		if ( $resp )
		{
			$resp = &JSON::decode_json( $resp );
			$count = $resp->{ "connections" } if $resp;
		}
	}
	else
	{
		my $vip      = &getFarmVip( "vip",  $farm_name );
		my $vip_port = &getFarmVip( "vipp", $farm_name );

		my $filter = {
					   proto         => 'tcp',
					   orig_dst      => $vip,
					   orig_port_dst => $vip_port,
					   state         => 'ESTABLISHED',
		};

		my $ct_params = &getConntrackParams( $filter );
		$count = &getConntrackCount( $ct_params );
	}

	#~ &zenlog( "getHTTPFarmEstConns: $farm_name farm -> $count connections." );

	return $count + 0;
}

=begin nd
Function: getHTTPFarmSYNConns

	Get all SYN connections for a farm

Parameters:
	farmname - Farm name

Returns:
	array - Return all SYN conntrack lines for a farm

=cut

sub getHTTPFarmSYNConns    # ($farm_name)
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my ( $farm_name ) = @_;

	my $count = 0;

	if ( &getGlobalConfiguration( 'proxy_ng' ) eq 'true' )
	{
		require JSON;

		# curl --unix-socket /tmp/webfarm_proxy.socket  http://localhost/listener/0
		my $curl_bin = &getGlobalConfiguration( 'curl_bin' );
		my $url      = "http://localhost/listener/0";
		my $socket   = &getHTTPFarmSocket( $farm_name );
		my $cmd      = "$curl_bin --unix-socket $socket $url";
		my $resp     = &logAndGet( $cmd, 'string' );

		if ( $resp )
		{
			$resp  = &JSON::decode_json( $resp );
			$count = $resp->{ "pending-connections" };
		}
	}
	else
	{
		my $vip      = &getFarmVip( "vip",  $farm_name );
		my $vip_port = &getFarmVip( "vipp", $farm_name );

		my $filter = {
					   proto         => 'tcp',
					   orig_dst      => $vip,
					   orig_port_dst => $vip_port,
					   state         => 'SYN_SENT',
		};

		my $ct_params = &getConntrackParams( $filter );
		my $count     = &getConntrackCount( $ct_params );

		$filter->{ state } = 'SYN_RECV';

		$ct_params = &getConntrackParams( $filter );
		$count += &getConntrackCount( $ct_params );

		#~ &zenlog( "getHTTPFarmSYNConns: $farm_name farm -> $count connections." );
	}

	return $count + 0;
}

=begin nd
Function: getHTTPBackendEstConns

	Get all ESTABLISHED connections for a backend

Parameters:
	farmname     - Farm name
	backend_ip   - IP backend
	backend_port - backend port

Returns:
	array - Return all ESTABLISHED conntrack lines for the backend

BUG:
	If a backend is used on more than one farm, here it appears all them
=cut

sub getHTTPBackendEstConns    # ($farm_name,$backend_ip,$backend_port, $netstat)
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my ( $farm_name, $backend_ip, $backend_port ) = @_;

	my $count = 0;

	if ( &getGlobalConfiguration( 'proxy_ng' ) eq 'true' )
	{
		require JSON;

		# curl --unix-socket /tmp/webfarm_proxy.socket  http://localhost/listener/0
		my $curl_bin = &getGlobalConfiguration( 'curl_bin' );
		my $url      = "http://localhost/listener/0";
		my $socket   = &getHTTPFarmSocket( $farm_name );
		my $cmd      = "$curl_bin --unix-socket $socket $url";
		my $resp     = &logAndGet( $cmd, 'string' );

		if ( $resp )
		{
			$resp = &JSON::decode_json( $resp );
			my $services = $resp->{ services };
			foreach my $service ( @$services )
			{
				foreach my $bk ( @{ $service->{ backends } } )
				{
					if ( $bk->{ ip } eq $backend_ip && $bk->{ port } eq $backend_port )
					{
						$count += $bk->{ connections };
						last;
					}
				}
			}
		}
	}
	else
	{
		my $filter = {
					   proto         => 'tcp',
					   orig_dst      => $backend_ip,
					   orig_port_dst => $backend_port,
					   state         => 'ESTABLISHED',
		};

		require Zevenet::Net::ConnStats;
		my $ct_params = &getConntrackParams( $filter );
		$count = &getConntrackCount( $ct_params );

	  # &zenlog( "getHTTPBackendEstConns: $farm_name backends -> $count connections." );

	}

	return $count + 0;
}

=begin nd
Function: getHTTPBackendSYNConns

	Get all SYN connections for a backend

Parameters:
	farmname     - Farm name
	backend_ip   - IP backend
	backend_port - backend port

Returns:
	unsigned integer - connections count

BUG:
	If a backend is used on more than one farm, here it appears all them.
=cut

sub getHTTPBackendSYNConns    # ($farm_name, $backend_ip, $backend_port)
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );

	my ( $farm_name, $backend_ip, $backend_port ) = @_;

	my $count = 0;

	if ( &getGlobalConfiguration( 'proxy_ng' ) eq 'true' )
	{
		require JSON;

		# curl --unix-socket /tmp/webfarm_proxy.socket  http://localhost/listener/0
		my $curl_bin = &getGlobalConfiguration( 'curl_bin' );
		my $url      = "http://localhost/listener/0";
		my $socket   = &getHTTPFarmSocket( $farm_name );
		my $cmd      = "$curl_bin --unix-socket $socket $url";
		my $resp     = &logAndGet( $cmd, 'string' );

		my $count = 0;

		if ( $resp )
		{
			$resp = &JSON::decode_json( $resp );
			my $services = $resp->{ services };
			foreach my $service ( @$services )
			{
				foreach my $bk ( @{ $service->{ backends } } )
				{
					if ( $bk->{ ip } eq $backend_ip && $bk->{ port } eq $backend_port )
					{
						$count += $bk->{ "pending-connections" };
						last;
					}
				}
			}
		}
	}
	else
	{
		my $filter = {
					   proto         => 'tcp',
					   orig_dst      => $backend_ip,
					   orig_port_dst => $backend_port,
					   state         => 'SYN_SENT',
		};

		my $ct_params = &getConntrackParams( $filter );
		my $count     = &getConntrackCount( $ct_params );

		$filter->{ state } = 'SYN_RECV';

		$ct_params = &getConntrackParams( $filter );
		$count += &getConntrackCount( $ct_params );
	}

	return $count + 0;

  # &zenlog( "getHTTPBackendSYNConns: $farm_name backends -> $count connections." );
}

=begin nd
Function: getHTTPFarmBackendsStats

	This function take data from pounctl or zproxy and it gives hash format

Parameters:
	farmname - Farm name

Returns:
	hash ref - hash with backend farm stats

	
=cut

sub getHTTPFarmBackendsStats    # ($farm_name,$service_name)
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my ( $farm_name, $service_name ) = @_;

	if ( &getGlobalConfiguration( 'proxy_ng' ) eq 'true' )
	{
		return &getZproxyHTTPFarmBackendsStats( $farm_name, $service_name );
	}
	else
	{
		return &getPoundHTTPFarmBackendsStats( $farm_name, $service_name );
	}
}

=begin nd
Function: getZproxyHTTPFarmBackendsStats

	This function take data from zproxy and gives it as hash format

Parameters:
	farmname - Farm name

Returns:
	hash ref - hash with backend farm stats

		backends =>
		[
			{
				"id"           = $backend_id		# it is the index in the backend array too
				"ip"           = $backend_ip
				"port"         = $backend_port
				"status"       = $backend_status
				"established"  = $established_connections
			}
		]

		sessions =>
		[
			{
				"client"       = $client_id 		# it is the index in the session array too
				"id"           = $backend id		# id associated to a backend, it can change depend of session type
				"backend_ip"   = $backend ip		# it is the backend ip
				"backend_port" = $backend port 		# it is the backend port
				"service"      = $service name          
				"session"      = $session identifier    # it depends on the persistence mode 
				"ttl"          = $ttl				# time remaining to delete session
			}
		]
=cut

sub getZproxyHTTPFarmBackendsStats    # ($farm_name, $service_name)
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my ( $farm_name, $service_name ) = @_;

	require JSON;
	require Zevenet::Farm::HTTP::Config;
	require Zevenet::Farm::HTTP::Service;
	use POSIX 'floor';

	my $stats = {
				  sessions => [],
				  backends => []
	};

	# curl --unix-socket /tmp/webfarm_proxy.socket  http://localhost/listener/0
	my $curl_bin = &getGlobalConfiguration( 'curl_bin' );
	my $url      = "http://localhost/listener/0";
	my $socket   = &getHTTPFarmSocket( $farm_name );
	my $cmd      = "$curl_bin --unix-socket $socket $url";
	my $resp     = &logAndGet( $cmd, 'string' );

	if ( $resp )
	{
		$resp = &JSON::decode_json( $resp );
		my $services = $resp->{ services };

		my $alias;
		$alias = &eload(
						 module => 'Zevenet::Alias',
						 func   => 'getAlias',
						 args   => ['backend']
		) if $eload;
		foreach my $service ( @$services )
		{
			next if ( defined $service_name && $service_name ne $service->{ name } );
			my $ttl = &getHTTPServiceStruct( $farm_name, $service->{ name } )->{ ttl };
			my $index = 0;
			my $backend_info;
			foreach my $bk ( @{ $service->{ backends } } )
			{
				# skip redirect backend
				next if ( $bk->{ type } eq "2" );
				my $backendHash = {
									id          => $bk->{ id },
									ip          => $bk->{ address },
									port        => $bk->{ port },
									status      => $bk->{ status },
									pending     => $bk->{ 'pending-connections' },
									established => $bk->{ connections },
									service     => $service->{ name }
				};
				$backendHash->{ alias } = $alias->{ $bk->{ address } } if $eload;
				if ( $backendHash->{ "status" } eq "active" )
				{
					$backendHash->{ "status" } = "up";
				}
				if ( $backendHash->{ "status" } eq "disabled" )
				{
					require Zevenet::Farm::HTTP::Backend;

					#Checkstatusfile
					$backendHash->{ "status" } =
					  &getHTTPBackendStatusFromFile( $farm_name, $bk->{ id }, $service->{ name } );

					# not show fgDOWN status
					$backendHash->{ "status" } = "down"
					  if ( $backendHash->{ "status" } ne "maintenance" );
				}
				push ( @{ $stats->{ backends } }, $backendHash );
				$backend_info->{ $bk->{ id } }->{ ip }   = $bk->{ address };
				$backend_info->{ $bk->{ id } }->{ port } = $bk->{ port };
			}

			$index = 0;
			my $time = time ();
			foreach my $ss ( @{ $service->{ sessions } } )
			{
				my $min_rem =
				  floor( ( $ttl - ( $time - $ss->{ 'last-seen' } ) ) / 60 );
				my $sec_rem =
				  floor( ( $ttl - ( $time - $ss->{ 'last-seen' } ) ) % 60 );

				my $ttl =
				  $ss->{ 'last-seen' } eq 0 ? undef : $min_rem . 'm' . $sec_rem . 's' . '0ms';

				my $sessionHash = {
								 client       => $index,
								 id           => $ss->{ 'backend-id' },
								 backend_ip   => $backend_info->{ $ss->{ 'backend-id' } }->{ ip },
								 backend_port => $backend_info->{ $ss->{ 'backend-id' } }->{ port },
								 session      => $ss->{ id },
								 service      => $service->{ name },
								 ttl          => $ttl,
				};
				push ( @{ $stats->{ sessions } }, $sessionHash );
				$index++;
			}

			last if ( defined $service_name );
		}
	}

	return $stats;
}

=begin nd
Function: getPoundHTTPFarmBackendsStats

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
				"client"       = $client_id 		# it is the index in the session array too
				"id"           = $session_id		# id associated to a backend, it can change depend of session type
				"backend_ip"   = $backend ip		# it is the backend ip
				"backend_port" = $backend port 		# it is the backend port
				"service"      = $service name          
				"session"      = $session identifier    # it depends on the persistence mode 
			}
		]

FIXME:
		Put output format same format than "GET /stats/farms/BasekitHTTP"

=cut

sub getPoundHTTPFarmBackendsStats    # ($farm_name,$service_name)
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my ( $farm_name, $service_name ) = @_;

	require Zevenet::Farm::Base;
	require Zevenet::Farm::HTTP::Config;
	require Zevenet::Validate;
	my $stats = {
				  sessions => [],
				  backends => []
	};

	my $serviceName;
	my $service_re = &getValidFormat( 'service' );

	unless ( $eload )
	{
		require Zevenet::Net::ConnStats;
	}

	# Get l7 proxy info
	#i.e. of proxyctl:

	#Requests in queue: 0
	#0. http Listener 185.76.64.223:80 a
	#0. Service "HTTP" active (4)
	#0. Backend 172.16.110.13:80 active (1 0.780 sec) alive (61)
	#1. Backend 172.16.110.14:80 active (1 0.878 sec) alive (90)
	#2. Backend 172.16.110.11:80 active (1 0.852 sec) alive (99)
	#3. Backend 172.16.110.12:80 active (1 0.826 sec) alive (75)
	my @proxyctl = &getHTTPFarmGlobalStatus( $farm_name );

	my $alias;
	$alias = &eload(
					 module => 'Zevenet::Alias',
					 func   => 'getAlias',
					 args   => ['backend']
	) if $eload;

	my $backend_info;

	# Parse ly proxy info
	foreach my $line ( @proxyctl )
	{
		# i.e.
		#     0. Service "HTTP" active (10)
		if ( $line =~ /(\d+)\. Service "($service_re)"/ )
		{
			$serviceName  = $2;
			$backend_info = undef;
		}

		next if ( defined $service_name && $service_name ne $serviceName );

		# Parse backend connections
		# i.e.
		#      0. Backend 192.168.100.254:80 active (5 0.000 sec) alive (0)
		if ( $line =~
			/(\d+)\. Backend (\d+\.\d+\.\d+\.\d+|[a-fA-F0-9:]+):(\d+) (\w+) .+ (\w+)(?: \((\d+)\))?/
		  )
		{
			my $backendHash = {
								id      => $1 + 0,
								ip      => $2,
								port    => $3 + 0,
								status  => $5,
								pending => 0,
								service => $serviceName,
			};
			$backendHash->{ alias } = $alias->{ $2 } if $eload;
			$backend_info->{ $backendHash->{ id } }->{ ip }   = $backendHash->{ ip };
			$backend_info->{ $backendHash->{ id } }->{ port } = $backendHash->{ port };

			if ( defined $6 )
			{
				$backendHash->{ established } = $6 + 0;
			}
			else
			{
				$backendHash->{ established } =
				  &getHTTPBackendEstConns( $farm_name,
										   $backendHash->{ ip },
										   $backendHash->{ port } );
			}

			# Getting real status
			my $backend_disabled = $4;
			if ( $backend_disabled eq "DISABLED" )
			{
				require Zevenet::Farm::HTTP::Backend;

				#Checkstatusfile
				$backendHash->{ "status" } =
				  &getHTTPBackendStatusFromFile( $farm_name, $backendHash->{ id },
												 $serviceName );

				# not show fgDOWN status
				$backendHash->{ "status" } = "down"
				  if ( $backendHash->{ "status" } ne "maintenance" );
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
			require Zevenet::Net::ConnStats;
			require Zevenet::Farm::Stats;

			$backendHash->{ pending } =
			  &getBackendSYNConns( $farm_name,
								   $backendHash->{ ip },
								   $backendHash->{ port } );

			push ( @{ $stats->{ backends } }, $backendHash );
		}

		# Parse sessions
		# i.e.
		#      1. Session 107.178.194.117 -> 1
		if ( $line =~ /(\d+)\. Session (.+) \-\> (\d+)/ )
		{
			push @{ $stats->{ sessions } },
			  {
				client       => $1 + 0,
				session      => $2,
				id           => $3 + 0,
				backend_ip   => $backend_info->{ $3 }->{ ip },
				backend_port => $backend_info->{ $3 }->{ port },
				service      => $serviceName,
			  };
		}
	}

	return $stats;
}

1;
