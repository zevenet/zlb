##############################################################################
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

# GET /certificates/letsencryptz
sub get_le_certificates    # ()
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );

	require Zevenet::LetsencryptZ;

	my $desc         = "List LetsEncrypt certificates";
	my $certificates = &getLetsencryptCertificates();
	my @out;

	if ( $certificates )
	{
		foreach my $cert ( @{ $certificates } )
		{
			push @out, &getLetsencryptCertificateInfo( $cert->{ name } );
		}
	}
	if ( $eload )
	{
		my $wildcards = &eload( module => 'Zevenet::LetsencryptZ::Wildcard',
								func   => 'getLetsencryptWildcardCertificates' );

		foreach my $cert ( @{ $wildcards } )
		{
			push @out,
			  &eload(
					  module => 'Zevenet::LetsencryptZ::Wildcard',
					  func   => 'getLetsencryptWildcardCertificateInfo',
					  args   => [$cert->{ name }]
			  );
		}

	}

	my $body = {
				 description => $desc,
				 params      => \@out,
	};

	&httpResponse( { code => 200, body => $body } );
}

# GET /certificates/letsencryptz/le_cert_re
sub get_le_certificate    # ( $cert_filename )
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $le_cert_name = shift;

	require Zevenet::LetsencryptZ;

	my $desc    = "Show Let's Encrypt certificate $le_cert_name";
	my $le_cert = &getLetsencryptCertificates( $le_cert_name );
	if ( !defined $le_cert_name or !@{ $le_cert } )
	{
		my $msg = "Let's Encrypt certificate $le_cert_name not found!";
		&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
	}

	my $out = &getLetsencryptCertificateInfo( $le_cert_name );

	my $body = {
				 description => $desc,
				 params      => $out,
	};

	&httpResponse( { code => 200, body => $body } );
}

# POST /certificates/letsencryptz
sub create_le_certificate    # ()
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );

	my $json_obj = shift;

	require Zevenet::Certificate;
	require Zevenet::LetsencryptZ;
	require Zevenet::Net::Interface;
	my $ip_list = &getIpAddressList();
	require Zevenet::Farm::Core;
	my @farm_list = &getFarmsByType( "http" );

	my $desc   = "Create LetsEncrypt certificate";
	my $params = &getZAPIModel( "letsencryptz-create.json" );
	$params->{ vip }->{ values }      = $ip_list;
	$params->{ farmname }->{ values } = \@farm_list;

	# avoid farmname when no HTTP Farm exists
	if ( !@farm_list and defined $json_obj->{ farmname } )
	{
		my $msg = "There is no HTTP Farms in the system, use 'vip' param instead.";
		&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
	}

	# vip or farmname has to be defined
	if (     !$json_obj->{ vip }
		 and !$json_obj->{ farmname }
		 and defined $json_obj->{ domains } )
	{
		my $msg = "No 'vip' or 'farmname' param found.";
		&httpErrorResponse( code => 404, desc => $desc, msg => $msg );
	}

	# Check allowed parameters
	my $error_msg = &checkZAPIParams( $json_obj, $params, $desc );
	if ( $error_msg )
	{
		&httpErrorResponse( code => 400, desc => $desc, msg => $error_msg );
	}

	# avoid wildcards domains
	if ( grep ( /^\*/, @{ $json_obj->{ domains } } ) )
	{
		my $msg = "Wildcard domains are not allowed.";
		&httpErrorResponse( code => 404, desc => $desc, msg => $msg );
	}

	# check farm has to be listening on port 80 and up
	if ( defined $json_obj->{ farmname } )
	{
		require Zevenet::Farm::Base;
		if ( &getFarmVip( 'vipp', $json_obj->{ farmname } ) ne 80 )
		{
			my $msg = "Farm $json_obj->{ farmname } must be listening on Port 80.";
			&httpErrorResponse( code => 404, desc => $desc, msg => $msg );
		}
		if ( &getHTTPFarmStatus( $json_obj->{ farmname } ) ne "up" )
		{
			my $msg = "Farm $json_obj->{ farmname } must be up.";
			&httpErrorResponse( code => 404, desc => $desc, msg => $msg );
		}

	}

	# check any farm listening on vip and port 80 and up
	my $le_farm_port = 80;
	if ( defined $json_obj->{ vip } )
	{
		require Zevenet::Net::Validate;
		if ( &validatePort( $json_obj->{ vip }, $le_farm_port, "tcp" ) == 0 )
		{
			#vip:port is in use
			require Zevenet::Farm::Base;
			foreach my $farm ( &getFarmListByVip( $json_obj->{ vip } ) )
			{
				if (     &getHTTPFarmVip( "vipp", $farm ) eq "$le_farm_port"
					 and &getHTTPFarmStatus( $farm ) eq "up" )
				{
					my $msg =
					  "Farm $farm is listening on 'vip' $json_obj->{ vip } and Port $le_farm_port.";
					&httpErrorResponse( code => 404, desc => $desc, msg => $msg );
				}
			}
			my $msg =
			  "The system has a process listening on 'vip' $json_obj->{ vip } and Port $le_farm_port.";
			&httpErrorResponse( code => 404, desc => $desc, msg => $msg );
		}
	}

	# check Email config
	my $le_conf = &getLetsencryptConfig();
	if ( !$le_conf->{ email } )
	{
		my $msg = "LetsencryptZ email is not configured.";
		&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
	}

	my $error = &runLetsencryptObtain(
									   $json_obj->{ farmname },
									   $json_obj->{ vip },
									   $json_obj->{ domains },
									   $json_obj->{ test }
	);
	if ( $error )
	{
		my $strdomains = join ( ", ", @{ $json_obj->{ domains } } );
		my $msg = "The Letsencrypt certificate for Domain $strdomains can't be created";
		&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
	}

	&zenlog( "Success, the Letsencrypt certificate has been created successfully.",
			 "info", "LestencryptZ" );

	my $out = &getLetsencryptCertificateInfo( $json_obj->{ domains }[0] );
	my $body = {
				 description => $desc,
				 params      => $out,
				 message => "The Letsencrypt certificate has been created successfully."
	};

	&httpResponse( { code => 200, body => $body } );
}

