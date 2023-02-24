#!/usr/bin/perl
###############################################################################
#
#    ZEVENET Software License
#    This file is part of the ZEVENET Load Balancer software package.
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
use MIME::Base64;
use Zevenet::Config;


my $basedir   = &getGlobalConfiguration( 'basedir' );
my $rrdap_dir = &getGlobalConfiguration( 'rrdap_dir' );
my $rrd_dir   = &getGlobalConfiguration( 'rrd_dir' );

my $width     = "600";
my $height    = "150";
my $imagetype = "PNG";

=begin nd
Function: translateRRDTime

	It translates a time from API format (11-09-2020-14:05) to RRD format (11/09/2020 14:05).
	Also, it returns the rrd format for daily, weekly, monthly or yearly.

Parameters:
	time - Time in API format

Returns:
	scalar - It is the time in RRD format

=cut

sub translateRRDTime
{
	my $time = shift;
	if ( not defined $time )
	{
		return "now";
	}
	elsif ( $time =~ /^([dwmy])/ )
	{
		return "-1$1";
	}
	elsif ( $time =~ /^(\d\d-\d\d-(?:\d\d)?\d\d)-(\d\d:\d\d)$/ )
	{
		# in (api): "11-09-2020-14:05"
		# out(rrd): "11/09/2020 14:05"
		my $date = $1;
		my $hour = $2;

		$date =~ s'-'/'g;
		return "$date $hour";
	}
	return $time;
}

=begin nd
Function: logRRDError

	It checks if some error exists in the last RRD read and it logs it

Parameters:
	graph file - it is the graph file created of reading the RRD

Returns:
	Integer - Error code. 1 on failure or 0 on success

=cut

sub logRRDError
{
	my $graph = shift;

	my $rrdError = RRDs::error;
	if ( $rrdError or not -s $graph )
	{
		$rrdError //= 'The graph was not generated';
		&zenlog( "$0: unable to generate $graph: $rrdError", "error" );
		return 1;
	}

	return 0;
}

=begin nd
Function: getRRDAxisXLimits

	It returns the first and last time value for a graph.
	It returns the times with the ZEVENET API format (11-09-2020-14:05)

Parameters:
	rrd file - It is the rrd bbdd file

Returns:
	Array - It returns an array with 2 values: the first and last times samples
		of the graph

=cut

sub getRRDAxisXLimits
{
	my $start = shift;
	my $last  = shift;

	my $format = "%m-%d-%Y-%H:%M";

	use Time::localtime;
	use POSIX qw(strftime);

	( $start, $last ) = RRDs::times( $start, $last );

	#     0    1    2     3     4    5     6     7     8
	# my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
	my @t = @{ localtime ( $last ) };
	$last  = strftime( $format, @t );
	@t     = @{ localtime ( $start ) };
	$start = strftime( $format, @t );

	return ( $start, $last );
}

=begin nd
Function: printImgFile

	Get a file encoded in base64 and remove it.

Parameters:
	file - Path to image file.

Returns:
	scalar - Base64 encoded image on success, or an empty string on failure.

See Also:
	<printGraph>
=cut

