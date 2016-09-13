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

use Sys::Hostname;
my $host = hostname();

print "
<!--Content INI-->
<div id=\"page-content\">

<!--Content Header INI-->
<h2>Settings::Server</h2>
<!--Content Header END-->";

#process changes in global.conf when action=Modify
if ( $action =~ /^Modify$/ )
{
	use Tie::File;
	tie @array, 'Tie::File', "$globalcfg";
	for ( @array )
	{
		s/\$$var.*/\$$var=\"$line\";/g;
	}

	#apt modifications
	if ( $var eq "apt" )
	{
		tie @arrayapt, 'Tie::File', "$fileapt";
		print "$line\n";
		$i = 0;
		foreach $aptserv ( @arrayapt )
		{
			print "line $aptserv\n";
			if ( $aptserv =~ /zenloadbalancer\.sourceforge\.net/ )
			{
				splice ( @arrayapt, $i, $i );
			}
			$i = $i + 1;
		}
		push ( @arrayapt, "deb $line\n" );
		untie @arrayapt;
	}

	#dns modifications
	if ( $var eq "dns" )
	{
		print "var es $var";
		@dns = split ( "\ ", $line );
		open FW, ">$filedns";
		foreach $dnsserv ( @dns )
		{
			print FW "nameserver $dnsserv\n";
		}
		close FW;
	}
	if ( $var eq "mgwebip" || $var eq "mgwebport" )
	{
		&successmsg( "Changes OK, restart web service now" );
	}
	else
	{
		&successmsg( "Changes OK" );
	}

	untie @array;
	#actions with Modify buttom
}

#action Save DNS
if ( $var eq "Save DNS" )
{
	open FW, ">$filedns";
	print FW "$line";
	&successmsg( "DNS saved" );
	close FW;
}

#action Save APT
if ( $var eq "Save APT" )
{
	open FW, ">$fileapt";
	print FW "$line";
	&successmsg( "APT saved" );
	close FW;
}

#action save ip
if ( $action eq "Save Management IP" )
{
	# save http gui ip
	use Tie::File;
	tie @array, 'Tie::File', "$confhttp";
	@array[0] = "host=$ipgui\n";
	untie @array;

	# save snmp ip
	my $mng_ip  = &GUIip();
	my $snmp_ip = &getSnmpdIp();

	# if snmp ip is different to management ip
	if ( $snmp_ip ne $mng_ip )
	{
		# with the exception of * in management, it is 0.0.0.0 for snmp server
		if ( !( $mng_ip eq '*' && $snmp_ip eq '0.0.0.0' ) )
		{
			&setSnmpdIp( $mng_ip );
		}
	}
	&successmsg("Changes have been applied. You need to restart management services")
}

if ( $action eq "Change GUI https port" )
{
	&setGuiPort( $guiport, $confhttp );
}

if ( $action eq "Restart Management Services" )
{
	if ( $pid = fork )
	{
		#$SIG{'CHLD'}='IGNORE';
		#print "Proceso de restart lanzado ...";
	}
	elsif ( defined $pid )
	{
		# snmpd restart if running
		if ( &getSnmpdStatus eq 'true' )
		{
			&setSnmpdStatus( 'false' );    # stopping snmp
			&setSnmpdStatus( 'true' );     # starting snmp
		}

		# minihttpd restart
		system ( "/etc/init.d/minihttpd restart > /dev/null &" );
		exit ( 0 );
	}
	if ( $ipgui =~ /^$/ )
	{
		$ipgui = &GUIip();
	}
	if ( $guiport =~ /^$/ )
	{
		$guiport = &getGuiPort( $confhttp );
	}
	if ( $ipgui =~ /\*/ )
	{
		&successmsg( "Restarted Service, access to management services over any IP on port $guiport" );
	}
	else
	{
		&successmsg( "Restarted Service, access to management services over $ipgui IP on port $guiport <a href=\"https:\/\/$ipgui:$guiport\/index.cgi?id=$id\">go here</a>" );
	}
}

if ( $action eq "edit-snmp" )
{
	if ( &applySnmpChanges( $snmpd_enabled, $snmpd_port, $snmpd_community, $snmpd_scope ) )
	{
		&errormsg( "SNMP service changes have failed. Please check the logs" );
	}
	else
	{
		&successmsg( "SNMP service changes applied successfully" );
	}
}

