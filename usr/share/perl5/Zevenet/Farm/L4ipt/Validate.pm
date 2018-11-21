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

=begin nd
Function: ismport

	Check if the string is a valid multiport definition

Parameters:
	port - Multiport string

Returns:
	String - "true" if port has a correct format or "false" if port has a wrong format

FIXME:
	Define regexp in check_functions.cgi and use it here

=cut
sub ismport    # ($string)
{
	&zenlog(__FILE__ . ":" . __LINE__ . ":" . (caller(0))[3] . "( @_ )", "debug", "PROFILING" );
	my $string = shift;

	chomp ( $string );
	if ( $string eq "*" )
	{
		return "true";
	}
	elsif ( $string =~ /^([1-9][0-9]*|[1-9][0-9]*\:[1-9][0-9]*)(,([1-9][0-9]*|[1-9][0-9]*\:[1-9][0-9]*))*$/ )
	{
		return "true";
	}
	else
	{
		return "false";
	}
}

1;