sub printImgFile    #($file)
{
	&zenlog( __FILE__ . q{:} . __LINE__ . q{:} . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my ( $file ) = @_;

	if ( open my $png, '<', $file )
	{
		my $raw_string = do { local $/ = undef; <$png>; };
		my $encoded = encode_base64( $raw_string );

		close $png;

		unlink ( $file );
		return $encoded;
	}
	else
	{
		return "";
	}
}

=begin nd
Function: delGraph

	Remove a farm,  network interface or vpn graph.

Parameters:
	name - Name of the graph resource, without sufixes.
	type - 'farm', 'iface', 'vpn'.

Returns:
	none - .

See Also:
	<runFarmDelete>, <setBondMaster>, <delIf>
=cut

sub delGraph    #($name, type)
{
	&zenlog( __FILE__ . q{:} . __LINE__ . q{:} . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $name = shift;
	my $type = shift;

	my $rrdap_dir = &getGlobalConfiguration( 'rrdap_dir' );
	my $rrd_dir   = &getGlobalConfiguration( 'rrd_dir' );

	if ( $type =~ /iface/ )
	{
		&zenlog( "Delete graph file: $rrdap_dir/$rrd_dir/${name}iface.rrd",
				 "info", "MONITOR" );
		unlink ( "$rrdap_dir/$rrd_dir/${name}iface.rrd" );
	}

	if ( $type =~ /farm/ )
	{
		&zenlog( "Delete graph file: $rrdap_dir/$rrd_dir/$name-farm.rrd",
				 "info", "MONITOR" );
		unlink glob ( "$rrdap_dir/$rrd_dir/$name-farm.rrd" );
	}
	if ( $type =~ /vpn/ )
	{
		&zenlog( "Delete graph file: $rrdap_dir/$rrd_dir/$name-vpn.rrd",
				 "info", "MONITOR" );
		unlink glob ( "$rrdap_dir/$rrd_dir/$name-vpn.rrd" );
	}
	return;
}

=begin nd
Function: printGraph

	Get a graph 'type' of a period of time base64 encoded.

Parameters:
	type - Name of the graph.
	time/start - This parameter can have one of the following values: *
		* Period of time shown in the image (Possible values: daily, d, weekly, w, monthly, m, yearly, y).
		* time which the graph starts. Format: MM-DD-YYYY-HH:mm (ie: 11-09-2020-14:05)
	end - time which the graph stops. The default value is "now", the current time.

Returns:
	hash ref - The output hash contains the following keys:
		img => Base64 encoded image, or an empty string on failure,
		start => firt time of the graph
		last => last time of the graph

See Also:
	<genCpuGraph>, <genDiskGraph>, <genLoadGraph>, <genMemGraph>, <genMemSwGraph>, <genNetGraph>, <genFarmGraph>, <genLoadGraph>
=cut

sub printGraph    #($type,$time)
{
	&zenlog( __FILE__ . q{:} . __LINE__ . q{:} . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my ( $type, $time, $end ) = @_;

	my $img_dir = &getGlobalConfiguration( 'img_dir' );
	my $graph   = $img_dir . "/" . $type . "_" . $time . ".png";

	$time = &translateRRDTime( $time );
	$end  = &translateRRDTime( $end );

	if ( $type eq "cpu" )
	{
		&genCpuGraph( $type, $graph, $time, $end );
	}
	elsif ( $type =~ /^dev-*/ )
	{
		&genDiskGraph( $type, $graph, $time, $end );
	}
	elsif ( $type eq "load" )
	{
		&genLoadGraph( $type, $graph, $time, $end );
	}
	elsif ( $type eq "mem" )
	{
		&genMemGraph( $type, $graph, $time, $end );
	}
	elsif ( $type eq "memsw" )
	{
		&genMemSwGraph( $type, $graph, $time, $end );
	}
	elsif ( $type =~ /iface$/ )
	{
		&genNetGraph( $type, $graph, $time, $end );
	}
	elsif ( $type =~ /-farm$/ )
	{
		&genFarmGraph( $type, $graph, $time, $end );
	}
	else
	{
		&zenlog( "The requested graph '$type' is unknown", "error" );
		return {};
	}
	if ( $type =~ /-vpn$/ )
	{
		&genVPNGraph( $type, $graph, $time );
	}

	return {} if ( &logRRDError( $graph ) );

	( $time, $end ) = &getRRDAxisXLimits( $time, $end );
	return {
			 img   => &printImgFile( $graph ),
			 start => $time,
			 last  => $end
	};
}

=begin nd
Function: genCpuGraph

	Generate CPU usage graph image file for a period of time.

Parameters:
	type - Database name without extension.
	graph - Path to file to be generated.
	time - time which the graph starts. Format: MM-DD-YYYY-HH:mm (ie: 11-09-2020-14:05)
	end - time which the graph stops


Returns:
	none - .

See Also:
	<printGraph>

	<genDiskGraph>, <genLoadGraph>, <genMemGraph>, <genMemSwGraph>, <genNetGraph>, <genFarmGraph>, <genLoadGraph>
=cut

sub genCpuGraph    #($type,$graph,$time)
{
	&zenlog( __FILE__ . q{:} . __LINE__ . q{:} . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my ( $type, $graph, $start, $end ) = @_;

	my $db_cpu = "$rrdap_dir/$rrd_dir/$type.rrd";

	if ( -e $db_cpu )
	{
		RRDs::graph(
					 "$graph",
					 "--imgformat=$imagetype",
					 "--start=$start",
					 "--end=$end",
					 "--width=$width",
					 "--height=$height",
					 "--alt-autoscale-max",
					 "--lower-limit=0",
					 "--title=CPU",
					 "--vertical-label=%",
					 "DEF:user=$db_cpu:user:AVERAGE",
					 "DEF:nice=$db_cpu:nice:AVERAGE",
					 "DEF:sys=$db_cpu:sys:AVERAGE",
					 "DEF:iowait=$db_cpu:iowait:AVERAGE",
					 "DEF:irq=$db_cpu:irq:AVERAGE",
					 "DEF:softirq=$db_cpu:softirq:AVERAGE",
					 "DEF:idle=$db_cpu:idle:AVERAGE",
					 "DEF:tused=$db_cpu:tused:AVERAGE",
					 "AREA:sys#DC374A:System\\t",
					 "GPRINT:sys:LAST:Last\\:%8.2lf %%",
					 "GPRINT:sys:MIN:Min\\:%8.2lf %%",
					 "GPRINT:sys:AVERAGE:Avg\\:%8.2lf %%",
					 "GPRINT:sys:MAX:Max\\:%8.2lf %%\\n",
					 "STACK:user#6B2E9A:User\\t\\t",
					 "GPRINT:user:LAST:Last\\:%8.2lf %%",
					 "GPRINT:user:MIN:Min\\:%8.2lf %%",
					 "GPRINT:user:AVERAGE:Avg\\:%8.2lf %%",
					 "GPRINT:user:MAX:Max\\:%8.2lf %%\\n",
					 "STACK:nice#ACD936:Nice\\t\\t",
					 "GPRINT:nice:LAST:Last\\:%8.2lf %%",
					 "GPRINT:nice:MIN:Min\\:%8.2lf %%",
					 "GPRINT:nice:AVERAGE:Avg\\:%8.2lf %%",
					 "GPRINT:nice:MAX:Max\\:%8.2lf %%\\n",
					 "STACK:iowait#8D85F3:Iowait\\t",
					 "GPRINT:iowait:LAST:Last\\:%8.2lf %%",
					 "GPRINT:iowait:MIN:Min\\:%8.2lf %%",
					 "GPRINT:iowait:AVERAGE:Avg\\:%8.2lf %%",
					 "GPRINT:iowait:MAX:Max\\:%8.2lf %%\\n",
					 "STACK:irq#46F2A2:Irq\\t\\t",
					 "GPRINT:irq:LAST:Last\\:%8.2lf %%",
					 "GPRINT:irq:MIN:Min\\:%8.2lf %%",
					 "GPRINT:irq:AVERAGE:Avg\\:%8.2lf %%",
					 "GPRINT:irq:MAX:Max\\:%8.2lf %%\\n",
					 "STACK:softirq#595959:Softirq\\t",
					 "GPRINT:softirq:LAST:Last\\:%8.2lf %%",
					 "GPRINT:softirq:MIN:Min\\:%8.2lf %%",
					 "GPRINT:softirq:AVERAGE:Avg\\:%8.2lf %%",
					 "GPRINT:softirq:MAX:Max\\:%8.2lf %%\\n",
					 "STACK:idle#46b971:Idle\\t\\t",
					 "GPRINT:idle:LAST:Last\\:%8.2lf %%",
					 "GPRINT:idle:MIN:Min\\:%8.2lf %%",
					 "GPRINT:idle:AVERAGE:Avg\\:%8.2lf %%",
					 "GPRINT:idle:MAX:Max\\:%8.2lf %%\\n",
					 "LINE1:tused#000000:Total used\\t",
					 "GPRINT:tused:LAST:Last\\:%8.2lf %%",
					 "GPRINT:tused:MIN:Min\\:%8.2lf %%",
					 "GPRINT:tused:AVERAGE:Avg\\:%8.2lf %%",
					 "GPRINT:tused:MAX:Max\\:%8.2lf %%\\n"
		);
	}
	return;
}

=begin nd
Function: genDiskGraph

	Generate disk partition usage graph image file for a period of time.

Parameters:
	type - Database name without extension.
	graph - Path to file to be generated.
	time - time which the graph starts. Format: MM-DD-YYYY-HH:mm (ie: 11-09-2020-14:05)
	end - time which the graph stops

Returns:
	none - .

See Also:
	<printGraph>

	<genCpuGraph>, <genLoadGraph>, <genMemGraph>, <genMemSwGraph>, <genNetGraph>, <genFarmGraph>, <genLoadGraph>
=cut

sub genDiskGraph    #($type,$graph,$time)
{
	&zenlog( __FILE__ . q{:} . __LINE__ . q{:} . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my ( $type, $graph, $start, $end ) = @_;

	my $db_hd = "$rrdap_dir/$rrd_dir/$type.rrd";

	my $dev = $type;
	$dev =~ s/hd$//;
	$dev =~ s/dev-//;
	$dev =~ s/-/\// if $dev !~ /dm-/;

	my $mount = &getDiskMountPoint( $dev );

	if ( -e $db_hd )
	{
		RRDs::graph(
					 "$graph",
					 "--start=$start",
					 "--end=$end",
					 "--title=PARTITION $mount",
					 "--vertical-label=SPACE",
					 "-h",
					 "$height",
					 "-w",
					 "$width",
					 "--lazy",
					 "-l 0",
					 "-a",
					 "$imagetype",
					 "DEF:tot=$db_hd:tot:AVERAGE",
					 "DEF:used=$db_hd:used:AVERAGE",
					 "DEF:free=$db_hd:free:AVERAGE",
					 "CDEF:total=used,free,+",
					 "AREA:used#595959:Used\\t",
					 "GPRINT:used:LAST:Last\\:%8.2lf %s",
					 "GPRINT:used:MIN:Min\\:%8.2lf %s",
					 "GPRINT:used:AVERAGE:Avg\\:%8.2lf %s",
					 "GPRINT:used:MAX:Max\\:%8.2lf %s\\n",
					 "STACK:free#46b971:Free\\t",
					 "GPRINT:free:LAST:Last\\:%8.2lf %s",
					 "GPRINT:free:MIN:Min\\:%8.2lf %s",
					 "GPRINT:free:AVERAGE:Avg\\:%8.2lf %s",
					 "GPRINT:free:MAX:Max\\:%8.2lf %s\\n",
					 "LINE1:total#000000:Total\\t",
					 "GPRINT:total:LAST:Last\\:%8.2lf %s",
					 "GPRINT:total:MIN:Min\\:%8.2lf %s",
					 "GPRINT:total:AVERAGE:Avg\\:%8.2lf %s",
					 "GPRINT:total:MAX:Max\\:%8.2lf %s\\n"
		);
	}
	return;
}

=begin nd
Function: genLoadGraph

	Generate system load graph image file for a period of time.

Parameters:
	type - Database name without extension.
	graph - Path to file to be generated.
	time - Period of time shown in the graph.

Returns:
	none - .

See Also:
	<printGraph>

	<genCpuGraph>, <genDiskGraph>, <genMemGraph>, <genMemSwGraph>, <genNetGraph>, <genFarmGraph>, <genLoadGraph>
=cut

sub genLoadGraph    #($type,$graph,$time)
{
	&zenlog( __FILE__ . q{:} . __LINE__ . q{:} . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my ( $type, $graph, $start, $end ) = @_;

	my $db_load = "$rrdap_dir/$rrd_dir/$type.rrd";

	if ( -e $db_load )
	{
		RRDs::graph(
					 "$graph",
					 "--imgformat=$imagetype",
					 "--start=$start",
					 "--end=$end",
					 "--width=$width",
					 "--height=$height",
					 "--alt-autoscale-max",
					 "--lower-limit=0",
					 "--title=LOAD AVERAGE",
					 "--vertical-label=LOAD",
					 "DEF:load=$db_load:load:AVERAGE",
					 "DEF:load5=$db_load:load5:AVERAGE",
					 "DEF:load15=$db_load:load15:AVERAGE",
					 "AREA:load#729e00:last minute\\t\\t",
					 "GPRINT:load:LAST:Last\\:%3.2lf",
					 "GPRINT:load:MIN:Min\\:%3.2lf",
					 "GPRINT:load:AVERAGE:Avg\\:%3.2lf",
					 "GPRINT:load:MAX:Max\\:%3.2lf\\n",
					 "STACK:load5#46b971:last 5 minutes\\t",
					 "GPRINT:load5:LAST:Last\\:%3.2lf",
					 "GPRINT:load5:MIN:Min\\:%3.2lf",
					 "GPRINT:load5:AVERAGE:Avg\\:%3.2lf",
					 "GPRINT:load5:MAX:Max\\:%3.2lf\\n",
					 "STACK:load15#595959:last 15 minutes\\t",
					 "GPRINT:load15:LAST:Last\\:%3.2lf",
					 "GPRINT:load15:MIN:Min\\:%3.2lf",
					 "GPRINT:load15:AVERAGE:Avg\\:%3.2lf",
					 "GPRINT:load15:MAX:Max\\:%3.2lf\\n"
		);
	}
	return;
}

=begin nd
Function: genMemGraph

	Generate RAM memory usage graph image file for a period of time.

Parameters:
	type - Database name without extension.
	graph - Path to file to be generated.
	time - time which the graph starts. Format: MM-DD-YYYY-HH:mm (ie: 11-09-2020-14:05)
	end - time which the graph stops

Returns:
	none - .

See Also:
	<printGraph>

	<genCpuGraph>, <genDiskGraph>, <genLoadGraph>, <genMemSwGraph>, <genNetGraph>, <genFarmGraph>, <genLoadGraph>
=cut

sub genMemGraph    #($type,$graph,$time)
{
	&zenlog( __FILE__ . q{:} . __LINE__ . q{:} . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my ( $type, $graph, $start, $end ) = @_;

	my $db_mem = "$rrdap_dir/$rrd_dir/$type.rrd";

	if ( -e $db_mem )
	{
		RRDs::graph(
					 "$graph",
					 "--imgformat=$imagetype",
					 "--start=$start",
					 "--end=$end",
					 "--width=$width",
					 "--height=$height",
					 "--alt-autoscale-max",
					 "--lower-limit=0",
					 "--title=RAM",
					 "--vertical-label=MEMORY",
					 "--base=1024",
					 "DEF:memt=$db_mem:memt:AVERAGE",
					 "DEF:memu=$db_mem:memu:AVERAGE",
					 "DEF:memf=$db_mem:memf:AVERAGE",
					 "DEF:memc=$db_mem:memc:AVERAGE",
					 "AREA:memu#595959:Used\\t\\t",
					 "GPRINT:memu:LAST:Last\\:%8.2lf %s",
					 "GPRINT:memu:MIN:Min\\:%8.2lf %s",
					 "GPRINT:memu:AVERAGE:Avg\\:%8.2lf %s",
					 "GPRINT:memu:MAX:Max\\:%8.2lf %s\\n",
					 "STACK:memf#46b971:Free\\t\\t",
					 "GPRINT:memf:LAST:Last\\:%8.2lf %s",
					 "GPRINT:memf:MIN:Min\\:%8.2lf %s",
					 "GPRINT:memf:AVERAGE:Avg\\:%8.2lf %s",
					 "GPRINT:memf:MAX:Max\\:%8.2lf %s\\n",
					 "LINE2:memc#46F2A2:Cache&Buffer\\t",
					 "GPRINT:memc:LAST:Last\\:%8.2lf %s",
					 "GPRINT:memc:MIN:Min\\:%8.2lf %s",
					 "GPRINT:memc:AVERAGE:Avg\\:%8.2lf %s",
					 "GPRINT:memc:MAX:Max\\:%8.2lf %s\\n",
					 "LINE1:memt#000000:Total\\t\\t",
					 "GPRINT:memt:LAST:Last\\:%8.2lf %s",
					 "GPRINT:memt:MIN:Min\\:%8.2lf %s",
					 "GPRINT:memt:AVERAGE:Avg\\:%8.2lf %s",
					 "GPRINT:memt:MAX:Max\\:%8.2lf %s\\n"
		);
	}
	return;
}

=begin nd
Function: genMemSwGraph

	Generate swap memory usage graph image file for a period of time.

Parameters:
	type - Database name without extension.
	graph - Path to file to be generated.
	time - time which the graph starts. Format: MM-DD-YYYY-HH:mm (ie: 11-09-2020-14:05)
	end - time which the graph stops

Returns:
	none - .

See Also:
	<printGraph>

	<genCpuGraph>, <genDiskGraph>, <genLoadGraph>, <genMemGraph>, <genNetGraph>, <genFarmGraph>, <genLoadGraph>
=cut

sub genMemSwGraph    #($type,$graph,$time)
{
	&zenlog( __FILE__ . q{:} . __LINE__ . q{:} . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my ( $type, $graph, $start, $end ) = @_;

	my $db_memsw = "$rrdap_dir/$rrd_dir/$type.rrd";

	if ( -e $db_memsw )
	{
		RRDs::graph(
				 "$graph",                             "--imgformat=$imagetype",
				 "--start=$start",                     "--end=$end",
				 "--width=$width",                     "--height=$height",
				 "--alt-autoscale-max",                "--lower-limit=0",
				 "--title=SWAP",                       "--vertical-label=MEMORY",
				 "--base=1024",                        "DEF:swt=$db_memsw:swt:AVERAGE",
				 "DEF:swu=$db_memsw:swu:AVERAGE",      "DEF:swf=$db_memsw:swf:AVERAGE",
				 "DEF:swc=$db_memsw:swc:AVERAGE",      "AREA:swu#595959:Used\\t\\t",
				 "GPRINT:swu:LAST:Last\\:%8.2lf %s",   "GPRINT:swu:MIN:Min\\:%8.2lf %s",
				 "GPRINT:swu:AVERAGE:Avg\\:%8.2lf %s", "GPRINT:swu:MAX:Max\\:%8.2lf %s\\n",
				 "STACK:swf#46b971:Free\\t\\t",        "GPRINT:swf:LAST:Last\\:%8.2lf %s",
				 "GPRINT:swf:MIN:Min\\:%8.2lf %s",     "GPRINT:swf:AVERAGE:Avg\\:%8.2lf %s",
				 "GPRINT:swf:MAX:Max\\:%8.2lf %s\\n",  "LINE2:swc#46F2A2:Cached\\t",
				 "GPRINT:swc:LAST:Last\\:%8.2lf %s",   "GPRINT:swc:MIN:Min\\:%8.2lf %s",
				 "GPRINT:swc:AVERAGE:Avg\\:%8.2lf %s", "GPRINT:swc:MAX:Max\\:%8.2lf %s\\n",
				 "LINE1:swt#000000:Total\\t\\t",       "GPRINT:swt:LAST:Last\\:%8.2lf %s",
				 "GPRINT:swt:MIN:Min\\:%8.2lf %s",     "GPRINT:swt:AVERAGE:Avg\\:%8.2lf %s",
				 "GPRINT:swt:MAX:Max\\:%8.2lf %s\\n",
		);
	}
	return;
}

=begin nd
Function: genNetGraph

	Generate network interface usage graph image file for a period of time.

Parameters:
	type - Database name without extension.
	graph - Path to file to be generated.
	time - time which the graph starts. Format: MM-DD-YYYY-HH:mm (ie: 11-09-2020-14:05)
	end - time which the graph stops

Returns:
	none - .

See Also:
	<printGraph>

	<genCpuGraph>, <genDiskGraph>, <genLoadGraph>, <genMemGraph>, <genMemSwGraph>, <genFarmGraph>, <genLoadGraph>
=cut

sub genNetGraph    #($type,$graph,$time)
{
	&zenlog( __FILE__ . q{:} . __LINE__ . q{:} . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my ( $type, $graph, $start, $end ) = @_;

	my $db_if   = "$rrdap_dir/$rrd_dir/$type.rrd";
	my $if_name = $type;
	$if_name =~ s/iface//g;

	if ( -e $db_if )
	{
		RRDs::graph(
					 "$graph",
					 "--imgformat=$imagetype",
					 "--start=$start",
					 "--end=$end",
					 "--height=$height",
					 "--width=$width",
					 "--lazy",
					 "-l 0",
					 "--alt-autoscale-max",
					 "--title=TRAFFIC ON $if_name",
					 "--vertical-label=BANDWIDTH",
					 "DEF:in=$db_if:in:AVERAGE",
					 "DEF:out=$db_if:out:AVERAGE",
					 "CDEF:in_bytes=in,1024,*",
					 "CDEF:out_bytes=out,1024,*",
					 "CDEF:out_bytes_neg=out_bytes,-1,*",
					 "AREA:in_bytes#46b971:In ",
					 "LINE1:in_bytes#000000",
					 "GPRINT:in_bytes:LAST:Last\\:%5.1lf %sByte/sec",
					 "GPRINT:in_bytes:MIN:Min\\:%5.1lf %sByte/sec",
					 "GPRINT:in_bytes:AVERAGE:Avg\\:%5.1lf %sByte/sec",
					 "GPRINT:in_bytes:MAX:Max\\:%5.1lf %sByte/sec\\n",
					 "AREA:out_bytes_neg#595959:Out",
					 "LINE1:out_bytes_neg#000000",
					 "GPRINT:out_bytes:LAST:Last\\:%5.1lf %sByte/sec",
					 "GPRINT:out_bytes:MIN:Min\\:%5.1lf %sByte/sec",
					 "GPRINT:out_bytes:AVERAGE:Avg\\:%5.1lf %sByte/sec",
					 "GPRINT:out_bytes:MAX:Max\\:%5.1lf %sByte/sec\\n",
					 "HRULE:0#000000"
		);
	}
	return;
}

=begin nd
Function: genFarmGraph

	Generate farm connections graph image file for a period of time.

Parameters:
	type - Database name without extension.
	graph - Path to file to be generated.
	time - time which the graph starts. Format: MM-DD-YYYY-HH:mm (ie: 11-09-2020-14:05)
	end - time which the graph stops

Returns:
	none - .

See Also:
	<printGraph>

	<genCpuGraph>, <genDiskGraph>, <genLoadGraph>, <genMemGraph>, <genMemSwGraph>, <genNetGraph>, <genLoadGraph>
=cut

sub genFarmGraph    #($type,$graph,$time)
{
	&zenlog( __FILE__ . q{:} . __LINE__ . q{:} . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my ( $type, $graph, $start, $end ) = @_;

	my $db_farm = "$rrdap_dir/$rrd_dir/$type.rrd";
	my $fname   = $type;
	$fname =~ s/-farm$//g;

	if ( -e $db_farm )
	{
		RRDs::graph(
			"$graph",
			"--start=$start",
			"--end=$end",
			"-h",
			"$height",
			"-w",
			"$width",
			"--lazy",
			"-l 0",
			"-a",
			"$imagetype",
			"--title=CONNECTIONS ON $fname farm",
			"--vertical-label=Connections",
			"DEF:pending=$db_farm:pending:AVERAGE",
			"DEF:established=$db_farm:established:AVERAGE",

			# "DEF:closed=$rrdap_dir/$rrd_dir/$db_farm:closed:AVERAGE",
			"LINE2:pending#595959:Pending\\t",
			"GPRINT:pending:LAST:Last\\:%6.0lf ",
			"GPRINT:pending:MIN:Min\\:%6.0lf ",
			"GPRINT:pending:AVERAGE:Avg\\:%6.0lf ",
			"GPRINT:pending:MAX:Max\\:%6.0lf \\n",
			"LINE2:established#46b971:Established\\t",
			"GPRINT:established:LAST:Last\\:%6.0lf ",
			"GPRINT:established:MIN:Min\\:%6.0lf ",
			"GPRINT:established:AVERAGE:Avg\\:%6.0lf ",
			"GPRINT:established:MAX:Max\\:%6.0lf \\n"

			  # "LINE2:closed#46F2A2:Closed\\t",
			  # "GPRINT:closed:LAST:Last\\:%6.0lf ",
			  # "GPRINT:closed:MIN:Min\\:%6.0lf ",
			  # "GPRINT:closed:AVERAGE:Avg\\:%6.0lf ",
			  # "GPRINT:closed:MAX:Max\\:%6.0lf \\n"
		);
	}
	return;
}

=begin nd
Function: genVPNGraph

	Generate VPN usage graph image file for a period of time.

Parameters:
	type - Database name without extension.
	graph - Path to file to be generated.
	time - Period of time shown in the graph.

Returns:
	none - .

See Also:
	<printGraph>

	<genCpuGraph>, <genDiskGraph>, <genLoadGraph>, <genMemGraph>, <genMemSwGraph>, <genFarmGraph>, <genLoadGraph>
=cut

sub genVPNGraph    #($type,$graph,$time)
{
	&zenlog( __FILE__ . q{:} . __LINE__ . q{:} . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my ( $type, $graph, $time ) = @_;

	my $db_vpn   = "$type.rrd";
	my $vpn_name = $type;
	$vpn_name =~ s/-vpn$//g;

	if ( -e "$rrdap_dir/$rrd_dir/$db_vpn" )
	{
		RRDs::graph(
					 "$graph",
					 "--imgformat=$imagetype",
					 "--start=-1$time",
					 "--height=$height",
					 "--width=$width",
					 "--lazy",
					 "-l 0",
					 "--alt-autoscale-max",
					 "--title=TRAFFIC ON $vpn_name",
					 "--vertical-label=BANDWIDTH",
					 "DEF:in=$rrdap_dir/$rrd_dir/$db_vpn:in:AVERAGE",
					 "DEF:out=$rrdap_dir/$rrd_dir/$db_vpn:out:AVERAGE",
					 "CDEF:in_bytes=in,1024,*",
					 "CDEF:out_bytes=out,1024,*",
					 "CDEF:out_bytes_neg=out_bytes,-1,*",
					 "AREA:in_bytes#46b971:In ",
					 "LINE1:in_bytes#000000",
					 "GPRINT:in_bytes:LAST:Last\\:%5.1lf %sByte/sec",
					 "GPRINT:in_bytes:MIN:Min\\:%5.1lf %sByte/sec",
					 "GPRINT:in_bytes:AVERAGE:Avg\\:%5.1lf %sByte/sec",
					 "GPRINT:in_bytes:MAX:Max\\:%5.1lf %sByte/sec\\n",
					 "AREA:out_bytes_neg#595959:Out",
					 "LINE1:out_bytes_neg#000000",
					 "GPRINT:out_bytes:LAST:Last\\:%5.1lf %sByte/sec",
					 "GPRINT:out_bytes:MIN:Min\\:%5.1lf %sByte/sec",
					 "GPRINT:out_bytes:AVERAGE:Avg\\:%5.1lf %sByte/sec",
					 "GPRINT:out_bytes:MAX:Max\\:%5.1lf %sByte/sec\\n",
					 "HRULE:0#000000"
		);

		my $rrdError = RRDs::error;
		print "$0: unable to generate $graph: $rrdError\n" if ( $rrdError );
	}
	return;
}

=begin nd
Function: getGraphs2Show

	Get list of graph names by type or all of them.

Parameters:
	graphtype - 'System', 'Network', 'Farm' or ... else?.

Returns:
	list - List of graph names or -1!!!.

See Also:
	zapi/v3/system_stats.cgi
=cut

#function that returns the graph list to show
sub getGraphs2Show    #($graphtype)
{
	&zenlog( __FILE__ . q{:} . __LINE__ . q{:} . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my ( $graphtype ) = @_;

	my @list = -1;

	if ( $graphtype eq 'System' )
	{
		opendir ( DIR, "$rrdap_dir/$rrd_dir" );
		my @disk = grep { /^dev-.*$/ } readdir ( DIR );
		closedir ( DIR );
		for ( @disk ) { s/.rrd$//g };    # remove filenames .rrd trailing
		@list = ( "cpu", @disk, "load", "mem", "memsw" );
	}
	elsif ( $graphtype eq 'Network' )
	{
		opendir ( DIR, "$rrdap_dir/$rrd_dir" );
		@list = grep { /iface.rrd$/ } readdir ( DIR );
		closedir ( DIR );
		for ( @list ) { s/.rrd$//g };    # remove filenames .rrd trailing
	}
	elsif ( $graphtype eq 'Farm' )
	{
		opendir ( DIR, "$rrdap_dir/$rrd_dir" );
		@list = grep { /farm.rrd$/ } readdir ( DIR );
		closedir ( DIR );
		for ( @list ) { s/.rrd$//g };    # remove filenames .rrd trailing
	}
	elsif ( $graphtype eq 'VPN' )
	{
		opendir ( DIR, "$rrdap_dir/$rrd_dir" );
		@list = grep { /vpn.rrd$/ } readdir ( DIR );
		closedir ( DIR );
		for ( @list ) { s/.rrd$//g };    # remove filenames .rrd trailing
	}
	else
	{
		opendir ( DIR, "$rrdap_dir/$rrd_dir" );
		@list = grep { /.rrd$/ } readdir ( DIR );
		closedir ( DIR );
		for ( @list ) { s/.rrd$//g };    # remove filenames .rrd trailing
	}

	return @list;
}

1;

