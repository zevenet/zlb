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

		if ( fgrep { /Cert \"$certdir\/$cfile\"/ } "$configdir/$farm_filename" )
		{
			$output = 0;
		}
	}

	return $output;
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

	# escaping special caracters
	$certname = quotemeta $certname;
	my $certdir;

	$certdir = &getGlobalConfiguration( 'certdir' );

	# verify existance in config directory for security reasons
	opendir ( DIR, $certdir );
	my @file = grep ( /^$certname$/, readdir ( DIR ) );
	closedir ( DIR );

	my $files_removed = unlink ( "$certdir\/$file[0]" );

	&zenlog( "Error removing certificate $certdir\/$file[0]", "error", "LSLB" )
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

Returns:
	list - List of lines with the information stored in the certificate.

Bugs:

See Also:
	zapi/v3/certificates.cgi
=cut

sub getCertData    # ($certfile)
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my ( $filepath ) = @_;

	my $cmd;

	if ( &getCertType( $filepath ) eq "Certificate" )
	{
		$cmd = "$openssl x509 -in $filepath -text";
	}
	else
	{
		$cmd = "$openssl req -in $filepath -text";
	}

	return @{ &logAndGet( $cmd, "array" ) };
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
		status, status of the certificate. 'expired' if the certificate is expired, 'about to expire' if the expiration date is in less than 15 days, 'valid' the expiration date is greater than 15 days

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
		my $x509 = Crypt::OpenSSL::X509->new_from_file( $filepath );

		my $time_offset = 60 * 60 * 24 * 15;    # 15 days
		my $status;
		if ( $x509->checkend( 0 ) ) { $status = 'expired' }
		else
		{
			$status = ( $x509->checkend( $time_offset ) ) ? 'about to expire' : 'valid';
		}

		my $CN = "no CN";
		if ( defined $x509->subject_name()->get_entry_by_type( 'CN' ) )
		{
			$CN = $x509->subject_name()->get_entry_by_type( 'CN' )->value;
		}
		my $ISSUER = "no issuer";
		if ( defined $x509->issuer_name()->get_entry_by_type( 'CN' ) )
		{
			$ISSUER = $x509->issuer_name()->get_entry_by_type( 'CN' )->value;
		}

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

1;

