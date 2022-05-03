#!/usr/bin/perl
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

my $eload;
if ( eval { require Zevenet::ELoad; } )
{
	$eload = 1;
}

=begin nd
Function: getLetsencryptConfigPath

	Returns the dirpath for Letsencrypt Config

Parameters:
	none - .

Returns:
	string -  dir path.
=cut

sub getLetsencryptConfigPath    # ( )
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	return &getGlobalConfiguration( 'le_config_path' );
}

=begin nd
Function: getLetsencryptConfig

	Returns the Letsencrypt Config

Parameters:
	none - .

Returns:
	Hash ref - Letsencrypt Configuration
=cut

sub getLetsencryptConfig    # ( )
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $le_conf_re = {};
	$le_conf_re->{ email } = &getGlobalConfiguration( 'le_email' );
	return $le_conf_re;
}

=begin nd
Function: setLetsencryptConfig

	Set the Letsencrypt Config

Parameters:
	Hash ref - .

Returns:
	Integer - 0 on succesfull, otherwise on error.
=cut

sub setLetsencryptConfig    # ( $le_conf_re )
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $le_conf_re = shift;
	my $rc         = 0;
	$rc = &setGlobalConfiguration( 'le_email', $le_conf_re->{ email } );
	return $rc;
}

=begin nd
Function: getLetsencryptCertificates

	Returns Letsencrypt Certificates

Parameters:
	le_cert_name - String. LE Certificate Name. None means all certificates.

Returns:
	Hash ref - Letsencrypt Certificates
=cut

sub getLetsencryptCertificates    # ( )
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $le_cert_name = shift;
	my $le_certs_ref = [];

	my $le_config_path = &getLetsencryptConfigPath();
	my $le_live_path   = $le_config_path . "live";

	my $certs;
	if ( defined $le_cert_name )
	{
		push @{ $certs }, "$le_cert_name";
	}
	else
	{
		opendir ( DIR, "$le_live_path" );
		while ( defined ( my $file = readdir DIR ) )
		{
			next if $file eq ".";
			next if $file eq "..";
			push @{ $certs }, $file if -d "$le_live_path/$file";
		}
		closedir ( DIR );
	}

	require Crypt::OpenSSL::X509;
	my $cert_ref;
	my $domains;
	foreach my $cert ( @{ $certs } )
	{
		# name
		$cert_ref->{ name } = $cert;

		# certificate path
		my $cert_path = $le_live_path . "/" . $cert . "/fullchain.pem";
		$cert_ref->{ certpath } = $cert_path if ( -l $cert_path );

		# key path
		my $key_path = $le_live_path . "/" . $cert . "/privkey.pem";
		$cert_ref->{ keypath } = $key_path if ( -l $key_path );

		# domains

		eval {
			my $x509 = Crypt::OpenSSL::X509->new_from_file( $cert_ref->{ certpath } );
			my $exts = $x509->extensions_by_name();
			if ( defined $exts->{ "subjectAltName" } )
			{
				my $value = $exts->{ "subjectAltName" }->to_string() . ", ";
				@{ $domains } = $value =~ /(?:DNS:(.*?), )/g;
			}
		};
		$cert_ref->{ domains } = $domains;

		push @{ $le_certs_ref }, $cert_ref if defined $domains;
		$cert_ref = undef;
		$domains  = undef;
	}

	return $le_certs_ref;
}

=begin nd
Function: getLetsencryptCertificateInfo

	Returns the Letsencrypt no Wildcard Certificates Info

Parameters:
	le_cert_name . LE Certificate name

Returns:
	Hash ref - Letsencrypt Certificate Info
=cut

