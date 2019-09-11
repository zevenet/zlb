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

use Zevenet::Log;
use Zevenet::Config;

my $configdir = &getGlobalConfiguration( "configdir" );
my $fg_conf   = "$configdir/farmguardian.conf";
my $fg_template =
  &getGlobalConfiguration( "templatedir" ) . "/farmguardian.template";

my $eload;
if ( eval { require Zevenet::ELoad; } )
{
	$eload = 1;
}

=begin nd
Function: getFGStatusFile

	The function returns the path of the file that is used to save the backend status for a farm.

Parameters:
	fname - Farm name

Returns:
	String - file path

=cut

sub getFGStatusFile
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $farm = shift;

	return "$configdir\/$farm\_status.cfg";
}

=begin nd
Function: getFGStruct

	It returns a default struct with all farmguardian parameters

Parameters:
	none - .

Returns:
	Hash ref - hash with the available parameters of fg

	example:
	hash => {
		'description' => "",       # Tiny description about the check
		'command'     => "",       # Command to check. The check must return 0 on sucess
		'farms'       => [],       # farm list where the farm guardian is applied
		'log'         => "false",  # logg farm guardian
		'interval'    => "10",     # Time between checks
		'cut_conns' => "false",    # cut the connections with the backend is marked as down
		'template'  => "false",    # it is a template. The fg cannot be deleted, only reset its configuration
	};

=cut

sub getFGStruct
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	return {
		'description' => "",       # Tiny description about the check
		'command'     => "",       # Command to check. The check must return 0 on sucess
		'farms'       => [],       # farm list where the farm guardian is applied
		'log'         => "false",  # logg farm guardian
		'interval'    => "10",     # Time between checks
		'cut_conns' => "false", # cut the connections with the backend is marked as down
		'template'  => "false",
	};
}

=begin nd
Function: getFGExistsConfig

	It checks out if the fg already exists in the configuration file.

Parameters:
	Farmguardian - Farmguardian name

Returns:
	Integer - 1 if the fg already exists or 0 if it is not

=cut

sub getFGExistsConfig
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $fg_name = shift;
	my $fh      = &getTiny( $fg_conf );
	return ( exists $fh->{ $fg_name } ) ? 1 : 0;
}

=begin nd
Function: getFGExistsTemplate

	It checks out if a template farmguardian exists with this name.

Parameters:
	Farmguardian - Farmguardian name

Returns:
	Integer - 1 if the fg exists or 0 if it is not

=cut

sub getFGExistsTemplate
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $fg_name = shift;
	my $fh      = &getTiny( $fg_template );
	return ( exists $fh->{ $fg_name } ) ? 1 : 0;
}

=begin nd
Function: getFGExists

	It checks out if the fg exists, in the template file or in the configuraton file

Parameters:
	Farmguardian - Farmguardian name

Returns:
	Integer - 1 if the fg already exists or 0 if it is not

=cut

sub getFGExists
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $fg_name = shift;
	return ( &getFGExistsTemplate( $fg_name ) or &getFGExistsConfig( $fg_name ) );
}

=begin nd
Function: getFGConfigList

	It returns a list of farmguardian names of the configuration file

Parameters:
	None - .

Returns:
	Array - List of fg names

=cut

sub getFGConfigList
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $fg_file = &getTiny( $fg_conf );
	return keys %{ $fg_file };
}

=begin nd
Function: getFGTemplateList

	It returns a list of farmguardian names of the template file

Parameters:
	None - .

Returns:
	Array - List of fg names

=cut

sub getFGTemplateList
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $fg_file = &getTiny( $fg_template );
	return keys %{ $fg_file };
}

=begin nd
Function: getFGList

	It is a list with all fg, templates and created by the user

Parameters:
	None - .

Returns:
	Array - List of fg names

=cut

sub getFGList
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my @list = &getFGConfigList();

	# get from template file
	foreach my $fg ( &getFGTemplateList() )
	{
		next if ( grep ( /^$fg$/, @list ) );
		push @list, $fg;
	}

	return @list;
}

=begin nd
Function: getFGObject

	Get the configuration of a farmguardian

Parameters:
	Farmguardian - Farmguardian name
	template - If this parameter has the value "template", the function returns the object from the template file

