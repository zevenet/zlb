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

$globalcfg = "/usr/local/zenloadbalancer/config/global.conf";

require "/usr/local/zenloadbalancer/www/farms_functions.cgi";
require "/usr/local/zenloadbalancer/www/networking_functions.cgi";
require "/usr/local/zenloadbalancer/www/nf_functions.cgi";
require "/usr/local/zenloadbalancer/www/cluster_functions.cgi";
require "/usr/local/zenloadbalancer/www/rrd_functions.cgi";
require "/usr/local/zenloadbalancer/www/cert_functions.cgi";
require "/usr/local/zenloadbalancer/www/l4_functions.cgi";
require "/usr/local/zenloadbalancer/www/gslb_functions.cgi";
require "/usr/local/zenloadbalancer/www/system_functions.cgi";
require "/usr/local/zenloadbalancer/www/gui_functions.cgi";
require "/usr/local/zenloadbalancer/www/snmp_functions.cgi";

if ( -e "/usr/local/zenloadbalancer/www/zapi_functions.cgi" )
{
	require "/usr/local/zenloadbalancer/www/zapi_functions.cgi";
}

#function that check if variable is a number no float
sub isnumber($num)
{
	( $num ) = @_;
	if ( $num !~ /[^0-9]/ )
	{
		return "true";
	}
	else
	{
		return "false";
	}
}

#check if the string is a valid multiport definition
sub ismport($string)
{
	my ( $string ) = @_;

	chomp ( $string );
	if ( $string eq "*" )
	{
		return "true";
	}
	elsif ( $string =~ /^[0-9]+(,[0-9]+|[0-9]+\:[0-9]+)*$/ )
	{
		return "true";
	}
	else
	{
		return "false";
	}
}

#check if the port has more than 1 port
sub checkmport($port)
{
	( $port ) = @_;

	if ( $port =~ /\,|\:|\*/ )
	{
		return "true";
	}
	else
	{
		return "false";
	}
}

#function that paint a static progess bar
sub progressbar($filename,$vbar)
{
	( $filename, $vbar ) = @_;
	$max = "150";

	# Create a new image
	use GD;
	$im = new GD::Image( $max, 12 );

	$white      = $im->colorAllocate( 255, 255, 255 );
	$blueborder = $im->colorAllocate( 77,  143, 204 );
	$grayborder = $im->colorAllocate( 102, 102, 102 );
	$blue       = $im->colorAllocate( 165, 192, 220 );
	$gray       = $im->colorAllocate( 156, 156, 156 );

	# Make the background transparent and interlaced
	$im->transparent( $white );
	$im->interlaced( 'true' );

	# Draw a border
	$im->rectangle( 0, 0, $max - 1, 11, $grayborder );

	#rectangle
	$im->filledRectangle( 1, 1, $vbar, 10, $grayborder );

	# Open a file for writing
	open ( PICTURE, ">$filename" ) or die ( "Cannot open file for writing" );

	# Make sure we are writing to a binary stream
	binmode PICTURE;

	# Convert the image to PNG and print it to the file PICTURE
	print PICTURE $im->png;
	close PICTURE;

}

#function that paint the date when started (uptime)
sub uptime()
{
	$timeseconds = time ();
	open TIME, '/proc/uptime' or die $!;

	#
	while ( <TIME> )
	{
		my @time = split ( "\ ", $_ );
		$uptimesec = @time[0];
	}

	$totaltime = $timeseconds - $uptimesec;

	#
	#my $time = time;       # or any other epoch timestamp
	my $time = $totaltime;
	my @months = ( "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec" );
	my ( $sec, $min, $hour, $day, $month, $year ) = ( localtime ( $time ) )[0, 1, 2, 3, 4, 5, 6];

	#print "Unix time ".$time." converts to ".$months[$month]." ".$day.", ".($year+1900) ." ". $hour .":".$min.":".$sec."\n";
	return @months[$month] . ", " . $day . " " . $hour . ":" . $min . ":" . $sec . " " . ( $year + 1900 ) . "\n";

}

