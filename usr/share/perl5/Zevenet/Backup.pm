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

use File::stat;
use File::Basename;

=begin nd
Function: getBackup

	List the backups in the system.

Parameters:
	none - .

Returns:
	scalar - Array reference.

See Also:
	<getExistsBackup>, zapi/v3/system.cgi
=cut
sub getBackup
{
	&zenlog(__FILE__ . ":" . __LINE__ . ":" . (caller(0))[3] . "( @_ )", "debug", "PROFILING" );
	my @backups;
	my $backupdir = &getGlobalConfiguration( 'backupdir' );
	my $backup_re = &getValidFormat( 'backup' );

	opendir ( DIR, $backupdir );
	my @files = grep ( /^backup.*/, readdir ( DIR ) );
	closedir ( DIR );

	foreach my $line ( @files )
	{
		my $filepath = "$backupdir/$line";
		chomp ( $filepath );

		$line =~ s/backup-($backup_re).tar.gz/$1/;

		use Time::localtime qw(ctime);

		my $datetime_string = ctime( stat ( $filepath )->mtime );
		$datetime_string = `date -d "${datetime_string}" +%F"  "%T" "%Z -u`;
		push @backups, { 'name' => $line, 'date' => $datetime_string };

	}

	return \@backups;
}

=begin nd
Function: getExistsBackup

	Check if there is a backup with the given name.

Parameters:
	name - Backup name.

Returns:
	1     - if the backup exists.
	undef - if the backup does not exist.

See Also:
	zapi/v3/system.cgi
=cut
sub getExistsBackup
{
	&zenlog(__FILE__ . ":" . __LINE__ . ":" . (caller(0))[3] . "( @_ )", "debug", "PROFILING" );
	my $name = shift;
	my $find;

	foreach my $backup ( @{ &getBackup } )
	{
		if ( $backup->{ 'name' } =~ /^$name/, )
		{
			$find = 1;
			last;
		}
	}
	return $find;
}

=begin nd
Function: createBackup

	Creates a backup with the given name

Parameters:
	name - Backup name.

Returns:
	integer - ERRNO or return code of backup creation process.

See Also:
	zapi/v3/system.cgi
=cut
sub createBackup
{
	&zenlog(__FILE__ . ":" . __LINE__ . ":" . (caller(0))[3] . "( @_ )", "debug", "PROFILING" );
	my $name      = shift;
	my $zenbackup = &getGlobalConfiguration( 'zenbackup' );
	my $error     = system ( "$zenbackup $name -c 2> /dev/null" );

	if ( $error )
	{
		&zenlog( "$zenbackup $name -c 2> /dev/null" );
	}

	return $error;
}

=begin nd
Function: downloadBackup

	Get zapi client to download a backup file.

Parameters:
	backup - Backup name.

Returns:
	1 - on error.

	Does not return on success.

See Also:
	zapi/v3/system.cgi
=cut
sub downloadBackup
{
	&zenlog(__FILE__ . ":" . __LINE__ . ":" . (caller(0))[3] . "( @_ )", "debug", "PROFILING" );
	my $backup = shift;
	my $error;

	$backup = "backup-$backup.tar.gz";
	my $backupdir = &getGlobalConfiguration( 'backupdir' );
	open ( my $download_fh, '<', "$backupdir/$backup" );

	if ( -f "$backupdir\/$backup" && $download_fh )
	{
		my $cgi = &getCGI();
		print $cgi->header(
							-type            					=> 'application/x-download',
							-attachment      					=> $backup,
							'Content-length' 				   	=> -s "$backupdir/$backup",
							'Access-Control-Allow-Origin'      	=> "https://$ENV{ HTTP_HOST }/",
						  	'Access-Control-Allow-Credentials' 	=> 'true',
		);

		binmode $download_fh;
		print while <$download_fh>;
		close $download_fh;
		exit;
	}
	else
	{
		$error = 1;
	}
	return $error;
}

=begin nd
Function: uploadBackup

	Store an uploaded backup.

Parameters:
	filename - Uploaded backup file name.
	upload_filehandle - File handle or file content.

Returns:
	1     - on failure.
	undef - on success.

See Also:
	zapi/v3/system.cgi
=cut
sub uploadBackup
{
	&zenlog(__FILE__ . ":" . __LINE__ . ":" . (caller(0))[3] . "( )", "debug", "PROFILING" );

	my $filename          = shift;
	my $upload_filehandle = shift;

	my $error;
	my $backupdir = &getGlobalConfiguration( 'backupdir' );
	$filename = "backup-$filename.tar.gz";

	if ( !-f "$backupdir/$filename" )
	{
		open ( my $disk_fh, '>', "$backupdir/$filename" ) or die "$!";

		binmode $disk_fh;

		use MIME::Base64 qw( decode_base64 );
		print $disk_fh decode_base64( $upload_filehandle );

		close $disk_fh;
	}
	else
	{
		$error = 1;
	}

	return $error;
}

=begin nd
Function: deleteBackup

	Delete a backup.

Parameters:
	file - Backup name.

Returns:
	1     - on failure.
	undef - on success.

See Also:
	zapi/v3/system.cgi
=cut
sub deleteBackup
{
	&zenlog(__FILE__ . ":" . __LINE__ . ":" . (caller(0))[3] . "( @_ )", "debug", "PROFILING" );
	my $file      = shift;
	$file      = "backup-$file.tar.gz";
	my $backupdir = &getGlobalConfiguration( "backupdir" );
	my $filepath  = "$backupdir/$file";
	my $error;

	if ( -e $filepath )
	{
		unlink ( $filepath );
		&zenlog( "Deleted backup file $file", "info", "SYSTEM" );
	}
	else
	{
		&zenlog( "File $file not found", "warning", "SYSTEM" );
		$error = 1;
	}

	return $error;
}

=begin nd
Function: applyBackup

	Restore files from a backup.

Parameters:
	backup - Backup name.

Returns:
	integer - ERRNO or return code of restarting load balancing service.

See Also:
	zapi/v3/system.cgi
=cut
sub applyBackup
{
	&zenlog(__FILE__ . ":" . __LINE__ . ":" . (caller(0))[3] . "( @_ )", "debug", "PROFILING" );
	my $backup = shift;
	my $error;
	my $tar  = &getGlobalConfiguration( 'tar' );
	my $file = &getGlobalConfiguration( 'backupdir' ) . "/backup-$backup.tar.gz";

	my @eject = `$tar -xvzf $file -C /`;
	unlink '/zevenet_version';

	&zenlog( "Restoring backup $file", "info", "SYSTEM" );
	&zenlog( "unpacking files: @eject", "info", "SYSTEM" );
	$error = system ( "/etc/init.d/zevenet restart 2> /dev/null" );

	if ( !$error )
	{
		&zenlog( "Backup applied and Zen Load Balancer restarted...", "info", "SYSTEM" );
	}
	else
	{
		&zenlog( "Problem restarting Zen Load Balancer service", "info", "SYSTEM" );
	}

	return $error;
}

1;
