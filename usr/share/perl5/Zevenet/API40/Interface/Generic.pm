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

# GET /interfaces Get params of the interfaces
sub get_interfaces    # ()
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	require Zevenet::Net::Interface;

	my $desc = "List interfaces";
	my $if_list_ref;

	if ( $eload )
	{
		$if_list_ref = &eload(
							   module => 'Zevenet::Net::Interface',
							   func   => 'get_interface_list_struct',    # 100
		);
	}
	else
	{
		$if_list_ref = &get_interface_list_struct();
	}

	my $body = {
				 description => $desc,
				 interfaces  => $if_list_ref,
	};

	&httpResponse( { code => 200, body => $body } );
}

1;
