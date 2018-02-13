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
Function: runDatalinkFarmCreate

	Create a datalink farm through its configuration file and run it
	
Parameters:
	farmname - Farm name
	vip - Virtual IP
	port - Virtual port where service is listening

Returns:
	Integer - Error code: return 0 on success or different of 0 on failure
	
FIXME: 
	it is possible calculate here the inteface of VIP and put standard the input as the others create farm functions
		
=cut
sub runDatalinkFarmCreate    # ($farm_name,$vip,$fdev)
{
	my ( $farm_name, $vip, $fdev ) = @_;

	open FO, ">$configdir\/$farm_name\_datalink.cfg";
	print FO "$farm_name\;$vip\;$fdev\;weight\;up\n";
	close FO;
	my $output = $?;

	my $piddir = &getGlobalConfiguration('piddir');
	if ( !-e "$piddir/${farm_name}_datalink.pid" )
	{
		# Enable active datalink file
		open FI, ">$piddir\/$farm_name\_datalink.pid";
		close FI;
	}

	return $output;
}

1;
