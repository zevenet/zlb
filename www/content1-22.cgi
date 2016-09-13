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

### EDIT TCP/UDP FARM ###

#lateral menu
#global info for a farm
$maxtimeout   = "10000";
$maxmaxclient = "3000000";
$maxsimconn   = "32760";
$maxbackend   = "10000";

&logfile( "loading the $farmname Farm data" );
if ( $farmname =~ /^$/ )
{
	&errormsg( "Unknown farm name" );
	$action = "";
}
$ftype = &getFarmType( $farmname );
if ( $ftype ne "tcp" && $ftype ne "udp" )
{
	&errormsg( "Invalid farm type" );
	$action = "";
}

#$ffconf = &getFarmFile($farmname);
#$mport = &getFarmPort($farmname);
#$pid = &getFarmPid($farmname);
#$fcommand = &getFarmCommand($farmname);
$fstate = &getFarmStatus( $farmname );
if ( $fstate eq "down" )
{
	&errormsg( "The farm $farmname is down, to edit please start it up" );
	$action = "";
}

print "<form method=\"get\" action=\"index.cgi\">";

#maintenance mode for servers
if ( $action eq "editfarm-maintenance" )
{
	&setFarmBackendMaintenance( $farmname, $id_server );
	if ( $? eq 0 )
	{
		&successmsg( "Enabled maintenance mode for backend $id_server" );
	}

}

#disable maintenance mode for servers
if ( $action eq "editfarm-nomaintenance" )
{
	&setFarmBackendNoMaintenance( $farmname, $id_server );
	if ( $? eq 0 )
	{
		&successmsg( "Disabled maintenance mode for backend" );
	}

}

#change vip and vipp
if ( $action eq "editfarm-changevipvipp" )
{
	$error = 0;
	if ( &isnumber( $vipp ) eq "false" )
	{
		&errormsg( "Invalid Virtual Port $vipp value, it must be a numeric value" );
		$error = 1;
	}
	if ( &checkport( $vip, $vipp ) eq "true" )
	{
		&errormsg( "Virtual Port $vipp in Virtual IP $vip is in use, select another port" );
		$error = 1;
	}
	if ( $error == 0 )
	{
		$status = &setFarmVirtualConf( $vip, $vipp, $farmname );
		if ( $status != -1 )
		{
			&runFarmStop( $farmname, "true" );
			&runFarmStart( $farmname, "true" );
			&successmsg( "Virtual IP and Virtual Port has been modified, the $farmname farm has been restarted" );
		}
		else
		{
			&errormsg( "It's not possible to change the $farmname farm virtual IP and port" );
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

			#Stop farm
			$oldfstat = &runFarmStop( $farmname, "true" );
			if ( $oldfstat == 0 )
			{
				&successmsg( "The Farm $farmname is now disabled" );
			}
			else
			{
				&errormsg( "The Farm $farmname is not disabled, are you sure it's running?" );
			}

			#Change farm name
			$fnchange = &setNewFarmName( $farmname, $newfarmname );

			if ( $fnchange == -1 )
			{
				&errormsg( "The name of the Farm $farmname can't be modified, delete the farm and create a new one." );
			}
			elsif ( $fnchange == -2 )
			{
				&errormsg( "The name of the Farm $farmname can't be modified, the new name can't be empty" );
				my $newfstat = &runFarmStart( $farmname, "true" );
				if ( $newfstat == 0 )
				{
					&successmsg( "The Farm $farmname is now running" );
				}
				else
				{
					&errormsg( "The Farm $farmname isn't running, check if the IP address is up and the PORT is in use" );
				}
			}
			else
			{
				&successmsg( "The Farm $farmname has been just renamed to $newfarmname" );
				$farmname = $newfarmname;

				#Start farm
				my $newfstat = &runFarmStart( $farmname, "true" );
				if ( $newfstat == 0 )
				{
					&successmsg( "The Farm $farmname is now running" );
				}
				else
				{
					&errormsg( "The Farm $farmname isn't running, check if the IP address is up and the PORT is in use" );
				}
			}
		}
	}
}

