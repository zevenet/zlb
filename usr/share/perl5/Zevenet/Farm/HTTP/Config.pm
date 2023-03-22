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
	&zenlog( __FILE__ . q{:} . __LINE__ . q{:} . ( caller ( 0 ) )[3] . "( @_ )",
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

	while ( $i_f <= $array_count and $found eq "false" )
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
	&zenlog( __FILE__ . q{:} . __LINE__ . q{:} . ( caller ( 0 ) )[3] . "( @_ )",
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
	session - type of session: nothing, BACKENDCOOKIE, HEADER, URL, COOKIE, PARAM, BASIC or IP
	farmname - Farm name

Returns:
	Integer - Error code: 0 on success, or -1 on failure.

=cut

sub setHTTPFarmSessionType    # ($session,$farm_name)
{
	&zenlog( __FILE__ . q{:} . __LINE__ . q{:} . ( caller ( 0 ) )[3] . "( @_ )",
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
			if ( $found eq "true" and $line =~ "End" )
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
					 or $session eq "COOKIE"
					 or $session eq "HEADER" )
				{
					$contents[$i + 2] =~ s/#//g;
				}
				elsif ( $session eq "BACKENDCOOKIE" )
				{
					$contents[$i + 2] =~ s/#//g;
					$contents[$i + 3] =~ s/#//g;
					$contents[$i + 4] =~ s/#//g;
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
			if ( $found eq "true" and $line =~ "End" )
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
			if ( $line =~ "Path" )
			{
				$contents[$i] = "#$contents[$i]";
			}
			if ( $line =~ "Domain" )
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
	&zenlog( __FILE__ . q{:} . __LINE__ . q{:} . ( caller ( 0 ) )[3] . "( @_ )",
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

	while ( $i_f <= $array_count and $found eq "false" )
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
	&zenlog( __FILE__ . q{:} . __LINE__ . q{:} . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my ( $farm_name ) = @_;

	my $blacklist_time = -1;
	my $conf_file      = &getFarmFile( $farm_name );
	my $conf_path      = "$configdir/$conf_file";

	my $error = open ( my $fh, '<', $conf_path );
	if ( not $error )
	{
		&zenlog( "Could not open $conf_path: $!", "error" );
		return -1;
	}
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
		5. OptionsHTTP, add the verb OPTIONS to the set extendedHTTP.

Parameters:
	verb - accepted verbs: 0, 1, 2, 3 or 4
	farmname - Farm name

Returns:
	Integer - Error code: 0 on success, or -1 on failure.

=cut

sub setFarmHttpVerb    # ($verb,$farm_name)
{
	&zenlog( __FILE__ . q{:} . __LINE__ . q{:} . ( caller ( 0 ) )[3] . "( @_ )",
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

	while ( $i_f <= $array_count and $found eq "false" )
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
		5. OptionsHTTP, add the verb OPTIONS to the set extendedHTTP.

Parameters:
	farmname - Farm name

Returns:
	integer - return the verb set identier or -1 on failure.

=cut

sub getFarmHttpVerb    # ($farm_name)
{
	&zenlog( __FILE__ . q{:} . __LINE__ . q{:} . ( caller ( 0 ) )[3] . "( @_ )",
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
	0 in case farm is not found - 1 in case it is found

=cut

sub setFarmListen    # ( $farm_name, $farmlisten )
{
	&zenlog( __FILE__ . q{:} . __LINE__ . q{:} . ( caller ( 0 ) )[3] . "( @_ )",
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

	while ( $i_f <= $array_count and $found eq "false" )
	{
		$i_f++;
		if ( $filefarmhttp[$i_f] =~ /^ListenHTTP/ and $flisten eq "http" )
		{
			$filefarmhttp[$i_f] = "ListenHTTP";
		}
		if ( $filefarmhttp[$i_f] =~ /^ListenHTTP/ and $flisten eq "https" )
		{
			$filefarmhttp[$i_f] = "ListenHTTPS";
		}

		#
		if ( $filefarmhttp[$i_f] =~ /.*Cert\ \"/ and $flisten eq "http" )
		{
			$filefarmhttp[$i_f] =~ s/Cert\ \"/#Cert\ \"/;
		}
		if ( $filefarmhttp[$i_f] =~ /.*Cert\ \"/ and $flisten eq "https" )
		{
			$filefarmhttp[$i_f] =~ s/#//g;
		}

		#
		if ( $filefarmhttp[$i_f] =~ /.*Ciphers\ \"/ and $flisten eq "http" )
		{
			$filefarmhttp[$i_f] =~ s/Ciphers\ \"/#Ciphers\ \"/;
		}
		if ( $filefarmhttp[$i_f] =~ /.*Ciphers\ \"/ and $flisten eq "https" )
		{
			$filefarmhttp[$i_f] =~ s/#//g;
		}

		# Enable 'Disable TLSv1, TLSv1_1 or TLSv1_2'
		if ( $filefarmhttp[$i_f] =~ /.*Disable TLSv1/ and $flisten eq "http" )
		{
			$filefarmhttp[$i_f] =~ s/Disable TLSv1/#Disable TLSv1/;
		}
		if ( $filefarmhttp[$i_f] =~ /.*Disable TLSv1/ and $flisten eq "https" )
		{
			$filefarmhttp[$i_f] =~ s/#//g;
		}
		elsif (     $filefarmhttp[$i_f] =~ /.*DisableTLSv1\d$/
				and $flisten eq "https" )
		{
			$filefarmhttp[$i_f] =~ s/#//g;
		}

		# Enable 'Disable SSLv3 or SSLv2'
		if ( $filefarmhttp[$i_f] =~ /.*Disable SSLv\d$/ and $flisten eq "http" )
		{
			$filefarmhttp[$i_f] =~ s/Disable SSLv/#Disable SSLv/;
		}
		if ( $filefarmhttp[$i_f] =~ /.*Disable SSLv\d$/ and $flisten eq "https" )
		{
			$filefarmhttp[$i_f] =~ s/#//g;
		}
		elsif (     $filefarmhttp[$i_f] =~ /.*DisableSSLv\d$/
				and $flisten eq "https" )
		{
			$filefarmhttp[$i_f] =~ s/#//g;
		}

		# Enable SSLHonorCipherOrder
		if (     $filefarmhttp[$i_f] =~ /.*SSLHonorCipherOrder/
			 and $flisten eq "http" )
		{
			$filefarmhttp[$i_f] =~ s/SSLHonorCipherOrder/#SSLHonorCipherOrder/;
		}
		if (     $filefarmhttp[$i_f] =~ /.*SSLHonorCipherOrder/
			 and $flisten eq "https" )
		{
			$filefarmhttp[$i_f] =~ s/#//g;
		}

		# Enable StrictTransportSecurity
		if (     $filefarmhttp[$i_f] =~ /.*StrictTransportSecurity/
			 and $flisten eq "http" )
		{
			$filefarmhttp[$i_f] =~ s/StrictTransportSecurity/#StrictTransportSecurity/;
		}
		if (     $filefarmhttp[$i_f] =~ /.*StrictTransportSecurity/
			 and $flisten eq "https" )
		{
			$filefarmhttp[$i_f] =~ s/#//g;
		}

		# Check for ECDHCurve cyphers
		if ( $filefarmhttp[$i_f] =~ /ECDHCurve/ and $flisten eq "http" )
		{
			$filefarmhttp[$i_f] =~ s/ECDHCurve/\#ECDHCurve/;
		}
		if ( $filefarmhttp[$i_f] =~ /ECDHCurve/ and $flisten eq "https" )
		{
			$filefarmhttp[$i_f] =~ s/#ECDHCurve/ECDHCurve/;
		}

		# Generate DH Keys if needed
		#my $dhfile = "$configdir\/$farm_name\_dh2048.pem";
		if ( $filefarmhttp[$i_f] =~ /^\#*DHParams/ and $flisten eq "http" )
		{
			$filefarmhttp[$i_f] =~ s/.*DHParams/\#DHParams/;
		}
		if ( $filefarmhttp[$i_f] =~ /^\#*DHParams/ and $flisten eq "https" )
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
	$found = $found eq "true" ? 1 : 0;
	return $found;
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

sub setFarmRewriteL    # ($farm_name,$rewritelocation,$path)
{
	&zenlog( __FILE__ . q{:} . __LINE__ . q{:} . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my ( $farm_name, $rewritelocation, $path ) = @_;

	my $farm_filename = &getFarmFile( $farm_name );

	&zenlog( "setting 'Rewrite Location' for $farm_name to $rewritelocation",
			 "info", "LSLB" );

	my $lock_file = &getLockFile( $farm_name );
	my $lock_fh = &openlock( $lock_file, 'w' );

	require Tie::File;
	tie my @filefarmhttp, 'Tie::File', "$configdir/$farm_filename";
	my $i_f         = -1;
	my $array_count = @filefarmhttp;
	my $found       = "false";

	while ( $i_f <= $array_count and $found eq "false" )
	{
		$i_f++;
		if ( $filefarmhttp[$i_f] =~ /RewriteLocation\ .*/ )
		{
			my $directive = "\tRewriteLocation $rewritelocation";
			if ( &getGlobalConfiguration( "proxy_ng" ) eq "true" )
			{
				if ( $path )
				{
					$directive .= " 1";
				}
				else
				{
					$directive .= " 0";
				}
			}
			$filefarmhttp[$i_f] = $directive;
			$found = "true";
		}
	}

	untie @filefarmhttp;
	close $lock_fh;
	return;
}

=begin nd
Function: getFarmRewriteL

	Return RewriteLocation Header configuration HTTP and HTTPS farms

Parameters:
	farmname - Farm name

Returns:
	string - The possible values are: disabled, enabled, enabled-backends, enabled-path, enabled-backends-path.
	diabled by default.

=cut

sub getFarmRewriteL    # ($farm_name)
{
	&zenlog( __FILE__ . q{:} . __LINE__ . q{:} . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my ( $farm_name ) = @_;

	my $farm_filename = &getFarmFile( $farm_name );
	my $output        = "disabled";

	open my $fd, '<', "$configdir\/$farm_filename";
	my @file = <$fd>;
	close $fd;

	foreach my $line ( @file )
	{
		last if $line =~ /^\s*#ZWACL-INI\s*$/;
		if ( $line =~ /^\s*RewriteLocation\s+(\d)\s*(\d)?\s*$/ )
		{
			if ( $1 == 0 ) { $output = "disabled"; last; }
			elsif ( $1 == 1 ) { $output = "enabled"; }
			elsif ( $1 == 2 ) { $output = "enabled-backends"; }

			if ( &getGlobalConfiguration( "proxy_ng" ) eq "true" )
			{
				if ( not defined $2 or $2 == 1 ) { $output .= "-path"; }
			}
			last;
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
	&zenlog( __FILE__ . q{:} . __LINE__ . q{:} . ( caller ( 0 ) )[3] . "( @_ )",
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

	while ( $i_f <= $array_count and $found eq "false" )
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
	&zenlog( __FILE__ . q{:} . __LINE__ . q{:} . ( caller ( 0 ) )[3] . "( @_ )",
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
	&zenlog( __FILE__ . q{:} . __LINE__ . q{:} . ( caller ( 0 ) )[3] . "( @_ )",
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

	while ( $i_f <= $array_count and $found eq "false" )
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
	&zenlog( __FILE__ . q{:} . __LINE__ . q{:} . ( caller ( 0 ) )[3] . "( @_ )",
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
	&zenlog( __FILE__ . q{:} . __LINE__ . q{:} . ( caller ( 0 ) )[3] . "( @_ )",
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

	while ( $i_f <= $array_count and $found eq "false" )
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
	&zenlog( __FILE__ . q{:} . __LINE__ . q{:} . ( caller ( 0 ) )[3] . "( @_ )",
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

	Get the status of a farm, sessions and its backends through l7 proxy command.

Parameters:
	farmname - Farm name

Returns:
	array - Return proxyctl output

=cut

sub getHTTPFarmGlobalStatus    # ($farm_name)
{
	&zenlog( __FILE__ . q{:} . __LINE__ . q{:} . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my ( $farm_name ) = @_;

	my $proxyctl = &getGlobalConfiguration( 'proxyctl' );

	return
	  @{ &logAndGet( "$proxyctl -c \"/tmp/$farm_name\_proxy.socket\"", "array" ) };
}

=begin nd
Function: setFarmErr

	Configure a error message for http error: WAF, 414, 500, 501 or 503

Parameters:
	farmname - Farm name
	message - Message body for the error
	error_number - Number of error to set, the options are WAF, 414, 500, 501 or 503

Returns:
	Integer - Error code: 0 on success, or -1 on failure.

=cut

sub setFarmErr    # ($farm_name,$content,$nerr)
{
	&zenlog( __FILE__ . q{:} . __LINE__ . q{:} . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my ( $farm_name, $content, $nerr ) = @_;

	my $output = -1;

	&zenlog( "Setting 'Err $nerr' for $farm_name farm http", "info", "LSLB" );

	if ( -e "$configdir\/$farm_name\_Err$nerr.html" and $nerr ne "" )
	{
		$output = 0;
		my @err = split ( "\n", "$content" );
		my $fd = &openlock( "$configdir\/$farm_name\_Err$nerr.html", 'w' );

		foreach my $line ( @err )
		{
			$line =~ s/\r$//;
			print $fd "$line\n";
			$output = ( $? or $output );
		}

		close $fd;
	}

	return $output;
}

=begin nd
Function: getFarmErr

	Return the error message for a http error: WAF, 414, 500, 501 or 503

Parameters:
	farmname - Farm name
	error_number - Number of error to set, the options are WAF, 414, 500, 501 or 503

Returns:
	Array - Message body for the error

=cut

# Only http function
sub getFarmErr    # ($farm_name,$nerr)
{
	&zenlog( __FILE__ . q{:} . __LINE__ . q{:} . ( caller ( 0 ) )[3] . "( @_ )",
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
Function: setHTTPFarmConfErrFile

	Comment or uncomment an error config file line from the proxy config file.

Parameters:
	enabled - true to uncomment the line ( or to add if it doesn't exist)
		or false to comment the line.
	farmname - Farm name
	err - error file: WAF, 414, 500 ...

Returns:
	None

=cut

sub setHTTPFarmConfErrFile    # ($enabled, $farm_name, $err)
{
	&zenlog( __FILE__ . q{:} . __LINE__ . q{:} . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my ( $enabled, $farm_name, $err ) = @_;
	require Zevenet::Farm::Core;
	my $farm_filename = &getFarmFile( $farm_name );
	my $i             = -1;
	my $found         = 0;                            # Error line was found

	require Tie::File;
	tie my @filefarmhttp, 'Tie::File', "$configdir/$farm_filename";
	foreach my $line ( @filefarmhttp )
	{
		$i++;
		if ( $enabled eq "true" )
		{
			if ( $line =~ /^.*Err$err/ )
			{
				$line =~ s/#//;
				splice @filefarmhttp, $i, 1, $line;
				$found = 1;
				last;
			}
		}
		else
		{
			if ( $line =~ /^\s*Err$err/ )
			{
				splice @filefarmhttp, $i, 1;
				last;
			}
		}
	}
	if ( not $found and $enabled eq "true" )
	{
		$i = -1;
		foreach my $line ( @filefarmhttp )
		{
			$i++;
			if ( $line =~ /^\tErr414\s\"$configdir/ )
			{
				$line =
				  "\tErr$err \"$configdir" . "/" . $farm_name . "_Err$err.html\"\n" . $line;
				last;
			}
		}
	}
	untie @filefarmhttp;
	return;
}

=begin nd
Function: getHTTPFarmBootStatus

	Return the farm status at boot ZEVENET

Parameters:
	farmname - Farm name

Returns:
	scalar - return "down" if the farm not run at boot or "up" if the farm run at boot

=cut

sub getHTTPFarmBootStatus    # ($farm_name)
{
	&zenlog( __FILE__ . q{:} . __LINE__ . q{:} . ( caller ( 0 ) )[3] . "( @_ )",
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

	Set the farm status in the configuration file to boot ZEVENET process

Parameters:
	farmname - Farm name
	value - Write the boot status "up" or "down"

Returns:
	scalar - return "down" if the farm not run at boot or "up" if the farm run at boot

=cut

sub setHTTPFarmBootStatus    # ($farm_name, $value)
{
	&zenlog( __FILE__ . q{:} . __LINE__ . q{:} . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my ( $farm_name, $value ) = @_;

	my $farm_filename = &getFarmFile( $farm_name );

	my $lock_file = &getLockFile( $farm_name );
	my $lock_fh = &openlock( $lock_file, 'w' );

	require Tie::File;
	tie my @configfile, 'Tie::File', "$configdir\/$farm_filename";
	@configfile = grep { not /^\#down/ } @configfile;

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
	&zenlog( __FILE__ . q{:} . __LINE__ . q{:} . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my ( $farm_name ) = @_;

	my @pid    = &getHTTPFarmPid( $farm_name );
	my $output = -1;
	my $running_pid;
	$running_pid = kill ( 0, @pid ) if @pid;

	if ( @pid and $running_pid )
	{
		$output = "up";
	}
	else
	{
	   #~ unlink &getHTTPFarmPidFile( $farm_name ) if ( not @pid and not $running_pid );
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
	&zenlog( __FILE__ . q{:} . __LINE__ . q{:} . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my ( $farm_name ) = @_;

	my $socketdir = &getGlobalConfiguration( "socketdir" );
	return $socketdir . "/" . $farm_name . "_proxy.socket";
}

=begin nd
Function: getHTTPFarmPid

	Returns farm PID

Parameters:
	farmname - Farm name

Returns:
	Integer - return a list with the PIDs of the farm

=cut

sub getHTTPFarmPid    # ($farm_name)
{
	&zenlog( __FILE__ . q{:} . __LINE__ . q{:} . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my ( $farm_name ) = @_;

	my $piddir  = &getGlobalConfiguration( 'piddir' );
	my $pidfile = "$piddir\/$farm_name\_proxy.pid";

	my @pid = ();
	if ( -e $pidfile )
	{
		open my $fd, '<', $pidfile;
		@pid = <$fd>;
		close $fd;
	}

	return @pid;
}

=begin nd
Function: getHTTPFarmPidPound

	This function returns all the pids of a process looking for in the ps table.

Parameters:
	farmname - Farm name

Returns:
	array - list of pids

=cut

sub getHTTPFarmPidPound
{
	my $farm_name = shift;

	my $ps        = &getGlobalConfiguration( 'ps' );
	my $grep      = &getGlobalConfiguration( 'grep_bin' );
	my @pid       = ();
	my $farm_file = "$configdir/" . &getFarmFile( $farm_name );
	my $cmd       = "$ps aux | $grep '\\-f $farm_file' | $grep -v grep";

	my $out = &logAndGet( $cmd, 'array' );
	foreach my $l ( @{ $out } )
	{
		if ( $l =~ /^\s*[^\s]+\s+([^\s]+)\s/ )
		{
			push @pid, $1;
		}
	}

	return @pid;
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
	&zenlog( __FILE__ . q{:} . __LINE__ . q{:} . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my ( $farm_name ) = @_;

	my $piddir  = &getGlobalConfiguration( 'piddir' );
	my $pidfile = "$piddir\/$farm_name\_proxy.pid";

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
	&zenlog( __FILE__ . q{:} . __LINE__ . q{:} . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my ( $info, $farm_name ) = @_;

	my $farm_filename = &getFarmFile( $farm_name );
	my $output        = -1;
	my $i             = 0;
	my $lw            = 0;

	open my $fi, '<', "$configdir/$farm_filename";
	my @file = <$fi>;
	close $fi;

	foreach my $line ( @file )
	{
		if ( $line =~ /^ListenHTTP/ )
		{
			$lw = 1;
		}
		if ( $lw )
		{
			if ( $info eq "vip" and $line =~ /^\s+Address\s+(.*)/ ) { $output = $1 }

			if ( $info eq "vipp" and $line =~ /^\s+Port\s+(.*)/ ) { $output = $1 }

			last if ( $output ne -1 );
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
	&zenlog( __FILE__ . q{:} . __LINE__ . q{:} . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my ( $vip, $vip_port, $farm_name ) = @_;

	my $farm_filename = &getFarmFile( $farm_name );
	my $stat          = 1;
	my $enter         = 2;
	$enter-- if not $vip_port;

	my $prev_config = getFarmStruct( $farm_name );

	my $lock_file = &getLockFile( $farm_name );
	my $lock_fh = &openlock( $lock_file, 'w' );

	require Tie::File;
	tie my @array, 'Tie::File', "$configdir\/$farm_filename";
	my $size = @array;

	for ( my $i = 0 ; $i < $size and $enter > 0 ; $i++ )
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
		last if ( not $enter );
	}

	untie @array;
	close $lock_fh;

	# Finally, reload rules and source address
	if ( &getGlobalConfiguration( 'proxy_ng' ) eq "true" )
	{
		&doL7FarmRules( "reload", $farm_name, $prev_config )
		  if ( $prev_config->{ status } eq "up" );

		# reload source address maquerade
		require Zevenet::Farm::Config;
		&reloadFarmsSourceAddressByFarm( $farm_name );
	}

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
	&zenlog( __FILE__ . q{:} . __LINE__ . q{:} . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $farm_name = shift;

	my $proxy         = &getGlobalConfiguration( 'proxy' );
	my $farm_filename = &getFarmFile( $farm_name );
	my $proxy_command = "$proxy -f $configdir\/$farm_filename -c";

# do not use the function 'logAndGet' here is managing the error output and error code
	my $run = `$proxy_command 2>&1`;
	my $rc  = $?;

	if ( $rc or &debug() )
	{
		my $tag     = ( $rc ) ? 'error'  : 'debug';
		my $message = $rc     ? 'failed' : 'running';
		&zenlog( "$message: $proxy_command", $tag, "LSLB" );
		&zenlog( "output: $run ",            $tag, "LSLB" );
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
	&zenlog( __FILE__ . q{:} . __LINE__ . q{:} . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $farm_name = shift;
	my $service;

	my $proxy         = &getGlobalConfiguration( 'proxy' );
	my $farm_filename = &getFarmFile( $farm_name );
	my $proxy_command = "$proxy -f $configdir\/$farm_filename -c";

# do not use the function 'logAndGet' here is managing the error output and error code
	my @run = `$proxy_command 2>&1`;
	my $rc  = $?;

	return "" unless ( $rc );

	shift @run if ( $run[0] =~ /starting\.\.\./ );
	chomp @run;
	my $msg;

	&zenlog( "Error checking $configdir\/$farm_filename.", "Error", "http" );
	&zenlog( $run[0],                                      "Error", "http" );

	$run[0] = $run[1] if ( $run[0] =~ /waf/i );

	$run[0] =~ / line (\d+): /;
	my $line_num = $1;

	# get line
	( $farm_name, $service ) = @_;
	my $file_id = 0;
	my $file_line;
	my $srv;

	open my $fileconf, '<', "$configdir/$farm_filename";

	while ( my $line = <$fileconf> )
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
#	AAAhttps, /usr/local/zevenet/config/AAAhttps_proxy.cfg line 36: unknown directive
#	AAAhttps, /usr/local/zevenet/config/AAAhttps_proxy.cfg line 40: SSL_CTX_use_PrivateKey_file failed - aborted
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
	elsif ( $param eq "WafRules" )
	{
		# return waf rule name  if the waf rule file is not correct
		$file_line =~ /([^\/]+)\"$/;
		$msg = "Error loading the WafRuleSet: $1" if $1;
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
	&zenlog( __FILE__ . q{:} . __LINE__ . q{:} . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $farmname = shift;
	my $type = shift // &getFarmType( $farmname );

	require Zevenet::Farm::Core;
	require Zevenet::Farm::Base;

	my $proxy_ng = &getGlobalConfiguration( 'proxy_ng' );

	# Output hash reference or undef if the farm does not exist.
	my $farm;

	return $farm unless $farmname;

	my $vip   = &getFarmVip( "vip",  $farmname );
	my $vport = &getFarmVip( "vipp", $farmname ) + 0;
	my $status = &getFarmVipStatus( $farmname );

	my $connto          = 0 + &getFarmConnTO( $farmname );
	my $timeout         = 0 + &getHTTPFarmTimeout( $farmname );
	my $alive           = 0 + &getHTTPFarmBlacklistTime( $farmname );
	my $client          = 0 + &getFarmClientTimeout( $farmname );
	my $rewritelocation = &getFarmRewriteL( $farmname );
	my $httpverb        = 0 + &getFarmHttpVerb( $farmname );

	if    ( $httpverb == 0 ) { $httpverb = "standardHTTP"; }
	elsif ( $httpverb == 1 ) { $httpverb = "extendedHTTP"; }
	elsif ( $httpverb == 2 ) { $httpverb = "standardWebDAV"; }
	elsif ( $httpverb == 3 ) { $httpverb = "MSextWebDAV"; }
	elsif ( $httpverb == 4 ) { $httpverb = "MSRPCext"; }
	elsif ( $httpverb == 5 ) { $httpverb = "optionsHTTP"; }

	my $errWAF = &getFarmErr( $farmname, "WAF" );
	my $err414 = &getFarmErr( $farmname, "414" );
	my $err500 = &getFarmErr( $farmname, "500" );
	my $err501 = &getFarmErr( $farmname, "501" );
	my $err503 = &getFarmErr( $farmname, "503" );

	$farm = {
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
			  error503        => $err503,
			  name            => $farmname
	};
	# HTTPS parameters
	if ( $type eq "https" )
	{
		require Zevenet::Farm::HTTP::HTTPS;

		## Get farm certificate(s)
		my @cnames;
			@cnames = ( &getFarmCertificate( $farmname ) );
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

	$farm->{ logs } = &getHTTPFarmLogs( $farmname );
	require Zevenet::Farm::Config;
	$farm = &get_http_farm_headers_struct( $farmname, $farm );

	$farm->{ ignore_100_continue } = &getHTTPFarm100Continue( $farmname );

	return $farm;
}

sub getHTTPVerbCode
{
	&zenlog( __FILE__ . q{:} . __LINE__ . q{:} . ( caller ( 0 ) )[3] . "( @_ )",
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
					   optionsHTTP    => 5,
	);

	if ( exists $http_verbs{ $verbs_set } )
	{
		$verb_code = $http_verbs{ $verbs_set };
	}

	return $verb_code;
}

######### l7 proxy Config

# Reading

sub parseL7ProxyConfig
{
	&zenlog( __FILE__ . q{:} . __LINE__ . q{:} . ( caller ( 0 ) )[3] . "( @_ )",
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
	my %conf;

	# Parse global farm parameters
	foreach my $clines ( @farm_lines )
	{
		$conf{ $1 } = $2 if ( $clines =~ /^(\w+)\s+(\S.+)/ );
	}
	&cleanHashValues( \%conf );
	delete $conf{ '' };
	my %listener;
	my @add_header;
	my @head_remove;
	my @certs;
	my @disable;

	# Parse listener parameters
	foreach my $llines ( @listener_lines )
	{
		# Parse listener parameters
		$listener{ $1 } = $2 if ( $llines =~ /^\t(\w+)\s+(.+)/ );

		# AddHeader
		push ( @add_header, $1 )
		  if ( $llines =~ /AddHeader/ and $llines =~ /^\tAddHeader "(.+)"$/ );

		# Head Remove
		push ( @head_remove, $1 )
		  if ( $llines =~ /HeadRemove/ and $llines =~ /^\tHeadRemove "(.+)"$/ );

		# Certificates
		push ( @certs, $1 ) if ( $llines =~ /Cert/ and $llines =~ /^\tCert "(.+)"$/ );

		# Disable HTTPS protocols
		push ( @disable, $1 )
		  if ( $llines =~ /Disable/ and $llines =~ /^\tDisable (.*)$/ );
	}
	delete $listener{ '' };
	&cleanHashValues( \%listener );
	$listener{ type }       = lc $listener;
	$listener{ AddHeader }  = \@add_header if scalar @add_header;
	$listener{ HeadRemove } = \@head_remove if scalar @head_remove;

	## HTTPS

	# Certificates
	$listener{ Cert } = \@certs if $listener{ type } eq 'https';

	# Disable HTTPS protocols
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
			for my $service ( @svc_lines )
			{
				$svc_r->{ $1 } = $2 if ( $service =~ /^\t\t(\S+)\ (\S.+)$/ );
			}

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
				if ( $line =~ /^\t\t\t(\w+) (.+)$/ and $bb ) { $be_r->{ $1 } = $2; next; }
				if ( $line =~ /^\t\t\tHTTPS$/ and $bb ) { $be_r->{ 'HTTPS' } = undef; next; }
				if ( $line =~ /^\t\tEnd$/ and $bb )
				{
					$bb = 0;
					&cleanHashValues( $be_r );
					push @be, $be_r;
					next;
				}

				# Session block
				if ( $line =~ /^\t\tSession$/ ) { $sb++; $se_r = {}; next; }
				if ( $line =~ /^\t\t\t(\w+) (\S.+)$/ and $sb ) { $se_r->{ $1 } = $2; next; }
				if ( $line =~ /^\t\tEnd$/ and $sb )
				{
					$sb = 0;
					&cleanHashValues( $se_r );
					next;
				}
			}

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

sub getL7ProxyConf
{
	&zenlog( __FILE__ . q{:} . __LINE__ . q{:} . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my ( $farm ) = @_;

	require Zevenet::Config;
	require Zevenet::System;
	require Zevenet::Farm::Core;

	my $farmfile  = &getFarmFile( $farm );
	my $configdir = &getGlobalConfiguration( 'configdir' );

	my $file = &slurpFile( "$configdir/$farmfile" );

	return &parseL7ProxyConfig( $file );
}

# Writing
require Zevenet::Config;
my $proxy_ng = &getGlobalConfiguration( "proxy_ng" );
my $svc_defaults = {
					 DynScale                => 1,
					 HeadRequire             => '""',
					 Url                     => '""',
					 Redirect                => '""',
					 StrictTransportSecurity => 21_600_000,
};
$svc_defaults->{ BackendCookie } = '"ZENSESSIONID" "domainname.com" "/" 0'
  if $proxy_ng eq "false";

sub print_backends
{
	&zenlog( __FILE__ . q{:} . __LINE__ . q{:} . ( caller ( 0 ) )[3] . "( @_ )",
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
		$single_be_str .= "\t\t\tConnLimit $be->{ ConnLimit }\n"
		  if exists $be->{ ConnLimit };
		$single_be_str .= "\t\tEnd\n";

		$be_list_str .= $single_be_str;
	}

	return "\t\t#BackEnd\n" . "\n" . $be_list_str . "\t\t#End\n";
}

sub print_session
{
	&zenlog( __FILE__ . q{:} . __LINE__ . q{:} . ( caller ( 0 ) )[3] . "( @_ )",
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
		$session_str .= "\t\t\tPath \"$session_ref->{ Path }\"\n"
		  if exists $session_ref->{ Path };
		$session_str .= "\t\t\tDomain \"$session_ref->{ Domain }\"\n"
		  if exists $session_ref->{ Domain };
		$session_str .= "\t\tEnd\n";
	}
	else
	{
		$session_str .= "\t\t#Session\n";
		$session_str .= "\t\t\t#Type nothing\n";
		$session_str .= "\t\t\t#TTL 120\n";
		$session_str .=
		  $proxy_ng eq "false"
		  ? "\t\t\t#ID \"sessionname\"\n"
		  : "\t\t\t#ID \"ZENSESSIONID\"\n";
		$session_str .= "\t\t\t#Path \"/\"\n"                if ( $proxy_ng eq "true" );
		$session_str .= "\t\t\t#Domain \"domainname.com\"\n" if ( $proxy_ng eq "true" );
		$session_str .= "\t\t#End\n";
	}

	return $session_str;
}

sub writeL7ProxyConfigToString
{
	&zenlog( __FILE__ . q{:} . __LINE__ . q{:} . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my ( $conf ) = @_;

	my $listener      = $conf->{ listeners }[0];
	my $listener_type = uc $listener->{ type };
	my $backendcookie_line =
	  $proxy_ng eq "true"
	  ? undef
	  : '#BackendCookie "ZENSESSIONID" "domainname.com" "/" 0';
	my $session_line = $proxy_ng eq "true" ? "ZENSESSIONID" : "sessionname";
	my $path_line    = $proxy_ng eq "true" ? '#Path "/"'    : undef;
	my $domain_line = $proxy_ng eq "true" ? '#Domain "domainname.com"' : undef;

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
		$global_str .= qq(#DHParams 	"/usr/local/zevenet/app/zproxy/etc/dh2048.pem"
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
		  if defined $svc->{ backends }[0] and exists $svc->{ backends }[0]{ HTTPS };

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
					 and ref $svc->{ 'BackendCookie' } eq 'HASH' )
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
);
	$listener_str .= qq(
	ErrWAF "$listener->{ ErrWAF }"
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
		 and ref $listener->{ AddHeader } eq 'ARRAY' )
	{
		for my $header ( @{ $listener->{ AddHeader } } )
		{
			$listener_str .= qq(\tAddHeader "$header"\n);
		}
	}

	# Include HeadRemove params
	if ( exists $listener->{ HeadRemove }
		 and ref $listener->{ HeadRemove } eq 'ARRAY' )
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
		$backendcookie_line 		
		#HeadRequire "Host: "
		#Url ""
		#Redirect ""
		#StrictTransportSecurity 21600000
		#Session
			#Type nothing
			#TTL 120
			#ID "$session_line"
			$path_line
			$domain_line
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
	&zenlog( __FILE__ . q{:} . __LINE__ . q{:} . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my ( $hash_ref ) = @_;

	for my $key ( keys %{ $hash_ref } )
	{
		# Convert digits to numeric type
		$hash_ref->{ $key } += 0 if ( $hash_ref->{ $key } =~ /^[0-9]+$/ );

		# Remove leading and trailing double quotes
		$hash_ref->{ $key } =~ s/^"|"$//g unless $key eq 'BackendCookie';
	}

	return defined wantarray ? $hash_ref : undef;
}

=begin nd
Function: setFarmProxyNGConf

	It migrates the farm configuration file from old to new generation proxy and viceversa.

Parameters:
	proxy_mode - 'true' if migration occurs from old to new gen proxy, 'false' migration occurs
	from new to the older proxy version.
	farm_name - farm that will get its config file migrated.

Returns:
	Integer - return 0 on success or different on failure

=cut

sub setFarmProxyNGConf    # ($proxy_mode,$farm_name)
{
	&zenlog( __FILE__ . q{:} . __LINE__ . q{:} . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my ( $proxy_mode, $farm_name ) = @_;

	require Zevenet::Farm::HTTP::Backend;

	my $farm_filename = &getFarmFile( $farm_name );
	my $stat          = 0;

	my $lock_file = &getLockFile( $farm_name );
	my $lock_fh = &openlock( $lock_file, 'w' );

	require Tie::File;
	tie my @array, 'Tie::File', "$configdir\/$farm_filename";
	my @array_bak = @array;
	my @wafs;
	my $sw = 0;
	my $bw = 0;
	my $cookie_params;
	my $session_checker;

	if ( $proxy_mode eq "true" )
	{
		for ( my $i = 0 ; $i < @array ; $i++ )
		{
			if ( $array[$i] =~ /^\s+Service/ )
			{
				$sw = 1;
			}
			elsif ( $array[$i] =~ /^\s+BackEnd/ and $sw == 1 )
			{
				$bw = 1;
			}
			elsif ( $array[$i] =~ /^\tEnd/ and $sw == 1 and $bw == 0 )
			{
				$sw = 0;
			}
			elsif ( $array[$i] =~ /^\t\tEnd/ and $sw == 1 and $bw == 1 )
			{
				$bw = 0;
			}
			elsif ( $array[$i] =~ /^(User\s+\"(.+)\"|Group\s+\"(.+)\"|Name\s+(.+))$/ )
			{
				splice @array, $i, 1;
				$i--;
			}
			elsif ( $array[$i] =~ /^Control\s+\".+\"$/ )
			{
				splice @array, $i, 1;
				$i--;
			}
			elsif ( $array[$i] =~ /^ListenHTTPS?$/ )
			{
				$array[$i] .= "\n\tName\t$farm_name";
			}
			elsif ( $array[$i] =~ /^(\s*)(WafRules.*)/ )
			{
				push @wafs, "\t" . $2;
				splice @array, $i, 1;
				$i--;
			}
			elsif (
					$array[$i] =~ /\t\t(#?)BackendCookie\s\"(.+)\"\s\"(.+)\"\s\"(.+)\"\s(\d+)/ )
			{
				$cookie_params->{ enabled } = $1 ne "#" ? 1 : 0;
				$cookie_params->{ id }      = $2;
				$cookie_params->{ domain }  = $3;
				$cookie_params->{ path }    = $4;
				$cookie_params->{ ttl }     = $5;

				splice @array, $i, 1;
				$i--;
			}
			elsif ( $array[$i] =~ /^\t\t#?Session$/ )
			{
				if ( $sw == 1 and $bw == 0 )
				{
					$array[$i] =~ s/#// if $cookie_params->{ enabled } == 1;
					$session_checker = 1;
				}
			}
			elsif ( $array[$i] =~ /^\t\t\t#?Type/ )
			{
				if ( $sw == 1 and $bw == 0 )
				{
					$array[$i] = "\t\t\tType BACKENDCOOKIE" if $cookie_params->{ enabled } == 1;
				}
				else
				{
					$array[$i] = "\t\t\t#Type nothing";
				}
			}
			elsif ( $array[$i] =~ /^\t\t\t#?TTL/ )
			{
				if ( $sw == 1 and $bw == 0 )
				{
					$array[$i] = "\t\t\tTTL $cookie_params->{ ttl }"
					  if $cookie_params->{ enabled } == 1;
				}
				else
				{
					$array[$i] = "\t\t\t#TTL 120";
				}
			}
			elsif ( $array[$i] =~ /^(#)?(\s+#?ID\s+.*)$/ )
			{
				if ( $1 )
				{
					$array[$i] = $2;
				}
				if ( $sw == 1 and $bw == 0 )
				{
					if ( $cookie_params->{ enabled } == 1 )
					{
						$array[$i] = "\t\t\tID \"$cookie_params->{ id }\"";
						$array[$i] .= "\n\t\t\t#Path \"/\"\n\t\t\t#Domain \"domainname.com\"";
						$array[$i] =~ s/#Path "\/"/Path \"$cookie_params->{ path }\"/;
						$array[$i] =~
						  s/#Domain "domainname\.com"/Domain \"$cookie_params->{ domain }\"/;
					}
					else
					{
						$array[$i] .= "\n\t\t\t#Path \"/\"\n\t\t\t#Domain \"domainname.com\"";
					}
				}
				else
				{
					$array[$i] = "\t\t\t#ID \"ZENSESSIONID\"";
					$array[$i] .= "\n\t\t\t#Path \"/\"\n\t\t\t#Domain \"domainname.com\"";
				}
			}
			elsif ( $array[$i] =~ /^\t\t#?End$/ )
			{
				if ( $sw == 1 and $bw == 0 and $session_checker == 1 )
				{
					$array[$i] =~ s/#// if $cookie_params->{ enabled } eq 1;
					$session_checker = 0;
				}
			}
			elsif ( $array[$i] =~
				/^\s*(#?)(PinnedConnection|RoutingPolicy|RewriteLocation|AddHeader|AddResponseHeader|HeadRemove|RemoveResponseHeader|RewriteUrl|ReplaceHeader)/
			  )
			{
				if ( $sw == 1 )
				{
					$array[$i] =~ s/#//;
				}
				elsif ( $array[$i] =~ /^\s*(#?)(ReplaceHeader)/ )
				{
					$array[$i] =~ s/#//;
				}
			}
			if ( $bw == 1 )
			{
				$array[$i] =~ s/Priority/Weight/;
			}
		}
		for ( my $i = 0 ; $i < @array ; $i++ )
		{
			if ( $array[$i] =~ /#ZWACL-INI/ )
			{
				my $sizewaf = @wafs;
				splice @array, $i + 1, 0, @wafs;
				$i = $i + $sizewaf;
				last;
			}
		}

		untie @array;

		&migrateHTTPFarmLogs( $farm_name, $proxy_mode );
		require Zevenet::Farm::HTTP::Sessions;
		my $farm_sessions_filename = &getSessionsFileName( $farm_name );
		&setHTTPFarmConfErrFile( $proxy_mode, $farm_name, "WAF" );
		&setHTTPFarmBackendsMarks( $farm_name );
		if ( not -f "$farm_sessions_filename" )
		{
			open my $f_err, '>', "$farm_sessions_filename";
			close $f_err;
		}
		require Zevenet::Farm::Config;
		&reloadFarmsSourceAddressByFarm( $farm_name );
	}

	if ( $proxy_mode eq "false" )
	{
		my $dw  = 0;
		my $dw2 = 0;
		my $session_index;
		my $cookie_on = "false";

		for ( my $i = 0 ; $i < @array ; $i++ )
		{
			if ( $array[$i] =~ /^\s+Service/ )
			{
				$sw = 1;
			}
			elsif ( $array[$i] =~ /^\s+BackEnd/ and $sw == 1 )
			{
				$bw = 1;
			}
			elsif ( $array[$i] =~ /^\tEnd/ and $sw == 1 and $bw == 0 )
			{
				$sw = 0;
			}
			elsif ( $array[$i] =~ /^\t\tEnd/ and $sw == 1 and $bw == 1 )
			{
				$bw = 0;
			}
			elsif ( $array[$i] =~ /^\t\t#?DynScale/ and $sw == 1 and $bw == 0 )
			{
				$dw = $i;
			}
			elsif ( $array[$i] =~ /^\t\t#?DynScale/ and $sw == 0 and $bw == 0 )
			{
				$dw2 = $i;
			}
			elsif ( $array[$i] =~ /^##GLOBAL OPTIONS/ )
			{
				$array[$i] .= "\nUser\t\t\"root\"\nGroup\t\t\"root\"\nName\t\t$farm_name";
			}
			elsif ( $array[$i] =~ /^ThreadModel\s+.+$/ )
			{
				$array[$i] .= "\nControl \"/tmp/$farm_name\_proxy.socket\"";
			}
			elsif ( $array[$i] =~
				/^\s*(#?)(PinnedConnection|RoutingPolicy|RewriteLocation|AddHeader|AddResponseHeader|HeadRemove|RemoveResponseHeader|RewriteUrl|ReplaceHeader)/
			  )
			{
				if ( $sw == 1 )
				{
					if ( $1 ne "#" )
					{
						$array[$i] =~ s/$1/\t\t#$2/;
					}
				}
				elsif ( $array[$i] =~ /^\s*(#?)(ReplaceHeader)/ )
				{
					if ( $1 ne "#" )
					{
						$array[$i] =~ s/$1/\t#$2/;
					}
				}
				if ( $array[$i] =~ /^\s*(#?)RewriteLocation\s+(\d)/ )
				{
					if ( $1 ne "#" )
					{
						$array[$i] = "\tRewriteLocation $2";
					}
				}
			}
			elsif ( $array[$i] =~ /^\tName\s+(.+)$/ )
			{
				splice @array, $i, 1;
				$i--;
			}
			elsif ( $array[$i] =~ /^(\s*)(WafRules.*)/ )
			{
				push @wafs, $2;
				splice @array, $i, 1;
				$i--;
			}
			elsif ( $array[$i] =~ /^\t\t#?Session$/ and $sw == 1 )
			{
				$session_index   = $i;
				$session_checker = 1;
			}
			elsif ( $array[$i] =~ /^\t\t\t(#?)Type\sBACKENDCOOKIE/ )
			{
				$cookie_params->{ enabled } = $1 ne "#" ? 1 : 0;
				$array[$i] = "\t\t\t#Type nothing";
			}
			elsif ( $array[$i] =~ /^\t\t\t(#?)TTL\s(\d+)/ )
			{
				$cookie_params->{ ttl } = $2;
				if ( $cookie_params->{ enabled } )
				{
					$array[$i] = "\t\t\t#TTL 120";
				}
			}
			elsif ( $array[$i] =~ /^\t\t\t(#?)ID\s"(.+)"/ )
			{
				$cookie_params->{ id } = $2;
				if ( $cookie_params->{ enabled } or $2 eq "ZENSESSIONID" )
				{
					$array[$i] = "\t\t\t#ID \"sessionname\"";
				}
			}
			elsif ( $array[$i] =~ /^\t\t\t(#?)Path\s"(.+)"/ )
			{
				$cookie_params->{ path } = $2;
				splice @array, $i, 1;
				$i--;
			}
			elsif ( $array[$i] =~ /^\t\t\t(#?)Domain\s"(.+)"/ )
			{
				$cookie_params->{ domain } = $2;
				splice @array, $i, 1;
				$i--;
			}
			elsif ( $array[$i] =~ /^\t\tEnd$/ )
			{
				if ( ( $sw == 1 ) and ( $bw == 0 ) and ( $session_checker ) )
				{
					if ( $cookie_on eq "true" )
					{
						$array[$i] =~ s/End/#End/;
					}
					$cookie_on       = "false";
					$session_checker = 0;
				}
			}
			if ( $bw == 1 )
			{
				if ( $array[$i] =~ /Priority|ConnLimit/ )
				{
					splice @array, $i, 1;
					$i--;
				}
				else
				{
					# Replace Priority value with Weight value
					$array[$i] =~ s/Weight/Priority/;
				}
			}

			if (     exists $cookie_params->{ domain }
				 and $cookie_params->{ domain } ne ""
				 and $session_checker )
			{
				if ( $dw != 0 )
				{
					if ( $cookie_params->{ enabled } )
					{
						$array[$dw] .=
						  "\n\t\tBackendCookie \"$cookie_params->{ id }\" \"$cookie_params->{ domain }\" \"$cookie_params->{ path }\" $cookie_params->{ ttl }";
						$array[$session_index] =~ s/Session/#Session/;
					}
					else
					{
						$array[$dw] .=
						  "\n\t\t#BackendCookie \"ZENSESSIONID\" \"domainname.com\" \"/\" 0";
					}
					$cookie_on     = $cookie_params->{ enabled } ? "true" : "false";
					$cookie_params = undef;
					$dw            = 0;
				}
			}
			if ( $dw2 != 0 )
			{
				$array[$dw2] .=
				  "\n\t\t#BackendCookie \"ZENSESSIONID\" \"domainname.com\" \"/\" 0";
				$dw2 = 0;
			}
		}
		for ( my $i = 0 ; $i < @array ; $i++ )
		{
			if ( $array[$i] =~ /^#HTTP\(S\)\sLISTENERS$/ )
			{
				my $sizewaf = @wafs;
				splice @array, $i, 0, @wafs;
				$i = $i + $sizewaf;
				last;
			}
		}

		untie @array;

		&migrateHTTPFarmLogs( $farm_name, $proxy_mode );
		require Zevenet::Farm::HTTP::Sessions;
		my $farm_sessions_filename = &getSessionsFileName( $farm_name );
		&setHTTPFarmConfErrFile( $proxy_mode, $farm_name, "WAF" );
		&removeHTTPFarmBackendsMarks( $farm_name );

		if ( -f "$farm_sessions_filename" )
		{
			unlink "$farm_sessions_filename";
		}
	}

	if ( &getHTTPFarmConfigIsOK( $farm_name ) )
	{
		tie my @array, 'Tie::File', "$configdir\/$farm_filename";
		@array = @array_bak;
		untie @array;
		$stat = 1;
		&zenlog( "Error in $farm_name config file!", "error", "SYSTEM" );
	}
	else
	{
		$stat = 0;
	}

	close $lock_fh;

	return $stat;
}

=begin nd
Function: doL7FarmRules

	Created to operate with setBackendRule in order to start, stop or reload ip rules

Parameters:
	action - stop (delete all ip rules), start (create ip rules) or reload (delete old one stored in prev_farm_ref and create new)
	farm_name - the farm name.
	prev_farm_ref - farm ref of the old configuration

Returns:
	none - .

=cut

sub doL7FarmRules
{
	&zenlog( __FILE__ . q{:} . __LINE__ . q{:} . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $action        = shift;
	my $farm_name     = shift;
	my $prev_farm_ref = shift;

	return if &getGlobalConfiguration( 'mark_routing_L7' ) ne 'true';
	require Zevenet::Farm::HTTP::Config;
	my $farm_ref;
	$farm_ref->{ name } = $farm_name;
	$farm_ref->{ vip } = &getHTTPFarmVip( "vip", $farm_name );

	require Zevenet::Farm::Backend;
	require Zevenet::Farm::HTTP::Backend;
	require Zevenet::Farm::HTTP::Service;

	my @backends;
	foreach my $service ( &getHTTPFarmServices( $farm_name ) )
	{
		my $bckds = &getHTTPFarmBackends( $farm_name, $service, "false" );
		push @backends, @{ $bckds };
	}

	foreach my $backend ( @backends )
	{
		my $mark = sprintf ( "0x%x", $backend->{ tag } );
		&setBackendRule( "del", $farm_ref, $mark )
		  if ( $action eq "stop" );
		&setBackendRule( "del", $prev_farm_ref, $mark )
		  if ( $action eq "reload" );
		&setBackendRule( "add", $farm_ref, $mark )
		  if ( $action eq "start" or $action eq "reload" );
	}
	return;
}

# Add request headers

=begin nd
Function: getHTTPAddReqHeader

	Get a list with all the http headers are added by the farm

Parameters:
	farmname - Farm name

Returns:
	Array ref - headers list

=cut

sub getHTTPAddReqHeader    # ($farm_name,$service)
{
	&zenlog( __FILE__ . q{:} . __LINE__ . q{:} . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my ( $farm_name ) = @_;
	return &get_http_farm_headers_struct( $farm_name )->{ addheader };
}

=begin nd
Function: addHTTPHeadremove

	The HTTP farm will add the header to the http communication

Parameters:
	farmname - Farm name
	header - Header to add

Returns:
	Integer - Error code: 0 on success or 1 on failure

=cut

sub addHTTPAddheader    # ($farm_name, $header, $header_ind)
{
	&zenlog( __FILE__ . q{:} . __LINE__ . q{:} . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my ( $farm_name, $header ) = @_;

	require Zevenet::Farm::Core;
	my $ffile = &getFarmFile( $farm_name );
	my $errno = 1;

	require Zevenet::Lock;
	&ztielock( \my @fileconf, "$configdir/$ffile" );

	my $index        = 0;
	my $rewrite_flag = 0;    # it is used to add HeadRemove before than AddHeader
	foreach my $line ( @fileconf )
	{
		if ( $line =~ /^[#\s]*Service \"/ ) { last; }
		if ( $line =~ /[#\s]*RewriteLocation/ )
		{
			$rewrite_flag = 1;
		}
		elsif ( $rewrite_flag )
		{
			# put new headremove before than last one
			if ( $line !~
				 /^[#\s]*(?:AddHeader|HeadRemove|AddResponseHeader|RemoveResponseHead)\s+"/
				 and $rewrite_flag )

			{
				# example: AddHeader "header: to add"
				splice @fileconf, $index, 0, "\tAddHeader \"$header\"";
				$errno = 0;
				last;
			}
		}
		$index++;
	}
	untie @fileconf;

	&zenlog( "Could not add AddHeader" ) if $errno;

	return $errno;
}

=begin nd
Function: modifyHTTPAddheader

	Modify an AddHeader directive from the given farm

Parameters:
	farmname - Farm name
	header - Header to add
	header_ind - directive index

Returns:
	Integer - Error code: 0 on success or 1 on failure

=cut

sub modifyHTTPAddheader    # ($farm_name, $header, $header_ind)
{
	&zenlog( __FILE__ . q{:} . __LINE__ . q{:} . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my ( $farm_name, $header, $header_ind ) = @_;

	require Zevenet::Farm::Core;
	my $ffile = &getFarmFile( $farm_name );
	my $errno = 1;

	require Zevenet::Lock;
	&ztielock( \my @fileconf, "$configdir/$ffile" );

	my $index = 0;
	my $ind   = 0;
	foreach my $line ( @fileconf )
	{
		if ( $line =~ /^[#\s]*Service \"/ ) { last; }
		if ( $line =~ /^\s*AddHeader\s+"/ )
		{
			# put new headremove before than last one
			if ( $header_ind == $ind )
			{
				splice @fileconf, $index, 1, "\tAddHeader \"$header\"";
				$errno = 0;
				last;
			}
			else
			{
				$ind++;
			}
		}
		$index++;
	}
	untie @fileconf;

	&zenlog( "Could not modify AddHeader" ) if $errno;

	return $errno;
}

=begin nd
Function: delHTTPAddheader

	Delete a directive "AddHeader".

Parameters:
	farmname - Farm name
	index - Header index

Returns:
	Integer - Error code: 0 on success or 1 on failure

=cut

sub delHTTPAddheader    # ($farm_name, $header_ind)
{
	&zenlog( __FILE__ . q{:} . __LINE__ . q{:} . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my ( $farm_name, $header_ind ) = @_;

	require Zevenet::Farm::Core;
	my $ffile = &getFarmFile( $farm_name );
	my $errno = 1;

	require Zevenet::Lock;
	&ztielock( \my @fileconf, "$configdir/$ffile" );

	my $index = 0;
	my $ind   = 0;
	foreach my $line ( @fileconf )
	{
		if ( $line =~ /^[#\s]*Service \"/ ) { last; }
		if ( $line =~ /^\s*AddHeader\s+"/ )
		{
			if ( $header_ind == $ind )
			{
				$errno = 0;
				splice @fileconf, $index, 1;
				last;
			}
			else
			{
				$ind++;
			}
		}
		$index++;
	}
	untie @fileconf;

	&zenlog( "Could not remove HeadRemove" ) if $errno;

	return $errno;
}

# remove request header

=begin nd
Function: getHTTPRemReqHeader

	Get a list with all the http headers are added by the farm

Parameters:
	farmname - Farm name

Returns:
	Array ref - headers list

=cut

sub getHTTPRemReqHeader    # ($farm_name,$service)
{
	&zenlog( __FILE__ . q{:} . __LINE__ . q{:} . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my ( $farm_name ) = @_;
	return &get_http_farm_headers_struct( $farm_name )->{ headremove };
}

=begin nd
Function: addHTTPHeadremove

	Add a directive "HeadRemove". The HTTP farm will remove the header that match with the sentence

Parameters:
	farmname - Farm name
	header - Header to add

Returns:
	Integer - Error code: 0 on success or 1 on failure

=cut

sub addHTTPHeadremove    # ($farm_name, $header)
{
	&zenlog( __FILE__ . q{:} . __LINE__ . q{:} . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my ( $farm_name, $header ) = @_;

	require Zevenet::Farm::Core;
	my $ffile = &getFarmFile( $farm_name );
	my $errno = 1;

	require Zevenet::Lock;
	&ztielock( \my @fileconf, "$configdir/$ffile" );

	my $index        = 0;
	my $rewrite_flag = 0;    # it is used to add HeadRemove before than AddHeader
	foreach my $line ( @fileconf )
	{
		if ( $line =~ /^[#\s]*Service \"/ ) { last; }
		if ( $line =~ /[#\s]*RewriteLocation/ )
		{
			$rewrite_flag = 1;
		}
		elsif ( $rewrite_flag )
		{
			# put new headremove after than last one
			if ( $line !~
				 /^[#\s]*(?:AddHeader|HeadRemove|AddResponseHeader|RemoveResponseHead)\s+"/
				 and $rewrite_flag )
			{
				# example: AddHeader "header: to add"
				splice @fileconf, $index, 0, "\tHeadRemove \"$header\"";
				$errno = 0;
				last;
			}
		}
		$index++;
	}
	untie @fileconf;

	&zenlog( "Could not add HeadRemove" ) if $errno;

	return $errno;
}

=begin nd
Function: modifyHTTPHeadremove

	Modify an Headremove directive from the given farm

Parameters:
	farmname    - Farm name
	header      - Header to add
	header_ind - directive index

Returns:
	Integer - Error code: 0 on success or 1 on failure

=cut

sub modifyHTTPHeadremove    # ($farm_name, $header, $header_ind)
{
	&zenlog( __FILE__ . q{:} . __LINE__ . q{:} . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my ( $farm_name, $header, $header_ind ) = @_;

	require Zevenet::Farm::Core;
	my $ffile = &getFarmFile( $farm_name );
	my $errno = 1;

	require Zevenet::Lock;
	&ztielock( \my @fileconf, "$configdir/$ffile" );

	my $index = 0;
	my $ind   = 0;
	foreach my $line ( @fileconf )
	{
		if ( $line =~ /^[#\s]*Service \"/ ) { last; }
		if ( $line =~ /^\s*HeadRemove\s+"/ )
		{
			# put new headremove before than last one
			if ( $header_ind == $ind )
			{
				splice @fileconf, $index, 1, "\tHeadRemove \"$header\"";
				$errno = 0;
				last;
			}
			else
			{
				$ind++;
			}
		}
		$index++;
	}
	untie @fileconf;

	&zenlog( "Could not modify HeadRemove" ) if $errno;

	return $errno;
}

=begin nd
Function: delHTTPHeadremove

	Delete a directive "HeadRemove".

Parameters:
	farmname - Farm name
	index - Header index

Returns:
	Integer - Error code: 0 on success or 1 on failure

=cut

sub delHTTPHeadremove    # ($farm_name,$service,$code)
{
	&zenlog( __FILE__ . q{:} . __LINE__ . q{:} . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my ( $farm_name, $header_ind ) = @_;

	require Zevenet::Farm::Core;
	my $ffile = &getFarmFile( $farm_name );
	my $errno = 1;

	require Zevenet::Lock;
	&ztielock( \my @fileconf, "$configdir/$ffile" );

	my $index = 0;
	my $ind   = 0;
	foreach my $line ( @fileconf )
	{
		if ( $line =~ /^[#\s]*Service \"/ ) { last; }
		if ( $line =~ /^\s*HeadRemove\s+"/ )
		{
			if ( $header_ind == $ind )
			{
				$errno = 0;
				splice @fileconf, $index, 1;
				last;
			}
			else
			{
				$ind++;
			}
		}
		$index++;
	}
	untie @fileconf;

	&zenlog( "Could not remove HeadRemove" ) if $errno;

	return $errno;
}

# Add response headers

=begin nd
Function: getHTTPAddRespHeader

	Get a list with all the http headers that load balancer will add to the backend repsonse

Parameters:
	farmname - Farm name

Returns:
	Array ref - headers list

=cut

sub getHTTPAddRespHeader    # ($farm_name,$service)
{
	&zenlog( __FILE__ . q{:} . __LINE__ . q{:} . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my ( $farm_name ) = @_;
	return &get_http_farm_headers_struct( $farm_name )->{ addresponseheader };
}

=begin nd
Function: addHTTPAddRespheader

	The HTTP farm will add the header to the http response from the backend to the client

Parameters:
	farmname - Farm name
	header - Header to add

Returns:
	Integer - Error code: 0 on success or 1 on failure

=cut

sub addHTTPAddRespheader    # ($farm_name,$service,$code)
{
	&zenlog( __FILE__ . q{:} . __LINE__ . q{:} . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my ( $farm_name, $header ) = @_;

	require Zevenet::Farm::Core;
	my $ffile = &getFarmFile( $farm_name );
	my $errno = 1;

	require Zevenet::Lock;
	&ztielock( \my @fileconf, "$configdir/$ffile" );

	my $index        = 0;
	my $rewrite_flag = 0;    # it is used to add HeadRemove before than AddHeader
	foreach my $line ( @fileconf )
	{
		if ( $line =~ /^[#\s]*Service \"/ ) { last; }
		if ( $line =~ /[#\s]*RewriteLocation/ )
		{
			$rewrite_flag = 1;
		}
		elsif ( $rewrite_flag )
		{
			# put new headremove before than last one
			if ( $line !~
				 /^[#\s]*(?:AddHeader|HeadRemove|AddResponseHeader|RemoveResponseHead)\s+"/
				 and $rewrite_flag )
			{
				# example: AddHeader "header: to add"
				splice @fileconf, $index, 0, "\tAddResponseHeader \"$header\"";
				$errno = 0;
				last;
			}
		}
		$index++;
	}
	untie @fileconf;

	&zenlog( "Could not add AddResponseHeader" ) if $errno;

	return $errno;
}

=begin nd
Function: modifyHTTPAddRespheader

	Modify an AddResponseHeader directive from the given farm

Parameters:
	farmname    - Farm name
	header      - Header to add
	header_ind - directive index

Returns:
	Integer - Error code: 0 on success or 1 on failure

=cut

sub modifyHTTPAddRespheader    # ($farm_name, $header, $header_ind)
{
	&zenlog( __FILE__ . q{:} . __LINE__ . q{:} . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my ( $farm_name, $header, $header_ind ) = @_;

	require Zevenet::Farm::Core;
	my $ffile = &getFarmFile( $farm_name );
	my $errno = 1;

	require Zevenet::Lock;
	&ztielock( \my @fileconf, "$configdir/$ffile" );

	my $index = 0;
	my $ind   = 0;
	foreach my $line ( @fileconf )
	{
		if ( $line =~ /^[#\s]*Service \"/ ) { last; }
		if ( $line =~ /^\s*AddResponseHeader\s+"/ )
		{
			# put new headremove before than last one
			if ( $header_ind == $ind )
			{
				splice @fileconf, $index, 1, "\tAddResponseHeader \"$header\"";
				$errno = 0;
				last;
			}
			else
			{
				$ind++;
			}
		}
		$index++;
	}
	untie @fileconf;

	&zenlog( "Could not modify AddResponseHeader" ) if $errno;

	return $errno;
}

=begin nd
Function: delHTTPAddRespheader

	Delete a directive "AddResponseHeader from the farm config file".

Parameters:
	farmname - Farm name
	index - Header index

Returns:
	Integer - Error code: 0 on success or 1 on failure

=cut

sub delHTTPAddRespheader    # ($farm_name,$service,$code)
{
	&zenlog( __FILE__ . q{:} . __LINE__ . q{:} . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my ( $farm_name, $header_ind ) = @_;

	require Zevenet::Farm::Core;
	my $ffile = &getFarmFile( $farm_name );
	my $errno = 1;

	require Zevenet::Lock;
	&ztielock( \my @fileconf, "$configdir/$ffile" );

	my $index = 0;
	my $ind   = 0;
	foreach my $line ( @fileconf )
	{
		if ( $line =~ /^[#\s]*Service \"/ ) { last; }
		if ( $line =~ /^\s*AddResponseHeader\s+"/ )
		{
			if ( $header_ind == $ind )
			{
				$errno = 0;
				splice @fileconf, $index, 1;
				last;
			}
			else
			{
				$ind++;
			}
		}
		$index++;
	}
	untie @fileconf;

	&zenlog( "Could not remove AddResponseHeader" ) if $errno;

	return $errno;
}

# remove response header

=begin nd
Function: getHTTPRemRespHeader

	Get a list with all the http headers that the load balancer will add to the
	response to the client

Parameters:
	farmname - Farm name

Returns:
	Array ref - headers list

=cut

sub getHTTPRemRespHeader    # ($farm_name,$service)
{
	&zenlog( __FILE__ . q{:} . __LINE__ . q{:} . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my ( $farm_name ) = @_;
	return &get_http_farm_headers_struct( $farm_name )->{ removeresponseheader };
}

=begin nd
Function: addHTTPRemRespHeader

	Add a directive "HeadResponseRemove". The HTTP farm will remove a reponse
	header from the backend that matches with this expression

Parameters:
	farmname - Farm name
	header - Header to add

Returns:
	Integer - Error code: 0 on success or 1 on failure

=cut

sub addHTTPRemRespHeader
{
	&zenlog( __FILE__ . q{:} . __LINE__ . q{:} . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my ( $farm_name, $header ) = @_;

	require Zevenet::Farm::Core;
	my $ffile = &getFarmFile( $farm_name );
	my $errno = 1;

	require Zevenet::Lock;
	&ztielock( \my @fileconf, "$configdir/$ffile" );

	my $index        = 0;
	my $rewrite_flag = 0;    # it is used to add HeadRemove before than AddHeader
	foreach my $line ( @fileconf )
	{
		if ( $line =~ /^[#\s]*Service \"/ ) { last; }
		if ( $line =~ /[#\s]*RewriteLocation/ )
		{
			$rewrite_flag = 1;
		}
		elsif ( $rewrite_flag )
		{
			# put new headremove after than last one
			if ( $line !~
				 /^[#\s]*(?:AddHeader|HeadRemove|AddResponseHeader|RemoveResponseHead)\s+"/
				 and $rewrite_flag )
			{
				# example: AddHeader "header: to add"
				splice @fileconf, $index, 0, "\tRemoveResponseHead \"$header\"";
				$errno = 0;
				last;
			}
		}
		$index++;
	}
	untie @fileconf;

	&zenlog( "Could not add RemoveResponseHead" ) if $errno;

	return $errno;
}

=begin nd
Function: modifyHTTPRemRespHeader

	Modify an RemoveResponseHead directive from the given farm

Parameters:
	farm_name     - Farm name
	header        - Header to add
	header_ind    - directive index

Returns:
	Integer - Error code: 0 on success or 1 on failure

=cut

sub modifyHTTPRemRespHeader    # ($farm_name, $header, $header_ind)
{
	&zenlog( __FILE__ . q{:} . __LINE__ . q{:} . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my ( $farm_name, $header, $header_ind ) = @_;

	require Zevenet::Farm::Core;
	my $ffile = &getFarmFile( $farm_name );
	my $errno = 1;

	require Zevenet::Lock;
	&ztielock( \my @fileconf, "$configdir/$ffile" );

	my $index = 0;
	my $ind   = 0;
	foreach my $line ( @fileconf )
	{
		if ( $line =~ /^[#\s]*Service \"/ ) { last; }
		if ( $line =~ /^\s*RemoveResponseHead\s+"/ )
		{
			# put new headremove before than last one
			if ( $header_ind == $ind )
			{
				splice @fileconf, $index, 1, "\tRemoveResponseHead \"$header\"";
				$errno = 0;
				last;
			}
			else
			{
				$ind++;
			}
		}
		$index++;
	}
	untie @fileconf;

	&zenlog( "Could not modify RemoveResponseHead" ) if $errno;

	return $errno;
}

=begin nd
Function: delHTTPRemRespHeader

	Delete a directive "HeadResponseRemove".

Parameters:
	farmname - Farm name
	index - Header index

Returns:
	Integer - Error code: 0 on success or 1 on failure

=cut

sub delHTTPRemRespHeader    # ($farm_name,$service,$code)
{
	&zenlog( __FILE__ . q{:} . __LINE__ . q{:} . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my ( $farm_name, $header_ind ) = @_;

	require Zevenet::Farm::Core;
	my $ffile = &getFarmFile( $farm_name );
	my $errno = 1;

	require Zevenet::Lock;
	&ztielock( \my @fileconf, "$configdir/$ffile" );

	my $index = 0;
	my $ind   = 0;
	foreach my $line ( @fileconf )
	{
		if ( $line =~ /^[#\s]*Service \"/ ) { last; }
		if ( $line =~ /^\s*RemoveResponseHead\s+"/ )
		{
			if ( $header_ind == $ind )
			{
				$errno = 0;
				splice @fileconf, $index, 1;
				last;
			}
			else
			{
				$ind++;
			}
		}
		$index++;
	}
	untie @fileconf;

	&zenlog( "Could not remove RemoveResponseHead" ) if $errno;

	return $errno;
}

=begin nd
Function: addHTTPReplaceHeaders

	Add a directive ReplaceHeader to a zproxy farm.

Parameters:
	farmname - Farm name
	type     - Request | Response
	header
	match
	replace

Returns:
	Integer - Error code: 0 on success or 1 on failure

=cut

sub addHTTPReplaceHeaders    # ( $farm_name, $type, $header, $match, $replace )
{
	&zenlog( __FILE__ . q{:} . __LINE__ . q{:} . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my ( $farm_name, $type, $header, $match, $replace ) = @_;

	require Zevenet::Farm::Core;
	my $ffile = &getFarmFile( $farm_name );
	my $errno = 1;

	require Zevenet::Lock;
	&ztielock( \my @fileconf, "$configdir/$ffile" );

	my $index        = 0;
	my $rewrite_flag = 0;    # it is used to add HeadRemove before than AddHeader
	my $rewritelocation_ind = 0;
	my $replace_found       = 0;
	foreach my $line ( @fileconf )
	{
		if ( $replace_found )
		{
			if ( $line =~ /^[#\s]*ReplaceHeader\s+$type\s+"/ ) { $index++; next; }

			# example: ReplaceHeader Request "header" "match" "replace"
			splice @fileconf, $index, 0,
			  "\tReplaceHeader $type \"$header\" \"$match\" \"$replace\"";
			$errno = 0;
			last;
		}
		if ( $line =~ /^[#\s]*Service \"/ )
		{
			if ( $rewrite_flag == 1 )
			{
				splice @fileconf, $rewritelocation_ind + 1, 0,
				  "\tReplaceHeader $type \"$header\" \"$match\" \"$replace\"";
				$errno = 0;
			}
			last;
		}
		if ( $line =~ /[#\s]*RewriteLocation/ )
		{
			$rewrite_flag        = 1;
			$rewritelocation_ind = $index;
		}
		elsif ( $rewrite_flag )
		{
			# put new ReplaceHeader after the last one
			if ( $line =~ /^[#\s]*ReplaceHeader\s+$type\s+"/ )
			{
				$replace_found = 1;
			}
		}
		$index++;
	}
	untie @fileconf;

	&zenlog( "Could not add ReplaceHeader" ) if $errno;

	return $errno;
}

=begin nd
Function: modifyHTTPReplaceHeaders

	Modify an ReplaceHeader directive from the given farm

Parameters:
	farm_name   - Farm name
	header      - Header to add
	$header_ind - directive index

Returns:
	Integer - Error code: 0 on success or 1 on failure

=cut

sub modifyHTTPReplaceHeaders # ( $farm_name, $type, $header, $match, $replace, $header_ind )
{
	&zenlog( __FILE__ . q{:} . __LINE__ . q{:} . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my ( $farm_name, $type, $header, $match, $replace, $header_ind ) = @_;

	require Zevenet::Farm::Core;
	my $ffile = &getFarmFile( $farm_name );
	my $errno = 1;

	require Zevenet::Lock;
	&ztielock( \my @fileconf, "$configdir/$ffile" );

	my $index = 0;
	my $ind   = 0;
	foreach my $line ( @fileconf )
	{
		if ( $line =~ /^[#\s]*Service \"/ ) { last; }
		if ( $line =~ /^\s*ReplaceHeader\s+$type\s+(.+)/ )
		{
			# put new headremove before than last one
			if ( $header_ind == $ind )
			{
				splice @fileconf, $index, 1,
				  "\tReplaceHeader $type \"$header\" \"$match\" \"$replace\"";
				$errno = 0;
				last;
			}
			else
			{
				$ind++;
			}
		}
		$index++;
	}
	untie @fileconf;

	&zenlog( "Could not modify ReplaceHeader" ) if $errno;

	return $errno;
}

=begin nd
Function: getHTTPReplaceHeaders

	Return 

Parameters:
	farmname - Farm name

Returns:
	list

=cut

sub getHTTPReplaceHeaders    # ( $farm_name, $type)
{
	&zenlog( __FILE__ . q{:} . __LINE__ . q{:} . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my ( $farm_name, $type ) = @_;
	my $res;
	if ( $type eq "Request" )
	{
		$res = &get_http_farm_headers_struct( $farm_name )->{ replacerequestheader };
	}
	elsif ( $type eq "Response" )
	{
		$res = &get_http_farm_headers_struct( $farm_name )->{ replaceresponseheader };
	}
	return $res;
}

=begin nd
Function: delHTTPReplaceHeaders

	Delete a directive "ReplaceHeader".

Parameters:
	farmname - Farm name
	index - Header index

Returns:
	Integer - Error code: 0 on success or 1 on failure

=cut

sub delHTTPReplaceHeaders    # ($farm_name, $header_ind, $type)
{
	&zenlog( __FILE__ . q{:} . __LINE__ . q{:} . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my ( $farm_name, $header_ind, $deltype ) = @_;

	require Zevenet::Farm::Core;
	my $ffile = &getFarmFile( $farm_name );
	my $errno = 1;

	require Zevenet::Lock;
	&ztielock( \my @fileconf, "$configdir/$ffile" );

	my $index = 0;
	my $ind   = 0;
	foreach my $line ( @fileconf )
	{
		if ( $line =~ /^[#\s]*Service \"/ ) { last; }
		if ( $line =~ /^\s*ReplaceHeader\s+(.+)/ )
		{
			( my $type ) = split ( /\s+/, $1 );
			if ( $deltype eq $type )
			{
				if ( $header_ind == $ind )
				{
					$errno = 0;
					splice @fileconf, $index, 1;
					last;
				}
				else
				{
					$ind++;
				}
			}
		}
		$index++;
	}
	untie @fileconf;

	&zenlog( "Could not remove ReplaceHeader" ) if $errno;

	return $errno;
}

=begin nd
Function: get_http_farm_headers_struct

	It extends farm struct with the parameters exclusives of the EE.
	It no farm struct was passed to the function. The function will returns a new
	farm struct with the enterprise fields

Parameters:
	farmname - Farm name
	farm struct - Struct with the farm configuration parameters

Returns:
	Hash ref - Farm struct updated with EE parameters
=cut

sub get_http_farm_headers_struct
{
	&zenlog( __FILE__ . q{:} . __LINE__ . q{:} . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $farmname = shift;
	my $farm_st  = shift // {};
	my $proxy_ng = shift // &getGlobalConfiguration( 'proxy_ng' );

	$farm_st->{ addheader }             = [];
	$farm_st->{ headremove }            = [];
	$farm_st->{ addresponseheader }     = [];
	$farm_st->{ removeresponseheader }  = [];
	$farm_st->{ replacerequestheader }  = [];
	$farm_st->{ replaceresponseheader } = [];

	my $farm_filename       = &getFarmFile( $farmname );
	my $add_req_head_index  = 0;
	my $rem_req_head_index  = 0;
	my $add_resp_head_index = 0;
	my $rem_resp_head_index = 0;
	my $rep_req_head_index  = 0;
	my $rep_res_head_index  = 0;
	open my $fileconf, "<", "$configdir/$farm_filename";
	while ( my $line = <$fileconf> )
	{
		if ( $line =~ /^[#\s]*Service \"/ ) { last; }
		elsif ( $line =~ /^[#\s]*AddHeader\s+"(.+)"/ )
		{
			push @{ $farm_st->{ addheader } },
			  {
				"id"     => $add_req_head_index++,
				"header" => $1
			  };
		}
		elsif ( $line =~ /^[#\s]*HeadRemove\s+"(.+)"/ )
		{
			push @{ $farm_st->{ headremove } },
			  {
				"id"      => $rem_req_head_index++,
				"pattern" => $1
			  };
		}
		elsif ( $line =~ /^[#\s]*AddResponseHeader\s+"(.+)"/ )
		{
			push @{ $farm_st->{ addresponseheader } },
			  {
				"id"     => $add_resp_head_index++,
				"header" => $1
			  };
		}
		elsif ( $line =~ /^[#\s]*RemoveResponseHead\s+"(.+)"/ )
		{
			push @{ $farm_st->{ removeresponseheader } },
			  {
				"id"      => $rem_resp_head_index++,
				"pattern" => $1
			  };
		}
		elsif (     $proxy_ng eq 'true'
				and $line =~ /^[#\s]*ReplaceHeader\s+(.+)\s+"(.+)"\s+"(.+)"\s+"(.*)"/ )
		{
			#( my $type, my $header, my $match, my $replace ) = split ( /\s+/, $1 );
			push @{ $farm_st->{ replacerequestheader } },
			  {
				"id"      => $rep_req_head_index++,
				"header"  => $2,
				"match"   => $3,
				"replace" => $4
			  }
			  if $1 eq "Request";
			push @{ $farm_st->{ replaceresponseheader } },
			  {
				"id"      => $rep_res_head_index++,
				"header"  => $2,
				"match"   => $3,
				"replace" => $4
			  }
			  if $1 eq "Response";
		}
		elsif ( $line =~ /Ignore100Continue (\d).*/ )
		{
			$farm_st->{ ignore_100_continue } = ( $1 eq '0' ) ? 'false' : 'true';
		}
		elsif ( $line =~ /LogLevel\s+(\d).*/ )
		{
			my $lvl = $1 + 0;
			if ( $proxy_ng eq 'true' )
			{
				$farm_st->{ logs } = 'true' if ( $lvl >= 6 );
			}
			else
			{
				$farm_st->{ logs } = 'true' if ( $lvl >= 5 );
			}
		}

	}
	close $fileconf;

	if ( $proxy_ng ne 'true' )
	{
		delete $farm_st->{ replacerequestheader };
		delete $farm_st->{ replaceresponseheader };
	}

	return $farm_st;
}

=begin nd
Function: moveHeader

	Changes the position of a farm header directive.

Parameters:
	farmname - Farm name
	regex    - Regex to match the directive
	pos      - It is the required position for the rule.
	index    - It is index of the rule in the set

Returns:
	

=cut

sub moveHeader
{
	&zenlog( __FILE__ . q{:} . __LINE__ . q{:} . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );

	my $farm_name = shift;
	my $regex     = shift;
	my $pos       = shift;
	my $index     = shift;

	require Zevenet::Arrays;

	my $err = 0;

	my $farm_filename = &getFarmFile( $farm_name );
	require Tie::File;
	tie my @file, 'Tie::File', "$configdir/$farm_filename";

	my $file_index   = 0;
	my $header_index = 0;
	my @headers      = ();
	foreach my $l ( @file )
	{
		if ( $l =~ /^[#\s]*Service \"/ ) { last; }
		if ( $l =~ /^$regex/ )
		{
			$header_index = $file_index unless ( $header_index != 0 );
			push @headers, $l;
		}
		$file_index++;
	}

	&moveByIndex( \@headers, $index, $pos );

	my $size = scalar @headers;

	splice ( @file, $header_index, $size, @headers );

	untie @file;

	return $err;
}

=begin nd
Function: getHTTPFarmLogs

	Return the log connection tracking status

Parameters:
	farmname - Farm name
	ng_proxy - It is used to set the log parameter depending on the zproxy or pound. It is termporary, it should disappear when pound will be removed from ZEVENET

Returns:
	scalar - The possible values are: 0 on disabled, possitive value on enabled or -1 on failure

=cut

sub getHTTPFarmLogs    # ($farm_name)
{
	&zenlog( __FILE__ . q{:} . __LINE__ . q{:} . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );

	my $farm_name = shift;
	my $proxy_ng = shift // &getGlobalConfiguration( 'proxy_ng' );

	my $output = 'false';

	my $farm_filename = &getFarmFile( $farm_name );
	open my $fileconf, '<', "$configdir/$farm_filename";

	while ( my $line = <$fileconf> )
	{
		if ( $line =~ /^[#\s]*Service \"/ ) { last; }
		elsif ( $line =~ /LogLevel\s+(\d).*/ )
		{
			my $lvl = $1 + 0;
			if ( $proxy_ng eq 'true' )
			{
				$output = 'true' if ( $lvl >= 6 );
			}
			else
			{
				$output = 'true' if ( $lvl >= 5 );
			}
			last;
		}
	}
	close $fileconf;
	return $output;
}

=begin nd
Function: migrateHTTPFarmLogs

	This function is temporary. It is used while zproxy and pound are available in ZEVENET.
	This should disappear when pound will be removed

Parameters:
	farmname - Farm name

Returns:
	scalar - The possible values are: 0 on disabled, possitive value on enabled or -1 on failure

=cut

sub migrateHTTPFarmLogs
{
	my ( $farm_name, $proxy_mode ) = @_;

	# invert the log
	my $read_log = ( $proxy_mode eq 'true' ) ? 'false' : 'true';
	my $log = &getHTTPFarmLogs( $farm_name, $read_log );
	return &setHTTPFarmLogs( $farm_name, $log, $proxy_mode );
}

=begin nd
Function: setHTTPFarmLogs

	Enable or disable the log connection tracking for a http farm

Parameters:
	farmname - Farm name
	action - The available actions are: "true" to enable or "false" to disable
	ng_proxy - It is used to set the log parameter depending on the zproxy or pound. It is termporary, it should disappear when pound will be removed from ZEVENET

Returns:
	scalar - The possible values are: 0 on success or -1 on failure

=cut

sub setHTTPFarmLogs    # ($farm_name, $action)
{
	&zenlog( __FILE__ . q{:} . __LINE__ . q{:} . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $farm_name = shift;
	my $action    = shift;
	my $proxy_ng  = shift // &getGlobalConfiguration( 'proxy_ng' );

	my $farm_filename = &getFarmFile( $farm_name );
	my $output        = -1;

	my $loglvl;
	if ( $proxy_ng eq 'true' )
	{
		$loglvl = ( $action eq "true" ) ? 6 : 5;
	}
	else
	{
		$loglvl = ( $action eq "true" ) ? 5 : 0;
	}

	require Tie::File;
	tie my @file, 'Tie::File', "$configdir/$farm_filename";

	# check if 100 continue directive exists
	if ( not grep { s/^LogLevel\s+(\d).*$/LogLevel\t$loglvl/ } @file )
	{
		&zenlog( "Error modifying http logs", "error", "HTTP" );
	}
	else
	{
		$output = 0;
	}
	untie @file;

	return $output;
}

=begin nd
Function: getHTTPFarm100Continue

	Return 100 continue Header configuration HTTP and HTTPS farms

Parameters:
	farmname - Farm name

Returns:
	scalar - The possible values are: 0 on disabled, 1 on enabled

=cut

sub getHTTPFarm100Continue    # ($farm_name)
{
	&zenlog( __FILE__ . q{:} . __LINE__ . q{:} . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $farm_name = shift;

	my $output = 'true';

	my $farm_filename = &getFarmFile( $farm_name );
	open my $fileconf, '<', "$configdir/$farm_filename";

	while ( my $line = <$fileconf> )
	{
		if ( $line =~ /^[#\s]*Service \"/ ) { last; }
		elsif ( $line =~ /Ignore100Continue (\d).*/ )
		{
			$output = ( $1 eq '0' ) ? 'false' : 'true';
			last;
		}
	}
	close $fileconf;
	return $output;
}

=begin nd
Function: setHTTPFarm100Continue

	Enable or disable the HTTP 100 continue header

Parameters:
	farmname - Farm name
	action - The available actions are: 1 to enable or 0 to disable

Returns:
	scalar - The possible values are: 0 on success or -1 on failure

=cut

sub setHTTPFarm100Continue    # ($farm_name, $action)
{
	&zenlog( __FILE__ . q{:} . __LINE__ . q{:} . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my ( $farm_name, $action ) = @_;

	my $farm_filename = &getFarmFile( $farm_name );
	my $output        = -1;

	require Tie::File;
	tie my @file, 'Tie::File', "$configdir/$farm_filename";

	# check if 100 continue directive exists
	if ( not grep { s/^Ignore100Continue\ .*/Ignore100Continue $action/ } @file )
	{
		foreach my $line ( @file )
		{
			# put ignore after threadmodel param
			if ( $line =~ /^ThreadModel\s/ )
			{
				$line = "$line\nIgnore100Continue $action";
				last;
			}
		}
	}
	$output = 0;
	untie @file;

	return $output;
}

1;