# DELETE /certificates/letsencryptz/le_cert_re
sub delete_le_certificate    # ( $cert_filename )
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );

	my $le_cert_name = shift;
	my $desc         = "Delete LetsEncrypt certificate";

	require Zevenet::LetsencryptZ;

	my $le_cert = &getLetsencryptCertificates( $le_cert_name );
	if ( !@{ $le_cert } )
	{
		my $msg = "Let's Encrypt certificate $le_cert_name not found!";
		&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
	}

	my $cert_name = $le_cert_name;
	$cert_name =~ s/\./\_/g;
	$cert_name .= ".pem";

	# check the certificate is being used by a Farm
	require Zevenet::Certificate;
	my $farms_used = &getCertFarmsUsed( $cert_name );
	if ( @{ $farms_used } )
	{
		my $msg =
		  "Let's Encrypt Certificate $le_cert_name can not be deleted because it is in use by "
		  . join ( ", ", @{ $farms_used } );
		&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
	}

	if ( $eload )
	{
		# check the certificate is being used by ZAPI Webserver
		my $status = &eload(
							 module => 'Zevenet::System::HTTP',
							 func   => 'getHttpsCertUsed',
							 args   => ['$cert_name']
		);
		if ( $status == 0 )
		{
			my $msg =
			  "Let's Encrypt Certificate $le_cert_name can not be deleted because it is in use by HTTPS server";
			&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
		}
	}

	# revoke LE cert
	my $error = &runLetsencryptDestroy( $le_cert_name );
	if ( $error )
	{
		my $msg = "Let's Encrypt Certificate can not be removed";
		&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
	}

	# delete autorenewal
	&unsetLetsencryptCron( $le_cert_name );

	# delete ZEVENET cert if exists
	my $cert_dir = &getGlobalConfiguration( 'certdir' );
	&delCert( $cert_name ) if ( -f "$cert_dir\/$cert_name" );

	if ( -f "$cert_dir\/$cert_name" )
	{
		my $msg = "Error deleting certificate $cert_name.";
		&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
	}

	&zenlog(
			 "Success, the Let's Encrypt certificate has been deleted successfully.",
			 "info", "LestencryptZ" );

	my $msg = "Let's Encrypt Certificate $le_cert_name has been deleted.";
	my $body = {
				 description => $desc,
				 success     => "true",
				 message     => $msg,
	};
	&httpResponse( { code => 200, body => $body } );
}

