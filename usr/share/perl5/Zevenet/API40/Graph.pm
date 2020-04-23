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

use Zevenet::RRD;

my $eload;
if ( eval { require Zevenet::ELoad; } )
{
	$eload = 1;
}

# Supported graphs periods
my $graph_period = {
					 'daily'   => 'd',
					 'weekly'  => 'w',
					 'monthly' => 'm',
					 'yearly'  => 'y',
};

#GET disk
sub possible_graphs    #()
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	require Zevenet::Stats;

	my @farms = grep ( s/-farm$//, &getGraphs2Show( "Farm" ) );

	if ( $eload )
	{
		@farms = @{
			&eload(
					module => 'Zevenet::RBAC::Group::Core',
					func   => 'getRBACResourcesFromList',
					args   => ['farms', \@farms],
			)
		};
	}

	my @net = grep ( s/iface$//, &getGraphs2Show( "Network" ) );
	my @sys = ( "cpu", "load", "ram", "swap" );

	# Get mount point of disks
	my @mount_points;
	my $partitions = &getDiskPartitionsInfo();

	for my $key ( keys %{ $partitions } )
	{
		# mount point : root/mount_point
		push ( @mount_points, "root$partitions->{ $key }->{ mount_point }" );
	}

	@mount_points = sort @mount_points;
	push @sys, { disks => \@mount_points };

	my $body = {
		description =>
		  "These are the possible graphs, you'll be able to access to the daily, weekly, monthly or yearly graph",
		system     => \@sys,
		interfaces => \@net,
		farms      => \@farms
	};

	&httpResponse( { code => 200, body => $body } );
}

# GET all system graphs
sub get_all_sys_graphs    #()
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	require Zevenet::Stats;

	# System values
	my @sys = ( "cpu", "load", "ram", "swap" );

	# Get mount point of disks
	my @mount_points;
	my $partitions = &getDiskPartitionsInfo();

	for my $key ( keys %{ $partitions } )
	{
		# mount point : root/mount_point
		push ( @mount_points, "root$partitions->{ $key }->{ mount_point }" );
	}

	@mount_points = sort @mount_points;
	push @sys, { disk => \@mount_points };

	my $body = {
		description =>
		  "These are the possible system graphs, you'll be able to access to the daily, weekly, monthly or yearly graph",
		system => \@sys
	};

	&httpResponse( { code => 200, body => $body } );
}

# GET system graphs
sub get_sys_graphs    #()
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $key = shift;

	my $desc = "Get $key graphs";

	$key = 'mem'   if ( $key eq 'ram' );
	$key = 'memsw' if ( $key eq 'swap' );

	# Print Graph Function
	my @output;
	my $graph = &printGraph( $key, 'd' );
	push @output, { frequency => 'daily', graph => $graph };
	$graph = &printGraph( $key, 'w' );
	push @output, { frequency => 'weekly', graph => $graph };
	$graph = &printGraph( $key, 'm' );
	push @output, { frequency => 'monthly', graph => $graph };
	$graph = &printGraph( $key, 'y' );
	push @output, { frequency => 'yearly', graph => $graph };

	my $body = { description => $desc, graphs => \@output };

	&httpResponse( { code => 200, body => $body } );
}

# GET frequency system graphs
sub get_frec_sys_graphs    #()
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $key       = shift;
	my $frequency = shift;

	my $desc = "Get $frequency $key graphs";

	$key = 'mem'   if ( $key eq 'ram' );
	$key = 'memsw' if ( $key eq 'swap' );

	# take initial idenfiticative letter
	$frequency = $1 if ( $frequency =~ /^(\w)/ );

	# Print Graph Function
	my $graph = &printGraph( $key, $frequency );
	my $body = { description => $desc, graphs => $graph };

	&httpResponse( { code => 200, body => $body } );
}

# GET all interface graphs
sub get_all_iface_graphs    #()
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my @iface = grep ( s/iface$//, &getGraphs2Show( "Network" ) );
	my $body = {
		description =>
		  "These are the possible interface graphs, you'll be able to access to the daily, weekly, monthly or yearly graph",
		interfaces => \@iface
	};

	&httpResponse( { code => 200, body => $body } );
}

