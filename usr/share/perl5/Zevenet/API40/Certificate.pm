#!/usr/bin/perl
###############################################################################
#
#    ZEVENET Software License
#    This file is part of the ZEVENET Load Balancer software package.
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
use warnings;


my $CSR_KEY_SIZE = 2048;

# GET /certificates
sub certificates    # ()
{
	&zenlog( __FILE__ . q{:} . __LINE__ . q{:} . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	require Zevenet::Certificate;

	my $desc         = "List certificates";
	my @certificates = &getCertFiles();
	my $configdir    = &getGlobalConfiguration( 'certdir' );
	my @out;

	foreach my $cert ( sort @certificates )
	{
		push @out, &getCertInfo( "$configdir/$cert" );
	}

	my $body = {
				 description => $desc,
				 params      => \@out,
	};

	&httpResponse( { code => 200, body => $body } );
	return;
}

# GET /certificates/CERTIFICATE/info
sub get_certificate_info    # ()
{
	&zenlog( __FILE__ . q{:} . __LINE__ . q{:} . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $cert_filename = shift;

	require Zevenet::Certificate;

	my $desc     = "Show certificate details";
	my $cert_dir = &getGlobalConfiguration( 'certdir' );

	# check is the certificate file exists
	if ( not -f "$cert_dir\/$cert_filename" )
	{
		my $msg = "Certificate file not found.";
		&httpErrorResponse( code => 404, desc => $desc, msg => $msg );
	}

	if ( &getValidFormat( 'certificate', $cert_filename ) )
	{
		my $cert = &getCertData( "$cert_dir\/$cert_filename", "true" );

		&httpResponse( { code => 200, body => $cert, type => 'text/plain' } );
	}
	else
	{
		my $msg = "Could not get such certificate information";
		&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
	}
	return;
}

# GET /certificates/CERTIFICATE
sub download_certificate    # ()
{
	&zenlog( __FILE__ . q{:} . __LINE__ . q{:} . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $cert_filename = shift;

	my $desc      = "Download certificate";
	my $cert_dir  = &getGlobalConfiguration( 'certdir' );
	my $cert_path = "$cert_dir/$cert_filename";

	unless ( $cert_filename =~ /\.(pem|csr)$/ and -f $cert_path )
	{
		my $msg = "Could not find such certificate";
		&httpErrorResponse( code => 404, desc => $desc, msg => $msg );
	}

	&httpDownloadResponse(
						   desc => $desc,
						   dir  => $cert_dir,
						   file => $cert_filename
	);
	return;
}

# DELETE /certificates/CERTIFICATE
sub delete_certificate    # ( $cert_filename )
{
	&zenlog( __FILE__ . q{:} . __LINE__ . q{:} . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $cert_filename = shift;

	require Zevenet::Certificate;
	require Zevenet::LetsencryptZ;

	my $desc     = "Delete certificate";
	my $cert_dir = &getGlobalConfiguration( 'certdir' );

	# check is the certificate file exists
	if ( not -f "$cert_dir\/$cert_filename" )
	{
		my $msg = "Certificate file not found.";
		&httpErrorResponse( code => 404, desc => $desc, msg => $msg );
	}

	my $status = &getFarmCertUsed( $cert_filename );

	# check is the certificate is being used
	if ( $status == 0 )
	{
		my $msg = "File can't be deleted because it's in use by a farm.";
		&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
	}
	# check if it is a LE certificate
	my $le_cert_name = $cert_filename;
	$le_cert_name =~ s/.pem//g;
	$le_cert_name =~ s/\_/\./g;
	my $error;
	if ( @{ &getLetsencryptCertificates( $le_cert_name ) } )
	{
		$error = &runLetsencryptDestroy( $le_cert_name );
	}
	if ( $error )
	{
		my $msg = "LE Certificate can not be removed";
		&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
	}

	&delCert( $cert_filename );

	# check if the certificate exists
	if ( -f "$cert_dir\/$cert_filename" )
	{
		my $msg = "Error deleting certificate $cert_filename.";
		&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
	}

	# no errors found, make a succesful response
	my $msg = "The Certificate $cert_filename has been deleted.";
	my $body = {
				 description => $desc,
				 success     => "true",
				 message     => $msg,
	};

	&httpResponse( { code => 200, body => $body } );
	return;
}

# POST /certificates (Create CSR)
sub create_csr
{
	&zenlog( __FILE__ . q{:} . __LINE__ . q{:} . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $json_obj = shift;

	require Zevenet::Certificate;

	my $desc      = 'Create CSR';
	my $configdir = &getGlobalConfiguration( 'certdir' );

	if ( -f "$configdir/$json_obj->{name}.csr" )
	{
		my $msg = "$json_obj->{name} already exists.";
		&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
	}

	my $params = &getZAPIModel( "certificate_csr-create.json" );
	$params->{ fqdn }->{ function } = \&checkFQDN;

	# Check allowed parameters
	my $error_msg = &checkZAPIParams( $json_obj, $params, $desc );
	if ( $error_msg )
	{
		&httpErrorResponse( code => 400, desc => $desc, msg => $error_msg );
	}

	my $error = &createCSR(
							$json_obj->{ name },
							$json_obj->{ fqdn },
							$json_obj->{ country },
							$json_obj->{ state },
							$json_obj->{ locality },
							$json_obj->{ organization },
							$json_obj->{ division },
							$json_obj->{ mail },
							$CSR_KEY_SIZE,
							""
	);

	if ( $error )
	{
		my $msg = "Error, creating certificate $json_obj->{ name }.";
		&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
	}

	my $message = "Certificate $json_obj->{ name } created";
	my $body = {
				 description => $desc,
				 success     => "true",
				 message     => $message,
	};

	&httpResponse( { code => 200, body => $body } );
	return;
}

# POST /certificates/CERTIFICATE (Upload PEM)
sub upload_certificate    # ()
{
	&zenlog( __FILE__ . q{:} . __LINE__ . q{:} . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $upload_data = shift;
	my $filename    = shift;

	require Zevenet::File;

	my $desc      = "Upload PEM certificate";
	my $configdir = &getGlobalConfiguration( 'certdir' );

	# add extension if it does not exist
	$filename .= ".pem" if $filename !~ /\.pem$/;

	# check if the certificate filename already exists
	$filename =~ s/[\(\)\@ ]//g;
	if ( -f "$configdir/$filename" )
	{
		my $msg = "Certificate file name already exists";
		&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
	}

	unless ( &setFile( "$configdir/$filename", $upload_data ) )
	{
		my $msg = "Could not save the certificate file";
		&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
	}

	# no errors found, return sucessful response
	my $message = "Certificate uploaded";
	my $body = {
				 description => $desc,
				 success     => "true",
				 message     => $message,
	};

	&httpResponse( { code => 200, body => $body } );
	return;
}

# GET /ciphers
sub ciphers_available    # ( $json_obj, $farmname )
{
	&zenlog( __FILE__ . q{:} . __LINE__ . q{:} . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $desc = "Get the ciphers available";

	my @out = (
				{ 'ciphers' => "all",            "description" => "All" },
				{ 'ciphers' => "highsecurity",   "description" => "High security" },
				{ 'ciphers' => "customsecurity", "description" => "Custom security" }
	);
	my $body = {
				 description => $desc,
				 params      => \@out,
	};

	&httpResponse( { code => 200, body => $body } );
	return;
}

# POST /farms/FARM/certificates (Add certificate to farm)
sub add_farm_certificate    # ( $json_obj, $farmname )
{
	&zenlog( __FILE__ . q{:} . __LINE__ . q{:} . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $json_obj = shift;
	my $farmname = shift;

	require Zevenet::Farm::Core;
	require Zevenet::Farm::Base;

		require Zevenet::Farm::HTTP::HTTPS;

	my $desc = "Add certificate to farm '$farmname'";

	# Check if the farm exists
	if ( not &getFarmExists( $farmname ) )
	{
		my $msg = "Farm not found";
		&httpErrorResponse( code => 404, desc => $desc, msg => $msg );
	}

	# Check if the farm exists
	if ( &getFarmType( $farmname ) ne 'https' )
	{
		my $msg = "This feature is only available for 'https' farms";
		&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
	}

	my $params = &getZAPIModel( "farm_certificate-add.json" );

	# Check allowed parameters
	my $error_msg = &checkZAPIParams( $json_obj, $params, $desc );
	if ( $error_msg )
	{
		&httpErrorResponse( code => 400, desc => $desc, msg => $error_msg );
	}

	my $configdir = &getGlobalConfiguration( 'certdir' );

	# validate certificate filename and format
	unless ( -f ( $configdir . "/" . $json_obj->{ file } ) )
	{
		my $msg = "The certificate does not exist.";
		&httpErrorResponse( code => 404, desc => $desc, msg => $msg );
	}

	my $cert_in_use;
		$cert_in_use = &getFarmCertificate( $farmname ) eq $json_obj->{ file };

	if ( $cert_in_use )
	{
		my $msg = "The certificate already exists in the farm.";
		&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
	}

	my $status;
		$status = &setFarmCertificate( $json_obj->{ file }, $farmname );

	if ( $status )
	{
		my $msg =
		  "It's not possible to add the certificate with name $json_obj->{file} for the $farmname farm";

		&zenlog( "It's not possible to add the certificate.", "error", "LSLB" );
		&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
	}

	# no errors found, return succesful response
	&zenlog( "Success trying to add a certificate to the farm.", "info", "LSLB" );

	my $message =
	  "The certificate $json_obj->{file} has been added to the farm $farmname, you need restart the farm to apply";

	my $body = {
				 description => $desc,
				 success     => "true",
				 message     => $message,
	};

	if ( &getFarmStatus( $farmname ) ne 'down' )
	{
		require Zevenet::Farm::Action;
		if ( &getGlobalConfiguration( 'proxy_ng' ) ne 'true' )
		{
			&setFarmRestart( $farmname );
			$body->{ status } = 'needed restart';
		}
		else
		{
			require Zevenet::Farm::HTTP::Config;
			my $config_error = &getHTTPFarmConfigErrorMessage( $farmname );
			if ( $config_error ne "" )
			{
				$body->{ warning } = "Farm '$farmname' config error: $config_error";
			}
			else
			{
				&runFarmReload( $farmname );
			}
		}
	}

	&httpResponse( { code => 200, body => $body } );
	return;
}

# DELETE /farms/FARM/certificates/CERTIFICATE
sub delete_farm_certificate    # ( $farmname, $certfilename )
{
	&zenlog( __FILE__ . q{:} . __LINE__ . q{:} . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $farmname     = shift;
	my $certfilename = shift;

	require Zevenet::Farm::Core;
	require Zevenet::Farm::Base;

	my $desc = "Delete farm certificate";

		my $msg = "HTTPS farm without certificate is not allowed.";
		&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
	return;
}

# POST /certificates/pem (Create PEM)
sub create_certificate    # ()
{
	&zenlog( __FILE__ . q{:} . __LINE__ . q{:} . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $json_obj = shift;
	my $desc     = "Create certificate";

	my $configdir = &getGlobalConfiguration( 'certdir' );

	if ( -f "$configdir/$json_obj->{ name }.pem" )
	{
		my $msg = "$json_obj->{ name } already exists.";
		&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
	}

	my $params = &getZAPIModel( "certificate_pem-create.json" );

	# Check allowed parameters
	my $error_msg = &checkZAPIParams( $json_obj, $params, $desc );
	if ( $error_msg )
	{
		&httpErrorResponse( code => 400, desc => $desc, msg => $error_msg );
	}

	require Zevenet::Certificate;
	my $error = &createPEM( $json_obj->{ name },
							$json_obj->{ key },
							$json_obj->{ ca },
							$json_obj->{ intermediates } );

	if ( $error->{ code } )
	{
		&httpErrorResponse( code => 400, desc => $desc, msg => $error->{ desc } );
	}

	# no errors found, return sucessful response
	my $message = "Certificate $json_obj->{ name } created";
	my $body = {
				 description => $desc,
				 success     => "true",
				 message     => $message,
	};

	&httpResponse( { code => 200, body => $body } );
	return;

}

1;
