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

my $configdir = &getGlobalConfiguration( 'configdir' );

=begin nd
Function: getL4FarmParam

	Returns farm parameter

Parameters:
	param - requested parameter. The options are:
		"vip": get the virtual IP
		"vipp": get the virtual port
		"status": get the current status
		"bootstatus": get the boot status
		"mode": get the topology (or nat type)
		"alg": get the algorithm
		"proto": get the protocol
		"persist": get persistence
		"persisttm": get client persistence timeout
		"logs": write the logs option
	farmname - Farm name

Returns:
	Scalar - return the parameter as a string or -1 on failure

=cut

sub getL4FarmParam    # ($param, $farm_name)
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my ( $param, $farm_name ) = @_;

	my $farm_filename = &getFarmFile( $farm_name );
	my $output        = -1;

	open my $fd, '<', "$configdir/$farm_filename";
	chomp ( my @content = <$fd> );
	close $fd;

	if ( $param eq "status" )
	{
		return &getL4FarmStatus( $farm_name );
	}

	$output = &_getL4ParseFarmConfig( $param, undef, \@content );

	return $output;
}

=begin nd
Function: setL4FarmParam

	Writes a farm parameter

Parameters:
	param - requested parameter. The options are:
		"family": write ipv4 or ipv6
		"vip": write the virtual IP
		"vipp": write the virtual port
		"status": write the boot status
		"mode": write the topology (or nat type)
		"alg": write the algorithm
		"proto": write the protocol
		"persist": write persistence
		"persisttm": write client persistence timeout
		"logs": write the logs option
	value - the new value of the given parameter of a certain farm
	farmname - Farm name

Returns:
	Scalar - return the parameter as a string or -1 on failure

=cut

sub setL4FarmParam    # ($param, $value, $farm_name)
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my ( $param, $value, $farm_name ) = @_;

	my $farm_filename = &getFarmFile( $farm_name );
	my $output        = -1;
	my $srvparam      = "";

	if ( $param eq "vip" )
	{
		$output = &setL4FarmVirtualConf( $value, undef, $farm_name );
	}
	elsif ( $param eq "vipp" )
	{
		$output = &setL4FarmVirtualConf( undef, $value, $farm_name );
	}
	elsif ( $param eq "bootstatus" )
	{
		$output = &setL4FarmBootStatus( $value, $farm_name );
	}
	elsif ( $param eq "alg" )
	{
		$output = &setL4FarmAlgorithm( $value, $farm_name );
	}
	elsif ( $param eq "proto" )
	{
		$output = &setL4FarmProto( $value, $farm_name );
	}
	elsif ( $param eq "mode" )
	{
		$output = &setFarmNatType( $value, $farm_name );
	}
	elsif ( $param eq "persist" )
	{
		$output = &setL4FarmSessionType( $value, $farm_name );
	}
	elsif ( $param eq "persisttm" )
	{
		$output = &setL4FarmMaxClientTime( $value, $farm_name );
	}
	elsif ( $param eq "logs" )
	{
		$output = &setL4FarmLogs( $farm_name, $value );
	}
	else
	{
		return -1;
	}

	return $output;
}

=begin nd
Function: _getL4ParseFarmConfig

	Parse the farm file configuration and read/write a certain parameter

Parameters:
	param - requested parameter. The options are "family", "vip", "vipp", "status", "mode", "alg", "proto", "persist", "presisttm", "logs"
	value - value to be changed in case of write operation, undef for read only cases
	config - reference of an array with the full configuration file

Returns:
	Scalar - return the parameter value on read or the changed value in case of write as a string or -1 in other case

=cut

sub _getL4ParseFarmConfig    # ($param, $value, $config)
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );

	my $param  = shift;
	my $value  = shift;
	my $config = shift;
	my $output = -1;
	my $first  = "true";

	foreach my $line ( @{ $config } )
	{
		if ( $line eq "" || $first ne "true" )
		{
			last;
		}

		$first = "false";
		my @l = split ( "\;", $line );

		if ( $param eq 'proto' )
		{
			$output = $l[1];
			last;
		}

		if ( $param eq 'vip' )
		{
			$output = $l[2];
			last;
		}

		if ( $param eq 'vipp' )
		{
			$output = $l[3];
			last;
		}

		if ( $param eq 'mode' )
		{
			$output = $l[4];
			last;
		}

		if ( $param eq 'alg' )
		{
			$output = $l[5];
			last;
		}

		if ( $param eq 'persist' )
		{
			$output = $l[6];
			last;
		}

		if ( $param eq 'persisttm' )
		{
			$output = $l[7];
			last;
		}

		if ( $param eq 'logs' )
		{
			$output = $l[9];
			last;
		}

		if ( $param eq 'bootstatus' )
		{
			if ( $l[8] ne "up" )
			{
				$output = "down";
			}
			else
			{
				$output = "up";
			}
			last;
		}
	}

	return $output;
}

