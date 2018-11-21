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

use Zevenet::SNMP;

# GET /system/snmp
sub get_snmp
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $desc = "Get snmp";

	my %snmp = %{ &getSnmpdConfig() };
	$snmp{ 'status' } = &getSnmpdStatus();

	&httpResponse(
				  { code => 200, body => { description => $desc, params => \%snmp } } );
}

#  POST /system/snmp
sub set_snmp
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $json_obj = shift;

	my $desc = "Post snmp";

	my @allowParams = ( "port", "status", "ip", "community", "scope" );
	my $param_msg = &getValidOptParams( $json_obj, \@allowParams );

	if ( $param_msg )
	{
		&httpErrorResponse( code => 400, desc => $desc, msg => $param_msg );
	}

	# Check key format
	foreach my $key ( keys %{ $json_obj } )
	{
		if ( !&getValidFormat( "snmp_$key", $json_obj->{ $key } ) )
		{
			my $msg = "$key hasn't a correct format.";
			&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
		}
	}

	my $status = $json_obj->{ 'status' };
	delete $json_obj->{ 'status' };
	my $snmp = &getSnmpdConfig();

	foreach my $key ( keys %{ $json_obj } )
	{
		$snmp->{ $key } = $json_obj->{ $key };
	}

	my $error = &setSnmpdConfig( $snmp );
	if ( $error )
	{
		my $msg = "There was a error modifying ssh.";
		&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
	}

	if ( !$status && &getSnmpdStatus() eq 'true' )
	{
		&setSnmpdStatus( 'false' );    # stopping snmp
		&setSnmpdStatus( 'true' );     # starting snmp
	}
	elsif ( $status eq 'true' && &getSnmpdStatus() eq 'false' )
	{
		&setSnmpdStatus( 'true' );     # starting snmp
	}
	elsif ( $status eq 'false' && &getSnmpdStatus() eq 'true' )
	{
		&setSnmpdStatus( 'false' );    # stopping snmp
	}

	$snmp->{ status } = &getSnmpdStatus();

	&httpResponse(
				   { code => 200, body => { description => $desc, params => $snmp } } );
}

1;
