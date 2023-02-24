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
use Zevenet::Farm::L4xNAT::Backend;


# GET /farms/<farmname> Request info of a l4xnat Farm
sub farms_name_l4    # ( $farmname )
{
	&zenlog( __FILE__ . q{:} . __LINE__ . q{:} . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $farmname = shift;

	my $out_p;
	my $out_b;

	require Zevenet::Farm::L4xNAT::Config;

	#	$output = &getL4FarmParam( $info, $farm_name );

	my $vip   = &getL4FarmParam( "vip",  $farmname );
	my $vport = &getL4FarmParam( "vipp", $farmname );

	my @ttl = &getFarmMaxClientTime( $farmname, "" );
	my $timetolimit = $ttl[0] + 0;

	# Farmguardian
	my @fgconfig    = &getFarmGuardianConf( $farmname, "" );
	my $fguse       = $fgconfig[3];
	my $fgcommand   = $fgconfig[2];
	my $fgtimecheck = $fgconfig[1];
	my $fglog       = $fgconfig[4];

	if ( not $fgtimecheck ) { $fgtimecheck = 5; }
	if ( not $fguse )       { $fguse       = "false"; }
	if ( not $fglog )       { $fglog       = "false"; }
	if ( not $fgcommand )   { $fgcommand   = ""; }

	my $status = &getFarmVipStatus( $farmname );

	$out_p = {
			   status      => $status,
			   vip         => $vip,
			   vport       => $vport,
			   algorithm   => &getL4FarmParam( 'alg', $farmname ),
			   nattype     => &getL4FarmParam( 'mode', $farmname ),
			   persistence => &getL4FarmParam( 'persist', $farmname ),
			   protocol    => &getL4FarmParam( 'proto', $farmname ),
			   ttl         => $timetolimit,
			   fgenabled   => $fguse,
			   fgtimecheck => $fgtimecheck + 0,
			   fgscript    => $fgcommand,
			   fglog       => $fglog,
			   listener    => 'l4xnat',
	};

	# Backends
	$out_b = &getL4FarmServers( $farmname );
	my $warning;
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
	&httpResponse( { code => 200, body => $body } );
	return;
}

1;
