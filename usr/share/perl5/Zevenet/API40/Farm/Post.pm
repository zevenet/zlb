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

	my $desc = "Creating a farm";

	# check if FARM NAME already exists
	unless ( &getFarmType( $json_obj->{ farmname } ) == 1 )
	{
		my $msg = "Error trying to create a new farm, the farm name already exists.";
		&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
	}

	if ( exists $json_obj->{ copy_from } )
	{
		my $ori_type = &getFarmType( $json_obj->{ copy_from } );
		$ori_type = 'http' if $ori_type eq 'https';
		if ( $ori_type == 1 )
		{
			my $msg = "The farm '$json_obj->{copy_from}' does not exist.";
			&httpErrorResponse( code => 404, desc => $desc, msg => $msg );
		}
		if ( exists ( $json_obj->{ profile } )
			 and ( $ori_type ne $json_obj->{ profile } ) )
		{
			my $msg =
			  "The profile '$json_obj->{ profile }' does not match with the profile '$ori_type' of the farm '$json_obj->{ copy_from }'.";
			&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
		}
		else
		{
			$json_obj->{ profile } = $ori_type;
		}
	}

	require Zevenet::Net::Interface;
	my $ip_list = &getIpAddressList();

	# Check allowed parameters
	my $params = &getZAPIModel( "farm-create.json" );
	$params->{ vport }->{ interval } = "1,65535"
	  if ( exists $json_obj->{ profile }
		   and $json_obj->{ profile } =~ /(?:http|gslb)/ );
	$params->{ vport }->{ required } = "true"
	  if ( exists $json_obj->{ profile } and $json_obj->{ profile } ne 'datalink' );
	$params->{ vip }->{ values } = $ip_list;

	my $error_msg = &checkZAPIParams( $json_obj, $params, $desc );
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
	if ( !&getValidPort( $json_obj->{ vport }, $json_obj->{ profile } ) )
	{
		my $msg = "The virtual port must be an acceptable value and must be available.";
		&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
	}

	# check ranges
	my @ranges = split ( /,/, $json_obj->{ vport } );
	foreach my $range ( @ranges )
	{
		if ( $range =~ /^(\d+):(\d+)$/ )
		{
			if ( $1 > $2 )
			{
				my $msg = "Range $range in virtual port is not a valid value.";
				&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
			}
		}
	}

	$json_obj->{ 'interface' } = &getInterfaceOfIp( $json_obj->{ 'vip' } );

	my $status = 0;
	if ( exists $json_obj->{ copy_from } )
	{
		$status = &runFarmCreateFrom( $json_obj );
	}
	else
	{
		$status = &runFarmCreate(
								  $json_obj->{ profile },
								  $json_obj->{ vip },
								  $json_obj->{ vport },
								  $json_obj->{ farmname },
								  $json_obj->{ interface }
		);
	}

	if ( $status )
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
			message => "The farm $json_obj->{ farmname } has been created successfully."
	};

	if ( $eload )
	{
		&eload(
				module => 'Zevenet::Cluster',
				func   => 'runZClusterRemoteManager',
				args   => ['farm', 'start', $json_obj->{ farmname }],
		);
	}

	&httpResponse( { code => 201, body => $body } );
}

1;