#function that configure the graphs apareance.
#sub graphs(@data,$description)
sub graphs($description,@data)
{
	( $description, @data ) = @_;
####graph configuration
	#midblue     => { R => 165,  G => 192, B => 220 },
	my %options = (

		#  	'file' => 'img/graphs/mygraph.jpg',
		#	'quality' => '9',
		# colours

		black      => { R => 0,   G => 0,   B => 0 },
		white      => { R => 255, G => 255, B => 255 },
		vltgrey    => { R => 245, G => 245, B => 245 },
		ltgrey     => { R => 230, G => 230, B => 230 },
		midgreen   => { R => 143, G => 184, B => 32 },
		midblue    => { R => 165, G => 192, B => 220 },
		midgray    => { R => 156, G => 156, B => 156 },
		background => { R => 244, G => 244, B => 244 },

		# file output details

		file    => $description,    # file path and name; file extension
		                            # can be .jpg|gif|png
		quality => 9,               # image quality: 1 (worst) - 10 (best)
		                            # Only applies to jpg and png

		# main image properties

		imgw     => 500,            # preferred width in pixels
		imgh     => 250,            # preferred height in pixels
		iplotpad => 8,              # padding between axis vals & plot area
		ipadding => 14,             # padding between other items
		ibgcol   => 'white',        # COLOUR NAME; background colour
		iborder  => '',             # COLOUR NAME; border, if any

		# plot area properties

		plinecol => 'midgrey',      # COLOUR NAME; line colour
		pflcol   => 'ltgrey',       # COLOUR NAME; floor colour
		pbgcol   => 'ltgrey',       # COLOUR NAME; back/side colour
		pbgfill  => 'gradient',     # 'gradient' or 'solid'; back/side fill
		plnspace => 25,             # minimum pixel spacing between divisions
		pnumdivs => 30,             # maximum number of y-axis divisions

		# bar properties

		bstyle      => 'bar',         # 'bar' or 'column' style
		bcolumnfill => 'gradient',    # 'gradient' or 'solid' for columns
		bminspace   => 18,            # minimum spacing between bars
		bwidth      => 18,            # width of bar
		bfacecol    => 'midgray',     # COLOUR NAME or 'random'; bar face,
		                              # 'random' for random bar face colour
		                              # graph title

		ttext    => '',               # title text
		tfont    => '',               # uses gdGiantFont unless a true type
		                              # font is specified
		tsize    => 10,               # font point size
		tfontcol => 'black',          # COLOUR NAME; font colour

		# axis labels

		xltext   => '',               # x-axis label text
		yltext   => '',               # y-axis label text
		lfont    => '',               # uses gdLargeFont unless a true type
		                              # font is specified
		lsize    => 10,               # font point size
		lfontcol => 'midblue',        # COLOUR NAME; font colour

		# axis values

		vfont    => '',               # uses gdSmallFont unless a true type
		                              # font is specified
		vsize    => 8,                # font point size
		vfontcol => 'black',          # COLOUR NAME; font colour

	);

	my $imagemap = creategraph( \@data, \%options );

}

#function that create a menu for certificates actions
sub createMenuFarmCert($fname,$cname)
{

	( $fname, $cname ) = @_;

	print "<input type=\"hidden\" name=\"action\" value=\"changecert\">";
	print "<input type=\"image\" src=\"img/icons/small/accept2.png\" title=\"Change Certificate $certname on farm $farmane\" name=\"action\" value=\"changecert\"> ";
}

#function that create a menu for backup actions
sub createmenubackup($file)
{
	( $file ) = @_;
	print "<a href=\"index.cgi?id=$id&action=apply&file=$file\"><img src=\"img/icons/small/accept2.png\" title=\"Apply $file backup and restart Zen Load Balancer service\"></a> ";
	print "<a href=\"downloads.cgi?filename=$file\"><img src=\"img/icons/small/arrow_down.png\" title=\"Download $file backup\"></a>";
	print "<a href=\"index.cgi?id=$id&action=del&file=$file\" onclick=\"return confirm('Are you sure you wish to delete this backup?')\"><img src=\"img/icons/small/cross_octagon.png\" title=\"Delete $file backup\"></a> ";

}

