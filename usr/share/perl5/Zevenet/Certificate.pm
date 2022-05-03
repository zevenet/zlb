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

use File::stat;
use Time::localtime;

use Zevenet::Core;

my $openssl = &getGlobalConfiguration( 'openssl' );

=begin nd
Function: getCertFiles

	Returns a list of all .pem and .csr certificate files in the config directory.

Parameters:
	none - .

Returns:
	list - certificate files in config/ directory.

Bugs:

See Also:
	zapi/v3/certificates.cgi, zapi/v2/certificates.cgi
=cut

sub getCertFiles    # ()
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $configdir = &getGlobalConfiguration( 'certdir' );

	opendir ( DIR, $configdir );
	my @files = grep ( /.*\.pem$/, readdir ( DIR ) );
	@files = grep ( !/_dh\d+\.pem$/, @files );
	closedir ( DIR );

	opendir ( DIR, $configdir );
	push ( @files, grep ( /.*\.csr$/, readdir ( DIR ) ) );
	closedir ( DIR );

	return @files;
}

=begin nd
Function: getCertFiles

	Returns a list of only .pem certificate files in the config directory.

Parameters:
	none - .

Returns:
	list - certificate files in config/ directory.

=cut

sub getPemCertFiles    # ()
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $configdir = &getGlobalConfiguration( 'certdir' );

	opendir ( DIR, $configdir );
	my @files = grep ( /.*\.pem$/, readdir ( DIR ) );
	@files = grep ( !/_dh\d+\.pem$/, @files );
	closedir ( DIR );

	return @files;
}

=begin nd
Function: getCleanBlanc

	Delete all blancs from the beginning and from the end of a variable.

Parameters:
	String - String possibly starting and/or ending with space characters.

Returns:
	String - String without space characters at the beginning or at the end.

Bugs:

See Also:
	<getCertCN>, <getCertIssuer>, zapi/v3/certificates.cgi
=cut

sub getCleanBlanc    # ($vartoclean)
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my ( $vartoclean ) = @_;

	$vartoclean =~ s/^\s+//;
	$vartoclean =~ s/\s+$//;

	return $vartoclean;
}

=begin nd
Function: getCertType

	Return the type of a certificate filename.

	The certificate types are:
	Certificate - For .pem or .crt certificates
	CSR - For .csr certificates
	none - for any other file or certificate

Parameters:
	String - Certificate filename.

Returns:
	String - Certificate type.

Bugs:

See Also:
	<getCertCN>, <getCertIssuer>, <getCertCreation>, <getCertExpiration>, <getCertData>, zapi/v3/certificates.cgi, zapi/v2/certificates.cgi
=cut

sub getCertType    # ($certfile)
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my ( $certfile ) = @_;
	my $certtype = "none";

	if ( $certfile =~ /\.pem/ || $certfile =~ /\.crt/ )
	{
		$certtype = "Certificate";
	}
	elsif ( $certfile =~ /\.csr/ )
	{
		$certtype = "CSR";
	}

	return $certtype;
}

=begin nd
Function: getCertCN

	Return the Common Name of a certificate file

Parameters:
	String - Certificate filename.

Returns:
	String - Certificate's Common Name.

Bugs:

See Also:
	zapi/v3/certificates.cgi, zapi/v2/certificates.cgi
=cut

sub getCertCN    # ($certfile)
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my ( $certfile ) = @_;
	my $certcn = "";

	my $type = ( &getCertType( $certfile ) eq "Certificate" ) ? "x509" : "req";
	my @eject = @{
		&logAndGet( "$openssl $type -noout -in $certfile -text | grep Subject:",
					"array" )
	};

	my $string = $eject[0];
	chomp $string;
	$string =~ s/Subject://;

	my @data = split ( /,/, $string );

	foreach my $param ( @data )
	{
		$certcn = $1 if ( $param =~ /CN ?=(.+)/ );
	}
	$certcn = &getCleanBlanc( $certcn );

	return $certcn;
}

=begin nd
Function: getCertIssuer

	Return the Issuer Common Name of a certificate file

