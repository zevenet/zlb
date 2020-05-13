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

# GET /system/ntp
sub get_ntp
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $desc = "Get ntp";
	my $ntp  = &getGlobalConfiguration( 'ntp' );

	&httpResponse(
				   {
					 code => 200,
					 body => { description => $desc, params => { "server" => $ntp } }
				   }
	);
}

#  POST /system/ntp
sub set_ntp
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $json_obj = shift;

	my $desc = "Post ntp";

	my $params = {
				   "server" => {
								 'valid_format' => 'ntp',
								 'non_blank'    => 'true',
								 'required'     => 'true',
				   },
	};

	# Check allowed parameters
	my $error_msg = &checkZAPIParams( $json_obj, $params, $desc );
	return &httpErrorResponse( code => 400, desc => $desc, msg => $error_msg )
	  if ( $error_msg );

	my $error = &setGlobalConfiguration( 'ntp', $json_obj->{ 'server' } );

	if ( $error )
	{
		my $msg = "There was a error modifying ntp.";
		&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
	}

	my $ntp = &getGlobalConfiguration( 'ntp' );
	&httpResponse(
				   { code => 200, body => { description => $desc, params => $ntp } } );
}

1;

