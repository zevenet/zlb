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

### EDIT L4xNAT FARM ###

if ( $farmname =~ /^$/ )
{
	&errormsg( "Unknown farm name" );
	$action = "";
}

$ftype = &getFarmType( $farmname );
if ( $ftype ne "l4xnat" )
{
	&errormsg( "Invalid farm type" );
	$action = "";
}

$fstate = &getFarmStatus( $farmname );
#if ( $fstate eq "down" )
#{
#	&errormsg( "The farm $farmname is down, to edit please start it up" );
	#$action = "";
#}

#maintenance mode for servers
#if ($action eq "editfarm-maintenance"){
#        &setFarmBackendMaintenance($farmname,$id_server);
#        if ($? eq 0){
#                &successmsg("Enabled maintenance mode for backend $id_server");
#        }
#}

#disable maintenance mode for servers
#if ($action eq "editfarm-nomaintenance"){
#        &setFarmBackendNoMaintenance($farmname,$id_server);
#        if ($? eq 0){
#                &successmsg("Disabled maintenance mode for backend");
#        }
#}

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

if ( $action eq "editfarm-changevipvipp" )
{
	my $fproto = &getFarmProto( $farmname );
	if ( $fproto ne "all" && &ismport( $vipp ) eq "false" )
	{
		&errormsg( "Invalid Virtual Port $vipp value, it must be a valid multiport value" );
		$error = 1;
	}

	#        if (&checkport($vip,$vipp) eq "true"){
	#                &errormsg("Virtual Port $vipp in Virtual IP $vip is in use, select another port");
	#                $error = 1;
	#        }
	if ( $error == 0 )
	{
		$status = &setFarmVirtualConf( $vip, $vipp, $farmname );
		if ( $status != -1 )
		{
	                if ( $fstate ne "down" ) #apply changes
        	        {
                	        &runFarmStop( $farmname, "false" );
                	        &runFarmStart( $farmname, "false" );
                	}
			&successmsg( "Virtual IP and Virtual Port has been modified for the farm $farmname" );
		}
		else
		{
			&errormsg( "It's not possible to change the $farmname farm virtual IP and port" );
		}
	}
}

if ( $action eq "editfarm-restart" )
{
	&runFarmStop( $farmname, "true" );
	$status = &runFarmStart( $farmname, "true" );
	if ( $status == 0 )
	{
		&successmsg( "The $farmname farm has been restarted" );
	}
	else
	{
		&errormsg( "The $farmname farm hasn't been restarted" );
	}
}

#delete server
if ( $action eq "editfarm-deleteserver" )
{
	$status = &runFarmServerDelete( $id_server, $farmname );
	if ( $status != -1 )
	{
                if ( $fstate ne "down" ) #apply changes
                {
                        &runFarmStop( $farmname, "false" );
                        &runFarmStart( $farmname, "false" );
                }
		&successmsg( "The real server with ID $id_server of the $farmname farm has been deleted" );
	}
	else
	{
		&errormsg( "It's not possible to delete the real server with ID $id_server of the $farmname farm" );
	}
}

#save server
if ( $action eq "editfarm-saveserver" )
{
	$error = 0;
	if ( &ipisok( $rip_server ) eq "false" || $rip_server =~ /^$/ )
	{
		&errormsg( "Invalid real server IP value, please insert a valid value" );
		$error = 1;
	}

	#if ($port_server =~ /^$/) {
	#	&errormsg("Invalid port for real server, it can't be blank");
	#	$error = 1;
	#}
	if ( &checkmport( $port_server ) eq "true" )
	{
		my $port = &getFarmVip( "vipp", $fname );
		if ( $port_server == $port )
		{
			$port_server = "";
		}
		else
		{
			&errormsg( "Invalid multiple ports for backend, please insert a single port number or blank" );
			$error = 1;
		}
	}
	if ( $weight_server =~ /^$/ )
	{
		$weight_server = 1;
	}
	elsif ( $weight_server eq "0" )
	{
		&errormsg( "Invalid real server weight value, please insert a value greater than 0" );
		$error = 1;
	}
	if ( $priority_server =~ /^$/ )
	{
		$priority_server = 1;
	}
	if ( $error == 0 )
	{
		$status = &setFarmServer( $id_server, $rip_server, $port_server, $max_server, $weight_server, $priority_server, $timeout_server, $farmname );
		if ( $status != -1 )
		{
                if ( $fstate ne "down" ) #apply changes
 	        {
                        &runFarmStop( $farmname, "false" );
                        &runFarmStart( $farmname, "false" );
        	}

			&successmsg( "The real server with ID $id_server and IP $rip_server of the $farmname farm has been modified" );
		}
		else
		{
			&errormsg( "It's not possible to modify the real server with ID $id_server and IP $rip_server of the $farmname farm" );
		}
	}
}