#function that create a menu where you can enable/disable the server backend in a farm.
sub createmenubackactions($id_server)
{
	( $id_server ) = @_;

	print "<input type=\"image\" src=\"img/icons/small/server_edit.png\" title=\"Edit Real Server $id_server\" name=\"action\" value=\"editfarm-editserver\"> ";
	print "<input type=\"image\" src=\"img/icons/small/server_edit.png\" title=\"Edit Real Server $id_server\" name=\"action\" value=\"editfarm-editserver\"> ";
}

#function that create a menu for configure servers in a farm
sub createmenuserversfarm($action,$name,$id_server)
{

	( $actionmenu, $name, $id_server ) = @_;
	my $type = &getFarmType( $farmname );

	print "<td>";
	if ( $actionmenu eq "normal" )
	{
		print "<input type=\"hidden\" name=\"action\" value=\"editfarm-editserver\">";
		print "<input type=\"image\" src=\"img/icons/small/server_edit.png\" title=\"Edit Real Server $id_server\" name=\"action\" value=\"editfarm-editserver\">";
		my $maintenance = -1;
                #print status of a farm
                if ( &getFarmStatus($name) eq "up" )
                {
			$maintenance = &getFarmBackendMaintenance( $name, $id_server, $sv );
		}
		if ( $type ne "datalink" && $type ne "l4xnat" && $type ne "gslb" )
		{
			if ( $maintenance ne "0" )
			{
				print "<a href=index.cgi?action=editfarm-maintenance&id=1-2&farmname=$name&id_server=$id_server&service=$sv title=\"Enable  maintenance mode for real Server $id_server $sv\" onclick=\"return confirm('Are you sure you want to enable the  maintenance mode for server: $id_server $sv?')\"><img src=\"img/icons/small/server_maintenance.png\"></a>";
			}
			else
			{
				print "<a href=index.cgi?action=editfarm-nomaintenance&id=1-2&farmname=$name&id_server=$id_server&service=$sv title=\"Disable maintenance mode for real Server $id_server $sv\" onclick=\"return confirm('Are you sure you want to disable the maintenance mode for server: $id_server $sv?')\"><img src=\"img/icons/small/server_ok.png\"></a>";
			}
		}

		my $sv20 = $sv;
		$sv20 =~ s/\ /%20/g;

		if ( $type eq "gslb" )
		{
			if ( $id_server ne "primary" && $id_server ne "secondary" )
			{
				print "<a href=index.cgi?action=editfarm-deleteserver&id=1-2&farmname=$name&id_server=$id_server&service=$sv20&service_type=$service_type title=\"Delete Real Server $id_server\" onclick=\"return confirm('Are you sure you want to delete the server: $id_server?')\"><img src=\"img/icons/small/server_delete.png\"></a>";
			}
		}
		else
		{
			print "<a href=index.cgi?action=editfarm-deleteserver&id=1-2&farmname=$name&id_server=$id_server&service=$sv20 title=\"Delete Real Server $id_server\" onclick=\"return confirm('Are you sure you want to delete the server: $id_server?')\"><img src=\"img/icons/small/server_delete.png\"></a>";
		}

	}

	if ( $actionmenu eq "add" )
	{
		print "<input type=\"hidden\" name=\"action\" value=\"editfarm-saveserver\">";
		print "<input type=\"image\" src=\"img/icons/small/server_save.png\"  title=\"Save Real Server $id_server\" name=\"action\" value=\"editfarm-saveserver\"> ";

		#print "<input type=\"image\" src=\"img/icons/small/server_out.png\" title=\"Cancel edit Real Server\" name=\"editfarm\" value=\"editfarm\"> ";
		print "<a href=index.cgi?id=1-2&action=editfarm&farmname=$farmname><img src=\"img/icons/small/server_out.png\"></a>";
	}

	if ( $actionmenu eq "new" )
	{
		print "<input type=\"hidden\" name=\"action\" value=\"editfarm-addserver\">";
		print "<input type=\"image\" src=\"img/icons/small/server_add.png\" title=\"Add Real Server\" name=\"action\" value=\"editfarm-addserver\"> ";
	}

	if ( $actionmenu eq "edit" )
	{
		print "<input type=\"hidden\" name=\"action\" value=\"editfarm-saveserver\">";
		print "<input type=\"image\" src=\"img/icons/small/server_save.png\" title=\"Save Real Server $id_server\" name=\"action\" value=\"editfarm-saveserver\"> ";

		#print "<input type=\"image\" src=\"img/icons/small/server_out.png\" title=\"Cancel edit Real Server\" name=\"editfarm\" value=\"editfarm\"> ";
		print "<a href=index.cgi?id=1-2&action=editfarm&farmname=$farmname><img src=\"img/icons/small/server_out.png\"></a>";
	}

	print "</td>";
}

