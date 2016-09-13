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

#search te manage port for selected farm
#$mport = &getFarmPort($farmname);
#&logfile("running '$pen_ctl 127.0.0.1:$mport status'");
#my @run = `$pen_ctl 127.0.0.1:$mport status`;

if ( $viewtableclients eq "" ) { $viewtableclients = "no"; }
if ( $viewtableconn    eq "" ) { $viewtableconn    = "no"; }

$type = &getFarmType( $farmname );

if ( $viewtableclients eq "" ) { $viewtableclients = "no"; }
if ( $viewtableconn    eq "" ) { $viewtableconn    = "no"; }

my @content = &getFarmBackendStatusCtl( $farmname );

#sessions
my @sessions = &getFarmBackendsClientsList( $farmname, @content );

#Real servers
my @backends = &getFarmBackendsStatus( $farmname, @content );

my @netstat;
$fvip = &getFarmVip( "vip", $farmname );
$fpid = &getFarmPid( $farmname );

my $activebackends     = 0;
my $activeservbackends = 0;
my $totalsessions      = 0;

#my $activesessions = 0;
foreach ( @backends )
{
	my @backends_data = split ( "\t", $_ );
	if ( $backends_data[1] ne "0\.0\.0\.0" )
	{
		$activeservbackends++;
		if ( $backends_data[3] eq "UP" )
		{
			$activebackends++;
		}
	}
}

##
&refreshstats();
print "<br>";
my @back_header = split ( "\t", @backends[0] );
print "<div class=\"box-header\">Real servers status <font size=1>&nbsp;&nbsp;&nbsp; $activeservbackends servers, $activebackends current</font>";

#print "<div class=\"box-header\">";
# &refreshstats();
print "</div>\n";
print "<div class=\"box table\"><table cellspacing=\"0\">\n";
print "<thead>\n";

print "<tr><td>Server</td><td>Address</td><td>Port</td><td>Status</td><td>Pending Conns</td><td>Established Conns</td><td>Clients</td><td>Weight</td><td>Priority</td></tr>\n";
print "</thead>";
print "<tbody>";
foreach ( @backends )
{
	my @backends_data = split ( "\t", $_ );

	#$activesessions = $activesessions+$backends_data[6];
	if ( @backends_data[1] ne "0\.0\.0\.0" && @backends_data[0] =~ /^[0-9]/ )
	{
		print "<tr>";
		print "<td>@backends_data[0]</td>";
		print "<td>@backends_data[1]</td>";
		print "<td>@backends_data[2]</td>";
		if ( $backends_data[3] eq "MAINTENANCE" )
		{
			print "<td><img src=\"img/icons/small/warning.png\" title=\"maintenance\"></td> ";
		}
		elsif ( $backends_data[3] eq "UP" )
		{
			print "<td><img src=\"img/icons/small/start.png\" title=\"up\"></td> ";
		}
		else
		{
			print "<td><img src=\"img/icons/small/stop.png\" title=\"down\"></td> ";
		}
		$ip_backend     = $backends_data[1];
		$port_backend   = $backends_data[2];
		@netstat        = &getConntrack( "", $ip_backend, "", "", $type );
		@synnetstatback = &getBackendSYNConns( $farmname, $ip_backend, $port_backend, @netstat );
		$npend          = @synnetstatback;
		print "<td>$npend</td>";
		@stabnetstatback = &getBackendEstConns( $farmname, $ip_backend, $port_backend, @netstat );
		$nestab = @stabnetstatback;
		print "<td>$nestab</td>";
		print "<td>@backends_data[6] </td>";
		$totalsessions = $totalsessions + @backends_data[6];
		print "<td>@backends_data[4]</td>";
		print "<td>@backends_data[5]</td> ";
		print "</tr>\n";
	}
}

print "</tbody>";
print "</table>";
print "</div>\n\n";

#Client sessions status
my @ses_header = split ( "\t", @sessions[0] );
print "<div class=\"box-header\">";
my @fclient = &getFarmMaxClientTime( $farmname );

if ( @fclient == -1 )
{
	$ftracking = 10;
}
else
{
	$ftracking = @fclient[1];
}

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
	print "<tr><td>Client</td><td>Address</td><td>Age(sec)</td><td>Last Server</td><td>Connects</td><td>Sent(mb)</td><td>Received(mb)</td></tr>\n";
	print "</thead>";
	print "<tbody>";

	foreach ( @sessions )
	{
		my @s_backend = split ( "\t", $_ );
		if ( @s_backend[0] =~ /^[0-9]/ && ( $ftracking == 0 || @s_backend[2] <= $ftracking ) )
		{
			print "<tr><td>@s_backend[0]  </td><td>@s_backend[1]  </td><td>@s_backend[2] </td><td>@s_backend[3] </td><td>@s_backend[4] </td><td>@s_backend[5] </td><td>@s_backend[6] </td></tr>";
		}
	}
	print "</tbody>";
}

print "</table>";
print "</div>";

###Active clients
my @activeclients = &getFarmBackendsClientsActives( $farmname, @content );
my @conns_header = split ( "\t", @activeclients[0] );

print "<div class=\"box-header\">";

if ( $viewtableconn eq "yes" )
{
	print "<a href=\"index.cgi?id=1-2&action=managefarm&farmname=$farmname&viewtableclients=$viewtableclients&viewtableconn=no\" title=\"Minimize\"><img src=\"img/icons/small/bullet_toggle_minus.png\"></a>";
}
else
{
	print "<a href=\"index.cgi?id=1-2&action=managefarm&farmname=$farmname&viewtableclients=$viewtableclients&viewtableconn=yes\" title=\"Maximize\"><img src=\"img/icons/small/bullet_toggle_plus.png\"></a>";
}

print "@conns_header[0]<font size=1>&nbsp;&nbsp;&nbsp; @conns_header[1] </font></div>\n";
print "<div class=\"box table\"><table cellspacing=\"0\">\n";
print "<thead>\n";

if ( $viewtableconn eq "yes" )
{
	print "<tr><td>Connection</td><td>Client</td><td>Server</td></tr>\n";
	print "</thead>";
	print "<tbody>";

	foreach ( @activeclients )
	{
		my @s_backend = split ( "\t", $_ );
		if ( @s_backend[0] =~ /^[0-9]/ )
		{
			print "<tr><td>@s_backend[0]  </td><td>@s_backend[1]  </td><td>@s_backend[2] </td></tr>";
		}
	}
	print "</tbody>";
}

print "</table>";
print "</div>";

print "<!--END MANAGE-->";

print "<div id=\"page-header\"></div>";
print "<form method=\"get\" action=\"index.cgi\">";
print "<input type=\"hidden\" value=\"1-2\" name=\"id\">";
print "<input type=\"submit\" value=\"Cancel\" name=\"action\" class=\"button small\">";
print "</form>";
print "<div id=\"page-header\"></div>";

#print "@run";
