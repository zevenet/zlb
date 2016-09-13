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

### EDIT HTTP/HTTPS FARM ###
#maintenance mode for servers

$actualservice = $service;

if ( $action eq "editfarm-farmlisten" )
{
	&setFarmListen( $farmname, $farmlisten );
	&successmsg( "HTTP listener modified" );
	&setFarmRestart( $farmname );
}

if ( $action eq "editfarm-rewritelocation" )
{
	&setFarmRewriteL( $farmname, "$rewritelocation" );
	&successmsg( "Rewrite Location modified for farm $farmname" );
	&setFarmRestart( $farmname );
}

if ( $action eq "editfarm-httpsbackends" )
{
	if ( $httpsbackend eq "true" )
	{
		&setFarmVS( $farmname, $service, "httpsbackend", $httpsbackend );
		&successmsg( "HTTPS mode enabled for backends in service $service" );
		&setFarmRestart( $farmname );
	}
	else
	{
		&setFarmVS( $farmname, $service, "httpsbackend", "" );
		&successmsg( "HTTPS mode disabled for backends in service $service" );
		&setFarmRestart( $farmname );
	}
}

if ( $action eq "editfarm-redirect" )
{
	if ( $string =~ /^http\:\/\//i || $string =~ /^https:\/\//i || $string =~ /^$/ )
	{
		&setFarmVS( $farmname, $service, "redirect", $string );
		&setFarmRestart( $farmname );
	}
	else
	{
		&errormsg( "Redirect doesn't begin with http or https" );
	}
}

if ( $action eq "editfarm-vs" )
{
	&setFarmVS( $farmname, $service, "vs", $string );
	&setFarmRestart( $farmname );
}

if ( $action eq "editfarm-urlp" )
{
	&setFarmVS( $farmname, $service, "urlp", $string );
	&setFarmRestart( $farmname );
}

if ( $action eq "editfarm-maintenance" )
{
	if ( &getFarmStatus( $farmname ) eq "up")
	{
		&setFarmBackendMaintenance( $farmname, $id_server, $service );
		if ( $? eq 0 )
		{
			&successmsg( "Enabled maintenance mode for backend $id_server in service $service" );
		}
	}
}

#disable maintenance mode for servers
if ( $action eq "editfarm-nomaintenance" )
{
	&setFarmBackendNoMaintenance( $farmname, $id_server, $service );
	if ( $? eq 0 )
	{
		&successmsg( "Disabled maintenance mode for backend" );
	}
}

#editfarm delete service
if ( $action eq "editfarm-deleteservice" )
{
	&deleteFarmService( $farmname, $service );
	if ( $? eq 0 )
	{
		&successmsg( "Deleted service $service in farm $farmname" );
		&setFarmRestart( $farmname );
	}
}

#manage ciphers
if ( $action eq "editfarm-httpsciphers" )
{
	if ( $ciphers eq "cipherglobal" )
	{
		&setFarmCiphers( $farmname, $ciphers );
		&successmsg( "Ciphers changed for farm $farmname" );
		&setFarmRestart( $farmname );
	}
	if ( $ciphers eq "cipherpci" )
	{
		&setFarmCiphers( $farmname, $ciphers );
		&successmsg( "Ciphers changed for farm $farmname" );
		&setFarmRestart( $farmname );
	}
	if ( $ciphers eq "ciphercustom" )
	{
		&setFarmCiphers( $farmname, $ciphers );
	}
}

if ( $action eq "editfarm-httpscipherscustom" )
{
	$cipherc =~ s/\ //g;
	if ( $cipherc eq "" )
	{
		&errormsg( "Ciphers can't be blank" );
	}
	else
	{
		&setFarmCiphers( $farmname, "", $cipherc );
		&successmsg( "Ciphers changed for farm $farmname" );
		&setFarmRestart( $farmname );
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
			&setFarmRestart( $farmname );
			&successmsg( "Virtual IP and Virtual Port has been modified, the $farmname farm need be restarted" );
		}
		else
		{
			&errormsg( "It's not possible to change the $farmname farm virtual IP and port" );
		}
	}
}

if ( $action eq "editfarm-httpscert" )
{
	$status = &setFarmCertificate( $certname, $farmname );
	if ( $status == 0 )
	{
		&setFarmRestart( $farmname );
		&successmsg( "Certificate is changed to $certname on farm $farmname, you need restart the farm to apply" );
	}
	else
	{
		&errormsg( "It's not possible to change the certificate for the $farmname farm" );
	}
}

if ( $action eq "editfarm-restart" )
{
	&runFarmStop( $farmname, "true" );
	my $status = &runFarmStart( $farmname, "true" );
	if ( $status == 0 )
	{
		&successmsg( "The $farmname farm has been restarted" );
		&setFarmHttpBackendStatus( $farmname );
	}
	else
	{
		&errormsg( "The $farmname farm hasn't been restarted" );
	}
}

if ( $action eq "editfarm-Err414" )
{
	$status = &setFarmErr( $farmname, $err414, "414" );
	if ( $status == 0 )
	{
		&setFarmRestart( $farmname );
		&successmsg( "The Err414 message for the $farmname farm has been modified" );
	}
	else
	{
		&errormsg( "The Err414 message for the $farmname farm hasn't been modified" );
	}
}

#err500
if ( $action eq "editfarm-Err500" )
{
	$status = &setFarmErr( $farmname, $err500, "500" );
	if ( $status == 0 )
	{
		&setFarmRestart( $farmname );
		&successmsg( "The Err500 message for the $farmname farm has been modified" );
	}
	else
	{
		&errormsg( "The Err500 message for the $farmname farm hasn't been modified" );
	}
}

#err501
if ( $action eq "editfarm-Err501" )
{
	$status = &setFarmErr( $farmname, $err501, "501" );
	if ( $status == 0 )
	{
		&setFarmRestart( $farmname );
		&successmsg( "The Err501 message for the $farmname farm has been modified" );
	}
	else
	{
		&errormsg( "The Err501 message for the $farmname farm hasn't been modified" );
	}
}

#err503
if ( $action eq "editfarm-Err503" )
{
	$status = &setFarmErr( $farmname, $err503, "503" );
	if ( $status == 0 )
	{
		&setFarmRestart( $farmname );
		&successmsg( "The Err503 message for the $farmname farm has been modified" );
	}
	else
	{
		&errormsg( "The Err503 message for the $farmname farm hasn't been modified" );
	}
}