# GET interface graphs
sub get_iface_graphs    #()
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $iface = shift;

	require Zevenet::Net::Interface;

	my $desc              = "Get interface graphs";
	my @system_interfaces = &getInterfaceList();

	# validate NIC NAME
	if ( !grep ( /^$iface$/, @system_interfaces ) )
	{
		my $msg = "Nic interface not found.";
		&httpErrorResponse( code => 404, desc => $desc, msg => $msg );
	}

	# graph for this farm doesn't exist
	elsif ( !grep ( /${iface}iface$/, &getGraphs2Show( "Network" ) ) )
	{
		my $msg = "There is no rrd files yet.";
		&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
	}

	# Print Graph Function
	my @output;

	my $graph = &printGraph( "${iface}iface", 'd' );
	push @output, { frequency => 'daily', graph => $graph };

	$graph = &printGraph( "${iface}iface", 'w' );
	push @output, { frequency => 'weekly', graph => $graph };

	$graph = &printGraph( "${iface}iface", 'm' );
	push @output, { frequency => 'monthly', graph => $graph };

	$graph = &printGraph( "${iface}iface", 'y' );
	push @output, { frequency => 'yearly', graph => $graph };

	my $body = { description => $desc, graphs => \@output };

	&httpResponse( { code => 200, body => $body } );
}

# GET frequency interface graphs
sub get_frec_iface_graphs    #()
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $iface     = shift;
	my $frequency = shift;

	require Zevenet::Net::Interface;

	my $desc              = "Get interface graphs";
	my @system_interfaces = &getInterfaceList();

	# validate NIC NAME
	if ( !grep ( /^$iface$/, @system_interfaces ) )
	{
		my $msg = "Nic interface not found.";
		&httpErrorResponse( code => 404, desc => $desc, msg => $msg );
	}
	elsif ( !grep ( /${iface}iface$/, &getGraphs2Show( "Network" ) ) )
	{
		my $msg = "There is no rrd files yet.";
		&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
	}

	if ( $frequency =~ /^daily|weekly|monthly|yearly$/ )
	{
		if ( $frequency eq "daily" )   { $frequency = "d"; }
		if ( $frequency eq "weekly" )  { $frequency = "w"; }
		if ( $frequency eq "monthly" ) { $frequency = "m"; }
		if ( $frequency eq "yearly" )  { $frequency = "y"; }
	}

	# Print Graph Function
	my $graph = &printGraph( "${iface}iface", $frequency );
	my $body = { description => $desc, graph => $graph };

	&httpResponse( { code => 200, body => $body } );
}

# GET all farm graphs
sub get_all_farm_graphs    #()
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my @farms = grep ( s/-farm$//, &getGraphs2Show( "Farm" ) );

	if ( $eload )
	{
		my $ref_farm = &eload(
							   module => 'Zevenet::RBAC::Group::Core',
							   func   => 'getRBACResourcesFromList',
							   args   => ['farms', \@farms]
		);
		@farms = @{ $ref_farm };
	}

	my $body = {
		description =>
		  "These are the possible farm graphs, you'll be able to access to the daily, weekly, monthly or yearly graph",
		farms => \@farms
	};

	&httpResponse( { code => 200, body => $body } );
}

# GET farm graphs
sub get_farm_graphs    #()
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $farmName = shift;

	require Zevenet::Farm::Core;

	my $desc = "Get farm graphs";

	# this farm doesn't exist
	if ( !&getFarmExists( $farmName ) )
	{
		my $msg = "$farmName doesn't exist.";
		&httpErrorResponse( code => 404, desc => $desc, msg => $msg );
	}

	# graph for this farm doesn't exist
	elsif ( !grep ( /^$farmName-farm$/, &getGraphs2Show( "Farm" ) ) )
	{
		my $msg = "There are no rrd files yet.";
		&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
	}

	# Print Graph Function
	my @output;

	my $graph = &printGraph( "$farmName-farm", 'd' );
	push @output, { frequency => 'daily', graph => $graph };

	$graph = &printGraph( "$farmName-farm", 'w' );
	push @output, { frequency => 'weekly', graph => $graph };

	$graph = &printGraph( "$farmName-farm", 'm' );
	push @output, { frequency => 'monthly', graph => $graph };

	$graph = &printGraph( "$farmName-farm", 'y' );
	push @output, { frequency => 'yearly', graph => $graph };

	my $body = { description => $desc, graphs => \@output };

	&httpResponse( { code => 200, body => $body } );
}

