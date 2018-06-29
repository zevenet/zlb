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

my $configdir = &getGlobalConfiguration( 'configdir' );

=begin nd
Function: setL4FarmServer

	Edit a backend or add a new one if the id is not found

Parameters:
	id - Backend id
	ip - Backend IP
	port - Backend port
	weight - Backend weight. The backend with more weight will manage more connections
	priority - The priority of this backend (between 1 and 9). Higher priority backends will be used more often than lower priority ones
	farmname - Farm name

Returns:
	Integer - return 0 on success or -1 on failure

Returns:
	Scalar - 0 on success or other value on failure

=cut

sub setL4FarmServer    # ($ids,$rip,$port,$weight,$priority,$farm_name)
{
	my ( $ids, $rip, $port, $weight, $priority, $farm_name, $max_conns ) = @_;

	require Zevenet::FarmGuardian;
	require Zevenet::Farm::L4xNAT::Config;

	&zenlog(
		"setL4FarmServer << ids:$ids rip:$rip port:$port weight:$weight priority:$priority farm_name:$farm_name max_conns:$max_conns"
	) if &debug;

	my $farm_filename = &getFarmFile( $farm_name );
	my $output        = 0;                            # output: error code
	my $found_server  = 'false';
	my $i             = 0;                            # server ID
	my $l             = 0;                            # line index

	my $farm       = &getL4FarmStruct( $farm_name );
	my $fg_enabled = ( &getFarmGuardianConf( $$farm{ name } ) )[3];
	my $fg_pid     = &getFarmGuardianPid( $farm_name );

	$weight   ||= 1;
	$priority ||= 1;

	if ( $$farm{ status } eq 'up' )
	{
		if ( $fg_enabled eq 'true' )
		{
			kill 'STOP' => $fg_pid;
		}
	}

	require Tie::File;
	tie my @contents, 'Tie::File', "$configdir\/$farm_filename";

	# edit the backed line if found
	foreach my $line ( @contents )
	{
		if ( $line =~ /^\;server\;/ && $found_server eq 'false' )
		{
			if ( $i eq $ids )
			{
				my @aline = split ( ';', $line );
				my $dline =
				  "\;server\;$rip\;$port\;$aline[4]\;$weight\;$priority\;up\;$max_conns\n";

				splice @contents, $l, 1, $dline;
				$output       = $?;       # FIXME
				$found_server = 'true';
			}
			else
			{
				$i++;
			}
		}
		$l++;
	}

	my $mark = undef;

	# add a new backend if not found
	if ( $found_server eq 'false' )
	{
		require Zevenet::Netfilter;

		$mark = &getNewMark( $farm_name );
		push ( @contents,
			   "\;server\;$rip\;$port\;$mark\;$weight\;$priority\;up\;$max_conns\n" );
		$output = $?;    # FIXME
	}
	untie @contents;
	### end editing config file ###

	$farm = &getL4FarmStruct( $farm_name );    # FIXME: start using it earlier

	if ( $$farm{ status } eq 'up' )
	{
		# enabling new server
		if ( $found_server eq 'false' )
		{
			require Zevenet::Net::Util;

			if ( $$farm{ lbalg } eq 'weight' || $$farm{ lbalg } eq 'leastconn' )
			{
				$output |= &_runL4ServerStart( $farm_name, $ids );
			}

			## Set ip rule mark ##
			my $ip_bin      = &getGlobalConfiguration( 'ip_bin' );
			my $vip_if_name = &getInterfaceOfIp( $farm->{ vip } );
			my $vip_if      = &getInterfaceConfig( $vip_if_name );
			my $table_if =
			  ( $vip_if->{ type } eq 'virtual' ) ? $vip_if->{ parent } : $vip_if->{ name };

			my $ip_cmd = "$ip_bin rule add fwmark $mark table table_$table_if";
			&logAndRun( $ip_cmd );
			## Set ip rule mark END ##
		}

		&refreshL4FarmRules( $farm );

		if ( $fg_enabled eq 'true' )
		{
			kill 'CONT' => $fg_pid;
		}
	}

	return $output;
}

=begin nd
Function: runL4FarmServerDelete

	Delete a backend from a l4 farm

Parameters:
	backend - Backend id
	farmname - Farm name

Returns:
	Scalar - 0 on success or other value on failure

=cut

