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

use v5.14;
use strict;

use Zevenet::Log;

=begin nd
Function: getGlobalConfiguration

	Set the value of a configuration variable.

Parameters:
	parameter - Name of the global configuration variable. Optional.

Returns:
	scalar - Value of the configuration variable when a variable name is passed as an argument.
	scalar - Hash reference to all global configuration variables when no argument is passed.

See Also:
	Widely used.
=cut
sub getGlobalConfiguration
{
	my $parameter = shift;

	my $global_conf_filepath = "/usr/local/zevenet/config/global.conf";
	my $global_conf;

	open ( my $global_conf_file, '<', $global_conf_filepath );

	if ( !$global_conf_file )
	{
		my $msg = "Could not open $global_conf_filepath: $!";

		&zenlog( $msg );
		die $msg;
	}

	while ( my $conf_line = <$global_conf_file> )
	{
		next if $conf_line !~ /^\$/;

		# extract variable name and value
		$conf_line =~ /\$(\w+)\s*=\s*(?:"(.*)"|\'(.*)\');\s*$/;
		my $var_name  = $1;
		my $var_value = $2;

		# if the var value contains any variable
		if ( $var_value =~ /\$/ )
		{
			# replace every variable used in the $var_value by its content
			foreach my $var ( $var_value =~ /\$(\w+)/g )
			{
				$var_value =~ s/\$$var/$global_conf->{ $var }/;
			}
		}

		# early finish if the requested paremeter is found
		return $var_value if $parameter && $parameter eq $var_name;

		$global_conf->{ $var_name } = $var_value;
	}

	close $global_conf_file;

	return eval { $global_conf->{ $parameter } } if $parameter;
	return $global_conf;
}

=begin nd
Function: setGlobalConfiguration

	Set a value to a configuration variable

Parameters:
	param - Configuration variable name.
	value - New value to be set on the configuration variable.

Returns:
	scalar - 0 on success, or -1 if the variable was not found.

Bugs:
	Control file handling errors.

See Also:
	<applySnmpChanges>

	Zapi v3: <set_ntp>
=cut
sub setGlobalConfiguration		# ( parameter, value )
{
	my ( $param, $value ) = @_;

	my $global_conf_file = &getGlobalConfiguration ( 'globalcfg' );
	my $output = -1;
	
	require Tie::File;
	tie my @global_hf, 'Tie::File', $global_conf_file;

	foreach my $line ( @global_hf )
	{
		if ( $line=~ /^\$$param\s*=/ )
		{
			$line = "\$$param = \"$value\";";
			$output = 0;
		}
	}
	untie @global_hf;
	
	return $output;
}

1;
