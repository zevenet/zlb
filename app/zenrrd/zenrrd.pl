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

#this script run all pl files with -rrd.pl regexh in $rrdap_dir, 
#this -rrd.pl files will create the rrd graphs that zen load balancer gui
#will paint in Monitoring section
#USE:
#you have to include in the cron user this next line for example:
#execution over 2 minutes
#*/2 * * * * /usr/local/zenloadbalancer/app/rrd/zenrrd.pl
#Fell free to create next graphs, in files type
#name-rrd.pl, the system going to include automatically to execute
#and viewing in Zen load balancer GUI (Monitoring secction)

require ("/usr/local/zenloadbalancer/config/global.conf");
$lockfile="/tmp/rrd.lock";

if ( -e $lockfile ){
        print "RRD Locked by $lockfile, maybe other zenrrd in execution\n";
	exit;
}else {
   open LOCK, '>', $lockfile;
   print LOCK "lock rrd";
   close LOCK;
}

opendir(DIR, $rrdap_dir);
@files = grep(/-rrd.pl$/,readdir(DIR));
closedir(DIR);

foreach $file(@files)
	{
	print "Executing $file...\n";
	if ($log_rrd eq "")
		{
		my @system =`$rrdap_dir$file`;
		}

	else
		{
		my @system =`$rrdap_dir$file >> $rrdap_dir$log_rrd`;
		}
	}

if ( -e $lockfile ){
	unlink($lockfile);
}


