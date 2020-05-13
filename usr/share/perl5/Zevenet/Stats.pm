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

my $eload;
if ( eval { require Zevenet::ELoad; } )
{
	$eload = 1;
}

=begin nd
Function: getMemStats

	Get stats of memory usage of the system.

Parameters:
	format - "b" for bytes, "kb" for KBytes and "mb" for MBytes (default: mb).

Returns:
	list - Two dimensional array.

	@data = (
			  [$mname,     $mvalue],
			  [$mfname,    $mfvalue],
			  ['MemUsed',  $mused],
			  [$mbname,    $mbvalue],
			  [$mcname,    $mcvalue],
			  [$swtname,   $swtvalue],
			  [$swfname,   $swfvalue],
			  ['SwapUsed', $swused],
			  [$swcname,   $swcvalue],
	);

See Also:
	memory-rrd.pl, zapi/v3/system_stats.cgi, zapi/v2/system_stats.cgi
=cut

sub getMemStats
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $meminfo_filename = '/proc/meminfo';
	my ( $format ) = @_;
	my @data;
	my (
		 $mvalue,   $mfvalue,  $mused,  $mbvalue, $mcvalue,
		 $swtvalue, $swfvalue, $swused, $swcvalue
	);
	my ( $mname, $mfname, $mbname, $mcname, $swtname, $swfname, $swcname );

	unless ( -f $meminfo_filename )
	{
		print "$0: Error: File $meminfo_filename not exist ...\n";
		exit 1;
	}

	$format = "mb" unless $format;

	open my $file, '<', $meminfo_filename;

	while ( my $line = <$file> )
	{
		if ( $line =~ /memtotal/i )
		{
			my @memtotal = split /[:\ ]+/, $line;
			$mvalue = $memtotal[1];
			$mvalue = $mvalue / 1024 if $format eq "mb";
			$mvalue = $mvalue * 1024 if $format eq "b";
			$mname  = $memtotal[0];
		}
		if ( $line =~ /memfree/i )
		{
			my @memfree = split ( ": ", $line );

			# capture first number found
			$memfree[1] =~ /^\s+(\d+)\ /;
			$mfvalue = $1;

			$mfvalue = $mfvalue / 1024 if $format eq "mb";
			$mfvalue = $mfvalue * 1024 if $format eq "b";
			$mfname  = $memfree[0];
		}
		if ( $mname && $mfname )
		{
			$mused = $mvalue - $mfvalue;
		}
		if ( $line =~ /buffers/i )
		{
			my @membuf = split /[:\ ]+/, $line;
			$mbvalue = $membuf[1];
			$mbvalue = $mbvalue / 1024 if $format eq "mb";
			$mbvalue = $mbvalue * 1024 if $format eq "b";
			$mbname  = $membuf[0];
		}
		if ( $line =~ /^cached/i )
		{
			my @memcached = split /[:\ ]+/, $line;
			$mcvalue = $memcached[1];
			$mcvalue = $mcvalue / 1024 if $format eq "mb";
			$mcvalue = $mcvalue * 1024 if $format eq "b";
			$mcname  = $memcached[0];
		}
		if ( $line =~ /swaptotal/i )
		{
			my @swtotal = split /[:\ ]+/, $line;
			$swtvalue = $swtotal[1];
			$swtvalue = $swtvalue / 1024 if $format eq "mb";
			$swtvalue = $swtvalue * 1024 if $format eq "b";
			$swtname  = $swtotal[0];
		}
		if ( $line =~ /swapfree/i )
		{
			my @swfree = split /[:\ ]+/, $line;
			$swfvalue = $swfree[1];
			$swfvalue = $swfvalue / 1024 if $format eq "mb";
			$swfvalue = $swfvalue * 1024 if $format eq "b";
			$swfname  = $swfree[0];
		}
		if ( $swtname && $swfname )
		{
			$swused = $swtvalue - $swfvalue;
		}
		if ( $line =~ /swapcached/i )
		{
			my @swcached = split /[:\ ]+/, $line;
			$swcvalue = $swcached[1];
			$swcvalue = $swcvalue / 1024 if $format eq "mb";
			$swcvalue = $swcvalue * 1024 if $format eq "b";
			$swcname  = $swcached[0];
		}
	}

	close $file;

	$mvalue   = sprintf ( '%.2f', $mvalue );
	$mfvalue  = sprintf ( '%.2f', $mfvalue );
	$mused    = sprintf ( '%.2f', $mused );
	$mbvalue  = sprintf ( '%.2f', $mbvalue );
	$mcvalue  = sprintf ( '%.2f', $mcvalue );
	$swtvalue = sprintf ( '%.2f', $swtvalue );
	$swfvalue = sprintf ( '%.2f', $swfvalue );
	$swused   = sprintf ( '%.2f', $swused );
	$swcvalue = sprintf ( '%.2f', $swcvalue );

	@data = (
			  [$mname,     $mvalue],
			  [$mfname,    $mfvalue],
			  ['MemUsed',  $mused],
			  [$mbname,    $mbvalue],
			  [$mcname,    $mcvalue],
			  [$swtname,   $swtvalue],
			  [$swfname,   $swfvalue],
			  ['SwapUsed', $swused],
			  [$swcname,   $swcvalue],
	);

	return @data;
}