Returns:
	Hash ref - It returns a hash with the configuration of the farmguardian

	example:
	hash => {
		'description' => "",       # Tiny description about the check
		'command'     => "",       # Command to check. The check must return 0 on sucess
		'farms'       => [],       # farm list where the farm guardian is applied
		'log'         => "false",  # log farm guardian
		'interval'    => "10",     # Time between checks
		'cut_conns' => "false",    # cut the connections with the backend is marked as down
		'template'  => "false",    # it is a template. The fg cannot be deleted, only reset its configuration
	};

=cut

sub getFGObject
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $fg_name      = shift;
	my $use_template = shift;
	my $file         = "";

	# using template file if this parameter is sent
	if ( $use_template eq 'template' ) { $file = $fg_template; }

	# using farmguardian config file by default
	elsif ( grep ( /^$fg_name$/, &getFGConfigList() ) ) { $file = $fg_conf; }

	# using template file if farmguardian is not defined in config file
	else { $file = $fg_template; }

	my $obj = &getTiny( $file )->{ $fg_name };

	$obj = &setConfigStr2Arr( $obj, ['farms'] );

	return $obj;
}

=begin nd
Function: getFGFarm

	Get the fg name that a farm is using

Parameters:
	Farm - Farm name
	service - Service of the farm. This parameter is mandatory for HTTP and GSLB farms

Returns:
	String - Farmguardian name

=cut

sub getFGFarm
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $farm = shift;
	my $srv  = shift;

	my $fg;
	my $farm_tag = ( $srv ) ? "${farm}_$srv" : "$farm";
	my $fg_list = &getTiny( $fg_conf );

	foreach my $fg_name ( keys %{ $fg_list } )
	{
		if ( grep ( /(^| )$farm_tag( |$)/, $fg_list->{ $fg_name }->{ farms } ) )
		{
			$fg = $fg_name;
			last;
		}
	}

	return $fg;
}

=begin nd
Function: createFGBlank

	Create a fg without configuration

Parameters:
	Name - Farmguardian name

Returns:
	none - .

=cut

sub createFGBlank
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $name = shift;

	my $values = &getFGStruct();
	&setFGObject( $name, $values );
}

=begin nd
Function: createFGTemplate

	Create a fg from a template

Parameters:
	Farmguardian - Farmguardian name
	template - If this parameter has the value "template", the function returns the object from the template file

Returns:
	None - .

=cut

sub createFGTemplate
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $name     = shift;
	my $template = shift;

	my $values = &getFGObject( $template, 'template' );
	$values->{ 'template' } = "false";

	&setFGObject( $name, $values );
}

=begin nd
Function: createFGConfig

	 create a farm guardian from another farm guardian

Parameters:
	Farmguardian - Farmguardian name
	template - Farmguardian name of the fg used as template

Returns:
	None - .

=cut

sub createFGConfig
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $name      = shift;
	my $fg_config = shift;

	my $values = &getFGObject( $fg_config );
	$values->{ farms } = [];
	&setFGObject( $name, $values );
}

=begin nd
Function: delFGObject

	Remove a farmguardianfrom the configuration file. First, it stops it.
	This function will restart the fg process.

Parameters:
	Farmguardian - Farmguardian name

Returns:
	Integer - 0 on success or another value on failure

=cut

sub delFGObject
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $fg_name = shift;

	my $out = &runFGStop( $fg_name );
	my $out = &delTinyObj( $fg_conf, $fg_name );

	return $out;
}

=begin nd
Function: setFGObject

	Set a configuration for fg.
	This function has 2 behaviour:
		* passing to the function a hash with several parameters
		* passing to the function 2 parameters, key and value. So, only is updated one parater.

	If the farmguardian name is not found in the configuration file, the configuraton will be got
	from the template file and save it in the configuration file.

	This function will restart the fg process

Parameters:
	Farmguardian - Farmguardian name
	object / key - object: hash reference with a set of parameters, or key: parameter name to set
	value - value for the "key"

Returns:
	Integer - 0 on success or another value on failure

=cut

