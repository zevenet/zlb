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
use Zevenet::Farm::Base;
use Zevenet::Farm::Datalink::Config;

my $eload;
if ( eval { require Zevenet::ELoad; } )
{
	$eload = 1;
}

sub modify_datalink_farm    # ( $json_obj, $farmname )
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $json_obj = shift;
	my $farmname = shift;

	my $desc           = "Modify datalink farm '$farmname'";
	my $reload_flag    = "false";
	my $restart_flag   = "false";
	my $initial_status = &getFarmStatus( $farmname );
	my $error          = "false";
	my $status;

	my $params = {
				   "newfarmname" => {
									  'valid_format' => 'farm_name',
									  'non_blank'    => 'true',
				   },
				   "algorithm" => {
									'values'    => ['prio', 'weight'],
									'non_blank' => 'true',
				   },
				   "vip" => {
							  'valid_format' => 'ip_addr',
							  'non_blank'    => 'true',
							  'format_msg'   => 'expects an IP'
				   },
	};

	# Check allowed parameters
	my $error_msg = &checkZAPIParams( $json_obj, $params );
	return &httpErrorResponse( code => 400, desc => $desc, msg => $error_msg )
	  if ( $error_msg );

	# Modify Farm's Name
	if ( exists ( $json_obj->{ newfarmname } ) )
	{
		unless ( &getFarmStatus( $farmname ) eq 'down' )
		{
			my $msg = 'Cannot change the farm name while running';
			&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
		}

		#Check if the new farm's name alredy exists
		if ( &getFarmExists( $json_obj->{ newfarmname } ) )
		{
			my $msg = "The farm $json_obj->{newfarmname} already exists, try another name.";
			&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
		}

		#Change farm name
		require Zevenet::Farm::Action;
		my $fnchange = &setNewFarmName( $farmname, $json_obj->{ newfarmname } );
		if ( $fnchange == -1 )
		{
			my $msg =
			  "The name of the farm can't be modified, delete the farm and create a new one.";
			&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
		}

		$farmname = $json_obj->{ newfarmname };
	}

	# Modify Load Balance Algorithm
	if ( exists ( $json_obj->{ algorithm } ) )
	{
		$status = &setDatalinkFarmAlgorithm( $json_obj->{ algorithm }, $farmname );
		if ( $status == -1 )
		{
			my $msg = "Some errors happened trying to modify the algorithm.";
			&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
		}

		$restart_flag = "true";
	}

	# Modify Virtual IP and Interface
	if ( exists ( $json_obj->{ vip } ) )
	{
		my $fdev = &getInterfaceOfIp( $json_obj->{ vip } );
		if ( !defined $fdev )
		{
			my $msg = "$json_obj->{ vip } has to be configured in some interface.";
			&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
		}

		# interface must be running
		if ( !grep { $_ eq $json_obj->{ vip } } &listallips() )
		{
			my $msg = "The IP has to be UP to be used as VIP.";
			&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
		}

		my $status =
		  &setDatalinkFarmVirtualConf( $json_obj->{ vip }, $fdev, $farmname );
		if ( $status == -1 )
		{
			my $msg = "It is not possible to change the farm virtual IP and interface.";
			&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
		}

		$restart_flag = "true";
	}

	# Restart Farm
	if ( $restart_flag eq "true" && $initial_status ne 'down' )
	{
		&runFarmStop( $farmname, "true" );
		&runFarmStart( $farmname, "true" );

		&eload(
				module => 'Zevenet::Cluster',
				func   => 'runZClusterRemoteManager',
				args   => ['farm', 'restart', $farmname],
		) if ( $eload );
	}

	# no error found, return successful response
	&zenlog( "Success, some parameters have been changed in farm $farmname.",
			 "info", "DSLB" );

	my $body = {
				 description => $desc,
				 params      => $json_obj
	};

	&httpResponse( { code => 200, body => $body } );
}

1;