=begin nd
Function: getL4FarmsPorts

	Get all port used of L4xNAT farms in up status and using a protocol

Parameters:
	protocol - protocol used by l4xnat farm

Returns:
	String - return a list with the used ports by all L4xNAT farms. Format: "portList1,portList2,..."

=cut

sub getL4FarmsPorts    # ($protocol)
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $protocol = shift;

	my @port_list = ();
	my @farms     = &getFarmsByType( 'l4xnat' );

	unless ( $#farms > -1 )
	{
		return "";
	}

	foreach my $farm_name ( @farms )
	{
		my $farm_protocol = &getL4FarmParam( 'proto', $farm_name );

		next if not ( $protocol eq $farm_protocol );
		next if ( &getL4FarmParam( 'status', $farm_name ) ne "up" );

		my $farm_port = &getL4FarmParam( 'vipp', $farm_name );
		$farm_port = join ( ',', &getFarmPortList( $farm_port ) );

		next if not &validL4ExtPort( $farm_protocol, $farm_port );

		push @port_list, $farm_port;
	}

	return join ( ',', @port_list );
}

=begin nd
Function: loadL4Modules

	Load sip, ftp or tftp conntrack module for l4 farms

Parameters:
	protocol - protocol module to load

Returns:
	Integer - 0 if success, otherwise error

=cut

sub loadL4Modules    # ($protocol)
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $protocol = shift;

	require Zevenet::Netfilter;

	my $status = 0;

	if ( $protocol == /sip|tftp|ftp/ )
	{
		$status = &loadNfModule( "nf_conntrack_$protocol", "" );
		$status = $status || &loadNfModule( "nf_nat_$protocol", "" );
	}

	return $status;
}

=begin nd
Function: unloadL4Modules

	Unload sip, ftp or tftp conntrack module for l4 farms

Parameters:
	protocol - protocol module to load

Returns:
	Integer - 0 if success, otherwise error

=cut

sub unloadL4Modules    # ($protocol)
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $protocol = shift;
	my $status   = 0;

	require Zevenet::Netfilter;

	if ( $protocol =~ /sip|tftp|ftp/ )
	{
		$status = &removeNfModule( "nf_nat_$protocol" );
		$status = $status || &removeNfModule( "nf_conntrack_$protocol", "" );
	}

	return $status;
}

=begin nd
Function: setL4FarmSessionType

	Configure type of persistence session

Parameters:
	session - Session type. The options are: "none" not use persistence or "ip" for ip persistencia
	farmname - Farm name

Returns:
	Integer - Error code: 0 on success or other value on failure

=cut

sub setL4FarmSessionType    # ($session,$farm_name)
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my ( $session, $farm_name ) = @_;

	my $farm_filename = &getFarmFile( $farm_name );
	my $output        = 0;
	my $i             = 0;

	require Zevenet::Farm::L4xNAT::Action;
	require Zevenet::FarmGuardian;
	require Tie::File;

	my $farm       = &getL4FarmStruct( $farm_name );
	my $fg_enabled = ( &getFarmGuardianConf( $$farm{ name } ) )[3];
	my $fg_pid;

	if ( $$farm{ status } eq 'up' && $fg_enabled eq 'true' )
	{
		$fg_pid = &getFarmGuardianPid( $farm_name );
		kill 'STOP' => $fg_pid if ( $fg_pid > 0 );
	}

	&zlog( "setL4FarmSessionType: SessionType" ) if &debug;

	tie my @configfile, 'Tie::File', "$configdir\/$farm_filename";

	for my $line ( @configfile )
	{
		if ( $line =~ /^$farm_name\;/ )
		{
			my @args = split ( "\;", $line );
			$line =
			  "$args[0]\;$args[1]\;$args[2]\;$args[3]\;$args[4]\;$args[5]\;$session\;$args[7]\;$args[8];$args[9]";
			splice @configfile, $i, $line;
		}
		$i++;
	}
	untie @configfile;

	$farm = &getL4FarmStruct( $farm_name );

	return $output if ( $$farm{ status } ne 'up' );

	&stopL4Farm( $farm_name );
	$output |= &startL4Farm( $farm_name );

	kill 'CONT' => $fg_pid if ( $fg_enabled eq 'true' && $fg_pid > 0 );

	return $output;
}

