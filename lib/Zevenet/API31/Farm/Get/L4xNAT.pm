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

# GET /farms/<farmname> Request info of a l4xnat Farm
sub farms_name_l4 # ( $farmname )
{
	my $farmname = shift;

	my $out_p;
	my @out_b;

	my $vip   = &getFarmVip( "vip",  $farmname );
	my $vport = &getFarmVip( "vipp", $farmname );

	if ( $vport =~ /^\d+$/ )
	{
		$vport = $vport + 0;
	}

	my @ttl = &getFarmMaxClientTime( $farmname, "" );
	my $timetolimit = $ttl[0] + 0;
	
	# Farmguardian
	my @fgconfig    = &getFarmGuardianConf( $farmname, "" );
	my $fguse       = $fgconfig[3];
	my $fgcommand   = $fgconfig[2];
	my $fgtimecheck = $fgconfig[1];
	my $fglog       = $fgconfig[4];
	
	if ( !$fgtimecheck ) { $fgtimecheck = 5; }
    if ( !$fguse ) { $fguse = "false"; }
    if ( !$fglog  ) { $fglog = "false"; }
    if ( !$fgcommand ) { $fgcommand = ""; }

	my $status = &getFarmVipStatus( $farmname );

	my $persistence = &getFarmPersistence( $farmname );
	$persistence = "" if $persistence eq 'none';

	$out_p = {
			   status      => $status,
			   vip         => $vip,
			   vport       => $vport,
			   algorithm   => &getFarmAlgorithm( $farmname ),
			   nattype     => &getFarmNatType( $farmname ),
			   persistence => $persistence,
			   protocol    => &getFarmProto( $farmname ),
			   ttl         => $timetolimit,
			   fgenabled   => $fguse,
			   fgtimecheck => $fgtimecheck + 0,
			   fgscript    => $fgcommand,
			   fglog       => $fglog,
			   listener    => 'l4xnat',
	};

	# Backends
	@out_b = &getL4FarmBackends( $farmname );

	my $body = {
				 description => "List farm $farmname",
				 params      => $out_p,
				 backends    => \@out_b,
	};

	if ( eval{ require Zevenet::IPDS; } )
	{
		$body->{ ipds } = &getIPDSfarmsRules( $farmname );
	}

	&httpResponse({ code => 200, body => $body });
}

1;