#session type
if ( $action eq "editfarm-typesession" )
{
	$status = &setFarmSessionType( $session, $farmname );
	if ( $status == 0 )
	{
                if ( $fstate ne "down" ) #apply changes
                {
                        &runFarmStop( $farmname, "false" );
                        &runFarmStart( $farmname, "false" );
                }

		&successmsg( "The session type for $farmname farm has been modified" );
	}
	else
	{
		&errormsg( "It's not possible to change the $farmname farm session type" );
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

                if ( $fstate ne "down" ) #apply changes
                {
                        &runFarmStop( $farmname, "false" );
                        &runFarmStart( $farmname, "false" );
                }

			&successmsg( "The algorithm for $farmname Farm is modified" );
		}
		else
		{
			&errormsg( "It's not possible to change the farm $farmname algorithm" );
		}
	}
}

#nat type
if ( $action eq "editfarm-nattype" )
{
	$status = &setFarmNatType( $nattype, $farmname );
	if ( $status == 0 )
	{
                if ( $fstate ne "down" ) #apply changes
                {
                        &runFarmStop( $farmname, "false" );
                        &runFarmStart( $farmname, "false" );
                }
		&successmsg( "The NAT type for $farmname farm has been modified" );
	}
	else
	{
		&errormsg( "It's not possible to change the $farmname farm NAT type" );
	}
}

#proto type
if ( $action eq "editfarm-prototype" )
{
	$status = &setFarmProto( $farmprotocol, $farmname );
	if ( $status == 0 )
	{
		if ( $fstate ne "down" ) #apply changes
		{
			&runFarmStop( $farmname, "false" );
                        &runFarmStart( $farmname, "false" );
                }
		&successmsg( "The protocol type for $farmname farm has been modified" );
	}
	else
	{
		&errormsg( "It's not possible to change the $farmname farm protocol type" );
	}
}

