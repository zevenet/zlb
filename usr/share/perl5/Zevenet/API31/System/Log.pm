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
use Zevenet::System::Log;

#	GET	/system/logs
sub get_logs
{
	my $desc    = "Get logs";
	my $backups = &getLogs;

	&httpResponse(
		 { code => 200, body => { description => $desc, params => $backups } } );
}

#	GET	/system/logs/LOG
sub download_logs
{
	my $logFile = shift;

	my $desc     = "Download log file '$logFile'";
	my $logfiles = &getLogs();
	my $error    = 1;

	# check if the file exists
	foreach my $file ( @{$logfiles} )
	{
		if ( $file->{file} eq $logFile )
		{
			$error=0;
			last;
		}
	}

	if ( $error )
	{
		my $msg = "Not found $logFile file.";
		&httpErrorResponse( code => 404, desc => $desc, msg => $msg );
	}

	# Download function ends communication if itself finishes successful. It is not necessary send "200 OK" msg
	my $logdir = &getGlobalConfiguration( 'logdir' );

	&httpDownloadResponse( desc => $desc, dir => $logdir, file => $logFile );
}

#	GET	/system/logs/LOG/lines/LINES
sub show_logs
{
	my $logFile      = shift;
	my $lines_number = shift; # number of lines to show

	my $desc     = "Show a log file";
	my $logfiles = &getLogs;
	my $error    = 1;
	
	# check if the file exists
	foreach my $file ( @{ $logfiles } )
	{
		if ( $file->{ file } eq $logFile )
		{
			$error = 0;
			last;
		}
	}

	if ( $error )
	{
		my $msg = "Not found $logFile file.";
		&httpErrorResponse( code => 404, desc => $desc, msg => $msg );
	}

	my $lines = &getLogLines( $logFile, $lines_number );
	my $body = { description => $desc, log => $lines };

	&httpResponse( { code => 200, body => $body } );
}

1;