=begin nd
Function: getLoadStats

	Get the system load values.

Parameters:
	none - .

Returns:
	list - Two dimensional array.

	@data = (
		['Last', $last],
		['Last 5', $last5],
		['Last 15', $last15]
	);

See Also:
	load-rrd.pl, zapi/v3/system_stats.cgi, zapi/v2/system_stats.cgi
=cut

sub getLoadStats
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $load_filename = '/proc/loadavg';

	my $last;
	my $last5;
	my $last15;

	if ( -f $load_filename )
	{
		my $lastline;

		open my $file, '<', $load_filename;
		while ( my $line = <$file> )
		{
			$lastline = $line;
		}
		close $file;

		( $last, $last5, $last15 ) = split ( " ", $lastline );
	}

	my @data = ( ['Last', $last], ['Last 5', $last5], ['Last 15', $last15], );

	return @data;
}

=begin nd
Function: getNetworkStats

	Get stats for the network interfaces.

Parameters:
	format - 'raw', 'hash' or nothing.

Returns:
	When 'format' is not defined:

		@data = (
			  [
				'eth0 in',
				'46.11'
			  ],
			  [
				'eth0 out',
				'63.02'
			  ],
			  ...
		);

	When 'format' is 'raw':

		@data = (
			  [
				'eth0 in',
				'48296309'
			  ],
			  [
				'eth0 out',
				'66038087'
			  ],
			  ...
		);

	When 'format' is 'hash':

		@data = (
			  {
				'in' => '46.12',
				'interface' => 'eth0',
				'out' => '63.04'
			  },
			  ...
		);

See Also:
	iface-rrd.pl, zapi/v3/system_stats.cgi, zapi/v2/system_stats.cgi
=cut

sub getNetworkStats
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my ( $format ) = @_;

	$format = "" unless defined $format;    # removes undefined variable warnings

	my $netinfo_filename = '/proc/net/dev';

	unless ( -f $netinfo_filename )
	{
		print "$0: Error: File $netinfo_filename not exist ...\n";
		exit 1;
	}

	my @outHash;

	open my $file, '<', $netinfo_filename or die $!;
	my ( $in, $out );
	my @data;
	my @interface;
	my @interfacein;
	my @interfaceout;

	my $alias;
	$alias = &eload(
					 module => 'Zevenet::Alias',
					 func   => 'getAlias',
					 args   => ['interface']
	) if $eload;

	my $i = -1;
	while ( <$file> )
	{
		chomp $_;
		if ( $_ =~ /\:/ && $_ !~ /lo/ )
		{
			$i++;
			my @iface = split ( ":", $_ );
			my $if = $iface[0];
			$if =~ s/\ //g;

			if ( $_ =~ /:\ / )
			{
				( $in, $out ) = ( split )[1, 9];
			}
			else
			{
				( $in, $out ) = ( split )[0, 8];
				$in = ( split /:/, $in )[1];
			}

			if ( $format ne "raw" )
			{
				$in  = ( ( $in / 1024 ) / 1024 );
				$out = ( ( $out / 1024 ) / 1024 );
				$in  = sprintf ( '%.2f', $in );
				$out = sprintf ( '%.2f', $out );
			}

			$if =~ s/\ //g;

			# not show cluster maintenance interface
			$i = $i - 1 if $if eq 'cl_maintenance';
			next if $if eq 'cl_maintenance';
			push @interface,    $if;
			push @interfacein,  $in;
			push @interfaceout, $out;

			push @outHash,
			  {
				'interface' => $if,
				'in'        => $in,
				'out'       => $out
			  };
			$outHash[-1]->{ alias } = $alias->{ $if } if $eload;

		}
	}

	for ( my $j = 0 ; $j <= $i ; $j++ )
	{
		push @data, [$interface[$j] . ' in', $interfacein[$j]],
		  [$interface[$j] . ' out', $interfaceout[$j]];
	}

	close $file;

	if ( $format eq 'hash' )
	{
		@data = sort { $a->{ interface } cmp $b->{ interface } } @outHash;
	}

	return @data;
}

