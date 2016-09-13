###############################################################################
#
#     Zen Load Balancer Software License
#     This file is part of the Zen Load Balancer software package.
#
#     Copyright (C) 2014 SOFINTEL IT ENGINEERING SL, Sevilla (Spain)
#
#     This library is free software; you can redistribute it and/or modify it
#     under the terms of the GNU Lesser General Public License as published
#     by the Free Software Foundation; either version 2.1 of the License, or
#     (at your option) any later version.
#
#     This library is distributed in the hope that it will be useful, but
#     WITHOUT ANY WARRANTY; without even the implied warranty of
#     MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU Lesser
#     General Public License for more details.
#
#     You should have received a copy of the GNU Lesser General Public License
#     along with this library; if not, write to the Free Software Foundation,
#     Inc., 59 Temple Place, Suite 330, Boston, MA 02111-1307 USA
#
###############################################################################

my $ext = 0;

if ( -e "/usr/local/zenloadbalancer/www/networking_functions_ext.cgi" )
{
	require "/usr/local/zenloadbalancer/www/networking_functions_ext.cgi";
	$ext = 1;
}

#check if a port in a ip is up
sub checkport($host,$port)
{
	( $host, $port ) = @_;

	#use strict;
	use IO::Socket;
	my $sock = new IO::Socket::INET( PeerAddr => $host, PeerPort => $port, Proto => 'tcp' );

	if ( $sock )
	{
		close ( $sock );
		return "true";
	}
	else
	{
		return "false";
	}
}

#list ALL IPS UP
sub listallips()
{
	use IO::Socket;
	use IO::Interface qw(:flags);

	my @listinterfaces = ();
	my $s              = IO::Socket::INET->new( Proto => 'udp' );
	my @interfaces     = $s->if_list;
	for my $if ( @interfaces )
	{
		$ip = $s->if_addr( $if );
		my $flags = $s->if_flags( $if );

		#print "ip es: $ip";
		if ( $flags & IFF_RUNNING && $ip !~ /127.0.0.1/ && ip !~ /0.0.0.0/ )
		{
			push ( @listinterfaces, $ip );
		}
	}
	return @listinterfaces;
}

#list all real ips up in server
sub listactiveips($class)
{
	( $class ) = @_;

	#list interfaces
	use IO::Socket;
	use IO::Interface qw(:flags);

	my $s = IO::Socket::INET->new( Proto => 'udp' );
	my @interfaces = $s->if_list;

	for my $if ( @interfaces )
	{
		if ( ( $class eq "phvlan" && $if !~ /\:/ ) || $class eq "" )
		{
			my $flags = $s->if_flags( $if );
			$ip      = $s->if_addr( $if );
			$hwaddr  = $s->if_hwaddr( $if );
			$netmask = $s->if_netmask( $if );
			$gw      = $s->if_dstaddr( $if );
			$bc      = $s->if_broadcast( $if );

			#if ( $bc && ($bc !~ /^0\.0\.0\.0$/) )
			#cluster ip will not be listed
			$clrip = &clrip();
			if ( $bc && $ip !~ /^127\.0\.0\.1$/ && $ip ne $clrip && $ip ne &GUIip() )
			{
				if ( !$netmask )            { $netmask = "-"; }
				if ( !$ip )                 { $ip      = "-"; }
				if ( !$hwaddr )             { $hwaddr  = "-"; }
				if ( $gw )                  { $gw      = "-"; }
				if ( $flags & IFF_RUNNING ) { $nvips   = $nvips . " " . $if . "->" . $ip; }
			}
		}
	}
	return "$nvips";
}

# list all interfaces
sub listActiveInterfaces($class)
{
	( $class ) = @_;
	my $s = IO::Socket::INET->new( Proto => 'udp' );
	my @interfaces = $s->if_list;
	my @aifaces;

	for my $if ( @interfaces )
	{
		if ( $if !~ /^lo|sit0/ )
		{
			if ( ( $class eq "phvlan" && $if !~ /\:/ ) || $class eq "" )
			{
				my $flags = $s->if_flags( $if );
				if ( $flags & IFF_UP )
				{
					push ( @aifaces, $if );
				}
			}
		}
	}

	return @aifaces;
}

