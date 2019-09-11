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

my $ip_bin = &getGlobalConfiguration( 'ip_bin' );

=begin nd
Function: writeRoutes

	Sets a routing table id and name pair in rt_tables file.

	Only required setting up a routed interface. Complemented in delIf()

Parameters:
	if_name - network interface name.

Returns:
	undef - .
=cut

# create table route identification, complemented in delIf()
sub writeRoutes    # ($if_name)
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $if_name = shift;

	my $rttables = &getGlobalConfiguration( 'rttables' );

	open my $rt_fd, '<', $rttables;
	my @contents = <$rt_fd>;
	close $rt_fd;

	if ( grep /^...\ttable_$if_name$/, @contents )
	{
		# the table is already in the file, nothig to do
		return;
	}

	my $found = "false";
	my $rtnumber;

	# Find next table number available
	for ( my $i = 200 ; $i < 1000 && $found eq "false" ; $i++ )
	{
		next if ( grep /^$i\t/, @contents );

		$found    = "true";
		$rtnumber = $i;
	}

	if ( $found eq "true" )
	{
		open ( my $rt_fd, ">>", "$rttables" );
		print $rt_fd "$rtnumber\ttable_$if_name\n";
		close $rt_fd;
	}

	return;
}

=begin nd
Function: addlocalnet

	Set routes to interface subnet into interface routing tables and fills the interface table.

Parameters:
	if_ref - network interface hash reference.

Returns:
	void - .

See Also:
	Only used here: <applyRoutes>
=cut

# add local network into routing table
sub addlocalnet    # ($if_ref)
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $if_ref = shift;

	&zenlog(
		"addlocalnet( name: $$if_ref{ name }, addr: $$if_ref{ addr }, mask: $$if_ref{ mask } )",
		"debug", "NETWORK"
	) if &debug();

	# Get network
	use NetAddr::IP;
	my $ip = new NetAddr::IP( $$if_ref{ addr }, $$if_ref{ mask } );
	my $net = $ip->network();

	# Get params
	my $routeparams = &getGlobalConfiguration( 'routeparams' );

	# Add or replace local net to all tables
	my @links = ( 'main', &getLinkNameList() );

	foreach my $link ( @links )
	{
		next if $link eq 'lo';
		next if $link eq 'cl_maintenance';

		my $table = 'main';

		if ( $link ne 'main' )
		{
			$table = "table_$link";
			my $if_ref = getInterfaceConfig( $link );

			# ignores interfaces down or not configured
			next if $if_ref->{ status } ne 'up';
			next if !defined $if_ref->{ addr };
		}

		&zenlog( "addlocalnet: setting route in table $table", "debug", "NETWORK" )
		  if &debug();

		my $ip_cmd =
		  "$ip_bin -$$if_ref{ip_v} route replace $net dev $$if_ref{name} src $$if_ref{addr} table $table $routeparams";

		&logAndRun( $ip_cmd );
	}

	# Include all routing into the current interface, in case it is new and empty
	my @ifaces = @{ &getConfigInterfaceList() };

	foreach my $iface ( @ifaces )
	{
		next if $iface->{ type } eq 'virtual';
		next if $iface->{ is_slave } eq 'true';    # Is in bonding iface
		next
		  if (   !defined $iface->{ addr }
			   or length $iface->{ addr } == 0 );    #IP addr doesn't exist
		next if $iface->{ name } eq $if_ref->{ name };
		&zenlog(
			   "addlocalnet: into current interface: name $$iface{name} type $$iface{type}",
			   "debug", "NETWORK" )
		  if &debug();

		my $ip    = new NetAddr::IP( $$iface{ addr }, $$iface{ mask } );
		my $net   = $ip->network();
		my $table = "table_$$if_ref{ name }";

		my $ip_cmd =
		  "$ip_bin -$$iface{ip_v} route replace $net dev $$iface{name} src $$iface{addr} table $table $routeparams";

		&logAndRun( $ip_cmd );
	}

	return;
}

=begin nd
Function: isRule

	Check if routing rule for the given table, from or fwmark exists.

Parameters:
	table - rule lookup table match, only filters if it's defined and not empty.
	from - rule from match, only filters if it's defined and not empty.
	fwmark - rule fwmark match, only filters if it's defined and not empty.
	iplist - array with the complete system rule listing.

Returns:
	scalar - number of times the rule was found. True if found.

Bugs:
	Rules for Datalink farms are included.

=cut

sub isRule
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $table  = shift;
	my $from   = shift;
	my $fwmark = shift;
	my $iplist = shift;

	$table  = "lookup $table"   if ( defined $table  && $table ne "" );
	$from   = "from $from "     if ( defined $from   && $from ne "" );
	$fwmark = "fwmark $fwmark " if ( defined $fwmark && $fwmark ne "" );

	my $exist = grep /$from$fwmark$table/, @{ $iplist };

	return $exist;
}