sub getLetsencryptCertificateInfo    # ( $le_cert_name )
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $le_cert_name = shift;
	my $cert_ref     = {};

	my $cert_info = &getLetsencryptCertificates( $le_cert_name );

	return if ( !$cert_info );

	$cert_info = @{ $cert_info }[0];

	require Crypt::OpenSSL::X509;
	my $status = "unknown";
	my $CN     = "";
	my $ISSUER = "";
	my $x509;
	my @domains;
	eval {
		$x509 = Crypt::OpenSSL::X509->new_from_file( $cert_info->{ certpath } );
		my $time_offset = 60 * 60 * 24 * 15;    # 15 days
		if ( $x509->checkend( 0 ) ) { $status = 'expired' }
		else
		{
			$status = ( $x509->checkend( $time_offset ) ) ? 'about to expire' : 'valid';
		}
		if ( defined $x509->subject_name()->get_entry_by_type( 'CN' ) )
		{
			$CN = $x509->subject_name()->get_entry_by_type( 'CN' )->value;
		}
		if ( defined $x509->issuer_name() )
		{
			foreach my $entry ( @{ $x509->issuer_name()->entries() } )
			{
				$ISSUER .= $entry->value() . ",";
			}
			chop $ISSUER;
		}
		my $exts = $x509->extensions_by_name();
		if ( defined $exts->{ "subjectAltName" } )
		{
			my $value = $exts->{ "subjectAltName" }->to_string() . ", ";
			@domains = $value =~ /(?:DNS:(.*?), )/g;
		}

	};
	$cert_ref->{ file }     = $cert_info->{ certpath };
	$cert_ref->{ type }     = 'LE Certificate';
	$cert_ref->{ wildcard } = 'false';
	$cert_ref->{ status }   = $status;
	if ( $@ )
	{
		$cert_ref->{ CN }         = '';
		$cert_ref->{ issuer }     = '';
		$cert_ref->{ creation }   = '';
		$cert_ref->{ expiration } = '';
		$cert_ref->{ domains }    = '';
	}
	else
	{
		$cert_ref->{ CN }         = $CN;
		$cert_ref->{ issuer }     = $ISSUER;
		$cert_ref->{ creation }   = $x509->notBefore();
		$cert_ref->{ expiration } = $x509->notAfter();
		$cert_ref->{ domains }    = \@domains;
	}

	return $cert_ref;
}

=begin nd
Function: setLetsencryptFarmService

	Configure the Letsencrypt Service on a Farm

Parameters:
	farm_name - Farm Name.
	vip - Virtual IP to use with Temporal Farm.

Returns:
	Integer - 0 on succesfull, otherwise on error.
=cut

sub setLetsencryptFarmService
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $farm_name = shift;
	my $vip       = shift;

	# if no exists farm return -1,
	my $le_service = &getGlobalConfiguration( 'le_service' );
	my $le_farm    = &getGlobalConfiguration( 'le_farm' );

	require Zevenet::Farm::Core;

	# create a temporal farm
	if ( $farm_name eq $le_farm )
	{
		require Zevenet::Farm::HTTP::Factory;
		my $error = &runHTTPFarmCreate( $vip, 80, $farm_name, "HTTP" );
		if ( $error )
		{
			&zenlog( "Error creating Temporal Farm $le_farm", "Error", "LetsEncryptZ" );
			return 1;
		}

	}

	#create Letsencrypt service
	require Zevenet::Farm::HTTP::Service;
	my $error = &setFarmHTTPNewService( $farm_name, $le_service );
	if ( $error )
	{
		&zenlog( "Error creating the service $le_service", "Error", "LetsEncryptZ" );
		return 1;
	}

	# create local Web Server Backend
	require Zevenet::Farm::HTTP::Backend;
	$error =
	  &setHTTPFarmServer( "", "127.0.0.1", 80, "", "", $farm_name, $le_service );
	if ( $error )
	{
		&zenlog( "Error creating the Local Web Server backend on service $le_service",
				 "Error", "LetsEncryptZ" );
		return 2;
	}

	# create Letsencrypt URL Pattern http challenge
	$error = &setHTTPFarmVS( $farm_name, $le_service, "urlp",
							 "^/.well-known/acme-challenge/" );
	if ( $error )
	{
		&zenlog( "Error creating the URL pattern on service $le_service",
				 "Error", "LetsEncryptZ" );
		return 3;
	}

	if ( $eload )
	{
		# Move the service to posistion 0
		$error = &eload(
						 module => 'Zevenet::Farm::HTTP::Service::Ext',
						 func   => 'setHTTPFarmMoveService',
						 args   => [$farm_name, $le_service, 0],
		);
		if ( $error )
		{
			&zenlog( "Error moving the service $le_service", "Error", "LetsEncryptZ" );
			return 4;
		}
	}

	# Restart the farm
	require Zevenet::Farm::Action;
	$error = &runFarmStop( $farm_name, "" );
	if ( $error )
	{
		&zenlog( "Error stopping the farm $farm_name", "Error", "LetsEncryptZ" );
		return 5;
	}
	$error = &runFarmStart( $farm_name, "" );
	if ( $error )
	{
		&zenlog( "Error starting the farm $farm_name", "Error", "LetsEncryptZ" );
		return 6;
	}

	return 0;
}

