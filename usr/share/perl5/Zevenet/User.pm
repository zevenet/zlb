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
Function: getUser

	Get the user that is executing the API or WEBGUI

Parameters:
	User - User name

Returns:
	String - User name

=cut

sub getUser
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );

	#~ if ( !exists $ENV{ REQ_USER } || !defined $ENV{ REQ_USER } )
	#~ {
	#~ &zenlog( 'User name not defined', 'Warning' );
	#~ }

	return $ENV{ REQ_USER } // '';
}

=begin nd
Function: setUser

	Save the user that is executing the API or WEBGUI

Parameters:
	None - .

Returns:
	String - User name

=cut

sub setUser
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $user = shift;
	$ENV{ REQ_USER } = $user;
}

1;
