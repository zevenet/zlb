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

my $s = IO::Socket::INET->new( Proto => 'udp' );
my $flags = $s->if_flags( $if );

$hwaddr = $s->if_hwaddr( $if );
if ( $flags & IFF_RUNNING )
{
	$state = "up";
}
else
{
	$state = "down";
}

if ( $source eq "system" && $state eq "up" )
{

	# Reading from system
	$ifmsg     = "The interface is running, getting config from system...";
	$state     = "up";
	$ipaddr    = $s->if_addr( $if );
	$netmask   = $s->if_netmask( $if );
	$broadcast = $s->if_broadcast( $if );

	#	$iface = "eth0.50:2";
	# Calculate VLAN
	@fiface = split ( /:/,  $if );
	@viface = split ( /\./, $fiface[0] );
	$vlan   = $viface[1];
	$gwaddr = &getDefaultGW( $if );
}
else
{

	# Reading from config files
	$ifmsg = "The interface is down, getting config from system files...";
	$state = "down";

	# Calculate VLAN
	@fiface = split ( /\:/, $if );
	@viface = split ( /\./, $fiface[0] );
	$vlan   = $viface[1];

	# Reading Config File
	$file = "$configdir/if_$if\_conf";
	tie @array, 'Tie::File', "$file", recsep => ':';
	$ipaddr  = $array[2];
	$netmask = $array[3];
	$state   = $array[4];
	$gwaddr  = $array[5];
	untie @array;
}

print "<div class=\"container_12\">";

#print "<div class=\"grid_12\">";
print "<div class=\"box-header\">Edit a new network interface</div>";
print "<div class=\"box stats\">";
print "<div class=\"row\">";

print "<form method=\"get\" action=\"index.cgi\">";
print "<input type=\"hidden\" name=\"id\" value=\"$id\">";
print "<input type=\"hidden\" name=\"if\" value=\"$if\">";
print "<input type=\"hidden\" name=\"status\" value=\"$status\">";
print "<div>$ifmsg<br><br></div>";
print "<b>Interface Name: </b>";
print "$if<br><br>";
print "<b>HWaddr: </b>";
print "$hwaddr<br><br>";
print "<b>IP Addr: </b>";
print "<input type=\"text\" value=\"$ipaddr\" size=\"15\" name=\"newip\"><br><br>";
print "<b>Netmask: </b>";
print "<input type=\"text\" value=\"$netmask\" size=\"15\" name=\"netmask\"><br><br>";
print "<b>Broadcast: </b>";

if ( $broadcast eq "" )
{
	print " -<br><br>";
}
else
{
	print "$broadcast<br><br>";
}
print "<b>Default Gateway: </b>";
if ( $if =~ /\:/ )
{
	if ( $gwaddr eq "" )
	{
		print " -<br><br>";
	}
	else
	{
		my @splif = split ( "\:", $if );
		my $ifused = &uplinkUsed( @splif[0] );
		if ( $ifused eq "false" )
		{
			print "$gwaddr<br><br>";
		}
		else
		{
			print "<img src=\"img/icons/small/lock.png\" title=\"A datalink farm is locking the gateway of this interface\"><br><br>";
		}
	}
}
else
{
	my $ifused = &uplinkUsed( $if );
	if ( $ifused eq "false" )
	{
		print "<input type=\"text\" value=\"$gwaddr\" size=\"15\" name=\"gwaddr\"><br><br>";
	}
	else
	{
		print "<img src=\"img/icons/small/lock.png\" title=\"A datalink farm is locking the gateway of this interface\"><br><br>";
	}
}
print "<b>Vlan tag: </b>";
if ( $vlan eq "" )
{
	print " -<br><br>";
}
else
{
	print "$vlan<br><br>";
}
print "</select><br>";

#print "<input type=\"submit\" value=\"Save Config\" name=\"action\" class=\"button small\">";
print "<input type=\"submit\" value=\"Save & Up!\" name=\"action\" class=\"button small\">";
print "<input type=\"submit\" value=\"Cancel\" name=\"action\" class=\"button small\">";
print "</form>";
print "</div>";

#print "</div></div></div>";
print "</div></div>";

#print "<br class=\"cl\">";
print "<div id=\"page-header\"></div>";
