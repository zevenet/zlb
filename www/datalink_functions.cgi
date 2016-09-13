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

#
sub getDatalinkFarmAlgorithm    # ($farm_name)
{
	my ( $farm_name ) = @_;

	my $farm_filename = &getFarmFile( $farm_name );
	my $algorithm     = -1;
	my $first         = "true";

	open FI, "<$configdir/$farm_filename";

	while ( my $line = <FI> )
	{
		if ( $line ne "" && $first eq "true" )
		{
			$first = "false";
			my @line = split ( "\;", $line );
			$algorithm = $line[3];
		}
	}
	close FI;

	return $algorithm;
}

# set the lb algorithm to a farm
sub setDatalinkFarmAlgorithm    # ($algorithm,$farm_name)
{
	my ( $algorithm, $farm_name ) = @_;

	my $farm_filename = &getFarmFile( $farm_name );

	#~ my $output        = -1;
	my $i = 0;

	use Tie::File;
	tie @configfile, 'Tie::File', "$configdir\/$farm_filename";

	for my $line ( @configfile )
	{
		if ( $line =~ /^$farm_name\;/ )
		{
			my @args = split ( "\;", $line );
			$line = "$args[0]\;$args[1]\;$args[2]\;$algorithm\;$args[4]";
			splice @configfile, $i, $line;
		}
		$i++;
	}
	untie @configfile;

	# Apply changes online
	if ( &getFarmStatus( $farm_name ) eq 'up' )
	{
		&runFarmStop( $farmname, "true" );
		&runFarmStart( $farmname, "true" );
	}

	return;    # $output;
}

#
sub getDatalinkFarmServers    # ($farm_name)
{
	my ( $farm_name ) = @_;

	my $farm_filename = &getFarmFile( $farm_name );
	my $farm_type     = &getFarmType( $farm_name );
	my $first         = "true";
	my $sindex        = 0;
	my @servers;

	open FI, "<$configdir/$farm_filename";

	while ( my $line = <FI> )
	{
		if ( $line ne "" && $line =~ /^\;server\;/ && $first ne "true" )
		{
			$line =~ s/^\;server/$sindex/g;    #, $line;
			push ( @servers, $line );
			$sindex = $sindex + 1;
		}
		else
		{
			$first = "false";
		}
	}
	close FI;

	return @servers;
}

#
sub getDatalinkFarmBootStatus    # ($farm_name)
{
	my ( $farm_name ) = @_;

	my $farm_filename = &getFarmFile( $farm_name );
	my $output        = "down";
	my $first         = "true";

	open FI, "<$configdir/$farm_filename";

	while ( my $line = <FI> )
	{
		if ( $line ne "" && $first eq "true" )
		{
			$first = "false";
			my @line_a = split ( "\;", $line );
			$output = $line_a[4];
			chomp ( $output );
		}
	}
	close FI;

	return $output;
}

# get network physical (vlan included) interface used by the farm vip
sub getFarmInterface    # ($farm_name)
{
	my ( $farm_name ) = @_;

	my $type   = &getFarmType( $farm_name );
	my $output = -1;

	if ( $type eq "datalink" )
	{
		my $farm_filename = &getFarmFile( $farm_name );
		open FI, "<$configdir/$farm_filename";
		my $first = "true";
		while ( $line = <FI> )
		{
			if ( $line ne "" && $first eq "true" )
			{
				$first = "false";
				my @line_a = split ( "\;", $line );
				my @line_b = split ( "\:", $line_a[2] );
				$output = $line_b[0];
			}
		}
		close FI;
	}

	return $output;
}

