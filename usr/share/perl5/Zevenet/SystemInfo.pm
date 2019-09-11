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

=begin nd
Function: getDate

	Get date string

Parameters:
	none - .

Returns:
	string - Date string.

	Example:

		"Mon May 22 10:42:39 2017"

See Also:
	zapi/v3/system.cgi, zapi/v3/system_stats.cgi, zapi/v2/system_stats.cgi
=cut

sub getDate
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	return scalar CORE::localtime ();
}

=begin nd
Function: getHostname

	Get system hostname

Parameters:
	none - .

Returns:
	string - Hostname.

See Also:
	setConntrackdConfig

	getZClusterLocalIp, setKeepalivedConfig, getZClusterRemoteHost, runSync, getZCusterStatusInfo

	setNotifCreateConfFile, setNotifData, getNotifData

	zapi/v3/cluster.cgi, zapi/v3/system_stats.cgi, zapi/v3/zapi.cgi, zapi/v2/system_stats.cgi

	zevenet
=cut

sub getHostname
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );

	my $uname    = &getGlobalConfiguration( 'uname' );
	my $hostname = `$uname -n`;
	chomp $hostname;

	return $hostname;
}

=begin nd
Function: getApplianceVersion

	Returns a string with the description of the appliance.

	NOTE: This function uses Tie::File, this module should be used only for writing files.

Parameters:
	none - .

Returns:
	string - Version string.

See Also:
	zapi/v3/system.cgi, zenbui.pl, zevenet
=cut

sub getApplianceVersion
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $version;
	my $hyperv;
	my $applianceFile = &getGlobalConfiguration( 'applianceVersionFile' );
	my $lsmod         = &getGlobalConfiguration( 'lsmod' );
	my @packages      = `$lsmod`;
	my @hypervisor    = grep ( /(xen|vm|hv|kvm)_/, @packages );

	# look for appliance vesion
	if ( -f $applianceFile )
	{
		require Tie::File;
		Tie::File->import;

		tie my @filelines, 'Tie::File', $applianceFile;
		$version = $filelines[0];
		untie @filelines;
	}

	# generate appliance version
	if ( !$version )
	{
		my $kernel = &getKernelVersion();

		my $awk      = &getGlobalConfiguration( 'awk' );
		my $ifconfig = &getGlobalConfiguration( 'ifconfig' );

		# look for mgmt interface
		my @ifaces = `$ifconfig -s | $awk '{print $1}'`;

		# Network appliance
		if ( grep ( /mgmt/, @ifaces ) )
		{
			$version = "ZNA 3300";
		}
		else
		{
			# select appliance verison
			if    ( $kernel =~ /3\.2\.0\-4/ )      { $version = "3110"; }
			elsif ( $kernel =~ /3\.16\.0\-4/ )     { $version = "4000"; }
			elsif ( $kernel =~ /3\.16\.7\-ckt20/ ) { $version = "4100"; }
			else { $version = "System version not detected"; }

			# virtual appliance
			if ( $hypervisor[0] =~ /(xen|vm|hv|kvm)_/ )
			{
				$version = "ZVA $version";
			}

			# baremetal appliance
			else
			{
				$version = "ZBA $version";
			}
		}

		# save version for future request
		require Tie::File;
		Tie::File->import;

		tie my @filelines, 'Tie::File', $applianceFile;
		$filelines[0] = $version;
		untie @filelines;
	}

	# virtual appliance
	if ( @hypervisor && $hypervisor[0] =~ /(xen|vm|hv|kvm)_/ )
	{
		$hyperv = $1;
		$hyperv = 'HyperV' if ( $hyperv eq 'hv' );
		$hyperv = 'Vmware' if ( $hyperv eq 'vm' );
		$hyperv = 'Xen' if ( $hyperv eq 'xen' );
		$hyperv = 'KVM' if ( $hyperv eq 'kvm' );
	}

# before zevenet versions had hypervisor in appliance version file, so not inclue it in the chain
	if ( $hyperv && $version !~ /hypervisor/ )
	{
		$version = "$version, hypervisor: $hyperv";
	}

	return $version;
}

=begin nd
Function: getCpuCores

	Get the number of CPU cores in the system.

Parameters:
	none - .

Returns:
	integer - Number of CPU cores.

See Also:
	zapi/v3/system_stats.cgi
=cut

sub getCpuCores
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $cpuinfo_filename = '/proc/stat';
	my $cores            = 1;

	open my $stat_file, '<', $cpuinfo_filename;

	while ( my $line = <$stat_file> )
	{
		next unless $line =~ /^cpu(\d) /;
		$cores = $1 + 1;
	}

	close $stat_file;

	return $cores;
}

=begin nd
Function: getCPUSecondToJiffy

	Is returns the number of jiffies for X seconds.
	If any value is sent. The function calculate the how many jiffies are 1 second

Parameters:
	seconds - Number of seconds to pass to jiffies

Returns:
	integer - Number of jiffies

=cut

sub getCPUSecondToJiffy
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $sec = shift // 1;
	my $ticks = &getCPUTicks();

	return -1 unless ( $ticks > 0 );

	return $sec * $ticks;
}

=begin nd
Function: getCPUJiffiesNow

	Get the number of jiffies since the last boot

Parameters:
	none - .

Returns:
	integer - number of jiffies

=cut

sub getCPUJiffiesNow
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $jiffies = -1;
	my $file    = '/proc/timer_list';
	open my $fh, '<', $file or return -1;

	foreach my $line ( <$fh> )
	{
		if ( $line =~ /^jiffies: ([\d]+)/ )
		{
			$jiffies = $1;
			last;
		}
	}

	close $fh;

	return $jiffies;
}

=begin nd
Function: getCPUTicks

	Get how many ticks are for a Hertz

Parameters:
	none - .

Returns:
	integer - Number of ticks

=cut

sub getCPUTicks
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $ticks = -1;
	my $file  = '/boot/config-';    # end file with the kernel version

	my $kernel = &getKernelVersion();

	open my $fh, '<', "${file}$kernel" or return -1;

	foreach my $line ( <$fh> )
	{
		if ( $line =~ /^CONFIG_HZ[=: ](\d+)/ )
		{
			$ticks = $1;
			last;
		}
	}

	close $fh;

	return $ticks;
}

=begin nd
Function: setEnv

	Set envorioment variables. It get variables from global.conf

Parameters:
	none - .

Returns:
	none - .

=cut

sub setEnv
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	use Zevenet::Config;
	$ENV{ http_proxy }  = &getGlobalConfiguration( 'http_proxy' )  // "";
	$ENV{ https_proxy } = &getGlobalConfiguration( 'https_proxy' ) // "";
}

sub getKernelVersion
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	require Zevenet::Config;

	my $uname   = &getGlobalConfiguration( 'uname' );
	my $version = `$uname -r`;

	chomp $version;

	return $version;
}

1;
