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

#
sub getGSLBFarmPidFile($farmname)
{
	my ( $fname ) = @_;

	my $pidf = "$configdir\/$fname\_gslb.cfg\/run\/gdnsd.pid";

	return $pidf;
}

#
sub getGSLBStartCommand($farmname)
{
	my ( $fname ) = @_;

	my $cmd = "$gdnsd -c $configdir\/$fname\_gslb.cfg start";

	return $cmd;
}

#
sub getGSLBStopCommand($farmname)
{
	my ( $fname ) = @_;

	my $cmd = "$gdnsd -c $configdir\/$fname\_gslb.cfg stop";

	return $cmd;
}

# Create a new Zone in a GSLB farm
sub setFarmGSLBNewZone($fname,$service)
{
	my ( $fname, $svice ) = @_;

	my $output = -1;

	opendir ( DIR, "$configdir\/$fname\_gslb.cfg\/zones\/" );
	my @files = grep { /^$svice/ } readdir ( DIR );
	closedir ( DIR );

	if ( $files == 0 )
	{
		open FO, ">$configdir\/$fname\_gslb.cfg\/zones\/$svice";
		print FO "@	SOA ns1 hostmaster (\n	1\n	7200\n	1800\n	259200\n	900\n)\n\n";
		print FO "@		NS	ns1 ;index_0\n";
		print FO "ns1		A	0.0.0.0 ;index_1\n";
		close FO;
		$output = 0;
	}
	else
	{
		$output = 1;
	}

	return $output;
}

# Delete an existing Zone in a GSLB farm
sub setFarmGSLBDeleteZone($fname,$service)
{
	my ( $fname, $svice ) = @_;

	my $output = -1;

	use File::Path 'rmtree';
	rmtree( ["$configdir\/$fname\_gslb.cfg\/zones\/$svice"] );
	$output = 0;

	return $output;
}

# Create a new Service in a GSLB farm
sub setFarmGSLBNewService($fname,$service,$algorithm)
{
	my ( $fname, $svice, $alg ) = @_;

	my $output = -1;
	my $gsalg  = "simplefo";

	if ( $alg eq "roundrobin" )
	{
		$gsalg = "multifo";
	}
	else
	{
		if ( $alg eq "prio" )
		{
			$gsalg = "simplefo";
		}
	}
	opendir ( DIR, "$configdir\/$fname\_gslb.cfg\/plugins\/" );
	my @files = grep { /^$svice/ } readdir ( DIR );
	closedir ( DIR );

	if ( $files == 0 )
	{
		open FO, ">$configdir\/$fname\_gslb.cfg\/plugins\/$svice.cfg";
		print FO "$gsalg => {\n\tservice_types = up\n";
		print FO "\t$svice => {\n\t\tservice_types = tcp_80\n";
		print FO "\t}\n}\n";
		close FO;
		$output = 0;

		# Include the plugin file in the main configuration
		tie @fileconf, 'Tie::File', "$configdir\/$fname\_gslb.cfg\/config";
		my $found = 0;
		my $index = 0;
		foreach $line ( @fileconf )
		{
			if ( $line =~ /plugins => / )
			{
				$found = 1;
				$index++;
			}
			if ( $found == 1 )
			{
				splice @fileconf, $index, 0, "	\$include{plugins\/$svice.cfg},";
				last;
			}
			$index++;
		}
		untie @fileconf;
		&setFarmVS( $fname, $svice, "dpc", "80" );
	}
	else
	{
		$output = -1;
	}

	return $output;
}

# Delete an existing Service in a GSLB farm
sub setFarmGSLBDeleteService($fname,$service)
{
	my ( $fname, $svice ) = @_;

	my $output = -1;

	use File::Path 'rmtree';
	rmtree( ["$configdir\/$fname\_gslb.cfg\/plugins\/$svice.cfg"] );
	tie @fileconf, 'Tie::File', "$configdir\/$fname\_gslb.cfg\/config";
	my $found = 0;
	my $index = 0;
	foreach $line ( @fileconf )
	{
		if ( $line =~ /plugins => / )
		{
			$found = 1;
			$index++;
		}
		if ( $found == 1 && $line =~ /plugins\/$svice.cfg/ )
		{
			splice @fileconf, $index, 1;
			last;
		}
		$index++;
	}
	untie @fileconf;
	$output = 0;

	return $output;
}

