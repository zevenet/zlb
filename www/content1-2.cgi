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

my $type = &getFarmType( $farmname );

print "
    <!--Content INI-->
        <div id=\"page-content\">

                <!--Content Header INI-->";

if ( $farmname !~ /^[a-zA-Z0-9\-]*$/)
{
	&errormsg("Farm name is not valid. Only numbers, letters and hyphens are allowed");
	$farmname = "";
}

if ( $farmname ne "" && $type != 1 )
{
	print "<h2>Manage::Farms\:\:$type\:\:$farmname</h2>";
}
else
{
	if ( $farmname ne "" )
	{
		print "<h2>Manage::Farms::$farmname</h2>";
	}
	else
	{
		print "<h2>Manage::Farms</h2>";
	}
}

print "<!--Content Header END-->";

#evaluate the $action variable, used for manage forms
if ( $action eq "addfarm" || $action eq "Save" || $action eq "Save & continue" )
{
	require "./content1-21.cgi";
}

if ( $action eq "deletefarm" )
{
	my $stat = &runFarmStop( $farmname, "true" );
	if ( $stat == 0 )
	{
		&successmsg( "The Farm $farmname is now disabled" );
	}

	$stat = &runFarmDelete( $farmname );
	if ( $stat == 0 )
	{
		&successmsg( "The Farm $farmname is now deleted" );
	}
	else
	{
		&successmsg( "The Farm $farmname hasn't been deleted" );
	}
}

if ( $action eq "startfarm" )
{
	my $stat = &runFarmStart( $farmname, "true" );
	if ( $stat == 0 )
	{
		&successmsg( "The Farm $farmname is now running" );
	}
	else
	{
		&errormsg( "The Farm $farmname isn't running, check if the IP address is up and the PORT is in use" );
	}
}

if ( $action eq "stopfarm" )
{
	my $stat = &runFarmStop( $farmname, "true" );
	if ( $stat == 0 )
	{
		&successmsg( "The Farm $farmname is now disabled" );
	}
	else
	{
		&errormsg( "The Farm $farmname is not disabled" );
	}
}

if ( $action =~ "^editfarm" || $editfarm )
{
	if ( $type == 1 )
	{
		&errormsg( "Unknown farm type of $farmname" );
	}
	else
	{
		$file = &getFarmFile( $farmname );
		if ( $type eq "tcp" || $type eq "udp" )
		{
			require "./content1-22.cgi";
		}
		if ( $type eq "http" || $type eq "https" )
		{
			require "./content1-24.cgi";
		}
		if ( $type eq "datalink" )
		{
			require "./content1-26.cgi";
		}
		if ( $type eq "l4xnat" )
		{
			require "./content1-28.cgi";
		}
		if ( $type eq "gslb" )
		{
			require "./content1-202.cgi";
		}
	}
}

if ( $action eq "managefarm" )
{
	$type = &getFarmType( $farmname );
	if ( $type == 1 )
	{
		&errormsg( "Unknown farm type of $farmname" );
	}
	else
	{
		$file = &getFarmFile( $farmname );
		if ( $type eq "tcp" || $type eq "udp" )
		{
			require "./content1-23.cgi";
		}
		if ( $type eq "http" || $type eq "https" )
		{
			require "./content1-25.cgi";
		}
		if ( $type eq "datalink" )
		{
			require "./content1-27.cgi";
		}
		if ( $type eq "l4xnat" )
		{
			require "./content1-29.cgi";
		}
		if ( $type eq "gslb" )
		{
			require "./content1-203.cgi";
		}
	}
}

#check if the user is into a farm for editing or for modifying

#list all farms configuration and status
#first list all configuration files
@files = &getFarmList();
$size  = $#files + 1;
if ( $size == 0 )
{
	$action   = "addfarm";
	$farmname = "";
	require "./content1-21.cgi";
}

#table that print the info
print "<div class=\"box-header\">Farms table</div>";
print "<div class=\"box table\">";

my $thereisdl = "false";

print "<table cellspacing=\"0\">";

print "<thead>";
print "<tr>";
print "<td width=85>Name</td>";
print "<td width=85>Virtual IP</td>";
print "<td>Virtual Port(s)</td>";
print "<td>Status</td>";
print "<td>Profile</td>";
print "<td>Actions</td>";
print "</tr>";
print "</thead>";
print "<tbody>";

