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

#require
use File::stat;
use File::Basename;
use Time::localtime;
use Sys::Hostname;

print "
    <!--Content INI-->
        <div id=\"page-content\">

                <!--Content Header INI-->
                        <h2>Manage::Certificates</h2>
                <!--Content Header END-->";

if ( $action eq "changecert" )
{
	$status = &setFarmCertificate( $certname, $farmname );
	if ( $status == 0 )
	{
		&successmsg( "Certificate is changed to $certname on farm $farmname, you need restart the farm to apply" );
		&setFarmRestart( $farmname );
	}
}

if ( $action eq "deletecert" )
{
	$status = &getFarmCertUsed( $certname );
	if ( &getFarmCertUsed( $certname ) == 0 )
	{
		&errormsg( "File can't be deleted because it's in use by a farm" );
	}
	else
	{
		&delCert( $certname );
		&successmsg( "File $file deleted" );
	}

}

if ( $action eq "Download_Cert" )
{
	&downloadCert( $certname );
}

if ( $action eq "Generate CSR" )
{
	$cert_name         = &getCleanBlanc( $cert_name );
	$cert_issuer       = &getCleanBlanc( $cert_issuer );
	$cert_fqdn         = &getCleanBlanc( $cert_fqdn );
	$cert_division     = &getCleanBlanc( $cert_division );
	$cert_organization = &getCleanBlanc( $cert_organization );
	$cert_locality     = &getCleanBlanc( $cert_locality );
	$cert_state        = &getCleanBlanc( $cert_state );
	$cert_country      = &getCleanBlanc( $cert_country );
	$cert_mail         = &getCleanBlanc( $cert_mail );
	if ( $cert_name =~ /^$/ || $cert_issuer =~ /^$/ || $cert_fqdn =~ /^$/ || $cert_division =~ /^$/ || $cert_organization =~ /^$/ || $cert_locality =~ /^$/ || $cert_state =~ /^$/ || $cert_country =~ /^$/ || $cert_mail =~ /^$/ || $cert_key =~ /^$/ )
	{
		&errormsg( "Fields can not be empty. Try again." );
		$action = "Show_Form";
	}
	elsif ( &checkFQDN( $cert_fqdn ) eq "false" )
	{
		&errormsg( "FQDN is not valid. It must be as these examples: domain.com, mail.domain.com, or *.domain.com. Try again." );
		$action = "Show_Form";
	}
	elsif ( $cert_name !~ /^[a-zA-Z0-9\-]*$/ )
	{
		&errormsg( "Certificate Name is not valid. Only letters, numbers and '-' chararter are allowed. Try again." );
		$action = "Show_Form";
	}
	else
	{
		&createCSR( $cert_name, $cert_fqdn, $cert_country, $cert_state, $cert_locality, $cert_organization, $cert_division, $cert_mail, $cert_key, "" );
		&successmsg( "Cert $cert_name created" );
	}
}

my @files = &getCertFiles();

#
#table
print "<div class=\"box-header\">Certificates inventory </div>";
print "<div class=\"box table\">";
print "<table cellspacing=\"0\">";
print "<thead>";
print "<tr>";
print "<td>File</td><td>Type</td><td>Common Name</td><td>Issuer</td><td>Created on</td><td>Expire on</td><td>Actions</td>";
print "</tr>";
print "</thead>";

print "<tbody>";
foreach ( @files )
{
	$filepath       = "$configdir\/$_";
	$cert_type      = &getCertType( $filepath );
	$issuer         = &getCertIssuer( $filepath );
	$commonname     = &getCertCN( $filepath );
	$datecreation   = &getCertCreation( $filepath );
	$dateexpiration = &getCertExpiration( $filepath );

	print "<tr><td>$_</td><td>$cert_type</td><td>$commonname</td><td>$issuer</td><td>$datecreation</td><td>$dateexpiration</td><td>";
	if ( $_ ne "zencert\.pem" )
	{

		#print "<a href=\"index.cgi?id=$id&action=deletecert&certname=$_ \"><img src=\"img/icons/small/cross_octagon.png\" title=\"Delete $_ certificate\" onclick=\"return confirm('Are you sure you want to delete the certificate: $_?')\"></a>"
		&createMenuCert( "", $_ );
	}

	print "</td></tr>";
}

print "<tr><td colspan=6></td><td>\n\n";

&uploadPEMCerts();
print "		<a href=\"index.cgi?id=$id&action=Show_Form\"><img src=\"img/icons/small/page_white_add.png\" title=\"Create CSR\"></a>";
print "		<a href=\"$buy_ssl\" target=\"_blank\"><img src=\"img/icons/small/cart_put.png\" title=\"Buy SSL Certificate\"></a>";
print "</td></tr>";