#check if a ip is ok structure
sub ipisok($checkip)
{
	( $checkip ) = @_;
	use Data::Validate::IP;
	if ( is_ipv4( $checkip ) )
	{
		return "true";
	}
	else
	{
		return "false";
	}
}

#function checks if ip is in a range
sub ipinrange($netmask, $toip, $newip)
{
	( $netmask, $toip, $newip ) = @_;
	use Net::IPv4Addr qw( :all );

	#$ip_str1="10.234.18.13";
	#$mask_str1="255.255.255.0";
	#$cidr_str2="10.234.18.23";
	#print "true" if ipv4_in_network( $toip, $netmask, $newip );
	if ( ipv4_in_network( $toip, $netmask, $newip ) )
	{
		return "true";
	}
	else
	{
		return "false";
	}
}

#function check if interface exist
sub ifexist($niface)
{
	( $nif ) = @_;

	use IO::Socket;
	use IO::Interface qw(:flags);
	my $s = IO::Socket::INET->new( Proto => 'udp' );
	my @interfaces = $s->if_list;

	for my $if ( @interfaces )
	{
		if ( $if eq $nif )
		{
			my $flags = $s->if_flags( $if );
			if   ( $flags & IFF_RUNNING ) { $status = "up"; }
			else                          { $status = "down"; }
			if ( $status eq "up" || -e "$configdir/if_$nif\_conf" )
			{
				return "true";
			}
			return "created";
		}
	}
	return "false";
}

# saving network interfaces config files
sub writeConfigIf($if,$string)
{
	( $if, $string ) = @_;

	open CONFFILE, "> $configdir/if\_$if\_conf";
	print CONFFILE "$string\n";
	close CONFFILE;
	return $?;
}

# create table route identification
sub writeRoutes($if)
{
	( $if ) = @_;

	open ROUTINGFILE, '<', $rttables;
	my @contents = <ROUTINGFILE>;
	close ROUTINGFILE;
	$exists = "false";
	if ( grep /^...\ttable_$if$/, @contents )
	{
		$exists = "true";
	}
	if ( $exists eq "false" )
	{
		$found    = "false";
		$rtnumber = 1000;
		my $i;

		# Calculate next number
		for ( $i = 200 ; $i < 1000 && $found eq "false" ; $i++ )
		{
			$exists = "false";
			if ( grep /^$i\t/, @contents )
			{
				$exists = "true";
			}
			if ( $exists eq "false" )
			{
				$found    = "true";
				$rtnumber = $i;
			}
		}
	}
	if ( $found eq "true" )
	{
		open ( ROUTINGFILE, ">>$rttables" );
		print ROUTINGFILE "$rtnumber\ttable_$if\n";
		close ROUTINGFILE;
	}
}

# add local network into routing table
sub addlocalnet($if)
{
	$ip = &iponif( $if );
	if ( $ip =~ /\./ )
	{
		$ipmask = &maskonif( $if );
		( $net, $mask ) = ipv4_network( "$ip / $ipmask" );
		&logfile( "running '$ip_bin route add $net/$mask dev $if src $ip table table_$if $routeparams' " );
		@eject = `$ip_bin route add $net/$mask dev $if src $ip table table_$if $routeparams`;
	}
}

# ask for rules
sub isRule($ip,$if)
{
	$existRule = 0;
	@eject     = `$ip_bin rule list`;
	for ( @eject )
	{
		if ( $_ =~ /from $ip lookup table_$if/ )
		{
			$existRule = 1;
		}
	}
	return $existRule;
}