#delete server
if ( $action eq "editfarm-deleteserver" )
{
	$status = &runFarmServerDelete( $id_server, $farmname, $service );
	if ( $status != -1 )
	{
		&setFarmRestart( $farmname );
		&successmsg( "The real server with ID $id_server in the service $service of the farm $farmname has been deleted" );
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
	if ( &ipisok( $rip_server ) eq "false" )
	{
		&errormsg( "Invalid real server IP value, please insert a valid value" );
		$error = 1;
	}
	if ( $priority_server && ( $priority_server > 9 || $priority_server < 1 ) )
	{
		# For HTTP and HTTPS farms the priority field its the weight
		&errormsg( "Invalid weight value for a real server, it must be 1-9" );
		$error = 1;
	}
	if ( $rip_server =~ /^$/ || $port_server =~ /^$/ )
	{
		&errormsg( "Invalid IP address and port for a real server, it can't be blank" );
		$error = 1;
	}
	if ( $error == 0 )
	{
		$status = &setFarmServer( $id_server, $rip_server, $port_server, $max_server, $weight_server, $priority_server, $timeout_server, $farmname, $service );
		if ( $status != -1 )
		{
			&setFarmRestart( $farmname );
			&successmsg( "The real server with ID $id_server and IP $rip_server of the $farmname farm has been modified" );
		}
		else
		{
			&errormsg( "It's not possible to modify the real server with ID $id_server and IP $rip_server of the $farmname farm" );
		}
	}
}

#actions over farm
if ( $action eq "editfarm-ConnTO-http" )
{
	$error = 0;
	if ( &isnumber( $param ) eq "false" )
	{
		&errormsg( "Invalid timeout $param value, it must be a numeric value" );
		$error = 1;
	}
	if ( $error == 0 )
	{
		$status = &setFarmConnTO( $param, $farmname );
		if ( $status != -1 )
		{
			&setFarmRestart( $farmname );
			&successmsg( "The timeout for $farmname farm has been modified" );
		}
		else
		{
			&errormsg( "It's not possible to change the $farmname farm timeout value" );
		}
	}
}

if ( $action eq "editfarm-Timeout-http" )
{
	$error = 0;
	if ( &isnumber( $param ) eq "false" )
	{
		&errormsg( "Invalid timeout $param value, it must be a numeric value" );
		$error = 1;
	}
	if ( $error == 0 )
	{
		$status = &setFarmTimeout( $param, $farmname );
		if ( $status != -1 )
		{
			&setFarmRestart( $farmname );
			&successmsg( "The timeout for $farmname farm has been modified" );
		}
		else
		{
			&errormsg( "It's not possible to change the $farmname farm timeout value" );
		}
	}
}

if ( $action eq "editfarm-Alive" )
{
	$error = 0;
	if ( &isnumber( $param ) eq "false" )
	{
		&errormsg( "Invalid alive time $param value, it must be a numeric value" );
		$error = 1;
	}
	if ( $error == 0 )
	{
		$status = &setFarmBlacklistTime( $param, $farmname );
		if ( $status != -1 )
		{
			&setFarmRestart( $farmname );
			&successmsg( "The alive time for $farmname farm has been modified" );
		}
		else
		{
			&errormsg( "It's not possible to change the $farmname farm alive time value" );
		}
	}
}

if ( $action eq "editfarm-httpverb" )
{
	$status = &setFarmHttpVerb( $httpverb, $farmname );
	if ( $status == 0 )
	{
		&setFarmRestart( $farmname );
		&successmsg( "The HTTP verb for $farmname farm has been modified" );
	}
	else
	{
		&errormsg( "It's not possible to change the $farmname farm HTTP verb" );
	}
}

if ( $action eq "editfarm-Client" )
{
	$error = 0;
	if ( &isnumber( $param ) eq "false" )
	{
		&errormsg( "Invalid client timeout $param value, it must be a numeric value" );
		$error = 1;
	}
	if ( $error == 0 )
	{
		$status = &setFarmClientTimeout( $param, $farmname );
		if ( $status == 0 )
		{
			&setFarmRestart( $farmname );
			&successmsg( "The client timeout for $farmname farm has been modified" );
		}
		else
		{
			&errormsg( "It's not possible to change the $farmname farm client timeout" );
		}
	}
}

#TTL
if ( $action eq "editfarm-TTL" )
{
	$error = 0;
	if ( &isnumber( $string ) eq "false" || $string eq "" )
	{
		&errormsg( "Invalid client timeout $param value, it must be a numeric value" );
		$error = 1;
	}
	if ( $error == 0 )
	{

		#$status = &setFarmMaxClientTime(0,$param,$farmname,$service);
		$status = &setFarmVS( $farmname, $service, "ttl", "$string" );
		if ( $status == 0 )
		{
			&setFarmRestart( $farmname );
			&successmsg( "The sessions TTL for $farmname farm has been modified" );
		}
		else
		{
			&errormsg( "It's not possible to change the $farmname farm sessions TTL" );
		}
	}
}

#session ID
if ( $action eq "editfarm-sessionid" )
{
	chomp ( $string );
	$string =~ s/ //eg;
	$error = 0;
	if ( $string eq "" )
	{
		&errormsg( "Invalid session id $string value" );
		$error = 1;
	}
	if ( $error == 0 )
	{
		#$status = &setFarmSessionId($param,$farmname,$service);
		$status = &setFarmVS( $farmname, $service, "sessionid", "$string" );
		if ( $status == 0 )
		{
			&setFarmRestart( $farmname );
			&successmsg( "The session id for $farmname farm has been modified" );
		}
		else
		{
			&errormsg( "It's not possible to change the $farmname farm session id" );
		}
	}
}

#session type
if ( $action eq "editfarm-typesession" )
{
	#$status = &setFarmSessionType($session,$farmname,$service);
	$status = &setFarmVS( $farmname, $service, "session", "$session" );
	if ( $status == 0 )
	{
		&setFarmRestart( $farmname );
		&successmsg( "The session type for $farmname farm has been modified" );
	}
	else
	{
		&errormsg( "It's not possible to change the $farmname farm session type" );
	}
}

if ( $action eq "editfarm-addservice" )
{
	my $result = &setFarmHTTPNewService( $farmname, $service );
	if ( $result eq "0" )
	{
		&setFarmRestart( $farmname );
		&successmsg( "Service name $service has been added to the farm" );
	}
	if ( $result eq "2" )
	{
		&errormsg( "New service can't be empty" );
	}
	if ( $result eq "1" )
	{
		&errormsg( "Service named $service exists" );
	}
	if ( $result eq "3" )
	{
		&errormsg( "Service name is not valid, only allowed numbers, letters and hyphens." );
	}
}

#farm guardian
#change farmguardian values
if ( $action eq "editfarm-farmguardian" )
{
	$fguardianconf = &getFarmGuardianFile( $fname, $service );

	if ( &isnumber( $timetocheck ) eq "false" )
	{
		&errormsg( "Invalid period time value $timetocheck, it must be numeric" );
	}
	else
	{
		$status = -1;
		$usefarmguardian =~ s/\n//g;
		&runFarmGuardianStop( $farmname, $service );
		&logfile( "creating $farmname farmguardian configuration file in  $fguardianconf" );
		$check_script =~ s/\"/\'/g;
		$status = &runFarmGuardianCreate( $farmname, $timetocheck, $check_script, $usefarmguardian, $farmguardianlog, $service );
		if ( $status != -1 )
		{
			&successmsg( "The FarmGuardian service for the $farmname farm has been modified" );
			if ( $usefarmguardian eq "true" )
			{
				$status = &runFarmGuardianStart( $farmname, $service );
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

$service = $farmname;

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

#Backend connection timeout.
print "<b>Backend connection timeout secs.<br>";
$connto = &getFarmConnTO( $farmname );
print "<form method=\"get\" action=\"index.cgi\">";
print "<input type=\"hidden\" name=\"action\" value=\"editfarm-ConnTO-http\">";
print "<input type=\"text\" value=\"$connto\" size=\"4\" name=\"param\">";
print "<input type=\"hidden\" name=\"id\" value=\"$id\">";
print "<input type=\"hidden\" name=\"farmname\" value=\"$farmname\">";
print "<input type=\"submit\" value=\"Modify\" name=\"buttom\" class=\"button small\"></form>";
print "<br>";

print "<b>Backend response timeout secs.<br>";
$timeout = &getFarmTimeout( $farmname );
print "<form method=\"get\" action=\"index.cgi\">";
print "<input type=\"hidden\" name=\"action\" value=\"editfarm-Timeout-http\">";
print "<input type=\"text\" value=\"$timeout\" size=\"4\" name=\"param\">";
print "<input type=\"hidden\" name=\"id\" value=\"$id\">";
print "<input type=\"hidden\" name=\"farmname\" value=\"$farmname\">";
print "<input type=\"submit\" value=\"Modify\" name=\"buttom\" class=\"button small\"></form>";
print "<br>";

print "<b>Frequency to check resurrected backends secs.</b>";
$alive = &getFarmBlacklistTime( $farmname );
print "<form method=\"get\" action=\"index.cgi\">";
print "<input type=\"hidden\" name=\"action\" value=\"editfarm-Alive\">";
print "<input type=\"text\" value=\"$alive\" size=\"4\" name=\"param\">";
print "<input type=\"hidden\" name=\"id\" value=\"$id\">";
print "<input type=\"hidden\" name=\"farmname\" value=\"$farmname\">";
print "<input type=\"submit\" value=\"Modify\" name=\"buttom\" class=\"button small\"></form>";
print "<br>";

#Timeout for client
print "<b>Client request timeout secs.</b>";
$client = &getFarmClientTimeout( $farmname );
print "<form method=\"get\" action=\"index.cgi\">";
print "<input type=\"hidden\" name=\"action\" value=\"editfarm-Client\">";
print "<input type=\"text\" value=\"$client\" size=\"4\" name=\"param\">";
print "<input type=\"hidden\" name=\"id\" value=\"$id\">";
print "<input type=\"hidden\" name=\"farmname\" value=\"$farmname\">";
print "<input type=\"submit\" value=\"Modify\" name=\"buttom\" class=\"button small\"></form>";

print "<br>";

#RewriteLocation
$type0 = "disabled";
$type1 = "enabled";
$type2 = "enabled and compare backends";
print "<b>Rewrite Location headers.</b>";
print "<br>";
$rewritelocation = &getFarmRewriteL( $fname );
print "<form method=\"get\" action=\"index.cgi\">";
print "<input type=\"hidden\" name=\"action\" value=\"editfarm-rewritelocation\">";
print "<input type=\"hidden\" name=\"id\" value=\"$id\">";
print "<input type=\"hidden\" name=\"farmname\" value=\"$farmname\">";
print "<select  name=\"rewritelocation\">";

if ( $rewritelocation == 0 )
{
	print "<option value=\"0\" selected=\"selected\">$type0</option>";
}
else
{
	print "<option value=\"0\">$type0</option>";
}
if ( $rewritelocation == 1 )
{
	print "<option value=\"1\" selected=\"selected\">$type1</option>";
}
else
{
	print "<option value=\"1\">$type1</option>";
}
if ( $rewritelocation == 2 )
{
	print "<option value=\"2\" selected=\"selected\">$type2</option>";
}
else
{
	print "<option value=\"2\">$type2</option>";
}
print "</select>";
print "<input type=\"submit\" value=\"Modify\" name=\"buttom\" class=\"button small\"></form>";

#acepted verbs
#
print "<br>";
$type0 = "standard HTTP request";
$type1 = "+ extended HTTP request";
$type2 = "+ standard WebDAV verbs";
$type3 = "+ MS extensions WebDAV verbs";
$type4 = "+ MS RPC extensions verbs";
print "<b>HTTP verbs accepted.</b>";
print "<br>";
$httpverb = &getFarmHttpVerb( $farmname );
print "<form method=\"get\" action=\"index.cgi\">";
print "<input type=\"hidden\" name=\"action\" value=\"editfarm-httpverb\">";
print "<input type=\"hidden\" name=\"id\" value=\"$id\">";
print "<input type=\"hidden\" name=\"farmname\" value=\"$farmname\">";
print "<select  name=\"httpverb\">";

if ( $httpverb == 0 )
{
	print "<option value=\"0\" selected=\"selected\">$type0</option>";
}
else
{
	print "<option value=\"0\">$type0</option>";
}

if ( $httpverb == 1 )
{
	print "<option value=\"1\" selected=\"selected\">$type1</option>";
}
else
{
	print "<option value=\"1\">$type1</option>";
}

if ( $httpverb == 2 )
{
	print "<option value=\"2\" selected=\"selected\">$type2</option>";
}
else
{
	print "<option value=\"2\">$type2</option>";
}

if ( $httpverb == 3 )
{
	print "<option value=\"3\" selected=\"selected\">$type3</option>";
}
else
{
	print "<option value=\"3\">$type3</option>";
}

if ( $httpverb == 4 )
{
	print "<option value=\"4\" selected=\"selected\">$type4</option>";
}
else
{
	print "<option value=\"4\">$type4</option>";
}
print "</select>";
print "<input type=\"submit\" value=\"Modify\" name=\"buttom\" class=\"button small\"></form>";
print "<br>";

$type = &getFarmType( $farmname );

#farm listener HTTP or HTTPS
print "<b>Farm listener.</b>";
print "<form method=\"get\" action=\"index.cgi\">";
print "<input type=\"hidden\" name=\"action\" value=\"editfarm-farmlisten\">";
print "<input type=\"hidden\" name=\"id\" value=\"$id\">";
print "<input type=\"hidden\" name=\"farmname\" value=\"$farmname\">";
print "<select  name=\"farmlisten\">";
if ( $type eq "http" )
{
	print "<option value=\"http\" selected=\"selected\">HTTP</option>";
}
else
{
	print "<option value=\"http\">HTTP</option>";
}

if ( $type eq "https" )
{
	print "<option value=\"https\" selected=\"selected\">HTTPS</option>";
}
else
{
	print "<option value=\"https\">HTTPS</option>";
}

print "</select>";
print "<input type=\"submit\" value=\"Modify\" name=\"buttom\" class=\"button small\"></form>";

# HTTPS FARMS
$moreliness      = "false";
$morelinescipher = "false";
$type            = &getFarmType( $farmname );
if ( $type eq "https" )
{
	print "<br>";
	print "<b>HTTPS certificate</b>.<font size=1>*Certificate with pem format is needed</font>";
	print "<br>";
	print "<form method=\"get\" action=\"\">";
	print "<input type=\"hidden\" name=\"action\" value=\"editfarm-httpscert\">";
	print "<input type=\"hidden\" name=\"id\" value=\"$id\">";
	print "<input type=\"hidden\" name=\"farmname\" value=\"$farmname\">";
	$certname = &getFarmCertificate( $farmname );
	print "<select  name=\"certname\">";
	opendir ( DIR, $configdir );
	@files = grep ( /.*\.pem$/, readdir ( DIR ) );
	closedir ( DIR );

	foreach $filecert ( @files )
	{
		if ( $certname eq $filecert )
		{
			print "<option value=\"$filecert\" selected=\"selected\">$filecert</option>";
		}
		else
		{
			print "<option value=\"$filecert\">$filecert</option>";
		}
	}
	print "</select>";
	print "<input type=\"submit\" value=\"Modify\" name=\"buttom\" class=\"button small\"></form>";

	$moreliness = "true";

	print "<br>";
	$cipher = &getFarmCipher( $farmname );
	print "Ciphers";
	chomp ( $cipher );
	print "<form method=\"get\" action=\"\">";
	print "<input type=\"hidden\" name=\"action\" value=\"editfarm-httpsciphers\">";
	print "<input type=\"hidden\" name=\"id\" value=\"$id\">";
	print "<input type=\"hidden\" name=\"farmname\" value=\"$farmname\">";
	print "<select name=\"ciphers\">\n";

	if ( $cipher eq "cipherglobal" )
	{
		print "<option value=\"cipherglobal\" selected=\"selected\">All</option>\n";
		print "<option value=\"ciphercustom\">Custom security</option>\n";
	}
	else
	{
		print "<option value=\"cipherglobal\">All</option>\n";
		print "<option value=\"ciphercustom\" selected=\"selected\">Custom security</option>\n";
		$morelinescipher = "true";
	}

	print "</select>";
	print "<input type=\"submit\" value=\"Modify\" name=\"buttom\" class=\"button small\"></form>";
	print "<br>";
	if ( $cipher ne "cipherglobal" )
	{
		print "Customize your ciphers.";
		print "<form method=\"get\" action=\"\">";
		print "<input type=\"hidden\" name=\"action\" value=\"editfarm-httpscipherscustom\">";
		print "<input type=\"hidden\" name=\"id\" value=\"$id\">";
		print "<input type=\"hidden\" name=\"farmname\" value=\"$farmname\">";
		print " <input type=\"text\" value=\"$cipher\" size=\"50\" name=\"cipherc\">";

		print "<input type=\"submit\" value=\"Modify\" name=\"buttom\" class=\"button small\"></form>";
	}
}

#END HTTPS FARM:

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

#Add Services
print "<br>";
print "Add service.  <font size=1>*manage virtual host, url, redirect, persistence and backends</font>";
print "<form method=\"get\" action=\"index.cgi\">";
print "<input type=\"hidden\" name=\"id\" value=\"$id\">";
print "<input type=\"hidden\" name=\"action\" value=\"editfarm-addservice\">";
print "<input type=\"hidden\" name=\"farmname\" value=\"$farmname\">";
print "<input type=\"text\" value=\"\" size=\"25\" name=\"service\">";
print "<input type=\"submit\" value=\"Add\" name=\"buttom\" class=\"button small\"></form>";
print "</form>";
print "</div><div style=\"align:right; margin-left: 50%; \">";

#Error messages
#Err414
print "<b>Personalized message Error 414 \"Request URI too long\", HTML tags accepted.</b>";
@err414 = &getFarmErr( $farmname, "414" );
print "<form method=\"post\" action=\"index.cgi\">";
print "<input type=\"hidden\" name=\"actionpost\" value=\"editfarm-Err414\">";

#print "<input type=\"textarea\" value=\"$err414\" size=\"4\" name=\"param\">";
print "<textarea name=\"err414\" cols=\"40\" rows=\"2\">";
foreach $line ( @err414 )
{
	print "$line";
}
print "</textarea>";
print "<input type=\"hidden\" name=\"id\" value=\"$id\">";
print "<input type=\"hidden\" name=\"farmname\" value=\"$farmname\">";
print "<input type=\"submit\" value=\"Modify\" name=\"buttom\" class=\"button small\"></form>";

#Error500
print "<br>";
print "<b>Personalized message Error 500 \"Internal server error\", HTML tags accepted.</b>";
@err500 = &getFarmErr( $farmname, "500" );
print "<form method=\"post\" action=\"index.cgi\">";
print "<input type=\"hidden\" name=\"actionpost\" value=\"editfarm-Err500\">";

#print "<input type=\"textarea\" value=\"$err500\" size=\"4\" name=\"param\">";
print "<textarea name=\"err500\" cols=\"40\" rows=\"2\">";
foreach $line ( @err500 )
{
	print "$line";
}
print "</textarea>";
print "<input type=\"hidden\" name=\"id\" value=\"$id\">";
print "<input type=\"hidden\" name=\"farmname\" value=\"$farmname\">";
print "<input type=\"submit\" value=\"Modify\" name=\"buttom\" class=\"button small\"></form>";

#Error501
print "<br>";
print "<b>Personalized message Error 501 \"Method may not be used\", HTML tags accepted.</b>";
@err501 = &getFarmErr( $farmname, "501" );
print "<form method=\"post\" action=\"index.cgi\">";
print "<input type=\"hidden\" name=\"actionpost\" value=\"editfarm-Err501\">";

#print "<input type=\"textarea\" value=\"$err501\" size=\"4\" name=\"param\">";
print "<textarea name=\"err501\" cols=\"40\" rows=\"2\">";
foreach $line ( @err501 )
{
	print "$line";
}
print "</textarea>";
print "<input type=\"hidden\" name=\"id\" value=\"$id\">";
print "<input type=\"hidden\" name=\"farmname\" value=\"$farmname\">";
print "<input type=\"submit\" value=\"Modify\" name=\"buttom\" class=\"button small\"></form>";

#Err503
print "<br>";
print "<b>Personalized message Error 503 \"Service is not available\", HTML tags accepted.</b>";
@err503 = &getFarmErr( $farmname, "503" );
print "<form method=\"post\" action=\"index.cgi\">";
print "<input type=\"hidden\" name=\"actionpost\" value=\"editfarm-Err503\">";

#print "<input type=\"textarea\" value=\"$err503\" size=\"4\" name=\"param\">";
print "<textarea name=\"err503\" cols=\"40\" rows=\"2\">";
foreach $line ( @err503 )
{
	print "$line";
}
print "</textarea>";
print "<input type=\"hidden\" name=\"id\" value=\"$id\">";
print "<input type=\"hidden\" name=\"farmname\" value=\"$farmname\">";
print "<input type=\"submit\" value=\"Modify\" name=\"buttom\" class=\"button small\"></form>";

print " <br/> <br/> <br/>";
if ( $morelines eq "true" )
{
	print "<br><br><br>";
}
if ( $moreliness eq "true" )
{
	print "<br><br><br><br><br><br><br>";
}
if ( $morelinescipher eq "true" )
{
	print "<br><br><br><br>";
}

print "</div>";
print "<div style=\"clear:both;\"></div>";

#Services

####end form for global parameters
$service = $farmname;
print "</div><br>";

print "</div>";

print "<a name=\"backendlist-$sv\"></a>";
print "<div id=\"page-header\"></div>\n";

#ZWACL-INI

open FR, "<$configdir\/$file";
my @file    = <FR>;
my $first   = 0;
my $vserver = -1;
my $pos     = 0;
$id_serverr = $id_server;
foreach $line ( @file )
{
	if ( $first == 1 && $line =~ /Service\ \"/ )
	{
		if ( $vserver == 0 )
		{
			#Virtual Server
			my $vser = &getFarmVS( $farmname, $sv, "vs" );
			print "<form method=\"get\" action=\"index.cgi\">";
			print "Virtual Host.  <font size=1>*empty value disabled</font> <br><input type=\"text\" size=\"60\"  name=\"string\" value=\"$vser\">";
			print "<input type=\"hidden\" name=\"action\" value=\"editfarm-vs\">";
			print "<input type=\"hidden\" name=\"id\" value=\"$id\">";
			print "<input type=\"hidden\" name=\"farmname\" value=\"$farmname\">";
			print "<input type=\"hidden\" name=\"id_server\" value=\"$nserv\">";
			print "<input type=\"hidden\" name=\"service\" value=\"$sv\">";
			print "<input type=\"submit\" value=\"Modify\" name=\"buttom\" class=\"button small\">";
			print "</form>";

			#Url
			print "<br>\n";
			my $urlp = &getFarmVS( $farmname, $sv, "urlp" );
			print "<form method=\"get\" action=\"index.cgi\">";
			print "Url pattern. <font size=1>*empty value disabled</font> <br><input type=\"text\" size=\"60\"  name=\"string\" value=\"$urlp\">";
			print "<input type=\"hidden\" name=\"action\" value=\"editfarm-urlp\">";
			print "<input type=\"hidden\" name=\"id\" value=\"$id\">";
			print "<input type=\"hidden\" name=\"farmname\" value=\"$farmname\">";
			print "<input type=\"hidden\" name=\"id_server\" value=\"$nserv\">";
			print "<input type=\"hidden\" name=\"service\" value=\"$sv\">";
			print "<input type=\"submit\" value=\"Modify\" name=\"buttom\" class=\"button small\">";
			print "</form>";

			#Redirect
			print "<br>\n";
			my $redirect = &getFarmVS( $farmname, $sv, "redirect" );
			print "<form method=\"get\" action=\"index.cgi\">";
			print "Redirect. <font size=1>*empty value disabled</font> <br><input type=\"text\" size=\"60\"  name=\"string\" value=\"$redirect\">";
			print "<input type=\"hidden\" name=\"action\" value=\"editfarm-redirect\">";
			print "<input type=\"hidden\" name=\"id\" value=\"$id\">";
			print "<input type=\"hidden\" name=\"farmname\" value=\"$farmname\">";
			print "<input type=\"hidden\" name=\"id_server\" value=\"$nserv\">";
			print "<input type=\"hidden\" name=\"service\" value=\"$sv\">";
			print "<input type=\"submit\" value=\"Modify\" name=\"buttom\" class=\"button small\">";
			print "</form>";

			#session type
			print "<br>";
			print "<b>Persistence session.</b>";

			#$session = &getFarmSessionType($farmname,$service);
			my $session = &getFarmVS( $farmname, $sv, "sesstype" );
			if ( $session =~ /^$/ )
			{
				$session = "nothing";
			}
			print "<form method=\"get\" action=\"index.cgi\">";
			print "<input type=\"hidden\" name=\"action\" value=\"editfarm-typesession\">";
			print "<input type=\"hidden\" name=\"id\" value=\"$id\">";
			print "<input type=\"hidden\" name=\"farmname\" value=\"$farmname\">";
			print "<input type=\"hidden\" name=\"service\" value=\"$sv\">";
			print "<select  name=\"session\">";
			print "<option value=\"nothing\">no persistence</option>";

			if ( $session eq "IP" )
			{
				print "<option value=\"IP\" selected=\"selected\">IP: client address</option>";
			}
			else
			{
				print "<option value=\"IP\">IP: client address</option>";
			}
			
			if ( $session eq "BASIC" )
			{
				print "<option value=\"BASIC\" selected=\"selected\">BASIC: basic authentication</option>";
			}
			else
			{
				print "<option value=\"BASIC\">BASIC: basic authentication</option>";
			}
			
			if ( $session eq "URL" )
			{
				print "<option value=\"URL\" selected=\"selected\">URL: a request parameter</option>";
			}
			else
			{
				print "<option value=\"URL\">URL: a request parameter</option>";
			}
			
			if ( $session eq "PARM" )
			{
				print "<option value=\"PARM\" selected=\"selected\">PARM: a  URI parameter</option>";
			}
			else
			{
				print "<option value=\"PARM\">PARM: a URI parameter</option>";
			}
			
			if ( $session eq "COOKIE" )
			{
				print "<option value=\"COOKIE\" selected=\"selected\">COOKIE: a certain cookie</option>";
			}
			else
			{
				print "<option value=\"COOKIE\">COOKIE: a certain cookie</option>";
			}
			
			if ( $session eq "HEADER" )
			{
				print "<option value=\"HEADER\" selected=\"selected\">HEADER: A certains request header</option>";
			}
			else
			{
				print "<option value=\"HEADER\">HEADER: A certains request header</option>";
			}
			print "</select>";
			print "<input type=\"submit\" value=\"Modify\" name=\"buttom\" class=\"button small\"></form>";

			#session TTL
			if ( $session ne "nothing" && $session )
			{
				print "<br>";
				print "<b>Persistence session time to limit.</b>";

				#@ttl = &getFarmMaxClientTime($farmname,$service);
				my $ttl = &getFarmVS( $farmname, $sv, "ttl" );
				print "<form method=\"get\" action=\"index.cgi\">";
				print "<input type=\"hidden\" name=\"action\" value=\"editfarm-TTL\">";
				print "<input type=\"text\" value=\"$ttl\" size=\"4\" name=\"string\">";
				print "<input type=\"hidden\" name=\"id\" value=\"$id\">";
				print "<input type=\"hidden\" name=\"farmname\" value=\"$farmname\">";
				print "<input type=\"hidden\" name=\"service\" value=\"$sv\">";
				print "<input type=\"submit\" value=\"Modify\" name=\"buttom\" class=\"button small\"></form>";
			}

			#session ID
			$morelines = "false";
			if ( $session eq "URL" || $session eq "COOKIE" || $session eq "HEADER" )
			{
				print "<br>";
				print "<b>Persistence session identifier.</b> <font size=1>*a cookie name, a header name or url value name</font>";

				#$sessionid = &getFarmSessionId($farmname,$service);
				$sessionid = &getFarmVS( $farmname, $sv, "sessionid" );
				print "<form method=\"get\" action=\"index.cgi\">";
				print "<input type=\"hidden\" name=\"action\" value=\"editfarm-sessionid\">";
				print "<input type=\"text\" value=\"$sessionid\" size=\"20\" name=\"string\">";
				print "<input type=\"hidden\" name=\"id\" value=\"$id\">";
				print "<input type=\"hidden\" name=\"service\" value=\"$sv\">";
				print "<input type=\"hidden\" name=\"farmname\" value=\"$farmname\">";
				print "<input type=\"submit\" value=\"Modify\" name=\"buttom\" class=\"button small\"></form>";
				$morelines = "true";
			}

			#use farmguardian
			#open farmguardian file to view config.
			print "<br>";
			my @fgconfig  = &getFarmGuardianConf( $farmname, $sv );
			my $fgttcheck = @fgconfig[1];
			my $fgscript  = @fgconfig[2];
			$fgscript =~ s/\n//g;
			$fgscript =~ s/\"/\'/g;
			my $fguse = @fgconfig[3];
			$fguse =~ s/\n//g;
			my $fglog = @fgconfig[4];
			if ( !$timetocheck ) { $timetocheck = 5; }

			##HTTPS Backends
			print "<form method=\"get\" action=\"index.cgi\">";
			my $httpsbe = &getFarmVS( $farmname, $sv, "httpsbackend" );
			if ( $httpsbe eq "true" )
			{
				print "<input type=\"checkbox\" checked name=\"httpsbackend\" value=\"true\">";
			}
			else
			{
				print "<input type=\"checkbox\"  name=\"httpsbackend\" value=\"true\"> ";
			}

			print "&nbsp;<b>HTTPS Backends.</b>";
			print "<input type=\"hidden\" name=\"action\" value=\"editfarm-httpsbackends\">";
			print "<input type=\"hidden\" name=\"id\" value=\"$id\">";
			print "<input type=\"hidden\" name=\"service\" value=\"$sv\">";
			print "<input type=\"hidden\" name=\"farmname\" value=\"$farmname\">";
			print "<input type=\"submit\" value=\"Modify\" name=\"buttom\" class=\"button small\">";
			print "</form>";

			print "<br>";

			##FarmGuardian
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
			print "<input type=\"hidden\" name=\"service\" value=\"$sv\">";
			print "<input type=\"hidden\" name=\"farmname\" value=\"$farmname\">";
			print "<input type=\"submit\" value=\"Modify\" name=\"buttom\" class=\"button small\">";
			print "</form>";

			$vserver = 1;
		}

		print "</div>";

		$vserver = 0;
		print "<div class=\"box table\">";
		print "<table cellpadding=0>";
		print "<thead><tr><td>Server</td><td>Address</td><td>Port</td><td>Timeout</td><td>Weight</td><td>Actions</td></tr></thead><tbody>";

		#search backends for this service
		#getBackends for this service
		my $backendsvs = &getFarmVS( $farmname, $sv, "backends" );
		my @be = split ( "\n", $backendsvs );
		foreach $subline ( @be )
		{
			my @subbe = split ( "\ ", $subline );

			#print "<tr> <td>@subbe[1]</td> <td>@subbe[3]</td> <td>@subbe[5]</td> <td>@subbe[7]</td> <td>@subbe[9]</td> <td>";
			if ( $id_serverr == @subbe[1] && $service eq "$actualservice" && $action eq "editfarm-editserver" )
			{
				print "<form method=\"get\" action=\"index.cgi\#backendlist-$sv\">";
				print "<tr class=\"selected\">";
				print "<td>@subbe[1]</td>";
				print "<td><input type=\"text\" size=\"12\"  name=\"rip_server\" value=\"@subbe[3]\"> </td>";
				print "<td><input type=\"text\" size=\"4\" name=\"port_server\" value=\"@subbe[5]\"> </td>";
				if ( @subbe[7] eq "-" ) { @subbe[7] =~ s/-//; }
				print "<td><input type=\"text\" size=\"4\" name=\"timeout_server\" value=\"@subbe[7]\"> </td>";
				if ( @subbe[9] eq "-" ) { @subbe[9] =~ s/-//; }
				print "<td><input type=\"text\" size=\"4\" name=\"priority_server\" value=\"@subbe[9]\"> </td>";
				$nserv = @subbe[1];
				&createmenuserversfarm( "edit", $farmname, $nserv );
				print "<input type=\"hidden\" name=\"id\" value=\"$id\">";
				print "<input type=\"hidden\" name=\"farmname\" value=\"$farmname\">";
				print "<input type=\"hidden\" name=\"id_server\" value=\"$subbe[1]\">";
				print "<input type=\"hidden\" name=\"service\" value=\"$sv\">";
				print "</tr>";
				print "</form>";
			}
			else
			{
				print "<form method=\"get\" action=\"index.cgi\#backendlist-$sv\">";
				print "<tr><td>@subbe[1]</td>";
				print "<td>@subbe[3]</td>";
				print "<td>@subbe[5]</td>";
				print "<td>@subbe[7]</td>";
				print "<td>@subbe[9]</td>";

				#print "<td></td>";
				$nserv = @subbe[1];
				&createmenuserversfarm( "normal", $farmname, $nserv );
				print "</tr>";
				print "<input type=\"hidden\" name=\"id\" value=\"$id\">";
				print "<input type=\"hidden\" name=\"farmname\" value=\"$farmname\">";
				print "<input type=\"hidden\" name=\"id_server\" value=\"@subbe[1]\">";
				print "<input type=\"hidden\" name=\"service\" value=\"$sv\">";
				print "</form>";
			}
		}

		print "<a name=\"backendlist-$sv\"></a>";

		#add new server to  server pool
		print "\n\n\n";
		if ( $action eq "editfarm-addserver" && $service eq "$actualservice" )
		{
			if ( ( $action eq "editfarm-editserver" || $action eq "editfarm-addserver" ) && $service eq "$actualservice" )
			{
				print "<form method=\"get\" action=\"index.cgi\#backendlist-$sv\">";
			}

			print "<tr class=\"selected\">";

			#id server
			print "<td>-</td>";
			print "<input type=\"hidden\" name=\"id_server\" value=\"\">";

			#real server ip
			print "<td><input type=\"text\" size=\"12\"  name=\"rip_server\" value=\"$rip_server\"> </td>";

			#port
			print "<td><input type=\"text\" size=\"4\"  name=\"port_server\" value=\"$port_server\"> </td>";

			#timeout
			print "<td><input type=\"text\" size=\"4\"  name=\"timeout_server\" value=\"$timeout_server\"> </td>";

			#Priority
			print "<td><input type=\"text\" size=\"4\"  name=\"priority_server\" value=\"$priority_server\"> </td>";
			&createmenuserversfarm( "add", $farmname, @l_serv[0] );
			print "<input type=\"hidden\" name=\"id\" value=\"$id\">";
			print "<input type=\"hidden\" name=\"farmname\" value=\"$farmname\">";
			print "<input type=\"hidden\" name=\"service\" value=\"$sv\">";

			#print "<input type=\"hidden\" name=\"farmprotocol\" value=\"$farmprotocol\">";
			print "</form>";
			print "</tr>";
		}

		print "\n\n\n";
		print "<tr><td colspan=\"5\">";

		print "<form method=\"get\" action=\"index.cgi\#backendlist-$sv\">";
		&createmenuserversfarm( "new", $farmname, @l_serv[0] );
		print "<input type=\"hidden\" name=\"id\" value=\"$id\">";
		print "<input type=\"hidden\" name=\"farmname\" value=\"$farmname\">";
		print "<input type=\"hidden\" name=\"id_server\" value=\"@l_serv[0]\">";
		print "<input type=\"hidden\" name=\"farmname\" value=\"$farmname\">";
		print "<input type=\"hidden\" name=\"service\" value=\"$sv\">";
		print "</form>";

		print "    </tr>";

		print "</tbody></table></div><br>";
	}

	if ( $line =~ /Service "$farmname"/ )
	{
		$service = $farmname;
		break;
	}
	if ( $line !~ /Service "$service"/ && $line =~ /Service\ \"/ )
	{
		$pos++;
		$first   = 1;
		$vserver = 0;
		@line    = split ( "\"", $line );
		print "<div class=\"box-header\">";
		$sv = @line[1];

		#$sv =~ s/"//g;
		&createmenuservice( $farmname, $sv, $pos );
		print " Service  \"@line[1]\"</div>";
		print "<div class=\"box-content\">\n";

		#my @serv = split("\ ",$line);
		#chomp($service);
		#$service = @serv[1];
		$service = $sv;
	}
}

close FR;

#ZWACL-END

###############################################
#JUMP BACKEND SECTION
goto BACKENDS;
##############################################

print "<br><br>";
print "<div class=\"box-header\">Edit real IP servers configuration</div>";

if ( $action eq "editfarm-editserver" || $action eq "editfarm-addserver" )
{
	print "<form method=\"get\" action=\"index.cgi\#backendlist-$sv\">";
}
print "<div class=\"box table\">  <table cellspacing=\"0\">";

#header table
print "<thead><tr><td>Server</td><td>Address</td><td>Port</td><td>Timeout</td><td>Weight</td><td>Actions</td></tr></thead><tbody>";

#
tie @contents, 'Tie::File', "$configdir\/$file";
$nserv      = -1;
$index      = -1;
$be_section = 0;
$to_sw      = 0;
$prio_sw    = 0;

$id_serverr = $id_server;
foreach $line ( @contents )
{
	$index++;
	if ( $line =~ /#BackEnd/ )
	{
		$be_section = 1;
	}
	if ( $be_section == 1 )
	{
		if ( $line =~ /Address/ )
		{
			$nserv++;
			@ip = split ( /\ /, $line );
			chomp ( @ip[1] );
		}
		if ( $line =~ /Port/ )
		{
			@port = split ( /\ /, $line );
			chomp ( @port );
		}
		if ( $line =~ /TimeOut/ )
		{
			@timeout = split ( /\ /, $line );
			chomp ( @timeout );
			$to_sw = 1;
		}
		if ( $line =~ /Priority/ )
		{
			@priority = split ( /\ /, $line );
			chomp ( @priority );
			$po_sw = 1;
		}
		if ( $line !~ /\#/ && $line =~ /End/ && $line !~ /Back/ )
		{
			if ( $id_serverr == $nserv && $action eq "editfarm-editserver" )
			{
				print "<form method=\"get\" action=\"index.cgi\#backendlist-$sv\">";
				print "<tr class=\"selected\">";
				print "<td>$nserv</td>";
				print "<td><input type=\"text\" size=\"12\"  name=\"rip_server\" value=\"@ip[1]\"> </td>";
				print "<td><input type=\"text\" size=\"4\" name=\"port_server\" value=\"@port[1]\"> </td>";
				print "<td><input type=\"text\" size=\"4\" name=\"timeout_server\" value=\"@timeout[1]\"> </td>";
				print "<td><input type=\"text\" size=\"4\" name=\"priority_server\" value=\"@priority[1]\"> </td>";
				&createmenuserversfarm( "edit", $farmname, $nserv );
				print "<input type=\"hidden\" name=\"id\" value=\"$id\">";
				print "<input type=\"hidden\" name=\"farmname\" value=\"$farmname\">";
				print "<input type=\"hidden\" name=\"id_server\" value=\"$nserv\">";
				print "<input type=\"hidden\" name=\"service\" value=\"$service\">";
				print "</form>";
			}
			else
			{
				print "<tr>";
				print "<form method=\"get\" action=\"index.cgi\#backendlist-$sv\">";
				print "<td>$nserv</td>";
				print "<td>@ip[1]</td>";
				print "<td>@port[1]</td>";
				if ( $to_sw == 0 )
				{
					print "<td>-</td>";
				}
				else
				{
					print "<td>@timeout[1]</td>";
					$to_sw = 0;
				}
				if ( $po_sw == 0 )
				{
					print "<td>-</td>";
				}
				else
				{
					print "<td>@priority[1]</td>";
					$po_sw = 0;
				}

				#print "<td></td>";
				&createmenuserversfarm( "normal", $farmname, $nserv );
				print "</tr>";
				print "<input type=\"hidden\" name=\"id\" value=\"$id\">";
				print "<input type=\"hidden\" name=\"farmname\" value=\"$farmname\">";
				print "<input type=\"hidden\" name=\"id_server\" value=\"$nserv\">";
				print "<input type=\"hidden\" name=\"service\" value=\"$service\">";
				print "</form>";
				undef @timeout;
				undef @priority;
			}
		}
	}
	if ( $be_section == 1 && $line =~ /#End/ )
	{
		$be_section = 0;
	}
}
untie @contents;

#content table
if ( $action eq "editfarm-addserver" && $actualservice eq $service )
{
	#add new server to  server pool
	$action = "editfarm";
	$isrs   = "true";
	print "<form method=\"get\" action=\"index.cgi\#backendlist-$sv\">";
	print "<tr class=\"selected\">";

	#id server
	print "<td>-</td>";
	print "<input type=\"hidden\" name=\"id_server\" value=\"\">";

	#real server ip
	print "<td><input type=\"text\" size=\"12\"  name=\"rip_server\" value=\"$rip_server\"> </td>";

	#port
	print "<td><input type=\"text\" size=\"4\"  name=\"port_server\" value=\"$port_server\"> </td>";

	#timeout
	print "<td><input type=\"text\" size=\"4\"  name=\"timeout_server\" value=\"$timeout_server\"> </td>";

	#Priority
	print "<td><input type=\"text\" size=\"4\"  name=\"priority_server\" value=\"$priority_server\"> </td>";
	&createmenuserversfarm( "add", $farmname, @l_serv[0] );
	print "<input type=\"hidden\" name=\"id\" value=\"$id\">";
	print "<input type=\"hidden\" name=\"farmname\" value=\"$farmname\">";
	print "<input type=\"hidden\" name=\"service\" value=\"$service\">";

	#print "<input type=\"hidden\" name=\"farmprotocol\" value=\"$farmprotocol\">";
	print "</form>";
	print "</tr>";
}

print "<tr><td colspan=\"5\"></td>";
print "<form method=\"get\" action=\"index.cgi\#backendlist-$sv\">";
&createmenuserversfarm( "new", $farmname, @l_serv[0] );
print "<input type=\"hidden\" name=\"id\" value=\"$id\">";
print "<input type=\"hidden\" name=\"farmname\" value=\"$farmname\">";
print "<input type=\"hidden\" name=\"id_server\" value=\"@l_serv[0]\">";
print "<input type=\"hidden\" name=\"farmname\" value=\"$farmname\">";
print "<input type=\"hidden\" name=\"service\" value=\"$service\">";
print "</form>";

print "</tr>";

print "</tbody></table>";
print "<div style=\"clear:both;\"></div>";
print "</div>";

#if ($action eq "editfarm-editserver" || $action eq "editfarm-addserver"){ print "</form>";}

#end table

#################################################################
BACKENDS:
##################################################################

print "</div>";

print "<div id=\"page-header\"></div>";
print "<form method=\"get\" action=\"index.cgi\">";
print "<input type=\"hidden\" value=\"1-2\" name=\"id\">";
print "<input type=\"submit\" value=\"Cancel\" name=\"action\" class=\"button small\">";
print "</form>";
print "<div id=\"page-header\"></div>";
print "</div>";