=begin nd
Function: applyRule

	Add or delete the rule according to the given parameters.

Parameters:
	ipv - ip version.
	action - "add" to create a new rule or "del" to remove it.
	table - rule lookup attribute.
	from - rule from attribute. This is optional.
	fwmark - rule fwmark optional attribute. This is optional.

Returns:
	integer - ip command return code.

Bugs:
	Rules for Datalink farms are included.
=cut

sub applyRule
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $ipv    = shift;
	my $action = shift;
	my $table  = shift;
	my $from   = shift;
	my $fwmark = shift;

	my $output = 0;

	return -1 if ( $table eq "" );

	my $prio_id = "28000";

	$from = "from $from" if ( defined $from && $from ne "" );
	$fwmark = "fwmark $fwmark prio $prio_id"
	  if ( defined $fwmark && $fwmark ne "" );

	$output =
	  &logAndRun( "$ip_bin -$ipv rule $action $from $fwmark lookup $table" );

	return $output;
}

=begin nd
Function: setRule

	Check and then apply action to add or delete the rule according to the parameters.

Parameters:
	action - "add" to create a new rule or "del" to remove it.
	if_ref - interface reference or empty. This will be used if $ifname or $from are undefined.
	ifname - rule lookup table interface name, undef to refer to the if_ref name or empty to avoid matching.
	from - rule from attribute, undef to refer to the if_ref network data or empty to avoid matching.
	fwmark - rule fwmark attribute, undef or empty to avoid matching.

Returns:
	integer - ip command return code.

Bugs:
	Rules for Datalink farms are included.
=cut

sub setRule
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $action = shift;
	my $if_ref = shift;
	my $ifname = shift;
	my $from   = shift;
	my $fwmark = shift;

	my $output = 0;
	my $isrule = 0;
	my $table  = "";
	my $ipv    = "4";

	$ipv = $if_ref->{ ip_v } if ( defined $if_ref );

	return -1 if ( $action != /add|del/ );
	return -1 if ( defined $fwmark && $fwmark =~ /^0x0$/ );

	$ifname = $if_ref->{ name } if ( !defined $ifname );
	$table  = "table_$ifname"   if ( $ifname ne "" );

	my @iplist = `$ip_bin -$ipv rule list`;

	if ( defined $from )
	{
		$isrule = &isRule( $table, $from, $fwmark, \@iplist );
	}
	else
	{
		$isrule =
		  &isRule( $table, "$if_ref->{ net }/$if_ref->{ mask }", $fwmark, \@iplist )
		  || &isRule( $table, NetAddr::IP->new( $if_ref->{ net }, $if_ref->{ mask } ),
					  $fwmark, \@iplist );
	}

	if (    ( $action eq "add" && $isrule == 0 )
		 || ( $action eq "del" && $isrule != 0 ) )
	{
		$output =
		  &applyRule( $ipv, $action, $table,
					  ( defined $from ) ? $from : "$if_ref->{ net }/$if_ref->{ mask }",
					  $fwmark );
	}

	return $output;
}

=begin nd
Function: applyRoutes

	Apply routes for interface or default gateway.

	For "local" table set route for interface.
	For "global" table set route for default gateway and save the default
	gateway in global configuration file.

Parameters:
	table - "local" for interface routes or "global" for default gateway route.
	if_ref - network interface hash reference.
	gateway - Default gateway. Only required if table parameter is "global".

Returns:
	integer - ip command return code.

See Also:
	<delRoutes>
=cut

