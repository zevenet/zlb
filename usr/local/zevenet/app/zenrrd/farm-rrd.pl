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
use Zevenet::Farm::Base;
use Zevenet::Farm::Stats;
use Zevenet::Net::ConnStats;

my $eload;
if ( eval { require Zevenet::ELoad; } ) { $eload = 1; }

my $rrdap_dir = &getGlobalConfiguration('rrdap_dir');
my $rrd_dir = &getGlobalConfiguration('rrd_dir');

foreach my $farmfile ( &getFarmList() )
{
	my $farm   = &getFarmName( $farmfile );
	my $ftype  = &getFarmType( $farm );
	my $status = &getFarmStatus( $farm );

	if ( $ftype =~ /datalink/ || $status ne "up" )
	{
		next;
	}

	my $ERROR;
	my $db_farm = "$farm-farm.rrd";

	my $synconns;
	my $globalconns;

	if ( $ftype eq 'gslb' )
	{
		my $stats;
		$stats = &eload(
							module => 'Zevenet::Farm::GSLB::Stats',
							func   => 'getGSLBFarmStats',
							args   => [$farm],
		) if $eload;

		$synconns    = $stats->{ syn };
		$globalconns = $stats->{ est };
	}
	else
	{
		my $vip = &getFarmVip( "vip", $farm );
		my $netstat = &getConntrack( "", $vip, "", "", "" );

		$synconns    = &getFarmSYNConns( $farm, $netstat ); # SYN_RECV connections
		$globalconns = &getFarmEstConns( $farm, $netstat ); # ESTABLISHED connections
	}

	if ( $globalconns eq '' || $synconns eq '' )
	{
		print "$0: Error: Unable to get the data for farm $farm\n";
		exit;
	}

	if (! -f "$rrdap_dir/$rrd_dir/$db_farm")
	{
		print "$0: Info: Creating the rrd database $rrdap_dir/$rrd_dir/$db_farm ...\n";
		RRDs::create "$rrdap_dir/$rrd_dir/$db_farm",
			"--step", "300",
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

		if ( $ERROR = RRDs::error )
		{
			print "$0: Error: Unable to generate the swap rrd database: $ERROR\n";
		}
	}

	print "$0: Info: $farm Farm Connections Stats ...\n";
	print "$0: Info:	Pending: $synconns\n";
	print "$0: Info:	Established: $globalconns\n";
	print "$0: Info: Updating data in $rrdap_dir/$rrd_dir/$db_farm ...\n";

	RRDs::update "$rrdap_dir/$rrd_dir/$db_farm",
		"-t", "pending:established",
		"N:$synconns:$globalconns";

	if ( $ERROR = RRDs::error )
	{
		print "$0: Error: Unable to update the rrd database: $ERROR\n";
	}
}
