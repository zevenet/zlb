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
require ("/usr/local/zenloadbalancer/www/functions.cgi");

my $synconns= 0;
my $globalconns = 0;

@farmlist = &getFarmList();
my @netstat = "";
foreach $farmfile(@farmlist){
	@farmargs = split(/_/,$farmfile);
	$farm = @farmargs[0];
	my $ftype = &getFarmType($farm);
	if ($ftype !~ /datalink/){
		$db_if="$farm-farm.rrd";
		#status
                $status = &getFarmStatus($farm);
		#vip
	        $vip = &getFarmVip("vip",$farm);
		  if ($status eq "up"){
                        @netstat = &getConntrack("",$vip,"","","");
                        # SYN_RECV connections
                        @synconnslist = &getFarmSYNConns($farm,@netstat);
                        $synconns = @synconnslist;
			# ESTABLISHED connections
                        @gconns = &getFarmEstConns($farm,@netstat);
                        $globalconns = @gconns;
                } 

		#process farm
		if (! -f "$rrdap_dir$rrd_dir$db_if"){
			print "Creating traffic rrd database for $farm $rrdap_dir$rrd_dir$db_if ...\n";
			RRDs::create "$rrdap_dir$rrd_dir$db_if",
        	               	"-s 300",
        	               	"DS:pending:GAUGE:600:0:12500000",
        	               	"DS:established:GAUGE:600:0:12500000",
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
	
			if ($ERROR = RRDs::error) { print "$0: unable to generate $farm database: $ERROR\n"};
		}
		print "Information for $farm farm graph ...\n";
		print "		pending: $synconns\n";
		print "		established: $globalconns\n";
		#update rrd info
		print "Updating Information in $rrdap_dir$rrd_dir$db_if ...\n";
		RRDs::update "$rrdap_dir$rrd_dir$db_if",
			"-t", "pending:established",
			"N:$synconns:$globalconns";
			
	}
}	

