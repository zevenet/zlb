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

if ( -e "/usr/local/zenloadbalancer/www/farms_functions_ext.cgi" )
{
	require "/usr/local/zenloadbalancer/www/farms_functions_ext.cgi";
}

#asign a port for manage a pen Farm
sub setFarmPort()
{

	#down limit
	$inf = "10000";

	#up limit
	$sup = "20000";

	$lock = "true";
	do
	{
		$randport = int ( rand ( $sup - $inf ) ) + $inf;
		use IO::Socket;
		my $host = "127.0.0.1";
		my $sock = new IO::Socket::INET( PeerAddr => $host, PeerPort => $randport, Proto => 'tcp' );
		if ( $sock )
		{
			close ( $sock );
		}
		else
		{
			$lock = "false";
		}
	} while ( $lock eq "true" );

	return $randport;
}

#
sub setFarmBlacklistTime($fbltime,$fname)
{
	my ( $fbltime, $fname ) = @_;

	my $type   = &getFarmType( $fname );
	my $ffile  = &getFarmFile( $fname );
	my $output = -1;

	if ( $type eq "tcp" || $type eq "udp" )
	{
		&logfile( "setting 'Blacklist time $fbltime' for $fname farm $type" );
		my $fport       = &getFarmPort( $fname );
		my $fmaxservers = &getFarmMaxServers( $fname );
		&logfile( "running '$pen_ctl 127.0.0.1:$fport blacklist $fbltime'" );
		my @run = `$pen_ctl 127.0.0.1:$fport blacklist $fbltime 2> /dev/null`;
		$output = $?;
		&logfile( "running '$pen_ctl 127.0.0.1:$fport write '$configdir/$ffile''" );
		my @run = `$pen_ctl 127.0.0.1:$fport write '$configdir/$ffile'`;
		$output = $? && $output;
		&setFarmMaxServers( $fmaxservers, $fname );
	}

	if ( $type eq "http" || $type eq "https" )
	{
		tie @filefarmhttp, 'Tie::File', "$configdir/$ffile";
		my $i_f         = -1;
		my $array_count = @filefarmhttp;
		my $found       = "false";
		while ( $i_f <= $array_count && $found eq "false" )
		{
			$i_f++;
			if ( @filefarmhttp[$i_f] =~ /^Alive/ )
			{
				&logfile( "setting 'Blacklist time $fbltime' for $fname farm $type" );
				@filefarmhttp[$i_f] = "Alive\t\t $fbltime";
				$output             = $?;
				$found              = "true";
			}
		}
		untie @filefarmhttp;
	}

	return $output;
}

#
sub getFarmBlacklistTime($fname)
{
	my ( $fname ) = @_;

	my $type   = &getFarmType( $fname );
	my $ffile  = &getFarmFile( $fname );
	my $output = -1;

	if ( $type eq "tcp" || $type eq "udp" )
	{
		my $fport = &getFarmPort( $fname );
		&logfile( "running '$pen_ctl 127.0.0.1:$fport blacklist' for $fname farm" );
		$output = `$pen_ctl 127.0.0.1:$fport blacklist 2> /dev/null`;
	}

	if ( $type eq "http" || $type eq "https" )
	{
		open FR, "<$configdir\/$ffile";
		my @file = <FR>;
		foreach $line ( @file )
		{
			if ( $line =~ /Alive/i )
			{
				@line = split ( "\ ", $line );
				$output = @line[1];
			}
		}
		close FR;
	}

	#&logfile("getting 'Blacklist time $output' for $fname farm $type");
	return $output;
}

#
sub setFarmClientTimeout($client,$fname)
{
	my ( $client, $fname ) = @_;

	my $type   = &getFarmType( $fname );
	my $ffile  = &getFarmFile( $fname );
	my $output = -1;

	if ( $type eq "http" || $type eq "https" )
	{
		tie @filefarmhttp, 'Tie::File', "$configdir/$ffile";
		my $i_f         = -1;
		my $array_count = @filefarmhttp;
		my $found       = "false";
		while ( $i_f <= $array_count && $found eq "false" )
		{
			$i_f++;
			if ( @filefarmhttp[$i_f] =~ /^Client/ )
			{
				&logfile( "setting 'ClientTimeout $client' for $fname farm $type" );
				@filefarmhttp[$i_f] = "Client\t\t $client";
				$output             = $?;
				$found              = "true";
			}
		}
		untie @filefarmhttp;
	}

	return $output;
}

#
sub getFarmClientTimeout($fname)
{
	my ( $fname ) = @_;

	my $type   = &getFarmType( $fname );
	my $ffile  = &getFarmFile( $fname );
	my $output = -1;

	if ( $type eq "http" || $type eq "https" )
	{
		open FR, "<$configdir\/$ffile";
		my @file = <FR>;
		foreach $line ( @file )
		{
			if ( $line =~ /Client/i )
			{
				@line = split ( "\ ", $line );
				$output = @line[1];
			}
		}
		close FR;
	}

	#&logfile("getting 'ClientTimeout $output' for $fname farm $type");
	return $output;
}

