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

	my $error = "false";
	my $desc  = "Creating a farm";

	my $params = {
		"profile" => {
					   'required'  => 'true',
					   'non_blank' => 'true',
					   'values'    => ['http', 'gslb', 'l4xnat', 'datalink'],
		},
		"farmname" => {
			'required'     => 'true',
			'non_blank'    => 'true',
			'valid_format' => 'farm_name',
			'format_msg' =>
			  "The farm name is required to have alphabet letters, numbers or hypens (-) only.",
		},
		"vip" => {
				   'valid_format' => 'ip_addr',
				   'non_blank'    => 'true',
				   'required'     => 'true',
		},
	};

	if ( $json_obj->{ profile } ne 'datalink' )
	{
		$params->{ "vport" } = {

			# the format is checked before
			'format_msg' => 'expects a port',
			'non_blank'  => 'true',
			'required'   => 'true',
		};
	}

	# check if FARM NAME already exists
	unless ( &getFarmType( $json_obj->{ farmname } ) == 1 )
	{
		my $msg = "Error trying to create a new farm, the farm name already exists.";
		&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
	}

	# Check allowed parameters
	my $error_msg = &checkZAPIParams( $json_obj, $params );
	return &httpErrorResponse( code => 400, desc => $desc, msg => $error_msg )
	  if ( $error_msg );

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
	if (
		 !&getValidPort(
						 $json_obj->{ vip },
						 $json_obj->{ vport },
						 $json_obj->{ profile }
		 )
	  )
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
		my $msg = "The $json_obj->{ farmname } farm can't be created";
		&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
	}

	&zenlog(
			 "Success, the farm $json_obj->{ farmname } has been created successfully.",
			 "info", "FARMS" );

	my $out_p = $json_obj;
	$out_p->{ interface } = $json_obj->{ interface };

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
