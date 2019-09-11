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

use Fcntl ':flock';    #use of lock functions

require Zevenet::Log;

my $lock_file = undef;
my $lock_fh   = undef;

# generate a lock file based on a input path
sub getLockFile
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $lock = shift;

	$lock =~ s/\//_/g;
	$lock = "/tmp/$lock.lock";

	return $lock;
}

=begin nd
Function: getLockStatus

	This function responses if a farm has pending changes waiting for restarting

Parameters:
	farmname - Farm name

Returns:
	Integer - 1 if the farm has to be restarted or 0 if it is not

NOTE:
	Generic function

=cut

sub getLockStatus
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $fname = shift;

	my $lfile = &getLockFile( $fname );

	return 1 if ( -e $lfile );
	return 0;
}

=begin nd
Function: openlock

	Open file and lock it, return the filehandle.

	Usage:

		my $filehandle = &openlock( $path );
		my $filehandle = &openlock( $path, 'r' );

	Lock is exclusive when the file is openend for writing.
	Lock is shared when the file is openend for reading.
	So only opening for writing is blocking the file for other uses.

	Opening modes:
		r - Read
		w - Write
		a - Append

		t - text mode. To enforce encoding UTF-8.
		b - binary mode. To make sure no information is lost.

	'r', 'w' and 'a' are mutually exclusive.
	't' and 'b' are mutually exclusive.

	If neither 't' or 'b' are used on the mode parameter, the default Perl mode is used.

	Take in mind, if you are executing process in parallel, if any of them remove the tmp locking file,
	the resource will be unlocked.

Parameters:
	path - Absolute or relative path to the file to be opened.
	mode - Mode used to open the file.

Returns:
	scalar - Filehandle
=cut

sub openlock    # ( $path, $mode )
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $path = shift;
	my $mode = shift // '';

	$mode =~ s/a/>>/;    # append
	$mode =~ s/w/>/;     # write
	$mode =~ s/r/</;     # read

	my $binmode  = $mode =~ s/b//;
	my $textmode = $mode =~ s/t//;

	my $encoding = '';
	$encoding = ":encoding(UTF-8)" if $textmode;
	$encoding = ":raw :bytes"      if $binmode;

	open ( my $fh, "$mode $encoding", $path )
	  or do { &zenlog( "Error openning the file $path" ); return undef; };

	binmode $fh if $fh && $binmode;

	if ( $mode =~ />/ )
	{
		# exclusive lock for writing
		flock $fh, LOCK_EX;
	}
	else
	{
		# shared lock for reading
		flock $fh, LOCK_SH;
	}

	return $fh;
}

=begin nd
Function: ztielock

	tie aperture with lock

	Usage:

		$handleArray = &tielock($file);

	Examples:

		$handleArray = &tielock("test.dat");
		$handleArray = &tielock($filename);

Parameters:
	file_name - Path to File.

Returns:
	scalar - Reference to the array with the content of the file.

Bugs:
	Not used yet.
=cut

sub ztielock    # ($file_name)
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $array_ref = shift;    #parameters
	my $file_name = shift;    #parameters

	require Tie::File;

	my $o = tie @{ $array_ref }, "Tie::File", $file_name;
	$o->flock;
}

sub copyLock
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $ori = shift;
	my $dst = shift;

	my $fhOri = &openlock( $ori, 'r' ) or return 1;
	my $fhDst = &openlock( $dst, 'w' ) or do { close $fhOri; return 1; };

	foreach my $line ( <$fhOri> )
	{
		print $fhDst $line;
	}

	close $fhOri;
	close $fhDst;

	return 0;
}

=begin nd
Function: lockResource

	lock or release an API resource.

	Usage:

		$handleArray = &tielock($file, $oper);

	Examples:

		$handleArray = &tielock("test.dat", "l");

Parameters:
	resource - Path to file.
	operation - l (lock), u (unlock), ud (unlock, delete the lock file), r (read)

Bugs:
	Not used yet.
=cut

sub lockResource
{
	my $resource = shift;
	my $oper     = shift;    # l (lock), r (release), rd (release, delete)

	if ( $oper =~ /l/ )
	{
		$lock_file = &getLockFile( $resource );
		$lock_fh = &openlock( $lock_file, 'w' );
	}
	elsif ( $oper =~ /u/ )
	{
		close $lock_fh;
		unlink $lock_file if ( $oper =~ /d/ );
	}
	elsif ( $oper =~ /r/ )
	{
		$lock_file = &getLockFile( $resource );
		$lock_fh = &openlock( $lock_file, 'r' );
	}

	return;
}

1;