# apply routes
sub applyRoutes    # ($table,$if_ref,$gateway)
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my ( $table, $if_ref, $gateway ) = @_;
	my $if_announce = "";

	# $gateway: The 3rd argument, '$gateway', is only used for 'global' table,
	#           to assign a default gateway.

	my $status = 0;

	return 0 if ( $$if_ref{ ip_v } != 4 and $$if_ref{ ip_v } != 6 );

	unless ( $$if_ref{ net } )
	{
		require Zevenet::Net::Interface;
		$$if_ref{ net } =
		  &getAddressNetwork( $$if_ref{ addr }, $$if_ref{ mask }, $$if_ref{ ip_v } );
	}

	# not virtual interface
	if ( !defined $$if_ref{ vini } || $$if_ref{ vini } eq '' )
	{
		if ( $table eq "local" )
		{
			&zenlog(
				"Applying $table routes in stack IPv$$if_ref{ip_v} to $$if_ref{name} with gateway \"$$if_ref{gateway}\"",
				"info", "NETWORK"
			);

			# &delRoutes( "local", $if );
			&addlocalnet( $if_ref );

			if ( $$if_ref{ gateway } )
			{
				my $routeparams = &getGlobalConfiguration( 'routeparams' );
				my $ip_cmd =
				  "$ip_bin -$$if_ref{ip_v} route replace default via $$if_ref{gateway} dev $$if_ref{name} table table_$$if_ref{name} $routeparams";
				$status = &logAndRun( "$ip_cmd" );
			}

			$status = &setRule( "add", $if_ref, undef, undef, undef );
		}
		else
		{
			# Apply routes on the global table
			# &delRoutes( "global", $if );
			if ( $gateway )
			{
				my $routeparams = &getGlobalConfiguration( 'routeparams' );

				my $action            = "replace";
				my $system_default_gw = &getDefaultGW();
				if ( $system_default_gw eq "" )
				{
					$action = "add";
				}
				&zenlog(
						 "Applying $table routes in stack IPv$$if_ref{ip_v} with gateway \""
						   . &getGlobalConfiguration( 'defaultgw' ) . "\"",
						 "info", "NETWORK"
				);
				my $ip_cmd =
				  "$ip_bin -$$if_ref{ip_v} route $action default via $gateway dev $$if_ref{name} $routeparams";
				$status = &logAndRun( "$ip_cmd" );

				if ( $$if_ref{ ip_v } == 6 )
				{
					&setGlobalConfiguration( 'defaultgw6',   $gateway );
					&setGlobalConfiguration( 'defaultgwif6', $$if_ref{ name } );
				}
				else
				{
					&setGlobalConfiguration( 'defaultgw',   $gateway );
					&setGlobalConfiguration( 'defaultgwif', $$if_ref{ name } );
				}

				require Zevenet::Farm::Config;
				&reloadFarmsSourceAddress() if $status == 0;
			}
		}
		$if_announce = $$if_ref{ name };
	}

	# virtual interface
	else
	{
		my ( $toif ) = split ( /:/, $$if_ref{ name } );
		$status = &setRule( "add", $if_ref, $toif, undef, undef );
		$if_announce = $toif;
	}

	#if arp_announce is enabled then send garps to network
	eval {
		if ( $eload )
		{
			my $cl_status = &eload(
									module => 'Zevenet::Cluster',
									func   => 'getZClusterNodeStatus',
									args   => [],
			);

			if (    &getGlobalConfiguration( 'arp_announce' ) eq "true"
				 && $cl_status ne "backup" )
			{
				require Zevenet::Net::Util;

				#&sendGArp($$if_ref{parent},$$if_ref{addr})
				&zenlog( "Announcing garp $if_announce and $$if_ref{addr} " );
				&sendGArp( $if_announce, $$if_ref{ addr } );
			}

		}

	};

	return $status;
}

=begin nd
Function: delRoutes

	Delete routes for interface or default gateway.

	For "local" table remove route for interface.
	For "global" table remove route for default gateway and removes the
	default gateway in global configuration file.

Parameters:
	table - "local" for interface routes or "global" for default gateway route.
	if_ref - network interface hash reference.

Returns:
	integer - ip command return code.

See Also:
	<applyRoutes>
=cut

# delete routes
sub delRoutes    # ($table,$if_ref)
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my ( $table, $if_ref ) = @_;

	my $status = 0;

	&zenlog(
			 "Deleting $table routes for IPv$$if_ref{ip_v} in interface $$if_ref{name}",
			 "info", "NETWORK" );

	if ( !defined $$if_ref{ vini } || $$if_ref{ vini } eq '' )
	{
		if ( $table eq "local" )
		{
			my $ip_cmd = "$ip_bin -$$if_ref{ip_v} route flush table table_$$if_ref{name}";
			$status = &logAndRun( "$ip_cmd" );

			$status = &setRule( "del", $if_ref, undef, undef, undef );
			return $status;
		}
		else
		{
			# Delete routes on the global table
			my $ip_cmd = "$ip_bin -$$if_ref{ip_v} route del default";
			$status = &logAndRun( "$ip_cmd" );

			require Tie::File;
			tie my @contents, 'Tie::File', &getGlobalConfiguration( 'globalcfg' );
			for my $line ( @contents )
			{
				if ( grep /^\$defaultgw/, $line )
				{
					if ( $$if_ref{ ip_v } == 6 )
					{
						$line =~ s/^\$defaultgw6=.*/\$defaultgw6=\"\"\;/g;
						$line =~ s/^\$defaultgwif6=.*/\$defaultgwif6=\"\"\;/g;
					}
					else
					{
						$line =~ s/^\$defaultgw=.*/\$defaultgw=\"\"\;/g;
						$line =~ s/^\$defaultgwif=.*/\$defaultgwif=\"\"\;/g;
					}
				}
			}
			untie @contents;

			require Zevenet::Farm::Config;
			&reloadFarmsSourceAddress() if $status == 0;

			return $status;
		}
	}

	return $status;
}

