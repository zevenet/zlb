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

### EDIT GSLB FARM ###

#Farm restart
if ( $action eq "editfarm-restart" )
{
	&runFarmStop( $farmname, "true" );
	my $status = &runFarmStart( $farmname, "true" );
	if ( $status == 0 )
	{
		&successmsg( "The $farmname farm has been restarted" );
	}
	else
	{
		&errormsg( "The $farmname farm hasn't been restarted" );
	}
}

#Change health check port for a service
if ( $action eq "editfarm-dpc" )
{
	if ( $service =~ /^$/ )
	{
		&errormsg( "Invalid service, please select a valid value" );
		$error = 1;
	}
	if ( $farmname =~ /^$/ )
	{
		&errormsg( "Invalid farm name, please select a valid value" );
		$error = 1;
	}
	if ( $string =~ /^$/ )
	{
		&errormsg( "Invalid default port health check, please select a valid value" );
		$error = 1;
	}
	if ( $error == 0 )
	{
		&setFarmVS( $farmname, $service, "dpc", $string );
		if ( $? eq 0 )
		{
			&successmsg( "The default port health check for the service $service has been successfully changed" );
			&setFarmRestart( $farmname );

			#&runFarmReload($farmname);
		}
		else
		{
			&errormsg( "The default port health check for the service $service has failed" );
		}
	}
}

if ( $action eq "editfarm-ns" )
{
	if ( $service =~ /^$/ )
	{
		&errormsg( "Invalid zone, please select a valid value" );
		$error = 1;
	}
	if ( $farmname =~ /^$/ )
	{
		&errormsg( "Invalid farm name, please select a valid value" );
		$error = 1;
	}
	if ( $string =~ /^$/ )
	{
		&errormsg( "Invalid name server, please select a valid value" );
		$error = 1;
	}
	if ( $error == 0 )
	{
		&setFarmVS( $farmname, $service, "ns", $string );
		if ( $? eq 0 )
		{
			&successmsg( "The name server for the zone $service has been successfully changed" );
			&runFarmReload( $farmname );
		}
		else
		{
			&errormsg( "The name server for the zone $service has failed" );
		}
	}
}

#editfarm delete service
if ( $action eq "editfarm-deleteservice" )
{
	if ( $service_type =~ /^$/ )
	{
		&errormsg( "Invalid service type, please select a valid value" );
		$error = 1;
	}
	if ( $error == 0 )
	{
		if ( $service_type eq "zone" )
		{
			&setFarmGSLBDeleteZone( $farmname, $service );
			if ( $? eq 0 )
			{
				&successmsg( "Deleted zone $service in farm $farmname" );
				&runFarmReload( $farmname );
			}
		}
		else
		{
			if ( $service_type eq "service" )
			{
				&setFarmGSLBDeleteService( $farmname, $service );
				if ( $? eq 0 )
				{
					&successmsg( "Deleted service $service in farm $farmname" );
					&setFarmRestart( $farmname );

					#&runFarmReload($farmname);
				}
			}
		}
	}
}

#change Farm's name
if ( $action eq "editfarm-Name" )
{

	#Check if farmname has correct characters (letters, numbers and hyphens)
	my $farmnameok = &checkFarmnameOK( $newfarmname );

	#Check the farm's name change
	if ( "$newfarmname" eq "$farmname" )
	{
		&errormsg( "The new farm's name \"$newfarmname\" is the same as the old farm's name \"$farmname\". Nothing to do" );
	}
	elsif ( $farmnameok ne 0 )
	{
		&errormsg( "Farm name is not valid, only allowed numbers, letters and hyphens" );
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
	$action = "editfarm";
}

if ( $action eq "editfarm-changevipvipp" )
{
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

			#&runFarmReload($farmname);
			&successmsg( "Virtual IP and Virtual Port has been modified, the $farmname farm need be restarted" );
			&setFarmRestart( $farmname );
		}
		else
		{
			&errormsg( "It's not possible to change the $farmname farm virtual IP and port" );
		}
	}
}

