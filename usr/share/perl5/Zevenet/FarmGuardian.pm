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

my $configdir = &getGlobalConfiguration('configdir');

=begin nd
Function: getFarmGuardianFile

	Returns FarmGuardian config file for this farm

Parameters:
	fname - Farm name.
	svice - Service name. Only apply if the farm profile has services. Leave undefined for farms without services.

Returns:
	scalar - Returns the farm-service farmguardian filename or -1 if it wasn't found.

Bugs:
	Returns first filename matching a regex with .*

See Also:
	<setNewFarmName>, <getFarmGuardianStatus>, <getFarmGuardianLog>, <runFarmGuardianStart>, <runFarmGuardianCreate>, <getFarmGuardianConf>
=cut
sub getFarmGuardianFile    # ($fname,$svice)
{
	my ( $fname, $svice ) = @_;

	my $output = -1;

	opendir ( my $dir, "$configdir" );

	if ( $dir )
	{
		my @files =
		  grep { /^$fname\_${svice}.*guardian\.conf/ && -f "$configdir/$_" }
		  readdir ( $dir );
		closedir $dir;

		if ( scalar @files )
		{
			$output = $files[0];
		}
	}

	return $output;
}

=begin nd
Function: getFarmGuardianStatus

	Returns if FarmGuardian is activated for this farm

Parameters:
	fname - Farm name.
	svice - Service name. Only apply if the farm profile has services. Leave undefined for farms without services.

Returns:
	-1 - If farmguardian file was not found.
	 0 - If farmguardian is disabled.
	 1 - If farmguardian is enabled.

Bugs:

See Also:
	zcluster-manager, zevenet, <setNewFarmName>
=cut
sub getFarmGuardianStatus    # ($fname,$svice)
{
	my ( $fname, $svice ) = @_;

	my $fgfile = &getFarmGuardianFile( $fname, $svice );
	my $output = -1;

	if ( $fgfile == -1 )
	{
		return $output;
	}

	open FR, "$configdir/$fgfile";
	my $line;
	my $lastline;
	while ( $line = <FR> )
	{
		$lastline = $line;
	}

	my @line_s = split ( "\:\:\:", $lastline );
	my $value = $line_s[3];
	close FR;

	if   ( $value =~ /true/ ) { $output = 1; }
	else                      { $output = 0; }

	return $output;
}

=begin nd
Function: getFarmGuardianLog

	Returns if FarmGuardian has logs activated for this farm

Parameters:
	fname - Farm name.
	svice - Service name. Only apply if the farm profile has services. Leave undefined for farms without services.

Returns:
	-1 - If farmguardian file was not found.
	 0 - If farmguardian log is disabled.
	 1 - If farmguardian log is enabled.

Bugs:

See Also:
	<runFarmGuardianStart>
=cut
sub getFarmGuardianLog    # ($fname,$svice)
{
	my ( $fname, $svice ) = @_;

	my $fgfile = &getFarmGuardianFile( $fname, $svice );

	if ( $fgfile == -1 )
	{
		return -1;
	}

	open FR, "$configdir/$fgfile";
	my $line;
	my $lastline;
	while ( $line = <FR> )
	{
		$lastline = $line;
	}

	my @line_s = split ( "\:\:\:", $lastline );
	my $value = $line_s[4];
	close FR;

	if ( $value =~ /true/ )
	{
		return 1;
	}
	else
	{
		return 0;
	}
}

=begin nd
Function: runFarmGuardianStart

	Start FarmGuardian rutine

Parameters:
	fname - Farm name.
	svice - Service name. Only apply if the farm profile has services. Leave undefined for farms without services.

Returns:
	-1       - If farmguardian file was not found or if farmguardian is not running.
	 0       - If farm profile is not supported by farmguardian, or farmguardian was executed.

Bugs:
	Returning $? after running a command in the background & gives the illusion of capturing the ERRNO of the ran program. That is not possible since the program may not have finished.