sub setFGObject
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $fg_name = shift;
	my $key     = shift;
	my $value   = shift;

	my $restart = 0;
	my $out     = 0;

	# not restart if only is changed the parameter description
	if ( &getFGExistsConfig( $fg_name ) )
	{
		if ( @{ &getFGRunningFarms( $fg_name ) } )
		{
			if ( ref $key and grep ( !/^description$/, keys %{ $key } ) )
			{
				$restart = 1;
			}
			elsif ( $key ne 'description' ) { $restart = 1; }
		}
	}

	# if the fg does not exist in config file, take it from template file
	unless ( &getFGExistsConfig( $fg_name ) )
	{
		my $template = &getFGObject( $fg_name, 'template' );
		$out = &setTinyObj( $fg_conf, $fg_name, $template );
	}

	$out = &runFGStop( $fg_name ) if $restart;
	$out = &setTinyObj( $fg_conf, $fg_name, $key, $value );
	$out = &runFGStart( $fg_name ) if $restart;

	if ( $eload )
	{
		$out += &eload(
						module => 'Zevenet::Farm::GSLB::FarmGuardian',
						func   => 'updateGSLBFg',
						args   => [$fg_name],
		);
	}

	return $out;
}

=begin nd
Function: setFGFarmRename

	Re-asign farmguardian to a farm that has been renamed

Parameters:
	old name - Old farm name
	new name - New farm name

Returns:
	Integer - 0 on success or another value on failure

=cut

sub setFGFarmRename
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $farm     = shift;
	my $new_farm = shift;

	my $fh = &getTiny( $fg_conf );
	my $srv;
	my $farm_tag;
	my $new_farm_tag;
	my $out;

	# foreach farm check, remove and add farm
	foreach my $fg ( keys %{ $fh } )
	{
		if ( $fh->{ $fg }->{ farms } =~ /(?:^| )${farm}_?([\w-]+)?(?:$| )/ )
		{
			$srv          = $1;
			$farm_tag     = ( $srv ) ? "${farm}_$srv" : $farm;
			$new_farm_tag = ( $srv ) ? "${new_farm}_$srv" : $farm;

			$out = &setTinyObj( $fg_conf, $fg, 'farms', $farm_tag,     'del' );
			$out = &setTinyObj( $fg_conf, $fg, 'farms', $new_farm_tag, 'add' );

			my $status_file     = &getFGStatusFile( $farm,     $srv );
			my $new_status_file = &getFGStatusFile( $new_farm, $srv );
			&zenlog( "renaming $status_file =>> $new_status_file" ) if &debug;
			rename ( $status_file, $new_status_file );
		}
	}

	return $out;
}

=begin nd
Function: linkFGFarm

	Assign a farmguardian to a farm (or service of a farm).
	Farmguardian will run if the farm is up.

Parameters:
	Farmguardian - Farmguardian name
	Farm - Farm name
	Service - Service name. It is used for GSLB and HTTP farms

Returns:
	Integer - 0 on success or another value on failure

=cut

sub linkFGFarm
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $fg_name = shift;
	my $farm    = shift;
	my $srv     = shift;
	my $out;

	require Zevenet::Farm::Base;
	my $farm_tag = ( $srv ) ? "${farm}_$srv" : "$farm";

	# if the fg does not exist in config file, take it from template file
	unless ( &getFGExistsConfig( $fg_name ) )
	{
		my $template = &getFGObject( $fg_name, 'template' );
		$out = &setTinyObj( $fg_conf, $fg_name, $template );
		return $out if $out;
	}

	$out = &setTinyObj( $fg_conf, $fg_name, 'farms', $farm_tag, 'add' );
	return $out if $out;

	if ( &getFarmType( $farm ) eq 'gslb' and $eload )
	{
		$out = &eload(
					   module => 'Zevenet::Farm::GSLB::FarmGuardian',
					   func   => 'linkGSLBFg',
					   args   => [$fg_name, $farm, $srv],
		);
	}
	elsif ( &getFarmStatus( $farm ) eq 'up' )
	{
		$out = &runFGFarmStart( $farm, $srv );
	}

	return $out;
}

=begin nd
Function: unlinkFGFarm

	Remove a farmguardian from a farm (or service of a farm).
	Farmguardian will be stopped if it is running.

Parameters:
	Farmguardian - Farmguardian name
	Farm - Farm name
	Service - Service name. It is used for GSLB and HTTP farms

Returns:
	Integer - 0 on success or another value on failure

=cut