sub runL4FarmServerDelete    # ($ids,$farm_name)
{
	my ( $ids, $farm_name ) = @_;

	require Zevenet::FarmGuardian;
	require Zevenet::Farm::L4xNAT::Config;

	my $farm_filename = &getFarmFile( $farm_name );

	my $output       = 0;
	my $found_server = 'false';
	my $i            = 0;
	my $l            = 0;

	my $farm       = &getL4FarmStruct( $farm_name );
	my $fg_enabled = ( &getFarmGuardianConf( $$farm{ name } ) )[3];
	my $fg_pid     = &getFarmGuardianPid( $farm_name );

	if ( $$farm{ status } eq 'up' )
	{
		if ( $fg_enabled eq 'true' )
		{
			kill 'STOP' => $fg_pid;
		}
	}

	if ( $$farm{ lbalg } eq 'weight' || $$farm{ lbalg } eq 'leastconn' )
	{
		$output |= &_runL4ServerStop( $farm_name, $ids ) if $$farm{ status } eq 'up';
	}

	require Tie::File;
	tie my @contents, 'Tie::File', "$configdir\/$farm_filename";

	foreach my $line ( @contents )
	{
		if ( $line =~ /^\;server\;/ && $found_server eq 'false' )
		{
			if ( $i eq $ids )
			{
				my @sdata = split ( "\;", $line );
				$found_server = 'true';

				splice @contents, $l, 1,;
			}
			else
			{
				$i++;
			}
		}
		$l++;
	}
	untie @contents;

	my $server = $$farm{ servers }[$ids];
	$farm = &getL4FarmStruct( $farm_name );

	# disabling server
	if ( $found_server eq 'true' && $$farm{ status } eq 'up' )
	{
		require Zevenet::Net::Util;

		splice @{ $$farm{ servers } }, $ids, 1;    # remove server from structure

		if ( $$farm{ lbalg } eq 'weight' || $$farm{ lbalg } eq 'prio' )
		{
			$output |= &refreshL4FarmRules( $farm );

			# clear conntrack for udp farms
			if ( $$farm{ proto } eq 'udp' )
			{
				&resetL4FarmBackendConntrackMark( $server );
			}
		}

		## Remove ip rule mark ##
		my $ip_bin      = &getGlobalConfiguration( 'ip_bin' );
		my $vip_if_name = &getInterfaceOfIp( $farm->{ vip } );
		my $vip_if      = &getInterfaceConfig( $vip_if_name );
		my $table_if =
		  ( $vip_if->{ type } eq 'virtual' ) ? $vip_if->{ parent } : $vip_if->{ name };

		my $ip_cmd = "$ip_bin rule del fwmark $server->{ tag } table table_$table_if";
		&logAndRun( $ip_cmd );
		## Remove ip rule mark END ##
	}

	if ( $$farm{ status } eq 'up' )
	{
		if ( $fg_enabled eq 'true' )
		{
			kill 'CONT' => $fg_pid;
		}
	}

	return $output;
}

=begin nd
Function: getL4FarmBackendsStatus_old

	function that return the status information of a farm:
	ip, port, backendstatus, weight, priority, clients

Parameters:
	farmname - Farm name

Returns:
	Array - one backed per line. The line format is: "ip;port;weight;priority;status"

FIXME:
	Change output to hash

=cut

sub getL4FarmBackendsStatus_old    # ($farm_name,@content)
{
	my ( $farm_name, @content ) = @_;

	my @backends_data;             # output

	foreach my $server ( @content )
	{
		my @serv = split ( "\;", $server );
		my $port = $serv[3];
		if ( $port eq "" )
		{
			$port = &getFarmVip( "vipp", $farm_name );
		}
		push ( @backends_data, "$serv[2]\;$port\;$serv[5]\;$serv[6]\;$serv[7]" );
	}

	return @backends_data;
}

=begin nd
Function: setL4FarmBackendsSessionsRemove

	Remove all the active sessions enabled to a backend in a given service
	Used by farmguardian

Parameters:
	farmname - Farm name
	backend - Backend id

Returns:
	Integer - 0 on success or -1 on failure

FIXME:

=cut

