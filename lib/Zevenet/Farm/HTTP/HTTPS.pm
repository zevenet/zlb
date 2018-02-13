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

my $configdir = &getGlobalConfiguration( 'configdir' );

=begin nd
Function: getHTTPFarmDHStatus

	Obtain the status of the DH file

Parameters:
	farmname - Farm name

Returns:
	scalar - on, if it is actived or off, if it is desactived

=cut
sub getHTTPFarmDHStatus    # ($farm_name)
{
	my ( $farm_name ) = @_;

	my $farm_filename = &getFarmFile( $farm_name );
	my $output        = "off";

	my $dhfile = "$configdir\/$farm_name\_dh2048.pem";
	tie my @filefarmhttp, 'Tie::File', "$configdir/$farm_filename";
	# my $match =~ /^DHParams.*/, @filefarmhttp;
	my @match = grep ( /^DHParams.*/, @filefarmhttp );
	untie @filefarmhttp;

	if ($match[0] ne "" && -e "$dhfile"){
		$output = "on";
	}

	return $output;
}

=begin nd
Function: setHTTPFarmDHStatus

	[NOT USED] Configure the status of the DH file

Parameters:
	farmname - Farm name
	status - set a status for the DH file

Returns:
	Integer - Error code: 1 on success, or 0 on failure.

=cut
sub setHTTPFarmDHStatus    # ($farm_name, $newstatus)
{
	my ( $farm_name, $newstatus ) = @_;

	my $farm_type     = &getFarmType( $farm_name );
	my $farm_filename = &getFarmFile( $farm_name );
	my $dhfile = "$configdir\/$farm_name\_dh2048.pem";
	my $output        = 0;

	tie my @filefarmhttp, 'Tie::File', "$configdir/$farm_filename";
	foreach my $row (@filefarmhttp)
	{
		if ($row =~ /.*DHParams.*/)
		{
			$row =~ s/.*DHParams.*/DHParams\t"$dhfile"/ if $newstatus eq "on";
			$row =~ s/.*DHParams/\#DHParams/ if $newstatus eq "off";
			$output = 1;
		}
	}
	untie @filefarmhttp;

	unlink ( "$dhfile" ) if -e "$dhfile" && $newstatus eq "off";

	return $output;
}

=begin nd
Function: getFarmCertificate

	Return the certificate applied to the farm

Parameters:
	farmname - Farm name

Returns:
	scalar - Return the certificate file, or -1 on failure.

FIXME:
	If are there more than one certificate, only return the last one

