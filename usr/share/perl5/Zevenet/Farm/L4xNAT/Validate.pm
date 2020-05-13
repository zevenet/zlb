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
Function: ismport

	Check if the string is a valid multiport definition

Parameters:
	port - Multiport string

Returns:
	String - "true" if port has a correct format or "false" if port has a wrong format


=cut

sub ismport
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $string = shift;

	my $validport =
	  "((6553[0-5])|(655[0-2][0-9])|(65[0-4][0-9]{2})|(6[0-4][0-9]{3})|([1-5][0-9]{4})|([0-5]{0,5})|([0-9]{1,4}))";

	chomp ( $string );
	if ( $string eq "*" )
	{
		return "true";
	}
	elsif ( $string =~
		/^($validport|$validport\:$validport)(,$validport|$validport\:$validport)*$/ )
	{
		return "true";
	}
	else
	{
		return "false";
	}
}

=begin nd
Function: checkL4Port

	Check if the port is used by some running l4 farm. It expands the port lists if the farm is using multiport

Parameters:
	ip - IP used for the vip of the farm
	port - Port or port expression to look for in other farms
	farmname - name of the farm. This farm will be deleted of the farm list

Returns:
	Integer - 1 if the port is been used or 0 if it is available

=cut

sub checkL4Port
{
	my ( $ip, $port, $farmname ) = @_;
	my $used = 0;

	# get l4 farms
	require Zevenet::Farm::Base;
	my @farm_list = &getFarmListByVip( $ip );
	@farm_list = grep ( !/^$farmname$/, @farm_list ) if defined $farmname;

	# cannot set all ports because almost a port is set
	if ( $port eq '*' and @farm_list )
	{
		&zenlog(
			"cannot be set all ports because there are more farms using ports in this interface",
			"error", "net"
		);
		return 1;
	}

	# check intervals
	my @port_list = split ( ',', $port );

	foreach my $farm ( @farm_list )
	{
		next if ( &getFarmType( $farm ) ne 'l4xnat' );
		next if ( &getFarmStatus( $farm ) ne 'up' );

		my $f_port = &getFarmVip( 'vipp', $farm );

		# check multiport
		if ( $f_port eq '*' )
		{
			&zenlog( "All ports are used by the farm '$farm'", "error", "net" );
			return 1;
		}

		my @f_port_list = split ( ',', $f_port );

		# there is a port list
		foreach my $p ( @port_list )
		{
			for ( @f_port_list )
			{
				return 1 if &checkPortMultiport( $p, $f_port );
			}
		}
	}

	return $used;
}

=begin nd
Function: checkPortMultiport

	Check if a collision exists between two port intervals.

Parameters:
	port interval 1 - It is a port interval. A port number can be sent to
	port interval 2 - It is a port interval. A port number can be sent to

Returns:
	Integer - 1 if both interval collision or 0 if they do not.

=cut

sub checkPortMultiport
{
	my $port  = shift;
	my $port2 = shift;
	my $used  = 0;

	if ( $port2 =~ /:/ )
	{
		if ( $port =~ /:/ )
		{
			my ( $min, $max ) = split ( ':', $port );
			$used = &checkPortIntervals( $min, $port2 );
			$used += &checkPortIntervals( $max, $port2 );
		}
		else
		{
			$used = &checkPortIntervals( $port, $port2 );
		}
	}
	elsif ( $port =~ /:/ )
	{
		$used = &checkPortIntervals( $port2, $port );
	}
	elsif ( $port == $port2 )
	{
		&zenlog( "The port '$port' collided with the port '$port2'", "error", 'net' );
		$used = 1;
	}

	return $used;
}

=begin nd
Function: checkPortIntervals

	Check if a port number is inside of a port interval. Is it the port 80 in the interval 40:1000?

Parameters:
	port - Port number, it only can be a integer value
	interval - It is an interval for checking if the port is inside. The interval has the format '5000:52220'

Returns:
	Integer - 1 if the port is in the interval or 0 if the port is not of the interval

=cut

sub checkPortIntervals
{
	my $port     = shift;
	my $interval = shift;

	my ( $min, $max ) = split ( ':', $interval );
	if ( $port >= $min and $port <= $max )
	{
		&zenlog( "The port '$port' collided in the interval '$interval'",
				 "error", "net" );
		return 1;
	}

	return 0;
}

1;