sub setL4FarmBackendsSessionsRemove
{
	my ( $farmname, $backend ) = @_;

	require Zevenet::Farm::L4xNAT::Config;

	my %farm        = %{ &getL4FarmStruct( $farmname ) };
	my %be          = %{ $farm{ servers }[$backend] };
	my $recent_file = "/proc/net/xt_recent/_${farmname}_$be{tag}_sessions";
	my $output      = -1;

	if ( open ( my $file, '>', $recent_file ) )
	{
		print $file "/\n";    # flush recent file!!
		close $file;
		$output = 0;
	}
	else
	{
		&zenlog( "Could not open file $recent_file: $!" );
	}

	return $output;
}

=begin nd
Function: setL4FarmBackendStatus

	Set backend status for a l4 farm

Parameters:
	farmname - Farm name
	backend - Backend id
	status - Backend status. The possible values are: "up" or "down"

Returns:
	Integer - 0 on success or other value on failure

=cut

sub setL4FarmBackendStatus    # ($farm_name,$server_id,$status)
{
	my ( $farm_name, $server_id, $status ) = @_;

	require Zevenet::FarmGuardian;
	require Zevenet::Farm::L4xNAT::Config;

	my %farm = %{ &getL4FarmStruct( $farm_name ) };

	my $output   = 0;
	my $line_num = 0;         # line index tracker
	my $serverid = 0;         # server index tracker

	&zenlog(
		"setL4FarmBackendStatus(farm_name:$farm_name,server_id:$server_id,status:$status)"
	);

	my $farm        = &getL4FarmStruct( $farm_name );
	my $fg_enabled  = ( &getFarmGuardianConf( $$farm{ name } ) )[3];
	my $caller      = ( caller ( 2 ) )[3];
	my $stopping_fg = ( $caller =~ /runFarmGuardianStop/ );
	my $fg_pid      = &getFarmGuardianPid( $farm_name );

	#~ &zlog("(caller(2))[3]:$caller");

	if ( $$farm{ status } eq 'up' )
	{
		if ( $fg_enabled eq 'true' && !$stopping_fg )
		{
			if ( $0 !~ /farmguardian/ && $fg_pid > 0 )
			{
				kill 'STOP' => $fg_pid;
			}
		}
	}

	# load farm configuration file
	require Tie::File;
	tie my @configfile, 'Tie::File', "$configdir\/$farm{filename}";

	# look for $server_id backend
	foreach my $line ( @configfile )
	{
		if ( $line =~ /\;server\;/ )
		{
			if ( $serverid eq $server_id )
			{
				# change status in configuration file
				my @lineargs = split ( "\;", $line );
				$lineargs[7] = $status;
				$configfile[$line_num] = join ( "\;", @lineargs );
			}
			$serverid++;
		}
		$line_num++;
	}
	untie @configfile;

	$farm{ servers } = undef;

	#~ %farm = undef;

	%farm = %{ &getL4FarmStruct( $farm_name ) };
	my %server = %{ $farm{ servers }[$server_id] };

	# do no apply rules if the farm is not up
	if ( $farm{ status } eq 'up' )
	{
		$output |= &refreshL4FarmRules( \%farm );

		if ( $status eq 'fgDOWN' && $farm{ lbalg } ne 'prio' && $farm{ persist } eq 'ip' )
		{
			&setL4FarmBackendsSessionsRemove( $farm{ name }, $server_id );
		}

		if ( $fg_enabled eq 'true' && !$stopping_fg )
		{
			if ( $0 !~ /farmguardian/ && $fg_pid > 0 )
			{
				kill 'CONT' => $fg_pid;
			}
		}
	}

	$farm{ servers } = undef;

	#~ %farm             = undef;
	$$farm{ servers } = undef;
	$farm = undef;

	return $output;
}

=begin nd
Function: getL4FarmServers

	 Get all backends and theris configuration

Parameters:
	farmname - Farm name

Returns:
	Array - one backed per line. The line format is:
	"index;ip;port;mark;weight;priority;status"

FIXME:
	Return as array of hash refs

=cut

sub getL4FarmServers    # ($farm_name)
{
	my $farm_name = shift;

	my $farm_filename = &getFarmFile( $farm_name );
	my $sindex        = 0;
	my @servers;

	open FI, "<", "$configdir/$farm_filename"
	  or &zenlog( "Error opening file $configdir/$farm_filename: $!" );

	while ( my $line = <FI> )
	{
		chomp ( $line );

		if ( $line =~ /^\;server\;/ )
		{
			$line =~ s/^\;server/$sindex/g;    #, $line;
			push ( @servers, $line );
			$sindex++;
		}
	}
	close FI;

	chomp @servers;

	return @servers;
}

