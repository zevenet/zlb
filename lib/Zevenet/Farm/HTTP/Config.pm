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

my $configdir = &getGlobalConfiguration('configdir');

=begin nd
Function: setFarmClientTimeout

	Configure the client time parameter for a HTTP farm.
	
Parameters:
	client - It is the time in seconds for the client time parameter
	farmname - Farm name

Returns:
	Integer - Error code: 0 on success, or -1 on failure.

=cut
sub setFarmClientTimeout    # ($client,$farm_name)
{
	my ( $client, $farm_name ) = @_;

	my $farm_type     = &getFarmType( $farm_name );
	my $farm_filename = &getFarmFile( $farm_name );
	my $output        = -1;

	if ( $farm_type eq "http" || $farm_type eq "https" )
	{
		require Tie::File;
		tie my @filefarmhttp, 'Tie::File', "$configdir/$farm_filename";

		my $i_f         = -1;
		my $array_count = @filefarmhttp;
		my $found       = "false";

		while ( $i_f <= $array_count && $found eq "false" )
		{
			$i_f++;

			if ( $filefarmhttp[$i_f] =~ /^Client/ )
			{
				&zenlog( "setting 'ClientTimeout $client' for $farm_name farm $farm_type" );
				$filefarmhttp[$i_f] = "Client\t\t $client";
				$output             = $?;
				$found              = "true";
			}
		}
		untie @filefarmhttp;
	}

	return $output;
}

=begin nd
Function: getFarmClientTimeout

	Return the client time parameter for a HTTP farm.
	
Parameters:
	farmname - Farm name

Returns:
	Integer - Return the seconds for client request timeout or -1 on failure.

=cut
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

		foreach my $line ( @file )
		{
			if ( $line =~ /^Client\t\t.*\d+/ )
			{
				my @line_aux = split ( "\ ", $line );
				$output = $line_aux[1];
			}
		}
		close FR;
	}

	return $output;
}

=begin nd
Function: setHTTPFarmSessionType

	Configure type of persistence
	
Parameters:
	session - type of session: nothing, HEADER, URL, COOKIE, PARAM, BASIC or IP
	farmname - Farm name

Returns:
	Integer - Error code: 0 on success, or -1 on failure.