#
sub _runDatalinkFarmStart    # ($farm_name, $writeconf, $status)
{
	my ( $farm_name, $writeconf, $status ) = @_;

	return $status if ( $status == -1 );

	my $farm_filename = &getFarmFile( $farm_name );

	if ( $writeconf eq "true" )
	{
		use Tie::File;
		tie my @configfile, 'Tie::File', "$configdir\/$farm_filename";
		my $first = 1;

		foreach ( @configfile )
		{
			if ( $first eq 1 )
			{
				s/\;down/\;up/g;
				$first = 0;
			}
		}
		untie @configfile;
	}

	# include cron task to check backends
	use Tie::File;
	tie my @cron_file, 'Tie::File', "/etc/cron.d/zenloadbalancer";
	my @farmcron = grep /\# \_\_$farm_name\_\_/, @cron_file;
	if ( scalar @farmcron eq 0 )
	{
		push ( @cron_file,
			   "* * * * *	root	\/usr\/local\/zenloadbalancer\/app\/libexec\/check_uplink $farm_name \# \_\_$farm_name\_\_"
		);
	}
	untie @cron_file;

	# Apply changes online

	# Set default uplinks as gateways
	my $iface     = &getFarmInterface( $farm_name );
	my @eject     = `$ip_bin route del default table table_$iface 2> /dev/null`;
	my @servers   = &getFarmServers( $farm_name );
	my $algorithm = &getFarmAlgorithm( $farm_name );
	my $routes    = "";

	if ( $algorithm eq "weight" )
	{
		foreach $serv ( @servers )
		{
			chomp ( $serv );
			my @line = split ( "\;", $serv );
			my $stat = $line[5];
			chomp ( $stat );
			my $weight = 1;

			if ( $line[3] ne "" )
			{
				$weight = $line[3];
			}
			if ( $stat eq "up" )
			{
				$routes = "$routes nexthop via $line[1] dev $line[2] weight $weight";
			}
		}
	}

	if ( $algorithm eq "prio" )
	{
		my $bestprio = 100;
		foreach $serv ( @servers )
		{
			chomp ( $serv );
			my @line = split ( "\;", $serv );
			my $stat = $line[5];
			my $prio = $line[4];
			chomp ( $stat );

			if (    $stat eq "up"
				 && $prio > 0
				 && $prio < 10
				 && $prio < $bestprio )
			{
				$routes   = "nexthop via $line[1] dev $line[2] weight 1";
				$bestprio = $prio;
			}
		}
	}

	if ( $routes ne "" )
	{
		my $ip_command =
		  "$ip_bin route add default scope global table table_$iface $routes";

		&logfile( "running $ip_command" );
		$status = system ( "$ip_command >/dev/null 2>&1" );
	}
	else
	{
		$status = 0;
	}

	# Set policies to the local network
	my $ip = &iponif( $iface );

	if ( $ip =~ /\./ )
	{
		my $ipmask = &maskonif( $iface );
		my ( $net, $mask ) = ipv4_network( "$ip / $ipmask" );
		&logfile( "running $ip_bin rule add from $net/$mask lookup table_$iface" );
		my @eject = `$ip_bin rule add from $net/$mask lookup table_$iface 2> /dev/null`;
	}

	# Enable IP forwarding
	&setIpForward( "true" );

	# Enable active datalink file
	open FI, ">$piddir\/$farm_name\_datalink.pid";
	close FI;

	return $status;
}

#
sub _runDatalinkFarmStop    # ($farm_name,$writeconf)
{
	my ( $farm_name, $writeconf ) = @_;

	my $farm_filename = &getFarmFile( $farm_name );
	my $status =
	  ( $writeconf eq "true" )
	  ? -1
	  : 0;

	if ( $writeconf eq "true" )
	{
		use Tie::File;
		tie @configfile, 'Tie::File', "$configdir\/$farm_filename";
		my $first = 1;
		foreach ( @configfile )
		{
			if ( $first == 1 )
			{
				s/\;up/\;down/g;
				$status = $?;
				$first  = 0;
			}
		}
		untie @configfile;
	}

	# delete cron task to check backends
	use Tie::File;
	tie @cron_file, 'Tie::File', "/etc/cron.d/zenloadbalancer";
	@cron_file = grep !/\# \_\_$farmname\_\_/, @cron_file;
	untie @cron_file;

	$status = 0 if $writeconf eq 'false';

	# Apply changes online
	if ( $status != -1 )
	{
		my $iface = &getFarmInterface( $farm_name );

		# Disable policies to the local network
		my $ip = &iponif( $iface );
		if ( $ip =~ /\./ )
		{
			my $ipmask = &maskonif( $iface );
			my ( $net, $mask ) = ipv4_network( "$ip / $ipmask" );

			&logfile( "running $ip_bin rule del from $net/$mask lookup table_$iface" );
			my @eject = `$ip_bin rule del from $net/$mask lookup table_$iface 2> /dev/null`;
		}

		# Disable default uplink gateways
		my @eject = `$ip_bin route del default table table_$iface 2> /dev/null`;

		# Disable active datalink file
		unlink ( "$piddir\/$farm_name\_datalink.pid" );
		if ( -e "$piddir\/$farm_name\_datalink.pid" )
		{
			$status = -1;
		}
	}

	return $status;
}