foreach $file ( @files )
{
	$name = &getFarmName( $file );
##########if farm is not the current farm then it doesn't print. only print for global view.
	#if ( $farmname eq $name || !( defined $farmname ) || $farmname eq "" || $action eq "deletefarm" || $action =~ /^Save|^Cancel/ )
	#if ($globalfarm eq 0 )
	#{
		$type = &getFarmType( $name );
		#$globalfarm++;
		if ( $type ne "datalink" )
		{

			if ( $farmname eq $name && $action ne "addfarm" && $action ne "Cancel" )
			{
				print "<tr class=\"selected\">";
			}
			else
			{
				print "<tr>";
			}

			#print the farm description name
			print "<td>$name</td>";

			#print the virtual ip
			$vip = &getFarmVip( "vip", $name );
			print "<td>$vip</td>";

			#print the virtual port where the vip is listening
			$vipp = &getFarmVip( "vipp", $name );
			print "<td>$vipp</td>";

			#print global connections bar
			$pid    = &getFarmPid( $name );
			$status = &getFarmStatus( $name );

			#print status of a farm
			if ( $status ne "up" )
			{
				print "<td><img src=\"img/icons/small/stop.png\" title=\"down\"></td>";
			}
			else
			{
				print "<td><img src=\"img/icons/small/start.png\" title=\"up\"></td>";
			}

			#type of farm
			print "<td>$type</td>";

			#menu
			print "<td>";
			if ( $type eq "tcp" || $type eq "udp" || $type eq "l4xnat" )
			{
				&createmenuvip( $name, $id, $status );
			}
			if ( $type eq "gslb" )
			{
				&createmenuviph( $name, $id, $type );
			}
			if ( $type =~ /http/ )
			{
				&createmenuviph( $name, $id, "HTTP" );
			}
			print "</td>";
			print "</tr>";
		}
		else
		{
			$thereisdl = "true";
		}
	#}
}
print "</tbody>";

# DATALINK

if ( $thereisdl eq "true" )
{
	print "<thead>";
	print "<tr>";
	print "<td width=85>Name</td>";
	print "<td width=85 colspan=2>IP</td>";
	print "<td>Status</td>";
	print "<td>Profile</td>";
	print "<td>Actions</td>";
	print "</tr>";
	print "</thead>";
	print "<tbody>";
	use Time::HiRes qw (sleep);

	foreach $file ( @files )
	{
		$name = &getFarmName( $file );
		$type = &getFarmType( $name );

		if ( $type eq "datalink" )
		{

			$vipp = &getFarmVip( "vipp", $name );
			my @startdata = &getDevData( $vipp );

			#print "@startdata<br>";
			sleep ( 0.5 );
			my @enddata = &getDevData( $vipp );

			#print "@enddata<br>";

			if ( $farmname eq $name && $action ne "addfarm" && $action ne "Cancel" )
			{
				print "<tr class=\"selected\">";
			}
			else
			{
				print "<tr>";
			}

			#print the farm description name
			print "<td>$name</td>";

			#print the virtual ip
			$vip = &getFarmVip( "vip", $name );
			print "<td colspan=2>$vip</td>";

			#print the interface to be the defaut gw
			#print "<td>$vipp</td>";

			#print global packets
			$status = &getFarmStatus( $name );

			#print status of a farm
			if ( $status ne "up" )
			{
				print "<td><img src=\"img/icons/small/stop.png\" title=\"down\"></td>";
			}
			else
			{
				print "<td><img src=\"img/icons/small/start.png\" title=\"up\"></td>";
			}

			#type of farm
			print "<td>$type</td>";

			#menu
			print "<td>";
			&createmenuvip( $name, $id, $status );

			print "</td>";
			print "</tr>";
		}
	}

## END DATALINK

	print "</tbody>";
}
print "<tr><td colspan=\"5\"></td><td><a href=\"index.cgi?id=$id&action=addfarm\"><img src=\"img/icons/small/farm_add.png\" title=\"Add new Farm\"></a></td></tr>";

print "</table>";
print "</div>";

print "<br class=\"cl\" >";
print "</div>";
