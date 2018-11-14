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

my $configdir = &getGlobalConfiguration( 'configdir' );

=begin nd
Function: setFarmHTTPNewService

	Create a new Service in a HTTP farm

Parameters:
	farmname - Farm name
	service - Service name

Returns:
	Integer - Error code: 0 on success, other value on failure

FIXME:
	This function returns nothing, do error control

=cut

sub setFarmHTTPNewService    # ($farm_name,$service)
{
	my ( $farm_name, $service ) = @_;

	use File::Grep 'fgrep';
	require Tie::File;
	require Zevenet::Farm::Config;

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

	if ( !fgrep { /Service "$service"/ } "$configdir/$farm_name\_pound.cfg" )
	{
		#create service
		my @newservice;
		my $sw       = 0;
		my $count    = 0;
		my $poundtpl = &getGlobalConfiguration( 'poundtpl' );
		tie my @poundtpl, 'Tie::File', "$poundtpl";
		my $countend = 0;

		foreach my $line ( @poundtpl )
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

		# lock file
		require Zevenet::Farm::HTTP::Config;
		my $lock_fh = &lockHTTPFile( $farm_name );

		my @fileconf;
		tie @fileconf, 'Tie::File', "$configdir/$farm_name\_pound.cfg";
		my $i         = 0;
		my $farm_type = "";
		$farm_type = &getFarmType( $farm_name );

		foreach my $line ( @fileconf )
		{
			if ( $line =~ /#ZWACL-END/ )
			{
				$output = 0;
				foreach my $lline ( @newservice )
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

		&unlockfile( $lock_fh );
	}
	else
	{
		$output = 1;
	}

	return $output;
}

=begin nd
Function: setFarmNewService

	[Not used] Create a new Service in a HTTP farm

Parameters:
	farmname - Farm name
	service - Service name

Returns:
	Integer - Error code: 0 on success, other value on failure

=cut

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

=begin nd
Function: deleteFarmService

	Delete a service in a Farm

Parameters:
	farmname - Farm name
	service - Service name

Returns:
	Integer - Error code: 0 on success, -1 on failure

FIXME:
	Rename function to delHTTPFarmService

=cut

sub deleteFarmService    # ($farm_name,$service)
{
	my ( $farm_name, $service ) = @_;

	require Tie::File;
	require Zevenet::FarmGuardian;
	require Zevenet::Farm::HTTP::Service;

	my $farm_filename = &getFarmFile( $farm_name );
	my $sw            = 0;
	my $output        = -1;

	# Counter the Service's backends
	my $sindex = &getFarmVSI( $farm_name, $service );
	my $backendsvs = &getHTTPFarmVS( $farm_name, $service, "backends" );
	my @be = split ( "\n", $backendsvs );
	my $counter = -1;

	foreach my $subline ( @be )
	{
		my @subbe = split ( "\ ", $subline );
		$counter++;
	}

	# Stop FG service
	&runFarmGuardianStop( $farm_name, $service );
	&runFarmGuardianRemove( $farm_name, $service );
	unlink "$configdir/$farm_name\_$service\_guardian.conf";

	# lock file
	require Zevenet::Farm::HTTP::Config;
	my $lock_fh = &lockHTTPFile( $farm_name );

	tie my @fileconf, 'Tie::File', "$configdir/$farm_filename";

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

	&unlockfile( $lock_fh );

	# delete service's backends  in status file
	if ( $counter > -1 )
	{
		while ( $counter > -1 )
		{
			require Zevenet::Farm::HTTP::Backend;
			&runRemoveHTTPBackendStatus( $farm_name, $counter, $service );
			$counter--;
		}
	}

# change the ID value of services with an ID higher than the service deleted (value - 1)
	tie my @contents, 'Tie::File', "$configdir\/$farm_name\_status.cfg";
	foreach my $line ( @contents )
	{
		my @params = split ( "\ ", $line );
		my $newval = $params[2] - 1;

		if ( $params[2] > $sindex )
		{
			$line =~
			  s/$params[0]\ $params[1]\ $params[2]\ $params[3]\ $params[4]/$params[0]\ $params[1]\ $newval\ $params[3]\ $params[4]/g;
		}
	}
	untie @contents;

	return $output;
}

=begin nd
Function: getHTTPFarmServices

	Get an array containing service name that are configured in a http farm

Parameters:
	farmname - Farm name

Returns:
	Array - service names

FIXME:
	&getHTTPFarmVS(farmname) does same but in a string

=cut

sub getHTTPFarmServices
{
	my ( $farm_name ) = @_;

	require Zevenet::Farm::Core;

	my $farm_filename = &getFarmFile( $farm_name );
	my $pos           = 0;
	my @output;

	open my $fh, "<$configdir\/$farm_filename";
	my @file = <$fh>;
	close $fh;

	foreach my $line ( @file )
	{
		if ( $line =~ /\tService\ \"/ )
		{
			$pos++;
			my @line_aux = split ( "\"", $line );
			my $service = $line_aux[1];
			push ( @output, $service );
		}
	}

	return @output;
}

=begin nd
Function: getHTTPServiceBlocks

	Return a struct with configuration about the configuration farm and its services

Parameters:
	farmname - Farm name
	service - Service to move

Returns:
	Hash ref - Return 3 keys: farm, it is the part of the farm configuration file with the configuration; request, it is the block of code for the request service;
	services, it is a hash reference with the id service, the code of the service is appending from the id, it is excluid the request service from this list.

	example:

	{
		farm => [
			'######################################################################',
			'##GLOBAL OPTIONS                                                      ',
			'User		"root"                                                     ',
			'Group		"root"                                                     ',
			'Name		AAmovesrv                                                  ',
			'## allow PUT and DELETE also (by default only GET, POST and HEAD)?:   ',
			'#ExtendedHTTP	0                                                      ',
			'## Logging: (goes to syslog by default)                               ',
			'##	0	no logging                                                     ',
			'##	1	normal                                                         ',
			'...																   '
		],
		request => [
			'Service "sev3"											 ',
			'	##False##HTTPS-backend##                             ',
			'	#DynScale 1                                          ',
			'	#BackendCookie "ZENSESSIONID" "domainname.com" "/" 0 ',
			'	#HeadRequire "Host: "                                ',
			'	#Url ""                                              ',
			'	Redirect "https://SEFAwwwwwwwwwwFA.hf"               ',
			'	#StrictTransportSecurity 21600000                    ',
			'	#Session                                             ',
			'	...													 '
		],
		services => {
			'0' => [
				'Service "sev1"											 ',
				'	##False##HTTPS-backend##                             ',
				'	#DynScale 1                                          ',
				'	#BackendCookie "ZENSESSIONID" "domainname.com" "/" 0 ',
				'	#HeadRequire "Host: "                                ',
				'	#Url ""                                              ',
				'	Redirect "https://SEFAwwwwwwwwwwFA.hf"               ',
				'	#StrictTransportSecurity 21600000                    ',
				'	#Session                                             ',
				'	...													 '
			],
			'1' => [
				'Service "sev2"											 ',
				'	##False##HTTPS-backend##                             ',
				'	#DynScale 1                                          ',
				'	#BackendCookie "ZENSESSIONID" "domainname.com" "/" 0 ',
				'	#HeadRequire "Host: "                                ',
				'	#Url ""                                              ',
				'	Redirect "https://SEFAwwwwwwwwwwFA.hf"               ',
				'	#StrictTransportSecurity 21600000                    ',
				'	#Session                                             ',
				'	...													 '
			],
		}
	}

=cut


sub getHTTPServiceBlocks
{
	my $farm = shift;
	my $srv  = shift;
	my $out = {
		farm => [],
		services => {},
		request => [],
		};
	my @block;
	my @srv_block;
	my $current_srv;
	my $srv_flag;
	my @srv_request;
	my $farm_flag = 1;
	my @aux;

	my $farm_filename = &getFarmFile( $farm );
	open my $fileconf, '<', "$configdir/$farm_filename";

	my $ind = 0;
	foreach my $line ( <$fileconf> )
	{
		if ( $line =~ /^\tService \"(.+)\"/ )
		{
			$srv_flag = 1;
			$farm_flag = 0;
			$current_srv = $1;
		}

		if ( $farm_flag )
		{
			push @{ $out->{ farm } }, $line;
		}
		if ( $srv_flag )
		{
			if ( $srv ne $current_srv )
			{
				push @{ $out->{ services }->{ $ind } }, $line;
			}
			else
			{
				push @{ $out->{ request } }, $line;
			}
		}
		if ( $line =~ /^\tEnd$/ and $srv_flag )
		{
			$srv_flag=0;
			$ind++ if ( $srv ne $current_srv );
		}
	}

	return $out;
}

=begin nd
Function: moveService

	Move a HTTP service to change its preference. This function changes the possition of a service in farm config file

Parameters:
	farmname - Farm name
	move - Direction where it moves the service. The possbile value are: "down", decrease the priority or "up", increase the priority
	service - Service to move

Returns:
	integer - Always return 0

FIXME:
	Rename function to setHTTPFarmMoveService
	Always return 0, create error control

=cut


sub moveService
{
	my $farm      = shift;
	my $srv       = shift;
	my $req_index = shift;
	my $out;

	# lock file
	my $farm_filename = &getFarmFile( $farm );
	require Zevenet::Lock;
	my $lock_file = "/tmp/$farm.lock";
	my $lock_fh   = &lockfile( $lock_file );

	# reduce a index if service was in a previuos position.
	my $srv_index = &getFarmVSI( $farm, $srv );

	# get service code
	my $srv_block = &getHTTPServiceBlocks( $farm, $srv );

	my @sort_list = @{ $srv_block->{ farm } };

	my $size = scalar keys %{ $srv_block->{ services } };
	my $srv_flag = 0;
	my $id = 0;

	for ( my $i=0; $i < $size+1; $i++ )
	{
		if ( $i == $req_index )
		{
			push @sort_list, @{ $srv_block->{ request } };
		}

		else
		{
			push @sort_list, @{ $srv_block->{ services }->{ $id } };
			$id++;
		}
	}

	# finish tags of config file
	push @sort_list, "\t#ZWACL-END";
	push @sort_list, "End";

	# write in config file
	use Tie::File;
	tie my @file, "Tie::File", "$configdir/$farm_filename";
	@file = @sort_list;
	untie @file;

	# unlock file
	&unlockfile( $lock_fh );

	# move fg
	&moveServiceFarmStatus( $farm, $srv, $req_index );

	return $out;
}


=begin nd
Function: moveServiceFarmStatus

	Modify the service index in status file ( farmname_status.cfg ). For updating farmguardian backend status.

Parameters:
	farmname - Farm name
	move - Direction where it moves the service. The possbile value are: "down", decrease the priority or "up", increase the priority
	service - Service to move

Returns:
	integer - Always return 0

FIXME:
	Rename function to setHTTPFarmMoveServiceStatusFile
	Always return 0, create error control

=cut

sub moveServiceFarmStatus
{
	my ( $farmname, $service, $req_index ) = @_;

	use Tie::File;
	my $fileName = "$configdir\/${farmname}_status.cfg";
	tie my @file, 'Tie::File', $fileName;

	my $srv_id = &getFarmVSI( $farmname, $service );
	return if ( $srv_id == -1 );
	return if ( $srv_id == $req_index );
	#
	my $dir = ( $srv_id < $req_index )? "up" : "down";

	foreach my $line ( @file )
	{
		if ( $line =~ /(^-[bB] 0) (\d+) (.+)$/ )
		{
			my $cad1 = $1;
			my $index = $2;
			my $cad2 = $3;

			# replace with the new service position
			if ( $index == $srv_id ) 				{ $index = $req_index; }

			# replace with the new service position
			elsif ( $dir eq "down" and $index < $srv_id and $index >= $req_index )	{ $index++ ; }
			# replace with the new service position
			elsif ( $dir eq "up" and $index > $srv_id and $index <= $req_index )	{ $index-- ; }

			$line = "$cad1 $index $cad2";
		}
	}

	untie @file;

	&zenlog(
		"The service \"$service\" from farm \"$farmname\" has been moved to $req_index the position", "debug2"
	);

	return 0;
}

=begin nd
Function: getHTTPServiceStruct

	Get a struct with all parameters of a HTTP service

Parameters:
	farmname - Farm name
	service - Farm name

Returns:
	hash ref - hash with service configuration

	Example output:
	{
	  "services" : {
      "backends" : [
         {
            "id" : 0,
            "ip" : "48.5.25.5",
            "port" : 70,
            "status" : "up",
            "timeout" : null,
            "weight" : null
         }
      ],
      "cookiedomain" : "",
      "cookieinsert" : "false",
      "cookiename" : "",
      "cookiepath" : "",
      "cookiettl" : 0,
      "fgenabled" : "false",
      "fglog" : "false",
      "fgscript" : "",
      "fgtimecheck" : 5,
      "httpsb" : "false",
      "id" : "srv3",
      "leastresp" : "false",
      "persistence" : "",
      "redirect" : "",
      "redirecttype" : "",
      "sessionid" : "",
      "ttl" : 0,
      "urlp" : "",
      "vhost" : ""
      }
    };

=cut

sub getHTTPServiceStruct
{
	my ( $farmname, $servicename ) = @_;

	require Zevenet::FarmGuardian;
	require Zevenet::Farm::HTTP::Backend;

	my $service = -1;

	#http services
	my $services = &getHTTPFarmVS( $farmname, "", "" );
	my @serv = split ( "\ ", $services );

	foreach my $s ( @serv )
	{
		if ( $s eq $servicename )
		{
			my $vser         = &getHTTPFarmVS( $farmname, $s, "vs" );
			my $urlp         = &getHTTPFarmVS( $farmname, $s, "urlp" );
			my $redirect     = &getHTTPFarmVS( $farmname, $s, "redirect" );
			my $redirecttype = &getHTTPFarmVS( $farmname, $s, "redirecttype" );
			my $session      = &getHTTPFarmVS( $farmname, $s, "sesstype" );
			my $ttl          = &getHTTPFarmVS( $farmname, $s, "ttl" );
			my $sesid        = &getHTTPFarmVS( $farmname, $s, "sessionid" );
			my $dyns         = &getHTTPFarmVS( $farmname, $s, "dynscale" );
			my $httpsbe      = &getHTTPFarmVS( $farmname, $s, "httpsbackend" );
			my $cookiei      = &getHTTPFarmVS( $farmname, $s, "cookieins" );

			if ( $cookiei eq "" )
			{
				$cookiei = "false";
			}

			my $cookieinsname = &getHTTPFarmVS( $farmname, $s, "cookieins-name" );
			my $domainname    = &getHTTPFarmVS( $farmname, $s, "cookieins-domain" );
			my $path          = &getHTTPFarmVS( $farmname, $s, "cookieins-path" );
			my $ttlc          = &getHTTPFarmVS( $farmname, $s, "cookieins-ttlc" );

			if ( $dyns =~ /^$/ )
			{
				$dyns = "false";
			}
			if ( $httpsbe =~ /^$/ )
			{
				$httpsbe = "false";
			}

			my @fgconfig  = &getFarmGuardianConf( $farmname, $s );
			my $fgttcheck = $fgconfig[1];
			my $fgscript  = $fgconfig[2];
			my $fguse     = $fgconfig[3];
			my $fglog     = $fgconfig[4];

			# Default values for farm guardian parameters
			if ( !$fgttcheck ) { $fgttcheck = 5; }
			if ( !$fguse )     { $fguse     = "false"; }
			if ( !$fglog )     { $fglog     = "false"; }
			if ( !$fgscript )  { $fgscript  = ""; }

			$fgscript =~ s/\n//g;
			$fguse =~ s/\n//g;

			my $backends = &getHTTPFarmBackends( $farmname, $s );

			$ttlc      = 0 unless $ttlc;
			$ttl       = 0 unless $ttl;
			$fgttcheck = 0 unless $fgttcheck;

			$service = {
						 id           => $s,
						 vhost        => $vser,
						 urlp         => $urlp,
						 redirect     => $redirect,
						 redirecttype => $redirecttype,
						 cookieinsert => $cookiei,
						 cookiename   => $cookieinsname,
						 cookiedomain => $domainname,
						 cookiepath   => $path,
						 cookiettl    => $ttlc + 0,
						 persistence  => $session,
						 ttl          => $ttl + 0,
						 sessionid    => $sesid,
						 leastresp    => $dyns,
						 httpsb       => $httpsbe,
						 fgtimecheck  => $fgttcheck + 0,
						 fgscript     => $fgscript,
						 fgenabled    => $fguse,
						 fglog        => $fglog,
						 backends     => $backends,
			};
			last;
		}
	}

	return $service;
}

=begin nd
Function: getHTTPFarmVS

	Return virtual server parameter

Parameters:
	farmname - Farm name
	service - Service name
	tag - Indicate which field will be returned. The options are: vs, urlp, redirect, redirecttype, cookieins, cookieins-name, cookieins-domain,
	cookieins-path, cookieins-ttlc, dynscale, sesstype, ttl, sessionid, httpsbackend or backends

Returns:
	scalar - if service and tag is blank, return all services in a string: "service0 service1 ..." else return the parameter value

FIXME:
	return a hash with all parameters
=cut

sub getHTTPFarmVS    # ($farm_name,$service,$tag)
{
	my ( $farm_name, $service, $tag ) = @_;

	$service = "" unless $service;
	$tag     = "" unless $tag;

	my $farm_filename = &getFarmFile( $farm_name );
	my $output        = "";
	my $l;

	open my $fileconf, '<', "$configdir/$farm_filename";

	my $sw         = 0;
	my $be_section = 0;
	my $be         = -1;
	my $sw_ti      = 0;
	my $output_ti  = "";
	my $sw_pr      = 0;
	my $output_pr  = "";
	my $outputa;
	my $outputp;
	my @return;

	foreach my $line ( <$fileconf> )
	{
		if ( $line =~ /^\tService \"$service\"/ ) { $sw = 1; }
		if ( $line =~ /^\tEnd$/ ) { $sw = 0; }

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
			# Redirect types: 301, 302 or 307.
			if (    $line =~ /Redirect(?:Append)?\s/
				 && $sw == 1
				 && $line !~ "#" )
			{
				@return = split ( " ", $line );

				my $url = $return[-1];
				$url =~ s/\"//g;
				$url =~ s/^\s+//;
				$url =~ s/\s+$//;
				$output = $url;
				last;
			}
		}

		if ( $tag eq "redirecttype" )
		{
			if (    $line =~ /Redirect(?:Append)?\s/
				 && $sw == 1
				 && $line !~ "#" )
			{
				if    ( $line =~ /Redirect / )       { $output = "default"; }
				elsif ( $line =~ /RedirectAppend / ) { $output = "append"; }
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
			if ( $line =~ "TTL" && $sw == 1 )
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
	close $fileconf;

	return $output;
}

=begin nd
Function: setHTTPFarmVS

	Set values for service parameters. The parameters are: vs, urlp, redirect, redirectappend, cookieins, cookieins-name, cookieins-domain,
	cookieins-path, cookieins-ttlc, dynscale, sesstype, ttl, sessionid, httpsbackend or backends

	A blank string comment the tag field in config file

Parameters:
	farmname - Farm name
	service - Service name
	tag - Indicate which parameter modify
	string - value for the field "tag"

Returns:
	Integer - Error code: 0 on success or -1 on failure

=cut

sub setHTTPFarmVS    # ($farm_name,$service,$tag,$string)
{
	my ( $farm_name, $service, $tag, $string ) = @_;

	my $farm_filename = &getFarmFile( $farm_name );
	my $output        = 0;
	my $line;
	my $sw = 0;
	my $j  = -1;
	my $l;

	$string =~ s/^\s+//;
	$string =~ s/\s+$//;

	# lock file
	require Zevenet::Farm::HTTP::Config;
	my $lock_fh = &lockHTTPFile( $farm_name );

	require Tie::File;
	tie my @fileconf, 'Tie::File', "$configdir/$farm_filename";

	foreach $line ( @fileconf )
	{
		$j++;
		if ( $line =~ /\tService \"$service\"/ ) { $sw = 1; }
		if ( $line =~ /^\tEnd$/ && $sw == 1 ) { last; }
		next if $sw == 0;

		#vs tag
		if ( $tag eq "vs" )
		{
			if ( $line =~ /^\t\t#?HeadRequire/ && $sw == 1 && $string ne "" )
			{
				$line = "\t\tHeadRequire \"Host: $string\"";
				last;
			}
			if ( $line =~ /^\t\t#?HeadRequire/ && $sw == 1 && $string eq "" )
			{
				$line = "\t\t#HeadRequire \"Host:\"";
				last;
			}
		}

		#url pattern
		if ( $tag eq "urlp" )
		{
			if ( $line =~ /^\t\t#?Url/ && $sw == 1 && $string ne "" )
			{
				$line = "\t\tUrl \"$string\"";
				last;
			}
			if ( $line =~ /^\t\t#?Url/ && $sw == 1 && $string eq "" )
			{
				$line = "\t\t#Url \"\"";
				last;
			}
		}

		#dynscale
		if ( $tag eq "dynscale" )
		{
			if ( $line =~ /^\t\t#?DynScale/ && $sw == 1 && $string ne "" )
			{
				$line = "\t\tDynScale 1";
				last;
			}
			if ( $line =~ /^\t\t#DynScale/ && $sw == 1 && $string eq "" )
			{
				$line = "\t\t#DynScale 1";
				last;
			}
		}

		#client redirect default
		if ( $tag eq "redirect" or $tag eq "redirectappend" )
		{
			if ( $line =~ /^\t\t#?Redirect(?:Append)?\s/ )
			{
				my $policy = 'Redirect';
				$policy .= 'Append' if $tag eq "redirectappend";

				my $comment = ( $string eq "" ) ? '#' : '';

				$line =~ /Redirect(?:Append)? (30[127] )?"/;
				my $redirect_code = $1 // "";

				$line = "\t\t${comment}${policy} $redirect_code\"$string\"";
				last;
			}
		}

		#cookie insertion name
		if ( $tag eq "cookieins-name" )
		{
			if ( $line =~ /^\t\t#?BackendCookie/ && $sw == 1 && $string ne "" )
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
			if ( $line =~ /^\t\t#?BackendCookie/ && $sw == 1 && $string ne "" )
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
			if ( $line =~ /^\t\t#?BackendCookie/ && $sw == 1 && $string ne "" )
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
			if ( $line =~ /^\t\t#?BackendCookie/ && $sw == 1 && $string ne "" )
			{
				$l = $line;
				$l =~ s/\t\t//g;
				my @values = split ( "\ ", $l );
				$values[4] =~ s/\"//g;
				$line = "\t\tBackendCookie $values[1] $values[2] $values[3] $string";
				last;
			}
		}

		#cookie ins
		if ( $tag eq "cookieins" )
		{
			if ( $line =~ /^\t\t#BackendCookie/ && $sw == 1 && $string ne "" )
			{
				$line =~ s/#//g;
				last;
			}
			if ( $line =~ /^\t\tBackendCookie/ && $sw == 1 && $string eq "" )
			{
				$line =~ s/\t\t//g;
				$line = "\t\t#$line";
				last;
			}
		}

		#TTL
		if ( $tag eq "ttl" )
		{
			if ( $line =~ /^\t\t\t#?TTL/ && $sw == 1 && $string ne "" )
			{
				$line = "\t\t\tTTL $string";
				last;
			}
			if ( $line =~ /^\t\t\t#?TTL/ && $sw == 1 && $string eq "" )
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
			if ( $sw == 1 && $line =~ /\t\tBackEnd$/ && $string ne "" )
			{
				$line .= "\n\t\t\tHTTPS";
			}

			#go out of curret Service
			if (    $line =~ /\tService \"/
				 && $sw == 1
				 && $line !~ /\tService \"$service\"/ )
			{
				$tag = "";
				$sw  = 0;
				last;
			}
		}

		#session type
		if ( $tag eq "session" )
		{
			if ( $string ne "nothing" && $sw == 1 )
			{
				if ( $line =~ /^\t\t#Session/ )
				{
					$line = "\t\tSession";
				}
				if ( $line =~ /\t\t#End/ )
				{
					$line = "\t\tEnd";
				}
				if ( $line =~ /^\t\t\t#?Type/ )
				{
					$line = "\t\t\tType $string";
				}
				if ( $line =~ /^\t\t\t#?TTL/ )
				{
					$line =~ s/#//g;
				}
				if ( $line =~ /\t\t\t#?ID / )
				{
					if (    $string eq "URL"
						 || $string eq "COOKIE"
						 || $string eq "HEADER" )
					{
						$line =~ s/#//g;
					}
					else
					{
						$line = "#$line";
					}
				}
			}

			if ( $string eq "nothing" && $sw == 1 )
			{
				if ( $line =~ /^\t\tSession/ )
				{
					$line = "\t\t#Session";
				}
				if ( $line =~ /^\t\tEnd/ )
				{
					$line = "\t\t#End";
				}
				if ( $line =~ /^\t\t\tTTL/ )
				{
					$line = "\t\t\t#TTL 120";
				}
				if ( $line =~ /^\t\t\tType/ )
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

	&unlockfile( $lock_fh );

	return $output;
}

=begin nd
Function: getFarmVSI

	Get the index of a service in a http farm

Parameters:
	farmname - Farm name
	service - Service name

Returns:
	integer - Service index, it returns -1 if the service does not exist

FIXME:
	Rename with intuitive name, something like getHTTPFarmServiceIndex
=cut

sub getFarmVSI    # ($farm_name,$service)
{
	my ( $farmname, $service ) = @_;

	# get service position
	my $srv_position = -1;
	my @services     = &getHTTPFarmServices( $farmname );
	my $index = 0;
	foreach my $srv ( @services )
	{
		if ( $srv eq $service )
		{
			# found
			$srv_position = $index;
			last;
		}
		else
		{
			$index++;
		}
	}

	return $srv_position;
}

1;
