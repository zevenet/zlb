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

use Zevenet::Farm::Core;
use Zevenet::Farm::Base;

my $eload;
if ( eval { require Zevenet::ELoad; } )
{
	$eload = 1;
}

unless ( $eload ) { require Zevenet::Farm::HTTP::HTTPS; }

# POST /farms/FARM/certificates (Add certificate to farm)
sub add_farm_certificate    # ( $json_obj, $farmname )
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $json_obj = shift;
	my $farmname = shift;

	my $desc = "Add certificate to farm '$farmname'";

	# Check if the farm exists
	if ( !&getFarmExists( $farmname ) )
	{
		my $msg = "Farm not found";
		&httpErrorResponse( code => 404, desc => $desc, msg => $msg );
	}

	my $certdir     = &getGlobalConfiguration( 'certdir' );
	my $cert_pem_re = &getValidFormat( 'cert_pem' );

	# validate certificate filename and format
	unless ( -f $certdir . "/" . $json_obj->{ file }
			 && &getValidFormat( 'cert_pem', $json_obj->{ file } ) )
	{
		my $msg = "Invalid certificate name, please insert a valid value.";
		&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
	}

	my $cert_in_use;
	if ( $eload )
	{
		$cert_in_use = grep ( /^$json_obj->{ file }$/,
							  &eload(
									  module => 'Zevenet::Farm::HTTP::HTTPS::Ext',
									  func   => 'getFarmCertificatesSNI',
									  args   => [$farmname]
							  ) );
	}
	else
	{
		$cert_in_use = &getFarmCertificate( $farmname ) eq $json_obj->{ file };
	}

	if ( $cert_in_use )
	{
		my $msg = "The certificate already exists in the farm.";
		&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
	}

	# FIXME: Show error if the certificate is already in the list
	my $status;
	if ( $eload )
	{
		$status = &eload(
						  module => 'Zevenet::Farm::HTTP::HTTPS::Ext',
						  func   => 'setFarmCertificateSNI',
						  args   => [$json_obj->{ file }, $farmname],
		);
	}
	else
	{
		$status = &setFarmCertificate( $json_obj->{ file }, $farmname );
	}

	if ( $status )
	{
		my $msg =
		  "It's not possible to add the certificate with name $json_obj->{file} for the $farmname farm";

		&zenlog( "It's not possible to add the certificate.", "warning", "LSLB" );
		&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
	}

	# no errors found, return succesful response
	&zenlog( "Success, trying to add a certificate to the farm.", "info", "LSLB" );

	my $message =
	  "The certificate $json_obj->{file} has been added to the farm $farmname, you need restart the farm to apply";

	my $body = {
				 description => $desc,
				 success     => "true",
				 message     => $message,
	};

	if ( &getFarmStatus( $farmname ) eq 'up' )
	{
		require Zevenet::Farm::Action;

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

# DELETE /farms/FARM/certificates/CERTIFICATE
sub delete_farm_certificate    # ( $farmname, $certfilename )
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $farmname     = shift;
	my $certfilename = shift;

	my $desc = "Delete farm certificate";

	unless ( $eload )
	{
		my $msg = "HTTPS farm without certificate is not allowed.";
		&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
	}

	# Check if the farm exists
	if ( !&getFarmExists( $farmname ) )
	{
		my $msg = "The farmname $farmname does not exists";
		&httpErrorResponse( code => 404, desc => $desc, msg => $msg );
	}

	# validate certificate
	unless ( $certfilename && &getValidFormat( 'cert_pem', $certfilename ) )
	{
		my $msg = "Invalid certificate id, please insert a valid value.";
		&zenlog( "Invalid certificate id.", "warning", "LSLB" );
		&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
	}

	my @certSNI = &eload(
						  module => 'Zevenet::Farm::HTTP::HTTPS::Ext',
						  func   => 'getFarmCertificatesSNI',
						  args   => [$farmname],
	);

	my $number = scalar grep ( { $_ eq $certfilename } @certSNI );
	if ( !$number )
	{
		my $msg = "Certificate is not used by the farm.";
		&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
	}

	my $status;

 # This is a BUGFIX: delete the certificate all times that it appears in config file
	for ( my $it = 0 ; $it < $number ; $it++ )
	{
		$status = &eload(
						  module => 'Zevenet::Farm::HTTP::HTTPS::Ext',
						  func   => 'setFarmDeleteCertNameSNI',
						  args   => [$certfilename, $farmname],
		);
		last if ( $status == -1 );
	}

	# check if the certificate could not be removed
	if ( $status == -1 )
	{
		&zenlog( "It's not possible to delete the certificate.", "warning", "LSLB" );

		my $msg =
		  "It isn't possible to delete the selected certificate $certfilename from the SNI list";
		&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
	}

   # check if removing the certificate would leave the SNI list empty, not supported
	if ( $status == 1 )
	{
		&zenlog(
			"It's not possible to delete all certificates, at least one is required for HTTPS.",
			"warning", "LSLB"
		);

		my $msg =
		  "It isn't possible to delete all certificates, at least one is required for HTTPS profiles";
		&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
	}

	# no errors found, return succesful response
	my $msg = "The Certificate $certfilename has been deleted";
	my $body = {
				 description => $desc,
				 success     => "true",
				 message     => $msg
	};

	if ( &getFarmStatus( $farmname ) eq 'up' )
	{
		require Zevenet::Farm::Action;

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

	&zenlog( "Success, trying to delete a certificate to the SNI list.",
			 "info", "LSLB" );
	&httpResponse( { code => 200, body => $body } );
}

1;
