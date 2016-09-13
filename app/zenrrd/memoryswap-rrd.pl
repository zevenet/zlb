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
$db_memsw="memsw.rrd";
#create db memory if not existS
if (! -f "$rrdap_dir$rrd_dir$db_memsw" )

	{
	print "Creating memory swap rrd data base $rrdap_dir$rrd_dir$db_memsw ...\n";
	RRDs::create "$rrdap_dir$rrd_dir$db_memsw",
		"-s 300",
		"DS:swt:GAUGE:600:0:U",
		"DS:swu:GAUGE:600:0:U",
		"DS:swf:GAUGE:600:0:U",
		"DS:swc:GAUGE:600:0:U",
	#	"RRA:AVERAGE:0.5:1:288",    
	#	"RRA:AVERAGE:0.5:6:2016",    
	#	"RRA:AVERAGE:0.5:24:8928",  
	#	"RRA:AVERAGE:0.5:288:105120",  
	#	"RRA:MIN:0.5:1:288",        
	#	"RRA:MIN:0.5:6:2016",        
	#	"RRA:MIN:0.5:24:8928",       
	#	"RRA:MIN:0.5:288:105120",     
	#	"RRA:MAX:0.5:1:288",       
	#	"RRA:MAX:0.5:6:2016",        
	#	"RRA:MAX:0.5:24:8928",       
	#	"RRA:MAX:0.5:288:105120";
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
	if ($ERROR = RRDs::error) { print "$0: unable to generate $rrdap_dir$rrd_dir$db_memsw: $ERROR\n"};
	}

#information
if (-f "/proc/meminfo")
	{
	open FR,"/proc/meminfo";
	while ($line=<FR>)
		{
		if ($line =~ /swaptotal/i)
			{
			my @memtotal = split(": ",$line);
			$mvalue = @memtotal[1]*1024;
			}
		if ($line =~ /swapfree/i)
			{
			my @memfree = split(": ",$line);
			$mfvalue = @memfree[1]*1024;
			}
		if ($mvalue && $mfvalue)
			{
			$mused = $mvalue-$mfvalue;
			}
		if ($line =~ /^swapcached/i)
			{
			my @memcached = split(": ",$line);
			$mcvalue = @memcached[1]*1024;
			}
		
		}
	
print "Information for swap memory graph ...\n";
	print "		Total Memory Swap: $mvalue Bytes\n";
	print "		Used Memory Swap: $mused Bytes\n";
	print "		Free Memory Swap: $mfvalue Bytes\n";
	print "		Cached Memory Swap: $mcvalue Bytes\n";
	}
	else
	{
	print "Error /proc/meminfo not exist...";
	exit 1;
	}

#update rrd info
print "Updating Information in $rrdap_dir$rrd_dir$db_memsw ...\n";		
RRDs::update "$rrdap_dir$rrd_dir$db_memsw",
	"-t", "swt:swu:swf:swc",
	"N:$mvalue:$mused:$mfvalue:$mcvalue";

#$last =  RRDs::last "$rrdap_dir$rrd_dir$db_memsw";



