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

#STATUS of a L4xNAT Farm

if ( $viewtableclients eq "" ) { $viewtableclients = "no"; }

#if ($viewtableconn eq ""){ $viewtableconn = "no";}

# Real Server Table
my $nattype = &getFarmNatType( $farmname );
my $proto   = &getFarmProto( $farmname );
if ( $proto eq "all" )
{
	$proto = "";
}

$fvip = &getFarmVip( "vip", $farmname );

my @content = &getFarmBackendStatusCtl( $farmname );
my @backends = &getFarmBackendsStatus( $farmname, @content );

my $backendsize    = @backends;
my $activebackends = 0;
foreach ( @backends )
{
	my @backends_data = split ( ";", $_ );
	if ( $backends_data[4] eq "up" )
	{
		$activebackends++;
	}
}

&refreshstats();
print "<br>";

print "<div class=\"box-header\">Real servers status<font size=1>&nbsp;&nbsp;&nbsp; $backendsize servers, $activebackends active </font></div>";
print "<div class=\"box table\"><table cellspacing=\"0\">\n";
print "<thead>\n";
print "<tr><td>Server</td><td>Address</td><td>Port(s)</td><td>Status</td><td>Pending Conns</td><td>Established Conns</td>";
print "</thead>\n";
print "<tbody>";

my $index = 0;
foreach ( @backends )
{
	my @backends_data = split ( ";", $_ );
	my $ip_backend    = $backends_data[0];
	my $port_backend  = $backends_data[1];
	print "<tr>";
	print "<td> $index </td> ";
	print "<td> $ip_backend </td> ";
	print "<td> $port_backend </td> ";
	if ( $backends_data[4] eq "maintenance" )
	{
		print "<td><img src=\"img/icons/small/warning.png\" title=\"up\"></td> ";
	}
	elsif ( $backends_data[4] eq "up" )
	{
		print "<td><img src=\"img/icons/small/start.png\" title=\"up\"></td> ";
	}
	elsif ( $backends_data[4] eq "fgDOWN" )
	{
		print "<td><img src=\"img/icons/small/disconnect.png\" title=\"FarmGuardian down\"></td> ";
	}
	else
	{
		print "<td><img src=\"img/icons/small/stop.png\" title=\"down\"></td> ";
	}

	my @synnetstatback;
	@netstat = &getConntrack( "", $fvip, $ip_backend, "", "" );
	@synnetstatback = &getBackendSYNConns( $farmname, $ip_backend, $port_backend, @netstat );
	my $npend = @synnetstatback;
	print "<td>$npend</td>";

	my @stabnetstatback;
	@stabnetstatback = &getBackendEstConns( $farmname, ${ ip_backend }, $port_backend, @netstat );
	my $nestab = @stabnetstatback;
	print "<td>$nestab</td>";
	print "</tr>";
	$index++;
}

print "</tbody>";
print "</table>";
print "</div>\n\n";

if ( $proto eq "sip" )
{

	# Active sessions
	print "<div class=\"box-header\">";
	my @csessions     = &getConntrackExpect();
	my $totalsessions = @csessions;

	if ( $viewtableclients eq "yes" )
	{
		print "<a href=\"index.cgi?id=1-2&action=managefarm&farmname=$farmname&viewtableclients=no&viewtableconn=$viewtableconn\" title=\"Minimize\"><img src=\"img/icons/small/bullet_toggle_minus.png\"></a>";
	}
	else
	{
		print "<a href=\"index.cgi?id=1-2&action=managefarm&farmname=$farmname&viewtableclients=yes&viewtableconn=$viewtableconn\" title=\"Maximize\"><img src=\"img/icons/small/bullet_toggle_plus.png\"></a>";
	}

	print "Client sessions status <font size=1>&nbsp;&nbsp;&nbsp; $totalsessions active clients</font></div>\n";
	print "<div class=\"box table\"><table cellspacing=\"0\">\n";
	if ( $viewtableclients eq "yes" )
	{
		print "<thead>\n";
		print "<tr><td>Client Address</td></tr>\n";
		print "</thead>";
		print "<tbody>";

		foreach $session ( @csessions )
		{

			#my @s_backend  = split("\t",$_);
			#if (@s_backend[0] =~ /^[0-9]/ && ($ftracking == 0 || @s_backend[2] <= $ftracking))
			#	{
			#	print "<tr><td>@s_backend[0]  </td><td>@s_backend[1]  </td><td>@s_backend[2] </td><td>@s_backend[3] </td><td>@s_backend[4] </td><td>@s_backend[5] </td><td>@s_backend[6] </td></tr>";
			#	}

			print "<tr><td>$session</td></tr>";
		}
		print "</tbody>";
	}

	print "</table>";
	print "</div>";

}

print "<!--END MANAGE-->";

print "<div id=\"page-header\"></div>";
print "<form method=\"get\" action=\"index.cgi\">";
print "<input type=\"hidden\" value=\"1-2\" name=\"id\">";
print "<input type=\"submit\" value=\"Cancel\" name=\"action\" class=\"button small\">";
print "</form>";
print "<div id=\"page-header\"></div>";

#print "@run";
