#!/usr/bin/perl
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

use RRDs;
require ("/usr/local/zenloadbalancer/config/global.conf");
$db_temp="temp.rrd";
#create db memory if not existS
if (! -f "$rrdap_dir$rrd_dir$db_temp" )
	{
	print "Creating temperature rrd data base $rrdap_dir$rrd_dir$db_temp ...\n";
	RRDs::create "$rrdap_dir$rrd_dir$db_temp",
		"-s 300",
		"DS:temp:GAUGE:600:0:100",
        #        "RRA:AVERAGE:0.5:1:288",
        #        "RRA:AVERAGE:0.5:6:2016",
        #        "RRA:AVERAGE:0.5:24:8928",
        #        "RRA:AVERAGE:0.5:288:105120",
        #        "RRA:MIN:0.5:1:288",
        #        "RRA:MIN:0.5:6:2016",
        #        "RRA:MIN:0.5:24:8928",
        #        "RRA:MIN:0.5:288:105120",
        #        "RRA:MAX:0.5:1:288",
        #        "RRA:MAX:0.5:6:2016",
        #        "RRA:MAX:0.5:24:8928",
        #        "RRA:MAX:0.5:288:105120";
		"RRA:LAST:0.5:1:288",		# daily - every 5 min - 288 reg
		"RRA:MIN:0.5:1:288",		# daily - every 5 min - 288 reg
		"RRA:AVERAGE:0.5:1:288",	# daily - every 5 min - 288 reg
		"RRA:MAX:0.5:1:288",		# daily - every 5 min - 288 reg
		"RRA:LAST:0.5:12:168",		# weekly - every 1 hour - 168 reg
		"RRA:MIN:0.5:12:168",		# weekly - every 1 hour - 168 reg
		"RRA:AVERAGE:0.5:12:168",	# weekly - every 1 hour - 168 reg
		"RRA:MAX:0.5:12:168",		# weekly - every 1 hour - 168 reg
		"RRA:LAST:0.5:96:93",		# monthly - every 8 hours - 93 reg
		"RRA:MIN:0.5:96:93",		# monthly - every 8 hours - 93 reg
		"RRA:AVERAGE:0.5:96:93",	# monthly - every 8 hours - 93 reg
		"RRA:MAX:0.5:96:93",		# monthly - every 8 hours - 93 reg
		"RRA:LAST:0.5:288:372",		# yearly - every 1 day - 372 reg
		"RRA:MIN:0.5:288:372",		# yearly - every 1 day - 372 reg
		"RRA:AVERAGE:0.5:288:372",	# yearly - every 1 day - 372 reg
		"RRA:MAX:0.5:288:372";		# yearly - every 1 day - 372 reg
	}

if (-f "/proc/acpi/thermal_zone/THRM/temperature")
	{
	open FT,"/proc/acpi/thermal_zone/THRM/temperature";
        while ($line=<FT>)
                {
                $lastline = $line;
                }
	my @lastlines = split("\:",$lastline);
	close FT;
	$temp = @lastlines[1];
	$temp =~ s/\ //g;
	$temp =~ s/\n//g;
	$temp =~ s/C//g;

	print "Information for Temperature graph ...\n";
	print "		Temperature: $temp C\n";
	}	
	else
	{
	print "Error /proc/acpi/thermal_zone/THRM/temperature not exist, please install sensors or change proc file where is cpu temperature...\n";
	exit 1;
	}
#update rrd info
print "Updating Information in $rrdap_dir$rrd_dir$db_temp ...\n";		
RRDs::update "$rrdap_dir$rrd_dir$db_temp",
	"-t", "temp",
	"N:$temp";

#size graph
$weidth="500";
$height="150";
#create graphs
#1 day
$last =  RRDs::last "$rrdap_dir$rrd_dir$db_temp";


@time=("d","w","m","y");
foreach $time_graph(@time)
	{

	$graph = $basedir.$img_dir."temp_".$time_graph.".png";
	print "Creating graph in $graph ...\n";
	#print "creating graph" .$rrd_dir.$png_mem. "...\n";

	#print "Creating image 1".$time_graph." ".$rrd_dir.$png_mem.$time_graph." ...\n";
	RRDs::graph ("$graph",
		"--imgformat=PNG",
		"--start=-1$time_graph",
		"--width=$width",
		"--height=$height",  
		"--alt-autoscale-max",
		"--lower-limit=0",
		"--vertical-label=CPU TEMPERATURE",
		"DEF:temp=$rrdap_dir$rrd_dir$db_temp:temp:AVERAGE",
		"AREA:temp#AAA8E4:CPU temperature", 
				"GPRINT:temp:LAST:Last\\:%4.0lf C", 
				"GPRINT:temp:MIN:Min\\:%4.0lf C",  
				"GPRINT:temp:AVERAGE:Avg\\:%4.0lf C",  
				"GPRINT:temp:MAX:Max\\:%4.0lf C\\n");
		if ($ERROR = RRDs::error) { print "$0: unable to generate $graph: $ERROR\n"};
	}