Parameters:
	String - Certificate filename.

Returns:
	String - Certificate issuer.

Bugs:

See Also:
	zapi/v3/certificates.cgi, zapi/v2/certificates.cgi
=cut

sub getCertIssuer    # ($certfile)
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my ( $certfile ) = @_;
	my $certissu = "";

	if ( &getCertType( $certfile ) eq "Certificate" )
	{
		my @eject = @{
			&logAndGet(
						"$openssl x509 -noout -in $certfile -text | grep Issuer:",
						"array"
			)
		};
		@eject = split ( /CN=/,             $eject[0] );
		@eject = split ( /\/emailAddress=/, $eject[1] );
		$certissu = $eject[0] // '';
	}
	else
	{
		$certissu = "NA";
	}

	$certissu = &getCleanBlanc( $certissu );

	return $certissu;
}

=begin nd
Function: getCertCreation

	Return the creation date of a certificate file

Parameters:
	String - Certificate filename.

Returns:
	String - Creation date.

Bugs:

See Also:
	zapi/v3/certificates.cgi, zapi/v2/certificates.cgi
=cut

sub getCertCreation    # ($certfile)
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my ( $certfile ) = @_;

	my $datecreation = "";

	if ( &getCertType( $certfile ) eq "Certificate" )
	{
		my @eject =
		  @{ &logAndGet( "$openssl x509 -noout -in $certfile -dates", "array" ) };
		my @datefrom = split ( /=/, $eject[0] );
		$datecreation = $datefrom[1];
	}
	else
	{
		my @eject = split ( / /, gmtime ( stat ( $certfile )->mtime ) );
		splice ( @eject, 0, 1 );
		push ( @eject, "GMT" );
		$datecreation = join ( ' ', @eject );
	}

	return $datecreation;
}

=begin nd
Function: getCertExpiration

	Return the expiration date of a certificate file

Parameters:
	String - Certificate filename.

Returns:
	String - Expiration date.

Bugs:

See Also:
	zapi/v3/certificates.cgi, zapi/v2/certificates.cgi
=cut

sub getCertExpiration    # ($certfile)
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my ( $certfile ) = @_;
	my $dateexpiration = "";

	if ( &getCertType( $certfile ) eq "Certificate" )
	{
		my @eject =
		  @{ &logAndGet( "$openssl x509 -noout -in $certfile -dates", "array" ) };
		my @dateto = split ( /=/, $eject[1] );
		$dateexpiration = $dateto[1];
	}
	else
	{
		$dateexpiration = "NA";
	}

	return $dateexpiration;
}

=begin nd
Function: getFarmCertUsed

	Get is a certificate file is being used by an HTTP farm

Parameters:
	String - Certificate filename.

Returns:
	Integer - 0 if the certificate is being used, or -1 if it is not.

Bugs:

See Also:
	zapi/v3/certificates.cgi, zapi/v2/certificates.cgi
=cut

