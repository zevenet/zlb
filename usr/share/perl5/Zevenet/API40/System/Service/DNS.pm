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

# GET /system/dns
sub get_dns
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	require Zevenet::System::DNS;

	my $desc = "Get dns";
	my $dns  = &getDns();

	&httpResponse(
				   { code => 200, body => { description => $desc, params => $dns } } );
}

#  POST /system/dns
sub set_dns
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $json_obj = shift;

	require Zevenet::System::DNS;

	my $desc = "Modify the DNS";

	my $params = {
				   "primary" => {
								  'valid_format' => 'dns_nameserver',
				   },
				   "secondary" => {
									'valid_format' => 'dns_nameserver',
				   },
	};

	# Check allowed parameters
	my $error_msg = &checkZAPIParams( $json_obj, $params );
	return &httpErrorResponse( code => 400, desc => $desc, msg => $error_msg )
	  if ( $error_msg );

	foreach my $key ( keys %{ $json_obj } )
	{
		my $msg = &setDns( $key, $json_obj->{ $key } );
		&httpErrorResponse( code => 400, desc => $desc, msg => $msg ) if $msg;
	}

	my $dns = &getDns();
	&httpResponse(
				   { code => 200, body => { description => $desc, params => $dns } } );
}

1;
