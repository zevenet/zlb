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
use Zevenet::Farm::Config;
use Zevenet::Farm::Action;

my $eload;
if ( eval { require Zevenet::ELoad; } )
{
	$eload = 1;
}

# PUT /farms/<farmname> Modify a http|https Farm
sub modify_http_farm    # ( $json_obj, $farmname )
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $json_obj = shift;
	my $farmname = shift;

	my $desc = "Modify HTTP farm $farmname";

	my $params = {
		"newfarmname" => {
						   'valid_format' => 'farm_name',
						   'non_blank'    => 'true',
		},
		"vport" => {
					 'interval'  => "1,65535",
					 'non_blank' => 'true',
		},
		"vip" => {
				   'valid_format' => 'ip_addr',
				   'non_blank'    => 'true',
				   'format_msg'   => 'expects an IP'
		},
		"contimeout" => {
						  'valid_format' => 'natural_num',
						  'non_blank'    => 'true',
						  'format_msg'   => 'expects a natural number'
		},
		"restimeout" => {
						  'valid_format' => 'natural_num',
						  'non_blank'    => 'true',
						  'format_msg'   => 'expects a natural number'
		},
		"resurrectime" => {
							'valid_format' => 'natural_num',
							'non_blank'    => 'true',
							'format_msg'   => 'expects a natural number'
		},
		"reqtimeout" => {
						  'valid_format' => 'natural_num',
						  'non_blank'    => 'true',
						  'format_msg'   => 'expects a natural number'
		},
		"rewritelocation" => {
							   'values'    => ["disabled", "enabled", "enabled-backends"],
							   'non_blank' => 'true',
		},
		"httpverb" => {
			'values' =>
			  ["standardHTTP", "extendedHTTP", "standardWebDAV", "MSextWebDAV", "MSRPCext"],
			'non_blank' => 'true',
		},
		"error414" => {
						'regex' => ".*",
		},
		"error500" => {
						'regex' => ".*",
		},
		"error501" => {
						'regex' => ".*",
		},
		"error503" => {
						'regex' => ".*",
		},
		"listener" => {
						'values'    => ["http", "https"],
						'non_blank' => 'true',
		},
		"ciphers" => {
					   'values'    => ["all", "highsecurity", "customsecurity"],
					   'non_blank' => 'true',
					   'listener'  => 'https',
		},
		"cipherc" => {
					   'non_blank' => 'true',
					   'listener'  => 'https',
		},
		"certname" => {
						'valid_format' => 'certificate',
						'non_blank'    => 'true',
						'listener'     => 'https',
		},
		"disable_sslv2" => {
							 'values'    => ["true", "false"],
							 'non_blank' => 'true',
							 'listener'  => 'https',
		},
		"disable_sslv3" => {
							 'values'    => ["true", "false"],
							 'non_blank' => 'true',
							 'listener'  => 'https',
		},
		"disable_tlsv1" => {
							 'values'    => ["true", "false"],
							 'non_blank' => 'true',
							 'listener'  => 'https',
		},
		"disable_tlsv1_1" => {
							   'values'    => ["true", "false"],
							   'non_blank' => 'true',
							   'listener'  => 'https',
		},
		"disable_tlsv1_2" => {
							   'values'    => ["true", "false"],
							   'non_blank' => 'true',
							   'listener'  => 'https',
		},
	};

	if ( $eload )
	{
		$params->{ logs } = {
							  'values'    => ["true", "false"],
							  'non_blank' => 'true',
		};
		$params->{ ignore_100_continue } = {
											 'values'    => ["true", "false"],
											 'non_blank' => 'true',
		};
		push @{ $params->{ ciphers }->{ values } }, "ssloffloading";
	}

	# Check allowed parameters
	my $error_msg = &checkZAPIParams( $json_obj, $params );
	return &httpErrorResponse( code => 400, desc => $desc, msg => $error_msg )
	  if ( $error_msg );

	# Get current conf
	my $farm_st = &getFarmStruct( $farmname );

	# Flags
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
		}
	}

	######## Functions
	# Modify Farm's Name
	if ( exists ( $json_obj->{ newfarmname } ) )
	{
		unless ( $farm_st->{ status } eq 'down' )
		{
			my $msg = 'Cannot change the farm name while the farm is running';
			&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
		}

		#Check if the new farm's name alredy exists
		if ( &getFarmExists( $json_obj->{ newfarmname } ) )
		{
			my $msg = "The farm $json_obj->{newfarmname} already exists, try another name.";
			&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
		}

		# Change farm name
		if ( &setNewFarmName( $farmname, $json_obj->{ newfarmname } ) )
		{
			my $msg = "Error modifying the farm name.";
			&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
		}

		$farmname = $json_obj->{ newfarmname };
	}

	# Modify Backend Connection Timeout
	if ( exists $json_obj->{ contimeout } )
	{
		if ( &setFarmConnTO( $json_obj->{ contimeout }, $farmname ) == -1 )
		{
			my $msg = "Some errors happened trying to modify the contimeout.";
			&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
		}
	}

	# Modify Backend Respone Timeout
	if ( exists ( $json_obj->{ restimeout } ) )
	{
		if ( &setFarmTimeout( $json_obj->{ restimeout }, $farmname ) == -1 )
		{
			my $msg = "Some errors happened trying to modify the restimeout.";
			&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
		}
	}

	# Modify Frequency To Check Resurrected Backends
	if ( exists ( $json_obj->{ resurrectime } ) )
	{
		if ( &setFarmBlacklistTime( $json_obj->{ resurrectime }, $farmname ) == -1 )
		{
			my $msg = "Some errors happened trying to modify the resurrectime.";
			&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
		}
	}

	# Modify Client Request Timeout
	if ( exists ( $json_obj->{ reqtimeout } ) )
	{
		if ( &setFarmClientTimeout( $json_obj->{ reqtimeout }, $farmname ) == -1 )
		{
			my $msg = "Some errors happened trying to modify the reqtimeout.";
			&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
		}
	}

	# Modify Rewrite Location Headers
	if ( exists ( $json_obj->{ rewritelocation } ) )
	{
		my $rewritelocation = 0;
		if    ( $json_obj->{ rewritelocation } eq "disabled" ) { $rewritelocation = 0; }
		elsif ( $json_obj->{ rewritelocation } eq "enabled" )  { $rewritelocation = 1; }
		elsif ( $json_obj->{ rewritelocation } eq "enabled-backends" )
		{
			$rewritelocation = 2;
		}

		if ( &setFarmRewriteL( $farmname, $rewritelocation ) == -1 )
		{
			my $msg = "Some errors happened trying to modify the rewritelocation.";
			&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
		}
	}

	if ( $eload )
	{
		# Enable the log connection tracking
		if ( exists ( $json_obj->{ logs } ) )
		{
			my $status = &eload(
								 module => 'Zevenet::Farm::HTTP::Ext',
								 func   => 'setHTTPFarmLogs',
								 args   => [$farmname, $json_obj->{ logs }],
			);

			if ( $status )
			{
				my $msg = "Some errors happened trying to modify the log parameter.";
				&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
			}
		}

		# Enable or disable ignore 100 continue header
		if ( exists ( $json_obj->{ ignore_100_continue } )
			 and
			 ( $json_obj->{ ignore_100_continue } ne $farm_st->{ ignore_100_continue } )
		  )    # this is a bugfix
		{
			my $action = ( $json_obj->{ ignore_100_continue } eq "true" ) ? 1 : 0;
			my $status = &eload(
								 module => 'Zevenet::Farm::HTTP::Ext',
								 func   => 'setHTTPFarm100Continue',
								 args   => [$farmname, $action],
			);

			if ( $status == -1 )
			{
				my $msg =
				  "Some errors happened trying to modify the ignore_100_continue parameter.";
				&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
			}
		}
	}

	# Modify HTTP Verbs Accepted
	if ( exists ( $json_obj->{ httpverb } ) )
	{
		my $code = &getHTTPVerbCode( $json_obj->{ httpverb } );
		if ( &setFarmHttpVerb( $code, $farmname ) == -1 )
		{
			my $msg = "Some errors happened trying to modify the httpverb.";
			&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
		}
	}

	#Modify Error 414
	if ( exists ( $json_obj->{ error414 } ) )
	{
		if ( &setFarmErr( $farmname, $json_obj->{ error414 }, "414" ) == -1 )
		{
			my $msg = "Some errors happened trying to modify the error414.";
			&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
		}
	}

	#Modify Error 500
	if ( exists ( $json_obj->{ error500 } ) )
	{
		if ( &setFarmErr( $farmname, $json_obj->{ error500 }, "500" ) == -1 )
		{
			my $msg = "Some errors happened trying to modify the error500.";
			&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
		}
	}

	#Modify Error 501
	if ( exists ( $json_obj->{ error501 } ) )
	{
		if ( &setFarmErr( $farmname, $json_obj->{ error501 }, "501" ) == -1 )
		{
			my $msg = "Some errors happened trying to modify the error501.";
			&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
		}
	}

	#Modify Error 503
	if ( exists ( $json_obj->{ error503 } ) )
	{
		if ( &setFarmErr( $farmname, $json_obj->{ error503 }, "503" ) == -1 )
		{
			my $msg = "Some errors happened trying to modify the error503.";
			&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
		}
	}

	# Modify Farm Listener
	if ( exists ( $json_obj->{ listener } ) )
	{
		if ( &setFarmListen( $farmname, $json_obj->{ listener } ) == -1 )
		{
			my $msg = "Some errors happened trying to modify the listener.";
			&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
		}

		$farm_st->{ listener } = $json_obj->{ listener };    # update listener type
	}

	# Discard parameters of the HTTPS listener when it is not configured
	if ( $farm_st->{ listener } ne "https" )
	{
		foreach my $key ( keys %{ $params } )
		{
			if (     exists $json_obj->{ $key }
				 and exists $params->{ $key }->{ listener }
				 and $params->{ $key }->{ listener } eq 'https' )
			{
				my $msg =
				  "The farm listener has to be 'HTTPS' to configure the parameter '$key'.";
				&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
			}
		}
	}

	# Modify HTTPS Params
	if ( $farm_st->{ listener } eq "https" )
	{
		require Zevenet::Farm::HTTP::HTTPS;

		# Cipher groups
		# API parameter => library parameter
		my %c = (
				  all            => "cipherglobal",
				  customsecurity => "ciphercustom",
				  highsecurity   => "cipherpci",
				  ssloffloading  => "cipherssloffloading",
		);
		my $ciphers_lib;

		# Modify Ciphers
		if ( exists ( $json_obj->{ ciphers } ) )
		{
			$ciphers_lib = $c{ $json_obj->{ ciphers } };

			my $ssloff = &eload( module => 'Zevenet::Farm::HTTP::HTTPS::Ext',
								 func   => 'getFarmCipherSSLOffLoadingSupport', );

			unless ( $ssloff )
			{
				&zenlog( "The CPU does not support SSL offloading.", "warning", "system" );
			}

			if ( &setFarmCipherList( $farmname, $ciphers_lib ) == -1 )
			{
				my $msg = "Error modifying ciphers.";
				&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
			}

			$farm_st->{ ciphers } = $json_obj->{ ciphers };    # update ciphers value
		}

		# Modify Customized Ciphers
		if ( exists ( $json_obj->{ cipherc } ) )
		{
			$ciphers_lib = $c{ $farm_st->{ ciphers } };

			if ( $farm_st->{ ciphers } eq "customsecurity" )
			{
				$json_obj->{ cipherc } =~ s/\ //g;
				if (
					 &setFarmCipherList( $farmname, $ciphers_lib, $json_obj->{ cipherc } ) == -1 )
				{
					my $msg = "Some errors happened trying to modify the cipherc.";
					&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
				}
			}
			else
			{
				my $msg =
				  "'ciphers' has to be 'customsecurity' to set the 'cipherc' parameter.";
				&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
			}
		}

		# Add Certificate to SNI list
		if ( exists ( $json_obj->{ certname } ) )
		{
			my $status;
			my $configdir = &getGlobalConfiguration( 'configdir' );

			if ( !-f "$configdir/$json_obj->{ certname }" )
			{
				my $msg =
				  "The certificate $json_obj->{ certname } has to be uploaded to use it in a farm.";
				&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
			}

			if ( $eload )
			{
				$status = &eload(
								  module => 'Zevenet::Farm::HTTP::HTTPS::Ext',
								  func   => 'setFarmCertificateSNI',
								  args   => [$json_obj->{ certname }, $farmname],
				);
			}
			else
			{
				$status = &setFarmCertificate( $json_obj->{ certname }, $farmname );
			}

			if ( $status == -1 )
			{
				my $msg = "Some errors happened trying to modify the certname.";
				&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
			}
		}

		# Disable security protocol
		# API parameter => l7 proxy parameter
		my %ssl_proto_hash = (
							   "disable_sslv2"   => "SSLv2",
							   "disable_sslv3"   => "SSLv3",
							   "disable_tlsv1"   => "TLSv1",
							   "disable_tlsv1_1" => "TLSv1_1",
							   "disable_tlsv1_2" => "TLSv1_2",
		);

		my %bool_to_int = (
							"false" => 0,
							"true"  => 1,
		);

		my $action;
		my $ssl_proto;
		foreach my $key_ssl ( keys %ssl_proto_hash )
		{
			next if ( !exists $json_obj->{ $key_ssl } );
			next
			  if ( $json_obj->{ $key_ssl } eq $farm_st->{ $key_ssl } )
			  ;    # skip when the farm already has the request value

			$action = $bool_to_int{ $json_obj->{ $key_ssl } };
			$ssl_proto = $ssl_proto_hash{ $key_ssl } if exists $ssl_proto_hash{ $key_ssl };

			if ( &setHTTPFarmDisableSSL( $farmname, $ssl_proto, $action ) == -1 )
			{
				my $msg = "Some errors happened trying to modify $key_ssl.";
				&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
			}
		}
	}

	if ( exists ( $json_obj->{ vip } ) )
	{
		# the ip must exist in some interface
		require Zevenet::Net::Interface;
		unless ( &getIpAddressExists( $json_obj->{ vip } ) )
		{
			my $msg = "The vip IP must exist in some interface.";
			&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
		}
	}

	# Modify vip and vport
	if ( exists ( $json_obj->{ vip } ) or exists ( $json_obj->{ vport } ) )
	{
		my $vip   = $json_obj->{ vip }   // $farm_st->{ vip };
		my $vport = $json_obj->{ vport } // $farm_st->{ vport };

		if ( &setFarmVirtualConf( $vip, $vport, $farmname ) )
		{
			my $msg = "Could not set the virtual configuration.";
			return &httpErrorResponse( code => 400, desc => $desc, msg => $msg );
		}
	}

	&zenlog( "Success, some parameters have been changed in farm $farmname.",
			 "info", "LSLB" );

	# Return the received json object updated.
	require Zevenet::API40::Farm::Output::HTTP;

	#~ my $farm_upd = &getFarmStruct( $farmname );
	#~ foreach my $key ( keys %{ $json_obj } )
	#~ {
	#~ $json_obj->{ $key } = $farm_upd->{ $key };
	#~ }

	my $out_obj = &getHTTPOutFarm( $farmname );

	if ( $reload_ipds and $eload )
	{
		&eload(
				module => 'Zevenet::IPDS::Base',
				func   => 'runIPDSStartByFarm',
				args   => [$farmname],
		);

		&eload(
				module => 'Zevenet::Cluster',
				func   => 'runZClusterRemoteManager',
				args   => ['ipds', 'start', $farmname],
		);
	}

	my $body = {
				 description => $desc,
				 params      => $out_obj,
	};

	if ( exists $json_obj->{ newfarmname } )
	{
		$body->{ params }->{ newfarmname } = $json_obj->{ newfarmname };
	}

	if ( $farm_st->{ status } ne 'down' )
	{
		&setFarmRestart( $farmname );
		$body->{ status } = 'needed restart';
		$body->{ info } =
		  "There're changes that need to be applied, stop and start farm to apply them!";
	}

	&httpResponse( { code => 200, body => $body } );
}

1;
