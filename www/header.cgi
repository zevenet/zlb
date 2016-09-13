###############################################################################
#
#     Zevenet Software License
#     This file is part of the Zevenet software package.
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

#header secction
use Sys::Hostname;
my $host = hostname();
$timeseconds = time ();

$now = ctime();

my @months = ( "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec" );
my ( $sec, $min, $hour, $day, $month, $year ) = ( localtime ( $time ) )[0, 1, 2, 3, 4, 5, 6];
$month = $months[$month];
$year  = $year + 1900;

#print "$month $day $year $hour:$min:$sec\n";
print "
<!DOCTYPE html PUBLIC \"-//W3C//DTD XHTML 1.0 Strict//EN\" \"http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd\">
<html xmlns=\"http://www.w3.org/1999/xhtml\">

<head>
<meta http-equiv=\"content-type\" content=\"text/html; charset=utf-8\" />
";

if ( $refresh )
{
	print "<meta http-equiv=\"refresh\" content=\"$refresh\">";
}

print "
<link type=\"text/css\" rel=\"stylesheet\" media=\"all\" href=\"css/base.css\" />
<link type=\"text/css\" rel=\"stylesheet\" media=\"all\" href=\"css/grid.css\" />
                <script type=\"text/javascript\">
                function logout() {
                var xmlhttp;
                if (window.XMLHttpRequest) {
                          xmlhttp = new XMLHttpRequest();
                }
                // code for IE
                else if (window.ActiveXObject) {
                xmlhttp=new ActiveXObject(\"Microsoft.XMLHTTP\");
                }
                if (window.ActiveXObject) {
                // IE clear HTTP Authentication
                        document.execCommand(\"ClearAuthenticationCache\");
                        window.location.href=\'/out/out.cgi\';
                } else {
                        xmlhttp.open(\"GET\", \'/noexist/\', true, \"logout\", \"logout\");
                        xmlhttp.send(\"\");
                        xmlhttp.onreadystatechange = function() {
                                if (xmlhttp.readyState == 4) {window.location.href=\'/out/out.cgi\';}

                        }

                }
                return false;
                }
                </script>

<title>ZEVENET Load Balancer GUI v$version on $host</title>

<link href=\"/img/favicon.ico\" rel=\"icon\" type=\"image/x-icon\" />
<link rel='stylesheet' href='/font/font-aw/css/font-awesome.min.css'>

</head>
<body>
<!-- <div id=\"container\"> --!
<div id=\"header\">
  <!--mensaje superior-->
  <div class=\"header-top tr\">
    <p>Hello <strong>$ENV{'REMOTE_USER'}</strong> | ";

open FR, "<$filecluster";
@file = <FR>;

if ( -e $filecluster && ( grep ( /UP/, @file ) ) )
{
	if ( &activenode() eq "true" )
	{
		print "Cluster: <b>this node is master</b>";
	}
	elsif ( `ps aux | grep "ucarp" | grep "\\-k 100" | grep -v grep` )
	{
		print "<img src=\"img/icons/small/exclamation_octagon_fram.png\" title=\"Changes will not be replicated!\">Cluster: <b>this node is on maintenance</b>";
	}
	else
	{
		print "<img src=\"img/icons/small/exclamation_octagon_fram.png\" title=\"Changes will not be replicated!\">Cluster: <b>this node is backup</b>";
	}
	print " |";
}
else
{
	print "<img src=\"img/icons/small/exclamation_octagon_fram.png\" title=\"HA issue, cluster not configured\">Cluster: <b>Not configured. <a href=\"http://www.zenloadbalancer.com/eliminate-a-single-point-of-failure/\" target=\"_blank\"><u>How to eliminate this single point of failure</u></a></b> |";
}

#print " Host: <strong>$host</strong> | Date: <strong>$month $day $year  $hour:$min:$sec</strong></p>
print " Host: <strong>$host</strong> | Date: <strong>$now</strong> | <a href=\'#\' onclick=\'logout()\' title=\'Logout\'> <strong>Logout</strong></a></p>
 </div>
</div>
<br/>
";
