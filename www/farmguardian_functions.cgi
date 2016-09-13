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

# Returns FarmGuardian config file for this farm
sub getFarmGuardianFile    # ($fname,$svice)
{
	my ( $fname, $svice ) = @_;

	opendir ( my $dir, "$configdir" ) || return -1;
	my @files =
	  grep { /^$fname\_$svice.*guardian\.conf/ && -f "$configdir/$_" }
	  readdir ( $dir );
	closedir $dir;

	my $nfiles = @files;

	if ( $nfiles == 0 )
	{
		return -1;
	}
	else
	{
		return $files[0];
	}
}

# Returns if FarmGuardian is activated for this farm
sub getFarmGuardianStatus    # ($fname,$svice)
{
	my ( $fname, $svice ) = @_;

	my $fgfile = &getFarmGuardianFile( $fname, $svice );

	if ( $fgfile == -1 )
	{
		return -1;
	}

	open FR, "$configdir/$fgfile";

	while ( $line = <FR> )
	{
		$lastline = $line;
	}

	my @line_s = split ( "\:\:\:", $lastline );
	$value = $line_s[3];
	close FR;

	if ( $value =~ /true/ )
	{
		return 1;
	}
	else
	{
		return 0;
	}
}

# Returns if FarmGuardian has logs activated for this farm
sub getFarmGuardianLog    # ($fname,$svice)
{
	my ( $fname, $svice ) = @_;

	my $fgfile = &getFarmGuardianFile( $fname, $svice );

	if ( $fgfile == -1 )
	{
		return -1;
	}

	open FR, "$configdir/$fgfile";

	while ( $line = <FR> )
	{
		$lastline = $line;
	}

	my @line_s = split ( "\:\:\:", $lastline );
	$value = $line_s[4];
	close FR;

	if ( $value =~ /true/ )
	{
		return 1;
	}
	else
	{
		return 0;
	}
}

# Start FarmGuardian rutine
sub runFarmGuardianStart    # ($fname,$svice)
{
	my ( $fname, $svice ) = @_;
	my $status = 0;
	my $log;
	my $sv;
	my $ftype  = &getFarmType( $fname );
	my $fgfile = &getFarmGuardianFile( $fname, $svice );
	my $fgpid  = &getFarmGuardianPid( $fname, $svice );

	if ( $fgpid != -1 )
	{
		return -1;
	}

	if ( $fgfile == -1 )
	{
		return -1;
	}

	if ( &getFarmGuardianLog( $fname, $svice ) )
	{
		$log = "-l";
	}

	if ( $svice ne "" )
	{
		$sv = "-s '$svice'";
	}

	if ( $ftype =~ /http/ && $svice eq "" )
	{
		# Iterate over every farm service
		my $services = &getFarmVS( $fname, "", "" );
		my @servs = split ( " ", $services );
		foreach $service ( @servs )
		{
			$stat = &runFarmGuardianStart( $fname, $service );
			$status = $status + $stat;
		}
	}
	else
	{
		&logfile( "running $farmguardian $fname $sv $log &" );
		zsystem( "$farmguardian $fname $sv $log &" );
		$status = $?;
	}

	return $status;
}

