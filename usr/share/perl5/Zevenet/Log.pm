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

use Unix::Syslog qw(:macros :subs);  # Syslog macros
#~ use Sys::Syslog;                          #use of syslog
#~ use Sys::Syslog qw(:standard :macros);    #standard functions for Syslog

# Get the program name for zenlog
my $run_cmd_name = ( split '/', $0 )[-1];
$run_cmd_name = ( split '/', "$ENV{'SCRIPT_NAME'}" )[-1] if $run_cmd_name eq '-e';
$run_cmd_name = ( split '/', $^X )[-1] if ! $run_cmd_name;

=begin nd
Function: zenlog

	Write logs through syslog

	Usage:

		&zenlog($text, $priority);

	Examples:

		&zenlog("This is test.", "info");
		&zenlog("Some errors happended.", "err");
		&zenlog("testing debug mode", "debug");

Parameters:
	string - String to be written in log.
	type   - Log level.

Returns:
	none - .
=cut
sub zenlog    # ($string, $type)
{
	my $string = shift;            # string = message
	my $type = shift // 'info';    # type   = log level (Default: info))

	# Get the program name
	my $program = $run_cmd_name;

	#~ openlog( $program, 'pid', 'local0' );    #open syslog
	openlog( $program, LOG_PID, LOG_LOCAL0 );

	my @lines = split /\n/, $string;

	foreach my $line ( @lines )
	{
		#~ syslog( $type, "(" . uc ( $type ) . ") " . $line );
		syslog( LOG_INFO, "(" . uc ( $type ) . ") " . $line );
	}

	closelog();                              #close syslog
}

=begin nd
Function: zlog

	Log some call stack information with an optional message.

	This function is only used for debugging pourposes.

Parameters:
	message - Optional message to be printed with the stack information.

Returns:
	none - .
=cut
sub zlog                                          # (@message)
{
	my @message = shift;

	#my ($package,		# 0
	#$filename,		# 1
	#$line,          # 2
	#$subroutine,    # 3
	#$hasargs,       # 4
	#$wantarray,     # 5
	#$evaltext,      # 6
	#$is_require,    # 7
	#$hints,         # 8
	#$bitmask,       # 9
	#$hinthash       # 10
	#) = caller (1);	 # arg = number of suroutines back in the stack trace

	#~ use Data::Dumper;
	&zenlog(   '>>> '
			 . ( caller ( 3 ) )[3] . ' >>> '
			 . ( caller ( 2 ) )[3] . ' >>> '
			 . ( caller ( 1 ) )[3]
			 . " => @message" );

	return;
}

=begin nd
Function: logAndRun

	Log and run the command string input parameter returning execution error code.

Parameters:
	command - String with the command to be run.

Returns:
	integer - ERRNO or return code returned by the command.

See Also:
	Widely used.
=cut
sub logAndRun    # ($command)
{
	my $command = shift;    # command string to log and run
	my $return_code;
	my @cmd_output;

	my $program = ( split '/', $0 )[-1];
	$program = "$ENV{'SCRIPT_NAME'}" if $program eq '-e';
	$program .= ' ';
	# &zenlog( (caller (2))[3] . ' >>> ' . (caller (1))[3]);

	require Zevenet::Debug;
	if ( &debug )
	{
		&zenlog( $program . "running: $command" );

		@cmd_output = `$command 2>&1`;
		$return_code = $?;

		if ( $return_code )
		{
			&zenlog( "@cmd_output" );
			&zenlog( "last command failed!" );
		}
	}
	else
	{
		system ( "$command >/dev/null 2>&1" );
		$return_code = $?;
		&zenlog( $program . "failed: $command" ) if $return_code;
	}

	# returning error code from execution
	return $return_code;
}

sub zdie
{
	require Carp;
	Carp->import();

	&zenlog( @_ );
	carp( @_ );
}

1;