sub unlinkFGFarm
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $fg_name = shift;
	my $farm    = shift;
	my $srv     = shift;

	my $type = &getFarmType( $farm );

	require Zevenet::Log;

	my $farm_tag = ( $srv ) ? "${farm}_$srv" : "$farm";
	my $out;

	$out = &setTinyObj( $fg_conf, $fg_name, 'farms', $farm_tag, 'del' );
	return $out if $out;

	if ( ( $type eq 'gslb' ) and $eload )
	{
		$out = &eload(
					   module => 'Zevenet::Farm::GSLB::FarmGuardian',
					   func   => 'unlinkGSLBFg',
					   args   => [$farm, $srv],
		);
	}
	else
	{
		$out = &runFGFarmStop( $farm, $srv );
	}

	return $out;
}

=begin nd
Function: delFGFarm

	Function used if a farm is deleted. All farmguardian assigned to it will be unliked.

Parameters:
	Farm - Farm name
	Service - Service name. It is used for GSLB and HTTP farms

Returns:
	None - .

=cut

sub delFGFarm
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $farm    = shift;
	my $service = shift;

	require Zevenet::Farm::Service;

	my $fg;
	my $err = &runFGFarmStop( $farm, $service );
	my $type = &getFarmType( $farm );

	if ( $type =~ /http/ or $type eq 'gslb' )
	{
		if ( not $service )
		{
			foreach my $srv ( &getFarmServices( $farm ) )
			{
				$fg = &getFGFarm( $farm, $srv );
				next if not $fg;
				$err |= &setTinyObj( $fg_conf, $fg, 'farms', "${farm}_$srv", 'del' );
			}
		}
		else
		{
			$fg = &getFGFarm( $farm, $service );
			$err |= &setTinyObj( $fg_conf, $fg, 'farms', "${farm}_$service", 'del' ) if $fg;
		}
	}
	else
	{
		$fg = &getFGFarm( $farm );
		$err |= &setTinyObj( $fg_conf, $fg, 'farms', $farm, 'del' ) if $fg;
	}
}

############# run process

=begin nd
Function: getFGPidFile

	Get the path of the file where the pid of the farmguardian is saved.

Parameters:
	Farm - Farm name
	Service - Service name. It is used for GSLB and HTTP farms

Returns:
	String - Pid file path.

=cut

sub getFGPidFile
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $fname  = shift;
	my $svice  = shift;
	my $piddir = &getGlobalConfiguration( 'piddir' );
	my $file;

	if ( $svice )
	{
		# return a regexp for a farm the request service
		$file = "$piddir/${fname}_${svice}_guardian.pid";
	}
	else
	{
		# return a regexp for a farm and all its services
		$file = "$piddir/${fname}_guardian.pid";
	}

	return $file;
}

=begin nd
Function: getFGPidFarm

	It returns the farmguardian PID assigned to a farm (and service)

Parameters:
	Farm - Farm name
	Service - Service name. It is used for GSLB and HTTP farms

Returns:
	Integer - 0 on failure, or a natural number for PID

=cut

sub getFGPidFarm
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $farm    = shift;
	my $service = shift;
	my $pid     = 0;

	# get pid
	my $pidFile = &getFGPidFile( $farm, $service );

	if ( !-f "$pidFile" )
	{
		return $pid;
	}

	open my $fh, '<', $pidFile or return 0;
	$pid = <$fh>;
	close $fh;

	my $run;

	# check if the pid exists
	if ( $pid > 0 )
	{
		$run = kill 0, $pid;
	}

	# if it does not exists, remove the pid file
	if ( !$run )
	{
		$pid = 0;
		unlink $pidFile;
	}

	# return status
	return $pid;
}

=begin nd
Function: runFGStop

	It stops all farmguardian process are using the passed fg name

Parameters:
	Farmguardian - Farmguardian name

Returns:
	Integer - 0 on failure, or another value on success

=cut

sub runFGStop
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $fgname = shift;
	my $out;

	&zenlog( "Stopping farmguardian $fgname", "debug", "FG" );

	my $obj = &getFGObject( $fgname );
	foreach my $farm ( @{ $obj->{ farms } } )
	{
		my $srv;
		if ( $farm =~ /([^_]+)_(.+)/ )
		{
			$farm = $1;
			$srv  = $2;
		}

		$out |= &runFGFarmStop( $farm, $srv );
	}

	return $out;
}

=begin nd
Function: runFGStart

	It runs fg for each farm is using it and it is running

Parameters:
	Farmguardian - Farmguardian name

Returns:
	Integer - 0 on failure, or another value on success

=cut

