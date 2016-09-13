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

# Only used in http content
sub setFarmClientTimeout    # ($client,$farm_name)
{
	my ( $client, $farm_name ) = @_;

	my $farm_type     = &getFarmType( $farm_name );
	my $farm_filename = &getFarmFile( $farm_name );
	my $output        = -1;

	if ( $farm_type eq "http" || $farm_type eq "https" )
	{
		tie @filefarmhttp, 'Tie::File', "$configdir/$farm_filename";

		my $i_f         = -1;
		my $array_count = @filefarmhttp;
		my $found       = "false";

		while ( $i_f <= $array_count && $found eq "false" )
		{
			$i_f++;

			if ( $filefarmhttp[$i_f] =~ /^Client/ )
			{
				&logfile( "setting 'ClientTimeout $client' for $farm_name farm $farm_type" );
				$filefarmhttp[$i_f] = "Client\t\t $client";
				$output             = $?;
				$found              = "true";
			}
		}
		untie @filefarmhttp;
	}

	return $output;
}

# Only used in http content
sub getFarmClientTimeout    # ($farm_name)
{
	my ( $farm_name ) = @_;

	my $farm_type     = &getFarmType( $farm_name );
	my $farm_filename = &getFarmFile( $farm_name );
	my $output        = -1;

	if ( $farm_type eq "http" || $farm_type eq "https" )
	{
		open FR, "<$configdir\/$farm_filename";
		my @file = <FR>;

		foreach $line ( @file )
		{
			if ( $line =~ /Client/i )
			{
				@line = split ( "\ ", $line );
				$output = $line[1];
			}
		}
		close FR;
	}

	return $output;
}