=begin nd
Function: unsetLetsencryptFarmService

	Remove the Letsencrypt Service on a Farm

Parameters:
	farm_name - Farm Name.

Returns:
	Integer - 0 on succesfull, otherwise on error.
=cut

sub unsetLetsencryptFarmService
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $farm_name = shift;

	# if no exists farm return -1,
	my $le_service = &getGlobalConfiguration( 'le_service' );
	my $le_farm    = &getGlobalConfiguration( 'le_farm' );

	if ( $farm_name eq $le_farm )
	{
		require Zevenet::Farm::Action;
		my $error = &runFarmStop( $farm_name );
		if ( $error )
		{
			&zenlog( "Error stopping the farm $farm_name", "Error", "LetsEncryptZ" );
			return 1;
		}
		$error = &runFarmDelete( $farm_name );
		if ( $error )
		{
			&zenlog( "Error deleting the farm $farm_name", "Error", "LetsEncryptZ" );
			return 2;
		}
	}
	else
	{
		require Zevenet::Farm::HTTP::Service;
		my $error = &delHTTPFarmService( $farm_name, $le_service );
		if ( $error )
		{
			&zenlog( "Error Deleting the service $le_service on farm $farm_name",
					 "Error", "LetsEncryptZ" );
			return 3;
		}

		# Restart the farm
		require Zevenet::Farm::Action;
		$error = &runFarmStop( $farm_name, "" );
		if ( $error )
		{
			&zenlog( "Error stopping the farm $farm_name", "Error", "LetsEncryptZ" );
			return 1;
		}
		$error = &runFarmStart( $farm_name, "" );
		if ( $error )
		{
			&zenlog( "Error starting the farm $farm_name", "Error", "LetsEncryptZ" );
			return 4;
		}
	}

	return 0;
}

=begin nd
Function: runLetsencryptLocalWebserverStart

	Start Local Webserver listening on localhost:80

Parameters:
	None - .

Returns:
	Integer - 0 on succesfull, otherwise on error.
=cut

sub runLetsencryptLocalWebserverStart
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $http_dir = &getGlobalConfiguration( 'http_server_dir' );
	my $pid_file = "$http_dir/var/run/cherokee_localhost.pid";
	my $le_webserver_config_file =
	  &getGlobalConfiguration( 'le_webserver_config_file' );
	my $http_bin = &getGlobalConfiguration( 'http_bin' );

	my $status = &getLetsencryptLocalWebserverRunning();

	if ( $status == 1 )
	{
		&zenlog( "$http_bin -d -C $le_webserver_config_file", "Info", "LetsencryptZ" );
		&logAndRunBG( "$http_bin -d -C $le_webserver_config_file" );
	}
	my $timeout = 3;
	while ( !-f $pid_file and $timeout > 1 )
	{
		$timeout++;
		sleep ( 1 );
	}
	if ( !-f $pid_file )
	{
		&zenlog( "Error starting Local Web Server", "Error", "LetsEncryptZ" );
		return 1;
	}

	return 0;

}