sub upload()
{
	print "<script language=\"javascript\">
                var popupWindow = null;
                function positionedPopup(url,winName,w,h,t,l,scroll)
                {
                settings ='height='+h+',width='+w+',top='+t+',left='+l+',scrollbars='+scroll+',resizable'
                popupWindow = window.open(url,winName,settings)
                }
        </script>";

	#print the information icon with the popup with info.
	print "<a href=\"upload.cgi\" onclick=\"positionedPopup(this.href,'myWindow','500','300','100','200','yes');return false\"><img src='img/icons/small/arrow_up.png' title=\"upload backup\"></a>";
}

sub uploadcerts()
{
	print "<script language=\"javascript\">
                var popupWindow = null;
                function positionedPopup(url,winName,w,h,t,l,scroll)
                {
                settings ='height='+h+',width='+w+',top='+t+',left='+l+',scrollbars='+scroll+',resizable'
                popupWindow = window.open(url,winName,settings)
                }
        </script>";

	#print the information icon with the popup with info.
	print "<a href=\"uploadcerts.cgi\" onclick=\"positionedPopup(this.href,'myWindow','500','300','100','200','yes');return false\"><img src='img/icons/small/arrow_up.png' title=\"upload certificate\"></a>";
}

#function that put a popup with help about the product
sub help($cod)
{

	#code
	( $cod ) = @_;

	#this is javascript emmbebed in perl
	print "<script language=\"javascript\">
                var popupWindow = null;
                function positionedPopup(url,winName,w,h,t,l,scroll)
                {
                settings ='height='+h+',width='+w+',top='+t+',left='+l+',scrollbars='+scroll+',resizable'
                popupWindow = window.open(url,winName,settings)
                }
        </script>";

	#print the information icon with the popup with info.
	print "<a href=\"help.cgi?id=$cod\" onclick=\"positionedPopup(this.href,'myWindow','500','300','100','200','yes');return false\"><img src='img/icons/small/information.png'></a>";
}

#function that create the menu for manage the vips in Farm Table
sub createmenuvip($name,$id,$status)
{
	( $name, $id, $status ) = @_;
	if ( $status eq "up" )
	{
		print "<a href=\"index.cgi?id=$id&action=stopfarm&farmname=$name\" onclick=\"return confirm('Are you sure you want to stop the farm: $name?')\"><img src=\"img/icons/small/farm_delete.png\" title=\"Stop the $name Farm\"></a> ";
		print "<a href=\"index.cgi?id=$id&action=editfarm&farmname=$name\"><img src=\"img/icons/small/farm_edit.png\" title=\"Edit the $name Farm\"></a> ";
	}
	else
	{
		print "<a href=\"index.cgi?id=$id&action=startfarm&farmname=$name\"><img src=\"img/icons/small/farm_up.png\" title=\"Start the $name Farm\"></a> ";
		print "<a href=\"index.cgi?id=$id&action=editfarm&farmname=$name\"><img src=\"img/icons/small/farm_edit.png\" title=\"Edit the $name Farm\"></a> ";
	}
	print "<a href=\"index.cgi?id=$id&action=deletefarm&farmname=$name\" onclick=\"return confirm('Are you sure you wish to delete the farm: $name?')\"><img src=\"img/icons/small/farm_cancel.png\" title=\"Delete the $name Farm\"></a> ";
}

