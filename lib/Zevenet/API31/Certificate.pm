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

my $CSR_KEY_SIZE = 2048;

# GET /certificates
sub certificates # ()
{
	require Zevenet::Certificate;

	my $desc         = "List certificates";
	my @certificates = &getCertFiles();
	my $configdir    = &getGlobalConfiguration( 'configdir' );
	my @out;

	foreach my $cert ( @certificates )
	{
		push @out, &getCertInfo( $cert, $configdir );
	}

	my $body = {
				 description => $desc,
				 params      => \@out,
	};

	&httpResponse({ code => 200, body => $body });
}

# GET /certificates/CERTIFICATE
sub download_certificate # ()
{
	my $cert_filename = shift;

	my $desc = "Download certificate";
	my $cert_dir = &getGlobalConfiguration('configdir');
	$cert_dir = &getGlobalConfiguration('basedir') if $cert_filename eq 'zlbcertfile.pem';

	open ( my $download_fh, '<', "$cert_dir/$cert_filename" );

	if ( $cert_filename =~ /\.(pem|csr)$/ && -f "$cert_dir\/$cert_filename" && $download_fh )
	{
		my $cgi = &getCGI();
		print $cgi->header(
						  -type            => 'application/x-download',
						  -attachment      => $cert_filename,
						  'Content-length' => -s "$cert_dir/$cert_filename",
		);

		binmode $download_fh;
		print while <$download_fh>;
		close $download_fh;
		exit;
	}
	else
	{
		my $msg = "Could not send such certificate";
		&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
	}
}

# GET /certificates/CERTIFICATE/info
sub get_certificate_info # ()
{
	my $cert_filename = shift;

	require Zevenet::Certificate;

	my $desc = "Show certificate details";
	my $cert_dir = &getGlobalConfiguration('configdir');
	$cert_dir = &getGlobalConfiguration('basedir') if $cert_filename eq 'zlbcertfile.pem';

	if ( &getValidFormat( 'certificate', $cert_filename ) && -f "$cert_dir\/$cert_filename" )
	{
		my @cert_info = &getCertData( $cert_filename );
		my $body;

		foreach my $line ( @cert_info )
		{
			$body .= $line;
		}

		&httpResponse({ code => 200, body => $body, type => 'text/plain' });
	}
	else
	{
		my $msg = "Could not get such certificate information";
		&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
	}
}

# DELETE /certificates/CERTIFICATE
sub delete_certificate # ( $cert_filename )
{
	my $cert_filename = shift;

	require Zevenet::Certificate;

	my $desc     = "Delete certificate";
	my $cert_dir = &getGlobalConfiguration( 'configdir' );

	$cert_dir = &getGlobalConfiguration('basedir') if $cert_filename eq 'zlbcertfile.pem';

	# check is the certificate file exists
	if ( ! -f "$cert_dir\/$cert_filename" )
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

	&httpResponse({ code => 200, body => $body });
}

# POST /certificates (Create CSR)
sub create_csr
{
	my $json_obj = shift;

	require Zevenet::Certificate;

	my $desc      = 'Create CSR';
	my $configdir = &getGlobalConfiguration( 'configdir' );

	if ( -f "$configdir/$json_obj->{name}.csr" )
	{
		my $msg = "$json_obj->{name} already exists.";
		&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
	}

	$json_obj->{ name }         = &getCleanBlanc( $json_obj->{ name } );
	#~ $json_obj->{ issuer }       = &getCleanBlanc( $json_obj->{ issuer } );
	$json_obj->{ fqdn }         = &getCleanBlanc( $json_obj->{ fqdn } );
	$json_obj->{ division }     = &getCleanBlanc( $json_obj->{ division } );
	$json_obj->{ organization } = &getCleanBlanc( $json_obj->{ organization } );
	$json_obj->{ locality }     = &getCleanBlanc( $json_obj->{ locality } );
	$json_obj->{ state }        = &getCleanBlanc( $json_obj->{ state } );
	$json_obj->{ country }      = &getCleanBlanc( $json_obj->{ country } );
	$json_obj->{ mail }         = &getCleanBlanc( $json_obj->{ mail } );

	if (    $json_obj->{ name } =~ /^$/
		 #~ || $json_obj->{ issuer } =~ /^$/
		 || $json_obj->{ fqdn } =~ /^$/
		 || $json_obj->{ division } =~ /^$/
		 || $json_obj->{ organization } =~ /^$/
		 || $json_obj->{ locality } =~ /^$/
		 || $json_obj->{ state } =~ /^$/
		 || $json_obj->{ country } =~ /^$/
		 || $json_obj->{ mail } =~ /^$/
		 #~ || $json_obj->{ key } =~ /^$/
		 )
	{
		my $msg = "Fields can not be empty. Try again.";
		&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
	}

	if ( &checkFQDN( $json_obj->{ fqdn } ) eq "false" )
	{
		my $msg = "FQDN is not valid. It must be as these examples: domain.com, mail.domain.com, or *.domain.com. Try again.";
		&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
	}

	if ( $json_obj->{ name } !~ /^[a-zA-Z0-9\-]*$/ )
	{
		my $msg = "Certificate Name is not valid. Only letters, numbers and '-' chararter are allowed. Try again.";
		&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
	}

	my $error = &createCSR(
				$json_obj->{ name },     $json_obj->{ fqdn },     $json_obj->{ country },
				$json_obj->{ state },    $json_obj->{ locality }, $json_obj->{ organization },
				$json_obj->{ division }, $json_obj->{ mail },     $CSR_KEY_SIZE,
				""
	);

	if ( $error )
	{
		my $msg = "Error, creating certificate $json_obj->{ name }.";
		&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
	}

	my $message = "Certificate $json_obj->{ name } created";
	&zenlog( $message );

	my $body = {
				description => $desc,
				success     => "true",
				message     => $message,
	};

	&httpResponse({ code => 200, body => $body });
}

# POST /certificates/CERTIFICATE (Upload PEM)
sub upload_certificate # ()
{
	my $upload_filehandle = shift;
	my $filename          = shift;

	my $desc      = "Upload PEM certificate";
	my $configdir = &getGlobalConfiguration( 'configdir' );

	if ( not &getValidFormat( 'certificate', $filename ) )
	{
		my $msg = "Invalid certificate file name";
		&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
	}

	# check if the certificate filename already exists
	$filename =~ s/[\(\)\@ ]//g;
	if ( -f "$configdir/$filename" )
	{
		my $msg = "Certificate file name already exists";
		&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
	}

	if ( $filename =~ /\\/ )
	{
		my @filen = split ( /\\/, $filename );
		$filename = $filen[-1];
	}

	open ( my $cert_filehandle, '>', "$configdir/$filename" ) or die "$!";
	print $cert_filehandle $upload_filehandle;
	close $cert_filehandle;

	# no errors found, return sucessful response
	my $message = "Certificate uploaded";
	my $body = {
				 description => $desc,
				 success     => "true",
				 message     => $message,
	};

	&httpResponse({ code => 200, body => $body });
}

1;
