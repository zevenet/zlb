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

$db_cpu="cpu.rrd";
$interval=1;
if (-f "/proc/stat")
	{
	open FR,"/proc/stat";
	foreach $line(<FR>)
		{
		if ($line =~ /^cpu\ /)
			{
			my @line_s = split ("\ ",$line);
			$cpu_user1= @line_s[1];
			$cpu_nice1= @line_s[2];
			$cpu_sys1= @line_s[3];
			$cpu_idle1= @line_s[4];
			$cpu_iowait1= @line_s[5];
			$cpu_irq1= @line_s[6];
			$cpu_softirq1= @line_s[7];
			$cpu_total1=$cpu_user1 + $cpu_nice1 + $cpu_sys1 + $cpu_idle1 + $cpu_iowait1 + $cpu_irq1 + $cpu_softirq1
			}
		}
	close FR;
	open FR,"/proc/stat";
	sleep $interval;
	foreach $line(<FR>)
		{
		if ($line =~ /^cpu\ /)
			{
			@line_s = split ("\ ",$line);
			$cpu_user2= @line_s[1];
                        $cpu_nice2= @line_s[2];
                        $cpu_sys2= @line_s[3];
                        $cpu_idle2= @line_s[4];
                        $cpu_iowait2= @line_s[5];
                        $cpu_irq2= @line_s[6];
                        $cpu_softirq2= @line_s[7];
                        $cpu_total2=$cpu_user2 + $cpu_nice2 + $cpu_sys2 + $cpu_idle2 + $cpu_iowait2 + $cpu_irq2 + $cpu_softirq2
			}

		}
	close FR;
	$diff_cpu_user = $cpu_user2 - $cpu_user1;
	$diff_cpu_nice = $cpu_nice2 - $cpu_nice1;
	$diff_cpu_sys = $cpu_sys2 - $cpu_sys1;
	$diff_cpu_idle = $cpu_idle2 - $cpu_idle1;
	$diff_cpu_iowait = $cpu_iowait2 - $cpu_iowait1;
	$diff_cpu_irq = $cpu_irq2 - $cpu_irq1;
	$diff_cpu_softirq = $cpu_softirq2 - $cpu_softirq1;
	$diff_cpu_total = $cpu_total2 - $cpu_total1;
	
	$cpu_user = (100*$diff_cpu_user)/$diff_cpu_total;
	$cpu_nice = (100*$diff_cpu_nice)/$diff_cpu_total;
	$cpu_sys = (100*$diff_cpu_sys)/$diff_cpu_total;
	$cpu_idle = (100*$diff_cpu_idle)/$diff_cpu_total;
	$cpu_iowait = (100*$diff_cpu_iowait)/$diff_cpu_total;
	$cpu_irq = (100*$diff_cpu_irq)/$diff_cpu_total;
	$cpu_softirq = (100*$diff_cpu_softirq)/$diff_cpu_total;
#	$cpu_total = (100*$diff_cpu_total)/$diff_cpu_total;
	$cpu_usage = $cpu_user + $cpu_nice + $cpu_sys + $cpu_iowait + $cpu_irq + $cpu_softirq;
		
	}
	else
	{
	print "File /proc/stat not exist ...\n";
	exit 1;
	
	}
	$cpu_user = sprintf("%.2f",$cpu_user);
	$cpu_nice = sprintf("%.2f",$cpu_nice);
	$cpu_sys = sprintf("%.2f",$cpu_sys);
	$cpu_iowait = sprintf("%.2f",$cpu_iowait);
	$cpu_irq = sprintf("%.2f",$cpu_irq);
	$cpu_softirq = sprintf("%.2f",$cpu_softirq);
	$cpu_idle = sprintf("%.2f",$cpu_idle);
	$cpu_usage = sprintf("%.2f",$cpu_usage);
	
	$cpu_user =~ s/,/\./g;
	$cpu_nice =~ s/,/\./g;
	$cpu_sys =~ s/,/\./g;
	$cpu_iowait =~ s/,/\./g;
	$cpu_softirq =~ s/,/\./g;
	$cpu_idle =~ s/,/\./g;
        $cpu_usage =~ s/,/\./g;



#end recovery information
use RRDs;
require ("/usr/local/zenloadbalancer/config/global.conf");

if (! -f "$rrdap_dir$rrd_dir$db_cpu" )
	{
	print "Creating cpu rrd data base $rrdap_dir$rrd_dir$db_cpu ...\n";
	RRDs::create "$rrdap_dir$rrd_dir$db_cpu",
		"-s 300",
		"DS:user:GAUGE:600:0,00:100,00",
		"DS:nice:GAUGE:600:0,00:100,00",
		"DS:sys:GAUGE:600:0,00:100,00",
		"DS:iowait:GAUGE:600:0,00:100,00",
		"DS:irq:GAUGE:600:0,00:100,00",
		"DS:softirq:GAUGE:600:0,00:100,00",
		"DS:idle:GAUGE:600:0,00:100,00",
		"DS:tused:GAUGE:600:0,00:100,00",
#		"RRA:AVERAGE:0.5:1:600",    
#		"RRA:AVERAGE:0.5:6:700",    
#		"RRA:AVERAGE:0.5:24:775",  
#		"RRA:AVERAGE:0.5:288:797",  
#		"RRA:MIN:0.5:1:288",        
#		"RRA:MIN:0.5:6:2016",        
#		"RRA:MIN:0.5:24:8928",       
#		"RRA:MIN:0.5:288:105120",     
#		"RRA:MAX:0.5:1:288",       
#		"RRA:MAX:0.5:6:2016",        
#		"RRA:MAX:0.5:24:8928",       
#		"RRA:MAX:0.5:288:105120";
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

print "Information for CPU graph ...\n";
	print "		user: $cpu_user %\n";
	print "		nice: $cpu_nice %\n";
	print "		sys: $cpu_sys %\n";
	print "		iowait: $cpu_iowait %\n";
	print "		irq: $cpu_irq %\n";
	print "		softirq: $cpu_softirq %\n";
	print "		idle: $cpu_idle %\n";
	print "		total used: $cpu_usage %\n";
#update rrd info
print "Updating Information in $rrdap_dir$rrd_dir$db_cpu ...\n";		
RRDs::update "$rrdap_dir$rrd_dir$db_cpu",
	"-t", "user:nice:sys:iowait:irq:softirq:idle:tused",
	"N:$cpu_user:$cpu_nice:$cpu_sys:$cpu_iowait:$cpu_irq:$cpu_softirq:$cpu_idle:$cpu_usage";