#delete server
if ( $action eq "editfarm-deleteserver" )
{
	$error = 0;
	if ( $service =~ /^$/ )
	{
		&errormsg( "Invalid $service_type, please insert a valid value" );
		$error = 1;
	}
	if ( $id_server =~ /^$/ )
	{
		&errormsg( "Invalid id server, please insert a valid value" );
		$error = 1;
	}
	if ( $farmname =~ /^$/ )
	{
		&errormsg( "Invalid farmname, please insert a valid value" );
		$error = 1;
	}
	if ( $service_type eq "zone" )
	{
		if ( $error == 0 )
		{
			$status = &remFarmZoneResource( $id_server, $farmname, $service );
			if ( $status != -1 )
			{
				&runFarmReload( $farmname );
				&successmsg( "The resource with ID $id_server in the zone $service has been deleted" );
			}
			else
			{
				&errormsg( "It's not possible to delete the resource server with ID $id_server in the zone $service" );
			}
		}
		$service_type = "zone";
	}
	else
	{
		if ( $error == 0 )
		{
			$status = &remFarmServiceBackend( $id_server, $farmname, $service );
			if ( $status != -1 )
			{
				if ( $status == -2 )
				{
					&errormsg( "You need at least one bakcend in the service. It's not possible to delete the backend." );
				}
				else
				{

					#&runFarmReload($farmname);
					&successmsg( "The backend with ID $id_server in the service $service has been deleted" );
					&setFarmRestart( $farmname );
				}
			}
			else
			{
				&errormsg( "It's not possible to delete the backend with ID $id_server in the service $service" );
			}
		}
		$service_type = "service";
	}
}

#save server
if ( $action eq "editfarm-saveserver" )
{
	$error = 0;
	if ( $service_type eq "zone" )
	{
		if ( $service =~ /^$/ )
		{

			#			&errormsg("Invalid zone, please insert a valid value");
			$error = 1;
		}
		if ( $resource_server =~ /^$/ )
		{

			#			&errormsg("Invalid resource server, please insert a valid value");
			$error = 1;
		}
		if ( $rdata_server =~ /^$/ )
		{

			#			&errormsg("Invalid RData, please insert a valid value");
			$error = 1;
		}
		if ( $error == 0 )
		{
			if ( $type_server eq "A" && &ipisok( $rdata_server ) eq "false" )
			{
				&errormsg( "If you choose A type, RDATA must be a valid IP address, $resource_server not modified for the zone $service" );
			}
			else
			{
				$status = &setFarmZoneResource( $id_server, $resource_server, $ttl_server, $type_server, $rdata_server, $farmname, $service );
				if ( $status != -1 )
				{
					&runFarmReload( $farmname );
					&successmsg( "The resource name $resource_server for the zone $zone has been modified" );
					$action = "";
				}
				else
				{
					&errormsg( "It's not possible to modify the resource name $resource_server for the zone $zone" );
				}
			}
		}
	}
	else
	{
		if ( $service =~ /^$/ )
		{
			&errormsg( "Invalid service, please insert a valid value" );
			$error = 1;
		}
		if ( $error == 0 )
		{
			$status = &setFarmGSLBNewBackend( $farmname, $service, $lb, $id_server, $rip_server );
			if ( $status != -1 )
			{

				#&runFarmReload($farmname);
				&successmsg( "The backend $rip_server for the service $service has been modified" );
				&setFarmRestart( $farmname );
			}
			else
			{
				&errormsg( "It's not possible to modify the backend $rip_server for the service $service" );
			}
		}
	}
}