#print "<tr><td colspan=2></td><td><a href=\"index.cgi?id=$id&action=uploadcert\"><img src=\"img/icons/small/arrow_up.png\" title=\"Upload new certificate\"></a></td></tr>";
print "</tbody>";
print "</table>";

print "</div>";

#end table
if ( $action eq "View_Cert" )
{
	print "<div class=\"box-header\">View $certname</div>";
	print "	<div class=\"box stats\">";
	my @eject  = &getCertData( $certname );
	my $numrow = @eject;
	my $isinto = 0;
	foreach ( @eject )
	{
		if ( $_ =~ /^-----BEGIN CERTIFICATE/ )
		{
			print "<br>CERTIFICATE CONTENT:<br><textarea rows=\"$numrow\" cols=\"70\" readonly>";
			$isinto = 1;
		}
		print "$_";
		$numrow--;
		if ( $isinto eq 0 )
		{
			print "<br>";
		}
	}
	print "</textarea>";

	print "         <br><div id=\"page-header\"></div>";
	print "         <form method=\"get\" action=\"index.cgi\">";
	print "         <input type=\"hidden\" name=\"id\" value=\"$id\">";
	print "         <input type=\"submit\" value=\"Close\" name=\"button\" class=\"button small\">";
	print "         </form>";

	print "</div>";

}

if ( $action eq "Show_Form" )
{

	print "<div class=\"box-header\">CSR Generation </div>";
	print "	<div class=\"box stats\">";
	print "		<form method=\"post\" action=\"index.cgi\">";
	print "		<b>Certificate Name.</b><font size=1> *Descriptive text, this name will be used in the future to identify this certificate.</font><br><input type=\"text\" value=\"$cert_name\" size=\"60\" name=\"cert_name\"><br><br>";
	print "		<b>Certificate Issuer.</b><br>";
	print "		<select name=\"cert_issuer\">";
	print "			<option value=\"Sofintel\" >Sofintel - Starfield Tech. </option>";
	print "			<option value=\"Others\" >Others </option>";
	print "		</select><br><br>";
	print "		<b>Common Name.</b><font size=1> *FQDN of the server. Example: domain.com, mail.domain.com, or *.domain.com.</font><br><input type=\"text\" value=\"$cert_fqdn\" size=\"60\" name=\"cert_fqdn\"><br><br>";
	print "		<b>Division.</b><font size=1> *Your department; such as 'IT','Web', 'Office', etc.</font><br><input type=\"text\" value=\"$cert_division\" size=\"60\" name=\"cert_division\"><br><br>";
	print "		<b>Organization.</b><font size=1> *The full legal name of your organization/company (ex.: Sofintel IT Co.)</font><br><input type=\"text\" value=\"$cert_organization\" size=\"60\" name=\"cert_organization\"><br><br>";
	print "		<b>Locality.</b><font size=1> *City where your organization is located.</font><br><input type=\"text\" value=\"$cert_locality\" size=\"60\" name=\"cert_locality\"><br><br>";
	print "		<b>State/Province.</b><font size=1> *State or province where your organization is located.</font><br><input type=\"text\" value=\"$cert_state\" size=\"60\" name=\"cert_state\"><br><br>";
	print "		<b>Country.</b><font size=1> *Country (two characters code, example: US) where your organization is located.</font><br><input type=\"text\" value=\"$cert_country\" size=\"2\" maxlength=\"2\" name=\"cert_country\"><br><br>";
	print "		<b>E-mail Address.</b><br><input type=\"text\" value=\"$cert_mail\" size=\"60\" name=\"cert_mail\"><br><br>";

	#print "		<b>Password.</b><br><input type=\"password\" value=\"$cert_password\" size=\"20\" name=\"cert_password\"><br><br>";
	#print "		<b>Confirm Password.</b><br><input type=\"password\" value=\"$cert_cpassword\" size=\"20\" name=\"cert_cpassword\"><br><br>";
	print "		<b>Key size.</b><br>";
	print "		<select name=\"cert_key\">";
	print "			<option value=\"2048\">2048 </option>";
	print "		</select><br><br>";
	print "		<input type=\"hidden\" name=\"id\" value=\"$id\">";
	print "		<input type=\"hidden\" name=\"actionpost\" value=\"Generate CSR\">";
	print "		<input type=\"submit\" value=\"Generate CSR\" name=\"button\" class=\"button small\"><br><br>";
	print "		</form>";

	print "		<br><div id=\"page-header\"></div>";
	print "		<form method=\"get\" action=\"index.cgi\">";
	print "		<input type=\"hidden\" name=\"id\" value=\"$id\">";
	print "		<input type=\"submit\" value=\"Cancel\" name=\"button\" class=\"button small\">";
	print "		</form>";

	print "	</div>";
}

print "</div><!--Content END-->";

