#!/usr/bin/perl
###############################################################################
#
#    ZEVENET Software License
#    This file is part of the ZEVENET Load Balancer software package.
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
use warnings;

=begin nd
Function: moveByIndex

	This function moves an element of an list to another position using its index.
	This funcion uses the original array to apply the changes, so it does not return anything.

Parameters:
	Array - Array reference with the list to modify.
	Origin index - Index of the element will be moved.
	Destination index - Position in the list that the element will have.

Returns:
	None - .

=cut

sub moveByIndex
{
	&zenlog( __FILE__ . q{:} . __LINE__ . q{:} . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my ( $list, $ori_index, $dst_index ) = @_;

	my $elem = $list->[$ori_index];

	# delete item
	splice ( @{ $list }, $ori_index, 1 );

	# add item
	splice ( @{ $list }, $dst_index, 0, $elem );
	return;
}

=begin nd
Function: getARRIndex

	It retuns the index of for a value of a list. It retunrs the first index where the value appears.

Parameters:
	Array ref - Array reference with the list to look for.
	Value - Value to get its index

Returns:
	Integer - index for an array value

=cut

sub getARRIndex
{
	&zenlog( __FILE__ . q{:} . __LINE__ . q{:} . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my ( $list, $item ) = @_;
	my $ind;

	my $id = 0;
	foreach my $it ( @{ $list } )
	{
		if ( $it eq $item )
		{
			$ind = $id;
			last;
		}
		$id++;
	}

	# fixme:  return undef when the index is not found

	return $ind;
}

=begin nd
Function: uniqueArray

	It gets an array for reference and it removes the items that are repeated.
	The original input array is modified. This function does not return anything

Parameters:
	Array ref - It is the array is going to be managed

Returns:
	None - .

=cut

sub uniqueArray
{
	&zenlog( __FILE__ . q{:} . __LINE__ . q{:} . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $arr = shift;

	my %hold = ();
	my @hold;

	foreach my $v ( @{ $arr } )
	{
		unless ( exists $hold{ $v } )
		{
			$hold{ $v } = 1;
			push @hold, $v;
		}
	}

	@{ $arr } = @hold;
	return;
}

=begin nd
Function: getArrayCollision

	It checks if two arrays have some value repeted.
	The arrays have to contain scalar values.

Parameters:
	Array ref 1 - List of values 1
	Array ref 2 - List of values 2

Returns:
	scalar - It returns the first value which is contained in both arrays

=cut

sub getArrayCollision
{
	&zenlog( __FILE__ . q{:} . __LINE__ . q{:} . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $arr1 = shift;
	my $arr2 = shift;

	foreach my $it ( sort @{ $arr1 } )
	{
		if ( grep { /^$it$/ } @{ $arr2 } )
		{
			return $it;
		}
	}

	return;
}

1;

