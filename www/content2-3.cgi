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

use File::stat;
use Time::localtime;

print "
<!--Content INI-->
<div id=\"page-content\">

<!--Content Header INI-->
<h2>Monitoring::Logs</h2>
<!--Content Header END-->";

print "<div class=\"container_12\">";
print "	<div class=\"grid_12\">";
print "		<div class=\"box-header\">System logs</div>";
print "		<div class=\"box stats\">";

# Print form
#search farm files
opendir ( DIR, $logdir );
@files = grep ( /.*\.log$/, readdir ( DIR ) );
closedir ( DIR );

print "<form method=\"get\" action=\"index.cgi\">";
print "<input type=\"hidden\" name=\"id\" value=\"2-3\">";

foreach $file ( @files )
{
	print "<b>Log: $file</b><br>";
	print "<table>";
	$filepath = "$logdir$file";
	print "<tr ><td style=\"border: 0px\"><input type=\"radio\" name=\"filelog\" value=\"$filepath\"></td>";
	$datetime_string = ctime( stat ( $filepath )->mtime );
	print "<td style=\"border: 0px\"> $filepath - $datetime_string</td></tr>\n";
	@filen = split ( "\.log", $file );

	#all files with same name:
	opendir ( DIR, $logdir );
	@filesgz = grep ( /@filen[0].*gz$/, readdir ( DIR ) );
	closedir ( DIR );
	@filesgz = sort ( @filesgz );
	foreach $filegz ( @filesgz )
	{
		$filepath        = "$logdir$filegz";
		$datetime_string = ctime( stat ( $filepath )->mtime );
		print "<tr><td style=\"border: 0px\"><input type=\"radio\" name=\"filelog\" value=\"$filepath\"></td>";
		print "<td style=\"border: 0px\">$filepath - $datetime_string</td></tr>";
	}
	print "</table>";
	print "<br><br>";
}

print "Tail the last <input type=\"text\" value=\"100\" name=\"nlines\" size=\"5\"> lines";
print "<input type=\"submit\" value=\"See logs\" name=\"action\" class=\"button small\">";
print "</form>";

print "<br>";

print "<div id=\"page-header\"></div>";

if ( $action eq "See logs" && $nlines !~ /^$/ && $filelog !~ /^$/ )
{
	if ( -e $filelog )
	{
		if ( $nlines =~ m/^\d+$/ )
		{
			print "<b>file $filelog tail last $nlines lines</b><br>";
			my @eject;
			if ( $filelog =~ /gz$/ )
			{
				@eject = `$zcat $filelog | $tail -$nlines`;
			}
			else
			{
				@eject = `$tail -$nlines $filelog`;
			}
			foreach $line ( @eject )
			{
				print "$line<br>";
			}
			print "<form method=\"get\" action=\"index.cgi\">";
			print "<input type=\"hidden\" name=\"id\" value=\"2-3\">";
			print "<input type=\"submit\" value=\"Cancel\" name=\"action\" class=\"button small\">";
			print "</form>";
		}
		else
		{
			&errormsg( "The number of lines you want to tail must be a number" );
		}
	}
	else
	{
		&errormsg( "We can not find the file $filelog" );
	}
}

print "<div id=\"page-header\"></div>";

print "		</div>";
print "<br>";
print "	</div>";
print "</div>";

print "<br class=\"cl\">";
print "
        <br><br><br>
        </div>
    <!--Content END-->
  </div>
</div>
";