=begin nd
Function: setL4FarmAlgorithm

	Set the load balancing algorithm to a farm

Parameters:
	algorithm - Load balancing algorithm. The options are: "leastconn" , "weight" or "prio"
	farmname - Farm name

Returns:
	Integer - always return 0

FIXME:
	do error control

=cut

sub setL4FarmAlgorithm    # ($algorithm,$farm_name)
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my ( $algorithm, $farm_name ) = @_;

	require Zevenet::FarmGuardian;
	require Tie::File;

	my $farm_filename = &getFarmFile( $farm_name );
	my $output        = -1;
	my $i             = 0;
	my $prev_alg      = &getL4FarmParam( 'alg', $farm_name );   # previous algorithm

	my $farm       = &getL4FarmStruct( $farm_name );
	my $fg_enabled = ( &getFarmGuardianConf( $$farm{ name } ) )[3];
	my $fg_pid;

	if ( $$farm{ status } eq 'up' && $fg_enabled eq 'true' )
	{
		$fg_pid = &getFarmGuardianPid( $farm_name );
		kill 'STOP' => $fg_pid if ( $fg_pid > 0 );
	}

	tie my @configfile, 'Tie::File', "$configdir\/$farm_filename";

	for my $line ( @configfile )
	{
		if ( $line =~ /^$farm_name\;/ )
		{
			my @args = split ( "\;", $line );
			$line =
			  "$args[0]\;$args[1]\;$args[2]\;$args[3]\;$args[4]\;$algorithm\;$args[6]\;$args[7]\;$args[8];$args[9]";
			splice @configfile, $i, $line;
			$output = $?;
		}
		$i++;
	}
	untie @configfile;
	$output = $?;

	$farm = &getL4FarmStruct( $farm_name );

	return $output if ( $$farm{ status } ne 'up' );

	&refreshL4FarmRules( $farm );

	# manage l4sd
	my $l4sd_pidfile = '/var/run/l4sd.pid';
	my $l4sd         = &getGlobalConfiguration( 'l4sd' );

	if ( $$farm{ lbalg } eq 'leastconn' && -e "$l4sd" )
	{
		system ( "$l4sd >/dev/null 2>&1 &" );
	}
	elsif ( -e $l4sd_pidfile )
	{
		require Zevenet::Lock;

		## lock iptables use ##
		my $iptlock = &getGlobalConfiguration( 'iptlock' );
		my $ipt_lockfile = &openlock( $iptlock, 'w' );

		# Get the binary of iptables (iptables or ip6tables)
		my $iptables_bin = &getBinVersion( $farm_name );

		my $num_lines = grep { /-m condition --condition/ }
		  `$iptables_bin --numeric --table mangle --list PREROUTING`;

		## unlock iptables use ##
		close $ipt_lockfile;

		if ( $num_lines == 0 )
		{
			# stop l4sd
			if ( open my $pidfile, '<', $l4sd_pidfile )
			{
				my $pid = <$pidfile>;
				close $pidfile;

				# close normally
				kill 'TERM' => $pid if ( $pid > 0 );
				&zenlog( "l4sd ended", "info", "LSLB" );
			}
			else
			{
				&zenlog( "Error opening file l4sd_pidfile: $!", "error", "LSLB" )
				  if !defined $pidfile;
			}
		}
	}

	kill 'CONT' => $fg_pid if ( $fg_enabled eq 'true' && $fg_pid > 0 );

	return;
}

