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

#The following script migrates the farms configuration files from zproxy to zproxy_ng valid config.

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
	my $sw        = 0;        #service section
	my $bw        = 0;        #backend section(s)
	my $lw        = 0;        #listener section
	my $mw        = 0;        #model section
	my $ssw       = 0;        #sessions section
	my $cookie_params;
	my $name_index;
	my $name_checker;
	my $id_index;
	my $path_checker;
	my $ip_port;
	my @backends;
	my $backend_index;
	my $delete_backend = 0;

	for ( my $i = 0 ; $i < @array ; $i++ )
	{
		if ( $lw == 0 )
		{
			if ( $array[$i] =~ /^(User\s+\".+\"|Group\s+\".+\"|Name\s+.+)$/ )
			{
				splice @array, $i, 1;
				$i--;
			}
			elsif ( $array[$i] =~ /^Control\s+\".+\"$/ )
			{
				splice @array, $i, 1;
				$i--;
			}
			elsif ( $array[$i] =~ /^#HTTP\(S\) LISTENERS$/ )
			{
				$lw = 1;
			}
		}
		else    # $lw == 1
		{
			if ( $sw == 0 )
			{
				if ( $mw == 0 )
				{
					if ( $array[$i] =~ /^ListenHTTPS?$/ )
					{
						$name_index = $i;
					}
					elsif ( $array[$i] =~ /^\s+Name\s+.+$/ )
					{
						$name_checker = 1;
					}
					elsif ( $array[$i] =~ /^\s*#?RewriteLocation\s+\d(\s+path)?$/ )
					{
						if ( $1 )
						{
							$array[$i] =~ s/path/1/;
						}
						else
						{
							$array[$i] .= " 0";
						}
					}
					elsif ( $array[$i] =~ /^\s+Service/ )
					{
						$sw = 1;
					}
					elsif ( $array[$i] =~ /^\s+#ZWACL-END$/ )
					{
						$mw = 1;
					}
				}
				else    # $mw == 1
				{
					if ( $array[$i] =~ /\s+#BackendCookie\s\".+\"\s\".+\"\s\".+\"\s\d+/ )
					{
						splice @array, $i, 1;
						$i--;
					}
					elsif ( $array[$i] =~ /^\s+#ID\s+.*$/ )
					{
						$id_index = $i;
						$array[$i] = "\t\t\t#ID \"ZENSESSIONID\"";
					}
					elsif ( $array[$i] =~ /^\s+#Path\s+.*/ )
					{
						$path_checker = 1;
						last;
					}
				}
			}
			else    # $sw == 1
			{
				if ( $ssw == 0 )
				{
					if ( $bw == 0 )
					{
						if ( $array[$i] =~ /^\s+BackEnd/ )
						{
							$bw            = 1;
							$backend_index = $i;
						}
						elsif (
								$array[$i] =~ /\s+(#?)BackendCookie\s\"(.+)\"\s\"(.+)\"\s\"(.+)\"\s(\d+)/ )
						{
							$cookie_params->{ enabled } = $1 ne "#" ? 1 : 0;
							$cookie_params->{ id }      = $2;
							$cookie_params->{ domain }  = $3;
							$cookie_params->{ path }    = $4;
							$cookie_params->{ ttl }     = $5;

							splice @array, $i, 1;
							$i--;
						}
						elsif ( $array[$i] =~ /^\s+#?Session$/ )
						{
							$array[$i] =~ s/#// if $cookie_params->{ enabled } == 1;
							$ssw = 1;
						}
						elsif ( $array[$i] =~ /^\s*#?RewriteLocation\s+\d(\s+path)?$/ )
						{
							if ( $1 )
							{
								$array[$i] =~ s/path/1/;
							}
							else
							{
								$array[$i] .= " 0";
							}
						}
						elsif ( $array[$i] =~ /^\s+End$/ )
						{
							#if the line End is located in the service block, but not in the
							#backend or session sections, it can only be the #?End line that marks
							#the ending of the service block.
							@backends = ();
							$sw       = 0;
						}
					}
					else    # $bw == 1
					{
						if ( $array[$i] =~ /^\s+Address\s+(.+)$/ )
						{
							$ip_port = $1;
						}
						elsif ( $array[$i] =~ /^\t\t\tPort\s(\d+)$/ )
						{
							$ip_port = $ip_port . $1;
							foreach my $backend ( @backends )
							{
								if ( $ip_port eq $backend )
								{
									$delete_backend = 1;
								}
							}
							push ( @backends, $ip_port ) if $delete_backend != 1;
						}
						elsif ( $array[$i] =~ /^\s+End$/ )
						{
							if ( $delete_backend == 1 )
							{
								#If this backend is duplicated, it needs to be deleted.
								$delete_backend = 0;
								my $offset = $i - $backend_index + 1;
								splice @array, $backend_index, $offset;
								$i = $i - $offset;
							}
							$bw = 0;

							#if the End line is located in the backend section of a service, it can
							#only be the line that marks the ending of that backend section.
						}
					}
				}
				else    # $ssw == 1
				{
					if ( $array[$i] =~ /^\s+#?Type/ )
					{
						$array[$i] = "\t\t\tType BACKENDCOOKIE" if $cookie_params->{ enabled } == 1;
					}
					elsif ( $array[$i] =~ /^\s+#?TTL/ )
					{
						$array[$i] = "\t\t\tTTL $cookie_params->{ ttl }"
						  if $cookie_params->{ enabled } == 1;
					}
					elsif ( $array[$i] =~ /^(#*)(\s+#?ID\s+.*)$/ )
					{
						if ( $1 )
						{
							$array[$i] = $2;
							if ( $array[$i] =~ /^\s+ID\s+.*$/ )
							{
								$array[$i] =~ s/ID/#ID/;
							}
						}
						if ( exists $cookie_params->{ enabled } )
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
					}
					elsif ( $array[$i] =~ /^\s+#?End$/ )
					{
						#if, on the other hand, the #?End line is located in the sessions section
						#of the service, it must be the line that marks the ending of the session
						#section.
						$array[$i] =~ s/#// if $cookie_params->{ enabled } eq 1;
						$ssw = 0;
					}
				}
			}
		}
	}

	if ( $path_checker == 0 )
	{
		$array[$id_index] .= "\n\t\t\t#Path \"/\"\n\t\t\t#Domain \"domainname.com\"";
	}
	if ( $name_checker == 0 )
	{
		$array[$name_index] .= "\n\tName\t$farm_name";
	}

	untie @array;
	my $config_error = &getHTTPFarmConfigErrorMessage( $farm_name );
	if ( $config_error->{ code } )
	{
		tie my @array, 'Tie::File', "$configdir\/$_";
		@array = @array_bak;
		untie @array;
		print ( "\nError migrating $farm_name config file: $config_error->{ desc }\n" );
		&zenlog( "Error migrating $farm_name config file: $config_error->{ desc }",
				 "error", "SYSTEM" );
	}
	else
	{
		print ( "\nSuccess migrating $farm_name config file!\n" );
		&zenlog( "Success migrating $farm_name config file!", "debug1", " SYSTEM" );
	}

	close $lock_fh;
}

1;
