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
if ( eval { require Zevenet::ELoad; } ) { $eload = 1; }

# GET /ciphers
sub ciphers_available # ( $json_obj, $farmname )
{
	&zenlog(__FILE__ . ":" . __LINE__ . ":" . (caller(0))[3] . "( @_ )", "debug", "PROFILING" );
	my $desc = "Get the ciphers available";

	my @out = (
				{ 'ciphers' => "all",            "description" => "All" },
				{ 'ciphers' => "highsecurity",   "description" => "High security" },
				{ 'ciphers' => "customsecurity", "description" => "Custom security" }
	);

	push( @out, &eload(
		module => 'Zevenet::Farm::HTTP::HTTPS::Ext',
		func   => 'getExtraCipherProfiles',
	) ) if ( $eload );

	my $body = {
				 description => $desc,
				 params      => \@out,
	};

	&httpResponse({ code => 200, body => $body });
}

1;
