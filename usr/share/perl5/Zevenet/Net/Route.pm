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
use Zevenet::Core;


my $ip_bin = &getGlobalConfiguration( 'ip_bin' );

=begin nd
Function: writeRoutes

	It sets a routing table id and name pair in rt_tables file.

	Only required setting up a routed interface. Complemented in delIf()

Parameters:
	if_name - network interface name.

Returns:
	undef - .
=cut

# create table route identification, complemented in delIf()
sub writeRoutes    # ($if_name)
{
	&zenlog( __FILE__ . q{:} . __LINE__ . q{:} . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $if_name = shift;

	my $rttables = &getGlobalConfiguration( 'rttables' );

	&zenlog( "Creating table 'table_$if_name'", "debug" );

	open my $rt_fd, '<', $rttables;
	my @contents = <$rt_fd>;
	close $rt_fd;

	if ( grep { /^...\ttable_$if_name$/ } @contents )
	{
		# the table is already in the file, nothig to do
		return;
	}

	my $found = "false";
	my $rtnumber;

	# Find next table number available
	for ( my $i = 200 ; $i < 1000 and $found eq "false" ; $i++ )
	{
		next if ( grep { /^$i\t/ } @contents );

		$found    = "true";
		$rtnumber = $i;
	}

	if ( $found eq "true" )
	{
		open ( my $rt_fd, ">>", "$rttables" );
		print $rt_fd "$rtnumber\ttable_$if_name\n";
		close $rt_fd;

		&zenlog( "Created the table ID 'table_$if_name'", "info", "network" );
	}

	return;
}

=begin nd
Function: deleteRoutesTable

	It removes the a routing table id and name pair from the rt_tables file.

Parameters:
	if_name - network interface name.

Returns:
	none - .
=cut

sub deleteRoutesTable
{
	&zenlog( __FILE__ . q{:} . __LINE__ . q{:} . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $if_name = shift;

	my $rttables = &getGlobalConfiguration( 'rttables' );

	open my $rt_fd, '<', $rttables;
	my @contents = <$rt_fd>;
	close $rt_fd;

	@contents = grep { not /\ttable_$if_name\n/ } @contents;

	open my $rt_fd2, '>', $rttables;
	foreach my $table ( @contents )
	{
		print $rt_fd2 $table;
	}
	close $rt_fd2;
	return;
}

=begin nd
Function: applyRoutingCmd

	It creates the command to add a routing entry in a table.

	Depend on the passed parameter, it can delete, add or replace the route

Parameters:
	action - it is the action to apply: add, replace or del
	if_ref - network interface hash reference
	table - it is the routing table where the entry will be added

Returns:
	Integer - Error code, it is 0 on success or another value on

TODO:
	use the 'buildRouteCmd' function

=cut

sub applyRoutingCmd
{
	my $action = shift;
	my $if_ref = shift;
	my $table  = shift;

	# Get params
	my $routeparams = &getGlobalConfiguration( 'routeparams' );
	use NetAddr::IP;
	my $ip_local = NetAddr::IP->new( $$if_ref{ addr }, $$if_ref{ mask } );
	my $net_local = $ip_local->network();

	&zenlog( "addlocalnet: $action route for $$if_ref{name} in table $table",
			 "debug", "NETWORK" )
	  if &debug();

	my $ip_cmd =
	  "$ip_bin -$$if_ref{ip_v} route $action $net_local dev $$if_ref{name} src $$if_ref{addr} table $table $routeparams";

	my $err = &logAndRun( $ip_cmd );
	return $err;
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

sub addlocalnet    # ($if_ref)
{
	&zenlog( __FILE__ . q{:} . __LINE__ . q{:} . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $if_ref = shift;

	&zenlog(
		"addlocalnet( name: $$if_ref{ name }, addr: $$if_ref{ addr }, mask: $$if_ref{ mask } )",
		"debug", "NETWORK"
	) if &debug();

	# Get network
	use NetAddr::IP;
	my $ip_local = NetAddr::IP->new( $$if_ref{ addr }, $$if_ref{ mask } );
	my $net_local = $ip_local->network();

	# Add or replace local net to all tables
	my @links = ( 'main', &getLinkNameList() );

	my @isolates = ();

	# filling the other tables
	foreach my $link ( @links )
	{
		my $skip_route = 0;
		next if $link eq 'lo';
		next if $link eq 'cl_maintenance';

		my $table = ( $link eq 'main' ) ? 'main' : "table_$link";

		if ( grep { /^(?:\*|$table)$/ } @isolates )
		{
			$skip_route = 1;
		}
		elsif ( $link ne 'main' )
		{
			my $iface = &getInterfaceConfig( $link );

			# ignores interfaces down or not configured
			next if $iface->{ status } ne 'up';
			next if not defined $iface->{ addr };

			#if duplicated network, next
			my $ip_table =
			  NetAddr::IP->new( $$iface{ addr }, $$iface{ mask } );
			my $net_local_table = $ip_table->network();

			if ( $net_local_table eq $net_local and $$if_ref{ name } ne $link )
			{
				&zenlog(
					"The network $net_local of dev $$if_ref{name} is the same than the network for $link, route is not going to be applied in table $table",
					"error", "network"
				);
				$skip_route = 1;
			}
		}

		if ( not $skip_route )
		{
			&applyRoutingCmd( 'replace', $if_ref, $table );
		}
	}

	# filling the own table
	my @ifaces = @{ &getConfigInterfaceList() };
	foreach my $iface ( @ifaces )
	{
		next if $iface->{ name } eq $if_ref->{ name };
		my $iface_sys = &getSystemInterface( $iface->{ name } );

		next if $iface_sys->{ status } ne 'up';
		next if $iface->{ type } eq 'virtual';
		next if $iface->{ is_slave } eq 'true';    # Is in bonding iface

		next
		  if ( not defined $iface->{ addr }
			   or length $iface->{ addr } == 0 );    #IP addr doesn't exist
		next if ( not &isIp( $iface ) );

		# do not import the iface route if it is isolate
		my @isolates = ();
		next if ( grep { /^(?:\*|table_$$if_ref{name})$/ } @isolates );

		&zenlog(
			   "addlocalnet: into current interface: name $$iface{name} type $$iface{type}",
			   "debug", "NETWORK" );

		#if duplicated network, next
		my $ip    = NetAddr::IP->new( $$iface{ addr }, $$iface{ mask } );
		my $net   = $ip->network();
		my $table = "table_$$if_ref{ name }";

		if ( $net eq $net_local and $$iface{ name } ne $$if_ref{ name } )
		{
			&zenlog(
				"The network $net of dev $$iface{name} is the same than the network for $$if_ref{name}, the route is not going to be applied in table $table",
				"error", "network"
			);
			next;
		}

		&applyRoutingCmd( 'replace', $iface, $table );
	}

	use Zevenet::Net::Core;
	&setRuleIPtoTable( $$if_ref{ name }, $$if_ref{ addr }, "add" );

	return;
}

=begin nd
Function: dellocalnet

	Remove the input interface of the other routing tables.
	It removes the interfaces own table too.
	It removes the custom routes too.

Parameters:
	if_ref - network interface hash reference.

Returns:
	none - .

=cut

sub dellocalnet    # ($if_ref)
{
	&zenlog( __FILE__ . q{:} . __LINE__ . q{:} . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $if_ref = shift;

	if ( defined $$if_ref{ addr } )
	{

		# Get network
		use NetAddr::IP;
		my $ip = NetAddr::IP->new( $$if_ref{ addr }, $$if_ref{ mask } );
		my $net = $ip->network();

		my @links = ( 'main', &getLinkNameList() );
		my @rtables_id = &listRoutingTablesNames();

		foreach my $link ( @links )
		{
			next if $link eq 'lo';
			next if $link eq 'cl_maintenance';

			my $table = ( $link eq 'main' ) ? "main" : "table_$link";

			next if ( not grep { /^$table$/ } @rtables_id );

# TODO: use the function 'buildRouteCmd' to create this command and use it here and with 'applyRoutingCmd'
			my $cmd_param = "$net dev $$if_ref{name} src $$if_ref{addr} table $table";

			next if ( not &isRoute( $cmd_param, $$if_ref{ ip_v } ) );

			&applyRoutingCmd( 'del', $if_ref, $table );
		}
	}
	return;
}

=begin nd
Function: isRoute

	Checks if any of the routes applied to the system matchs according to the input parameters.
	It receives the ip route command line options and it checks the system. Example. "src 1.1.12.5 dev eth3 table table_eth3".

Parameters:
	route - command line options for the "ip route list" command.
	ip_version - version used for the ip command. If this parameter is not used, the command will be executed without this flag

Returns:
	Integer - It returns 1 if any applied rule matchs, or 0 if not

=cut

sub isRoute
{
	&zenlog( __FILE__ . q{:} . __LINE__ . q{:} . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );

	my $route = shift;
	my $ipv = shift // '';

	$ipv = "-$ipv" if ( $ipv ne '' );
	my $exist = 1;

	my $ip_cmd = "$ip_bin $ipv route list $route";
	my $out    = &logAndGet( "$ip_cmd" );

	if ( $out eq '' )
	{
		$exist = 0;
	}
	else
	{
		require Zevenet::Validate;
		my $ip_re = &getValidFormat( 'ipv4v6' );
		$exist = 0 if ( $exist and $route !~ /src $ip_re/ and $out =~ /src $ip_re/ );
	}

	if ( &debug() > 1 )
	{
		my $msg = ( $exist ) ? "(Already exist)" : "(Not found)";
		$msg .= " $ip_cmd";
		&zenlog( $msg, "debug", "net" );
	}

	return $exist;
}

=begin nd
Function: existRoute

	Checks if any of the paths applied to the system has same properties to the input.
	It receives the ip route command line options and it checks the system. Example. "src 1.1.12.5 dev eth3 table table_eth3".

Parameters:
	route - command line options for the "ip route list" command.
	via   - 1 to check via
	src   - 1 to check via

Returns:
	Integer - It returns 1 if any applied rule matchs, or 0 if not

=cut

sub existRoute
{
	&zenlog( __FILE__ . q{:} . __LINE__ . q{:} . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );

	my $route = shift;
	my $via   = shift;
	my $src   = shift;

	require Zevenet::Validate;
	my $ip_re = &getValidFormat( 'ipv4v6' );
	$route =~ s/via ($ip_re)// unless $via;
	$route =~ s/src ($ip_re)// unless $src;

	my $ip_cmd = "$ip_bin route list $route";
	my $out    = &logAndGet( "$ip_cmd" );
	my $exist  = ( $out eq '' ) ? 0 : 1;

	return $exist;
}

=begin nd
Function: buildRuleCmd

	It creates the command line for a routing directive.

Parameters:
	action - it is the action to apply, 'add' to create a new routing entry, 'del' to delete the requested routing entry or 'undef' to create the parameters wihout adding the 'ip route <action>'
	conf - It is a hash referece with the parameters expected to build the command. The options are:
		ip_v : is the ip version for the route
		priority : is the priority which the route will be execute. Lower priority will be executed before
		not : is the NOT logical operator
		from : is the source address or networking segment from is comming the request
		to : is the destination address or networking segment the request is comming to
		fwmark : is the traffic mark of the packet
		lookup : is the routing table where is going to be added the route

Returns:
	String - It is the command line string to execute in the system

=cut

sub buildRuleCmd
{
	&zenlog( __FILE__ . q{:} . __LINE__ . q{:} . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );

	my $action = shift;
	my $conf   = shift;
	my $cmd    = "";

	my $ipv = ( exists $conf->{ ip_v } ) ? "-$conf->{ip_v}" : "";

# ip rule { add | del } [ priority PRIO ] [ not ] from IP/NETMASK [ to IP/NETMASK ] [ fwmark FW_MARK ] lookup TABLE_ID
	$cmd .= "$ip_bin $ipv rule $action" if ( defined $action );
	if (     ( defined $action and $action ne 'list' )
		 and ( exists $conf->{ priority } and $conf->{ priority } =~ /\d/ ) )
	{
		$cmd .= " priority $conf->{priority} ";
	}
	$cmd .= " not" if ( exists $conf->{ not } and $conf->{ not } eq 'true' );
	$cmd .= " from $conf->{from}";
	$cmd .= " to $conf->{to}"
	  if ( exists $conf->{ to } and $conf->{ to } ne "" );
	$cmd .= " fwmark $conf->{fwmark}"
	  if ( exists $conf->{ fwmark } and $conf->{ fwmark } ne "" );
	$cmd .= " lookup $conf->{table}";

	return $cmd;
}

=begin nd
Function: isRule

	Check if routing rule for the given table, from or fwmark exists.

Parameters:
	conf - Rule hash reference.

Returns:
	scalar - number of times the rule was found. True if found.

Todo:
	Rules for Datalink farms are included.

=cut

sub isRule
{
	&zenlog( __FILE__ . q{:} . __LINE__ . q{:} . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $conf = shift;

	my $ipv = ( exists $conf->{ ip_v } ) ? "-$conf->{ip_v}" : "";

	my $cmd  = "$ip_bin $ipv rule list";
	my $rule = "";
	$rule .= " not" if ( exists $conf->{ not } and $conf->{ not } eq 'true' );
	my ( $net, $netmask ) = split /\//, $conf->{ from };
	if ( defined $netmask
		 and ( $netmask eq "32" or $netmask eq "255.255.255.255" ) )
	{
		$rule .= " from $net";
	}
	else
	{
		$rule .= " from $conf->{from}";
	}
	$rule .= " to $conf->{to}"
	  if ( exists $conf->{ to } and $conf->{ to } ne "" );
	$rule .= " fwmark $conf->{fwmark}"
	  if ( exists $conf->{ fwmark } and $conf->{ fwmark } ne "" );
	$rule .= " lookup $conf->{table}";
	$rule =~ s/^\s+//;
	$rule =~ s/\s+$//;

	my @out = @{ &logAndGet( $cmd, 'array' ) };
	chomp @out;

	my $exist = ( grep { /^\d+:\s*$rule\s*$/ } @out ) ? 1 : 0;

	if ( &debug() > 1 )
	{
		my $msg = ( $exist ) ? "(Already exist)" : "(Not found)";
		$msg .= " $cmd";
		&zenlog( $msg, "debug", "net" );
	}

	return $exist;
}

=begin nd
Function: applyRule

	Add or delete the rule according to the given parameters.

Parameters:
	action - "add" to create a new rule or "del" to remove it.
	rule - Rule hash reference.

Returns:
	integer - ip command return code.

Bugs:
	Rules for Datalink farms are included.
=cut

sub applyRule
{
	&zenlog( __FILE__ . q{:} . __LINE__ . q{:} . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );

	my $action = shift;
	my $rule   = shift;

	return -1 if ( $rule->{ table } eq "" );

	if ( $rule->{ priority } eq '' and $action eq 'add' )
	{
		$rule->{ priority } = &genRoutingRulesPrio( $rule->{ type } );
	}

	my $cmd = &buildRuleCmd( $action, $rule );
	my $output = &logAndRun( "$cmd" );

	return $output;
}

=begin nd
Function: genRoutingRulesPrio

	Create a priority according to the type of route is going to be created

Parameters:
	Type - type of route, the possible values are:
		'iface' for the default interface routes,
		'l4xnat' for the l4xnat backend routes,
		'http or https' for the L7 backend routes,
		'farm-datalink' for the rules applied by datalink farms,
		'user' for the customized routes created for the user,
		'vpn' for the routes applied by vpn connections

Returns:
	Integer - Priority for the route
=cut

sub genRoutingRulesPrio
{
	&zenlog( __FILE__ . q{:} . __LINE__ . q{:} . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );

	my $type = shift;    # user, farm, ifaces

	# The maximun priority value in the system is '32766'
	my $farmL4       = &getGlobalConfiguration( 'routingRulePrioFarmL4' );
	my $farmDatalink = &getGlobalConfiguration( 'routingRulePrioFarmDatalink' );
	my $userInit     = &getGlobalConfiguration( 'routingRulePrioUserMin' );
	my $userEnd      = &getGlobalConfiguration( 'routingRulePrioUserMax' ) + 1;
	my $ifacesInit   = &getGlobalConfiguration( 'routingRulePrioIfaces' );

	my $min;
	my $max;

	# l4xnat farm rules
	if ( $type eq 'l4xnat' or $type eq 'http' or $type eq 'https' )
	{
		$min = $farmL4;
		$max = $farmDatalink;
	}

	# datalink farm rules
	elsif ( $type eq 'farm-datalink' )
	{
		$min = $farmDatalink;
		$max = $userInit;
	}

	# custom rules
	elsif ( $type eq 'user' )
	{
		$min = $userInit;
		$max = $userEnd;
	}

	# iface rules
	else
	{
		return $ifacesInit;
	}

	my $prio;
	my $prioList = &listRoutingRulesPrio();
	for ( $prio = $max - 1 ; $prio >= $min ; $prio-- )
	{
		last if ( not grep { /^$prio$/ } @{ $prioList } );
	}

	return $prio;
}

=begin nd
Function: listRoutingRulesPrio

	List the priority of the rules that are currently applied in the system

Parameters:
	None - .

Returns:
	Array ref - list of priorities
=cut

sub listRoutingRulesPrio
{
	&zenlog( __FILE__ . q{:} . __LINE__ . q{:} . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );

	my $rules = &listRoutingRules();
	my @list;

	foreach my $r ( @{ $rules } )
	{
		push @list, $r->{ priority };
	}

	@list = sort @list;
	return \@list;
}

=begin nd
Function: getRuleFromIface

	It returns a object with the routing parameters that are needed for creating the default route of an interface.

Parameters:
	Interface - name of the interace

Returns:
	Hash ref -
		{
			table => "table_eth3",	# table where creating the entry
			type => 'iface',					# type of route rule
			from => 15.255.25.2/24,						# networking segement of the interface
		}
=cut

sub getRuleFromIface
{
	&zenlog( __FILE__ . q{:} . __LINE__ . q{:} . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );

	my $if_ref = shift;
	my $from   = "";
	if ( defined ( $if_ref->{ net } ) and $if_ref->{ net } ne '' )
	{
		$from =
		  ( $if_ref->{ mask } =~ /^\d$/ )
		  ? "$if_ref->{ net }/$if_ref->{ mask }"
		  : NetAddr::IP->new( $if_ref->{ net }, $if_ref->{ mask } )->cidr();
	}

	my $rule = {
				 table => "table_$if_ref->{name}",
				 type  => 'iface',
				 from  => $from,
				 ip_v  => $if_ref->{ ip_v }
	};

	return $rule;
}

=begin nd
Function: setRule

	Check and then apply action to add or delete the rule according to the parameters.

Parameters:
	action - "add" to create a new rule or "del" to remove it.
	rule - Rule hash reference

Returns:
	integer - ip command return code.

Bugs:
	Rules for Datalink farms are included.
=cut

sub setRule
{
	&zenlog( __FILE__ . q{:} . __LINE__ . q{:} . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );

	my $action = shift;
	my $rule   = shift;
	my $output = 0;

	return 0 if ( not defined ( $rule->{ from } ) or $rule->{ from } eq '' );

	return -1 if ( $action !~ /^add$|^del$/ );
	return -1 if ( defined $rule->{ fwmark } and $rule->{ fwmark } =~ /^0x0$/ );

	my $isrule = &isRule( $rule );

	&zenlog( "action '$action' and the rule exist=$isrule", "debug", "net" );

	if ( $action eq "add" and $isrule == 0 )
	{
		&applyRule( $action, $rule );
		$output = &isRule( $rule ) ? 0 : 1;
	}
	elsif ( $action eq "del" and $isrule != 0 )
	{
		&applyRule( $action, $rule );
		$output = &isRule( $rule );
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

sub applyRoutes    # ($table,$if_ref,$gateway)
{
	&zenlog( __FILE__ . q{:} . __LINE__ . q{:} . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my ( $table, $if_ref, $gateway ) = @_;
	my $if_announce = "";

	# $gateway: The 3rd argument, '$gateway', is only used for 'global' table,
	#           to assign a default gateway.

	my $status = 0;

	# do not add routes if the inteface is down
	my $if_sys = &getSystemInterface( $$if_ref{ name } );
	return 0 if ( $$if_sys{ status } ne 'up' );
	return 0 if ( $$if_ref{ ip_v } != 4 and $$if_ref{ ip_v } != 6 );

	unless ( $$if_ref{ net } )
	{
		require Zevenet::Net::Interface;
		$$if_ref{ net } =
		  &getAddressNetwork( $$if_ref{ addr }, $$if_ref{ mask }, $$if_ref{ ip_v } );
	}

	# not virtual interface
	if ( not defined $$if_ref{ vini } or $$if_ref{ vini } eq '' )
	{
		if ( $table eq "local" )
		{
			&zenlog(
				"Applying $table routes in stack IPv$$if_ref{ip_v} to $$if_ref{name} with gateway \"$$if_ref{gateway}\"",
				"info", "NETWORK"
			);

			&addlocalnet( $if_ref );

			if ( $$if_ref{ gateway } )
			{
				my $routeparams = &getGlobalConfiguration( 'routeparams' );
				my $ip_cmd =
				  "$ip_bin -$$if_ref{ip_v} route replace default via $$if_ref{gateway} dev $$if_ref{name} table table_$$if_ref{name} $routeparams";
				$status = &logAndRun( "$ip_cmd" );
			}

			my $rule = &getRuleFromIface( $if_ref );
			$status = &setRule( "add", $rule );

			#~ require Zevenet::Farm::Config;
			#~ &reloadFarmsSourceAddress() if $status == 0;
		}
		else
		{
			# Apply routes on the global table
			# &delRoutes( "global", $if );
			if ( $gateway )
			{
				my $routeparams = &getGlobalConfiguration( 'routeparams' );

				my $action = "replace";
				my $system_default_gw;
				if ( $$if_ref{ ip_v } == 4 )
				{
					$system_default_gw = &getDefaultGW();
				}
				elsif ( $$if_ref{ ip_v } == 6 )
				{
					$system_default_gw = &getIPv6DefaultGW();
				}

				if ( $system_default_gw eq "" )
				{
					$action = "add";
				}

				if ( &existRoute( "default via $gateway dev $$if_ref{name}", 1, 0 ) )
				{
					&zenlog(
						"Gateway \"$gateway\" is already applied in $table routes in stack IPv$$if_ref{ip_v}",
						"info", "NETWORK"
					);
				}
				else
				{
					&zenlog(
						  "Applying $table routes in stack IPv$$if_ref{ip_v} with gateway \"$gateway\"",
						  "info", "NETWORK" );
					my $ip_cmd =
					  "$ip_bin -$$if_ref{ip_v} route $action default via $gateway dev $$if_ref{name} $routeparams";
					$status = &logAndRun( "$ip_cmd" );
				}
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
			}
		}
		$if_announce = $$if_ref{ name };
	}

	# virtual interface
	else
	{
		my ( $toif ) = split ( /:/, $$if_ref{ name } );

		my $rule = &getRuleFromIface( $if_ref );
		$rule->{ table } = "table_$toif";
		$status = &setRule( "add", $rule );
		$if_announce = $toif;
	}

	# not send garps to network if node is backup or it is in maintenance
	eval {

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

sub delRoutes    # ($table,$if_ref)
{
	&zenlog( __FILE__ . q{:} . __LINE__ . q{:} . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my ( $table, $if_ref ) = @_;

	my $status = 0;

	&zenlog(
			 "Deleting $table routes for IPv$$if_ref{ip_v} in interface $$if_ref{name}",
			 "info", "NETWORK" );

	if ( not defined $$if_ref{ vini } or $$if_ref{ vini } eq '' )
	{
		#an interface is going to be deleted, delete the rule of the IP first
		use Zevenet::Net::Core;
		&setRuleIPtoTable( $$if_ref{ name }, $$if_ref{ addr }, "del" );

		if ( $table eq "local" )
		{
			# exists if the tables does not exist
			if ( not grep { /^table_$if_ref->{name}/ } &listRoutingTablesNames() )
			{
				&zenlog(
						 "The table table_$if_ref->{name} was not flushed because it was not found",
						 "debug2", "net" );
				return 0;
			}

			my $ip_cmd = "$ip_bin -$$if_ref{ip_v} route flush table table_$$if_ref{name}";
			$status = &logAndRun( "$ip_cmd" );

			my $rule = &getRuleFromIface( $if_ref );
			$status = &setRule( "del", $rule );
			return $status;
		}
		else
		{
			# Delete routes on the global table
			my $ip_cmd = "$ip_bin -$$if_ref{ip_v} route del default";
			$status = &logAndRun( "$ip_cmd" );

			if ( $status == 0 )
			{
				if ( $$if_ref{ ip_v } == 6 )
				{
					&setGlobalConfiguration( 'defaultgw6',   '' );
					&setGlobalConfiguration( 'defaultgwif6', '' );
				}
				else
				{
					&setGlobalConfiguration( 'defaultgw',   '' );
					&setGlobalConfiguration( 'defaultgwif', '' );
				}
			}

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
	&zenlog( __FILE__ . q{:} . __LINE__ . q{:} . ( caller ( 0 ) )[3] . "( @_ )",
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
			@routes = @{ &logAndGet( "$ip_bin route list table table_$cif", "array" ) };
		}

		close $rt_fd;
		@defgw = grep { /^default/ } @routes;
		@line = split ( / /, $defgw[0] );
		$gw = $line[2];
		return $gw;
	}
	else
	{
		@routes = @{ &logAndGet( "$ip_bin route list", "array" ) };
		@defgw = grep { /^default/ } @routes;
		@line = split ( / /, $defgw[0] );
		$gw = $line[2];
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
	&zenlog( __FILE__ . q{:} . __LINE__ . q{:} . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my @routes = @{ &logAndGet( "$ip_bin -6 route list", "array" ) };
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
	&zenlog( __FILE__ . q{:} . __LINE__ . q{:} . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my @routes = @{ &logAndGet( "$ip_bin -6 route list", "array" ) };
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
	&zenlog( __FILE__ . q{:} . __LINE__ . q{:} . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my @routes = @{ &logAndGet( "$ip_bin route list", "array" ) };
	my @defgw = grep { /^default/ } @routes;
	my @line = split ( / /, $defgw[0] );

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
	&zenlog( __FILE__ . q{:} . __LINE__ . q{:} . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $defaultgw    = &getGlobalConfiguration( 'defaultgw' );
	my $defaultgwif  = &getGlobalConfiguration( 'defaultgwif' );
	my $defaultgw6   = &getGlobalConfiguration( 'defaultgw6' );
	my $defaultgwif6 = &getGlobalConfiguration( 'defaultgwif6' );

	# input: global variables $defaultgw and $defaultgwif
	if ( $defaultgw and $defaultgwif )
	{
		my $if_ref = &getInterfaceConfig( $defaultgwif, 4 );
		if ( $if_ref )
		{
			&applyRoutes( "global", $if_ref, $defaultgw );
		}
	}

	# input: global variables $$defaultgw6 and $defaultgwif6
	if ( $defaultgw6 and $defaultgwif6 )
	{
		my $if_ref = &getInterfaceConfig( $defaultgwif, 6 );
		if ( $if_ref )
		{
			&applyRoutes( "global", $if_ref, $defaultgw6 );
		}
	}
	return;
}

=begin nd
Function: listRoutingTablesNames

	It lists the system routing tables by its nickname

Parameters:
	none - .

Returns:
	Array - List of routing tables in the system

=cut

sub listRoutingTablesNames
{
	&zenlog( __FILE__ . q{:} . __LINE__ . q{:} . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );

	my $rttables = &getGlobalConfiguration( 'rttables' );

	my @list       = ();
	my @exceptions = qw(local default unspec);

	require Zevenet::Lock;
	my $fh = &openlock( $rttables, '<' );

	while ( my $line = <$fh> )
	{
		next if ( $line =~ /^\s*#/ );

		if ( $line =~ /\d+\s+([\w\-\.]+)/ )
		{
			my $name = $1;
			next if grep { /^$name$/ } @exceptions;
			push @list, $name;
		}
	}
	close $fh;

	return @list;
}

=begin nd
Function: listRoutingRulesSys

	It returns a list of the routing rules from the system.

Parameters:
	filter - filter hash reference for matching rules. No filter means all rules.

Returns:
	Array ref - list of routing rules

=cut

sub listRoutingRulesSys
{
	&zenlog( __FILE__ . q{:} . __LINE__ . q{:} . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $filter = shift;
	my $filter_param;
	my @rules = ();

	if ( defined $filter )
	{
		my @filter_params = keys %{ $filter };
		$filter_param = $filter_params[0];
	}

	# get data
	my $cmd  = "$ip_bin -j -p rule list";
	my $data = &logAndGet( $cmd );

	# decoding
	require JSON::XS;
	JSON::XS->import;
	my $dec_data = eval { decode_json( $data ); };
	if ( $@ )
	{
		&zenlog( "Decoding json: $@", "error", "net" );
		$dec_data = [];
	}

	# filter data
	foreach my $r ( @{ $dec_data } )
	{
		if (    ( not defined $filter )
			 or ( $filter->{ $filter_param } eq $r->{ $filter_param } ) )
		{
			my $type = ( exists $r->{ fwmask } ) ? 'farm' : 'system';

			$r->{ from } = $r->{ src };
			$r->{ from } .= "/$r->{ srclen }" if exists ( $r->{ srclen } );

			delete $r->{ src };
			delete $r->{ srclen };

			$r->{ to } = $r->{ dst } if exists ( $r->{ dst } );
			$r->{ to } .= "/$r->{ dstlen }" if exists ( $r->{ dstlen } );

			delete $r->{ dst };
			delete $r->{ dstlen };

			$r->{ type } = $type;
			$r->{ not } = 'true' if ( exists $r->{ not } );
			push @rules, $r;
		}
	}

	return \@rules;
}

=begin nd
Function: listRoutingRules

	It returns a list of the routing rules. These rules are the resulting list of
	join the system administred and the created by the user.

Parameters:
	none - .

Returns:
	Array ref - list of routing rules

=cut

sub listRoutingRules
{
	&zenlog( __FILE__ . q{:} . __LINE__ . q{:} . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );

	my @rules_conf = ();
	my @priorities = ();
	foreach my $r ( @rules_conf )
	{
		push @priorities, $r->{ priority };
	}

	foreach my $sys ( @{ &listRoutingRulesSys() } )
	{
		push @rules_conf, $sys if ( not grep { /^$sys->{priority}$/ } @priorities );
	}

	return \@rules_conf;
}

=begin nd
Function: getRoutingTableExists

	It checks if a routing table exists in the system

Parameters:
	table - It is the table to check

Returns:
	Integer - It returns 1 if the table exists or 0 if it does not exist

=cut

sub getRoutingTableExists
{
	&zenlog( __FILE__ . q{:} . __LINE__ . q{:} . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );

	my $table = shift;
	my $rc    = 1;

	if ( grep { /^$table$/ } &listRoutingTablesNames() )
	{
		$rc = &logAndRunCheck( "$ip_bin route list table $table" );
	}

	return ( $rc ) ? 0 : 1;
}

=begin nd
Function: getRoutingOutgoing

	It gets the output interface in the system

Parameters:
	ip - Ip address.
	mark - mark.

Returns:
	Hash ref - $route_ref

Variable: $route_ref
	Hash ref that maps the route info

	$outgoing_ref->{ in }->{ ip } - dest ip address
	$outgoing_ref->{ in }->{ mark } - mark.
	$outgoing_ref->{ out }->{ ifname } - Interface name for output.
	$outgoing_ref->{ out }->{ srcaddr } - IP address for output.
	$outgoing_ref->{ out }->{ table } - Route Table name used
	$outgoing_ref->{ out }->{ custom } - Custom route

=cut

sub getRoutingOutgoing    # ( $ip, $mark )
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my ( $ip, $mark ) = @_;
	my $outgoing_ref;

	$outgoing_ref->{ in }->{ ip }       = $ip;
	$outgoing_ref->{ in }->{ mark }     = "";
	$outgoing_ref->{ out }->{ ifname }  = "";
	$outgoing_ref->{ out }->{ srcaddr } = "";
	$outgoing_ref->{ out }->{ table }   = "";
	$outgoing_ref->{ out }->{ custom }  = "";

	my $mark_option;
	if ( $mark )
	{
		$outgoing_ref->{ in }->{ mark } = $mark;
		$mark_option = "mark $mark";
	}

	my $cmd  = "$ip_bin -o -d route get $ip $mark_option";
	my $data = &logAndGet( $cmd );

	require Zevenet::Validate;
	my $ip_re = &getValidFormat( "ip_addr" );

	if ( $data =~
		/^.* \Q$ip\E (?:via .* )?dev (.*) table (.*) src ($ip_re)(?: $mark_option)? uid (.*)/
	  )
	{
		my $iface      = $1;
		my $table      = $2;
		my $sourceaddr = $3;
		my $custom     = $4;

		if ( $iface eq "lo" )
		{
			my $cmd = "$ip_bin -o -d route list table $table type local";
			my $data = &logAndGet( $cmd, "array" );
			foreach my $route_local ( @{ $data } )
			{
				if ( $route_local =~ /^local \Q$ip\E dev (.*) proto .* src .*/ )
				{
					$iface = $1;
					last;
				}
			}
			$outgoing_ref->{ out }->{ custom } = "false";
		}
		else
		{
			my $route_params = &getGlobalConfiguration( 'routeparams' );
			if ( $custom =~ $route_params )
			{
				$outgoing_ref->{ out }->{ custom } = "false";
			}
			else
			{
				$outgoing_ref->{ out }->{ custom } = "true";
			}
		}

		$outgoing_ref->{ out }->{ ifname }  = $iface;
		$outgoing_ref->{ out }->{ table }   = $table;
		$outgoing_ref->{ out }->{ srcaddr } = $sourceaddr;
	}

	return $outgoing_ref;
}

1;