# GET frequency farm graphs
sub get_frec_farm_graphs    #()
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $farmName  = shift;
	my $frequency = shift;

	require Zevenet::Farm::Core;

	my $desc = "Get farm graphs";

	# this farm doesn't exist
	if ( !&getFarmExists( $farmName ) )
	{
		my $msg = "$farmName doesn't exist.";
		&httpErrorResponse( code => 404, desc => $desc, msg => $msg );
	}

	# graph for this farm doesn't exist
	elsif ( !grep ( /$farmName-farm/, &getGraphs2Show( "Farm" ) ) )
	{
		my $msg = "There is no rrd files yet.";
		&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
	}

	if ( $frequency =~ /^daily|weekly|monthly|yearly$/ )
	{
		if ( $frequency eq "daily" )   { $frequency = "d"; }
		if ( $frequency eq "weekly" )  { $frequency = "w"; }
		if ( $frequency eq "monthly" ) { $frequency = "m"; }
		if ( $frequency eq "yearly" )  { $frequency = "y"; }
	}

	# Print Graph Function
	my $graph = &printGraph( "$farmName-farm", $frequency );
	my $body = { description => $desc, graph => $graph };

	&httpResponse( { code => 200, body => $body } );
}

#GET mount points list
sub list_disks    #()
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	require Zevenet::Stats;

	my @mount_points;
	my $partitions = &getDiskPartitionsInfo();

	for my $key ( keys %{ $partitions } )
	{
		# mount point : root/mount_point
		push ( @mount_points, "root$partitions->{ $key }->{ mount_point }" );
	}

	@mount_points = sort @mount_points;

	my $body = {
				 description => "List disk partitions",
				 params      => \@mount_points,
	};

	&httpResponse( { code => 200, body => $body } );
}

#GET disk graphs for all periods
sub graphs_disk_mount_point_all    #()
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $mount_point = shift;

	require Zevenet::Stats;

	$mount_point =~ s/^root[\/]?/\//;    # remove leading 'root/'
	my $desc  = "Disk partition usage graphs";
	my $parts = &getDiskPartitionsInfo();

	my ( $part_key ) =
	  grep { $parts->{ $_ }->{ mount_point } eq $mount_point } keys %{ $parts };

	unless ( $part_key )
	{
		my $msg = "Mount point not found";
		&httpErrorResponse( code => 404, desc => $desc, msg => $msg );
	}

	my $dev_id = $parts->{ $part_key }->{ rrd_id };
	my @graphs = (
				   { frequency => 'daily',   graph => &printGraph( $dev_id, 'd' ) },
				   { frequency => 'weekly',  graph => &printGraph( $dev_id, 'w' ) },
				   { frequency => 'monthly', graph => &printGraph( $dev_id, 'm' ) },
				   { frequency => 'yearly',  graph => &printGraph( $dev_id, 'y' ) },
	);
	my $body = {
				 description => $desc,
				 graphs      => \@graphs,
	};

	&httpResponse( { code => 200, body => $body } );
}

#GET disk graph for a single period
sub graph_disk_mount_point_freq    #()
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $mount_point = shift;
	my $frequency   = shift;

	require Zevenet::Stats;

	my $desc  = "Disk partition usage graph";
	my $parts = &getDiskPartitionsInfo();
	$mount_point =~ s/^root[\/]?/\//;

	my ( $part_key ) =
	  grep { $parts->{ $_ }->{ mount_point } eq $mount_point } keys %{ $parts };

	unless ( $part_key )
	{
		my $msg = "Mount point not found";
		&httpErrorResponse( code => 404, desc => $desc, msg => $msg );
	}

	my $dev_id = $parts->{ $part_key }->{ rrd_id };
	my $freq   = $graph_period->{ $frequency };
	my $body = {
				 description => $desc,
				 frequency   => $frequency,
				 graph       => &printGraph( $dev_id, $freq ),
	};

	&httpResponse( { code => 200, body => $body } );
}

1;