=begin nd
Function: getL4FarmBackends

	 Get all backends and theirs configuration

Parameters:
	farmname - Farm name

Returns:
	Array ref - Return a array in each element is a hash with the backend
	configuration. The array index is the backend id

=cut

sub getL4FarmBackends    # ($farm_name)
{
	my $farm_name = shift;

	my $farm_filename = &getFarmFile( $farm_name );
	my $sindex        = 0;
	my @servers;

	require Zevenet::Farm::Base;
	my $farmStatus = &getFarmStatus( $farm_name );

	open FI, "<", "$configdir/$farm_filename"
	  or &zenlog( "Error opening file $configdir/$farm_filename: $!" );

	while ( my $line = <FI> )
	{
		chomp ( $line );

		# ;server;192.168.100.254;80;0x20e;1;1;maintenance;0
		if ( $line =~ /^\;server\;/ )
		{
			my @aux = split ( ';', $line );

			# Return port as integer
			$aux[3] = $aux[3] + 0 if ( $aux[3] =~ /^\d+$/ );

			my $status = $aux[7];
			if ( $status eq "fgDOWN" )
			{
				$status = "down";
			}
			if ( ( $status ne "maintenance" ) && ( $farmStatus eq "down" ) )
			{
				$status = "undefined";
			}

			push @servers, {
				id   => $sindex,
				ip   => $aux[2],
				port => ( $aux[3] ) ? $aux[3] : undef,

				#~ mark=>$aux[4],
				weight    => $aux[5] + 0,
				priority  => $aux[6] + 0,
				max_conns => $aux[8] + 0,
				status    => $status,
			};

			$sindex++;
		}
	}
	close FI;

	return \@servers;
}

=begin nd
Function: getL4FarmBackendStatusCtl

	Returns backends information lines

Parameters:
	farmname - Farmname

Returns:
	Array - Each line has the next format: ";server;ip;port;mark;weight;priority;status"

Bugfix:
	DUPLICATED, do same than getL4FarmServers

=cut

sub getL4FarmBackendStatusCtl    # ($farm_name)
{
	my $farm_name     = shift;
	my $farm_filename = &getFarmFile( $farm_name );
	my @output;

	open my $farm_file, '<', "$configdir\/$farm_filename";
	@output = grep { /^\;server\;/ } <$farm_file>;
	close $farm_file;

	chomp @output;

	return @output;
}

=begin nd
Function: _runL4ServerStart

	called from setL4FarmBackendStatus($farm_name,$server_id,$status)
	Run rules to enable a backend

Parameters:
	farmname - Farm name
	backend - Backend id

Returns:
	Integer - Error code: 0 on success or other value on failure

=cut

sub _runL4ServerStart    # ($farm_name,$server_id)
{
	my $farm_name = shift;    # input: farm name string
	my $server_id = shift;    # input: server id number

	my $status = 0;
	my $rules;

	&zenlog( "_runL4ServerStart << farm_name:$farm_name server_id:$server_id" )
	  if &debug;

	my $fg_enabled = ( &getFarmGuardianConf( $farm_name ) )[3];

	# if calling function is setL4FarmAlgorithm
	my $caller             = ( caller ( 2 ) )[3];
	my $changing_algorithm = ( $caller =~ /setL4FarmAlgorithm/ );
	my $setting_be         = ( $caller =~ /setFarmServer/ );
	my $fg_pid             = &getFarmGuardianPid( $farm_name );

	#~ &zlog("(caller(2))[3]:$caller");

	if ( $fg_enabled eq 'true' && !$changing_algorithm && !$setting_be )
	{
		kill 'STOP' => $fg_pid;
	}

	# initialize a farm struct
	my %farm   = %{ &getL4FarmStruct( $farm_name ) };
	my %server = %{ $farm{ servers }[$server_id] };

	## Applying all rules ##
	$rules = &getL4ServerActionRules( \%farm, \%server, 'on' );

	$status |= &applyIptRules( @{ $$rules{ t_mangle_p } } );
	$status |= &applyIptRules( @{ $$rules{ t_mangle } } );
	$status |= &applyIptRules( @{ $$rules{ t_nat } } );
	$status |= &applyIptRules( @{ $$rules{ t_snat } } );
	## End applying rules ##

	if ( $fg_enabled eq 'true' && !$changing_algorithm && !$setting_be )
	{
		kill 'CONT' => $fg_pid;
	}

	return $status;
}

