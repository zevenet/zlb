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
use feature 'state';
use CGI::Simple;

$CGI::Simple::DISABLE_UPLOADS = 0;                # enable uploads
$CGI::Simple::POST_MAX        = 1_048_576_000;    # allow 1000MB uploads

=begin nd
Function: getCGI

	Get a cgi object only once per http request and reuse the same object if the function is used more than once.

Parameters:
	none - .

Returns:
	CGI Object - CGI Object reference.

Bugs:

See Also:
	zapi/v3/zapi.cgi, zapi/v3/certificates.cgi, zapi/v3/system.cgi, <downloadBackup>
=cut

sub getCGI
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	state $cgi = CGI::Simple->new();

	return $cgi;
}

=begin nd
Function: getCgiParam

	Get CGI variables.

	This functions can be used in two diferent ways:

	1- When a variable name is passed as an argument, the variable value is returned:

		$var = &getCgiParam( 'variableName' );

	2- When no arguments are passed, a hash reference with all the variables is returned:

		$hash_ref = &getCgiParam();
		print $hash_ref->{ 'variableName' };

Parameters:
	String - CGI variable name. Optional.

Returns:
	Scalar - Variable value. When a variable name has been passed as an argument.
	Scalar - Reference to a hash with all the CGI variables. When the function is run without arguments.

Bugs:

See Also:
	zapi/v3/zapi.cgi
=cut

sub getCgiParam
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $variable = shift;

	my $cgi = getCGI();

	return eval { $cgi->param( $variable ) } if $variable;

	return $cgi->Vars;
}

1;

