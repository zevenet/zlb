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

my $eload;
if ( eval { require Zevenet::ELoad; } )
{
	$eload = 1;
}

my $configdir = &getGlobalConfiguration( 'configdir' );

=begin nd
Function: getDatalinkFarmBackends

	List all farm backends and theirs configuration

Parameters:
	farmname - Farm name

Returns:
	scalar - backends list array reference with hashes of backends objects

=cut

sub getDatalinkFarmBackends    # ($farm_name)
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my ( $farm_name ) = @_;

	my $farm_filename = &getFarmFile( $farm_name );
	my $first         = "true";
	my $sindex        = 0;
	my @servers;

	require Zevenet::Farm::Base;
	my $farmStatus = &getFarmStatus( $farm_name );

	my $permission = 0;
	my $alias;

	open my $fd, '<', "$configdir/$farm_filename";

	while ( my $line = <$fd> )
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
	close $fd;

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
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
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
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
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

sub getDatalinkFarmBackendAvailableID
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $farmname = shift;

	my $id       = 0;
	my $backends = &getDatalinkFarmBackends( $farmname );

	foreach my $l_serv ( @{ $backends } )
	{
		if ( $l_serv->{ id } > $id && $l_serv->{ ip } ne "0.0.0.0" )
		{
			$id = $l_serv->{ id };
		}
	}

	$id++ if @{ $backends };

	return $id;
}

1;