=begin nd
Function: _runL4ServerStop

	Delete rules to disable a backend

Parameters:
	farmname - Farm name
	backend - Backend id

Returns:
	Integer - Error code: 0 on success or other value on failure

=cut

sub _runL4ServerStop    # ($farm_name,$server_id)
{
	my $farm_name = shift;    # input: farm name string
	my $server_id = shift;    # input: server id number

	my $output = 0;
	my $rules;

	my $farm       = &getL4FarmStruct( $farm_name );
	my $fg_enabled = ( &getFarmGuardianConf( $farm_name ) )[3];

	# check calls
	my $caller             = ( caller ( 2 ) )[3];
	my $changing_algorithm = ( $caller =~ /setL4FarmAlgorithm/ );
	my $removing_be        = ( $caller =~ /runL4FarmServerDelete/ );
	my $fg_pid             = &getFarmGuardianPid( $farm_name );

	#~ &zlog("(caller(2))[3]:$caller");

	if ( $fg_enabled eq 'true' && !$changing_algorithm && !$removing_be )
	{
		kill 'STOP' => $fg_pid;
	}

	$farm = &getL4FarmStruct( $farm_name );
	my $server = $$farm{ servers }[$server_id];

	## Applying all rules ##
	$rules = &getL4ServerActionRules( $farm, $server, 'off' );

	$output |= &applyIptRules( @{ $$rules{ t_mangle_p } } );
	$output |= &applyIptRules( @{ $$rules{ t_mangle } } );
	$output |= &applyIptRules( @{ $$rules{ t_nat } } );
	$output |= &applyIptRules( @{ $$rules{ t_snat } } );
	## End applying rules ##

	if ( $fg_enabled eq 'true' && !$changing_algorithm && !$removing_be )
	{
		kill 'CONT' => $fg_pid;
	}

	return $output;
}

=begin nd
Function: getL4ServerActionRules

	???

Parameters:
	farm - Farm hash ref. It is a hash with all information about the farm
	backend - Backend id
	switch - "on" or "off" ???

Returns:
	???

=cut

sub getL4ServerActionRules
{
	my $farm   = shift;    # input: farm reference
	my $server = shift;    # input: server reference
	my $switch = shift;    # input: on/off

	require Zevenet::Netfilter;

	my $rules = &getIptRulesStruct();
	my $rule;

	## persistence rules ##
	if ( $$farm{ persist } ne 'none' )
	{
		# remove if the backend is not under maintenance
		# but if algorithm is set to prio remove anyway
		if (
			 $switch eq 'on'
			 || ( $switch eq 'off'
				  && ( $$farm{ lbalg } eq 'prio' || $$server{ status } ne 'maintenance' ) )
		  )
		{
			$rule = &genIptMarkPersist( $farm, $server );

			$rule = ( $switch eq 'off' )
			  ? &getIptRuleDelete( $rule )    # delete
			  : &getIptRuleInsert( $farm, $server, $rule );    # insert second

			push ( @{ $$rules{ t_mangle_p } }, $rule );
		}
	}

	## dnat (redirect) rules ##
	$rule = &genIptRedirect( $farm, $server );

	$rule = ( $switch eq 'off' )
	  ? &getIptRuleDelete( $rule )                             # delete
	  : &getIptRuleAppend( $rule );

	push ( @{ $$rules{ t_nat } }, $rule );

	## rules for source nat or nat ##
	if ( $$farm{ nattype } eq 'nat' )
	{
		if ( $$farm{ vproto } eq 'sip' )
		{
			$rule = &genIptSourceNat( $farm, $server );
		}
		else
		{
			$rule = &genIptMasquerade( $farm, $server );
		}

		$rule = ( $switch eq 'off' )
		  ? &getIptRuleDelete( $rule )    # delete
		  : &getIptRuleAppend( $rule );

		push ( @{ $$rules{ t_snat } }, $rule );
	}

	## packet marking rules ##
	$rule = &genIptMark( $farm, $server );

	$rule = ( $switch eq 'off' )
	  ? &getIptRuleDelete( $rule )        # delete
	  : &getIptRuleInsert( $farm, $server, $rule );    # insert second

	push ( @{ $$rules{ t_mangle } }, $rule );

	return $rules;
}

=begin nd
Function: getL4ServerWithLowestPriority

	Look for backend with the lowest priority

