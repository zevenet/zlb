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

# GET /ciphers
sub ciphers_available # ( $json_obj, $farmname )
{
	my @out;
	my $desc = "Get the ciphers available";

	require Zevenet::Farm::HTTP::HTTPS;

	push @out, { 'ciphers' => "all", "description" => "All" };
	push @out, { 'ciphers' => "highsecurity", "description" => "High security" };
	push @out, { 'ciphers' => "customsecurity", "description" => "Custom security" };

	if ( &getFarmCipherSSLOffLoadingSupport() )
	{
		push @out, { 'ciphers' => "ssloffloading", "description" => "SSL offloading" };
	}

	my $body = {
				description => $desc,
				params      => \@out,
	};

	# Success
	&httpResponse({ code => 200, body => $body });
}

1;