sub runFGStart
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $fgname = shift;
	my $out;

	&zenlog( "Starting farmguardian $fgname", "debug", "FG" );

	my $obj = &getFGObject( $fgname );
	foreach my $farm ( @{ $obj->{ farms } } )
	{
		my $srv;
		if ( $farm =~ /([^_]+)_(.+)/ )
		{
			$farm = $1;
			$srv  = $2;
		}

		$out |= &runFGFarmStart( $farm, $srv );
	}

	return $out;
}

=begin nd
Function: runFGRestart

	It restarts all farmguardian process for each farm is using the passed fg

Parameters:
	Farmguardian - Farmguardian name

Returns:
	Integer - 0 on failure, or another value on success

=cut

sub runFGRestart
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $fgname = shift;
	my $out;

	$out = &runFGStop( $fgname );
	$out |= &runFGStart( $fgname );

	return $out;
}

=begin nd
Function: runFGFarmStop

	It stops farmguardian process used by the farm. If the farm is GSLB or HTTP
	and is not passed the service name, all farmguardians will be stoped.

Parameters:
	Farm - Farm name
	Service - Service name. This parameter is for HTTP and GSLB farms.

Returns:
	Integer - 0 on failure, or another value on success

=cut

sub runFGFarmStop
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $farm    = shift;
	my $service = shift
	  ; # optional, if the farm is http and the service is not sent to the function, all services will be restarted
	my $out = 0;
	my $srvtag;
	my $status_file = &getFGStatusFile( $farm, $service );

	require Zevenet::Farm::Core;
	my $type = &getFarmType( $farm );
	if ( $type =~ /http/ and not $service )
	{
		require Zevenet::Farm::Service;
		foreach my $srv ( &getFarmServices( $farm ) )
		{
			$out |= &runFGFarmStop( $farm, $srv );
		}
	}
	else
	{
		my $fgpid = &getFGPidFarm( $farm, $service );

		if ( $fgpid && $fgpid > 0 )
		{
			&zenlog( "running 'kill 9, $fgpid' stopping FarmGuardian $farm $service",
					 "debug", "FG" );

			# kill returns the number of process affected
			$out = kill 9, $fgpid;
			$out = ( not $out );
			if ( $out )
			{
				&zenlog( "running 'kill 9, $fgpid' stopping FarmGuardian $farm $service",
						 "error", "FG" );
			}

			# delete pid files
			unlink &getFGPidFile( $farm, $service );

			# put backend up
			if ( $type eq "http" || $type eq "https" )
			{
				if ( -e $status_file )
				{
					require Zevenet::Farm::HTTP::Config;
					require Zevenet::Farm::HTTP::Service;
					require Tie::File;

					my $portadmin = &getHTTPFarmSocket( $farm );
					my $idsv      = &getFarmVSI( $farm, $service );
					my $poundctl  = &getGlobalConfiguration( 'poundctl' );

					tie my @filelines, 'Tie::File', $status_file;

					my @fileAux = @filelines;
					my $lines   = scalar @fileAux;

					while ( $lines >= 0 )
					{
						$lines--;
						my $line = $fileAux[$lines];
						if ( $fileAux[$lines] =~ /0 $idsv (\d+) fgDOWN/ )
						{
							my $index = $1;
							my $auxlin = splice ( @fileAux, $lines, 1, );

							&logAndRun( "$poundctl -c $portadmin -B 0 $idsv $index" );
						}
					}
					@filelines = @fileAux;
					untie @filelines;
				}
			}

			if ( $type eq "l4xnat" )
			{
				require Zevenet::Farm::Backend;

				my $be = &getFarmServers( $farm );

				foreach my $l_serv ( @{ $be } )
				{
					if ( $l_serv->{ status } eq "fgDOWN" )
					{
						$out |= &setL4FarmBackendStatus( $farm, $l_serv->{ id }, "up" );
					}
				}
			}
		}
		$srvtag = "${service}_" if ( $service );
		unlink "$configdir/${farm}_${srvtag}status.cfg";
	}

	return $out;
}

=begin nd
Function: runFGFarmStart

	It starts the farmguardian process used by the farm. If the farm is GSLB or HTTP
	and is not passed the service name, all farmguardians will be run.
	The pid file is created by the farmguardian process.

Parameters:
	Farm - Farm name
	Service - Service name. This parameter is for HTTP and GSLB farms.

Returns:
	Integer - 0 on failure, or another value on success

=cut

