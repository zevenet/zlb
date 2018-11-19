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
use Zevenet::Farm::Datalink::Backend;

sub farms_name_datalink    # ( $farmname )
{
	my $farmname = shift;

	require Zevenet::Farm::Config;
	my $vip = &getFarmVip( "vip", $farmname );
	my $status = &getFarmVipStatus( $farmname );

	my $out_p = {
				  vip       => $vip,
				  algorithm => &getFarmAlgorithm( $farmname ),
				  status    => $status,
	};

	### backends	
	my $out_b = &getDatalinkFarmBackends( $farmname );

	my $body = {
				 description => "List farm $farmname",
				 params      => $out_p,
				 backends    => $out_b,
	};

	if ( eval{ require Zevenet::IPDS; } )
	{
		$body->{ ipds } = &getIPDSfarmsRules( $farmname );
		delete $body->{ ipds }->{ rbl };
		delete $body->{ ipds }->{ dos };
	}

	&httpResponse( { code => 200, body => $body } );
}

1;
