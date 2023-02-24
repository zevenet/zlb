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

# Description:
# Migrate from old Farmguardian configuration file to new Farmguardian configuration format

use strict;
use warnings;
use Zevenet::Log;
use Zevenet::Config;

my $conf_dir = &getGlobalConfiguration( 'configdir' );
my $fg_conf  = "$conf_dir/farmguardian.conf";

use Zevenet::File;
use Zevenet::FarmGuardian;

opendir ( DIR, $conf_dir ) or return;
my $index = 0;
while ( my $file = readdir ( DIR ) )
{
	if ( $file =~ /_guardian\.conf$/ )
	{
		print " + Migrating Farmguardian file $conf_dir/$file ...\n";
		my $file_content = &getFile( "$conf_dir/$file" );
		chomp $file_content;

		my $file_name;
		$file_name = $1 if $file =~ /^(.+)_guardian\.conf$/;
		my ( undef, $service ) = split ( /_/, $file_name );
		my ( $farm, $interval, $command, $cut, $log ) = split ( /:{3}/, $file_content );

		my @check_command = split ( / /, $command );
		my $farmguardian_name = "migrated" . $index++ . "_" . $check_command[0];
		my $farmguardian_ref = {
								 "description" => "check migrated from community backup",
								 "interval"    => $interval,
								 "command"     => "$command",
								 "cut_conns"   => "$cut",
								 "log"         => "$log"
		};

		print "      Create Farmguardian $farmguardian_name ... ";
		my $error = &createFGBlank( $farmguardian_name );
		if ( $error )
		{
			print "ERROR\n";
			next;
		}
		print "OK\n";
		print "      Update Farmguardian $farmguardian_name ... ";
		$error = &setFGObject( $farmguardian_name, $farmguardian_ref );

		#$error = &setTinyObj( $fg_conf, $farmguardian_name, $farmguardian_ref );
		if ( $error )
		{
			print "ERROR\n";
			next;
		}
		print "OK\n";
		print "      Link farm : $farm ";
		print " service : $service " if $service;
		print " to Farmguardian : $farmguardian_name ...";
		$error = &linkFGFarm( $farmguardian_name, $farm, $service );
		if ( $error )
		{
			print "ERROR\n";
			next;
		}
		print "OK\n";
		print "      Delete old configuration file : $file ... ";
		unlink "$conf_dir/$file";
		if ( -f "$conf_dir/$file" )
		{
			print "ERROR\n";
		}
		else
		{
			print "OK\n";
		}
	}
}
closedir ( DIR );
1;