=begin nd
Function: getDefaultGW

	Get system or interface default gateway.

Parameters:
	if - interface name. Optional.

Returns:
	scalar - Gateway IP address.

See Also:
	<getIfDefaultGW>
=cut

# get default gw for interface
sub getDefaultGW    # ($if)
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $if = shift;    # optional argument

	my @line;
	my @defgw;
	my $gw;
	my @routes = "";

	if ( $if )
	{
		my $cif = $if;
		if ( $if =~ /\:/ )
		{
			my @iface = split ( /\:/, $cif );
			$cif = $iface[0];
		}

		open ( my $rt_fd, '<', &getGlobalConfiguration( 'rttables' ) );

		if ( grep { /^...\ttable_$cif$/ } <$rt_fd> )
		{
			@routes = `$ip_bin route list table table_$cif`;
		}

		close $rt_fd;
		@defgw = grep ( /^default/, @routes );
		@line = split ( / /, $defgw[0] );
		$gw = $line[2];
		return $gw;
	}
	else
	{
		@routes = `$ip_bin route list`;
		@defgw  = grep ( /^default/, @routes );
		@line   = split ( / /, $defgw[0] );
		$gw     = $line[2];
		return $gw;
	}
}

=begin nd
Function: getIPv6DefaultGW

	Get system IPv6 default gateway.

Parameters:
	none - .

Returns:
	scalar - IPv6 default gateway address.

See Also:
	<getDefaultGW>, <getIPv6IfDefaultGW>
=cut

sub getIPv6DefaultGW    # ()
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my @routes = `$ip_bin -6 route list`;
	my ( $default_line ) = grep { /^default/ } @routes;

	my $default_gw;
	if ( $default_line )
	{
		$default_gw = ( split ( ' ', $default_line ) )[2];
	}

	return $default_gw;
}

=begin nd
Function: getIPv6IfDefaultGW

	Get network interface to IPv6 default gateway.

Parameters:
	none - .

Returns:
	scalar - Interface to IPv6 default gateway.

See Also:
	<getIPv6DefaultGW>, <getIfDefaultGW>
=cut

sub getIPv6IfDefaultGW    # ()
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my @routes = `$ip_bin -6 route list`;
	my ( $default_line ) = grep { /^default/ } @routes;

	my $if_default_gw;
	if ( $default_line )
	{
		$if_default_gw = ( split ( ' ', $default_line ) )[4];
	}

	return $if_default_gw;
}

=begin nd
Function: getIfDefaultGW

	Get network interface to default gateway.

Parameters:
	none - .

Returns:
	scalar - Interface to default gateway address.

See Also:
	<getDefaultGW>, <getIPv6IfDefaultGW>
=cut

# get interface for default gw
sub getIfDefaultGW    # ()
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my @routes = `$ip_bin route list`;
	my @defgw  = grep ( /^default/, @routes );
	my @line   = split ( / /, $defgw[0] );

	return $line[4];
}

=begin nd
Function: configureDefaultGW

	Setup the configured default gateway (for IPv4 and IPv6).

Parameters:
	none - .

Returns:
	none - .

See Also:
	zevenet
=cut

# from bin/zevenet, almost exactly
sub configureDefaultGW    #()
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $defaultgw    = &getGlobalConfiguration( 'defaultgw' );
	my $defaultgwif  = &getGlobalConfiguration( 'defaultgwif' );
	my $defaultgw6   = &getGlobalConfiguration( 'defaultgw6' );
	my $defaultgwif6 = &getGlobalConfiguration( 'defaultgwif6' );

	# input: global variables $defaultgw and $defaultgwif
	if ( $defaultgw && $defaultgwif )
	{
		my $if_ref = &getInterfaceConfig( $defaultgwif, 4 );
		if ( $if_ref )
		{
			print "Default Gateway:$defaultgw Device:$defaultgwif\n";
			&applyRoutes( "global", $if_ref, $defaultgw );
		}
	}

	# input: global variables $$defaultgw6 and $defaultgwif6
	if ( $defaultgw6 && $defaultgwif6 )
	{
		my $if_ref = &getInterfaceConfig( $defaultgwif, 6 );
		if ( $if_ref )
		{
			print "Default Gateway:$defaultgw6 Device:$defaultgwif6\n";
			&applyRoutes( "global", $if_ref, $defaultgw6 );
		}
	}
}

1;