=begin nd
Function: runLetsencryptLocalWebserverStop

	Stop Local Webserver listening on localhost:80

Parameters:
	None - .

Returns:
	Integer - 0 on succesfull, otherwise on error.
=cut

sub runLetsencryptLocalWebserverStop
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $http_dir = &getGlobalConfiguration( 'http_server_dir' );
	my $pid_file = "$http_dir/var/run/cherokee_localhost.pid";
	my $pid      = "0";
	my $kill_bin = &getGlobalConfiguration( 'kill_bin' );
	my $cat_bin  = &getGlobalConfiguration( 'cat_bin' );

	my $status = &getLetsencryptLocalWebserverRunning();

	if ( $status == 0 )
	{
		$pid = &logAndGet( "$cat_bin $pid_file" );
		my $error = &logAndRun( "$kill_bin -15 $pid" );
		if ( $error )
		{
			&zenlog( "Error stopping Local Web Server", "Error", "LetsEncryptZ" );
			return 1;
		}
		unlink $pid_file if ( -f $pid_file );
	}

	return 0;

}

=begin nd
Function: getLetsencryptLocalWebserverRunning

	Check Local Webserver is running

Parameters:
	None - .

Returns:
	Integer - 0 on succesfull, otherwise on error.
=cut

sub getLetsencryptLocalWebserverRunning
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $rc;
	my $http_dir = &getGlobalConfiguration( 'http_server_dir' );
	my $pid_file = "$http_dir/var/run/cherokee_localhost.pid";
	if ( -f $pid_file )
	{
		use Zevenet::System;
		if ( &checkPidFileRunning( $pid_file ) )
		{
			&zenlog(
					 "LetsencryptZ Local Webser is not running but PID file $pid_file exists!",
					 "warning", "LetsEncryptZ" );
			unlink $pid_file;
		}
		$rc = 0;
	}
	else
	{
		my $pgrep    = &getGlobalConfiguration( 'pgrep' );
		my $http_bin = &getGlobalConfiguration( 'http_bin' );
		my $le_webserver_config_file =
		  &getGlobalConfiguration( 'le_webserver_config_file' );
		if (
			 &logAndRunCheck( "$pgrep -f \"$http_bin -d -C $le_webserver_config_file\"" ) )
		{
			&zenlog(
					 "LetsencryptZ Local Webser is running but no PID file $pid_file exists!",
					 "warning", "LetsEncryptZ" );
			$rc = 2;
		}
		else
		{
			$rc = 1;
		}

	}

	return $rc;
}

=begin nd
Function: setLetsencryptCert

	Create ZEVENET Pem Certificate. Dot characters are replaced with underscore character.

Parameters:
	le_cert_name - Certificate main domain name.

Returns:
	Integer - 0 on succesfull, otherwise on error.
=cut

sub setLetsencryptCert    # ( $le_cert_name )
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $le_cert_name = shift;
	my $rc           = 1;

	my $le_cert_conf = &getLetsencryptCertificates( $le_cert_name );
	if ( @{ $le_cert_conf } )
	{
		$le_cert_conf = @{ $le_cert_conf }[0];
		if (     ( defined $le_cert_conf->{ certpath } )
			 and ( defined $le_cert_conf->{ keypath } ) )
		{
			if ( ( -e $le_cert_conf->{ keypath } ) and ( -e $le_cert_conf->{ certpath } ) )
			{
				my $cert_name = $le_cert_name;
				$cert_name =~ s/\./_/g;
				my $cat_bin   = &getGlobalConfiguration( 'cat_bin' );
				my $cert_dir  = &getGlobalConfiguration( 'certdir' );
				my $cert_file = "$cert_dir/${cert_name}.pem";
				&logAndRun(
					  "$cat_bin $le_cert_conf->{ keypath } $le_cert_conf->{ certpath } > $cert_file"
				);
				return 1 if ( !-f $cert_file );
				$rc = 0;
			}
		}
	}

	return $rc;
}

