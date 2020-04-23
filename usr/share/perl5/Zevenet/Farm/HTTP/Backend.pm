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
my $proxy_ng  = &getGlobalConfiguration( 'proxy_ng' );

my $eload;
if ( eval { require Zevenet::ELoad; } )
{
	$eload = 1;
}

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

sub setHTTPFarmServer # ($ids,$rip,$port,$weight,$timeout,$farm_name,$service,$priority)
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my ( $ids, $rip, $port, $weight, $timeout, $farm_name, $service, $priority ) =
	  @_;

	if ( $proxy_ng eq 'true' )
	{
		return
		  &setHTTPNGFarmServer( $ids, $rip, $port, $weight, $timeout, $farm_name,
								$service, $priority );
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
			if ( $line =~ /BackEnd/ && $line !~ /#/ && $sw eq 1 )
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
						 && (    $contents[$i + 3] =~ /End/
							  || $contents[$i + 3] =~ /Priority/ )
					  )
					{
						splice @contents, $i + 3, 0, "\t\t\tTimeOut $timeout";
					}
					if (
						    $p_m eq 0
						 && $priority !~ /^$/
						 && (    $contents[$i + 3] =~ /End/
							  || $contents[$i + 4] =~ /End/ )
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
			if ( $be_section == 1 && $line =~ /Address/ )
			{
				$backend++;
			}
			if ( $line =~ /Service \"$service\"/ && $be_section == -1 )
			{
				$be_section++;
			}
			if ( $line =~ /#BackEnd/ && $be_section == 0 )
			{
				$be_section++;
			}
			if ( $be_section == 1 && $line =~ /#End/ )
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

sub setHTTPNGFarmServer # ($ids,$rip,$port,$weight,$timeout,$farm_name,$service,$priority)
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my ( $ids, $rip, $port, $weight, $timeout, $farm_name, $service, $priority ) =
	  @_;
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
			if ( $line =~ /BackEnd/ && $line !~ /#/ && $sw eq 1 )
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
					my $p_t = 0;
					my $p_p = 0;
					my $p_w = 0;
					my $mod = 0;

					if ( $contents[$i + 3] =~ /TimeOut/ )
					{
						if ( $timeout != ~/^$/ )
						{
							$contents[$i + 3] = "\t\t\tTimeOut $timeout";
							$p_t = 1;
						}
						if ( $contents[$i + 4] =~ /Priority/ )
						{
							if ( defined ( $priority ) and ( $priority != ~/^$/ ) )
							{
								$contents[$i + 4] = "\t\t\tPriority $priority";
								$p_p = 1;
							}
							if ( $contents[$i + 5] =~ /Weight/ )
							{
								if ( $weight != ~/^$/ )
								{
									$contents[$i + 5] = "\t\t\tWeight $weight";
									$p_w = 1;
								}
							}
						}
						if ( $contents[$i + 4] =~ /Weight/ )
						{
							if ( $weight != ~/^$/ )
							{
								$contents[$i + 4] = "\t\t\tWeight $weight";
								$p_w = 1;
							}
						}
					}
					if ( $contents[$i + 3] =~ /Priority/ )
					{
						if ( defined ( $priority ) and ( $priority != ~/^$/ ) )
						{
							$contents[$i + 3] = "\t\t\tPriority $priority";
							$p_p = 1;
						}
						if ( $contents[$i + 4] =~ /Weight/ )
						{
							if ( $weight != ~/^$/ )
							{
								$contents[$i + 4] = "\t\t\tWeight $weight";
								$p_w = 1;
							}
						}
					}
					if ( $contents[$i + 3] =~ /Weight/ )
					{
						if ( $weight != ~/^$/ )
						{
							$contents[$i + 3] = "\t\t\tWeight $weight";
							$p_w = 1;
						}
					}

					#delete item
					if ( $timeout =~ /^$/ )
					{
						if ( $contents[$i + 3] =~ /TimeOut/ )
						{
							splice @contents, $i + 3, 1,;
							$mod = 1;
						}
					}
					if ( ( defined ( $priority ) ) and ( $priority =~ /^$/ ) )
					{
						if ( $contents[$i + 3] =~ /Priority/ )
						{
							splice @contents, $i + 3, 1,;
							$mod = 1;
						}
						if ( $contents[$i + 4] =~ /Priority/ )
						{
							splice @contents, $i + 4, 1,;
							$mod = 1;
						}
					}
					if ( $weight =~ /^$/ )
					{
						if ( $contents[$i + 3] =~ /Weight/ )
						{
							splice @contents, $i + 3, 1,;
							$mod = 1;
						}
						if ( $contents[$i + 4] =~ /Weight/ )
						{
							splice @contents, $i + 4, 1,;
							$mod = 1;
						}
						if ( $contents[$i + 5] =~ /Weight/ )
						{
							splice @contents, $i + 5, 1,;
							$mod = 1;
						}
					}

					#new item
					if ( ( $timeout !~ /^$/ ) and ( $p_t == 0 ) )
					{
						if ( $contents[$i + 3] =~ /(Priority|Weight|End)/ )
						{
							splice @contents, $i + 3, 0, "\t\t\tTimeOut $timeout";
							$mod = 1;
						}
					}
					if ( ( $priority !~ /^$/ ) and ( $p_p == 0 ) )
					{
						if ( $contents[$i + 3] =~ /(Weight|End)/ )
						{
							splice @contents, $i + 3, 0, "\t\t\tPriority $priority";
							$mod = 1;
						}
						elsif ( $contents[$i + 3] =~ /TimeOut/ )
						{
							splice @contents, $i + 4, 0, "\t\t\tPriority $priority";
							$mod = 1;
						}
					}
					if ( ( $weight !~ /^$/ ) and ( $p_w == 0 ) )
					{
						if ( $contents[$i + 3] =~ /End/ )
						{
							splice @contents, $i + 3, 0, "\t\t\tWeight $weight";
							$mod = 1;
						}
						else
						{
							if ( $contents[$i + 3] =~ /TimeOut/ )
							{
								if ( $contents[$i + 4] =~ /End/ )
								{
									splice @contents, $i + 4, 0, "\t\t\tWeight $weight";
									$mod = 1;
								}
								elsif ( $contents[$i + 4] =~ /Priority/ )
								{
									splice @contents, $i + 5, 0, "\t\t\tWeight $weight";
									$mod = 1;
								}

							}
							elsif ( $contents[$i + 3] =~ /Priority/ )
							{
								splice @contents, $i + 4, 0, "\t\t\tWeight $weight";
								$mod = 1;
							}
						}
					}
					if ( $mod == 1 or $p_t == 1 or $p_p == 1 or $p_w == 1 )
					{
						&zenlog( "Backend modified", "info", "LSLB" );

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
			if ( $be_section == 1 && $line =~ /Address/ )
			{
				$backend++;
			}
			if ( $line =~ /Service \"$service\"/ && $be_section == -1 )
			{
				$be_section++;
			}
			if ( $line =~ /#BackEnd/ && $be_section == 0 )
			{
				$be_section++;
			}
			if ( $be_section == 1 && $line =~ /#End/ )
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
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my ( $ids, $farm_name, $service ) = @_;

	my $farm_filename = &getFarmFile( $farm_name );
	my $output        = -1;
	my $i             = -1;
	my $j             = -1;
	my $sw            = 0;

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
		if ( $line =~ /BackEnd/ && $line !~ /#/ && $sw == 1 )
		{
			$j++;
			if ( $j == $ids )
			{
				splice @contents, $i, 1,;
				$output = $?;
				while ( $contents[$i] !~ /End/ )
				{
					splice @contents, $i, 1,;
				}
				splice @contents, $i, 1,;
			}
		}
	}
	untie @contents;

	close $lock_fh;

	if ( $output != -1 )
	{
		&runRemoveHTTPBackendStatus( $farm_name, $ids, $service );
	}

	return $output;
}

=begin nd
Function: getHTTPFarmBackendStatusCtl

	Get status of a HTTP farm and its backends

Parameters:
	farmname - Farm name

Returns:
	array - return the output of proxyctl command for a farm

=cut

sub getHTTPFarmBackendStatusCtl    # ($farm_name)
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my ( $farm_name ) = @_;

	my $proxyctl = &getGlobalConfiguration( 'proxyctl' );

	return @{ &logAndGet( "$proxyctl -c /tmp/$farm_name\_proxy.socket", "array" ) };
}

=begin nd
Function: getHTTPFarmBackends

	Return a list with all backends in a service and theirs configuration

Parameters:
	farmname - Farm name
	service - Service name

Returns:
	array ref - Each element in the array it is a hash ref to a backend.
	the array index is the backend id

=cut

sub getHTTPFarmBackends    # ($farm_name,$service)
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my ( $farmname, $service ) = @_;

	require Zevenet::Farm::HTTP::Service;

	my $backendsvs = &getHTTPFarmVS( $farmname, $service, "backends" );
	my @be = split ( "\n", $backendsvs );
	my @be_status = @{ &getHTTPFarmBackendsStatus( $farmname, $service ) };
	my @out_ba;

	foreach my $subl ( @be )
	{
		my @subbe = split ( ' ', $subl );
		my $id = $subbe[1] + 0;

		my $ip   = $subbe[3];
		my $port = $subbe[5] + 0;
		my $tout = $subbe[7];
		my $prio = $subbe[9];
		my $weig = $subbe[11];

		$tout = $tout eq '-' ? undef : $tout + 0;
		$prio = $prio eq '-' ? undef : $prio + 0;
		$weig = $weig eq '-' ? undef : $weig + 0;

		my $status = "undefined";
		$status = $be_status[$id] if $be_status[$id];

		if ( $proxy_ng eq 'true' )
		{
			push @out_ba,
			  {
				id       => $id,
				status   => $status,
				ip       => $ip,
				port     => $port + 0,
				timeout  => $tout,
				priority => $prio,
				weight   => $weig
			  };
		}
		elsif ( $proxy_ng )
		{
			push @out_ba,
			  {
				id      => $id,
				status  => $status,
				ip      => $ip,
				port    => $port + 0,
				timeout => $tout,
				weight  => $prio
			  };

		}
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
	Array ref - the index is backend index, the value is the backend status

=cut

#ecm possible bug here returns 2 values instead of 1 (1 backend only)
sub getHTTPFarmBackendsStatus    # ($farm_name,@content)
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my ( $farm_name, $service ) = @_;

	require Zevenet::Farm::Base;

	my @status;
	my $farmStatus = &getFarmStatus( $farm_name );
	my $stats;

	if ( $farmStatus eq "up" )
	{
		require Zevenet::Farm::HTTP::Stats;
		$stats = &getHTTPFarmBackendsStats( $farm_name );
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
				$backendstatus = $stats->{ backends }[$id]->{ status };
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
	backend - backend id
	service - service name

Returns:
	scalar - return backend status: "maintentance", "fgDOWN", "active" or -1 on failure

=cut

sub getHTTPBackendStatusFromFile    # ($farm_name,$backend,$service)
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my ( $farm_name, $backend, $service ) = @_;

	require Zevenet::Farm::HTTP::Service;

	my $index;
	my $stfile = "$configdir\/$farm_name\_status.cfg";

	# if the status file does not exist the backend is ok
	my $output = "active";
	if ( !-e $stfile )
	{
		return $output;
	}

	$index = &getFarmVSI( $farm_name, $service );
	open my $fd, '<', $stfile;

	while ( my $line = <$fd> )
	{
		#service index
		if ( $line =~ /\ 0\ ${index}\ ${backend}/ )
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
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my ( $farm_name, $backend, $status, $idsv ) = @_;

	require Tie::File;

	my $statusfile = "$configdir\/$farm_name\_status.cfg";
	my $changed    = "false";

	if ( !-e $statusfile )
	{
		open my $fd, '>', "$statusfile";
		my $proxyctl = &getGlobalConfiguration( 'proxyctl' );
		my @run =
		  @{ &logAndGet( "$proxyctl -c /tmp/$farm_name\_proxy.socket", "array" ) };
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
				if ( $bw[3] eq "active" )
				{
					#~ print FW "-B 0 $sw[0] $bw[0] active\n";
				}
				else
				{
					print $fd "-b 0 $sw[0] $bw[0] fgDOWN\n";
				}
			}
		}
		close $fd;
	}

	tie my @filelines, 'Tie::File', "$statusfile";
	my $i;

	foreach my $linea ( @filelines )
	{
		if ( $linea =~ /\ 0\ $idsv\ $backend/ )
		{
			if ( $status =~ /maintenance/ || $status =~ /fgDOWN/ )
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
		open my $fd, '>>', "$statusfile";

		if ( $status =~ /maintenance/ || $status =~ /fgDOWN/ )
		{
			print $fd "-b 0 $idsv $backend $status\n";
		}
		else
		{
			splice @filelines, $i, 1,;
		}

		close $fd;
	}

}

=begin nd
Function: getHTTPFarmBackendsClients

	Function that return number of clients with session in a backend server

Parameters:
	backend - backend id
	content - command output where parsing backend status
	farmname - Farm name

Returns:
	Integer - return number of clients in the backend

=cut

sub getHTTPFarmBackendsClients    # ($idserver,@content,$farm_name)
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my ( $idserver, @content, $farm_name ) = @_;

	if ( !@content )
	{
		@content = &getHTTPFarmBackendStatusCtl( $farm_name );
	}

	my $numclients = 0;

	foreach ( @content )
	{
		if ( $_ =~ / Session .* -> $idserver$/ )
		{
			$numclients++;
		}
	}

	return $numclients;
}

=begin nd
Function: getHTTPFarmBackendsClientsList

	Function that return sessions of clients

Parameters:
	farmname - Farm name
	content - command output where it must be parsed backend status

Returns:
	array - return information about existing sessions. The format for each line is: "service" . "\t" . "session_id" . "\t" . "session_value" . "\t" . "backend_id"

FIXME:
	will be useful change output format to hash format

=cut

sub getHTTPFarmBackendsClientsList    # ($farm_name,@content)
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my ( $farm_name, @content ) = @_;

	my @client_list;
	my $s;

	if ( !@content )
	{
		@content = &getHTTPFarmBackendStatusCtl( $farm_name );
	}

	foreach ( @content )
	{
		my $line;
		if ( $_ =~ /Service/ )
		{
			my @service = split ( "\ ", $_ );
			$s = $service[2];
			$s =~ s/"//g;
		}
		if ( $_ =~ / Session / )
		{
			my @sess = split ( "\ ", $_ );
			my $id = $sess[0];
			$id =~ s/\.//g;
			$line = $s . "\t" . $id . "\t" . $sess[2] . "\t" . $sess[4];
			push ( @client_list, $line );
		}
	}

	return @client_list;
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
	Integer - return 0 on success or -1 on failure

=cut

sub setHTTPFarmBackendMaintenance    # ($farm_name,$backend,$service)
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my ( $farm_name, $backend, $mode, $service ) = @_;

	my $output = 0;

	if ( $mode eq "cut" )
	{
		&setHTTPFarmBackendsSessionsRemove( $farm_name, $service, $backend );
	}

	#find the service number
	my $idsv = &getFarmVSI( $farm_name, $service );

	&zenlog(
			"setting Maintenance mode for $farm_name service $service backend $backend",
			"info", "LSLB" );

	if ( &getFarmStatus( $farm_name ) eq 'up' )
	{
		my $proxyctl = &getGlobalConfiguration( 'proxyctl' );
		my $proxyctl_command =
		  "$proxyctl -c /tmp/$farm_name\_proxy.socket -b 0 $idsv $backend";

		$output = &logAndRun( $proxyctl_command );
	}

	if ( !$output )
	{
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
	Integer - return 0 on success or -1 on failure

=cut

sub setHTTPFarmBackendNoMaintenance    # ($farm_name,$backend,$service)
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
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
		my $proxyctl = &getGlobalConfiguration( 'proxyctl' );
		my $proxyctl_command =
		  "$proxyctl -c /tmp/$farm_name\_proxy.socket -B 0 $idsv $backend";

		$output = &logAndRun( $proxyctl_command );
	}

	# save backend status in status file
	&setHTTPFarmBackendStatusFile( $farm_name, $backend, "active", $idsv );

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
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
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
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $farm_name = shift;

	&zenlog( "Setting backends status in farm $farm_name", "info", "LSLB" );

	my $be_status_filename = "$configdir\/$farm_name\_status.cfg";

	unless ( -f $be_status_filename )
	{
		open my $fh, ">", $be_status_filename;
		close $fh;
	}

	open my $fh, "<", $be_status_filename;

	unless ( $fh )
	{
		my $msg = "Error opening $be_status_filename: $!. Aborting execution.";

		&zenlog( $msg, "error", "LSLB" );
		die $msg;
	}

	my $proxyctl = &getGlobalConfiguration( 'proxyctl' );

	while ( my $line_aux = <$fh> )
	{
		my @line = split ( "\ ", $line_aux );
		&logAndRun(
			"$proxyctl -c /tmp/$farm_name\_proxy.socket $line[0] $line[1] $line[2] $line[3]"
		);
	}
	close $fh;
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
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my ( $farm_name, $service, $backendid ) = @_;

	my @content = &getHTTPFarmBackendStatusCtl( $farm_name );
	my @service;
	my $sw = 0;
	my $serviceid;
	my @sessionid;
	my $sessid;
	my $sessionid2;
	my $proxyctl = &getGlobalConfiguration( 'proxyctl' );
	my $err      = 0;

	&zenlog(
		"Deleting established sessions to a backend $backendid from farm $farm_name in service $service",
		"info", "LSLB"
	);

	foreach ( @content )
	{
		if ( $_ =~ /Service/ && $sw eq 1 )
		{
			$sw = 0;
		}

		if ( $_ =~ /Service\ \"$service\"/ && $sw eq 0 )
		{
			$sw        = 1;
			@service   = split ( /\./, $_ );
			$serviceid = $service[0];
		}

		if ( $_ =~ /Session.*->\ $backendid/ && $sw eq 1 )
		{
			@sessionid  = split ( /Session/, $_ );
			$sessionid2 = $sessionid[1];
			@sessionid  = split ( /\ /, $sessionid2 );
			$sessid     = $sessionid[1];
			$err += &logAndRun(
						 "$proxyctl -c /tmp/$farm_name\_proxy.socket -n 0 $serviceid $sessid" );
		}
	}
	return $err;
}

sub getHTTPFarmBackendAvailableID
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
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

1;