#TTL
if ( $action eq "editfarm-TTL" )
{
	$error = 0;
	if ( &isnumber( $param ) eq "false" )
	{
		&errormsg( "Invalid client timeout $param value, it must be a numeric value" );
		$error = 1;
	}
	if ( $error == 0 )
	{
		$status = &setFarmMaxClientTime( 0, $param, $farmname );
		if ( $status == 0 )
		{
			if ( $fstate ne "down" ) #apply changes
			{
				&runFarmStop( $farmname, "false" );
				&runFarmStart( $farmname, "false" );
			}
			&successmsg( "The sessions TTL for $farmname farm has been modified" );
		}
		else
		{
			&errormsg( "It's not possible to change the $farmname farm sessions TTL" );
		}
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

#check if the farm need a restart
#if (-e "/tmp/$farmname.lock"){
#	&tipmsg("There're changes that need to be applied, stop and start farm to apply them!");
#}

#global info for a farm
print "<div class=\"container_12\">";
print "<div class=\"grid_12\">";

#paint a form to the global configuration
print "<div class=\"box-header\">Edit $farmname Farm global parameters</div>";
print "<div class=\"box stats\">";
print "<div class=\"row\">";

#print "<div style=\"float:left;\">";

#Change farm's name form
print "<b>Farm's name</b><font size=1> *service will be restarted</font><b>.</b><br>";
print "<form method=\"get\" action=\"index.cgi\">";
print "<input type=\"hidden\" name=\"action\" value=\"editfarm-Name\">";
print "<input type=\"text\" value=\"$farmname\" size=\"25\" name=\"newfarmname\">";
print "<input type=\"hidden\" name=\"id\" value=\"$id\">";
print "<input type=\"hidden\" name=\"farmname\" value=\"$farmname\">";
print "<input type=\"hidden\" name=\"done\" value=\"yes\">";
print "<input type=\"hidden\" name=\"id_server\" value=\"@l_serv[0]\">";
print "<input type=\"submit\" value=\"Modify\" name=\"buttom\" class=\"button small\"></form>";
print "<br>";

#protocol
print "<b>Protocol type </b><font size=\"1\">*the service will be restarted</font><b>.</b>";
my $farmprotocol = &getFarmProto( $farmname );
if ( $farmprotocol == -1 )
{
	$farmprotocol = "all";
}
print "<form method=\"get\" action=\"index.cgi\">";
print "<input type=\"hidden\" name=\"action\" value=\"editfarm-prototype\">";
print "<input type=\"hidden\" name=\"id\" value=\"$id\">";
print "<input type=\"hidden\" name=\"farmname\" value=\"$farmname\">";
print "<select  name=\"farmprotocol\">";
if ( $farmprotocol eq "all" )
{
	print "<option value=\"all\" selected=\"selected\">ALL</option>";
}
else
{
	print "<option value=\"all\">ALL</option>";
}
if ( $farmprotocol eq "tcp" )
{
	print "<option value=\"tcp\" selected=\"selected\">TCP</option>";
}
else
{
	print "<option value=\"tcp\">TCP</option>";
}
if ( $farmprotocol eq "udp" )
{
	print "<option value=\"udp\" selected=\"selected\">UDP</option>";
}
else
{
	print "<option value=\"udp\">UDP</option>";
}
if ( $farmprotocol eq "sip" )
{
	print "<option value=\"sip\" selected=\"selected\">SIP</option>";
}
else
{
	print "<option value=\"sip\">SIP</option>";
}
print "</select>";
print "<input type=\"submit\" value=\"Modify\" name=\"buttom\" class=\"button small\"></form>";
print "<br>";

# NAT type
print "<b>NAT type </b><font size=\"1\">*the service will be restarted</font><b>.</b>";
my $nattype = &getFarmNatType( $farmname );
if ( $nattype == -1 )
{
	$nattype = "nat";
}
my $seldisabled = "";

#if ($farmprotocol eq "sip"){
#	$seldisabled="disabled";
#}
print "<form method=\"get\" action=\"index.cgi\">";
print "<input type=\"hidden\" name=\"action\" value=\"editfarm-nattype\">";
print "<input type=\"hidden\" name=\"id\" value=\"$id\">";
print "<input type=\"hidden\" name=\"farmname\" value=\"$farmname\">";
print "<select $seldisabled name=\"nattype\">";
if ( $nattype eq "nat" )
{
	print "<option value=\"nat\" selected=\"selected\">NAT</option>";
}
else
{
	print "<option value=\"nat\">NAT</option>";
}
if ( $nattype eq "dnat" )
{
	print "<option value=\"dnat\" selected=\"selected\">DNAT</option>";
}
else
{
	print "<option value=\"dnat\">DNAT</option>";
}

#if ($nattype eq "snat"){
#	print "<option value=\"snat\" selected=\"selected\">SNAT</option>";
#} else {
#	print "<option value=\"snat\">SNAT</option>";
#}
print "</select>";
print "<input type=\"submit\" value=\"Modify\" name=\"buttom\" class=\"button small\"></form>";
print "<br>";

#print "<b>Backend response timeout secs.<br>";
#$timeout = &getFarmTimeout($farmname);
#print "<form method=\"get\" action=\"index.cgi\">";
#print "<input type=\"hidden\" name=\"action\" value=\"editfarm-Timeout-http\">";
#print "<input type=\"text\" value=\"$timeout\" size=\"4\" name=\"param\">";
#print "<input type=\"hidden\" name=\"id\" value=\"$id\">";
#print "<input type=\"hidden\" name=\"farmname\" value=\"$farmname\">";
#print "<input type=\"submit\" value=\"Modify\" name=\"buttom\" class=\"button small\"></form>";
#print "<br>";

#Timeout for client
#print "<b>Timeout request from clients secs.</b>";
#$client = &getFarmClientTimeout($farmname);
#print "<form method=\"get\" action=\"index.cgi\">";
#print "<input type=\"hidden\" name=\"action\" value=\"editfarm-Client\">";
#print "<input type=\"text\" value=\"$client\" size=\"4\" name=\"param\">";
#print "<input type=\"hidden\" name=\"id\" value=\"$id\">";
#print "<input type=\"hidden\" name=\"farmname\" value=\"$farmname\">";
#print "<input type=\"submit\" value=\"Modify\" name=\"buttom\" class=\"button small\"></form>";

#algorithm
print "<b>Load Balance Algorithm </b><font size=\"1\">*the service will be restarted</font><b>.</b>";
$lbalg = &getFarmAlgorithm( $farmname );
if ( $lbalg == -1 )
{
	$lbalg = "weight";
}
print "<form method=\"get\" action=\"index.cgi\">";
print "<input type=\"hidden\" name=\"action\" value=\"editfarm-algorithm\">";
print "<input type=\"hidden\" name=\"id\" value=\"$id\">";
print "<input type=\"hidden\" name=\"farmname\" value=\"$farmname\">";
print "<select  name=\"lb\">";
if ( $lbalg eq "weight" )
{
	print "<option value=\"weight\" selected=\"selected\">Weight: connection linear dispatching by weight</option>";
}
else
{
	print "<option value=\"weight\">Weight: connection linear dispatching by weight</option>";
}
if ( $lbalg eq "prio" )
{
	print "<option value=\"prio\" selected=\"selected\">Priority: connections always to the most prio available</option>";
}
else
{
	print "<option value=\"prio\" >Priority: connections always to the most prio available</option>";
}
print "</select>";
print "<input type=\"submit\" value=\"Modify\" name=\"buttom\" class=\"button small\"></form>";
print "<br>";

#type session
print "<b>Persistence mode </b><font size=\"1\">*the service will be restarted</font><b>.</b>";
$session = &getFarmSessionType( $farmname );
if ( $session == -1 )
{
	$session = "none";
}
print "<form method=\"get\" action=\"index.cgi\">";
print "<input type=\"hidden\" name=\"action\" value=\"editfarm-typesession\">";
print "<input type=\"hidden\" name=\"id\" value=\"$id\">";
print "<input type=\"hidden\" name=\"farmname\" value=\"$farmname\">";
print "<select  name=\"session\">";
print "<option value=\"none\">no persistence</option>";
if ( $session eq "ip" )
{
	print "<option value=\"ip\" selected=\"selected\">IP persistence</option>";
}
else
{
	print "<option value=\"ip\" >IP persistence</option>";
}

#if ($session eq "connection"){
#	print "<option value=\"connection\" selected=\"selected\">CONNECTION persistence</option>";
#} else {
#	print "<option value=\"connection\">CONNECTION persistence</option>";
#}
print "</select>";
print "<input type=\"submit\" value=\"Modify\" name=\"buttom\" class=\"button small\"></form>";
print "<br>";

#print "<b>Frequency to check resurrected backends.</b>";
#$alive = &getFarmBlacklistTime($farmname);
#print "<form method=\"get\" action=\"index.cgi\">";
#print "<input type=\"hidden\" name=\"action\" value=\"editfarm-Alive\">";
#print "<input type=\"text\" value=\"$alive\" size=\"4\" name=\"param\">";
#print "<input type=\"hidden\" name=\"id\" value=\"$id\">";
#print "<input type=\"hidden\" name=\"farmname\" value=\"$farmname\">";
#print "<input type=\"submit\" value=\"Modify\" name=\"buttom\" class=\"button small\"></form>";
#print "<br>";

#session TTL
#if ($session ne "nothing" && $session){
print "<b>Source IP Address Persistence time to limit </b><font size=\"1\">*in secs, only for IP persistence</font><b>.</b>";
@ttl = &getFarmMaxClientTime( $farmname );
print "<form method=\"get\" action=\"index.cgi\">";
print "<input type=\"hidden\" name=\"action\" value=\"editfarm-TTL\">";
print "<input type=\"text\" value=\"@ttl[0]\" size=\"4\" name=\"param\">";
print "<input type=\"hidden\" name=\"id\" value=\"$id\">";
print "<input type=\"hidden\" name=\"farmname\" value=\"$farmname\">";
print "<input type=\"submit\" value=\"Modify\" name=\"buttom\" class=\"button small\"></form>";

#}

print "<br>";

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

print "<br>";
print "<b>Farm Virtual IP and Virtual port(s) </b><font size=\"1\">*the service will be restarted</font><b>.</b>";
$vip   = &getFarmVip( "vip",  $farmname );
$vport = &getFarmVip( "vipp", $farmname );
print "<br>";
@listinterfaces = &listallips();
$clrip          = &clrip();
my $disabled = "";
if ( $farmprotocol eq "all" || $farmprotocol eq "sip" )
{
	$disabled = "disabled";
}
print "<form method=\"get\" action=\"index.cgi\">";
print "<input type=\"hidden\" name=\"id\" value=\"$id\">";
print "<input type=\"hidden\" name=\"action\" value=\"editfarm-changevipvipp\">";
print "<input type=\"hidden\" name=\"farmname\" value=\"$farmname\">";
print "<select name=\"vip\">";
foreach $ip ( @listinterfaces )
{

	if ( $ip !~ $clrip )
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
print " <input type=\"text\" value=\"$vport\" size=\"20\" name=\"vipp\" $disabled>";
print "&nbsp;<img src=\"img/icons/small/help.png\" title=\"Specify a port, several ports between `,', ports range between `:', or all ports with `*'. Also a combination of them should work.\"</img>&nbsp;";
print "<input type=\"submit\" value=\"Modify\" name=\"buttom\" class=\"button small\"></form>";

#print "</div><div style=\"align:right; margin-left: 50%; \">";

#print "</div>";
#print "</td></tr></table>";

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
print "		<td>Weight</td>";
print "		<td>Priority</td>";
print "		<td>Actions</td>";
print "    </tr>";
print "    </thead>";
print "	   <tbody>";

$id_serverchange = $id_server;
my $sindex = 0;

#my @laifaces = &listActiveInterfaces();
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
		if ( @l_serv[2] eq "" || $farmprotocol eq "all" || $farmprotocol eq "sip" )
		{
			print "<td><input type=\"text\" size=\"12\"  name=\"port_server\" value=\"$vport\" $disabled></td>";
		}
		else
		{
			print "<td><input type=\"text\" size=\"12\"  name=\"port_server\" value=\"@l_serv[2]\" $disabled> </td>";
		}

		#Weight
		print "<td><input type=\"text\" size=\"4\"  name=\"weight_server\" value=\"@l_serv[4]\"> </td>";

		#Priority
		print "<td><input type=\"text\" size=\"4\"  name=\"priority_server\" value=\"@l_serv[5]\"> </td>";
		&createmenuserversfarm( "edit", $farmname, @l_serv[0] );
	}
	else
	{
		print "<form method=\"get\" action=\"index.cgi\#backendlist\">";
		print "<tr>";
		print "<td>@l_serv[0]</td>";
		print "<td>@l_serv[1]</td>";
		if ( @l_serv[2] eq "" || $farmprotocol eq "all" || $farmprotocol eq "sip" )
		{
			print "<td>$vport</td>";
		}
		else
		{
			print "<td>@l_serv[2]</td>";
		}
		print "<td>@l_serv[4]</td>";
		print "<td>@l_serv[5]</td>";
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

	# port only editable if the farm isnt multiport
	if ( @l_serv[2] eq "" || $farmprotocol eq "all" || $farmprotocol eq "sip" )
	{
		print "<td><input type=\"text\" size=\"12\"  name=\"port_server\" value=\"$vport\" $disabled></td>";
	}
	else
	{
		print "<td><input type=\"text\" size=\"12\"  name=\"port_server\" value=\"@l_serv[2]\" $disabled> </td>";
	}

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

print "</tbody>";
print "</table>";
print "</div>";
print "</div>";

print "<div id=\"page-header\"></div>";
print "<form method=\"get\" action=\"index.cgi\">";
print "<input type=\"hidden\" value=\"1-2\" name=\"id\">";
print "<input type=\"submit\" value=\"Cancel\" name=\"action\" class=\"button small\">";
print "</form>";
print "<div id=\"page-header\"></div>";
print "</form>";
print "</div>";

