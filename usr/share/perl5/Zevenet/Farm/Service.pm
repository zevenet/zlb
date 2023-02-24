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


my $configdir = &getGlobalConfiguration( 'configdir' );

=begin nd
Function: getFarmServices

	Get a list of services name for a farm
	
Parameters:
	farmname - Farm name

Returns:
	Array - list of service names 
	
=cut

sub getFarmServices    # ($farm_name)
{
	&zenlog( __FILE__ . q{:} . __LINE__ . q{:} . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my ( $farm_name ) = @_;

	my $farm_type = &getFarmType( $farm_name );
	my @output    = ();

	if ( $farm_type eq "http" or $farm_type eq "https" )
	{
		require Zevenet::Farm::HTTP::Service;
		@output = &getHTTPFarmServices( $farm_name );
	}
	return @output;
}

1;

