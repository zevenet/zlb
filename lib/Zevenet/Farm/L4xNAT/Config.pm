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
Function: getL4FarmsPorts

	Get all port used of L4xNAT farms in up status and using a protocol
	
Parameters:
	protocol - protocol used by l4xnat farm

Returns:
	String - return a list with the used ports by all L4xNAT farms. Format: "portList1,portList2,..."
	
=cut

sub getL4FarmsPorts    # ($protocol)
{
	my $protocol = shift;

	my $port_list       = "";
	my @farms_filenames = &getFarmList();

	unless ( $#farms_filenames > -1 )
	{
		return $port_list;
	}

	foreach my $farm_filename ( @farms_filenames )
	{
		my $farm_name     = &getFarmName( $farm_filename );
		my $farm_type     = &getFarmType( $farm_name );
		my $farm_protocol = &getFarmProto( $farm_name );

		next if not ( $farm_type eq "l4xnat" && $protocol eq $farm_protocol );
		next if ( &getFarmBootStatus( $farm_name ) ne "up" );

		my $farm_port = &getFarmVip( "vipp", $farm_name );
		$farm_port = join ( ',', &getFarmPortList( $farm_port ) );
		next if not &validL4ExtPort( $farm_protocol, $farm_port );

		$port_list .= "$farm_port,";
	}

	# remove the las comma
	chop ( $port_list );

	return $port_list;
}

=begin nd
Function: loadL4Modules

	Load sip, ftp or tftp conntrack module for l4 farms
	
Parameters:
	protocol - protocol module to load

Returns:
	Integer - Always return 0

FIXME:
	1. The maximum number of ports, when the module is loaded, is 8
	2. Always return 0
	
=cut

sub loadL4Modules    # ($protocol)
{
	my $protocol = shift;

	require Zevenet::Netfilter;

	my $status    = 0;
	my $port_list = &getL4FarmsPorts( $protocol );

	if ( $protocol eq "sip" )
	{
		&removeNfModule( "nf_nat_sip" );
		&removeNfModule( "nf_conntrack_sip" );
		if ( $port_list )
		{
			&loadNfModule( "nf_conntrack_sip", "ports=\"$port_list\"" );
			&loadNfModule( "nf_nat_sip",       "" );
		}
	}
	elsif ( $protocol eq "ftp" )
	{
		&removeNfModule( "nf_nat_ftp" );
		&removeNfModule( "nf_conntrack_ftp" );
		if ( $port_list )
		{
			&loadNfModule( "nf_conntrack_ftp", "ports=\"$port_list\"" );
			&loadNfModule( "nf_nat_ftp",       "" );
		}
	}
	elsif ( $protocol eq "tftp" )
	{
		&removeNfModule( "nf_nat_tftp" );
		&removeNfModule( "nf_conntrack_tftp" );
		if ( $port_list )
		{
			&loadNfModule( "nf_conntrack_tftp", "ports=\"$port_list\"" );
			&loadNfModule( "nf_nat_tftp",       "" );
		}
	}

	return $status;
}

=begin nd
Function: validL4ExtPort

	check if the port is valid for a sip, ftp or tftp farm
	
Parameters:
	protocol - protocol module to load
	ports - port string

Returns:
	Integer - 1 is valid or 0 is not valid

=cut

sub validL4ExtPort    # ($farm_protocol,$ports)
{
	my ( $farm_protocol, $ports ) = @_;

	my $status = 0;

	if (    $farm_protocol eq "sip"
		 || $farm_protocol eq "ftp"
		 || $farm_protocol eq "tftp" )
	{
		if ( $ports =~ /^\d+$/ || $ports =~ /^((\d+),(\d+))+$/ )
		{
			$status = 1;
		}
	}
	return $status;
}

=begin nd
Function: sendL4ConfChange

	Run a l4xnat farm
	
Parameters:
	farmname - Farm name

Returns:
	Integer - Error code: 0 on success or other value on failure

FIXME:
	only used in zapi v2. Obsolet

BUG:
	same functionlity than _runL4FarmRestart and runL4FarmRestart

=cut

sub sendL4ConfChange    # ($farm_name)
{
	my $farm_name = shift;

	my $algorithm   = &getFarmAlgorithm( $farm_name );
	my $fbootstatus = &getFarmBootStatus( $farm_name );
	my $output      = 0;
	my $pidfile     = "/var/run/l4sd.pid";

	if ( $algorithm eq "leastconn" && -e "$pidfile" )
	{
		# read pid number
		open my $file, "<", "$pidfile";
		my $pid = <$file>;
		close $file;

		kill USR1 => $pid;
		$output = $?;    # FIXME
	}
	else
	{
		&zenlog( "Running L4 restart for $farm_name" );
		&_runL4FarmRestart( $farm_name, "false", "" );
	}

	return $output;      # FIXME
}

=begin nd
Function: setL4FarmSessionType

	Configure type of persistence session
	
Parameters:
	session - Session type. The options are: "none" not use persistence or "ip" for ip persistencia
	farmname - Farm name

Returns:
	Integer - Error code: 0 on success or other value on failure

FIXME:
	only used in zapi v2. Obsolet

BUG:
	same functionlity than _runL4FarmRestart and runL4FarmRestart

=cut

sub setL4FarmSessionType    # ($session,$farm_name)
{
	my ( $session, $farm_name ) = @_;

	my $farm_filename = &getFarmFile( $farm_name );
	my $output        = 0;
	my $i             = 0;

	require Zevenet::FarmGuardian;
	require Tie::File;

	my $farm       = &getL4FarmStruct( $farm_name );
	my $fg_enabled = ( &getFarmGuardianConf( $$farm{ name } ) )[3];
	my $fg_pid     = &getFarmGuardianPid( $farm_name );

	if ( $$farm{ status } eq 'up' )
	{
		if ( $fg_enabled eq 'true' )
		{
			kill 'STOP' => $fg_pid;
		}
	}

	&zlog( "setL4FarmSessionType: SessionType" ) if &debug;

	tie my @configfile, 'Tie::File', "$configdir\/$farm_filename";

	for my $line ( @configfile )
	{
		if ( $line =~ /^$farm_name\;/ )
		{
			my @args = split ( "\;", $line );
			$line =
			  "$args[0]\;$args[1]\;$args[2]\;$args[3]\;$args[4]\;$args[5]\;$session\;$args[7]\;$args[8]";
			splice @configfile, $i, $line;
			$output = $?;    # FIXME
		}
		$i++;
	}
	untie @configfile;

	$farm = &getL4FarmStruct( $farm_name );

	if ( $$farm{ status } eq 'up' )
	{
		require Zevenet::Netfilter;

		my @rules;
		my $prio_server = &getL4ServerWithLowestPriority( $farm );

		foreach my $server ( @{ $$farm{ servers } } )
		{
			#~ next if $$server{ status } !~ /up|maintenance/;    # status eq fgDOWN
			next if $$farm{ lbalg } eq 'prio' && $$prio_server{ id } != $$server{ id };

			my $rule = &genIptMarkPersist( $farm, $server );

			$rule =
			  ( $$farm{ persist } eq 'none' )
			  ? &getIptRuleDelete( $rule )
			  : &getIptRuleInsert( $farm, $server, $rule );
			&applyIptRules( $rule );

			$rule = &genIptRedirect( $farm, $server );
			$rule = &getIptRuleReplace( $farm, $server, $rule );

			$output = &applyIptRules( $rule );
		}

		if ( $fg_enabled eq 'true' )
		{
			kill 'CONT' => $fg_pid;
		}
	}

	return $output;
}

=begin nd
Function: getL4FarmSessionType

	Get type of persistence session
	
Parameters:
	farmname - Farm name

Returns:
	Scalar - "none" not use persistence, "ip" for ip persistencia or -1 on failure
	
BUG:
	DUPLICATE with getL4FarmPersistence
	Not used 
	Use get and set with same name

=cut

sub getL4FarmSessionType    # ($farm_name)
{
	my $farm_name = shift;

	my $farm_filename = &getFarmFile( $farm_name );
	my $output        = -1;
	my $first         = "true";

	open FI, "<$configdir/$farm_filename";

	while ( my $line = <FI> )
	{
		if ( $line ne "" && $first eq "true" )
		{
			$first = "false";
			my @line = split ( "\;", $line );
			$output = $line[6];
		}
	}
	close FI;

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
	my ( $algorithm, $farm_name ) = @_;

	require Zevenet::FarmGuardian;
	require Tie::File;

	my $farm_filename = &getFarmFile( $farm_name );
	my $output        = -1;
	my $i             = 0;
	my $prev_alg      = getL4FarmAlgorithm( $farm_name );    # previous algorithm

	my $farm       = &getL4FarmStruct( $farm_name );
	my $fg_enabled = ( &getFarmGuardianConf( $$farm{ name } ) )[3];
	my $fg_pid     = &getFarmGuardianPid( $farm_name );

	if ( $$farm{ status } eq 'up' )
	{
		if ( $fg_enabled eq 'true' )
		{
			kill 'STOP' => $fg_pid;
		}
	}

	tie my @configfile, 'Tie::File', "$configdir\/$farm_filename";

	for my $line ( @configfile )
	{
		if ( $line =~ /^$farm_name\;/ )
		{
			my @args = split ( "\;", $line );
			$line =
			  "$args[0]\;$args[1]\;$args[2]\;$args[3]\;$args[4]\;$algorithm\;$args[6]\;$args[7]\;$args[8]";
			splice @configfile, $i, $line;
			$output = $?;    # FIXME
		}
		$i++;
	}
	untie @configfile;
	$output = $?;            # FIXME

	$farm = &getL4FarmStruct( $farm_name );

	if ( $$farm{ status } eq 'up' )
	{
		require Zevenet::Netfilter;
		my @rules;

		my $prio_server = &getL4ServerWithLowestPriority( $farm );

		foreach my $server ( @{ $$farm{ servers } } )
		{
			my $rule;

			# weight    => leastconn or (many to many)
			# leastconn => weight
			if (    ( $prev_alg eq 'weight' && $$farm{ lbalg } eq 'leastconn' )
				 || ( $prev_alg eq 'leastconn' && $$farm{ lbalg } eq 'weight' ) )
			{
				# replace packet marking rules
				# every thing else stays the same way
				$rule = &genIptMark( $farm, $server );
				my $rule_num = &getIptRuleNumber( $rule, $$farm{ name }, $$server{ id } );
				$rule = &applyIptRuleAction( $rule, 'replace', $rule_num );

				&applyIptRules( $rule );

				if ( $$farm{ persist } ne 'none' )    # persistence
				{
					$rule = &genIptMarkPersist( $farm, $server );
					$rule_num = &getIptRuleNumber( $rule, $$farm{ name }, $$server{ id } );
					$rule = &applyIptRuleAction( $rule, 'replace', $rule_num );
					&applyIptRules( $rule );
				}
			}

			# prio => weight or (one to many)
			# prio => leastconn
			elsif ( ( $$farm{ lbalg } eq 'weight' || $$farm{ lbalg } eq 'leastconn' )
					&& $prev_alg eq 'prio' )
			{
				$rule = &genIptMark( $farm, $server );
				my $rule_num = &getIptRuleNumber( $rule, $$farm{ name }, $$server{ id } );

				# start not started servers
				if ( $rule_num == -1 )    # no rule was found
				{
					&_runL4ServerStart( $$farm{ name }, $$server{ id } );
					$rule = undef;        # changes are already done
				}

				# refresh already started server
				else
				{
					&_runL4ServerStop( $$farm{ name }, $$server{ id } );
					&_runL4ServerStart( $$farm{ name }, $$server{ id } );
					$rule = undef;        # changes are already done
				}
				&applyIptRules( $rule ) if defined ( $rule );
			}

			# weight    => prio or (many to one)
			# leastconn => prio
			elsif ( ( $prev_alg eq 'weight' || $prev_alg eq 'leastconn' )
					&& $$farm{ lbalg } eq 'prio' )
			{
				if ( $server == $prio_server )    # no rule was found
				{
					$rule = &genIptMark( $farm, $server );
					my $rule_num = &getIptRuleNumber( $rule, $$farm{ name }, $$server{ id } );
					$rule = &applyIptRuleAction( $rule, 'replace', $rule_num );

					&applyIptRules( $rule ) if defined ( $rule );
				}
				else
				{
					&_runL4ServerStop( $$farm{ name }, $$server{ id } );
					$rule = undef;                # changes are already done
				}
			}
		}

		# manage l4sd
		my $l4sd_pidfile = '/var/run/l4sd.pid';
		my $l4sd         = &getGlobalConfiguration( 'l4sd' );

		if ( $$farm{ lbalg } eq 'leastconn' && -e "$l4sd" )
		{
			system ( "$l4sd >/dev/null &" );
		}
		elsif ( -e $l4sd_pidfile )
		{
			require Zevenet::Netfilter;
			## lock iptables use ##
			my $iptlock = &getGlobalConfiguration( 'iptlock' );
			open my $ipt_lockfile, '>', $iptlock;
			&setIptLock( $ipt_lockfile );

			# Get the binary of iptables (iptables or ip6tables)
			my $iptables_bin = &getBinVersion( $farm_name );

			my $num_lines = grep { /-m condition --condition/ }
			  `$iptables_bin --numeric --table mangle --list PREROUTING`;

			## unlock iptables use ##
			&setIptUnlock( $ipt_lockfile );
			close $ipt_lockfile;

			if ( $num_lines == 0 )
			{
				# stop l4sd
				if ( open my $pidfile, '<', $l4sd_pidfile )
				{
					my $pid = <$pidfile>;
					close $pidfile;

					# close normally
					kill 'TERM' => $pid;
					&zenlog( "l4sd ended" );
				}
				else
				{
					&zenlog( "Error opening file l4sd_pidfile: $!" ) if !defined $pidfile;
				}
			}
		}

		if ( $fg_enabled eq 'true' )
		{
			kill 'CONT' => $fg_pid;
		}
	}

	return;
}

=begin nd
Function: getL4FarmAlgorithm

	Get the load balancing algorithm for a farm
	
Parameters:
	farmname - Farm name

Returns:
	Scalar - "leastconn" , "weight", "prio" or -1 on failure
	
=cut

sub getL4FarmAlgorithm    # ($farm_name)
{
	my $farm_name = shift;

	my $farm_filename = &getFarmFile( $farm_name );
	my $output        = -1;
	my $first         = 'true';

	open FI, "<", "$configdir/$farm_filename";

	while ( my $line = <FI> )
	{
		if ( $line ne '' && $first eq 'true' )
		{
			$first = 'false';
			my @line = split ( "\;", $line );
			$output = $line[5];
		}
	}
	close FI;

	return $output;
}

=begin nd
Function: setFarmProto

	Set the protocol to a L4 farm
	
Parameters:
	protocol - which protocol the farm will use to work. The available options are: "all", "tcp", "udp", "sip", "ftp" and "tftp"
	farmname - Farm name

Returns:
	Integer - Error code: 0 on success or other value in failure
	
FIXME:
	It is necessary more error control

BUG:
	Before change to sip, ftp or tftp protocol, check if farm port is contability

=cut

sub setFarmProto    # ($proto,$farm_name)
{
	my ( $proto, $farm_name ) = @_;

	require Zevenet::FarmGuardian;
	my $farm_type     = &getFarmType( $farm_name );
	my $farm_filename = &getFarmFile( $farm_name );
	my $output        = 0;

	&zenlog( "setting 'Protocol $proto' for $farm_name farm $farm_type" );

	my $farm       = &getL4FarmStruct( $farm_name );
	my $old_proto  = $$farm{ vproto };
	my $fg_enabled = ( &getFarmGuardianConf( $$farm{ name } ) )[3];
	my $fg_pid     = &getFarmGuardianPid( $farm_name );

	if ( $$farm{ status } eq 'up' )
	{
		if ( $fg_enabled eq 'true' )
		{
			kill 'STOP' => $fg_pid;
		}
	}

	if ( $farm_type eq "l4xnat" )
	{
		require Tie::File;
		tie my @configfile, 'Tie::File', "$configdir\/$farm_filename" or return $output;
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
				if ( $proto eq "sip" )
				{
					#~ $args[4] = "nat";
				}
				$line =
				  "$args[0]\;$proto\;$args[2]\;$args[3]\;$args[4]\;$args[5]\;$args[6]\;$args[7]\;$args[8]";
				splice @configfile, $i, $line;
			}
			$i++;
		}
		untie @configfile;
	}

	$farm = &getL4FarmStruct( $farm_name );

	if ( $$farm{ status } eq 'up' )
	{
		# Remove required modules
		if ( $old_proto =~ /sip|ftp/ )
		{
			my $status = &loadL4Modules( $old_proto );
		}

		# Load required modules
		if ( $$farm{ vproto } =~ /sip|ftp/ )
		{
			my $status = &loadL4Modules( $$farm{ vproto } );
		}

		$output = &refreshL4FarmRules( $farm );

		if ( $fg_enabled eq 'true' )
		{
			kill 'CONT' => $fg_pid;
		}
	}

	return $output;
}

