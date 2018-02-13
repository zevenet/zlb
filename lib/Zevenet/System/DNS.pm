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

	if ( !-e $dnsFile )
	{
		return undef;
	}

	require Tie::File;
	tie my @dnsArr, 'Tie::File', $dnsFile;

	#primary
	my @aux = split ( ' ', $dnsArr[0] );
	$dns->{ 'primary' } = $aux[1];

	# secondary
	if ( defined $dnsArr[1] )
	{
		@aux = split ( ' ', $dnsArr[1] );
		$dns->{ 'secondary' } = $aux[1];
	}
	else
	{
		$dns->{ 'secondary' } = "";
	}
	untie @dnsArr;

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
	my $output;
	my $line;

	if ( !-e $dnsFile )
	{
		$output = system ( &getGlobalConfiguration( 'touch' ) . " $dnsFile" );
	}

	require Tie::File;
	tie my @dnsArr, 'Tie::File', $dnsFile;

	if ( $dns eq 'primary' )
	{
		$line = 0;
	}

	# secondary:   $dns eq 'secondary'
	else
	{
		$line = 1;
	}

	$dnsArr[$line] = "nameserver $value";
	untie @dnsArr;

	return $output;
}

1;
