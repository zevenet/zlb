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

=begin nd
Function: getSysGroupList

List all Operating System groups

Parameters:
	None - .

Returns:
	Array - List of groups

=cut

sub getSysGroupList
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );

	my @groupSet = ();
	my $group_file = &openlock( "/etc/group", "r" );
	while ( my $group = <$group_file> )
	{
		push ( @groupSet, $1 ) if ( $group =~ m/(\w+):x:.*/g );
	}
	close $group_file;

	return @groupSet;

}

=begin nd
Function: getSysUserList

List all Operating System users

Parameters:
	None - .

Returns:
	Array - List of users

=cut

sub getSysUserList
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );

	my @userSet = ();
	my $user_file = &openlock( "/etc/passwd", "r" );
	while ( my $user = <$user_file> )
	{
		push ( @userSet, $1 ) if ( $user =~ m/(\w+):x:.*/g );
	}
	close $user_file;

	return @userSet;

}

=begin nd

Function: getSysUserExists

	Check if a user exists in the Operting System

Parameters:
	User - User name

Returns:
	Integer - 1 if the user exists or 0 if it doesn't exist

=cut

sub getSysUserExists
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $user = shift;

	my $out = 0;
	$out = 1 if ( grep ( /^$user$/, &getSysUserList() ) );

	return $out;
}

=begin nd

Function: getSysGroupExists

	Check if a group exists in the Operting System

Parameters:
	Group - group name

Returns:
	Integer - 1 if the group exists or 0 if it doesn't exist

=cut

sub getSysGroupExists
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $group = shift;

	my $out = 0;
	$out = 1 if ( grep ( /^$group$/, &getSysGroupList() ) );

	return $out;
}

1;

