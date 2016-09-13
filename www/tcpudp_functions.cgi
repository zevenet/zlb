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

#asign a port for manage a pen Farm
sub setFarmPort    # ()
{
	#down limit
	my $min = "10000";

	#up limit
	my $max = "20000";

	my $lock = "true";
	do
	{
		$random_port = int ( rand ( $max - $min ) ) + $min;
		use IO::Socket;
		my $host = "127.0.0.1";
		my $socket = new IO::Socket::INET(
										   PeerAddr => $host,
										   PeerPort => $random_port,
										   Proto    => 'tcp'
		);
		if ( $socket )
		{
			close ( $socket );
		}
		else
		{
			$lock = "false";
		}
	} while ( $lock eq "true" );

	return $random_port;
}

#
sub setTcpUdpFarmBlacklistTime    # ($blacklist_time,$farm_name)
{
	my ( $blacklist_time, $farm_name ) = @_;

	my $farm_type     = &getFarmType( $farm_name );
	my $farm_filename = &getFarmFile( $farm_name );
	my $output        = -1;

	&logfile(
			"setting 'Blacklist time $blacklist_time' for $farm_name farm $farm_type" );

	my $farm_port   = &getFarmPort( $farm_name );
	my $fmaxservers = &getFarmMaxServers( $farm_name );

	my $pen_ctl_command = "$pen_ctl 127.0.0.1:$farm_port blacklist $blacklist_time";
	&logfile( "running '$pen_ctl_command'" );
	system ( "$pen_ctl_command >/dev/null 2>&1" );
	$output = $?;

	my $pen_write_config_command =
	  "$pen_ctl 127.0.0.1:$farm_port write '$configdir/$farm_filename'";
	&logfile( "running '$pen_write_config_command'" );
	system ( "$pen_write_config_command >/dev/null 2>&1" );

	$output = $? && $output;

	&setFarmMaxServers( $fmaxservers, $farm_name );

	return $output;
}

#
sub getTcpUdpFarmBlacklistTime    # ($farm_name)
{
	my ( $farm_name ) = @_;
	my $blacklist_time = -1;

	my $farm_port = &getFarmPort( $farm_name );

	my $pen_ctl_command = "$pen_ctl 127.0.0.1:$farm_port blacklist";
	&logfile( "running '$pen_ctl_command' for $farm_name farm" );
	$blacklist_time = `$pen_ctl_command 2> /dev/null`;

	return $blacklist_time;
}

#asign a timeout value to a farm
sub setTcpUdpFarmTimeout    # ($timeout,$farm_name)
{
	my ( $timeout, $farm_name ) = @_;

	my $output        = -1;
	my $farm_port     = &getFarmPort( $farm_name );
	my $fmaxservers   = &getFarmMaxServers( $farm_name );
	my $farm_filename = &getFarmFile( $farm_name );

	my $pen_ctl_command = "$pen_ctl 127.0.0.1:$farm_port timeout $timeout";
	&logfile( "running '$pen_ctl_command' for $farm_name farm $farm_type" );
	system ( "$pen_ctl_command >/dev/null 2>&1" );
	$output = $?;

	my $pen_write_config_command =
	  "$pen_ctl 127.0.0.1:$farm_port write '$configdir/$farm_filename'";
	&logfile(
			  "running '$pen_write_config_command' for $farm_name farm $farm_type" );
	system ( "$pen_write_config_command >/dev/null 2>&1" );
	$output = $? && $output;

	&setFarmMaxServers( $fmaxservers, $farm_name );

	return $output;
}

#
sub getTcpUdpFarmTimeout    # ($farm_name)
{
	my ( $farm_name ) = @_;

	my $output    = -1;
	my $farm_port = &getFarmPort( $farm_name );

	$pen_ctl_command = "$pen_ctl 127.0.0.1:$farm_port timeout";
	$output          = `$pen_ctl_command 2> /dev/null`;
	&logfile( "running '$pen_ctl_command' for $farm_name farm $farm_type" );

	return $output;
}

# set the lb algorithm to a farm
sub setTcpUdpFarmAlgorithm    # ($algorithm,$farm_name)
{
	my ( $algorithm, $farm_name ) = @_;

	my $output        = -1;
	my $farm_port     = &getFarmPort( $farm_name );
	my $fmaxservers   = &getFarmMaxServers( $farm_name );
	my $farm_filename = &getFarmFile( $farm_name );

	system ( "$pen_ctl 127.0.0.1:$farm_port no hash >/dev/null 2>&1" );
	system ( "$pen_ctl 127.0.0.1:$farm_port no prio >/dev/null 2>&1" );
	system ( "$pen_ctl 127.0.0.1:$farm_port no weight >/dev/null 2>&1" );

	$output = $?;

	if ( $algorithm ne "roundrobin" )
	{
		my $pen_ctl_command = "$pen_ctl 127.0.0.1:$farm_port $algorithm";

		&logfile( "running '$pen_ctl_command'" );
		system ( "$pen_ctl_command >/dev/null 2>&1" );
		$output = $?;
	}

	my $pen_ctl_command =
	  "$pen_ctl 127.0.0.1:$farm_port write '$configdir/$farm_filename'";

	&logfile( "runing '$pen_ctl_command'" );
	system ( $pen_ctl_command);

	&setFarmMaxServers( $fmaxservers, $farm_name );

	return $output;
}

