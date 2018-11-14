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
Function: getDns

	Get the dns servers.

Parameters:
	none - .

Returns:
	scalar - Hash reference.

	Example:

	$dns = {
			primary => "value",
			secundary => "value",
	};

See Also:
	zapi/v3/system.cgi
=cut

sub getDns
{
	my $dns;
	my $dnsFile = &getGlobalConfiguration( 'filedns' );

	if ( !-f $dnsFile )
	{
		return undef;
	}

	open FI, '<', $dnsFile;
	my @file = <FI>;
	close FI;

	my $index = 1;
	foreach my $line ( @file )
	{
		if ( $line =~ /nameserver\s+([^\s]+)/ )
		{
			$dns->{ 'primary' }   = $1 if ( $index == 1 );
			$dns->{ 'secondary' } = $1 if ( $index == 2 );

			$index++;
			last if ( $index > 2 );
		}
	}

	return $dns;
}

=begin nd
Function: setDns

	Set a primary or secondary dns server.

Parameters:
	dns - 'primary' or 'secondary'.
	value - ip addres of dns server.

Returns:
	none - .

Bugs:
	Returned value.

See Also:
	zapi/v3/system.cgi
=cut

sub setDns
{
	my ( $dns, $value ) = @_;

	my $dnsFile = &getGlobalConfiguration( 'filedns' );

	if ( !-f $dnsFile )
	{
		system ( &getGlobalConfiguration( 'touch' ) . " $dnsFile" );
	}

	require Tie::File;
	tie my @dnsArr, 'Tie::File', $dnsFile;

	my $index = 1;
	foreach my $line ( @dnsArr )
	{
		if ( $line =~ /\s*nameserver/ )
		{
			$line = "nameserver $value" if ( $index == 1 and $dns eq 'primary' );
			$line = "nameserver $value" if ( $index == 2 and $dns eq 'secondary' );

			$index++;
			last if ( $index > 2 );
		}
	}

	# if the secondary nameserver has not been found, add it
	push @dnsArr, "nameserver $value" if ( $index == 2 and $dns eq 'secondary' );

	untie @dnsArr;

	return 0;
}

1;
