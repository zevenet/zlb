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
use Zevenet::FarmGuardian;
use Zevenet::Farm::Config;
use Zevenet::Farm::L4xNAT::Backend;
use Zevenet::Farm::L4xNAT::Config;

my $eload;
if ( eval { require Zevenet::ELoad; } )
{
	$eload = 1;
}

# GET /farms/<farmname> Request info of a l4xnat Farm
sub farms_name_l4    # ( $farmname )
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $farmname = shift;

	my $out_p;
	my $out_b;

	my $vip   = &getL4FarmParam( "vip",  $farmname );
	my $vport = &getL4FarmParam( "vipp", $farmname );

	if ( $vport =~ /^\d+$/ )
	{
		$vport = $vport + 0;
	}

	my @ttl = &getFarmMaxClientTime( $farmname, "" );
	my $timetolimit = $ttl[0] + 0;

	my $status = &getFarmVipStatus( $farmname );

	my $persistence = &getL4FarmParam( 'persist', $farmname );
	$persistence = "" if $persistence eq 'none';

	$out_p = {
			   status       => $status,
			   vip          => $vip,
			   vport        => $vport,
			   algorithm    => &getL4FarmParam( 'alg', $farmname ),
			   nattype      => &getL4FarmParam( 'mode', $farmname ),
			   persistence  => $persistence,
			   protocol     => &getL4FarmParam( 'proto', $farmname ),
			   ttl          => $timetolimit,
			   farmguardian => &getFGFarm( $farmname ),
			   logs         => &getL4FarmParam( 'logs', $farmname ),
			   listener     => 'l4xnat',
	};

	# Backends
	$out_b = &getL4FarmServers( $farmname );

	# Delete not visible params
	my $validParamsre = qr/(alias)|(^id$)|(weight)|(^ip$)|(priority)|(status)/;
	foreach my $backend ( @{ $out_b } )
	{
		$backend->{ status } = "down" if ( $backend->{ status } =~ /fgdown/i );
		foreach my $param ( keys ( %{ $backend } ) )
		{
			delete $backend->{ $param } if ( !( $param =~ $validParamsre ) );
		}
	}

	my $body = {
				 description => "List farm $farmname",
				 params      => $out_p,
				 backends    => $out_b,
	};

	$body->{ ipds } = &eload(
							  module => 'Zevenet::IPDS::Core',
							  func   => 'getIPDSfarmsRules',
							  args   => [$farmname],
	) if ( $eload );

	&httpResponse( { code => 200, body => $body } );
}

1;