=begin nd
Function: getCPU

	Get system CPU usage stats.

Parameters:
	none - .

Returns:
	list - Two dimensional array.

	Example:

	@data = (
			  ['CPUuser',    $cpu_user],
			  ['CPUnice',    $cpu_nice],
			  ['CPUsys',     $cpu_sys],
			  ['CPUiowait',  $cpu_iowait],
			  ['CPUirq',     $cpu_irq],
			  ['CPUsoftirq', $cpu_softirq],
			  ['CPUidle',    $cpu_idle],
			  ['CPUusage',   $cpu_usage],
	);

See Also:
	zapi/v3/system_stats.cgi, zapi/v2/system_stats.cgi, cpu-rrd.pl
=cut

sub getCPU
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my @data;
	my $interval         = 1;
	my $cpuinfo_filename = '/proc/stat';

	unless ( -f $cpuinfo_filename )
	{
		print "$0: Error: File $cpuinfo_filename not exist ...\n";
		exit 1;
	}

	my $cpu_user1;
	my $cpu_nice1;
	my $cpu_sys1;
	my $cpu_idle1;
	my $cpu_iowait1;
	my $cpu_irq1;
	my $cpu_softirq1;
	my $cpu_total1;

	my $cpu_user2;
	my $cpu_nice2;
	my $cpu_sys2;
	my $cpu_idle2;
	my $cpu_iowait2;
	my $cpu_irq2;
	my $cpu_softirq2;
	my $cpu_total2;

	my @line_s;

	open my $file, '<', $cpuinfo_filename;

	foreach my $line ( <$file> )
	{
		if ( $line =~ /^cpu\ / )
		{
			@line_s       = split ( "\ ", $line );
			$cpu_user1    = $line_s[1];
			$cpu_nice1    = $line_s[2];
			$cpu_sys1     = $line_s[3];
			$cpu_idle1    = $line_s[4];
			$cpu_iowait1  = $line_s[5];
			$cpu_irq1     = $line_s[6];
			$cpu_softirq1 = $line_s[7];
			$cpu_total1 =
			  $cpu_user1 +
			  $cpu_nice1 +
			  $cpu_sys1 +
			  $cpu_idle1 +
			  $cpu_iowait1 +
			  $cpu_irq1 +
			  $cpu_softirq1;
		}
	}
	close $file;

	sleep $interval;

	open $file, '<', $cpuinfo_filename;
	foreach my $line ( <$file> )
	{
		if ( $line =~ /^cpu\ / )
		{
			@line_s       = split ( "\ ", $line );
			$cpu_user2    = $line_s[1];
			$cpu_nice2    = $line_s[2];
			$cpu_sys2     = $line_s[3];
			$cpu_idle2    = $line_s[4];
			$cpu_iowait2  = $line_s[5];
			$cpu_irq2     = $line_s[6];
			$cpu_softirq2 = $line_s[7];
			$cpu_total2 =
			  $cpu_user2 +
			  $cpu_nice2 +
			  $cpu_sys2 +
			  $cpu_idle2 +
			  $cpu_iowait2 +
			  $cpu_irq2 +
			  $cpu_softirq2;
		}
	}
	close $file;

	my $diff_cpu_user    = $cpu_user2 - $cpu_user1;
	my $diff_cpu_nice    = $cpu_nice2 - $cpu_nice1;
	my $diff_cpu_sys     = $cpu_sys2 - $cpu_sys1;
	my $diff_cpu_idle    = $cpu_idle2 - $cpu_idle1;
	my $diff_cpu_iowait  = $cpu_iowait2 - $cpu_iowait1;
	my $diff_cpu_irq     = $cpu_irq2 - $cpu_irq1;
	my $diff_cpu_softirq = $cpu_softirq2 - $cpu_softirq1;
	my $diff_cpu_total   = $cpu_total2 - $cpu_total1;

	my $cpu_user    = ( 100 * $diff_cpu_user ) / $diff_cpu_total;
	my $cpu_nice    = ( 100 * $diff_cpu_nice ) / $diff_cpu_total;
	my $cpu_sys     = ( 100 * $diff_cpu_sys ) / $diff_cpu_total;
	my $cpu_idle    = ( 100 * $diff_cpu_idle ) / $diff_cpu_total;
	my $cpu_iowait  = ( 100 * $diff_cpu_iowait ) / $diff_cpu_total;
	my $cpu_irq     = ( 100 * $diff_cpu_irq ) / $diff_cpu_total;
	my $cpu_softirq = ( 100 * $diff_cpu_softirq ) / $diff_cpu_total;

	my $cpu_usage =
	  $cpu_user + $cpu_nice + $cpu_sys + $cpu_iowait + $cpu_irq + $cpu_softirq;

	$cpu_user    = sprintf ( "%.2f", $cpu_user );
	$cpu_nice    = sprintf ( "%.2f", $cpu_nice );
	$cpu_sys     = sprintf ( "%.2f", $cpu_sys );
	$cpu_iowait  = sprintf ( "%.2f", $cpu_iowait );
	$cpu_irq     = sprintf ( "%.2f", $cpu_irq );
	$cpu_softirq = sprintf ( "%.2f", $cpu_softirq );
	$cpu_idle    = sprintf ( "%.2f", $cpu_idle );
	$cpu_usage   = sprintf ( "%.2f", $cpu_usage );

	$cpu_user =~ s/,/\./g;
	$cpu_nice =~ s/,/\./g;
	$cpu_sys =~ s/,/\./g;
	$cpu_iowait =~ s/,/\./g;
	$cpu_softirq =~ s/,/\./g;
	$cpu_idle =~ s/,/\./g;
	$cpu_usage =~ s/,/\./g;

	@data = (
			  ['CPUuser',    $cpu_user],
			  ['CPUnice',    $cpu_nice],
			  ['CPUsys',     $cpu_sys],
			  ['CPUiowait',  $cpu_iowait],
			  ['CPUirq',     $cpu_irq],
			  ['CPUsoftirq', $cpu_softirq],
			  ['CPUidle',    $cpu_idle],
			  ['CPUusage',   $cpu_usage],
	);

	return @data;
}

