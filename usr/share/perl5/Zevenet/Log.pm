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
	tag    - RBAC, LSLB, GSLB, DSLB, IPDS, FG, NOTIF, NETWORK, MONITOR, SYSTEM, CLUSTER, AWS

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
		$type = "debug5";
		require Zevenet::Debug;
		return 0 if ( &debug() < 5 );
	}

	if ( $type =~ /^(debug)(\d*)?$/ )
	{
		require Zevenet::Debug;

		# debug lvl
		my $debug_lvl = $2;
		$debug_lvl = 1 if not $debug_lvl;
		$type = "$1$debug_lvl";
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
		&zenlog( "out: @cmd_output", "error", "error", "SYSTEM" );
		&zenlog( "last command failed!", "error", "SYSTEM" );
	}
	else
	{
		&zenlog( $program . " running: $command", "debug",  "SYSTEM" );
		&zenlog( "out: @cmd_output",              "debug2", "SYSTEM" );
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

=begin nd
Function: zsystem

	Run a command with the environment parameters customized.

Parameters:
	exec - Command to run.

Returns:
	integer - Returns 0 on success or another value on failure

See Also:
	<runFarmGuardianStart>, <_runHTTPFarmStart>, <runHTTPFarmCreate>, <_runGSLBFarmStart>, <_runGSLBFarmStop>, <runGSLBFarmReload>, <runGSLBFarmCreate>, <setGSLBFarmStatus>
=cut

sub zsystem
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my ( @exec ) = @_;
	my $program = $basename;

	my @cmd_output = `. /etc/profile -notzenbui >/dev/null 2>&1 && @exec 2>&1`;
	my $out        = $?;

	if ( $out )
	{
		&zenlog( $program . " running: @exec", "error", "SYSTEM" );
		&zenlog( "@cmd_output", "error", "error", "SYSTEM" );
		&zenlog( "last command failed!", "error", "SYSTEM" );
	}
	else
	{
		&zenlog( $program . " running: @exec", "debug",  "SYSTEM" );
		&zenlog( "out: @cmd_output",           "debug2", "SYSTEM" );
	}

	return $out;
}

=begin nd
Function: logAndGet

	Execute a command in the system to get the output. If the command fails,
	it logs the error and returns a empty string or array.
	It returns only the standard output, it does not return stderr.

Parameters:
	command - String with the command to be run in order to get info from the system.
	output format - Force that the output will be convert to 'string' or 'array'. String by default
	stderr flag - If this parameter is different of 0, the stderr will be added to the command output '2>&1'

Returns:
	Array ref or string - data obtained from the system. The type of output is specified
	in the type input param

See Also:
	logAndRun

TODO:
	Add an option to manage exclusively the output error and discard the standard output

=cut

sub logAndGet
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $cmd        = shift;
	my $type       = shift // 'string';
	my $add_stderr = shift // 0;

	my $tmp_err = ( $add_stderr ) ? '&1' : "/tmp/err.log";
	my @print_err;

	my $out      = `$cmd 2>$tmp_err`;
	my $err_code = $?;
	&zenlog( "Executed (out: $err_code): $cmd", "debug", "system" );

	if ( $err_code and !$add_stderr )
	{
		# execute again, removing stdout and getting stderr
		if ( open ( my $fh, '<', $tmp_err ) )
		{
			local $/ = undef;
			my $err_str = <$fh>;
			&zenlog( "sterr: $err_str", "debug2", "SYSTEM" );
			close $fh;
		}
		else
		{
			&zenlog( "file '$tmp_err' not found", "error", "SYSTEM" );
		}
	}

	chomp ( $out );

	# logging if there is not any error
	if ( !@print_err )
	{
		&zenlog( "out: $out", "debug3", "SYSTEM" );
	}

	if ( $type eq 'array' )
	{
		my @out = split ( "\n", $out );
		return \@out;
	}

	return $out;
}

=begin nd
Function: logAndRunCheck

	It executes a command but is does not log anything if it fails. This functions
	is useful to check things in the system as if a process is running or doing connectibity tests.
	This function will log the command if the loglevel is greater than 1, and will
	log the error output if the loglevel is greater than 2.

Parameters:
	command - String with the command to be run.

Returns:
	integer - error code of the command. 0 on success or another value on failure

See Also:
	logAndRun

=cut

sub logAndRunCheck
{
	my $command = shift;
	my $program = $basename;

	my @cmd_output  = `$command 2>&1`;
	my $return_code = $?;

	if ( &debug() >= 2 )
	{
		&zenlog( $program . " err_code '$return_code' checking: $command",
				 "debug2", "SYSTEM" );
	}
	if ( &debug() >= 3 )
	{
		&zenlog( $program . " output: @cmd_output", "debug3", "SYSTEM" );
	}

	# returning error code of the execution
	return $return_code;
}

1;

