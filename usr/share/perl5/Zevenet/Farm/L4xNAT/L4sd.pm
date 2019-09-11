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

=begin nd
Function: runL4sdDaemon

	Launch the l4sd daemon if it's not already launched

Parameters:
	none

Returns:
	Integer - Error code: 0 on success or other value on failure
=cut

sub runL4sdDaemon
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );

	my $l4sdbin = &getGlobalConfiguration( 'l4sd' );
	my $pidfile = &getGlobalConfiguration( 'l4sdpid' );

	if ( !-f "$pidfile" )
	{
		return &logAndRunBG( $l4sdbin );
	}

	return -1;
}

=begin nd
Function: sendL4sdSignal

	Send a USR1 signal to L4sd

Parameters:
	none

Returns:
	Integer - Error code: 0 on success or other value on failure
=cut

sub sendL4sdSignal
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );

	my $output  = -1;
	my $pidfile = &getGlobalConfiguration( 'l4sdpid' );

	&runL4sdDaemon();

	# read pid number
	open my $file, "<", "$pidfile" or return -1;
	my $pid = <$file>;
	close $file;

	kill USR1 => $pid;
	$output = $?;

	return $output;
}

=begin nd
Function: getL4sdType

	Obtain if a given farm has l4sd and its type

Parameters:
	farm_name - Name of the farm to search for l4sd configuration

Returns:
	String - Returns a string with the type of dynamic scheduler, empty if none.
=cut

sub getL4sdType
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );

	my $farm_name = shift;
	my $output    = "";
	my $l4sdfile  = &getGlobalConfiguration( 'l4sdcfg' );

	if ( !-f "$l4sdfile" )
	{
		return $output;
	}

	require Config::Tiny;
	my $config = Config::Tiny->read( $l4sdfile );
	if ( defined $config->{ $farm_name } && exists $config->{ $farm_name } )
	{
		$output = $config->{ $farm_name }->{ type };
	}

	return $output;
}

=begin nd
Function: setL4sdType

	Obtain if a given farm has l4sd and its type

Parameters:
	farm_name - Name of the farm to search for l4sd configuration
	type - Type of dynamic scheduler (ex: leastconn, none )

Returns:
	String - Returns a string with the type of dynamic scheduler, empty if none.
=cut

sub setL4sdType
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );

	my $farm_name = shift;
	my $type      = shift;
	my $l4sdfile  = &getGlobalConfiguration( 'l4sdcfg' );
	my $l4sdbin   = &getGlobalConfiguration( 'l4sd' );
	my $pidfile   = &getGlobalConfiguration( 'l4sdpid' );

	if ( !-f "$l4sdfile" )
	{
		open my $fd, '>', $l4sdfile;
		if ( !$fd )
		{
			&zenlog( "Could not create file $l4sdfile: $!", "error", "L4SD" );
			return -1;
		}
		close $fd;
	}

	require Config::Tiny;
	my $config = Config::Tiny->read( $l4sdfile );

	if ( $type eq "none" )
	{
		delete $config->{ $farm_name };
	}
	elsif ( $type eq "leastconn" )
	{
		$config->{ $farm_name }->{ type } = $type;
	}
	$config->write( $l4sdfile );

	&sendL4sdSignal();

	return 0;
}

1;
