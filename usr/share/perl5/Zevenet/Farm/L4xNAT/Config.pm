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
use warnings;

my $configdir = &getGlobalConfiguration( 'configdir' );

use Zevenet::Nft;

my $eload;
if ( eval { require Zevenet::ELoad; } )
{
	$eload = 1;
}

=begin nd
Function: getL4FarmParam

	Returns farm parameter

Parameters:
	param - requested parameter. The options are:
		"vip": get the virtual IP
		"vipp": get the virtual port
		"bootstatus": get boot status
		"status": get the current status
		"mode": get the topology (or nat type)
		"alg": get the algorithm
		"proto": get the protocol
		"persist": get persistence
		"persisttm": get client persistence timeout
		"limitrst": limit RST request per second
		"limitrstbrst": limit RST request per second burst
		"limitsec": connection limit per second
		"limitsecbrst": Connection limit per second burst
		"limitconns": total connections limit per source IP
		"bogustcpflags": check bogus TCP flags
		"nfqueue": queue to verdict the packets
		"sourceaddr": get the source address
	farmname - Farm name

Returns:
	Scalar - return the parameter as a string or -1 on failure

=cut

sub getL4FarmParam
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my ( $param, $farm_name ) = @_;

	require Zevenet::Farm::Core;

	my $farm_filename = &getFarmFile( $farm_name );
	my $output        = -1;

	if ( $param eq "status" )
	{
		return &getL4FarmStatus( $farm_name );
	}

	if ( $param eq "alg" )
	{
		require Zevenet::Farm::L4xNAT::L4sd;
		my $l4sched = &getL4sdType( $farm_name );
		return $l4sched if ( $l4sched ne "" );
	}

	open my $fd, '<', "$configdir/$farm_filename";
	chomp ( my @content = <$fd> );
	close $fd;

	$output = &_getL4ParseFarmConfig( $param, undef, \@content );

	return $output;
}

=begin nd
Function: setL4FarmParam

	Writes a farm parameter

Parameters:
	param - requested parameter. The options are:
		"name": new farm name
		"family": write ipv4 or ipv6
		"vip": write the virtual IP
		"vipp": write the virtual port
		"status" or "bootstatus" : write the status and boot status
		"mode": write the topology (or nat type)
		"alg": write the algorithm
		"proto": write the protocol
		"persist": write persistence
		"persisttm": write client persistence timeout
		"limitrst": limit RST request per second
		"limitrstbrst": limit RST request per second burst
		"limitsec": connection limit per second
		"limitsecbrst": Connection limit per second burst
		"limitconns": total connections limit per source IP
		"bogustcpflags": check bogus TCP flags
		"nfqueue": queue to verdict the packets
		"policy": policy list to be applied
		"sourceaddr": set the source address
	value - the new value of the given parameter of a certain farm
	farmname - Farm name

Returns:
	Scalar - return the parameter as a string or -1 on failure

=cut