# POST /certificates/letsencryptz/le_cert_re/actions
sub actions_le_certificate    # ( $le_cert_name )
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $json_obj     = shift;
	my $le_cert_name = shift;
	my $desc         = "Let's Encrypt certificate actions";

	require Zevenet::Certificate;
	require Zevenet::LetsencryptZ;

	# check the certificate is a LE cert
	my $le_cert = &getLetsencryptCertificates( $le_cert_name );
	if ( !@{ $le_cert } )
	{
		my $msg = "Let's Encrypt certificate $le_cert_name not found!";
		&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
	}

	require Zevenet::Net::Interface;
	my $ip_list = &getIpAddressList();
	require Zevenet::Farm::Core;
	my @farm_list = &getFarmsByType( "http" );

	my $params = &getZAPIModel( "letsencryptz-action.json" );
	$params->{ vip }->{ values }      = $ip_list;
	$params->{ farmname }->{ values } = \@farm_list;

	# Check allowed parameters
	my $error_msg = &checkZAPIParams( $json_obj, $params, $desc );
	if ( $error_msg )
	{
		&httpErrorResponse( code => 400, desc => $desc, msg => $error_msg );
	}

	# avoid farmname when no HTTP Farm exists
	if ( !@farm_list and defined $json_obj->{ farmname } )
	{
		my $msg = "There is no HTTP Farms in the system, use 'vip' param instead.";
		&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
	}

	# vip or farmname has to be defined
	if (     !$json_obj->{ vip }
		 and !$json_obj->{ farmname } )
	{
		my $msg = "No 'vip' or 'farmname' param found.";
		&httpErrorResponse( code => 404, desc => $desc, msg => $msg );
	}

	# check farm has to be listening on port 80 and up
	if ( defined $json_obj->{ farmname } )
	{
		require Zevenet::Farm::Base;
		if ( &getFarmVip( 'vipp', $json_obj->{ farmname } ) ne 80 )
		{
			my $msg = "Farm $json_obj->{ farmname } must be listening on Port 80.";
			&httpErrorResponse( code => 404, desc => $desc, msg => $msg );
		}
		if ( &getHTTPFarmStatus( $json_obj->{ farmname } ) ne "up" )
		{
			my $msg = "Farm $json_obj->{ farmname } must be up.";
			&httpErrorResponse( code => 404, desc => $desc, msg => $msg );
		}
	}

	# check any farm listening on vip and port 80 and up
	my $le_farm_port = 80;
	if ( defined $json_obj->{ vip } )
	{
		require Zevenet::Net::Validate;
		if ( &validatePort( $json_obj->{ vip }, $le_farm_port, "tcp" ) == 0 )
		{
			#vip:port is in use
			require Zevenet::Farm::Base;
			foreach my $farm ( &getFarmListByVip( $json_obj->{ vip } ) )
			{
				if (     &getHTTPFarmVip( "vipp", $farm ) eq "$le_farm_port"
					 and &getHTTPFarmStatus( $farm ) eq "up" )
				{
					my $msg =
					  "Farm $farm is listening on 'vip' $json_obj->{ vip } and Port $le_farm_port.";
					&httpErrorResponse( code => 404, desc => $desc, msg => $msg );
				}
			}
			my $msg =
			  "The system has a process listening on 'vip' $json_obj->{ vip } and Port $le_farm_port.";
			&httpErrorResponse( code => 404, desc => $desc, msg => $msg );
		}
	}

	# check Email config
	my $le_conf = &getLetsencryptConfig();
	if ( !$le_conf->{ email } )
	{
		my $msg = "LetsencryptZ email is not configured.";
		&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
	}

	my $error_ref = &runLetsencryptRenew(
										  $le_cert_name,
										  $json_obj->{ farmname },
										  $json_obj->{ vip },
										  $json_obj->{ force_renewal },
										  $json_obj->{ test }
	);
	if ( $error_ref->{ code } )
	{
		&httpErrorResponse( code => 400, desc => $desc, msg => $error_ref->{ desc } );
	}

	&zenlog( "Success, the Letsencrypt certificate has been renewed successfully.",
			 "info", "LestencryptZ" );

	my @farms_restarted;
	my @farms_restarted_error;
	if (     ( defined $json_obj->{ restart } )
		 and ( $json_obj->{ restart } eq "true" ) )
	{
		my $cert_name = $le_cert_name;
		$cert_name =~ s/\./\_/g;
		$cert_name .= ".pem";

		my $error;
		require Zevenet::Farm::Action;
		require Zevenet::Farm::Base;
		foreach my $farm ( @{ getCertFarmsUsed( $cert_name ) } )
		{
			# restart farm used and up
			if ( &getFarmStatus( $farm ) ne 'down' )
			{
				$error = &runFarmStop( $farm, "" );
				if ( $error )
				{
					push @farms_restarted_error, $farm;
					next;
				}
				$error = &runFarmStart( $farm, "" );
				if ( $error )
				{
					push @farms_restarted_error, $farm;
					next;
				}
				push @farms_restarted, $farm;
			}
		}

		# restart on backup node
		if ( $eload )
		{
			&eload(
					module => 'Zevenet::Cluster',
					func   => 'runZClusterRemoteManager',
					args   => ['farm', 'restart_farms', @farms_restarted],
			) if @farms_restarted;
		}
	}

	my $info_msg;
	if ( @farms_restarted )
	{
		$info_msg =
		  "The following farms were been restarted: " . join ( ", ", @farms_restarted );
	}
	if ( @farms_restarted_error )
	{
		$info_msg = "The following farms could not been restarted: "
		  . join ( ", ", @farms_restarted_error );
	}

	my $msg =
	  "The Let's Encrypt certificate $le_cert_name has been renewed successfully.";
	my $out = &getLetsencryptCertificateInfo( $le_cert_name );
	my $body = {
				 description => $desc,
				 params      => $out,
				 message     => $msg
	};
	$body->{ warning } = $info_msg if defined $info_msg;
	&httpResponse( { code => 200, body => $body } );

}