See Also:
	zcluster-manager, zevenet, <runFarmStart>, <setNewFarmName>, zapi/v3/farm_guardian.cgi, zapi/v2/farm_guardian.cgi
=cut
sub runFarmGuardianStart    # ($fname,$svice)
{
	my ( $fname, $svice ) = @_;

	my $status = 0;
	my $log;
	my $sv;
	my $ftype  = &getFarmType( $fname );
	my $fgfile = &getFarmGuardianFile( $fname, $svice );
	my $fgpid  = &getFarmGuardianPid( $fname, $svice );

	if ( $fgpid != -1 )
	{
		my $fg_running = kill 0, $fgpid;

		if ( $fg_running )
		{
			return -1;
		}
		else
		{
			my $piddir = &getGlobalConfiguration( 'piddir' );
			my $sv = ( length ${ svice } ) ? "${svice}_" : "";
			unlink "$piddir/${fname}_${svice}guardian.pid";
		}
	}

	if ( $fgfile == -1 )
	{
		return -1;
	}

	if ( &getFarmGuardianLog( $fname, $svice ) )
	{
		$log = "-l";
	}

	if ( $svice ne "" )
	{
		$sv = "-s '$svice'";
	}

	if ( $ftype =~ /http/ && $svice eq "" )
	{
		require Zevenet::Farm::Config;

		# Iterate over every farm service
		my $services = &getFarmVS( $fname, "", "" );
		my @servs = split ( " ", $services );

		foreach my $service ( @servs )
		{
			my $stat = &runFarmGuardianStart( $fname, $service );
			$status = $status + $stat;
		}
	}
	elsif ( $ftype eq 'l4xnat' || $ftype =~ /http/ )
	{
		my $farmguardian = &getGlobalConfiguration('farmguardian');
		my $fg_cmd = "$farmguardian $fname $sv $log";
		&zenlog( "running $fg_cmd" );

		require Zevenet::System;
		&zsystem( "$fg_cmd > /dev/null &" );
		$status = $?;
	}
	else
	{
		# WARNING: farm types not supported by farmguardian return 0.
		$status = 0;
	}

	return $status;
}

=begin nd
Function: runFarmGuardianStop

	Stop FarmGuardian rutine

Parameters:
	fname - Farm name.
	svice - Service name. Only apply if the farm profile has services. Leave undefined for farms without services.

Returns:
	Integer - 0 on success, or greater than 0 on failure.

See Also:
	zevenet, <runFarmStop>, <setNewFarmName>, zapi/v3/farm_guardian.cgi, <runFarmGuardianRemove>
=cut
sub runFarmGuardianStop    # ($fname,$svice)
{
	my ( $fname, $svice ) = @_;

	my $status = 0;
	my $sv;
	my $type = &getFarmType( $fname );
	my $fgpid = &getFarmGuardianPid( $fname, $svice );

	if ( $type =~ /http/ && $svice eq "" )
	{
		require Zevenet::Farm::Config;

		# Iterate over every farm service
		my $services = &getFarmVS( $fname, "", "" );
		my @servs = split ( " ", $services );

		foreach my $service ( @servs )
		{
			my $stat = &runFarmGuardianStop( $fname, $service );
			$status |= $stat;
		}
	}
	else
	{
		if ( $svice ne "" )
		{
			$sv = "${svice}_";
		}

		if ( $fgpid != -1 )
		{
			&zenlog( "running 'kill 9, $fgpid' stopping FarmGuardian $fname $svice" );
			my $count = kill 9, $fgpid;
			$status = 1 unless $count;
			unlink glob ( "/var/run/$fname\_${sv}guardian.pid" );
		}
	}

	return $status;
}

=begin nd
Function: runFarmGuardianCreate

	Create or update farmguardian config file

	ttcheck and script must be defined and non-empty to enable farmguardian.

Parameters:
	fname - Farm name.
	ttcheck - Time between command executions for all the backends.
	script - Command to run.
	usefg - 'true' to enable farmguardian, or 'false' to disable it.
	fglog - 'true' to enable farmguardian verbosity in logs, or 'false' to disable it.
	svice - Service name.