sub setL4FarmParam
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my ( $param, $value, $farm_name ) = @_;

	require Zevenet::Farm::Core;

	my $farm_filename = &getFarmFile( $farm_name );
	my $output        = -1;
	my $srvparam      = "";
	my $addition      = "";
	my $prev_config   = "";
	my $farm_req      = $farm_name;
	my $parameters    = "";

	if ( $param eq "name" )
	{
		$farm_filename = "${value}_l4xnat.cfg";
		$farm_req      = $value;
		$parameters    = qq(, "newname" : "$value" );
	}
	elsif ( $param eq "family" )
	{
		$parameters = qq(, "family" : "$value" );
	}
	elsif ( $param eq "mode" )
	{
		$value = "snat"     if ( $value eq "nat" );
		$value = "stlsdnat" if ( $value eq "stateless_dnat" );
		$parameters = qq(, "mode" : "$value" );

		# deactivate leastconn and persistence for ingress modes
		if ( $value eq "dsr" || $value eq "stateless_dnat" )
		{
			require Zevenet::Farm::L4xNAT::L4sd;
			&setL4sdType( $farm_name, "none" );
			&setL4FarmParam( 'persist', "", $farm_name );

			if ( $eload )
			{
				# unassign DoS & RBL
				&eload(
						module => 'Zevenet::IPDS::Base',
						func   => 'runIPDSStopByFarm',
						args   => [$farm_name, "dos"],
				);
				&eload(
						module => 'Zevenet::IPDS::Base',
						func   => 'runIPDSStopByFarm',
						args   => [$farm_name, "rbl"],
				);
			}
		}

		# take care of floating interfaces without masquerading
		if ( $value eq "snat" && $eload )
		{
			my $farm_ref = &getL4FarmStruct( $farm_name );
			&eload(
					module => 'Zevenet::Net::Floating',
					func   => 'setFloatingSourceAddr',
					args   => [$farm_ref, undef],
			);
		}
	}
	elsif ( $param eq "vip" )
	{
		$prev_config = &getFarmStruct( $farm_name );
		$parameters  = qq(, "virtual-addr" : "$value" );
	}
	elsif ( $param eq "vipp" or $param eq "vport" )
	{
		$value =~ s/\:/\-/g;
		if ( $value eq "*" )
		{
			$parameters = qq(, "virtual-ports" : "" );
		}
		else
		{
			$parameters = qq(, "virtual-ports" : "$value" );
		}
	}
	elsif ( $param eq "alg" )
	{
		$value = "rr" if ( $value eq "roundrobin" );

		if ( $value eq "hash_srcip_srcport" )
		{
			$value    = "hash";
			$addition = $addition . qq( , "sched-param" : "srcip srcport" );
		}

		if ( $value eq "hash_srcip" )
		{
			$value    = "hash";
			$addition = $addition . qq( , "sched-param" : "srcip" );
		}

		require Zevenet::Farm::L4xNAT::L4sd;
		if ( $value eq "leastconn" )
		{
			&setL4sdType( $farm_name, $value );
			$value = "weight";
		}
		else
		{
			&setL4sdType( $farm_name, "none" );
		}

		$parameters = qq(, "scheduler" : "$value" ) . $addition;
	}
	elsif ( $param eq "proto" )
	{
		$srvparam = "protocol";

		&loadL4Modules( $value );

		if ( $value =~ /^ftp|irc|pptp|sane/ )
		{
			$addition = $addition . qq( , "helper" : "$value" );
			$value    = "tcp";
		}
		elsif ( $value =~ /tftp|snmp|amanda|netbios-ns/ )
		{
			$addition = $addition . qq( , "helper" : "$value" );
			$value    = "udp";
		}
		elsif ( $value =~ /sip|h323/ )
		{
			$addition = $addition . qq( , "helper" : "$value" );
			$value    = "all";
		}
		else
		{
			$addition = $addition . qq( , "helper" : "none" );
		}

		$addition = $addition . qq( , "virtual-ports" : "" ) if ( $value eq "all" );
		$parameters = qq(, "protocol" : "$value" ) . $addition;
	}
	elsif ( $param eq "status" || $param eq "bootstatus" )
	{
		$parameters = qq(, "state" : "$value" );
	}
	elsif ( $param eq "persist" )
	{
		$value = "srcip" if ( $value eq "ip" );
		$value = "none"  if ( $value eq "" );
		$parameters = qq(, "persistence" : "$value" );
	}
	elsif ( $param eq "persisttm" )
	{
		$parameters = qq(, "persist-ttl" : "$value" );
	}
	elsif ( $param eq "limitrst" )
	{
		$parameters = qq(, "rst-rtlimit" : "$value" );
	}
	elsif ( $param eq "limitrstbrst" )
	{
		$parameters = qq(, "rst-rtlimit-burst" : "$value" );
	}
	elsif ( $param eq "limitrst-logprefix" )
	{
		$parameters = qq(, "rst-rtlimit-log-prefix" : "$value" );
	}
	elsif ( $param eq "limitsec" )
	{
		$parameters = qq(, "new-rtlimit" : "$value" );
	}
	elsif ( $param eq "limitsecbrst" )
	{
		$parameters = qq(, "new-rtlimit-burst" : "$value" );
	}
	elsif ( $param eq "limitsec-logprefix" )
	{
		$parameters = qq(, "new-rtlimit-log-prefix" : "$value" );
	}
	elsif ( $param eq "limitconns" )
	{
		$parameters = qq(, "est-connlimit" : "$value" );
	}
	elsif ( $param eq "limitconns-logprefix" )
	{
		$parameters = qq(, "est-connlimit-log-prefix" : "$value" );
	}
	elsif ( $param eq "bogustcpflags" )
	{
		$parameters = qq(, "tcp-strict" : "$value" );
	}
	elsif ( $param eq "bogustcpflags-logprefix" )
	{
		$parameters = qq(, "tcp-strict-log-prefix" : "$value" );
	}
	elsif ( $param eq "nfqueue" )
	{
		$parameters = qq(, "queue" : "$value" );
	}
	elsif ( $param eq "sourceaddr" )
	{
		$parameters = qq(, "source-addr" : "$value" );
	}
	elsif ( $param eq 'policy' )
	{
		$parameters = qq(, "policies" : [ { "name" : "$value" } ] );
	}
	else
	{
		return -1;
	}

	require Zevenet::Farm::L4xNAT::Action;

	$output = &sendL4NlbCmd(
				{
				  farm   => $farm_req,
				  file   => ( $param ne 'status' ) ? "$configdir/$farm_filename" : undef,
				  method => "PUT",
				  body   => qq({"farms" : [ { "name" : "$farm_name"$parameters } ] })
				}
	);

	# Finally, reload rules
	if ( $param eq "vip" )
	{
		&doL4FarmRules( "reload", $farm_name, $prev_config );

		# reload source address maquerade
		require Zevenet::Farm::Config;
		&reloadFarmsSourceAddressByFarm( $farm_name );
	}

	return $output;
}

