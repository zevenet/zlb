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

use Zevenet::Backup;

#	GET	/system/backup
sub get_backup
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $desc    = "Get backups";
	my $backups = &getBackup();

	&httpResponse(
				{ code => 200, body => { description => $desc, params => $backups } } );
}

#	POST  /system/backup
sub create_backup
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $json_obj = shift;

	my $desc = "Create a backups";

	my $params = {
				   "name" => {
							   'valid_format' => 'backup',
							   'non_blank'    => 'true',
							   'required'     => 'true',
				   },
	};

	# Check allowed parameters
	my $error_msg = &checkZAPIParams( $json_obj, $params, $desc );
	return &httpErrorResponse( code => 400, desc => $desc, msg => $error_msg )
	  if ( $error_msg );

	if ( &getExistsBackup( $json_obj->{ 'name' } ) )
	{
		my $msg = "A backup already exists with this name.";
		&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
	}

	my $error = &createBackup( $json_obj->{ 'name' } );
	if ( $error )
	{
		my $msg = "Error creating backup.";
		&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
	}

	my $msg = "Backup $json_obj->{ 'name' } was created successfully.";
	my $body = {
				 description => $desc,
				 params      => $json_obj->{ 'name' },
				 message     => $msg,
	};

	&httpResponse( { code => 200, body => $body } );
}

#	GET	/system/backup/BACKUP
sub download_backup
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $backup = shift;

	my $desc = "Download a backup";

	if ( !&getExistsBackup( $backup ) )
	{
		my $msg = "Not found $backup backup.";
		&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
	}

	# Download function ends communication if itself finishes successful.
	# It is not necessary to send "200 OK" msg here
	&downloadBackup( $backup );

	my $msg = "Error, downloading backup.";
	&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
}

#	PUT	/system/backup/BACKUP
sub upload_backup
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $upload_filehandle = shift;
	my $name              = shift;

	my $desc = "Upload a backup";

	if ( !$upload_filehandle || !$name )
	{
		my $msg = "It's necessary to add a data binary file.";
		&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
	}
	elsif ( &getExistsBackup( $name ) )
	{
		my $msg = "A backup already exists with this name.";
		&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
	}
	elsif ( !&getValidFormat( 'backup', $name ) )
	{
		my $msg = "The backup name has invalid characters.";
		&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
	}

	my $error = &uploadBackup( $name, $upload_filehandle );
	if ( $error == 1 )
	{
		my $msg = "Error creating backup.";
		&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
	}
	elsif ( $error == 2 )
	{
		my $msg = "$name is not a valid backup.";
		&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
	}

	my $msg = "Backup $name was created successfully.";
	my $body = { description => $desc, params => $name, message => $msg };

	&httpResponse( { code => 200, body => $body } );
}

#	DELETE /system/backup/BACKUP
sub del_backup
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $backup = shift;

	my $desc = "Delete backup $backup'";

	if ( !&getExistsBackup( $backup ) )
	{
		my $msg = "$backup doesn't exist.";
		&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
	}

	my $error = &deleteBackup( $backup );

	if ( $error )
	{
		my $msg = "There was a error deleting list $backup.";
		&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
	}

	my $msg = "The list $backup has been deleted successfully.";
	my $body = {
				 description => $desc,
				 success     => "true",
				 message     => $msg,
	};

	&httpResponse( { code => 200, body => $body } );
}

#	POST /system/backup/BACKUP/actions
sub apply_backup
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $json_obj = shift;
	my $backup   = shift;

	my $desc = "Apply a backup to the system";

	my $params = {
				   "action" => {
								 'non_blank' => 'true',
								 'required'  => 'true',
								 'values'    => ['apply'],
				   },
				   "force" => {
								'non_blank' => 'true',
								'values'    => ['true', 'false'],
				   },
	};

	# Check allowed parameters
	my $error_msg = &checkZAPIParams( $json_obj, $params, $desc );
	return &httpErrorResponse( code => 400, desc => $desc, msg => $error_msg )
	  if ( $error_msg );

	if ( !&getExistsBackup( $backup ) )
	{
		my $msg = "Not found $backup backup.";
		&httpErrorResponse( code => 404, desc => $desc, msg => $msg );
	}

	my $b_version   = &getBackupVersion( $backup );
	my $sys_version = &getGlobalConfiguration( 'version' );
	if ( $b_version ne $sys_version )
	{
		if ( !exists $json_obj->{ force }
			 or ( exists $json_obj->{ force } and $json_obj->{ force } ne 'true' ) )
		{
			my $msg =
			  "The backup version ($b_version) is different to the Zevenet version ($sys_version). The parameter 'force' must be used to force the backup applying.";
			&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
		}
		else
		{
			&zenlog(
				"Applying The backup version ($b_version) is different to the Zevenet version ($sys_version)."
			);
		}
	}

	my $msg =
	  "The backup was properly applied. Some changes need a system reboot to work.";
	my $error = &applyBackup( $backup );

	if ( $error )
	{
		$msg = "There was a error applying the backup.";
		&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
	}

	&httpResponse( { code => 200, body => { description => $desc, msg => $msg } } );
}

1;

