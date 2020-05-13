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

my $eload;
$eload = 1 if ( eval { require Zevenet::ELoad; } );

=begin nd
Function: getZAPI

	Get zapi status

Parameters:
	name - 'status' to get if the user 'zapi' is enabled, or 'zapikey' to get the 'zapikey'.

Returns:
	For 'status': Boolean. 'true' if the zapi user is enabled, or 'false' if it is disabled.

	For 'zapikey': Returns the current zapikey.

See Also:
	zapi/v3/system.cgi
=cut

sub getZAPI    #($name)
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my ( $name ) = @_;

	use File::Grep 'fgrep';

	my $result = "false";

	#return if zapi user is enabled or not true = enable, false = disabled
	if ( $name eq "status" )
	{
		if ( fgrep { /^zapi/ } &getGlobalConfiguration( 'htpass' ) )
		{
			$result = "true";
		}
	}
	elsif ( $name eq "zapikey" )
	{
		$result = &getGlobalConfiguration( 'zapikey' );
	}

	return $result;
}

=begin nd
Function: setZAPI

	Set zapi values

Parameters:
	name - Actions to be taken: 'enable', 'disable', 'randomkey' to set a random key, or 'key' to set the key specified in value.

		enable - Enables the user 'zapi'.
		disable - Disables the user 'zapi'.
		randomkey - Generates a random key.
		key - Sets $value a the zapikey.

	value - New key to be used. Only apply when the action 'key' is used.

Returns:
	none - .

Bugs:
	-setGlobalConfig should be used to set the zapikey.
	-Randomkey is not used.

See Also:
	zapi/v3/system.cgi
=cut

sub setZAPI    #($name,$value)
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my ( $name, $value ) = @_;

	my $globalcfg = &getGlobalConfiguration( 'globalcfg' );

	#Enable ZAPI
	if ( $name eq "enable" )
	{
		my $cmd = "adduser --system --shell /bin/false --no-create-home zapi";
		return &logAndRun( $cmd );
	}

	#Disable ZAPI
	if ( $name eq "disable" )
	{
		my $deluser_bin = &getGlobalConfiguration( 'deluser_bin' );
		my $cmd         = "$deluser_bin zapi";
		return &logAndRun( $cmd );
	}

	#Set Random key for zapi
	if ( $name eq "randomkey" )
	{
		require Tie::File;
		my $random = &setZAPIKey( 64 );
		tie my @contents, 'Tie::File', "$globalcfg";
		foreach my $line ( @contents )
		{
			if ( $line =~ /zapi/ )
			{
				$line =~ s/^\$zapikey.*/\$zapikey="$random"\;/g;
			}
		}
		untie @contents;
	}

	#Set ZAPI KEY
	if ( $name eq "key" )
	{
		if ( $eload )
		{
			$value = &eload(
							 module => 'Zevenet::Code',
							 func   => 'setCryptString',
							 args   => [$value],
			);
		}

		require Tie::File;
		tie my @contents, 'Tie::File', "$globalcfg";

		foreach my $line ( @contents )
		{
			if ( $line =~ /zapi/ )
			{
				$line =~ s/^\$zapikey.*/\$zapikey="$value"\;/g;
			}
		}
		untie @contents;

		# Update zapikey global configuration
		&getGlobalConfiguration( 'zapikey', 1 );
	}
}

=begin nd
Function: setZAPIKey

	Generate random key for ZAPI user.

Parameters:
	passwordsize - Number of characters in the new key.

Returns:
	string - Random key.

See Also:
	<setZAPI>
=cut

sub setZAPIKey    #()
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $passwordsize = shift;

	my @alphanumeric = ( 'a' .. 'z', 'A' .. 'Z', 0 .. 9 );
	my $randpassword = join '', map $alphanumeric[rand @alphanumeric],
	  0 .. $passwordsize;

	return $randpassword;
}

sub validZapiKey    # ()
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );

	my $validKey = 0;                 # output
	my $key      = "HTTP_ZAPI_KEY";

	require Zevenet::User;
	if ( exists $ENV{ $key } )        # zapi key was provided
	{
		if (
			 &getZAPI( "status" ) eq "true"              # zapi user is enabled
			 && &getZAPI( "zapikey" ) eq $ENV{ $key }    # matches key
		  )
		{
			&setUser( 'root' );
			$validKey = 1;
		}
		elsif ( $eload )
		{
			# get a RBAC user
			my $user = &eload(
							   module => 'Zevenet::RBAC::User::Core',
							   func   => 'validateRBACUserZapi',
							   args   => [$ENV{ $key }],
			);
			if ( $user )
			{
				&setUser( $user );
				$validKey = 1;
			}
		}
	}

	return $validKey;
}

sub listZapiVersions
{
	my $version_st = &getGlobalConfiguration( "zapi_versions" );
	my @versions = split ( ' ', $version_st );

	return sort @versions;
}

1;

