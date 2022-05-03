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
use Zevenet::Farm::Base;
use Zevenet::Farm::L4xNAT::Config;
use Zevenet::Net::Interface;
use Zevenet::Farm::Config;

my $eload;
if ( eval { require Zevenet::ELoad; } )
{
	$eload = 1;
}

# PUT /farms/<farmname> Modify a l4xnat Farm
sub modify_l4xnat_farm    # ( $json_obj, $farmname )
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $json_obj = shift;
	my $farmname = shift;

	my $desc = "Modify L4xNAT farm '$farmname'";

	# Flags
	my $status = &getFarmStatus( $farmname );

	# Check that the farm exists
	if ( !&getFarmExists( $farmname ) )
	{
		my $msg = "The farmname $farmname does not exist.";
		&httpErrorResponse( code => 404, desc => $desc, msg => $msg );
	}

	# Removed
	if ( $json_obj->{ algorithm } =~ /^(prio)$/ )
	{
		my $msg = "'Prio' algorithm is not supported anymore.";
		&httpErrorResponse( code => 410, desc => $desc, msg => $msg );
	}

	require Zevenet::Net::Interface;
	my $ip_list = &getIpAddressList();

	# Modify the vport if protocol is set to 'all'
	if (    ( exists $json_obj->{ protocol } and $json_obj->{ protocol } eq 'all' )
		 or ( exists $json_obj->{ vport } and $json_obj->{ vport } eq '*' ) )
	{
		$json_obj->{ vport }    = "*";      # fixme
		$json_obj->{ protocol } = "all";    # fixme
	}
	if ( exists $json_obj->{ persistence }
		 and $json_obj->{ persistence } eq 'none' )
	{
		$json_obj->{ persistence } = '';
	}

	# Check allowed parameters
	my $params = &getZAPIModel( "farm_l4xnat-modify.json" );
	$params->{ vip }->{ values } = $ip_list;

	my $error_msg = &checkZAPIParams( $json_obj, $params, $desc );
	return &httpErrorResponse( code => 400, desc => $desc, msg => $error_msg )
	  if ( $error_msg );

	if ( $json_obj->{ protocol } =~ /^(?:amanda|irc|netbios-ns|sane)$/ )
	{
		my $msg = "'$json_obj->{ protocol }' protocol is not supported anymore.";
		&httpErrorResponse( code => 410, desc => $desc, msg => $msg );
	}

	# Get current vip & vport & proto
	my $vip   = $json_obj->{ vip }   // &getFarmVip( 'vip',  $farmname );
	my $vport = $json_obj->{ vport } // &getFarmVip( 'vipp', $farmname );
	my $proto = $json_obj->{ protocol } // &getL4FarmParam( 'proto', $farmname );

	# Extend parameter checks
	if ( exists $json_obj->{ protocol } and $json_obj->{ protocol } ne 'all' )
	{
		if ( $vport eq '*' )
		{
			my $msg = "Protocol can not be '$json_obj->{ protocol }' with port '$vport'";
			&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
		}
	}

	if ( exists $json_obj->{ vport } and $json_obj->{ vport } ne '*' )
	{
		if ( $proto eq 'all' )
		{
			my $msg = "Port can not be '$json_obj->{ vport }' with protocol '$proto'";
			&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
		}
	}

	# check ranges
	if ( exists $json_obj->{ vport } )
	{
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
	}

	if (    exists ( $json_obj->{ vip } )
		 or exists ( $json_obj->{ vport } )
		 or exists ( $json_obj->{ protocol } ) )
	{
		require Zevenet::Net::Validate;
		require Zevenet::Farm::L4xNAT::Config;
		if ( $status eq 'up' and !&validatePort( $vip, $vport, $proto, $farmname ) )
		{
			my $msg =
			  "The '$vip' ip and '$vport' port are being used for another farm. This farm should be stopped before modifying it";
			&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
		}

		if ( exists ( $json_obj->{ vip } ) )
		{
			require Zevenet::Farm::L4xNAT::Backend;

			my $backends = &getL4FarmServers( $farmname );
			unless ( !@{ $backends }[0]
					 || &ipversion( @{ $backends }[0]->{ ip } ) eq &ipversion( $vip ) )
			{
				my $msg =
				  "Invalid VIP address, VIP and backends can't be from diferent IP version.";
				&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
			}

			# the vip must be UP
			if ( $status ne 'down' )
			{
				require Zevenet::Net::Interface;
				my $if_name = &getInterfaceByIp( $json_obj->{ vip } );
				my $if_ref  = &getInterfaceConfig( $if_name );
				if ( &getInterfaceSystemStatus( $if_ref ) ne "up" )
				{
					my $msg =
					  "The '$json_obj->{ vip }' ip is not UP. This farm should be stopped before modifying it";
					&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
				}
			}
		}

		if ( exists ( $json_obj->{ vport } ) )
		{
			# VPORT validation
			if ( !&getValidPort( $vport, "L4XNAT", $farmname ) )
			{
				my $msg = "The virtual port must be an acceptable value and must be available.";
				&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
			}
		}
	}

	my $reload_ipds = 0;
	if (    exists $json_obj->{ vport }
		 || exists $json_obj->{ vip }
		 || exists $json_obj->{ newfarmname } )
	{

		if ( $eload )
		{
			$reload_ipds = 1;

			&eload(
					module => 'Zevenet::IPDS::Base',
					func   => 'runIPDSStopByFarm',
					args   => [$farmname],
			);

			&eload(
					module => 'Zevenet::Cluster',
					func   => 'runZClusterRemoteManager',
					args   => ['ipds', 'stop', $farmname],
			);

			&eload(
					module => 'Zevenet::Cluster',
					func   => 'runZClusterRemoteManager',
					args   => ['farm', 'stop', $farmname],
			);
		}
	}

	####### Functions

	# Modify Farm's Name
	if ( exists ( $json_obj->{ newfarmname } ) )
	{
		unless ( &getL4FarmParam( 'status', $farmname ) eq 'down' )
		{
			my $msg = 'Cannot change the farm name while running';
			&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
		}

		if ( $json_obj->{ newfarmname } ne $farmname )
		{
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
	}

	# Modify Load Balance Algorithm
	if ( exists ( $json_obj->{ algorithm } ) )
	{
		my $error = &setFarmAlgorithm( $json_obj->{ algorithm }, $farmname );
		if ( $error )
		{
			my $msg = "Some errors happened trying to modify the algorithm.";
			&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
		}
	}

	# Modify Persistence Mode
	if ( exists ( $json_obj->{ persistence } ) )
	{
		my $persistence = $json_obj->{ persistence };

		if ( &getL4FarmParam( 'persist', $farmname ) ne $persistence )
		{
			my $statusp = &setFarmSessionType( $persistence, $farmname, "" );
			if ( $statusp )
			{
				my $msg = "Some errors happened trying to modify the persistence.";
				&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
			}
		}
	}

	# Modify Protocol Type
	if ( exists ( $json_obj->{ protocol } ) )
	{
		my $error = &setL4FarmParam( 'proto', $json_obj->{ protocol }, $farmname );
		if ( $error )
		{
			my $msg = "Some errors happened trying to modify the protocol.";
			&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
		}
	}

	# Modify NAT Type
	if ( exists ( $json_obj->{ nattype } ) )
	{
		if ( &getL4FarmParam( 'mode', $farmname ) ne $json_obj->{ nattype } )
		{
			my $error = &setL4FarmParam( 'mode', $json_obj->{ nattype }, $farmname );
			if ( $error )
			{
				my $msg = "Some errors happened trying to modify the nattype.";
				&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
			}
		}
	}

	# Modify IP Address Persistence Time To Limit
	if ( exists ( $json_obj->{ ttl } ) )
	{
		my $error = &setFarmMaxClientTime( 0, $json_obj->{ ttl }, $farmname );
		if ( $error )
		{
			my $msg = "Some errors happened trying to modify the ttl.";
			&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
		}
		$json_obj->{ ttl } = $json_obj->{ ttl } + 0;
	}

	# Modify vip and vport
	if ( exists ( $json_obj->{ vip } ) or exists ( $json_obj->{ vport } ) )
	{
		if ( &setFarmVirtualConf( $vip, $vport, $farmname ) )
		{
			my $msg = "Could not set the virtual configuration.";
			return &httpErrorResponse( code => 400, desc => $desc, msg => $msg );
		}
	}

	# Modify logs
	if ( exists ( $json_obj->{ logs } ) )
	{
		my $msg = &modifyLogsParam( $farmname, $json_obj->{ logs } );
		if ( defined $msg && length $msg )
		{
			return &httpErrorResponse( code => 400, desc => $desc, msg => $msg );
		}
	}

	# no error found, return successful response
	&zenlog( "Success, some parameters have been changed in farm $farmname.",
			 "info", "LSLB" );

	if ( &getL4FarmParam( 'status', $farmname ) eq 'up' and $eload )
	{
		if ( $reload_ipds )
		{
			&eload(
					module => 'Zevenet::IPDS::Base',
					func   => 'runIPDSStartByFarm',
					args   => [$farmname],
			);

			&eload(
					module => 'Zevenet::Cluster',
					func   => 'runZClusterRemoteManager',
					args   => ['farm', 'start', $farmname],
			);

			&eload(
					module => 'Zevenet::Cluster',
					func   => 'runZClusterRemoteManager',
					args   => ['ipds', 'start', $farmname],
			);
		}
		else
		{
			&eload(
					module => 'Zevenet::Cluster',
					func   => 'runZClusterRemoteManager',
					args   => ['farm', 'restart', $farmname],
			);
		}
	}

	my $body = {
				 description => $desc,
				 params      => $json_obj,
				 message     => "Some parameters have been changed in farm $farmname."
	};

	&httpResponse( { code => 200, body => $body } );
}

1;

