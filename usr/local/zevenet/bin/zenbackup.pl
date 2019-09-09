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

use Zevenet::Log;
use Zevenet::Config;

my $name   = $ARGV[0];
my $action = $ARGV[1];

my $backupdir = &getGlobalConfiguration( 'backupdir' );
my $tar       = &getGlobalConfiguration( 'tar' );
my $exclude_52_60 =
  "--exclude=hostname --exclude=zlbcertfile.pem --exclude=/etc/cron.d/zevenet --exclude=global.conf --exclude=ssh_brute_force.txt --exclude=cluster.conf";

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

if ( $action eq "-D52to60" )
{
	print
	  "Importing from Zevenet 5.2 to Zevenet 6.0, using $backupdir\/backup-$name.tar.gz\n";
	print
	  "A snapshot before to continue is recommended for Virtual Load Balancers...\n";
	if ( !-e "$backupdir\/backup-$name.tar.gz" )
	{
		print "The given file doesn't exist...\n";
		exit;
	}
	print
	  "Will be kept: current hostname, global.conf and activation certificate file.\n";
	print "Cluster config file will not be imported\n";
	print "Press a key to start...\n";
	<STDIN>;

	my @eject = `$tar $exclude_52_60 -xvzf $backupdir\/backup-$name.tar.gz -C /`;
	print "@eject\n";
	print "Configuration files have been moved to local system.\n";

	#migrating config files
	my $MIG_DIR = "/usr/local/zevenet/migrating/";
	my @listing = `ls $MIG_DIR`;
	foreach my $file ( @listing )
	{
		print "Running Migration: ${MIG_DIR}${file}\n";
		my @run = `${MIG_DIR}${file}`;
	}

	print
	  "A restart of the load balancer is pending in order to apply the changes...\n";
}