sub getFarmCertUsed    #($cfile)
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my ( $cfile ) = @_;

	require Zevenet::Farm::Core;

	my $certdir   = &getGlobalConfiguration( 'certdir' );
	my $configdir = &getGlobalConfiguration( 'configdir' );
	my @farms     = &getFarmsByType( "https" );
	my $output    = -1;

	for ( @farms )
	{
		my $fname         = $_;
		my $farm_filename = &getFarmFile( $fname );

		use File::Grep qw( fgrep );

		if ( fgrep { /Cert \"$certdir\/\Q$cfile\E\"/ } "$configdir/$farm_filename" )
		{
			$output = 0;
		}
	}

	return $output;
}

=begin nd
Function: getFarmCertUsed

	Get HTTPS Farms list using the certificate file. 

Parameters:
	String - Certificate filename.

Returns:
	Array ref - Farm list using the certificate.

=cut

sub getCertFarmsUsed    #($cfile)
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my ( $cfile ) = @_;

	require Zevenet::Farm::Core;

	my $certdir   = &getGlobalConfiguration( 'certdir' );
	my $configdir = &getGlobalConfiguration( 'configdir' );
	my @farms     = &getFarmsByType( "https" );
	my $farms_ref = [];

	foreach my $farm_name ( @farms )
	{
		my $farm_filename = &getFarmFile( $farm_name );

		use File::Grep qw( fgrep );

		if ( fgrep { /Cert \"$certdir\/\Q$cfile\E\"/ } "$configdir/$farm_filename" )
		{
			push @{ $farms_ref }, $farm_name;
		}
	}

	return $farms_ref;
}

=begin nd
Function: checkFQDN

	Check if a FQDN is valid

Parameters:
	certfqdn - FQDN.

Returns:
	String - Boolean 'true' or 'false'.

Bugs:

See Also:
	zapi/v3/certificates.cgi
=cut

sub checkFQDN    # ($certfqdn)
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my ( $certfqdn ) = @_;
	my $valid = "true";

	if ( $certfqdn =~ /^http:/ )
	{
		$valid = "false";
	}
	if ( $certfqdn =~ /^\./ )
	{
		$valid = "false";
	}
	if ( $certfqdn =~ /\.$/ )
	{
		$valid = "false";
	}
	if ( $certfqdn =~ /\// )
	{
		$valid = "false";
	}

	return $valid;
}

=begin nd
Function: delCert

	Removes a certificate file

Parameters:
	String - Certificate filename.

Returns:
	Integer - Number of files removed.

Bugs:
	Removes the _first_ file found _starting_ with the given certificate name.

See Also:
	zapi/v3/certificates.cgi, zapi/v2/certificates.cgi
=cut

sub delCert    # ($certname)
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my ( $certname ) = @_;

	my $certdir = &getGlobalConfiguration( 'certdir' );

	# escaping special caracters
	$certname =~ s/ /\ /g;

	my $files_removed;

	# verify existance in config directory for security reasons
	if ( -f "$certdir/$certname" )
	{
		$files_removed = unlink ( "$certdir/$certname" );

		my $key_file = $certname;
		$key_file =~ s/\.pem$/\.key/;

		if ( -f "$certdir/$key_file" )
		{
			unlink ( "$certdir/$key_file" );
		}

		# remove key file for CSR
		if ( $certname =~ /.csr$/ )
		{
			my $key_file = $certname;
			$key_file =~ s/\.csr$/\.key/;

			if ( -f "$certdir/$key_file" )
			{
				unlink "$certdir/$key_file";
			}
			else
			{
				&zenlog( "Key file was not found '$certdir/$key_file'", "error", "LSLB" );
			}
		}
	}

	&zenlog( "Error removing certificate '$certdir/$certname'", "error", "LSLB" )
	  if !$files_removed;

	return $files_removed;
}

=begin nd
Function: createCSR

	Create a CSR file.

	If the function run correctly two files will appear in the config/ directory:
	certname.key and certname.csr.

Parameters:
	certname - Certificate name, part of the certificate filename without the extension.
	certfqdn - FQDN.
	certcountry - Country.
	certstate - State.
	certlocality - Locality.
	certorganization - Organization.
	certdivision - Division.
	certmail - E-Mail.
	certkey - Key. ¿?
	certpassword - Password. Optional.

Returns:
	Integer - Return code of openssl generating the CSR file..

Bugs:

See Also:
	zapi/v3/certificates.cgi
=cut

sub createCSR # ($certname, $certfqdn, $certcountry, $certstate, $certlocality, $certorganization, $certdivision, $certmail, $certkey, $certpassword)
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my (
		 $certname,     $certfqdn,         $certcountry,  $certstate,
		 $certlocality, $certorganization, $certdivision, $certmail,
		 $certkey,      $certpassword
	) = @_;

	my $configdir = &getGlobalConfiguration( 'certdir' );
	my $output;

	##sustituir los espacios por guiones bajos en el nombre de archivo###
	if ( $certpassword eq "" )
	{
		$output =
		  logAndRun(
			"$openssl req -nodes -newkey rsa:$certkey -keyout $configdir/$certname.key -out $configdir/$certname.csr -batch -subj \"/C=$certcountry\/ST=$certstate/L=$certlocality/O=$certorganization/OU=$certdivision/CN=$certfqdn/emailAddress=$certmail\" 2> /dev/null"
		  );
		&zenlog(
			"Creating CSR: $openssl req -nodes -newkey rsa:$certkey -keyout $configdir/$certname.key -out $configdir/$certname.csr -batch -subj \"/C=$certcountry\/ST=$certstate/L=$certlocality/O=$certorganization/OU=$certdivision/CN=$certfqdn/emailAddress=$certmail\"",
			"info", "LSLB"
		) if ( !$output );
	}
	else
	{
		$output =
		  &logAndRun(
			"$openssl req -passout pass:$certpassword -newkey rsa:$certkey -keyout $configdir/$certname.key -out $configdir/$certname.csr -batch -subj \"/C=$certcountry/ST=$certstate/L=$certlocality/O=$certorganization/OU=$certdivision/CN=$certfqdn/emailAddress=$certmail\""
		  );
		&zenlog(
			"Creating CSR: $openssl req -passout pass:$certpassword -newkey rsa:$certkey -keyout $configdir/$certname.key -out $configdir/$certname.csr -batch -subj \"/C=$certcountry\/ST=$certstate/L=$certlocality/O=$certorganization/OU=$certdivision/CN=$certfqdn/emailAddress=$certmail\"",
			"info", "LSLB"
		) if ( !$output );
	}
	return $output;
}