if ( $action eq "editfarm-addservice" )
{
	if ( $service_type eq "zone" )
	{
		if ( $zone !~ /.*\..*/ )
		{
			&errormsg( "Wrong zone name. The name has to be like zonename.com, zonename.net, etc. The zone $zone can't be created" );
		}
		else
		{
			my $result = &setFarmGSLBNewZone( $farmname, $zone );
			if ( $result eq "0" )
			{
				&setFarmRestart( $farmname );
				&successmsg( "Zone $zone has been added to the farm" );
			}
			else
			{
				&errormsg( "The zone $zone can't be created" );
			}
		}
	}
	else
	{
		if ( $service_type eq "service" )
		{
			if ( $service =~ /^$/ )
			{
				&errormsg( "Invalid service, please insert a valid value" );
				$error = 1;
			}
			if ( $farmname =~ /^$/ )
			{
				&errormsg( "Invalid farm name, please insert a valid value" );
				$error = 1;
			}
			if ( $lb =~ /^$/ )
			{
				&errormsg( "Invalid algorithm, please insert a valid value" );
				$error = 1;
			}
			if ( $error == 0 )
			{
				$status = &setFarmGSLBNewService( $farmname, $service, $lb );
				if ( $status != -1 )
				{

					#&runFarmReload($farmname);
					&successmsg( "The service $service has been successfully created" );
					&setFarmRestart( $farmname );
				}
				else
				{
					&errormsg( "It's not possible to create the service $service" );
				}
			}
		}
	}
}

#$service=$farmname;
#check if the farm need a restart
if ( -e "/tmp/$farmname.lock" )
{
	&tipmsg( "There're changes that need to be applied, stop and start farm to apply them!" );
}

#global info for a farm
print "<div class=\"container_12\">";
print "<div class=\"grid_12\">";

#paint a form to the global configuration
print "<div class=\"box-header\">Edit $farmname Farm global parameters</div>";
print "<div class=\"box stats\">";
print "<div class=\"row\">";

print "<div style=\"float:left;\">";

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

print "<b>Farm Virtual IP and Virtual port.</b>";
$vip   = &getFarmVip( "vip",  $farmname );
$vport = &getFarmVip( "vipp", $farmname );
print "<br>";
@listinterfaces = &listallips();

#print @listinterfaces;
$clrip = &clrip();
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
print " <input type=\"text\" value=\"$vport\" size=\"4\" name=\"vipp\">";
print "<input type=\"submit\" value=\"Modify\" name=\"buttom\" class=\"button small\"></form>";

#Add SERVICES
print "<br>";
print "<b>Add service and algorithm.</b> <font size=1>*manage services and backends</font>";
print "<form method=\"get\" action=\"index.cgi\">";
print "<input type=\"hidden\" name=\"id\" value=\"$id\">";
print "<input type=\"hidden\" name=\"action\" value=\"editfarm-addservice\">";
print "<input type=\"hidden\" name=\"farmname\" value=\"$farmname\">";
print "<input type=\"hidden\" name=\"service_type\" value=\"service\">";
print "<input type=\"text\" value=\"\" size=\"25\" name=\"service\">";
print " <select name=\"lb\"><option value=\"roundrobin\" selected=\"selected\">Round Robin: equal sharing</option><option value=\"prio\">Priority: connections always to the most prio available</option></select>";
print "<input type=\"submit\" value=\"Add\" name=\"buttom\" class=\"button small\"></form>";

#Add ZONES
print "<br>";
print "<b>Add zone.</b> <font size=1>*manage DNS zones</font>";
print "<form method=\"get\" action=\"index.cgi\">";
print "<input type=\"hidden\" name=\"id\" value=\"$id\">";
print "<input type=\"hidden\" name=\"action\" value=\"editfarm-addservice\">";
print "<input type=\"hidden\" name=\"farmname\" value=\"$farmname\">";
print "<input type=\"hidden\" name=\"service_type\" value=\"zone\">";
print "<input type=\"text\" value=\"\" size=\"25\" name=\"zone\">";
print "<input type=\"submit\" value=\"Add\" name=\"buttom\" class=\"button small\"></form>";

print "</div><div style=\"align:right; margin-left: 50%; \">";

print "</div>";
print "<div style=\"clear:both;\"></div>";

#Services
#$service=$farmname;
print "</div><br>";
print "</div>";

####end form for global parameters

# SERVICES
print "<a name=\"servicelist-$service\"></a>";
print "<div id=\"page-header\"></div>\n";

my $id_serverr = $id_server;

