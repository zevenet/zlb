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
	my $configdir = &getGlobalConfiguration( 'configdir' );

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
	my @eject = `$openssl $type -noout -in $certfile -text | grep Subject:`;

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
		my @eject = `$openssl x509 -noout -in $certfile -text | grep Issuer:`;
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

	#~ use File::stat;
	#~ use Time::localtime;

	my $datecreation = "";

	if ( &getCertType( $certfile ) eq "Certificate" )
	{
		my @eject = `$openssl x509 -noout -in $certfile -dates`;
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
		my @eject = `$openssl x509 -noout -in $certfile -dates`;
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

	my $configdir = &getGlobalConfiguration( 'configdir' );
	my @farms     = &getFarmsByType( "https" );
	my $output    = -1;

	for ( @farms )
	{
		my $fname         = $_;
		my $farm_filename = &getFarmFile( $fname );

		use File::Grep qw( fgrep );

		if ( fgrep { /Cert \"$configdir\/$cfile\"/ } "$configdir/$farm_filename" )
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

	$certdir = &getGlobalConfiguration( 'configdir' );

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

	my $configdir = &getGlobalConfiguration( 'configdir' );
	my $output;

	##sustituir los espacios por guiones bajos en el nombre de archivo###
	if ( $certpassword eq "" )
	{
		&zenlog(
			"Creating CSR: $openssl req -nodes -newkey rsa:$certkey -keyout $configdir/$certname.key -out $configdir/$certname.csr -batch -subj \"/C=$certcountry\/ST=$certstate/L=$certlocality/O=$certorganization/OU=$certdivision/CN=$certfqdn/emailAddress=$certmail\"",
			"info", "LSLB"
		);
		$output =
		  system (
			"$openssl req -nodes -newkey rsa:$certkey -keyout $configdir/$certname.key -out $configdir/$certname.csr -batch -subj \"/C=$certcountry\/ST=$certstate/L=$certlocality/O=$certorganization/OU=$certdivision/CN=$certfqdn/emailAddress=$certmail\" 2> /dev/null"
		  );
	}
	else
	{
		$output =
		  system (
			"$openssl req -passout pass:$certpassword -newkey rsa:$certkey -keyout $configdir/$certname.key -out $configdir/$certname.csr -batch -subj \"/C=$certcountry/ST=$certstate/L=$certlocality/O=$certorganization/OU=$certdivision/CN=$certfqdn/emailAddress=$certmail\" 2> /dev/null"
		  );
		&zenlog(
			"Creating CSR: $openssl req -passout pass:$certpassword -newkey rsa:$certkey -keyout $configdir/$certname.key -out $configdir/$certname.csr -batch -subj \"/C=$certcountry\/ST=$certstate/L=$certlocality/O=$certorganization/OU=$certdivision/CN=$certfqdn/emailAddress=$certmail\"",
			"info", "LSLB"
		);
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

	my @eject;

	if ( &getCertType( $filepath ) eq "Certificate" )
	{
		@eject = `$openssl x509 -in $filepath -text`;
	}
	else
	{
		@eject = `$openssl req -in $filepath -text`;
	}

	return @eject;
}

sub getCertInfo    # ($certfile)
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );

	my $filepath = shift;
	my $certfile;

	if ( $filepath =~ /([^\/]+)$/ )
	{
		$certfile = $1;
	}

	my @cert_data;

	# Cert type
	my $type = "none";

	if    ( $certfile =~ /\.(?:pem|crt)$/ ) { $type = "Certificate"; }
	elsif ( $certfile =~ /\.csr$/ )         { $type = "CSR"; }

	if ( $type eq "Certificate" )
	{
		@cert_data = `$openssl x509 -in $filepath -text`;
	}
	elsif ( $type eq "CSR" ) { @cert_data = `$openssl req -in $filepath -text`; }

# Cert CN
# Stretch: Subject: C = SP, ST = SP, L = SP, O = Test, O = f9**3b, OU = al**X6, CN = zevenet-hostname, emailAddress = cr**@zevenet.com
# Jessie:  Subject: C=SP, ST=SP, L=SP, O=Test, O=f9**3b, OU=al**X6, CN=zevenet-hostname/emailAddress=cr**@zevenet.com
	my $cn;
	my $key;
	my $key2;
	{
		my ( $string ) = grep ( /\sSubject: /, @cert_data );
		chomp $string;
		$string =~ s/Subject://;

		my @data = split ( /,/, $string );

		foreach my $param ( @data )
		{
			if ( $param =~ /CN ?= ?(.+)/ )
			{
				$cn = $1;
			}
			elsif ( $param =~ /OU ?= ?(.+)/ )
			{
				$key = $1;
			}
			elsif ( $param =~ /1\.2\.3\.4\.5\.8 ?= ?(.+)/ )
			{
				$key2 = $1;
			}
		}
		$key = $key2 if ( $key eq 'false' );
	}

	# Cert Issuer
	my $issuer = "";
	if ( $type eq "Certificate" )
	{
		my ( $line ) = grep ( /Issuer:/, @cert_data );
		my @data = split ( /,/, $line );

		foreach my $param ( @data )
		{
			if ( $param =~ /CN ?= ?(.*)$/ )
			{
				$issuer = $1;
			}
		}
	}
	elsif ( $type eq "CSR" )
	{
		$issuer = "NA";
	}

	# Cert Creation Date
	my $creation = "";
	if ( $type eq "Certificate" )
	{
		my ( $line ) = grep /\sNot Before/, @cert_data;

		#~ my @eject = `$openssl x509 -noout -in $certfile -dates`;
		( undef, $creation ) = split ( /: /, $line );
	}
	elsif ( $type eq "CSR" )
	{
		my @eject = split ( / /, gmtime ( stat ( $filepath )->mtime ) );
		splice ( @eject, 0, 1 );
		push ( @eject, "GMT" );
		$creation = join ( ' ', @eject );
	}
	chomp $creation;
	$creation = `date -d "${creation}" +%F" "%T" "%Z -u`;
	chomp $creation;

	# Cert Expiration Date
	my $expiration = "";
	if ( $type eq "Certificate" )
	{
		my ( $line ) = grep /\sNot After/, @cert_data;
		( undef, $expiration ) = split ( /: /, $line );
		chomp $expiration;
		$expiration = `date -d "${expiration}" +%F" "%T" "%Z -u`;
		chomp $expiration;
	}
	elsif ( $type eq "CSR" )
	{
		$expiration = "NA";
	}

	my %response = (
					 file       => $certfile,
					 type       => $type,
					 CN         => $cn,
					 key        => $key,
					 issuer     => $issuer,
					 creation   => $creation,
					 expiration => $expiration,
	);

	return \%response;
}

# 2018-05-17 15:04:52 UTC
# May 17 15:04:52 2018 GMT
sub getDateEpoc
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $date_string = shift @_;
	my @months      = qw(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec);

	my ( $year, $month, $day, $hours, $min, $sec ) = split /[ :-]+/, $date_string;

	# the range of the month is from 0 to 11
	$month--;
	return timegm( $sec, $min, $hours, $day, $month, $year );
}

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
