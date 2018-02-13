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
Function: getDatalinkFarmServers

	List all farm backends and theirs configuration
	
Parameters:
	farmname - Farm name

Returns:
	array - list of backends. Each item has the format: ";index;ip;iface;weight;priority;status"
		
FIXME:
	changes output to hash format
	
=cut

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
		# ;server;45.2.2.3;eth0;1;1;up
		if ( $line ne "" && $line =~ /^\;server\;/ && $first ne "true" )
		{
			$line =~ s/^\;server/$sindex/g;    #, $line;
			chomp ( $line );
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

=begin nd
Function: getDatalinkFarmBackends

	List all farm backends and theirs configuration
	
Parameters:
	farmname - Farm name

Returns:
	array - list of backends. Each item has the format: ";index;ip;iface;weight;priority;status"
	
=cut

sub getDatalinkFarmBackends    # ($farm_name)
{
	my ( $farm_name ) = @_;

	my $farm_filename = &getFarmFile( $farm_name );
	my $first         = "true";
	my $sindex        = 0;
	my @servers;

	require Zevenet::Farm::Base;
	my $farmStatus = &getFarmStatus( $farm_name );

	open FI, "<$configdir/$farm_filename";

	while ( my $line = <FI> )
	{
		chomp ( $line );

		# ;server;45.2.2.3;eth0;1;1;up
		if ( $line ne "" && $line =~ /^\;server\;/ && $first ne "true" )
		{
			my @aux = split ( ';', $line );
			my $status = $aux[6];
			$status = "undefined" if ( $farmStatus eq "down" );

			push @servers,
			  {
				id        => $sindex,
				ip        => $aux[2],
				interface => $aux[3],
				weight    => $aux[4] + 0,
				priority  => $aux[5] + 0,
				status    => $status
			  };
			$sindex = $sindex + 1;
		}
		else
		{
			$first = "false";
		}
	}
	close FI;

	return \@servers;
}

=begin nd
Function: setDatalinkFarmServer

	Set a backend or create it if it doesn't exist
	
Parameters:
	id - Backend id, if this id doesn't exist, it will create a new backend
	ip - Real server ip
	interface - Local interface used to connect to such backend.
	weight - The higher the weight, the more request will go to this backend.
	priority -  The lower the priority, the most preferred is the backend.
	farmname - Farm name

Returns:
	none - .
	
FIXME:
	Not return nothing, do error control
		
=cut

sub setDatalinkFarmServer    # ($ids,$rip,$iface,$weight,$priority,$farm_name)
{
	my ( $ids, $rip, $iface, $weight, $priority, $farm_name ) = @_;

	require Tie::File;

	my $farm_filename = &getFarmFile( $farm_name );
	my $end           = "false";
	my $i             = 0;
	my $l             = 0;

	# default value
	$weight   ||= 1;
	$priority ||= 1;

	tie my @contents, 'Tie::File', "$configdir\/$farm_filename";

	foreach my $line ( @contents )
	{
		if ( $line =~ /^\;server\;/ && $end ne "true" )
		{
			# modify a backend
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

	# create a backend
	if ( $end eq "false" )
	{
		push ( @contents, "\;server\;$rip\;$iface\;$weight\;$priority\;up\n" );
	}

	untie @contents;

	# Apply changes online
	require Zevenet::Farm::Base;
	if ( &getFarmStatus( $farm_name ) eq 'up' )
	{
		require Zevenet::Farm::Action;
		&runFarmStop( $farm_name, "true" );
		&runFarmStart( $farm_name, "true" );
	}

	return;
}

=begin nd
Function: runDatalinkFarmServerDelete

	Delete a backend from a datalink farm
	
Parameters:
	id - Backend id
	farmname - Farm name

Returns:
	Integer - Error code: return 0 on success or -1 on failure
	
=cut

sub runDatalinkFarmServerDelete    # ($ids,$farm_name)
{
	my ( $ids, $farm_name ) = @_;

	require Tie::File;
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
	require Zevenet::Farm::Base;

	if ( &getFarmStatus( $farm_name ) eq 'up' )
	{
		require Zevenet::Farm::Action;
		&runFarmStop( $farm_name, "true" );
		&runFarmStart( $farm_name, "true" );
	}

	return $output;
}

=begin nd
Function: getDatalinkFarmBackendsStatus_old

	Get the backend status from a datalink farm
	
Parameters:
	content - Not used, it is necessary create a function to generate content

Returns:
	array - Each item has the next format: "ip;port;backendstatus;weight;priority;clients"
	
BUG:
	Not used. This function exist but is not contemplated in zapi v3
	Use farmname as parameter
	It is necessary creates backend checks and save backend status
	
=cut

sub getDatalinkFarmBackendsStatus_old    # (@content)
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

=begin nd
Function: setDatalinkFarmBackendStatus

	Change backend status to up or down
	
Parameters:
	farmname - Farm name
	backend - Backend id
	status - Backend status, "up" or "down"

Returns:
	none - .
	
FIXME:
	Not return nothing, do error control	
	
=cut

sub setDatalinkFarmBackendStatus    # ($farm_name,$index,$stat)
{
	my ( $farm_name, $index, $stat ) = @_;

	require Tie::File;
	require Zevenet::Farm::Base;

	my $farm_filename = &getFarmFile( $farm_name );
	my $fileid        = 0;
	my $serverid      = 0;

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
		&runFarmStop( $farm_name, "true" );
		&runFarmStart( $farm_name, "true" );
	}

	return;
}

=begin nd
Function: getDatalinkFarmBackendStatusCtl

	Return from datalink config file, all backends with theirs parameters and status
	
Parameters:
	farmname - Farm name

Returns:
	array - Each item has the next format: ";server;ip;interface;weight;priority;status"
	
=cut

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

1;