=begin nd
Function: getCertData

	Returns the information stored in a certificate.

Parameters:
	String - Certificate path.
	String - "true" for checking the Certificate.

Returns:
	string - It returns a string with the certificate content. It contains new line characters.

Bugs:

See Also:
	zapi/v3/certificates.cgi
=cut

sub getCertData    # ($certfile)
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my ( $filepath, $check ) = @_;

	my $cmd;
	my $filepath_orig = $filepath;
	$filepath = quotemeta ( $filepath );

	if ( &getCertType( $filepath ) eq "Certificate" )
	{
		$cmd = "$openssl x509 -in $filepath -text";
	}
	else
	{
		$cmd = "$openssl req -in $filepath -text";

		# request Certs do not need to be checked
		$check = 0;
	}

	my $cert = &logAndGet( $cmd );
	$cert = $cert eq "" ? "This certificate is not valid." : $cert;
	if ( $check )
	{
		my $status = checkCertPEMValid( $filepath_orig );
		if ( $status and $status->{ code } )
		{
			$cert = $status->{ desc };
		}
	}

	return $cert;
}

=begin nd
Function: getCertIsValid
	Check if a certificate is a valid x509 object

Parameters:
	String - Certificate path.

Returns:
	Integer - 0 if the cert is a valid x509 object, 1 if not

=cut

sub getCertIsValid    # ($cert_filepath)
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my ( $cert_filepath ) = shift;
	my $rc = 1;
	eval {
		require Crypt::OpenSSL::X509;
		my $x509 = Crypt::OpenSSL::X509->new_from_file( $cert_filepath );
		$rc = 0;
	};
	return $rc;

}

=begin nd
Function: getCertInfo

	It returns an object with the certificate information parsed

Parameters:
	certificate path - path to the certificate

Returns:
	hash ref - The hash contains the following keys:
		file, name of the certificate with extension and without path. "zert.pem"
		type, type of file. CSR or Certificate
		CN, common name
		issuer, name of the certificate authority
		creation, date of certificate creation. "019-08-13 09:31:33 UTC"
		expiration, date of certificate expiration. "2020-07-11 09:31:33 UTC"
		status, status of the certificate. 'unknown' if the file is not recognized as a certificate, 'expired' if the certificate is expired, 'about to expire' if the expiration date is in less than 15 days, 'valid' the expiration date is greater than 15 days, 'invalid' if the file is a not valid certificate

=cut