Returns:
	-1 - If ttcheck or script is not defined or empty and farmguardian is enabled.
	 0 - If farmguardian configuration was created.

Bugs:
	The function 'print' does not write the variable $?.

See Also:
	zapi/v3/farm_guardian.cgi, zapi/v2/farm_guardian.cgi
=cut
sub runFarmGuardianCreate    # ($fname,$ttcheck,$script,$usefg,$fglog,$svice)
{
	my ( $fname, $ttcheck, $script, $usefg, $fglog, $svice ) = @_;

	&zenlog( "runFarmGuardianCreate( farm: $fname, interval: $ttcheck, cmd: $script, log: $fglog, enabled: $usefg )" );

	my $fgfile = &getFarmGuardianFile( $fname, $svice );
	my $output = -1;

	if ( $fgfile == -1 )
	{
		if ( $svice ne "" )
		{
			$svice = "${svice}_";
		}

		$fgfile = "${fname}_${svice}guardian.conf";
		&zenlog(
			  "running 'Create FarmGuardian $ttcheck $script $usefg $fglog' for $fname farm"
		);
	}

	if ( ( $ttcheck eq "" || $script eq "" ) && $usefg eq "true" )
	{
		return $output;
	}

	open my $fh, '>', "$configdir/$fgfile";
	print $fh "$fname\:\:\:$ttcheck\:\:\:$script\:\:\:$usefg\:\:\:$fglog\n";
	close $fh;

	$output = 0;

	return $output;
}

=begin nd
Function: runFarmGuardianRemove

	Remove farmguardian down status on backends.

	When farmguardian is stopped or disabled any backend marked as down by farmgardian must reset it's status.

Parameters:
	fname - Farm name.
	svice - Service name. Only apply if the farm profile has services. Leave undefined for farms without services.

Returns:
	none - Nothing is returned explicitly.

Bugs:

See Also:
	zapi/v3/farm_guardian.cgi, zapi/v2/farm_guardian.cgi, <deleteFarmService>
=cut
sub runFarmGuardianRemove    # ($fname,$svice)
{
	my ( $fname, $svice ) = @_;

	my $type = &getFarmType( $fname );
	my $status = 0;
	
	if ( $type =~ /http/ && $svice eq "" )
	{
		# Iterate over every farm service
		my $services = &getFarmVS( $fname, "", "" );
		my @servs = split ( " ", $services );

		foreach my $service ( @servs )
		{
			my $stat = &runFarmGuardianStop( $fname, $service );
			$status |= $stat;
		}
	}
	
	else
	{
		if ( $type eq "http" || $type eq "https" )
		{
			if ( -e "$configdir\/$fname\_status.cfg" )
			{
				require Zevenet::Farm::HTTP::Config;
				my $portadmin = &getHTTPFarmSocket( $fname );
				my $idsv      = &getFarmVSI( $fname, $svice );

				require Tie::File;
				tie my @filelines, 'Tie::File', "$configdir\/$fname\_status.cfg";
				
				my @fileAux = @filelines;
				my $lines     = scalar @fileAux;
				
				while ( $lines >= 0 )
				{
					$lines--;
					my $line = $fileAux[ $lines ];
					if ( $fileAux[ $lines ] =~ /0 $idsv (\d+) fgDOWN/ )
					{
						my $index = $1;
						my $auxlin = splice ( @fileAux, $lines, 1, );
						my $poundctl = &getGlobalConfiguration('poundctl');
						system ( "$poundctl -c $portadmin -B 0 $idsv $index >/dev/null 2>&1" );
					}
				}
				@filelines = @fileAux;
				untie @filelines;
			}
		}
		
		if ( $type eq "l4xnat" )
		{
			require Zevenet::Farm::Backend;

			my @be = &getFarmBackendStatusCtl( $fname );
			my $i  = -1;
		
			foreach my $line ( @be )
			{
				my @subbe = split ( ";", $line );
				$i++;
				my $backendid     = $i;
				my $backendserv   = $subbe[2];
				my $backendport   = $subbe[3];
				my $backendstatus = $subbe[7];
				chomp $backendstatus;
		
				if ( $backendstatus eq "fgDOWN" )
				{
					$status |= &setL4FarmBackendStatus( $fname, $i, "up" );
				}
			}
		}
	}
}

