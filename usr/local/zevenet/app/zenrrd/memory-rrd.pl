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

my $db_mem = "mem.rrd";
my $db_memsw = "memsw.rrd";

my @mem = &getMemStats("b");

my $mvalue;
my $mused;
my $mfvalue;
my $mbvalue;
my $mcvalue;

my $swtvalue;
my $swfvalue;
my $swused;
my $swcvalue;
my $ERROR;

my $row = shift @mem;

if ( $row->[0] eq "MemTotal" )
{
	$mvalue = $row->[1];
	$row = shift @mem;
}

if ( $row->[0] eq "MemFree" )
{
	$mfvalue = $row->[1];
	$row = shift @mem;
}

if ( $row->[0] eq "MemUsed" )
{
	$mused = $row->[1];
	$row = shift @mem;
}

if ( $row->[0] eq "Buffers" )
{
	$mbvalue = $row->[1];
	$row = shift @mem;
}

if ( $row->[0] eq "Cached" )
{
	$mcvalue = $row->[1];
	#$mcvalue =+ $mbvalue;
	$row = shift @mem;
}

if ( $row->[0] eq "SwapTotal" )
{
	$swtvalue = $row->[1];
	$row = shift @mem;
}

if ( $row->[0] eq "SwapFree" )
{
	$swfvalue = $row->[1];
	$row = shift @mem;
}

if ( $row->[0] eq "SwapUsed" )
{
	$swused = $row->[1];
	$row = shift @mem;
}

if ( $row->[0] eq "SwapCached" )
{
	$swcvalue = $row->[1];
	$row = shift @mem;
}

if ( $mvalue =~ /^$/ || $mused =~ /^$/ || $mfvalue =~ /^$/ || $mcvalue =~ /^$/ ||
	$swtvalue =~ /^$/ || $swfvalue =~ /^$/ || $swused =~ /^$/ || $swcvalue =~ /^$/ )
{
	print "$0: Error: Unable to get the data\n";
	exit;
}

if ( ! -f "$rrdap_dir/$rrd_dir/$db_mem" )
{
	print "$0: Info: Creating the rrd database $rrdap_dir/$rrd_dir/$db_mem ...\n";
	RRDs::create "$rrdap_dir/$rrd_dir/$db_mem",
		"--step", "300",
		"DS:memt:GAUGE:600:0:U",
		"DS:memu:GAUGE:600:0:U",
		"DS:memf:GAUGE:600:0:U",
		"DS:memc:GAUGE:600:0:U",
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
		print "$0: Error: Unable to generate the memory rrd database: $ERROR\n";
	}
}

if ( ! -f "$rrdap_dir/$rrd_dir/$db_memsw" )
{
	print "$0: Info: Creating the rrd database $rrdap_dir/$rrd_dir/$db_memsw ...\n";
	RRDs::create "$rrdap_dir/$rrd_dir/$db_memsw",
		"--step", "300",
		"DS:swt:GAUGE:600:0:U",
		"DS:swu:GAUGE:600:0:U",
		"DS:swf:GAUGE:600:0:U",
		"DS:swc:GAUGE:600:0:U",
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
		print "$0: Error: Unable to generate the swap rrd database: $ERROR\n";
	}
}

print "$0: Info: Memory Stats ...\n";
print "$0: Info:	Total Memory: $mvalue Bytes\n";
print "$0: Info:	Used Memory: $mused Bytes\n";
print "$0: Info:	Free Memory: $mfvalue Bytes\n";
print "$0: Info:	Cached Memory: $mcvalue Bytes\n";
print "$0: Info:	Buffered Memory: $mbvalue Bytes\n";

print "$0: Info: Updating data in $rrdap_dir/$rrd_dir/$db_mem ...\n";

RRDs::update "$rrdap_dir/$rrd_dir/$db_mem",
	"-t", "memt:memu:memf:memc",
	"N:$mvalue:$mused:$mfvalue:". ($mcvalue + $mbvalue);

if ( $ERROR = RRDs::error )
{
	print "$0: Error: Unable to update the rrd database: $ERROR\n";
}

print "$0: Info: Swap Stats ...\n";
print "$0: Info:	Total Memory Swap: $swtvalue Bytes\n";
print "$0: Info:	Used Memory Swap: $swused Bytes\n";
print "$0: Info:	Free Memory Swap: $swfvalue Bytes\n";
print "$0: Info:	Cached Memory Swap: $swcvalue Bytes\n";

print "$0: Info: Updating data in $rrdap_dir/$rrd_dir/$db_memsw ...\n";
RRDs::update "$rrdap_dir/$rrd_dir/$db_memsw",
	"-t", "swt:swu:swf:swc",
	"N:$swtvalue:$swused:$swfvalue:$swcvalue";

if ( $ERROR = RRDs::error )
{
	print "$0: Error: Unable to update the rrd database: $ERROR\n";
}
