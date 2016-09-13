#!/usr/bin/perl
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

require "/usr/local/zenloadbalancer/config/global.conf";
require "./functions.cgi";
use CGI qw(:standard escapeHTML);
print "Content-type: text/html\n\n";

print "
<HTML>
<head>
<meta http-equiv=\"content-type\" content=\"text/html; charset=utf-8\" />

<link type=\"text/css\" rel=\"stylesheet\" media=\"all\" href=\"css/base.css\" />
<link type=\"text/css\" rel=\"stylesheet\" media=\"all\" href=\"css/grid.css\" />
<title>Upload Certificates</title></head>";

print "<BODY onunload=\"opener.location=('index.cgi?id=1-3')\">";

print "<div id=\"header\">
	 <div class=\"header-top tr\">";

print "<br><br><br>";
print "<div id=\"page-header\"></div>

	 </div>
      </div>";

#print "<b>Upload Backup.</b>";
#print "<div id=\"page-header\"></div>";

my $query             = new CGI;
my $upload_dir        = $configdir;
my $action            = $query->param( "action" );
my $filename          = $query->param( "fileup" );
my $certname          = $query->param( "certname" );
my $certaut           = "Starfield";
my $filecert          = "";
my $certautfile       = "sf_bundle-g2-g1.crt";
my $upload_filehandle = $query->upload( "fileup" );
if ( $action eq "Upload" && $filename !~ /^$/ && $certname !~ /^$/ )
{

	if ( $filename =~ /\.pem$/ || $filename =~ /\.zip$/ || $filename =~ /\.cert$/ )
	{
		if ( $filename =~ /\// )
		{
			@filen = split ( /\//, $filename );
			$filename = $filen[-1];
		}

		open ( UPLOADFILE, ">$upload_dir/$filename" ) or die "$!";
		binmode UPLOADFILE;
		while ( <$upload_filehandle> )
		{
			print UPLOADFILE;
		}
		close UPLOADFILE;
		print "<br>";
		my $tmpdir = "/tmp/$certname";
		mkdir ( $tmpdir );
		&successmsg( "File $filename uploaded!" );
		if ( $filename =~ /\.zip/ )
		{
			my @eject = `$unzip -o -d $tmpdir $upload_dir/$filename 2> /dev/null`;
			$filecert = `$ls -1 $tmpdir | grep -v "$certautfile"`;
			@eject    = `$mv -f $upload_dir/$filename $tmpdir/ 2> /dev/null`;

			#$filename =~ s/\.zip$/\.crt/;
			$filename = $filecert;
			chomp ( $filename );
		}
		if ( $filename =~ /\.crt/ )
		{
			if ( !( -e "${tmpdir}/${filename}" ) )
			{
				my @eject = `$mv -f $upload_dir/$filename $tmpdir/$filename 2> /dev/null`;
			}
			$crtaut = &getCertIssuer( "$tmpdir/$filename" );
			if ( $crtaut !~ /$certaut/ )
			{
				&errormsg( "File can not be proccesed, you have to build your pem file by yourself." );
			}
			else
			{
				$csrcn = &getCertCN( "$upload_dir/$certname" );
				$crtcn = &getCertCN( "$tmpdir/$filename" );

				if ( $csrcn ne $crtcn )
				{
					&errormsg( "CRT file was not created from this CSR." );
				}
				else
				{
					$keyfile = $certname;
					$keyfile =~ s/\.csr$/\.key/;
					if ( -e "$upload_dir/$keyfile" && -e "$tmpdir/$certautfile" )
					{
						&createPemFromKeyCRT( $keyfile, $filename, $certautfile, $tmpdir );
						my @eject = `$mv -f $upload_dir/$certname $tmpdir/ 2> /dev/null`;
						my @eject = `$mv -f $upload_dir/$keyfile $tmpdir/ 2> /dev/null`;
						$pemfile = $certname;
						$pemfile =~ s/\.csr$/\.pem/;
						$tgzfile = $certname;
						$tgzfile =~ s/\.csr$/\.tgz/;
						my @eject = `$cp -f $upload_dir/$pemfile $tmpdir/ 2> /dev/null`;
						my @eject = `$tar czvf $upload_dir/$tgzfile $tmpdir/* 2> /dev/null`;
						unlink glob ( "$tmpdir\/*" );
						rmdir ( "$tmpdir" );
						&successmsg( "File $pemfile created!" );
					}
					else
					{
						&errormsg( "Private key or Intermediate CA file not found." );
					}
				}
			}
		}
		if ( $filename =~ /\.pem/ )
		{

			$csrcn = &getCertCN( "$upload_dir/$certname" );
			$crtcn = &getCertCN( "$tmpdir/$filename" );

			if ( $csrcn ne $crtcn )
			{
				&errormsg( "PEM file was not created from this CSR." );
			}
			else
			{
				$keyfile = $certname;
				$keyfile =~ s/\.csr$/\.key/;
				my $tmpdir = "/tmp/$certname";
				if ( -e "$upload_dir/$keyfile" )
				{
					my @eject = `$mv -f $upload_dir/$certname $tmpdir/ 2> /dev/null`;
					my @eject = `$mv -f $upload_dir/$keyfile $tmpdir/ 2> /dev/null`;
					$tgzfile = $certname;
					$tgzfile =~ s/\.csr$/\.tgz/;
					my @eject = `$cp -f $upload_dir/$filename $tmpdir/ 2> /dev/null`;
					my @eject = `$tar czvf $upload_dir/$tgzfile $tmpdir/* 2> /dev/null`;
					unlink glob ( "$tmpdir\/*" );
					rmdir ( "$tmpdir" );
					&successmsg( "File $filename created!" );
				}
				else
				{
					&errormsg( "Private key file not found." );
				}
			}
		}
	}
	else
	{
		print "<br>";
		&errormsg( "File without correct extension!" );
	}
}

print "<br>";
print "<br>";

print "<form method=\"post\" action=\"uploadcertsfromcsr.cgi\" enctype=\"multipart/form-data\">";

print "<b>Upload file on pem, crt or zip format. <font size=1> filename.pem, filename.crt, filename.zip</fon>:</b> <input   type=\"file\" name=\"fileup\" value=\"Ex\" >";
print "<br>";
print "<br>";
print "<input type=\"hidden\" value=\"$certname\" name=\"certname\">";
print "<input type=\"submit\" value=\"Upload\" name=\"action\" class=\"button small\">";
print "</form>";
print "<br>";

print "</BODY>";
print "</HTML>";