#
sub setFarmSessionType($session,$fname,$service)
{
	my ( $session, $fname, $svice ) = @_;

	my $type   = &getFarmType( $fname );
	my $ffile  = &getFarmFile( $fname );
	my $output = -1;

	if ( $type eq "http" || $type eq "https" )
	{
		&logfile( "setting 'Session type $session' for $fname farm $type" );
		tie @contents, 'Tie::File', "$configdir\/$ffile";
		my $i     = -1;
		my $found = "false";
		foreach $line ( @contents )
		{
			$i++;
			if ( $session ne "nothing" )
			{
				if ( $line =~ "Session" )
				{
					@contents[$i] = "\t\tSession";
					$found = "true";
				}
				if ( $found eq "true" && $line =~ "End" )
				{
					@contents[$i] = "\t\tEnd";
					$found = "false";
				}
				if ( $line =~ "Type" )
				{
					@contents[$i] = "\t\t\tType $session";
					$output = $?;
					@contents[$i + 1] =~ s/#//g;
					if ( $session eq "URL" || $session eq "COOKIE" || $session eq "HEADER" )
					{
						@contents[$i + 2] =~ s/#//g;
					}
					else
					{
						if ( @contents[$i + 2] !~ /#/ )
						{
							@contents[$i + 2] =~ s/^/#/;
						}
					}
				}
			}
			if ( $session eq "nothing" )
			{
				if ( $line =~ "Session" )
				{
					@contents[$i] = "\t\t#Session $session";
					$found = "true";
				}
				if ( $found eq "true" && $line =~ "End" )
				{
					@contents[$i] = "\t\t#End";
					$found = "false";
				}
				if ( $line =~ "TTL" )
				{
					@contents[$i] = "#@contents[$i]";
				}
				if ( $line =~ "Type" )
				{
					@contents[$i] = "#@contents[$i]";
					$output = $?;
				}
				if ( $line =~ "ID" )
				{
					@contents[$i] = "#@contents[$i]";
				}
			}
		}
		untie @contents;
	}

	if ( $type eq "l4xnat" )
	{
		use Tie::File;
		tie @filelines, 'Tie::File', "$configdir\/$ffile";
		my $i = 0;
		for $line ( @filelines )
		{
			if ( $line =~ /^$fname\;/ )
			{
				my @args = split ( "\;", $line );
				$line = "@args[0]\;@args[1]\;@args[2]\;@args[3]\;@args[4]\;@args[5]\;$session\;@args[7]\;@args[8]";
				splice @filelines, $i, $line;
				$output = $?;
			}
			$i++;
		}
		untie @filelines;
		$output = $?;
	}

	return $output;
}

#
sub getFarmSessionType($fname,$service)
{
	my ( $fname, $svice ) = @_;

	my $type   = &getFarmType( $fname );
	my $ffile  = &getFarmFile( $fname );
	my $output = -1;

	if ( $type eq "http" || $type eq "https" )
	{
		open FR, "<$configdir\/$ffile";
		my @file = <FR>;
		foreach $line ( @file )
		{
			if ( $line =~ /Type/ && $line !~ /#/ )
			{
				@line = split ( "\ ", $line );
				$output = @line[1];
			}
		}
		close FR;
	}

	if ( $type eq "l4xnat" )
	{
		open FI, "<$configdir/$ffile";
		my $first = "true";
		while ( $line = <FI> )
		{
			if ( $line ne "" && $first eq "true" )
			{
				$first = "false";
				my @line = split ( "\;", $line );
				$output = @line[6];
			}
		}
		close FI;
	}

	return $output;
}

#
sub setFarmSessionId($sessionid,$fname,$service)
{
	my ( $sessionid, $fname, $svice ) = @_;

	my $type   = &getFarmType( $fname );
	my $ffile  = &getFarmFile( $fname );
	my $output = -1;

	if ( $type eq "http" || $type eq "https" )
	{
		tie @filefarmhttp, 'Tie::File', "$configdir/$ffile";
		my $i_f         = -1;
		my $array_count = @filefarmhttp;
		my $found       = "false";
		while ( $i_f <= $array_count && $found eq "false" )
		{
			$i_f++;
			if ( @filefarmhttp[$i_f] =~ /ID/ )
			{
				&logfile( "setting 'Session id $sessionid' for $fname farm $type" );
				@filefarmhttp[$i_f] = "\t\t\tID \"$sessionid\"";
				$output             = $?;
				$found              = "true";
			}
		}

		untie @filefarmhttp;
	}

	return $output;
}

#
sub getFarmSessionId($fname,$service)
{
	my ( $fname, $svice ) = @_;

	my $type   = &getFarmType( $fname );
	my $ffile  = &getFarmFile( $fname );
	my $output = -1;

	if ( $type eq "http" || $type eq "https" )
	{
		open FR, "<$configdir\/$ffile";
		my @file = <FR>;
		foreach $line ( @file )
		{
			if ( $line =~ /ID/ )
			{
				@line = split ( "\ ", $line );
				$output = @line[1];
				$output =~ s/\"//g;
			}
		}
		close FR;
	}

	#&logfile("getting 'Session id $output' for $fname farm $type");
	return $output;
}

#
sub setFarmHttpVerb($verb,$fname)
{
	my ( $verb, $fname ) = @_;

	my $type   = &getFarmType( $fname );
	my $ffile  = &getFarmFile( $fname );
	my $output = -1;

	if ( $type eq "http" || $type eq "https" )
	{
		tie @filefarmhttp, 'Tie::File', "$configdir/$ffile";
		my $i_f         = -1;
		my $array_count = @filefarmhttp;
		my $found       = "false";
		while ( $i_f <= $array_count && $found eq "false" )
		{
			$i_f++;
			if ( @filefarmhttp[$i_f] =~ /xHTTP/ )
			{
				&logfile( "setting 'Http verb $verb' for $fname farm $type" );
				@filefarmhttp[$i_f] = "\txHTTP $verb";
				$output             = $?;
				$found              = "true";
			}
		}
		untie @filefarmhttp;
	}

	return $output;
}

#
sub getFarmHttpVerb($fname)
{
	my ( $fname ) = @_;

	my $type   = &getFarmType( $fname );
	my $ffile  = &getFarmFile( $fname );
	my $output = -1;

	if ( $type eq "http" || $type eq "https" )
	{
		open FR, "<$configdir\/$ffile";
		my @file = <FR>;
		foreach $line ( @file )
		{
			if ( $line =~ /xHTTP/ )
			{
				@line = split ( "\ ", $line );
				$output = @line[1];
			}
		}
		close FR;
	}

	#&logfile("getting 'Http verb $output' for $fname farm $type");
	return $output;
}

#change HTTP or HTTP listener
sub setFarmListen($farmlisten)
{
	my ( $fname, $flisten ) = @_;

	my $ffile = &getFarmFile( $fname );
	tie @filefarmhttp, 'Tie::File', "$configdir/$ffile";
	my $i_f         = -1;
	my $array_count = @filefarmhttp;
	my $found       = "false";
	while ( $i_f <= $array_count && $found eq "false" )
	{
		$i_f++;
		if ( @filefarmhttp[$i_f] =~ /^ListenHTTP/ && $flisten eq "http" )
		{
			@filefarmhttp[$i_f] = "ListenHTTP";
		}
		if ( @filefarmhttp[$i_f] =~ /^ListenHTTP/ && $flisten eq "https" )
		{
			@filefarmhttp[$i_f] = "ListenHTTPS";
		}

		#
		if ( @filefarmhttp[$i_f] =~ /.*Cert\ \"/ && $flisten eq "http" )
		{
			@filefarmhttp[$i_f] =~ s/Cert\ \"/#Cert\ \"/;
		}
		if ( @filefarmhttp[$i_f] =~ /.*Cert\ \"/ && $flisten eq "https" )
		{
			@filefarmhttp[$i_f] =~ s/#//g;

		}

		#
		if ( @filefarmhttp[$i_f] =~ /.*Ciphers\ \"/ && $flisten eq "http" )
		{
			@filefarmhttp[$i_f] =~ s/Ciphers\ \"/#Ciphers\ \"/;
		}
		if ( @filefarmhttp[$i_f] =~ /.*Ciphers\ \"/ && $flisten eq "https" )
		{
			@filefarmhttp[$i_f] =~ s/#//g;

		}

		# Enable 'Disable SSLv3'
		if ( @filefarmhttp[$i_f] =~ /.*Disable SSLv3$/ && $flisten eq "http" )
		{
			@filefarmhttp[$i_f] =~ s/Disable SSLv3/#Disable SSLv3/;
		}
		elsif ( @filefarmhttp[$i_f] =~ /.*DisableSSLv3$/ && $flisten eq "http" )
		{
			@filefarmhttp[$i_f] =~ s/DisableSSLv3/#DisableSSLv3/;
		}
		if ( @filefarmhttp[$i_f] =~ /.*Disable SSLv3$/ && $flisten eq "https" )
		{
			@filefarmhttp[$i_f] =~ s/#//g;
		}
		elsif ( @filefarmhttp[$i_f] =~ /.*DisableSSLv3$/ && $flisten eq "https" )
		{
			@filefarmhttp[$i_f] =~ s/#//g;
		}

		# Enable SSLHonorCipherOrder
		if ( @filefarmhttp[$i_f] =~ /.*SSLHonorCipherOrder/ && $flisten eq "http" )
		{
			@filefarmhttp[$i_f] =~ s/SSLHonorCipherOrder/#SSLHonorCipherOrder/;
		}
		if ( @filefarmhttp[$i_f] =~ /.*SSLHonorCipherOrder/ && $flisten eq "https" )
		{
			@filefarmhttp[$i_f] =~ s/#//g;
		}

		# Enable StrictTransportSecurity
		if ( @filefarmhttp[$i_f] =~ /.*StrictTransportSecurity/ && $flisten eq "http" )
		{
			@filefarmhttp[$i_f] =~ s/StrictTransportSecurity/#StrictTransportSecurity/;
		}
		if ( @filefarmhttp[$i_f] =~ /.*StrictTransportSecurity/ && $flisten eq "https" )
		{
			@filefarmhttp[$i_f] =~ s/#//g;
		}

		if ( @filefarmhttp[$i_f] =~ /ZWACL-END/ )
		{
			$found = "true";
		}

	}
	untie @filefarmhttp;
}

#asign a RewriteLocation vaue to a farm HTTP or HTTPS
sub setFarmRewriteL($fname,$rewritelocation)
{
	my ( $fname, $rewritelocation ) = @_;

	my $type   = &getFarmType( $fname );
	my $ffile  = &getFarmFile( $fname );
	my $output = -1;
	&logfile( "setting 'Rewrite Location' for $fname to $rewritelocation" );

	if ( $type eq "http" || $type eq "https" )
	{
		tie @filefarmhttp, 'Tie::File', "$configdir/$ffile";
		my $i_f         = -1;
		my $array_count = @filefarmhttp;
		my $found       = "false";
		while ( $i_f <= $array_count && $found eq "false" )
		{
			$i_f++;
			if ( @filefarmhttp[$i_f] =~ /RewriteLocation\ .*/ )
			{
				@filefarmhttp[$i_f] = "\tRewriteLocation $rewritelocation";
				$output             = $?;
				$found              = "true";
			}
		}
		untie @filefarmhttp;
	}

}

#set ConnTo value to a farm HTTP or HTTPS
sub setFarmConnTO($tout,$fname)
{
	my ( $tout, $fname ) = @_;

	my $type   = &getFarmType( $fname );
	my $ffile  = &getFarmFile( $fname );
	my $output = -1;

	&logfile( "setting 'ConnTo timeout $tout' for $fname farm $type" );

	if ( $type eq "http" || $type eq "https" )
	{
		tie @filefarmhttp, 'Tie::File', "$configdir/$ffile";
		my $i_f         = -1;
		my $array_count = @filefarmhttp;
		my $found       = "false";
		while ( $i_f <= $array_count && $found eq "false" )
		{
			$i_f++;
			if ( @filefarmhttp[$i_f] =~ /^ConnTO.*/ )
			{
				@filefarmhttp[$i_f] = "ConnTO\t\t $tout";
				$output             = $?;
				$found              = "true";
			}
		}
		untie @filefarmhttp;
	}

	return $output;

}

#Get RewriteLocation Header configuration HTTP and HTTPS farms
sub getFarmRewriteL($fname)
{
	my ( $fname ) = @_;

	my $type   = &getFarmType( $fname );
	my $ffile  = &getFarmFile( $fname );
	my $output = -1;

	if ( $type eq "http" || $type eq "https" )
	{
		open FR, "<$configdir\/$ffile";
		my @file = <FR>;
		foreach $line ( @file )
		{
			if ( $line =~ /RewriteLocation\ .*/ )
			{
				@line = split ( "\ ", $line );
				$output = @line[1];
			}
		}
		close FR;
	}

	#&logfile("getting 'Timeout $output' for $fname farm $type");
	return $output;

}

#get farm ConnTO value for http and https farms
sub getFarmConnTO($fname)
{
	my ( $fname ) = @_;

	my $type   = &getFarmType( $fname );
	my $ffile  = &getFarmFile( $fname );
	my $output = -1;

	if ( $type eq "http" || $type eq "https" )
	{
		open FR, "<$configdir\/$ffile";
		my @file = <FR>;
		foreach $line ( @file )
		{
			if ( $line =~ /^ConnTO/ )
			{
				@line = split ( "\ ", $line );
				$output = @line[1];
			}
		}
		close FR;
	}

	return $output;
}

#asign a timeout value to a farm
sub setFarmTimeout($tout,$fname)
{
	my ( $tout, $fname ) = @_;

	my $type   = &getFarmType( $fname );
	my $ffile  = &getFarmFile( $fname );
	my $output = -1;

	&logfile( "setting 'Timeout $tout' for $fname farm $type" );

	if ( $type eq "tcp" || $type eq "udp" )
	{
		my $fport       = &getFarmPort( $fname );
		my $fmaxservers = &getFarmMaxServers( $fname );
		&logfile( "running '$pen_ctl 127.0.0.1:$fport timeout $tout' for $fname farm $type" );
		my @run = `$pen_ctl 127.0.0.1:$fport timeout $tout 2> /dev/null`;
		$output = $?;
		&logfile( "running '$pen_ctl 127.0.0.1:$fport write '$configdir/$ffile'' for $fname farm $type" );
		my @run = `$pen_ctl 127.0.0.1:$fport write '$configdir/$ffile'`;
		$output = $? && $output;
		&setFarmMaxServers( $fmaxservers, $fname );
	}

	if ( $type eq "http" || $type eq "https" )
	{
		tie @filefarmhttp, 'Tie::File', "$configdir/$ffile";
		my $i_f         = -1;
		my $array_count = @filefarmhttp;
		my $found       = "false";
		while ( $i_f <= $array_count && $found eq "false" )
		{
			$i_f++;
			if ( @filefarmhttp[$i_f] =~ /^Timeout/ )
			{
				@filefarmhttp[$i_f] = "Timeout\t\t $tout";
				$output             = $?;
				$found              = "true";
			}
		}
		untie @filefarmhttp;
	}

	return $output;
}

#
sub getFarmTimeout($fname)
{
	my ( $fname ) = @_;

	my $type   = &getFarmType( $fname );
	my $ffile  = &getFarmFile( $fname );
	my $output = -1;

	if ( $type eq "tcp" || $type eq "udp" )
	{
		my $fport = &getFarmPort( $fname );
		&logfile( "running '$pen_ctl 127.0.0.1:$fport timeout' for $fname farm $type" );
		$output = `$pen_ctl 127.0.0.1:$fport timeout 2> /dev/null`;
	}

	if ( $type eq "http" || $type eq "https" )
	{
		open FR, "<$configdir\/$ffile";
		my @file = <FR>;
		foreach $line ( @file )
		{
			if ( $line =~ /^Timeout/ )
			{
				@line = split ( "\ ", $line );
				$output = @line[1];
			}
		}
		close FR;
	}

	#&logfile("getting 'Timeout $output' for $fname farm $type");
	return $output;
}

# set the lb algorithm to a farm
sub setFarmAlgorithm($alg,$fname)
{
	my ( $alg, $fname ) = @_;

	my $type   = &getFarmType( $fname );
	my $ffile  = &getFarmFile( $fname );
	my $output = -1;

	&logfile( "setting 'Algorithm $alg' for $fname farm $type" );

	if ( $type eq "tcp" || $type eq "udp" )
	{
		my $fport       = &getFarmPort( $fname );
		my $fmaxservers = &getFarmMaxServers( $fname );
		my @run         = `$pen_ctl 127.0.0.1:$fport no hash 2> /dev/null`;
		my @run         = `$pen_ctl 127.0.0.1:$fport no prio 2> /dev/null`;
		my @run         = `$pen_ctl 127.0.0.1:$fport no weight 2> /dev/null`;
		$output = $?;
		if ( $alg ne "roundrobin" )
		{
			&logfile( "running '$pen_ctl 127.0.0.1:$fport $alg'" );
			my @run = `$pen_ctl 127.0.0.1:$fport $alg 2> /dev/null`;
			$output = $?;
		}
		my @run = `$pen_ctl 127.0.0.1:$fport write '$configdir/$ffile'`;
		&setFarmMaxServers( $fmaxservers, $fname );
	}

	if ( $type eq "datalink" )
	{
		use Tie::File;
		tie @filelines, 'Tie::File', "$configdir\/$ffile";
		my $i = 0;
		for $line ( @filelines )
		{
			if ( $line =~ /^$fname\;/ )
			{
				my @args = split ( "\;", $line );
				$line = "@args[0]\;@args[1]\;@args[2]\;$alg\;@args[4]";
				splice @filelines, $i, $line;
				$output = $?;
			}
			$i++;
		}
		untie @filelines;
		$output = $?;

		# Apply changes online
		if ( $output != -1 )
		{
			&runFarmStop( $farmname, "true" );
			&runFarmStart( $farmname, "true" );
		}
	}

	if ( $type eq "l4xnat" )
	{
		use Tie::File;
		tie @filelines, 'Tie::File', "$configdir\/$ffile";
		my $i = 0;
		for $line ( @filelines )
		{
			if ( $line =~ /^$fname\;/ )
			{
				my @args = split ( "\;", $line );
				$line = "@args[0]\;@args[1]\;@args[2]\;@args[3]\;@args[4]\;$alg\;@args[6]\;@args[7]\;@args[8]";
				splice @filelines, $i, $line;
				$output = $?;
			}
			$i++;
		}
		untie @filelines;
		$output = $?;
	}

	return $output;
}

#
sub getFarmAlgorithm($fname)
{
	my ( $fname ) = @_;

	my $type   = &getFarmType( $fname );
	my $ffile  = &getFarmFile( $fname );
	my $output = -1;

	if ( $type eq "tcp" || $type eq "udp" )
	{
		my $flb = "roundrobin";
		use File::Grep qw( fgrep fmap fdo );
		if ( fgrep { /^roundrobin/ } "$configdir/$ffile" )
		{
			$flb = "roundrobin";
		}
		if ( fgrep { /^hash/ } "$configdir/$ffile" )
		{
			$flb = "hash";
		}
		if ( fgrep { /^weight/ } "$configdir/$ffile" )
		{
			$flb = "weight";
		}
		if ( fgrep { /^prio/ } "$configdir/$ffile" )
		{
			$flb = "prio";
		}
		$output = $flb;
	}

	if ( $type eq "datalink" )
	{
		open FI, "<$configdir/$ffile";
		my $first = "true";
		while ( $line = <FI> )
		{
			if ( $line ne "" && $first eq "true" )
			{
				$first = "false";
				my @line = split ( "\;", $line );
				$output = @line[3];
			}
		}
		close FI;
	}

	if ( $type eq "l4xnat" )
	{
		open FI, "<$configdir/$ffile";
		my $first = "true";
		while ( $line = <FI> )
		{
			if ( $line ne "" && $first eq "true" )
			{
				$first = "false";
				my @line = split ( "\;", $line );
				$output = @line[5];
			}
		}
		close FI;
	}

	return $output;
}

# set the protocol to a farm
sub setFarmProto($proto,$fname)
{
	my ( $proto, $fname ) = @_;

	my $type   = &getFarmType( $fname );
	my $ffile  = &getFarmFile( $fname );
	my $output = -1;

	&logfile( "setting 'Protocol $proto' for $fname farm $type" );

	if ( $type eq "l4xnat" )
	{
		use Tie::File;
		tie @filelines, 'Tie::File', "$configdir\/$ffile";
		my $i = 0;
		for $line ( @filelines )
		{
			if ( $line =~ /^$fname\;/ )
			{
				my @args = split ( "\;", $line );
				if ( $proto eq "all" )
				{
					@args[3] = "*";
				}
				if ( $proto eq "sip" )
				{
					@args[3] = "5060";    # the port by default for sip protocol
					@args[4] = "nat";
				}
				$line = "@args[0]\;$proto\;@args[2]\;@args[3]\;@args[4]\;@args[5]\;@args[6]\;@args[7]\;@args[8]";
				splice @filelines, $i, $line;
				$output = $?;
			}
			$i++;
		}
		untie @filelines;
		$output = $?;
	}

	return $output;
}

#
sub getFarmProto($fname)
{
	my ( $fname ) = @_;

	my $type   = &getFarmType( $fname );
	my $ffile  = &getFarmFile( $fname );
	my $output = -1;

	if ( $type eq "l4xnat" )
	{
		open FI, "<$configdir/$ffile";
		my $first = "true";
		while ( $line = <FI> )
		{
			if ( $line ne "" && $first eq "true" )
			{
				$first = "false";
				my @line = split ( "\;", $line );
				$output = @line[1];
			}
		}
		close FI;
	}

	return $output;
}

#
sub getFarmNatType($fname)
{
	my ( $fname ) = @_;

	my $type   = &getFarmType( $fname );
	my $ffile  = &getFarmFile( $fname );
	my $output = -1;

	if ( $type eq "l4xnat" )
	{
		open FI, "<$configdir/$ffile";
		my $first = "true";
		while ( $line = <FI> )
		{
			if ( $line ne "" && $first eq "true" )
			{
				$first = "false";
				my @line = split ( "\;", $line );
				$output = @line[4];
			}
		}
		close FI;
	}

	return $output;
}

# set the NAT type for a farm
sub setFarmNatType($nat,$fname)
{
	my ( $nat, $fname ) = @_;

	my $type   = &getFarmType( $fname );
	my $ffile  = &getFarmFile( $fname );
	my $output = -1;

	&logfile( "setting 'NAT type $nat' for $fname farm $type" );

	if ( $type eq "l4xnat" )
	{
		use Tie::File;
		tie @filelines, 'Tie::File', "$configdir\/$ffile";
		my $i = 0;
		for $line ( @filelines )
		{
			if ( $line =~ /^$fname\;/ )
			{
				my @args = split ( "\;", $line );
				$line = "@args[0]\;@args[1]\;@args[2]\;@args[3]\;$nat\;@args[5]\;@args[6]\;@args[7]\;@args[8]";
				splice @filelines, $i, $line;
				$output = $?;
			}
			$i++;
		}
		untie @filelines;
		$output = $?;
	}

	return $output;
}

# set client persistence to a farm
sub setFarmPersistence($persistence,$fname)
{
	my ( $persistence, $fname ) = @_;

	my $type   = &getFarmType( $fname );
	my $ffile  = &getFarmFile( $fname );
	my $output = -1;

	if ( $type eq "tcp" || $type eq "udp" )
	{
		&logfile( "setting 'Persistence $persistence' for $fname farm $type" );
		my $fport       = &getFarmPort( $fname );
		my $fmaxservers = &getFarmMaxServers( $fname );
		if ( $persistence eq "true" )
		{
			&logfile( "running '$pen_ctl 127.0.0.1:$fport no roundrobin' for $fname farm $type" );
			my @run = `$pen_ctl 127.0.0.1:$fport no roundrobin 2> /dev/null`;
			$output = $?;
		}
		else
		{
			&logfile( "running '$pen_ctl 127.0.0.1:$fport roundrobin' for $fname farm $type" );
			my @run = `$pen_ctl 127.0.0.1:$fport roundrobin 2> /dev/null`;
			$output = $?;
		}
		my @run = `$pen_ctl 127.0.0.1:$fport write '$configdir/$ffile'`;
		&setFarmMaxServers( $fmaxservers, $fname );
	}

	if ( $type eq "l4xnat" )
	{
		use Tie::File;
		tie @filelines, 'Tie::File', "$configdir\/$ffile";
		my $i = 0;
		for $line ( @filelines )
		{
			if ( $line =~ /^$fname\;/ )
			{
				my @args = split ( "\;", $line );
				$line = "@args[0]\;@args[1]\;@args[2]\;@args[3]\;@args[4]\;@args[5]\;$persistence\;@args[7]\;@args[8]";
				splice @filelines, $i, $line;
				$output = $?;
			}
			$i++;
		}
		untie @filelines;
		$output = $?;
	}

	return $output;
}

#
sub getFarmPersistence($fname)
{
	my ( $fname ) = @_;

	my $type   = &getFarmType( $fname );
	my $ffile  = &getFarmFile( $fname );
	my $output = -1;

	if ( $type eq "tcp" || $type eq "udp" )
	{
		$output = "false";
		use File::Grep qw( fgrep fmap fdo );
		if ( fgrep { /^no\ roundrobin/ } "$configdir/$ffile" )
		{
			$output = "true";
		}
	}

	if ( $type eq "l4xnat" )
	{
		open FI, "<$configdir/$ffile";
		my $first = "true";
		while ( $line = <FI> )
		{
			if ( $line ne "" && $first eq "true" )
			{
				$first = "false";
				my @line = split ( "\;", $line );
				$output = @line[6];
			}
		}
		close FI;
	}

	return $output;
}

# set the max clients of a farm
sub setFarmMaxClientTime($maxcl,$track,$fname,$service)
{
	my ( $maxcl, $track, $fname, $svice ) = @_;

	my $type   = &getFarmType( $fname );
	my $ffile  = &getFarmFile( $fname );
	my $output = -1;

	&logfile( "setting 'MaxClientTime $maxcl $track' for $fname farm $type" );
	if ( $type eq "tcp" || $type eq "udp" )
	{
		$fport = &getFarmPort( $fname );
		my $fmaxservers = &getFarmMaxServers( $fname );
		my @run         = `$pen_ctl 127.0.0.1:$fport tracking $track 2> /dev/null`;
		my @run         = `$pen_ctl 127.0.0.1:$fport write '$configdir/$ffile'`;
		use Tie::File;
		tie @array, 'Tie::File', "$configdir/$ffile";
		for ( @array )
		{

			if ( $_ =~ "# pen" )
			{
				s/-c [0-9]*/-c $maxcl/g;
				$output = $?;
			}
		}
		untie @array;
		&setFarmMaxServers( $fmaxservers, $fname );
	}

	if ( $type eq "http" || $type eq "https" )
	{
		tie @filefarmhttp, 'Tie::File', "$configdir/$ffile";
		my $i_f         = -1;
		my $array_count = @filefarmhttp;
		my $found       = "false";
		while ( $i_f <= $array_count && $found eq "false" )
		{
			$i_f++;
			if ( @filefarmhttp[$i_f] =~ /TTL/ )
			{
				@filefarmhttp[$i_f] = "\t\t\tTTL $track";
				$output             = $?;
				$found              = "true";
			}
		}
		untie @filefarmhttp;
	}

	if ( $type eq "l4xnat" )
	{
		use Tie::File;
		tie @filelines, 'Tie::File', "$configdir\/$ffile";
		my $i = 0;
		for $line ( @filelines )
		{
			if ( $line =~ /^$fname\;/ )
			{
				my @args = split ( "\;", $line );
				$line = "@args[0]\;@args[1]\;@args[2]\;@args[3]\;@args[4]\;@args[5]\;@args[6]\;$track\;@args[8]";
				splice @filelines, $i, $line;
				$output = $?;
			}
			$i++;
		}
		untie @filelines;
		$output = $?;
	}

	return $output;
}

#
sub getFarmMaxClientTime($fname,$service)
{
	my ( $fname, $svice ) = @_;

	my $type = &getFarmType( $fname );
	my @output;

	if ( $type eq "tcp" || $type eq "udp" )
	{
		push ( @output, "" );
		push ( @output, "" );
		my $fport = &getFarmPort( $fname );
		&logfile( "running '$pen_ctl 127.0.0.1:$fport clients_max' " );
		@output[0] = `$pen_ctl 127.0.0.1:$fport clients_max 2> /dev/null`;
		@output[1] = `$pen_ctl 127.0.01:$fport tracking 2> /dev/null`;
	}

	if ( $type eq "http" || $type eq "https" )
	{
		push ( @output, "" );
		push ( @output, "" );
		$ffile = &getFarmFile( $fname );
		open FR, "<$configdir\/$ffile";
		my @file = <FR>;
		foreach $line ( @file )
		{
			if ( $line =~ /TTL/ )
			{
				@line = split ( "\ ", $line );
				@output[0] = "";
				@output[1] = @line[1];
			}
		}
		close FR;
	}

	if ( $type eq "l4xnat" )
	{
		my $ffile = &getFarmFile( $fname );
		open FI, "<$configdir/$ffile";
		my $first = "true";
		while ( $line = <FI> )
		{
			if ( $line ne "" && $first eq "true" )
			{
				$first = "false";
				my @line = split ( "\;", $line );
				@output = @line[7];
			}
		}
		close FI;
	}

	return @output;
}

# set the max conn of a farm
sub setFarmMaxConn($maxc,$fname)
{
	my ( $maxc, $fname ) = @_;

	my $type   = &getFarmType( $fname );
	my $ffile  = &getFarmFile( $fname );
	my $output = -1;

	&logfile( "setting 'MaxConn $maxc' for $fname farm $type" );
	if ( $type eq "tcp" || $type eq "udp" )
	{
		use Tie::File;
		tie @array, 'Tie::File', "$configdir/$ffile";
		for ( @array )
		{
			if ( $_ =~ "# pen" )
			{
				s/-x [0-9]*/-x $maxc/g;
				$output = $?;
			}
		}
		untie @array;
	}

	if ( $type eq "http" || $type eq "https" )
	{
		use Tie::File;
		tie @array, 'Tie::File', "$configdir/$ffile";
		for ( @array )
		{
			if ( $_ =~ "Threads" )
			{

				#s/^Threads.*/Threads   $maxc/g;
				$_      = "Threads\t\t$maxc";
				$output = $?;
			}

		}
		untie @array;

	}

	return $output;

}

# set the max servers of a farm
sub setFarmMaxServers($maxs,$fname)
{
	my ( $maxs, $fname ) = @_;

	my $type   = &getFarmType( $fname );
	my $ffile  = &getFarmFile( $fname );
	my $output = -1;

	&logfile( "setting 'MaxServers $maxs' for $fname farm $type" );
	if ( $type eq "tcp" || $type eq "udp" )
	{
		use Tie::File;
		tie @array, 'Tie::File', "$configdir/$ffile";
		for ( @array )
		{
			if ( $_ =~ "# pen" )
			{
				if ( $_ !~ "-S " )
				{
					s/# pen/# pen -S $maxs/g;
					$output = $?;
				}
				else
				{
					s/-S [0-9]*/-S $maxs/g;
					$output = $?;
				}
			}
		}
		untie @array;
	}

	return $output;
}

#
sub getFarmMaxServers($fname)
{
	my ( $fname ) = @_;

	my $type   = &getFarmType( $fname );
	my $output = -1;

	if ( $type eq "tcp" || $type eq "udp" )
	{
		my $fport = &getFarmPort( $fname );
		&logfile( "running '$pen_ctl 127.0.0.1:$fport servers' " );
		my @out = `$pen_ctl 127.0.0.1:$fport servers 2> /dev/null`;
		$output = @out;
	}

	#&logfile("getting 'MaxServers $output' for $fname farm $type");
	return $output;
}

#
sub getFarmServers($fname)
{
	my ( $fname ) = @_;

	my $type = &getFarmType( $fname );
	my @output;

	if ( $type eq "tcp" || $type eq "udp" )
	{
		my $fport = &getFarmPort( $fname );
		&logfile( "running '$pen_ctl 127.0.0.1:$fport servers' " );
		@output = `$pen_ctl 127.0.0.1:$fport servers 2> /dev/null`;
	}

	if ( $type eq "datalink" || $type eq "l4xnat" )
	{
		my $file = &getFarmFile( $fname );
		open FI, "<$configdir/$file";
		my $first  = "true";
		my $sindex = 0;
		while ( $line = <FI> )
		{
			if ( $line ne "" && $line =~ /^\;server\;/ && $first ne "true" )
			{

				#print "$line<br>";
				$line =~ s/^\;server/$sindex/g, $line;
				push ( @output, $line );
				$sindex = $sindex + 1;
			}
			else
			{
				$first = "false";
			}
		}
		close FI;
	}

	#&logfile("getting 'Servers @output' for $fname farm $type");
	return @output;
}

#
sub getFarmCertificate($fname)
{
	my ( $fname ) = @_;

	my $type   = &getFarmType( $fname );
	my $output = -1;

	if ( $type eq "https" )
	{
		my $file = &getFarmFile( $fname );
		open FI, "<$configdir/$file";
		my @content = <FI>;
		close FI;
		foreach $line ( @content )
		{
			if ( $line =~ /Cert/ && $line !~ /\#.*Cert/ )
			{
				my @partline = split ( '\"', $line );
				@partline = split ( "\/", @partline[1] );
				my $lfile = @partline;
				$output = @partline[$lfile - 1];
			}
		}
	}

	#&logfile("getting 'Certificate $output' for $fname farm $type");
	return $output;
}

#
sub setFarmCertificate($cfile,$fname)
{
	my ( $cfile, $fname ) = @_;

	my $type   = &getFarmType( $fname );
	my $ffile  = &getFarmFile( $fname );
	my $output = -1;

	&logfile( "setting 'Certificate $cfile' for $fname farm $type" );
	if ( $type eq "https" )
	{
		use Tie::File;
		tie @array, 'Tie::File', "$configdir/$ffile";
		for ( @array )
		{
			if ( $_ =~ /Cert/ )
			{
				s/.*Cert\ .*/\tCert\ \"$configdir\/$cfile\"/g;
				$output = $?;
			}
		}
		untie @array;
	}

	return $output;
}

# set xforwarder for feature for a farm
sub setFarmXForwFor($isset,$fname)
{
	my ( $isset, $fname ) = @_;

	my $type   = &getFarmType( $fname );
	my $ffile  = &getFarmFile( $fname );
	my $output = -1;

	&logfile( "setting 'XForwFor $isset' for $fname farm $type" );
	if ( $type eq "tcp" || $type eq "udp" )
	{
		my $fport       = &getFarmPort( $fname );
		my $fmaxservers = &getFarmMaxServers( $fname );
		if ( $isset eq "true" )
		{
			&logfile( "running '$pen_ctl 127.0.0.1:$fport http'" );
			my @run = `$pen_ctl 127.0.0.1:$fport http 2> /dev/null`;
			$output = $?;
		}
		else
		{
			&logfile( "running '$pen_ctl 127.0.0.1:$fport no http'" );
			my @run = `$pen_ctl 127.0.0.1:$fport no http 2> /dev/null`;
			$output = $?;
		}

		if ( $output != -1 )
		{
			my @run = `$pen_ctl 127.0.0.1:$fport write '$configdir/$ffile'`;
			&logfile( "configuration saved in $configdir/$ffile file" );
			&setFarmMaxServers( $fmaxservers, $fname );
		}
	}

	return $output;
}

#
sub getFarmXForwFor($fname)
{
	my ( $fname ) = @_;

	my $type   = &getFarmType( $fname );
	my $ffile  = &getFarmFile( $fname );
	my $output = -1;

	if ( $type eq "tcp" || $type eq "udp" )
	{
		use Tie::File;
		tie @array, 'Tie::File', "$configdir/$ffile";
		$output = "false";
		if ( grep ( /^http/, @array ) )
		{
			$output = "true";
		}
		untie @array;
	}

	#&logfile("getting 'XForwFor $output' for $fname farm $type");
	return $output;
}

#
sub getFarmGlobalStatus($fname)
{
	my ( $fname ) = @_;

	my $type = &getFarmType( $fname );
	my @run;

	if ( $type eq "tcp" || $type eq "udp" )
	{
		my $port = &getFarmPort( $fname );
		@run = `$pen_ctl 127.0.0.1:$port status`;
	}

	if ( $type eq "http" || $type eq "https" )
	{
		@run = `$poundctl -c "/tmp/$fname\_pound.socket"`;
	}

	#&logfile("getting 'GlobalStatus' for $fname farm $type");
	return @run;
}

sub getBackendEstConns($fname,$ip_backend,$port_backend,@netstat)
{
	my ( $fname, $ip_backend, $port_backend, @netstat ) = @_;
	my $type  = &getFarmType( $fname );
	my $fvip  = &getFarmVip( "vip", $fname );
	my $fvipp = &getFarmVip( "vipp", $fname );
	my @nets  = ();
	if ( $type eq "tcp" || $type eq "udp" || $type =~ "http" )
	{
		if ( $type =~ "http" )
		{
			$type = "tcp";
		}
		@nets = &getNetstatFilter( "$type", "", "\.*ESTABLISHED src=\.* dst=$ip_backend sport=\.* dport=$port_backend \.*src=$ip_backend \.*", "", @netstat );
	}
	if ( $type eq "l4xnat" )
	{
		my $proto   = &getFarmProto( $fname );
		my $nattype = &getFarmNatType( $farmname );
		my @fportlist;
		my $regexp = "";
		@fportlist = &getFarmPortList( $fvipp );
		if ( @fportlist[0] !~ /\*/ )
		{
			$regexp = "\(" . join ( '|', @fportlist ) . "\)";
		}
		else
		{
			$regexp = "\.*";
		}
		undef ( @fportlist );
		if ( $nattype eq "dnat" )
		{
			if ( $proto eq "sip" || $proto eq "all" || $proto eq "tcp" )
			{
				push ( @nets, &getNetstatFilter( "tcp", "", "\.* ESTABLISHED src=\.* dst=$fvip \.* dport=$regexp \.*src=$ip_backend \.*", "", @netstat ) );
			}
			if ( $proto eq "sip" || $proto eq "all" || $proto eq "udp" )
			{
				push ( @nets, &getNetstatFilter( "udp", "", "\.* src=\.* dst=$fvip \.* dport=$regexp .*src=$ip_backend \.*", "", @netstat ) );
			}
		}
		else
		{
			if ( $proto eq "sip" || $proto eq "all" || $proto eq "tcp" )
			{
				push ( @nets, &getNetstatFilter( "tcp", "", "\.*ESTABLISHED src=\.* dst=$fvip sport=\.* dport=$regexp \.*src=$ip_backend \.*", "", @netstat ) );
			}
			if ( $proto eq "sip" || $proto eq "all" || $proto eq "udp" )
			{
				push ( @nets, &getNetstatFilter( "udp", "", "\.* src=\.* dst=$fvip \.* dport=$regexp .*src=$ip_backend \.*", "", @netstat ) );
			}
		}

	}
	return @nets;
}

#
sub getFarmEstConns($fname,@netstat)
{
	my ( $fname, @netstat ) = @_;

	my $type  = &getFarmType( $fname );
	my $fvip  = &getFarmVip( "vip", $fname );
	my $fvipp = &getFarmVip( "vipp", $fname );
	my $pid   = &getFarmPid( $fname );
	my @nets  = ();

	if ( $pid eq "-" )
	{
		return @nets;
	}

	if ( $type eq "tcp" )
	{
		push ( @nets, &getNetstatFilter( "tcp", "", "\.* ESTABLISHED src=\.* dst=$fvip sport=\.* dport=$fvipp .*src=\.*", "", @netstat ) );

		#push(@nets, &getNetstatFilter("tcp","","\.* SYN\.* src=\.* dst=$fvip \.* src=$ip_backend \.*","",@netstat)); # TCP
	}

	if ( $type eq "udp" )
	{
		push ( @nets, &getNetstatFilter( "udp", "", "\.* src=\.* dst=$fvip sport=\.* dport=$fvipp .*src=\.*", "", @netstat ) );
	}

	if ( $type eq "http" || $type eq "https" )
	{
		push ( @nets, &getNetstatFilter( "tcp", "", "\.* ESTABLISHED src=\.* dst=$fvip sport=\.* dport=$fvipp .*src=\.*", "", @netstat ) );
	}

	if ( $type eq "l4xnat" )
	{
		my $proto   = &getFarmProto( $fname );
		my $nattype = &getFarmNatType( $farmname );
		my $fvip    = &getFarmVip( "vip", $fname );
		my $fvipp   = &getFarmVip( "vipp", $fname );
		my @fportlist;
		my $regexp = "";
		@fportlist = &getFarmPortList( $fvipp );
		if ( @fportlist[0] !~ /\*/ )
		{
			$regexp = "\(" . join ( '|', @fportlist ) . "\)";
		}
		else
		{
			$regexp = "\.*";
		}
		undef ( @fportlist );
		my @content = &getFarmBackendStatusCtl( $fname );
		my @backends = &getFarmBackendsStatus( $fname, @content );
		foreach ( @backends )
		{
			my @backends_data = split ( ";", $_ );
			if ( $backends_data[4] eq "up" )
			{
				my $ip_backend = $backends_data[0];
				if ( $nattype eq "dnat" )
				{
					if ( $proto eq "sip" || $proto eq "all" || $proto eq "tcp" )
					{
						push ( @nets, &getNetstatFilter( "tcp", "", "\.* ESTABLISHED src=\.* dst=$fvip \.* dport=$regexp .*src=$ip_backend \.*", "", @netstat ) );
					}
					if ( $proto eq "sip" || $proto eq "all" || $proto eq "udp" )
					{
						push ( @nets, &getNetstatFilter( "udp", "", "\.* src=\.* dst=$fvip \.* dport=$regexp .*src=$ip_backend \.*", "", @netstat ) );
					}
				}
				else
				{
					if ( $proto eq "sip" || $proto eq "all" || $proto eq "tcp" )
					{
						push ( @nets, &getNetstatFilter( "tcp", "", "\.* ESTABLISHED src=\.* dst=$fvip \.* dport=$regexp .*src=$ip_backend \.*", "", @netstat ) );
					}
					if ( $proto eq "sip" || $proto eq "all" || $proto eq "udp" )
					{
						push ( @nets, &getNetstatFilter( "udp", "", "\.* src=\.* dst=$fvip \.* dport=$regexp .*[^\[UNREPLIED\]] src=$ip_backend", "", @netstat ) );
					}
				}

			}
		}
	}

	return @nets;
}

sub getBackendTWConns($fname,$ip_backend,$port_backend,@netstat)
{
	my ( $fname, $ip_backend, $port_backend, @netstat ) = @_;
	my $type  = &getFarmType( $fname );
	my $fvip  = &getFarmVip( "vip", $fname );
	my $fvipp = &getFarmVip( "vipp", $fname );
	my @nets  = ();
	if ( $type eq "tcp" || $type eq "udp" || $type eq "http" )
	{
		if ( $type eq "http" )
		{
			$type = "tcp";
		}
		@nets = &getNetstatFilter( "$type", "", "\.*TIME\_WAIT src=$fvip dst=$ip_backend sport=\.* dport=$port_backend \.*", "", @netstat );
	}
	if ( $type eq "l4xnat" )
	{
		my $proto   = &getFarmProto( $fname );
		my $nattype = &getFarmNatType( $farmname );
		my @fportlist;
		my $regexp = "";
		@fportlist = &getFarmPortList( $fvipp );
		if ( @fportlist[0] !~ /\*/ )
		{
			$regexp = "\(" . join ( '|', @fportlist ) . "\)";
		}
		else
		{
			$regexp = "\.*";
		}
		undef ( @fportlist );
		if ( $proto eq "sip" || $proto eq "all" || $proto eq "tcp" )
		{
			push ( @nets, &getNetstatFilter( "tcp", "", "\.*TIME\_WAIT src=\.* dst=$fvip \.* dport=$regexp .*src=$ip_backend \.*", "", @netstat ) );
		}
		if ( $proto eq "sip" || $proto eq "all" || $proto eq "udp" )
		{
			push ( @nets, &getNetstatFilter( "udp", "", "\.*TIME\_WAIT src=\.* dst=$fvip \.* dport=$regexp .*src=$ip_backend .\*", "", @netstat ) );
		}

	}
	return @nets;
}

#
sub getFarmTWConns($fname,@netstat)
{
	my ( $fname, @netstat ) = @_;

	my $type  = &getFarmType( $fname );
	my $fvip  = &getFarmVip( "vip", $fname );
	my $fvipp = &getFarmVip( "vipp", $fname );
	my @nets  = ();

	#&logfile("getting 'TWConns' for $fname farm $type");
	if ( $type eq "tcp" || $type eq "http" || $type eq "https" )
	{
		push ( @nets, &getNetstatFilter( "tcp", "", "\.*\_WAIT src=\.* dst=$fvip sport=\.* dport=$fvipp .*src=\.*", "", @netstat ) );
	}

	if ( $type eq "udp" )
	{
		@nets = &getNetstatFilter( "udp", "\.\*\_WAIT\.\*", $ninfo, "", @netstat );
	}

	if ( $type eq "l4xnat" )
	{
		my $proto   = &getFarmProto( $fname );
		my $nattype = &getFarmNatType( $farmname );
		my $fvip    = &getFarmVip( "vip", $fname );
		my $fvipp   = &getFarmVip( "vipp", $fname );
		my @fportlist;
		my $regexp = "";
		@fportlist = &getFarmPortList( $fvipp );
		if ( @fportlist[0] !~ /\*/ )
		{
			$regexp = "\(" . join ( '|', @fportlist ) . "\)";
		}
		else
		{
			$regexp = "\.*";
		}
		undef ( @fportlist );
		my @content = &getFarmBackendStatusCtl( $fname );
		my @backends = &getFarmBackendsStatus( $fname, @content );
		foreach ( @backends )
		{
			my @backends_data = split ( ";", $_ );
			if ( $backends_data[4] eq "up" )
			{
				my $ip_backend   = $backends_data[0];
				my $port_backend = $backends_data[1];
				push ( @nets, &getNetstatFilter( "tcp", "", "\.*\_WAIT src=\.* dst=$fvip \.* dport=$regexp .*src=$ip_backend \.*", "", @netstat ) );
			}
		}
	}

	return @nets;
}

sub getBackendSYNConns($fname,$ip_backend,$port_backend,@netstat)
{
	my ( $fname, $ip_backend, $port_backend, @netstat ) = @_;
	my $type  = &getFarmType( $fname );
	my $fvip  = &getFarmVip( "vip", $fname );
	my $fvipp = &getFarmVip( "vipp", $fname );
	my @nets  = ();
	if ( $type eq "tcp" || $type eq "http" )
	{
		@nets = &getNetstatFilter( "tcp", "", "\.*SYN\.* src=\.* dst=$ip_backend sport=\.* dport=$port_backend \.*", "", @netstat );
	}
	if ( $type eq "udp" )
	{
		@nets = &getNetstatFilter( "udp", "", "\.* src=\.* dst=$ip_backend \.* dport=$port_backend \.*UNREPLIED\.* src=\.*", "", @netstat );
	}
	if ( $type eq "l4xnat" )
	{
		my $proto   = &getFarmProto( $fname );
		my $nattype = &getFarmNatType( $farmname );
		my @fportlist;
		my $regexp = "";
		@fportlist = &getFarmPortList( $fvipp );
		if ( @fportlist[0] !~ /\*/ )
		{
			$regexp = "\(" . join ( '|', @fportlist ) . "\)";
		}
		else
		{
			$regexp = "\.*";
		}
		undef ( @fportlist );
		if ( $nattype eq "dnat" )
		{
			if ( $proto eq "sip" || $proto eq "all" || $proto eq "tcp" )
			{
				push ( @nets, &getNetstatFilter( "tcp", "", "\.* SYN\.* src=\.* dst=$fvip \.* dport=$regexp \.* src=$ip_backend \.*", "", @netstat ) );
			}
			if ( $proto eq "sip" || $proto eq "all" || $proto eq "udp" )
			{
				push ( @nets, &getNetstatFilter( "udp", "", "\.* src=\.* dst=$fvip \.* dport=$regexp \.*UNREPLIED\.* src=$ip_backend \.*", "", @netstat ) );
			}
		}
		else
		{
			if ( $proto eq "sip" || $proto eq "all" || $proto eq "tcp" )
			{
				push ( @nets, &getNetstatFilter( "tcp", "", "\.* SYN\.* src=\.* dst=$fvip \.* dport=$regexp \.* src=$ip_backend \.*", "", @netstat ) );
			}
			if ( $proto eq "sip" || $proto eq "all" || $proto eq "udp" )
			{
				push ( @nets, &getNetstatFilter( "udp", "", "\.* src=\.* dst=$fvip \.* dport=$regexp \.*UNREPLIED\.* src=$ip_backend \.*", "", @netstat ) );
			}
		}

	}
	return @nets;
}

#
sub getFarmSYNConns($fname,@netstat)
{
	my ( $fname, @netstat ) = @_;

	my $type  = &getFarmType( $fname );
	my $fvip  = &getFarmVip( "vip", $fname );
	my $fvipp = &getFarmVip( "vipp", $fname );
	my @nets  = ();

	#&logfile("getting 'SYNConns' for $fname farm $type");
	if ( $type eq "tcp" )
	{
		push ( @nets, &getNetstatFilter( "tcp", "", "\.*SYN\.* src=\.* dst=$fvip sport=\.* dport=$fvipp \.* src=\.*", "", @netstat ) );
	}

	if ( $type eq "udp" )
	{
		push ( @nets, &getNetstatFilter( "udp", "", "\.* src=\.* dst=$fvip \.* dport=$fvipp \.*UNREPLIED\.* src=\.*", "", @netstat ) );
	}

	if ( $type eq "http" || $type eq "https" )
	{
		push ( @nets, &getNetstatFilter( "tcp", "", "\.* SYN\.* src=\.* dst=$fvip \.* dport=$fvipp \.* src=\.*", "", @netstat ) );
	}

	if ( $type eq "l4xnat" )
	{
		my $proto   = &getFarmProto( $fname );
		my $nattype = &getFarmNatType( $farmname );
		my $fvip    = &getFarmVip( "vip", $fname );
		my $fvipp   = &getFarmVip( "vipp", $fname );
		my @fportlist;
		my $regexp = "";
		@fportlist = &getFarmPortList( $fvipp );
		if ( @fportlist[0] !~ /\*/ )
		{
			$regexp = "\(" . join ( '|', @fportlist ) . "\)";
		}
		else
		{
			$regexp = "\.*";
		}
		undef ( @fportlist );
		my @content = &getFarmBackendStatusCtl( $fname );
		my @backends = &getFarmBackendsStatus( $fname, @content );
		foreach ( @backends )
		{
			my @backends_data = split ( ";", $_ );
			if ( $backends_data[4] eq "up" )
			{
				my $ip_backend = $backends_data[0];

				if ( $nattype eq "dnat" )
				{
					if ( $proto eq "sip" || $proto eq "all" || $proto eq "tcp" )
					{
						push ( @nets, &getNetstatFilter( "tcp", "", "\.* SYN\.* src=\.* dst=$fvip \.* dport=$regexp \.* src=$ip_backend \.*", "", @netstat ) );

						#push(@nets, &getNetstatFilter("tcp","","\.* SYN\.* src=\.* dst=$fvip \.* src=$ip_backend \.*","",@netstat)); # TCP
					}
					if ( $proto eq "sip" || $proto eq "all" || $proto eq "udp" )
					{
						push ( @nets, &getNetstatFilter( "udp", "", "\.* src=\.* dst=$fvip \.* dport=$regexp \.*UNREPLIED\.* src=$ip_backend \.*", "", @netstat ) );

						#push(@nets, &getNetstatFilter("udp","","\.* src=\.* dst=$fvip \.*UNREPLIED\.* src=$ip_backend \.*","",@netstat)); # UDP
					}
				}
				else
				{
					if ( $proto eq "sip" || $proto eq "all" || $proto eq "tcp" )
					{
						push ( @nets, &getNetstatFilter( "tcp", "", "\.* SYN\.* src=\.* dst=$fvip \.* dport=$regexp \.* src=$ip_backend \.*", "", @netstat ) );

						#push(@nets, &getNetstatFilter("tcp","","\.* SYN\.* src=\.* dst=$fvip \.* src=$ip_backend \.*","",@netstat)); # TCP
					}
					if ( $proto eq "sip" || $proto eq "all" || $proto eq "udp" )
					{
						push ( @nets, &getNetstatFilter( "udp", "", "\.* src=\.* dst=$fvip \.* dport=$regexp \.*UNREPLIED\.* src=$ip_backend \.*", "", @netstat ) );
					}

				}

			}
		}
	}

	return @nets;
}

sub getFarmPortList($fvipp)
{
	my ( $fvipp ) = @_;
	my @portlist;
	my $port;
	my @retportlist = ();
	@portlist = split ( ",", $fvipp );

	if ( $portlist[0] !~ /\*/ )
	{

		foreach $port ( @portlist )
		{
			if ( $port =~ /:/ )
			{
				my @intlimits = split ( ":", $port );
				for ( my $i = @intlimits[0] ; $i <= @intlimits[1] ; $i++ )
				{
					push ( @retportlist, $i );
				}
			}
			else
			{
				push ( @retportlist, $port );
			}

		}
	}
	else
	{
		$retportlist[0] = '*';
	}
	return @retportlist;
}

#
sub setFarmErr($fname,$content,$nerr)
{
	my ( $fname, $content, $nerr ) = @_;

	my $type   = &getFarmType( $fname );
	my $output = -1;

	&logfile( "setting 'Err $nerr' for $fname farm $type" );
	if ( $type eq "http" || $type eq "https" )
	{
		if ( -e "$configdir\/$fname\_Err$nerr.html" && $nerr != "" )
		{
			$output = 0;
			my @err = split ( "\n", "$content" );
			print "<br><br>";
			open FO, ">$configdir\/$fname\_Err$nerr.html";
			foreach $line ( @err )
			{
				$line =~ s/\r$//;
				print FO "$line\n";
				$output = $? || $output;
			}
			close FO;
		}
	}

	return $output;
}

#
sub getFarmErr($fname,$nerr)
{
	my ( $fname, $nerr ) = @_;

	my $type  = &getFarmType( $fname );
	my $ffile = &getFarmFile( $fname );
	my @output;

	if ( $type eq "http" || $type eq "https" )
	{
		open FR, "<$configdir\/$ffile";
		my @file = <FR>;
		foreach $line ( @file )
		{
			if ( $line =~ /Err$nerr/ )
			{
				@line = split ( "\ ", $line );
				my $err = @line[1];
				$err =~ s/"//g;
				if ( -e $err )
				{
					open FI, "$err";
					while ( <FI> )
					{
						push ( @output, $_ );
					}
					close FI;
				}
			}
		}
		close FR;
	}

	#&logfile("getting 'Err $nerr' for $fname farm $type");
	return @output;
}

# Returns farm file name
sub getFarmsByType($ftype)
{
	my ( $ftype ) = @_;
	opendir ( my $dir, "$configdir" ) || return -1;
	my @ffiles = grep { /^.*\_.*\.cfg/ && -f "$configdir/$_" } readdir ( $dir );
	closedir $dir;
	my @farms;
	foreach ( @ffiles )
	{
		my $fname = &getFarmName( $_ );
		my $tp    = &getFarmType( $fname );
		if ( $tp eq $ftype )
		{
			push ( @farms, $fname );
		}
	}
	return @farms;
}

#
sub getFarmCertUsed($cfile)
{
	my ( $cfile ) = @_;

	my @farms  = &getFarmsByType( "https" );
	my $output = -1;

	for ( @farms )
	{
		my $fname = $_;
		my $file  = &getFarmFile( $fname );
		use File::Grep qw( fgrep fmap fdo );
		if ( fgrep { /Cert \"$configdir\/$cfile\"/ } "$configdir/$file" )
		{
			$output = 0;
		}
	}

	#&logfile("getting 'CertUsed $cfile' for $fname farm $type");
	return $output;
}

# Returns farm type [udp|tcp|http|https]
sub getFarmType($fname)
{
	my ( $fname ) = @_;
	my $filename = &getFarmFile( $fname );
	if ( $filename =~ /$fname\_pen\_udp.cfg/ )
	{
		return "udp";
	}
	if ( $filename =~ /$fname\_pen.cfg/ )
	{
		return "tcp";
	}
	if ( $filename =~ /$fname\_pound.cfg/ )
	{
		my $out = "http";
		use File::Grep qw( fgrep fmap fdo );
		if ( fgrep { /ListenHTTPS/ } "$configdir/$filename" )
		{
			$out = "https";
		}
		return $out;
	}
	if ( $filename =~ /$fname\_datalink.cfg/ )
	{
		return "datalink";
	}
	if ( $filename =~ /$fname\_l4xnat.cfg/ )
	{
		return "l4xnat";
	}
	if ( $filename =~ /$fname\_gslb.cfg/ )
	{
		return "gslb";
	}
	return 1;
}

# Returns farm file name
sub getFarmFile($fname)
{
	my ( $fname ) = @_;
	opendir ( my $dir, "$configdir" ) || return -1;

	#	my @ffiles = grep { /^$fname\_.*\.cfg/ && !/^$fname\_.*guardian\.conf/ && -f "$configdir/$_" && !/^$fname\_status.cfg/} readdir($dir);
	my @ffiles = grep { /^$fname\_.*\.cfg/ && !/^$fname\_.*guardian\.conf/ && !/^$fname\_status.cfg/ } readdir ( $dir );
	closedir $dir;
	if ( @ffiles )
	{
		return @ffiles[0];
	}
	else
	{
		return -1;
	}
}

# Returns farm status
sub getFarmStatus($fname)
{
	my ( $fname ) = @_;

	my $ftype  = &getFarmType( $fname );
	my $output = -1;

	if ( $ftype ne "datalink" && $ftype ne "l4xnat" )
	{
		my $pid = &getFarmPid( $fname );
		if ( $pid eq "-" )
		{
			$output = "down";
		}
		else
		{
			$output = "up";
		}
	}
	else
	{

		# Only for datalink and l4xnat
		if ( -e "$piddir\/$fname\_$ftype.pid" )
		{
			$output = "up";
		}
		else
		{
			$output = "down";
		}
	}

	return $output;
}

# Returns farm status
sub getFarmBootStatus($fname)
{
	my ( $fname ) = @_;

	my $type   = &getFarmType( $fname );
	my $file   = &getFarmFile( $fname );
	my $output = "down";

	if ( $type eq "tcp" || $type eq "udp" || $type eq "http" || $type eq "https" )
	{
		open FO, "<$configdir/$file";
		while ( $line = <FO> )
		{
			$lastline = $line;
		}
		close FO;
		if ( $lastline !~ /^#down/ )
		{
			$output = "up";
		}
	}

	if ( $type eq "gslb" )
	{
		$output = &getFarmGSLBBootStatus( $file );
	}

	if ( $type eq "datalink" )
	{
		open FI, "<$configdir/$file";
		my $first = "true";
		while ( $line = <FI> )
		{
			if ( $line ne "" && $first eq "true" )
			{
				$first = "false";
				my @line_a = split ( "\;", $line );
				$output = @line_a[4];
				chomp ( $output );
			}
		}
		close FI;
	}

	if ( $type eq "l4xnat" )
	{
		open FI, "<$configdir/$file";
		my $first = "true";
		while ( $line = <FI> )
		{
			if ( $line ne "" && $first eq "true" )
			{
				$first = "false";
				my @line_a = split ( "\;", $line );
				$output = @line_a[8];
				chomp ( $output );
			}
		}
		close FI;
	}

	return $output;
}

# get network physical (vlan included) interface used by the farm vip
sub getFarmInterface($fname)
{
	my ( $fname ) = @_;

	my $type   = &getFarmType( $fname );
	my $output = -1;

	if ( $type eq "datalink" )
	{
		my $file = &getFarmFile( $fname );
		open FI, "<$configdir/$file";
		my $first = "true";
		while ( $line = <FI> )
		{
			if ( $line ne "" && $first eq "true" )
			{
				$first = "false";
				my @line_a = split ( "\;", $line );
				my @line_b = split ( "\:", @line_a[2] );
				$output = @line_b[0];
			}
		}
		close FI;
	}

	return $output;
}

# Start Farm rutine
sub _runFarmStart($fname,$writeconf)
{
	my ( $fname, $writeconf ) = @_;

	my $status = &getFarmStatus( $fname );
	chomp ( $status );
	if ( $status eq "up" )
	{
		return 0;
	}

	my $type = &getFarmType( $fname );
	my $file = &getFarmFile( $fname );

	&logfile( "running 'Start write $writeconf' for $fname farm $type" );
	if ( $writeconf eq "true" && $type ne "datalink" && $type ne "l4xnat" && $type ne "gslb" )
	{
		use Tie::File;
		tie @filelines, 'Tie::File', "$configdir\/$file";
		@filelines = grep !/^\#down/, @filelines;
		untie @filelines;
	}

	if ( $type eq "tcp" || $type eq "udp" )
	{
		$run_farm = &getFarmCommand( $fname );
		&logfile( "running $pen_bin $run_farm" );
		zsystem( "$pen_bin $run_farm" );
		$status = $?;
	}

	if ( $type eq "http" || $type eq "https" )
	{
		unlink ( "/tmp/$fname.lock" );
		&logfile( "running $pound -f $configdir\/$file -p $piddir\/$fname\_pound.pid" );
		zsystem( "$pound -f $configdir\/$file -p $piddir\/$fname\_pound.pid 2>/dev/null" );
		$status = $?;
		if ( $status == 0 )
		{
			&setFarmHttpBackendStatus( $fname );
		}
	}

	if ( $type eq "gslb" )
	{
		$output = &setFarmGSLBStatus( $fname, "start", $writeconf );
	}

	if ( $type eq "datalink" )
	{
		if ( $writeconf eq "true" )
		{
			use Tie::File;
			tie @filelines, 'Tie::File', "$configdir\/$file";
			my $first = 1;
			foreach ( @filelines )
			{
				if ( $first eq 1 )
				{
					s/\;down/\;up/g;
					$first = 0;
				}
			}
			untie @filelines;

		}

		# include cron task to check backends
		use Tie::File;
		tie @filelines, 'Tie::File', "/etc/cron.d/zenloadbalancer";
		my @farmcron = grep /\# \_\_$fname\_\_/, @filelines;
		my $cron = @farmcron;
		if ( $cron eq 0 )
		{
			push ( @filelines, "* * * * *	root	\/usr\/local\/zenloadbalancer\/app\/libexec\/check_uplink $fname \# \_\_$fname\_\_" );
		}
		untie @filelines;

		# Apply changes online
		if ( $status != -1 )
		{

			# Set default uplinks as gateways
			my $iface     = &getFarmInterface( $fname );
			my @eject     = `$ip_bin route del default table table_$iface 2> /dev/null`;
			my @servers   = &getFarmServers( $fname );
			my $algorithm = &getFarmAlgorithm( $fname );
			my $routes    = "";
			if ( $algorithm eq "weight" )
			{

				foreach $serv ( @servers )
				{
					chomp ( $serv );
					my @line = split ( "\;", $serv );
					my $stat = @line[5];
					chomp ( $stat );
					my $wei = 1;
					if ( @line[3] ne "" )
					{
						$wei = @line[3];
					}
					if ( $stat eq "up" )
					{
						$routes = "$routes nexthop via @line[1] dev @line[2] weight $wei";
					}
				}
			}
			if ( $algorithm eq "prio" )
			{
				my $bestprio = 100;
				foreach $serv ( @servers )
				{
					chomp ( $serv );
					my @line = split ( "\;", $serv );
					my $stat = @line[5];
					my $prio = @line[4];
					chomp ( $stat );
					if ( $stat eq "up" && $prio > 0 && $prio < 10 && $prio < $bestprio )
					{
						$routes   = "nexthop via @line[1] dev @line[2] weight 1";
						$bestprio = $prio;
					}
				}
			}
			if ( $routes ne "" )
			{
				&logfile( "running $ip_bin route add default scope global table table_$iface $routes" );
				my @eject = `$ip_bin route add default scope global table table_$iface $routes 2> /dev/null`;
				$status = $?;
			}
			else
			{
				$status = 0;
			}

			# Set policies to the local network
			my $ip = &iponif( $iface );
			if ( $ip =~ /\./ )
			{
				my $ipmask = &maskonif( $if );
				my ( $net, $mask ) = ipv4_network( "$ip / $ipmask" );
				&logfile( "running $ip_bin rule add from $net/$mask lookup table_$iface" );
				my @eject = `$ip_bin rule add from $net/$mask lookup table_$iface 2> /dev/null`;
			}

			# Enable IP forwarding
			&setIpForward( "true" );

			# Enable active datalink file
			open FI, ">$piddir\/$fname\_datalink.pid";
			close FI;
		}
	}
	if ( $type eq "l4xnat" )
	{
		if ( $writeconf eq "true" )
		{
			use Tie::File;
			tie @filelines, 'Tie::File', "$configdir\/$file";
			my $first = 1;
			foreach ( @filelines )
			{
				if ( $first eq 1 )
				{
					s/\;down/\;up/g;
					$first = 0;
				}
			}
			untie @filelines;
		}

		# Apply changes online
		if ( $status != -1 )
		{

			# Set fw rules calculating the $nattype and $protocol
			# for every server of the farm do:
			#   set mark rules for matched connections
			#   set rule for nattype
			my $status  = 0;
			my $nattype = &getFarmNatType( $fname );
			my $lbalg   = &getFarmAlgorithm( $fname );
			my $vip     = &getFarmVip( "vip", $fname );
			my $vport   = &getFarmVip( "vipp", $fname );
			my $vproto  = &getFarmProto( $fname );
			my $persist = &getFarmPersistence( $fname );
			my @pttl    = &getFarmMaxClientTime( $fname );
			my $ttl     = @pttl[0];
			my $proto   = "";

			my @run = &getFarmServers( $fname );
			my @tmangle;
			my @tnat;
			my @tmanglep;
			my @tsnat;
			my @traw;

			my $total_weight = 0;
			foreach $lservers ( @run )
			{
				my @serv = split ( "\;", $lservers );
				if ( @serv[6] =~ /up/ )
				{
					$total_weight = $total_weight + @serv[4];
				}
			}

			if ( $vport eq "*" )
			{
				$vport = "0:65535";
			}

			# Load L4 scheduler if needed
			if ( $lbalg eq "leastconn" && -e "$l4sd" )
			{
				system ( "$l4sd & > /dev/null" );
			}

			# Load required modules
			if ( $vproto eq "sip" || $vproto eq "tftp" )
			{
				$status = &loadL4Modules( $vproto );
				$proto  = "udp";
			}
			elsif ( $vproto eq "ftp" )
			{
				$status = &loadL4Modules( $vproto );
				$proto  = "tcp";
			}
			else
			{
				$proto = $vproto;
			}
			my $bestprio = 1000;
			my @srvprio;
			my $prob = 0;

			foreach $lservers ( @run )
			{
				my @serv = split ( "\;", $lservers );
				if ( @serv[6] =~ /up/ || $lbalg eq "leastconn" )
				{    # TMP: leastconn dynamic backend status check
					if ( $lbalg eq "weight" || $lbalg eq "leastconn" )
					{
						my $port = @serv[2];
						my $rip  = @serv[1];
						if ( @serv[2] ne "" && $proto ne "all" )
						{
							$rip = "$rip\:$port";
						}

						$prob += @serv[4] / $total_weight;
						my $tag = &genIptMark( $fname, $nattype, $lbalg, $vip, $vport, $proto, @serv[0], @serv[3], @serv[4], @serv[6], $prob );

						if ( $persist ne "none" )
						{
							my $tagp = &genIptMarkPersist( $fname, $vip, $vport, $proto, $ttl, @serv[0], @serv[3], @serv[6] );
							push ( @tmanglep, $tagp );
						}

						# dnat rules
						my $red = &genIptRedirect( $fname, $nattype, @serv[0], $rip, $proto, @serv[3], @serv[4], $persist, @serv[6] );
						push ( @tnat, $red );

						if ( $nattype eq "nat" )
						{
							my $ntag;
							if ( $vproto eq "sip" )
							{
								$ntag = &genIptSourceNat( $fname, $vip, $nattype, @serv[0], $proto, @serv[3], @serv[6] );
							}
							else
							{
								$ntag = &genIptMasquerade( $fname, $nattype, @serv[0], $proto, @serv[3], @serv[6] );
							}

							push ( @tsnat, $ntag );
						}

						push ( @tmangle, $tag );
					}

					if ( $lbalg eq "prio" )
					{
						if ( @serv[5] ne "" && @serv[5] < $bestprio )
						{
							@srvprio  = @serv;
							$bestprio = @serv[5];
						}
					}
				}
			}

			if ( @srvprio && $lbalg eq "prio" )
			{
				my @run = `echo 10 > /proc/sys/net/netfilter/nf_conntrack_udp_timeout_stream`;
				my @run = `echo 5 > /proc/sys/net/netfilter/nf_conntrack_udp_timeout`;

				#&logfile("BESTPRIO $bestprio");
				my $port = @srvprio[2];
				my $rip  = @srvprio[1];
				if ( @srvprio[2] ne "" )
				{
					$rip = "$rip\:$port";
				}
				my $tag = &genIptMark( $fname, $nattype, $lbalg, $vip, $vport, $proto, @srvprio[0], @srvprio[3], @srvprio[4], @srvprio[6], $prob );

				# dnat rules
				#if ($vproto ne "sip"){
				my $red = &genIptRedirect( $fname, $nattype, @srvprio[0], $rip, $proto, @srvprio[3], @srvprio[4], $persist, @srvprio[6] );

				if ( $persist ne "none" )
				{
					my $tagp = &genIptMarkPersist( $fname, $vip, $vport, $proto, $ttl, @srvprio[0], @srvprio[3], @srvprio[6] );
					push ( @tmanglep, $tagp );

					#my $tagp2 = &genIptMarkReturn($fname,$vip,$vport,$proto,@srvprio[0],@srvprio[6]);
					#push(@tmanglep,$tagp2);
				}

				if ( $nattype eq "nat" )
				{
					my $ntag;
					if ( $vproto eq "sip" )
					{
						$ntag = &genIptSourceNat( $fname, $vip, $nattype, @srvprio[0], $proto, @srvprio[3], @srvprio[6] );
					}
					else
					{
						$ntag = &genIptMasquerade( $fname, $nattype, @srvprio[0], $proto, @srvprio[3], @srvprio[6] );
					}
					push ( @tsnat, $ntag );
				}

				push ( @tmangle, $tag );
				push ( @tnat,    $red );
			}

			# not used
			foreach $nraw ( @traw )
			{
				if ( $nraw ne "" )
				{
					&logfile( "running $nraw" );
					my @run = `$nraw`;
					if ( $? != 0 )
					{
						&logfile( "last command failed!" );
						$status = -1;
					}
				}
			}

			#~ @tmangle = reverse ( @tmangle );
			# apply tags
			foreach $ntag ( @tmangle )
			{
				if ( $ntag ne "" )
				{
					&logfile( "running $ntag" );
					my @run = `$ntag`;
					if ( $? != 0 )
					{
						&logfile( "last command failed!" );
						$status = -1;
					}
				}
			}

			# apply persistence tags
			if ( $persist eq "ip" )
			{
				# preprocess rules: if farm guardian is starting a server
				# only start the one now available
				if ( $0 =~ /farmguardian/ )
				{
					my @iptables_lines = grep {/recent: CHECK/} `$iptables -n -t mangle -L PREROUTING`;

					# add only not started backends
					foreach my $be_line ( &getFarmServers($fname) )
					{
						# (0:#,1:ip,2:port,3:tag,4:weight,5:prio,6:status)
						my ($tag,$state) = (split ';', $be_line)[3,6];
						chomp ($state);

						if ($state eq 'up' && grep (/$tag/, @iptables_lines) == 1)
						{
							@tmanglep = grep {!/$tag/} @tmanglep;
						}
					}
				}

				foreach $ntag ( @tmanglep )
				{
					if ( $ntag ne "" )
					{
						&logfile( "running $ntag" );
						my @run = `$ntag`;
						if ( $? != 0 )
						{
							&logfile( "last command failed!" );
							$status = -1;
						}
					}
				}
			}

			# redirect/routing to backends

			# preprocess rules: if farm guardian is starting a server
			# only start the one now available
			if ( $0 =~ /farmguardian/ && $persist eq "ip" )
			{
				my @iptables_lines = grep {/recent: SET/} `$iptables -n -t nat -L PREROUTING`;

				# add only not started backends
				foreach my $be_line ( &getFarmServers($fname) )
				{
					# (0:#,1:ip,2:port,3:tag,4:weight,5:prio,6:status)
					my ($tag,$state) = (split ';', $be_line)[3,6];
					chomp ($state);

					if ($state eq 'up' && grep (/$tag/, @iptables_lines) == 1)
					{
						@tnat = grep {!/$tag/} @tnat;
					}
				}
			}

			foreach $nred ( @tnat )
			{
				if ( $nred ne "" )
				{
					&logfile( "running $nred" );
					my @run = `$nred`;
					if ( $? != 0 )
					{
						&logfile( "last command failed!" );
						$status = -1;
					}
				}
			}

			# masquerade
			foreach $nred ( @tsnat )
			{
				if ( $nred ne "" )
				{
					&logfile( "running $nred" );
					my @run = `$nred`;
					if ( $? != 0 )
					{
						&logfile( "last command failed!" );
						$status = -1;
					}
				}
			}

			# Enable IP forwarding
			&setIpForward( "true" );

			# Enable active l4 file
			if ( $status != -1 )
			{
				open FI, ">$piddir\/$fname\_$type.pid";
				close FI;
			}
		}
	}

	return $status;
}

# Start Farm basic rutine
sub runFarmStart($fname,$writeconf)
{
	my ( $fname, $writeconf ) = @_;

	my $status = &_runFarmStart( $fname, $writeconf );

	if ( $status == 0 )
	{
		&runFarmGuardianStart( $fname, "" );
	}

	return $status;
}

# Stop Farm basic rutine
sub runFarmStop($fname,$writeconf)
{
	my ( $fname, $writeconf ) = @_;

	&runFarmGuardianStop( $fname, "" );

	my $status = &_runFarmStop( $fname, $writeconf );

	return $status;
}

# Stop Farm rutine
sub _runFarmStop($fname,$writeconf)
{
	my ( $fname, $writeconf ) = @_;

	#&runFarmGuardianStop($fname,"");

	my $status = &getFarmStatus( $fname );
	if ( $status eq "down" )
	{
		return 0;
	}

	my $filename = &getFarmFile( $fname );
	if ( $filename == -1 )
	{
		return -1;
	}

	my $type   = &getFarmType( $fname );
	my $status = $type;

	&logfile( "running 'Stop write $writeconf' for $fname farm $type" );
	if ( $type eq "tcp" || $type eq "udp" )
	{
		$pid = &getFarmPid( $fname );
		&logfile( "running 'kill 15, $pid'" );
		$run = kill 15, $pid;
		$status = $?;
	}

	if ( $type eq "http" || $type eq "https" )
	{
		&runFarmGuardianStop( $fname, "" );
		my $checkfarm = &getFarmConfigIsOK( $fname );
		if ( $checkfarm == 0 )
		{
			$pid = &getFarmPid( $fname );
			&logfile( "running 'kill 15, $pid'" );
			$run = kill 15, $pid;
			$status = $?;
			unlink ( "$piddir\/$fname\_pound.pid" );
			unlink ( "\/tmp\/$fname\_pound.socket" );
		}
		else
		{
			&errormsg( "Farm $fname can't be stopped, check the logs and modify the configuration" );
			return 1;
		}
	}

	if ( $type eq "gslb" )
	{
		my $checkfarm = &getFarmConfigIsOK( $fname );
		if ( $checkfarm == 0 )
		{
			$output = &setFarmGSLBStatus( $fname, "stop", $writeconf );
			unlink ( $pidfile );
		}
		else
		{
			&errormsg( "Farm $fname can't be stopped, check the logs and modify the configuration" );
			return 1;
		}
	}

	if ( $type eq "datalink" )
	{
		if ( $writeconf eq "true" )
		{
			use Tie::File;
			tie @filelines, 'Tie::File', "$configdir\/$filename";
			my $first = 1;
			foreach ( @filelines )
			{
				if ( $first eq 1 )
				{
					s/\;up/\;down/g;
					$status = $?;
					$first  = 0;
				}
			}
			untie @filelines;
		}

		# delete cron task to check backends
		use Tie::File;
		tie @filelines, 'Tie::File', "/etc/cron.d/zenloadbalancer";
		@filelines = grep !/\# \_\_$farmname\_\_/, @filelines;
		untie @filelines;

		# Apply changes online
		if ( $status != -1 )
		{
			my $iface = &getFarmInterface( $fname );

			# Disable policies to the local network
			my $ip = &iponif( $iface );
			if ( $ip =~ /\./ )
			{
				my $ipmask = &maskonif( $if );
				my ( $net, $mask ) = ipv4_network( "$ip / $ipmask" );
				&logfile( "running $ip_bin rule del from $net/$mask lookup table_$iface" );
				my @eject = `$ip_bin rule del from $net/$mask lookup table_$iface 2> /dev/null`;
			}

			# Disable default uplink gateways
			my @eject = `$ip_bin route del default table table_$iface 2> /dev/null`;

			# Disable active datalink file
			unlink ( "$piddir\/$fname\_datalink.pid" );
			if ( -e "$piddir\/$fname\_datalink.pid" )
			{
				$status = -1;
			}
			else
			{
				$status = 0;
			}
		}
	}

	if ( $type eq "l4xnat" )
	{
		if ( $writeconf eq "true" )
		{
			use Tie::File;
			tie @filelines, 'Tie::File', "$configdir\/$filename";
			my $first = 1;
			foreach ( @filelines )
			{
				if ( $first eq 1 )
				{
					s/\;up/\;down/g;
					$status = $?;
					$first  = 0;
				}
			}
			untie @filelines;
		}

		#&runFarmGuardianStop($fname,"");
		my $falg = &getFarmAlgorithm( $fname );

		# Apply changes online
		if ( $status != -1 )
		{
			# Disable rules
			#~ my @allrules = &getIptList( "raw", "OUTPUT" );
			#~ $status = &deleteIptRules( "farm", $fname, "raw", "OUTPUT", @allrules );
			my @allrules = &getIptList( "mangle", "PREROUTING" );
			
			# do not remove persistence rules when backend detected as failed
			if ($0 =~ /farmguardian/ && &getFarmSessionType($fname) eq 'ip')
			{
				# @allrules includes the rules to be deleted
				# non recent related rules
				my @non_recent_rules = grep {!/recent: CHECK/} @allrules;
				
				# take all persistence rules
				my @recent_rules = grep {/recent: CHECK/} @allrules;

				@allrules = @non_recent_rules;
				
				# pick backends down to remove them
				foreach my $be_line ( &getFarmServers($fname) )
				{
					# (0:#,1:ip,2:port,3:tag,4:weight,5:prio,6:status)
					my ($tag,$state) = (split ';', $be_line)[3,6];
					chomp ($state);
					# if status eq up -> remove
					# for each backend as down, add it to the removal list
					if ($state eq 'fgDOWN')
					{
						push (@allrules, grep {/$tag/} @recent_rules);
					}
				}
			}
			
			$status = &deleteIptRules( "farm", $fname, "mangle", "PREROUTING", @allrules );

			@allrules = &getIptList( "nat", "PREROUTING" );

			if ($0 =~ /farmguardian/ && &getFarmSessionType($fname) eq 'ip')
			{
				# do not remove available backends
				foreach my $be_line ( &getFarmServers($fname) )
				{
					# (0:#,1:ip,2:port,3:tag,4:weight,5:prio,6:status)
					my ($tag,$state) = (split ';', $be_line)[3,6];
					chomp ($state);
					# if status eq up -> remove
					# for each backend as down, add it to the removal list
					if ($state eq 'up')
					{
						@allrules = grep {!/$tag/} @allrules;
					}
				}
			}

			$status = &deleteIptRules( "farm", $fname, "nat", "PREROUTING", @allrules );
			
			@allrules = &getIptList( "nat", "POSTROUTING" );
			$status = &deleteIptRules( "farm", $fname, "nat", "POSTROUTING", @allrules );

			# Disable active l4xnat file
			unlink ( "$piddir\/$fname\_$type.pid" );
			if ( -e "$piddir\/$fname\_$type.pid" )
			{
				$status = -1;
			}
			else
			{
				$status = 0;
			}
		}
	}

	if ( $writeconf eq "true" && $type ne "datalink" && $type ne "l4xnat" && $type ne "gslb" )
	{
		open FW, ">>$configdir/$filename";
		print FW "#down\n";
		close FW;
	}

	return $status;
}

#
sub runFarmCreate($fproto,$fvip,$fvipp,$fname,$fdev)
{
	my ( $fproto, $fvip, $fvipp, $fname, $fdev ) = @_;

	my $output = -1;
	my $ffile  = &getFarmFile( $fname );
	if ( $ffile != -1 )
	{

		# the farm name already exists
		$output = -2;
		return $output;
	}

	&logfile( "running 'Create' for $fname farm $type" );
	if ( $fproto eq "TCP" )
	{
		my $fport = &setFarmPort();
		&logfile( "running '$pen_bin $fvip:$fvipp -c 2049 -x 257 -S 10 -C 127.0.0.1:$fport'" );
		my @run = `$pen_bin $fvip:$fvipp -c 2049 -x 257 -S 10 -C 127.0.0.1:$fport`;
		$output = $?;
		&logfile( "running '$pen_ctl 127.0.0.1:$fport acl 9 deny 0.0.0.0 0.0.0.0'" );
		my @run = `$pen_ctl 127.0.0.1:$fport acl 9 deny 0.0.0.0 0.0.0.0`;
		&logfile( "running $pen_ctl 127.0.0.1:$fport write '$configdir/$fname\_pen.cfg' " );
		my @run = `$pen_ctl 127.0.0.1:$fport write '$configdir/$fname\_pen.cfg'`;
	}

	if ( $fproto eq "UDP" )
	{
		my $fport = &setFarmPort();
		&logfile( "running '$pen_bin $fvip:$fvipp -U -t 1 -b 3 -c 2049 -x 257 -S 10 -C 127.0.0.1:$fport'" );
		my @run = `$pen_bin $fvip:$fvipp -U -t 1 -b 3 -c 2049 -x 257 -S 10 -C 127.0.0.1:$fport`;
		$output = $?;
		&logfile( "running '$pen_ctl 127.0.0.1:$fport acl 9 deny 0.0.0.0 0.0.0.0'" );
		my @run = `$pen_ctl 127.0.0.1:$fport acl 9 deny 0.0.0.0 0.0.0.0`;
		&logfile( "running $pen_ctl 127.0.0.1:$fport write '$configdir/$fname\_pen\_udp.cfg' " );
		my @run = `$pen_ctl 127.0.0.1:$fport write '$configdir/$fname\_pen\_udp.cfg'`;
	}

	if ( $fproto eq "HTTP" || $fproto eq "HTTPS" )
	{

		#copy template modyfing values
		use File::Copy;
		&logfile( "copying pound tpl file on $fname\_pound.cfg" );
		copy( "$poundtpl", "$configdir/$fname\_pound.cfg" );

		#modify strings with variables
		use Tie::File;
		tie @file, 'Tie::File', "$configdir/$fname\_pound.cfg";
		foreach $line ( @file )
		{
			$line =~ s/\[IP\]/$fvip/;
			$line =~ s/\[PORT\]/$fvipp/;
			$line =~ s/\[DESC\]/$fname/;
			$line =~ s/\[CONFIGDIR\]/$configdir/;
			if ( $fproto eq "HTTPS" )
			{
				$line =~ s/ListenHTTP/ListenHTTPS/;
				$line =~ s/#Cert/Cert/;
			}
		}
		untie @file;

		#create files with personalized errors
		open FERR, ">$configdir\/$fname\_Err414.html";
		print FERR "Request URI is too long.\n";
		close FERR;
		open FERR, ">$configdir\/$fname\_Err500.html";
		print FERR "An internal server error occurred. Please try again later.\n";
		close FERR;
		open FERR, ">$configdir\/$fname\_Err501.html";
		print FERR "This method may not be used.\n";
		close FERR;
		open FERR, ">$configdir\/$fname\_Err503.html";
		print FERR "The service is not available. Please try again later.\n";
		close FERR;

		#run farm
		&logfile( "running $pound -f $configdir\/$fname\_pound.cfg -p $piddir\/$fname\_pound.pid" );
		zsystem( "$pound -f $configdir\/$fname\_pound.cfg -p $piddir\/$fname\_pound.pid 2>/dev/null" );
		$output = $?;
	}

	if ( $fproto eq "DATALINK" )
	{
		open FO, ">$configdir\/$fname\_datalink.cfg";
		print FO "$fname\;$fvip\;$fdev\;weight\;up\n";
		close FO;
		$output = $?;

		if ( !-e "$piddir/$fname_datalink.pid" )
		{

			# Enable active datalink file
			open FI, ">$piddir\/$fname\_datalink.pid";
			close FI;
		}
	}

	if ( $fproto eq "L4xNAT" )
	{

		#my $tproto=&getFarmProto($fname);
		my $type = "l4xnat";

		#if ($fproto eq "tcp"){
		#	$type = "l4txnat";
		#} elsif($fproto eq "udp"){
		#	$type = "l4uxnat";
		#} else {
		#	$type = "l4xnat";
		#}
		open FO, ">$configdir\/$fname\_$type.cfg";
		print FO "$fname\;tcp\;$fvip\;$fvipp\;nat\;weight\;none\;120\;up\n";
		close FO;
		$output = $?;

		if ( !-e "$piddir/$fname_$type.pid" )
		{

			# Enable active l4xnat file
			open FI, ">$piddir\/$fname\_$type.pid";
			close FI;
		}
	}

	if ( $fproto eq "GSLB" )
	{
		$output = &setFarmGSLB( $fvip, $fvipp, $fname );
	}

	return $output;
}

# Returns Farm blacklist
sub getFarmBlacklist($fname)
{
	my ( $fname ) = @_;

	my $type   = &getFarmType( $fname );
	my $file   = &getFarmFile( $fname );
	my $output = -1;

	if ( $type eq "tcp" || $type eq "udp" )
	{
		open FI, "$configdir/$file";
		my $exit = "false";
		while ( $line = <FI> || $exit eq "false" )
		{
			if ( $line =~ /^# pen/ )
			{
				$exit = "true";
				my @line_a = split ( "\ ", $line );
				if ( $type eq "tcp" )
				{
					$admin_ip = @line_a[11];
				}
				else
				{
					$admin_ip = @line_a[12];
				}
				my @blacklist = `$pen_ctl $admin_ip blacklist 2> /dev/null`;
				if   ( @blacklist =~ /^[1-9].*/ ) { $output = "@blacklist"; }
				else                              { $output = "-"; }
			}
		}
		close FI;
	}

	#&logfile("getting 'Blacklist $output' for $fname farm $type");
	return $output;
}

# Returns farm max connections
sub getFarmMaxConn($fname)
{
	my ( $fname ) = @_;

	my $type   = &getFarmType( $fname );
	my $file   = &getFarmFile( $fname );
	my $output = -1;

	if ( $type eq "tcp" || $type eq "udp" )
	{
		open FI, "$configdir/$file";
		my $exit = "false";
		while ( $line = <FI> || $exit eq "false" )
		{
			if ( $line =~ /^# pen/ )
			{
				$exit = "true";
				my @line_a = split ( "\ ", $line );
				if ( $type eq "tcp" )
				{
					$admin_ip = @line_a[11];
				}
				else
				{
					$admin_ip = @line_a[12];
				}
				my @conn_max = `$pen_ctl $admin_ip conn_max 2> /dev/null`;
				if   ( @conn_max =~ /^[1-9].*/ ) { $output = "@conn_max"; }
				else                             { $output = "-"; }
			}
		}
		close FI;
	}

	if ( $type eq "http" || $type eq "https" )
	{
		my $ffile = &getFarmFile( $fname );
		open FR, "<$configdir\/$ffile";
		my @file = <FR>;
		foreach $line ( @file )
		{
			if ( $line =~ /^Threads/ )
			{
				@line = split ( "\ ", $line );
				my $maxt = @line[1];
				$maxt =~ s/\ //g;
				chomp ( $maxt );
				$output = $maxt;
			}
		}
		close FR;
	}

	#&logfile("getting 'MaxConn $output' for $fname farm $type");
	return $output;

}

# Returns farm listen port
sub getFarmPort($fname)
{
	my ( $fname ) = @_;

	my $type   = &getFarmType( $fname );
	my $file   = &getFarmFile( $fname );
	my $output = -1;

	if ( $type eq "tcp" || $type eq "udp" )
	{
		open FI, "$configdir/$file";
		my $exit = "false";
		while ( $line = <FI> || $exit eq "false" )
		{
			if ( $line =~ /^# pen/ )
			{
				$exit = "true";
				my @line_a = split ( "\ ", $line );
				if ( $type eq "tcp" )
				{
					$port_manage = @line_a[11];
				}
				else
				{
					$port_manage = @line_a[12];
				}
				my @managep = split ( ":", $port_manage );
				$output = @managep[1];
			}
		}
		close FI;
	}

	if ( $type eq "http" || $type eq "https" )
	{
		$output = "/tmp/" . $fname . "_pound.socket";
	}

	return $output;
}

# Returns farm command
sub getFarmCommand($fname)
{
	my ( $fname ) = @_;

	my $type   = &getFarmType( $fname );
	my $file   = &getFarmFile( $fname );
	my $output = -1;

	if ( $type eq "tcp" || $type eq "udp" )
	{
		open FI, "$configdir/$file";
		my $exit = "false";
		while ( $line = <FI> || $exit eq "false" )
		{
			if ( $line =~ /^# pen/ )
			{
				$exit = "true";
				$line =~ s/^#\ pen//;
				$output = $line;
			}
		}
		close FI;
	}

	return $output;
}

# Returns farm PID
sub getFarmPid($fname)
{
	my ( $fname ) = @_;

	my $type   = &getFarmType( $fname );
	my $file   = &getFarmFile( $fname );
	my $output = -1;

	if ( $type eq "tcp" || $type eq "udp" )
	{
		open FI, "$configdir/$file";
		my $exit = "false";
		while ( $line = <FI> || $exit eq "false" )
		{
			if ( $line =~ /^# pen/ )
			{
				$exit = "true";
				my @line_a = split ( "\ ", $line );
				@ip_and_port = split ( ":", @line_a[-2] );
				$admin_ip = "@ip_and_port[0]:@ip_and_port[1]";
				my @pid = `$pen_ctl $admin_ip pid 2> /dev/null`;
				if   ( @pid =~ /^[1-9].*/ ) { $output = "@pid"; }
				else                        { $output = "-"; }
			}
		}
		close FI;
	}

	if ( $type eq "http" || $type eq "https" )
	{
		@fname = split ( /\_/, $file );
		my $pidfile = "$piddir\/$fname\_pound.pid";
		if ( -e $pidfile )
		{
			open FPID, "<$pidfile";
			@pid = <FPID>;
			close FPID;
			$pid_hprof = @pid[0];
			chomp ( $pid_hprof );
			if   ( $pid_hprof =~ /^[1-9].*/ ) { $output = "$pid_hprof"; }
			else                              { $output = "-"; }
		}
		else { $output = "-"; }
	}

	if ( $type eq "gslb" )
	{
		@fname = split ( /\_/, $file );
		my $pidfile = &getGSLBFarmPidFile( $fname );
		if ( -e $pidfile )
		{
			open FPID, "<$pidfile";
			@pid = <FPID>;
			close FPID;
			$pid_hprof = @pid[0];
			chomp ( $pid_hprof );
			my $exists = kill 0, $pid_hprof;
			if   ( $pid_hprof =~ /^[1-9].*/ && $exists ) { $output = "$pid_hprof"; }
			else                                         { $output = "-"; }
		}
		else { $output = "-"; }
	}

	return $output;
}

# Returns farm Child PID
sub getFarmChildPid($fname)
{
	my ( $fname ) = @_;
	use File::Grep qw( fgrep fmap fdo );

	my $type   = &getFarmType( $fname );
	my $fpid   = &getFarmPid( $fname );
	my $output = -1;

	if ( $type eq "http" || $type eq "https" )
	{
		my $pids = `pidof -o $fpid pound`;
		my @pids = split ( " ", $pids );
		foreach $pid ( @pids )
		{
			if ( fgrep { /^PPid:.*${fpid}$/ } "/proc/$pid/status" )
			{
				$output = $pid;
				last;
			}
		}
	}

	return $output;

}

# Returns farm vip
sub getFarmVip($info,$fname)
{
	my ( $info, $fname ) = @_;

	my $type   = &getFarmType( $fname );
	my $file   = &getFarmFile( $fname );
	my $output = -1;

	if ( $type eq "tcp" || $type eq "udp" )
	{
		open FI, "$configdir/$file";
		my $exit = "false";
		while ( $line = <FI> || $exit eq "false" )
		{

			# find line with pen command
			if ( $line =~ /^# pen/ )
			{
				$exit = "true";
				my @line_a = split ( "\ ", $line );

				# use last argument
				$vip_port = @line_a[-1];
				my @vipp = split ( ":", $vip_port );
				if ( $info eq "vip" )   { $output = @vipp[0]; }
				if ( $info eq "vipp" )  { $output = @vipp[1]; }
				if ( $info eq "vipps" ) { $output = "$vip_port"; }
			}
		}
		close FI;
	}

	if ( $type eq "http" || $type eq "https" )
	{
		open FI, "<$configdir/$file";
		my @file = <FI>;
		my $i    = 0;
		close FI;
		foreach $line ( @file )
		{
			if ( $line =~ /^ListenHTTP/ )
			{
				my $vip  = @file[$i + 5];
				my $vipp = @file[$i + 6];
				chomp ( $vip );
				chomp ( $vipp );
				my @vip  = split ( "\ ", $vip );
				my @vipp = split ( "\ ", $vipp );
				if ( $info eq "vip" )   { $output = @vip[1]; }
				if ( $info eq "vipp" )  { $output = @vipp[1]; }
				if ( $info eq "vipps" ) { $output = "@vip[1]\:@vipp[1]"; }
			}
			$i++;
		}
	}

	if ( $type eq "l4xnat" )
	{
		open FI, "<$configdir/$file";
		my $first = "true";
		while ( $line = <FI> )
		{
			if ( $line ne "" && $first eq "true" )
			{
				$first = "false";
				my @line_a = split ( "\;", $line );
				if ( $info eq "vip" )   { $output = @line_a[2]; }
				if ( $info eq "vipp" )  { $output = @line_a[3]; }
				if ( $info eq "vipps" ) { $output = "@line_a[2]\:@line_a[3]"; }
			}
		}
		close FI;
	}

	if ( $type eq "datalink" )
	{
		open FI, "<$configdir/$file";
		my $first = "true";
		while ( $line = <FI> )
		{
			if ( $line ne "" && $first eq "true" )
			{
				$first = "false";
				my @line_a = split ( "\;", $line );
				if ( $info eq "vip" )   { $output = @line_a[1]; }
				if ( $info eq "vipp" )  { $output = @line_a[2]; }
				if ( $info eq "vipps" ) { $output = "@vip[1]\:@vipp[2]"; }
			}
		}
		close FI;
	}

	if ( $type eq "gslb" )
	{
		open FI, "<$configdir/$file/etc/config";
		my @file = <FI>;
		my $i    = 0;
		close FI;
		foreach $line ( @file )
		{
			if ( $line =~ /^options =>/ )
			{
				my $vip  = @file[$i + 1];
				my $vipp = @file[$i + 2];
				chomp ( $vip );
				chomp ( $vipp );
				my @vip  = split ( "\ ", $vip );
				my @vipp = split ( "\ ", $vipp );
				if ( $info eq "vip" )   { $output = @vip[2]; }
				if ( $info eq "vipp" )  { $output = @vipp[2]; }
				if ( $info eq "vipps" ) { $output = "@vip[2]\:@vipp[2]"; }
			}
			$i++;
		}
	}

	return $output;
}

# Returns FarmGuardian config file for this farm
sub getFarmGuardianFile($fname,$svice)
{
	my ( $fname, $svice ) = @_;

	opendir ( my $dir, "$configdir" ) || return -1;
	my @files = grep { /^$fname\_$svice.*guardian\.conf/ && -f "$configdir/$_" } readdir ( $dir );
	closedir $dir;
	my $nfiles = @files;
	if ( $nfiles == 0 )
	{
		return -1;
	}
	else
	{
		return @files[0];
	}
}

# Returns if FarmGuardian is activated for this farm
sub getFarmGuardianStatus($fname,$svice)
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
	$value = @line_s[3];
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
sub getFarmGuardianLog($fname,$svice)
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
	$value = @line_s[4];
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
sub runFarmGuardianStart($fname,$svice)
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

sub runFarmGuardianStop($fname,$svice)
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
			$status = $status + $stat;
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
			$run = kill 9, $fgpid;
			$status = $?;
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
							my $run = `$poundctl -c $portadmin -B 0 $idsv $index`;
						}
					}
					untie @filelines;
				}
			}
			if ( $type eq "l4xnat" )
			{
				my @be = &getFarmBackendStatusCtl( $fname );
				$i = -1;
				foreach my $line ( @be )
				{
					my @subbe = split ( ";", $line );
					$i++;
					my $backendid     = $i;
					my $backendserv   = @subbe[2];
					my $backendport   = @subbe[3];
					my $backendstatus = @subbe[7];
					if ( $backendstatus eq "fgDOWN" )
					{
						&_runFarmStop( $fname, "false" );
						&setFarmBackendStatus( $fname, $i, "up" );
						&_runFarmStart( $fname, "false" );
					}
				}
			}

		}
	}

	return $status;
}

# Delete Farm rutine
sub runFarmDelete($fname)
{
	my ( $fname ) = @_;

	my $ftype = &getFarmType( $fname );

	&logfile( "running 'Delete' for $fname" );
	unlink glob ( "$configdir/$fname\_*\.cfg" );
	$status = $?;
	unlink glob ( "$configdir/$fname\_*\.html" );
	unlink glob ( "$configdir/$fname\_*\.conf" );
	unlink glob ( "$basedir/img/graphs/bar$fname*" );
	unlink glob ( "$basedir/img/graphs/$fname-farm\_*" );
	unlink glob ( "$rrdap_dir$rrd_dir/$fname-farm*" );
	unlink glob ( "${logdir}/${fname}\_*farmguardian*" );

	if ( $ftype eq "gslb" )
	{
		use File::Path 'rmtree';
		rmtree( ["$configdir/$fname\_gslb.cfg"] );
	}

	# delete cron task to check backends
	use Tie::File;
	tie @filelines, 'Tie::File', "/etc/cron.d/zenloadbalancer";
	my @filelines = grep !/\# \_\_$farmname\_\_/, @filelines;
	untie @filelines;

	# delete nf marks
	delMarks( $fname, "" );

	return $status;
}

#function that create a file for tell that the farm need a restart for apply the changes
sub setFarmRestart($farmname)
{
	my ( $farmname ) = @_;
	if ( !-e "/tmp/$farmname.lock" )
	{
		open FILE, ">/tmp/$farmname.lock";
		print FILE "";
		close FILE;
	}

}

#function that delete a file used for tell that the farm need a restart for apply the changes
sub setFarmNoRestart($farmname)
{
	my ( $farmname ) = @_;
	if ( -e "/tmp/$farmname.lock" )
	{
		unlink ( "/tmp/$farmname.lock" );
	}
}

# Returns farm file list
sub getFarmList()
{
	opendir ( DIR, $configdir );
	my @files = grep ( /\_pen.*\.cfg$/, readdir ( DIR ) );
	closedir ( DIR );
	opendir ( DIR, $configdir );
	my @files2 = grep ( /\_pound.cfg$/, readdir ( DIR ) );
	closedir ( DIR );
	opendir ( DIR, $configdir );
	my @files3 = grep ( /\_datalink.cfg$/, readdir ( DIR ) );
	closedir ( DIR );
	opendir ( DIR, $configdir );
	my @files4 = grep ( /\_l4xnat.cfg$/, readdir ( DIR ) );
	closedir ( DIR );
	opendir ( DIR, $configdir );
	my @files5 = grep ( /\_gslb.cfg$/, readdir ( DIR ) );
	closedir ( DIR );
	my @files = ( @files, @files2, @files3, @files4, @files5 );
	return @files;
}

sub getFarmName($farmfile)
{
	my ( $farmfile ) = @_;
	my @ffile = split ( "_", $farmfile );
	return @ffile[0];
}

# Set farm virtual IP and virtual PORT
sub setFarmVirtualConf($vip,$vipp,$fname)
{
	my ( $vip, $vipp, $fname ) = @_;
	my $fconf = &getFarmFile( $fname );
	my $type  = &getFarmType( $fname );
	my $stat  = -1;

	&logfile( "setting 'VirtualConf $vip $vipp' for $fname farm $type" );
	if ( $type eq "tcp" || $type eq "udp" )
	{
		$vips = &getFarmVip( "vipps", $fname );
		use Tie::File;
		tie @filelines, 'Tie::File', "$configdir\/$fconf";
		for ( @filelines )
		{
			if ( $_ =~ "# pen" )
			{
				s/$vips/$vip:$vipp/g;
				$stat = $?;
			}
		}
		untie @filelines;
	}

	if ( $type eq "http" || $type eq "https" )
	{
		$stat = 0;
		my $enter = 2;
		use Tie::File;
		tie @array, 'Tie::File', "$configdir\/$fconf";
		my $size = @array;
		for ( $i = 0 ; $i < $size && $enter > 0 ; $i++ )
		{
			if ( @array[$i] =~ /Address/ )
			{
				@array[$i] =~ s/.*Address\ .*/\tAddress\ $vip/g;
				$stat = $? || $stat;
				$enter--;
			}
			if ( @array[$i] =~ /Port/ )
			{
				@array[$i] =~ s/.*Port\ .*/\tPort\ $vipp/g;
				$stat = $? || $stat;
				$enter--;
			}
		}
		untie @array;
	}

	if ( $type eq "datalink" )
	{
		use Tie::File;
		tie @filelines, 'Tie::File', "$configdir\/$fconf";
		my $i = 0;
		for $line ( @filelines )
		{
			if ( $line =~ /^$fname\;/ )
			{
				my @args = split ( "\;", $line );
				$line = "@args[0]\;$vip\;$vipp\;@args[3]\;@args[4]";
				splice @filelines, $i, $line;
				$stat = $?;
			}
			$i++;
		}
		untie @filelines;
		$stat = $?;
	}

	if ( $type eq "l4xnat" )
	{
		use Tie::File;
		tie @filelines, 'Tie::File', "$configdir\/$fconf";
		my $i = 0;
		for $line ( @filelines )
		{
			if ( $line =~ /^$fname\;/ )
			{
				my @args = split ( "\;", $line );
				$line = "@args[0]\;@args[1]\;$vip\;$vipp\;@args[4]\;@args[5]\;@args[6]\;@args[7]\;@args[8]";
				splice @filelines, $i, $line;
				$stat = $?;
			}
			$i++;
		}
		untie @filelines;
		$stat = $?;
	}

	if ( $type eq "gslb" )
	{
		my $index = 0;
		my $found = 0;
		tie @fileconf, 'Tie::File', "$configdir/$fconf/etc/config";
		foreach $line ( @fileconf )
		{
			if ( $line =~ /options => / )
			{
				$found = 1;
			}
			if ( $found == 1 && $line =~ / listen = / )
			{
				$line =~ s/$line/   listen = $vip/g;
			}
			if ( $found == 1 && $line =~ /dns_port = / )
			{
				$line =~ s/$line/   dns_port = $vipp/g;
			}
			if ( $found == 1 && $line =~ /\}/ )
			{
				last;
			}
			$index++;
		}
		untie @fileconf;
		$stat = $?;
	}

	return $stat;
}

# create farmguardian config file
sub runFarmGuardianCreate($fname,$ttcheck,$script,$usefg,$fglog,$svice)
{
	( $fname, $ttcheck, $script, $usefg, $fglog, $svice ) = @_;

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

	&logfile( "running 'Create FarmGuardian $ttcheck $script $usefg $fglog' for $fname farm" );
	if ( ( $ttcheck eq "" || $script eq "" ) && $usefg eq "true" )
	{
		return $output;
	}

	open FO, ">$configdir/$fgfile";
	print FO "$fname\:\:\:$ttcheck\:\:\:$script\:\:\:$usefg\:\:\:$fglog";
	$output = $?;
	close FO;

	return $output;
}

#
sub getFarmGuardianConf($fname,$svice)
{
	( $fname, $svice ) = @_;
	my $lastline;

	my $fgfile = &getFarmGuardianFile( $fname, $svice );

	if ( $fgfile == -1 )
	{
		if ( $svice ne "" )
		{
			$svice = "${svice}_";
		}
		$fgfile = "${fname}_${svice}guardian.conf";
	}

	open FG, "$configdir/$fgfile";
	my $line;
	while ( $line = <FG> )
	{
		if ( $line !~ /^#/ )
		{
			$lastline = $line;
		}
	}
	close FG;
	my @line = split ( ":::", $lastline );

	#&logfile("getting 'FarmGuardianConf @line' for $fname farm");
	return @line;
}

#
sub getFarmGuardianPid($fname,$svice)
{
	my ( $fname, $svice ) = @_;

	my $pidfile = "";

	opendir ( my $dir, "$piddir" ) || return -1;
	@files = grep { /^$fname\_$svice.*guardian\.pid/ && -f "$piddir/$_" } readdir ( $dir );
	closedir $dir;
	$numfiles = @files;
	if ( @files )
	{
		$pidfile = @files[0];
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

#
sub setFarmServer($ids,$rip,$port,$max,$weight,$priority,$timeout,$fname,$service)
{
	my ( $ids, $rip, $port, $max, $weight, $priority, $timeout, $fname, $svice ) = @_;

	my $type      = &getFarmType( $fname );
	my $file      = &getFarmFile( $fname );
	my $output    = -1;
	my $nsflag    = "false";
	my $backend   = 0;
	my $idservice = 0;

	&logfile( "setting 'Server $ids $rip $port max $max weight $weight prio $priority timeout $timeout' for $fname farm $type" );

	if ( $type eq "tcp" || $type eq "udp" )
	{
		$fport = &getFarmPort( $fname );
		my $fmaxservers = &getFarmMaxServers( $fname );
		if ( $max      ne "" ) { $max      = "max $max"; }
		if ( $weight   ne "" ) { $weight   = "weight $weight"; }
		if ( $priority ne "" ) { $priority = "prio $priority"; }

		#&logfile ("running '$pen_ctl 127.0.0.1:$fport server $ids address $rip port $port max $max weight $weight prio $priority' in $fname farm");
		#my @run = `$pen_ctl 127.0.0.1:$fport server $ids address $rip port $port max $max weight $weight prio $priority`;
		&logfile( "running '$pen_ctl 127.0.0.1:$fport server $ids address $rip port $port $max $weight $priority' in $fname farm" );
		my @run = `$pen_ctl 127.0.0.1:$fport server $ids address $rip port $port $max $weight $priority`;
		$output = $?;
		&logfile( "running '$pen_ctl 127.0.0.1:$fport write '$configdir/$file''" );
		my @run = `$pen_ctl 127.0.0.1:$fport write '$configdir/$file'`;
		&setFarmMaxServers( $fmaxservers, $fname );
	}

	if ( $type eq "datalink" )
	{
		my $iface = $port;
		tie @contents, 'Tie::File', "$configdir\/$file";
		my $i   = 0;
		my $l   = 0;
		my $end = "false";
		foreach $line ( @contents )
		{
			if ( $line =~ /^\;server\;/ && $end ne "true" )
			{
				if ( $i eq $ids )
				{
					my $dline = "\;server\;$rip\;$iface\;$weight\;$priority\;up\n";
					splice @contents, $l, 1, $dline;
					$output = $?;
					$end    = "true";
				}
				else
				{
					$i++;
				}
			}
			$l++;
		}
		if ( $end eq "false" )
		{
			push ( @contents, "\;server\;$rip\;$iface\;$weight\;$priority\;up\n" );
			$output = $?;
		}
		untie @contents;

		# Apply changes online
		if ( $output != -1 )
		{
			&runFarmStop( $farmname, "true" );
			&runFarmStart( $farmname, "true" );
		}
	}

	if ( $type eq "l4xnat" )
	{
		tie my @contents, 'Tie::File', "$configdir\/$file";
		my $i   = 0;
		my $l   = 0;
		my $end = "false";
		foreach $line ( @contents )
		{
			if ( $line =~ /^\;server\;/ && $end ne "true" )
			{
				if ( $i eq $ids )
				{
					my @aline = split ( "\;", $line );
					my $dline = "\;server\;$rip\;$port\;@aline[4]\;$weight\;$priority\;up\n";
					splice @contents, $l, 1, $dline;
					$output = $?;
					$end    = "true";
				}
				else
				{
					$i++;
				}
			}
			$l++;
		}
		if ( $end eq "false" )
		{
			my $mark = &getNewMark( $fname );
			push ( @contents, "\;server\;$rip\;$port\;$mark\;$weight\;$priority\;up\n" );
			$output = $?;
		}
		untie @contents;

		# Apply changes online
		#if ($output != -1){
		#	&runFarmStop($farmname,"true");
		#	&runFarmStart($farmname,"true");
		#}
	}

	if ( $type eq "http" || $type eq "https" )
	{
		tie @contents, 'Tie::File', "$configdir\/$file";
		my $be_section = -1;
		if ( $ids !~ /^$/ )
		{
			my $index_count = -1;
			my $i           = -1;
			my $sw          = 0;
			foreach $line ( @contents )
			{
				$i++;

				#search the service to modify
				if ( $line =~ /Service \"$svice\"/ )
				{
					$sw = 1;
				}
				if ( $line =~ /BackEnd/ && $line !~ /#/ && $sw eq 1 )
				{
					$index_count++;
					if ( $index_count == $ids )
					{

						#server for modify $ids;
						#HTTPS
						my $httpsbe = &getFarmVS( $fname, $svice, "httpsbackend" );
						if ( $httpsbe eq "true" )
						{

							#       #add item
							$i++;
						}
						$output           = $?;
						@contents[$i + 1] = "\t\t\tAddress $rip";
						@contents[$i + 2] = "\t\t\tPort $port";
						my $p_m = 0;
						if ( @contents[$i + 3] =~ /TimeOut/ )
						{
							@contents[$i + 3] = "\t\t\tTimeOut $timeout";
							&logfile( "Modified current timeout" );
						}
						if ( @contents[$i + 4] =~ /Priority/ )
						{
							@contents[$i + 4] = "\t\t\tPriority $priority";
							&logfile( "Modified current priority" );
							$p_m = 1;
						}
						if ( @contents[$i + 3] =~ /Priority/ )
						{
							@contents[$i + 3] = "\t\t\tPriority $priority";
							$p_m = 1;
						}

						#delete item
						if ( $timeout =~ /^$/ )
						{
							if ( @contents[$i + 3] =~ /TimeOut/ )
							{
								splice @contents, $i + 3, 1,;
							}
						}
						if ( $priority =~ /^$/ )
						{
							if ( @contents[$i + 3] =~ /Priority/ )
							{
								splice @contents, $i + 3, 1,;
							}
							if ( @contents[$i + 4] =~ /Priority/ )
							{
								splice @contents, $i + 4, 1,;
							}
						}

						#new item
						if ( $timeout !~ /^$/ && ( @contents[$i + 3] =~ /End/ || @contents[$i + 3] =~ /Priority/ ) )
						{
							splice @contents, $i + 3, 0, "\t\t\tTimeOut $timeout";
						}
						if ( $p_m eq 0 && $priority !~ /^$/ && ( @contents[$i + 3] =~ /End/ || @contents[$i + 4] =~ /End/ ) )
						{
							if ( @contents[$i + 3] =~ /TimeOut/ )
							{
								splice @contents, $i + 4, 0, "\t\t\tPriority $priority";
							}
							else
							{
								splice @contents, $i + 3, 0, "\t\t\tPriority $priority";
							}
						}
					}
				}
			}
		}
		else
		{

			#add new server
			$nsflag = "true";
			my $index   = -1;
			my $backend = 0;
			foreach $line ( @contents )
			{
				$index++;
				if ( $be_section == 1 && $line =~ /Address/ )
				{
					$backend++;
				}
				if ( $line =~ /Service \"$svice\"/ )
				{
					$be_section++;
				}
				if ( $line =~ /#BackEnd/ && $be_section == 0 )
				{
					$be_section++;
				}
				if ( $be_section == 1 && $line =~ /#End/ )
				{
					splice @contents, $index, 0, "\t\tBackEnd";
					$output = $?;
					$index++;
					splice @contents, $index, 0, "\t\t\tAddress $rip";
					my $httpsbe = &getFarmVS( $fname, $svice, "httpsbackend" );
					if ( $httpsbe eq "true" )
					{

						#add item
						splice @contents, $index, 0, "\t\t\tHTTPS";
						$index++;
					}
					$index++;
					splice @contents, $index, 0, "\t\t\tPort $port";
					$index++;

					#Timeout?
					if ( $timeout )
					{
						splice @contents, $index, 0, "\t\t\tTimeOut $timeout";
						$index++;
					}

					#Priority?
					if ( $priority )
					{
						splice @contents, $index, 0, "\t\t\tPriority $priority";
						$index++;
					}
					splice @contents, $index, 0, "\t\tEnd";
					$be_section = -1;
				}

				# if backend added then go out of form
			}
			if ( $nsflag eq "true" )
			{
				$idservice = &getFarmVSI( $fname, $svice );
				if ( $idservice ne "" )
				{
					&getFarmHttpBackendStatus( $fname, $backend, "active", $idservice );
				}
			}
		}
		untie @contents;
	}

	return $output;
}

#
sub runFarmServerDelete($ids,$fname,$service)
{
	( $ids, $fname, $svice ) = @_;

	my $type   = &getFarmType( $fname );
	my $ffile  = &getFarmFile( $fname );
	my $output = -1;

	&logfile( "running 'ServerDelete $ids' for $fname farm $type" );

	if ( $type eq "tcp" || $type eq "udp" )
	{
		my $fport       = &getFarmPort( $fname );
		my $fmaxservers = &getFarmMaxServers( $fname );
		&logfile( "running '$pen_ctl 127.0.0.1:$fport server $ids address 0 port 0 max 0 weight 0 prio 0' deleting server $ids in $fname farm" );
		my @run = `$pen_ctl 127.0.0.1:$fport server $ids address 0 port 0 max 0 weight 0 prio 0`;
		$output = $?;
		&logfile( "running '$pen_ctl 127.0.0.1:$fport write '$configdir/$ffile''" );
		my @run = `$pen_ctl 127.0.0.1:$fport write '$configdir/$ffile'`;
		&setFarmMaxServers( $fmaxservers, $fname );
	}

	if ( $type eq "datalink" )
	{
		tie my @contents, 'Tie::File', "$configdir\/$ffile";
		my $i   = 0;
		my $l   = 0;
		my $end = "false";
		foreach $line ( @contents )
		{
			if ( $line =~ /^\;server\;/ && $end ne "true" )
			{
				if ( $i eq $ids )
				{
					splice @contents, $l, 1,;
					$output = $?;
					$end    = "true";
				}
				else
				{
					$i++;
				}
			}
			$l++;
		}
		untie @contents;
	}

	if ( $type eq "l4xnat" )
	{
		tie my @contents, 'Tie::File', "$configdir\/$ffile";
		my $i   = 0;
		my $l   = 0;
		my $end = "false";
		my $mark;

		foreach $line ( @contents )
		{
			if ( $line =~ /^\;server\;/ && $end ne "true" )
			{
				if ( $i eq $ids )
				{
					my @sdata = split ( "\;", $line );
					$mark = &delMarks( "", @sdata[4] );
					splice @contents, $l, 1,;
					$output = $?;
					$end    = "true";
				}
				else
				{
					$i++;
				}
			}
			$l++;
		}
		untie @contents;
	}

	if ( $type eq "http" || $type eq "https" )
	{
		my $i  = -1;
		my $j  = -1;
		my $sw = 0;
		tie @contents, 'Tie::File', "$configdir\/$ffile";
		foreach $line ( @contents )
		{
			$i++;
			if ( $line =~ /Service \"$svice\"/ )
			{
				$sw = 1;
			}
			if ( $line =~ /BackEnd/ && $line !~ /#/ && $sw == 1 )
			{
				$j++;
				if ( $j == $ids )
				{
					splice @contents, $i, 1,;
					$output = $?;
					while ( @contents[$i] !~ /End/ )
					{
						splice @contents, $i, 1,;
					}
					splice @contents, $i, 1,;
				}
			}
		}
		untie @contents;
		if ( $output != -1 )
		{
			&runRemovehttpBackend( $fname, $ids, $svice );
		}
	}

	if ( $type eq "gslb" )
	{
		my @fileconf;
		my $line;
		my $param;
		my @linesplt;
		my $index = 0;
		use Tie::File;
		tie @fileconf, 'Tie::File', "$configdir/$ffile/etc/zones/$service";
		foreach $line ( @fileconf )
		{

			if ( $line =~ /\;index_/ )
			{
				@linesplt = split ( "\;index_", $line );
				$param = @linesplt[1];
				if ( $ids !~ /^$/ && $ids eq $param )
				{
					splice @fileconf, $index, 1,;
				}
			}
			$index++;
		}
		untie @fileconf;
		$output = $?;
	}

	return $output;
}

#
sub getFarmBackendStatusCtl($fname)
{
	my ( $fname ) = @_;
	my $type      = &getFarmType( $fname );
	my @output    = -1;

	#&logfile("getting 'BackendStatusCtl' for $fname farm $type");

	if ( $type eq "tcp" || $type eq "udp" )
	{
		my $mport = &getFarmPort( $fname );
		@output = `$pen_ctl 127.0.0.1:$mport status`;
	}

	if ( $type eq "http" || $type eq "https" )
	{
		@output = `$poundctl -c  /tmp/$fname\_pound.socket`;
	}

	if ( $type eq "datalink" || $type eq "l4xnat" )
	{
		my $ffile = &getFarmFile( $fname );
		my @content;
		tie @content, 'Tie::File', "$configdir\/$ffile";
		@output = grep /^\;server\;/, @content;
		untie @content;
	}

	return @output;
}

#function that return the status information of a farm:
#ip, port, backendstatus, weight, priority, clients
sub getFarmBackendsStatus($fname,@content)
{
	( $fname, @content ) = @_;
	my $type   = &getFarmType( $fname );
	my @output = -1;

	#&logfile("getting 'BackendsStatus' for $fname farm $type");

	if ( $type eq "http" || $type eq "https" )
	{
		if ( !@content )
		{
			@content = &getFarmBackendStatusCtl( $fname );
		}
		my @backends;
		my @b_data;
		my $line;
		my @serviceline;
		foreach ( @content )
		{
			if ( $_ =~ /Service/ )
			{
				@serviceline = split ( "\ ", $_ );
				@serviceline[2] =~ s/"//g;
				chomp ( @serviceline[2] );
			}
			if ( $_ =~ /Backend/ )
			{

				#backend ID
				@backends = split ( "\ ", $_ );
				@backends[0] =~ s/\.//g;
				$line = @backends[0];

				#backend IP,PORT
				@backends_ip  = split ( ":", @backends[2] );
				$ip_backend   = @backends_ip[0];
				$port_backend = @backends_ip[1];
				$line         = $line . "\t" . $ip_backend . "\t" . $port_backend;

				#status
				$status_backend = @backends[7];
				my $backend_disabled = @backends[3];
				if ( $backend_disabled eq "DISABLED" )
				{

					#Checkstatusfile
					$status_backend = &getBackendStatusFromFile( $fname, @backends[0], @serviceline[2] );
				}
				elsif ( $status_backend eq "alive" )
				{
					$status_backend = "up";
				}
				elsif ( $status_backend eq "DEAD" )
				{
					$status_backend = "down";
				}
				$line = $line . "\t" . $status_backend;

				#priority
				$priority_backend = @backends[4];
				$priority_backend =~ s/\(//g;
				$line = $line . "\t" . "-\t" . $priority_backend;
				my $clients = &getFarmBackendsClients( @backends[0], @content );
				if ( $clients != -1 )
				{
					$line = $line . "\t" . $clients;
				}
				else
				{
					$line = $line . "\t-";
				}
				push ( @b_data, $line );
			}
		}
		@output = @b_data;
	}

	if ( $type eq "tcp" || $type eq "udp" )
	{
		if ( !@content )
		{

			#my $i=-1;
			#my $trc=-1;
			@content = &getFarmBackendStatusCtl( $fname );
		}
		foreach ( @content )
		{
			$i++;
			if ( $_ =~ /\<tr\>/ )
			{
				$trc++;
			}
			if ( $_ =~ /Time/ )
			{
				$_ =~ s/\<p\>//;
				my @value_backend = split ( ",", $_ );

				#$line =  "Real servers status\t@value_backend[1], @value_backend[2]";
				#push (@b_data,$line);
			}
			if ( $trc >= 2 && $_ =~ /\<tr\>/ )
			{

				#backend ID
				@content[$i] =~ s/\<td\>//;
				@content[$i] =~ s/\<\/td\>//;
				@content[$i] =~ s/\n//;
				my $id_backend = @content[$i];
				$line = $id_backend;

				#backend IP,PORT
				@content[$i + 1] =~ s/\<td\>//;
				@content[$i + 1] =~ s/\<\/td\>//;
				@content[$i + 1] =~ s/\n//;
				my $ip_backend = @content[$i + 1];
				$line = $line . "\t" . $ip_backend;

				#
				@content[$i + 3] =~ s/\<td\>//;
				@content[$i + 3] =~ s/\<\/td\>//;
				@content[$i + 3] =~ s/\n//;
				my $port_backend = @content[$i + 3];
				$line = $line . "\t" . $port_backend;

				#status
				@content[$i + 2] =~ s/\<td\>//;
				@content[$i + 2] =~ s/\<\/td\>//;
				@content[$i + 2] =~ s/\n//;
				my $status_maintenance = &getFarmBackendMaintenance( $fname, $id_backend );
				my $status_backend = @content[$i + 2];
				if ( $status_maintenance eq "0" )
				{
					$status_backend = "MAINTENANCE";
				}
				elsif ( $status_backend eq "0" )
				{
					$status_backend = "UP";
				}
				else
				{
					$status_backend = "DEAD";
				}
				$line = $line . "\t" . $status_backend;

				#clients
				#my $clients = &getFarmBackendsClients($id_backend,@content);
				#weight
				@content[$i + 9] =~ s/\<td\>//;
				@content[$i + 9] =~ s/\<\/td\>//;
				@content[$i + 9] =~ s/\n//;
				my $w_backend = @content[$i + 9];
				$line = $line . "\t" . $w_backend;

				#priority
				@content[$i + 10] =~ s/\<td\>//;
				@content[$i + 10] =~ s/\<\/td\>//;
				@content[$i + 10] =~ s/\n//;
				my $p_backend = @content[$i + 10];
				$line = $line . "\t" . $p_backend;

				#sessions
				if ( $ip_backend ne "0\.0\.0\.0" )
				{
					my $clients = &getFarmBackendsClients( $id_backend, @content );
					if ( $clients != -1 )
					{
						$line = $line . "\t" . $clients;
					}
					else
					{
						$line = $line . "\t-";
					}

				}

				#end
				push ( @b_data, $line );
			}

			if ( $_ =~ /\/table/ )
			{
				last;
			}
		}
		@output = @b_data;
	}

	if ( $type eq "datalink" )
	{
		my @servers;
		foreach $server ( @content )
		{
			my @serv = split ( ";", $server );
			push ( @servers, "@serv[2]\;@serv[3]\;@serv[4]\;@serv[5]\;@serv[6]" );
		}
		@output = @servers;
	}

	if ( $type eq "l4xnat" )
	{
		my @servers;
		foreach $server ( @content )
		{
			my @serv = split ( "\;", $server );
			my $port = @serv[3];
			if ( $port eq "" )
			{
				$port = &getFarmVip( "vipp", $fname );
			}
			push ( @servers, "@serv[2]\;$port\;@serv[5]\;@serv[6]\;@serv[7]" );
		}
		@output = @servers;
	}

	return @output;
}

#function that return if a pound backend is active, down by farmguardian or it's in maintenance mode
sub getBackendStatusFromFile($fname,$backend,$svice)
{
	my ( $fname, $backend, $svice ) = @_;
	my $index;
	my $line;
	my $stfile = "$configdir\/$fname\_status.cfg";
	my $output = -1;
	if ( -e "$stfile" )
	{
		$index = &getFarmVSI( $fname, $svice );
		open FG, "$stfile";
		while ( $line = <FG> )
		{

			#service index
			if ( $line =~ /\ 0\ ${index}\ ${backend}/ )
			{
				if ( $line =~ /maintenance/ )
				{
					$output = "maintenance";
				}
				elsif ( $line =~ /fgDOWN/ )
				{
					$output = "fgDOWN";
				}
				else
				{
					$output = "active";
				}
			}
		}
		close FG;
	}
	return $output;
}

#function that return the status information of a farm:
sub getFarmBackendsClients($idserver,@content)
{
	( $idserver, @content ) = @_;
	my $type   = &getFarmType( $fname );
	my $output = -1;
	my @backends;

	if ( $type eq "http" || $type eq "https" )
	{
		if ( !@content )
		{
			@content = &getFarmBackendStatusCtl( $fname );
		}
		my $numclients = 0;
		foreach ( @content )
		{
			if ( $_ =~ / Session .* -> $idserver$/ )
			{
				$numclients++;
			}
		}
		$output = $numclients;
	}

	if ( $type eq "tcp" || $type eq "udp" )
	{
		if ( !@content )
		{
			@content = &getFarmBackendStatusCtl( $fname );
		}
		if ( !@sessions )
		{
			@sessions = &getFarmBackendsClientsList( $farmname, @content );
		}
		my $numclients = 0;
		foreach ( @sessions )
		{
			my @ses_client = split ( "\t", $_ );
			chomp ( @ses_client[3] );
			chomp ( $idserver );
			if ( @ses_client[3] eq $idserver )
			{
				$numclients++;
			}
		}
		$output = $numclients;

	}
	return $output;
}

#function that return the status information of a farm:
sub getFarmBackendsClientsList($fname,@content)
{
	( $fname, @content ) = @_;
	my $type   = &getFarmType( $fname );
	my @output = -1;

	if ( $type eq "http" || $type eq "https" )
	{
		if ( !@content )
		{
			@content = &getFarmBackendStatusCtl( $fname );
		}
		my @sess;
		my @s_data;
		my @service;
		my $s;

		foreach ( @content )
		{
			my $line;
			if ( $_ =~ /Service/ )
			{
				@service = split ( "\ ", $_ );
				$s = @service[2];
				$s =~ s/"//g;
			}
			if ( $_ =~ / Session / )
			{
				@sess = split ( "\ ", $_ );
				my $id = @sess[0];
				$id =~ s/\.//g;
				$line = $s . "\t" . $id . "\t" . @sess[2] . "\t" . @sess[4];
				push ( @s_data, $line );
			}
		}
		@output = @s_data;
	}

	if ( $type eq "tcp" || $type eq "udp" )
	{
		if ( !@content )
		{
			@content = &getFarmBackendStatusCtl( $fname );
		}
		my $line;
		my @sess;
		my @s_data;
		my $ac_header = 0;
		my $tr        = 0;
		my $i         = -1;
		foreach ( @content )
		{
			$i++;
			if ( $_ =~ /Active clients/ )
			{
				$ac_header = 1;
				@value_session = split ( "\<\/h2\>", $_ );
				@value_session[1] =~ s/\<p\>\<table bgcolor\=\"#c0c0c0\">//;
				$line = @value_session[1];
				push ( @s_data, "Client sessions status\t$line" );
			}
			if ( $ac_header == 1 && $_ =~ /\<tr\>/ )
			{
				$tr++;
			}
			if ( $tr >= 2 && $_ =~ /\<tr\>/ )
			{
				@content[$i + 1] =~ s/\<td\>//;
				@content[$i + 1] =~ s/\<\/td\>//;
				chomp ( @content[$i + 1] );
				$line = @content[$i + 1];

				#
				@content[$i + 2] =~ s/\<td\>//;
				@content[$i + 2] =~ s/\<\/td\>//;
				chomp ( @content[$i + 2] );

				#
				$line = $line . "\t" . @content[$i + 2];
				@content[$i + 3] =~ s/\<td\>//;
				@content[$i + 3] =~ s/\<\/td\>//;
				chomp ( @content[$i + 3] );

				#
				$line = $line . "\t" . @content[$i + 3];
				@content[$i + 4] =~ s/\<td\>//;
				@content[$i + 4] =~ s/\<\/td\>//;

				#
				$line = $line . "\t" . @content[$i + 4];
				@content[$i + 5] =~ s/\<td\>//;
				@content[$i + 5] =~ s/\<\/td\>//;

				#
				$line = $line . "\t" . @content[$i + 5];
				@content[$i + 6] =~ s/\<td\>//;
				@content[$i + 6] =~ s/\<\/td\>//;
				@content[$i + 6] = @content[$i + 6] / 1024 / 1024;
				@content[$i + 6] = sprintf ( '%.2f', @content[$i + 6] );

				#
				$line = $line . "\t" . @content[$i + 6];
				@content[$i + 7] =~ s/\<td\>//;
				@content[$i + 7] =~ s/\<\/td\>//;
				@content[$i + 7] = @content[$i + 7] / 1024 / 1024;
				@content[$i + 7] = sprintf ( '%.2f', @content[$i + 7] );

				#
				$line = $line . "\t" . @content[$i + 7];
				push ( @s_data, $line );
			}
			if ( $ac_header == 1 && $_ =~ /\<\/table\>/ )
			{
				last;
			}

		}
		@output = @s_data;

	}
	return @output;
}

sub setFarmBackendStatus($fname,$index,$stat)
{
	( $fname, $index, $stat ) = @_;

	my $type   = &getFarmType( $fname );
	my $file   = &getFarmFile( $fname );
	my $output = -1;

	if ( $type eq "datalink" )
	{
		use Tie::File;
		tie @filelines, 'Tie::File', "$configdir\/$file";
		my $fileid   = 0;
		my $serverid = 0;
		foreach $line ( @filelines )
		{
			if ( $line =~ /\;server\;/ )
			{
				if ( $serverid eq $index )
				{
					my @lineargs = split ( "\;", $line );
					@lineargs[6] = $stat;
					@filelines[$fileid] = join ( "\;", @lineargs );
				}
				$serverid++;
			}
			$fileid++;
		}
		untie @filelines;
	}

	if ( $type eq "l4xnat" )
	{
		use Tie::File;
		tie @filelines, 'Tie::File', "$configdir\/$file";
		my $fileid   = 0;
		my $serverid = 0;
		foreach $line ( @filelines )
		{
			if ( $line =~ /\;server\;/ )
			{
				if ( $serverid eq $index )
				{
					my @lineargs = split ( "\;", $line );
					@lineargs[7] = $stat;
					@filelines[$fileid] = join ( "\;", @lineargs );
				}
				$serverid++;
			}
			$fileid++;
		}
		untie @filelines;
	}

	return $output;
}

sub getFarmBackendsClientsActives($fname,@content)
{
	( $fname, @content ) = @_;
	my $type   = &getFarmType( $fname );
	my @output = -1;
	if ( $type eq "tcp" || $type eq "udp" )
	{
		if ( !@content )
		{
			@content = &getFarmBackendStatusCtl( $fname );
		}
		my $line;
		my @sess;
		my @s_data;
		my $ac_header = 0;
		my $tr        = 0;
		my $i         = -1;
		foreach ( @content )
		{
			$i++;
			if ( $_ =~ /Active connections/ )
			{
				$ac_header = 1;
				my @value_conns = split ( "\<\/h2\>", $_ );
				@value_conns[1] =~ s/\<p\>\<table bgcolor\=\"#c0c0c0\"\>//;
				@value_conns[1] =~ s/Number of connections\://;
				$line = "Active connections\t@value_conns[1]";
				push ( @s_data, $line );
			}
			if ( $ac_header == 1 && $_ =~ /\<tr\>/ )
			{
				$tr++;
			}
			if ( $tr >= 2 && $_ =~ /\<tr\>/ )
			{
				@content[$i + 1] =~ s/\<td\>//;
				@content[$i + 1] =~ s/\<\/td\>//;
				chomp ( @content[$i + 1] );
				$line = @content[$i + 1];

				#
				@content[$i + 6] =~ s/\<td\>//;
				@content[$i + 6] =~ s/\<\/td\>//;
				$line = $line . "\t" . @content[$i + 6];

				#
				@content[$i + 7] =~ s/\<td\>//;
				@content[$i + 7] =~ s/\<\/td\>//;
				$line = $line . "\t" . @content[$i + 7];

				#
				push ( @s_data, $line );
			}
			if ( $ac_header == 1 && $_ =~ /\<\/table\>/ )
			{
				last;
			}

		}
		@output = @s_data;

	}
	return @output;

}

#function that renames a farm
sub setNewFarmName($fname,$newfname)
{
	my ( $fname, $newfname ) = @_;
	my $type   = &getFarmType( $fname );
	my $ffile  = &getFarmFile( $fname );
	my $output = -1;

	if ( $newfname =~ /^$/ )
	{
		&logfile( "error 'NewFarmName $newfname' is empty" );
		return -2;
	}

	&logfile( "setting 'NewFarmName $newfname' for $fname farm $type" );

	if ( $type eq "tcp" || $type eq "udp" )
	{
		my $newffile = "$newfname\_pen.cfg";
		if ( $type eq "udp" )
		{
			$newffile = "$newfname\_pen\_udp.cfg";
		}
		my $gfile = "$fname\_guardian.conf";
		use Tie::File;
		tie @filelines, 'Tie::File', "$configdir\/$ffile";
		for ( @filelines )
		{
			s/$fname/$newfname/g;
		}
		untie @filelines;

		rename ( "$configdir\/$ffile", "$configdir\/$newffile" );
		$output = $?;
		&logfile( "configuration saved in $configdir/$newffile file" );
		if ( -e "$configdir\/$gfile" )
		{
			my $newgfile = "$newfname\_guardian.conf";
			use Tie::File;
			tie @filelines, 'Tie::File', "$configdir\/$gfile";
			for ( @filelines )
			{
				s/$fname/$newfname/g;
			}
			untie @filelines;
			rename ( "$configdir\/$gfile", "$configdir\/$newgfile" );
			$output = $?;
			&logfile( "configuration saved in $configdir/$newgfile file" );
		}
	}

	if ( $type eq "http" || $type eq "https" )
	{
		my @ffiles    = ( "$configdir\/$fname\_status.cfg",    "$configdir\/$fname\_pound.cfg",    "$configdir\/$fname\_Err414.html",    "$configdir\/$fname\_Err500.html",    "$configdir\/$fname\_Err501.html",    "$configdir\/$fname\_Err503.html",    "$fname\_guardian.conf" );
		my @newffiles = ( "$configdir\/$newfname\_status.cfg", "$configdir\/$newfname\_pound.cfg", "$configdir\/$newfname\_Err414.html", "$configdir\/$newfname\_Err500.html", "$configdir\/$newfname\_Err501.html", "$configdir\/$newfname\_Err503.html", "$fname\_guardian.conf" );
		if ( -e "\/tmp\/$fname\_pound.socket" )
		{
			unlink ( "\/tmp\/$fname\_pound.socket" );
		}
		foreach $ffile ( @ffiles )
		{
			if ( -e "$ffile" )
			{
				use Tie::File;
				tie @filelines, 'Tie::File', "$ffile";
				for ( @filelines )
				{
					s/$fname/$newfname/g;
				}
				untie @filelines;
				rename ( "$ffile", "$newffiles[0]" );
				$output = $?;
				&logfile( "configuration saved in $newffiles[0] file" );
			}
			shift ( @newffiles );
		}
	}

	if ( $type eq "datalink" || $type eq "l4xnat" )
	{
		if ( $type eq "l4xnat" )
		{
			&runFarmStop( $fname, "false" );
		}
		my $newffile = "$newfname\_$type.cfg";
		use Tie::File;
		tie @filelines, 'Tie::File', "$configdir\/$ffile";
		for ( @filelines )
		{
			s/^$fname\;/$newfname\;/g;
		}
		untie @filelines;
		rename ( "$configdir\/$ffile",         "$configdir\/$newffile" );
		rename ( "$piddir\/$fname\_$type.pid", "$piddir\/$newfname\_$type.pid" );
		$output = $?;
	}

	if ( $type eq "l4xnat" )
	{

		# Rename fw marks for this farm
		&renameMarks( $fname, $newfname );
		&runFarmStart( $newfname, "false" );
		$output = 0;
	}

	if ( $type eq "gslb" )
	{
		my $newffile = "$newfname\_$type.cfg";
		rename ( "$configdir\/$ffile", "$configdir\/$newffile" );
		$output = 0;
	}

	# rename rrd
	rename ( "$rrdap_dir$rrd_dir/$fname-farm.rrd", "$rrdap_dir$rrd_dir/$newfname-farm.rrd" );

	# delete old graphs
	unlink ( "img/graphs/bar$fname.png" );

	return $output;
}

#Set Farm Ciphers vale
sub setFarmCiphers($fname,$ciphers)
{
	( $fname, $ciphers, $cipherc ) = @_;
	my $type   = &getFarmType( $fname );
	my $output = -1;
	if ( $type eq "https" )
	{
		my $file = &getFarmFile( $fname );
		tie @array, 'Tie::File', "$configdir/$file";
		for ( @array )
		{
			if ( $_ =~ /Ciphers/ )
			{
				if ( $ciphers eq "cipherglobal" )
				{
					$_ =~ s/\tCiphers/\t#Ciphers/g;
					$output = 0;
				}
				if ( $ciphers eq "cipherpci" )
				{
					$_ =~ s/#//g;
					$_      = "\tCiphers \"$cipher_pci\"";
					$output = 0;
				}
				if ( $ciphers eq "ciphercustom" )
				{
					$_ =~ s/#//g;
					$_      = "\tCiphers \"$cipher_pci\"";
					$output = 0;
				}
				if ( $cipherc )
				{
					$_ =~ s/#//g;
					$_      = "\tCiphers \"$cipherc\"";
					$output = 0;
				}
			}
		}
		untie @array;
	}
	return $output;
}

#Get Farm Ciphers value
sub getFarmCipher($fname)
{
	( $fname ) = @_;
	my $type   = &getFarmType( $fname );
	my $output = -1;
	if ( $type eq "https" )
	{
		my $file = &getFarmFile( $fname );
		open FI, "<$configdir/$file";
		my @content = <FI>;
		close FI;
		foreach $line ( @content )
		{
			if ( $line =~ /Ciphers/ )
			{
				my @partline = split ( '\ ', $line );
				$lfile = @partline[1];
				$lfile =~ s/\"//g;
				chomp ( $lfile );
				if ( $line =~ /#/ )
				{
					$output = "cipherglobal";
				}
				else
				{
					$output = $lfile;
				}
			}
		}
	}
	return $output;
}

#function that check if the config file is OK.
sub getFarmConfigIsOK($fname)
{
	( $fname ) = @_;

	my $type  = &getFarmType( $fname );
	my $ffile = &getFarmFile( $fname );
	$output = -1;
	if ( $type eq "http" || $type eq "https" )
	{
		&logfile( "running: $pound -f $configdir\/$ffile -c " );

		#zsystem("$pound -f $configdir\/$ffile -c >/dev/null");
		my $run = `$pound -f $configdir\/$ffile -c 2>&1`;
		$output = $?;
		&logfile( "output: $run " );
	}
	if ( $type eq "gslb" )
	{
		$output = &getFarmGSLBConfigIsOK( $ffile );
	}
	return $output;
}

#function that check if a backend on a farm is on maintenance mode
sub getFarmBackendMaintenance($fname,$backend,$sv)
{
	my ( $fname, $backend, $svice ) = @_;
	my $type  = &getFarmType( $fname );
	my $ffile = &getFarmFile( $fname );
	$output = -1;
	if ( $type eq "tcp" || $type eq "udp" )
	{
		open FR, "<$configdir\/$ffile";
		my @content = <FR>;
		foreach $line ( @content )
		{
			if ( $line =~ /^server $backend acl 9/ )
			{
				$output = 0;
			}
			close FR;
		}
	}

	if ( $type eq "http" || $type eq "https" )
	{
		@run = `$poundctl -c "/tmp/$fname\_pound.socket"`;
		my $sw = 0;
		foreach $line ( @run )
		{
			if ( $line =~ /Service \"$svice\"/ )
			{
				$sw = 1;
			}
			if ( $line =~ /$backend\. Backend/ && $sw == 1 )
			{
				my @line = split ( "\ ", $line );
				my $backendstatus = @line[3];
				if ( $backendstatus eq "DISABLED" )
				{
					$backendstatus = &getBackendStatusFromFile( $fname, $backend, $svice );
					if ( $backendstatus =~ /maintenance/ )
					{
						$output = 0;
					}
				}
				last;
			}
		}
	}

	return $output;
}

#function that enable the maintenance mode for backend
sub setFarmBackendMaintenance($fname,$backend,$service)
{
	my ( $fname, $backend, $svice ) = @_;
	my $type  = &getFarmType( $fname );
	my $ffile = &getFarmFile( $fname );
	$output = -1;
	if ( $type eq "tcp" || $type eq "udp" )
	{
		&logfile( "setting Maintenance mode for $fname backend $backend" );
		my $fport       = &getFarmPort( $fname );
		my $fmaxservers = &getFarmMaxServers( $fname );
		&logfile( "running '$pen_ctl 127.0.0.1:$fport server $id_server acl 9'" );
		my @run = `$pen_ctl 127.0.0.1:$fport server $id_server acl 9  2> /dev/null`;
		$output = $?;
		&logfile( "running '$pen_ctl 127.0.0.1:$fport write '$configdir/$ffile'" );
		my @run = `$pen_ctl 127.0.0.1:$fport write '$configdir/$ffile'`;
		&setFarmMaxServers( $fmaxservers, $fname );
	}

	if ( $type eq "http" || $type eq "https" )
	{
		&logfile( "setting Maintenance mode for $fname service $svice backend $backend" );

		#find the service number
		my $idsv = &getFarmVSI( $fname, $svice );
		@run    = `$poundctl -c /tmp/$fname\_pound.socket -b 0 $idsv $backend`;
		$output = $?;
		&logfile( "running '$poundctl -c /tmp/$fname\_pound.socket -b 0 $idsv $backend'" );
		&getFarmHttpBackendStatus( $farmname, $backend, "maintenance", $idsv );
	}

	return $output;
}

#function that disable the maintenance mode for backend
sub setFarmBackendNoMaintenance($fname,$backend,$service)
{
	my ( $fname, $backend, $svice ) = @_;
	my $type  = &getFarmType( $fname );
	my $ffile = &getFarmFile( $fname );
	$output = -1;
	if ( $type eq "tcp" || $type eq "udp" )
	{
		&logfile( "setting Disabled maintenance mode for $fname backend $backend" );
		my $fport       = &getFarmPort( $fname );
		my $fmaxservers = &getFarmMaxServers( $fname );
		&logfile( "running '$pen_ctl 127.0.0.1:$fport server $id_server acl 0'" );
		my @run = `$pen_ctl 127.0.0.1:$fport server $id_server acl 0  2> /dev/null`;
		$output = $?;
		&logfile( "running '$pen_ctl 127.0.0.1:$fport write '$configdir/$ffile'" );
		my @run = `$pen_ctl 127.0.0.1:$fport write '$configdir/$ffile'`;
		&setFarmMaxServers( $fmaxservers, $fname );
	}

	if ( $type eq "http" || $type eq "https" )
	{
		&logfile( "setting Disabled maintenance mode for $fname backend $backend" );

		#find the service number
		my $idsv = &getFarmVSI( $fname, $svice );
		@run    = `$poundctl -c /tmp/$fname\_pound.socket -B 0 $idsv $backend`;
		$output = $?;
		&logfile( "running '$poundctl -c /tmp/$fname\_pound.socket -B 0 $idsv $backend'" );
		&getFarmHttpBackendStatus( $fname, $backend, "active", $idsv );
	}
	return $output;
}

#function that save in a file the backend status (maintenance or not)
sub getFarmHttpBackendStatus($fname,$backend,$status,$idsv)
{
	( $fname, $backend, $status, $idsv ) = @_;
	my $line;
	my @sw;
	my @bw;
	my $changed    = "false";
	my $statusfile = "$configdir\/$fname\_status.cfg";

	#&logfile("Saving backends status in farm $fname");
	if ( !-e $statusfile )
	{
		open FW, ">$statusfile";
		@run = `$poundctl -c /tmp/$fname\_pound.socket`;
		foreach $line ( @run )
		{
			if ( $line =~ /\.\ Service\ / )
			{
				@sw = split ( "\ ", $line );
				@sw[0] =~ s/\.//g;
				chomp @sw[0];
			}
			if ( $line =~ /\.\ Backend\ / )
			{
				@bw = split ( "\ ", $line );
				@bw[0] =~ s/\.//g;
				chomp @bw[0];
				if ( @bw[3] eq "active" )
				{
					print FW "-B 0 @sw[0] @bw[0] active\n";
				}
				else
				{
					print FW "-b 0 @sw[0] @bw[0] fgDOWN\n";
				}
			}
		}
		close FW;
	}
	use Tie::File;
	tie @filelines, 'Tie::File', "$statusfile";
	for ( @filelines )
	{
		if ( $_ =~ /\ 0\ $idsv\ $backend/ )
		{
			if ( $status =~ /maintenance/ || $status =~ /fgDOWN/ )
			{
				$_       = "-b 0 $idsv $backend $status";
				$changed = "true";
			}
			else
			{
				$_       = "-B 0 $idsv $backend $status";
				$changed = "true";
			}
		}
	}
	untie @filelines;
	if ( $changed eq "false" )
	{
		open FW, ">>$statusfile";
		if ( $status =~ /maintenance/ || $status =~ /fgDOWN/ )
		{
			print FW "-b 0 $idsv $backend $status\n";
		}
		else
		{
			print FW "-B 0 $idsv $backend active\n";
		}
		close FW;
	}
}

#Function that removes a backend from the status file
sub runRemovehttpBackend($fname,$backend,$service)
{
	( $fname, $backend, $service ) = @_;
	my $i      = -1;
	my $j      = -1;
	my $change = "false";
	my $sindex = &getFarmVSI( $fname, $service );
	tie @contents, 'Tie::File', "$configdir\/$fname\_status.cfg";
	foreach $line ( @contents )
	{
		$i++;
		if ( $line =~ /0\ ${sindex}\ ${backend}/ )
		{
			splice @contents, $i, 1,;
		}
	}
	untie @contents;
	my $index = -1;
	tie @filelines, 'Tie::File', "$configdir\/$fname\_status.cfg";
	for ( @filelines )
	{
		$index++;
		if ( $_ !~ /0\ ${sindex}\ $index/ )
		{
			$jndex = $index + 1;
			$_ =~ s/0\ ${sindex}\ $jndex/0\ ${sindex}\ $index/g;
		}
	}
	untie @filelines;
}

sub setFarmHttpBackendStatus($fname)
{
	( $fname ) = @_;
	my $line;
	&logfile( "Setting backends status in farm $fname" );
	open FR, "<$configdir\/$fname\_status.cfg";
	while ( <FR> )
	{
		@line = split ( "\ ", $_ );
		@run = `$poundctl -c /tmp/$fname\_pound.socket @line[0] @line[1] @line[2] @line[3]`;
	}
	close FR;
}

#checks thata farmname has correct characters (number, letters and lowercases)
sub checkFarmnameOK($fname)
{
	( $check_name ) = @_;
	$output = -1;

	#if ($fname =~ /^\w+$/){
	if ( $check_name =~ /^[a-zA-Z0-9\-]*$/ )
	{
		$output = 0;
	}

	return $output;
}

#Create a new Service in a HTTP farm
sub setFarmHTTPNewService($fname,$service)
{
	my ( $fname, $service ) = @_;
	$output = -1;

	#first check if service name exist
	if ( $service =~ /(?=)/ && $service =~ /^$/ )
	{

		#error 2 eq $service is empty
		$output = 2;
		return $output;
	}

	#check the correct string in the service
	my $newservice = &checkFarmnameOK( $service );
	if ( $newservice ne 0 )
	{
		$output = 3;
		return $output;
	}
	use File::Grep qw( fgrep fmap fdo );
	if ( !fgrep { /Service "$service"/ } "$configdir/$fname\_pound.cfg" )
	{

		#create service
		my @newservice;
		my $sw    = 0;
		my $count = 0;
		tie @poundtpl, 'Tie::File', "$poundtpl";
		my $countend = 0;
		foreach $line ( @poundtpl )
		{

			if ( $line =~ /Service \"\[DESC\]\"/ )
			{
				$sw = 1;
			}

			if ( $sw eq "1" )
			{
				push ( @newservice, $line );

			}

			if ( $line =~ /End/ )
			{
				$count++;
			}
			if ( $count eq "4" )
			{
				last;
			}

		}
		untie @poundtpl;

		@newservice[0] =~ s/#//g;
		@newservice[$#newservice] =~ s/#//g;

		my @fileconf;
		tie @fileconf, 'Tie::File', "$configdir/$fname\_pound.cfg";
		my $i    = 0;
		my $type = "";
		$type = &getFarmType( $farmname );
		foreach $line ( @fileconf )
		{
			if ( $line =~ /#ZWACL-END/ )
			{
				foreach $lline ( @newservice )
				{
					if ( $lline =~ /\[DESC\]/ ) { $lline =~ s/\[DESC\]/$service/; }
					if ( $lline =~ /StrictTransportSecurity/ && $type eq "https" )
					{
						$lline =~ s/#//;
					}
					splice @fileconf, $i, 0, "$lline";
					$i++;
				}
				last;
			}
			$i++;
		}
		untie @fileconf;
		$output = 0;

	}
	else
	{
		$output = 1;
	}
	return $output;
}

# Get farm zones list for GSLB farms
sub getFarmZones($fname)
{
	my ( $fname ) = @_;

	my $output = -1;
	my $ftype  = &getFarmType( $fname );

	opendir ( DIR, "$configdir\/$fname\_$ftype.cfg\/etc\/zones\/" );
	my @files = grep { /^[a-zA-Z]/ } readdir ( DIR );
	closedir ( DIR );

	return @files;
}

# Get farm services list for GSLB farms
sub getFarmServices($fname)
{
	my ( $fname ) = @_;

	my $output = -1;
	my $ftype  = &getFarmType( $fname );
	my @srvarr = ();

	opendir ( DIR, "$configdir\/$fname\_$ftype.cfg\/etc\/plugins\/" );
	my @pluginlist = readdir ( DIR );
	closedir ( DIR );
	foreach $plugin ( @pluginlist )
	{
		if ( $plugin !~ /^\./ )
		{
			@fileconf = ();
			tie @fileconf, 'Tie::File', "$configdir\/$fname\_$ftype.cfg\/etc\/plugins\/$plugin";
			my @srv = grep ( /^\t[a-zA-Z1-9].* => {/, @fileconf );
			foreach $srvstring ( @srv )
			{
				my @srvstr = split ( ' => ', $srvstring );
				$srvstring = $srvstr[0];
				$srvstring =~ s/^\s+|\s+$//g;
			}
			my $nsrv = @srv;
			if ( $nsrv > 0 )
			{
				push ( @srvarr, @srv );
			}
			untie @fileconf;
		}
	}
	return @srvarr;
}

#Create a new farm service
sub setFarmNewService($fname,$service)
{
	my ( $fname, $svice ) = @_;

	my $type   = &getFarmType( $fname );
	my $output = -1;

	if ( $type eq "http" || $type eq "https" )
	{
		$output = &setFarmHTTPNewService( $fname, $svice );
	}

	return $output;
}

#delete a service in a Farm
sub deleteFarmService($farmname,$service)
{
	my ( $fname, $svice ) = @_;

	my $ffile = &getFarmFile( $fname );
	my @fileconf;
	my $line;
	use Tie::File;
	tie @fileconf, 'Tie::File', "$configdir/$ffile";
	my $sw     = 0;
	my $output = -1;

	# Stop FG service
	&runFarmGuardianStop( $farmname, $svice );

	my $i = 0;
	for ( $i = 0 ; $i < $#fileconf ; $i++ )
	{
		$line = @fileconf[$i];
		if ( $sw eq "1" && ( $line =~ /ZWACL-END/ || $line =~ /Service\ \"/ ) )
		{
			$output = 0;
			last;
		}

		if ( $sw == 1 )
		{
			splice @fileconf, $i, 1,;
			$i--;
		}
		if ( $line =~ /Service "$svice"/ )
		{
			$sw = 1;
			splice @fileconf, $i, 1,;
			$i--;
		}

	}
	untie @fileconf;

	return $output;

}

#function that return indicated value from a HTTP Service
#vs return virtual server
sub getFarmVS($farmname,$service,$tag)
{
	my ( $fname, $svice, $tag ) = @_;

	my $output = "";
	my $type   = &getFarmType( $fname );
	my $ffile  = &getFarmFile( $fname );

	if ( $type eq "http" || $type eq "https" )
	{
		my @fileconf;
		my $line;
		use Tie::File;
		tie @fileconf, 'Tie::File', "$configdir/$ffile";
		my $sw = 0;
		my @return;
		my $be_section = 0;
		my $be         = -1;
		my @output;
		my $sw_ti     = 0;
		my $output_ti = "";
		my $sw_pr     = 0;
		my $output_pr = "";

		foreach $line ( @fileconf )
		{
			if ( $line =~ /^\tService/ )
			{
				$sw = 0;
			}
			if ( $line =~ /^\tService \"$svice\"/ )
			{
				$sw = 1;
			}

			# returns all services for this farm
			if ( $tag eq "" && $svice eq "" )
			{
				if ( $line =~ /^\tService\ \"/ && $line !~ "#" )
				{
					@return = split ( "\ ", $line );
					@return[1] =~ s/\"//g;
					@return[1] =~ s/^\s+//;
					@return[1] =~ s/\s+$//;
					$output = "$output @return[1]";
				}
			}

			#vs tag
			if ( $tag eq "vs" )
			{
				if ( $line =~ "HeadRequire" && $sw == 1 && $line !~ "#" )
				{
					@return = split ( "Host:", $line );
					@return[1] =~ s/\"//g;
					@return[1] =~ s/^\s+//;
					@return[1] =~ s/\s+$//;
					$output = @return[1];
					last;

				}
			}

			#url pattern
			if ( $tag eq "urlp" )
			{
				if ( $line =~ "Url \"" && $sw == 1 && $line !~ "#" )
				{
					@return = split ( "Url", $line );
					@return[1] =~ s/\"//g;
					@return[1] =~ s/^\s+//;
					@return[1] =~ s/\s+$//;
					$output = @return[1];
					last;
				}
			}

			#redirect
			if ( $tag eq "redirect" )
			{
				if ( ( $line =~ "Redirect \"" || $line =~ "RedirectAppend \"" ) && $sw == 1 && $line !~ "#" )
				{
					if ( $line =~ "Redirect \"" )
					{
						@return = split ( "Redirect", $line );
					}
					elsif ( $line =~ "RedirectAppend \"" )
					{
						@return = split ( "RedirectAppend", $line );
					}
					@return[1] =~ s/\"//g;
					@return[1] =~ s/^\s+//;
					@return[1] =~ s/\s+$//;
					$output = @return[1];
					last;
				}
			}
			if ( $tag eq "redirecttype" )
			{
				if ( ( $line =~ "Redirect \"" || $line =~ "RedirectAppend \"" ) && $sw == 1 && $line !~ "#" )
				{
					if ( $line =~ "Redirect \"" )
					{
						$output = "default";
					}
					elsif ( $line =~ "RedirectAppend \"" )
					{
						$output = "append";
					}
					last;
				}
			}

			#cookie insertion
			if ( $tag eq "cookieins" )
			{
				if ( $line =~ "BackendCookie \"" && $sw == 1 && $line !~ "#" )
				{
					$output = "true";
					last;
				}
			}

			#cookie insertion name
			if ( $tag eq "cookieins-name" )
			{
				if ( $line =~ "BackendCookie \"" && $sw == 1 && $line !~ "#" )
				{
					$l = $line;
					$l =~ s/\t\t//g;
					$l =~ s/\"//g;
					my @values = split ( "\ ", $l );
					$output = @values[1];
					chomp ( $output );
					last;
				}
			}

			#cookie insertion Domain
			if ( $tag eq "cookieins-domain" )
			{
				if ( $line =~ "BackendCookie \"" && $sw == 1 && $line !~ "#" )
				{
					$l = $line;
					$l =~ s/\t\t//g;
					$l =~ s/\"//g;
					my @values = split ( "\ ", $l );
					$output = @values[2];
					chomp ( $output );
					last;
				}
			}

			#cookie insertion Path
			if ( $tag eq "cookieins-path" )
			{
				if ( $line =~ "BackendCookie \"" && $sw == 1 && $line !~ "#" )
				{
					$l = $line;
					$l =~ s/\t\t//g;
					$l =~ s/\"//g;
					my @values = split ( "\ ", $l );
					$output = @values[3];
					chomp ( $output );
					last;
				}
			}

			#cookie insertion TTL
			if ( $tag eq "cookieins-ttlc" )
			{
				if ( $line =~ "BackendCookie \"" && $sw == 1 && $line !~ "#" )
				{
					$l = $line;
					$l =~ s/\t\t//g;
					$l =~ s/\"//g;
					my @values = split ( "\ ", $l );
					$output = @values[4];
					chomp ( $output );
					last;
				}
			}

			#dynscale
			if ( $tag eq "dynscale" )
			{
				if ( $line =~ "DynScale\ " && $sw == 1 && $line !~ "#" )
				{
					$output = "true";
					last;
				}

			}

			#sesstion type
			if ( $tag eq "sesstype" )
			{
				if ( $line =~ "Type" && $sw == 1 && $line !~ "#" )
				{
					@return = split ( "\ ", $line );
					@return[1] =~ s/\"//g;
					@return[1] =~ s/^\s+//;
					@return[1] =~ s/\s+$//;
					$output = @return[1];
					last;
				}
			}

			#ttl
			if ( $tag eq "ttl" )
			{
				if ( $line =~ "TTL" && $sw == 1 && $line !~ "#" )
				{
					@return = split ( "\ ", $line );
					@return[1] =~ s/\"//g;
					@return[1] =~ s/^\s+//;
					@return[1] =~ s/\s+$//;
					$output = @return[1];
					last;
				}
			}

			#session id
			if ( $tag eq "sessionid" )
			{
				if ( $line =~ "\t\t\tID" && $sw == 1 && $line !~ "#" )
				{
					@return = split ( "\ ", $line );
					@return[1] =~ s/\"//g;
					@return[1] =~ s/^\s+//;
					@return[1] =~ s/\s+$//;
					$output = @return[1];
					last;
				}
			}

			#HTTPS tag
			if ( $tag eq "httpsbackend" )
			{
				if ( $line =~ "##True##HTTPS-backend##" && $sw == 1 )
				{
					$output = "true";
					last;
				}
			}

			#backends
			if ( $tag eq "backends" )
			{
				if ( $line =~ /#BackEnd/ && $sw == 1 )
				{
					$be_section = 1;
				}
				if ( $be_section == 1 )
				{

					#if ($line =~ /Address/ && $be >=1){
					if ( $line =~ /End/ && $line !~ /#/ && $sw == 1 && $be_section == 1 && $line !~ /BackEnd/ )
					{
						if ( $sw_ti == 0 )
						{
							$output_ti = "TimeOut -";
						}
						if ( $sw_pr == 0 )
						{
							$output_pr = "Priority -";
						}
						$output    = "$output $outputa $outputp $output_ti $output_pr\n";
						$output_ti = "";
						$output_pr = "";
						$sw_ti     = 0;
						$sw_pr     = 0;
					}
					if ( $line =~ /Address/ )
					{
						$be++;
						chomp ( $line );
						$outputa = "Server $be $line";
					}
					if ( $line =~ /Port/ )
					{
						chomp ( $line );
						$outputp = "$line";
					}
					if ( $line =~ /TimeOut/ )
					{
						chomp ( $line );

						#$output = $output . "$line";
						$output_ti = $line;
						$sw_ti     = 1;
					}
					if ( $line =~ /Priority/ )
					{
						chomp ( $line );

						#$output = $output . "$line";
						$output_pr = $line;
						$sw_pr     = 1;
					}
				}
				if ( $sw == 1 && $be_section == 1 && $line =~ /#End/ )
				{
					last;
				}
			}
		}
		untie @fileconf;
	}

	if ( $type eq "gslb" )
	{
		my @fileconf;
		my $line;
		my @linesplt;
		use Tie::File;
		if ( $tag eq "ns" || $tag eq "resources" )
		{
			tie @fileconf, 'Tie::File', "$configdir/$ffile/etc/zones/$svice";
			foreach $line ( @fileconf )
			{
				if ( $tag eq "ns" )
				{
					if ( $line =~ /@.*SOA .* hostmaster / )
					{
						@linesplt = split ( " ", $line );
						$output = @linesplt[2];
						last;
					}
				}
				if ( $tag eq "resources" )
				{
					if ( $line =~ /;index_.*/ )
					{
						my $tmpline = $line;
						$tmpline =~ s/multifo!|simplefo!//g;
						$output = "$output\n$tmpline";
					}
				}
			}
		}
		else
		{
			my $found      = 0;
			my $pluginfile = "";
			opendir ( DIR, "$configdir\/$fname\_$type.cfg\/etc\/plugins\/" );
			my @pluginlist = readdir ( DIR );
			foreach $plugin ( @pluginlist )
			{
				tie @fileconf, 'Tie::File', "$configdir\/$fname\_$type.cfg\/etc\/plugins\/$plugin";
				if ( grep ( /^\t$svice => /, @fileconf ) )
				{
					$pluginfile = $plugin;
				}
				untie @fileconf;
			}
			closedir ( DIR );
			tie @fileconf, 'Tie::File', "$configdir\/$fname\_$type.cfg\/etc\/plugins\/$pluginfile";
			foreach $line ( @fileconf )
			{
				if ( $tag eq "backends" )
				{
					if ( $found == 1 && $line =~ /.*}.*/ )
					{
						last;
					}
					if ( $found == 1 && $line !~ /^$/ && $line !~ /.*service_types.*/ )
					{
						$output = "$output\n$line";
					}
					if ( $line =~ /\t$svice => / )
					{
						$found = 1;
					}
				}
				if ( $tag eq "algorithm" )
				{
					@linesplt = split ( " ", $line );
					if ( @linesplt[0] eq "simplefo" )
					{
						$output = "prio";
					}
					if ( @linesplt[0] eq "multifo" )
					{
						$output = "roundrobin";
					}
					last;
				}
				if ( $tag eq "plugin" )
				{
					@linesplt = split ( " ", $line );
					$output = @linesplt[0];
					last;
				}
				if ( $tag eq "dpc" )
				{
					if ( $found == 1 && $line =~ /.*}.*/ )
					{
						last;
					}
					if ( $found == 1 && $line =~ /.*service_types.*/ )
					{
						my @tmpline = split ( "=", $line );
						$output = @tmpline[1];
						$output =~ s/['\[''\]'' ']//g;
						my @tmp = split ( "_", $output );
						$output = @tmp[1];
						last;
					}
					if ( $line =~ /\t$svice => / )
					{
						$found = 1;
					}
				}
			}
		}
		untie @fileconf;
	}

	return $output;
}

#set values for a service
sub setFarmVS($farmname,$service,$tag,$string)
{
	( $fname, $svice, $tag, $stri ) = @_;

	my $output = "";
	my $type   = &getFarmType( $fname );
	my $ffile  = &getFarmFile( $fname );

	if ( $type eq "http" || $type eq "https" )
	{
		my @fileconf;
		my $line;
		use Tie::File;
		tie @fileconf, 'Tie::File', "$configdir/$ffile";
		my $sw = 0;
		my @vserver;

		$j = -1;
		foreach $line ( @fileconf )
		{
			$j++;
			if ( $line =~ /Service \"$svice\"/ )
			{
				$sw = 1;
			}
			$stri =~ s/^\s+//;
			$stri =~ s/\s+$//;

			#vs tag
			if ( $tag eq "vs" )
			{
				if ( $line =~ "HeadRequire" && $sw == 1 && $stri ne "" )
				{
					$line = "\t\tHeadRequire \"Host: $stri\"";
					last;
				}
				if ( $line =~ "HeadRequire" && $sw == 1 && $stri eq "" )
				{
					$line = "\t\t#HeadRequire \"Host:\"";
					last;
				}
			}

			#url pattern
			if ( $tag eq "urlp" )
			{
				if ( $line =~ "Url" && $sw == 1 && $stri ne "" )
				{
					$line = "\t\tUrl \"$stri\"";
					last;
				}
				if ( $line =~ "Url" & $sw == 1 && $stri eq "" )
				{
					$line = "\t\t#Url \"\"";
					last;
				}
			}

			#dynscale
			if ( $tag eq "dynscale" )
			{
				if ( $line =~ "DynScale" && $sw == 1 && $stri ne "" )
				{
					$line = "\t\tDynScale 1";
					last;
				}
				if ( $line =~ "DynScale" && $sw == 1 && $stri eq "" )
				{
					$line = "\t\t#DynScale 1";
					last;
				}
			}

			#client redirect default
			if ( $tag eq "redirect" )
			{
				if ( ( $line =~ "Redirect\ \"" || $line =~ "RedirectAppend\ \"" ) && $sw == 1 && $stri ne "" )
				{
					$line = "\t\tRedirect \"$stri\"";
					last;
				}
				if ( ( $line =~ "Redirect\ \"" || $line =~ "RedirectAppend\ \"" ) && $sw == 1 && $stri eq "" )
				{
					$line = "\t\t#Redirect \"\"";
					last;
				}
			}

			#client redirect append
			if ( $tag eq "redirectappend" )
			{
				if ( ( $line =~ "Redirect\ \"" || $line =~ "RedirectAppend\ \"" ) && $sw == 1 && $stri ne "" )
				{
					$line = "\t\tRedirectAppend \"$stri\"";
					last;
				}
				if ( ( $line =~ "Redirect\ \"" || $line =~ "RedirectAppend\ \"" ) && $sw == 1 && $stri eq "" )
				{
					$line = "\t\t#Redirect \"\"";
					last;
				}
			}

			#cookie ins
			if ( $tag eq "cookieins" )
			{
				if ( $line =~ "BackendCookie" && $sw == 1 && $stri ne "" )
				{

					#$line =~ s/\t\t/$line/g;
					$line =~ s/#//g;

					#$line = "$line";
					last;
				}
				if ( $line =~ "BackendCookie" && $sw == 1 && $stri eq "" )
				{
					$line =~ s/\t\t//g;
					$line = "\t\t#$line";
					last;
				}
			}

			#cookie insertion name
			if ( $tag eq "cookieins-name" )
			{
				if ( $line =~ "BackendCookie" && $sw == 1 && $stri ne "" )
				{
					$l = $line;
					$l =~ s/\t\t//g;
					my @values = split ( "\ ", $l );
					@values[1] =~ s/\"//g;
					$line = "\t\tBackendCookie \"$stri\" @values[2] @values[3] @values[4]";
					last;
				}
			}

			#cookie insertion domain
			if ( $tag eq "cookieins-domain" )
			{
				if ( $line =~ "BackendCookie" && $sw == 1 && $stri ne "" )
				{
					$l = $line;
					$l =~ s/\t\t//g;
					my @values = split ( "\ ", $l );
					@values[2] =~ s/\"//g;
					$line = "\t\tBackendCookie @values[1] \"$stri\" @values[3] @values[4]";
					last;
				}
			}

			#cookie insertion path
			if ( $tag eq "cookieins-path" )
			{
				if ( $line =~ "BackendCookie" && $sw == 1 && $stri ne "" )
				{
					$l = $line;
					$l =~ s/\t\t//g;
					my @values = split ( "\ ", $l );
					@values[3] =~ s/\"//g;
					$line = "\t\tBackendCookie @values[1] @values[2] \"$stri\" @values[4]";
					last;
				}
			}

			#cookie insertion TTL
			if ( $tag eq "cookieins-ttlc" )
			{
				if ( $line =~ "BackendCookie" && $sw == 1 && $stri ne "" )
				{
					$l = $line;
					$l =~ s/\t\t//g;
					my @values = split ( "\ ", $l );
					@values[4] =~ s/\"//g;
					$line = "\t\tBackendCookie @values[1] @values[2] @values[3] $stri";
					last;
				}
			}

			#TTL
			if ( $tag eq "ttl" )
			{
				if ( $line =~ "TTL" && $sw == 1 && $stri ne "" )
				{
					$line = "\t\t\tTTL $stri";
					last;
				}
				if ( $line =~ "TTL" && $sw == 1 && $stri eq "" )
				{
					$line = "\t\t\t#TTL 120";
					last;
				}
			}

			#session id
			if ( $tag eq "sessionid" )
			{
				if ( $line =~ "\t\t\tID|\t\t\t#ID" && $sw == 1 && $stri ne "" )
				{
					$line = "\t\t\tID \"$stri\"";
					last;
				}
				if ( $line =~ "\t\t\tID|\t\t\t#ID" && $sw == 1 && $stri eq "" )
				{
					$line = "\t\t\t#ID \"$stri\"";
					last;
				}
			}

			#HTTPS Backends tag
			if ( $tag eq "httpsbackend" )
			{
				if ( $line =~ "##HTTPS-backend##" && $sw == 1 && $stri ne "" )
				{

					#turn on
					$line = "\t\t##True##HTTPS-backend##";

					#last;
				}

				#
				if ( $line =~ "##HTTPS-backend##" && $sw == 1 && $stri eq "" )
				{

					#turn off
					$line = "\t\t##False##HTTPS-backend##";

					#last;
				}

				#Delete HTTPS tag in a BackEnd
				if ( $sw == 1 && $line =~ /HTTPS$/ && $stri eq "" )
				{

					#Delete HTTPS tag
					splice @fileconf, $j, 1,;
				}

				#Add HTTPS tag
				if ( $sw == 1 && $line =~ /BackEnd$/ && $stri ne "" )
				{
					if ( @fileconf[$j + 1] =~ /Address\ .*/ )
					{

						#add new line with HTTPS tag
						splice @fileconf, $j + 1, 0, "\t\t\tHTTPS";
					}
				}

				#go out of curret Service
				if ( $line =~ /Service \"/ && $sw == 1 && $line !~ /Service \"$svice\"/ )
				{
					$tag = "";
					$sw  = 0;
					last;
				}
			}

			#session type
			if ( $tag eq "session" )
			{
				if ( $session ne "nothing" && $sw == 1 )
				{
					if ( $line =~ "Session" )
					{
						$line = "\t\tSession";
					}
					if ( $line =~ "End" )
					{
						$line = "\t\tEnd";
					}
					if ( $line =~ "Type" )
					{
						$line = "\t\t\tType $session";

						#@contents[$i+1]=~ s/#//g;
					}
					if ( $line =~ "TTL" )
					{
						$line =~ s/#//g;
					}
					if ( $session eq "URL" || $session eq "COOKIE" || $session eq "HEADER" )
					{

						#@contents[$i+2]=~ s/#//g;
						if ( $line =~ "\t\t\tID |\t\t\t#ID " )
						{
							$line =~ s/#//g;
						}
					}
					if ( $session eq "IP" )
					{
						if ( $line =~ "\t\t\tID |\t\t\t#ID " )
						{
							$line = "\#$line";
						}
					}
					$output = $?;
				}
				if ( $session eq "nothing" && $sw == 1 )
				{
					if ( $line =~ "Session" )
					{
						$line = "\t\t#Session";
					}
					if ( $line =~ "End" )
					{
						$line = "\t\t#End";
					}
					if ( $line =~ "TTL" )
					{
						$line = "\t\t\t#TTL 120";
					}
					if ( $line =~ "Type" )
					{
						$line = "\t\t\t#Type nothing";
					}
					if ( $line =~ "\t\t\tID |\t\t\t#ID " )
					{
						$line = "\t\t\t#ID \"sessionname\"";
					}
				}
				if ( $sw == 1 && $line =~ /End/ )
				{
					last;
				}
			}
		}
		untie @fileconf;
	}

	if ( $type eq "gslb" )
	{
		my @fileconf;
		my $line;
		my $param;
		my @linesplt;
		use Tie::File;
		if ( $tag eq "ns" )
		{
			tie @fileconf, 'Tie::File', "$configdir/$ffile/etc/zones/$svice";
			foreach $line ( @fileconf )
			{
				if ( $line =~ /^@\tSOA .* hostmaster / )
				{
					@linesplt = split ( " ", $line );
					$param    = @linesplt[2];
					$line     = "@\tSOA $stri hostmaster (";
				}
				if ( $line =~ /\t$param / )
				{
					$line =~ s/\t$param /\t$stri /g;
				}
				if ( $line =~ /^$param\t/ )
				{
					$line =~ s/^$param\t/$stri\t/g;
				}
			}
			untie @fileconf;
			&setFarmZoneSerial( $fname, $svice );
		}
		if ( $tag eq "dpc" )
		{
			my $found = 0;

			#Find the plugin file
			opendir ( DIR, "$configdir\/$ffile\/etc\/plugins\/" );
			my @pluginlist = readdir ( DIR );
			foreach $plugin ( @pluginlist )
			{
				tie @fileconf, 'Tie::File', "$configdir\/$ffile\/etc\/plugins\/$plugin";
				if ( grep ( /^\t$svice => /, @fileconf ) )
				{
					$pluginfile = $plugin;
				}
				untie @fileconf;
			}
			closedir ( DIR );

			tie @fileconf, 'Tie::File', "$configdir/$ffile/etc/plugins/$pluginfile";
			foreach $line ( @fileconf )
			{
				if ( $found == 1 && $line =~ /.*}.*/ )
				{
					last;
				}
				if ( $found == 1 && $line =~ /.*service_types.*/ )
				{
					$line   = "\t\tservice_types = tcp_$stri";
					$output = "0";
					last;
				}
				if ( $line =~ /\t$svice => / )
				{
					$found = 1;
				}
			}
			untie @fileconf;
			if ( $output eq "0" )
			{

				# Check if there is already an entry
				my $found = 0;
				my $index = 1;
				tie @fileconf, 'Tie::File', "$configdir/$ffile/etc/config";
				while ( @fileconf[$index] !~ /plugins => / )
				{
					my $line = @fileconf[$index];
					if ( $found == 2 && $line =~ /.*}.*/ )
					{
						splice @fileconf, $index, 1;
						last;
					}
					if ( $found == 2 )
					{
						splice @fileconf, $index, 1;
						next;
					}
					if ( $found == 1 && $line =~ /tcp_$stri => / )
					{
						splice @fileconf, $index, 1;
						$found = 2;
						next;
					}
					if ( $line =~ /service_types => / )
					{
						$found = 1;
					}
					$index++;
				}
				untie @fileconf;

				# New service_types entry
				my $index = 0;
				tie @fileconf, 'Tie::File', "$configdir/$ffile/etc/config";
				foreach $line ( @fileconf )
				{
					if ( $line =~ /service_types => / )
					{
						$index++;
						splice @fileconf, $index, 0, "\ttcp_$stri => {\n\t\tplugin = tcp_connect,\n\t\tport = $stri,\n\t\tup_thresh = 2,\n\t\tok_thresh = 2,\n\t\tdown_thresh = 2,\n\t\tinterval = 5,\n\t\ttimeout = 3,\n\t}\n";
						last;
					}
					$index++;
				}
				untie @fileconf;
			}
		}
	}

	return @output;
}

sub setFarmZoneSerial($fname,$zone)
{
	my ( $fname, $zone ) = @_;
	my $ftype  = &getFarmType( $fname );
	my $ffile  = &getFarmFile( $fname );
	my $output = -1;
	if ( $ftype eq "gslb" )
	{
		my @fileconf;
		use Tie::File;
		tie @fileconf, 'Tie::File', "$configdir/$ffile/etc/zones/$zone";
		foreach $line ( @fileconf )
		{
			if ( $line =~ /@\tSOA / )
			{
				my $date = `date +%s`;
				splice @fileconf, $index + 1, 1, "\t$date";
			}
			$index++;
		}
		untie @fileconf;
		$output = $?;
	}
	return $output;
}

sub setFarmZoneResource($id,$resource,$ttl,$type,$rdata,$fname,$service)
{
	my ( $id, $resource, $ttl, $type, $rdata, $fname, $service ) = @_;

	my $output = 0;
	my $ftype  = &getFarmType( $fname );
	my $ffile  = &getFarmFile( $fname );

	if ( $ftype eq "gslb" )
	{
		my @fileconf;
		my $line;
		my $param;
		my @linesplt;
		my $index = 0;
		my $lb    = "";
		if ( $type =~ /DYN./ )
		{
			$lb = &getFarmVS( $fname, $rdata, "plugin" );
			$lb = "$lb!";
		}
		use Tie::File;
		tie @fileconf, 'Tie::File', "$configdir/$ffile/etc/zones/$service";
		foreach $line ( @fileconf )
		{
			if ( $line =~ /\;index_/ )
			{
				@linesplt = split ( "\;index_", $line );
				$param = @linesplt[1];
				if ( $id !~ /^$/ && $id eq $param )
				{
					$line = "$resource\t$ttl\t$type\t$lb$rdata ;index_$param";
				}
				else
				{
					$index = $param + 1;
				}
			}
		}
		if ( $id =~ /^$/ )
		{
			push @fileconf, "$resource\t$ttl\t$type\t$lb$rdata ;index_$index";
		}
		untie @fileconf;
		&setFarmZoneSerial( $fname, $service );
		$output = $?;
	}

	return $output;
}

sub remFarmZoneResource($id,$fname,$service)
{
	my ( $id, $fname, $service ) = @_;

	my $output = 0;
	my $ftype  = &getFarmType( $fname );
	my $ffile  = &getFarmFile( $fname );

	if ( $ftype eq "gslb" )
	{
		my @fileconf;
		my $line;
		my $index = 0;
		use Tie::File;
		tie @fileconf, 'Tie::File', "$configdir/$ffile/etc/zones/$service";
		foreach $line ( @fileconf )
		{
			if ( $line =~ /\;index_$id/ )
			{
				splice @fileconf, $index, 1;
			}
			$index++;
		}
		untie @fileconf;
		$output = $?;
		&setFarmZoneSerial( $fname, $service );
		$output = $output + $?;
	}
	return $output;
}

sub remFarmServiceBackend($id,$fname,$service)
{
	my ( $id, $fname, $srv ) = @_;

	my $output = 0;
	my $ftype  = &getFarmType( $fname );
	my $ffile  = &getFarmFile( $fname );

	if ( $ftype eq "gslb" )
	{
		my @fileconf;
		my $line;
		my $index      = 0;
		my $pluginfile = "";
		use Tie::File;

		#Find the plugin file
		opendir ( DIR, "$configdir\/$ffile\/etc\/plugins\/" );
		my @pluginlist = readdir ( DIR );
		foreach $plugin ( @pluginlist )
		{
			tie @fileconf, 'Tie::File', "$configdir\/$ffile\/etc\/plugins\/$plugin";
			if ( grep ( /^\t$srv => /, @fileconf ) )
			{
				$pluginfile = $plugin;
			}
			untie @fileconf;
		}
		closedir ( DIR );

		tie @fileconf, 'Tie::File', "$configdir/$ffile/etc/plugins/$pluginfile";
		foreach $line ( @fileconf )
		{
			if ( $line =~ /^\t$srv => / )
			{
				$found = 1;
				$index++;
				next;
			}
			if ( $found == 1 && $line =~ /primary => / )
			{
				$output = -2;
				last;
			}
			if ( $found == 1 && $line =~ /$id => / )
			{
				my @backendslist = grep ( /^\s+[1-9].* =>/, @fileconf );
				my $nbackends = @backendslist;
				if ( $nbackends == 1 )
				{
					$output = -2;
				}
				else
				{
					splice @fileconf, $index, 1;
				}
				last;
			}
			$index++;
		}
		untie @fileconf;
		$output = $output + $?;
	}

	return $output;
}

sub setFarmGSLBNewBackend($fname,$srv,$lb,$id,$ipaddress)
{
	my ( $fname, $srv, $lb, $id, $ipaddress ) = @_;

	my $output = 0;
	my $ftype  = &getFarmType( $fname );
	my $ffile  = &getFarmFile( $fname );

	if ( $ftype eq "gslb" )
	{
		my @fileconf;
		my $line;
		my @linesplt;
		my $found      = 0;
		my $index      = 0;
		my $idx        = 0;
		my $pluginfile = "";
		use Tie::File;

		#Find the plugin file
		tie @fileconf, 'Tie::File', "$configdir/$ffile/etc/plugins/$srv.cfg";
		foreach $line ( @fileconf )
		{
			if ( $line =~ /^\t$srv => / )
			{
				$found = 1;
				$index++;
				next;
			}
			if ( $found == 1 && $lb eq "prio" && $line =~ /\}/ && $id eq "primary" )
			{
				splice @fileconf, $index, 0, "		$id => $ipaddress";
				last;
			}
			if ( $found == 1 && $lb eq "prio" && $line =~ /primary => / && $id eq "primary" )
			{
				splice @fileconf, $index, 1, "		$id => $ipaddress";
				last;
			}
			if ( $found == 1 && $lb eq "prio" && $line =~ /\}/ && $id eq "secondary" )
			{
				splice @fileconf, $index, 0, "		$id => $ipaddress";
				last;
			}
			if ( $found == 1 && $lb eq "prio" && $line =~ /secondary => / && $id eq "secondary" )
			{
				splice @fileconf, $index, 1, "		$id => $ipaddress";
				last;
			}
			if ( $found == 1 && $lb eq "roundrobin" && $line =~ /\t\t$id => / )
			{
				splice @fileconf, $index, 1, "		$id => $ipaddress";
				last;
			}
			if ( $found == 1 && $lb eq "roundrobin" && $line =~ / => / )
			{

				# What is the latest id used?
				my @temp = split ( " => ", $line );
				$idx = @temp[0];
				$idx =~ s/^\s+//;
			}
			if ( $found == 1 && $lb eq "roundrobin" && $line =~ /\}/ )
			{
				$idx++;
				splice @fileconf, $index, 0, "		$idx => $ipaddress";
				last;
			}
			$index++;
		}
		untie @fileconf;
		$output = $?;
	}

	return $output;
}

sub runFarmReload($farmname)
{
	my ( $fname ) = @_;

	my $type = &getFarmType( $fname );
	my $output;

	if ( $type eq "gslb" )
	{
		&logfile( "running $gdnsd -c $configdir\/$fname\_$type.cfg/etc reload-zones" );
		zsystem( "$gdnsd -c $configdir\/$fname\_$type.cfg/etc reload-zones 2>/dev/null" );
		$output = $?;
		if ( $output != 0 )
		{
			$output = -1;
		}
	}

	return $output;
}

#get index of a service in a http farm
sub getFarmVSI($farmname,$sv)
{

	my ( $fname, $svice ) = @_;
	my $output;
	my @line;
	my $index;
	my $l;
	my @content = &getFarmBackendStatusCtl( $fname );
	foreach ( @content )
	{

		if ( $_ =~ /Service \"$svice\"/ )
		{
			$l     = $_;
			@line  = split ( '\.', $l );
			$index = @line[0];
		}
	}
	$index =~ s/\"//g;
	$index =~ s/^\s+//;
	$index =~ s/\s+$//;
	$output = $index;
	return $output;

}

#function that removes all the active sessions enabled to a backend in a given service
#needed: farmname, serviceid, backendid
sub setFarmBackendsSessionsRemove($fname,$svice,$backendid)
{
	( $fname, $svice, $backendid ) = @_;
	my @content = &getFarmBackendStatusCtl( $fname );
	my @sessions = &getFarmBackendsClientsList( $fname, @content );
	my @service;
	my $sw = 0;
	my $sviceid;
	my @sessionid;
	my $sessid;

	&logfile( "Deleting established sessions to a backend $backendid from farm $fname in service $svice" );
	foreach ( @content )
	{
		if ( $_ =~ /Service/ && $sw eq 1 )
		{
			$sw = 0;
		}

		if ( $_ =~ /Service\ \"$svice\"/ && $sw eq 0 )
		{
			$sw      = 1;
			@service = split ( /\./, $_ );
			$sviceid = @service[0];
		}
		if ( $_ =~ /Session.*->\ $backendid/ && $sw eq 1 )
		{
			@sessionid  = split ( /Session/, $_ );
			$sessionid2 = @sessionid[1];
			@sessionid  = split ( /\ /, $sessionid2 );
			$sessid     = @sessionid[1];
			@output     = `$poundctl -c  /tmp/$fname\_pound.socket -n 0 $sviceid $sessid`;
			&logfile( "Executing:  $poundctl -c /tmp/$fname\_pound.socket -n 0 $sviceid $sessid" );

		}
	}

}

sub setFarmName($farmname)
{

	$farmname =~ s/[^a-zA-Z0-9]//g;

}

sub getConntrack($orig_src, $orig_dst, $reply_src, $reply_dst, $proto)
{
	( $orig_src, $orig_dst, $reply_src, $reply_dst, $proto ) = @_;
	my @output = ();
	chomp ( $orig_src );
	chomp ( $orig_dst );
	chomp ( $reply_src );
	chomp ( $reply_dst );
	chomp ( $proto );
	if ( $orig_src )
	{
		$orig_src = "-s $orig_src";
	}
	if ( $orig_dst )
	{
		$orig_dst = "-d $orig_dst";
	}
	if ( $reply_src )
	{
		$reply_src = "-r $reply_src";
	}
	if ( $reply_dst )
	{
		$reply_dst = "-q $reply_dst";
	}
	if ( $proto )
	{
		$proto = "-p $proto";
	}
	&logfile( "$conntrack -L $orig_src $orig_dst $reply_src $reply_dst $proto 2>/dev/null" );
	@output = `$conntrack -L $orig_src $orig_dst $reply_src $reply_dst $proto 2>/dev/null`;
	return @output;
}

# do not remove this
1
