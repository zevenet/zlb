###############################################################################
#
#     Zen Load Balancer Software License
#     This file is part of the Zen Load Balancer software package.
#
#     Copyright (C) 2014 SOFINTEL IT ENGINEERING SL, Sevilla (Spain)
#
#     This library is free software; you can redistribute it and/or modify it
#     under the terms of the GNU Lesser General Public License as published
#     by the Free Software Foundation; either version 2.1 of the License, or
#     (at your option) any later version.
#
#     This library is distributed in the hope that it will be useful, but
#     WITHOUT ANY WARRANTY; without even the implied warranty of
#     MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU Lesser
#     General Public License for more details.
#
#     You should have received a copy of the GNU Lesser General Public License
#     along with this library; if not, write to the Free Software Foundation,
#     Inc., 59 Temple Place, Suite 330, Boston, MA 02111-1307 USA
#
###############################################################################

#Return all certificate files in config directory
sub getCertFiles()
{
	opendir ( DIR, $configdir );
	my @files = grep ( /.*\.pem$/, readdir ( DIR ) );
	closedir ( DIR );

	opendir ( DIR, $configdir );
	push ( @files, grep ( /.*\.csr$/, readdir ( DIR ) ) );
	closedir ( DIR );
	return @files;
}

#Delete all blancs from the beginning and from the end of a variable.
sub getCleanBlanc($vartoclean)
{
	( $vartoclean ) = @_;
	$vartoclean =~ s/^\s+//;
	$vartoclean =~ s/\s+$//;
	return $vartoclean;
}

