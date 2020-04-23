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

	# Flags
	my $reload_flag  = "false";
	my $restart_flag = "false";
	my $error        = "false";

	my $farmname_old;

	# Check that the farm exists
	if ( !&getFarmExists( $farmname ) )
	{
		my $msg = "The farm '$farmname' does not exist.";
		&httpErrorResponse( code => 404, desc => $desc, msg => $msg );
	}

	# Get current vip & vport
	my $vip   = &getFarmVip( "vip",  $farmname );
	my $vport = &getFarmVip( "vipp", $farmname );
	my $changedname = "false";
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
		unless ( &getFarmStatus( $farmname ) eq 'down' )
		{
			my $msg = 'Cannot change the farm name while the farm is running';
			&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
		}

		#Check if farmname has correct characters (letters, numbers and hyphens)
		unless ( $json_obj->{ newfarmname } =~ /^[a-zA-Z0-9\-]+$/ )
		{
			my $msg = "Invalid newfarmname value.";
			&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
		}

		if ( $json_obj->{ newfarmname } eq $farmname )
		{
			my $msg = "The new farm name is the current name.";
			&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
		}

		#Check if the new farm's name alredy exists
		my $newffile = &getFarmFile( $json_obj->{ newfarmname } );
		if ( $newffile != -1 )
		{
			my $msg = "The farm $json_obj->{newfarmname} already exists, try another name.";
			&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
		}

		my $oldfstat = &runFarmStop( $farmname, "true" );
		if ( $oldfstat != 0 )
		{
			my $msg = "The farm is not disabled, are you sure it's running?";
			&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
		}

		# Change farm name
		my $fnchange = &setNewFarmName( $farmname, $json_obj->{ newfarmname } );
		$changedname = "true";

		if ( $fnchange == -1 )
		{
			my $msg =
			  "The name of the farm can't be modified, delete the farm and create a new one.";
			&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
		}
		elsif ( $fnchange == -2 )
		{
			my $msg = "Invalid newfarmname, the new name can't be empty.";
			&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
		}

		$farmname_old = $farmname;
		$farmname     = $json_obj->{ newfarmname };
	}

	# Modify Backend Connection Timeout
	if ( exists ( $json_obj->{ contimeout } ) )
	{
		if ( $json_obj->{ contimeout } !~ /^\d+$/ )
		{
			my $msg = ( "Invalid contimeout value." );
			&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
		}

		my $status = &setFarmConnTO( $json_obj->{ contimeout }, $farmname );
		if ( $status == -1 )
		{
			my $msg = "Some errors happened trying to modify the contimeout.";
			&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
		}

		$restart_flag = "true";
	}

	# Modify Backend Respone Timeout
	if ( exists ( $json_obj->{ restimeout } ) )
	{
		if ( $json_obj->{ restimeout } !~ /^\d+$/ )
		{
			my $msg = "Invalid restimeout value.";
			&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
		}

		my $status = &setFarmTimeout( $json_obj->{ restimeout }, $farmname );
		if ( $status == -1 )
		{
			my $msg = "Some errors happened trying to modify the restimeout.";
			&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
		}

		$restart_flag = "true";
	}

	# Modify Frequency To Check Resurrected Backends
	if ( exists ( $json_obj->{ resurrectime } ) )
	{
		if ( $json_obj->{ resurrectime } !~ /^\d+$/ )
		{
			my $msg = "Invalid resurrectime value.";
			&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
		}

		my $status = &setFarmBlacklistTime( $json_obj->{ resurrectime }, $farmname );
		if ( $status == -1 )
		{
			my $msg = "Some errors happened trying to modify the resurrectime.";
			&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
		}

		$restart_flag = "true";
	}

	# Modify Client Request Timeout
	if ( exists ( $json_obj->{ reqtimeout } ) )
	{
		if ( $json_obj->{ reqtimeout } !~ /^\d+$/ )
		{
			my $msg = "Invalid reqtimeout value.";
			&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
		}

		my $status = &setFarmClientTimeout( $json_obj->{ reqtimeout }, $farmname );
		if ( $status == -1 )
		{
			my $msg = "Some errors happened trying to modify the reqtimeout.";
			&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
		}

		$restart_flag = "true";
	}

	# Modify Rewrite Location Headers
	if ( exists ( $json_obj->{ rewritelocation } ) )
	{
		if (
			 $json_obj->{ rewritelocation } !~ /^(?:disabled|enabled|enabled-backends)$/ )
		{
			my $msg = "Invalid rewritelocation value.";
			&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
		}

		my $rewritelocation = 0;
		if    ( $json_obj->{ rewritelocation } eq "disabled" ) { $rewritelocation = 0; }
		elsif ( $json_obj->{ rewritelocation } eq "enabled" )  { $rewritelocation = 1; }
		elsif ( $json_obj->{ rewritelocation } eq "enabled-backends" )
		{
			$rewritelocation = 2;
		}

		my $status = &setFarmRewriteL( $farmname, $rewritelocation );
		if ( $status == -1 )
		{
			my $msg = "Some errors happened trying to modify the rewritelocation.";
			&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
		}

		$restart_flag = "true";
	}

	if ( $eload )
	{
		# Enable or disable ignore 100 continue header
		if ( exists ( $json_obj->{ ignore_100_continue } ) )
		{
			if ( $json_obj->{ ignore_100_continue } !~ /^(?:true|false)$/ )
			{
				my $msg = "Invalid ignore_100_continue value.";
				&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
			}

			my $action = 0;
			$action = 1 if ( $json_obj->{ ignore_100_continue } =~ /^true$/ );

			my $newaction = &eload(
									module => 'Zevenet::Farm::HTTP::Ext',
									func   => 'getHTTPFarm100Continue',
									args   => [$farmname],
			);

			if ( $newaction != $action )
			{
				my $status = &eload(
									 module => 'Zevenet::Farm::HTTP::Ext',
									 func   => 'setHTTPFarm100Continue',
									 args   => [$farmname, $action],
				);

				if ( $status == -1 )
				{
					my $msg = "Some errors happened trying to modify the certname.";
					&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
				}

				$restart_flag = "true";
			}
		}
	}

	# Modify HTTP Verbs Accepted
	if ( exists ( $json_obj->{ httpverb } ) )
	{
		if ( $json_obj->{ httpverb } !~
			/^(?:standardHTTP|extendedHTTP|standardWebDAV|MSextWebDAV|MSRPCext|optionsHTTP)$/
		  )
		{
			my $msg = "Invalid httpverb value.";
			&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
		}

		my $httpverb = 0;

		if    ( $json_obj->{ httpverb } eq "standardHTTP" )   { $httpverb = 0; }
		elsif ( $json_obj->{ httpverb } eq "extendedHTTP" )   { $httpverb = 1; }
		elsif ( $json_obj->{ httpverb } eq "standardWebDAV" ) { $httpverb = 2; }
		elsif ( $json_obj->{ httpverb } eq "MSextWebDAV" )    { $httpverb = 3; }
		elsif ( $json_obj->{ httpverb } eq "MSRPCext" )       { $httpverb = 4; }
		elsif ( $json_obj->{ httpverb } eq "optionsHTTP" )    { $httpverb = 5; }

		my $status = &setFarmHttpVerb( $httpverb, $farmname );
		if ( $status == -1 )
		{
			my $msg = "Some errors happened trying to modify the httpverb.";
			&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
		}

		$restart_flag = "true";
	}

	#Modify Error 414
	if ( exists ( $json_obj->{ error414 } ) )
	{
		my $status = &setFarmErr( $farmname, $json_obj->{ error414 }, "414" );
		if ( $status == -1 )
		{
			my $msg = "Some errors happened trying to modify the error414.";
			&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
		}

		$restart_flag = "true";
	}

	#Modify Error 500
	if ( exists ( $json_obj->{ error500 } ) )
	{
		my $status = &setFarmErr( $farmname, $json_obj->{ error500 }, "500" );
		if ( $status == -1 )
		{
			my $msg = "Some errors happened trying to modify the error500.";
			&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
		}

		$restart_flag = "true";
	}

	#Modify Error 501
	if ( exists ( $json_obj->{ error501 } ) )
	{
		my $status = &setFarmErr( $farmname, $json_obj->{ error501 }, "501" );
		if ( $status == -1 )
		{
			my $msg = "Some errors happened trying to modify the error501.";
			&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
		}

		$restart_flag = "true";
	}

	#Modify Error 503
	if ( exists ( $json_obj->{ error503 } ) )
	{
		my $status = &setFarmErr( $farmname, $json_obj->{ error503 }, "503" );
		if ( $status == -1 )
		{
			my $msg = "Some errors happened trying to modify the error503.";
			&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
		}

		$restart_flag = "true";
	}

	# Modify Farm Listener
	if ( exists ( $json_obj->{ listener } ) )
	{
		if ( $json_obj->{ listener } !~ /^(?:http|https)$/ )
		{
			my $msg = "Invalid listener value.";
			&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
		}

		my $status = &setFarmListen( $farmname, $json_obj->{ listener } );
		if ( $status == -1 )
		{
			my $msg = "Some errors happened trying to modify the listener.";
			&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
		}

		$restart_flag = "true";
	}

	# Modify HTTPS Params
	my $farmtype = &getFarmType( $farmname );

	if ( $farmtype eq "https" )
	{
		require Zevenet::Farm::HTTP::HTTPS;

		# Modify Ciphers
		if ( exists ( $json_obj->{ ciphers } ) )
		{
			if ( !&getValidFormat( 'ciphers', $json_obj->{ ciphers } ) )
			{
				my $msg = "Invalid ciphers value.";
				&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
			}

			my $ssloffloading_error = 0;
			my $ciphers;

			if ( $json_obj->{ ciphers } eq "all" )
			{
				$ciphers = "cipherglobal";
			}
			elsif ( $json_obj->{ ciphers } eq "customsecurity" )
			{
				$ciphers = "ciphercustom";
			}
			elsif ( $json_obj->{ ciphers } eq "highsecurity" ) { $ciphers = "cipherpci"; }
			elsif ( $json_obj->{ ciphers } eq "ssloffloading" )
			{
				if ( $eload )
				{
					my $ssloff = &eload( module => 'Zevenet::Farm::HTTP::HTTPS::Ext',
										 func   => 'getFarmCipherSSLOffLoadingSupport', );

					unless ( $ssloff )
					{
						my $msg = "The CPU does not support SSL offloading.";
						&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
					}

					$ciphers = "cipherssloffloading";
				}
				else
				{
					my $msg = "SSL offloading cipher profile not available.";
					&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
				}
			}

			my $status = &setFarmCipherList( $farmname, $ciphers );
			$restart_flag = "true" if ( $status != -1 );
		}

		# Get ciphers value
		my $cipher = &getFarmCipherSet( $farmname );
		chomp ( $cipher );

		if ( $cipher eq "ciphercustom" )
		{
			# Modify Customized Ciphers
			if ( exists ( $json_obj->{ cipherc } ) )
			{
				my $cipherc = $json_obj->{ cipherc };
				$cipherc =~ s/\ //g;

				if ( $cipherc eq '' )
				{
					my $msg = "Invalid cipherc, can't be blank.";
					&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
				}

				my $status = &setFarmCipherList( $farmname, $cipher, $cipherc );
				if ( $status == -1 )
				{
					my $msg = "Some errors happened trying to modify the cipherc.";
					&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
				}

				$restart_flag = "true";
			}
		}

		# Add Certificate to SNI list
		if ( exists ( $json_obj->{ certname } ) )
		{
			my $status;
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

			$restart_flag = "true";
		}

		# Disable security protocol
		my @protocols_ssl_keys = (
								   "disable_sslv2", "disable_sslv3",
								   "disable_tlsv1", "disable_tlsv1_1",
								   "disable_tlsv1_2"
		);
		foreach my $key_ssl ( @protocols_ssl_keys )
		{
			if ( grep ( /^$key_ssl$/, keys %{ $json_obj } ) )
			{
				my $ssl_proto;
				my $action = -1;
				$action = 1 if ( $json_obj->{ $key_ssl } eq "true" );
				$action = 0 if ( $json_obj->{ $key_ssl } eq "false" );

				$ssl_proto = "SSLv2"   if ( $key_ssl eq "disable_sslv2" );
				$ssl_proto = "SSLv3"   if ( $key_ssl eq "disable_sslv3" );
				$ssl_proto = "TLSv1"   if ( $key_ssl eq "disable_tlsv1" );
				$ssl_proto = "TLSv1_1" if ( $key_ssl eq "disable_tlsv1_1" );
				$ssl_proto = "TLSv1_2" if ( $key_ssl eq "disable_tlsv1_2" );

				if ( $action == -1 )
				{
					my $msg = "Error, the value is not valid for parameter $key_ssl.";
					&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
				}

				if ( $action != &getHTTPFarmDisableSSL( $farmname, $ssl_proto ) )
				{
					my $status = &setHTTPFarmDisableSSL( $farmname, $ssl_proto, $action );
					if ( $status == -1 )
					{
						my $msg = "Some errors happened trying to modify the certname.";
						&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
					}

					$restart_flag = "true";
				}
			}
		}
	}
	else
	{
		if (    exists ( $json_obj->{ ciphers } )
			 || exists ( $json_obj->{ cipherc } )
			 || exists ( $json_obj->{ certname } ) )
		{
			my $msg = "To modify ciphers, chiperc or certname, listener must be https.";
			&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
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

	if ( exists ( $json_obj->{ vport } ) )
	{
		if ( !$json_obj->{ vport } =~ /^\d+$/ )
		{
			my $msg = "Invalid port value.";
			&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
		}
	}

	# Modify only vip
	if ( exists ( $json_obj->{ vip } ) && !exists ( $json_obj->{ vport } ) )
	{
		my $status = &setFarmVirtualConf( $json_obj->{ vip }, $vport, $farmname );
		if ( $status == -1 )
		{
			my $msg = "Invalid vip value.";
			&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
		}

		$restart_flag = "true";
	}

	# Modify only vport
	if ( exists ( $json_obj->{ vport } ) && !exists ( $json_obj->{ vip } ) )
	{
		my $status = &setFarmVirtualConf( $vip, $json_obj->{ vport }, $farmname );
		if ( $status == -1 )
		{
			my $msg = "Invalid port value.";
			&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
		}

		$restart_flag = "true";
	}

	# Modify both vip & vport
	if ( exists ( $json_obj->{ vip } ) && exists ( $json_obj->{ vport } ) )
	{
		my $status =
		  &setFarmVirtualConf( $json_obj->{ vip }, $json_obj->{ vport }, $farmname );
		if ( $status == -1 )
		{
			my $msg = "Invalid port or vip value.";
			&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
		}

		$restart_flag = "true";
	}

	&zenlog( "Success, some parameters have been changed in farm $farmname.",
			 "info", "LSLB" );

	# set numeric values to numeric type
	for my $key ( keys %{ $json_obj } )
	{
		if ( $json_obj->{ $key } =~ /^\d+$/ )
		{
			$json_obj->{ $key } += 0;
		}
	}

	if ( $json_obj->{ listener } eq 'https' )
	{
		# certlist
		my @certlist;
		my @cnames;

		if ( $eload )
		{
			@cnames = &eload(
							  module => 'Zevenet::Farm::HTTP::HTTPS::Ext',
							  func   => 'getFarmCertificatesSNI',
							  args   => [$farmname],
			);
		}
		else
		{
			@cnames = ( &getFarmCertificate( $farmname ) );
		}

		my $elem = scalar @cnames;

		for ( my $i = 0 ; $i < $elem ; $i++ )
		{
			push @certlist, { file => $cnames[$i], id => $i + 1 };
		}

		$json_obj->{ certlist } = \@certlist;

		# cipherlist
		unless ( exists $json_obj->{ cipherc } )
		{
			$json_obj->{ cipherc } = &getFarmCipherList( $farmname );
		}

		# cipherset
		unless ( exists $json_obj->{ ciphers } )
		{
			chomp ( $json_obj->{ ciphers } = &getFarmCipherSet( $farmname ) );

			if ( $json_obj->{ ciphers } eq "cipherglobal" )
			{
				$json_obj->{ ciphers } = "all";
			}
		}

		# disabled protocols
		$json_obj->{ disable_sslv2 } =
		  ( &getHTTPFarmDisableSSL( $farmname, "SSLv2" ) ) ? "true" : "false";
		$json_obj->{ disable_sslv3 } =
		  ( &getHTTPFarmDisableSSL( $farmname, "SSLv3" ) ) ? "true" : "false";
		$json_obj->{ disable_tlsv1 } =
		  ( &getHTTPFarmDisableSSL( $farmname, "TLSv1" ) ) ? "true" : "false";
		$json_obj->{ disable_tlsv1_1 } =
		  ( &getHTTPFarmDisableSSL( $farmname, "TLSv1_1" ) ) ? "true" : "false";
		$json_obj->{ disable_tlsv1_2 } =
		  ( &getHTTPFarmDisableSSL( $farmname, "TLSv1_2" ) ) ? "true" : "false";
	}

	if ( $reload_ipds )
	{

		if ( $eload )
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
	}

	my $body = {
				 description => $desc,
				 params      => $json_obj,
	};

	if ( $restart_flag eq "true" && &getFarmStatus( $farmname ) eq 'up' )
	{
		if ( &getGlobalConfiguration( 'proxy_ng' ) ne 'true' )
		{
			&setFarmRestart( $farmname );
			$body->{ status } = 'needed restart';
		}
		else
		{
			&runFarmReload( $farmname );
			&eload(
					module => 'Zevenet::Cluster',
					func   => 'runZClusterRemoteManager',
					args   => ['farm', 'reload', $farmname],
			) if ( $eload );
		}
	}

	&httpResponse( { code => 200, body => $body } );
}

1;