#Create menu for Actions in Conns stats
sub createmenuvipstats($name,$id,$status,$type)
{
	my ( $name, $id, $status, $type ) = @_;

	print "<a href=\"index.cgi?id=2-1&action=$name-farm\" \">
		<img src=\"img/icons/small/chart_bar.png\"
			title=\"Show connection graphs for Farm $name\"></a> ";

	if ( $status eq "up" && $type ne "gslb" )
	{
		print "<a href=\"index.cgi?id=1-2&action=managefarm&farmname=$name\"><img src=\"img/icons/small/connect.png\" title=\"View $name backends status\"></a> ";
	}
}

#
#
#
sub createmenuGW($id,$action)
{
	( $id, $action ) = @_;
	if ( $action =~ /editgw/ )
	{
		print "<input type=\"hidden\" name=\"action\" value=\"editgw\">";
		print "<input type=\"image\" src=\"img/icons/small/disk.png\" onclick=\"submit();\" name=\"action\" type=\"submit\" value=\"editgw\" title=\"save default gw\">";
		print " <a href=\"index.cgi?id=$id\"><img src=\"img/icons/small/arrow_left.png\" title=\"cancel operation\"></a> ";
	}
	else
	{
		print "<a href=\"index.cgi?id=$id&action=editgw\"><img src=\"img/icons/small/pencil.png\" title=\"edit default GW\"/></a>";
		print "&nbsp";
		print "<a href=\"index.cgi?id=$id&action=deletegw\" onclick=\"return confirm('Are you sure you wish to delete the default gateway?')\"><img src=\"img/icons/small/delete.png\" title=\"delete default GW\"/></a> ";
	}
}

#
#function create menu for interfaces in id 3-2
#
sub createmenuif($if, $id, $configured, $state)
{
	use IO::Socket;
	use IO::Interface qw(:flags);

	my $s = IO::Socket::INET->new( Proto => 'udp' );
	my @interfaces = $s->if_list;

	( $if, $id, $configured, $state ) = @_;
	$clrip = &clrip();
	$guiip = &GUIip();
	$clvip = &clvip();

	print "<td>";
	$ip     = $s->if_addr( $if );
	$source = "";
	$locked = "false";

	if ( -e $filecluster )
	{
		open FC, "<$filecluster";
		@filecl = <FC>;
		if ( grep ( /$ip/, @filecl ) && $ip !~ /^$/ )
		{
			$locked = "true";
		}
		if ( grep ( /$if$/, @filecl ) )
		{
			$locked = "true";
		}
	}
	if ( $ip !~ /^$/ && ( ( $ip eq $clrip ) || ( $ip eq $guiip ) ) )
	{
		$locked = "true";
	}

	if ( ( $status eq "up" ) && ( $ip ne $clrip ) && ( $ip ne $guiip ) )
	{
		if ( $locked eq "false" )
		{
			print "<a href=\"index.cgi?id=$id&action=downif&if=$if\" onclick=\"return confirm('Are you sure you wish to shutdown the interface: $if?')\"><img src=\"img/icons/small/plugin_stop.png\" title=\"down network interface\"></a> ";
			$source = "system";
		}
	}
	else
	{
		if ( $status eq "down" )
		{
			if ( $locked eq "false" )
			{
				print "<a href=\"index.cgi?id=$id&action=upif&if=$if\"><img src=\"img/icons/small/plugin_upn.png\" title=\"up network interface\"></a> ";
				$source = "files";
			}
		}
	}

	if ( ( ( $ip ne $clrip ) && ( $ip ne $guiip ) ) || !$ip )
	{
		if ( $locked eq "false" )
		{
			print "<a href=\"index.cgi?id=$id&action=editif&if=$if&toif=$if&source=$source&status=$status\"><img src=\"img/icons/small/plugin_edit.png\" title=\"edit network interface\"></a> ";
		}
	}

	if ( $if =~ /\:/ )
	{

		#virtual interface
		if ( $locked eq "false" )
		{
			print "<a href=\"index.cgi?id=$id&action=deleteif&if=$if\" onclick=\"return confirm('Are you sure you wish to delete the virtual interface: $if?')\"><img src=\"img/icons/small/plugin_delete.png\" title=\"delete network interface\"></a> ";
		}
	}
	else
	{

		# Physical interface
		#	if ( $configured == 1 ) {
		if ( $if =~ /\./ )
		{
			if ( $locked eq "false" )
			{
				print "<a href=\"index.cgi?id=$id&action=addvip&toif=$if\"><img src=\"img/icons/small/pluginv_add.png\" title=\"add virtual network interface\"></a> ";
				print "<a href=\"index.cgi?id=$id&action=deleteif&if=$if\" onclick=\"return confirm('Are you sure you wish to delete the physical interface: $if?')\"><img src=\"img/icons/small/plugin_delete.png\" title=\"delete network interface\"></a> ";
			}
		}
		else
		{
			print "<a href=\"index.cgi?id=$id&action=addvip&toif=$if\"><img src=\"img/icons/small/pluginv_add.png\" title=\"add virtual network interface\"></a> ";
			print "<a href=\"index.cgi?id=$id&action=addvlan&toif=$if\"><img src=\"img/icons/small/plugin_add.png\" title=\"add vlan network interface\"></a> ";
			if ( $locked eq "false" )
			{
				print "<a href=\"index.cgi?id=$id&action=deleteif&if=$if\" onclick=\"return confirm('Are you sure you wish to delete the physical interface: $if?')\"><img src=\"img/icons/small/plugin_delete.png\" title=\"delete network interface\"></a> ";
			}
		}

		#	}

		#	print "</td>";
	}

	if ( $locked eq "true" )
	{
		print "&nbsp&nbsp&nbsp&nbsp<img src=\"img/icons/small/lock.png\" title=\"some actions are locked\">";
	}

	print "</td>";
}