sub getCPUUsageStats
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $out;    # Output

	my @data_cpu = &getCPU();

	foreach my $x ( 0 .. @data_cpu - 1 )
	{
		my $name  = $data_cpu[$x][0];
		my $value = $data_cpu[$x][1] + 0;

		( undef, $name ) = split ( 'CPU', $name );

		$out->{ $name } = $value;
	}

	return $out;
}

=begin nd
Function: getDiskSpace

	Return total, used and free space for every partition in the system.

Parameters:
	none - .

Returns:
	list - Two dimensional array.

	@data = (
          [
            'dev-dm-0 Total',
            1981104128
          ],
          [
            'dev-dm-0 Used',
            1707397120
          ],
          [
            'dev-dm-0 Free',
            154591232
          ],
          ...
	);

See Also:
	disk-rrd.pl
=cut

sub getDiskSpace
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my @data;    # output

	my $df_bin = &getGlobalConfiguration( 'df_bin' );
	my @system = @{ &logAndGet( "$df_bin -k", "array" ) };
	chomp ( @system );
	my @df_system = @system;

	foreach my $line ( @system )
	{
		next if $line !~ /^\/dev/;

		my @dd_name = split ( ' ', $line );
		my $dd_name = $dd_name[0];

		my ( $line_df ) = grep ( { /^$dd_name\s/ } @df_system );
		my @s_line = split ( /\s+/, $line_df );

		my $partitions = $s_line[0];
		$partitions =~ s/\///;
		$partitions =~ s/\//-/g;

		my $tot  = $s_line[1] * 1024;
		my $used = $s_line[2] * 1024;
		my $free = $s_line[3] * 1024;

		push ( @data,
			   [$partitions . ' Total', $tot],
			   [$partitions . ' Used',  $used],
			   [$partitions . ' Free',  $free] );
	}

	return @data;
}