# PUT /certificates/letsencryptz/le_cert_re
sub modify_le_certificate    # ( $le_cert_name )
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $json_obj     = shift;
	my $le_cert_name = shift;
	my $desc         = "Modify Let's Encrypt certificate";

	require Zevenet::Certificate;
	require Zevenet::LetsencryptZ;

	# check the certificate is a LE cert
	my $le_cert = &getLetsencryptCertificates( $le_cert_name );
	if ( !@{ $le_cert } )
	{
		my $msg = "Let's Encrypt certificate $le_cert_name not found!";
		&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
	}

	my $params = &getZAPIModel( "letsencryptz-modify.json" );

	# dyn_values model
	if ( defined $json_obj->{ vip } )
	{
		require Zevenet::Net::Interface;
		my $ip_list = &getIpAddressList();
		$params->{ vip }->{ values } = $ip_list;

	}
	if ( defined $json_obj->{ farmname } )
	{
		require Zevenet::Farm::Core;
		my @farm_list = &getFarmsByType( "http" );
		$params->{ farmname }->{ values } = \@farm_list;
	}

	# depends_on model
	if ( defined $json_obj->{ farmname } )
	{
		delete $params->{ vip } if defined $json_obj->{ vip };
	}

	if (     ( defined $json_obj->{ autorenewal } )
		 and ( $json_obj->{ autorenewal } eq "false" ) )
	{
		delete $params->{ force_renewal } if defined $params->{ force_renewal };
		delete $params->{ restart }       if defined $params->{ restart };
		delete $params->{ vip }           if defined $params->{ vip };
		delete $params->{ farmname }      if defined $params->{ farmname };
	}

	# Check allowed parameters
	my $error_msg = &checkZAPIParams( $json_obj, $params, $desc );
	if ( $error_msg )
	{
		&httpErrorResponse( code => 400, desc => $desc, msg => $error_msg );
	}

	# depends_on model
	# vip or farmname has to be defined
	if (     !$json_obj->{ vip }
		 and !$json_obj->{ farmname }
		 and $json_obj->{ autorenewal } eq "true" )
	{
		my $msg = "No 'vip' or 'farmname' param found.";
		&httpErrorResponse( code => 404, desc => $desc, msg => $msg );
	}

	# check farm has to be listening on port 80 and up
	if ( defined $json_obj->{ farmname } )
	{
		require Zevenet::Farm::Base;
		if ( &getFarmVip( 'vipp', $json_obj->{ farmname } ) ne 80 )
		{
			my $msg = "Farm $json_obj->{ farmname } must be listening on Port 80.";
			&httpErrorResponse( code => 404, desc => $desc, msg => $msg );
		}
		if ( &getHTTPFarmStatus( $json_obj->{ farmname } ) ne "up" )
		{
			my $msg = "Farm $json_obj->{ farmname } must be up.";
			&httpErrorResponse( code => 404, desc => $desc, msg => $msg );
		}
	}

	# check any farm listening on vip and port 80 and up
	my $le_farm_port = 80;
	if ( defined $json_obj->{ vip } )
	{
		require Zevenet::Net::Validate;
		if ( &validatePort( $json_obj->{ vip }, $le_farm_port, "tcp" ) == 0 )
		{
			#vip:port is in use
			require Zevenet::Farm::Base;
			foreach my $farm ( &getFarmListByVip( $json_obj->{ vip } ) )
			{
				if (     &getHTTPFarmVip( "vipp", $farm ) eq "$le_farm_port"
					 and &getHTTPFarmStatus( $farm ) eq "up" )
				{
					my $msg =
					  "Farm $farm is listening on 'vip' $json_obj->{ vip } and Port $le_farm_port.";
					&httpErrorResponse( code => 404, desc => $desc, msg => $msg );
				}
			}
			my $msg =
			  "The system has a process listening on 'vip' $json_obj->{ vip } and Port $le_farm_port.";
			&httpErrorResponse( code => 404, desc => $desc, msg => $msg );
		}
	}

	# check Email config
	my $le_conf = &getLetsencryptConfig();
	if ( !$le_conf->{ email } )
	{
		my $msg = "LetsencryptZ email is not configured.";
		&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
	}

	my $msg;
	if ( $json_obj->{ autorenewal } eq "true" )
	{
		my $error = &setLetsencryptCron(
										 $le_cert_name,
										 $json_obj->{ farmname },
										 $json_obj->{ vip },
										 $json_obj->{ force_renewal },
										 $json_obj->{ restart }
		);

		if ( $error )
		{
			my $msg =
			  "The Auto Renewal for Let's Encrypt certificate $le_cert_name can't be enabled";
			&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
		}

		&zenlog(
			"Success, the Auto Renewal for Letsencrypt certificate has been enabled successfully.",
			"info", "LestencryptZ"
		);
		$msg =
		  "The Auto Renewal for Let's Encrypt certificate $le_cert_name has been enabled successfully.";
	}
	else
	{
		my $error = &unsetLetsencryptCron( $le_cert_name );
		if ( $error )
		{
			my $msg =
			  "The Auto Renewal for Let's Encrypt certificate $le_cert_name can't be disabled";
			&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
		}
		&zenlog(
			"Success, the Auto Renewal for Letsencrypt certificate has been disabled successfully.",
			"info", "LestencryptZ"
		);
		$msg =
		  "The Auto Renewal for Let's Encrypt certificate $le_cert_name has been disabled successfully.";
	}

	my $out = &getLetsencryptCertificateInfo( $le_cert_name );
	my $body = {
				 description => $desc,
				 params      => $out,
				 message     => $msg,
	};
	&httpResponse( { code => 200, body => $body } );
}

