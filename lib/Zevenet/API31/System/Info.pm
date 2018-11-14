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

# show license
sub get_license
{
	my $format = shift;

	my $desc = "Get license";
	my $licenseFile;
	my $file;

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

	open ( my $license_fh, '<', $licenseFile );
	{
		local $/ = undef;
		$file = <$license_fh>;
	}
	close $license_fh;

	&httpResponse({ code => 200, body => $file, type => 'text/plain' });
}

sub get_supportsave
{
	my $desc = "Get supportsave file";
	my @ss_output = `/usr/local/zevenet/app/zbin/supportsave 2>&1`;

	# get the last "word" from the first line
	my $first_line = shift @ss_output;
	my $last_word = ( split ( ' ', $first_line ) )[-1];

	my $ss_path = $last_word;
	my ( undef, $ss_filename ) = split ( '/tmp/', $ss_path );

	&httpDownloadResponse( desc => $desc, dir => '/tmp', file => $ss_filename );
}

# GET /system/version
sub get_version
{
	require Zevenet::SystemInfo;
	require Zevenet::Certificate;

	my $desc    = "Get version";
	my $uname   = &getGlobalConfiguration( 'uname' );
	my $zevenet = &getGlobalConfiguration( 'version' );

	my $kernel     = `$uname -r`;
	my $hostname   = &getHostname();
	my $date       = &getDate();
	my $applicance = &getApplianceVersion();

	chomp $kernel;

	my $params = {
				   'kernel_version'    => $kernel,
				   'zevenet_version'   => $zevenet,
				   'hostname'          => $hostname,
				   'system_date'       => $date,
				   'appliance_version' => $applicance,
	};
	my $body = { description => $desc, params => $params };

	&httpResponse( { code => 200, body => $body } );
}

1;
