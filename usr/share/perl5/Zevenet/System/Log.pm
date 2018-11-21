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
	&zenlog(__FILE__ . ":" . __LINE__ . ":" . (caller(0))[3] . "( @_ )", "debug", "PROFILING" );
	my @logs;
	my $logdir = &getGlobalConfiguration( 'logdir' );

	opendir ( DIR, $logdir );
	my @files = readdir ( DIR );
	closedir ( DIR );

	foreach my $line ( @files )
	{
		# not list if it is a directory
		next if -d "$logdir/$line";

		use File::stat; # Cannot 'require' this module
		#~ use Time::localtime qw(ctime);

		require Time::localtime;
		Time::localtime->import;

		my $filepath = "$logdir/$line";
		chomp ( $filepath );
		my $datetime_string = ctime( stat ( $filepath )->mtime );
		$datetime_string = `date -d "${datetime_string}" +%F" "%T" "%Z -u`;
		push @logs, { 'file' => $line, 'date' => $datetime_string };
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
	&zenlog(__FILE__ . ":" . __LINE__ . ":" . (caller(0))[3] . "( @_ )", "debug", "PROFILING" );
	my ( $logFile, $lines_number ) = @_;

	my @lines;
	my $path = &getGlobalConfiguration( 'logdir' );
	my $tail = &getGlobalConfiguration( 'tail' );

	if ( $logFile =~ /\.gz$/ )
	{
		my $zcat = &getGlobalConfiguration( 'zcat' );
		@lines = `$zcat ${path}/$logFile | $tail -n $lines_number`;
	}
	else
	{
		@lines = `$tail -n $lines_number ${path}/$logFile`;
	}

	return \@lines;
}

1;