sub getCertInfo
{
	my $filepath = shift;
	my %response;

	my $certfile = "";
	if ( $filepath =~ /([^\/]+)$/ )
	{
		$certfile = $1;
	}

	# PEM
	if ( $certfile =~ /\.pem$/ )
	{
		require Crypt::OpenSSL::X509;
		my $status = "unknown";
		my $CN     = "no CN";
		my $ISSUER = "no issuer";
		my $x509;
		eval {
			$x509 = Crypt::OpenSSL::X509->new_from_file( $filepath );

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
			if ( defined $x509->issuer_name()->get_entry_by_type( 'CN' ) )
			{
				$ISSUER = $x509->issuer_name()->get_entry_by_type( 'CN' )->value;
			}
		};
		if ( $@ )
		{
			%response = (
						  file       => $certfile,
						  type       => 'Certificate',
						  CN         => '-',
						  issuer     => '-',
						  creation   => '-',
						  expiration => '-',
						  status     => $status,
			);
		}
		else
		{
			$status = "invalid" if ( &checkCertPEMValid( $filepath )->{ code } );
			%response = (
						  file       => $certfile,
						  type       => 'Certificate',
						  CN         => $CN,
						  issuer     => $ISSUER,
						  creation   => $x509->notBefore(),
						  expiration => $x509->notAfter(),
						  status     => $status,
			);
		}
	}

	# CSR
	else
	{
		require Zevenet::File;

		my @cert_data =
		  @{ &logAndGet( "$openssl req -in $filepath -text -noout", "array" ) };

		my $cn = "";
		my ( $string ) = grep ( /\sSubject: /, @cert_data );
		if ( $string =~ /CN ?= ?([^,]+)/ )
		{
			$cn = $1;
		}

		%response = (
					  file       => $certfile,
					  type       => 'CSR',
					  CN         => $cn,
					  issuer     => "NA",
					  creation   => &getFileDateGmt( $filepath ),
					  expiration => "NA",
					  status     => 'valid',
		);
	}

	return \%response;
}

=begin nd
Function: getDateEpoc

	It converts a human date (2018-05-17 15:04:52 UTC) in a epoc date (1594459893)

Parameters:
	date - string with the date. The string has to be as "2018-05-17 15:04:52"

Returns:
	Integer - Time in epoc time. "1594459893"
=cut

sub getDateEpoc
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $date_string = shift @_;

	# my @months      = qw(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec);

	my ( $year, $month, $day, $hours, $min, $sec ) = split /[ :-]+/, $date_string;

	# the range of the month is from 0 to 11
	$month--;
	return timegm( $sec, $min, $hours, $day, $month, $year );
}

=begin nd
Function: getCertDaysToExpire

	It calculates the number of days to expire the certificate.

Parameters:
	ending date - String with the ending date with the following format "2018-05-17 15:04:52 UTC"

Returns:
	Integer - Number of days to expire the certificate
=cut

sub getCertDaysToExpire
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my ( $cert_ends ) = @_;

	use Time::Local;

	my $end       = &getDateEpoc( $cert_ends );
	my $days_left = ( $end - time () ) / 86400;

	# leave only two decimals
	if ( $days_left < 1 )
	{
		$days_left *= 100;
		$days_left =~ s/\..*//g;
		$days_left /= 100;
	}
	else
	{
		$days_left =~ s/\..*//g;
	}

	return $days_left;
}

=begin nd
Function: checkCertPEMFormat

	Checks if a certificate is in PEM Format: Text File and headers --BEGIN-- and --END--

Parameters:
	cert_path - path to the certificate

Returns:

	0 if the certificate is in PEM Format, otherwise 1
=cut

sub checkCertPEMFormat    # ( $cert_path )
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my ( $cert_path ) = @_;

	my $rc = 1;
	if ( -T $cert_path )
	{
		require Tie::File;
		use Fcntl 'O_RDONLY';
		tie my @cert_file, 'Tie::File', "$cert_path", mode => O_RDONLY;
		my $found = 0;
		my $begin = 0;
		foreach ( @cert_file )
		{
			if ( $_ =~ /^-+BEGIN.*-+$/ )
			{
				$begin = 1;
			}
			if ( ( $_ =~ /^-+END.*-+$/ ) and ( $begin ) )
			{
				$found++;
			}
		}
		$rc = 0 if $found;
	}
	return $rc;
}