=begin nd
Function: getFarmNatType

	Get the NAT type for a L4 farm
	
Parameters:
	farmname - Farm name

Returns:
	Scalar - "nat", "dnat" or -1 on failure
	
=cut

sub getFarmNatType    # ($farm_name)
{
	my $farm_name = shift;

	my $farm_type     = &getFarmType( $farm_name );
	my $farm_filename = &getFarmFile( $farm_name );
	my $output        = -1;

	if ( $farm_type eq "l4xnat" )
	{
		open FI, "<", "$configdir/$farm_filename";
		my $first = "true";
		while ( my $line = <FI> )
		{
			if ( $line ne "" && $first eq "true" )
			{
				$first = "false";
				my @line = split ( "\;", $line );
				$output = $line[4];
			}
		}
		close FI;
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
	my ( $nat, $farm_name ) = @_;

	my $farm_type     = &getFarmType( $farm_name );
	my $farm_filename = &getFarmFile( $farm_name );
	my $output        = 0;

	require Zevenet::FarmGuardian;

	&zenlog( "setting 'NAT type $nat' for $farm_name farm $farm_type" );

	my $farm       = &getL4FarmStruct( $farm_name );
	my $fg_enabled = ( &getFarmGuardianConf( $$farm{ name } ) )[3];
	my $fg_pid     = &getFarmGuardianPid( $farm_name );

	if ( $$farm{ status } eq 'up' )
	{
		if ( $fg_enabled eq 'true' )
		{
			if ( $0 !~ /farmguardian/ )
			{
				kill 'STOP' => $fg_pid;
			}
		}
	}

	if ( $farm_type eq "l4xnat" )
	{
		require Tie::File;
		tie my @configfile, 'Tie::File', "$configdir\/$farm_filename";
		my $i = 0;
		for my $line ( @configfile )
		{
			if ( $line =~ /^$farm_name\;/ )
			{
				my @args = split ( "\;", $line );
				$line =
				  "$args[0]\;$args[1]\;$args[2]\;$args[3]\;$nat\;$args[5]\;$args[6]\;$args[7]\;$args[8]";
				splice @configfile, $i, $line;
			}
			$i++;
		}
		untie @configfile;
	}

	$farm = &getL4FarmStruct( $farm_name );

	if ( $$farm{ status } eq 'up' )
	{
		require Zevenet::Netfilter;

		my @rules;
		my $prio_server = &getL4ServerWithLowestPriority( $farm );

		foreach my $server ( @{ $$farm{ servers } } )
		{
			&zlog( "server:$$server{id}" ) if &debug == 2;

			#~ next if $$server{ status } !~ /up|maintenance/;
			next if $$farm{ lbalg } eq 'prio' && $$prio_server{ id } != $$server{ id };

			my $rule;

			# get the rule 'template'
			$rule = ( $$farm{ vproto } eq 'sip' )
			  ? &genIptSourceNat( $farm, $server )    # SIP protocol
			  : &genIptMasquerade( $farm, $server );  # Masq otherwise

			# apply the desired action to the rule template
			$rule = ( $$farm{ nattype } eq 'nat' )
			  ? &getIptRuleAppend( $rule )            # append for SNAT aka NAT
			  : &getIptRuleDelete( $rule );           # delete for DNAT

			# apply rules as they are generated, so rule numbers are right
			$output = &applyIptRules( $rule );
		}

		if ( $fg_enabled eq 'true' )
		{
			if ( $0 !~ /farmguardian/ )
			{
				kill 'CONT' => $fg_pid;
			}
		}
	}

	return $output;
}

=begin nd
Function: getL4FarmPersistence

	Get type of persistence session for a l4 farm
	
Parameters:
	farmname - Farm name

Returns:
	Scalar - "none" not use persistence, "ip" for ip persistencia or -1 on failure
	
=cut

sub getL4FarmPersistence    # ($farm_name)
{
	my $farm_name = shift;

	my $farm_filename = &getFarmFile( $farm_name );
	my $persistence   = -1;
	my $first         = "true";

	open FI, "<", "$configdir/$farm_filename";

	while ( my $line = <FI> )
	{
		if ( $line ne "" && $first eq "true" )
		{
			$first = "false";
			my @line = split ( "\;", $line );
			$persistence = $line[6];
		}
	}
	close FI;

	return $persistence;
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
	my ( $track, $farm_name ) = @_;

	my $farm_filename = &getFarmFile( $farm_name );
	my $output        = -1;
	my $i             = 0;

	require Zevenet::FarmGuardian;
	require Tie::File;

	my $farm       = &getL4FarmStruct( $farm_name );
	my $fg_enabled = ( &getFarmGuardianConf( $$farm{ name } ) )[3];
	my $fg_pid     = &getFarmGuardianPid( $farm_name );

	if ( $$farm{ status } eq 'up' )
	{
		if ( $fg_enabled eq 'true' )
		{
			kill 'STOP' => $fg_pid;
		}
	}

	tie my @configfile, 'Tie::File', "$configdir\/$farm_filename";

	for my $line ( @configfile )
	{
		if ( $line =~ /^$farm_name\;/ )
		{
			my @args = split ( "\;", $line );
			$line =
			  "$args[0]\;$args[1]\;$args[2]\;$args[3]\;$args[4]\;$args[5]\;$args[6]\;$track\;$args[8]";
			splice @configfile, $i, $line;
			$output = $?;    # FIXME
		}
		$i++;
	}
	untie @configfile;
	$output = $?;            # FIXME

	$farm = &getL4FarmStruct( $farm_name );

	if ( $$farm{ status } eq 'up' && $$farm{ persist } ne 'none' )
	{
		require Zevenet::Netfilter;

		my @rules;
		my $prio_server = &getL4ServerWithLowestPriority( $farm );

		foreach my $server ( @{ $$farm{ servers } } )
		{
			next if $$server{ status } != /up|maintenance/;
			next if $$farm{ lbalg } eq 'prio' && $$prio_server{ id } != $$server{ id };

			my $rule = &genIptMarkPersist( $farm, $server );
			my $rule_num = &getIptRuleNumber( $rule, $$farm{ name }, $$server{ id } );

			$rule = &applyIptRuleAction( $rule, 'replace', $rule_num );

			push ( @rules, $rule );    # collect rule
		}

		require Zevenet::Netfilter;
		$output = &applyIptRules( @rules );

		if ( $fg_enabled eq 'true' )
		{
			kill 'CONT' => $fg_pid;
		}
	}

	return $output;
}

=begin nd
Function: getL4FarmMaxClientTime

	 Get the max client time of a farm
	
Parameters:
	farmname - Farm name

Returns:
	Integer - Time to Live (TTL) or -1 on failure
	
FIXME:
	The returned value must to be a integer. Fit output like in the description
	
=cut

sub getL4FarmMaxClientTime    # ($farm_name)
{
	my ( $farm_name ) = @_;

	my $farm_filename = &getFarmFile( $farm_name );
	my $first         = "true";
	my @max_client_time;

	open FI, "<", "$configdir/$farm_filename";

	while ( my $line = <FI> )
	{
		if ( $line ne "" && $first eq "true" )
		{
			$first = "false";
			my @line = split ( "\;", $line );
			@max_client_time = $line[7];
		}
	}
	close FI;

	return @max_client_time;
}

=begin nd
Function: getL4FarmBootStatus

	Return the farm status at boot zevenet
	 
Parameters:
	farmname - Farm name

Returns:
	scalar - return "down" if the farm not run at boot or "up" if the farm run at boot

=cut

sub getL4FarmBootStatus    # ($farm_name)
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
			$output = $line_a[8];
			chomp ( $output );
		}
	}
	close FI;

	$output = "down" if ( !$output );

	return $output;
}

