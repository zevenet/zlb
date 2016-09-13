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

$db_hd="hd.rrd";
use RRDs;
require ("/usr/local/zenloadbalancer/config/global.conf");

my @system = `$df_bin -h`;

foreach $line(@system)
	{
	chomp($line);
	if ($line =~ /^\/dev/)
		{
		my @dd_name = split("\ ",$line);
		chomp(@dd_name[0]);
		$dd_name = @dd_name[0];
		$dd_mame =~ s/"\/"/" "/g;
		my @df_system = `$df_bin -k`;
		for $line_df(@df_system)
				{
				if ($line_df =~ /$dd_name/)
					{
					my @s_line = split("\ ",$line_df);
					chomp(@s_line[0]);
					$partition = @s_line[0];
					$size= @s_line[4];
					$mount = @s_line[5];
					$partitions = @s_line[0];
					$partitions =~ s/\///;
					$partitions =~ s/\//-/g;
					#total
					$tot = @s_line[1]*1024;
					$used = @s_line[2]*1024;
					$free = @s_line[3]*1024;
					if (! -f "$rrdap_dir$rrd_dir$partitions$db_hd")
						{
						print "Creating $partiton rrd database in $rrdap_dir$rrd_dir$partitions$db_hd ...\n";
						RRDs::create "$rrdap_dir$rrd_dir$partitions$db_hd",
						"-s 300", 
						"DS:tot:GAUGE:600:0:U",
						"DS:used:GAUGE:600:0:U",
						"DS:free:GAUGE:600:0:U",
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
						if ($ERROR = RRDs::error) { print "$0: unable to generate $partition database: $ERROR\n"};
						}
					#infomation
					print "Information for $partition in $mount  graph ...\n";
                			print "                Total: $tot Bytes\n";
                			print "                used: $used Bytes\n";
                			print "                size: $size Bytes\n";
                			print "                free: $free Bytes\n";
                			##update rrd info
					$size =~ s/%//g;
					print "Updating Informatino in $rrdap_dir$rrd_dir$partitions$db_hd ...\n";
					RRDs::update "$rrdap_dir$rrd_dir$partitions$db_hd",
						"-t", "tot:used:free",
						"N:$tot:$used:$free";

					if ($ERROR = RRDs::error) { print "$0: unable to generate $partition database: $ERROR\n"};

					}
				}
		}
	}