sub setL4FarmBootStatus    #( value, farm_name )
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $value         = shift;
	my $farm_name     = shift;
	my $farm_filename = &getFarmFile( $farm_name );

	require Tie::File;

	tie my @configfile, 'Tie::File', "$configdir\/$farm_filename";
	for my $line ( @configfile )
	{
		my @args = split ( "\;", $line );
		$line =
		  "$args[0]\;$args[1]\;$args[2]\;$args[3]\;$args[4]\;$args[5]\;$args[6]\;$args[7]\;$value;$args[9]";
		splice @configfile, 0, $line;
		last;    # run only for the first line
	}

	untie @configfile;
}

=begin nd
Function: setL4FarmProto

	Set the protocol to a L4 farm

Parameters:
	protocol - which protocol the farm will use to work. The available options are: "all", "tcp", "udp", "sip", "ftp" and "tftp"
	farmname - Farm name

Returns:
	Integer - Error code: 0 on success or other value in failure

FIXME:
	It is necessary more error control

=cut

sub setL4FarmProto    # ($proto,$farm_name)
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my ( $proto, $farm_name ) = @_;

	require Zevenet::FarmGuardian;
	require Zevenet::Netfilter;
	require Zevenet::Farm::L4xNAT::Action;

	my $farm_filename = &getFarmFile( $farm_name );
	my $output        = 0;

	&zenlog( "setting 'Protocol $proto' for $farm_name farm L4xNAT",
			 "info", "LSLB" );

	my $farm       = &getL4FarmStruct( $farm_name );
	my $old_proto  = $$farm{ vproto };
	my $fg_enabled = ( &getFarmGuardianConf( $$farm{ name } ) )[3];
	my $fg_pid;

	if ( $$farm{ status } eq 'up' && $fg_enabled eq 'true' )
	{
		$fg_pid = &getFarmGuardianPid( $farm_name );
		kill 'STOP' => $fg_pid if ( $fg_pid > 0 );
	}

	require Tie::File;
	tie my @configfile, 'Tie::File', "$configdir\/$farm_filename" or return 1;
	my $i = 0;

	for my $line ( @configfile )
	{
		if ( $line =~ /^$farm_name\;/ )
		{
			my @args = split ( "\;", $line );
			if ( $proto eq "all" )
			{
				$args[3] = "*";
			}
			$line =
			  "$args[0]\;$proto\;$args[2]\;$args[3]\;$args[4]\;$args[5]\;$args[6]\;$args[7]\;$args[8];$args[9]";
			splice @configfile, $i, $line;
		}
		$i++;
	}
	untie @configfile;

	$farm = &getL4FarmStruct( $farm_name );

	&stopL4Farm( $farm_name );

	if ( $$farm{ status } eq 'up' )
	{
		$output |= &startL4Farm( $farm_name );
		kill 'CONT' => $fg_pid if ( $fg_enabled eq 'true' && $fg_pid > 0 );
	}

	return $output;
}

=begin nd
Function: setFarmNatType

	Set the NAT type for a farm

Parameters:
	nat - Type of nat. The options are: "nat" or "dnat"
	farmname - Farm name

Returns:
	Scalar - 0 on success or other value on failure

=cut

sub setFarmNatType    # ($nat,$farm_name)
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my ( $nat, $farm_name ) = @_;

	my $farm_filename = &getFarmFile( $farm_name );
	my $output        = 0;

	require Zevenet::FarmGuardian;

	&zenlog( "setting 'NAT type $nat' for $farm_name farm L4xNAT", "info", "LSLB" );

	my $farm       = &getL4FarmStruct( $farm_name );
	my $fg_enabled = ( &getFarmGuardianConf( $$farm{ name } ) )[3];
	my $fg_pid;

	if ( $$farm{ status } eq 'up' && $fg_enabled eq 'true' )
	{
		if ( $0 !~ /farmguardian/ )
		{
			$fg_pid = &getFarmGuardianPid( $farm_name );
			kill 'STOP' => $fg_pid if ( $fg_pid > 0 );
		}
	}

	require Tie::File;

	tie my @configfile, 'Tie::File', "$configdir\/$farm_filename";
	my $i = 0;

	for my $line ( @configfile )
	{
		if ( $line =~ /^$farm_name\;/ )
		{
			my @args = split ( "\;", $line );
			$line =
			  "$args[0]\;$args[1]\;$args[2]\;$args[3]\;$nat\;$args[5]\;$args[6]\;$args[7]\;$args[8];$args[9]";
			splice @configfile, $i, $line;
		}
		$i++;
	}

	untie @configfile;

	$farm = &getL4FarmStruct( $farm_name );

	return $output if ( $$farm{ status } ne 'up' );

	&refreshL4FarmRules( $farm );

	kill 'CONT' => $fg_pid
	  if ( $fg_enabled eq 'true' && $0 !~ /farmguardian/ && $fg_pid > 0 );

	return $output;
}