# Manage every service
my @services = &getFarmServices( $farmname );
foreach $srv ( @services )
{
	my @serv = split ( ".cfg", $srv );
	my $srv  = @serv[0];
	my $lb   = &getFarmVS( $farmname, $srv, "algorithm" );
	print "<div class=\"box-header\">";

	#print "<a href=index.cgi?id=1-2&action=editfarm&service_type=service&service=$srv&farmname=$farmname><img src=\"img/icons/small/bullet_toggle_plus.png \" title=\"Maximize service $srv\"></a>";
	print "<a href=index.cgi?id=1-2&action=editfarm-deleteservice&service_type=service&service=$srv&farmname=$farmname><img src=\"img/icons/small/cross_octagon.png \" title=\"Delete service $srv\" onclick=\"return confirm('Are you sure you want to delete the Service $srv?')\" ></a> &nbsp;";
	print " Service \"$srv\" with ";
	if ( $lb eq "roundrobin" )
	{
		print "Round Robin";
	}
	else
	{
		if ( $lb eq "prio" )
		{
			print "Priority";
		}
		else
		{
			print "Unknown";
		}
	}
	print " algorithm</div>";

	print "<div class=\"box-content\">";

	# Default port health check
	my $dpc = &getFarmVS( $farmname, $srv, "dpc" );
	print "<form method=\"get\" action=\"index.cgi\">";
	print "<b>Default TCP port health check.</b>  <font size=1>*empty value disabled</font> <br><input type=\"text\" size=\"20\"  name=\"string\" value=\"$dpc\">";
	print "<input type=\"hidden\" name=\"action\" value=\"editfarm-dpc\">";
	print "<input type=\"hidden\" name=\"farmname\" value=\"$farmname\">";
	print "<input type=\"hidden\" name=\"service\" value=\"$srv\">";
	print "<input type=\"hidden\" name=\"service_type\" value=\"service\">";
	print "<input type=\"hidden\" name=\"id\" value=\"$id\">";
	print "<input type=\"submit\" value=\"Modify\" name=\"buttom\" class=\"button small\">";
	print "</form>";
	print "</div>";

	# Maximize button
	#if ($service_type eq "service" && $service eq "$srv"){
	print "<div class=\"box table\"> <table cellpadding=0 >";
	print "<thead><tr><td>ID</td><td>IP Address</td><td>Actions</td></tr></thead><tbody>";
	my $backendsvs = &getFarmVS( $farmname, $srv, "backends" );
	my @be = split ( "\n", $backendsvs );
	foreach $subline ( @be )
	{
		$subline =~ s/^\s+//;
		if ( $subline =~ /^$/ )
		{
			next;
		}

		my @subbe = split ( " => ", $subline );

		if ( $id_serverr eq "@subbe[0]" && $service eq "$srv" && $action eq "editfarm-editserver" )
		{
			print "<form method=\"get\" action=\"index.cgi\#servicelist-$srv\">";
			print "<tr class=\"selected\">";

			#print "<td><input type=\"text\" size=\"20\"  name=\"id_server\" value=\"@subbe[0]\" disabled></td>";
			if ( $lb eq "prio" )
			{
				print "<td><select name=\"id_server\" disabled>";
				if ( @subbe[0] eq "primary" )
				{
					print "<option value=\"primary\" selected=\"selected\">primary</option>";
					print "<option value=\"secondary\">secondary</option>";
				}
				else
				{
					print "<option value=\"primary\" >primary</option>";
					print "<option value=\"secondary\" selected=\"selected\">secondary</option>";
				}
				print "</select></td>";
			}
			else
			{
				print "<td>@subbe[0]</td>";
			}

			print "<td><input type=\"text\" size=\"20\"  name=\"rip_server\" value=\"@subbe[1]\"></td>";
			print "<input type=\"hidden\" name=\"id\" value=\"$id\">";
			print "<input type=\"hidden\" name=\"farmname\" value=\"$farmname\">";
			print "<input type=\"hidden\" name=\"service\" value=\"$service\">";
			print "<input type=\"hidden\" name=\"lb\" value=\"$lb\">";
			print "<input type=\"hidden\" name=\"id_server\" value=\"$id_serverr\">";
			print "<input type=\"hidden\" name=\"service_type\" value=\"service\">";
			$sv = $srv;
			&createmenuserversfarm( "edit", $farmname, $id_serverr );
			print "</tr>";
			print "</form>";
		}
		else
		{
			print "<form method=\"get\" action=\"index.cgi\#servicelist-$srv\">";
			print "<tr><td>@subbe[0]</td><td>@subbe[1]</td>";
			$sv = $srv;
			&createmenuserversfarm( "normal", $farmname, @subbe[0] );
			print "</tr>";
			print "<input type=\"hidden\" name=\"id\" value=\"$id\">";
			print "<input type=\"hidden\" name=\"farmname\" value=\"$farmname\">";
			print "<input type=\"hidden\" name=\"service\" value=\"$srv\">";
			print "<input type=\"hidden\" name=\"lb\" value=\"$lb\">";
			print "<input type=\"hidden\" name=\"id_server\" value=\"@subbe[0]\">";
			print "<input type=\"hidden\" name=\"service_type\" value=\"service\">";
			print "</form>";
		}
	}

	# New backend form
	print "<a name=\"servicelist-$srv\"></a>\n\n";
	if ( $action eq "editfarm-addserver" && $service eq "$srv" )
	{
		my $id_srv = "";
		print "<form method=\"get\" action=\"index.cgi\#servicelist-$srv\">";
		print "<tr class=\"selected\">";
		if ( $lb eq "prio" )
		{
			print "<td><select name=\"id_server\" disabled>";
			if ( @be == 0 )
			{
				print "<option value=\"primary\" selected=\"selected\">primary</option>";
				print "<option value=\"secondary\">secondary</option>";
				$id_srv = "primary";
			}
			else
			{
				print "<option value=\"primary\" >primary</option>";
				print "<option value=\"secondary\" selected=\"selected\">secondary</option>";
				$id_srv = "secondary";
			}
			print "</select></td>";
		}
		else
		{
			print "<td>-</td>";
		}
		print "<td><input type=\"text\" size=\"20\" name=\"rip_server\" value=\"\"></td>";
		$sv = $srv;
		&createmenuserversfarm( "add", $farmname, @l_serv[0] );
		print "<input type=\"hidden\" name=\"id\" value=\"$id\">";
		print "<input type=\"hidden\" name=\"farmname\" value=\"$farmname\">";
		print "<input type=\"hidden\" name=\"service\" value=\"$service\">";
		print "<input type=\"hidden\" name=\"lb\" value=\"$lb\">";
		print "<input type=\"hidden\" name=\"id_server\" value=\"$id_srv\">";
		print "<input type=\"hidden\" name=\"service_type\" value=\"service\">";
		print "</form>";
		print "</tr>";
	}

	# add backend button
	if ( !( $lb eq "prio" && @be > 2 ) )
	{
		print "<tr><td colspan=\"2\"></td>";
		print "<form method=\"get\" action=\"index.cgi\#servicelist-$service\">";
		&createmenuserversfarm( "new", $farmname, "" );
		print "<input type=\"hidden\" name=\"id\" value=\"$id\">";
		print "<input type=\"hidden\" name=\"farmname\" value=\"$farmname\">";
		print "<input type=\"hidden\" name=\"service_type\" value=\"service\">";
		print "<input type=\"hidden\" name=\"service\" value=\"$srv\">";
		print "<input type=\"hidden\" name=\"lb\" value=\"$lb\">";

		#print "<input type=\"hidden\" name=\"action\" value=\"editfarm-addserver\">";
		print "</form>";
		print "</tr>";
	}
	print "</tbody></table>";
	print "</div>";

	#}
	print "<br>";
}