=begin nd
Function: getDiskPartitionsInfo

	Get a reference to a hash with the partitions devices, mount points and name of rrd database.

Parameters:
	none - .

Returns:
	scalar - Hash reference.

	Example:

	$partitions = {
		'/dev/dm-0' => {
							'mount_point' => '/',
							'rrd_id' => 'dev-dm-0hd'
						},
		'/dev/mapper/zva64-config' => {
										'mount_point' => '/usr/local/zevenet/config',
										'rrd_id' => 'dev-mapper-zva64-confighd'
										},
		'/dev/mapper/zva64-log' => {
									'mount_point' => '/var/log',
									'rrd_id' => 'dev-mapper-zva64-loghd'
									},
		'/dev/xvda1' => {
							'mount_point' => '/boot',
							'rrd_id' => 'dev-xvda1hd'
						}
	};

See Also:
	zapi/v3/system_stats.cgi
=cut

sub getDiskPartitionsInfo
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $partitions;    # output

	my $df_bin = &getGlobalConfiguration( 'df_bin' );

	my @out = @{ &logAndGet( "$df_bin -k", "array" ) };
	my @df_lines = grep { /^\/dev/ } @out;
	chomp ( @df_lines );

	foreach my $line ( @df_lines )
	{
		my @df_line = split ( /\s+/, $line );

		my $mount_point = $df_line[5];
		my $partition   = $df_line[0];
		my $part_id     = $df_line[0];
		$part_id =~ s/\///;
		$part_id =~ s/\//-/g;

		$partitions->{ $partition } = {
										mount_point => $mount_point,
										rrd_id      => "${part_id}hd",
		};
	}

	return $partitions;
}

=begin nd
Function: getDiskMountPoint

	Get the mount point of a partition device

Parameters:
	dev - Partition device.

Returns:
	string - Mount point for such partition device.
	undef  - The partition device is not mounted

See Also:
	<genDiskGraph>
=cut

sub getDiskMountPoint
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my ( $dev ) = @_;

	my $df_bin = &getGlobalConfiguration( 'df_bin' );
	my @df_system = @{ &logAndGet( "$df_bin -k", "array" ) };
	my $mount;

	for my $line_df ( @df_system )
	{
		if ( $line_df =~ /$dev/ )
		{
			my @s_line = split ( "\ ", $line_df );
			chomp ( @s_line );

			$mount = $s_line[5];
		}
	}

	return $mount;
}

=begin nd
Function: getCPUTemp

	Get the CPU temperature in celsius degrees.

Parameters:
	none - .

Returns:
	string - Temperature in celsius degrees.

See Also:
	temperature-rrd.pl
=cut

sub getCPUTemp
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $filename = &getGlobalConfiguration( "temperatureFile" );
	my $lastline;

	unless ( -f $filename )
	{
		print "$0: Error: File $filename not exist ...\n";
		exit 1;
	}

	open my $file, '<', $filename;

	while ( my $line = <$file> )
	{
		$lastline = $line;
	}

	close $file;

	my @lastlines = split ( "\:", $lastline );
	my $temp = $lastlines[1];
	$temp =~ s/\ //g;
	$temp =~ s/\n//g;
	$temp =~ s/C//g;

	return $temp;
}

1;