# apply routes
sub applyRoutes($table,$if,$gw)
{
	( $table, $if, $gw ) = @_;
	$statusR = 0;
	chomp ( $gw );

	$ip = &iponif( $if );

	if ( $if !~ /\:/ )
	{
		if ( $table eq "local" )
		{

			# Apply routes on the interface table
			if ( $ip !~ /\./ )
			{
				return 1;
			}
			&delRoutes( "local", $if );
			&addlocalnet( $if );
			if ( $gw !~ /^$/ )
			{
				&logfile( "running '$ip_bin route add default via $gw dev $if table table_$if $routeparams' " );
				@eject   = `$ip_bin route add default via $gw dev $if table table_$if $routeparams 2> /dev/null`;
				$statusR = $?;
			}
			if ( &isRule( $ip, $if ) eq 0 )
			{
				&logfile( "running '$ip_bin rule add from $ip table table_$if' " );
				@eject = `$ip_bin rule add from $ip table table_$if 2> /dev/null`;
			}
		}
		else
		{

			# Apply routes on the global table
			&delRoutes( "global", $if );
			if ( $gw !~ /^$/ )
			{
				&logfile( "running '$ip_bin route add default via $gw dev $if $routeparams' " );
				@eject   = `$ip_bin route add default via $gw dev $if $routeparams 2> /dev/null`;
				$statusR = $?;
				tie @contents, 'Tie::File', "$globalcfg";
				for ( @contents )
				{
					if ( grep /^\$defaultgw/, $_ )
					{
						s/^\$defaultgw=.*/\$defaultgw=\"$gw\"\;/g;
						s/^\$defaultgwif=.*/\$defaultgwif=\"$if\"\;/g;
					}
				}
				untie @contents;
			}
		}
	}
	else
	{

		# Include rules for virtual interfaces
		&delRoutes( "global", $if );
		if ( $ip !~ /\./ )
		{
			return 1;
		}
		@iface = split ( /:/, $if );
		if ( &isRule( $ip, @iface[0] ) eq 0 )
		{
			&logfile( "running '$ip_bin rule add from $ip table table_@iface[0]' " );
			@eject   = `$ip_bin rule add from $ip table table_@iface[0]  2> /dev/null`;
			$statusR = $?;
		}
	}
	return $statusR;
}

# delete routes
sub delRoutes($table,$if)
{
	( $table, $if ) = @_;

	$ip = &iponif( $if );

	if ( $if !~ /\:/ )
	{
		if ( $table eq "local" )
		{

			# Delete routes on the interface table
			if ( $ip !~ /\./ )
			{
				return 1;
			}
			&logfile( "running '$ip_bin route flush table table_$if' " );
			@eject = `$ip_bin route flush table table_$if 2> /dev/null`;
			&logfile( "running '$ip_bin rule del from $ip table table_$if' " );
			@eject = `$ip_bin rule del from $ip table table_$if 2> /dev/null`;
			return $?;
		}
		else
		{

			# Delete routes on the global table
			&logfile( "running '$ip_bin route del default' " );
			@eject  = `$ip_bin route del default 2> /dev/null`;
			$status = $?;
			tie @contents, 'Tie::File', "$globalcfg";
			for ( @contents )
			{
				if ( grep /^\$defaultgw/, $_ )
				{
					s/^\$defaultgw=.*/\$defaultgw=\"\"\;/g;
					s/^\$defaultgwif=.*/\$defaultgwif=\"\"\;/g;
				}
			}
			untie @contents;
			return $status;
		}
	}
	else
	{

		# Delete rules for virtual interfaces
		if ( $ip !~ /\./ )
		{
			return 1;
		}
		@iface = split ( /:/, $if );
		&logfile( "running '$ip_bin rule del from $ip table table_@iface[0]' " );
		@eject = `$ip_bin rule del from $ip table table_@iface[0] 2> /dev/null`;
		return $?;
	}
}

# create network interface
sub createIf($if)
{
	( $if ) = @_;

	my $status = 0;
	if ( $if =~ /\./ )
	{
		my @iface = split ( /\./, $if );

		# enable the parent physical interface
		$status = upIf( $iface[0] );
		&logfile( "running '$ip_bin link add link $iface[0] name $if type vlan id $iface[1]' " );
		my @eject = `$ip_bin link add link $iface[0] name $if type vlan id $iface[1] 2> /dev/null`;
		$status = $?;
	}
	return $status;
}

# up network interface
sub upIf($if)
{
	my ( $if ) = @_;

	my $status = 0;
	&logfile( "running '$ip_bin link set $if up' " );
	my @eject = `$ip_bin link set $if up 2> /dev/null`;
	$status = $?;
	return $status;
}

# down network interface
sub downIf($if)
{
	( $if ) = @_;

	$status = 0;
	if ( $if !~ /\:/ )
	{
		&logfile( "running '$ip_bin link set $if down' " );
		@eject  = `$ip_bin link set $if down 2> /dev/null`;
		$status = $?;
	}
	else
	{
		&logfile( "running '$ifconfig_bin $if down' " );
		@eject  = `$ifconfig_bin $if down 2> /dev/null`;
		$status = $?;
	}
	return $status;
}

