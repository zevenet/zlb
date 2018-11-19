#!/usr/bin/perl
###############################################################################
#
#    Zevenet Software License
#    This file is part of the Zevenet Load Balancer software package.
#
#    Copyright (C) 2014-today ZEVENET SL, Sevilla (Spain)
#
#    This program is free software: you can redistribute it and/or modify
#    it under the terms of the GNU Affero General Public License as
#    published by the Free Software Foundation, either version 3 of the
#    License, or any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU Affero General Public License for more details.
#
#    You should have received a copy of the GNU Affero General Public License
#    along with this program.  If not, see <http://www.gnu.org/licenses/>.
#
###############################################################################

use strict;
use warnings;
use RRDs;
use Zevenet::Config;
use Zevenet::Stats;

my $rrdap_dir = &getGlobalConfiguration('rrdap_dir');
my $rrd_dir = &getGlobalConfiguration('rrd_dir');
my $db_load = "load.rrd";

my @load = &getLoadStats();

my $last;
my $last5;
my $last15;
my $ERROR;

my $row = shift @load;

if ( $row->[0] eq "Last" )
{
	$last = $row->[1];
	$row = shift @load;
}

if ( $row->[0] eq "Last 5" )
{
	$last5 = $row->[1];
	$row = shift @load;
}

if ( $row->[0] eq "Last 15" )
{
	$last15 = $row->[1];
}

if ( $last =~ /^$/ || $last5 =~ /^$/ || $last15 =~ /^$/ )
{
	print "$0: Error: Unable to get the data\n";
	exit;
}

if (! -f "$rrdap_dir/$rrd_dir/$db_load" )
{
	print "$0: Info: Creating the rrd database $rrdap_dir/$rrd_dir/$db_load ...\n";
	RRDs::create "$rrdap_dir/$rrd_dir/$db_load",
		"--step", "300",
		"DS:load:GAUGE:600:0.00:100.00",
		"DS:load5:GAUGE:600:0.00:100.00",
		"DS:load15:GAUGE:600:0.00:100.00",
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

	if ( $ERROR = RRDs::error )
	{
		print "$0: Error: Unable to generate the rrd database: $ERROR\n";
	}
}

print "$0: Info: Load Stats ...\n";
print "$0: Info:	Last minute: $last\n";
print "$0: Info:	Last 5 minutes: $last5\n";
print "$0: Info:	Last 15 minutes: $last15\n";

print "$0: Info: Updating data in $rrdap_dir/$rrd_dir/$db_load ...\n";

RRDs::update "$rrdap_dir/$rrd_dir/$db_load",
	"-t", "load:load5:load15",
	"N:$last:$last5:$last15";

if ( $ERROR = RRDs::error )
{
	print "$0: Error: Unable to update the rrd database: $ERROR\n";
}