#Return the type of a certificate file
sub getCertType($certfile)
{
	( $certfile ) = @_;
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

#Return the Common Name of a certificate file
sub getCertCN($certfile)
{
	( $certfile ) = @_;
	my $certcn = "";
	if ( &getCertType( $certfile ) eq "Certificate" )
	{
		@eject  = `$openssl x509 -noout -in $certfile -text | grep Subject:`;
		@eject  = split ( /CN=/, @eject[0] );
		@eject  = split ( /\/emailAddress=/, @eject[1] );
		$certcn = @eject[0];
	}
	else
	{
		@eject  = `$openssl req -noout -in $certfile -text | grep Subject:`;
		@eject  = split ( /CN=/, @eject[0] );
		@eject  = split ( /\/emailAddress=/, @eject[1] );
		$certcn = @eject[0];
	}
	$certcn = &getCleanBlanc( $certcn );
	return $certcn;
}

#Return the Issuer Common Name of a certificate file
sub getCertIssuer($certfile)
{
	( $certfile ) = @_;
	my $certissu = "";
	if ( &getCertType( $certfile ) eq "Certificate" )
	{
		my @eject = `$openssl x509 -noout -in $certfile -text | grep Issuer:`;
		@eject = split ( /CN=/,             @eject[0] );
		@eject = split ( /\/emailAddress=/, @eject[1] );
		$certissu = @eject[0];
	}
	else
	{
		$certissu = "NA";
	}
	$certissu = &getCleanBlanc( $certissu );
	return $certissu;
}

#Return the creation date of a certificate file
sub getCertCreation($certfile)
{
	( $certfile ) = @_;
	use File::stat;
	use Time::localtime;
	my $datecreation = "";
	if ( &getCertType( $certfile ) eq "Certificate" )
	{
		my @eject = `$openssl x509 -noout -in $certfile -dates`;
		my @datefrom = split ( /=/, @eject[0] );
		$datecreation = @datefrom[1];
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

#Return the expiration date of a certificate file
sub getCertExpiration($certfile)
{
	( $certfile ) = @_;
	my $dateexpiration = "";
	if ( &getCertType( $certfile ) eq "Certificate" )
	{
		my @eject = `$openssl x509 -noout -in $certfile -dates`;
		my @dateto = split ( /=/, @eject[1] );
		$dateexpiration = @dateto[1];
	}
	else
	{
		$dateexpiration = "NA";
	}
	return $dateexpiration;
}

#Check if a fqdn is valid
sub checkFQDN($certfqdn)
{
	( $certfqdn ) = @_;
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

sub delCert($certname)
{
	( $certname ) = @_;
	my @filename = split ( /\./, $certname );
	my @filename = splice ( @filename, -0, 1 );
	$certname = join ( '.', @filename );
	opendir ( DIR, $configdir );
	my @files = grep ( /^($certname)\.[a-zA-Z0-9]+$/, readdir ( DIR ) );
	closedir ( DIR );
	foreach $file ( @files )
	{
		unlink ( "$configdir\/$file" );
	}

}

#Create CSR file
sub createCSR($certname, $certfqdn, $certcountry, $certstate, $certlocality, $certorganization, $certdivision, $certmail, $certkey, $certpassword)
{
	( $certname, $certfqdn, $certcountry, $certstate, $certlocality, $certorganization, $certdivision, $certmail, $certkey, $certpassword ) = @_;
	##sustituir los espacios por guiones bajos en el nombre de archivo###
	if ( $certpassword eq "" )
	{
		&logfile( "Creating CSR: $openssl req -nodes -newkey rsa:$certkey -keyout $configdir/$certname.key -out $configdir/$certname.csr -batch -subj \"/C=$certcountry\/ST=$certstate/L=$certlocality/O=$certorganization/OU=$certdivision/CN=$certfqdn/emailAddress=$certmail\"" );
		my @opensslout = `$openssl req -nodes -newkey rsa:$certkey -keyout $configdir/$certname.key -out $configdir/$certname.csr -batch -subj "/C=$certcountry\/ST=$certstate/L=$certlocality/O=$certorganization/OU=$certdivision/CN=$certfqdn/emailAddress=$certmail" 2> /dev/null`;
	}
	else
	{
		my @opensslout = `$openssl req -passout pass:$certpassword -newkey rsa:$certkey -keyout $configdir/$certname.key -out  $configdir/$certname.csr -batch -subj "/C=$certcountry/ST=$certstate/L=$certlocality/O=$certorganization/OU=$certdivision/CN=$certfqdn/emailAddress=$certmail" 2> /dev/null`;
		&logfile( "Creating CSR: $openssl req -passout pass:$certpassword -newkey rsa:$certkey -keyout $configdir/$certname.key -out $configdir/$certname.csr -batch -subj \"/C=$certcountry\/ST=$certstate/L=$certlocality/O=$certorganization/OU=$certdivision/CN=$certfqdn/emailAddress=$certmail\"" );
	}
}

#function that creates a menu to manage a certificate
sub createMenuCert($action,$certfile)
{
	( $actionmenu, $certfile ) = @_;
	my $certtype = &getCertType( $certfile );
	if ( $certtype eq "CSR" )
	{
		&uploadCertFromCSR( $certfile );
	}
	print "<a href=\"index.cgi?id=$id&action=deletecert&certname=$certfile\"><img src=\"img/icons/small/page_white_delete.png\" title=\"Delete $certtype $certfile\" onclick=\"return confirm('Are you sure you want to delete the certificate: $certfile?')\"></a> ";
	print "<a href=\"index.cgi?id=$id&action=View_Cert&certname=$certfile\"><img src=\"img/icons/small/page_white_find.png\" title=\"View $certtype $certfile content\"></a> ";
	print "<a href=\"downloadcerts.cgi?certname=$certfile\" target=\"_blank\"><img src=\"img/icons/small/page_white_put.png\" title=\"Download $certtype $certfile\"></a> ";

	#&downloadCert($certfile);
}

sub uploadCertFromCSR($certfile)
{
	( $certfile ) = @_;
	print "<script language=\"javascript\">
	                var popupWindow = null;
	                function positionedPopup(url,winName,w,h,t,l,scroll)
	                {
	                settings ='height='+h+',width='+w+',top='+t+',left='+l+',scrollbars='+scroll+',resizable'
	                popupWindow = window.open(url,winName,settings)
	                }
	        </script>";

	#print the information icon with the popup with info.
	print "<a href=\"uploadcertsfromcsr.cgi?certname=$certfile\" onclick=\"positionedPopup(this.href,'myWindow','500','300','100','200','yes');return false\"><img src='img/icons/small/page_white_get.png' title=\"Upload certificate for CSR $certfile\"></a> ";
}

sub uploadPEMCerts($certfile)
{
	( $certfile ) = @_;
	print "<script language=\"javascript\">
	                var popupWindow = null;
	                function positionedPopup(url,winName,w,h,t,l,scroll)
	                {
	                settings ='height='+h+',width='+w+',top='+t+',left='+l+',scrollbars='+scroll+',resizable'
	                popupWindow = window.open(url,winName,settings)
	                }
	        </script>";

	#print the information icon with the popup with info.
	print "<a href=\"uploadcerts.cgi\" onclick=\"positionedPopup(this.href,'myWindow','500','300','100','200','yes');return false\"><img src='img/icons/small/page_white_get.png' title=\"Upload .pem certificate\"></a> ";
}

sub downloadCert($certfile)
{
	( $certfile ) = @_;
	print "<script language=\"javascript\">
	                var popupWindow = null;
	                function positionedPopup(url,winName,w,h,t,l,scroll)
	                {
	                settings ='height='+h+',width='+w+',top='+t+',left='+l+',scrollbars='+scroll+',resizable'
	                popupWindow = window.open(url,winName,settings)
	                }
	        </script>";

	#print the information icon with the popup with info.
	print "<a href=\"downloadcerts.cgi?certname=$certfile\" onclick=\"positionedPopup(this.href,'myWindow','500','300','100','200','yes');return false\"><img src='img/icons/small/page_white_put.png' title=\"Download $certfile\"></a> ";
}

sub getCertData($certfile)
{
	( $certfile ) = @_;
	my $filepath = "$configdir\/$certfile";
	my @eject    = ( "" );
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

sub createPemFromKeyCRT($keyfile,$crtfile,$certautfile,$tmpdir)
{
	( $keyfile, $crtfile, $certautfile, $tmpdir ) = @_;
	$path = $configdir;
	my $pemfile = $keyfile;
	$pemfile =~ s/\.key$/\.pem/;
	my $buff = "";
	@files = ( "$path/$keyfile", "$tmpdir/$crtfile", "$tmpdir/$certautfile" );
	foreach $file ( @files )
	{

		# Open key files
		open FILE, "<", $file or die $!;

		# Now get every line in the file, and attach it to the full ‘buffer’ variable.
		while ( my $line = <FILE> )
		{
			$buff .= $line;
		}

		# Close this particular file.
		close FILE;
	}
	open $pemhandler, ">", "$path/$pemfile" or die $!;

	# Write the buffer into the output file.
	print $pemhandler $buff;

	close $pemhandler;
}

# do not remove this
1