#
#function that print a OK message
#
sub successmsg($string)
{
	my ( $string ) = @_;
	print "<div class=\"notification success\"> <span class=\"strong\">SUCCESS!</span> $string.</div>";

	#print "<div class=\"notification success\"> <span class=\"strong\">SUCCESS!</span> $string. <a href='index.cgi?id=$id'><img src='img/icons/small/cross.png' title='accept'></a></div>";
	&logfile( $string );
}

#function that print a TIP message
sub tipmsg($string)
{
	my ( $string ) = @_;
	print "<div class=\"notification tip\"> <span class=\"strong\">TIP!</span> $string. Restart HERE! <a href='index.cgi?id=$id&farmname=$farmname&action=editfarm-restart'><img src='img/icons/small/arrow_refresh.png' title='restart'></a></div>";
	&logfile( $string );
}

#function that print a WARNING message
sub warnmsg($string)
{
	my ( $string ) = @_;
	print "<div class=\"notification warning\"> <span class=\"strong\">WARNING!</span> $string.</div>";

	#print "<div class=\"notification warning\"> <span class=\"strong\">WARNING!</span> $string. <a href='index.cgi?id=$id'><img src='img/icons/small/warning.png' title='accept'></a></div>";
	&logfile( $string );
}

#
#function that print a ERROR message
#
sub errormsg($string)
{
	my ( $string ) = @_;
	print "<div class=\"notification error\"> <span class=\"strong\">ERROR!</span> $string.</div>";

	#print "<div class=\"notification error\"> <span class=\"strong\">ERROR!</span> $string. <a href='index.cgi?id=$id'><img src='img/icons/small/cross.png' title='accept'></a></div>";
	&logfile( $string );
}

#insert info in log file
sub logfile($string)
{
	my ( $string ) = @_;
	my $date = `date`;
	$date =~ s/\n//g;
	open FO, ">> $logfile";
	print FO "$date - $ENV{'SERVER_NAME'} - $ENV{'REMOTE_ADDR'} - $ENV{'REMOTE_USER'} - $string\n";
	close FO;
}

#
#no remove this
1