#
sub runDatalinkFarmCreate    # ($farm_name,$vip,$fdev)
{
	my ( $farm_name, $vip, $fdev ) = @_;

	open FO, ">$configdir\/$farm_name\_datalink.cfg";
	print FO "$farm_name\;$vip\;$fdev\;weight\;up\n";
	close FO;
	$output = $?;

	if ( !-e "$piddir/${farm_name}_datalink.pid" )
	{
		# Enable active datalink file
		open FI, ">$piddir\/$farm_name\_datalink.pid";
		close FI;
	}

	return $output;
}

# Returns farm vip
sub getDatalinkFarmVip    # ($info,$farm_name)
{
	my ( $info, $farm_name ) = @_;

	my $farm_filename = &getFarmFile( $farm_name );
	my $output        = -1;
	my $first         = "true";

	open FI, "<$configdir/$farm_filename";

	while ( my $line = <FI> )
	{
		if ( $line ne "" && $first eq "true" )
		{
			$first = "false";
			my @line_a = split ( "\;", $line );

			if ( $info eq "vip" )   { $output = $line_a[1]; }
			if ( $info eq "vipp" )  { $output = $line_a[2]; }
			if ( $info eq "vipps" ) { $output = "$line_a[1]\:$line_a[2]"; }
		}
	}
	close FI;

	return $output;
}

# Set farm virtual IP and virtual PORT
sub setDatalinkFarmVirtualConf    # ($vip,$vip_port,$farm_name)
{
	my ( $vip, $vip_port, $farm_name ) = @_;

	my $farm_filename = &getFarmFile( $farm_name );
	my $farm_state    = &getFarmStatus( $farm_name );
	my $stat          = -1;
	my $i             = 0;

	&runFarmStop( $farm_name, 'true' ) if $farm_state eq 'up';

	use Tie::File;
	tie @configfile, 'Tie::File', "$configdir\/$farm_filename";

	for my $line ( @configfile )
	{
		if ( $line =~ /^$farm_name\;/ )
		{
			my @args = split ( "\;", $line );
			$line = "$args[0]\;$vip\;$vip_port\;$args[3]\;$args[4]";
			splice @configfile, $i, $line;
			$stat = $?;
		}
		$i++;
	}
	untie @configfile;
	$stat = $?;

	&runFarmStart( $farm_name, 'true' ) if $farm_state eq 'up';

	return $stat;
}

#
sub setDatalinkFarmServer    # ($ids,$rip,$iface,$weight,$priority,$farm_name)
{
	my ( $ids, $rip, $iface, $weight, $priority, $farm_name ) = @_;

	my $farm_filename = &getFarmFile( $farm_name );
	my $end           = "false";
	my $i             = 0;
	my $l             = 0;

	tie my @contents, 'Tie::File', "$configdir\/$farm_filename";

	foreach my $line ( @contents )
	{
		if ( $line =~ /^\;server\;/ && $end ne "true" )
		{
			if ( $i eq $ids )
			{
				my $dline = "\;server\;$rip\;$iface\;$weight\;$priority\;up\n";
				splice @contents, $l, 1, $dline;
				$end = "true";
			}
			else
			{
				$i++;
			}
		}
		$l++;
	}

	if ( $end eq "false" )
	{
		push ( @contents, "\;server\;$rip\;$iface\;$weight\;$priority\;up\n" );
	}

	untie @contents;

	# Apply changes online
	if ( &getFarmStatus( $farm_name ) eq 'up' )
	{
		&runFarmStop( $farmname, "true" );
		&runFarmStart( $farmname, "true" );
	}

	return;
}

