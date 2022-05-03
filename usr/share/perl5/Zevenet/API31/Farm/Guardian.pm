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
if ( eval { require Zevenet::ELoad; } )
{
	$eload = 1;
}

#  PUT /farms/<farmname>/fg Modify the parameters of the farm guardian in a Farm
#  PUT /farms/<farmname>/fg Modify the parameters of the farm guardian in a Service
sub modify_farmguardian    # ( $json_obj, $farmname )
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $json_obj = shift;
	my $farmname = shift;

	require Zevenet::Farm::Core;
	require Zevenet::Farm::Base;
	require Zevenet::FarmGuardian;

	my $desc    = "Modify farm guardian";
	my $type    = &getFarmType( $farmname );
	my $service = $json_obj->{ 'service' };
	delete $json_obj->{ 'service' };

	#~ my @fgKeys = ( "fg_time", "fg_log", "fg_enabled", "fg_type" );

	# validate FARM NAME
	if ( !&getFarmExists( $farmname ) )
	{
		my $msg = "The farmname $farmname does not exist.";
		&httpErrorResponse( code => 404, desc => $desc, msg => $msg );
	}

	# validate FARM TYPE
	unless ( $type eq 'l4xnat' || $type =~ /^https?$/ || $type eq 'gslb' )
	{
		my $msg = "Farm guardian is not supported for the requested farm profile.";
		&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
	}

	# check if no service is declared for l4xnat farms
	if ( $type eq 'l4xnat' && $service )
	{
		my $msg = "L4xNAT profile farms do not have services.";
		&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
	}

	# make service variable empty for l4xnat functions
	$service = '' if $type eq "l4xnat";

	# check if the service exists for http farms
	if ( $type =~ /^https?$/ )
	{
		require Zevenet::Farm::HTTP::Service;

		if ( !grep ( /^$service$/, &getHTTPFarmServices( $farmname ) ) )
		{
			my $msg = "Invalid service name, please insert a valid value.";
			&httpErrorResponse( code => 404, desc => $desc, msg => $msg );
		}
	}

	# check farmguardian time interval
	if ( exists ( $json_obj->{ fgtimecheck } )
		 && !&getValidFormat( 'fg_time', $json_obj->{ fgtimecheck } ) )
	{
		my $msg = "Invalid format, please insert a valid fgtimecheck.";
		&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
	}

	# check farmguardian command
	elsif ( exists ( $json_obj->{ fgscript } ) && $json_obj->{ fgscript } eq '' )
	{
		my $msg = "Invalid fgscript, can't be blank.";
		&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
	}

	# check farmguardian enabled
	elsif ( exists ( $json_obj->{ fgenabled } )
			&& !&getValidFormat( 'fg_enabled', $json_obj->{ fgenabled } ) )
	{
		my $msg = "Invalid format, please insert a valid fgenabled.";
		&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
	}

	# check farmguardian log
	elsif ( exists ( $json_obj->{ fglog } )
			&& !&getValidFormat( 'fg_log', $json_obj->{ fglog } ) )
	{
		my $msg = "Invalid format, please insert a valid fglog.";
		&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
	}

	my @allowParams = ( "fgtimecheck", "fgscript", "fglog", "fgenabled" );

	# check optional parameters
	if ( my $msg = &getValidOptParams( $json_obj, \@allowParams ) )
	{
		&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
	}

	my $fg = &getFGFarm( $farmname, $service );
	if ( $fg )
	{
		my $num_farms = scalar @{ &getFGObject( $fg )->{ farms } };
		if ( $num_farms > 1 )
		{
			my $errormsg =
			  "Farm guardian $fg is used for several farms, modify it from API 3.2 or later";
			my $body = { description => $desc, error => "true", message => $errormsg };
			&httpResponse( { code => 400, body => $body } );
		}
	}

	if ( $type eq 'gslb' && $eload )
	{
		&eload(
				module => 'Zevenet::API31::Farm::GSLB',
				func   => 'modify_gslb_farmguardian',
				args   => [$json_obj, $farmname, $service]
		);
	}

	else
	{
		# HTTP or L4xNAT
		# get current farmguardian configuration
		my @fgconfig = &getFarmGuardianConf( $farmname, $service );

		chomp @fgconfig;
		my ( undef, $timetocheck, $check_script, $usefarmguardian, $farmguardianlog ) =
		  @fgconfig;

		$timetocheck += 0;
		$timetocheck = 5 if !$timetocheck;

		$check_script =~ s/\"/\'/g;

		# update current configuration with new settings
		if ( exists $json_obj->{ fgtimecheck } )
		{
			$timetocheck = $json_obj->{ fgtimecheck };
			$timetocheck = $timetocheck + 0;
		}
		if ( exists $json_obj->{ fgscript } )
		{
			$check_script = $json_obj->{ fgscript };    # FIXME: Make safe script string
		}
		if ( exists $json_obj->{ fgenabled } )
		{
			$usefarmguardian = $json_obj->{ fgenabled };
		}
		if ( exists $json_obj->{ fglog } )
		{
			$farmguardianlog = $json_obj->{ fglog };
		}

		# apply new farmguardian configuration
		&runFarmGuardianStop( $farmname, $service );
		&runFarmGuardianRemove( $farmname, $service );

		my $status =
		  &runFarmGuardianCreate( $farmname, $timetocheck, $check_script,
								  $usefarmguardian, $farmguardianlog, $service );

		# check for errors setting farmguardian
		if ( $status == -1 )
		{
			my $msg = "It's not possible to create the FarmGuardian configuration file.";
			&httpErrorResponse( code => 400, desc => $desc, msg => $msg );
		}

		# get current farmguardian configuration
		my ( undef, $timetocheck, $check_script, $usefarmguardian, $farmguardianlog ) =
		  &getFarmGuardianConf( $farmname, $service );

		$timetocheck += 0;
		$timetocheck = 5 if !$timetocheck;

		# no error found, return successful response
		my $msg =
		  "Success, some parameters have been changed in farm guardian in farm $farmname.";
		my $body = {
					 description => $desc,
					 params      => {
								 fgenabled   => $usefarmguardian,
								 fgtimecheck => $timetocheck,
								 fgscript    => $check_script,
								 fglog       => $farmguardianlog,
					 },
					 message => $msg,
		};

		&httpResponse( { code => 200, body => $body } );
	}
}

1;