=begin nd
Function: setL4FarmMaxClientTime

	 Set the max client time of a farm

Parameters:
	ttl - Persistence Session Time to Live
	farmname - Farm name

Returns:
	Integer - 0 on success or other value on failure

=cut

sub setL4FarmMaxClientTime    # ($track,$farm_name)
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my ( $track, $farm_name ) = @_;

	my $farm_filename = &getFarmFile( $farm_name );
	my $output        = -1;
	my $i             = 0;

	require Zevenet::FarmGuardian;
	require Tie::File;

	my $farm       = &getL4FarmStruct( $farm_name );
	my $fg_enabled = ( &getFarmGuardianConf( $$farm{ name } ) )[3];
	my $fg_pid;

	if ( $$farm{ status } eq 'up' && $fg_enabled eq 'true' )
	{
		$fg_pid = &getFarmGuardianPid( $farm_name );
		kill 'STOP' => $fg_pid if ( $fg_pid > 0 );
	}

	tie my @configfile, 'Tie::File', "$configdir\/$farm_filename";

	for my $line ( @configfile )
	{
		if ( $line =~ /^$farm_name\;/ )
		{
			my @args = split ( "\;", $line );
			$line =
			  "$args[0]\;$args[1]\;$args[2]\;$args[3]\;$args[4]\;$args[5]\;$args[6]\;$track\;$args[8];$args[9]";
			splice @configfile, $i, $line;
			$output = $?;
		}
		$i++;
	}
	untie @configfile;
	$output = $?;

	$farm = &getL4FarmStruct( $farm_name );

	return $output if ( $$farm{ status } ne 'up' );

	&refreshL4FarmRules( $farm );

	kill 'CONT' => $fg_pid if ( $fg_enabled eq 'true' && $fg_pid > 0 );

	return $output;
}

=begin nd
Function: setL4FarmVirtualConf

	Set farm virtual IP and virtual PORT

Parameters:
	vip - Farm virtual IP
	port - Farm virtual port. If the port is not sent, the port will not be changed
	farmname - Farm name

Returns:
	Scalar - 0 on success or other value on failure

=cut

sub setL4FarmVirtualConf    # ($vip,$vip_port,$farm_name)
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my ( $vip, $vip_port, $farm_name ) = @_;

	require Tie::File;
	require Zevenet::FarmGuardian;

	my $farm_filename = &getFarmFile( $farm_name );
	my $output        = 0;

	my $farm       = &getL4FarmStruct( $farm_name );
	my $fg_enabled = ( &getFarmGuardianConf( $$farm{ name } ) )[3];
	my $fg_pid;

	if ( $$farm{ status } eq 'up' && $fg_enabled eq 'true' )
	{
		$fg_pid = &getFarmGuardianPid( $farm_name );
		kill 'STOP' => $fg_pid if ( $fg_pid > 0 );
	}

	tie my @configfile, 'Tie::File', "$configdir\/$farm_filename";

	my $i = 0;
	for my $line ( @configfile )
	{
		if ( $line =~ /^$farm_name\;/ )
		{
			my @args = split ( "\;", $line );
			$vip      = $args[2] if ( !$vip );
			$vip_port = $args[3] if ( !$vip_port );
			$line =
			  "$args[0]\;$args[1]\;$vip\;$vip_port\;$args[4]\;$args[5]\;$args[6]\;$args[7]\;$args[8];$args[9]";
			splice @configfile, $i, $line;
		}
		$i++;
	}
	untie @configfile;

	$farm = &getL4FarmStruct( $farm_name );

	return $output if ( $$farm{ status } ne 'up' );

	&refreshL4FarmRules( $farm );

	kill 'CONT' => $fg_pid if ( $fg_enabled eq 'true' && $fg_pid > 0 );

	if ( $$farm{ vproto } =~ /sip|ftp/ )    # helpers
	{
		require Zevenet::Netfilter;
		&loadL4Modules( $$farm{ vproto } );

		my $rule_ref = &genIptHelpers( $farm );
		foreach my $rule ( @{ $rule_ref } )
		{
			$output |= &runIptables( &applyIptRuleAction( $rule, 'delete' ) );
			$output |= &runIptables( &applyIptRuleAction( $rule, 'append' ) );
		}
	}
	return $output;
}

