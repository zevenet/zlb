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
use Zevenet::Farm::HTTP::Config;

my $eload;
if ( eval { require Zevenet::ELoad; } )
{
	$eload = 1;
}

# GET /farms/<farmname> Request info of a http|https Farm
sub farms_name_http    # ( $farmname )
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $farmname = shift;

	# Get farm reference
	require Zevenet::API40::Farm::Output::HTTP;
	my $farm_ref = &getHTTPOutFarm( $farmname );

	# Get farm services reference
	require Zevenet::Farm::HTTP::Service;
	my $services_ref = &getHTTPOutService( $farmname );

	# Output
	my $body = {
				 description => "List farm $farmname",
				 params      => $farm_ref,
				 services    => $services_ref,
	};

	if ( $eload )
	{
		$body->{ ipds } = &eload(
								  module => 'Zevenet::IPDS::Core',
								  func   => 'getIPDSfarmsRules',
								  args   => [$farmname],
		);
	}

	&httpResponse( { code => 200, body => $body } );
}

# GET /farms/<farmname>/summary
sub farms_name_http_summary
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $farmname = shift;

	# Get farm reference
	require Zevenet::API40::Farm::Output::HTTP;
	my $farm_ref = &getHTTPOutFarm( $farmname );

	# Services
	require Zevenet::Farm::HTTP::Service;

	my $services_ref = &get_http_all_services_summary_struct( $farmname );

	my $body = {
				 description => "List farm $farmname",
				 params      => $farm_ref,
				 services    => $services_ref,
	};

	if ( $eload )
	{
		$body->{ ipds } = &eload(
								  module => 'Zevenet::IPDS::Core',
								  func   => 'getIPDSfarmsRules',
								  args   => [$farmname],
		);
	}

	&httpResponse( { code => 200, body => $body } );
}

1;
