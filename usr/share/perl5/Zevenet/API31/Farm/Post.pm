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
use Zevenet::Net::Util;
use Zevenet::Farm::Core;
use Zevenet::Farm::Factory;

my $eload;
if ( eval { require Zevenet::ELoad; } )
{
	$eload = 1;
}

sub new_farm    # ( $json_obj )
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $json_obj = shift;

   # 3 Mandatory Parameters ( 1 mandatory for HTTP or GSBL and optional for L4xNAT )
   #
   #	- farmname
   #	- profile
   #	- vip
   #	- vport: optional for L4xNAT and not used in Datalink profile.

	my $desc = "Creating farm '$json_obj->{ farmname }'";

	# validate FARM NAME
	unless (    $json_obj->{ farmname }
			 && &getValidFormat( 'farm_name', $json_obj->{ farmname } ) )
	{
		my $msg =
		  "The farm name is required to have alphabet letters, numbers or hypens (-) only.";
		&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
	}

	# check if FARM NAME already exists
	unless ( &getFarmType( $json_obj->{ farmname } ) == 1 )
	{
		my $msg = "Error trying to create a new farm, the farm name already exists.";
		&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
	}

	# Farm PROFILE validation
	if ( $json_obj->{ profile } !~ /^(:?HTTP|GSLB|L4XNAT|DATALINK)$/i )
	{
		my $msg = "The farm's profile is not supported.";
		&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
	}

	# VIP validation
	if ( $json_obj->{ profile } =~ /^DATALINK$/i )
	{
		# interface must be running
		if ( !grep { $_ eq $json_obj->{ vip } } &listallips() )
		{
			my $msg = "An available virtual IP must be set.";
			&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
		}
	}
	else
	{
		# the ip must exist in some interface
		require Zevenet::Net::Interface;
		if ( !&getIpAddressExists( $json_obj->{ vip } ) )
		{
			my $msg = "The vip IP must exist in some interface.";
			&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
		}
	}

	# VPORT validation
	if ( !&getValidPort( $json_obj->{ vport }, $json_obj->{ profile } ) )
	{
		my $msg = "The virtual port must be an acceptable value and must be available.";
		&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
	}

	$json_obj->{ 'interface' } = &getInterfaceOfIp( $json_obj->{ 'vip' } );

	my $status = &runFarmCreate(
								 $json_obj->{ profile },
								 $json_obj->{ vip },
								 $json_obj->{ vport },
								 $json_obj->{ farmname },
								 $json_obj->{ interface }
	);

	if ( $status == -1 )
	{
		&zenlog(
			 "Error trying to create a new farm $json_obj->{ farmname }, can't be created.",
			 "error", "FARMS"
		);

		my $msg = "The $json_obj->{ farmname } farm can't be created";
		&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
	}

	&zenlog(
			 "Success, the farm $json_obj->{ farmname } has been created successfully.",
			 "info", "FARMS" );

	my $out_p;

	if ( $json_obj->{ profile } =~ /^DATALINK$/i )
	{
		$out_p = {
				   farmname  => $json_obj->{ farmname },
				   profile   => $json_obj->{ profile },
				   vip       => $json_obj->{ vip },
				   interface => $json_obj->{ interface },
		};
	}
	else
	{
		$out_p = {
				   farmname  => $json_obj->{ farmname },
				   profile   => $json_obj->{ profile },
				   vip       => $json_obj->{ vip },
				   vport     => $json_obj->{ vport },
				   interface => $json_obj->{ interface },
		};
	}

	my $body = {
				 description => $desc,
				 params      => $out_p,
	};

	if ( $eload )
	{
		&eload(
				module => 'Zevenet::Cluster',
				func   => 'zClusterFarmUp',
				args   => [$json_obj->{ farmname }],
		) if $json_obj->{ profile } =~ /^l4xnat$/i;

		&eload(
				module => 'Zevenet::Cluster',
				func   => 'runZClusterRemoteManager',
				args   => ['farm', 'start', $json_obj->{ farmname }],
		);
	}

	&httpResponse( { code => 201, body => $body } );
}

1;