Parameters:
	farm - Farm hash ref. It is a hash with all information about the farm

Returns:
	hash ref - reference to the selected server for prio algorithm

=cut

sub getL4ServerWithLowestPriority    # ($farm)
{
	my $farm = shift;                # input: farm reference

	my $prio_server;    # reference to the selected server for prio algorithm

	foreach my $server ( @{ $$farm{ servers } } )
	{
		if ( $$server{ status } eq 'up' )
		{
			# find the lowest priority server
			$prio_server = $server if not defined $prio_server;
			$prio_server = $server if $$prio_server{ priority } > $$server{ priority };
		}
	}

	return $prio_server;
}

=begin nd
Function: getL4FarmBackendMaintenance

	Check if a backend on a farm is on maintenance mode

Parameters:
	farmname - Farm name
	backend - Backend id

Returns:
	Integer - 0 for backend in maintenance or 1 for backend not in maintenance

=cut

sub getL4FarmBackendMaintenance
{
	my ( $farm_name, $backend ) = @_;

	my @servers = &getL4FarmServers( $farm_name );
	my @backend_args = split "\;", $servers[$backend];
	chomp ( @backend_args );

	return (    # parentheses required
		$backend_args[6] eq 'maintenance'
		? 0                                 # in maintenance
		: 1                                 # not in maintenance
	);
}

=begin nd
Function: setL4FarmBackendMaintenance

	Enable the maintenance mode for backend

Parameters:
	farmname - Farm name
	backend - Backend id
	mode - Maintenance mode, the options are: drain, the backend continues working with
	  the established connections; or cut, the backend cuts all the established
	  connections

Returns:
	Integer - 0 on success or other value on failure

=cut

sub setL4FarmBackendMaintenance    # ( $farm_name, $backend )
{
	my ( $farm_name, $backend, $mode ) = @_;

	if ( $mode eq "cut" )
	{
		&setL4FarmBackendsSessionsRemove( $farm_name, $backend );

		# remove conntrack
		my $farm   = &getL4FarmStruct( $farm_name );
		my $server = $$farm{ servers }[$backend];
		&resetL4FarmBackendConntrackMark( $server );
	}

	return &setL4FarmBackendStatus( $farm_name, $backend, 'maintenance' );
}

=begin nd
Function: setL4FarmBackendNoMaintenance

	Disable the maintenance mode for backend

Parameters:
	farmname - Farm name
	backend - Backend id

Returns:
	Integer - 0 on success or other value on failure

=cut

sub setL4FarmBackendNoMaintenance
{
	my ( $farm_name, $backend ) = @_;

	return &setL4FarmBackendStatus( $farm_name, $backend, 'up' );
}

=begin nd
Function: getL4BackendsWeightProbability

	Get probability for every backend

Parameters:
	farm - Farm hash ref. It is a hash with all information about the farm

Returns:
	none - .

=cut

sub getL4BackendsWeightProbability
{
	my $farm = shift;    # input: farm reference

	my $weight_sum = 0;

	&doL4FarmProbability( $farm );    # calculate farm weight sum

	foreach my $server ( @{ $$farm{ servers } } )
	{
		# only calculate probability for servers running
		if ( $$server{ status } eq 'up' )
		{
			my $delta = $$server{ weight };
			$weight_sum += $$server{ weight };
			$$server{ prob } = $weight_sum / $$farm{ prob };
		}
		else
		{
			$$server{ prob } = 0;
		}
	}
}

# reset connection tracking for a backend
# used in udp protocol
# called by: refreshL4FarmRules, runL4FarmServerDelete
sub resetL4FarmBackendConntrackMark
{
	my $server = shift;

	my $conntrack = &getGlobalConfiguration( 'conntrack' );
	my $cmd       = "$conntrack -D -m $server->{ tag }";

	&zenlog( "running: $cmd" ) if &debug();

	# return_code = 0 -> deleted
	# return_code = 1 -> not found/deleted
	# WARNIG: STDOUT must be null so cherokee does not receive this output
	# as http headers.
	my $return_code = system( "$cmd 2>/dev/null" );

	if ( &debug() )
	{
		if ( $return_code )
		{
			&zenlog( "Connection tracking for $server->{ vip } not found." );
		}
		else
		{
			&zenlog( "Connection tracking for $server->{ vip } removed." );
		}
	}

	return $return_code;
}

1;