=begin nd
Function: getL4FarmVip

	Returns farm vip or farm port
		
Parameters:
	tag - requested parameter. The options are "vip"for virtual ip or "vipp" for virtual port
	farmname - Farm name

Returns:
	Scalar - return vip, port of farm or -1 on failure
	
FIXME
	vipps parameter is only used in tcp farms. Soon this parameter will be obsolet
			
=cut

sub getL4FarmVip    # ($info,$farm_name)
{
	my ( $info, $farm_name ) = @_;

	my $farm_filename = &getFarmFile( $farm_name );
	my $first         = 'true';
	my $output        = -1;

	open FI, "<", "$configdir/$farm_filename";

	while ( my $line = <FI> )
	{
		if ( $line ne '' && $first eq 'true' )
		{
			$first = 'false';
			my @line_a = split ( "\;", $line );

			if ( $info eq 'vip' )   { $output = $line_a[2]; }
			if ( $info eq 'vipp' )  { $output = $line_a[3]; }
			if ( $info eq 'vipps' ) { $output = "$line_a[2]\:$line_a[3]"; }
		}
	}
	close FI;

	return $output;
}

=begin nd
Function: setL4FarmVirtualConf

	Set farm virtual IP and virtual PORT
		
Parameters:
	vip - Farm virtual IP
	port - Farm virtual port
	farmname - Farm name

