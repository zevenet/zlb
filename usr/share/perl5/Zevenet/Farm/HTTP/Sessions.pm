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
use POSIX 'strftime';
require Tie::File;


=begin nd
Function: listL7FarmSessions

	Get a list of the static and dynamic l7 sessions in a farm. Using zproxy. If the farm is down, 
	get the static sessions list from the config file.

Parameters:
	farmname - Farm name
	service  - Service name

Returns:
	array ref - Returns a list of hash references with the following parameters:
		"backend" is the client position entry in the session table
		"id" is the backend id assigned to session
		"session" is the key that identifies the session
		"type" is the key that identifies the session

		[
			{
				"backend" : 0,
				"session" : "192.168.1.186",
				"type" : "dynamic",
				"ttl" : "54m5s",
			}
		]
	
	or 

	Integer 1 - on error

=cut

sub listL7FarmSessions
{
	&zenlog( __FILE__ . q{:} . __LINE__ . q{:} . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );

	my $farmname = shift;
	my $service  = shift;

	require Zevenet::Farm::Base;
	use POSIX 'floor';

	my $output;
	my $error = 1;

	require Zevenet::Farm::HTTP::Config;
	my $status = &getHTTPFarmStatus( $farmname );

	if ( $status eq 'up' )
	{
		require Zevenet::Farm::HTTP::Config;
		my $call = {
					 method   => "GET",
					 protocol => "http",
					 host     => "localhost",
					 path     => "/listener/0/service/$service",
					 socket   => &getHTTPFarmSocket( "$farmname" ),
					 json     => 3,
		};

		require Zevenet::HTTPClient;
		$output = &runHTTPRequest( $call );

		if ( $output->{ code } ne 0 )
		{
			&zenlog(
					 "Zproxy socket HTTP request failed: "
					   . $output->{ desc }
					   . ", code: "
					   . $output->{ code },
					 "error",
					 "HTTP"
			);
			return $error;
		}

		$output = $output->{ return }->{ body }->{ sessions };

		require Zevenet::Farm::HTTP::Backend;
		my $backend_id_ref;
		foreach my $id ( @{ $output } )
		{
			if ( exists $backend_id_ref->{ $id->{ 'backend-id' } } )
			{
				$id->{ 'backend-id' } = $backend_id_ref->{ $id->{ 'backend-id' } };
			}
			else
			{
				$backend_id_ref->{ $id->{ 'backend-id' } } =
				  &getHTTPFarmBackendIndexById( $farmname, $service, $id->{ 'backend-id' } );
				$id->{ 'backend-id' } = $backend_id_ref->{ $id->{ 'backend-id' } };
			}
		}
	}

	my @result;
	my $ttl = &getHTTPFarmVS( $farmname, $service, "ttl" );
	if ( $ttl !~ /^\d+$/ )
	{
		&zenlog( "Unable to fetch ttl from farm $farmname", "error", "HTTP" );
		return $error;
	}
	my $time = time ();
	foreach my $ss ( @{ $output } )
	{
		my $min_rem =
		  floor( ( $ttl - ( $time - $ss->{ 'last-seen' } ) ) / 60 );
		my $sec_rem =
		  floor( ( $ttl - ( $time - $ss->{ 'last-seen' } ) ) % 60 );

		my $type = $ss->{ 'last-seen' } eq 0 ? 'static' : 'dynamic';
		my $ttl = $type eq 'static' ? undef : $min_rem . 'm' . $sec_rem . 's' . '0ms';

		my $sessionHash = {
							session => $ss->{ id },
							id      => $ss->{ 'backend-id' },
							type    => $type,
							service => $service,
							ttl     => $ttl,
		};
		push ( @result, $sessionHash );
	}
	return \@result;
}

1;
