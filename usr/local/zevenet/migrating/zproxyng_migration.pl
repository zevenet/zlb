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
require Zevenet::Config;

my $proxy_ng = &getGlobalConfiguration( "proxy_ng" );

die "Zproxy is not activated\n" if $proxy_ng eq "false";

my $configdir = &getGlobalConfiguration( "configdir" );

opendir my $dir, $configdir or die "Cannot open configuration directory: $!";
my @files = readdir $dir;
closedir $dir;

require Zevenet::Lock;
require Tie::File;
require Zevenet::Farm::Core;
require Zevenet::Farm::HTTP::Config;

my @farm_files = grep ( /.*\_proxy\.cfg$/, @files );
my $farm_name;

foreach ( @farm_files )
{
	$farm_name = $1 if $_ =~ /^(.*)\_proxy\.cfg$/;
	my $lock_file = &getLockFile( $farm_name );
	my $lock_fh = &openlock( $lock_file, 'w' );

	tie my @array, 'Tie::File', "$configdir\/$_";

	print ( "\nMigrating $farm_name config file...\n" );
	&zenlog( "Migrating $farm_name config file...", "debug1", " SYSTEM" );

	my @array_bak = @array;
	my $sw        = 0;
	my $bw        = 0;
	my $cookie_params;
	my $session_checker;
	my $stat = 0;

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
		elsif ( $array[$i] =~ /^\s*(#?)RewriteLocation\s+(\d)(\s+path)?$/ )
		{
			if ( $3 )
			{
				$array[$i] =~ s/path/1/;
			}
			else
			{
				$array[$i] .= " 0";
			}
		}
		elsif ( $array[$i] =~ /^ListenHTTP$/ )
		{
			$array[$i] .= "\n\tName\t$farm_name";
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
		}
		elsif ( $array[$i] =~ /^\t\t\t#?TTL/ )
		{
			if ( $sw == 1 and $bw == 0 )
			{
				$array[$i] = "\t\t\tTTL $cookie_params->{ ttl }"
				  if $cookie_params->{ enabled } == 1;
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
					$array[$i] .=
					  "\n\t\t\tPath \"$cookie_params->{ path }\"\n\t\t\tDomain \"$cookie_params->{ domain }\"";
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
	}

	untie @array;

	if ( &getHTTPFarmConfigIsOK( $farm_name ) )
	{
		tie my @array, 'Tie::File', "$configdir\/$_";
		@array = @array_bak;
		untie @array;
		$stat = 1;
		print ( "\nError migrating $farm_name config file!\n" );
		&zenlog( "Error migrating $farm_name config file!", "error", "SYSTEM" );
	}
	else
	{
		$stat = 0;
		print ( "\nSuccess migrating $farm_name config file!\n" );
		&zenlog( "Success migrating $farm_name config file!", "debug1", " SYSTEM" );
	}

	close $lock_fh;
}

1;