Returns:
	Scalar - 0 on success or other value on failure
	
=cut

sub setL4FarmVirtualConf    # ($vip,$vip_port,$farm_name)
{
	my ( $vip, $vip_port, $farm_name ) = @_;

	require Tie::File;
	require Zevenet::FarmGuardian;

	my $farm_filename = &getFarmFile( $farm_name );
	my $i             = 0;

	my $farm       = &getL4FarmStruct( $farm_name );
	my $fg_enabled = ( &getFarmGuardianConf( $$farm{ name } ) )[3];
	my $fg_pid     = &getFarmGuardianPid( $farm_name );

	if ( $$farm{ status } eq 'up' )
	{
		if ( $fg_enabled eq 'true' )
		{
			kill 'STOP' => $fg_pid;
		}
	}

	tie my @configfile, 'Tie::File', "$configdir\/$farm_filename";

	for my $line ( @configfile )
	{
		if ( $line =~ /^$farm_name\;/ )
		{
			my @args = split ( "\;", $line );
			$line =
			  "$args[0]\;$args[1]\;$vip\;$vip_port\;$args[4]\;$args[5]\;$args[6]\;$args[7]\;$args[8]";
			splice @configfile, $i, $line;
		}
		$i++;
	}
	untie @configfile;

	$farm = &getL4FarmStruct( $farm_name );

	if ( $$farm{ status } eq 'up' )
	{
		require Zevenet::Netfilter;

		my @rules;

		foreach my $server ( @{ $$farm{ servers } } )
		{
			my $rule = &genIptMark( $farm, $server );
			my $rule_num = &getIptRuleNumber( $rule, $$farm{ name }, $$server{ id } );

			$rule = &applyIptRuleAction( $rule, 'replace', $rule_num );

			push ( @rules, $rule );    # collect rule

			if ( $$farm{ persist } eq 'ip' )
			{
				$rule = &genIptMarkPersist( $farm, $server );
				$rule_num = &getIptRuleNumber( $rule, $$farm{ name }, $$server{ id } );

				$rule = &applyIptRuleAction( $rule, 'replace', $rule_num );

				push ( @rules, $rule );    # collect rule
			}
		}

		&applyIptRules( @rules );

		if ( $fg_enabled eq 'true' )
		{
			kill 'CONT' => $fg_pid;
		}

		# Reload required modules
		if ( $$farm{ vproto } =~ /sip|ftp/ )
		{
			my $status = &loadL4Modules( $$farm{ vproto } );
		}
	}

	return 0;    # FIXME?
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
	my $vproto = shift;

	return
	    ( $vproto =~ /sip|tftp/ ) ? 'udp'
	  : ( $vproto eq 'ftp' )      ? 'tcp'
	  :                             $vproto;
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
	my %farm;    # declare output hash

	$farm{ name } = shift;    # input: farm name

	require Zevenet::Farm::Base;
	require Zevenet::Farm::L4xNAT::Backend;

	$farm{ filename } = &getFarmFile( $farm{ name } );
	$farm{ nattype }  = &getFarmNatType( $farm{ name } );
	$farm{ lbalg }    = &getL4FarmAlgorithm( $farm{ name } );
	$farm{ vip }      = &getL4FarmVip( 'vip', $farm{ name } );
	$farm{ vport }    = &getL4FarmVip( 'vipp', $farm{ name } );
	$farm{ vproto }   = &getFarmProto( $farm{ name } );
	$farm{ persist }  = &getL4FarmPersistence( $farm{ name } );
	$farm{ ttl }      = ( &getL4FarmMaxClientTime( $farm{ name } ) )[0];
	$farm{ proto }    = &getL4ProtocolTransportLayer( $farm{ vproto } );
	$farm{ status }   = &getFarmStatus( $farm{ name } );
	$farm{ servers }  = [];

	foreach my $server_line ( &getL4FarmServers( $farm{ name } ) )
	{
		push ( @{ $farm{ servers } }, &getL4ServerStruct( \%farm, $server_line ) );
	}

	# replace port * for all the range
	if ( $farm{ vport } eq '*' )
	{
		$farm{ vport } = '0:65535';
	}

	if ( $farm{ lbalg } eq 'weight' )
	{
		&getL4BackendsWeightProbability( \%farm );
	}

	return \%farm;    # return a hash reference
}

