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
use Zevenet::FarmGuardian;
use Zevenet::Farm::Config;
use Zevenet::Farm::Backend;
use Zevenet::Farm::L4xNAT::Config;


# GET /farms/<farmname> Request info of a l4xnat Farm
sub farms_name_l4    # ( $farmname )
{
	&zenlog( __FILE__ . q{:} . __LINE__ . q{:} . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $farmname = shift;

	my $out_p;

	my $farm   = &getL4FarmStruct( $farmname );
	my $status = &getFarmVipStatus( $farmname );

	require Zevenet::Farm::L4xNAT::Sessions;
	$out_p = {
		status      => $status,
		vip         => $farm->{ vip },
		vport       => $farm->{ vport },
		algorithm   => $farm->{ lbalg },
		nattype     => $farm->{ nattype },
		persistence => $farm->{ persist },
		ttl         => $farm->{ ttl } + 0,
		protocol    => $farm->{ vproto },

		farmguardian => &getFGFarm( $farmname ),
		listener     => 'l4xnat',
		sessions     => &listL4FarmSessions( $farmname )
	};
	# Backends
	my $warning;
	my $out_b = &getFarmServers( $farmname );
	if ( &getAPIFarmBackends( $out_b, 'l4xnat' ) == 2 )
	{
		$out_b   = [];
		$warning = "Error get info from backends";
	}

	my $body = {
				 description => "List farm $farmname",
				 params      => $out_p,
				 backends    => $out_b,
	};
	$body->{ warning } = $warning if $warning;


	&httpResponse( { code => 200, body => $body } );
	return;
}

1;

