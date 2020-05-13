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
use Zevenet::Net::Util;
use Zevenet::Farm::Base;
use Zevenet::Farm::Datalink::Config;

my $eload;
if ( eval { require Zevenet::ELoad; } ) { $eload = 1; }

sub modify_datalink_farm    # ( $json_obj, $farmname )
{
	&zenlog(__FILE__ . ":" . __LINE__ . ":" . (caller(0))[3] . "( @_ )", "debug", "PROFILING" );
	my $json_obj = shift;
	my $farmname = shift;

	my $desc           = "Modify datalink farm '$farmname'";
	my $reload_flag    = "false";
	my $restart_flag   = "false";
	my $initial_status = &getFarmStatus( $farmname );
	my $error          = "false";
	my $status;

	# Check parameters
	foreach my $key ( keys %$json_obj )
	{
		unless ( grep { $key eq $_ } qw(newfarmname algorithm vip) )
		{
			my $msg = "The parameter $key is invalid.";
			&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
		}
	}

	# Modify Farm's Name
	if ( exists ( $json_obj->{ newfarmname } ) )
	{
		unless ( &getFarmStatus( $farmname ) eq 'down' )
		{
			my $msg = 'Cannot change the farm name while running';
			&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
		}

		if ( $json_obj->{ newfarmname } =~ /^$/ )
		{
			my $msg = "Invalid newfarmname, can't be blank.";
			&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
		}

		if ( $json_obj->{ newfarmname } ne $farmname )
		{
			#Check if farmname has correct characters (letters, numbers and hyphens)
			if ( $json_obj->{ newfarmname } !~ /^[a-zA-Z0-9\-]*$/ )
			{
				my $msg = "Invalid newfarmname.";
				&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
			}

			#Check if the new farm's name alredy exists
			my $newffile = &getFarmFile( $json_obj->{ newfarmname } );
			if ( $newffile != -1 )
			{
				my $msg = "The farm $json_obj->{newfarmname} already exists, try another name.";
				&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
			}

			#Change farm name
			require Zevenet::Farm::Action;
			my $fnchange = &setNewFarmName( $farmname, $json_obj->{ newfarmname } );
			if ( $fnchange == -1 )
			{
				my $msg =
				  "The name of the farm can't be modified, delete the farm and create a new one.";
				&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
			}

			$farmname = $json_obj->{ newfarmname };
		}
	}

	# Modify Load Balance Algorithm
	if ( exists ( $json_obj->{ algorithm } ) )
	{
		if ( $json_obj->{ algorithm } =~ /^$/ )
		{
			my $msg = "Invalid algorithm, can't be blank.";
			&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
		}

		unless ( $json_obj->{ algorithm } =~ /^(weight|prio)$/ )
		{
			my $msg = "Invalid algorithm.";
			&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
		}

		$status = &setDatalinkFarmAlgorithm( $json_obj->{ algorithm }, $farmname );
		if ( $status == -1 )
		{
			my $msg = "Some errors happened trying to modify the algorithm.";
			&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
		}

		$restart_flag = "true";
	}

	# Modify Virtual IP and Interface
	if ( exists ( $json_obj->{ vip } ) )
	{
		if ( $json_obj->{ vip } =~ /^$/ )
		{
			my $msg = "Invalid vip, can't be blank.";
			&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
		}

		if ( $json_obj->{ vip } !~ /^[a-zA-Z0-9.]+/ )
		{
			my $msg = "Invalid vip.";
			&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
		}

		if ( !defined $json_obj->{ vip } || $json_obj->{ vip } eq "" )
		{
			my $msg = "Invalid Virtual IP value.";
			&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
		}

		# interface must be running
		if ( !grep { $_ eq $json_obj->{ vip } } &listallips() )
		{
			my $msg = "An available virtual IP must be set.";
			&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
		}

		my $fdev = &getInterfaceOfIp( $json_obj->{ vip } );
		if ( !defined $fdev )
		{
			my $msg = "Invalid Interface value.";
			&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
		}

		my $status =
		  &setDatalinkFarmVirtualConf( $json_obj->{ vip }, $fdev, $farmname );
		if ( $status == -1 )
		{
			my $msg = "It's not possible to change the farm virtual IP and interface.";
			&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
		}

		$restart_flag = "true";
	}

	# Restart Farm
	if ( $restart_flag eq "true" && $initial_status ne 'down' )
	{
		&runFarmStop( $farmname, "true" );
		&runFarmStart( $farmname, "true" );

		&eload(
			module => 'Zevenet::Cluster',
			func   => 'runZClusterRemoteManager',
			args   => ['farm', 'restart', $farmname],
		) if ( $eload );
	}

	# no error found, return successful response
	&zenlog( "Success, some parameters have been changed in farm $farmname.", "info", "DSLB" );


	my $body = {
				 description => $desc,
				 params      => $json_obj
	};

	&httpResponse( { code => 200, body => $body } );
}

1;
