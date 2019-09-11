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
	my $reload_flag = "false";
	my $error       = "false";
	my $status;
	my $initialStatus = &getL4FarmParam( 'status', $farmname );

	# Check that the farm exists
	if ( !&getFarmExists( $farmname ) )
	{
		my $msg = "The farmname $farmname does not exists.";
		&httpErrorResponse( code => 404, desc => $desc, msg => $msg );
	}

	# Removed
	if ( $json_obj->{ algorithm } =~ /^(prio)$/ )
	{
		my $msg = "'Prio' algorithm is not supported anymore.";
		&httpErrorResponse( code => 410, desc => $desc, msg => $msg );
	}

	my $params = {
		   "newfarmname" => {
							  'valid_format' => 'farm_name',
							  'non_blank'    => 'true',
		   },
		   "vport" => {
						'non_blank' => 'true',
		   },
		   "vip" => {
					  'function'   => \&getIpAddressExists,
					  'non_blank'  => 'true',
					  'format_msg' => 'The vip IP must exist in some interface.'
		   },
		   "algorithm" => {
							'values' => [
										 'weight',             'roundrobin',
										 'hash_srcip_srcport', 'hash_srcip',
										 'symhash',            'leastconn'
							],
							'non_blank' => 'true',
		   },
		   "persistence" => {
				   'values' =>
					 ['ip', 'srcip', 'srcport', 'srcmac', 'srcip_srcport', 'srcip_dstport'],
		   },
		   "protocol" => {
						   'values' => [
										'all',  'tcp', 'udp',        'sctp',
										'sip',  'ftp', 'tftp',       'amanda',
										'h323', 'irc', 'netbios-ns', 'pptp',
										'sane', 'snmp'
						   ],
						   'non_blank' => 'true',
		   },
		   "nattype" => {
						  'values'    => ['nat', 'dnat', 'dsr', 'stateless_dnat'],
						  'non_blank' => 'true',
		   },
		   "ttl" => {
					  'valid_format' => 'natural_num',
					  'non_blank'    => 'true',
		   },
	};

	if ( $eload )
	{
		$params->{ "logs" } = {
								'valid_format' => 'boolean',
								'non_blank'    => 'true',
		};
	}

	# Modify the vport if protocol is set to 'all'
	if (    ( exists $json_obj->{ protocol } and $json_obj->{ protocol } eq 'all' )
		 or ( exists $json_obj->{ vport } and $json_obj->{ vport } eq '*' ) )
	{
		$json_obj->{ vport }    = "*";
		$json_obj->{ protocol } = "all";
	}

	# Check allowed parameters
	my $error_msg = &checkZAPIParams( $json_obj, $params );
	return &httpErrorResponse( code => 400, desc => $desc, msg => $error_msg )
	  if ( $error_msg );

	# Extend parameter checks
	if ( exists ( $json_obj->{ vip } ) )
	{
		# the ip must exist in some interface
		require Zevenet::Farm::L4xNAT::Backend;

		my $backends = &getL4FarmServers( $farmname );
		unless ( !@{ $backends }[0]
			|| &ipversion( @{ $backends }[0]->{ ip } ) eq &ipversion( $json_obj->{ vip } ) )
		{
			my $msg =
			  "Invalid VIP address, VIP and backends can't be from diferent IP version.";
			&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
		}
	}

	if ( exists ( $json_obj->{ vport } ) )
	{
		# VPORT validation
		if (
			 !&getValidPort( $json_obj->{ vip }, $json_obj->{ vport }, "L4XNAT", $farmname )
		  )
		{
			my $msg = "The virtual port must be an acceptable value and must be available.";
			&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
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
		# Get current vip & vport
		my $vip   = $json_obj->{ vip }   // "";
		my $vport = $json_obj->{ vport } // "";

		if ( &setFarmVirtualConf( $vip, $vport, $farmname ) )
		{
			my $msg = "Could not set the virtual configuration.";
			return &httpErrorResponse( code => 400, desc => $desc, msg => $msg );
		}
	}

	# Modify logs
	if ( $eload )
	{
		if ( exists ( $json_obj->{ logs } ) )
		{
			my $msg = &eload(
							  module   => 'Zevenet::Farm::L4xNAT::Config::Ext',
							  func     => 'modifyLogsParam',
							  args     => [$farmname, $json_obj->{ logs }],
							  just_ret => 1,
			);
			if ( defined $msg && length $msg )
			{
				return &httpErrorResponse( code => 400, desc => $desc, msg => $msg );
			}
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
				 params      => $json_obj
	};

	&httpResponse( { code => 200, body => $body } );
}

1;