#
sub getFarmGSLBBootStatus($file)
{
	my ( $file ) = @_;

	open FI, "<$configdir/$file/config";
	my $first = "true";
	while ( $line = <FI> )
	{
		if ( $line ne "" && $first eq "true" )
		{
			$first = "false";
			my @line_a = split ( "\;", $line );
			$output = @line_a[1];
			chomp ( $output );
		}
	}
	close FI;

	return $output;
}

#
sub setFarmGSLBBootStatus($fname, $status)
{
	my ( $fname, $status ) = @_;

	use Tie::File;
	tie @filelines, 'Tie::File', "$configdir\/$file\/config";
	my $first = 1;
	foreach ( @filelines )
	{
		if ( $first eq 1 )
		{
			if ( $status eq "start" )
			{
				s/\;down/\;up/g;
			}
			else
			{
				s/\;up/\;down/g;
			}
			$first = 0;
			last;
		}
	}
	untie @filelines;

	return $output;
}

#
sub setFarmGSLBStatus($fname, $status, $writeconf)
{

	my ( $fname, $status, $writeconf ) = @_;

	my $exec = "";

	unlink ( "/tmp/$fname.lock" );
	if ( $writeconf eq "true" )
	{
		&setFarmGSLBBootStatus( $fname, $status );
	}

	if ( $status eq "start" )
	{
		$exec = &getGSLBStartCommand( $fname );
	}
	else
	{
		$exec = &getGSLBStopCommand( $fname );
	}
	&logfile( "setFarmGSLBStatus(): Executing $exec" );
	zsystem( "$exec > /dev/null 2>&1" );
	$output = $?;
	if ( $output != 0 )
	{
		$output = -1;
	}

	return $output;
}

#function that check if the config file is OK.
sub getFarmGSLBConfigIsOK($ffile)
{
	( $ffile ) = @_;

	my $output = -1;

	&logfile( "getFarmGSLBConfigIsOK(): Executing $gdnsd -c $configdir\/$ffile/etc checkconf " );
	my $run = `$gdnsd -c $configdir\/$ffile/etc checkconf 2>&1`;
	$output = $?;
	&logfile( "Execution output: $output " );

	return $output;
}

# Create a new GSLB farm
sub setFarmGSLB($fvip,$fvipp,$fname)
{
	my ( $fvip, $fvipp, $fname ) = @_;

	my $output = -1;
	my $type   = "gslb";

	mkdir "$configdir\/$fname\_$type.cfg";
	mkdir "$configdir\/$fname\_$type.cfg\/";
	mkdir "$configdir\/$fname\_$type.cfg\/zones";
	mkdir "$configdir\/$fname\_$type.cfg\/plugins";
	mkdir "$configdir\/$fname\_$type.cfg\/run";
	mkdir "$configdir\/$fname\_$type.cfg\/lib";
	my $httpport = 35060;
	while ( $httpport < 35160 && &checkport( 127.0.0.1, $httpport ) eq "true" )
	{
		$httpport++;
	}
	if ( $httpport == 35160 )
	{
		$output = -1;    # No room for a new farm
	}
	else
	{
		open FO, ">$configdir\/$fname\_$type.cfg\/config";
		print FO ";up\noptions => {\n   run_dir = $configdir\/$fname\_gslb.cfg\/run\n   listen = $fvip\n   dns_port = $fvipp\n   http_port = $httpport\n   http_listen = 127.0.0.1\n}\n\n";
		print FO "service_types => { \n\n}\n\n";
		print FO "plugins => { \n\n}\n\n";
		close FO;

		#run farm
		my $exec = &getGSLBStartCommand( $fname );
		&logfile( "setFarmGSLB(): Executing $exec" );
		zsystem( "$exec > /dev/null 2>&1" );
		$output = $?;
		if ( $output != 0 )
		{
			$output = -1;
		}
	}
	if ( $output != 0 )
	{
		&runFarmDelete( $fname );
	}

	return $output;
}

# do not remove this
1