=begin nd
Function: getFarmPortList

	If port is multiport, it removes range port and it passes it to a port list

Parameters:
	port - Port string

Returns:
	array - return a list of ports

=cut

sub getFarmPortList    # ($fvipp)
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $fvipp = shift;

	my @portlist = split ( ',', $fvipp );
	my @retportlist = ();

	if ( !grep ( /\*/, @portlist ) )
	{
		foreach my $port ( @portlist )
		{
			if ( $port =~ /:/ )
			{
				my @intlimits = split ( ':', $port );

				for ( my $i = $intlimits[0] ; $i <= $intlimits[1] ; $i++ )
				{
					push ( @retportlist, $i );
				}
			}
			else
			{
				push ( @retportlist, $port );
			}
		}
	}
	else
	{
		$retportlist[0] = '*';
	}

	return @retportlist;
}

=begin nd
Function: getL4ProtocolTransportLayer

	Return basic transport protocol used by l4 farm protocol

Parameters:
	protocol - L4xnat farm protocol

Returns:
	String - "udp" or "tcp"

=cut

sub getL4ProtocolTransportLayer
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $vproto = shift;

	return
	    ( $vproto eq 'sip' )  ? 'udp+tcp'
	  : ( $vproto eq 'tftp' ) ? 'udp'
	  : ( $vproto eq 'ftp' )  ? 'tcp'
	  :                         $vproto;
}

=begin nd
Function: getL4FarmStatus

	Return current farm status

Parameters:
	farm_name - Farm name

Returns:
	String - "up" or "down"

=cut

sub getL4FarmStatus
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $farm_name = shift;

	my $piddir = &getGlobalConfiguration( 'piddir' );
	open my $fi, '<', "$piddir\/$farm_name\_l4xnat.pid";
	close $fi;

	return "up" if ( $fi );
	return "down";
}

=begin nd
Function: getL4FarmStruct

	Return a hash with all data about a l4 farm

Parameters:
	farmname - Farm name

Returns:
	hash ref -
		\%farm = { $name, $filename, $nattype, $lbalg, $vip, $vport, $vproto, $persist, $ttl, $proto, $status, \@servers }
		\@servers = [ \%backend1, \%backend2, ... ]

=cut

sub getL4FarmStruct
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my %farm;    # declare output hash

	$farm{ name } = shift;    # input: farm name

	require Zevenet::Farm::L4xNAT::Backend;

	$farm{ filename } = &getFarmFile( $farm{ name } );
	my $config = &getL4FarmPlainInfo( $farm{ name } );

	$farm{ nattype }    = &_getL4ParseFarmConfig( 'mode', undef, $config );
	$farm{ mode }       = $farm{ nattype };
	$farm{ lbalg }      = &_getL4ParseFarmConfig( 'alg', undef, $config );
	$farm{ vip }        = &_getL4ParseFarmConfig( 'vip', undef, $config );
	$farm{ vport }      = &_getL4ParseFarmConfig( 'vipp', undef, $config );
	$farm{ vproto }     = &_getL4ParseFarmConfig( 'proto', undef, $config );
	$farm{ persist }    = &_getL4ParseFarmConfig( 'persist', undef, $config );
	$farm{ ttl }        = &_getL4ParseFarmConfig( 'persisttm', undef, $config );
	$farm{ proto }      = &getL4ProtocolTransportLayer( $farm{ vproto } );
	$farm{ bootstatus } = &_getL4ParseFarmConfig( 'bootstatus', undef, $config );
	$farm{ status }     = &getL4FarmStatus( $farm{ name } );
	$farm{ logs }       = &_getL4ParseFarmConfig( 'logs', undef, $config );
	$farm{ servers }    = &_getL4FarmParseServers( $config );

	# replace port * for all the range
	if ( $farm{ vport } eq '*' )
	{
		$farm{ vport } = '0:65535';
	}

	if ( $farm{ lbalg } =~ /weight|prio/ )
	{
		&getL4BackendsWeightProbability( \%farm );
	}

	return \%farm;    # return a hash reference
}