=begin nd
Function: runLetsencryptObtain

	Obtain a new LetsEncrypt Certificate for the Domains especified.

Parameters:
	farm_name - Farm Name where Letsencrypt will connect.
	vip - VIP where the new Farm and service is created. The virtual Port will be 80.
	domains_list - List of Domains the certificate is created for.
	test - if "true" the action simulates all the process but no certificate is created.

Returns:
	Integer - 0 on succesfull, otherwise on error.
=cut

sub runLetsencryptObtain    # ( $farm_name, $vip, $domains_list, $test )
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my ( $farm_name, $vip, $domains_list, $test ) = @_;

	return 1 if ( !$domains_list );
	return 2 if ( !$vip && !$farm_name );
	my $status;
	my $rc = 0;

	my $le_farm = &getGlobalConfiguration( 'le_farm' );
	$farm_name = $le_farm if ( !$farm_name );

	# check is a wildcard
	my $challenge = "http";

	# start local Web Server
	$status = &runLetsencryptLocalWebserverStart();

	return 1 if $status;

	# add le service
	$status = &setLetsencryptFarmService( $farm_name, $vip );
	return 2 if $status;

	# run le_binary command
	my $test_opt = "--test-cert" if ( $test eq "true" );
	my $domains_opt = "-d " . join ( ',', @{ $domains_list } );
	my $fullchain_opt =
	  "--fullchain-path " . &getGlobalConfiguration( 'le_fullchain_path' );
	my $method_opt;
	if ( $challenge eq "http" )
	{
		$method_opt =
		  "--webroot --webroot-path " . &getGlobalConfiguration( 'le_webroot_path' );
	}
	my $configdir_opt = "--config-dir " . &getLetsencryptConfigPath();
	my $email_opt     = "-m " . &getLetsencryptConfig()->{ email };
	my $challenge_opt = "--preferred-challenges $challenge";
	my $opts          = "--agree-tos --no-eff-email -n";

	my $le_binary = &getGlobalConfiguration( 'le_certbot_bin' );
	my $cmd =
	  "$le_binary certonly $domains_opt $fullchain_opt $method_opt $configdir_opt $email_opt $test_opt $challenge_opt $opts";
	&zenlog( "Executing Letsencryptz obtain command : $cmd",
			 "Info", "LetsencryptZ" );

	$status = &logRunAndGet( $cmd, "array" );
	if ( $status->{ stderr } and ( $challenge eq "http" ) )
	{
		&zenlog( "Letsencryptz obtain command failed!", "error", "LetsencryptZ" );
		$rc = 3;
	}
	else
	{
		# create ZEVENET PEM cert
		$status = &setLetsencryptCert( @{ $domains_list }[0] );
		if ( $status )
		{
			&zenlog( "Letsencryptz create PEM cert failed!", "error", "LetsencryptZ" );
			$rc = 4;
		}
	}

	# delete le service
	&unsetLetsencryptFarmService( $farm_name );

	# stop local Web Server
	&runLetsencryptLocalWebserverStop();

	return $rc;
}

=begin nd
Function: runLetsencryptDestroy

	Revoke a LetsEncrypt Certificate.

Parameters:
	le_cert_name - LE Certificate name.

Returns:
	Integer - 0 on succesfull, otherwise on error.
=cut

sub runLetsencryptDestroy    # ( $le_cert_name )
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $le_cert_name   = shift;
	my $le_config_path = &getLetsencryptConfigPath();

	return 1 if ( !$le_cert_name );
	return 2 if ( !-d "$le_config_path/live/$le_cert_name" );

	my $le_binary = &getGlobalConfiguration( 'le_certbot_bin' );

