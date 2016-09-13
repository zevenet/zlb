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

#get ip GUI
sub GUIip()
{
	open FO, "<$confhttp";
	@file  = <FO>;
	$guiip = @file[0];
	@guiip = split ( "=", $guiip );
	chomp ( @guiip );
	@guiip[1] =~ s/\ //g;
	return @guiip[1];

}

#function that read the https port for GUI
sub getGuiPort($minihttpdconf)
{
	( $minihttpdconf ) = @_;
	open FR, "<$minihttpdconf";
	@minihttpdconffile = <FR>;
	my @guiportline = split ( "=", @minihttpdconffile[1] );
	close FR;
	return @guiportline[1];
}

#function that write the https port for GUI
sub setGuiPort($httpsguiport,$minihttpdconf)
{
	( $httpsguiport, $minihttpdconf ) = @_;
	$httpsguiport =~ s/\ //g;
	use Tie::File;
	tie @array, 'Tie::File', "$minihttpdconf";
	@array[1] = "port=$httpsguiport\n";
	untie @array;
}

#function that create the menu for manage the vips in HTTP Farm Table
sub createmenuviph($name,$pid,$fproto)
{
	( $name, $id, $farmprotocol ) = @_;

	if ( $pid =~ /^[1-9]/ )
	{
		print "<a href=\"index.cgi?id=$id&action=stopfarm&farmname=$name\" onclick=\"return confirm('Are you sure you want to stop the farm: $name?')\"><img src=\"img/icons/small/farm_delete.png\" title=\"Stop the $name Farm\"></a> ";
		print "<a href=\"index.cgi?id=$id&action=editfarm&farmname=$name\"><img src=\"img/icons/small/farm_edit.png\" title=\"Edit the $name Farm\"></a> ";
	}
	else
	{
		print "<a href=\"index.cgi?id=$id&action=startfarm&farmname=$name\"><img src=\"img/icons/small/farm_up.png\" title=\"Start the $name Farm\"></a> ";
		print "<a href=\"index.cgi?id=$id&action=editfarm&farmname=$name\"><img src=\"img/icons/small/farm_edit.png\" title=\"Edit the $name Farm\"></a> ";
	}
	print "<a href=\"index.cgi?id=$id&action=deletefarm&farmname=$name\"><img src=\"img/icons/small/farm_cancel.png\" title=\"Delete the $name Farm\" onclick=\"return confirm('Are you sure you want to delete the farm: $name?')\"></a> ";

}

#function that create the menu for delete, move a service in a http[s] farm
sub createmenuservice($fname,$sv,$pos)
{
	my ( $fname, $sv, $pos ) = @_;
	my $serv20   = $sv;
	my $serv     = $sv;
	my $filefarm = &getFarmFile( $fname );
	use Tie::File;
	tie @array, 'Tie::File', "$configdir/$filefarm";
	my @output = grep { /Service/ } @array;
	untie @array;
	$serv20 =~ s/\ /%20/g;
	print "<a href=index.cgi?id=1-2&action=editfarm-deleteservice&service=$serv20&farmname=$farmname><img src=\"img/icons/small/cross_octagon.png \" title=\"Delete service $svice\" onclick=\"return confirm('Are you sure you want to delete the Service $serv?')\" ></a> ";

}

#Refresh stats
sub refreshstats()
{
	print "<form method=\"get\" action=\"index.cgi\">";
	print "<b>Refresh stats every</b><input type=\"hidden\" name=\"id\" value=\"$id\">";
	print "<select name=\"refresh\" onchange=\"this.form.submit()\">";
	print "<option value=\"Disabled\"> - </option>\n";
	if ( $refresh eq "10" )
	{
		print "<option value=\"10\" selected>10</option>\n";
	}
	else
	{
		print "<option value=\"10\">10</option>\n";
	}
	if ( $refresh eq "30" )
	{
		print "<option value=\"30\" selected>30</option>\n";
	}
	else
	{
		print "<option value=\"30\">30</option>\n";
	}
	if ( $refresh eq "60" )
	{
		print "<option value=\"60\" selected>60</option>\n";
	}
	else
	{
		print "<option value=\"60\">60</option>\n";
	}
	if ( $refresh eq "120" )
	{
		print "<option value=\"120\" selected>120</option>\n";
	}
	else
	{
		print "<option value=\"120\">120</option>\n";
	}

	print "</select> <b>secs</b>, <font size=1>It can overload the zen server</font>";

	print "<input type=\"hidden\" name=\"farmname\" value=\"$farmname\">";
	print "<input type=\"hidden\" name=\"viewtableclients\" value=\"$viewtableclients\">";
	print "<input type=\"hidden\" name=\"viewtableconn\" value=\"$viewtableconn\">";
	print "<input type=\"hidden\" value=\"managefarm\" name=\"action\" class=\"button small\">";

	#print "<input type=\"submit\" value=\"Submit\" name=\"button\" class=\"button small\">";
	print "</form>";
}

#
#no remove this
1