=cut
sub setHTTPFarmSessionType    # ($session,$farm_name)
{
	my ( $session, $farm_name ) = @_;

	my $farm_filename = &getFarmFile( $farm_name );
	my $farm_type     = &getFarmType( $farm_name );
	my $output        = -1;

	&zenlog( "setting 'Session type $session' for $farm_name farm $farm_type" );
	tie my @contents, 'Tie::File', "$configdir\/$farm_filename";
	my $i     = -1;
	my $found = "false";
	foreach my $line ( @contents )
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

=begin nd
Function: getHTTPFarmSessionType

	Return the type of session persistence for a HTTP farm.
	
Parameters:
	farmname - Farm name

Returns:
	scalar - type of persistence or -1 on failure.

=cut
sub getHTTPFarmSessionType    # ($farm_name)
{
	my ( $farm_name ) = @_;
	my $output = -1;

	open FR, "<$configdir\/$farm_name";
	my @file = <FR>;
	foreach my $line ( @file )
	{
		if ( $line =~ /Type/ && $line !~ /#/ )
		{
			my @line_aux = split ( "\ ", $line );
			$output = $line_aux[1];
		}
	}
	close FR;

	return $output;
}

=begin nd
Function: setHTTPFarmBlacklistTime

	Configure check time for resurected back-end. It is a HTTP farm paramter.
	
Parameters:
	checktime - time for resurrected checks
	farmname - Farm name

Returns:
	Integer - Error code: 0 on success, or -1 on failure.

=cut
sub setHTTPFarmBlacklistTime    # ($blacklist_time,$farm_name)
{
	my ( $blacklist_time, $farm_name ) = @_;

	my $farm_type     = &getFarmType( $farm_name );
	my $farm_filename = &getFarmFile( $farm_name );
	my $output        = -1;

	require Tie::File;
	tie my @filefarmhttp, 'Tie::File', "$configdir/$farm_filename";
	my $i_f         = -1;
	my $array_count = @filefarmhttp;
	my $found       = "false";

	while ( $i_f <= $array_count && $found eq "false" )
	{
		$i_f++;
		if ( $filefarmhttp[$i_f] =~ /^Alive/ )
		{
			&zenlog(
					"setting 'Blacklist time $blacklist_time' for $farm_name farm $farm_type" );
			$filefarmhttp[$i_f] = "Alive\t\t $blacklist_time";
			$output             = $?;
			$found              = "true";
		}
	}
	untie @filefarmhttp;

	return $output;
}

=begin nd
Function: getHTTPFarmBlacklistTime

	Return  time for resurrected checks for a HTTP farm.
	
Parameters:
	farmname - Farm name

Returns:
	integer - seconds for check or -1 on failure.

=cut
sub getHTTPFarmBlacklistTime    # ($farm_name)
{
	my ( $farm_name ) = @_;

	my $blacklist_time = -1;
	my $conf_file      = &getFarmFile( $farm_name );
	my $conf_path      = "$configdir/$conf_file";

	open( my $fh, '<', $conf_path ) or die "Could not open $conf_path: $!";
	while ( my $line = <$fh> )
	{
		next unless $line =~ /^Alive/i;

		my @line_aux = split ( "\ ", $line );
		$blacklist_time = $line_aux[1];
		last;
	}
	close $fh;

	return $blacklist_time;
}

=begin nd
Function: setFarmHttpVerb

	Configure the accepted HTTP verb for a HTTP farm.
	The accepted verb sets are: 
		0. standardHTTP, for the verbs GET, POST, HEAD.
		1. extendedHTTP, add the verbs PUT, DELETE.
		2. standardWebDAV, add the verbs LOCK, UNLOCK, PROPFIND, PROPPATCH, SEARCH, MKCOL, MOVE, COPY, OPTIONS, TRACE, MKACTIVITY, CHECKOUT, MERGE, REPORT.
		3. MSextWebDAV, add the verbs SUBSCRIBE, UNSUBSCRIBE, NOTIFY, BPROPFIND, BPROPPATCH, POLL, BMOVE, BCOPY, BDELETE, CONNECT.
		4. MSRPCext, add the verbs RPC_IN_DATA, RPC_OUT_DATA.
	
Parameters:
	verb - accepted verbs: 0, 1, 2, 3 or 4
	farmname - Farm name

Returns:
	Integer - Error code: 0 on success, or -1 on failure.

=cut
sub setFarmHttpVerb    # ($verb,$farm_name)
{
	my ( $verb, $farm_name ) = @_;

	my $farm_type     = &getFarmType( $farm_name );
	my $farm_filename = &getFarmFile( $farm_name );
	my $output        = -1;

	if ( $farm_type eq "http" || $farm_type eq "https" )
	{
		require Tie::File;
		tie my @filefarmhttp, 'Tie::File', "$configdir/$farm_filename";
		my $i_f         = -1;
		my $array_count = @filefarmhttp;
		my $found       = "false";
		while ( $i_f <= $array_count && $found eq "false" )
		{
			$i_f++;
			if ( $filefarmhttp[$i_f] =~ /xHTTP/ )
			{
				&zenlog( "setting 'Http verb $verb' for $farm_name farm $farm_type" );
				$filefarmhttp[$i_f] = "\txHTTP $verb";
				$output             = $?;
				$found              = "true";
			}
		}
		untie @filefarmhttp;
	}

	return $output;
}

=begin nd
Function: getFarmHttpVerb

	Return the available verb set for a HTTP farm.
	The possible verb sets are: 
		0. standardHTTP, for the verbs GET, POST, HEAD.
		1. extendedHTTP, add the verbs PUT, DELETE.
		2. standardWebDAV, add the verbs LOCK, UNLOCK, PROPFIND, PROPPATCH, SEARCH, MKCOL, MOVE, COPY, OPTIONS, TRACE, MKACTIVITY, CHECKOUT, MERGE, REPORT.
		3. MSextWebDAV, add the verbs SUBSCRIBE, UNSUBSCRIBE, NOTIFY, BPROPFIND, BPROPPATCH, POLL, BMOVE, BCOPY, BDELETE, CONNECT.
		4. MSRPCext, add the verbs RPC_IN_DATA, RPC_OUT_DATA.
	
Parameters:
	farmname - Farm name

Returns:
	integer - return the verb set identier or -1 on failure.

=cut
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
		foreach my $line ( @file )
		{
			if ( $line =~ /xHTTP/ )
			{
				my @line_aux = split ( "\ ", $line );
				$output = $line_aux[1];
			}
		}
		close FR;
	}

	return $output;
}