=begin nd
Function: getL4ServerStruct

	Return a hash with all data about a backend in a l4 farm
		
Parameters:
	farmname - Farm name
	backend - Backend id

Returns:
	hash ref - 
		\%backend = { $id, $vip, $vport, $tag, $weight, $priority, $status, $rip = $vip }
	
=cut

sub getL4ServerStruct
{
	my $farm        = shift;
	my $server_line = shift;    # input example: ;0;192.168.101.252;80;0x20a;1;1;up

	require Zevenet::Net::Validate;

	my @server_args = split ( "\;", $server_line );    # split server line
	chomp ( @server_args );

	# server args example: ( 0, 192.168.101.252, 80, 0x20a, 1, 1 ,up )
	my %server;                                        # output hash

	$server{ id }        = shift @server_args;         # input 0
	$server{ vip }       = shift @server_args;         # input 1
	$server{ vport }     = shift @server_args;         # input 2
	$server{ tag }       = shift @server_args;         # input 3
	$server{ weight }    = shift @server_args;         # input 4
	$server{ priority }  = shift @server_args;         # input 5
	$server{ status }    = shift @server_args;         # input 6
	$server{ max_conns } = shift @server_args // 0;    # input 7
	$server{ rip }       = $server{ vip };

	if ( $server{ vport } ne '' && $$farm{ proto } ne 'all' )
	{
		if ( &ipversion( $server{ rip } ) == 4 )
		{
			$server{ rip } = "$server{vip}\:$server{vport}";
		}
		elsif ( &ipversion( $server{ rip } ) == 6 )
		{
			$server{ rip } = "[$server{vip}]\:$server{vport}";
		}
	}

	return \%server;    # return reference
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
	my $farm = shift;    # input: farm reference

	$$farm{ prob } = 0;

	foreach my $server_ref ( @{ $$farm{ servers } } )
	{
		if ( $$server_ref{ status } eq 'up' )
		{
			$$farm{ prob } += $$server_ref{ weight };
		}
	}

  #~ &zenlog( "doL4FarmProbability($$farm{ name }) => prob:$$farm{ prob }" ); ######
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
	my $farm = shift;     # input: reference to farm structure

	require Zevenet::Netfilter;

	my $prio_server;
	my @rules;
	my $return_code = 0;

	$prio_server = &getL4ServerWithLowestPriority( $farm );

	# refresh backends probability values
	&getL4BackendsWeightProbability( $farm ) if ( $$farm{ lbalg } eq 'weight' );

	## lock iptables use ##
	my $iptlock = &getGlobalConfiguration( 'iptlock' );
	open ( my $ipt_lockfile, '>', $iptlock );

	unless ( $ipt_lockfile )
	{
		&zenlog( "Could not open $iptlock: $!" );
		return 1;
	}

	# get new rules
	foreach my $server ( @{ $$farm{ servers } } )
	{
		# skip cycle for servers not running
		next if ( $$farm{ lbalg } eq 'prio' && $$server{ id } != $$prio_server{ id } );

		my $rule;
		my $rule_num;

		# refresh marks
		$rule = &genIptMark( $farm, $server );

		$rule =
		  ( $$farm{ lbalg } eq 'prio' )
		  ? &getIptRuleReplace( $farm, undef,   $rule )
		  : &getIptRuleReplace( $farm, $server, $rule );

		$return_code |= &applyIptRules( $rule );

		if ( $$farm{ persist } ne 'none' )    # persistence
		{
			$rule = &genIptMarkPersist( $farm, $server );

			$rule =
			  ( $$farm{ lbalg } eq 'prio' )
			  ? &getIptRuleReplace( $farm, undef,   $rule )
			  : &getIptRuleReplace( $farm, $server, $rule );

			$return_code |= &applyIptRules( $rule );
		}

		# redirect
		$rule = &genIptRedirect( $farm, $server );

		$rule =
		  ( $$farm{ lbalg } eq 'prio' )
		  ? &getIptRuleReplace( $farm, undef,   $rule )
		  : &getIptRuleReplace( $farm, $server, $rule );

		$return_code |= &applyIptRules( $rule );

		if ( $$farm{ nattype } eq 'nat' )    # nat type = nat
		{
			if ( $$farm{ vproto } eq 'sip' )
			{
				$rule = &genIptSourceNat( $farm, $server );
			}
			else
			{
				$rule = &genIptMasquerade( $farm, $server );
			}

			$rule =
			  ( $$farm{ lbalg } eq 'prio' )
			  ? &getIptRuleReplace( $farm, undef,   $rule )
			  : &getIptRuleReplace( $farm, $server, $rule );

			$return_code |= &applyIptRules( $rule );
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
	&setIptUnlock( $ipt_lockfile );
	close $ipt_lockfile;

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
	require Zevenet::Farm::Core;
	require Zevenet::Farm::Base;
	require Zevenet::Netfilter;

	for my $farm_name ( &getFarmNameList() )
	{
		my $farm_type = &getFarmType( $farm_name );

		next if $farm_type ne 'l4xnat';
		next if &getFarmStatus( $farm_name ) ne 'up';

		my $l4f_conf = &getL4FarmStruct( $farm_name );

		next if $$l4f_conf{ nattype } ne 'nat';

		foreach my $server ( @{ $$l4f_conf{ servers } } )
		{
			my $rule;

			if ( $$l4f_conf{ vproto } eq 'sip' )
			{
				$rule = &genIptSourceNat( $l4f_conf, $server );
			}
			else
			{
				$rule = &genIptMasquerade( $l4f_conf, $server );
			}

			$rule = &getIptRuleReplace( $l4f_conf, $server, $rule );

			#~ push ( @{ $$rules{ t_snat } }, $rule );
			&applyIptRules( $rule );
		}
	}
}

1;
