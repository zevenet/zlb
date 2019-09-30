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
Function: setL4FarmServer

	Edit a backend or add a new one if the id is not found

Parameters:
	farmname - Farm name
	id - Backend id
	rip - Backend IP
	port - Backend port
	weight - Backend weight. The backend with more weight will manage more connections
	priority - The priority of this backend (between 1 and 9). Higher priority backends will be used more often than lower priority ones
	maxconn - Maximum connections for the given backend

Returns:
	Integer - return 0 on success, -1 on NFTLB failure or -2 on IP duplicated.

Returns:
	Scalar - 0 on success or other value on failure
	FIXME: Stop returning -2 when IP duplicated, nftlb should do this
=cut

sub setL4FarmServer
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my ( $farm_name, $ids, $ip, $port, $weight, $priority, $max_conns ) = @_;

	require Zevenet::Farm::L4xNAT::Config;
	require Zevenet::Farm::L4xNAT::Action;
	require Zevenet::Farm::Backend;
	require Zevenet::Netfilter;

	my $farm_filename = &getFarmFile( $farm_name );
	my $output        = 0;
	my $json          = qq();
	my $msg           = "setL4FarmServer << farm_name:$farm_name ids:$ids ";

	# load the configuration file first if the farm is down
	my $f_ref = &getL4FarmStruct( $farm_name );
	if ( $f_ref->{ status } ne "up" )
	{
		my $out = &loadL4FarmNlb( $farm_name );
		return $out if ( $out != 0 );
	}

	my $exists = &getFarmServer( $f_ref->{ servers }, $ids );

	my $rip = $ip;

	if ( defined $port && $port ne "" )
	{
		if ( &ipversion( $ip ) == 4 )
		{
			$rip = "$ip\:$port";
		}
		elsif ( &ipversion( $ip ) == 6 )
		{
			$rip = "[$ip]\:$port";
		}

		if ( !defined $exists || ( defined $exists && $exists->{ port } ne $port ) )
		{
			$json .= qq(, "port" : "$port");
			$msg  .= "port:$port ";
		}
	}

	if (   defined $ip
		&& $ip ne ""
		&& ( !defined $exists || ( defined $exists && $exists->{ rip } ne $rip ) ) )
	{
		my $existrip = &getFarmServer( $f_ref->{ servers }, $rip, "rip" );
		return -2 if ( defined $existrip && ( $existrip->{ id } ne $ids ) );
		$json = qq(, "ip-addr" : "$ip") . $json;
		$msg .= "ip:$ip ";

		my $mark = "0x0";
		if ( !defined $exists )
		{
			$mark = &getNewMark( $farm_name );
			return -1 if ( !defined $mark || $mark eq "" );
			$json .= qq(, "mark" : "$mark");
			$msg  .= "mark:$mark ";
		}
		else
		{
			$mark = $exists->{ tag };
		}
		&setL4BackendRule( "add", $f_ref, $mark );
	}

	if (   defined $weight
		&& $weight ne ""
		&& ( !defined $exists || ( defined $exists && $exists->{ weight } ne $weight ) )
	  )
	{
		$weight = 1 if ( $weight == 0 );
		$json .= qq(, "weight" : "$weight");
		$msg  .= "weight:$weight ";
	}

	if (
		    defined $priority
		 && $priority ne ""
		 && ( !defined $exists
			  || ( defined $exists && $exists->{ priority } ne $priority ) )
	  )
	{
		$priority = 1 if ( $priority == 0 );
		$json .= qq(, "priority" : "$priority");
		$msg  .= "priority:$priority ";
	}

	if (
		    defined $max_conns
		 && $max_conns ne ""
		 && ( !defined $exists
			  || ( defined $exists && $exists->{ max_conns } ne $max_conns ) )
	  )
	{
		$max_conns = 0 if ( $max_conns < 0 );
		$json .= qq(, "est-connlimit" : "$max_conns");
		$msg  .= "maxconns:$max_conns ";
	}

	if ( !defined $exists )
	{
		$json .= qq(, "state" : "up");
		$msg  .= "state:up ";
	}

	&zenlog( "$msg" ) if &debug;

	$output = &sendL4NlbCmd(
		{
		   farm   => $farm_name,
		   file   => "$configdir/$farm_filename",
		   method => "PUT",
		   body =>
			 qq({"farms" : [ { "name" : "$farm_name", "backends" : [ { "name" : "bck$ids"$json } ] } ] })
		}
	);

	# take care of floating interfaces without masquerading
	if ( $json =~ /ip-addr/ && $eload )
	{
		my $farm_ref = &getL4FarmStruct( $farm_name );
		&eload(
				module => 'Zevenet::Net::Floating',
				func   => 'setFloatingSourceAddr',
				args   => [$farm_ref, { ip => $ip, id => $ids }],
		);
	}

	return $output;
}