# GET /certificates/letsencryptz/config
sub get_le_conf    # ( )
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );

	my $desc = "Get LetsEncrypt Config";

	require Zevenet::LetsencryptZ;
	my $out = &getLetsencryptConfig();
	my $body = {
				 description => $desc,
				 params      => $out,
	};
	&httpResponse( { code => 200, body => $body } );
}

# PUT /certificates/letsencryptz/config
sub modify_le_conf    # ( )
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $json_obj = shift;

	my $desc   = "Modify LetsEncrypt Config";
	my $params = &getZAPIModel( "letsencryptz_config-modify.json" );

	# Check allowed parameters
	my $error_msg = &checkZAPIParams( $json_obj, $params, $desc );
	if ( $error_msg )
	{
		&httpErrorResponse( code => 400, desc => $desc, msg => $error_msg );
	}

	require Zevenet::LetsencryptZ;
	my $error = &setLetsencryptConfig( $json_obj );
	if ( $error )
	{
		my $msg = "The Letsencrypt Config can't be updated";
		&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
	}
	my $msg = "The Letsencrypt Config has been updated successfully.";
	my $out = &getLetsencryptConfig();
	my $body = {
				 description => $desc,
				 success     => "true",
				 message     => $msg,
				 params      => $out,
	};
	&httpResponse( { code => 200, body => $body } );
}

1;