=begin nd
Function: doL4FarmProbability

	Create in the passed hash a new key called "prob". In this key is saved total weight of all backends

Parameters:
	farm - farm hash ref. It is a hash with all information about the farm

Returns:
	none - .

=cut

sub doL4FarmProbability
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $farm = shift;    # input: farm reference

	$$farm{ prob } = 0;

	foreach my $server_ref ( @{ $$farm{ servers } } )
	{
		if ( $$server_ref{ status } eq 'up' )
		{
			$$farm{ prob } += $$server_ref{ weight };
		}
	}
}

=begin nd
Function: refreshL4FarmRules

	Refresh all iptables rule for a l4 farm

Parameters:
	farm - Farm hash ref. It is a hash with all information about the farm

Returns:
	Integer - Error code: 0 on success or -1 on failure

FIXME:
	Send signal to l4sd to reload configuration

=cut

sub refreshL4FarmRules    # AlgorithmRules
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $farm = shift;     # input: reference to farm structure

	require Zevenet::Lock;
	require Zevenet::Netfilter;

	my @rules;
	my $return_code = 0;

	# refresh backends probability values
	&getL4BackendsWeightProbability( $farm );

	## lock iptables use ##
	my $iptlock = &getGlobalConfiguration( 'iptlock' );
	my $ipt_lockfile = &openlock( $iptlock, 'r' );

	# get new rules
	foreach my $server ( @{ $$farm{ servers } } )
	{
		my $rule;
		my $rule_num;

		# refresh marks
		my $rule_ref = &genIptMark( $farm, $server );
		foreach my $rule ( @{ $rule_ref } )
		{
			$rule = &getIptRuleReplace( $farm, $server, $rule );
			$return_code |= &applyIptRules( $rule );
		}

		if ( $$farm{ persist } ne 'none' )    # persistence
		{
			my $prule_ref = &genIptMarkPersist( $farm, $server );
			foreach my $rule ( @{ $prule_ref } )
			{
				$rule = &getIptRuleReplace( $farm, $server, $rule );
				$return_code |= &applyIptRules( $rule );
			}
		}

		# redirect
		my $rule_ref = &genIptRedirect( $farm, $server );
		foreach my $rule ( @{ $rule_ref } )
		{
			$rule = &getIptRuleReplace( $farm, $server, $rule );
			$return_code |= &applyIptRules( $rule );
		}

		if ( $$farm{ nattype } eq 'nat' )    # nat type = nat
		{
			my $rule_ref = &genIptMasquerade( $farm, $server );
			foreach my $rule ( @{ $rule_ref } )
			{
				$rule =
				  ( &getIptRuleNumber( $rule, $farm->{ name }, $server->{ id } ) == -1 )
				  ? &getIptRuleAppend( $rule )
				  : &getIptRuleReplace( $farm, $server, $rule );
				$return_code |= &applyIptRules( $rule );
			}
		}
		else
		{
			&deleteIptRules( $farm->{ name },
							 "farm", ".*", "nat", "POSTROUTING",
							 &getIptList( $farm->{ name }, "nat", "POSTROUTING" ) );
		}

		# reset connection mark on udp
		if ( $$farm{ proto } eq 'udp' )
		{
			foreach my $be ( @{ $$farm{ servers } } )
			{
				&resetL4FarmBackendConntrackMark( $be );
			}
		}
	}

	## unlock iptables use ##
	close $ipt_lockfile;

	&reloadL4FarmLogsRule( $$farm{ name } );

	# apply new rules
	return $return_code;
}

=begin nd
Function: reloadL4FarmsSNAT

	Reload iptables rules of all SNAT L4 farms

Parameters:
	farm - Farm hash ref. It is a hash with all information about the farm

Returns:
	none - .

FIXME:
	Send signal to l4sd to reload configuration

=cut