#
sub getTcpUdpFarmAlgorithm    # ($farm_name)
{
	my ( $farm_name ) = @_;

	my $farm_filename = &getFarmFile( $farm_name );
	my $algorithm     = "roundrobin";

	use File::Grep qw( fgrep fmap fdo );
	if ( fgrep { /^roundrobin/ } "$configdir/$farm_filename" )
	{
		$algorithm = "roundrobin";
	}
	if ( fgrep { /^hash/ } "$configdir/$farm_filename" )
	{
		$algorithm = "hash";
	}
	if ( fgrep { /^weight/ } "$configdir/$farm_filename" )
	{
		$algorithm = "weight";
	}
	if ( fgrep { /^prio/ } "$configdir/$farm_filename" )
	{
		$algorithm = "prio";
	}

	return $algorithm;
}

# set client persistence to a farm
sub setTcpUdpFarmPersistence    # ($persistence,$farm_name)
{
	my ( $persistence, $farm_name ) = @_;

	my $farm_type     = &getFarmType( $farm_name );
	my $farm_filename = &getFarmFile( $farm_name );
	my $farm_port     = &getFarmPort( $farm_name );
	my $fmaxservers   = &getFarmMaxServers( $farm_name );
	my $output        = -1;

	&logfile( "setting 'Persistence $persistence' for $farm_name farm $farm_type" );

	if ( $persistence eq "true" )
	{
		&logfile(
			"running '$pen_ctl 127.0.0.1:$farm_port no roundrobin' for $farm_name farm $farm_type"
		);
		my @run = `$pen_ctl 127.0.0.1:$farm_port no roundrobin 2> /dev/null`;
		$output = $?;
	}
	else
	{
		&logfile(
			"running '$pen_ctl 127.0.0.1:$farm_port roundrobin' for $farm_name farm $farm_type"
		);
		my @run = `$pen_ctl 127.0.0.1:$farm_port roundrobin 2> /dev/null`;
		$output = $?;
	}
	my @run = `$pen_ctl 127.0.0.1:$farm_port write '$configdir/$farm_filename'`;
	&setFarmMaxServers( $fmaxservers, $farm_name );

	return $output;
}

#
sub getTcpUdpFarmPersistence    # ($farm_name)
{
	my ( $farm_name ) = @_;

	my $farm_filename = &getFarmFile( $farm_name );
	my $persistence   = "false";

	use File::Grep qw( fgrep fmap fdo );
	if ( fgrep { /^no\ roundrobin/ } "$configdir/$farm_filename" )
	{
		$persistence = "true";
	}

	return $persistence;
}

# set the max clients of a farm
sub setTcpUdpFarmMaxClientTime    # ($max_client_time,$track,$farm_name)
{
	my ( $max_client_time, $track, $farm_name ) = @_;

	my $farm_filename = &getFarmFile( $farm_name );
	my $farm_port     = &getFarmPort( $farm_name );
	my $fmaxservers   = &getFarmMaxServers( $farm_name );
	my $output        = -1;

	system ( "$pen_ctl 127.0.0.1:$farm_port tracking $track >/dev/null 2>&1" );
	system (
		"$pen_ctl 127.0.0.1:$farm_port write '$configdir/$farm_filename >/dev/null 2>&1"
	);

	use Tie::File;
	tie @array, 'Tie::File', "$configdir/$farm_filename";

	for ( @array )
	{
		if ( $_ =~ "# pen" )
		{
			s/-c [0-9]*/-c $max_client_time/g;
			$output = $?;
		}
	}
	untie @array;
	&setFarmMaxServers( $fmaxservers, $farm_name );

	return $output;
}

#
sub getTcpUdpFarmMaxClientTime    # ($farm_name)
{
	my ( $farm_name ) = @_;

	my @max_client_time;
	push ( @max_client_time, "" );
	push ( @max_client_time, "" );
	my $farm_port = &getFarmPort( $farm_name );

	&logfile( "running '$pen_ctl 127.0.0.1:$farm_port clients_max' " );
	@max_client_time[0] = `$pen_ctl 127.0.0.1:$farm_port clients_max 2> /dev/null`;
	@max_client_time[1] = `$pen_ctl 127.0.01:$farm_port tracking 2> /dev/null`;

	return @max_client_time;
}

# set the max conn of a farm
sub setTcpUdpFarmMaxConn    # ($max_connections,$farm_name)
{
	my ( $max_connections, $farm_name ) = @_;

	my $farm_filename = &getFarmFile( $farm_name );
	my $output        = -1;

	use Tie::File;
	tie my @array, 'Tie::File', "$configdir/$farm_filename";

	for ( @array )
	{
		if ( $_ =~ "# pen" )
		{
			s/-x [0-9]*/-x $max_connections/g;
			$output = $?;
		}
	}
	untie @array;

	return $output;
}

# Tcp/Udp only function
# set the max servers of a farm
sub setFarmMaxServers    # ($maxs,$farm_name)
{
	my ( $maxs, $farm_name ) = @_;

	my $farm_type     = &getFarmType( $farm_name );
	my $farm_filename = &getFarmFile( $farm_name );
	my $output        = -1;

	&logfile( "setting 'MaxServers $maxs' for $farm_name farm $farm_type" );
	if ( $farm_type eq "tcp" || $farm_type eq "udp" )
	{
		use Tie::File;
		tie @array, 'Tie::File', "$configdir/$farm_filename";
		for ( @array )
		{
			if ( $_ =~ "# pen" )
			{
				if ( $_ !~ "-S " )
				{
					s/# pen/# pen -S $maxs/g;
					$output = $?;
				}
				else
				{
					s/-S [0-9]*/-S $maxs/g;
					$output = $?;
				}
			}
		}
		untie @array;
	}

	return $output;
}