### BEGIN Global information ###
#open global file config
$nextline = "false";
open FR, "$globalcfg";
while ( <FR> )
{
	if ( $_ =~ /^#::INI/ )
	{
		$linea = $_;
		$linea =~ s/^#::INI//;
		my @actionform = split ( /\ /, $linea );
		print "<div class=\"container_12\">";
		print "<div class=\"grid_12\">";
		print "<div class=\"box-header\">$linea</div>";
		print "<div class=\"box stats\">";
	}
	if ( $_ =~ /^#\./ )
	{
		$nextline = "true";
		print "<div class=\"row\">";
		$linea = $_;
		$linea =~ s/^#\.//;
		print "<label>$linea</label>";
	}

	if ( $_ =~ /^\$/ && $nextline eq "true" )
	{
		$nextline = "fase";
		my @linea = split ( /=/, $_ );
		$linea[1] =~ s/"||\;//g;
		$linea[0] =~ s/^\$//g;
		print "<form method=\"get\" action=\"index.cgi\">";
		print "<input type=\"hidden\" name=\"id\" value=\"3-1\">";
		print "<input type=\"text\" value=\"$linea[1]\" size=\"20\" name=\"line\">";
		print "<input type=\"hidden\" name=\"var\" value=\"$linea[0]\">";
		print "<input type=\"submit\" value=\"Modify\" name=\"action\" class=\"button small\">";
		print "</form>";
		print "</div>";
		print "<br>";
	}

	if ( $_ =~ /^#::END/ )
	{
		print "</div></div></div>";
	}
}
close FR;
### END Global information ###

### BEGIN Local configuration ###
print "<div class=\"container_12\">";
print "<div class=\"grid_12\">";
print "<div class=\"box-header\">Local configuration</div>";
print "<div class=\"box stats\">";

open FR, "<$confhttp";

@file     = <FR>;
$hosthttp = $file[0];
close FR;
print "<b>Management interface where is running GUI service and SNMP (if enabled).</b>";
print "<font size=\"1\"> If cluster is up you only can select \"--All interfaces--\" option, or \"the cluster interface\". Changes need restart management services.</font>";
print "<form method=\"get\" action=\"index.cgi\">";
print "<input type=\"hidden\" name=\"id\" value=\"3-1\">";

opendir ( DIR, "$configdir" );
@files = grep ( /^if.*/, readdir ( DIR ) );
closedir ( DIR );

@ipguic = split ( "=", $file[0] );
$hosthttp = $ipguic[1];
chomp ( $hosthttp );

open FR, "<$filecluster";
@filecluster = <FR>;
close FR;
$lclusterstatus = $filecluster[2];
@lclustermember = split ( ":", $filecluster[0] );
chomp ( @lclustermember );
$lhost = $lclustermember[1];
$rhost = $lclustermember[3];
$lip   = $lclustermember[2];
$rip   = $lclustermember[4];
if ( $host eq $rhost )
{
	$thost = $rhost;
	$rhost = $lhost;
	$lhost = $thost;
	$tip   = $rip;
	$rip   = $lip;
	$lip   = $tip;
}

#       print "Zen cluster service is UP, Zen GUI should works over ip $lip";
print "<select name=\"ipgui\">\n";

$existiphttp = "false";
if ( $hosthttp =~ /\*/ )
{
	print "<option value=\"*\" selected=\"selected\">--All interfaces--</option>";
	$existiphttp = "true";
}
else
{
	print "<option value=\"*\">--All interfaces--</option>";
}

if ( grep ( /UP/, $lclusterstatus ) )
{
	#cluster active you only can use all interfaces or cluster real ip
	if ( $hosthttp =~ /$lip/ )
	{
		print "<option value=\"$lip\" selected=\"selected\">*cluster $lip</option>";
		$existiphttp = "true";
	}
	else
	{
		print "<option value=\"$lip\">*cluster $lip</option>";
	}
}
else
{
	foreach $file ( @files )
	{
		if ( $file !~ /:/ )
		{
			open FI, "$configdir\/$file";
			@lines = <FI>;
			@line = split ( ":", $lines[0] );
			chomp ( @line );
			if ( $line[4] =~ /up/i )
			{
				chomp ( $line[2] );
				if ( $hosthttp =~ /$line[2]/ )
				{
					print "<option value=\"$line[2]\" selected=\"selected\">$line[0] $line[2]</option>";
				}
				else
				{
					print "<option value=\"$line[2]\">$line[0] $line[2]</option>";
				}
			}
			close FI;
		}
	}
}

print "</select>";

print "<input type=\"submit\" value=\"Save Management IP\" name=\"action\" class=\"button small\">";
print "<input type=\"submit\" value=\"Restart Management Services\" name=\"action\" class=\"button small\">";
print "<br>";
print "<br>";
print "</form>";

#https port for GUI interface
$guiport = &getGuiPort( $confhttp );
if ( $guiport =~ /^$/ )
{
	$guiport = 444;
}
print "<b>HTTPS Port where is running GUI service.</b><font size=\"1\"> Default is 444. Changes need restart GUI service.</font>";
print "<form method=\"get\" action=\"index.cgi\">";
print "<input type=\"hidden\" name=\"id\" value=\"3-1\">";
print "<input type=\"text\" name=\"guiport\" value=\"$guiport\" size=12>";
print "<input type=\"submit\" value=\"Change GUI https port\" name=\"action\" class=\"button small\">";
print "<input type=\"submit\" value=\"Restart GUI Service\" name=\"action\" class=\"button small\">";
print "</form>";
print "<br>";

## START SNMP ##
print "<form method=\"get\" action=\"index.cgi\">";

# set global variables as in config file
( undef, $snmpd_port, $snmpd_community, $snmpd_scope ) = &getSnmpdConfig();

# SNMPD Switch
if ( &getSnmpdStatus() eq "true" )
{
	print "<input type=\"checkbox\" name=\"snmpd_enabled\" value=\"true\" checked>";
}
else
{
	print "<input type=\"checkbox\" name=\"snmpd_enabled\" value=\"true\"> ";
}
print "&nbsp;<b>SNMP Service</b><br>";

# SNMP port
print "<font size=1>Port: </font>";
print "<input type=\"number\" name=\"snmpd_port\" value=\"$snmpd_port\" size=\"5\" min=\"1\" max=\"65535\" required>";
print "<br>";

# SNMP community
print "<font size=1>Community name: </font>";
print "<input type=\"text\" name=\"snmpd_community\" value=\"$snmpd_community\" size=\"12\" required >";
print "<br>";

# IP or subnet with access to SNMP server
print "<font size=1>IP or subnet with access (IP/bit): </font>";
print "<input type=\"text\" name=\"snmpd_scope\" value=\"$snmpd_scope\" size=\"12\" required>";
print "<br>";

print "<input type=\"hidden\" name=\"id\" value=\"3-1\">";
print "<input type=\"hidden\" name=\"action\" value=\"edit-snmp\">";

# Submit
print "<input type=\"submit\" name=\"button\" value=\"Modify\" class=\"button small\">";
print "</form>";
print "<br>";
## END SNMP ##

#dns
print "<b>DNS servers</b>";
print "<br>";
print "<form method=\"get\" action=\"index.cgi\">";
print "<input type=\"hidden\" name=\"id\" value=\"3-1\">";
print "<input type=\"hidden\" name=\"var\" value=\"Save DNS\">";
print "<textarea  name=\"line\" cols=\"30\" rows=\"2\" align=\"center\">";
open FR, "$filedns";
print <FR>;
print "</textarea>";
print "<input type=\"submit\" value=\"Save DNS\" name=\"action\" class=\"button small\">";
print "</form>";

#apt
print "<br>";
print "<b>APT repository</b>";
print "<br>";
print "<form method=\"get\" action=\"index.cgi\">";
print "<input type=\"hidden\" name=\"id\" value=\"3-1\">";
print "<input type=\"hidden\" name=\"var\" value=\"Save APT\">";
print "<textarea  name=\"line\" cols=\"60\" rows=\"6\" align=\"center\">";
open FR, "$fileapt";
print <FR>;
print "</textarea>";
print "<input type=\"submit\" value=\"Save APT\" name=\"action\" class=\"button small\">";
print "</form>";

print "</div></div></div>";

print "<br class=\"cl\">";
print "</div><!--Content END--></div></div>";
### END Local configuration ###
