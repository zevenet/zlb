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
my $db_cpu = "cpu.rrd";

my @cpu = &getCPU();

my $cpu_user;
my $cpu_nice;
my $cpu_sys;
my $cpu_iowait;
my $cpu_irq;
my $cpu_softirq;
my $cpu_idle;
my $cpu_usage;
my $ERROR;

my $row = shift @cpu;

if ( $row->[0] eq "CPUuser" )
{
	$cpu_user = $row->[1];
	$row = shift @cpu;
}

if ( $row->[0] eq "CPUnice" )
{
	$cpu_nice = $row->[1];
	$row = shift @cpu;
}

if ( $row->[0] eq "CPUsys" )
{
	$cpu_sys = $row->[1];
	$row = shift @cpu;
}

if ( $row->[0] eq "CPUiowait" )
{
	$cpu_iowait = $row->[1];
	$row = shift @cpu;
}

if ( $row->[0] eq "CPUirq" )
{
	$cpu_irq = $row->[1];
	$row = shift @cpu;
}

if ( $row->[0] eq "CPUsoftirq" )
{
	$cpu_softirq = $row->[1];
	$row = shift @cpu;
}

if ( $row->[0] eq "CPUidle" )
{
	$cpu_idle = $row->[1];
	$row = shift @cpu;
}

if ( $row->[0] eq "CPUusage" )
{
	$cpu_usage = $row->[1];
	$row = shift @cpu;
}

if ( $cpu_user =~ /^$/ || 
	$cpu_nice =~ /^$/ || 
	$cpu_sys =~ /^$/ || 
	$cpu_iowait =~ /^$/ || 
	$cpu_irq =~ /^$/ || 
	$cpu_softirq =~ /^$/ || 
	$cpu_idle =~ /^$/ || 
	$cpu_usage =~ /^$/ )
{
	print "$0: Error: Unable to get the data\n";
	exit;
}

if ( ! -f "$rrdap_dir/$rrd_dir/$db_cpu" )
{
	print "$0: Info: Creating the rrd database $rrdap_dir/$rrd_dir/$db_cpu ...\n";
	RRDs::create "$rrdap_dir/$rrd_dir/$db_cpu",
		"--step", "300",
		"DS:user:GAUGE:600:0.00:100.00",
		"DS:nice:GAUGE:600:0.00:100.00",
		"DS:sys:GAUGE:600:0.00:100.00",
		"DS:iowait:GAUGE:600:0.00:100.00",
		"DS:irq:GAUGE:600:0.00:100.00",
		"DS:softirq:GAUGE:600:0.00:100.00",
		"DS:idle:GAUGE:600:0.00:100.00",
		"DS:tused:GAUGE:600:0.00:100.00",
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

print "$0: Info: CPU Stats ...\n";
print "$0: Info:	user: $cpu_user %\n";
print "$0: Info:	nice: $cpu_nice %\n";
print "$0: Info:	sys: $cpu_sys %\n";
print "$0: Info:	iowait: $cpu_iowait %\n";
print "$0: Info:	irq: $cpu_irq %\n";
print "$0: Info:	softirq: $cpu_softirq %\n";
print "$0: Info:	idle: $cpu_idle %\n";
print "$0: Info:	total used: $cpu_usage %\n";

print "$0: Info: Updating data in $rrdap_dir/$rrd_dir/$db_cpu ...\n";
RRDs::update "$rrdap_dir/$rrd_dir/$db_cpu",
	"-t", "user:nice:sys:iowait:irq:softirq:idle:tused",
	"N:$cpu_user:$cpu_nice:$cpu_sys:$cpu_iowait:$cpu_irq:$cpu_softirq:$cpu_idle:$cpu_usage";

if ( $ERROR = RRDs::error )
{
	print "$0: Error: Unable to update the rrd database: $ERROR\n";
}
