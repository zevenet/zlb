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

my $rrdap_dir = &getGlobalConfiguration( 'rrdap_dir' );
my $rrd_dir = &getGlobalConfiguration( 'rrd_dir' );
my $db_hd = "hd.rrd";
my $ERROR;

my @disks = getDiskSpace();

while ( @disks )
{
	my $total_ref = shift @disks;
	my $used_ref = shift @disks;
	my $free_ref = shift @disks;

	my ($partition) = split("\ ",$total_ref->[0]);

	my $tot = $total_ref->[1];
	my $used = $used_ref->[1];
	my $free = $free_ref->[1];

	if ( $tot =~ /^$/ || $used =~ /^$/ || $free =~ /^$/ )
	{
		print "$0: Error: Unable to get the data for partition $partition\n";
		print "$0: tot:$tot used:$used free:$free\n";
		next;
	}

	if ( ! -f "$rrdap_dir/$rrd_dir/$partition$db_hd" )
	{
		print "$0: Info: Creating the rrd database $rrdap_dir/$rrd_dir/$partition$db_hd ...\n";
		RRDs::create "$rrdap_dir/$rrd_dir/$partition$db_hd",
			"--step", "300",
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

		if ( $ERROR = RRDs::error )
		{
			print "$0: Error: Unable to generate the rrd database for partition $partition: $ERROR\n";
		}
	}

	print "$0: Info: Disk Stats for partition $partition ...\n";
	print "$0: Info:	Total: $tot Bytes\n";
	print "$0: Info:	Used: $used Bytes\n";
	print "$0: Info:	Free: $free Bytes\n";

	print "$0: Info: Updating data in $rrdap_dir/$rrd_dir/$partition$db_hd ...\n";

	RRDs::update "$rrdap_dir/$rrd_dir/$partition$db_hd",
		"-t", "tot:used:free",
		"N:$tot:$used:$free";

	if ( $ERROR = RRDs::error )
	{
		print "$0: Error: Unable to update the rrd database for partition $partition: $ERROR\n";
	}
}