#
sub setHTTPFarmSessionType    # ($session,$farm_name)
{
	my ( $session, $farm_name ) = @_;

	my $farm_filename = &getFarmFile( $farm_name );
	my $farm_type     = &getFarmType( $farm_name );
	my $output        = -1;

	&logfile( "setting 'Session type $session' for $farm_name farm $farm_type" );
	tie @contents, 'Tie::File', "$configdir\/$farm_filename";
	my $i     = -1;
	my $found = "false";
	foreach $line ( @contents )
	{
		$i++;
		if ( $session ne "nothing" )
		{
			if ( $line =~ "Session" )
			{
				$contents[$i] = "\t\tSession";
				$found = "true";
			}
			if ( $found eq "true" && $line =~ "End" )
			{
				$contents[$i] = "\t\tEnd";
				$found = "false";
			}
			if ( $line =~ "Type" )
			{
				$contents[$i] = "\t\t\tType $session";
				$output = $?;
				$contents[$i + 1] =~ s/#//g;
				if (    $session eq "URL"
					 || $session eq "COOKIE"
					 || $session eq "HEADER" )
				{
					$contents[$i + 2] =~ s/#//g;
				}
				else
				{
					if ( $contents[$i + 2] !~ /#/ )
					{
						$contents[$i + 2] =~ s/^/#/;
					}
				}
			}
		}
		if ( $session eq "nothing" )
		{
			if ( $line =~ "Session" )
			{
				$contents[$i] = "\t\t#Session $session";
				$found = "true";
			}
			if ( $found eq "true" && $line =~ "End" )
			{
				$contents[$i] = "\t\t#End";
				$found = "false";
			}
			if ( $line =~ "TTL" )
			{
				$contents[$i] = "#$contents[$i]";
			}
			if ( $line =~ "Type" )
			{
				$contents[$i] = "#$contents[$i]";
				$output = $?;
			}
			if ( $line =~ "ID" )
			{
				$contents[$i] = "#$contents[$i]";
			}
		}
	}
	untie @contents;
	return $output;
}

#
sub getHTTPFarmSessionType    # ($farm_name)
{
	my ( $farm_name ) = @_;
	my $output = -1;

	open FR, "<$configdir\/$farm_name";
	my @file = <FR>;
	foreach $line ( @file )
	{
		if ( $line =~ /Type/ && $line !~ /#/ )
		{
			@line = split ( "\ ", $line );
			$output = $line[1];
		}
	}
	close FR;

	return $output;
}

# setFarmSessionId not used ?
#sub setFarmSessionId($sessionid,$farm_name,$service)
#{
#my ( $sessionid, $farm_name, $service ) = @_;

#my $farm_type   = &getFarmType( $farm_name );
#my $farm_filename  = &getFarmFile( $farm_name );
#my $output = -1;

#if ( $farm_type eq "http" || $farm_type eq "https" )
#{
#tie @filefarmhttp, 'Tie::File', "$configdir/$farm_filename";
#my $i_f         = -1;
#my $array_count = @filefarmhttp;
#my $found       = "false";
#while ( $i_f <= $array_count && $found eq "false" )
#{
#$i_f++;
#if ( $filefarmhttp[$i_f] =~ /ID/ )
#{
#&logfile( "setting 'Session id $sessionid' for $farm_name farm $farm_type" );
#$filefarmhttp[$i_f] = "\t\t\tID \"$sessionid\"";
#$output             = $?;
#$found              = "true";
#}
#}

#untie @filefarmhttp;
#}

#return $output;
#}

# getFarmSessionId not used ?
#sub getFarmSessionId($farm_name,$service)
#{
#my ( $farm_name, $service ) = @_;

#my $farm_type   = &getFarmType( $farm_name );
#my $farm_filename  = &getFarmFile( $farm_name );
#my $output = -1;

#if ( $farm_type eq "http" || $farm_type eq "https" )
#{
#open FR, "<$configdir\/$farm_filename";
#my @file = <FR>;
#foreach $line ( @file )
#{
#if ( $line =~ /ID/ )
#{
#@line = split ( "\ ", $line );
#$output = $line[1];
#$output =~ s/\"//g;
#}
#}
#close FR;
#}

##&logfile("getting 'Session id $output' for $farm_name farm $farm_type");
#return $output;
#}

#
sub setHTTPFarmBlacklistTime    # ($blacklist_time,$farm_name)
{
	my ( $blacklist_time, $farm_name ) = @_;

	my $farm_type     = &getFarmType( $farm_name );
	my $farm_filename = &getFarmFile( $farm_name );
	my $output        = -1;

	tie @filefarmhttp, 'Tie::File', "$configdir/$farm_filename";
	my $i_f         = -1;
	my $array_count = @filefarmhttp;
	my $found       = "false";

	while ( $i_f <= $array_count && $found eq "false" )
	{
		$i_f++;
		if ( $filefarmhttp[$i_f] =~ /^Alive/ )
		{
			&logfile(
					"setting 'Blacklist time $blacklist_time' for $farm_name farm $farm_type" );
			$filefarmhttp[$i_f] = "Alive\t\t $blacklist_time";
			$output             = $?;
			$found              = "true";
		}
	}
	untie @filefarmhttp;

	return $output;
}

#
sub getHTTPFarmBlacklistTime    # ($farm_filename)
{
	my ( $farm_filename ) = @_;
	my $blacklist_time = -1;

	open FR, "<$configdir\/$farm_filename";
	my @file = <FR>;
	foreach $line ( @file )
	{
		if ( $line =~ /Alive/i )
		{
			@line = split ( "\ ", $line );
			$blacklist_time = $line[1];
		}
	}
	close FR;

	return $blacklist_time;
}

#
sub setFarmHttpVerb    # ($verb,$farm_name)
{
	my ( $verb, $farm_name ) = @_;

	my $farm_type     = &getFarmType( $farm_name );
	my $farm_filename = &getFarmFile( $farm_name );
	my $output        = -1;

	if ( $farm_type eq "http" || $farm_type eq "https" )
	{
		tie @filefarmhttp, 'Tie::File', "$configdir/$farm_filename";
		my $i_f         = -1;
		my $array_count = @filefarmhttp;
		my $found       = "false";
		while ( $i_f <= $array_count && $found eq "false" )
		{
			$i_f++;
			if ( $filefarmhttp[$i_f] =~ /xHTTP/ )
			{
				&logfile( "setting 'Http verb $verb' for $farm_name farm $farm_type" );
				$filefarmhttp[$i_f] = "\txHTTP $verb";
				$output             = $?;
				$found              = "true";
			}
		}
		untie @filefarmhttp;
	}

	return $output;
}

#
sub getFarmHttpVerb    # ($farm_name)
{
	my ( $farm_name ) = @_;

	my $farm_type     = &getFarmType( $farm_name );
	my $farm_filename = &getFarmFile( $farm_name );
	my $output        = -1;

	if ( $farm_type eq "http" || $farm_type eq "https" )
	{
		open FR, "<$configdir\/$farm_filename";
		my @file = <FR>;
		foreach $line ( @file )
		{
			if ( $line =~ /xHTTP/ )
			{
				@line = split ( "\ ", $line );
				$output = $line[1];
			}
		}
		close FR;
	}

	return $output;
}

#change HTTP or HTTP listener
sub setFarmListen    # ( $farm_name, $farmlisten )
{
	my ( $farm_name, $flisten ) = @_;

	my $farm_filename = &getFarmFile( $farm_name );
	tie @filefarmhttp, 'Tie::File', "$configdir/$farm_filename";
	my $i_f         = -1;
	my $array_count = @filefarmhttp;
	my $found       = "false";
	while ( $i_f <= $array_count && $found eq "false" )
	{
		$i_f++;
		if ( $filefarmhttp[$i_f] =~ /^ListenHTTP/ && $flisten eq "http" )
		{
			$filefarmhttp[$i_f] = "ListenHTTP";
		}
		if ( $filefarmhttp[$i_f] =~ /^ListenHTTP/ && $flisten eq "https" )
		{
			$filefarmhttp[$i_f] = "ListenHTTPS";
		}

		#
		if ( $filefarmhttp[$i_f] =~ /.*Cert\ \"/ && $flisten eq "http" )
		{
			$filefarmhttp[$i_f] =~ s/Cert\ \"/#Cert\ \"/;
		}
		if ( $filefarmhttp[$i_f] =~ /.*Cert\ \"/ && $flisten eq "https" )
		{
			$filefarmhttp[$i_f] =~ s/#//g;

		}

		#
		if ( $filefarmhttp[$i_f] =~ /.*Ciphers\ \"/ && $flisten eq "http" )
		{
			$filefarmhttp[$i_f] =~ s/Ciphers\ \"/#Ciphers\ \"/;
		}
		if ( $filefarmhttp[$i_f] =~ /.*Ciphers\ \"/ && $flisten eq "https" )
		{
			$filefarmhttp[$i_f] =~ s/#//g;

		}

		# Enable 'Disable SSLv3'
		if ( $filefarmhttp[$i_f] =~ /.*Disable SSLv3$/ && $flisten eq "http" )
		{
			$filefarmhttp[$i_f] =~ s/Disable SSLv3/#Disable SSLv3/;
		}
		elsif ( $filefarmhttp[$i_f] =~ /.*DisableSSLv3$/ && $flisten eq "http" )
		{
			$filefarmhttp[$i_f] =~ s/DisableSSLv3/#DisableSSLv3/;
		}
		if ( $filefarmhttp[$i_f] =~ /.*Disable SSLv3$/ && $flisten eq "https" )
		{
			$filefarmhttp[$i_f] =~ s/#//g;
		}
		elsif (    $filefarmhttp[$i_f] =~ /.*DisableSSLv3$/
				&& $flisten eq "https" )
		{
			$filefarmhttp[$i_f] =~ s/#//g;
		}

		# Enable SSLHonorCipherOrder
		if (    $filefarmhttp[$i_f] =~ /.*SSLHonorCipherOrder/
			 && $flisten eq "http" )
		{
			$filefarmhttp[$i_f] =~ s/SSLHonorCipherOrder/#SSLHonorCipherOrder/;
		}
		if (    $filefarmhttp[$i_f] =~ /.*SSLHonorCipherOrder/
			 && $flisten eq "https" )
		{
			$filefarmhttp[$i_f] =~ s/#//g;
		}

		# Enable StrictTransportSecurity
		if (    $filefarmhttp[$i_f] =~ /.*StrictTransportSecurity/
			 && $flisten eq "http" )
		{
			$filefarmhttp[$i_f] =~ s/StrictTransportSecurity/#StrictTransportSecurity/;
		}
		if (    $filefarmhttp[$i_f] =~ /.*StrictTransportSecurity/
			 && $flisten eq "https" )
		{
			$filefarmhttp[$i_f] =~ s/#//g;
		}

		if ( $filefarmhttp[$i_f] =~ /ZWACL-END/ )
		{
			$found = "true";
		}

	}
	untie @filefarmhttp;
}

#asign a RewriteLocation vaue to a farm HTTP or HTTPS
sub setFarmRewriteL    # ($farm_name,$rewritelocation)
{
	my ( $farm_name, $rewritelocation ) = @_;

	my $farm_type     = &getFarmType( $farm_name );
	my $farm_filename = &getFarmFile( $farm_name );
	my $output        = -1;
	&logfile( "setting 'Rewrite Location' for $farm_name to $rewritelocation" );

	if ( $farm_type eq "http" || $farm_type eq "https" )
	{
		tie @filefarmhttp, 'Tie::File', "$configdir/$farm_filename";
		my $i_f         = -1;
		my $array_count = @filefarmhttp;
		my $found       = "false";
		while ( $i_f <= $array_count && $found eq "false" )
		{
			$i_f++;
			if ( $filefarmhttp[$i_f] =~ /RewriteLocation\ .*/ )
			{
				$filefarmhttp[$i_f] = "\tRewriteLocation $rewritelocation";
				$output             = $?;
				$found              = "true";
			}
		}
		untie @filefarmhttp;
	}

}

#Get RewriteLocation Header configuration HTTP and HTTPS farms
sub getFarmRewriteL    # ($farm_name)
{
	my ( $farm_name ) = @_;

	my $farm_type     = &getFarmType( $farm_name );
	my $farm_filename = &getFarmFile( $farm_name );
	my $output        = -1;

	if ( $farm_type eq "http" || $farm_type eq "https" )
	{
		open FR, "<$configdir\/$farm_filename";
		my @file = <FR>;
		foreach $line ( @file )
		{
			if ( $line =~ /RewriteLocation\ .*/ )
			{
				@line = split ( "\ ", $line );
				$output = $line[1];
			}
		}
		close FR;
	}

	return $output;
}

#set ConnTo value to a farm HTTP or HTTPS
sub setFarmConnTO    # ($tout,$farm_name)
{
	my ( $tout, $farm_name ) = @_;

	my $farm_type     = &getFarmType( $farm_name );
	my $farm_filename = &getFarmFile( $farm_name );
	my $output        = -1;

	&logfile( "setting 'ConnTo timeout $tout' for $farm_name farm $farm_type" );

	if ( $farm_type eq "http" || $farm_type eq "https" )
	{
		tie @filefarmhttp, 'Tie::File', "$configdir/$farm_filename";
		my $i_f         = -1;
		my $array_count = @filefarmhttp;
		my $found       = "false";
		while ( $i_f <= $array_count && $found eq "false" )
		{
			$i_f++;
			if ( $filefarmhttp[$i_f] =~ /^ConnTO.*/ )
			{
				$filefarmhttp[$i_f] = "ConnTO\t\t $tout";
				$output             = $?;
				$found              = "true";
			}
		}
		untie @filefarmhttp;
	}
	return $output;
}

#get farm ConnTO value for http and https farms
sub getFarmConnTO    # ($farm_name)
{
	my ( $farm_name ) = @_;

	my $farm_type     = &getFarmType( $farm_name );
	my $farm_filename = &getFarmFile( $farm_name );
	my $output        = -1;

	if ( $farm_type eq "http" || $farm_type eq "https" )
	{
		open FR, "<$configdir\/$farm_filename";
		my @file = <FR>;
		foreach $line ( @file )
		{
			if ( $line =~ /^ConnTO/ )
			{
				@line = split ( "\ ", $line );
				$output = $line[1];
			}
		}
		close FR;
	}

	return $output;
}

#asign a timeout value to a farm
sub setHTTPFarmTimeout    # ($timeout,$farm_name)
{
	my ( $timeout, $farm_name ) = @_;

	my $farm_filename = &getFarmFile( $farm_name );
	my $output        = -1;

	tie @filefarmhttp, 'Tie::File', "$configdir/$farm_filename";
	my $i_f         = -1;
	my $array_count = @filefarmhttp;
	my $found       = "false";

	while ( $i_f <= $array_count && $found eq "false" )
	{
		$i_f++;
		if ( $filefarmhttp[$i_f] =~ /^Timeout/ )
		{
			$filefarmhttp[$i_f] = "Timeout\t\t $timeout";
			$output             = $?;
			$found              = "true";
		}
	}
	untie @filefarmhttp;

	return $output;
}

#
sub getHTTPFarmTimeout    # ($farm_filename)
{
	my ( $farm_name ) = @_;

	my $farm_filename = &getFarmFile( $farm_name );
	my $output        = -1;

	open FR, "<$configdir\/$farm_filename";
	my @file = <FR>;

	foreach my $line ( @file )
	{
		if ( $line =~ /^Timeout/ )
		{
			@line = split ( "\ ", $line );
			$output = $line[1];
		}
	}
	close FR;

	return $output;
}

# set the max clients of a farm
sub setHTTPFarmMaxClientTime    # ($track,$farm_name)
{
	my ( $track, $farm_name ) = @_;

	my $farm_filename = &getFarmFile( $farm_name );
	my $output        = -1;
	my $i_f           = -1;
	my $found         = "false";

	tie @filefarmhttp, 'Tie::File', "$configdir/$farm_filename";
	my $array_count = @filefarmhttp;

	while ( $i_f <= $array_count && $found eq "false" )
	{
		$i_f++;
		if ( $filefarmhttp[$i_f] =~ /TTL/ )
		{
			$filefarmhttp[$i_f] = "\t\t\tTTL $track";
			$output             = $?;
			$found              = "true";
		}
	}
	untie @filefarmhttp;

	return $output;
}

#
sub getHTTPFarmMaxClientTime    # ($farm_name)
{
	my ( $farm_name ) = @_;

	my $farm_filename = &getFarmFile( $farm_name );
	my @max_client_time;

	push ( @max_client_time, "" );
	push ( @max_client_time, "" );
	open FR, "<$configdir\/$farm_filename";
	my @configfile = <FR>;

	foreach my $line ( @configfile )
	{
		if ( $line =~ /TTL/ )
		{
			@line = split ( "\ ", $line );
			@max_client_time[0] = "";
			@max_client_time[1] = $line[1];
		}
	}
	close FR;

	return @max_client_time;
}

# set the max conn of a farm
sub setHTTPFarmMaxConn    # ($max_connections,$farm_name)
{
	my ( $max_connections, $farm_name ) = @_;

	my $farm_filename = &getFarmFile( $farm_name );
	my $output        = -1;

	use Tie::File;
	tie my @array, 'Tie::File', "$configdir/$farm_filename";

	for ( @array )
	{
		if ( $_ =~ "Threads" )
		{
			#s/^Threads.*/Threads   $maxc/g;
			$_      = "Threads\t\t$max_connections";
			$output = $?;
		}
	}
	untie @array;

	return $output;
}

#
sub getFarmCertificate    # ($farm_name)
{
	my ( $farm_name ) = @_;

	my $farm_type = &getFarmType( $farm_name );
	my $output    = -1;

	if ( $farm_type eq "https" )
	{
		my $farm_filename = &getFarmFile( $farm_name );
		open FI, "<$configdir/$farm_filename";
		my @content = <FI>;
		close FI;
		foreach my $line ( @content )
		{
			if ( $line =~ /Cert/ && $line !~ /\#.*Cert/ )
			{
				my @partline = split ( '\"', $line );
				@partline = split ( "\/", $partline[1] );
				my $lfile = @partline;
				$output = $partline[$lfile - 1];
			}
		}
	}

	return $output;
}

#
sub setFarmCertificate    # ($cfile,$farm_name)
{
	my ( $cfile, $farm_name ) = @_;

	my $farm_type     = &getFarmType( $farm_name );
	my $farm_filename = &getFarmFile( $farm_name );
	my $output        = -1;

	&logfile( "setting 'Certificate $cfile' for $farm_name farm $farm_type" );
	if ( $farm_type eq "https" )
	{
		use Tie::File;
		tie @array, 'Tie::File', "$configdir/$farm_filename";
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

sub getHTTPFarmGlobalStatus    # ($farm_name)
{
	my ( $farm_name ) = @_;

	return `$poundctl -c "/tmp/$farm_name\_pound.socket"`;
}

#
sub getHTTPBackendEstConns     # ($farm_name,$ip_backend,$port_backend,@netstat)
{
	my ( $farm_name, $ip_backend, $port_backend, @netstat ) = @_;

	return
	  &getNetstatFilter(
		"tcp",
		"",
		"\.*ESTABLISHED src=\.* dst=$ip_backend sport=\.* dport=$port_backend \.*src=$ip_backend \.*",
		"",
		@netstat
	  );
}

#
sub getHTTPFarmEstConns    # ($farm_name,@netstat)
{
	my ( $farm_name, @netstat ) = @_;

	my $vip      = &getFarmVip( "vip",  $farm_name );
	my $vip_port = &getFarmVip( "vipp", $farm_name );

	return
	  &getNetstatFilter( "tcp", "",
			  "\.* ESTABLISHED src=\.* dst=$vip sport=\.* dport=$vip_port .*src=\.*",
			  "", @netstat );
}

#
sub getHTTPBackendTWConns    # ($farm_name,$ip_backend,$port_backend,@netstat)
{
	my ( $farm_name, $ip_backend, $port_backend, @netstat ) = @_;

	my $vip = &getFarmVip( "vip", $farm_name );

	return
	  &getNetstatFilter( "tcp", "",
		  "\.*TIME\_WAIT src=$vip dst=$ip_backend sport=\.* dport=$port_backend \.*",
		  "", @netstat );
}

#
sub getHTTPBackendSYNConns  # ($farm_name, $ip_backend, $port_backend, @netstat)
{
	my ( $farm_name, $ip_backend, $port_backend, @netstat ) = @_;

	return
	  &getNetstatFilter( "tcp", "",
				"\.*SYN\.* src=\.* dst=$ip_backend sport=\.* dport=$port_backend\.*",
				"", @netstat );
}

#
sub getHTTPFarmSYNConns     # ($farm_name, @netstat)
{
	my ( $farm_name, @netstat ) = @_;

	my $vip      = &getFarmVip( "vip",  $farm_name );
	my $vip_port = &getFarmVip( "vipp", $farm_name );

	return
	  &getNetstatFilter( "tcp", "",
					   "\.* SYN\.* src=\.* dst=$vip \.* dport=$vip_port \.* src=\.*",
					   "", @netstat );
}

# Only http function
sub setFarmErr    # ($farm_name,$content,$nerr)
{
	my ( $farm_name, $content, $nerr ) = @_;

	my $farm_type = &getFarmType( $farm_name );
	my $output    = -1;

	&logfile( "setting 'Err $nerr' for $farm_name farm $farm_type" );
	if ( $farm_type eq "http" || $farm_type eq "https" )
	{
		if ( -e "$configdir\/$farm_name\_Err$nerr.html" && $nerr != "" )
		{
			$output = 0;
			my @err = split ( "\n", "$content" );
			print "<br><br>";
			open FO, ">$configdir\/$farm_name\_Err$nerr.html";
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

# Only http function
sub getFarmErr    # ($farm_name,$nerr)
{
	my ( $farm_name, $nerr ) = @_;

	my $farm_type     = &getFarmType( $farm_name );
	my $farm_filename = &getFarmFile( $farm_name );
	my @output;

	if ( $farm_type eq "http" || $farm_type eq "https" )
	{
		open FR, "<$configdir\/$farm_filename";
		my @file = <FR>;
		foreach $line ( @file )
		{
			if ( $line =~ /Err$nerr/ )
			{
				@line = split ( "\ ", $line );
				my $err = $line[1];
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

	return @output;
}

# Returns farm status
sub getHTTPFarmBootStatus    # ($farm_name)
{
	my ( $farm_name ) = @_;

	my $farm_filename = &getFarmFile( $farm_name );
	my $output        = "down";

	open FO, "<$configdir/$farm_filename";
	while ( $line = <FO> )
	{
		$lastline = $line;
	}
	close FO;

	if ( $lastline !~ /^#down/ )
	{
		$output = "up";
	}

	return $output;
}

# Start Farm rutine
sub _runHTTPFarmStart    # ($farm_name)
{
	my ( $farm_name ) = @_;

	my $farm_filename = &getFarmFile( $farm_name );
	my $status        = -1;

	&logfile(
		"running $pound -f $configdir\/$farm_filename -p $piddir\/$farm_name\_pound.pid"
	);
	zsystem(
		"$pound -f $configdir\/$farm_filename -p $piddir\/$farm_name\_pound.pid 2>/dev/null"
	);
	$status = $?;

	if ( $status == 0 )
	{
		&setFarmHttpBackendStatus( $farm_name );
	}

	return $status;
}

# Stop Farm rutine
sub _runHTTPFarmStop    # ($farm_name)
{
	my ( $farm_name ) = @_;

	&runFarmGuardianStop( $farm_name, "" );

	if ( &getFarmConfigIsOK( $farm_name ) == 0 )
	{
		$pid = &getFarmPid( $farm_name );

		&logfile( "running 'kill 15, $pid'" );
		$run = kill 15, $pid;
		$status = $?;

		unlink ( "$piddir\/$farm_name\_pound.pid" );
		unlink ( "\/tmp\/$farm_name\_pound.socket" );
		unlink ( "/tmp/$farm_name.lock" );
	}
	else
	{
		&errormsg(
			 "Farm $farm_name can't be stopped, check the logs and modify the configuration"
		);
		return 1;
	}

	return $status;
}

#
sub runHTTPFarmCreate    # ( $vip, $vip_port, $farm_name, $farm_type )
{
	my ( $vip, $vip_port, $farm_name, $farm_type ) = @_;

	my $output = -1;

	#copy template modyfing values
	use File::Copy;
	&logfile( "copying pound tpl file on $farm_name\_pound.cfg" );
	copy( "$poundtpl", "$configdir/$farm_name\_pound.cfg" );

	#modify strings with variables
	use Tie::File;
	tie @file, 'Tie::File', "$configdir/$farm_name\_pound.cfg";
	foreach my $line ( @file )
	{
		$line =~ s/\[IP\]/$vip/;
		$line =~ s/\[PORT\]/$vip_port/;
		$line =~ s/\[DESC\]/$farm_name/;
		$line =~ s/\[CONFIGDIR\]/$configdir/;
		if ( $farm_type eq "HTTPS" )
		{
			$line =~ s/ListenHTTP/ListenHTTPS/;
			$line =~ s/#Cert/Cert/;
		}
	}
	untie @file;

	#create files with personalized errors
	open FERR, ">$configdir\/$farm_name\_Err414.html";
	print FERR "Request URI is too long.\n";
	close FERR;
	open FERR, ">$configdir\/$farm_name\_Err500.html";
	print FERR "An internal server error occurred. Please try again later.\n";
	close FERR;
	open FERR, ">$configdir\/$farm_name\_Err501.html";
	print FERR "This method may not be used.\n";
	close FERR;
	open FERR, ">$configdir\/$farm_name\_Err503.html";
	print FERR "The service is not available. Please try again later.\n";
	close FERR;

	#run farm
	&logfile(
		"running $pound -f $configdir\/$farm_name\_pound.cfg -p $piddir\/$farm_name\_pound.pid"
	);
	zsystem(
		"$pound -f $configdir\/$farm_name\_pound.cfg -p $piddir\/$farm_name\_pound.pid 2>/dev/null"
	);
	$output = $?;

	return $output;
}

# Returns farm max connections
sub getHTTPFarmMaxConn    # ($farm_name)
{
	my ( $farm_name ) = @_;

	my $farm_filename = &getFarmFile( $farm_name );
	my $farm_type     = &getFarmType( $farm_name );
	my $output        = -1;

	open FR, "<$configdir\/$farm_filename";
	my @configfile = <FR>;
	foreach my $line ( @configfile )
	{
		if ( $line =~ /^Threads/ )
		{
			@line = split ( "\ ", $line );
			my $maxt = $line[1];

			$maxt =~ s/\ //g;
			chomp ( $maxt );
			$output = $maxt;
		}
	}
	close FR;

	return $output;
}

# Returns farm listen port
sub getHTTPFarmPort    # ($farm_name)
{
	my ( $farm_name ) = @_;

	return "/tmp/" . $farm_name . "_pound.socket";
}

# Returns farm PID
sub getHTTPFarmPid     # ($farm_name)
{
	my ( $farm_name ) = @_;
	my $output = -1;

	my $pidfile = "$piddir\/$farm_name\_pound.pid";
	if ( -e $pidfile )
	{
		open FPID, "<$pidfile";
		my @pid = <FPID>;
		close FPID;

		my $pid_hprof = $pid[0];
		chomp ( $pid_hprof );

		if ( $pid_hprof =~ /^[1-9].*/ )
		{
			$output = "$pid_hprof";
		}
		else
		{
			$output = "-";
		}
	}
	else
	{
		$output = "-";
	}

	return $output;
}

# Returns farm Child PID (ONLY HTTP Farms)
sub getFarmChildPid    # ($farm_name)
{
	my ( $farm_name ) = @_;
	use File::Grep qw( fgrep fmap fdo );

	my $farm_type = &getFarmType( $farm_name );
	my $fpid      = &getFarmPid( $farm_name );
	my $output    = -1;

	if ( $farm_type eq "http" || $farm_type eq "https" )
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
sub getHTTPFarmVip    # ($info,$farm_name)
{
	my ( $info, $farm_name ) = @_;

	my $farm_filename = &getFarmFile( $farm_name );
	my $output        = -1;
	my $i             = 0;

	open FI, "<$configdir/$farm_filename";
	my @file = <FI>;
	close FI;

	foreach my $line ( @file )
	{
		if ( $line =~ /^ListenHTTP/ )
		{
			my $vip  = $file[$i + 5];
			my $vipp = $file[$i + 6];

			chomp ( $vip );
			chomp ( $vipp );

			my @vip  = split ( "\ ", $vip );
			my @vipp = split ( "\ ", $vipp );

			if ( $info eq "vip" )   { $output = $vip[1]; }
			if ( $info eq "vipp" )  { $output = $vipp[1]; }
			if ( $info eq "vipps" ) { $output = "$vip[1]\:$vipp[1]"; }
		}
		$i++;
	}

	return $output;
}

# Set farm virtual IP and virtual PORT
sub setHTTPFarmVirtualConf    # ($vip,$vip_port,$farm_name)
{
	my ( $vip, $vip_port, $farm_name ) = @_;

	my $farm_filename = &getFarmFile( $farm_name );
	my $stat          = 0;
	my $enter         = 2;

	use Tie::File;
	tie @array, 'Tie::File', "$configdir\/$farm_filename";
	my $size = @array;

	for ( my $i = 0 ; $i < $size && $enter > 0 ; $i++ )
	{
		if ( $array[$i] =~ /Address/ )
		{
			$array[$i] =~ s/.*Address\ .*/\tAddress\ $vip/g;
			$stat = $? || $stat;
			$enter--;
		}
		if ( $array[$i] =~ /Port/ )
		{
			$array[$i] =~ s/.*Port\ .*/\tPort\ $vip_port/g;
			$stat = $? || $stat;
			$enter--;
		}
	}
	untie @array;

	return $stat;
}

#
sub setHTTPFarmServer # ($ids,$rip,$port,$priority,$timeout,$farm_name,$service)
{
	my ( $ids, $rip, $port, $priority, $timeout, $farm_name, $service ) = @_;

	my $farm_filename = &getFarmFile( $farm_name );
	my $output        = -1;

	tie my @contents, 'Tie::File', "$configdir\/$farm_filename";

	if ( $ids !~ /^$/ )
	{
		my $index_count = -1;
		my $i           = -1;
		my $sw          = 0;
		foreach my $line ( @contents )
		{
			$i++;

			#search the service to modify
			if ( $line =~ /Service \"$service\"/ )
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
					my $httpsbe = &getFarmVS( $farm_name, $service, "httpsbackend" );
					if ( $httpsbe eq "true" )
					{
						#add item
						$i++;
					}
					$output           = $?;
					$contents[$i + 1] = "\t\t\tAddress $rip";
					$contents[$i + 2] = "\t\t\tPort $port";
					my $p_m = 0;
					if ( $contents[$i + 3] =~ /TimeOut/ )
					{
						$contents[$i + 3] = "\t\t\tTimeOut $timeout";
						&logfile( "Modified current timeout" );
					}
					if ( $contents[$i + 4] =~ /Priority/ )
					{
						$contents[$i + 4] = "\t\t\tPriority $priority";
						&logfile( "Modified current priority" );
						$p_m = 1;
					}
					if ( $contents[$i + 3] =~ /Priority/ )
					{
						$contents[$i + 3] = "\t\t\tPriority $priority";
						$p_m = 1;
					}

					#delete item
					if ( $timeout =~ /^$/ )
					{
						if ( $contents[$i + 3] =~ /TimeOut/ )
						{
							splice @contents, $i + 3, 1,;
						}
					}
					if ( $priority =~ /^$/ )
					{
						if ( $contents[$i + 3] =~ /Priority/ )
						{
							splice @contents, $i + 3, 1,;
						}
						if ( $contents[$i + 4] =~ /Priority/ )
						{
							splice @contents, $i + 4, 1,;
						}
					}

					#new item
					if (
						 $timeout !~ /^$/
						 && (    $contents[$i + 3] =~ /End/
							  || $contents[$i + 3] =~ /Priority/ )
					  )
					{
						splice @contents, $i + 3, 0, "\t\t\tTimeOut $timeout";
					}
					if (
						    $p_m eq 0
						 && $priority !~ /^$/
						 && (    $contents[$i + 3] =~ /End/
							  || $contents[$i + 4] =~ /End/ )
					  )
					{
						if ( $contents[$i + 3] =~ /TimeOut/ )
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
		my $nsflag     = "true";
		my $index      = -1;
		my $backend    = 0;
		my $be_section = -1;

		foreach my $line ( @contents )
		{
			$index++;
			if ( $be_section == 1 && $line =~ /Address/ )
			{
				$backend++;
			}
			if ( $line =~ /Service \"$service\"/ )
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
				my $httpsbe = &getFarmVS( $farm_name, $service, "httpsbackend" );
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
			my $idservice = &getFarmVSI( $farm_name, $service );
			if ( $idservice ne "" )
			{
				&getFarmHttpBackendStatus( $farm_name, $backend, "active", $idservice );
			}
		}
	}
	untie @contents;

	return $output;
}

#
sub runHTTPFarmServerDelete    # ($ids,$farm_name,$service)
{
	my ( $ids, $farm_name, $service ) = @_;

	my $farm_filename = &getFarmFile( $farm_name );
	my $output        = -1;
	my $i             = -1;
	my $j             = -1;
	my $sw            = 0;

	tie my @contents, 'Tie::File', "$configdir\/$farm_filename";

	foreach my $line ( @contents )
	{
		$i++;
		if ( $line =~ /Service \"$service\"/ )
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
				while ( $contents[$i] !~ /End/ )
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
		&runRemovehttpBackend( $farm_name, $ids, $service );
	}

	return $output;
}

#
sub getHTTPFarmBackendStatusCtl    # ($farm_name)
{
	my ( $farm_name ) = @_;

	return `$poundctl -c  /tmp/$farm_name\_pound.socket`;
}

#function that return the status information of a farm:
#ip, port, backendstatus, weight, priority, clients
sub getHTTPFarmBackendsStatus    # ($farm_name,@content)
{
	my ( $farm_name, @content ) = @_;

	my @backends_data;

	if ( !@content )
	{
		@content = &getFarmBackendStatusCtl( $farm_name );
	}

	foreach ( @content )
	{
		my @serviceline;
		if ( $_ =~ /Service/ )
		{
			@serviceline = split ( "\ ", $_ );
			$serviceline[2] =~ s/"//g;
			chomp ( $serviceline[2] );
		}
		if ( $_ =~ /Backend/ )
		{
			#backend ID
			my @backends = split ( "\ ", $_ );
			$backends[0] =~ s/\.//g;
			my $line = $backends[0];

			#backend IP,PORT
			@backends_ip  = split ( ":", $backends[2] );
			$ip_backend   = $backends_ip[0];
			$port_backend = $backends_ip[1];
			$line         = $line . "\t" . $ip_backend . "\t" . $port_backend;

			#status
			$status_backend = $backends[7];
			my $backend_disabled = $backends[3];
			if ( $backend_disabled eq "DISABLED" )
			{
				#Checkstatusfile
				$status_backend =
				  &getHTTPBackendStatusFromFile( $farm_name, $backends[0], $serviceline[2] );
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
			$priority_backend = $backends[4];
			$priority_backend =~ s/\(//g;
			$line = $line . "\t" . "-\t" . $priority_backend;
			my $clients = &getFarmBackendsClients( $backends[0], @content, $farm_name );
			if ( $clients != -1 )
			{
				$line = $line . "\t" . $clients;
			}
			else
			{
				$line = $line . "\t-";
			}
			push ( @backends_data, $line );
		}
	}

	return @backends_data;
}

# function that return if a pound backend is active, down by farmguardian
# or it's in maintenance mode
sub getHTTPBackendStatusFromFile    # ($farm_name,$backend,$service)
{
	my ( $farm_name, $backend, $service ) = @_;

	my $index;
	my $line;
	my $stfile = "$configdir\/$farm_name\_status.cfg";
	my $output = -1;

	if ( -e "$stfile" )
	{
		$index = &getFarmVSI( $farm_name, $service );
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
sub getHTTPFarmBackendsClients    # ($idserver,@content,$farm_name)
{
	my ( $idserver, @content, $farm_name ) = @_;

	if ( !@content )
	{
		@content = &getFarmBackendStatusCtl( $farm_name );
	}
	my $numclients = 0;
	foreach ( @content )
	{
		if ( $_ =~ / Session .* -> $idserver$/ )
		{
			$numclients++;
		}
	}

	return $numclients;
}

#function that return the status information of a farm:
sub getHTTPFarmBackendsClientsList    # ($farm_name,@content)
{
	my ( $farm_name, @content ) = @_;

	my @client_list;
	my $s;

	if ( !@content )
	{
		@content = &getFarmBackendStatusCtl( $farm_name );
	}

	foreach ( @content )
	{
		my $line;
		if ( $_ =~ /Service/ )
		{
			my @service = split ( "\ ", $_ );
			$s = $service[2];
			$s =~ s/"//g;
		}
		if ( $_ =~ / Session / )
		{
			my @sess = split ( "\ ", $_ );
			my $id = $sess[0];
			$id =~ s/\.//g;
			$line = $s . "\t" . $id . "\t" . $sess[2] . "\t" . $sess[4];
			push ( @client_list, $line );
		}
	}

	return @client_list;
}

#function that renames a farm
sub setHTTPNewFarmName    # ($farm_name,$new_farm_name)
{
	my ( $farm_name, $new_farm_name ) = @_;

	my $output = -1;
	my @farm_configfiles = (
							 "$configdir\/$farm_name\_status.cfg",
							 "$configdir\/$farm_name\_pound.cfg",
							 "$configdir\/$farm_name\_Err414.html",
							 "$configdir\/$farm_name\_Err500.html",
							 "$configdir\/$farm_name\_Err501.html",
							 "$configdir\/$farm_name\_Err503.html",
							 "$farm_name\_guardian.conf"
	);
	my @new_farm_configfiles = (
								 "$configdir\/$new_farm_name\_status.cfg",
								 "$configdir\/$new_farm_name\_pound.cfg",
								 "$configdir\/$new_farm_name\_Err414.html",
								 "$configdir\/$new_farm_name\_Err500.html",
								 "$configdir\/$new_farm_name\_Err501.html",
								 "$configdir\/$new_farm_name\_Err503.html",
								 "$farm_name\_guardian.conf"
	);

	if ( -e "\/tmp\/$farm_name\_pound.socket" )
	{
		unlink ( "\/tmp\/$farm_name\_pound.socket" );
	}

	foreach my $farm_filename ( @farm_configfiles )
	{
		if ( -e "$farm_filename" )
		{
			use Tie::File;
			tie @configfile, 'Tie::File', "$farm_filename";

			for ( @configfile )
			{
				s/$farm_name/$new_farm_name/g;
			}
			untie @configfile;

			rename ( "$farm_filename", "$new_farm_configfiles[0]" );
			$output = $?;

			&logfile( "configuration saved in $new_farm_configfiles[0] file" );
		}
		shift ( @new_farm_configfiles );
	}

	return $output;
}

# HTTPS only
# Set Farm Ciphers value
sub setFarmCipherList    # ($farm_name,$ciphers,$cipherc)
{
	# assign first/second/third argument or take global value
	my $farm_name = shift // $farmname;
	my $ciphers   = shift // $ciphers;
	my $cipherc   = shift // $cipherc;

	my $farm_type     = &getFarmType( $farm_name );
	my $farm_filename = &getFarmFile( $farm_name );
	my $output        = -1;

	tie my @array, 'Tie::File', "$configdir/$farm_filename";
	for my $line ( @array )
	{
		# takes the first Ciphers line only
		next if ( $line !~ /Ciphers/ );

		if ( $ciphers eq "cipherglobal" )
		{
			$line =~ s/#//g;
			$line   = "\tCiphers \"ALL\"";
			$output = 0;
		}
		elsif ( $ciphers eq "cipherpci" )
		{
			$line =~ s/#//g;
			$line   = "\tCiphers \"$cipher_pci\"";
			$output = 0;
		}
		elsif ( $ciphers eq "ciphercustom" )
		{
			$cipherc = 'DEFAULT' if not defined $cipherc;
			$line =~ s/#//g;
			$line   = "\tCiphers \"$cipherc\"";
			$output = 0;
		}

		# default cipher
		else
		{
			$line =~ s/#//g;
			$line   = "\tCiphers \"ALL\"";
			$output = 0;
		}

		last;
	}
	untie @array;

	return $output;
}

# HTTPS only
# Get Farm Ciphers value
sub getFarmCipherList    # ($farm_name)
{
	my $farm_name = shift // $farmname;
	my $output = -1;

	my $farm_filename = &getFarmFile( $farm_name );

	open FI, "<$configdir/$farm_filename";
	my @content = <FI>;
	close FI;

	foreach $line ( @content )
	{
		next if ( $line !~ /Ciphers/ );

		$output = ( split ( '\"', $line ) )[1];

		last;
	}

	return $output;
}

# HTTPS only
# Get Farm Ciphers value
sub getFarmCipherSet    # ($farm_name)
{
	my $farm_name = shift // $farmname;

	my $output = -1;

	my $cipher_list = &getFarmCipherList( $farm_name );

	if ( $cipher_list eq 'ALL' )
	{
		$output = "cipherglobal";
	}
	elsif ( $cipher_list eq $cipher_pci )
	{
		$output = "cipherpci";
	}
	else
	{
		$output = "ciphercustom";
	}

	return $output;
}

#function that check if the config file is OK.
sub getHTTPFarmConfigIsOK    # ($farm_name)
{
	my $farm_name = shift;

	my $farm_filename = &getFarmFile( $farm_name );
	my $pound_command = "$pound -f $configdir\/$farm_filename -c";
	my $output        = -1;

	&logfile( "running: $pound_command" );

	my $run = `$pound_command 2>&1`;
	$output = $?;

	&logfile( "output: $run " );

	return $output;
}

#function that check if a backend on a farm is on maintenance mode
sub getHTTPFarmBackendMaintenance    # ($farm_name,$backend,$service)
{
	my ( $farm_name, $backend, $service ) = @_;

	my @run    = `$poundctl -c "/tmp/$farm_name\_pound.socket"`;
	my $output = -1;
	my $sw     = 0;

	foreach my $line ( @run )
	{
		if ( $line =~ /Service \"$service\"/ )
		{
			$sw = 1;
		}

		if ( $line =~ /$backend\. Backend/ && $sw == 1 )
		{
			my @line = split ( "\ ", $line );
			my $backendstatus = $line[3];

			if ( $backendstatus eq "DISABLED" )
			{
				$backendstatus =
				  &getHTTPBackendStatusFromFile( $farm_name, $backend, $service );

				if ( $backendstatus =~ /maintenance/ )
				{
					$output = 0;
				}
			}
			last;
		}
	}

	return $output;
}

#function that enable the maintenance mode for backend
sub setHTTPFarmBackendMaintenance    # ($farm_name,$backend,$service)
{
	my ( $farm_name, $backend, $service ) = @_;

	my $output = -1;

	#find the service number
	my $idsv = &getFarmVSI( $farm_name, $service );

	&logfile(
		  "setting Maintenance mode for $farm_name service $service backend $backend" );

	my $poundctl_command =
	  "$poundctl -c /tmp/$farm_name\_pound.socket -b 0 $idsv $backend";

	&logfile( "running '$poundctl_command'" );
	my @run = `$poundctl_command`;
	$output = $?;

	&getFarmHttpBackendStatus( $farm_name, $backend, "maintenance", $idsv );

	return $output;
}

#function that disable the maintenance mode for backend
sub setHTTPFarmBackendNoMaintenance    # ($farm_name,$backend,$service)
{
	my ( $farm_name, $backend, $service ) = @_;

	my $output = -1;

	#find the service number
	my $idsv = &getFarmVSI( $farm_name, $service );

	&logfile(
		"setting Disabled maintenance mode for $farm_name service $service backend $backend"
	);

	my $poundctl_command =
	  "$poundctl -c /tmp/$farm_name\_pound.socket -B 0 $idsv $backend";

	&logfile( "running '$poundctl_command'" );
	@run    = `$poundctl_command`;
	$output = $?;

	&getFarmHttpBackendStatus( $farm_name, $backend, "active", $idsv );

	return $output;
}

#function that save in a file the backend status (maintenance or not)
sub getFarmHttpBackendStatus    # ($farm_name,$backend,$status,$idsv)
{
	my ( $farm_name, $backend, $status, $idsv ) = @_;

	my $statusfile = "$configdir\/$farm_name\_status.cfg";
	my $changed    = "false";

	if ( !-e $statusfile )
	{
		open FW, ">$statusfile";
		@run = `$poundctl -c /tmp/$farm_name\_pound.socket`;
		my @sw;
		my @bw;

		foreach my $line ( @run )
		{
			if ( $line =~ /\.\ Service\ / )
			{
				@sw = split ( "\ ", $line );
				$sw[0] =~ s/\.//g;
				chomp $sw[0];
			}
			if ( $line =~ /\.\ Backend\ / )
			{
				@bw = split ( "\ ", $line );
				$bw[0] =~ s/\.//g;
				chomp $bw[0];
				if ( $bw[3] eq "active" )
				{
					print FW "-B 0 $sw[0] $bw[0] active\n";
				}
				else
				{
					print FW "-b 0 $sw[0] $bw[0] fgDOWN\n";
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
sub runRemovehttpBackend    # ($farm_name,$backend,$service)
{
	my ( $farm_name, $backend, $service ) = @_;

	my $i      = -1;
	my $j      = -1;
	my $change = "false";
	my $sindex = &getFarmVSI( $farm_name, $service );
	tie @contents, 'Tie::File', "$configdir\/$farm_name\_status.cfg";
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
	tie @filelines, 'Tie::File', "$configdir\/$farm_name\_status.cfg";
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

sub setFarmHttpBackendStatus    # ($farm_name)
{
	my $farm_name = shift;

	my $line;
	&logfile( "Setting backends status in farm $farm_name" );

	open FR, "<$configdir\/$farm_name\_status.cfg";
	while ( <FR> )
	{
		@line = split ( "\ ", $_ );
		@run =
		  `$poundctl -c /tmp/$farm_name\_pound.socket $line[0] $line[1] $line[2] $line[3]`;
	}
	close FR;
}

#Create a new Service in a HTTP farm
sub setFarmHTTPNewService    # ($farm_name,$service)
{
	my ( $farm_name, $service ) = @_;
	my $output = -1;

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
	if ( !fgrep { /Service "$service"/ } "$configdir/$farm_name\_pound.cfg" )
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

		$newservice[0] =~ s/#//g;
		$newservice[$#newservice] =~ s/#//g;

		my @fileconf;
		tie @fileconf, 'Tie::File', "$configdir/$farm_name\_pound.cfg";
		my $i         = 0;
		my $farm_type = "";
		$farm_type = &getFarmType( $farm_name );
		foreach $line ( @fileconf )
		{
			if ( $line =~ /#ZWACL-END/ )
			{
				foreach $lline ( @newservice )
				{
					if ( $lline =~ /\[DESC\]/ )
					{
						$lline =~ s/\[DESC\]/$service/;
					}
					if (    $lline =~ /StrictTransportSecurity/
						 && $farm_type eq "https" )
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

#Create a new farm service
sub setFarmNewService    # ($farm_name,$service)
{
	my ( $farm_name, $service ) = @_;

	my $farm_type = &getFarmType( $farm_name );
	my $output    = -1;

	if ( $farm_type eq "http" || $farm_type eq "https" )
	{
		$output = &setFarmHTTPNewService( $farm_name, $service );
	}

	return $output;
}

#delete a service in a Farm
sub deleteFarmService    # ($farm_name,$service)
{
	my ( $farm_name, $service ) = @_;

	my $farm_filename = &getFarmFile( $farm_name );
	my $sw            = 0;
	my $output        = -1;

	# Counter the Service's backends
	my $sindex = &getFarmVSI( $farm_name, $service );
	my $backendsvs = &getFarmVS( $farm_name, $service, "backends" );
	my @be = split ( "\n", $backendsvs );
	my $counter = -1;
	foreach $subline ( @be )
	{
		my @subbe = split ( "\ ", $subline );
		$counter++;
	}

	use Tie::File;
	tie my @fileconf, 'Tie::File', "$configdir/$farm_filename";

	# Stop FG service
	&runFarmGuardianStop( $farm_name, $service );

	my $i = 0;
	for ( $i = 0 ; $i < $#fileconf ; $i++ )
	{
		my $line = $fileconf[$i];
		if ( $sw eq "1" && ( $line =~ /ZWACL-END/ || $line =~ /Service/ ) )
		{
			$output = 0;
			last;
		}

		if ( $sw == 1 )
		{
			splice @fileconf, $i, 1,;
			$i--;
		}

		if ( $line =~ /Service "$service"/ )
		{
			$sw = 1;
			splice @fileconf, $i, 1,;
			$i--;
		}
	}
	untie @fileconf;

	# delete service's backends  in status file
	if ( $counter > -1 )
	{
		while ( $counter > -1 )
		{
			&runRemovehttpBackend( $farm_name, $counter, $service );
			$counter--;
		}
	}

# change the ID value of services with an ID higher than the service deleted (value - 1)
	tie @contents, 'Tie::File', "$configdir\/$farm_name\_status.cfg";
	foreach $line ( @contents )
	{
		my @params = split ( "\ ", $line );
		my $newval = @params[2] - 1;

		&logfile( "param2: @params[2] $newval" );

		if ( @params[2] > $sindex )
		{
			&logfile( "linea $_" );
			$line =~
			  s/@params[0]\ @params[1]\ @params[2]\ @params[3]\ @params[4]/@params[0]\ @params[1]\ $newval\ @params[3]\ @params[4]/g;
		}
	}
	untie @contents;

	return $output;
}

#function that return indicated value from a HTTP Service
#vs return virtual server
sub getHTTPFarmVS    # ($farm_name,$service,$tag)
{
	my ( $farm_name, $service, $tag ) = @_;

	my $farm_filename = &getFarmFile( $farm_name );
	my $output        = "";

	use Tie::File;
	tie my @fileconf, 'Tie::File', "$configdir/$farm_filename";

	my $sw         = 0;
	my $be_section = 0;
	my $be         = -1;
	my $sw_ti      = 0;
	my $output_ti  = "";
	my $sw_pr      = 0;
	my $output_pr  = "";
	my @return;

	foreach my $line ( @fileconf )
	{
		if ( $line =~ /^\tService/ )
		{
			$sw = 0;
		}
		if ( $line =~ /^\tService \"$service\"/ )
		{
			$sw = 1;
		}

		# returns all services for this farm
		if ( $tag eq "" && $service eq "" )
		{
			if ( $line =~ /^\tService\ \"/ && $line !~ "#" )
			{
				@return = split ( "\ ", $line );
				$return[1] =~ s/\"//g;
				$return[1] =~ s/^\s+//;
				$return[1] =~ s/\s+$//;
				$output = "$output $return[1]";
			}
		}

		#vs tag
		if ( $tag eq "vs" )
		{
			if ( $line =~ "HeadRequire" && $sw == 1 && $line !~ "#" )
			{
				@return = split ( "Host:", $line );
				$return[1] =~ s/\"//g;
				$return[1] =~ s/^\s+//;
				$return[1] =~ s/\s+$//;
				$output = $return[1];
				last;

			}
		}

		#url pattern
		if ( $tag eq "urlp" )
		{
			if ( $line =~ "Url \"" && $sw == 1 && $line !~ "#" )
			{
				@return = split ( "Url", $line );
				$return[1] =~ s/\"//g;
				$return[1] =~ s/^\s+//;
				$return[1] =~ s/\s+$//;
				$output = $return[1];
				last;
			}
		}

		#redirect
		if ( $tag eq "redirect" )
		{
			if (    ( $line =~ "Redirect \"" || $line =~ "RedirectAppend \"" )
				 && $sw == 1
				 && $line !~ "#" )
			{
				if ( $line =~ "Redirect \"" )
				{
					@return = split ( "Redirect", $line );
				}
				elsif ( $line =~ "RedirectAppend \"" )
				{
					@return = split ( "RedirectAppend", $line );
				}
				$return[1] =~ s/\"//g;
				$return[1] =~ s/^\s+//;
				$return[1] =~ s/\s+$//;
				$output = $return[1];
				last;
			}
		}
		if ( $tag eq "redirecttype" )
		{
			if (    ( $line =~ "Redirect \"" || $line =~ "RedirectAppend \"" )
				 && $sw == 1
				 && $line !~ "#" )
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
				$output = $values[1];
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
				$output = $values[2];
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
				$output = $values[3];
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
				$output = $values[4];
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
				$return[1] =~ s/\"//g;
				$return[1] =~ s/^\s+//;
				$return[1] =~ s/\s+$//;
				$output = $return[1];
				last;
			}
		}

		#ttl
		if ( $tag eq "ttl" )
		{
			if ( $line =~ "TTL" && $sw == 1 && $line !~ "#" )
			{
				@return = split ( "\ ", $line );
				$return[1] =~ s/\"//g;
				$return[1] =~ s/^\s+//;
				$return[1] =~ s/\s+$//;
				$output = $return[1];
				last;
			}
		}

		#session id
		if ( $tag eq "sessionid" )
		{
			if ( $line =~ "\t\t\tID" && $sw == 1 && $line !~ "#" )
			{
				@return = split ( "\ ", $line );
				$return[1] =~ s/\"//g;
				$return[1] =~ s/^\s+//;
				$return[1] =~ s/\s+$//;
				$output = $return[1];
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
				if (    $line =~ /End/
					 && $line !~ /#/
					 && $sw == 1
					 && $be_section == 1
					 && $line !~ /BackEnd/ )
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

	return $output;
}

#set values for a service
sub setHTTPFarmVS    # ($farm_name,$service,$tag,$string)
{
	my ( $farm_name, $service, $tag, $string ) = @_;

	my $farm_filename = &getFarmFile( $farm_name );
	my $output        = "";
	my $line;
	my $sw = 0;
	my $j  = 0;

	use Tie::File;
	tie my @fileconf, 'Tie::File', "$configdir/$farm_filename";

	foreach $line ( @fileconf )
	{
		if ( $line =~ /Service \"$service\"/ )
		{
			$sw = 1;
		}
		$string =~ s/^\s+//;
		$string =~ s/\s+$//;

		#vs tag
		if ( $tag eq "vs" )
		{
			if ( $line =~ "HeadRequire" && $sw == 1 && $string ne "" )
			{
				$line = "\t\tHeadRequire \"Host: $string\"";
				last;
			}
			if ( $line =~ "HeadRequire" && $sw == 1 && $string eq "" )
			{
				$line = "\t\t#HeadRequire \"Host:\"";
				last;
			}
		}

		#url pattern
		if ( $tag eq "urlp" )
		{
			if ( $line =~ "Url" && $sw == 1 && $string ne "" )
			{
				$line = "\t\tUrl \"$string\"";
				last;
			}
			if ( $line =~ "Url" && $sw == 1 && $string eq "" )
			{
				$line = "\t\t#Url \"\"";
				last;
			}
		}

		#dynscale
		if ( $tag eq "dynscale" )
		{
			if ( $line =~ "DynScale" && $sw == 1 && $string ne "" )
			{
				$line = "\t\tDynScale 1";
				last;
			}
			if ( $line =~ "DynScale" && $sw == 1 && $string eq "" )
			{
				$line = "\t\t#DynScale 1";
				last;
			}
		}

		#client redirect default
		if ( $tag eq "redirect" )
		{
			if (    ( $line =~ "Redirect\ \"" || $line =~ "RedirectAppend\ \"" )
				 && $sw == 1
				 && $string ne "" )
			{
				$line = "\t\tRedirect \"$string\"";
				last;
			}
			if (    ( $line =~ "Redirect\ \"" || $line =~ "RedirectAppend\ \"" )
				 && $sw == 1
				 && $string eq "" )
			{
				$line = "\t\t#Redirect \"\"";
				last;
			}
		}

		#client redirect append
		if ( $tag eq "redirectappend" )
		{
			if (    ( $line =~ "Redirect\ \"" || $line =~ "RedirectAppend\ \"" )
				 && $sw == 1
				 && $string ne "" )
			{
				$line = "\t\tRedirectAppend \"$string\"";
				last;
			}
			if (    ( $line =~ "Redirect\ \"" || $line =~ "RedirectAppend\ \"" )
				 && $sw == 1
				 && $string eq "" )
			{
				$line = "\t\t#Redirect \"\"";
				last;
			}
		}

		#cookie ins
		if ( $tag eq "cookieins" )
		{
			if ( $line =~ "BackendCookie" && $sw == 1 && $string ne "" )
			{
				$line =~ s/#//g;
				last;
			}
			if ( $line =~ "BackendCookie" && $sw == 1 && $string eq "" )
			{
				$line =~ s/\t\t//g;
				$line = "\t\t#$line";
				last;
			}
		}

		#cookie insertion name
		if ( $tag eq "cookieins-name" )
		{
			if ( $line =~ "BackendCookie" && $sw == 1 && $string ne "" )
			{
				$l = $line;
				$l =~ s/\t\t//g;
				my @values = split ( "\ ", $l );
				$values[1] =~ s/\"//g;
				$line = "\t\tBackendCookie \"$string\" $values[2] $values[3] $values[4]";
				last;
			}
		}

		#cookie insertion domain
		if ( $tag eq "cookieins-domain" )
		{
			if ( $line =~ "BackendCookie" && $sw == 1 && $string ne "" )
			{
				$l = $line;
				$l =~ s/\t\t//g;
				my @values = split ( "\ ", $l );
				$values[2] =~ s/\"//g;
				$line = "\t\tBackendCookie $values[1] \"$string\" $values[3] $values[4]";
				last;
			}
		}

		#cookie insertion path
		if ( $tag eq "cookieins-path" )
		{
			if ( $line =~ "BackendCookie" && $sw == 1 && $string ne "" )
			{
				$l = $line;
				$l =~ s/\t\t//g;
				my @values = split ( "\ ", $l );
				$values[3] =~ s/\"//g;
				$line = "\t\tBackendCookie $values[1] $values[2] \"$string\" $values[4]";
				last;
			}
		}

		#cookie insertion TTL
		if ( $tag eq "cookieins-ttlc" )
		{
			if ( $line =~ "BackendCookie" && $sw == 1 && $string ne "" )
			{
				$l = $line;
				$l =~ s/\t\t//g;
				my @values = split ( "\ ", $l );
				$values[4] =~ s/\"//g;
				$line = "\t\tBackendCookie $values[1] $values[2] $values[3] $string";
				last;
			}
		}

		#TTL
		if ( $tag eq "ttl" )
		{
			if ( $line =~ "TTL" && $sw == 1 && $string ne "" )
			{
				$line = "\t\t\tTTL $string";
				last;
			}
			if ( $line =~ "TTL" && $sw == 1 && $string eq "" )
			{
				$line = "\t\t\t#TTL 120";
				last;
			}
		}

		#session id
		if ( $tag eq "sessionid" )
		{
			if ( $line =~ "\t\t\tID|\t\t\t#ID" && $sw == 1 && $string ne "" )
			{
				$line = "\t\t\tID \"$string\"";
				last;
			}
			if ( $line =~ "\t\t\tID|\t\t\t#ID" && $sw == 1 && $string eq "" )
			{
				$line = "\t\t\t#ID \"$string\"";
				last;
			}
		}

		#HTTPS Backends tag
		if ( $tag eq "httpsbackend" )
		{
			if ( $line =~ "##HTTPS-backend##" && $sw == 1 && $string ne "" )
			{
				#turn on
				$line = "\t\t##True##HTTPS-backend##";
			}

			#
			if ( $line =~ "##HTTPS-backend##" && $sw == 1 && $string eq "" )
			{
				#turn off
				$line = "\t\t##False##HTTPS-backend##";
			}

			#Delete HTTPS tag in a BackEnd
			if ( $sw == 1 && $line =~ /HTTPS$/ && $string eq "" )
			{
				#Delete HTTPS tag
				splice @fileconf, $j, 1,;
			}

			#Add HTTPS tag
			if ( $sw == 1 && $line =~ /BackEnd$/ && $string ne "" )
			{
				if ( $fileconf[$j + 1] =~ /Address\ .*/ )
				{
					#add new line with HTTPS tag
					splice @fileconf, $j + 1, 0, "\t\t\tHTTPS";
				}
			}

			#go out of curret Service
			if (    $line =~ /Service \"/
				 && $sw == 1
				 && $line !~ /Service \"$service\"/ )
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
				}
				if ( $line =~ "TTL" )
				{
					$line =~ s/#//g;
				}
				if (    $session eq "URL"
					 || $session eq "COOKIE"
					 || $session eq "HEADER" )
				{
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
		$j++;
	}
	untie @fileconf;

	return $output;
}

#get index of a service in a http farm
sub getFarmVSI    # ($farm_name,$service)
{
	my ( $farm_name, $service ) = @_;
	my $output;
	my $index;
	my $l;
	my @content = &getFarmBackendStatusCtl( $farm_name );

	foreach ( @content )
	{
		if ( $_ =~ /Service \"$service\"/ )
		{
			$l = $_;
			my @line = split ( '\.', $l );
			$index = $line[0];
		}
	}
	$index =~ s/\"//g;
	$index =~ s/^\s+//;
	$index =~ s/\s+$//;
	$output = $index;

	return $output;
}

# Get an array containing services that are configured in a http farm
sub getFarmServices
{

	#print "Content-type: text/javascript; charset=utf8\n\n";

	my ( $farm_name ) = @_;
	my @output;
	my $farm_filename = &getFarmFile( $farm_name );

	open FR, "<$configdir\/$farm_filename";
	my @file = <FR>;
	my $pos  = 0;

  #print "farm filename is $farm_filename. Full path is $configdir\/$farm_filename";

	foreach $line ( @file )
	{
		#print "line is $line";

		if ( $line =~ /\tService\ \"/ )
		{

			$pos++;
			@line = split ( "\"", $line );
			my $service = @line[1];

			#print "line is $line and service is $service";

			push ( @output, $service );
		}
	}
	return @output;

}

# setFarmBackendsSessionsRemove not in use???
#function that removes all the active sessions enabled to a backend in a given service
#needed: farmname, serviceid, backendid
#~ sub setFarmBackendsSessionsRemove($farm_name,$service,$backendid)
#~ {
#~ ( $farm_name, $service, $backendid ) = @_;
#~
#~ my @content = &getFarmBackendStatusCtl( $farm_name );
#~ my @sessions = &getFarmBackendsClientsList( $farm_name, @content );
#~ my @service;
#~ my $sw = 0;
#~ my $serviceid;
#~ my @sessionid;
#~ my $sessid;
#~
#~ &logfile(
#~ "Deleting established sessions to a backend $backendid from farm $farm_name in service $service"
#~ );
#~
#~ foreach ( @content )
#~ {
#~ if ( $_ =~ /Service/ && $sw eq 1 )
#~ {
#~ $sw = 0;
#~ }
#~
#~ if ( $_ =~ /Service\ \"$service\"/ && $sw eq 0 )
#~ {
#~ $sw      = 1;
#~ @service = split ( /\./, $_ );
#~ $serviceid = $service[0];
#~ }
#~
#~ if ( $_ =~ /Session.*->\ $backendid/ && $sw eq 1 )
#~ {
#~ @sessionid  = split ( /Session/, $_ );
#~ $sessionid2 = @sessionid[1];
#~ @sessionid  = split ( /\ /, $sessionid2 );
#~ $sessid     = @sessionid[1];
#~ @output     = `$poundctl -c  /tmp/$farm_name\_pound.socket -n 0 $serviceid $sessid`;
#~ &logfile(
#~ "Executing:  $poundctl -c /tmp/$farm_name\_pound.socket -n 0 $serviceid $sessid" );
#~ }
#~ }
#~ }

# do not remove this
1