=begin nd
Function: getCertPEM

	It returns an object with all certificates: key, fullchain

Parameters:
	cert_path - path to the certificate

Returns:

	hash ref - List of certificates : key, fullchain
=cut

sub getCertPEM    # ( $cert_path )
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my ( $cert_path ) = @_;
	my $pem_config;

	if ( -T $cert_path )
	{
		require Tie::File;
		use Fcntl 'O_RDONLY';
		tie my @cert_file, 'Tie::File', "$cert_path", mode => O_RDONLY;
		my $key_boundary         = 0;
		my $certificate_boundary = 0;
		my $cert;
		foreach ( @cert_file )
		{

			if ( $_ =~ /^-+BEGIN.*KEY-+/ )
			{
				$key_boundary = 1;
			}
			if ( $_ =~ /^-+BEGIN.*CERTIFICATE-+/ )
			{
				$certificate_boundary = 1;
			}
			if ( $key_boundary )
			{
				push @{ $pem_config->{ key } }, $_;
			}
			if ( $certificate_boundary )
			{
				push @{ $cert }, $_;
			}
			if ( ( $_ =~ /^-+END.*KEY-+/ ) and ( $key_boundary ) )
			{
				$key_boundary = 0;
				next;
			}
			if ( ( $_ =~ /^-+END.*CERTIFICATE-+/ ) and ( $certificate_boundary ) )
			{
				push @{ $pem_config->{ fullchain } }, $cert;
				$certificate_boundary = 0;
				$cert                 = undef;
				next;
			}
		}
	}
	return $pem_config;

}

=begin nd
Function: checkCertPEMKeyEncrypted

	Checks if a certificate private key in PEM format is encrypted.

Parameters:
	cert_path - path to the certificate

Returns:

	Integer - 0 if it is not encrypted, 1 if encrypted, -1 on error.
=cut

sub checkCertPEMKeyEncrypted    # ( $cert_path )
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my ( $cert_path ) = @_;
	my $rc            = -1;
	my $pem_config    = &getCertPEM( $cert_path );
	if ( ( $pem_config ) and ( $pem_config->{ key } ) )
	{
		$rc = 0;
		use Net::SSLeay;
		$Net::SSLeay::trace = 1;
		my $bio_key = Net::SSLeay::BIO_new_file( $cert_path, 'r' );

		# Loads PEM formatted private key via given BIO structure using empty password
		unless ( Net::SSLeay::PEM_read_bio_PrivateKey( $bio_key, undef, "" ) )
		{
			my $error     = Net::SSLeay::ERR_error_string( Net::SSLeay::ERR_get_error() );
			my @strerr    = split ( /:/, $error );
			my $error_str = $strerr[4];
			if ( $error_str eq "bad decrypt" )
			{
				&zenlog( "Private Key Encrypted was found in '$cert_path': " . $strerr[4],
						 "debug", "LSLB" );
				$rc = 1;
			}
			else
			{
				&zenlog( "Error checking Private Key Encrypted in '$cert_path': " . $strerr[4],
						 "debug", "LSLB" );
				$rc = -1;
			}
		}
		Net::SSLeay::BIO_free( $bio_key );
	}
	return $rc;
}

=begin nd
Function: checkCertPEMValid

	Checks if a certificate is in PEM format and has a valid structure.
	The certificates must be in PEM format and must be sorted starting with the subject's certificate (actual client or server certificate), followed by intermediate CA certificates if applicable, and ending at the highest level (root) CA. The Private key has to be unencrypted.

Parameters:
	cert_path - path to the certificate

Returns: 	

	error_ref - error object. code = 0 if the PEM file is valid,

Variable: $error_ref.

 	A hashref that maps error code and description         
		$error_ref->{ code } - Integer.Error code
		$error_ref->{ desc } - String. Description of the error.
=cut

