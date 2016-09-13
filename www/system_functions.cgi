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

#get Memory usage of the System.
#return @array
#	name,value
sub getMemStats()
{

	my @data;
	my $mvalue;
	my $mfvalue;
	my $mused;
	my $mbvalue;
	my $mcvalue;
	my $swtvalue;
	my $swfvalue;
	my $swused;

	if ( -f "/proc/meminfo" )
	{
		open FR, "/proc/meminfo";
		while ( $line = <FR> )
		{
			if ( $line =~ /memtotal/i )
			{
				my @memtotal = split ( ": ", $line );
				$mvalue = @memtotal[1] / 1024;
				$mname  = @memtotal[0];
			}
			if ( $line =~ /memfree/i )
			{
				my @memfree = split ( ": ", $line );
				$mfvalue = @memfree[1] / 1024;
				$mfname  = @memfree[0];
			}
			if ( $mname && $mfname )
			{
				$mused = $mvalue - $mfvalue;
			}
			if ( $line =~ /buffers/i )
			{
				my @membuf = split ( ": ", $line );
				$mbvalue = @membuf[1] / 1024;
				$mbname  = @membuf[0];
			}
			if ( $line =~ /^cached/i )
			{
				my @memcached = split ( ": ", $line );
				$mcvalue = @memcached[1] / 1024;
				$mcname  = @memcached[0];
			}
			if ( $line =~ /swaptotal/i )
			{
				my @swtotal = split ( ": ", $line );
				$swtvalue = @swtotal[1] / 1024;
				$swtname  = @swtotal[0];
			}
			if ( $line =~ /swapfree/i )
			{
				my @swfree = split ( ": ", $line );
				$swfvalue = @swfree[1] / 1024;
				$swfname  = @swfree[0];
			}
			if ( $swtname && $swfname )
			{
				$swused = $swtvalue - $swfvalue;
			}

		}
	}

	$mvalue   = sprintf ( '%.2f', $mvalue );
	$mfvalue  = sprintf ( '%.2f', $mfvalue );
	$mused    = sprintf ( '%.2f', $mused );
	$mbvalue  = sprintf ( '%.2f', $mbvalue );
	$mcvalue  = sprintf ( '%.2f', $mcvalue );
	$swtvalue = sprintf ( '%.2f', $swtvalue );
	$swfvalue = sprintf ( '%.2f', $swfvalue );
	$swused   = sprintf ( '%.2f', $swused );

	@data = ( [$mname, $mvalue], [$mfname, $mfvalue], ['MemUsed', $mused], [$mbname, $mbvalue], [$mcname, $mcvalue], [$swtname, $swtvalue], [$swfname, $swfvalue], ['SwapUsed', $swused], );

	close FR;
	return @data;

}

#get Load usage of the System.
#return @array
#       name,value
sub getLoadStats()
{

	#my @datan;
	my $last;
	my $last5;
	my $last15;

	if ( -f "/proc/loadavg" )
	{
		open FR, "/proc/loadavg";
		while ( $line = <FR> )
		{
			$lastline = $line;
		}
		my @splitline = split ( " ", $lastline );
		$last   = @splitline[0];
		$last5  = @splitline[1];
		$last15 = @splitline[2];

	}
	@data = ( ['Last', $last], ['Last 5', $last5], ['Last 15', $last15], );

	close FR;
	return @data;

}

sub getNetworkStats()
{

	open DEV, '/proc/net/dev' or die $!;
	my ( $in, $out );
	my @data;

	$i = -1;
	while ( <DEV> )
	{
		if ( $_ =~ /\:/ && $_ !~ /lo/ )
		{
			$i++;
			my @iface = split ( ":", $_ );
			$if =~ s/\ //g;
			$if = @iface[0];

			#exit;
			#next unless /$dev:\d+/;
			#($in,$out) = (split)[0,8];
			if ( $_ =~ /:\ / )
			{
				( $in, $out ) = ( split )[1, 9];
			}
			else
			{
				( $in, $out ) = ( split )[0, 8];
				$in = ( split /:/, $in )[1];
			}
			$in  = ( ( $in / 1024 ) / 1024 );
			$out = ( ( $out / 1024 ) / 1024 );
			$in  = sprintf ( '%.2f', $in );
			$out = sprintf ( '%.2f', $out );
			$if =~ s/\ //g;

			$interface[$i]    = $if;
			$interfacein[$i]  = $in;
			$interfaceout[$i] = $out;
		}

	}

	for ( $j = 0 ; $j <= $i ; $j++ )
	{
		push @data, [$interface[$j] . ' in', $interfacein[$j]], [$interface[$j] . ' out', $interfaceout[$j]];

	}

	close DEV;
	return @data;

}

#get Date
sub getDate()
{

	#$timeseconds = time();
	$now = ctime();
	return $now;

}

#get hostname
sub getHostname()
{

	use Sys::Hostname;
	my $host = hostname();
	return $host;

}