# delete network interface
sub delIf($if)
{
	( $if ) = @_;

	my $status = 0;
	my $file   = "$configdir/if_$if\_conf";
	unlink ( $file );
	$status = $?;
	if ( $status != 0 )
	{
		return $status;
	}
	if ( $if !~ /\:/ )
	{
		&logfile( "running '$ip_bin address flush dev $if' " );
		@eject  = `$ip_bin address flush dev $if 2> /dev/null`;
		$status = $?;
		if ( $if =~ /\./ )
		{
			&logfile( "running '$ip_bin link delete $if type vlan' " );
			@eject  = `$ip_bin link delete $if type vlan 2> /dev/null`;
			$status = $?;
		}

		# Delete routes table
		open ROUTINGFILE, '<', $rttables;
		my @contents = <ROUTINGFILE>;
		close ROUTINGFILE;
		@contents = grep !/^...\ttable_$if$/, @contents;
		open ROUTINGFILE, '>', $rttables;
		print ROUTINGFILE @contents;
		close ROUTINGFILE;
	}

	# delete graphs
	unlink ( "/usr/local/zenloadbalancer/www/img/graphs/${if}\_d.png" );
	unlink ( "/usr/local/zenloadbalancer/www/img/graphs/${if}\_m.png" );
	unlink ( "/usr/local/zenloadbalancer/www/img/graphs/${if}\_w.png" );
	unlink ( "/usr/local/zenloadbalancer/www/img/graphs/${if}\_y.png" );
	unlink ( "/usr/local/zenloadbalancer/app/zenrrd/rrd/${if}iface.rrd" );
	return $status;
}

# get default gw for interface
sub getDefaultGW($if)
{
	( $if ) = @_;

	if ( $if ne "" )
	{
		$cif = $if;
		if ( $if =~ /\:/ )
		{
			@iface = split ( /\:/, $cif );
			$cif = $iface[0];
		}

		@routes = "";
		open ( ROUTINGFILE, $rttables );
		if ( grep { /^...\ttable_$cif$/ } <ROUTINGFILE> )
		{
			@routes = `$ip_bin route list table table_$cif`;

			#} else {
			#	@routes = `$ip_bin route list`;
		}
		close ROUTINGFILE;
		@defgw = grep ( /^default/, @routes );
		@line = split ( / /, @defgw[0] );
		$gw = $line[2];
		return $gw;
	}
	else
	{
		@routes = "";
		@routes = `$ip_bin route list`;
		@defgw  = grep ( /^default/, @routes );
		@line   = split ( / /, @defgw[0] );
		$gw     = $line[2];
		return $gw;
	}
}

# get interface for default gw
sub getIfDefaultGW()
{
	@routes = "";
	@routes = `$ip_bin route list`;
	@defgw  = grep ( /^default/, @routes );
	@line   = split ( / /, @defgw[0] );
	return $line[4];
}

#know if and return ip
sub iponif($if)
{
	( $if ) = @_;

	use IO::Socket;
	use IO::Interface qw(:flags);
	my $s = IO::Socket::INET->new( Proto => 'udp' );
	my @interfaces = $s->if_list;
	$iponif = $s->if_addr( $if );
	return $iponif;
}

# return the mask of an if
sub maskonif($if)
{
	( $if ) = @_;

	use IO::Socket;
	use IO::Interface qw(:flags);
	my $s = IO::Socket::INET->new( Proto => 'udp' );
	my @interfaces = $s->if_list;
	$maskonif = $s->if_netmask( $if );
	return $maskonif;
}

#return the gw of a if
sub gwofif($ifgw)
{
	( $ifgw ) = @_;

	open FGW, "<$configdir\/if\_$if\_conf";
	@gw_if = <FGW>;
	close FGW;
	@gw_ifspt = split ( /:/, @gw_if[0] );
	chomp ( @gw_ifspt[5] );
	return @gw_ifspt[5];
}

