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

use Zevenet::Farm::L4xNAT::Action;

my $configdir = &getGlobalConfiguration( 'configdir' );

my $eload;
if ( eval { require Zevenet::ELoad; } )
{
	$eload = 1;
}

=begin nd
Function: runL4FarmCreate

	Create a l4xnat farm

Parameters:
	vip - Virtual IP
	port - Virtual port. In l4xnat it ls possible to define multiport using ',' for add ports and ':' for ranges
	farmname - Farm name

Returns:
	Integer - return 0 on success or other value on failure

=cut

sub runL4FarmCreate
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my ( $vip, $farm_name, $vip_port ) = @_;

	my $output        = -1;
	my $farm_type     = 'l4xnat';
	my $farm_filename = "$configdir/$farm_name\_$farm_type.cfg";

	require Zevenet::Farm::L4xNAT::Action;
	require Zevenet::Farm::L4xNAT::Config;

	$vip_port = "80" if not defined $vip_port;
	$vip_port = ""   if ( $vip_port eq "*" );

	$output = &sendL4NlbCmd(
		{
		   farm   => $farm_name,
		   file   => "$farm_filename",
		   method => "POST",
		   body =>
			 qq({"farms" : [ { "name" : "$farm_name", "virtual-addr" : "$vip", "virtual-ports" : "$vip_port", "protocol" : "tcp", "mode" : "snat", "scheduler" : "weight", "state" : "up" } ] })
		}
	);

	&startL4Farm( $farm_name );

	return $output;
}

=begin nd
Function: runL4FarmDelete

	Delete a l4xnat farm

Parameters:

	farm_name - Farm name

Returns:
	Integer - return 0 on success or other value on failure

=cut

sub runL4FarmDelete
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my ( $farm_name ) = @_;

	my $output = -1;

	require Zevenet::Farm::L4xNAT::Action;
	require Zevenet::Farm::L4xNAT::Config;
	require Zevenet::Farm::Core;
	require Zevenet::Netfilter;

	my $farmfile = &getFarmFile( $farm_name );

	$output = &sendL4NlbCmd( { farm => $farm_name, method => "DELETE" } );

	unlink ( "$configdir/$farmfile" ) if ( -f "$configdir/$farmfile" );

	&delMarks( $farm_name, "" );

	return $output;
}

1;
