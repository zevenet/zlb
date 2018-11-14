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
use Zevenet::Farm::Core;
use Zevenet::Farm::Base;
use Zevenet::Farm::Action;

# DELETE /farms/FARMNAME
sub delete_farm # ( $farmname )
{
	my $farmname = shift;

	my $desc = "Delete farm $farmname";
	my $newffile = &getFarmFile( $farmname );

	if ( $newffile == -1 )
	{
		my $msg = "The farm $farmname doesn't exist, try another name.";
		&httpErrorResponse( code => 404, desc => $desc, msg => $msg );
	}

	if ( &getFarmStatus( $farmname ) eq 'up' )
	{
		&runFarmStop( $farmname, "true" );

		if ( eval { require Zevenet::Cluster; } )
		{
			&runZClusterRemoteManager( 'farm', 'stop', $farmname );
		}
	}

	my $error = &runFarmDelete( $farmname );

	if ( $error )
	{
		my $msg = "The Farm $farmname hasn't been deleted";
		&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
	}

	&zenlog( "ZAPI success, the farm $farmname has been deleted." );

	if ( eval { require Zevenet::Cluster; } )
	{
		&runZClusterRemoteManager( 'farm', 'delete', $farmname );
	}

	my $msg = "The Farm $farmname has been deleted.";
	my $body = {
				 description => $desc,
				 success     => "true",
				 message     => $msg
	};

	&httpResponse({ code => 200, body => $body });
}

1;