sub runFarmGuardianStop    # ($fname,$svice)
{
	my ( $fname, $svice ) = @_;
	my $status = 0;
	my $sv;
	my $type = &getFarmType( $fname );
	my $fgpid = &getFarmGuardianPid( $fname, $svice );

	if ( $type =~ /http/ && $svice eq "" )
	{
		# Iterate over every farm service
		my $services = &getFarmVS( $fname, "", "" );
		my @servs = split ( " ", $services );

		foreach $service ( @servs )
		{
			$stat = &runFarmGuardianStop( $fname, $service );
			$status |= $stat;
		}
	}
	else
	{
		if ( $svice ne "" )
		{
			$sv = "${svice}_";
		}

		if ( $fgpid != -1 )
		{
			&logfile( "running 'kill 9, $fgpid' stopping FarmGuardian $fname $svice" );
			kill 9, $fgpid;
			$status = $?;    # FIXME
			unlink glob ( "/var/run/$fname\_${sv}guardian.pid" );

			if ( $type eq "http" || $type eq "https" )
			{
				if ( -e "$configdir\/$fname\_status.cfg" )
				{
					my $portadmin = &getFarmPort( $fname );
					my $idsv      = &getFarmVSI( $fname, $svice );
					my $index     = -1;
					tie @filelines, 'Tie::File', "$configdir\/$fname\_status.cfg";

					for ( @filelines )
					{
						$index++;

						if ( $_ =~ /fgDOWN/ )
						{
							$_ = "-B 0 $idsv $index active";
							system ( "$poundctl -c $portadmin -B 0 $idsv $index >/dev/null 2>&1" );
						}
					}
					untie @filelines;
				}
			}

			if ( $type eq "l4xnat" )
			{
				my @be = &getFarmBackendStatusCtl( $fname );
				my $i  = -1;

				foreach my $line ( @be )
				{
					my @subbe = split ( ";", $line );
					$i++;
					my $backendid     = $i;
					my $backendserv   = $subbe[2];
					my $backendport   = $subbe[3];
					my $backendstatus = $subbe[7];

					if ( $backendstatus eq "fgDOWN" )
					{
						$status |= &setFarmBackendStatus( $fname, $i, "up" );
					}
				}
			}
		}
	}
	return $status;
}

# create farmguardian config file
sub runFarmGuardianCreate    # ($fname,$ttcheck,$script,$usefg,$fglog,$svice)
{
	my ( $fname, $ttcheck, $script, $usefg, $fglog, $svice ) = @_;

	my $fgfile = &getFarmGuardianFile( $fname, $svice );
	my $output = -1;

	if ( $fgfile == -1 )
	{
		if ( $svice ne "" )
		{
			$svice = "${svice}_";
		}
		$fgfile = "${fname}_${svice}guardian.conf";
	}

	&logfile(
		  "running 'Create FarmGuardian $ttcheck $script $usefg $fglog' for $fname farm"
	);
	if ( ( $ttcheck eq "" || $script eq "" ) && $usefg eq "true" )
	{
		return $output;
	}

	open FO, ">$configdir/$fgfile";
	print FO "$fname\:\:\:$ttcheck\:\:\:$script\:\:\:$usefg\:\:\:$fglog\n";
	$output = $?;
	close FO;

	return $output;
}

#
sub getFarmGuardianConf    # ($fname,$svice)
{
	my ( $fname, $svice ) = @_;
	my $lastline;

	# get filename
	my $fgfile = &getFarmGuardianFile( $fname, $svice );

	if ( $fgfile == -1 )
	{
		if ( $svice ne "" )
		{
			$svice = "${svice}_";
		}
		$fgfile = "${fname}_${svice}guardian.conf";
	}

	# read file
	open FG, "$configdir/$fgfile";
	my $line;
	while ( $line = <FG> )
	{
		if ( $line !~ /^#/ )
		{
			$lastline = $line;
			last;
		}
	}
	close FG;
	my @line = split ( ":::", $lastline );
	chomp ( @line );

	#&logfile("getting 'FarmGuardianConf @line' for $fname farm");
	return @line;
}

#
sub getFarmGuardianPid    # ($fname,$svice)
{
	my ( $fname, $svice ) = @_;

	my $pidfile = "";

	opendir ( my $dir, "$piddir" ) || return -1;
	@files =
	  grep { /^$fname\_$svice.*guardian\.pid/ && -f "$piddir/$_" } readdir ( $dir );
	closedir $dir;

	if ( @files )
	{
		$pidfile = $files[0];
		open FR, "$piddir/$pidfile";
		$fgpid = <FR>;
		close FR;
		return $fgpid;
	}
	else
	{
		return -1;
	}
}

# do not remove this
1;
