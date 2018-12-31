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
		"bootstatus": get boot status
		"status": get the current status
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

	if ( $param eq "status" )
	{
		return &getL4FarmStatus( $farm_name );
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
	my $addition      = "";
	my $farm_req      = $farm_name;

	if ( $param eq "name" )
	{
		$srvparam      = "newname";
		$farm_filename = "${value}_l4xnat.cfg";
		$farm_req      = $value;
	}
	elsif ( $param eq "family" )
	{
		$srvparam = $param;
	}
	elsif ( $param eq "mode" )
	{
		$srvparam = $param;
		$value    = "snat" if ( $value eq "nat" );
		$value    = "stlsdnat" if ( $value eq "stateless_dnat" );
	}
	elsif ( $param eq "vip" )
	{
		$srvparam = "virtual-addr";
	}
	elsif ( $param eq "vipp" )
	{
		$srvparam = "virtual-ports";
		$value =~ s/\:/\-/g, $value;
	}
	elsif ( $param eq "alg" )
	{
		$srvparam = "scheduler";

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
	}
	elsif ( $param eq "proto" )
	{
		$srvparam = "protocol";

		if ( $value =~ /ftp|irc|pptp/ )
		{
			$addition = $addition . qq( , "helper" : "$value" );
			$value    = "tcp";
		}
		elsif ( $value =~ /tftp/ )
		{
			$addition = $addition . qq( , "helper" : "$value" );
			$value    = "udp";
		}
		elsif ( $value =~ /sip|amanda|h323|netbios-ns|sane|snmp/ )
		{
			$addition = $addition . qq( , "helper" : "$value" );
			$value    = "all";
		}
		else
		{
			$addition = $addition . qq( , "helper" : "none" );
		}

		$addition = $addition . qq( , "vport" : "" ) if ( $value eq "all" );
	}
	elsif ( $param eq "status" || $param eq "bootstatus" )
	{
		$srvparam = "state";
	}
	elsif ( $param =~ /persist/ )
	{
		return 0;    # TODO
	}
	elsif ( $param eq "logs" )
	{
		$srvparam = "log";
		$value    = "input" if ( $value eq "true" );
		$value    = "none" if ( $value eq "false" );
	}
	else
	{
		return -1;
	}

	# load the configuration file first if the farm is down
	my $f_ref = &getL4FarmStruct( $farm_name );
	if ( $f_ref->{ status } ne "up" )
	{
		my $out = &loadNLBFarm( $farm_name );
		if ( $out != 0 )
		{
			return $out;
		}
	}

	$output = &httpNLBRequest(
		{
		   farm       => $farm_req,
		   configfile => ( $param ne 'status' ) ? "$configdir/$farm_filename" : undef,
		   method     => "PUT",
		   uri        => "/farms",
		   body =>
			 qq({"farms" : [ { "name" : "$farm_name", "$srvparam" : "$value"$addition } ] })
		}
	);

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
	my ( $param, $value, $config ) = @_;
	my $output = -1;
	my $exit   = 1;

	if ( $param eq 'persist' || $param eq 'persisttm' )
	{
		$output = "none";
		return $output;
	}

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
			$output =~ s/-/:/g;
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
			$exit   = 0;
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

		if ( $output ne "-1" )
		{
			$line =~ s/$output/$value/r if $value != undef;
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

	my $nlbpid = &getNLBPid();
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
	my %farm;    # declare output hash

	$farm{ name } = shift;    # input: farm name

	require Zevenet::Farm::L4xNAT::Backend;

	$farm{ filename } = &getFarmFile( $farm{ name } );
	require Zevenet::Farm::Config;
	my $config = &getFarmPlainInfo( $farm{ name } );

	$farm{ nattype } = &_getL4ParseFarmConfig( 'mode', undef, $config );
	$farm{ mode }    = $farm{ nattype };
	$farm{ lbalg }   = &_getL4ParseFarmConfig( 'alg', undef, $config );
	$farm{ vip }     = &_getL4ParseFarmConfig( 'vip', undef, $config );
	$farm{ vport }   = &_getL4ParseFarmConfig( 'vipp', undef, $config );
	$farm{ vproto }  = &_getL4ParseFarmConfig( 'proto', undef, $config );

#	$farm{ persist }    = &_getL4ParseFarmConfig( 'persist', undef, $config ); #TODO: not yet supported
#	$farm{ ttl }        = &_getL4ParseFarmConfig( 'persisttm', undef, $config );
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

	if ( $farm{ lbalg } eq 'weight' )
	{
		&getL4BackendsWeightProbability( \%farm );
	}

	return \%farm;    # return a hash reference
}

=begin nd
Function: httpNLBRequest

	Send an action to nftlb

Parameters:
	hash - includes a method, uri, reference of headers and body

Returns:
	Integer - return code of the request command

=cut

sub httpNLBRequest # ( \%hash ) hash_keys->( $farm, $configfile, $method, $uri, %headers, $body )
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $self     = shift;
	my $curl_cmd = `which curl`;    #TODO
	my $output   = -1;
	my $body     = "";

	require Zevenet::Farm::L4xNAT::Action;

	my $pid = &startNLB();
	if ( $pid <= 0 )
	{
		return -1;
	}

	chomp ( $curl_cmd );

	$body = qq(-d'$self->{ body }') if ( $self->{ body } );
	my $execmd =
	  qq($curl_cmd -s -H "Key: HoLa" -H \"Expect:\" -X "$self->{ method }" $body http://127.0.0.1:27$self->{ uri });

	#~ &zenlog( "Executing nftlb: " . "$execmd" );
	$output = &logAndRun( $execmd );

	if ( $output != 0 )
	{
		return -1;
	}

	if ( $self->{ method } eq "GET" )
	{
		return $output;
	}

	my $execmd =
	  "$curl_cmd -s -H \"Key: HoLa\" -H \"Expect:\" -X \"GET\" http://127.0.0.1:27/farms/$self->{ farm }";

	if ( $self->{ method } =~ /PUT|DELETE/ and $self->{ configfile } )
	{
		$execmd = $execmd . " > '$self->{ configfile }'";
	}

	$output = &logAndRun( $execmd );

	if ( $output != 0 )
	{
		return -1;
	}

	return 0;
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
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
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

# TODO: Obsolete. Eliminate callers.
sub reloadL4FarmsSNAT
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	require Zevenet::Farm::Core;
	require Zevenet::Farm::Base;
}

1;