sub checkCertPEMValid    # ( $cert_path )
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my ( $cert_path ) = @_;
	my $error_ref->{ code } = 0;
	use Net::SSLeay;
	$Net::SSLeay::trace = 1;
	my $ctx = Net::SSLeay::CTX_new_with_method( Net::SSLeay::SSLv23_method() );
	if ( !$ctx )
	{
		my $error_msg = "Error check PEM certificate";
		$error_ref->{ code } = -1;
		$error_ref->{ desc } = $error_msg;
		my $error     = Net::SSLeay::ERR_error_string( Net::SSLeay::ERR_get_error() );
		my @strerr    = split ( /:/, $error );
		my $error_str = $strerr[4];
		&zenlog( "$error_msg in '$cert_path': " . $error_str, "debug", "LSLB" );
		return $error_ref;
	}

	if ( &checkCertPEMKeyEncrypted( $cert_path ) == 1 )
	{
		Net::SSLeay::CTX_free( $ctx );
		my $error_msg = "PEM file private key is encrypted";
		$error_ref->{ code } = 1;
		$error_ref->{ desc } = $error_msg;
		&zenlog( "$error_msg in '$cert_path'", "debug", "LSLB" );
		return $error_ref;
	}

	unless ( Net::SSLeay::CTX_use_certificate_chain_file( $ctx, "$cert_path" ) )
	{
		my $error = Net::SSLeay::ERR_error_string( Net::SSLeay::ERR_get_error() );
		my @strerr = split ( /:/, $error );
		Net::SSLeay::CTX_free( $ctx );
		my $error_str = $strerr[4];
		if ( $error_str eq "no start line" )
		{
			my $error_msg = "No Certificate found";
			$error_ref->{ code } = 2;
			$error_ref->{ desc } = $error_msg;
			&zenlog( "$error_msg in '$cert_path': " . $error_str, "debug", "LSLB" );
			return $error_ref;
		}
		elsif ( $error_str eq "ca md too weak" )
		{
			my $error_msg = "Cipher weak found";
			$error_ref->{ code } = 3;
			$error_ref->{ desc } = $error_msg;
			&zenlog( "$error_msg in '$cert_path': " . $error_str, "debug", "LSLB" );
			return $error_ref;
		}
		else
		{
			my $error_msg = "Error using Certificate";
			$error_ref->{ code } = 4;
			$error_ref->{ desc } = $error_msg;
			&zenlog( "$error_msg in '$cert_path': " . $error_str, "debug", "LSLB" );
			return $error_ref;
		}
	}

	unless (
			 Net::SSLeay::CTX_use_PrivateKey_file( $ctx, "$cert_path",
												   Net::SSLeay::FILETYPE_PEM() )
	  )
	{
		my $error = Net::SSLeay::ERR_error_string( Net::SSLeay::ERR_get_error() );
		my @strerr = split ( /:/, $error );
		Net::SSLeay::CTX_free( $ctx );
		my $error_str = $strerr[4];
		if ( $error_str eq "no start line" )
		{
			my $error_msg = "No Private Key found";
			$error_ref->{ code } = 5;
			$error_ref->{ desc } = $error_msg;
			&zenlog( "$error_msg in '$cert_path': " . $error_str, "debug", "LSLB" );
			return $error_ref;
		}
		elsif ( $error_str eq "key values mismatch" )
		{
			my $error_msg = "Private Key is not valid for the first Certificate found";
			$error_ref->{ code } = 6;
			$error_ref->{ desc } = $error_msg;
			&zenlog( "$error_msg in '$cert_path': " . $error_str, "debug", "LSLB" );
			return $error_ref;
		}
		else
		{
			my $error_msg = "Error using Private Key";
			$error_ref->{ code } = 7;
			$error_ref->{ desc } = $error_msg;
			&zenlog( "$error_msg in '$cert_path': " . $error_str, "debug", "LSLB" );
			return $error_ref;
		}

	}
	unless ( Net::SSLeay::CTX_check_private_key( $ctx ) )
	{
		my $error = Net::SSLeay::ERR_error_string( Net::SSLeay::ERR_get_error() );
		Net::SSLeay::CTX_free( $ctx );
		my @strerr    = split ( /:/, $error );
		my $error_str = $strerr[4];
		my $error_msg = "Error checking Private Key";
		$error_ref->{ code } = 8;
		$error_ref->{ desc } = $error_msg;
		&zenlog( "$error_msg in '$cert_path': " . $error_str, "debug", "LSLB" );
		return $error_ref;
	}

	Net::SSLeay::CTX_free( $ctx );
	return $error_ref;
}

