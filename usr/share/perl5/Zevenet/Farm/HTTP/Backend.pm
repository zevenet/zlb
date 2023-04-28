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
sub include;
require Zevenet::Netfilter;
require Zevenet::Farm::Config;

my $configdir = &getGlobalConfiguration( 'configdir' );
my $proxy_ng  = &getGlobalConfiguration( 'proxy_ng' );


=begin nd
Function: setHTTPFarmServer

	Add a new backend to a HTTP service or modify if it exists

Parameters:
	ids - backend id
	rip - backend ip
	port - backend port
	weight - The weight of this backend (between 1 and 9). Higher weight backends will be used more often than lower weight ones.
	timeout - Override the global time out for this backend
	farmname - Farm name
	service - service name
	priority - The priority of this backend (greater than 1). Lower value indicates higher priority

Returns:
	Integer - return 0 on success or -1 on failure

=cut

sub setHTTPFarmServer # ($ids,$rip,$port,$weight,$timeout,$farm_name,$service,$priority,$connlimit)
{
	&zenlog( __FILE__ . q{:} . __LINE__ . q{:} . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my (
		 $ids,       $rip,     $port,     $weight, $timeout,
		 $farm_name, $service, $priority, $connlimit
	) = @_;

	if ( $proxy_ng eq 'true' )
	{
		return
		  &setHTTPNGFarmServer(
								$ids,     $rip,      $port,
								$weight,  $timeout,  $farm_name,
								$service, $priority, $connlimit
		  );
	}
	elsif ( $proxy_ng eq 'false' )
	{
		$priority = $weight;
	}

	my $farm_filename = &getFarmFile( $farm_name );
	my $output        = -1;

	require Zevenet::Lock;
	my $lock_file = &getLockFile( $farm_name );
	my $lock_fh = &openlock( $lock_file, 'w' );

	require Tie::File;
	tie my @contents, 'Tie::File', "$configdir\/$farm_filename";

	if ( $ids !~ /^$/ )
	{
		my $index_count = -1;
		my $i           = -1;
		my $sw          = 0;

		foreach my $line ( @contents )
		{
			$i++;

			#search the service to modify
			if ( $line =~ /Service \"$service\"/ )
			{
				$sw = 1;
			}
			if ( $line =~ /BackEnd/ and $line !~ /#/ and $sw eq 1 )
			{
				$index_count++;
				if ( $index_count == $ids )
				{
					#server for modify $ids;
					#HTTPS
					my $httpsbe = &getHTTPFarmVS( $farm_name, $service, "httpsbackend" );
					if ( $httpsbe eq "true" )
					{
						#add item
						$i++;
					}
					$output           = $?;
					$contents[$i + 1] = "\t\t\tAddress $rip";
					$contents[$i + 2] = "\t\t\tPort $port";
					my $p_m = 0;
					if ( $contents[$i + 3] =~ /TimeOut/ )
					{
						$contents[$i + 3] = "\t\t\tTimeOut $timeout";
						&zenlog( "Modified current timeout", "info", "LSLB", "info", "LSLB" );
					}
					if ( $contents[$i + 4] =~ /Priority/ )
					{
						$contents[$i + 4] = "\t\t\tPriority $priority";
						&zenlog( "Modified current priority", "info", "LSLB" );
						$p_m = 1;
					}
					if ( $contents[$i + 3] =~ /Priority/ )
					{
						$contents[$i + 3] = "\t\t\tPriority $priority";
						$p_m = 1;
					}

					#delete item
					if ( $timeout =~ /^$/ )
					{
						if ( $contents[$i + 3] =~ /TimeOut/ )
						{
							splice @contents, $i + 3, 1,;
						}
					}
					if ( $priority =~ /^$/ )
					{
						if ( $contents[$i + 3] =~ /Priority/ )
						{
							splice @contents, $i + 3, 1,;
						}
						if ( $contents[$i + 4] =~ /Priority/ )
						{
							splice @contents, $i + 4, 1,;
						}
					}

					#new item
					if (
						 $timeout !~ /^$/
						 and (    $contents[$i + 3] =~ /End/
							   or $contents[$i + 3] =~ /Priority/ )
					  )
					{
						splice @contents, $i + 3, 0, "\t\t\tTimeOut $timeout";
					}
					if (
						     $p_m eq 0
						 and $priority !~ /^$/
						 and (    $contents[$i + 3] =~ /End/
							   or $contents[$i + 4] =~ /End/ )
					  )
					{
						if ( $contents[$i + 3] =~ /TimeOut/ )
						{
							splice @contents, $i + 4, 0, "\t\t\tPriority $priority";
						}
						else
						{
							splice @contents, $i + 3, 0, "\t\t\tPriority $priority";
						}
					}
				}
			}
		}
	}
	else
	{
		#add new server
		my $nsflag     = "true";
		my $index      = -1;
		my $backend    = 0;
		my $be_section = -1;

		foreach my $line ( @contents )
		{
			$index++;
			if ( $be_section == 1 and $line =~ /Address/ )
			{
				$backend++;
			}
			if ( $line =~ /Service \"$service\"/ and $be_section == -1 )
			{
				$be_section++;
			}
			if ( $line =~ /#BackEnd/ and $be_section == 0 )
			{
				$be_section++;
			}
			if ( $be_section == 1 and $line =~ /#End/ )
			{
				splice @contents, $index, 0, "\t\tBackEnd";
				$output = $?;
				$index++;
				splice @contents, $index, 0, "\t\t\tAddress $rip";
				my $httpsbe = &getHTTPFarmVS( $farm_name, $service, "httpsbackend" );
				if ( $httpsbe eq "true" )
				{
					#add item
					splice @contents, $index, 0, "\t\t\tHTTPS";
					$index++;
				}
				$index++;
				splice @contents, $index, 0, "\t\t\tPort $port";
				$index++;

				#Timeout?
				if ( $timeout )
				{
					splice @contents, $index, 0, "\t\t\tTimeOut $timeout";
					$index++;
				}

				#Priority?
				if ( $priority )
				{
					splice @contents, $index, 0, "\t\t\tPriority $priority";
					$index++;
				}
				splice @contents, $index, 0, "\t\tEnd";
				$be_section++;    # Backend Added
			}

			# if backend added then go out of form
		}
		if ( $nsflag eq "true" )
		{
			my $idservice = &getFarmVSI( $farm_name, $service );
			if ( $idservice ne "" )
			{
				&setHTTPFarmBackendStatusFile( $farm_name, $backend, "active", $idservice );
			}
		}
	}
	untie @contents;
	close $lock_fh;

	return $output;
}

=begin nd
Function: setHTTPNGFarmServer

	Add a new backend to a HTTP service or modify if it exists

Parameters:
	ids - backend id
	rip - backend ip
	port - backend port
	weight - The weight of this backend (between 1 and 9). Higher weight backends will be used more often than lower weight ones.
	timeout - Override the global time out for this backend
	farmname - Farm name
	service - service name
	priority - The priority of this backend (greater than 1). Lower value indicates higher priority

Returns:
	Integer - return 0 on success or -1 on failure

=cut

sub setHTTPNGFarmServer # ($ids,$rip,$port,$weight,$timeout,$farm_name,$service,$priority,$connlimit)
{
	&zenlog( __FILE__ . q{:} . __LINE__ . q{:} . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );

	my (
		 $ids,       $rip,     $port,     $weight, $timeout,
		 $farm_name, $service, $priority, $connlimit
	) = @_;
	my $farm_filename = &getFarmFile( $farm_name );
	my $output        = -1;

	require Zevenet::Lock;
	my $lock_file = &getLockFile( $farm_name );
	my $lock_fh = &openlock( $lock_file, 'w' );

	require Tie::File;
	tie my @contents, 'Tie::File', "$configdir\/$farm_filename";

	if ( $ids !~ /^$/ )
	{
		my $index_count = -1;
		my $i           = -1;
		my $sw          = 0;
		my $bw          = 0;
		my %data = (
					 'TimeOut', $timeout, 'Priority',  $priority,
					 'Weight',  $weight,  'ConnLimit', $connlimit,
					 'Address', $rip,     'Port',      $port
		);
		my %setted = (
					   'TimeOut',   0, 'Priority', 0, 'Weight', 0,
					   'ConnLimit', 0, 'Address',  0, 'Port',   0
		);
		my $value;
		my $dec_mark;

		my $line;
		for ( $i = 0 ; $i < $#contents ; $i++ )
		{
			$line = $contents[$i];

			#search the service to modify
			if ( $line =~ /Service \"$service\"/ )
			{
				$sw = 1;
				next;
			}
			if ( $line =~ /BackEnd/ and $line !~ /#/ and $sw eq 1 )
			{
				$index_count++;
				if ( $index_count == $ids )
				{
					$output = $?;
					$bw     = 1;
				}
				next;
			}
			if ( $bw == 1 )
			{
				if ( $line =~ /(TimeOut|Priority|Weight|ConnLimit|Address|Port)/ )
				{
					$value = $data{ $1 };
					$setted{ "$1" } = 1;
					if ( $value =~ /^$/ )
					{
						splice @contents, $i, 1,;
						$i--;
						next;
					}
					else
					{
						$contents[$i] = "\t\t\t$1 $value";
						next;
					}
				}
				if ( $line =~ /\s*NfMark\s*(.*)/ )
				{
					$dec_mark = $1;
					next;
				}
				if ( $line =~ /^\s+End/ )
				{
					my @keys = keys %data;
					foreach my $key ( @keys )
					{
						$value = $data{ $key };
						if ( not $setted{ $key } and $value !~ /^$/ )
						{
							splice @contents, $i, 0, "\t\t\t$key $data{\"$key\"}";
							$data{ "$key" } = 1;
						}
					}
					last;
				}
			}
		}
	}
	else
	{
		#add new server
		my $nsflag             = "true";
		my $index              = -1;
		my $backend            = 0;
		my $be_section         = -1;
		my $farm_ref->{ name } = $farm_name;
		$ids = 0;

		foreach my $line ( @contents )
		{
			$index++;
			if ( $be_section == 1 and $line =~ /Address/ )
			{
				$ids++;
				$backend++;
			}
			if ( $line =~ /Service \"$service\"/ and $be_section == -1 )
			{
				$be_section++;
			}
			if ( $line =~ /#BackEnd/ and $be_section == 0 )
			{
				$be_section++;
			}
			if ( $be_section == 1 and $line =~ /#End/ )
			{
				splice @contents, $index, 0, "\t\tBackEnd";
				$output = $?;
				$index++;
				splice @contents, $index, 0, "\t\t\tAddress $rip";
				my $httpsbe = &getHTTPFarmVS( $farm_name, $service, "httpsbackend" );
				if ( $httpsbe eq "true" )
				{
					#add item
					splice @contents, $index, 0, "\t\t\tHTTPS";
					$index++;
				}
				$index++;
				splice @contents, $index, 0, "\t\t\tPort $port";
				$index++;

				#Timeout?
				if ( $timeout )
				{
					splice @contents, $index, 0, "\t\t\tTimeOut $timeout";
					$index++;
				}

				#Priority?
				if ( $priority )
				{
					splice @contents, $index, 0, "\t\t\tPriority $priority";
					$index++;
				}

				#Weight?
				if ( $weight )
				{
					splice @contents, $index, 0, "\t\t\tWeight $weight";
					$index++;
				}

				#ConnLimit?
				if ( $connlimit )
				{
					splice @contents, $index, 0, "\t\t\tConnLimit $connlimit";
					$index++;
				}

				#NfMark
				my $hex_mark = &getNewMark( $farm_name );
				my $dec_mark = sprintf ( "%D", hex ( $hex_mark ) );
				splice @contents, $index, 0, "\t\t\tNfMark $dec_mark";
				if ( &getGlobalConfiguration( 'mark_routing_L7' ) eq 'true' )
				{
					my $fstate = &getFarmStatus( $farm_name );
					$farm_ref->{ vip } = &getFarmVip( 'vip', $farm_name );
					require Zevenet::Farm::Backend;
					&setBackendRule( "add", $farm_ref, $hex_mark ) if ( $fstate eq 'up' );
				}
				$index++;

				splice @contents, $index, 0, "\t\tEnd";
				$be_section++;    # Backend Added
			}

			# if backend added then go out of form
		}
		if ( $nsflag eq "true" )
		{
			my $idservice = &getFarmVSI( $farm_name, $service );
			if ( $idservice ne "" )
			{
				&setHTTPFarmBackendStatusFile( $farm_name, $backend, "active", $idservice );
			}
		}
	}
	untie @contents;
	close $lock_fh;

	return $output;
}

=begin nd
Function: runHTTPFarmServerDelete

	Delete a backend in a HTTP service

Parameters:
	ids - backend id to delete it
	farmname - Farm name
	service - service name where is the backend

Returns:
	Integer - return 0 on success or -1 on failure

=cut

sub runHTTPFarmServerDelete    # ($ids,$farm_name,$service)
{
	&zenlog( __FILE__ . q{:} . __LINE__ . q{:} . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my ( $ids, $farm_name, $service ) = @_;

	my $farm_filename = &getFarmFile( $farm_name );
	my $output        = -1;
	my $i             = -1;
	my $j             = -1;
	my $sw            = 0;
	my $dec_mark;
	my $farm_ref = getFarmStruct( $farm_name );

	require Zevenet::Lock;
	my $lock_file = &getLockFile( $farm_name );
	my $lock_fh = &openlock( $lock_file, 'w' );

	require Tie::File;
	tie my @contents, 'Tie::File', "$configdir\/$farm_filename";
	foreach my $line ( @contents )
	{
		$i++;
		if ( $line =~ /Service \"$service\"/ )
		{
			$sw = 1;
		}
		if ( $line =~ /BackEnd/ and $line !~ /#/ and $sw == 1 )
		{
			$j++;
			if ( $j == $ids )
			{
				splice @contents, $i, 1,;
				$output = $?;
				while ( $contents[$i] !~ /End/ )
				{
					if ( $contents[$i] =~ /\s*NfMark\s*(.*)/ )
					{
						$dec_mark = $1;
						my $mark = sprintf ( "0x%x", $1 );
						&delMarks( "", $mark );
						if ( &getGlobalConfiguration( 'mark_routing_L7' ) eq 'true' )
						{
							require Zevenet::Farm::Backend;
							&setBackendRule( "del", $farm_ref, $mark );
						}
					}
					splice @contents, $i, 1,;
				}
				splice @contents, $i, 1,;
			}
		}
	}
	untie @contents;

	close $lock_fh;

	if ( $proxy_ng eq 'true' )
	{
		require Zevenet::Farm::HTTP::Sessions;
		&deleteConfL7FarmAllSession( $farm_name, $service, $ids );
	}

	if ( $output != -1 )
	{
		&runRemoveHTTPBackendStatus( $farm_name, $ids, $service );
	}

	return $output;
}

=begin nd
Function: setHTTPFarmBackendsMarks

	Set marks in the backends of an HTTP farm

Parameters:
	farmname - Farm name

Returns:
	None

=cut

sub setHTTPFarmBackendsMarks    # ($farm_name)
{
	&zenlog( __FILE__ . q{:} . __LINE__ . q{:} . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );

	my ( $farm_name ) = @_;
	require Zevenet::Farm::Core;
	my $farm_filename = &getFarmFile( $farm_name );

	my $i        = -1;
	my $farm_ref = getFarmStruct( $farm_name );
	my $sw       = 0;
	my $bw       = 0;
	my $ms       = 0;

	require Tie::File;
	tie my @contents, 'Tie::File', "$configdir\/$farm_filename";
	foreach my $line ( @contents )
	{
		$i++;
		if ( $line =~ /^\s+Service\s*\".*\"/ )
		{
			$sw = 1;
		}
		if ( $line =~ /^\s+BackEnd/ and $sw == 1 )
		{
			$bw = 1;
			$ms = 0;
		}
		if ( $line =~ /^\s+NfMark\s*(.*)/ and $bw == 1 )
		{
			$ms = 1;
		}
		if ( $line =~ /^\s+End/ and $bw == 1 )
		{
			$bw = 0;
			if ( $ms == 0 )
			{
				my $hex_mark = &getNewMark( $farm_name );
				my $dec_mark = sprintf ( "%D", hex ( $hex_mark ) );
				splice @contents, $i, 0, "\t\t\tNfMark $dec_mark";
				if ( &getGlobalConfiguration( 'mark_routing_L7' ) eq 'true' )
				{
					my $fstate = &getFarmStatus( $farm_name );
					&setBackendRule( "add", $farm_ref, $hex_mark ) if ( $fstate eq 'up' );
				}
				$ms = 1;
			}
		}
	}
	untie @contents;
	return;
}

=begin nd
Function: removeHTTPFarmBackendsMarks

	Remove marks from the backends of an HTTP farm

Parameters:
	farmname - Farm name

Returns:
	None

=cut

sub removeHTTPFarmBackendsMarks    # ($farm_name)
{
	&zenlog( __FILE__ . q{:} . __LINE__ . q{:} . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );

	require Zevenet::Farm::Core;
	my ( $farm_name ) = @_;
	my $farm_filename = &getFarmFile( $farm_name );

	my $i        = -1;
	my $farm_ref = getFarmStruct( $farm_name );
	my $sw       = 0;
	my $bw       = 0;

	require Tie::File;
	tie my @contents, 'Tie::File', "$configdir\/$farm_filename";
	foreach my $line ( @contents )
	{
		$i++;
		if ( $line =~ /^\tService\s*\".*\"/ )
		{
			$sw = 1;
		}
		if ( $line =~ /^\tEnd/ and $sw == 1 and $bw == 0 )
		{
			$sw = 0;
		}
		if ( $line =~ /^\t\tBackEnd/ and $sw == 1 )
		{
			$bw = 1;
		}
		if ( $line =~ /^\s+NfMark\s*(.*)/ and $bw == 1 )
		{
			my $mark = sprintf ( "0x%x", $1 );
			&delMarks( "", $mark );
			if ( &getGlobalConfiguration( 'mark_routing_L7' ) eq 'true' )
			{
				require Zevenet::Farm::Backend;
				&setBackendRule( "del", $farm_ref, $mark );
			}
			splice @contents, $i, 1,;
		}
		if ( $line =~ /^\t\tEnd/ and $bw == 1 )
		{
			$bw = 0;
		}
	}
	untie @contents;
	return;
}

=begin nd
Function: getHTTPFarmBackendStatusCtl

	Get status of a HTTP farm and its backends, sessions can be not included

Parameters:
	farmname - Farm name
	sessions - "true" show sessions info. "false" sessions are not shown.

Returns:
	array - return the output of proxyctl command for a farm 

=cut

sub getHTTPFarmBackendStatusCtl    # ($farm_name, $sessions)
{
	&zenlog( __FILE__ . q{:} . __LINE__ . q{:} . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my ( $farm_name, $sessions ) = @_;

	require Zevenet::Farm::HTTP::Config;
	my $socket_file = &getHTTPFarmSocket( $farm_name );
	my $proxyctl    = &getGlobalConfiguration( 'proxyctl' );

	my $sessions_option = "-C";
	if ( defined $sessions and $sessions = "true" )
	{
		$sessions_option = "";
	}
	return @{ &logAndGet( "$proxyctl $sessions_option -c $socket_file", "array" ) };
}

=begin nd
Function: getHTTPFarmBackends

	Return a list with all backends in a service and theirs configuration

Parameters:
	farmname - Farm name
	service - Service name
	param_status - "true" or "false" to indicate to get backend status.

Returns:
	array ref - Each element in the array it is a hash ref to a backend.
	the array index is the backend id

=cut

sub getHTTPFarmBackends    # ($farm_name,$service,$param_status)
{
	&zenlog( __FILE__ . q{:} . __LINE__ . q{:} . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my ( $farmname, $service, $param_status ) = @_;

	require Zevenet::Farm::HTTP::Service;

	my $proxy_ng   = &getGlobalConfiguration( 'proxy_ng' );
	my $backendsvs = &getHTTPFarmVS( $farmname, $service, "backends" );
	my @be         = split ( "\n", $backendsvs );
	my @be_status;
	if ( not $param_status or $param_status eq "true" )
	{
		@be_status = @{ &getHTTPFarmBackendsStatus( $farmname, $service ) };
		@be_status = () if ( exists $be_status[0] and ( $be_status[0] eq -1 ) );
	}
	my @out_ba;

	my $backend_ref;
	foreach my $subl ( @be )
	{
		my @subbe = split ( ' ', $subl );
		my $id = $subbe[1] + 0;

		my $ip   = $subbe[3];
		my $port = $subbe[5] + 0;
		my $tout = $subbe[7];
		my $prio = $subbe[9];
		my $weig = $subbe[11];
		my $conn = $subbe[13];
		my $tag  = $subbe[15];

		$tout = $tout eq '-' ? undef : $tout + 0;
		$prio = $prio eq '-' ? undef : $prio + 0;
		$weig = $weig eq '-' ? undef : $weig + 0;
		$conn = $conn eq '-' ? undef : $conn + 0;
		$tag  = $tag eq '-'  ? undef : $tag + 0;

		my $status = "undefined";
		if ( not $param_status or $param_status eq "true" )
		{
			$status = $be_status[$id] if $be_status[$id];
		}

		if ( $proxy_ng eq 'true' )
		{
			$backend_ref = {
							 id               => $id,
							 ip               => $ip,
							 port             => $port + 0,
							 timeout          => $tout,
							 priority         => $prio,
							 weight           => $weig,
							 connection_limit => $conn,
							 tag              => $tag
			};

		}
		elsif ( $proxy_ng )
		{
			$backend_ref = {
							 id      => $id,
							 ip      => $ip,
							 port    => $port + 0,
							 timeout => $tout,
							 weight  => $prio
			};
		}
		if ( not $param_status or $param_status eq "true" )
		{
			$backend_ref->{ status } = $status;
		}
		push @out_ba, $backend_ref;
		$backend_ref = undef;

	}

	return \@out_ba;
}

=begin nd
Function: getHTTPFarmBackendsStatus

	Get the status of all backends in a service. The possible values are:

	- up = The farm is in up status and the backend is OK.
	- down = The farm is in up status and the backend is unreachable
	- maintenace = The backend is in maintenance mode.
	- undefined = The farm is in down status and backend is not in maintenance mode.


Parameters:
	farmname - Farm name
	service - Service name

Returns:
	Array ref - the index is backend index, the value is the backend status.

=cut

#ecm possible bug here returns 2 values instead of 1 (1 backend only)
sub getHTTPFarmBackendsStatus    # ($farm_name,$service)
{
	&zenlog( __FILE__ . q{:} . __LINE__ . q{:} . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my ( $farm_name, $service ) = @_;

	require Zevenet::Farm::Base;

	my @status;
	my $farmStatus = &getFarmStatus( $farm_name );
	my $stats;

	if ( $farmStatus eq "up" )
	{
		require Zevenet::Farm::HTTP::Backend;
		$stats = &getHTTPFarmBackendsStatusInfo( $farm_name );
	}

	require Zevenet::Farm::HTTP::Service;

	my $backendsvs = &getHTTPFarmVS( $farm_name, $service, "backends" );
	my @be = split ( "\n", $backendsvs );
	my $id = 0;

	# @be is used to get size of backend array
	for ( @be )
	{
		my $backendstatus = &getHTTPBackendStatusFromFile( $farm_name, $id, $service );
		if ( $backendstatus ne "maintenance" )
		{
			if ( $farmStatus eq "up" )
			{
				$backendstatus = $stats->{ $service }->{ backends }[$id]->{ status };
			}
			else
			{
				$backendstatus = "undefined";
			}
		}
		push @status, $backendstatus;
		$id = $id + 1;
	}

	return \@status;
}

=begin nd
Function: getHTTPBackendStatusFromFile

	Function that return if a l7 proxy backend is active, down by farmguardian or it's in maintenance mode

Parameters:
	farmname - Farm name
	backend - backend id (index or ip-port)
	service - service name

Returns:
	scalar - return backend status: "maintentance", "fgDOWN", "active" or -1 on failure

=cut

sub getHTTPBackendStatusFromFile    # ($farm_name,$backend,$service)
{
	&zenlog( __FILE__ . q{:} . __LINE__ . q{:} . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my ( $farm_name, $backend, $service ) = @_;

	require Zevenet::Farm::HTTP::Service;
	my $stfile = "$configdir\/$farm_name\_status.cfg";

	# if the status file does not exist the backend is ok
	my $output = "active";
	if ( not -e $stfile )
	{
		return $output;
	}

	my $srvc_index = &getFarmVSI( $farm_name, $service );

	if ( $backend !~ /^(\d+)$/ )
	{
		$backend = &getHTTPFarmBackendIndexById( $farm_name, $service, $backend );
	}

	open my $fd, '<', $stfile;
	while ( my $line = <$fd> )
	{
		#service index
		if ( $line =~ /\ 0\ ${srvc_index}\ ${backend}/ )
		{
			if ( $line =~ /maintenance/ )
			{
				$output = "maintenance";
			}
			elsif ( $line =~ /fgDOWN/ )
			{
				$output = "fgDOWN";
			}
			else
			{
				$output = "active";
			}
		}
	}
	close $fd;
	return $output;
}

=begin nd
Function: setHTTPFarmBackendStatusFile

	Function that save in a file the backend status (maintenance or not)

Parameters:
	farmname - Farm name
	backend - Backend id
	status - backend status to save in the status file
	service_id - Service id

Returns:
	none - .

FIXME:
	Not return anything, do error control

=cut

sub setHTTPFarmBackendStatusFile    # ($farm_name,$backend,$status,$idsv)
{
	&zenlog( __FILE__ . q{:} . __LINE__ . q{:} . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my ( $farm_name, $backend, $status, $idsv ) = @_;

	require Tie::File;

	my $status_file = "$configdir\/$farm_name\_status.cfg";
	my $changed     = "false";
	require Zevenet::Farm::HTTP::Config;
	my $socket_file = &getHTTPFarmSocket( "$farm_name" );

	if ( not -e $status_file )
	{
		if ( $proxy_ng eq "false" )
		{
			open my $fd, '>', "$status_file";
			my $proxyctl = &getGlobalConfiguration( 'proxyctl' );
			my @run = @{ &logAndGet( "$proxyctl -C -c $socket_file", "array" ) };
			my @sw;
			my @bw;

			foreach my $line ( @run )
			{
				if ( $line =~ /\.\ Service\ / )
				{
					@sw = split ( "\ ", $line );
					$sw[0] =~ s/\.//g;
					chomp $sw[0];
				}
				if ( $line =~ /\.\ Backend\ / )
				{
					@bw = split ( "\ ", $line );
					$bw[0] =~ s/\.//g;
					chomp $bw[0];
					if ( $bw[3] ne "active" )
					{
						print $fd "-b 0 $sw[0] $bw[0] fgDOWN\n";
					}
				}
			}
			close $fd;
		}
		elsif ( $proxy_ng eq "true" )
		{
			my $call = {
						 method   => "GET",
						 protocol => "http",
						 host     => "localhost",
						 path     => "/listener/0",
						 socket   => $socket_file,
						 json     => 3,
			};

			require Zevenet::HTTPClient;
			my $run = &runHTTPRequest( $call );
			open my $fd, '>', "$status_file";
			if ( exists $run->{ return }->{ body }->{ services } )
			{
				my @services   = @{ $run->{ return }->{ body }->{ services } };
				my $srvc_index = 0;
				my $bknd_index = 0;
				foreach my $srvc ( @services )
				{
					my @backends = @{ $srvc->{ backends } };
					if ( @backends )
					{
						foreach my $bknd ( @backends )
						{
							if ( $bknd->{ status } ne "active" )
							{
								print $fd "-b 0 $srvc_index $bknd_index fgDOWN\n";
							}
							$bknd_index++;
						}
					}
					$srvc_index++;
				}
			}
			close $fd;
		}
	}

	tie my @filelines, 'Tie::File', "$status_file";
	my $i;

	foreach my $linea ( @filelines )
	{
		if ( $linea =~ /\ 0\ $idsv\ $backend/ )
		{
			if ( $status =~ /maintenance/ or $status =~ /fgDOWN/ )
			{
				$linea   = "-b 0 $idsv $backend $status";
				$changed = "true";
			}
			else
			{
				splice @filelines, $i, 1,;
				$changed = "true";
			}
		}
		$i++;
	}
	untie @filelines;

	if ( $changed eq "false" )
	{
		open my $fd, '>>', "$status_file";

		if ( $status =~ /maintenance/ or $status =~ /fgDOWN/ )
		{
			print $fd "-b 0 $idsv $backend $status\n";
		}
		else
		{
			splice @filelines, $i, 1,;
		}

		close $fd;
	}
	return;

}

=begin nd
Function: setHTTPFarmBackendMaintenance

	Function that enable the maintenance mode for backend

Parameters:
	farmname - Farm name
	backend - Backend id
	mode - Maintenance mode, the options are: drain, the backend continues working with
	  the established connections; or cut, the backend cuts all the established
	  connections
	service - Service name

Returns:
	Integer - return 0 on success or any other value on failure

=cut

sub setHTTPFarmBackendMaintenance    # ($farm_name,$backend,$mode,$service)
{
	&zenlog( __FILE__ . q{:} . __LINE__ . q{:} . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my ( $farm_name, $backend, $mode, $service ) = @_;

	my $output = 0;

	#find the service number
	my $idsv = &getFarmVSI( $farm_name, $service );
	&zenlog(
			"setting Maintenance mode for $farm_name service $service backend $backend",
			"info", "LSLB" );

	if ( &getFarmStatus( $farm_name ) eq 'up' )
	{
		require Zevenet::Farm::HTTP::Config;
		my $socket_file = &getHTTPFarmSocket( $farm_name );
		if ( $proxy_ng eq "false" )
		{
			my $proxyctl         = &getGlobalConfiguration( 'proxyctl' );
			my $proxyctl_command = "$proxyctl -c $socket_file -b 0 $idsv $backend";

			$output = &logAndRun( $proxyctl_command );
		}
		elsif ( $proxy_ng eq "true" )
		{
			my @bknd_data = @{ &getHTTPFarmBackends( $farm_name, $service, "false" ) };
			my $backend_id =
			  $bknd_data[$backend]->{ ip } . "-" . $bknd_data[$backend]->{ port };
			my $socket_params = {
								  farm_name   => $farm_name,
								  service     => $service,
								  backend_id  => $backend_id,
								  socket_file => $socket_file,
								  status      => "disabled"
			};
			require Zevenet::Farm::HTTP::Runtime;
			my $error_ref = &setHTTPFarmBackendStatusSocket( $socket_params );
			if ( $error_ref->{ code } )
			{
				&zenlog(
					"Backend '$backend_id' in service '$service' in Farm '$farm_name' can not be disabled: "
					  . $error_ref->{ desc },
					"warning", "FARMS"
				);
			}
			$output = $error_ref->{ code };
		}
	}

	if ( not $output )
	{
		if ( $mode eq "cut" )
		{
			require Zevenet::Farm::HTTP::Service;
			if ( &getHTTPFarmVS( $farm_name, $service, "sesstype" ) ne "" )
			{
				&setHTTPFarmBackendsSessionsRemove( $farm_name, $service, $backend );
			}
		}
		&setHTTPFarmBackendStatusFile( $farm_name, $backend, "maintenance", $idsv );
	}

	return $output;
}

=begin nd
Function: setHTTPFarmBackendNoMaintenance

	Function that disable the maintenance mode for backend

Parameters:
	farmname - Farm name
	backend - Backend id
	service - Service name

Returns:
	Integer - return 0 on success or any other value on failure

=cut

sub setHTTPFarmBackendNoMaintenance    # ($farm_name,$backend,$service)
{
	&zenlog( __FILE__ . q{:} . __LINE__ . q{:} . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my ( $farm_name, $backend, $service ) = @_;

	my $output = 0;

	#find the service number
	my $idsv = &getFarmVSI( $farm_name, $service );
	&zenlog(
		"setting Disabled maintenance mode for $farm_name service $service backend $backend",
		"info", "LSLB"
	);

	if ( &getFarmStatus( $farm_name ) eq 'up' )
	{
		require Zevenet::Farm::HTTP::Config;
		my $socket_file = &getHTTPFarmSocket( $farm_name );
		if ( $proxy_ng eq "false" )
		{
			my $proxyctl         = &getGlobalConfiguration( 'proxyctl' );
			my $proxyctl_command = "$proxyctl -c $socket_file -B 0 $idsv $backend";

			$output = &logAndRun( $proxyctl_command );
		}
		elsif ( $proxy_ng eq "true" )
		{
			my @bknd_data = @{ &getHTTPFarmBackends( $farm_name, $service, "false" ) };
			my $backend_id =
			  $bknd_data[$backend]->{ ip } . "-" . $bknd_data[$backend]->{ port };
			my $socket_params = {
								  farm_name   => $farm_name,
								  service     => $service,
								  backend_id  => $backend_id,
								  socket_file => $socket_file,
								  status      => "active"
			};
			require Zevenet::Farm::HTTP::Runtime;
			my $error_ref = &setHTTPFarmBackendStatusSocket( $socket_params );
			if ( $error_ref->{ code } )
			{
				&zenlog(
					"Backend '$backend_id' in service '$service' in Farm '$farm_name' can not be enabled: "
					  . $error_ref->{ desc },
					"warning", "FARMS"
				);
			}
			$output = $error_ref->{ code };
		}
	}

	if ( not $output )
	{
		&setHTTPFarmBackendStatusFile( $farm_name, $backend, "active", $idsv );
	}

	return $output;
}

=begin nd
Function: runRemoveHTTPBackendStatus

	Function that removes a backend from the status file

Parameters:
	farmname - Farm name
	backend - Backend id
	service - Service name

Returns:
	none - .

FIXME:
	This function returns nothing, do error control

=cut

sub runRemoveHTTPBackendStatus    # ($farm_name,$backend,$service)
{
	&zenlog( __FILE__ . q{:} . __LINE__ . q{:} . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my ( $farm_name, $backend, $service ) = @_;

	require Tie::File;

	my $i = -1;
	my $serv_index = &getFarmVSI( $farm_name, $service );

	tie my @contents, 'Tie::File', "$configdir\/$farm_name\_status.cfg";

	foreach my $line ( @contents )
	{
		$i++;
		if ( $line =~ /0\ ${serv_index}\ ${backend}/ )
		{
			splice @contents, $i, 1,;
			last;
		}
	}
	untie @contents;

	# decrease backend index in greater backend ids
	tie my @filelines, 'Tie::File', "$configdir\/$farm_name\_status.cfg";

	foreach my $line ( @filelines )
	{
		if ( $line =~ /0\ ${serv_index}\ (\d+) (\w+)/ )
		{
			my $backend_index = $1;
			my $status        = $2;
			if ( $backend_index > $backend )
			{
				$backend_index = $backend_index - 1;
				$line          = "-b 0 $serv_index $backend_index $status";
			}
		}
	}
	untie @filelines;
	return;
}

=begin nd
Function: setHTTPFarmBackendStatus

	For a HTTP farm, it gets each backend status from status file and set it in ly proxy daemon

Parameters:
	farmname - Farm name

Returns:
	none - .

FIXME:
	This function returns nothing, do error control

=cut

sub setHTTPFarmBackendStatus    # ($farm_name)
{
	&zenlog( __FILE__ . q{:} . __LINE__ . q{:} . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $farm_name = shift;

	&zenlog( "Setting backends status in farm $farm_name", "info", "LSLB" );

	my $status_file = "$configdir\/$farm_name\_status.cfg";
	require Zevenet::Farm::HTTP::Config;
	my $socket_file = &getHTTPFarmSocket( $farm_name );
	my $output      = 0;

	unless ( -f $status_file )
	{
		open my $fh, ">", $status_file;
		close $fh;
		return;
	}

	open my $fh, "<", $status_file;
	if ( $proxy_ng eq "false" )
	{
		my $proxyctl = &getGlobalConfiguration( 'proxyctl' );
		while ( my $line_aux = <$fh> )
		{
			my @line = split ( "\ ", $line_aux );
			&logAndRun( "$proxyctl -c $socket_file $line[0] $line[1] $line[2] $line[3]" );
			if ( $? ne 0 )
			{
				$output = $?;
				&zenlog(
						 "Error Setting Backend Status => service $line[2], backend: $line[3]:"
						   . $output,
						 "error",
						 "FARMS"
				);
			}
		}
	}
	elsif ( $proxy_ng eq "true" )
	{
		require Zevenet::Farm::HTTP::Service;
		my @services = &getHTTPFarmServices( $farm_name );
		my $service_prev;
		my @backend_data;
		while ( my $line_aux = <$fh> )
		{
			my @line = split ( "\ ", $line_aux );
			my $service_name = $services[$line[2]];
			if ( $service_name ne $service_prev )
			{
				@backend_data = @{ &getHTTPFarmBackends( $farm_name, $service_name, "false" ) };
			}
			my $backend_id =
			  $backend_data[$line[3]]->{ ip } . "-" . $backend_data[$line[3]]->{ port };
			my $socket_params = {
								  farm_name   => $farm_name,
								  service     => $service_name,
								  backend_id  => $backend_id,
								  socket_file => $socket_file,
								  status      => "disabled"
			};

			require Zevenet::Farm::HTTP::Runtime;
			my $error_ref = &setHTTPFarmBackendStatusSocket( $socket_params );
			if ( $error_ref->{ code } )
			{
				$output = $error_ref->{ code };
				&zenlog(
					"Backend '$backend_id' in service '$service_name' in Farm '$farm_name' can not be disabled: "
					  . $error_ref->{ desc },
					"warning", "FARMS"
				);
			}
			$service_prev = $service_name;
		}
	}
	close $fh;
	return $output;
}

=begin nd
Function: setHTTPFarmBackendsSessionsRemove

	Remove all the active sessions enabled to a backend in a given service
	Used by farmguardian

Parameters:
	farmname - Farm name
	service - Service name
	backend - Backend id

Returns:
	Integer - Error code: It returns 0 on success or another value if it fails deleting some sessions

FIXME:

=cut

sub setHTTPFarmBackendsSessionsRemove    #($farm_name,$service,$backendid)
{
	&zenlog( __FILE__ . q{:} . __LINE__ . q{:} . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my ( $farm_name, $service, $backendid ) = @_;

	require Zevenet::Farm::HTTP::Config;
	my $socket_file = &getHTTPFarmSocket( $farm_name );
	my $err         = 0;
	my $proxy_ng    = &getGlobalConfiguration( 'proxy_ng' );

	&zenlog(
		"Deleting established sessions to a backend $backendid from farm $farm_name in service $service",
		"info", "LSLB"
	);

	if ( $proxy_ng eq "true" )
	{
		require Zevenet::Farm::HTTP::Service;
		my @bknd_data = @{ &getHTTPFarmBackends( $farm_name, $service, "false" ) };
		my $backend_id =
		  $bknd_data[$backendid]->{ ip } . "-" . $bknd_data[$backendid]->{ port };

		my $proxy_request_params = {
									 method   => "DELETE",
									 data     => { "backend-id" => $backend_id },
									 protocol => "http",
									 socket   => $socket_file,
									 host     => "localhost",
									 path     => "/listener/0/service/$service/sessions",
									 json     => 3,
		};

		require Zevenet::HTTPClient;
		my $response = &runHTTPRequest( $proxy_request_params );
		if ( $response->{ code } ne 0 )
		{
			$err = $response->{ code };
			&zenlog(
				"Session for Backend '$backend_id' in service '$service' in Farms '$farm_name' can not be deleted: "
				  . $response->{ desc },
				"error", "FARMS"
			);
		}
	}
	elsif ( $proxy_ng eq "false" )
	{
		my $serviceid;
		$serviceid = &getFarmVSI( $farm_name, $service );
		my $proxyctl = &getGlobalConfiguration( 'proxyctl' );
		my $cmd      = "$proxyctl -c $socket_file -f 0 $serviceid $backendid";
		$err = &logAndRun( $cmd );
	}

	return $err;
}

sub getHTTPFarmBackendAvailableID
{
	&zenlog( __FILE__ . q{:} . __LINE__ . q{:} . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $farmname = shift;
	my $service  = shift;

	require Zevenet::Farm::HTTP::Service;

	# get an ID for the new backend
	my $backendsvs = &getHTTPFarmVS( $farmname, $service, "backends" );
	my @be = split ( "\n", $backendsvs );
	my $id;

	foreach my $subl ( @be )
	{
		my @subbe = split ( ' ', $subl );
		$id = $subbe[1] + 1;
	}

	$id = 0 if $id eq '';

	return $id;
}

=begin nd
Function: getHTTPFarmBackendsStatusInfo

	This function take data from proxy and it gives hash format

Parameters:
	farmname - Farm name

Returns:
	hash ref - hash with backends farm status

		services =>
		[
			"id" => $service_id,				 # it is the index in the backend array too
			"name" => $service_name,
			"backends" =>
			[
				{
					"id" = $backend_id		# it is the index in the backend array too
					"ip" = $backend_ip
					"port" = $backend_port
					"status" = $backend_status
					"service" = $service_name
				}
			]
		]

=cut

sub getHTTPFarmBackendsStatusInfo    # ($farm_name)
{
	&zenlog( __FILE__ . q{:} . __LINE__ . q{:} . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my ( $farm_name ) = @_;

	require Zevenet::Farm::Base;
	require Zevenet::Farm::HTTP::Backend;
	require Zevenet::Validate;
	my $status;
	my $serviceName;
	my $service_re = &getValidFormat( 'service' );

	if ( $proxy_ng eq "false" )

	  # Get l7 proxy info
	  #i.e. of proxyctl:

	  #Requests in queue: 0
	  #0. http Listener 185.76.64.223:80 a
	  #0. Service "HTTP" active (4)
	  #0. Backend 172.16.110.13:80 active (1 0.780 sec) alive (61)
	  #1. Backend 172.16.110.14:80 active (1 0.878 sec) alive (90)
	  #2. Backend 172.16.110.11:80 active (1 0.852 sec) alive (99)
	  #3. Backend 172.16.110.12:80 active (1 0.826 sec) alive (75)
	{
		# Parse l7 proxy info
		my @proxyStatus = &getHTTPFarmBackendStatusCtl( $farm_name );
		foreach my $line ( @proxyStatus )
		{
			# i.e.
			#     0. Service "HTTP" active (10)
			if ( $line =~ /(\d+)\. Service "($service_re)"/ )
			{
				$serviceName = $2;
			}

			# Parse backend connections
			# i.e.
			#      0. Backend 192.168.100.254:80 active (5 0.000 sec) alive (0)
			if ( $line =~
				/(\d+)\. Backend (\d+\.\d+\.\d+\.\d+|[a-fA-F0-9:]+):(\d+) (\w+) .+ (\w+)(?: \((\d+)\))?/
			  )
			{
				my $backendHash = {
									id     => $1 + 0,
									ip     => $2,
									port   => $3 + 0,
									status => $5,
				};

				# Getting real status
				my $backend_disabled = $4;
				if ( $backend_disabled eq "DISABLED" )
				{
					require Zevenet::Farm::HTTP::Backend;

					#Checkstatusfile
					$backendHash->{ "status" } =
					  &getHTTPBackendStatusFromFile( $farm_name, $backendHash->{ id },
													 $serviceName );

					# not show fgDOWN status
					$backendHash->{ "status" } = "down"
					  if ( $backendHash->{ "status" } ne "maintenance" );
				}
				elsif ( $backendHash->{ "status" } eq "alive" )
				{
					$backendHash->{ "status" } = "up";
				}
				elsif ( $backendHash->{ "status" } eq "DEAD" )
				{
					$backendHash->{ "status" } = "down";
				}

				push ( @{ $status->{ $serviceName }->{ backends } }, $backendHash );
			}
		}

		return $status;
	}
	elsif ( $proxy_ng eq "true" )
	{
		require Zevenet::Farm::HTTP::Runtime;
		my $proxyStatus = &getHTTPFarmBackendStatusSocket( $farm_name );

		foreach ( @{ $proxyStatus->{ services } } )
		{
			$serviceName = $_->{ name };

			foreach my $backend ( @{ $_->{ backends } } )
			{
				my $backendHash = {
									id     => $backend->{ id },
									ip     => $backend->{ address },
									port   => $backend->{ port },
									status => $backend->{ status },
				};

				# Getting real status
				if ( $backendHash->{ status } eq "disabled" )
				{
					require Zevenet::Farm::HTTP::Backend;

					#Checkstatusfile
					$backendHash->{ "status" } =
					  &getHTTPBackendStatusFromFile( $farm_name, $backendHash->{ id },
													 $serviceName );

					# not show fgDOWN status
					$backendHash->{ "status" } = "down"
					  if ( $backendHash->{ "status" } ne "maintenance" );
				}
				elsif ( $backendHash->{ "status" } eq "active" )
				{
					$backendHash->{ "status" } = "up";
				}

				push ( @{ $status->{ $serviceName }->{ backends } }, $backendHash );
			}
		}

		return $status;
	}
}

=begin nd
Function: getHTTPFarmBackendIndexById

	Get backend index from config using backend id.

Parameters:
	farm_name - Farm name
	service_name - Service name
	backend_id - Backend id . Format "ipaddr-port"

Returns:
	Integer . -1 if not index found.

=cut

sub getHTTPFarmBackendIndexById    # ($farm_name, $service, $backend_id)
{
	&zenlog( __FILE__ . q{:} . __LINE__ . q{:} . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $farm_name  = shift;
	my $service    = shift;
	my $backend_id = shift;

	my $backend_idx = -1;

	my ( $address, $port ) = split ( '-', $backend_id );

	require Zevenet::Farm::HTTP::Backend;
	my $index = 0;
	foreach
	  my $backend_ref ( @{ &getHTTPFarmBackends( $farm_name, $service, "false" ) } )
	{
		if ( $backend_ref->{ ip } eq $address and $backend_ref->{ port } == $port )
		{
			$backend_idx = $index;
			last;
		}
		else
		{
			$index++;
		}
	}

	return $backend_idx;
}

=begin nd
Function: getHTTPFarmBackendIdByIndex

	Get backend id form config using backend index.

Parameters:
	farm_name - Farm name
	service_name - Service name
	backend_index - Backend index .

Returns:
	String . Format "ipaddr-port". Undef if not index found.

=cut

sub getHTTPFarmBackendIdByIndex    # ($farm_name, $service, $backend_index)
{
	&zenlog( __FILE__ . q{:} . __LINE__ . q{:} . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $farm_name   = shift;
	my $service     = shift;
	my $backend_idx = shift;

	my $backend_id;

	my $backends_ref = &getHTTPFarmBackends( $farm_name, $service, "false" );
	if (     defined @{ $backends_ref }[$backend_idx]->{ ip }
		 and defined @{ $backends_ref }[$backend_idx]->{ port } )
	{
		$backend_id = @{ $backends_ref }[$backend_idx]->{ ip } . "-"
		  . @{ $backends_ref }[$backend_idx]->{ port };
	}

	return $backend_id;
}

1;