# ZONES
print "<a name=\"zonelist-$zone\"></a>";
print "<div id=\"page-header\"></div>\n";

my @zones   = &getFarmZones( $farmname );
my $first   = 0;
my $vserver = 0;
my $pos     = 0;
foreach $zone ( @zones )
{

	#if ($first == 0) {
	$pos++;
	$first = 1;
	print "<div class=\"box-header\">";

	#print "<a href=index.cgi?id=1-2&action=editfarm&service_type=zone&service=$zone&farmname=$farmname><img src=\"img/icons/small/bullet_toggle_plus.png \" title=\"Maximize zone $zone\"></a>";
	print "<a href=index.cgi?id=1-2&action=editfarm-deleteservice&service_type=zone&service=$zone&farmname=$farmname><img src=\"img/icons/small/cross_octagon.png \" title=\"Delete zone $zone\" onclick=\"return confirm('Are you sure you want to delete the Zone $zone?')\" ></a> &nbsp;";
	print " Zone \"$zone\"</div>";

	#Maximize button
	#if ($service_type eq "zone" && $service eq "$zone"){

	print "<div class=\"box-content\">";

	# Default name server
	my $ns = &getFarmVS( $farmname, $zone, "ns" );
	print "<form method=\"get\" action=\"index.cgi\">";
	print "<b>Default Name Server.</b>  <font size=1>*empty value disabled</font> <br><input type=\"text\" size=\"20\"  name=\"string\" value=\"$ns\">";
	print "<input type=\"hidden\" name=\"action\" value=\"editfarm-ns\">";
	print "<input type=\"hidden\" name=\"farmname\" value=\"$farmname\">";
	print "<input type=\"hidden\" name=\"service\" value=\"$zone\">";
	print "<input type=\"hidden\" name=\"id\" value=\"$id\">";
	print "<input type=\"hidden\" name=\"service_type\" value=\"zone\">";
	print "<input type=\"submit\" value=\"Modify\" name=\"buttom\" class=\"button small\">";
	print "</form>";
	print "</div>";

	print "<div class=\"box table\"> <table cellpadding=0 >";
	print "<thead ><tr><td>Resource Name</td><td>TTL</td><td>Type</td><td>RData</td><td>Actions</td></tr></thead><tbody>";
	my $backendsvs = &getFarmVS( $farmname, $zone, "resources" );
	my @be = split ( "\n", $backendsvs );
	foreach $subline ( @be )
	{
		if ( $subline =~ /^$/ )
		{
			next;
		}

		my @subbe  = split ( "\;", $subline );
		my @subbe1 = split ( "\t", @subbe[0] );
		my @subbe2 = split ( "\_", @subbe[1] );
		my $ztype  = @subbe1[1];
		my $la_resource = @subbe1[0];
		my $la_ttl      = @subbe1[1];

		if ( $resource_server ne "" ) { $la_resource = $resource_server; }
		if ( $ttl_server      ne "" ) { $la_ttl      = $ttl_server; }

		if ( $id_serverr eq "@subbe2[1]" && $service eq "$zone" && $action eq "editfarm-editserver" )
		{
			print "<form method=\"get\" action=\"index.cgi\#zonelist-$zone\">";
			print "<tr class=\"selected\">";
			print "<td><input type=\"text\" size=\"10\"  name=\"resource_server\" value=\"$la_resource\"> </td>";
			if ( @subbe1[1] ne "NS" && @subbe1[1] ne "A" && @subbe1[1] ne "CNAME" && @subbe1[1] ne "DYNA" && @subbe1[1] ne "DYNC" )
			{
				print "<td><input type=\"text\" size=\"10\" name=\"ttl_server\" value=\"$la_ttl\"> </td>";
				$ztype = @subbe1[2];
			}
			else
			{
				print "<td><input type=\"text\" size=\"10\" name=\"ttl_server\" value=\"\"></td>";
			}
			my $la_type = $ztype;
			if ( $type_server ne "" ) { $la_type = $type_server; }
			print "<td><select name=\"type_server\" onchange=\"chRType(this)\">";
			if ( $la_type eq "NS" )
			{
				print "<option value=\"NS\" selected=\"selected\">NS</option>";
			}
			else
			{
				print "<option value=\"NS\">NS</option>";
			}
			if ( $la_type eq "A" )
			{
				print "<option value=\"A\" selected=\"selected\">A</option>";
			}
			else
			{
				print "<option value=\"A\">A</option>";
			}
			if ( $la_type eq "CNAME" )
			{
				print "<option value=\"CNAME\" selected=\"selected\">CNAME</option>";
			}
			else
			{
				print "<option value=\"CNAME\">CNAME</option>";
			}
			if ( $la_type eq "DYNA" )
			{
				print "<option value=\"DYNA\" selected=\"selected\">DYNA</option>";
			}
			else
			{
				print "<option value=\"DYNA\">DYNA</option>";
			}

			#if ($la_type eq "DYNC"){
			#	print "<option value=\"DYNC\" selected=\"selected\">DYNC</option>";
			#} else {
			#	print "<option value=\"DYNC\">DYNC</option>";
			#}
			print "</select></td>";

			print "<td>";

			my $rdata = "";
			if ( @subbe1 == 3 )
			{
				$rdata = @subbe1[2];
			}
			elsif ( @subbe1 == 4 )
			{
				$rdata = @subbe1[3];
			}
			elsif ( @subbe1 == 5 )
			{
				$rdata = @subbe1[4];
			}
			chop ( $rdata );

			if ( $rdata_server ne "" ) { $rdata = $rdata_server; }
			if ( $la_type eq "DYNA" || $la_type eq "DYNC" )
			{
				print "<select name=\"rdata_server\">";
				foreach $sr ( @services )
				{
					my @srv = split ( ".cfg", $sr );
					my $srr = @srv[0];
					print "<option value=\"$srr\" ";
					if ( $rdata eq $srr ) { print " selected=\"selected\" "; }
					print ">$srr</option>";
				}
				print "</select>";
			}
			else
			{
				print "<input type=\"text\" size=\"10\" name=\"rdata_server\" value=\"$rdata\">";
			}
			print "</td>";
			$nserv = @subbe2[1];
			&createmenuserversfarm( "edit", $farmname, $nserv );
			print "<input type=\"hidden\" name=\"id\" value=\"$id\">";
			print "<input type=\"hidden\" name=\"farmname\" value=\"$farmname\">";
			print "<input type=\"hidden\" name=\"id_server\" value=\"$subbe2[1]\">";
			print "<input type=\"hidden\" name=\"service\" value=\"$zone\">";
			print "<input type=\"hidden\" name=\"service_type\" value=\"zone\">";
			print "</tr>";
			print "</form>";
		}
		else
		{
			print "<form method=\"get\" action=\"index.cgi\#zonelist-$zone\">";
			print "<tr><td>@subbe1[0]</td>";
			if ( @subbe1[1] ne "NS" && @subbe1[1] ne "A" && @subbe1[1] ne "CNAME" && @subbe1[1] ne "DYNA" && @subbe1[1] ne "DYNC" )
			{
				print "<td>@subbe1[1]</td>";
				$ztype = @subbe1[2];
			}
			else
			{
				print "<td></td>";
			}
			print "<td>$ztype</td>";
			if ( @subbe1 == 3 )
			{
				print "<td>@subbe1[2]</td>";
			}
			elsif ( @subbe1 == 4 )
			{
				print "<td>@subbe1[3]</td>";
			}
			elsif ( @subbe1 == 5 )
			{
				print "<td>@subbe1[4]</td>";
			}

			$nserv = @subbe2[1];
			$sv    = $zone;
			&createmenuserversfarm( "normal", $farmname, $nserv );
			print "</tr>";
			print "<input type=\"hidden\" name=\"id\" value=\"$id\">";
			print "<input type=\"hidden\" name=\"farmname\" value=\"$farmname\">";
			print "<input type=\"hidden\" name=\"id_server\" value=\"@subbe2[1]\">";
			print "<input type=\"hidden\" name=\"service\" value=\"$zone\">";
			print "<input type=\"hidden\" name=\"service_type\" value=\"zone\">";
			print "</form>";
		}
	}

	# New backend form
	print "<a name=\"zonelist-$zone\"></a>\n\n";
	if ( ( $action =~ /editfarm-addserver/ || $action =~ /editfarm-saveserver/ ) && $service eq "$zone" )
	{
		print "<form method=\"get\" action=\"index.cgi\#zonelist-$zone\">";
		print "<tr class=\"selected\">";
		print "<td><input type=\"text\" size=\"10\" name=\"resource_server\" value=\"$resource_server\"> </td>";
		print "<td><input type=\"text\" size=\"10\" name=\"ttl_server\" value=\"$ttl_server\"> </td>";
		print "<td><select name=\"type_server\" onchange=\"this.form.submit()\">";
		if ( $type_server eq "NS" )
		{
			print "<option value=\"NS\" selected=\"selected\">NS</option>";
		}
		else
		{
			print "<option value=\"NS\">NS</option>";
		}
		if ( $type_server eq "A" )
		{
			print "<option value=\"A\" selected=\"selected\">A</option>";
		}
		else
		{
			print "<option value=\"A\">A</option>";
		}
		if ( $type_server eq "CNAME" )
		{
			print "<option value=\"CNAME\" selected=\"selected\">CNAME</option>";
		}
		else
		{
			print "<option value=\"CNAME\">CNAME</option>";
		}
		if ( $type_server eq "DYNA" )
		{
			print "<option value=\"DYNA\" selected=\"selected\">DYNA</option>";
		}
		else
		{
			print "<option value=\"DYNA\">DYNA</option>";
		}

		#if ($type_server eq "DYNC"){
		#	print "<option value=\"DYNC\" selected=\"selected\">DYNC</option>";
		#} else {
		#	print "<option value=\"DYNC\">DYNC</option>";
		#}
		print "</select></td>";

		print "<td>";
		if ( $type_server eq "DYNA" || $type_server eq "DYNC" )
		{
			print "<select name=\"rdata_server\">";
			foreach $sr ( @services )
			{
				my @srv = split ( ".cfg", $sr );
				my $srr = @srv[0];
				print "<option value=\"$srr\">$srr</option>";
			}
			print "</select>";
		}
		else
		{
			print "<input type=\"text\" size=\"10\" name=\"rdata_server\" value=\"$rdata_server\">";
		}
		print "</td>";
		&createmenuserversfarm( "add", $farmname, @l_serv[0] );
		print "<input type=\"hidden\" name=\"id\" value=\"$id\">";
		print "<input type=\"hidden\" name=\"farmname\" value=\"$farmname\">";
		print "<input type=\"hidden\" name=\"service\" value=\"$zone\">";
		print "<input type=\"hidden\" name=\"service_type\" value=\"zone\">";
		print "</form>";
		print "</tr>";
	}

	# add backend button
	print "<tr><td colspan=\"4\"></td>";
	print "<form method=\"get\" action=\"index.cgi\#zonelist-$zone\">";
	&createmenuserversfarm( "new", $farmname, @l_serv[0] );
	print "<input type=\"hidden\" name=\"id\" value=\"$id\">";
	print "<input type=\"hidden\" name=\"id_server\" value=\"@l_serv[0]\">";
	print "<input type=\"hidden\" name=\"farmname\" value=\"$farmname\">";
	print "<input type=\"hidden\" name=\"service_type\" value=\"zone\">";
	print "<input type=\"hidden\" name=\"service\" value=\"$zone\">";
	print "</form>";
	print "</tr>";
	print "</tbody></table>";
	print "</div>";

	#}
	print "<div style=\"clear:both;\"></div>";
}

#end table

#################################################################
#BACKENDS:
##################################################################

print "<br></div>";

print "<div id=\"page-header\"></div>";
print "<form method=\"get\" action=\"index.cgi\">";
print "<input type=\"hidden\" value=\"1-2\" name=\"id\">";
print "<input type=\"submit\" value=\"Cancel\" name=\"action\" class=\"button small\">";
print "</form>";
print "<div id=\"page-header\"></div>";
print "</div>";

print "
 <script type=\"text/javascript\">
  function chRType(oSelect)
  {
    oSelect.form.action.value=\"editfarm-editserver\";
    oSelect.form.submit();
  }
  </script>
";