# Tcp/Udp only function
sub getFarmMaxServers    # ($farm_name)
{
	my ( $farm_name ) = @_;

	my $farm_type = &getFarmType( $farm_name );
	my $output    = -1;

	if ( $farm_type eq "tcp" || $farm_type eq "udp" )
	{
		my $farm_port = &getFarmPort( $farm_name );
		&logfile( "running '$pen_ctl 127.0.0.1:$farm_port servers' " );
		my @out = `$pen_ctl 127.0.0.1:$farm_port servers 2> /dev/null`;
		$output = @out;
	}

	return $output;
}

#
sub getTcpUdpFarmServers    # ($farm_name)
{
	my ( $farm_name ) = @_;

	my @output;
	my $farm_port = &getFarmPort( $farm_name );

	&logfile( "running '$pen_ctl 127.0.0.1:$farm_port servers' " );

	@output = `$pen_ctl 127.0.0.1:$farm_port servers 2> /dev/null`;

	return @output;
}

# Tcp/Udp only function
# set xforwarder for feature for a farm
sub setFarmXForwFor    # ($isset,$farm_name)
{
	my ( $isset, $farm_name ) = @_;

	my $farm_type     = &getFarmType( $farm_name );
	my $farm_filename = &getFarmFile( $farm_name );
	my $output        = -1;

	&logfile( "setting 'XForwFor $isset' for $farm_name farm $farm_type" );
	if ( $farm_type eq "tcp" || $farm_type eq "udp" )
	{
		my $farm_port   = &getFarmPort( $farm_name );
		my $fmaxservers = &getFarmMaxServers( $farm_name );
		if ( $isset eq "true" )
		{
			&logfile( "running '$pen_ctl 127.0.0.1:$farm_port http'" );
			my @run = `$pen_ctl 127.0.0.1:$farm_port http 2> /dev/null`;
			$output = $?;
		}
		else
		{
			&logfile( "running '$pen_ctl 127.0.0.1:$farm_port no http'" );
			my @run = `$pen_ctl 127.0.0.1:$farm_port no http 2> /dev/null`;
			$output = $?;
		}

		if ( $output != -1 )
		{
			my @run = `$pen_ctl 127.0.0.1:$farm_port write '$configdir/$farm_filename'`;
			&logfile( "configuration saved in $configdir/$farm_filename file" );
			&setFarmMaxServers( $fmaxservers, $farm_name );
		}
	}

	return $output;
}

# Tcp/Udp only function
sub getFarmXForwFor    # ($farm_name)
{
	my ( $farm_name ) = @_;

	my $farm_type     = &getFarmType( $farm_name );
	my $farm_filename = &getFarmFile( $farm_name );
	my $output        = -1;

	if ( $farm_type eq "tcp" || $farm_type eq "udp" )
	{
		use Tie::File;
		tie @array, 'Tie::File', "$configdir/$farm_filename";
		$output = "false";
		if ( grep ( /^http/, @array ) )
		{
			$output = "true";
		}
		untie @array;
	}

	return $output;
}

#
sub getTcpUdpFarmGlobalStatus    # ($farm_name)
{
	my ( $farm_name ) = @_;

	my @run;
	my $port = &getFarmPort( $farm_name );
	@run = `$pen_ctl 127.0.0.1:$port status`;

	return @run;
}

#
sub getTcpUdpBackendEstConns   # ($farm_name,$ip_backend,$port_backend,@netstat)
{
	my ( $farm_name, $ip_backend, $port_backend, @netstat ) = @_;

	my $farm_type = &getFarmType( $farm_name );

	return
	  &getNetstatFilter(
		"$farm_type",
		"",
		"\.*ESTABLISHED src=\.* dst=$ip_backend sport=\.* dport=$port_backend \.*src=$ip_backend \.*",
		"",
		@netstat
	  );
}

#
sub getTcpFarmEstConns    # ($farm_name,@netstat)
{
	my ( $farm_name, @netstat ) = @_;

	my $vip      = &getFarmVip( "vip",  $farm_name );
	my $vip_port = &getFarmVip( "vipp", $farm_name );

	return
	  &getNetstatFilter( "tcp", "",
			  "\.* ESTABLISHED src=\.* dst=$vip sport=\.* dport=$vip_port .*src=\.*",
			  "", @netstat );
}

#
sub getUdpFarmEstConns    # ($farm_name, @netstat)
{
	my ( $farm_name, @netstat ) = @_;

	my $vip      = &getFarmVip( "vip",  $farm_name );
	my $vip_port = &getFarmVip( "vipp", $farm_name );

	return
	  &getNetstatFilter( "udp", "",
						 "\.* src=\.* dst=$vip sport=\.* dport=$vip_port .*src=\.*",
						 "", @netstat );
}

#
sub getTcpUdpBackendTWConns    # ($farm_name,$ip_backend,$port_backend,@netstat)
{
	my ( $farm_name, $ip_backend, $port_backend, @netstat ) = @_;

	my $farm_type = &getFarmType( $farm_name );
	my $vip = &getFarmVip( "vip", $farm_name );

	return
	  &getNetstatFilter( "$farm_type", "",
		  "\.*TIME\_WAIT src=$vip dst=$ip_backend sport=\.* dport=$port_backend \.*",
		  "", @netstat );
}