=begin nd
Function: runL4FarmServerDelete

	Delete a backend from a l4 farm

Parameters:
	backend - Backend id
	farmname - Farm name

Returns:
	Scalar - 0 on success or other value on failure

=cut

sub runL4FarmServerDelete
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my ( $ids, $farm_name ) = @_;

	require Zevenet::Farm::L4xNAT::Config;
	require Zevenet::Farm::L4xNAT::Action;
	require Zevenet::Netfilter;

	my $farm_filename = &getFarmFile( $farm_name );
	my $output        = 0;
	my $mark          = "0x0";

	# load the configuration file first if the farm is down
	my $f_ref = &getL4FarmStruct( $farm_name );

	$output = &sendL4NlbCmd(
							 {
							   farm    => $farm_name,
							   backend => "bck" . $ids,
							   file    => "$configdir/$farm_filename",
							   method  => "DELETE",
							 }
	);

	foreach my $server ( @{ $f_ref->{ servers } } )
	{
		if ( $server->{ id } eq $ids )
		{
			$mark = $server->{ tag };
			last;
		}
	}

	&setL4BackendRule( "del", $f_ref, $mark );
	&delMarks( "", $mark );

	return $output;
}

=begin nd
Function: setL4FarmBackendsSessionsRemove

	Remove all the active sessions enabled to a backend in a given service
	Used by farmguardian

Parameters:
	farmname - Farm name
	backend - Backend id

Returns:
	Integer - 0 on success or -1 on failure

=cut

sub setL4FarmBackendsSessionsRemove
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my ( $farmname, $backend ) = @_;
	my $output = 0;

	my $nft_bin = &getGlobalConfiguration( 'nft_bin' );

	require Zevenet::Farm::L4xNAT::Config;

	my $farm = &getL4FarmStruct( $farmname );

	return 0 if ( $farm->{ persist } eq "" );

	my $be = $farm->{ servers }[$backend];
	( my $tag = $be->{ tag } ) =~ s/0x//g;
	my $map_name   = "persist-$farmname";
	my @persistmap = `$nft_bin list map nftlb $map_name`;
	my $data       = 0;

	foreach my $line ( @persistmap )
	{
		$data = 1 if ( $line =~ /elements = / );
		next if ( !$data );

		my ( $key, $time, $value ) =
		  ( $line =~ / ([\w\.\s\:]+) expires (\w+) : (\w+)[\s,]/ );
		&logAndRun( "/usr/local/sbin/nft delete element nftlb $map_name { $key }" )
		  if ( $value =~ /^0x.0*$tag/ );

		( $key, $time, $value ) =
		  ( $line =~ /, ([\w\.\s\:]+) expires (\w+) : (\w+)[\s,]/ );
		&logAndRun( "/usr/local/sbin/nft delete element nftlb $map_name { $key }" )
		  if ( $value ne "" && $value =~ /^0x.0*$tag/ );

		last if ( $data && $line =~ /\}/ );
	}

	return $output;
}

=begin nd
Function: setL4FarmBackendStatus

	Set backend status for a l4 farm

Parameters:
	farmname - Farm name
	backend - Backend id
	status - Backend status. The possible values are: "up" or "down"
	cutmode - cut to force the traffic stop for such backend

Returns:
	Integer - 0 on success or other value on failure

=cut

sub setL4FarmBackendStatus
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my ( $farm_name, $backend, $status, $cutmode ) = @_;

	require Zevenet::Farm::L4xNAT::Config;
	require Zevenet::Farm::L4xNAT::Action;

	my $output        = 0;
	my $farm          = &getL4FarmStruct( $farm_name );
	my $farm_filename = $farm->{ filename };

	$status = 'off'  if ( $status eq "maintenance" );
	$status = 'down' if ( $status eq "fgDOWN" );

	$output =
	  &sendL4NlbCmd(
		{
		   farm   => $farm_name,
		   file   => "$configdir/$farm_filename",
		   method => "PUT",
		   body =>
			 qq({"farms" : [ { "name" : "$farm_name", "backends" : [ { "name" : "bck$backend", "state" : "$status" } ] } ] })
		}
	  );

	if ( $status ne "up" && $cutmode eq "cut" && $farm->{ persist } ne '' )
	{
		&setL4FarmBackendsSessionsRemove( $farm_name, $backend );

		# remove conntrack
		my $server = $$farm{ servers }[$backend];
		&resetL4FarmBackendConntrackMark( $server );
	}

	#~ TODO
	#~ my $stopping_fg = ( $caller =~ /runFarmGuardianStop/ );
	#~ if ( $fg_enabled eq 'true' && !$stopping_fg )
	#~ {
	#~ if ( $0 !~ /farmguardian/ && $fg_pid > 0 )
	#~ {
	#~ kill 'CONT' => $fg_pid;
	#~ }
	#~ }

	if ( $farm->{ lbalg } eq 'leastconn' )
	{
		require Zevenet::Farm::L4xNAT::L4sd;
		&sendL4sdSignal();
	}

	return $output;
}

