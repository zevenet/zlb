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

use Unix::Syslog qw(:macros :subs);    # Syslog macros

# Get the program name for zenlog
my $TAG = "[Log.pm]";
my $program_name =
    ( $0 ne '-e' ) ? $0
  : ( exists $ENV{ _ } && $ENV{ _ } !~ /enterprise.bin$/ ) ? $ENV{ _ }
  :                                                          $^X;

my $basename = ( split ( '/', $program_name ) )[-1];

=begin nd
Function: zenlog

	Write logs through syslog

	Usage:

		&zenlog($text, $priority, $tag);

	Examples:

		&zenlog("This is a message.", "info", "LSLB");
		&zenlog("Some errors happened.", "err", "FG");
		&zenlog("testing debug mode", "debug", "SYSTEM");


	The different debug levels are:
	1 - Command executions.
		API inputs.
	2 - The command standart output, when there isn't any error.
		API outputs.
		Parameters modified in configuration files.
	3 - (reserved)
	4 - (reserved)
	5 - Profiling.

Parametes:
	string - String to be written in log.
	type   - Log level. info, error, debug, debug2, warn
	tag    - RBAC, LSLB, GSLB, DSLB, IPDS, FG, NOTIF, NETWORK, MONITOR, SYSTEM, CLUSTER

Returns:
	none - .
=cut

sub zenlog    # ($string, $type)
{
	my $string = shift;              # string = message
	my $type   = shift // 'info';    # type   = log level (Default: info))
	my $tag    = shift // "";

	if ( $tag eq 'PROFILING' )
	{
		require Zevenet::Debug;
		return 0 if ( &debug() < 5 );
	}

	if ( $type =~ /^(debug)(\d*)$/ )
	{
		require Zevenet::Debug;

		# debug lvl
		my $debug_lvl = $2;
		$debug_lvl = 1 if not $debug_lvl;
		$type = $1;
		return 0 if ( &debug() lt $debug_lvl );
	}

	$tag = lc $tag    if $tag;
	$tag = "$tag :: " if $tag;

	# Get the program name
	my $program = $basename;

	#~ openlog( $program, 'pid', 'local0' );    #open syslog
	openlog( $program, LOG_PID, LOG_LOCAL0 );

	my @lines = split /\n/, $string;

	foreach my $line ( @lines )
	{
		#~ syslog( $type, "(" . uc ( $type ) . ") " . $line );
		syslog( LOG_INFO, "(" . uc ( $type ) . ") " . "${tag}$line" );
	}

	closelog();    #close syslog
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

sub zlog    # (@message)
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my @message = shift;

	#my ($package,   # 0
	#$filename,      # 1
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
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $command = shift;    # command string to log and run

	my $program     = $basename;
	my @cmd_output  = `$command 2>&1`;
	my $return_code = $?;

	if ( $return_code )
	{
		&zenlog( $program . " running: $command", "error", "SYSTEM" );
		&zenlog( "@cmd_output", "error", "error", "SYSTEM" );
		&zenlog( "last command failed!", "error", "SYSTEM" );
	}
	else
	{
		&zenlog( $program . " running: $command", "debug", "SYSTEM" );
	}

	# returning error code from execution
	return $return_code;
}

=begin nd
Function: logAndRunBG

	Non-blocking version of logging and running a command, returning execution error code.

Parameters:
	command - String with the command to be run.

Returns:
	boolean - true on error, false on success launching the command.
=cut

sub logAndRunBG    # ($command)
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $command = shift;    # command string to log and run

	my $program = $basename;

	my $return_code = system ( "$command >/dev/null 2>&1 &" );

	if ( $return_code )
	{
		&zenlog( $program . " running: $command", "error", "SYSTEM" );
		&zenlog( "last command failed!",          "error", "SYSTEM" );
	}
	else
	{
		&zenlog( $program . " running: $command", "debug", "SYSTEM" );
	}

	# return_code is -1 on error.

 # returns true on error launching the program, false on error launching the program
	return $return_code == -1;
}

sub zdie
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	require Carp;
	Carp->import();

	&zenlog( @_ );
	carp( @_ );
}

1;
