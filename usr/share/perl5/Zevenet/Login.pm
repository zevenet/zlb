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

my $passfile = "/etc/shadow";

=begin nd
Function: changePassword

	Change the password of a username.

Parameters:
	user - User name.
	newpass - New password.
	verifypass - New password again.

Returns:
	integer - ERRNO or return code .

Bugs:
	Verify password? Really?!

See Also:
	Zapi v3: <set_user>, <set_user_zapi>
=cut

sub changePassword    #($user, $newpass, $verifypass)
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my ( $user, $newpass, $verifypass ) = @_;

	$verifypass = $newpass if ( !$verifypass );

	##write \$ instead $
	$newpass =~ s/\$/\\\$/g;
	$verifypass =~ s/\$/\\\$/g;

	chomp ( $newpass );
	chomp ( $verifypass );

	##no move the next lines
	my $cmd = "
/usr/bin/passwd $user 2>/dev/null<<EOF
$newpass
$verifypass
EOF
	";

	my $output = system ( $cmd );
	if ( $output )
	{
		&zenlog( "Error trying to change the $user password", "error" );
	}
	else { &zenlog( "The $user password was changed", "info" ); }

	return $output;
}

=begin nd
Function: checkValidUser

	Validate an user's password.

Parameters:
	user - User name.
	curpasswd - Password.

Returns:
	scalar - Boolean. 1 for valid password, or 0 for invalid one.

Bugs:
	Not a bug, but using pam would be desirable.

See Also:
	Zapi v3: <set_user>
=cut

sub checkValidUser    #($user,$curpasswd)
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my ( $user, $curpasswd ) = @_;

	my $output = 0;
	use Authen::Simple::Passwd;
	my $passwd = Authen::Simple::Passwd->new( path => "$passfile" );
	if ( $passwd->authenticate( $user, $curpasswd ) )
	{
		$output = 1;
	}

	return $output;
}

1;