=cut
sub getFarmCertificate    # ($farm_name)
{
	my ( $farm_name ) = @_;

	my $farm_type = &getFarmType( $farm_name );
	my $output    = -1;

	if ( $farm_type eq "https" )
	{
		my $farm_filename = &getFarmFile( $farm_name );
		open FI, "<$configdir/$farm_filename";
		my @content = <FI>;
		close FI;
		foreach my $line ( @content )
		{
			if ( $line =~ /Cert/ && $line !~ /\#.*Cert/ )
			{
				my @partline = split ( '\"', $line );
				@partline = split ( "\/", $partline[1] );
				my $lfile = @partline;
				$output = $partline[$lfile - 1];
			}
		}
	}

	return $output;
}

=begin nd
Function: setFarmCertificate

	Configure a certificate for a HTTP farm

Parameters:
	certificate - certificate file name
	farmname - Farm name

Returns:
	Integer - Error code: 0 on success, or -1 on failure.

FIXME:
	There is other function for this action: setFarmCertificateSNI

=cut
sub setFarmCertificate    # ($cfile,$farm_name)
{
	my ( $cfile, $farm_name ) = @_;

	require Tie::File;

	my $farm_type     = &getFarmType( $farm_name );
	my $farm_filename = &getFarmFile( $farm_name );
	my $output        = -1;

	&zenlog( "setting 'Certificate $cfile' for $farm_name farm $farm_type" );
	if ( $farm_type eq "https" )
	{
		tie my @array, 'Tie::File', "$configdir/$farm_filename";
		for ( @array )
		{
			if ( $_ =~ /Cert "/ )
			{
				s/.*Cert\ .*/\tCert\ \"$configdir\/$cfile\"/g;
				$output = $?;
			}
		}
		untie @array;
	}

	return $output;
}

=begin nd
Function: validateHTTPFarmDH

	[NOT USED] Validate the farm Diffie Hellman configuration

Parameters:
	farmname - Farm name

Returns:
	Integer - always return -1

BUG
	Not finish
=cut
sub validateHTTPFarmDH    # ($farm_name)
{
	my ( $farm_name ) = @_;

	my $farm_type     = &getFarmType( $farm_name );
	my $farm_filename = &getFarmFile( $farm_name );
	my $output        = -1;

	my $dhstatus = &getHTTPFarmDHStatus($farm_name);
	if ( $farm_type eq "https" && $dhstatus ne "on" )
	{
		my $lockstatus = &getFarmLock( $farm_name );
		if ( $lockstatus !~ /Diffie-Hellman/ ) {
			#$output = &setHTTPFarmDHStatus( $farm_name, "on" );
			#&genDHFile( $farm_name );
		}
	}

	if ( $farm_type eq "http" && $dhstatus ne "on" )
	{
		#$output = &setHTTPFarmDHStatus( $farm_name, "off" );
	}

	return $output;
}

=begin nd
Function: genDHFile

	[NOT USED] Generate the Diffie Hellman keys file

Parameters:
	farmname - Farm name

Returns:
	Integer - return 0 on success or different of 0 on failure
=cut
sub genDHFile    # ($farm_name)
{
	my ( $farm_name ) = @_;

	my $farm_type     = &getFarmType( $farm_name );
	my $farm_filename = &getFarmFile( $farm_name );
	my $output        = 0;

	my $dhfile = "$configdir\/$farm_name\_dh2048.pem";

	if ( ! -e "$dhfile" )
	{
		&zenlog( "Generating DH keys in $dhfile ..." );
		&setFarmLock( $farm_name, "on", "<a href=\"https://www.zenloadbalancer.com/knowledge-base/misc/diffie-hellman-keys-generation-important/\" target=\"_blank\">Generating SSL Diffie-Hellman 2048 keys</a> <img src=\"img/loading.gif\"/>" );

		my $openssl = &getGlobalConfiguration('openssl');
		system("$openssl dhparam -5 2048 -out $dhfile &");
		$output = $?;
	}

	return $output
}

=begin nd
Function: setFarmCipherList

	Set Farm Ciphers value

Parameters:
	farmname - Farm name
	ciphers - The options are: cipherglobal, cipherpci, cipherssloffloading or ciphercustom
	cipherc - Cipher custom, this field is used when ciphers is ciphercustom

Returns:
	Integer - return 0 on success or -1 on failure
=cut
sub setFarmCipherList    # ($farm_name,$ciphers,$cipherc)
{
	# assign first/second/third argument or take global value
	my $farm_name = shift;
	my $ciphers   = shift;
	my $cipherc   = shift;

	my $farm_type     = &getFarmType( $farm_name );
	my $farm_filename = &getFarmFile( $farm_name );
	my $output        = -1;

	require Tie::File;
	tie my @array, 'Tie::File', "$configdir/$farm_filename";

	for my $line ( @array )
	{
		# takes the first Ciphers line only
		next if ( $line !~ /Ciphers/ );

		if ( $ciphers eq "cipherglobal" )
		{
			$line =~ s/#//g;
			$line   = "\tCiphers \"ALL\"";
			$output = 0;
		}
		elsif ( $ciphers eq "cipherpci" )
		{
			my $cipher_pci = &getGlobalConfiguration('cipher_pci');
			$line =~ s/#//g;
			$line   = "\tCiphers \"$cipher_pci\"";
			$output = 0;
		}
		elsif ( $ciphers eq "ciphercustom" )
		{
			$cipherc = 'DEFAULT' if not defined $cipherc;
			$line =~ s/#//g;
			$line   = "\tCiphers \"$cipherc\"";
			$output = 0;
		}
		elsif ( $ciphers eq "cipherssloffloading" )
		{
			my $cipher = &getGlobalConfiguration('cipher_ssloffloading');
			$line   = "\tCiphers \"$cipher\"";
			$output = 0;
		}

		# default cipher
		else
		{
			$line =~ s/#//g;
			$line   = "\tCiphers \"ALL\"";
			$output = 0;
		}

		last;
	}
	untie @array;

	return $output;
}

=begin nd
Function: getFarmCipherList

	Get Cipher value defined in pound configuration file

Parameters:
	farmname - Farm name

Returns:
	scalar - return a string with cipher value or -1 on failure
=cut
sub getFarmCipherList    # ($farm_name)
{
	my $farm_name = shift;
	my $output = -1;

	my $farm_filename = &getFarmFile( $farm_name );

	open FI, "<$configdir/$farm_filename";
	my @content = <FI>;
	close FI;

	foreach my $line ( @content )
	{
		next if ( $line !~ /Ciphers/ );

		$output = ( split ( '\"', $line ) )[1];

		last;
	}

	return $output;
}

=begin nd
Function: getFarmCipherSet

	Get Ciphers value defined in pound configuration file. Possible values are:
		cipherglobal, cipherpci, cipherssloffloading or ciphercustom.

Parameters:
	farmname - Farm name

Returns:
	scalar - return a string with cipher set (ciphers) or -1 on failure

=cut
sub getFarmCipherSet    # ($farm_name)
{
	my $farm_name = shift;

	my $output = -1;

	my $cipher_list = &getFarmCipherList( $farm_name );

	if ( $cipher_list eq 'ALL' )
	{
		$output = "cipherglobal";
	}
	elsif ( $cipher_list eq &getGlobalConfiguration('cipher_pci') )
	{
		$output = "cipherpci";
	}
	elsif ( $cipher_list eq &getGlobalConfiguration('cipher_ssloffloading') )
	{
		$output = "cipherssloffloading";
	}
	else
	{
		$output = "ciphercustom";
	}

	return $output;
}

=begin nd
Function: getHTTPFarmDisableSSL

	Get if a security protocol version is enabled or disabled in a HTTPS farm

Parameters:
	farmname - Farm name
	protocol - SSL or TLS protocol get status (disabled or enabled)

Returns:
	Integer - 1 on disabled, 0 on enabled or -1 on failure
=cut
sub getHTTPFarmDisableSSL    # ($farm_name, $protocol)
{
	my ( $farm_name, $protocol ) = @_;

	my $farm_type     = &getFarmType( $farm_name );
	my $farm_filename = &getFarmFile( $farm_name );
	my $output        = -1;

	if ( $farm_type eq "https" )
	{
		open FR, "<$configdir\/$farm_filename" or return $output;
		$output = 0;	# if the sentence is not in config file, it is disabled
		my @file = <FR>;
		foreach my $line ( @file )
		{
			if ( $line =~ /^\tDisable $protocol$/ )
			{
				$output = 1;
				last;
			}
		}
		close FR;
	}

	return $output;
}

=begin nd
Function: setHTTPFarmDisableSSL

	Enable or disable a security protocol for a HTTPS farm

Parameters:
	farmname - Farm name
	protocol - SSL or TLS protocol to disable/enable: SSLv2|SSLv3|TLSv1|TLSv1_1|TLSv1_2
	action - The available actions are: 1 to disable or 0 to enable

Returns:
	Integer - Error code: 0 on success or -1 on failure
=cut
sub setHTTPFarmDisableSSL    # ($farm_name, $protocol, $action )
{
	my ( $farm_name, $protocol, $action ) = @_;

	require Tie::File;

	my $farm_type     = &getFarmType( $farm_name );
	my $farm_filename = &getFarmFile( $farm_name );
	my $output        = -1;

	if ( $farm_type eq "https" )
	{
		tie my @file, 'Tie::File', "$configdir/$farm_filename";

		if ( $action == 1 )
		{
			foreach my $line (@file)
			{
				if ( $line =~ /Ciphers\ .*/ )
				{
					$line = "$line\n\tDisable $protocol";
					last;
				}
			}
			$output = 0;
		}
		else
		{
			my $it=-1;
			foreach my $line (@file)
			{
				$it = $it +1;
				last if( $line =~ /Disable $protocol$/);
			}
			splice @file, $it, 1;
			$output = 0;
		}

		untie @file;
	}

	return $output;
}

1;
