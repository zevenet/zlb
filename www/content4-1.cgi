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
<h2>About::License</h2>
<!--Content Header END-->";

#my $cgiurl = $ENV{SCRIPT_NAME}."?".$ENV{QUERY_STRING};

# Print form if not a valid form
#if(!( ($pass || $newpass || $trustedpass) && check_valid_user() && verify_passwd()) ) {
##content 3-2 INI
print "<div class=\"container_12\">";
print "	<div class=\"grid_12\">";
print "		<div class=\"box-header\">Zen Load Balancer license</div>";
print "		<div class=\"box stats\">";

#print content
print "<div align=\"center\">";
print "<form method=\"get\" action=\"index.cgi\">";

#print "<input type=\"hidden\" name=\"id\" value=\"$id\"
print "<textarea  name=\"license\" cols=\"80\" rows=\"20\" align=\"center\" readonly>";
open FR, "/usr/local/zenloadbalancer/license.txt";
while ( <FR> )
{
	print "$_";
}
close FR;
print "</textarea>";
print "<br>";
print "<b>*If you use this program, you accept the GNU/LGPL license</b>";
print "</form>";
print "</div>";
print "		</div>";
print "	</div>";
print "</div>";

print "<br class=\"cl\">";

#content 3-4 END
print "
        <br><br><br>
        </div>
    <!--Content END-->
  </div>
</div>
";

