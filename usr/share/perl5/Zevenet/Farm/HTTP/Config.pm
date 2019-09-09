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

require Zevenet::Lock;

my $configdir = &getGlobalConfiguration( 'configdir' );

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
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my ( $client, $farm_name ) = @_;

	my $farm_filename = &getFarmFile( $farm_name );
	my $output        = -1;

	my $lock_file = &getLockFile( $farm_name );
	my $lock_fh = &openlock( $lock_file, 'w' );

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
			&zenlog( "setting 'ClientTimeout $client' for $farm_name farm http",
					 "info", "LSLB" );
			$filefarmhttp[$i_f] = "Client\t\t $client";
			$output             = $?;
			$found              = "true";
		}
	}

	untie @filefarmhttp;
	close $lock_fh;

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
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my ( $farm_name ) = @_;

	my $farm_filename = &getFarmFile( $farm_name );
	my $output        = -1;

	open my $fd, '<', "$configdir\/$farm_filename";
	my @file = <$fd>;
	close $fd;

	foreach my $line ( @file )
	{
		if ( $line =~ /^Client\t\t.*\d+/ )
		{
			my @line_aux = split ( "\ ", $line );
			$output = $line_aux[1];
		}
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
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my ( $session, $farm_name ) = @_;

	my $farm_filename = &getFarmFile( $farm_name );
	my $output        = -1;

	my $lock_file = &getLockFile( $farm_name );
	my $lock_fh = &openlock( $lock_file, 'w' );

	&zenlog( "Setting 'Session type $session' for $farm_name farm http",
			 "info", "LSLB" );
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
	close $lock_fh;

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
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my ( $blacklist_time, $farm_name ) = @_;

	my $farm_filename = &getFarmFile( $farm_name );
	my $output        = -1;

	my $lock_file = &getLockFile( $farm_name );
	my $lock_fh = &openlock( $lock_file, 'w' );

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
			&zenlog( "Setting 'Blacklist time $blacklist_time' for $farm_name farm http",
					 "info", "LSLB" );
			$filefarmhttp[$i_f] = "Alive\t\t $blacklist_time";
			$output             = $?;
			$found              = "true";
		}
	}

	untie @filefarmhttp;
	close $lock_fh;

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
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my ( $farm_name ) = @_;

	my $blacklist_time = -1;
	my $conf_file      = &getFarmFile( $farm_name );
	my $conf_path      = "$configdir/$conf_file";

	open ( my $fh, '<', $conf_path ) or die "Could not open $conf_path: $!";
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
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my ( $verb, $farm_name ) = @_;

	my $farm_filename = &getFarmFile( $farm_name );
	my $output        = -1;

	my $lock_file = &getLockFile( $farm_name );
	my $lock_fh = &openlock( $lock_file, 'w' );

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
			&zenlog( "Setting 'Http verb $verb' for $farm_name farm http", "info", "LSLB" );
			$filefarmhttp[$i_f] = "\txHTTP $verb";
			$output             = $?;
			$found              = "true";
		}
	}

	untie @filefarmhttp;
	close $lock_fh;

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
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my ( $farm_name ) = @_;

	my $farm_filename = &getFarmFile( $farm_name );
	my $output        = -1;

	open my $fh, '<', "$configdir\/$farm_filename";
	my @file = <$fh>;
	close $fh;

	foreach my $line ( @file )
	{
		if ( $line =~ /xHTTP/ )
		{
			my @line_aux = split ( "\ ", $line );
			$output = $line_aux[1];
		}
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
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my ( $farm_name, $flisten ) = @_;

	my $farm_filename = &getFarmFile( $farm_name );
	my $i_f           = -1;
	my $found         = "false";

	my $lock_file = &getLockFile( $farm_name );
	my $lock_fh = &openlock( $lock_file, 'w' );

	require Tie::File;
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
		if ( $filefarmhttp[$i_f] =~ /ECDHCurve/ && $flisten eq "http" )
		{
			$filefarmhttp[$i_f] =~ s/ECDHCurve/\#ECDHCurve/;
		}
		if ( $filefarmhttp[$i_f] =~ /ECDHCurve/ && $flisten eq "https" )
		{
			$filefarmhttp[$i_f] =~ s/#ECDHCurve/ECDHCurve/;
		}

		# Generate DH Keys if needed
		#my $dhfile = "$configdir\/$farm_name\_dh2048.pem";
		if ( $filefarmhttp[$i_f] =~ /^\#*DHParams/ && $flisten eq "http" )
		{
			$filefarmhttp[$i_f] =~ s/.*DHParams/\#DHParams/;
		}
		if ( $filefarmhttp[$i_f] =~ /^\#*DHParams/ && $flisten eq "https" )
		{
			$filefarmhttp[$i_f] =~ s/.*DHParams/DHParams/;

			#$filefarmhttp[$i_f] =~ s/.*DHParams.*/DHParams\t"$dhfile"/;
		}

		if ( $filefarmhttp[$i_f] =~ /ZWACL-END/ )
		{
			$found = "true";
		}
	}

	untie @filefarmhttp;
	close $lock_fh;
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
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my ( $farm_name, $rewritelocation ) = @_;

	my $farm_filename = &getFarmFile( $farm_name );
	my $output        = -1;

	&zenlog( "setting 'Rewrite Location' for $farm_name to $rewritelocation",
			 "info", "LSLB" );

	my $lock_file = &getLockFile( $farm_name );
	my $lock_fh = &openlock( $lock_file, 'w' );

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
	close $lock_fh;
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
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my ( $farm_name ) = @_;

	my $farm_filename = &getFarmFile( $farm_name );
	my $output        = -1;

	open my $fd, '<', "$configdir\/$farm_filename";
	my @file = <$fd>;
	close $fd;

	foreach my $line ( @file )
	{
		if ( $line =~ /RewriteLocation\ .*/ )
		{
			my @line_aux = split ( "\ ", $line );
			$output = $line_aux[1];
		}
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
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my ( $tout, $farm_name ) = @_;

	my $farm_filename = &getFarmFile( $farm_name );
	my $output        = -1;

	&zenlog( "Setting 'ConnTo timeout $tout' for $farm_name farm http",
			 "info", "LSLB" );

	my $lock_file = &getLockFile( $farm_name );
	my $lock_fh = &openlock( $lock_file, 'w' );

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
	close $lock_fh;

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
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my ( $farm_name ) = @_;

	my $farm_filename = &getFarmFile( $farm_name );
	my $output        = -1;

	open my $fd, '<', "$configdir\/$farm_filename";
	my @file = <$fd>;
	close $fd;

	foreach my $line ( @file )
	{
		if ( $line =~ /^ConnTO/ )
		{
			my @line_aux = split ( "\ ", $line );
			$output = $line_aux[1];
		}
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
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my ( $timeout, $farm_name ) = @_;

	my $farm_filename = &getFarmFile( $farm_name );
	my $output        = -1;

	my $lock_file = &getLockFile( $farm_name );
	my $lock_fh = &openlock( $lock_file, 'w' );

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
	close $lock_fh;

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
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my ( $farm_name ) = @_;

	my $farm_filename = &getFarmFile( $farm_name );
	my $output        = -1;

	open my $fd, '<', "$configdir\/$farm_filename";
	my @file = <$fd>;

	foreach my $line ( @file )
	{
		if ( $line =~ /^Timeout/ )
		{
			my @line_aux = split ( "\ ", $line );
			$output = $line_aux[1];
		}
	}
	close $fd;

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
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my ( $track, $farm_name ) = @_;

	my $farm_filename = &getFarmFile( $farm_name );
	my $output        = -1;
	my $i_f           = -1;
	my $found         = "false";

	my $lock_file = &getLockFile( $farm_name );
	my $lock_fh = &openlock( $lock_file, 'w' );

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
	close $lock_fh;

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
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my ( $farm_name ) = @_;

	my $farm_filename = &getFarmFile( $farm_name );
	my @max_client_time;

	push ( @max_client_time, "" );
	push ( @max_client_time, "" );

	open my $fd, '<', "$configdir\/$farm_filename";
	my @configfile = <$fd>;

	foreach my $line ( @configfile )
	{
		if ( $line =~ /TTL/ )
		{
			my @line_aux = split ( "\ ", $line );
			@max_client_time[0] = "";
			@max_client_time[1] = $line_aux[1];
		}
	}
	close $fd;

	return @max_client_time;
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
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my ( $farm_name ) = @_;

	my $poundctl = &getGlobalConfiguration( 'poundctl' );

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
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my ( $farm_name, $content, $nerr ) = @_;

	my $output = -1;

	&zenlog( "Setting 'Err $nerr' for $farm_name farm http", "info", "LSLB" );

	if ( -e "$configdir\/$farm_name\_Err$nerr.html" && $nerr != "" )
	{
		$output = 0;
		my @err = split ( "\n", "$content" );
		my $fd = &openlock( "$configdir\/$farm_name\_Err$nerr.html", 'w' );

		foreach my $line ( @err )
		{
			$line =~ s/\r$//;
			print $fd "$line\n";
			$output = $? || $output;
		}

		close $fd;
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
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my ( $farm_name, $nerr ) = @_;

	my $farm_filename = &getFarmFile( $farm_name );
	my $output;

	open my $fd, '<', "$configdir\/$farm_filename";
	my @file = <$fd>;
	close $fd;

	foreach my $line ( @file )
	{
		if ( $line =~ /Err$nerr/ )
		{
			my @line_aux = split ( "\ ", $line );
			my $err = $line_aux[1];
			$err =~ s/"//g;

			if ( -e $err )
			{
				open my $fd, '<', "$err";
				while ( <$fd> )
				{
					$output .= $_;
				}
				close $fd;
				chomp ( $output );
			}
		}
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
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my ( $farm_name ) = @_;

	my $farm_filename = &getFarmFile( $farm_name );
	my $output        = "down";
	my $lastline;

	open my $fd, '<', "$configdir/$farm_filename";

	while ( my $line = <$fd> )
	{
		$lastline = $line;
	}
	close $fd;

	if ( $lastline !~ /^#down/ )
	{
		$output = "up";
	}

	return $output;
}

=begin nd
Function: setHTTPFarmBootStatus

	Return the farm status at boot zevenet

Parameters:
	farmname - Farm name
	value - Write the boot status "up" or "down"

Returns:
	scalar - return "down" if the farm not run at boot or "up" if the farm run at boot

=cut

sub setHTTPFarmBootStatus    # ($farm_name, $value)
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my ( $farm_name, $value ) = @_;

	my $farm_filename = &getFarmFile( $farm_name );
	my $output        = "down";
	my $lastline;

	my $lock_file = &getLockFile( $farm_name );
	my $lock_fh = &openlock( $lock_file, 'w' );

	require Tie::File;
	tie my @configfile, 'Tie::File', "$configdir\/$farm_filename";
	@configfile = grep !/^\#down/, @configfile;

	push @configfile, '#down' if ( $value eq "down" );

	untie @configfile;
	close $lock_fh;

	return;
}

=begin nd
Function: getHTTPFarmStatus

	Return current farm process status

Parameters:
	farmname - Farm name

Returns:
	string - return "up" if the process is running or "down" if it isn't

=cut

sub getHTTPFarmStatus    # ($farm_name)
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my ( $farm_name ) = @_;

	my $pid    = &getHTTPFarmPid( $farm_name );
	my $output = -1;
	my $running_pid;
	$running_pid = kill ( 0, $pid ) if $pid ne "-";

	if ( $pid ne "-" && $running_pid )
	{
		$output = "up";
	}
	else
	{
		unlink &getHTTPFarmPidFile( $farm_name ) if ( $pid ne "-" && !$running_pid );
		$output = "down";
	}

	return $output;
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

sub getHTTPFarmSocket    # ($farm_name)
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
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

sub getHTTPFarmPid    # ($farm_name)
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my ( $farm_name ) = @_;

	my $output  = -1;
	my $piddir  = &getGlobalConfiguration( 'piddir' );
	my $pidfile = "$piddir\/$farm_name\_pound.pid";

	# Get number of cores
	my $processors = `nproc`;
	chomp $processors;

	# If the LB has one core, wait 20ms for pound child process to generate pid.
	select ( undef, undef, undef, 0.020 ) if ( $processors == 1 );

	if ( -e $pidfile )
	{
		open my $fd, '<', $pidfile;
		my @pid = <$fd>;
		close $fd;

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
Function: getHTTPFarmPidFile

	Returns farm PID File

Parameters:
	farmname - Farm name

Returns:
	String - Pid file path

=cut

sub getHTTPFarmPidFile    # ($farm_name)
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my ( $farm_name ) = @_;

	my $piddir  = &getGlobalConfiguration( 'piddir' );
	my $pidfile = "$piddir\/$farm_name\_pound.pid";

	return $pidfile;
}

=begin nd
Function: getHTTPFarmVip

	Returns farm vip or farm port

Parameters:
	tag - requested parameter. The options are vip, for virtual ip or vipp, for virtual port
	farmname - Farm name

Returns:
	Scalar - return vip or port of farm or -1 on failure

=cut

sub getHTTPFarmVip    # ($info,$farm_name)
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
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

			if ( $info eq "vip" )  { $output = $vip[1]; }
			if ( $info eq "vipp" ) { $output = $vipp[1]; }
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
	port - virtual port. If the port is not sent, the port will not be changed
	farmname - Farm name

Returns:
	Integer - return 0 on success or different on failure

=cut

sub setHTTPFarmVirtualConf    # ($vip,$vip_port,$farm_name)
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my ( $vip, $vip_port, $farm_name ) = @_;

	my $farm_filename = &getFarmFile( $farm_name );
	my $stat          = 1;
	my $enter         = 2;

	my $lock_file = &getLockFile( $farm_name );
	my $lock_fh = &openlock( $lock_file, 'w' );

	require Tie::File;
	tie my @array, 'Tie::File', "$configdir\/$farm_filename";
	my $size = @array;

	for ( my $i = 0 ; $i < $size && $enter > 0 ; $i++ )
	{
		if ( $array[$i] =~ /Address/ )
		{
			if ( $array[$i] =~ s/.*Address\ .*/\tAddress\ $vip/ )
			{
				$stat = 0;
			}
			$enter--;
		}
		if ( $array[$i] =~ /Port/ and $vip_port )
		{
			if ( $array[$i] =~ s/.*Port\ .*/\tPort\ $vip_port/ )
			{
				$stat = 0;
			}
			$enter--;
		}
		last if ( !$enter );
	}

	untie @array;
	close $lock_fh;

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
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $farm_name = shift;

	my $pound         = &getGlobalConfiguration( 'pound' );
	my $farm_filename = &getFarmFile( $farm_name );
	my $pound_command = "$pound -f $configdir\/$farm_filename -c";

	my $run = `$pound_command 2>&1`;
	my $rc  = $?;

	if ( $rc or &debug() )
	{
		my $message = $rc ? 'failed' : 'running';
		&zenlog( "$message: $pound_command", "error", "LSLB" );
		&zenlog( "output: $run ",            "error", "LSLB" );
	}

	return $rc;
}

=begin nd
Function: getHTTPFarmConfigErrorMessage

	This function return a message to know what parameter is not correct in a HTTP farm

Parameters:
	farmname - Farm name

Returns:
	Scalar - If there is an error, it returns a message, else it returns a blank string

=cut

sub getHTTPFarmConfigErrorMessage    # ($farm_name)
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $farm_name = shift;

	my $pound         = &getGlobalConfiguration( 'pound' );
	my $farm_filename = &getFarmFile( $farm_name );
	my $pound_command = "$pound -f $configdir\/$farm_filename -c";

	my @run = `$pound_command 2>&1`;
	my $rc  = $?;

	return "" unless ( $rc );

	shift @run if ( $run[0] =~ /starting\.\.\./ );
	chomp @run;
	my $msg;

	&zenlog( "Error checking $configdir\/$farm_filename." );
	&zenlog( $run[0], "Error", "http" );

	return "Error loading waf configuration" if ( $run[0] =~ /waf/i );

	$run[0] =~ / line (\d+): /;
	my $line_num = $1;

	# get line
	my ( $farm_name, $service ) = @_;
	my $file_id = 0;
	my $file_line;
	my $srv;

	open my $fileconf, '<', "$configdir/$farm_filename";

	foreach my $line ( <$fileconf> )
	{
		if ( $line =~ /^\tService \"(.+)\"/ ) { $srv = $1; }
		if ( $file_id == $line_num - 1 )
		{
			$file_line = $line;
			last;
		}
		$file_id++;
	}

	close $fileconf;

# examples of error msg
#	AAAhttps, /usr/local/zevenet/config/AAAhttps_pound.cfg line 36: unknown directive
#	AAAhttps, /usr/local/zevenet/config/AAAhttps_pound.cfg line 40: SSL_CTX_use_PrivateKey_file failed - aborted
	$file_line =~ /\s*([\w-]+)/;
	my $param = $1;
	$msg = "Error in the configuration file";

	# parse line
	if ( $param eq "Cert" )
	{
		# return pem name if the pem file is not correct
		$file_line =~ /([^\/]+)\"$/;
		$msg = "Error loading the certificate: $1" if $1;
	}
	elsif ( $param )
	{
		$srv = "in the service $srv" if ( $srv );
		$msg = "Error in the parameter $param ${srv}";
	}
	elsif ( $param )
	{
		$srv = "in the service $srv" if ( $srv );
		$msg = "Error in the parameter $param ${srv}";
	}

	elsif ( &debug() )
	{
		$msg = $run[0];
	}

	&zenlog( "Error checking config file: $msg", 'debug' );

	return $msg;
}

sub getHTTPFarmStruct
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $farmname = shift;
	my $type = shift // &getFarmType( $farmname );

	require Zevenet::Farm::Core;
	require Zevenet::Farm::Base;

	# Output hash reference or undef if the farm does not exist.
	my $farm;

	return unless $farmname;

	my $vip   = &getFarmVip( "vip",  $farmname );
	my $vport = &getFarmVip( "vipp", $farmname ) + 0;
	my $status = &getFarmVipStatus( $farmname );

	my $connto          = 0 + &getFarmConnTO( $farmname );
	my $timeout         = 0 + &getHTTPFarmTimeout( $farmname );
	my $alive           = 0 + &getHTTPFarmBlacklistTime( $farmname );
	my $client          = 0 + &getFarmClientTimeout( $farmname );
	my $rewritelocation = 0 + &getFarmRewriteL( $farmname );
	my $httpverb        = 0 + &getFarmHttpVerb( $farmname );

	if    ( $rewritelocation == 0 ) { $rewritelocation = "disabled"; }
	elsif ( $rewritelocation == 1 ) { $rewritelocation = "enabled"; }
	elsif ( $rewritelocation == 2 ) { $rewritelocation = "enabled-backends"; }

	if    ( $httpverb == 0 ) { $httpverb = "standardHTTP"; }
	elsif ( $httpverb == 1 ) { $httpverb = "extendedHTTP"; }
	elsif ( $httpverb == 2 ) { $httpverb = "standardWebDAV"; }
	elsif ( $httpverb == 3 ) { $httpverb = "MSextWebDAV"; }
	elsif ( $httpverb == 4 ) { $httpverb = "MSRPCext"; }

	my $err414 = &getFarmErr( $farmname, "414" );
	my $err500 = &getFarmErr( $farmname, "500" );
	my $err501 = &getFarmErr( $farmname, "501" );
	my $err503 = &getFarmErr( $farmname, "503" );

	my $farm = {
				 status          => $status,
				 restimeout      => $timeout,
				 contimeout      => $connto,
				 resurrectime    => $alive,
				 reqtimeout      => $client,
				 rewritelocation => $rewritelocation,
				 httpverb        => $httpverb,
				 listener        => $type,
				 vip             => $vip,
				 vport           => $vport,
				 error500        => $err500,
				 error414        => $err414,
				 error501        => $err501,
				 error503        => $err503
	};

	# HTTPS parameters
	if ( $type eq "https" )
	{
		require Zevenet::Farm::HTTP::HTTPS;

		## Get farm certificate(s)
		my @cnames;

		if ( $eload )
		{
			@cnames = &eload(
							  module => 'Zevenet::Farm::HTTP::HTTPS::Ext',
							  func   => 'getFarmCertificatesSNI',
							  args   => [$farmname],
			);
		}
		else
		{
			@cnames = ( &getFarmCertificate( $farmname ) );
		}

		# Make struct array
		my @cert_list;

		for ( my $i = 0 ; $i < scalar @cnames ; $i++ )
		{
			push @cert_list, { file => $cnames[$i], id => $i + 1 };
		}

		## Get cipher set
		my $ciphers = &getFarmCipherSet( $farmname );

		# adapt "ciphers" to required interface values
		if ( $ciphers eq "cipherglobal" )
		{
			$ciphers = "all";
		}
		elsif ( $ciphers eq "cipherssloffloading" )
		{
			$ciphers = "ssloffloading";
		}
		elsif ( $ciphers eq "cipherpci" )
		{
			$ciphers = "highsecurity";
		}
		else
		{
			$ciphers = "customsecurity";
		}

		## All HTTPS parameters
		$farm->{ certlist } = \@cert_list;
		$farm->{ ciphers }  = $ciphers;
		$farm->{ cipherc }  = &getFarmCipherList( $farmname );
		$farm->{ disable_sslv2 } =
		  ( &getHTTPFarmDisableSSL( $farmname, "SSLv2" ) ) ? "true" : "false";
		$farm->{ disable_sslv3 } =
		  ( &getHTTPFarmDisableSSL( $farmname, "SSLv3" ) ) ? "true" : "false";
		$farm->{ disable_tlsv1 } =
		  ( &getHTTPFarmDisableSSL( $farmname, "TLSv1" ) ) ? "true" : "false";
		$farm->{ disable_tlsv1_1 } =
		  ( &getHTTPFarmDisableSSL( $farmname, "TLSv1_1" ) ) ? "true" : "false";
		$farm->{ disable_tlsv1_2 } =
		  ( &getHTTPFarmDisableSSL( $farmname, "TLSv1_2" ) ) ? "true" : "false";
	}

	if ( $eload )
	{
		$farm = &eload(
						module => 'Zevenet::Farm::HTTP::Ext',
						func   => 'get_http_farm_ee_struct',
						args   => [$farmname, $farm],
		);
	}

	return $farm;
}

sub getHTTPVerbCode
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $verbs_set = shift;

	# Default output value in case of missing verb set
	my $verb_code;

	my %http_verbs = (
					   standardHTTP   => 0,
					   extendedHTTP   => 1,
					   standardWebDAV => 2,
					   MSextWebDAV    => 3,
					   MSRPCext       => 4,
	);

	if ( exists $http_verbs{ $verbs_set } )
	{
		$verb_code = $http_verbs{ $verbs_set };
	}

	return $verb_code;
}

######### Pound Config

# Reading

sub parsePoundConfig
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my ( $file ) = @_;

	my @lines = split /\n/, $file;
	chomp @lines;

	my @farm_lines     = ();    # block 1
	my @listener_lines = ();    # block 2
	my @services_lines = ();    # block 3
	my $block          = 1;
	my $listener;

	# Split config in 3 blocks: farm, listener and services
	for my $line ( @lines )
	{
		next unless $line;

		# only one listener is expected
		if ( $line =~ /^Listen(HTTPS?)/ ) { $block++; $listener = $1; next; }
		if ( $line =~ /#ZWACL-INI/ )      { $block++; next; }
		if ( $line =~ /#ZWACL-END/ )      { last; }

		push ( @farm_lines,     $line ) if $block == 1;
		push ( @listener_lines, $line ) if $block == 2;
		push ( @services_lines, $line ) if $block == 3;
	}

	# Parse global farm parameters
	my %conf = map {
		if ( /^(\w+)\s+(\S.+)/ )
		{
			{ $1 => $2 }
		}
	} @farm_lines;
	&cleanHashValues( \%conf );
	delete $conf{ '' };

	# Parse listener parameters
	my %listener = map {
		if ( /^\t(\w+)\s+(.+)/ )
		{
			{ $1 => $2 }
		}
	} @listener_lines;
	delete $listener{ '' };
	&cleanHashValues( \%listener );
	$listener{ type } = lc $listener;

	# AddHeader
	my @add_header = map {
		if ( /^\tAddHeader "(.+)"$/ ) { $1 }
	} grep { /AddHeader/ } @listener_lines;
	$listener{ AddHeader } = \@add_header if scalar @add_header;

	# HeadRemove
	my @head_remove = map {
		if ( /^\tHeadRemove "(.+)"$/ ) { $1 }
	} grep { /HeadRemove/ } @listener_lines;
	$listener{ HeadRemove } = \@head_remove if scalar @head_remove;

	## HTTPS

	# Certificates
	my @certs = map {
		if ( /^\tCert "(.+)"$/ ) { $1 }
	} grep { /Cert/ } @listener_lines;
	$listener{ Cert } = \@certs if $listener{ type } eq 'https';

	# Disable HTTPS protocols
	# Warning: Doesn't work without grep
	my @disable = map {
		if ( /^\tDisable (.*)$/ ) { $1 }
	} grep { /Disable/ } @listener_lines;
	$listener{ Disable } = \@disable if $listener{ type } eq 'https';

	$conf{ listeners }[0] = \%listener;

	## Parse services
	my $svc_r;
	my $svc_name;
	my $svc_id = 0;
	my @svc_lines;

	for my $line ( @services_lines )
	{
		# Detect the beginnig of a service block
		if ( $line =~ /^\tService "(.+)"$/ )
		{
			$svc_name  = $1;
			@svc_lines = ();
			$svc_r     = {};
			next;
		}

		# Detect the end of a service block and parse the block
		if ( $line =~ /^\tEnd$/ )
		{
			# Parse service paremeters
			%$svc_r = map {
				if ( /^\t\t(\S+)\ (\S.+)$/ )
				{
					{ $1 => $2 }
				}
			} @svc_lines;

			# Clean up empty parameters.
			# FIXME: With a better parsing this should not be necessary
			delete $svc_r->{ '' };

			# Remove commented service parameters
			for my $key ( keys %{ $svc_r } )
			{
				delete $svc_r->{ $key } if $key =~ /^#/;
			}

			## Backends blocks
			my $bb;      # 'In Backend Block' flag
			my $be_r;    # Backend hash reference
			my @be = (); # List of backends

			# Session block
			my $sb;      # 'In Session Block' flag
			my $se_r;    # Session hash reference

			for my $line ( @svc_lines )
			{
				# Backends blocks
				if ( $line =~ /^\t\tBackEnd$/ ) { $bb++; $be_r = {}; next; }
				if ( $line =~ /^\t\t\t(\w+) (.+)$/ && $bb ) { $be_r->{ $1 } = $2; next; }
				if ( $line =~ /^\t\t\tHTTPS$/ && $bb ) { $be_r->{ 'HTTPS' } = undef; next; }
				if ( $line =~ /^\t\tEnd$/ && $bb )
				{
					$bb = 0;
					&cleanHashValues( $be_r );
					push @be, $be_r;
					next;
				}

				# Session block
				if ( $line =~ /^\t\tSession$/ ) { $sb++; $se_r = {}; next; }
				if ( $line =~ /^\t\t\t(\w+) (\S.+)$/ && $sb ) { $se_r->{ $1 } = $2; next; }
				if ( $line =~ /^\t\tEnd$/ && $sb )
				{
					$sb = 0;
					&cleanHashValues( $se_r );
					next;
				}
			}

			# Backend Cookie
			if ( exists $svc_r->{ BackendCookie } )
			{
				$svc_r->{ BackendCookie } =~ /^"(.+)" "(.+)" "(.+)" ([0-9]+)$/;
				$svc_r->{ BackendCookie } = {
											  name   => $1,
											  domain => $2,
											  path   => $3,
											  age    => $4 + 0,
				};
			}

			# Populate service hash
			$svc_r->{ name }     = $svc_name;
			$svc_r->{ Session }  = $se_r if $se_r;
			$svc_r->{ backends } = \@be;

			&cleanHashValues( $svc_r );

			# Add service to listener
			$conf{ listeners }[0]{ services }[$svc_id++] = $svc_r;
			next;
		}

		# Every line of a service block is stored
		push @svc_lines, $line;
	}

	return \%conf;
}

sub getPoundConf
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my ( $farm ) = @_;

	require Zevenet::Config;
	require Zevenet::System;
	require Zevenet::Farm::Core;

	my $farmfile  = &getFarmFile( $farm );
	my $configdir = &getGlobalConfiguration( 'configdir' );

	my $file = &slurpFile( "$configdir/$farmfile" );

	return &parsePoundConfig( $file );
}

# Writing

my $svc_defaults = {
					 DynScale      => 1,
					 BackendCookie => '"ZENSESSIONID" "domainname.com" "/" 0',
					 HeadRequire   => '""',
					 Url           => '""',
					 Redirect      => '""',
					 StrictTransportSecurity => 21600000,
};

sub print_backends
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my ( $be_list ) = @_;

	my $be_list_str = '';

	for my $be ( @{ $be_list } )
	{
		my $single_be_str = "\t\tBackEnd\n";
		$single_be_str .= "\t\t\tHTTPS\n"                    if exists $be->{ HTTPS };
		$single_be_str .= "\t\t\tAddress $be->{ Address }\n";
		$single_be_str .= "\t\t\tPort $be->{ Port }\n";
		$single_be_str .= "\t\t\tTimeOut $be->{ TimeOut }\n" if exists $be->{ TimeOut };
		$single_be_str .= "\t\t\tPriority $be->{ Priority }\n"
		  if exists $be->{ Priority };
		$single_be_str .= "\t\tEnd\n";

		$be_list_str .= $single_be_str;
	}

	return "\t\t#BackEnd\n" . "\n" . $be_list_str . "\t\t#End\n";
}

sub print_session
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my ( $session_ref ) = @_;

	my $session_str = '';

	if ( defined $session_ref )
	{
		$session_str .= "\t\tSession\n";
		$session_str .= "\t\t\tType $session_ref->{ Type }\n";
		$session_str .= "\t\t\tTTL $session_ref->{ TTL }\n";
		$session_str .= "\t\t\tID \"$session_ref->{ ID }\"\n"
		  if exists $session_ref->{ ID };
		$session_str .= "\t\tEnd\n";
	}
	else
	{
		$session_str .= "\t\t#Session\n";
		$session_str .= "\t\t\t#Type nothing\n";
		$session_str .= "\t\t\t#TTL 120\n";
		$session_str .= "\t\t\t#ID \"sessionname\"\n";
		$session_str .= "\t\t#End\n";
	}

	return $session_str;
}