# Returns array execution of netstat
sub getNetstatFilter($proto,$state,$ninfo,$fpid,@netstat)
{
	my ( $proto, $state, $ninfo, $fpid, @netstat ) = @_;

	my $lfpid = $fpid;
	chomp ( $lfpid );

	#print "proto $proto ninfo $ninfo state $state pid $fpid<br/>";
	if ( $lfpid )
	{
		$lfpid = "\ $lfpid\/";
	}
	if ( $proto ne "tcp" && $proto ne "udp" )
	{
		$proto = "";
	}
	my @output = grep { /${proto}.*\ ${ninfo}\ .*\ ${state}.*${lfpid}/ } @netstat;
	return @output;
}

#~ Legacy function
#~ sub getNetstat($args){
#~ ($args)= @_;
#~ my @netstat = `netstat -$args`;
#~ return @netstat;
#~ }

#~ sub getNetstatNat($args){
#~ ($args)= @_;
#~ #my @netstat = `$netstatNat -$args`;
#~ open CONNS, "</proc/net/nf_conntrack";
#~ my @netstat = <CONNS>;
#~ close CONNS;
#~ return @netstat;
#~ }

sub getDevData($dev)
{
	( $dev ) = @_;
	open FI, "</proc/net/dev";
	my $exit = "false";
	my @dataout;
	while ( $line = <FI> && $exit eq "false" )
	{
		if ( $dev ne "" )
		{
			my @curline = split ( ":", $line );
			my $ini = @curline[0];
			chomp ( $ini );
			if ( $ini ne "" && $ini =~ $dev )
			{
				$exit = "true";
				my @datain = split ( " ", @curline[1] );
				push ( @dataout, @datain[0] );
				push ( @dataout, @datain[1] );
				push ( @dataout, @datain[8] );
				push ( @dataout, @datain[9] );
			}
		}
		else
		{
			if ( $line ne // )
			{
				push ( @dataout, $line );
			}
			else
			{
				$exit = "true";
			}
		}
	}
	close FI;

	return @dataout;
}

# send gratuitous ARP frames
sub sendGArp($if,$ip)
{
	( $if, $ip ) = @_;
	my @iface = split ( ":.", $if );
	&logfile( "sending '$arping_bin -c 2 -A -I $iface[0] $ip' " );
	my @eject = `$arping_bin -c 2 -A -I $iface[0] $ip > /dev/null &`;
	if ( $ext == 1 )
	{
		&sendGPing( $iface[0] );
	}
}

# Enable(true) / Disable(false) IP Forwarding
sub setIpForward($arg)
{
	( $arg ) = @_;
	my $status = -1;

	&logfile( "setting $arg to IP forwarding " );
	if ( $arg eq "true" )
	{
		my @run = `echo 1 > /proc/sys/net/ipv4/conf/all/forwarding`;
		my @run = `echo 1 > /proc/sys/net/ipv4/ip_forward`;
		$status = $?;
		my @run = `echo 1 > /proc/sys/net/ipv6/conf/all/forwarding`;
	}
	else
	{
		my @run = `echo 0 > /proc/sys/net/ipv4/conf/all/forwarding`;
		my @run = `echo 0 > /proc/sys/net/ipv4/ip_forward`;
		$status = $?;
		my @run = `echo 0 > /proc/sys/net/ipv6/conf/all/forwarding`;
	}

	return $status;
}

# Flush cache routes
sub flushCacheRoutes()
{
	&logfile( "flushing routes cache" );
	@run = `$ip_bin route flush cache`;
}

# Return if interface is used for datalink farm
sub uplinkUsed($if)
{
	( $if ) = @_;
	my @farms  = &getFarmsByType( "datalink" );
	my $output = "false";
	foreach $farm ( @farms )
	{
		my $farmif = &getFarmVip( "vipp", $farm );
		my $status = &getFarmStatus( $farm );
		if ( $status eq "up" && $farmif eq $if )
		{
			$output = "true";
		}
	}
	return $output;
}

sub isValidPortNumber($port)
{
	my ( $port ) = @_;
	my $valid;

	if ( defined ( $port ) && $port >= 1 && $port <= 65535 )
	{
		$valid = 'true';
	}
	else
	{
		$valid = 'false';

		#&logfile("Port $port out of range");
	}

	return $valid;
}

# do not remove this
1