=begin nd
Function: setFarmListen

	Change a HTTP farm between HTTP and HTTPS listener
	
Parameters:
	farmname - Farm name
	listener - type of listener: http or https

Returns:
	none - .
	
FIXME 
	not return nothing, use $found variable to return success or error

=cut
sub setFarmListen    # ( $farm_name, $farmlisten )
{
	my ( $farm_name, $flisten ) = @_;

	require Tie::File;

	my $farm_filename = &getFarmFile( $farm_name );
	my $i_f           = -1;
	my $found         = "false";

	tie my @filefarmhttp, 'Tie::File', "$configdir/$farm_filename";
	my $array_count = @filefarmhttp;

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

		# Enable 'Disable TLSv1, TLSv1_1 or TLSv1_2'
		if ( $filefarmhttp[$i_f] =~ /.*Disable TLSv1/ && $flisten eq "http" )
		{
			$filefarmhttp[$i_f] =~ s/Disable TLSv1/#Disable TLSv1/;
		}
		if ( $filefarmhttp[$i_f] =~ /.*Disable TLSv1/ && $flisten eq "https" )
		{
			$filefarmhttp[$i_f] =~ s/#//g;
		}
		elsif (    $filefarmhttp[$i_f] =~ /.*DisableTLSv1\d$/
				&& $flisten eq "https" )
		{
			$filefarmhttp[$i_f] =~ s/#//g;
		}

		# Enable 'Disable SSLv3 or SSLv2'
		if ( $filefarmhttp[$i_f] =~ /.*Disable SSLv\d$/ && $flisten eq "http" )
		{
			$filefarmhttp[$i_f] =~ s/Disable SSLv/#Disable SSLv/;
		}
		if ( $filefarmhttp[$i_f] =~ /.*Disable SSLv\d$/ && $flisten eq "https" )
		{
			$filefarmhttp[$i_f] =~ s/#//g;
		}
		elsif (    $filefarmhttp[$i_f] =~ /.*DisableSSLv\d$/
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

		# Check for ECDHCurve cyphers
		if ( $filefarmhttp[$i_f] =~ /^\#*ECDHCurve/ && $flisten eq "http" )
		{
			$filefarmhttp[$i_f] =~ s/.*ECDHCurve/\#ECDHCurve/;
		}
		if ( $filefarmhttp[$i_f] =~ /^\#*ECDHCurve/ && $flisten eq "https" )
		{
			$filefarmhttp[$i_f] =~ s/.*ECDHCurve.*/ECDHCurve\t"prime256v1"/;
		}

		# Generate DH Keys if needed
		#my $dhfile = "$configdir\/$farm_name\_dh2048.pem";
		if ( $filefarmhttp[$i_f] =~ /^\#*DHParams/ && $flisten eq "http" )
		{
			$filefarmhttp[$i_f] =~ s/.*DHParams/\#DHParams/;
			#&setHTTPFarmDHStatus( $farm_name, "off" );
		}
		if ( $filefarmhttp[$i_f] =~ /^\#*DHParams/ && $flisten eq "https" )
		{
			$filefarmhttp[$i_f] =~ s/.*DHParams/DHParams/;
			#$filefarmhttp[$i_f] =~ s/.*DHParams.*/DHParams\t"$dhfile"/;
			#&setHTTPFarmDHStatus( $farm_name, "on" );
			#&genDHFile ( $farm_name );
		}

		if ( $filefarmhttp[$i_f] =~ /ZWACL-END/ )
		{
			$found = "true";
		}

	}
	untie @filefarmhttp;
}

=begin nd
Function: setFarmRewriteL

	Asign a RewriteLocation vaue to a farm HTTP or HTTPS
	
Parameters:
	farmname - Farm name
	rewritelocation - The options are: disabled, enabled or enabled-backends

Returns:
	none - .

=cut
sub setFarmRewriteL    # ($farm_name,$rewritelocation)
{
	my ( $farm_name, $rewritelocation ) = @_;

	my $farm_type     = &getFarmType( $farm_name );
	my $farm_filename = &getFarmFile( $farm_name );
	my $output        = -1;
	&zenlog( "setting 'Rewrite Location' for $farm_name to $rewritelocation" );

	if ( $farm_type eq "http" || $farm_type eq "https" )
	{
		require Tie::File;
		tie my @filefarmhttp, 'Tie::File', "$configdir/$farm_filename";
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

=begin nd
Function: getFarmRewriteL

	Return RewriteLocation Header configuration HTTP and HTTPS farms

Parameters:
	farmname - Farm name

Returns:
	scalar - The possible values are: disabled, enabled, enabled-backends or -1 on failure

=cut
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
		foreach my $line ( @file )
		{
			if ( $line =~ /RewriteLocation\ .*/ )
			{
				my @line_aux = split ( "\ ", $line );
				$output = $line_aux[1];
			}
		}
		close FR;
	}

	return $output;
}

=begin nd
Function: setFarmConnTO

	Configure connection time out value to a farm HTTP or HTTPS
	
Parameters:
	connectionTO - Conection time out in seconds
	farmname - Farm name

Returns:
	Integer - Error code: 0 on success, or -1 on failure.

=cut
sub setFarmConnTO    # ($tout,$farm_name)
{
	my ( $tout, $farm_name ) = @_;

	my $farm_type     = &getFarmType( $farm_name );
	my $farm_filename = &getFarmFile( $farm_name );
	my $output        = -1;

	&zenlog( "setting 'ConnTo timeout $tout' for $farm_name farm $farm_type" );

	if ( $farm_type eq "http" || $farm_type eq "https" )
	{
		require Tie::File;
		tie my @filefarmhttp, 'Tie::File', "$configdir/$farm_filename";
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

=begin nd
Function: getFarmConnTO

	Return farm connecton time out value for http and https farms

Parameters:
	farmname - Farm name

Returns:
	integer - return the connection time out or -1 on failure

=cut
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
		foreach my $line ( @file )
		{
			if ( $line =~ /^ConnTO/ )
			{
				my @line_aux = split ( "\ ", $line );
				$output = $line_aux[1];
			}
		}
		close FR;
	}

	return $output;
}

=begin nd
Function: setHTTPFarmTimeout

	Asign a timeout value to a farm
	
Parameters:
	timeout - Time out in seconds
	farmname - Farm name

Returns:
	Integer - Error code: 0 on success, or -1 on failure.

=cut
sub setHTTPFarmTimeout    # ($timeout,$farm_name)
{
	my ( $timeout, $farm_name ) = @_;

	my $farm_filename = &getFarmFile( $farm_name );
	my $output        = -1;

	require Tie::File;
	tie my @filefarmhttp, 'Tie::File', "$configdir/$farm_filename";
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

=begin nd
Function: getHTTPFarmTimeout

	Return the farm time out
	
Parameters:
	farmname - Farm name

Returns:
	Integer - Return time out, or -1 on failure.

=cut
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
			my @line_aux = split ( "\ ", $line );
			$output = $line_aux[1];
		}
	}
	close FR;

	return $output;
}

=begin nd
Function: setHTTPFarmMaxClientTime

	Set the maximum time for a client
	
Parameters:
	maximumTO - Maximum client time
	farmname - Farm name

Returns:
	Integer - Error code: 0 on success, or -1 on failure.

=cut
sub setHTTPFarmMaxClientTime    # ($track,$farm_name)
{
	my ( $track, $farm_name ) = @_;

	my $farm_filename = &getFarmFile( $farm_name );
	my $output        = -1;
	my $i_f           = -1;
	my $found         = "false";

	tie my @filefarmhttp, 'Tie::File', "$configdir/$farm_filename";
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

=begin nd
Function: getHTTPFarmMaxClientTime

	Return the maximum time for a client
	
Parameters:
	farmname - Farm name

Returns:
	Integer - Return maximum time, or -1 on failure.

=cut
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
			my @line_aux = split ( "\ ", $line );
			@max_client_time[0] = "";
			@max_client_time[1] = $line_aux[1];
		}
	}
	close FR;

	return @max_client_time;
}