sub getTcpBackendSYNConns   # ($farm_name, $ip_backend, $port_backend, @netstat)
{
	my ( $farm_name, $ip_backend, $port_backend, @netstat ) = @_;

	return
	  &getNetstatFilter( "tcp", "",
				"\.*SYN\.* src=\.* dst=$ip_backend sport=\.* dport=$port_backend\.*",
				"", @netstat );
}

sub getUdpBackendSYNConns   # ($farm_name, $ip_backend, $port_backend, @netstat)
{
	my ( $farm_name, $ip_backend, $port_backend, @netstat ) = @_;

	return
	  &getNetstatFilter( "udp", "",
		"\.* src=\.* dst=$ip_backend \.* dport=$port_backend \.*UNREPLIED\.* src=\.*",
		"", @netstat );
}

#
sub getTcpFarmSYNConns      # ($farm_name, @netstat)
{
	my ( $farm_name, @netstat ) = @_;

	my $vip      = &getFarmVip( "vip",  $farm_name );
	my $vip_port = &getFarmVip( "vipp", $farm_name );

	return
	  &getNetstatFilter( "tcp", "",
				  "\.*SYN\.* src=\.* dst=$vip sport=\.* dport=$vip_port \.* src=\.*",
				  "", @netstat );
}
#
sub getUdpFarmSYNConns    # ($farm_name, @netstat)
{
	my ( $farm_name, @netstat ) = @_;

	my $vip      = &getFarmVip( "vip",  $farm_name );
	my $vip_port = &getFarmVip( "vipp", $farm_name );

	return
	  &getNetstatFilter( "udp", "",
				  "\.* src=\.* dst=$vip \.* dport=$vip_port \.*UNREPLIED\.* src=\.*",
				  "", @netstat );
}

