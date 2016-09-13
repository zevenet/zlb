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

### EDIT DATALINK FARM ###

#lateral menu

if ( $farmname =~ /^$/ )
{
	&errormsg( "Unknown farm name" );
	$action = "";
}

$ftype = &getFarmType( $farmname );
if ( $ftype ne "datalink" )
{
	&errormsg( "Invalid farm type" );
	$action = "";
}

$fstate = &getFarmStatus( $farmname );
if ( $fstate eq "down" )
{
	&errormsg( "The farm $farmname is down, to edit please start it up" );
	$action = "";
}

print "<form method=\"get\" action=\"index.cgi\">";

#change vip and vipp
if ( $action eq "editfarm-changevipvipp" )
{
	$error = 0;
	my @fvip = split ( " ", $vip );
	$fdev = @fvip[0];
	$vip  = @fvip[1];

	if ( $fdev eq "" )
	{
		&errormsg( "Invalid Interface value" );
		$error = 1;
	}
	if ( $vip eq "" )
	{
		&errormsg( "Invalid Virtual IP value" );
		$error = 1;
	}
	if ( $error == 0 )
	{
		&runFarmStop( $farmname, "true" );
		$status = &setFarmVirtualConf( $vip, $fdev, $farmname );
		if ( $status != -1 )
		{
			&runFarmStart( $farmname, "true" );
			&successmsg( "Virtual IP and Interface has been modified, the $farmname farm has been restarted" );
		}
		else
		{
			&errormsg( "It's not possible to change the $farmname farm virtual IP and interface" );
		}
	}
}

#change the global parameters##
#change Farm's name
if ( $action eq "editfarm-Name" )
{

	#Check if farmname has correct characters (letters, numbers and hyphens)
	my $farmnameok = &checkFarmnameOK( $newfarmname );

	#Check the farm's name change
	if ( "$newfarmname" eq "$farmname" )
	{
		&errormsg( "The new farm's name \"$newfarmname\" is the same as the old farm's name \"$farmname\": nothing to do" );
	}
	elsif ( $farmnameok ne 0 )
	{
		&errormsg( "Farm name isn't OK, only allowed numbers letters and hyphens" );
	}
	else
	{

		#Check if the new farm's name alredy exists
		$newffile = &getFarmFile( $newfarmname );
		if ( $newffile != -1 )
		{
			&errormsg( "The farm $newfarmname already exists, try another name" );
		}
		else
		{

			#Change farm name
			$fnchange = &setNewFarmName( $farmname, $newfarmname );

			if ( $fnchange == -1 )
			{
				&errormsg( "The name of the Farm $farmname can't be modified, delete the farm and create a new one." );
			}
			elsif ( $fnchange == -2 )
			{
				&errormsg( "The name of the Farm $farmname can't be modified, the new name can't be empty" );
			}
			else
			{
				&successmsg( "The Farm $farmname has been just renamed to $newfarmname." );
				$farmname = $newfarmname;
			}
		}
	}
}

#change the load balance algorithm;
if ( $action eq "editfarm-algorithm" )
{
	$error = 0;
	if ( $lb =~ /^$/ )
	{
		&errormsg( "Invalid algorithm value" );
		$error = 1;
	}
	if ( $error == 0 )
	{
		$status = &setFarmAlgorithm( $lb, $farmname );
		if ( $status != -1 )
		{

			#			$action="editfarm";
			&successmsg( "The algorithm for $farmname Farm is modified" );
		}
		else
		{
			&errormsg( "It's not possible to change the farm $farmname algorithm" );
		}
	}
}

#evalue the actions in the servers##
#edit server action
if ( $action eq "editfarm-saveserver" )
{
	$error = 0;
	if ( &ipisok( $rip_server ) eq "false" )
	{
		&errormsg( "Invalid real server IP value, please insert a valid value" );
		$error = 1;
	}
	if ( $rip_server =~ /^$/ || $if =~ /^$/ )
	{
		&errormsg( "Invalid IP address and network interface for a real server, it can't be blank" );
		$error = 1;
	}
	if ( $priority_server ne "" && ( $priority_server <= 0 || $priority_server >= 10 ) )
	{
		&errormsg( "Invalid priority value for real server" );
		$error = 1;
	}
	if ( $weight_server ne "" && ( $weight_server <= 0 || $weight_server >= 10000 ) )
	{
		&errormsg( "Invalid weight value for real server" );
		$error = 1;
	}

	if ( $error == 0 )
	{
		$status = &setFarmServer( $id_server, $rip_server, $if, "", $weight_server, $priority_server, "", $farmname );
		if ( $status != -1 )
		{
			&successmsg( "The real server with ip $rip_server and local interface $if for the $farmname farm has been modified" );
		}
		else
		{
			&errormsg( "It's not possible to modify the real server with ip $rip_server and interface $if for the $farmname farm" );
		}
	}
}