=begin nd
Function: setHTTPFarmMaxConn

	set the max conn of a farm
	
Parameters:
	none - .

Returns:
	Integer - always return 0

FIXME:
	This function is in blank

=cut
sub setHTTPFarmMaxConn    # ($max_connections,$farm_name)
{
	return 0;
}

=begin nd
Function: getHTTPFarmGlobalStatus

	Get the status of a farm and its backends through pound command.
	
Parameters:
	farmname - Farm name

Returns:
	array - Return poundctl output 

=cut
sub getHTTPFarmGlobalStatus    # ($farm_name)
{
	my ( $farm_name ) = @_;

	my $poundctl = &getGlobalConfiguration('poundctl');

	return `$poundctl -c "/tmp/$farm_name\_pound.socket"`;
}

=begin nd
Function: setFarmErr

	Configure a error message for http error: 414, 500, 501 or 503
	 
Parameters:
	farmname - Farm name
	message - Message body for the error
	error_number - Number of error to set, the options are 414, 500, 501 or 503

Returns:
	Integer - Error code: 0 on success, or -1 on failure.

=cut
sub setFarmErr    # ($farm_name,$content,$nerr)
{
	my ( $farm_name, $content, $nerr ) = @_;

	my $farm_type = &getFarmType( $farm_name );
	my $output    = -1;

	&zenlog( "setting 'Err $nerr' for $farm_name farm $farm_type" );
	if ( $farm_type eq "http" || $farm_type eq "https" )
	{
		if ( -e "$configdir\/$farm_name\_Err$nerr.html" && $nerr != "" )
		{
			$output = 0;
			my @err = split ( "\n", "$content" );
			open FO, ">$configdir\/$farm_name\_Err$nerr.html";
			foreach my $line ( @err )
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

=begin nd
Function: getFarmErr

	Return the error message for a http error: 414, 500, 501 or 503
	 
Parameters:
	farmname - Farm name
	error_number - Number of error to set, the options are 414, 500, 501 or 503

Returns:
	Array - Message body for the error

=cut
# Only http function
sub getFarmErr    # ($farm_name,$nerr)
{
	my ( $farm_name, $nerr ) = @_;

	my $farm_type     = &getFarmType( $farm_name );
	my $farm_filename = &getFarmFile( $farm_name );
	my $output;

	if ( $farm_type eq "http" || $farm_type eq "https" )
	{
		open FR, "<$configdir\/$farm_filename";
		my @file = <FR>;
		foreach my $line ( @file )
		{
			if ( $line =~ /Err$nerr/ )
			{
				my @line_aux = split ( "\ ", $line );
				my $err = $line_aux[1];
				$err =~ s/"//g;
				if ( -e $err )
				{
					open FI, "$err";
					while ( <FI> )
					{
						$output .= $_;
					}
					close FI;
					chomp ($output);
				}
			}
		}
		close FR;
	}

	return $output;
}

=begin nd
Function: getHTTPFarmBootStatus

	Return the farm status at boot zevenet
	 
Parameters:
	farmname - Farm name

Returns:
	scalar - return "down" if the farm not run at boot or "up" if the farm run at boot

=cut
sub getHTTPFarmBootStatus    # ($farm_name)
{
	my ( $farm_name ) = @_;

	my $farm_filename = &getFarmFile( $farm_name );
	my $output        = "down";
	my $lastline;

	open FO, "<$configdir/$farm_filename";

	while ( my $line = <FO> )
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

=begin nd
Function: getHTTPFarmMaxConn

	Returns farm max connections
	
Parameters:
	none - .

Returns:
	Integer - always return 0
	
FIXME:
	This function do nothing
		
=cut
sub getHTTPFarmMaxConn    # ($farm_name)
{
	return 0;
}

=begin nd
Function: getHTTPFarmSocket

	Returns socket for HTTP farm.

	This funcion is only used in farmguardian functions.

Parameters:
	farmname - Farm name

Returns:
	String - return socket file
=cut
sub getHTTPFarmSocket       # ($farm_name)
{
	my ( $farm_name ) = @_;

	return "/tmp/" . $farm_name . "_pound.socket";
}

=begin nd
Function: getHTTPFarmPid

	Returns farm PID
		
Parameters:
	farmname - Farm name

Returns:
	Integer - return pid of farm, '-' if pid not exist or -1 on failure
			
=cut
sub getHTTPFarmPid        # ($farm_name)
{
	my ( $farm_name ) = @_;

	my $output = -1;
	my $piddir = &getGlobalConfiguration('piddir');

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

=begin nd
Function: getFarmChildPid

	Returns farm Child PID 
		
Parameters:
	farmname - Farm name

Returns:
	Integer - return child pid of farm or -1 on failure
			
=cut
sub getFarmChildPid    # ($farm_name)
{
	my ( $farm_name ) = @_;

	use File::Grep 'fgrep';

	my $farm_type = &getFarmType( $farm_name );
	my $fpid      = &getFarmPid( $farm_name );
	my $output    = -1;

	if ( $farm_type eq "http" || $farm_type eq "https" )
	{
		my $pids = `pidof -o $fpid pound`;
		my @pids = split ( " ", $pids );
		foreach my $pid ( @pids )
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

=begin nd
Function: getHTTPFarmVip

	Returns farm vip or farm port
		
Parameters:
	tag - requested parameter. The options are vip, for virtual ip or vipp, for virtual port
	farmname - Farm name

Returns:
	Scalar - return vip or port of farm or -1 on failure
	
FIXME
	vipps parameter is only used in tcp farms. Soon this parameter will be obsolet
			
=cut
sub getHTTPFarmVip    # ($info,$farm_name)
{
	my ( $info, $farm_name ) = @_;

	my $farm_filename = &getFarmFile( $farm_name );
	my $output        = -1;
	my $i             = 0;

	open my $fi, '<', "$configdir/$farm_filename";
	my @file = <$fi>;
	close $fi;

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

=begin nd
Function: setHTTPFarmVirtualConf

	Set farm virtual IP and virtual PORT
	
Parameters:
	vip - virtual ip
	port - virtual port
	farmname - Farm name

Returns:
	Integer - return 0 on success or different on failure
	
=cut
sub setHTTPFarmVirtualConf    # ($vip,$vip_port,$farm_name)
{
	my ( $vip, $vip_port, $farm_name ) = @_;

	my $farm_filename = &getFarmFile( $farm_name );
	my $stat          = 0;
	my $enter         = 2;

	require Tie::File;
	tie my @array, 'Tie::File', "$configdir\/$farm_filename";
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

=begin nd
Function: getHTTPFarmConfigIsOK

	Function that check if the config file is OK.
	
Parameters:
	farmname - Farm name

Returns:
	scalar - return 0 on success or different on failure
		
=cut
sub getHTTPFarmConfigIsOK    # ($farm_name)
{
	my $farm_name = shift;

	my $pound         = &getGlobalConfiguration( 'pound' );
	my $farm_filename = &getFarmFile( $farm_name );
	my $pound_command = "$pound -f $configdir\/$farm_filename -c";

	my $run = `$pound_command 2>&1`;
	my $rc  = $?;

	if ( $rc or &debug() )
	{
		my $message = $rc ? 'failed' : 'running';
		&zenlog( "$message: $pound_command" );
		&zenlog( "output: $run " );
	}

	return $rc;
}

=begin nd
Function: setFarmNameParam

	[NOT USED] Rename a HTTP farm
	
Parameters:
	farmname - Farm name
	newfarmname - New farm name

Returns:
	none - Error code: 0 on success or -1 on failure
	
BUG: 
	this function is duplicated
		
=cut
sub setFarmNameParam    # &setFarmNameParam( $farm_name, $new_name );
{
	my ( $farmName, $newName ) = @_;

	my $farmType     = &getFarmType( $farmName );
	my $farmFilename = &getFarmFile( $farmName );
	my $output       = -1;

	&zenlog( "setting 'farm name $newName' for $farmName farm $farmType" );

	if ( $farmType eq "http" || $farmType eq "https" )
	{
		tie my @filefarmhttp, 'Tie::File', "$configdir/$farmFilename";
		my $i_f        = -1;
		my $arrayCount = @filefarmhttp;
		my $found      = "false";
		while ( $i_f <= $arrayCount && $found eq "false" )
		{
			$i_f++;
			if ( $filefarmhttp[$i_f] =~ /^Name.*/ )
			{
				$filefarmhttp[$i_f] = "Name\t\t$newName";
				$output             = $?;
				$found              = "true";
			}
		}
		untie @filefarmhttp;
	}

	return $output;
}

1;