sub runFGFarmStart
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my ( $farm, $svice ) = @_;

	my $status = 0;
	my $log    = "";
	my $sv     = "";

	require Zevenet::Farm::Core;
	require Zevenet::Farm::Base;

	my $ftype = &getFarmType( $farm );

	# check if the farm is up
	return 0 if ( &getFarmStatus( $farm ) ne 'up' );

	# if the farmguardian is running...
	if ( &getFGPidFarm( $farm, $svice ) )
	{
		return 0;

		#~ &runFGFarmStop( $farm, $svice );
	}

	# check if the node is master
	if ( $eload )
	{
		my $node = "";
		$node = &eload(
						module => 'Zevenet::Cluster',
						func   => 'getZClusterNodeStatus',
						args   => [],
		);
		return 0 unless ( !$node or $node eq 'master' );
	}

	&zenlog( "Start fg for farm $farm, $svice", "debug2", "FG" );

	if ( $ftype =~ /http/ && $svice eq "" )
	{
		require Zevenet::Farm::Config;

		# Iterate over every farm service
		my $services = &getFarmVS( $farm, "", "" );
		my @servs = split ( " ", $services );

		foreach my $service ( @servs )
		{
			$status |= &runFGFarmStart( $farm, $service );
		}
	}
	elsif ( $ftype eq 'l4xnat' || $ftype =~ /http/ )
	{
		my $fgname       = &getFGFarm( $farm, $svice );
		my $farmguardian = &getGlobalConfiguration( 'farmguardian' );
		my $fg_cmd       = "$farmguardian $farm $sv $log";
		&zenlog( "running $fg_cmd", "info", "FG" );

		return 0 if not $fgname;

		&zenlog( "Starting fg $fgname, farm $farm, $svice", "debug2", "FG" );
		my $fg = &getFGObject( $fgname );

		if ( $fg->{ log } eq 'true' )
		{
			$log = "-l";
		}

		if ( $svice ne "" )
		{
			$sv = "-s $svice";
		}

		my $farmguardian = &getGlobalConfiguration( 'farmguardian' );
		my $fg_cmd       = "$farmguardian $farm $sv $log";

		require Zevenet::Log;
		$status = system ( "$fg_cmd >/dev/null 2>&1 &" );
		if   ( $status ) { &zenlog( "running $fg_cmd", "error", "FG" ); }
		else             { &zenlog( "running $fg_cmd", 'debug', 'FG' ); }

		# necessary for waiting that fg process write its process
		sleep ( 1 );
	}
	elsif ( $ftype ne 'gslb' )
	{
		# WARNING: farm types not supported by farmguardian return 0.
		$status = 1;
	}

	return $status;
}

=begin nd
Function: runFGFarmRestart

	It restarts the farmguardian process used by the farm. If the farm is GSLB or HTTP
	and is not passed the service name, all farmguardians will be restarted.

Parameters:
	Farm - Farm name
	Service - Service name. This parameter is for HTTP and GSLB farms.

Returns:
	Integer - 0 on failure, or another value on success

=cut

sub runFGFarmRestart
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $farm    = shift;
	my $service = shift;
	my $out;

	$out = &runFGFarmStop( $farm, $service );
	$out |= &runFGFarmStart( $farm, $service );

	return $out;
}

=begin nd
Function: getFGRunningFarms

	Get a list with all running farms where the farmguardian is applied.

Parameters:
	Farmguardian - Farmguardian name

Returns:
	Array ref - list of farm names

=cut

sub getFGRunningFarms
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $fg = shift;
	my @runfarm;

	require Zevenet::Farm::Core;
	require Zevenet::Farm::Base;

	# check all pid
	foreach my $farm ( @{ &getFGObject( $fg )->{ 'farms' } } )
	{
		my $srv;
		if ( $farm =~ /([^_]+)_(.+)/ )
		{
			$farm = $1;
			$srv  = $2;
		}

		if ( &getFarmStatus( $farm ) eq 'up' )
		{
			push @runfarm, $farm;
		}
	}
	return \@runfarm;
}

=begin nd
Function: getFGMigrateFile

	This function returns a standard name used to migrate the old farmguardians.

Parameters:
	Farm - Farm name
	Service - Service name. This parameter is for HTTP and GSLB farms.

Returns:
	String - Farmguardian name

=cut

sub getFGMigrateFile
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $farm = shift;
	my $srv  = shift;

	return ( $srv ) ? "_default_${farm}_$srv" : "_default_$farm";
}

