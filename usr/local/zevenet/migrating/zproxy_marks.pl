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
require Zevenet::Farm::Core;
require Zevenet::Farm::HTTP::Backend;
require Zevenet::Farm::HTTP::Config;

my $ng_cur = &getGlobalConfiguration( 'proxy_ng' );

if ( $ng_cur eq "true" )
{
	print "Setting new proxy directives on existing l7 farms";
	my @farmsf = &getFarmsByType( 'http' );
	push @farmsf, &getFarmsByType( 'https' );
	foreach my $farm_name ( @farmsf )
	{
		&setHTTPFarmBackendsMarks( $farm_name );
	}
}