#
sub runDatalinkFarmServerDelete    # ($ids,$farm_name)
{
	my ( $ids, $farm_name ) = @_;

	my $farm_filename = &getFarmFile( $farm_name );
	my $output        = -1;
	my $end           = "false";
	my $i             = 0;
	my $l             = 0;

	tie my @contents, 'Tie::File', "$configdir\/$farm_filename";

	foreach my $line ( @contents )
	{
		if ( $line =~ /^\;server\;/ && $end ne "true" )
		{
			if ( $i eq $ids )
			{
				splice @contents, $l, 1,;
				$output = $?;
				$end    = "true";
			}
			else
			{
				$i++;
			}
		}
		$l++;
	}
	untie @contents;

	# Apply changes online
	if ( &getFarmStatus( $farm_name ) eq 'up' )
	{
		&runFarmStop( $farmname, "true" );
		&runFarmStart( $farmname, "true" );
	}

	return $output;
}

#function that return the status information of a farm:
#ip, port, backendstatus, weight, priority, clients
sub getDatalinkFarmBackendsStatus    # (@content)
{
	my ( @content ) = @_;

	my @backends_data;

	foreach my $server ( @content )
	{
		my @serv = split ( ";", $server );
		push ( @backends_data, "$serv[2]\;$serv[3]\;$serv[4]\;$serv[5]\;$serv[6]" );
	}

	return @backends_data;
}

sub setDatalinkFarmBackendStatus    # ($farm_name,$index,$stat)
{
	my ( $farm_name, $index, $stat ) = @_;

	my $farm_filename = &getFarmFile( $farm_name );

	my $fileid   = 0;
	my $serverid = 0;

	use Tie::File;
	tie my @configfile, 'Tie::File', "$configdir\/$farm_filename";

	foreach my $line ( @configfile )
	{
		if ( $line =~ /\;server\;/ )
		{
			if ( $serverid eq $index )
			{
				my @lineargs = split ( "\;", $line );
				@lineargs[6] = $stat;
				@configfile[$fileid] = join ( "\;", @lineargs );
			}
			$serverid++;
		}
		$fileid++;
	}
	untie @configfile;

	# Apply changes online
	if ( &getFarmStatus( $farm_name ) eq 'up' )
	{
		&runFarmStop( $farmname, "true" );
		&runFarmStart( $farmname, "true" );
	}

	return;
}

#
sub getDatalinkFarmBackendStatusCtl    # ($farm_name)
{
	my ( $farm_name ) = @_;

	my $farm_filename = &getFarmFile( $farm_name );
	my @output;

	tie my @content, 'Tie::File', "$configdir\/$farm_filename";
	@output = grep /^\;server\;/, @content;
	untie @content;

	return @output;
}

#function that renames a farm
sub setDatalinkNewFarmName    # ($farm_name,$new_farm_name)
{
	my ( $farm_name, $new_farm_name ) = @_;

	my $farm_filename = &getFarmFile( $farm_name );
	my $farm_type     = &getFarmType( $farm_name );
	my $newffile      = "$new_farm_name\_$farm_type.cfg";
	my $output        = -1;

	use Tie::File;
	tie @configfile, 'Tie::File', "$configdir\/$farm_filename";

	for ( @configfile )
	{
		s/^$farm_name\;/$new_farm_name\;/g;
	}
	untie @configfile;

	rename ( "$configdir\/$farm_filename", "$configdir\/$newffile" );
	rename ( "$piddir\/$farm_name\_$farm_type.pid",
			 "$piddir\/$new_farm_name\_$farm_type.pid" );
	$output = $?;

	return $output;
}

# do not remove this
1;