=begin nd
Function: setOldFarmguardian

	Create a struct of the new fg using the parameters of the old fg

Parameters:
	Configuration - Hash with the configuration of the old FG

Returns:
	None - .

=cut

sub setOldFarmguardian
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $obj = shift;

	my $srv  = $obj->{ service } // "";
	my $farm = $obj->{ farm };
	my $name = &getFGMigrateFile( $obj->{ farm }, $srv );
	my $type = &getFarmType( $farm );
	my $set;

	&zenlog( "setOldFarmguardian: $farm, $srv", "debug2", "FG" );

	# default object
	my $def = {
		'description' =>
		  "Deprecated. This farm guardian was created using a zapi version before than 3.2",
		'command'   => $obj->{ command },
		'log'       => $obj->{ log },
		'interval'  => $obj->{ interval },
		'cut_conns' => ( $type =~ /http/ ) ? "true" : "false",
		'template'  => "false",
		'farms'     => [],
	};

	&runFGFarmStop( $farm, $srv );

	# if exists, update it
	if ( &getFGExistsConfig( $name ) )
	{
		$set = &getFGObject( $name );
		$set->{ command }  = $obj->{ command }  if exists $obj->{ command };
		$set->{ log }      = $obj->{ log }      if exists $obj->{ log };
		$set->{ interval } = $obj->{ interval } if exists $obj->{ interval };
	}

	# else create it
	else
	{
		$set = $def;
	}

	&setFGObject( $name, $set );
	my $farm_tag = ( $srv ) ? "${farm}_$srv" : $farm;
	&setTinyObj( $fg_conf, $name, 'farms', $farm_tag, 'add' )
	  if ( $obj->{ enable } eq 'true' );
}

####################################################################
######## ######## 	OLD FUNCTIONS 	######## ########
# Those functions are for compatibility with the APIs 3.0 and 3.1
####################################################################

=begin nd
Function: getFarmGuardianLog

	Returns if FarmGuardian has logs activated for this farm

Parameters:
	fname - Farm name.
	svice - Service name. Only apply if the farm profile has services. Leave undefined for farms without services.

Returns:
	-1 - If farmguardian file was not found.
	 0 - If farmguardian log is disabled.
	 1 - If farmguardian log is enabled.

Bugs:

See Also:
	<runFarmGuardianStart>
=cut

sub getFarmGuardianLog    # ($fname,$svice)
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my ( $fname, $svice ) = @_;

	my $fg = &getFGFarm( $fname, $svice );

	return &getFGObject( $fg )->{ logs } // undef;
}

=begin nd
Function: runFarmGuardianStart

	Start FarmGuardian rutine

Parameters:
	fname - Farm name.
	svice - Service name. Only apply if the farm profile has services. Leave undefined for farms without services.

Returns:
	-1       - If farmguardian file was not found or if farmguardian is not running.
	 0       - If farm profile is not supported by farmguardian, or farmguardian was executed.

Bugs:
	Returning $? after running a command in the background & gives the illusion of capturing the ERRNO of the ran program. That is not possible since the program may not have finished.

See Also:
	zcluster-manager, zevenet, <runFarmStart>, <setNewFarmName>, zapi/v3/farm_guardian.cgi, zapi/v2/farm_guardian.cgi
=cut

sub runFarmGuardianStart    # ($fname,$svice)
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my ( $fname, $svice ) = @_;

	return &runFGFarmStart( $fname, $svice );
}

=begin nd
Function: runFarmGuardianStop

	Stop FarmGuardian rutine

Parameters:
	fname - Farm name.
	svice - Service name. Only apply if the farm profile has services. Leave undefined for farms without services.

Returns:
	Integer - 0 on success, or greater than 0 on failure.

See Also:
	zevenet, <runFarmStop>, <setNewFarmName>, zapi/v3/farm_guardian.cgi, <runFarmGuardianRemove>
=cut

sub runFarmGuardianStop    # ($fname,$svice)
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my ( $fname, $svice ) = @_;

	return &runFGFarmStop( $fname, $svice );
}

=begin nd
Function: runFarmGuardianCreate

	Create or update farmguardian config file

	ttcheck and script must be defined and non-empty to enable farmguardian.

Parameters:
	fname - Farm name.
	ttcheck - Time between command executions for all the backends.
	script - Command to run.
	usefg - 'true' to enable farmguardian, or 'false' to disable it.
	fglog - 'true' to enable farmguardian verbosity in logs, or 'false' to disable it.
	svice - Service name.

