#!/usr/bin/perl
###############################################################################
#
#    Zevenet Software License
#    This file is part of the Zevenet Load Balancer software package.
#
#    Copyright (C) 2020-today ZEVENET SL, Sevilla (Spain)
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
Function: priorityAlgorithmIsOK

	This funcion receives a list of priority values and it checks if all backends will be started according to priority Algorithm

Parameters:
	Priorities - List of priorities to check

Returns:
	Integer - Return 0 if valid priority settings, unsuitable priority value if not.

=cut

sub priorityAlgorithmIsOK    # ( \@Priorities )
{
	use List::Util qw( min max );
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $priority_ref = shift;
	my @backends     = sort @{ $priority_ref };
	my @backendstmp;

	my $prio_last = 0;
	foreach my $prio_cur ( @backends )
	{
		if ( $prio_cur != $prio_last )
		{
			my $n_backendstmp = @backendstmp;
			return $prio_cur if ( $prio_cur > ( $n_backendstmp + 1 ) );
			push @backendstmp, $prio_cur;
			$prio_last = $prio_cur;
		}
		else
		{
			push @backendstmp, $prio_cur;
		}
	}
	return 0;
}

1;