sub reloadL4FarmsSNAT
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	require Zevenet::Farm::Core;
	require Zevenet::Farm::Base;
	require Zevenet::Netfilter;

	for my $farm_name ( &getFarmsByType( 'l4xnat' ) )
	{
		next if &getL4FarmParam( 'status', $farm_name ) ne 'up';

		my $l4f_conf = &getL4FarmStruct( $farm_name );

		next if $$l4f_conf{ nattype } ne 'nat';

		foreach my $server ( @{ $$l4f_conf{ servers } } )
		{
			my $rule_ref = &genIptMasquerade( $l4f_conf, $server );
			foreach my $rule ( @{ $rule_ref } )
			{
				$rule = &getIptRuleReplace( $l4f_conf, $server, $rule );
				&applyIptRules( $rule );
			}
		}
	}
}

sub setL4FarmLogs
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $farmname = shift;
	my $action   = shift;    # true or false
	my $out;

	# execute action
	&reloadL4FarmLogsRule( $farmname, $action );

	# write configuration
	require Tie::File;
	my $farm_filename = &getFarmFile( $farmname );
	tie my @configfile, 'Tie::File', "$configdir\/$farm_filename";

	my $i = 0;
	for my $line ( @configfile )
	{
		if ( $line =~ /^$farmname\;/ )
		{
			my @args = split ( "\;", $line );
			$line =
			  "$args[0]\;$args[1]\;$args[2]\;$args[3]\;$args[4]\;$args[5]\;$args[6]\;$args[7]\;$args[8]\;$action";
			splice @configfile, $i, $line;
		}
		$i++;
	}
	untie @configfile;

	return $out;
}

# if action is false, the rule won't be started
# if farm is in down status, the farm won't be started

sub reloadL4FarmLogsRule
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my ( $farmname, $action ) = @_;

	require Zevenet::Netfilter;

	my $error;
	my $table     = "mangle";
	my $ipt_hook  = "FORWARD";
	my $log_chain = "LOG_CONNS";
	my $bin       = &getBinVersion( $farmname );
	my $farm      = &getL4FarmStruct( $farmname );

	my $comment = "conns,$farmname";

	# delete current rules
	&runIptDeleteByComment( $comment, $log_chain, $table );

	# delete chain if it was the last rule
	my @ipt_list = `$bin -S $log_chain -t $table 2>/dev/null`;
	my $err      = $?;

	# If the CHAIN is created, has a rule: -N LOG_CONNS
	if ( scalar @ipt_list <= 1 and !$err )
	{
		&iptSystem( "$bin -D $ipt_hook -t $table -j $log_chain" );
		&iptSystem( "$bin -X $log_chain -t $table" );
	}

	# not to apply rules if:
	return if ( $action eq 'false' );
	return
	  if ( &getL4FarmParam( 'logs', $farmname ) ne "true" and $action ne "true" );
	return if ( &getL4FarmParam( 'status', $farmname ) ne 'up' );

	my $comment_tag = "-m comment --comment \"$comment\"";
	my $log_tag     = "-j LOG --log-prefix \"l4: $farmname \" --log-level 4";

	# create chain if it does not exist
	if ( &iptSystem( "$bin -S $log_chain -t $table" ) )
	{
		$error = &iptSystem( "$bin -N $log_chain -t $table" );
		$error = &iptSystem( "$bin -A $ipt_hook -t $table -j $log_chain" );
	}

	my %farm_st = %{ &getL4FarmStruct( $farmname ) };
	foreach my $bk ( @{ $farm_st{ servers } } )
	{
		my $mark = "-m mark --mark $bk->{tag}";

		# log only the new connections
		if ( &getGlobalConfiguration( 'full_farm_logs' ) ne 'true' )
		{
			$error |= &iptSystem(
				 "$bin -A $log_chain -t $table -m state --state NEW $mark $log_tag $comment_tag"
			);
		}

		# log all trace
		else
		{
			$error |=
			  &iptSystem( "$bin -A $log_chain -t $table $mark $log_tag $comment_tag" );
		}
	}

}

=begin nd
Function: getL4FarmPlainInfo

	Return the L4 farm text configuration

Parameters:
	farm_name - farm name to get the status

Returns:
	Scalar - Reference of the file content in plain text

=cut

sub getL4FarmPlainInfo    # ($farm_name)
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my ( $farm_name ) = @_;

	my $farm_filename = &getFarmFile( $farm_name );

	open my $fd, '<', "$configdir/$farm_filename";
	chomp ( my @content = <$fd> );
	close $fd;

	return \@content;
}

1;