Returns:
	-1 - If ttcheck or script is not defined or empty and farmguardian is enabled.
	 0 - If farmguardian configuration was created.

Bugs:
	The function 'print' does not write the variable $?.

See Also:
	zapi/v3/farm_guardian.cgi, zapi/v2/farm_guardian.cgi
=cut

sub runFarmGuardianCreate    # ($fname,$ttcheck,$script,$usefg,$fglog,$svice)
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my ( $fname, $ttcheck, $script, $usefg, $fglog, $svice ) = @_;

	&zenlog(
		"runFarmGuardianCreate( farm: $fname, interval: $ttcheck, cmd: $script, log: $fglog, enabled: $usefg )",
		"debug", "FG"
	);

	my $output = -1;

	# get default name and check not exist
	my $obj = {
				'service'  => $svice,
				'farm'     => $fname,
				'command'  => $script,
				'log'      => $fglog,
				'interval' => $ttcheck,
				'enable'   => $usefg,
	};

	my $output = &setOldFarmguardian( $obj );

	# start
	$output |= &runFGFarmStart( $fname, $svice );

	return $output;
}

=begin nd
Function: runFarmGuardianRemove

	Remove farmguardian down status on backends.

	When farmguardian is stopped or disabled any backend marked as down by farmgardian must reset it's status.

Parameters:
	fname - Farm name.
	svice - Service name. Only apply if the farm profile has services. Leave undefined for farms without services.

Returns:
	none - Nothing is returned explicitly.

Bugs:

See Also:
	zapi/v3/farm_guardian.cgi, zapi/v2/farm_guardian.cgi
=cut

sub runFarmGuardianRemove    # ($fname,$svice)
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my ( $fname, $svice ) = @_;

	my $fg = &getFGFarm( $fname, $svice );

	return if ( not $fg );

	# "unlink" stops the fg
	my $out = &unlinkFGFarm( $fg, $fname, $svice );

	if ( $fg eq &getFGMigrateFile( $fname, $svice )
		 and !@{ &getFGObject( $fg )->{ farms } } )
	{
		$out |= &delFGObject( $fg );
	}

	return;
}

=begin nd
Function: getFarmGuardianConf

	Get farmguardian configuration for a farm-service.

Parameters:
	fname - Farm name.
	svice - Service name. Only apply if the farm profile has services. Leave undefined for farms without services.

Returns:
	list - List with (fname, ttcheck, script, usefg, fglog).

Bugs:
	There is no control if the file could not be opened, for example, if it does not exist.

See Also:
	zapi/v3/get_l4.cgi, zapi/v3/farm_guardian.cgi,

	zapi/v2/get_l4.cgi, zapi/v2/farm_guardian.cgi, zapi/v2/get_http.cgi, zapi/v2/get_tcp.cgi

	<getHttpFarmService>, <getHTTPServiceStruct>
=cut

sub getFarmGuardianConf    # ($fname,$svice)
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my ( $fname, $svice ) = @_;

	# name for old checks
	my $old = &getFGMigrateFile( $fname, $svice );
	my $obj;
	my $usefg = "true";

	my $fg = &getFGFarm( $fname, $svice );
	if ( not $fg )
	{
		$fg = $old if &getFGExists( $old );
		$usefg = "false";
	}

	if ( $fg )
	{
		$obj = &getFGObject( $fg );

		# (fname, ttcheck, script, usefg, fglog).
		return ( $fname, $obj->{ interval }, $obj->{ command }, $usefg, $obj->{ log } );
	}

	return;
}

=begin nd
Function: getFarmGuardianPid

	Read farmgardian pid from pid file. Check if the pid is running and return it,
	else it removes the pid file.

Parameters:
	fname - Farm name.
	svice - Service name. Only apply if the farm profile has services. Leave undefined for farms without services.

Returns:
	-1      - If farmguardian PID file was not found (farmguardian not running).
	integer - PID number (unsigned integer) if farmguardian is running.

Bugs:
	Regex with .* should be fixed.

See Also:
	zevenet

=cut

sub getFarmGuardianPid    # ($fname,$svice)
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my ( $fname, $svice ) = @_;

	my $pid = &getFGPidFarm( $fname, $svice );

	return $pid;
}

1;