#delete server action
if ( $action eq "editfarm-deleteserver" )
{
	$status = &runFarmServerDelete( $id_server, $farmname );
	if ( $status != -1 )
	{
		&successmsg( "The real server with ID $id_server of the $farmname farm has been deleted" );
	}
	else
	{
		&errormsg( "It's not possible to delete the real server with ID $id_server of the $farmname farm" );
	}
}

print "<div class=\"container_12\">";
print "<div class=\"grid_12\">";

#paint a form to the global configuration
print "<div class=\"box-header\">Edit $farmname Farm global parameters</div>";
print "<div class=\"box stats\">";
print "<div class=\"row\">";

#Change farm's name form
print "<b>Farm's name.</b><br>";
print "<form method=\"get\" action=\"index.cgi\">";
print "<input type=\"hidden\" name=\"action\" value=\"editfarm-Name\">";
print "<input type=\"text\" value=\"$farmname\" size=\"25\" name=\"newfarmname\">";
print "<input type=\"hidden\" name=\"id\" value=\"$id\">";
print "<input type=\"hidden\" name=\"farmname\" value=\"$farmname\">";

#print "<input type=\"hidden\" name=\"id_server\" value=\"@l_serv[0]\">";
print "<input type=\"submit\" value=\"Modify\" name=\"buttom\" class=\"button small\"></form>";
print "<br><br>";

#load balance algoritm
$lb = &getFarmAlgorithm( $farmname );
if ( $lb == -1 )
{
	$lb = "weight";
}
$weight   = "Weight: connection dispatching by weight";
$priority = "Priority: connections to the highest priority available";
print "<b>Load Balance Algorithm.</b><br>";
print "<form method=\"get\" action=\"index.cgi\">";
print "<input type=\"hidden\" name=\"action\" value=\"editfarm-algorithm\">";
print "<select name=\"lb\">";
if ( $lb eq "weight" )
{
	print "<option value=\"weight\" selected=\"selected\">$weight</option>";
}
else
{
	print "<option value=\"weight\">$weight</option>";
}
if ( $lb eq "prio" )
{
	print "<option value=\"prio\" selected=\"selected\">$priority</option>";
}
else
{
	print "<option value=\"prio\">$priority</option>";
}

print "</select>";
print "<input type=\"hidden\" name=\"id\" value=\"$id\">";
print "<input type=\"hidden\" name=\"farmname\" value=\"$farmname\">";
print "<input type=\"submit\" value=\"Modify\" name=\"buttom\" class=\"button small\"></form>";
print "<br>";

#change ip or port for VIP
$vip   = &getFarmVip( "vip",  $farmname );
$vport = &getFarmVip( "vipp", $farmname );
print "<b>Farm Virtual IP and Interface</b> <font size=1> *service will be restarted</font><b>.</b>";

#my @listinterfaces = &listallips();
$clrip = &clrip();
$guiip = &GUIip();
print "<form method=\"get\" action=\"index.cgi\">";
print "<input type=\"hidden\" name=\"id\" value=\"$id\">";
print "<input type=\"hidden\" name=\"action\" value=\"editfarm-changevipvipp\">";
print "<input type=\"hidden\" name=\"farmname\" value=\"$farmname\">";

#print "<input type=\"hidden\" value=\"$vip\" size=\"12\" name=\"vip\">";
#print "<br>";