=begin nd
Function: _getL4ParseFarmConfig

	Parse the farm file configuration and read/write a certain parameter

Parameters:
	param - requested parameter. The options are "family", "vip", "vipp", "status", "mode", "alg", "proto", "persist", "presisttm", "limitsec", "limitsecbrst", "limitconns", "limitrst", "limitrstbrst", "bogustcpflags", "nfqueue", "sourceaddr"
	value - value to be changed in case of write operation, undef for read only cases
	config - reference of an array with the full configuration file

Returns:
	Scalar - return the parameter value on read or the changed value in case of write as a string or -1 in other case

=cut

sub _getL4ParseFarmConfig
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my ( $param, $value, $config ) = @_;
	my $output = -1;
	my $exit   = 1;

	foreach my $line ( @{ $config } )
	{
		if ( $line =~ /\"family\"/ && $param eq 'family' )
		{
			my @l = split /"/, $line;
			$output = $l[3];
		}

		if ( $line =~ /\"virtual-addr\"/ && $param eq 'vip' )
		{
			my @l = split /"/, $line;
			$output = $l[3];
		}

		if ( $line =~ /\"virtual-ports\"/ && $param eq 'vipp' )
		{
			my @l = split /"/, $line;
			$output = $l[3];
			$output = "*" if ( $output eq '1-65535' || $output eq '' );
			$output =~ s/-/:/g;
		}

		if ( $line =~ /\"source-addr\"/ && $param eq 'sourceaddr' )
		{
			my @l = split /"/, $line;
			$output = $l[3];
		}

		if ( $line =~ /\"mode\"/ && $param eq 'mode' )
		{
			my @l = split /"/, $line;
			$output = $l[3];
			$output = "nat" if ( $output eq "snat" );
			$output = "stateless_dnat" if ( $output eq "stlsdnat" );
		}

		if ( $line =~ /\"protocol\"/ && $param eq 'proto' )
		{
			my @l = split /"/, $line;
			$output = $l[3];
			$exit   = 0;
		}

		if ( $line =~ /\"persistence\"/ && $param eq 'persist' )
		{
			my @l = split /"/, $line;
			my $out = $l[3];
			if ( $out =~ /none/ )
			{
				$output = "";
			}
			elsif ( $out =~ /srcip/ )
			{
				$output = "ip";
				$output = "srcip_srcport" if ( $out =~ /srcport/ );
				$output = "srcip_dstport" if ( $out =~ /dstport/ );
			}
			elsif ( $out =~ /srcport/ )
			{
				$output = "srcport";
			}
			elsif ( $out =~ /srcmac/ )
			{
				$output = "srcmac";
			}
			$exit = 0;
		}

		if ( $line =~ /\"persist-ttl\"/ && $param eq 'persisttm' )
		{
			my @l = split /"/, $line;
			$output = $l[3] + 0;
			$exit   = 0;
		}

		if ( $line =~ /\"helper\"/ && $param eq 'proto' )
		{
			my @l = split /"/, $line;
			my $out = $l[3];

			$output = $out if ( $out ne "none" );
			$exit = 1;
		}

		if ( $line =~ /\"scheduler\"/ && $param eq 'alg' )
		{
			my @l = split /"/, $line;
			$output = $l[3];

			$exit   = 0            if ( $output =~ /hash/ );
			$output = "roundrobin" if ( $output eq "rr" );
		}

		if ( $line =~ /\"sched-param\"/ && $param eq 'alg' )
		{
			my @l = split /"/, $line;
			my $out = $l[3];

			if ( $output eq "hash" )
			{
				if ( $out =~ /srcip/ )
				{
					$output = "hash_srcip";
					$output = "hash_srcip_srcport" if ( $out =~ /srcport/ );
				}
			}
			$exit = 1;
		}

		if ( $line =~ /\"log\"/ && $param eq 'logs' )
		{
			my @l = split /"/, $line;
			$output = "false";
			$output = "true" if ( $l[3] ne "none" );
		}

		if ( $line =~ /\"state\"/ && $param =~ /status/ )
		{
			my @l = split /"/, $line;
			if ( $l[3] ne "up" )
			{
				$output = "down";
			}
			else
			{
				$output = "up";
			}
		}

		if ( $line =~ /\"rst-rtlimit\"/ && $param eq "limitrst" )
		{
			my @l = split /"/, $line;
			$output = $l[3];
		}

		if ( $line =~ /\"rst-rtlimit-burst\"/ && $param eq "limitrstbrst" )
		{
			my @l = split /"/, $line;
			$output = $l[3];
		}

		if ( $line =~ /\"new-rtlimit\"/ && $param eq "limitsec" )
		{
			my @l = split /"/, $line;
			$output = $l[3];
		}

		if ( $line =~ /\"new-rtlimit-burst\"/ && $param eq "limitsecbrst" )
		{
			my @l = split /"/, $line;
			$output = $l[3];
		}

		if ( $line =~ /\"est-connlimit\"/ && $param eq "limitconns" )
		{
			my @l = split /"/, $line;
			$output = $l[3];
		}

		if ( $line =~ /\"tcp-strict\"/ && $param eq "bogustcpflags" )
		{
			my @l = split /"/, $line;
			$output = $l[3];
		}

		if ( $line =~ /\"queue\"/ && $param eq "nfqueue" )
		{
			my @l = split /"/, $line;
			$output = $l[3];
		}

		if ( $output ne "-1" )
		{
			$line =~ s/$output/$value/g if defined $value;
			return $output if ( $exit );
		}
	}

	return $output;
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

	require Zevenet::Farm::L4xNAT::Action;

	my $pidfile = &getL4FarmPidFile( $farm_name );
	my $output  = "down";

	my $nlbpid = &getNlbPid();
	if ( $nlbpid eq "-1" )
	{
		return $output;
	}

	$output = "up" if ( -e "$pidfile" );

	return $output;
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
	my %farm;

	$farm{ name } = shift;

	require Zevenet::Farm::L4xNAT::Backend;

	$farm{ filename } = &getFarmFile( $farm{ name } );
	require Zevenet::Farm::Config;
	my $config = &getFarmPlainInfo( $farm{ name } );

	$farm{ nattype } = &_getL4ParseFarmConfig( 'mode', undef, $config );
	$farm{ mode } = $farm{ nattype };

	require Zevenet::Farm::L4xNAT::L4sd;
	my $l4sched = &getL4sdType( $farm{ name } );
	if ( $l4sched ne "" )
	{
		$farm{ lbalg } = $l4sched;
	}
	else
	{
		$farm{ lbalg } = &_getL4ParseFarmConfig( 'alg', undef, $config );
	}

	$farm{ vip }    = &_getL4ParseFarmConfig( 'vip',   undef, $config );
	$farm{ vport }  = &_getL4ParseFarmConfig( 'vipp',  undef, $config );
	$farm{ vproto } = &_getL4ParseFarmConfig( 'proto', undef, $config );

	my $persist = &_getL4ParseFarmConfig( 'persist', undef, $config );
	$farm{ persist } = ( $persist eq "-1" ) ? '' : $persist;
	my $ttl = &_getL4ParseFarmConfig( 'persisttm', undef, $config );
	$farm{ ttl } = ( $ttl == -1 ) ? 0 : $ttl;

	$farm{ proto }      = &getL4ProtocolTransportLayer( $farm{ vproto } );
	$farm{ bootstatus } = &_getL4ParseFarmConfig( 'bootstatus', undef, $config );
	$farm{ status }     = &getL4FarmStatus( $farm{ name } );
	$farm{ logs } = &_getL4ParseFarmConfig( 'logs', undef, $config ) if ( $eload );
	$farm{ servers } = &_getL4FarmParseServers( $config );

	if ( $farm{ lbalg } eq 'weight' )
	{
		&getL4BackendsWeightProbability( \%farm );
	}

	return \%farm;
}

=begin nd
Function: getL4FarmsPorts

	Get all port used of L4xNAT farms in up status and using a protocol

Parameters:
	protocol - protocol used by l4xnat farm

Returns:
	String - return a list with the used ports by all L4xNAT farms. Format: "portList1,portList2,..."

=cut

sub getL4FarmsPorts
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $protocol = shift;

	my $port_list       = "";
	my @farms_filenames = &getFarmList();

	unless ( $#farms_filenames > -1 )
	{
		return $port_list;
	}

	foreach my $farm_filename ( @farms_filenames )
	{
		my $farm_name = &getFarmName( $farm_filename );
		my $farm_type = &getFarmType( $farm_name );

		next if not ( $farm_type eq "l4xnat" );

		my $farm_protocol = &getL4FarmParam( 'proto', $farm_name );

		next if not ( $protocol eq $farm_protocol );
		next if ( &getL4FarmParam( 'status', $farm_name ) ne "up" );

		my $farm_port = &getL4FarmParam( 'vipp', $farm_name );
		$farm_port = join ( ',', &getFarmPortList( $farm_port ) );
		next if not &validL4ExtPort( $farm_protocol, $farm_port );

		$port_list .= "$farm_port,";
	}

	chop ( $port_list );

	return $port_list;
}

=begin nd
Function: loadL4Modules

	Load sip, ftp or tftp conntrack module for l4 farms

Parameters:
	protocol - protocol module to load

Returns:
	Integer - 0 if success, otherwise error

=cut

sub loadL4Modules
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $protocol = shift;

	require Zevenet::Netfilter;

	my $status = 0;

	if ( $protocol =~ /sip|tftp|ftp|amanda|h323|irc|netbios-ns|pptp|sane|snmp/ )
	{
		$status = &loadNfModule( "nf_conntrack_$protocol", "" );
		$status = $status || &loadNfModule( "nf_nat_$protocol", "" );
	}

	return $status;
}

=begin nd
Function: unloadL4Modules

	Unload conntrack helpers modules for l4 farms

Parameters:
	protocol - protocol module to load

Returns:
	Integer - 0 if success, otherwise error

=cut

sub unloadL4Modules
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $protocol = shift;
	my $status   = 0;

	require Zevenet::Netfilter;

	if ( $protocol =~ /sip|tftp|ftp|amanda|h323|irc|netbios-ns|pptp|sane|snmp/ )
	{
		$status = &removeNfModule( "nf_nat_$protocol" );
		$status = $status || &removeNfModule( "nf_conntrack_$protocol", "" );
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

sub validL4ExtPort
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
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
Function: getFarmPortList

	If port is multiport, it removes range port and it passes it to a port list

Parameters:
	fvipp - Port string

Returns:
	array - return a list of ports

=cut

sub getFarmPortList
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
	    ( $vproto =~ /sip|tftp/ ) ? 'udp'
	  : ( $vproto eq 'ftp' )      ? 'tcp'
	  :                             $vproto;
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
	my $farm = shift;

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
Function: doL4FarmRules

	Created to operate with setL4BackendRule in order to start, stop or reload ip rules

Parameters:
	action - stop (delete all ip rules), start (create ip rules) or reload (delete old one stored in prev_farm_ref and create new)
	farm_name - farm hash ref. It is a hash with all information about the farm
	prev_farm_ref - farm ref of the old configuration

Returns:
	none - .

=cut

sub doL4FarmRules
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $action        = shift;
	my $farm_name     = shift;
	my $prev_farm_ref = shift;

	my $farm_ref = &getL4FarmStruct( $farm_name );

	foreach my $server ( @{ $farm_ref->{ servers } } )
	{
		&setL4BackendRule( "del", $farm_ref, $server->{ tag } )
		  if ( $action eq "stop" );
		&setL4BackendRule( "del", $prev_farm_ref, $server->{ tag } )
		  if ( $action eq "reload" );
		&setL4BackendRule( "add", $farm_ref, $server->{ tag } )
		  if ( $action eq "start" || $action eq "reload" );
	}
}

=begin nd
Function: writeL4NlbConfigFile

	Write the L4 config file from a curl Nlb request, by filtering IPDS parameters.

Parameters:
	nftfile - temporary file captured from the nftlb farm configuration
	cfgfile - definitive file where the definitive nftlb farm configuration will be stored

Returns:
	Integer - 0 if success, other if error.

=cut

sub writeL4NlbConfigFile
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );

	my $nftfile = shift;
	my $cfgfile = shift;

	require Zevenet::Lock;

	if ( !-e "$nftfile" )
	{
		return 1;
	}

	my $fo = &openlock( $cfgfile, 'w' );
	open my $fi, '<', "$nftfile";
	my $backends = 0;
	my $policies = 0;
	while ( my $line = <$fi> )
	{
		$backends = 1 if ( $line =~ /\"backends\"\:/ );
		$policies = 1 if ( $line =~ /\"policies\"\:/ );
		if ( $backends == 1 && $line =~ /\]/ )
		{
			$backends = 0;
			$line =~ s/,$//g;
		}
		print $fo $line
		  if (
			   $line !~ /new-rtlimit|rst-rtlimit|tcp-strict|queue|^[\s]{24}.est-connlimit/
			   && $policies == 0 );
		$policies = 0 if ( $policies == 1 && $line =~ /\]/ );
	}
	close $fo;
	close $fi;
	unlink $nftfile;

	return 0;
}

1;
