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

use Tie::File;

print "
<!--Content INI-->
<div id=\"page-content\">

<!--Content Header INI-->
<h2>Settings::Change Password</h2>
<!--Content Header END-->";

#my $cgiurl = $ENV{SCRIPT_NAME}."?".$ENV{QUERY_STRING};
my $cgiurl   = $ENV{ SCRIPT_NAME };
my $htpasswd = '/usr/local/zenloadbalancer/www/.htpasswd';

# Print form if not a valid form
#if(!( ($pass || $newpass || $trustedpass) && check_valid_user() && verify_passwd()) ) {
if ( !( valid_form() ) )
{
	##content 3-2 INI
	print "<div class=\"container_12\">";
	print "	<div class=\"grid_12\">";
	print "		<div class=\"box-header\">Change admin password</div>";
	print "		<div class=\"box stats\">";

	# Print form
	print "		<form method=\"POST\" action=\"$cgiurl\">";
	print "			<input type=\"hidden\" name=\"id\" value=\"3-4\">";
	print "			<label>Current password: </label>";
	print "			<input type=\"password\"  name=\"pass\">";
	print "			<div style=\"clear:both;\"></div>";
	print "			<label>New password: </label>";
	print "			<input type=\"password\"  name=\"newpass\">";
	print "			<div style=\"clear:both;\"></div>";
	print "			<label>Verify password: </label>";
	print "			<input type=\"password\" name=\"trustedpass\">";
	print "			<br><br>";
	print "			<input type=\"submit\" value=\"Change\" name=\"actionpost\" class=\"button small\">";
	print "			<input type=\"submit\" value=\"Change & Sync with root passwd\" name=\"actionpost\" class=\"button small\">";
	print "			<div style=\"clear:both;\"></div>";
	print "		</form>";

	print "		</div>";
	print "	</div>";
	print "</div>";
}
else
{
	change_passwd();
	&successmsg( "Successfully changed password" );
	if ( $action eq "Change & Sync with root passwd" )
	{
		#scape special characters:
		
		chomp ( $newpass );
		$newpass =~ s/\$/\\\$/g;
##no move the next lines
		my @run = `
/usr/bin/passwd 2>/dev/null<<EOF
$newpass
$newpass
EOF
	`;

		#end no move last lines
		if ( $? == 0 )
		{
			&successmsg( "root password synced to admin password..." );
		}
		else
		{
			&errormsg( "root password not synced..." );
		}

	}

}

print "<br class=\"cl\">";

#content 3-4 END
print "
        <br><br><br>
        </div>
    <!--Content END-->
  </div>
</div>
";

## SUBROUTINES ##

sub valid_form
{
	my $ok = 0;

	# Passed form's variables
	if ( defined ( $pass ) && defined ( $newpass ) && defined ( $trustedpass ) )
	{

		# Empty strings
		if ( !( $pass ) )
		{
			&errormsg( "Fill in Current password field" );
		}
		elsif ( !( $newpass ) )
		{
			&errormsg( "Fill in New password field" );
		}
		elsif ( !( $trustedpass ) )
		{
			&errormsg( "Fill in Verify password field" );
		}
		elsif ( !( check_valid_user() ) )
		{
			&errormsg( "Invalid current password" );
		}
		elsif ( !( verify_passwd() ) )
		{
			&errormsg( "Invalid password verification" );
		}
		else
		{
			$ok = 1;
		}
	}
	return $ok;
}

sub check_valid_user
{
	my $res   = 0;
	my $login = $ENV{ REMOTE_USER };
	tie @array, 'Tie::File', "$htpasswd";
	@found = grep ( $login, @array );
	if ( @found )
	{
		my ( $user, $pwd ) = split ( /:/, shift ( @found ) );
		my $cpasswd = crypt ( $pass, $pwd );
		$res = 1 if ( "$cpasswd" eq "$pwd" );

	}
	untie @array;
	return $res;
}

sub verify_passwd
{
	return ( $newpass eq $trustedpass );
}

sub change_passwd
{
	my $login = $ENV{ REMOTE_USER };
	tie @array, 'Tie::File', "$htpasswd";
	my ( $index ) = grep { $array[$_] =~ /$login/ } 0 .. $#array;
	$array[$index] = "$login:" . crypt ( $newpass, $pass );
	untie @array;
}
