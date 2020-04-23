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

use Zevenet::System;

my $eload;
if ( eval { require Zevenet::ELoad; } )
{
	$eload = 1;
}

# Get all farm stats
sub getAllFarmStats
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	require Zevenet::Farm::Core;
	require Zevenet::Farm::Base;

	my @files = &getFarmList();
	my @farms;

	# FIXME: Verify stats are working with every type of farm

	foreach my $file ( @files )
	{
		my $name = &getFarmName( $file );
		my $type = &getFarmType( $name );

		my $status      = &getFarmVipStatus( $name );
		my $vip         = &getFarmVip( 'vip', $name );
		my $port        = &getFarmVip( 'vipp', $name );
		my $established = 0;
		my $pending     = 0;

		# datalink has not got stats
		if ( $type eq 'datalink' )
		{
			$established = undef;
			$pending     = undef;
		}
		elsif ( $status ne "down" )
		{
			require Zevenet::Net::ConnStats;
			require Zevenet::Farm::Stats;

			my $netstat;
			$netstat = &getConntrack( '', $vip, '', '', '' ) if $type !~ /^https?$/;

			$pending = &getFarmSYNConns( $name, $netstat );
			$established = &getFarmEstConns( $name, $netstat );
		}

		push @farms,
		  {
			farmname    => $name,
			profile     => $type,
			status      => $status,
			vip         => $vip,
			vport       => $port,
			established => $established,
			pending     => $pending,
		  };
	}

	if ( $eload )
	{
		@farms = @{
			&eload(
					module => 'Zevenet::RBAC::Group::Core',
					func   => 'getRBACUserSet',
					args   => ['farms', \@farms],
			)
		};
	}

	return \@farms;
}

#Get Farm Stats
sub farm_stats    # ( $farmname )
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $farmname = shift;
	if ( $farmname eq 'modules' ) { return; }
	if ( $farmname eq 'total' )   { return; }

	require Zevenet::Farm::Core;

	my $desc = "Get farm stats";

	if ( !&getFarmExists( $farmname ) )
	{
		my $msg = "The farmname $farmname does not exist.";
		&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
	}

	my $type = &getFarmType( $farmname );

	if ( $type eq "http" || $type eq "https" )
	{
		require Zevenet::Farm::HTTP::Stats;

		my $stats = &getHTTPFarmBackendsStats( $farmname );
		my $body = {
					 description => $desc,
					 backends    => $stats->{ backends },
					 sessions    => $stats->{ sessions },
		};

		&httpResponse( { code => 200, body => $body } );
	}

	if ( $type eq "l4xnat" )
	{
		my $stats    = [];
		my $sessions = [];

		require Zevenet::Farm::L4xNAT::Config;
		if ( &getL4FarmStatus( $farmname ) ne "down" )
		{
			require Zevenet::Farm::L4xNAT::Stats;
			$stats = &getL4FarmBackendsStats( $farmname );

			require Zevenet::API40::Farm::Get;
			&getAPIFarmBackends( $stats, $type, ['established', 'pending'] );

			require Zevenet::Farm::L4xNAT::Sessions;
			$sessions = &listL4FarmSessions( $farmname );
		}
		my $body = {
					 description => $desc,
					 backends    => $stats,
					 sessions    => $sessions,
		};

		&httpResponse( { code => 200, body => $body } );
	}

	if ( $type eq "gslb" && $eload )
	{
		my $gslb_stats;

		my $gslbStatus =
		  &eload(
				  module => 'Zevenet::Farm::GSLB::Config',
				  func   => 'getGSLBFarmStatus',
				  args   => [$farmname],
		  );
		if ( $gslbStatus ne "down" )
		{
			$gslb_stats = &eload(
								  module => 'Zevenet::Farm::GSLB::Stats',
								  func   => 'getGSLBFarmBackendsStats',
								  args   => [$farmname],
								  decode => 'true'
			);
		}

		my $body = {
					 description => $desc,
					 backends    => $gslb_stats->{ 'backends' } // [],
					 client      => $gslb_stats->{ 'udp' } // [],
					 server      => $gslb_stats->{ 'tcp' } // [],
					 extended    => $gslb_stats->{ 'stats' } // [],
		};

		&httpResponse( { code => 200, body => $body } );
	}
}

#Get Farm Stats
sub all_farms_stats    # ()
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $farms = &getAllFarmStats();

	my $body = {
				 description => "List all farms stats",
				 farms       => $farms,
	};

	&httpResponse( { code => 200, body => $body } );
}

#GET /stats
sub stats    # ()
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	require Zevenet::Stats;
	require Zevenet::SystemInfo;

	my @data_mem  = &getMemStats();
	my @data_load = &getLoadStats();
	my @data_net  = &getNetworkStats();
	my @data_cpu  = &getCPU();

	my $out = {
				'hostname' => &getHostname(),
				'date'     => &getDate(),
	};

	foreach my $x ( 0 .. @data_mem - 1 )
	{
		my $name  = $data_mem[$x][0];
		my $value = $data_mem[$x][1] + 0;
		$out->{ memory }->{ $name } = $value;
	}

	foreach my $x ( 0 .. @data_load - 1 )
	{
		my $name  = $data_load[$x][0];
		my $value = $data_load[$x][1] + 0;

		$name =~ s/ /_/;
		$name = 'Last_1' if $name eq 'Last';
		$out->{ load }->{ $name } = $value;
	}

	foreach my $x ( 0 .. @data_cpu - 1 )
	{
		my $name  = $data_cpu[$x][0];
		my $value = $data_cpu[$x][1] + 0;

		$name =~ s/CPU//;
		$out->{ cpu }->{ $name } = $value;
	}

	$out->{ cpu }->{ cores } = &getCpuCores();

	foreach my $x ( 0 .. @data_net - 1 )
	{
		my $name;
		if ( $x % 2 == 0 )
		{
			$name = $data_net[$x][0] . ' in';
		}
		else
		{
			$name = $data_net[$x][0] . ' out';
		}
		my $value = $data_net[$x][1] + 0;
		$out->{ network }->{ $name } = $value;
	}

	my $body = {
				 description => "System stats",
				 params      => $out
	};

	&httpResponse( { code => 200, body => $body } );
}

#GET /stats/network
sub stats_network    # ()
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	require Zevenet::Stats;
	require Zevenet::SystemInfo;

	my @interfaces = &getNetworkStats( 'hash' );
	my $output;
	$output->{ 'hostname' }   = &getHostname();
	$output->{ 'date' }       = &getDate();
	$output->{ 'interfaces' } = \@interfaces;

	my $body = {
				 description => "Network interefaces usage",
				 params      => $output
	};

	&httpResponse( { code => 200, body => $body } );
}

1;