$nvips = &listactiveips( "phvlan" );
my @vips = split ( " ", $nvips );
print "<select name=\"vip\">\n";
print "<option value=\"\">-Select One-</option>\n";
for ( $i = 0 ; $i <= $#vips ; $i++ )
{
	my @ip = split ( "->", @vips[$i] );
	if ( @ip[1] ne $clrip && @ip[1] ne $guiip )
	{
		if ( $vip eq @ip[1] )
		{
			print "<option value=\"@ip[0] @ip[1]\" selected=\"selected\">@vips[$i]</option>\n";
		}
		else
		{
			print "<option value=\"@ip[0] @ip[1]\">@vips[$i]</option>\n";
		}
	}
}
print "</select>";
print "<input type=\"submit\" value=\"Modify\" name=\"buttom\" class=\"button small\"></form>";

#print "</form>";

####end form for global parameters

print "</div><br>";
print "</div>";
print "<div id=\"page-header\"></div>";

##paint the server configuration
my @run = &getFarmServers( $farmname );

print "<a name=\"backendlist\"></a>";

print "<div class=\"box-header\">Edit real IP servers configuration </div>";
print "<div class=\"box table\">";
print "  <table cellspacing=\"0\">";
print "    <thead>";
print "    <tr>";
print "		<td>Server</td>";
print "		<td>Address</td>";
print "		<td>Local Interface</td>";
print "		<td>Weight</td>";
print "		<td>Priority</td>";
print "		<td>Actions</td>";
print "    </tr>";
print "    </thead>";
print "	   <tbody>";

$id_serverchange = $id_server;
my $sindex   = 0;
my @laifaces = &listActiveInterfaces( "phvlan" );
foreach $l_servers ( @run )
{
	my @l_serv = split ( "\;", $l_servers );

	#	if (@l_serv[2] ne "0.0.0.0"){
	$isrs = "true";
	if ( $action eq "editfarm-editserver" && $id_serverchange eq @l_serv[0] )
	{
		print "<form method=\"get\" action=\"index.cgi\#backendlist\">";
		print "<tr class=\"selected\">";

		#id server
		print "<td>@l_serv[0]</td>";
		print "<input type=\"hidden\" name=\"id_server\" value=\"@l_serv[0]\">";

		#real server ip
		print "<td><input type=\"text\" size=\"12\"  name=\"rip_server\" value=\"@l_serv[1]\"> </td>";

		#local interface
		#print "<td><input type=\"text\" size=\"4\"  name=\"port_server\" value=\"@l_serv[2]\"> </td>";
		print "<td>";
		print "<select name=\"if\">";
		foreach $iface ( @laifaces )
		{
			if ( @l_serv[2] eq $iface )
			{
				print "<option value=\"$iface\" selected=\"selected\">$iface</option>";
			}
			else
			{
				print "<option value=\"$iface\">$iface</option>";
			}
		}
		print "</select>";
		print "</td>";

		#Weight
		print "<td><input type=\"text\" size=\"4\"  name=\"weight_server\" value=\"@l_serv[3]\"> </td>";

		#Priority
		print "<td><input type=\"text\" size=\"4\"  name=\"priority_server\" value=\"@l_serv[4]\"> </td>";
		&createmenuserversfarm( "edit", $farmname, @l_serv[0] );
	}
	else
	{
		print "<form method=\"get\" action=\"index.cgi\#backendlist\">";
		print "<tr>";
		print "<td>@l_serv[0]</td>";
		print "<td>@l_serv[1]</td>";
		print "<td>@l_serv[2]</td>";
		print "<td>@l_serv[3]</td>";
		print "<td>@l_serv[4]</td>";
		&createmenuserversfarm( "normal", $farmname, @l_serv[0] );
	}
	print "<input type=\"hidden\" name=\"id\" value=\"$id\">";
	print "<input type=\"hidden\" name=\"farmname\" value=\"$farmname\">";
	print "<input type=\"hidden\" name=\"id_server\" value=\"@l_serv[0]\">";
	print "</form>";
	print "</tr>";
	$sindex = @l_serv[0];

	#	}
}

## New backend form
$sindex = $sindex + 1;
if ( $action eq "editfarm-addserver" )
{
	$action = "editfarm";
	$isrs   = "true";
	print "<form method=\"get\" action=\"index.cgi\#backendlist\">";
	print "<tr class=\"selected\">";

	#id server
	print "<td>$sindex</td>";
	print "<input type=\"hidden\" name=\"id_server\" value=\"$sindex\">";

	#real server ip
	print "<td><input type=\"text\" size=\"12\"  name=\"rip_server\" value=\"\"> </td>";

	#local interface
	#print "<td><input type=\"text\" size=\"4\"  name=\"if\" value=\"\"> </td>";
	print "<td>";
	print "<select name=\"if\">";
	my $first = "true";
	foreach $iface ( @laifaces )
	{
		if ( $first eq "true" )
		{
			print "<option value=\"$iface\" selected=\"selected\">$iface</option>";
			$first = "false";
		}
		else
		{
			print "<option value=\"$iface\">$iface</option>";
		}
	}
	print "</select>";
	print "</td>";

	#Weight
	print "<td><input type=\"text\" size=\"4\"  name=\"weight_server\" value=\"\"></td>";

	#Priority
	print "<td><input type=\"text\" size=\"4\"  name=\"priority_server\" value=\"\"> </td>";
	&createmenuserversfarm( "add", $farmname, $sindex );
	print "<input type=\"hidden\" name=\"id\" value=\"$id\">";
	print "<input type=\"hidden\" name=\"farmname\" value=\"$farmname\">";
	print "<input type=\"hidden\" name=\"id_server\" value=\"$sindex\">";
	print "</form>";
	print "</tr>";
}

print "<tr>";
print "<td  colspan=\"5\"></td>";
print "<form method=\"get\" action=\"index.cgi\#backendlist\">";
&createmenuserversfarm( "new", $farmname, "" );
print "<input type=\"hidden\" name=\"id\" value=\"$id\">";
print "<input type=\"hidden\" name=\"farmname\" value=\"$farmname\">";
print "<input type=\"hidden\" name=\"id_server\" value=\"\">";
print "</form>";
print "</tr>";

#
print "</tbody>";
print "</table>";

#
print "</div>";

#
print "</div>";

print "<div id=\"page-header\"></div>";
print "<input type=\"submit\" value=\"Cancel\" name=\"action\" class=\"button small\">";
print "<div id=\"page-header\"></div>";
print "</form>";
print "</div>";