#change Timeout
if ( $action eq "editfarm-Timeout" )
{
	$error = 0;
	if ( &isnumber( $timeout ) eq "false" )
	{
		&errormsg( "Invalid timeout $timeout value, it must be a numeric value" );
		$error = 1;
	}
	if ( $timeout > $maxtimeout )
	{
		&errormsg( "Invalid timeout $timeout value, the max timeout value is $maxtimeout" );
		$error = 1;
	}
	if ( $error == 0 )
	{
		$status = &setFarmTimeout( $timeout, $farmname );
		if ( $status != -1 )
		{
			&successmsg( "The timeout for $farmname farm has been modified" );
		}
		else
		{
			&errormsg( "It's not possible to change the $farmname farm timeout value" );
		}
	}
}

#change blacklist time
if ( $action eq "editfarm-blacklist" )
{
	$error = 0;
	if ( &isnumber( $blacklist ) eq "false" )
	{
		&errormsg( "Invalid blacklist $blacklist value, it must be a numeric value" );
		$error = 1;
	}
	if ( $error == 0 )
	{
		$status = &setFarmBlacklistTime( $blacklist, $farmname );
		if ( $status != -1 )
		{
			&successmsg( "The blacklist time for $farmname farm is modified" );
		}
		else
		{
			&errormsg( "It's not possible to change the farm $farmname blacklist time value" );
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

# control client persistence
if ( $action eq "editfarm-persistence" )
{
	if ( $persistence eq "true" )
	{
		$status = &setFarmPersistence( $persistence, $farmname );
		if ( $status != -1 )
		{
			&successmsg( "The client persistence is enabled" );
		}
		else
		{
			&errormsg( "It's not possible to enable the client persistence for the farm $farmname" );
		}
	}
	else
	{
		$status = &setFarmPersistence( $persistence, $farmname );
		if ( $status != -1 )
		{
			&successmsg( "The client persistence is disabled" );
		}
		else
		{
			&errormsg( "It's not possible to disable the client persistence for the farm $farmname" );
		}
	}
}

#change max_clients
if ( $action eq "editfarm-max_clients" )
{
	$error = 0;
	if ( &isnumber( $max_clients ) eq "false" )
	{
		&errormsg( "Invalid max clients value $max_clients, it must be numeric" );
		$error = 1;
	}
	if ( $max_clients > $maxmaxclient )
	{
		&errormsg( "Invalid max clients value $max_clients, the max value is $maxmaxclient" );
		$error = 1;
	}
	if ( $error == 0 )
	{
		$status = &setFarmMaxClientTime( $max_clients, $tracking, $farmname );
		if ( $status != -1 )
		{
			&runFarmStop( $farmname, "true" );
			&runFarmStart( $farmname, "true" );
			&successmsg( "The max number of clients has been modified, the farm $farmname has been restarted" );
		}
		else
		{
			&errormsg( "It's not possible to change the farm $farmname max clients" );
		}
	}
}

#change conn_max
if ( $action eq "editfarm-conn_max" )
{
	$error = 0;
	if ( &isnumber( $conn_max ) eq "false" )
	{
		&errormsg( "Invalid max connections value $conn_max, it must be numeric" );
		$error = 1;
	}
	if ( $conn_max > $maxsimconn )
	{
		&errormsg( "Invalid max connections value $conn_max, the max value is $maxsimconn" );
		$error = 1;
	}
	if ( $error == 0 )
	{
		$status = &setFarmMaxConn( $conn_max, $farmname );
		if ( $status != -1 )
		{
			&runFarmStop( $farmname, "true" );
			&runFarmStart( $farmname, "true" );
			&successmsg( "The max number of connections has been modified, the farm $farmname has been restarted" );
		}
		else
		{
			&errormsg( "It's not possible to change the farm $farmname max connections" );
		}
	}
}

#change max_servers
if ( $action eq "editfarm-max_servers" )
{
	$error = 0;
	if ( &isnumber( $max_servers ) eq "false" )
	{
		&errormsg( "Invalid max servers value $max_servers, it must be numeric" );
		$error = 1;
	}
	if ( $max_servers > $maxbackend )
	{
		&errormsg( "Invalid max servers value $max_servers, the max value is $maxsimconn" );
		$error = 1;
	}
	if ( $error == 0 )
	{
		$status = &setFarmMaxServers( $max_servers, $farmname );
		if ( $status != -1 )
		{
			&runFarmStop( $farmname, "true" );
			&runFarmStart( $farmname, "true" );
			&successmsg( "The max number of servers has been modified, the farm $farmname has been restarted" );
		}
		else
		{
			&errormsg( "It's not possible to change the farm $farmname max servers" );
		}
	}
}

#
if ( $action eq "editfarm-xforwardedfor" )
{
	if ( $ftype eq "tcp" )
	{
		if ( $xforwardedfor eq "true" )
		{
			$status = &setFarmXForwFor( $xforwardedfor, $farmname );
			if ( $status != -1 )
			{
				&successmsg( "The X-Forwarded-For header is enabled" );
			}
			else
			{
				&errormsg( "It's not possible to enable the X-Forwarded-For header for the farm $farmname" );
			}
		}
		else
		{
			$status = &setFarmXForwFor( $xforwardedfor, $farmname );
			if ( $status != -1 )
			{
				&successmsg( "The X-Forwarded-For header is disabled" );
			}
			else
			{
				&errormsg( "It's not possible to disable the X-Forwarded-For header for the farm $farmname" );
			}
		}
	}
	else
	{
		&errormsg( "It's not possible to use the X-Forwarded-For header for the UDP farm $farmname" );
	}
}

#change farmguardian values
if ( $action eq "editfarm-farmguardian" )
{
	$fguardianconf = &getFarmGuardianFile( $fname, "" );

	if ( &isnumber( $timetocheck ) eq "false" )
	{
		&errormsg( "Invalid period time value $timetocheck, it must be numeric" );
	}
	else
	{
		$status = -1;
		$usefarmguardian =~ s/\n//g;
		&runFarmGuardianStop( $farmname, "" );
		&logfile( "creating $farmname farmguardian configuration file in  $fguardianconf" );
		$check_script =~ s/\"/\'/g;
		$status = &runFarmGuardianCreate( $farmname, $timetocheck, $check_script, $usefarmguardian, $farmguardianlog, "" );
		if ( $status != -1 )
		{
			&successmsg( "The FarmGuardian service for the $farmname farm has been modified" );
			if ( $usefarmguardian eq "true" )
			{
				$status = &runFarmGuardianStart( $farmname, "" );
				if ( $status != -1 )
				{
					&successmsg( "The FarmGuardian service for the $farmname farm has been started" );
				}
				else
				{
					&errormsg( "An error ocurred while starting the FarmGuardian service for the $farmname farm" );
				}
			}
		}
		else
		{
			&errormsg( "It's not possible to create the FarmGuardian configuration file for the $farmname farm" );
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
	if ( $rip_server =~ /^$/ || $port_server =~ /^$/ )
	{
		&errormsg( "Invalid IP address and port for a real server, it can't be blank" );
		$error = 1;
	}

	if ( $error == 0 )
	{
		$status = &setFarmServer( $id_server, $rip_server, $port_server, $max_server, $weight_server, $priority_server, "", $farmname );
		if ( $status != -1 )
		{
			&successmsg( "The real server with ip $rip_server and port $port_server for the $farmname farm has been modified" );
		}
		else
		{
			&errormsg( "It's not possible to modify the real server with ip $rip_server and port $port_server for the $farmname farm" );
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
print "<b>Farm's name</b><font size=1> *service will be restarted</font><b>.</b><br>";
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
	$lb = "roundrobin";
}

#$Default="Round Robin: persistence client-time";
$roundrobin = "Round Robin: equal sharing";
$hash       = "Hash: sticky client";
$weight     = "Weight: connection linear dispatching by weight";
$priority   = "Priority: connections to the highest priority available";
print "<b>Load Balance Algorithm.</b>";
print "<form method=\"get\" action=\"index.cgi\">";
print "<input type=\"hidden\" name=\"action\" value=\"editfarm-algorithm\">";
print "<select name=\"lb\">";

#	if ($lb eq "Default"){
#		print "<option value=\"Default\" selected=\"selected\">$Default</option>";
#	} else {
#		print "<option value=\"Default\">$Default</option>";
#	}
if ( $lb eq "roundrobin" )
{
	print "<option value=\"roundrobin\" selected=\"selected\">$roundrobin</option>";
}
else
{
	print "<option value=\"roundrobin\">$roundrobin</option>";
}
if ( $lb eq "hash" )
{
	print "<option value=\"hash\" selected=\"selected\">$hash</option>";
}
else
{
	print "<option value=\"hash\">$hash</option>";
}
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

#enable client persistence
if ( $ftype eq "tcp" )
{
	$persistence = &getFarmPersistence( $farmname );
	if ( $persistence == -1 )
	{
		$persistence = "true";
	}
	print "<br>";
	print "<form method=\"get\" action=\"index.cgi\">";
	if ( $persistence eq "true" )
	{
		print "<input type=\"checkbox\" checked name=\"persistence\" value=\"true\">";
	}
	else
	{
		print "<input type=\"checkbox\" name=\"persistence\" value=\"true\">";
	}
	print "&nbsp;<b>Enable client ip address persistence through memory.</b><br>";
	print "<input type=\"hidden\" name=\"action\" value=\"editfarm-persistence\">";
	print "<input type=\"hidden\" name=\"id\" value=\"$id\">";
	print "<input type=\"hidden\" name=\"farmname\" value=\"$farmname\">";
	print "<input type=\"submit\" value=\"Modify\" name=\"buttom\" class=\"button small\"></form>";
	print "</form><br/>";

	#clients_max value
	@client = &getFarmMaxClientTime( $farmname );
	if ( @client == -1 )
	{
		$maxclients = 256;
		$tracking   = 10;
	}
	else
	{
		$maxclients = @client[0];
		$tracking   = @client[1];
	}
	print "<b>Max number of clients memorized in the farm</b><font size=1> *service will be restarted</font><b>.</b><br>";
	print "<form method=\"get\" action=\"index.cgi\">";
	print "<input type=\"hidden\" name=\"action\" value=\"editfarm-max_clients\">";
	print "<input type=\"text\" value=\"$maxclients\" size=\"4\" name=\"max_clients\">";
	print "<input type=\"hidden\" name=\"id\" value=\"$id\">";
	print "<input type=\"hidden\" name=\"farmname\" value=\"$farmname\">";
	print "<b> client-time</b>(sec, 0=always)<input type=\"text\" value=\"$tracking\" size=\"4\" name=\"tracking\">";
	print "<input type=\"submit\" value=\"Modify\" name=\"buttom\" class=\"button small\"></form>";
	print "</form>";
}
print "<br>";

# Timeout Form
$ftimeout = &getFarmTimeout( $farmname );
if ( $ftimeout == -1 )
{
	$ftimeout = 4;
}
print "<b>Backend response timeout secs.</b><br>";
print "<form method=\"get\" action=\"index.cgi\">";
print "<input type=\"hidden\" name=\"action\" value=\"editfarm-Timeout\">";
print "<input type=\"text\" value=\"$ftimeout\" size=\"4\" name=\"timeout\">";
print "<input type=\"hidden\" name=\"id\" value=\"$id\">";
print "<input type=\"hidden\" name=\"farmname\" value=\"$farmname\">";
print "<input type=\"submit\" value=\"Modify\" name=\"buttom\" class=\"button small\"></form>";

#conn_max value
$conn_max = &getFarmMaxConn( $farmname );
if ( $conn_max == -1 )
{
	$conn_max = 512;
}
print "<br>";
print "<b>Max number of simultaneous connections that manage in Virtual IP</b><font size=1> *service will be restarted</font><b>.</b><br>";
print "<form method=\"get\" action=\"index.cgi\">";
print "<input type=\"hidden\" name=\"action\" value=\"editfarm-conn_max\">";
print "<input type=\"text\" value=\"$conn_max\" size=\"4\" name=\"conn_max\">";
print "<input type=\"hidden\" name=\"id\" value=\"$id\">";
print "<input type=\"hidden\" name=\"farmname\" value=\"$farmname\">";
print "<input type=\"submit\" value=\"Modify\" name=\"buttom\" class=\"button small\"></form>";
print "</form>";

#number of real ip
$numberofservers = &getFarmMaxServers( $farmname );
if ( $numberofservers == -1 )
{
	$numberofservers = 16;
}
print "<br>";
print "<b>Max number of real ip servers</b><font size=1> *service will be restarted</font><b>.</b><br>";
print "<form method=\"get\" action=\"index.cgi\">";
print "<input type=\"hidden\" name=\"action\" value=\"editfarm-max_servers\">";
print "<input type=\"text\" value=\"$numberofservers\" size=\"4\" name=\"max_servers\">";
print "<input type=\"hidden\" name=\"id\" value=\"$id\">";
print "<input type=\"hidden\" name=\"farmname\" value=\"$farmname\">";
print "<input type=\"submit\" value=\"Modify\" name=\"buttom\" class=\"button small\"></form>";
print "</form>";

if ( $ftype eq "tcp" )
{

	#x-forwarded-for header parameter
	$xforw = &getFarmXForwFor( $farmname );
	if ( $xforw == -1 )
	{
		$xforw = "false";
	}
	print "<br>";
	print "<form method=\"get\" action=\"index.cgi\">";
	if ( $xforw eq "false" )
	{
		print "<input type=\"checkbox\" name=\"xforwardedfor\" value=\"true\">";
	}
	else
	{
		print "<input type=\"checkbox\" checked name=\"xforwardedfor\" value=\"true\">";
	}
	print "&nbsp;<b>Add X-Forwarded-For header to http requests.</b><br>";
	print "<input type=\"hidden\" name=\"action\" value=\"editfarm-xforwardedfor\">";
	print "<input type=\"hidden\" name=\"id\" value=\"$id\">";
	print "<input type=\"hidden\" name=\"farmname\" value=\"$farmname\">";
	print "<input type=\"submit\" value=\"Modify\" name=\"buttom\" class=\"button small\"></form>";
	print "</form>";
}

#blackisted time  parameter
$blacklist = &getFarmBlacklistTime( $farmname );
if ( $blacklist == -1 )
{
	if ( $ftype eq "udp" )
	{
		$blacklist = 3;
	}
	else
	{
		$blacklist = 30;
	}
}
print "<br>";
print "<form method=\"get\" action=\"index.cgi\">";
print "&nbsp;<b>Frequency to check resurrected backends secs.</b><br>";
print "<input type=\"hidden\" name=\"action\" value=\"editfarm-blacklist\">";
print "<input type=\"text\" value=\"$blacklist\" size=\"4\" name=\"blacklist\">";
print "<input type=\"hidden\" name=\"id\" value=\"$id\">";
print "<input type=\"hidden\" name=\"farmname\" value=\"$farmname\">";
print "<input type=\"submit\" value=\"Modify\" name=\"buttom\" class=\"button small\"></form>";
print "</form>";

if ( $ftype eq "tcp" )
{

	#use farmguardian
	#open farmguardian file to view config.
	@fgconfig  = &getFarmGuardianConf( $farmname, "" );
	$fgttcheck = @fgconfig[1];
	$fgscript  = @fgconfig[2];
	$fgscript =~ s/\n//g;
	$fgscript =~ s/\"/\'/g;
	$fguse = @fgconfig[3];
	$fguse =~ s/\n//g;
	$fglog = @fgconfig[4];
	if ( !$timetocheck ) { $timetocheck = 5; }

	print "<br>";
	print "<form method=\"get\" action=\"index.cgi\">";
	if ( $fguse eq "true" )
	{
		print "<input type=\"checkbox\" checked name=\"usefarmguardian\" value=\"true\">";
	}
	else
	{
		print "<input type=\"checkbox\"  name=\"usefarmguardian\" value=\"true\"> ";
	}
	print "&nbsp;<b>Use FarmGuardian to check Backend Servers.</b><br>";
	print "<input type=\"hidden\" name=\"action\" value=\"editfarm-farmguardian\">";
	print "<font size=1>Check every </font>&nbsp;<input type=\"text\" value=\"$fgttcheck\" size=\"1\" name=\"timetocheck\">&nbsp;<font size=1> secs.</font><br>";
	print "<font size=1>Command to check </font><input type=\"text\" value=\"$fgscript\" size=\"60\" name=\"check_script\">";
	print "<br>";
	if ( $fglog eq "true" )
	{
		print "<input type=\"checkbox\" checked name=\"farmguardianlog\" value=\"true\"> ";
	}
	else
	{
		print "<input type=\"checkbox\"  name=\"farmguardianlog\" value=\"true\"> ";
	}
	print "&nbsp;<font size=1> Enable farmguardian logs</font>";
	print "<br>";
	print "<input type=\"hidden\" name=\"id\" value=\"$id\">";
	print "<input type=\"hidden\" name=\"farmname\" value=\"$farmname\">";
	print "<input type=\"submit\" value=\"Modify\" name=\"buttom\" class=\"button small\"></form>";
	print "</form>";
}

#change ip or port for VIP
$vip   = &getFarmVip( "vip",  $farmname );
$vport = &getFarmVip( "vipp", $farmname );
print "<br>";
print "<b>Farm Virtual IP and Virtual port</b> <font size=1> *service will be restarted</font><b>.</b>";
@listinterfaces = &listallips();
$clrip          = &clrip();
$guiip          = &GUIip();
print "<form method=\"get\" action=\"index.cgi\">";
print "<input type=\"hidden\" name=\"id\" value=\"$id\">";
print "<input type=\"hidden\" name=\"action\" value=\"editfarm-changevipvipp\">";
print "<input type=\"hidden\" name=\"farmname\" value=\"$farmname\">";

#print "<input type=\"hidden\" value=\"$vip\" size=\"12\" name=\"vip\">";
print "<select name=\"vip\">";
foreach $ip ( @listinterfaces )
{
	if ( $ip ne $clrip && $ip ne $guiip )
	{
		if ( $vip eq $ip )
		{
			print "<option value=\"$ip\" selected=\"selected\">$ip</option>";
		}
		else
		{
			print "<option value=\"$ip\">$ip</option>";
		}
	}
}

print "</select>";
print " <input type=\"text\" value=\"$vport\" size=\"4\" name=\"vipp\">";
print "<input type=\"submit\" value=\"Modify\" name=\"buttom\" class=\"button small\"></form>";
print "</form>";

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
print "		<td>Port</td>";
print "		<td>Max connections</td>";
print "		<td>Weight</td>";
print "		<td>Priority</td>";
print "		<td>Actions</td>";
print "    </tr>";
print "    </thead>";
print "	   <tbody>";

$id_serverchange = $id_server;
foreach $l_servers ( @run )
{
	my @l_serv = split ( "\ ", $l_servers );
	if ( @l_serv[2] ne "0.0.0.0" )
	{
		$isrs = "true";
		if ( $action eq "editfarm-editserver" && $id_serverchange eq @l_serv[0] )
		{
			print "<form method=\"get\" action=\"index.cgi\#backendlist\">";
			print "<tr class=\"selected\">";

			#id server
			print "<td>@l_serv[0]</td>";
			print "<input type=\"hidden\" name=\"id_server\" value=\"@l_serv[0]\">";

			#real server ip
			print "<td><input type=\"text\" size=\"12\"  name=\"rip_server\" value=\"@l_serv[2]\"> </td>";

			#port
			print "<td><input type=\"text\" size=\"4\"  name=\"port_server\" value=\"@l_serv[4]\"> </td>";

			#max connections
			print "<td><input type=\"text\" size=\"4\"  name=\"max_server\" value=\"@l_serv[8]\"> </td>";

			#Weight
			print "<td><input type=\"text\" size=\"4\"  name=\"weight_server\" value=\"@l_serv[12]\"> </td>";

			#Priority
			print "<td><input type=\"text\" size=\"4\"  name=\"priority_server\" value=\"@l_serv[14]\"> </td>";
			&createmenuserversfarm( "edit", $farmname, @l_serv[0] );
		}
		else
		{
			print "<form method=\"get\" action=\"index.cgi\#backendlist\">";
			print "<tr>";
			print "<td>@l_serv[0]</td>";
			print "<td>@l_serv[2]</td>";
			print "<td>@l_serv[4]</td>";
			print "<td>@l_serv[8]</td>";
			print "<td>@l_serv[12]</td>";
			print "<td>@l_serv[14]</td>";
			&createmenuserversfarm( "normal", $farmname, @l_serv[0] );
			my $maintenance = &getFarmBackendMaintenance( $farmname, @l_serv[0] );
		}
		print "<input type=\"hidden\" name=\"id\" value=\"$id\">";
		print "<input type=\"hidden\" name=\"farmname\" value=\"$farmname\">";
		print "<input type=\"hidden\" name=\"id_server\" value=\"@l_serv[0]\">";
		print "</form>";
		print "</tr>";
	}

	if ( @l_serv[2] eq "0.0.0.0" && $action eq "editfarm-addserver" )
	{
		$action = "editfarm";
		$isrs   = "true";
		print "<form method=\"get\" action=\"index.cgi\#backendlist\">";
		print "<tr class=\"selected\">";

		#id server
		print "<td>@l_serv[0]</td>";
		print "<input type=\"hidden\" name=\"id_server\" value=\"@l_serv[0]\">";

		#real server ip
		print "<td><input type=\"text\" size=\"12\"  name=\"rip_server\" value=\"\"> </td>";

		#port
		print "<td><input type=\"text\" size=\"4\"  name=\"port_server\" value=\"\"> </td>";

		#max connections
		print "<td><input type=\"text\" size=\"4\"  name=\"max_server\" value=\"\"> </td>";

		#Weight
		print "<td><input type=\"text\" size=\"4\"  name=\"weight_server\" value=\"\"> </td>";

		#Priority
		print "<td><input type=\"text\" size=\"4\"  name=\"priority_server\" value=\"\"> </td>";
		&createmenuserversfarm( "add", $farmname, @l_serv[0] );
		print "<input type=\"hidden\" name=\"id\" value=\"$id\">";
		print "<input type=\"hidden\" name=\"farmname\" value=\"$farmname\">";
		print "<input type=\"hidden\" name=\"id_server\" value=\"@l_serv[0]\">";
		print "</form>";
		print "</tr>";
	}
}

print "<tr>";
print "<td  colspan=\"6\"></td>";
print "<form method=\"get\" action=\"index.cgi\#backendlist\">";
&createmenuserversfarm( "new", $farmname, @l_serv[0] );
print "<input type=\"hidden\" name=\"id\" value=\"$id\">";
print "<input type=\"hidden\" name=\"farmname\" value=\"$farmname\">";
print "<input type=\"hidden\" name=\"id_server\" value=\"@l_serv[0]\">";
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