=begin nd
Function: getL4FarmServers

	 Get all backends and their configuration

Parameters:
	farmname - Farm name

Returns:
	Array - array of hash refs of backend struct

=cut

sub getL4FarmServers
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $farm_name = shift;

	my $farm_filename = &getFarmFile( $farm_name );

	open my $fd, '<', "$configdir/$farm_filename";
	chomp ( my @content = <$fd> );
	close $fd;

	return &_getL4FarmParseServers( \@content );
}

=begin nd
Function: _getL4FarmParseServers

	Return the list of backends with all data about a backend in a l4 farm

Parameters:
	config - plain text server list

Returns:
	backends array - array of backends structure
		\%backend = { $id, $alias, $family, $ip, $port, $tag, $weight, $priority, $status, $rip = $ip, $max_conns }

=cut

sub _getL4FarmParseServers
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $config = shift;
	my $stage  = 0;
	my $server;
	my @servers;

	require Zevenet::Farm::L4xNAT::Config;
	my $fproto = &_getL4ParseFarmConfig( 'proto', undef, $config );

	foreach my $line ( @{ $config } )
	{
		if ( $line =~ /\"farms\"/ )
		{
			$stage = 1;
		}

		# do not go to the next level if empty
		if ( $line =~ /\"backends\"/ && $line !~ /\[\],/ )
		{
			$stage = 2;
		}

		if ( $stage == 2 && $line =~ /\{/ )
		{
			$stage = 3;
			undef $server;
		}

		if ( $stage == 3 && $line =~ /\}/ )
		{
			$stage = 2;
			push ( @servers, $server );
		}

		if ( $stage == 3 && $line =~ /\"name\"/ )
		{
			my @l = split /"/, $line;
			my $index = $l[3];
			$index =~ s/bck//;
			$server->{ id }        = $index + 0;
			$server->{ port }      = undef;
			$server->{ tag }       = "0x0";
			$server->{ max_conns } = 0 if ( $eload );
		}

		if ( $stage == 3 && $line =~ /\"ip-addr\"/ )
		{
			my @l = split /"/, $line;
			$server->{ ip }  = $l[3];
			$server->{ rip } = $l[3];
		}

		if ( $stage == 3 && $line =~ /\"port\"/ )
		{
			my @l = split /"/, $line;
			$server->{ port } = $l[3];

			require Zevenet::Net::Validate;
			if ( $server->{ port } ne '' && $fproto ne 'all' )
			{
				if ( &ipversion( $server->{ rip } ) == 4 )
				{
					$server->{ rip } = "$server->{ip}\:$server->{port}";
				}
				elsif ( &ipversion( $server->{ rip } ) == 6 )
				{
					$server->{ rip } = "[$server->{ip}]\:$server->{port}";
				}
			}
		}

		if ( $stage == 3 && $line =~ /\"weight\"/ )
		{
			my @l = split /"/, $line;
			$server->{ weight } = $l[3] + 0;
		}

		if ( $stage == 3 && $line =~ /\"priority\"/ )
		{
			my @l = split /"/, $line;
			$server->{ priority } = $l[3] + 0;
		}

		if ( $stage == 3 && $line =~ /\"mark\"/ )
		{
			my @l = split /"/, $line;
			$server->{ tag } = $l[3];
		}

		if ( $stage == 3 && $line =~ /\"est-connlimit\"/ )
		{
			my @l = split /"/, $line;
			$server->{ max_conns } = $l[3] + 0 if ( $eload );
		}

		if ( $stage == 3 && $line =~ /\"state\"/ )
		{
			my @l = split /"/, $line;
			$server->{ status } = $l[3];
			$server->{ status } = "undefined" if ( $server->{ status } eq "config_error" );
			$server->{ status } = "maintenance" if ( $server->{ status } eq "off" );
			$server->{ status } = "fgDOWN" if ( $server->{ status } eq "down" );
		}
	}

	return \@servers;
}

=begin nd
Function: getL4ServerWithLowestPriority

	Look for backend with the lowest priority

Parameters:
	farm - Farm hash ref. It is a hash with all information about the farm

Returns:
	hash ref - reference to the selected server for prio algorithm

=cut

sub getL4ServerWithLowestPriority
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $farm = shift;

	my $prio_server;

	foreach my $server ( @{ $$farm{ servers } } )
	{
		if ( $$server{ status } eq 'up' )
		{
			# find the lowest priority server
			$prio_server = $server if not defined $prio_server;
			$prio_server = $server if $$prio_server{ priority } > $$server{ priority };
		}
	}

	return $prio_server;
}

=begin nd
Function: getL4BackendsWeightProbability

	Get probability for every backend

Parameters:
	farm - Farm hash ref. It is a hash with all information about the farm

Returns:
	none - .

=cut

sub getL4BackendsWeightProbability
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $farm = shift;

	my $weight_sum = 0;

	&doL4FarmProbability( $farm );

	foreach my $server ( @{ $$farm{ servers } } )
	{
		# only calculate probability for the servers running
		if ( $$server{ status } eq 'up' )
		{
			my $delta = $$server{ weight };
			$weight_sum += $$server{ weight };
			$$server{ prob } = $weight_sum / $$farm{ prob };
		}
		else
		{
			$$server{ prob } = 0;
		}
	}
}

=begin nd
Function: getL4BackendsWeightProbability

	Reset Connection tracking for a given backend

Parameters:
	server - Backend hash reference. It uses the backend unique mark in order to deletes the conntrack entries.

Returns:
	scalar - 0 if deleted, 1 if not found or not deleted

=cut

sub resetL4FarmBackendConntrackMark
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $server = shift;

	my $conntrack = &getGlobalConfiguration( 'conntrack' );
	my $cmd       = "$conntrack -D -m $server->{ tag }/0x7fffffff";

	&zenlog( "running: $cmd" ) if &debug();

	# return_code = 0 -> deleted
	# return_code = 1 -> not found/deleted
	my $return_code = system ( "$cmd >/dev/null 2>&1" );

	if ( &debug() )
	{
		if ( $return_code )
		{
			&zenlog( "Connection tracking for " . $server->{ ip } . " not found." );
		}
		else
		{
			&zenlog( "Connection tracking for " . $server->{ ip } . " removed." );
		}
	}

	return $return_code;
}

=begin nd
Function: getL4FarmBackendAvailableID

	Get next available backend ID

Parameters:
	farmname - farm name

Returns:
	integer - .

=cut

sub getL4FarmBackendAvailableID
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $farmname = shift;

	require Zevenet::Farm::Backend;

	my $backends  = &getL4FarmServers( $farmname );
	my $nbackends = $#{ $backends } + 1;

	for ( my $id = 0 ; $id < $nbackends ; $id++ )
	{
		my $exists = &getFarmServer( $backends, $id );
		return $id if ( !$exists );
	}

	return $nbackends;
}

=begin nd
Function: setL4BackendRule

	Add or delete the route rule according to the backend mark.

Parameters:
	action - "add" to create the mark or "del" to remove it.
	farm_ref - farm reference.
	mark - backend mark to apply in the rule.

Returns:
	integer - 0 if successful, otherwise error.

=cut

sub setL4BackendRule
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $action   = shift;
	my $farm_ref = shift;
	my $mark     = shift;

	return -1
	  if (    $action !~ /add|del/
		   || !defined $farm_ref
		   || $mark eq ""
		   || $mark eq "0x0" );

	require Zevenet::Net::Util;
	require Zevenet::Net::Route;

	my $vip_if_name = &getInterfaceOfIp( $farm_ref->{ vip } );
	my $vip_if      = &getInterfaceConfig( $vip_if_name );
	my $table_if =
	  ( $vip_if->{ type } eq 'virtual' ) ? $vip_if->{ parent } : $vip_if->{ name };

	return &setRule( $action, $vip_if, $table_if, "", "$mark/0x7fffffff" );
}

=begin nd
Function: getL4ServerByMark

	Obtain the backend id from the mark

Parameters:
	servers_ref - reference to the servers array
	mark - backend mark to discover the id

Returns:
	integer - > 0 if successful, -1 if error.

=cut

sub getL4ServerByMark
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $servers_ref = shift;
	my $mark        = shift;

	( my $tag = $mark ) =~ s/0x.0*/0x/g;

	foreach my $server ( @{ $servers_ref } )
	{
		if ( $server->{ tag } eq $tag )
		{
			return $server->{ id };
		}
	}

	return -1;
}

1;