=begin nd
Function: createPEM

	Create a valid PEM file.

Parameters:
	certname - Certificate name, part of the certificate filename without the extension.
	key - String. Private Key.
	ca - String. CA Certificate or fullchain certificates.
	intermediates - CA Intermediates Certificates.

Returns:
	error_ref - error object. code = 0 if the PEM file is created,

Variable: $error_ref.

 	A hashref that maps error code and description         
		$error_ref->{ code } - Integer.Error code
		$error_ref->{ desc } - String. Description of the error.

=cut

sub createPEM    # ( $cert_name, $cert_key, $cert_ca, $cert_intermediates )
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );

	my ( $cert_name, $cert_key, $cert_ca, $cert_intermediates ) = @_;
	my $error_ref->{ code } = 0;

	if ( !$cert_name or !$cert_key or !$cert_ca )
	{
		my $error_msg = "A required parameter is missing";
		$error_ref->{ code } = 1;
		$error_ref->{ desc } = $error_msg;
		return $error_ref;
	}

	# check certificate exists
	my $configdir = &getGlobalConfiguration( 'certdir' );
	my $cert_file = $configdir . "/" . $cert_name . ".pem";

	if ( -T $cert_file )
	{
		my $error_msg = "Certificate already exists";
		$error_ref->{ code } = 2;
		$error_ref->{ desc } = $error_msg;
		return $error_ref;
	}

	# create temp certificate
	my $tmp_cert  = "/tmp/cert_$cert_name.tmp";
	my $lock_file = &getLockFile( $tmp_cert );
	my $lock_fh   = &openlock( $lock_file, 'w' );
	my $fh        = &openlock( $tmp_cert, 'w' );
	print $fh $cert_key . "\n";
	print $fh $cert_ca . "\n";
	print $fh $cert_intermediates . "\n" if ( defined $cert_intermediates );
	close $fh;

	unless ( -T $tmp_cert )
	{
		close $lock_fh;
		my $error_msg = "Error creating Temp Certificate File";
		$error_ref->{ code } = 3;
		$error_ref->{ desc } = $error_msg;
		return $error_ref;
	}

	# check temp certificate
	my $cert_conf = &getCertPEM( $tmp_cert );
	if ( !$cert_conf->{ key } )
	{
		unlink $tmp_cert;
		close $lock_fh;
		my $error_msg = "No Private Key in PEM format found";
		$error_ref->{ code } = 4;
		$error_ref->{ desc } = $error_msg;
		return $error_ref;
	}
	if ( !$cert_conf->{ fullchain } )
	{
		unlink $tmp_cert;
		close $lock_fh;
		my $error_msg = "No Certificate in PEM format found";
		$error_ref->{ code } = 4;
		$error_ref->{ desc } = $error_msg;
		return $error_ref;
	}

	my $error = &checkCertPEMValid( $tmp_cert );
	if ( $error->{ code } )
	{
		unlink $tmp_cert;
		close $lock_fh;
		$error_ref->{ code } = 5;
		$error_ref->{ desc } = $error->{ desc } . " in generated PEM";
		return $error_ref;
	}

	# copy temp certificate
	if ( &copyLock( $tmp_cert, $cert_file ) )
	{
		unlink $tmp_cert;
		close $lock_fh;
		my $error_msg = "Error creating Certificate File";
		$error_ref->{ code } = 5;
		$error_ref->{ desc } = $error_msg;
		return $error_ref;
	}

	unlink $tmp_cert;
	close $lock_fh;
	return $error_ref;
}

1;

