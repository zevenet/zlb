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


$db_if="iface.rrd";
#my @system = `$ifconfig_bin -a`;
my @system = `$ifconfig_bin`;

$is_if=0;
foreach $line(@system)
	{
	chomp($line);
	if ($line =~ /^[a-z]/ && $line !~ /^lo/)
		{
		my @if_name = split("\ ",$line);
		chomp(@if_name[0]);
		$if_name = @if_name[0];
		$is_if = 1;
		}	
	if ($is_if && $line =~ /rx bytes/i)
		{
		my @s_line = split(":",$line);
		my @rx = split("\ ",@s_line[1]);
		my @tx = split("\ ",@s_line[2]);
		$in = @rx[0];
		$out = @tx[0];
		$is_if = 0;
		#process if_name
		if (! -f "$rrdap_dir$rrd_dir$if_name$db_if")		
			{
			print "Creating traffic rrd database for $if_name $rrdap_dir$rrd_dir$if_name$db_if ...\n";
			RRDs::create "$rrdap_dir$rrd_dir$if_name$db_if",
                        	"-s 300",
                        	"DS:in:DERIVE:600:0:12500000",
                        	"DS:out:DERIVE:600:0:12500000",
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

			if ($ERROR = RRDs::error) { print "$0: unable to generate $if_name database: $ERROR\n"};
			}
		print "Information for $if_name interface graph ...\n";
		print "		in: $in\n";
		print "		out: $out\n";
		#update rrd info
		print "Updating Informatino in $rrdap_dir$rrd_dir$if_name$db_if ...\n";
		RRDs::update "$rrdap_dir$rrd_dir$if_name$db_if",
			"-t", "in:out",
			"N:$in:$out";
		
		#end process rrd for $if_name
		}
	if ($line =~ /^$/)
		{
		#line is blank
		$is_if = 0;
		}
	}