# Returns farm status
sub getTcpUdpFarmBootStatus    # ($farm_name)
{
	my ( $farm_name ) = @_;

	my $farm_filename = &getFarmFile( $farm_name );
	my $output        = "down";

	open FO, "<$configdir/$farm_filename";
	while ( $line = <FO> )
	{
		$lastline = $line;
	}
	close FO;

	if ( $lastline !~ /^#down/ )
	{
		$output = "up";
	}

	return $output;
}

# Start Farm rutine
sub _runTcpUdpFarmStart    # ($farm_name)
{
	my ( $farm_name ) = @_;

	my $status   = -1;
	my $run_farm = &getFarmCommand( $farm_name );

	&logfile( "running $pen_bin $run_farm" );
	zsystem( "$pen_bin $run_farm" );
	$status = $?;

	return $status;
}

# Stop Farm rutine
sub _runTcpUdpFarmStop    # ($farm_name)
{
	my ( $farm_name ) = @_;

	my $pid = &getFarmPid( $farm_name );

	&logfile( "running 'kill 15, $pid'" );
	kill 15, $pid;

	return $?;
}

#
sub runTcpFarmCreate    # ($vip,$vip_port,$farm_name)
{
	my ( $vip, $vip_port, $farm_name ) = @_;

	my $output    = -1;
	my $farm_port = &setFarmPort();

	# execute pen command
	my $pen_command =
	  "$pen_bin $vip:$vip_port -c 2049 -x 257 -S 10 -C 127.0.0.1:$farm_port";
	&logfile( "running '$pen_command'" );
	system ( "$pen_command >/dev/null 2>&1" );
	$output = $?;

	# execute pen_ctl command
	my $pen_ctl_command =
	  "$pen_ctl 127.0.0.1:$farm_port acl 9 deny 0.0.0.0 0.0.0.0";
	&logfile( "running '$pen_ctl_command" );
	system ( "$pen_ctl_command >/dev/null 2>&1" );

	# write configuration file
	$pen_ctl_command =
	  "$pen_ctl 127.0.0.1:$farm_port write '$configdir/$farm_name\_pen.cfg'";
	&logfile( "running $pen_ctl_command" );
	system ( "$pen_ctl_command >/dev/null 2>&1" );

	return $output;
}

#
sub runUdpFarmCreate    # ($vip,$vip_port,$farm_name)
{
	my ( $vip, $vip_port, $farm_name ) = @_;

	my $output    = -1;
	my $farm_port = &setFarmPort();

	# execute pen command
	my $pen_command =
	  "$pen_bin $vip:$vip_port -U -t 1 -b 3 -c 2049 -x 257 -S 10 -C 127.0.0.1:$farm_port";
	&logfile( "running '$pen_command'" );
	system ( "$pen_command >/dev/null 2>&1" );
	$output = $?;

	# execute pen_ctl command
	my $pen_ctl_command =
	  "$pen_ctl 127.0.0.1:$farm_port acl 9 deny 0.0.0.0 0.0.0.0";
	&logfile( "running '$pen_ctl_command" );
	system ( "$pen_ctl_command >/dev/null 2>&1" );

	# write configuration file
	$pen_ctl_command =
	  "$pen_ctl 127.0.0.1:$farm_port write '$configdir/$farm_name\_pen\_udp.cfg'";
	&logfile( "running $pen_ctl_command" );
	system ( "$pen_ctl_command >/dev/null 2>&1" );

	return $output;
}

# Returns Farm blacklist
sub getFarmBlacklist    # ($farm_name)
{
	my ( $farm_name ) = @_;

	my $farm_type     = &getFarmType( $farm_name );
	my $farm_filename = &getFarmFile( $farm_name );
	my $output        = -1;

	if ( $farm_type eq "tcp" || $farm_type eq "udp" )
	{
		open FI, "$configdir/$farm_filename";
		my $exit = "false";
		while ( $line = <FI> || $exit eq "false" )
		{
			if ( $line =~ /^# pen/ )
			{
				$exit = "true";
				my @line_a = split ( "\ ", $line );
				if ( $farm_type eq "tcp" )
				{
					$admin_ip = $line_a[11];
				}
				else
				{
					$admin_ip = $line_a[12];
				}
				my @blacklist = `$pen_ctl $admin_ip blacklist 2> /dev/null`;
				if   ( @blacklist =~ /^[1-9].*/ ) { $output = "@blacklist"; }
				else                              { $output = "-"; }
			}
		}
		close FI;
	}

	return $output;
}

# Returns farm max connections
sub getTcpUdpFarmMaxConn    # ( $farm_name )
{
	my ( $farm_name ) = @_;

	my $farm_filename = &getFarmFile( $farm_name );
	my $farm_type     = &getFarmType( $farm_name );
	my $output        = -1;
	my $exit          = "false";
	my $admin_ip;

	open FI, "$configdir/$farm_filename";
	while ( my $line = <FI> || $exit eq "false" )
	{
		if ( $line =~ /^# pen/ )
		{
			$exit = "true";
			my @line_a = split ( "\ ", $line );

			if ( $farm_type eq "tcp" )
			{
				$admin_ip = $line_a[11];
			}
			else
			{
				$admin_ip = $line_a[12];
			}

			my @conn_max = `$pen_ctl $admin_ip conn_max 2> /dev/null`;

			if ( @conn_max =~ /^[1-9].*/ )
			{
				$output = "@conn_max";
			}
			else
			{
				$output = "-";
			}
		}
	}
	close FI;

	return $output;
}

# Returns farm listen port
sub getTcpUdpFarmPort    # ($farm_name)
{
	my ( $farm_name ) = @_;

	my $farm_filename = &getFarmFile( $farm_name );
	my $farm_type     = &getFarmType( $farm_name );
	my $output        = -1;
	my $exit          = "false";
	my $port_manage;

	open FI, "$configdir/$farm_filename";
	while ( my $line = <FI> || $exit eq "false" )
	{
		if ( $line =~ /^# pen/ )
		{
			$exit = "true";
			my @line_a = split ( "\ ", $line );
			if ( $farm_type eq "tcp" )
			{
				$port_manage = $line_a[11];
			}
			else
			{
				$port_manage = $line_a[12];
			}
			my @managep = split ( ":", $port_manage );
			$output = $managep[1];
		}
	}
	close FI;

	return $output;
}

# Only used by tcpudp_func
# Returns farm command
sub getFarmCommand    # ($farm_name)
{
	my ( $farm_name ) = @_;

	my $farm_type     = &getFarmType( $farm_name );
	my $farm_filename = &getFarmFile( $farm_name );
	my $output        = -1;

	if ( $farm_type eq "tcp" || $farm_type eq "udp" )
	{
		open FI, "$configdir/$farm_filename";
		my $exit = "false";
		while ( $line = <FI> || $exit eq "false" )
		{
			if ( $line =~ /^# pen/ )
			{
				$exit = "true";
				$line =~ s/^#\ pen//;
				$output = $line;
			}
		}
		close FI;
	}

	return $output;
}

# Returns farm PID
sub getTcpUdpFarmPid    # ($farm_name)
{
	my ( $farm_name ) = @_;

	my $farm_filename = &getFarmFile( $farm_name );
	my $output        = -1;
	my $exit          = "false";

	open FI, "$configdir/$farm_filename";
	while ( my $line = <FI> || $exit eq "false" )
	{
		if ( $line =~ /^# pen/ )
		{
			$exit = "true";
			my @line_a      = split ( "\ ", $line );
			my @ip_and_port = split ( ":",  $line_a[-2] );
			my $admin_ip    = "$ip_and_port[0]:$ip_and_port[1]";
			my @pid         = `$pen_ctl $admin_ip pid 2> /dev/null`;

			if ( @pid =~ /^[1-9].*/ )
			{
				$output = "@pid";
			}
			else
			{
				$output = "-";
			}
		}
	}
	close FI;

	return $output;
}

# Returns farm vip
sub getTcpUdpFarmVip    # ($info,$farm_name)
{
	my ( $info, $farm_name ) = @_;

	my $farm_filename = &getFarmFile( $farm_name );
	my $output        = -1;
	my $exit          = "false";

	open FI, "$configdir/$farm_filename";

	while ( my $line = <FI> || $exit eq "false" )
	{
		# find line with pen command
		if ( $line =~ /^# pen/ )
		{
			$exit = "true";
			my @line_a = split ( "\ ", $line );

			# use last argument
			$vip_port = $line_a[-1];
			my @vipp = split ( ":", $vip_port );

			if ( $info eq "vip" )   { $output = $vipp[0]; }
			if ( $info eq "vipp" )  { $output = $vipp[1]; }
			if ( $info eq "vipps" ) { $output = "$vip_port"; }
		}
	}
	close FI;

	return $output;
}

# Set farm virtual IP and virtual PORT
sub setTcpUdpFarmVirtualConf    # ($vip,$vip_port,$farm_name)
{
	my ( $vip, $vip_port, $farm_name ) = @_;

	my $farm_filename = &getFarmFile( $farm_name );
	my $vips          = &getFarmVip( "vipps", $farm_name );
	my $stat          = -1;

	use Tie::File;
	tie @configfile, 'Tie::File', "$configdir\/$farm_filename";

	for ( @configfile )
	{
		if ( $_ =~ "# pen" )
		{
			s/$vips/$vip:$vip_port/g;
			$stat = $?;
		}
	}
	untie @configfile;

	return $stat;
}

#
sub setTcpUdpFarmServer    # ($ids,$rip,$port,$max,$weight,$priority,$farm_name)
{
	my ( $ids, $rip, $port, $max, $weight, $priority, $farm_name, ) = @_;

	my $farm_filename = &getFarmFile( $farm_name );
	my $fmaxservers   = &getFarmMaxServers( $farm_name );
	my $farm_port     = &getFarmPort( $farm_name );
	my $output        = -1;

	if ( $max ne "" )      { $max      = "max $max"; }
	if ( $weight ne "" )   { $weight   = "weight $weight"; }
	if ( $priority ne "" ) { $priority = "prio $priority"; }

	# pen setup server
	my $pen_ctl_command =
	  "$pen_ctl 127.0.0.1:$farm_port server $ids address $rip port $port $max $weight $priority";

	&logfile( "running '$pen_ctl_command' in $farm_name farm" );
	system ( "$pen_ctl_command >/dev/null 2>&1" );
	$output = $?;

	# pen write configuration file
	my $pen_write_config_command =
	  "$pen_ctl 127.0.0.1:$farm_port write '$configdir/$farm_filename'";

	&logfile( "running '$pen_write_config_command'" );
	system ( "$pen_write_config_command >/dev/null 2>&1" );

	&setFarmMaxServers( $fmaxservers, $farm_name );

	return $output;
}

#
sub runTcpUdpFarmServerDelete    # ($ids,$farm_name)
{
	my ( $ids, $farm_name ) = @_;

	my $farm_filename = &getFarmFile( $farm_name );
	my $fmaxservers   = &getFarmMaxServers( $farm_name );
	my $farm_port     = &getFarmPort( $farm_name );
	my $output        = -1;

	my $pen_ctl_command =
	  "$pen_ctl 127.0.0.1:$farm_port server $ids address 0 port 0 max 0 weight 0 prio 0";

	&logfile(
			  "running '$pen_ctl_command' deleting server $ids in $farm_name farm" );
	system ( "$pen_ctl_command >/dev/null 2>&1" );
	$output = $?;

	my $pen_write_config_command =
	  "$pen_ctl 127.0.0.1:$farm_port write '$configdir/$farm_filename'";

	&logfile( "running '$pen_write_config_command'" );
	system ( "$pen_write_config_command >/dev/null 2>&1" );

	&setFarmMaxServers( $fmaxservers, $farm_name );

	return $output;
}

#
sub getTcpUdpFarmBackendStatusCtl    # ($farm_name)
{
	my ( $farm_name ) = @_;

	my $mport = &getFarmPort( $farm_name );

	return `$pen_ctl 127.0.0.1:$mport status`;
}

#function that return the status information of a farm:
#ip, port, backendstatus, weight, priority, clients
sub getTcpUdpFarmBackendsStatus    # ($farm_name,@content)
{
	my ( $farm_name, @content ) = @_;

	my @backends_data;

	if ( !@content )
	{
		@content = &getFarmBackendStatusCtl( $farm_name );
	}

	foreach ( @content )
	{
		$i++;
		if ( $_ =~ /\<tr\>/ )
		{
			$trc++;
		}
		if ( $_ =~ /Time/ )
		{
			$_ =~ s/\<p\>//;
			my @value_backend = split ( ",", $_ );
		}
		if ( $trc >= 2 && $_ =~ /\<tr\>/ )
		{
			#backend ID
			$content[$i] =~ s/\<td\>//;
			$content[$i] =~ s/\<\/td\>//;
			$content[$i] =~ s/\n//;
			my $id_backend = $content[$i];
			$line = $id_backend;

			#backend IP,PORT
			$content[$i + 1] =~ s/\<td\>//;
			$content[$i + 1] =~ s/\<\/td\>//;
			$content[$i + 1] =~ s/\n//;
			my $ip_backend = $content[$i + 1];
			$line = $line . "\t" . $ip_backend;

			#
			$content[$i + 3] =~ s/\<td\>//;
			$content[$i + 3] =~ s/\<\/td\>//;
			$content[$i + 3] =~ s/\n//;
			my $port_backend = $content[$i + 3];
			$line = $line . "\t" . $port_backend;

			#status
			$content[$i + 2] =~ s/\<td\>//;
			$content[$i + 2] =~ s/\<\/td\>//;
			$content[$i + 2] =~ s/\n//;
			my $status_maintenance = &getFarmBackendMaintenance( $farm_name, $id_backend );
			my $status_backend = $content[$i + 2];
			if ( $status_maintenance eq "0" )
			{
				$status_backend = "MAINTENANCE";
			}
			elsif ( $status_backend eq "0" )
			{
				$status_backend = "UP";
			}
			else
			{
				$status_backend = "DEAD";
			}
			$line = $line . "\t" . $status_backend;

			#weight
			$content[$i + 9] =~ s/\<td\>//;
			$content[$i + 9] =~ s/\<\/td\>//;
			$content[$i + 9] =~ s/\n//;
			my $w_backend = $content[$i + 9];
			$line = $line . "\t" . $w_backend;

			#priority
			$content[$i + 10] =~ s/\<td\>//;
			$content[$i + 10] =~ s/\<\/td\>//;
			$content[$i + 10] =~ s/\n//;
			my $p_backend = $content[$i + 10];
			$line = $line . "\t" . $p_backend;

			#sessions
			if ( $ip_backend ne "0\.0\.0\.0" )
			{
				my $clients = &getFarmBackendsClients( $id_backend, @content, $farm_name );
				if ( $clients != -1 )
				{
					$line = $line . "\t" . $clients;
				}
				else
				{
					$line = $line . "\t-";
				}
			}

			#end
			push ( @backends_data, $line );
		}
		if ( $_ =~ /\/table/ )
		{
			last;
		}
	}

	return @backends_data;
}

#function that return the status information of a farm:
sub getTcpUdpFarmBackendsClients    # ($idserver,@content,$farm_name)
{
	my ( $idserver, @content, $farm_name ) = @_;

	my $numclients = 0;

	if ( !@content )
	{
		@content = &getFarmBackendStatusCtl( $farm_name );
	}

	if ( !@sessions )
	{
		@sessions = &getFarmBackendsClientsList( $farm_name, @content );
	}

	foreach ( @sessions )
	{
		my @ses_client = split ( "\t", $_ );
		chomp ( $ses_client[3] );
		chomp ( $idserver );
		if ( $ses_client[3] eq $idserver )
		{
			$numclients++;
		}
	}

	return $numclients;
}

#function that return the status information of a farm:
sub getTcpUdpFarmBackendsClientsList    # ($farm_name,@content)
{
	my ( $farm_name, @content ) = @_;

	my @client_list;
	my $ac_header = 0;
	my $i         = 0;

	if ( !@content )
	{
		@content = &getFarmBackendStatusCtl( $farm_name );
	}

	foreach ( @content )
	{
		my $line;
		my $tr = 0;

		if ( $_ =~ /Active clients/ )
		{
			$ac_header = 1;
			@value_session = split ( "\<\/h2\>", $_ );
			$value_session[1] =~ s/\<p\>\<table bgcolor\=\"#c0c0c0\">//;
			$line = $value_session[1];
			push ( @client_list, "Client sessions status\t$line" );
		}

		if ( $ac_header == 1 && $_ =~ /\<tr\>/ )
		{
			$tr++;
		}

		if ( $tr >= 2 && $_ =~ /\<tr\>/ )
		{
			$content[$i + 1] =~ s/\<td\>//;
			$content[$i + 1] =~ s/\<\/td\>//;
			chomp ( $content[$i + 1] );
			$line = $content[$i + 1];

			#
			$content[$i + 2] =~ s/\<td\>//;
			$content[$i + 2] =~ s/\<\/td\>//;
			chomp ( $content[$i + 2] );

			#
			$line = $line . "\t" . $content[$i + 2];
			$content[$i + 3] =~ s/\<td\>//;
			$content[$i + 3] =~ s/\<\/td\>//;
			chomp ( $content[$i + 3] );

			#
			$line = $line . "\t" . $content[$i + 3];
			$content[$i + 4] =~ s/\<td\>//;
			$content[$i + 4] =~ s/\<\/td\>//;

			#
			$line = $line . "\t" . $content[$i + 4];
			$content[$i + 5] =~ s/\<td\>//;
			$content[$i + 5] =~ s/\<\/td\>//;

			#
			$line = $line . "\t" . $content[$i + 5];
			$content[$i + 6] =~ s/\<td\>//;
			$content[$i + 6] =~ s/\<\/td\>//;
			$content[$i + 6] = $content[$i + 6] / 1024 / 1024;
			$content[$i + 6] = sprintf ( '%.2f', $content[$i + 6] );

			#
			$line = $line . "\t" . $content[$i + 6];
			$content[$i + 7] =~ s/\<td\>//;
			$content[$i + 7] =~ s/\<\/td\>//;
			$content[$i + 7] = $content[$i + 7] / 1024 / 1024;
			$content[$i + 7] = sprintf ( '%.2f', $content[$i + 7] );

			#
			$line = $line . "\t" . $content[$i + 7];
			push ( @client_list, $line );
		}

		if ( $ac_header == 1 && $_ =~ /\<\/table\>/ )
		{
			last;
		}
		$i++;
	}

	return @client_list;
}

# Only used for tcp/udp
sub getFarmBackendsClientsActives    # ($farm_name,@content)
{
	my ( $farm_name, @content ) = @_;

	my $farm_type = &getFarmType( $farm_name );
	my @s_data;

	if ( $farm_type eq "tcp" || $farm_type eq "udp" )
	{
		if ( !@content )
		{
			@content = &getFarmBackendStatusCtl( $farm_name );
		}

		my $line;
		my @sess;
		my $ac_header = 0;
		my $tr        = 0;
		my $i         = -1;

		foreach ( @content )
		{
			$i++;
			if ( $_ =~ /Active connections/ )
			{
				$ac_header = 1;
				my @value_conns = split ( "\<\/h2\>", $_ );
				$value_conns[1] =~ s/\<p\>\<table bgcolor\=\"#c0c0c0\"\>//;
				$value_conns[1] =~ s/Number of connections\://;
				$line = "Active connections\t$value_conns[1]";
				push ( @s_data, $line );
			}
			if ( $ac_header == 1 && $_ =~ /\<tr\>/ )
			{
				$tr++;
			}
			if ( $tr >= 2 && $_ =~ /\<tr\>/ )
			{
				$content[$i + 1] =~ s/\<td\>//;
				$content[$i + 1] =~ s/\<\/td\>//;
				chomp ( $content[$i + 1] );
				$line = $content[$i + 1];

				#
				$content[$i + 6] =~ s/\<td\>//;
				$content[$i + 6] =~ s/\<\/td\>//;
				$line = $line . "\t" . $content[$i + 6];

				#
				$content[$i + 7] =~ s/\<td\>//;
				$content[$i + 7] =~ s/\<\/td\>//;
				$line = $line . "\t" . $content[$i + 7];

				push ( @s_data, $line );
			}
			if ( $ac_header == 1 && $_ =~ /\<\/table\>/ )
			{
				last;
			}
		}
	}

	return @s_data;
}

#function that renames a farm
sub setTcpUdpNewFarmName    # ($farm_name,$new_farm_name)
{
	my ( $farm_name, $new_farm_name ) = @_;

	my $farm_filename = &getFarmFile( $farm_name );
	my $farm_type     = &getFarmType( $farm_name );
	my $output        = -1;

	my $new_farm_filename = "$new_farm_name\_pen.cfg";

	if ( $farm_type eq "udp" )
	{
		$new_farm_filename = "$new_farm_name\_pen\_udp.cfg";
	}
	my $farmguardian_filename = "$farm_name\_guardian.conf";

	use Tie::File;
	tie my @configfile, 'Tie::File', "$configdir\/$farm_filename";

	for ( @configfile )
	{
		s/$farm_name/$new_farm_name/g;
	}
	untie @configfile;

	rename ( "$configdir\/$farm_filename", "$configdir\/$new_farm_filename" );
	$output = $?;

	&logfile( "configuration saved in $configdir/$new_farm_filename file" );

	if ( -e "$configdir\/$farmguardian_filename" )
	{
		my $new_farmguardian_filename = "$new_farm_name\_guardian.conf";

		use Tie::File;
		tie my @farmgardian_configfile, 'Tie::File',
		  "$configdir\/$farmguardian_filename";

		for ( @farmgardian_configfile )
		{
			s/$farm_name/$new_farm_name/g;
		}
		untie @farmgardian_configfile;

		rename ( "$configdir\/$farmguardian_filename",
				 "$configdir\/$new_farmguardian_filename" );
		$output = $?;

		&logfile( "configuration saved in $configdir/$new_farmguardian_filename file" );
	}

	return $output;
}

#function that check if a backend on a farm is on maintenance mode
sub getTcpUdpFarmBackendMaintenance    # ($farm_name,$backend)
{
	my ( $farm_name, $backend ) = @_;

	my $farm_filename = &getFarmFile( $farm_name );
	my $output        = -1;

	open FR, "<$configdir\/$farm_filename";
	my @configfile = <FR>;

	foreach my $line ( @configfile )
	{
		if ( $line =~ /^server $backend acl 9/ )
		{
			$output = 0;
		}
	}
	close FR;

	return $output;
}

#function that enable the maintenance mode for backend
sub setTcpUdpFarmBackendMaintenance    # ($farm_name,$backend)
{
	my ( $farm_name, $backend ) = @_;

	my $farm_filename = &getFarmFile( $farm_name );
	my $fmaxservers   = &getFarmMaxServers( $farm_name );
	my $farm_port     = &getFarmPort( $farm_name );
	my $output        = -1;

	&logfile( "setting Maintenance mode for $farm_name backend $backend" );

	my $pen_ctl_command = "$pen_ctl 127.0.0.1:$farm_port server $backend acl 9";

	&logfile( "running '$pen_ctl_command'" );
	system ( "$pen_ctl_command >/dev/null 2>&1" );
	$output = $?;

	my $pen_write_config_command =
	  "$pen_ctl 127.0.0.1:$farm_port write '$configdir/$farm_filename'";

	&logfile( "running '$pen_write_config_command'" );
	system ( "$pen_write_config_command >/dev/null 2>&1" );

	&setFarmMaxServers( $fmaxservers, $farm_name );

	return $output;
}

#function that disable the maintenance mode for backend
sub setTcpUdpFarmBackendNoMaintenance    # ($farm_name,$backend)
{
	my ( $farm_name, $backend ) = @_;

	my $farm_filename = &getFarmFile( $farm_name );
	my $farm_port     = &getFarmPort( $farm_name );
	my $fmaxservers   = &getFarmMaxServers( $farm_name );
	my $output        = -1;

	&logfile( "setting Disabled maintenance mode for $farm_name backend $backend" );

	#
	my $pen_ctl_command = "$pen_ctl 127.0.0.1:$farm_port server $backend acl 0";

	&logfile( "running '$pen_ctl_command'" );
	system ( "$pen_ctl_command >/dev/null 2>&1" );
	$output = $?;

	#
	my $pen_write_config_command =
	  "$pen_ctl 127.0.0.1:$farm_port write '$configdir/$farm_filename'";

	&logfile( "running '$pen_write_config_command'" );
	system ( "$pen_write_config_command >/dev/null 2>&1" );

	&setFarmMaxServers( $fmaxservers, $farm_name );

	return $output;
}

# do not remove this
1
