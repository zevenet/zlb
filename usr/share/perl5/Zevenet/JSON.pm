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
require JSON::XS;
require Zevenet::Lock;

JSON::XS->import;
my $json = JSON::XS->new->utf8->pretty( 1 );
$json->canonical( [1] );

sub decodeJSONFile
{
	my $file = shift;

	my $file_str;
	my $fh = &openlock( $file, '<' );
	return undef if !defined $fh;

	{
		local $/ = undef;
		$file_str = <$fh>;
	}
	close $fh;

	my $f_json;
	eval { $f_json = $json->decode( $file_str ); };
	if ( $@ )
	{
		&zenlog( "Error decoding the file $file", 'error' );
		&zenlog( "json: $@",                      'debug' );
	}
	return $f_json;
}

sub encodeJSONFile
{
	my $f_json = shift;
	my $file   = shift;

	my $file_str;
	eval { $file_str = $json->encode( $f_json ); };
	if ( $@ )
	{
		&zenlog( "Error encoding the file $file" );
		&zenlog( "json: $@", 'debug' );
	}

	my $fh = &openlock( $file, '>' );
	return 1 if not defined $fh;

	print $fh $file_str;
	close $fh;
	return 0;
}

1;

