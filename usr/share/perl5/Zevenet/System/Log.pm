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

=begin nd
Function: getLogs

	Get list of log files.

Parameters:
	none - .

Returns:
	scalar - Array reference.

	Array element example:

	{
		'file' => $line,
		'date' => $datetime_string
	}

See Also:
	zapi/v3/system.cgi
=cut

sub getLogs
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my @logs;
	my $logdir = &getGlobalConfiguration( 'logdir' );

	require Zevenet::File;

	opendir ( DIR, $logdir );
	my @files = readdir ( DIR );
	closedir ( DIR );

	foreach my $line ( @files )
	{
		# not list if it is a directory
		next if -d "$logdir/$line";

		my $filepath = "$logdir/$line";
		chomp ( $filepath );

		push @logs, { 'file' => $line, 'date' => &getFileDateGmt( $filepath ) };
	}

	return \@logs;
}

=begin nd
Function: getLogLines

	Show a number of the last lines of a log file

Parameters:
	logFile - log file name in /var/log
	lines - number of lines to show

Returns:
	array - last lines of log file

See Also:
	zapi/v31/system.cgi
=cut

sub getLogLines
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my ( $logFile, $lines_number ) = @_;

	my @lines;
	my $path = &getGlobalConfiguration( 'logdir' );
	my $tail = &getGlobalConfiguration( 'tail' );

	if ( $logFile =~ /\.gz$/ )
	{
		my $zcat = &getGlobalConfiguration( 'zcat' );
		@lines =
		  @{ &logAndGet( "$zcat ${path}/$logFile | $tail -n $lines_number", "array" ) };
	}
	else
	{
		@lines = @{ &logAndGet( "$tail -n $lines_number ${path}/$logFile", "array" ) };
	}

	return \@lines;
}

1;