# run le_binary revoke command ??
# revoke --cert-path /PATH/TO/live/$cert_name/cert.pem --key-path /PATH/TO/live/$cert_name/privkey.pem

   # run le_binary delete command
   # delete --cert-name $cert_name --config-dir $le_config_path --reason unspecified

	my $certname_opt  = "--cert-name " . $le_cert_name;
	my $configdir_opt = "--config-dir " . &getLetsencryptConfigPath();
	my $opts          = "--reason unspecified";

	my $cmd = "$le_binary delete $certname_opt $configdir_opt $opts";
	&zenlog( "Executing Letsencryptz obtain command : $cmd",
			 "Info", "LetsencryptZ" );

	my $status = &logRunAndGet( $cmd, "array" );
	if ( $status->{ stderr } )
	{
		&zenlog( "Letsencryptz delete command failed!", "error", "LetsencryptZ" );
		return 3;
	}
	return 3 if ( -d "$le_config_path/live/$le_cert_name" );

	return 0;
}

=begin nd
Function: runLetsencryptRenew

	Renew a LetsEncrypt Certificate.

Parameters:
	le_cert_name - LE Cert Name
	farm_name - Farm Name where Letsencrypt will connect.
	vip - VIP where the new Farm and service is created. The virtual Port will be 80.
	force_renewal - if "true" forces a renew even the cert not yet due for renewal( over 30 days for expire ).
	test - if "true" the action simulates all the process but no certificate is created.

Returns:
	Integer - 0 on succesfull, otherwise on error.
=cut

sub runLetsencryptRenew    # ( $le_cert_name, $farm_name, $vip, $force, $test )
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my ( $le_cert_name, $farm_name, $vip, $force, $test ) = @_;

	return 1 if ( !$le_cert_name );
	return 2 if ( !$vip && !$farm_name );

	my $status;
	my $rc = 0;

	my $le_farm = &getGlobalConfiguration( 'le_farm' );
	$farm_name = $le_farm if ( !$farm_name );

	# start local Web Server
	$status = &runLetsencryptLocalWebserverStart();

	return 1 if $status;

	# add le service
	$status = &setLetsencryptFarmService( $farm_name, $vip );
	return 2 if $status;

	# run le_binary command
	my $test_opt = "--test-cert" if ( $test eq "true" );
	my $force_opt = "--force-renewal --break-my-certs" if ( $force eq "true" );
	my $fullchain_opt =
	  "--fullchain-path " . &getGlobalConfiguration( 'le_fullchain_path' );
	my $webroot_opt =
	  "--webroot --webroot-path " . &getGlobalConfiguration( 'le_webroot_path' );
	my $configdir_opt = "--config-dir " . &getLetsencryptConfigPath();
	my $email_opt     = "-m " . &getLetsencryptConfig()->{ email };
	my $opts =
	  "--preferred-challenges http-01 --agree-tos --no-eff-email -n --no-random-sleep-on-renew";

	my $le_binary = &getGlobalConfiguration( 'le_certbot_bin' );
	my $cmd =
	  "$le_binary renew $fullchain_opt $webroot_opt $configdir_opt $email_opt $test_opt $force_opt $opts";
	&zenlog( "Executing Letsencryptz renew command : $cmd",
			 "Info", "LetsencryptZ" );
	$status = &logRunAndGet( $cmd, "array" );

	if ( $status->{ stderr } )
	{
		&zenlog( "Letsencryptz renew command failed!", "error", "LetsencryptZ" );
		$rc = 3;
	}
	else
	{
		# create ZEVENET PEM cert
		$status = &setLetsencryptCert( $le_cert_name );
		if ( $status )
		{
			&zenlog( "Letsencryptz create PEM cert failed!", "error", "LetsencryptZ" );
			$rc = 4;
		}
	}

	# delete le service
	&unsetLetsencryptFarmService( $farm_name );

	# stop local Web Server
	&runLetsencryptLocalWebserverStop();

	return $rc;
}

1;