=begin nd
Function: getFarmGuardianConf

	Get farmguardian configuration for a farm-service.

Parameters:
	fname - Farm name.
	svice - Service name. Only apply if the farm profile has services. Leave undefined for farms without services.

Returns:
	list - List with (fname, ttcheck, script, usefg, fglog).

Bugs:
	There is no control if the file could not be opened, for example, if it does not exist.

See Also:
	L4xNAT: <setL4FarmSessionType>, <setL4FarmAlgorithm>, <setFarmProto>, <setFarmNatType>, <setL4FarmMaxClientTime>, <setL4FarmVirtualConf>, <setL4FarmServer>, <runL4FarmServerDelete>, <setL4FarmBackendStatus>, <setL4NewFarmName>, <_runL4ServerStart>, <_runL4ServerStop>

	zapi/v3/get_l4.cgi, zapi/v3/farm_guardian.cgi,

	zapi/v2/get_l4.cgi, zapi/v2/farm_guardian.cgi, zapi/v2/get_http.cgi, zapi/v2/get_tcp.cgi

	<getHttpFarmService>, <getHTTPServiceStruct>
=cut
sub getFarmGuardianConf    # ($fname,$svice)
{
	my ( $fname, $svice ) = @_;
	my $lastline;

	# get filename
	my $fgfile = &getFarmGuardianFile( $fname, $svice );

	if ( $fgfile == -1 )
	{
		if ( $svice ne "" )
		{
			$svice = "${svice}_";
		}
		$fgfile = "${fname}_${svice}guardian.conf";
	}

	# read file
	open my $fh, "$configdir/$fgfile";
	my $line;
	while ( $line = <$fh> )
	{
		if ( $line !~ /^#/ )
		{
			$lastline = $line;
			last;
		}
	}
	close $fh;

	my @line = split ( ":::", $lastline );
	chomp ( @line );
	$line[4]="false" if ( ! $line[4] );

	#&zenlog("getting 'FarmGuardianConf @line' for $fname farm");
	return @line;
}

=begin nd
Function: getFarmGuardianPid

	Get farmguardian PID for a running farm-service.

Parameters:
	fname - Farm name.
	svice - Service name. Only apply if the farm profile has services. Leave undefined for farms without services.

Returns:
	-1      - If farmguardian PID file was not found (farmguardian not running).
	integer - PID number (unsigned integer) if farmguardian is running.

Bugs:
	Regex with .* should be fixed.

See Also:
	zevenet

	L4xNAT: <setL4FarmSessionType>, <setL4FarmAlgorithm>, <setFarmProto>, <setFarmNatType>, <setL4FarmMaxClientTime>, <setL4FarmVirtualConf>, <setL4FarmServer>, <runL4FarmServerDelete>, <setL4FarmBackendStatus>, <setL4NewFarmName>, <_runL4ServerStart>, <_runL4ServerStop>
=cut
sub getFarmGuardianPid    # ($fname,$svice)
{
	my ( $fname, $svice ) = @_;

	my $pidfile = "";
	my $piddir = &getGlobalConfiguration('piddir');

	opendir ( my $dir, "$piddir" ) || return -1;
	my @files =
	  grep { /^$fname\_$svice.*guardian\.pid/ && -f "$piddir/$_" } readdir ( $dir );
	closedir $dir;

	if ( @files )
	{
		$pidfile = $files[0];

		open my $fh, '<', "$piddir/$pidfile";
		my $fgpid = <$fh>;
		close $fh;

		return $fgpid;
	}
	else
	{
		return -1;
	}
}

1;