sub writePoundConfigToString
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my ( $conf ) = @_;

	my $listener      = $conf->{ listeners }[0];
	my $listener_type = uc $listener->{ type };

	my $global_str =
	  qq(######################################################################
##GLOBAL OPTIONS
User		"$conf->{ User }"
Group		"$conf->{ Group }"
Name		$conf->{ Name }
## allow PUT and DELETE also (by default only GET, POST and HEAD)?:
#ExtendedHTTP	0
## Logging: (goes to syslog by default)
##	0	no logging
##	1	normal
##	2	extended
##	3	Apache-style (common log format)
#LogFacility	local5
LogLevel 	0
## check timeouts:
Timeout		$conf->{ Timeout }
ConnTO		$conf->{ ConnTO }
Alive		$conf->{ Alive }
Client		$conf->{ Client }
ThreadModel	$conf->{ ThreadModel }
Control 	"$conf->{ Control }"
);

	if ( $listener_type eq 'HTTP' )
	{
		$global_str .= qq(#DHParams 	"/usr/local/zevenet/app/pound/etc/dh2048.pem"
#ECDHCurve	"prime256v1"
);
	}
	else
	{
		$global_str .= qq(DHParams 	"$conf->{ DHParams }"
ECDHCurve	"$conf->{ ECDHCurve }"
);
	}

	## Services
	my $services_print = '';

	for my $svc ( @{ $conf->{ listeners }[0]{ services } } )
	{
		my @item_list = qw(
		  DynScale
		  BackendCookie
		  HeadRequire
		  Url
		  Redirect
		  StrictTransportSecurity
		  Session
		  BackEnd
		);

		my $single_service_print = qq(\tService "$svc->{ name }"\n);

		my $https_be = 'False';
		$https_be = 'True'
		  if defined $svc->{ backends }[0] && exists $svc->{ backends }[0]{ HTTPS };

		$single_service_print .= qq(\t\t##$https_be##HTTPS-backend##\n);

		for my $i ( @item_list )
		{
			#
			my $exists = exists $svc->{ $i };

			my $prefix = $exists ? ''           : '#';
			my $value  = $exists ? $svc->{ $i } : $svc_defaults->{ $i };

			my $i_str;

			if ( $i eq 'Session' )
			{
				$i_str = &print_session( $svc->{ 'Session' } );
			}
			elsif ( $i eq 'BackEnd' )
			{
				$i_str =
				  exists $svc->{ 'backends' } ? &print_backends( $svc->{ 'backends' } ) : '';
			}
			elsif ( $i eq 'BackendCookie' )
			{
				if ( exists $svc->{ 'BackendCookie' }
					 && ref $svc->{ 'BackendCookie' } eq 'HASH' )
				{
					my $ckie   = $svc->{ 'BackendCookie' };
					my $values = qq("$ckie->{name}" "$ckie->{domain}" "$ckie->{path}" $ckie->{age});
					$i_str = qq(\t\tBackendCookie $values\n);
				}
				else
				{
					$i_str = '';
				}
			}
			else
			{
				$i_str = "\t\t${prefix}${i} $value\n";
			}

			$single_service_print .= $i_str;
		}

		$single_service_print .= "\tEnd\n";
		$services_print .= $single_service_print;
	}

	chomp $services_print;

	## Listener
	my $listener_str = qq(
#HTTP(S) LISTENERS
Listen${listener_type}
	Err414 "$listener->{ Err414 }"
	Err500 "$listener->{ Err500 }"
	Err501 "$listener->{ Err501 }"
	Err503 "$listener->{ Err503 }"
	Address $listener->{ Address }
	Port $listener->{ Port }
	xHTTP $listener->{ xHTTP }
	RewriteLocation $listener->{ RewriteLocation }
);

	# Include AddHeader params
	if ( exists $listener->{ AddHeader }
		 && ref $listener->{ AddHeader } eq 'ARRAY' )
	{
		for my $header ( @{ $listener->{ AddHeader } } )
		{
			$listener_str .= qq(\tAddHeader "$header"\n);
		}
	}

	# Include HeadRemove params
	if ( exists $listener->{ HeadRemove }
		 && ref $listener->{ HeadRemove } eq 'ARRAY' )
	{
		for my $header ( @{ $listener->{ HeadRemove } } )
		{
			$listener_str .= qq(\tHeadRemove "$header"\n);
		}
	}

	# Include https params
	if ( $listener_type eq 'HTTPS' )
	{
		$listener_str .= "\n";
		$listener_str .= qq(\tCert "$_"\n) for @{ $listener->{ Cert } };
		$listener_str .= qq(\tCiphers "$listener->{ Ciphers }"\n);
		$listener_str .= qq(\tDisable "$_"\n) for @{ $listener->{ Disable } };
		$listener_str .=
		  qq(\tSSLHonorCipherOrder "$listener->{ SSLHonorCipherOrder }"\n);
	}
	else
	{
		$listener_str .= qq(
	#Cert "/usr/local/zevenet/config/zencert.pem"
	#Ciphers "ALL"
	#Disable SSLv3
	#SSLHonorCipherOrder 1
);
	}

	# Include services and bottom of the configuration
	$listener_str .= qq(\t#ZWACL-INI

$services_print
	#ZWACL-END


	#Service "$conf->{ Name }"
		##False##HTTPS-backend##
		#DynScale 1
		#BackendCookie "ZENSESSIONID" "domainname.com" "/" 0
		#HeadRequire "Host: "
		#Url ""
		#Redirect ""
		#StrictTransportSecurity 21600000
		#Session
			#Type nothing
			#TTL 120
			#ID "sessionname"
		#End
		#BackEnd

		#End
	#End


End
);

	## Global configuration
	#~ my $out_str = "$global_str\n";
	#~ $out_str .= "$listener_str\n";

	#~ return $out_str;
	return "$global_str\n$listener_str";
}

sub cleanHashValues
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my ( $hash_ref ) = @_;

	for my $key ( keys %{ $hash_ref } )
	{
		# Convert digits to numeric type
		$hash_ref->{ $key } += 0 if ( $hash_ref->{ $key } =~ /^[0-9]+$/ );

		# Remove leading and trailing double quotes
		$hash_ref->{ $key } =~ s/^"|"$//g unless $key eq 'BackendCookie';
	}

	return $hash_ref if defined wantarray;
}

1;
