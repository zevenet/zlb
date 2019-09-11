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
Function: getDatalinkFarmAlgorithm

	Get type of balancing algorithm.

Parameters:
	farmname - Farm name

Returns:
	scalar - The possible values are "weight", "priority" or -1 on failure

=cut

sub getDatalinkFarmAlgorithm    # ($farm_name)
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my ( $farm_name ) = @_;

	my $farm_filename = &getFarmFile( $farm_name );
	my $algorithm     = -1;
	my $first         = "true";

	open my $fd, '<', "$configdir/$farm_filename";

	while ( my $line = <$fd> )
	{
		if ( $line ne "" && $first eq "true" )
		{
			$first = "false";
			my @line = split ( "\;", $line );
			$algorithm = $line[3];
		}
	}
	close $fd;

	return $algorithm;
}

=begin nd
Function: setDatalinkFarmAlgorithm

	Set the load balancing algorithm to a farm

Parameters:
	algorithm - Type of balancing mode: "weight" or "priority"
	farmname - Farm name

Returns:
	none - .

FIXME:
	set a return value, and do error control

=cut

sub setDatalinkFarmAlgorithm    # ($algorithm,$farm_name)
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my ( $algorithm, $farm_name ) = @_;

	require Tie::File;

	my $farm_filename = &getFarmFile( $farm_name );
	my $i             = 0;

	tie my @configfile, 'Tie::File', "$configdir\/$farm_filename";

	for my $line ( @configfile )
	{
		if ( $line =~ /^$farm_name\;/ )
		{
			my @args = split ( "\;", $line );
			$line = "$args[0]\;$args[1]\;$args[2]\;$algorithm\;$args[4]";
			splice @configfile, $i, $line;
		}
		$i++;
	}
	untie @configfile;

	# Apply changes online
	if ( &getFarmStatus( $farm_name ) eq 'up' )
	{
		require Zevenet::Farm::Action;
		&runFarmStop( $farm_name, "true" );
		&runFarmStart( $farm_name, "true" );
	}

	return;
}

=begin nd
Function: getDatalinkFarmBootStatus

	Return the farm status at boot zevenet

Parameters:
	farmname - Farm name

Returns:
	scalar - return "down" if the farm not run at boot or "up" if the farm run at boot

=cut

sub getDatalinkFarmBootStatus    # ($farm_name)
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my ( $farm_name ) = @_;

	my $farm_filename = &getFarmFile( $farm_name );
	my $output        = "down";
	my $first         = "true";

	open my $fd, '<', "$configdir/$farm_filename";

	while ( my $line = <$fd> )
	{
		if ( $line ne "" && $first eq "true" )
		{
			$first = "false";
			my @line_a = split ( /;/, $line );
			$output = $line_a[4];
			chomp ( $output );
		}
	}
	close $fd;

	return $output;
}

=begin nd
Function: setDatalinkFarmBootStatus

	Write farm boot status

Parameters:
	farmname - Farm name
	value -	"up" or "down"

=cut

sub setDatalinkFarmBootStatus    # ($farm_name, $value)
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my ( $farm_name, $value ) = @_;
	my $output = -1;

	require Tie::File;

	my $farm_filename = &getFarmFile( $farm_name );
	my $i             = 0;

	tie my @configfile, 'Tie::File', "$configdir\/$farm_filename";

	for my $line ( @configfile )
	{
		if ( $line =~ /^$farm_name\;/ )
		{
			my @args = split ( "\;", $line );
			$line = "$args[0]\;$args[1]\;$args[2]\;$args[3]\;$value";
			splice @configfile, $i, $line;
			$output = 0;
			last;
		}
		$i++;
	}
	untie @configfile;
	return $output;
}

=begin nd
Function: getDatalinkFarmStatus

	Return the farm current status

Parameters:
	farmname - Farm name

Returns:
	string - return "up" if the farm is running or "down" if the farm is not running

=cut

sub getDatalinkFarmStatus    # ($farm_name)
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my ( $farm_name ) = @_;
	my $output;

	my $piddir = &getGlobalConfiguration( 'piddir' );
	my $output = "down";

	$output = "up" if ( -e "$piddir\/$farm_name\_datalink.pid" );

	return $output;
}

=begin nd
Function: getDatalinkFarmInterface

	 Get network physical interface used by the farm vip

Parameters:
	farmname - Farm name

Returns:
	scalar - return NIC interface or -1 on failure

=cut

sub getDatalinkFarmInterface    # ($farm_name)
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my ( $farm_name ) = @_;

	my $output = -1;

	my $line;
	my $first         = "true";
	my $farm_filename = &getFarmFile( $farm_name );

	open my $fd, '<', "$configdir/$farm_filename";

	while ( $line = <$fd> )
	{
		if ( $line ne "" && $first eq "true" )
		{
			$first = "false";
			my @line_a = split ( "\;", $line );
			my @line_b = split ( "\:", $line_a[2] );
			$output = $line_b[0];
		}
	}

	close $fd;

	return $output;
}

=begin nd
Function: getDatalinkFarmVip

	Returns farm vip, vport or vip:vport

Parameters:
	info - parameter to return: vip, for virtual ip; vipp, for virtual port
	farmname - Farm name

Returns:
	Scalar - return request parameter on success or -1 on failure

=cut

sub getDatalinkFarmVip    # ($info,$farm_name)
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my ( $info, $farm_name ) = @_;

	my $farm_filename = &getFarmFile( $farm_name );
	my $output        = -1;
	my $first         = "true";

	open my $fd, '<', "$configdir/$farm_filename";

	while ( my $line = <$fd> )
	{
		if ( $line ne "" && $first eq "true" )
		{
			$first = "false";
			my @line_a = split ( "\;", $line );

			if ( $info eq "vip" )  { $output = $line_a[1]; }
			if ( $info eq "vipp" ) { $output = $line_a[2]; }
		}
	}
	close $fd;

	return $output;
}

=begin nd
Function: setDatalinkFarmVirtualConf

	Set farm virtual IP and virtual PORT

Parameters:
	vip - virtual ip
	interface - interface
	farmname - Farm name

Returns:
	Scalar - Error code: 0 on success or -1 on failure

=cut

sub setDatalinkFarmVirtualConf    # ($vip,$interface,$farm_name)
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my ( $vip, $interface, $farm_name ) = @_;

	require Tie::File;
	require Zevenet::Farm::Action;

	# set the interface that has defined the vip
	require Zevenet::Net::Interface;
	foreach my $if_ref ( @{ &getConfigInterfaceList() } )
	{
		if ( $if_ref->{ addr } eq $vip )
		{
			$interface = $if_ref->{ name };
			last;
		}
	}

	my $farm_filename = &getFarmFile( $farm_name );
	my $farm_state    = &getFarmStatus( $farm_name );
	my $stat          = -1;
	my $i             = 0;

	&runFarmStop( $farm_name, 'true' ) if $farm_state eq 'up';

	tie my @configfile, 'Tie::File', "$configdir\/$farm_filename";

	for my $line ( @configfile )
	{
		if ( $line =~ /^$farm_name\;/ )
		{
			my @args = split ( "\;", $line );
			$interface = $args[2] if ( !$interface );
			$line = "$args[0]\;$vip\;$interface\;$args[3]\;$args[4]";
			splice @configfile, $i, $line;
			$stat = $?;
		}
		$i++;
	}
	untie @configfile;
	$stat = $?;

	&runFarmStart( $farm_name, 'true' ) if $farm_state eq 'up';

	return $stat;
}

1;