#get total CPU usage
sub getCPU()
{

	my @data;
	my $interval = 1;
	if ( -f "/proc/stat" )
	{
		open FR, "/proc/stat";
		foreach $line ( <FR> )
		{
			if ( $line =~ /^cpu\ / )
			{
				my @line_s = split ( "\ ", $line );
				$cpu_user1    = @line_s[1];
				$cpu_nice1    = @line_s[2];
				$cpu_sys1     = @line_s[3];
				$cpu_idle1    = @line_s[4];
				$cpu_iowait1  = @line_s[5];
				$cpu_irq1     = @line_s[6];
				$cpu_softirq1 = @line_s[7];
				$cpu_total1   = $cpu_user1 + $cpu_nice1 + $cpu_sys1 + $cpu_idle1 + $cpu_iowait1 + $cpu_irq1 + $cpu_softirq1;
			}
		}
		close FR;
		open FR, "/proc/stat";
		sleep $interval;
		foreach $line ( <FR> )
		{
			if ( $line =~ /^cpu\ / )
			{
				@line_s       = split ( "\ ", $line );
				$cpu_user2    = @line_s[1];
				$cpu_nice2    = @line_s[2];
				$cpu_sys2     = @line_s[3];
				$cpu_idle2    = @line_s[4];
				$cpu_iowait2  = @line_s[5];
				$cpu_irq2     = @line_s[6];
				$cpu_softirq2 = @line_s[7];
				$cpu_total2   = $cpu_user2 + $cpu_nice2 + $cpu_sys2 + $cpu_idle2 + $cpu_iowait2 + $cpu_irq2 + $cpu_softirq2;
			}

		}
		close FR;
		$diff_cpu_user    = $cpu_user2 - $cpu_user1;
		$diff_cpu_nice    = $cpu_nice2 - $cpu_nice1;
		$diff_cpu_sys     = $cpu_sys2 - $cpu_sys1;
		$diff_cpu_idle    = $cpu_idle2 - $cpu_idle1;
		$diff_cpu_iowait  = $cpu_iowait2 - $cpu_iowait1;
		$diff_cpu_irq     = $cpu_irq2 - $cpu_irq1;
		$diff_cpu_softirq = $cpu_softirq2 - $cpu_softirq1;
		$diff_cpu_total   = $cpu_total2 - $cpu_total1;

		$cpu_user    = ( 100 * $diff_cpu_user ) / $diff_cpu_total;
		$cpu_nice    = ( 100 * $diff_cpu_nice ) / $diff_cpu_total;
		$cpu_sys     = ( 100 * $diff_cpu_sys ) / $diff_cpu_total;
		$cpu_idle    = ( 100 * $diff_cpu_idle ) / $diff_cpu_total;
		$cpu_iowait  = ( 100 * $diff_cpu_iowait ) / $diff_cpu_total;
		$cpu_irq     = ( 100 * $diff_cpu_irq ) / $diff_cpu_total;
		$cpu_softirq = ( 100 * $diff_cpu_softirq ) / $diff_cpu_total;

		#	$cpu_total = (100*$diff_cpu_total)/$diff_cpu_total;
		$cpu_usage = $cpu_user + $cpu_nice + $cpu_sys + $cpu_iowait + $cpu_irq + $cpu_softirq;

	}
	else
	{
		print "File /proc/stat not exist ...\n";
		exit 1;

	}
	$cpu_user    = sprintf ( "%.2f", $cpu_user );
	$cpu_nice    = sprintf ( "%.2f", $cpu_nice );
	$cpu_sys     = sprintf ( "%.2f", $cpu_sys );
	$cpu_iowait  = sprintf ( "%.2f", $cpu_iowait );
	$cpu_irq     = sprintf ( "%.2f", $cpu_irq );
	$cpu_softirq = sprintf ( "%.2f", $cpu_softirq );
	$cpu_idle    = sprintf ( "%.2f", $cpu_idle );
	$cpu_usage   = sprintf ( "%.2f", $cpu_usage );

	$cpu_user    =~ s/,/\./g;
	$cpu_nice    =~ s/,/\./g;
	$cpu_sys     =~ s/,/\./g;
	$cpu_iowait  =~ s/,/\./g;
	$cpu_softirq =~ s/,/\./g;
	$cpu_idle    =~ s/,/\./g;
	$cpu_usage   =~ s/,/\./g;

	@data = ( ['CPUuser', $cpu_user], ['CPUnice', $cpu_nice], ['CPUsys', $cpu_sys], ['CPUiowait', $cpu_iowait], ['CPUirq', $cpu_irq], ['CPUsoftirq', $cpu_softirq], ['CPUidle', $cpu_idle], ['CPUusage', $cpu_usage], );

	return @data;

}

#
sub zsystem(@exec)
{
	( @exec ) = @_;

	system ( "@exec" );
	return $?;
}

#do not remove this
1
