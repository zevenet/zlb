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
use warnings;
use Zevenet::Log;
use Zevenet::Config;

my $name   = $ARGV[0];
my $action = $ARGV[1];

my $backupdir = &getGlobalConfiguration( 'backupdir' );
my $tar       = &getGlobalConfiguration( 'tar' );

if ( $action eq "-c" )
{
	my $backupfor      = &getGlobalConfiguration( 'backupfor' );
	my $version        = &getGlobalConfiguration( 'version' );
	my $z_version_file = '/zevenet_version';
	my $backup_file    = "$backupdir\/backup-$name.tar.gz";

	open my $file, '>', $z_version_file;
	print $file "$version";
	close $file;

	zenlog( "Creating backup $backup_file" );

	my $cmd = "$tar -czf $backup_file $backupfor";
	zenlog( `$cmd 2>&1` );

	unlink $z_version_file;
}

if ( $action eq "-d" )
{
	my @eject = `$tar -xzf $backupdir\/backup-$name.tar.gz -C /`;
}
