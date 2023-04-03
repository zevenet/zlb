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


require Zevenet::System;

# show license
sub get_license
{
	&zenlog( __FILE__ . q{:} . __LINE__ . q{:} . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $format = shift;

	my $desc = "Get license";
	my $licenseFile;

	if ( $format eq 'txt' )
	{
		$licenseFile = &getGlobalConfiguration( 'licenseFileTxt' );
	}
	elsif ( $format eq 'html' )
	{
		$licenseFile = &getGlobalConfiguration( 'licenseFileHtml' );
	}
	else
	{
		my $msg = "Not found license.";
		&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
	}

	my $file = &slurpFile( $licenseFile );

	&httpResponse( { code => 200, body => $file, type => 'text/plain' } );
	return;
}

# GET /system/supportsave
# GET /system/supportsave/all
sub get_supportsave
{
	&zenlog( __FILE__ . q{:} . __LINE__ . q{:} . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my ( $type ) = @_;

	$type = undef if ( $type ne "all" );
	my $desc     = "Get supportsave file";
	my $req_size = &checkSupportSaveSpace();
	if ( $req_size )
	{
		my $space = &getSpaceFormatHuman( $req_size );
		my $msg =
		  "Supportsave cannot be generated because '/tmp' needs '$space' Bytes of free space";
		&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
	}

	my $ss_filename = &getSupportSave( $type );

	&httpDownloadResponse(
						   desc => $desc,
						   dir  => '/tmp',
						   file => $ss_filename
	);
	return;
}

# GET /system/version
sub get_version
{
	&zenlog( __FILE__ . q{:} . __LINE__ . q{:} . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	require Zevenet::SystemInfo;

	my $desc       = "Get version";
	my $zevenet    = &getGlobalConfiguration( 'version' );
	my $kernel     = &getKernelVersion();
	my $hostname   = &getHostname();
	my $date       = &getDate();
	my $applicance = &getApplianceVersion();

	my $params = {
				   'kernel_version'    => $kernel,
				   'zevenet_version'   => $zevenet,
				   'hostname'          => $hostname,
				   'system_date'       => $date,
				   'appliance_version' => $applicance,
	};
	my $body = { description => $desc, params => $params };

	&httpResponse( { code => 200, body => $body } );
	return;
}

# GET /system/info
sub get_system_info
{
	&zenlog( __FILE__ . q{:} . __LINE__ . q{:} . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );

	require Zevenet::SystemInfo;
	require Zevenet::User;
	require Zevenet::Zapi;

	my $desc = "Get the system information";

	my $zevenet       = &getGlobalConfiguration( 'version' );
	my $lang          = &getGlobalConfiguration( 'lang' );
	my $kernel        = &getKernelVersion();
	my $hostname      = &getHostname();
	my $date          = &getDate();
	my $applicance    = &getApplianceVersion();
	my $user          = &getUser();
	my @zapi_versions = &listZapiVersions();
	my $edition       = "community";

	my $platform = &getGlobalConfiguration( 'cloud_provider' );

	my $params = {
				   'system_date'             => $date,
				   'appliance_version'       => $applicance,
				   'kernel_version'          => $kernel,
				   'zevenet_version'         => $zevenet,
				   'hostname'                => $hostname,
				   'user'                    => $user,
				   'supported_zapi_versions' => \@zapi_versions,
				   'last_zapi_version'       => $zapi_versions[-1],
				   'edition'                 => $edition,
				   'language'                => $lang,
				   'platform'                => $platform,
	};
	my $body = { description => $desc, params => $params };
	&httpResponse( { code => 200, body => $body } );
	return;
}

#  POST /system/language
sub set_language
{
	&zenlog( __FILE__ . q{:} . __LINE__ . q{:} . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $json_obj = shift;

	my $desc = "Modify the WebGUI language";

	my $params = &getZAPIModel( "system_language-modify.json" );

	# Check allowed parameters
	my $error_msg = &checkZAPIParams( $json_obj, $params, $desc );

	if ( $error_msg )
	{
		&httpErrorResponse( code => 400, desc => $desc, msg => $error_msg );
	}

	# Check allowed parameters
	&setGlobalConfiguration( 'lang', $json_obj->{ language } );

	&httpResponse(
				{
				  code => 200,
				  body => {
							description => $desc,
							params      => { language => &getGlobalConfiguration( 'lang' ) },
							message => "The WebGui language has been configured successfully"
				  }
				}
	);
	return;
}

#  GET /system/language
sub get_language
{
	&zenlog( __FILE__ . q{:} . __LINE__ . q{:} . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );

	my $desc = "List the WebGUI language";
	my $lang = &getGlobalConfiguration( 'lang' ) // 'en';

	&httpResponse(
				   {
					 code => 200,
					 body => {
							   description => $desc,
							   params      => { lang => $lang },
					 }
				   }
	);
	return;
}

# GET /system/packages
sub get_packages_info
{
	&zenlog( __FILE__ . q{:} . __LINE__ . q{:} . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );

	require Zevenet::System::Packages;
	my $desc = "Zevenet packages list info";
	my $output;

	$output = &getSystemPackagesUpdatesList();

	$output->{ number } += 0 if ( defined $output->{ number } );

	&httpResponse(
				 { code => 200, body => { description => $desc, params => $output } } );
	return;
}

1;
