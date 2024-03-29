#!/usr/bin/perl
###############################################################################
#
#    ZEVENET Software License
#    This file is part of the ZEVENET Load Balancer software package.
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
use warnings;
use Zevenet::Backup;

#	GET	/system/backup
sub get_backup
{
	&zenlog( __FILE__ . q{:} . __LINE__ . q{:} . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $desc    = "Get backups";
	my $backups = &getBackup();

	&httpResponse(
				{ code => 200, body => { description => $desc, params => $backups } } );
	return;
}

#	POST  /system/backup
sub create_backup
{
	&zenlog( __FILE__ . q{:} . __LINE__ . q{:} . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $json_obj = shift;

	my $desc           = "Create a backups";
	my @requiredParams = ( "name" );

	my $param_msg = getValidReqParams( $json_obj, \@requiredParams );
	if ( $param_msg )
	{
		&httpErrorResponse( code => 400, desc => $desc, msg => $param_msg );
	}

	if ( &getExistsBackup( $json_obj->{ 'name' } ) )
	{
		my $msg = "A backup already exists with this name.";
		&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
	}

	if ( not &getValidFormat( 'backup', $json_obj->{ 'name' } ) )
	{
		my $msg = "The backup name has invalid characters.";
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
	return;
}

#	GET	/system/backup/BACKUP
sub download_backup
{
	&zenlog( __FILE__ . q{:} . __LINE__ . q{:} . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $backup = shift;

	my $desc = "Download a backup";

	if ( not &getExistsBackup( $backup ) )
	{
		my $msg = "Not found $backup backup.";
		&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
	}

	# Download function ends communication if itself finishes successful.
	# It is not necessary to send "200 OK" msg here
	&downloadBackup( $backup );

	my $msg = "Error, downloading backup.";
	&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
	return;
}

#	PUT	/system/backup/BACKUP
sub upload_backup
{
	&zenlog( __FILE__ . q{:} . __LINE__ . q{:} . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $upload_filehandle = shift;
	my $name              = shift;

	my $desc = "Upload a backup";

	if ( not $upload_filehandle or not $name )
	{
		my $msg = "It's necessary add a data binary file.";
		&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
	}
	elsif ( &getExistsBackup( $name ) )
	{
		my $msg = "A backup already exists with this name.";
		&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
	}
	elsif ( not &getValidFormat( 'backup', $name ) )
	{
		my $msg = "The backup name has invalid characters.";
		&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
	}

	my $error = &uploadBackup( $name, $upload_filehandle );
	if ( $error )
	{
		my $msg = "Error creating backup.";
		&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
	}

	my $msg = "Backup $name was created successfully.";
	my $body = { description => $desc, params => $name, message => $msg };

	&httpResponse( { code => 200, body => $body } );
	return;
}

#	DELETE /system/backup/BACKUP
sub del_backup
{
	&zenlog( __FILE__ . q{:} . __LINE__ . q{:} . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $backup = shift;

	my $desc = "Delete backup $backup'";

	if ( not &getExistsBackup( $backup ) )
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
	return;
}

#	POST /system/backup/BACKUP/actions
sub apply_backup
{
	&zenlog( __FILE__ . q{:} . __LINE__ . q{:} . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $json_obj = shift;
	my $backup   = shift;

	my $desc        = "Apply a backup to the system";
	my @allowParams = ( "action" );
	my $msg         = &getValidOptParams( $json_obj, \@allowParams );

	if ( $msg )
	{
		&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
	}

	if ( not &getExistsBackup( $backup ) )
	{
		my $msg = "Not found $backup backup.";
		&httpErrorResponse( code => 404, desc => $desc, msg => $msg );
	}
	elsif ( not &getValidFormat( 'backup_action', $json_obj->{ 'action' } ) )
	{
		my $msg = "Error, it's necessary add a valid action";
		&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
	}

	my $error = &applyBackup( $backup );

	if ( $error )
	{
		my $msg = "There was a error applying the backup.";
		&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
	}

	&httpResponse(
			   { code => 200, body => { description => $desc, params => $json_obj } } );
	return;
}

1;
