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
Function: runL4FarmRestart

	Restart a l4xnat farm

Parameters:
	farmname - Farm name
	writeconf - Write start on configuration file
	changes - This field lets to do the changes without stop the farm. The possible values are: "", blank for stop and start the farm, or "hot" for not stop the farm before run it

Returns:
	Integer - Error code: 0 on success or other value on failure

FIXME:
	writeconf is a obsolet parameter

=cut

sub runL4FarmRestart    # ($farm_name,$writeconf,$type)
{
	my ( $farm_name, $writeconf, $type ) = @_;

	my $algorithm   = &getFarmAlgorithm( $farm_name );
	my $fbootstatus = &getFarmBootStatus( $farm_name );
	my $output      = 0;
	my $pidfile     = "/var/run/l4sd.pid";

	if (    $algorithm eq "leastconn"
		 && $fbootstatus eq "up"
		 && $writeconf eq "false"
		 && $type eq "hot"
		 && -e "$pidfile" )
	{
		open FILE, "<$pidfile";
		my $pid = <FILE>;
		close FILE;

		kill USR1 => $pid;
		$output = $?;    # FIXME
	}
	else
	{
		&_runL4FarmStop( $farm_name, $writeconf );
		$output = &_runL4FarmStart( $farm_name, $writeconf );
	}

	return $output;
}

=begin nd
Function: _runL4FarmRestart

	Restart a l4xnat farm

Parameters:
	farmname - Farm name
	writeconf - Write start on configuration file
	changes - This field lets to do the changes without stop the farm. The possible values are: "", blank for stop and start the farm, or "hot" for not stop the farm before run it

Returns:
	Integer - Error code: 0 on success or other value on failure

FIXME:
	writeconf is a obsolet parameter
	$type parameter never is used

BUG:
	DUPLICATED FUNCTION, do the same than &runL4FarmRestart function.

=cut

sub _runL4FarmRestart    # ($farm_name,$writeconf,$type)
{
	my ( $farm_name, $writeconf, $type ) = @_;

	my $algorithm   = &getFarmAlgorithm( $farm_name );
	my $fbootstatus = &getFarmBootStatus( $farm_name );
	my $output      = 0;
	my $pidfile     = "/var/run/l4sd.pid";

	if (    $algorithm eq "leastconn"
		 && $fbootstatus eq "up"
		 && $writeconf eq "false"
		 && $type eq "hot"
		 && -e $pidfile )
	{
		open FILE, "<$pidfile";
		my $pid = <FILE>;
		close FILE;

		# reload config file
		kill USR1 => $pid;
		$output = $?;    # FIXME
	}
	else
	{
		&_runL4FarmStop( $farm_name, $writeconf );
		$output = &_runL4FarmStart( $farm_name, $writeconf );
	}

	return $output;
}

=begin nd
Function: _runL4FarmStart

	Run a l4xnat farm

Parameters:
	farmname - Farm name
	writeconf - write this change in configuration status "true" or omit it "false"

Returns:
	Integer - return 0 on success or different of 0 on failure

FIXME:
	delete writeconf parameter. It is obsolet

=cut

sub _runL4FarmStart    # ($farm_name,$writeconf)
{
	my $farm_name = shift;    # input
	my $writeconf = shift;    # input

	require Zevenet::Net::Util;
	require Zevenet::Netfilter;
	require Zevenet::Farm::L4xNAT::Config;

	&zlog( "Starting farm $farm_name" ) if &debug == 2;

	my $status = 0;           # output

	&zenlog( "_runL4FarmStart << farm_name:$farm_name writeconf:$writeconf" )
	  if &debug;

	# initialize a farm struct
	my $farm = &getL4FarmStruct( $farm_name );

	if ( $writeconf eq "true" )
	{
		require Tie::File;

		tie my @configfile, 'Tie::File', "$configdir\/$$farm{ filename }";
		foreach ( @configfile )
		{
			s/\;down/\;up/g;
			last;
		}
		untie @configfile;
	}

	my $l4sd = &getGlobalConfiguration( 'l4sd' );

	# Load L4 scheduler if needed
	if ( $$farm{ lbalg } eq 'leastconn' && -e "$l4sd" )
	{
		system ( "$l4sd >/dev/null &" );
	}

	# Load required modules
	if ( $$farm{ vproto } =~ /sip|ftp/ )
	{
		&loadL4Modules( $$farm{ vproto } );
	}

	my $rules;
	my $lowest_prio;
	my $server_prio;    # reference to the selected server for prio algorithm

	## Set ip rule mark ##
	my $ip_bin      = &getGlobalConfiguration( 'ip_bin' );
	my $vip_if_name = &getInterfaceOfIp( $farm->{ vip } );
	my $vip_if      = &getInterfaceConfig( $vip_if_name );
	my $table_if =
	  ( $vip_if->{ type } eq 'virtual' ) ? $vip_if->{ parent } : $vip_if->{ name };

# insert the save rule, then insert on top the restore rule
# WARNING: Set Connmark rules BEFORE getting the farm rules or Connmark rules will be misplaced
	&setIptConnmarkSave( $farm_name, 'true' );
	&setIptConnmarkRestore( $farm_name, 'true' );

	foreach my $server ( @{ $$farm{ servers } } )
	{
		&zenlog( "_runL4FarmStart :: server:$server->{id}" ) if &debug;

		my $backend_rules;

		## Set ip rule mark ##
		my $ip_cmd = "$ip_bin rule add fwmark $server->{ tag } table table_$table_if";
		&logAndRun( $ip_cmd );

		# TMP: leastconn dynamic backend status check
		if ( $$farm{ lbalg } =~ /weight|leastconn/ )
		{
			$backend_rules = &getL4ServerActionRules( $farm, $server, 'on' );

			push ( @{ $$rules{ t_mangle_p } }, @{ $$backend_rules{ t_mangle_p } } );
			push ( @{ $$rules{ t_mangle } },   @{ $$backend_rules{ t_mangle } } );
			push ( @{ $$rules{ t_nat } },      @{ $$backend_rules{ t_nat } } );
			push ( @{ $$rules{ t_snat } },     @{ $$backend_rules{ t_snat } } );
		}
		elsif ( $$farm{ lbalg } eq 'prio' && $$server{ status } ne 'fgDOWN' )
		{
			# find the lowest priority server
			if ( $$server{ priority } ne ''
				 && ( $$server{ priority } < $lowest_prio || !defined $lowest_prio ) )
			{
				$server_prio = $server;
				$lowest_prio = $$server{ priority };
			}
		}
	}

	# prio only apply rules to one server
	if ( $server_prio && $$farm{ lbalg } eq 'prio' )
	{
		system ( "echo 10 > /proc/sys/net/netfilter/nf_conntrack_udp_timeout_stream" );
		system ( "echo 5 > /proc/sys/net/netfilter/nf_conntrack_udp_timeout" );

		$rules = &getL4ServerActionRules( $farm, $server_prio, 'on' );
	}

	## lock iptables use ##
	my $iptlock = &getGlobalConfiguration( 'iptlock' );
	open ( my $ipt_lockfile, '>', $iptlock );

	unless ( $ipt_lockfile )
	{
		&zenlog( "Could not open $iptlock: $!" );
		return 1;
	}

	for my $table ( qw(t_mangle_p t_mangle t_nat t_snat) )
	{
		$status = &applyIptRules( @{ $$rules{ $table } } );
		return $status if $status;
	}

	## unlock iptables use ##
	&setIptUnlock( $ipt_lockfile );
	close $ipt_lockfile;

	# Enable IP forwarding
	&setIpForward( 'true' );

	# Enable active l4 file
	if ( $status == 0 )
	{
		my $piddir = &getGlobalConfiguration( 'piddir' );
		open my $fi, '>', "$piddir\/$$farm{name}\_l4xnat.pid";
		close $fi;
	}

	return $status;
}

=begin nd
Function: _runL4FarmStop

	Stop a l4xnat farm

Parameters:
	farmname - Farm name
	writeconf - write this change in configuration status "true" or omit it "false"

Returns:
	Integer - return 0 on success or other value on failure

FIXME:
	delete writeconf parameter. It is obsolet

=cut

sub _runL4FarmStop    # ($farm_name,$writeconf)
{
	my ( $farm_name, $writeconf ) = @_;

	require Zevenet::Net::Util;
	require Zevenet::Farm::L4xNAT::Config;

	&zlog( "Stopping farm $farm_name" ) if &debug == 2;

	my $farm_filename = &getFarmFile( $farm_name );
	my $status;       # output

	if ( $writeconf eq 'true' )
	{
		require Tie::File;

		tie my @configfile, 'Tie::File', "$configdir\/$farm_filename";
		foreach ( @configfile )
		{
			s/\;up/\;down/g;
			last;     # run only for the first line
		}
		untie @configfile;
	}

	## lock iptables use ##
	my $iptlock = &getGlobalConfiguration( 'iptlock' );
	open ( my $ipt_lockfile, '>', $iptlock );

	unless ( $ipt_lockfile )
	{
		&zenlog( "Could not open $iptlock: $!" );
		return 1;
	}

	require Zevenet::Netfilter;
	&setIptLock( $ipt_lockfile );

	# Disable rules
	my @allrules;

	require Zevenet::Netfilter;
	@allrules = &getIptList( $farm_name, "mangle", "PREROUTING" );
	$status =
	  &deleteIptRules( $farm_name,   "farm", $farm_name, "mangle",
					   "PREROUTING", @allrules );

	@allrules = &getIptList( $farm_name, "nat", "PREROUTING" );
	$status = &deleteIptRules( $farm_name,   "farm", $farm_name, "nat",
							   "PREROUTING", @allrules );

	@allrules = &getIptList( $farm_name, "nat", "POSTROUTING" );
	$status =
	  &deleteIptRules( $farm_name, "farm", $farm_name, "nat", "POSTROUTING",
					   @allrules );

	## unlock iptables use ##
	&setIptUnlock( $ipt_lockfile );
	close $ipt_lockfile;

	# Disable active l4xnat file
	my $piddir = &getGlobalConfiguration( 'piddir' );
	unlink ( "$piddir\/$farm_name\_l4xnat.pid" );

	if ( -e "$piddir\/$farm_name\_l4xnat.pid" )
	{
		$status = -1;
	}

	## Delete ip rule mark ##
	my $farm        = &getL4FarmStruct( $farm_name );
	my $ip_bin      = &getGlobalConfiguration( 'ip_bin' );
	my $vip_if_name = &getInterfaceOfIp( $farm->{ vip } );
	my $vip_if      = &getInterfaceConfig( $vip_if_name );
	my $table_if =
	  ( $vip_if->{ type } eq 'virtual' ) ? $vip_if->{ parent } : $vip_if->{ name };

	foreach my $server ( @{ $$farm{ servers } } )
	{
		# remove conntrack
		&resetL4FarmBackendConntrackMark( $server );

		unless ( defined $table_if )
		{
			&zenlog("Warning: Skipping removal of backend $server->{ tag } routing rule. Interface table not found.");
			next;
		}

		my $ip_cmd = "$ip_bin rule del fwmark $server->{ tag } table table_$table_if";
		&logAndRun( $ip_cmd );
	}

	## Delete ip rule mark END ##
	&setIptConnmarkRestore( $farm_name );
	&setIptConnmarkSave( $farm_name );

	# Reload conntrack modules
	if ( $$farm{ vproto } =~ /sip|ftp/ )
	{
		&loadL4Modules( $$farm{ vproto } );
	}

	return $status;
}

=begin nd
Function: setL4NewFarmName

	Function that renames a farm

Parameters:
	newfarmname - New farm name
	farmname - Farm name

Returns:
	Array - Each line has the next format: ";server;ip;port;mark;weight;priority;status"

Bugfix:
	DUPLICATED, do same than getL4FarmServers

=cut

sub setL4NewFarmName    # ($farm_name,$new_farm_name)
{
	my ( $farm_name, $new_farm_name ) = @_;

	require Tie::File;
	require Zevenet::Netfilter;

	my $farm_filename     = &getFarmFile( $farm_name );
	my $farm_type         = &getFarmType( $farm_name );
	my $new_farm_filename = "$new_farm_name\_$farm_type.cfg";
	my $output            = 0;
	my $status            = &getFarmStatus( $farm_name );

	# previous farm info
	my $prev_farm = &getL4FarmStruct( $farm_name );

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

	tie my @configfile, 'Tie::File', "$configdir\/$farm_filename";

	for ( @configfile )
	{
		s/^$farm_name\;/$new_farm_name\;/g;
	}
	untie @configfile;

	my $piddir = &getGlobalConfiguration( 'piddir' );
	rename ( "$configdir\/$farm_filename", "$configdir\/$new_farm_filename" )
	  or $output = -1;
	if ( -f "$piddir\/$farm_name\_$farm_type.pid" )
	{
		rename ( "$piddir\/$farm_name\_$farm_type.pid",
				 "$piddir\/$new_farm_name\_$farm_type.pid" )
		  or $output = -1;
	}

	# Rename fw marks for this farm
	&renameMarks( $farm_name, $new_farm_name );

	$farm = &getL4FarmStruct( $new_farm_name );
	my $apply_farm = $farm;
	$apply_farm = $prev_farm if $$farm{ lbalg } eq 'prio';

	if ( $$farm{ status } eq 'up' )
	{
		my @rules;

		my $prio_server = &getL4ServerWithLowestPriority( $$farm{ name } )
		  if ( $$farm{ lbalg } eq 'prio' );

		# refresh backends probability values
		&getL4BackendsWeightProbability( $farm ) if ( $$farm{ lbalg } eq 'weight' );

		# get new rules
		foreach my $server ( @{ $$farm{ servers } } )
		{
			# skip cycle for servers not running
			#~ next if ( $$server{ status } !~ /up|maintenance/ );

			next if ( $$farm{ lbalg } eq 'prio' && $$server{ id } != $$prio_server{ id } );

			my $rule;
			my $rule_num;

			# refresh marks
			$rule = &genIptMark( $prev_farm, $server );

			$rule_num =
			  ( $$farm{ lbalg } eq 'prio' )
			  ? &getIptRuleNumber( $rule, $$apply_farm{ name } )
			  : &getIptRuleNumber( $rule, $$apply_farm{ name }, $$server{ id } );
			$rule = &genIptMark( $farm, $server );
			$rule = &applyIptRuleAction( $rule, 'replace', $rule_num );
			push ( @rules, $rule );

			if ( $$farm{ persist } ne 'none' )    # persistence
			{
				$rule = &genIptMarkPersist( $prev_farm, $server );
				$rule_num =
				  ( $$farm{ lbalg } eq 'prio' )
				  ? &getIptRuleNumber( $rule, $$apply_farm{ name } )
				  : &getIptRuleNumber( $rule, $$apply_farm{ name }, $$server{ id } );
				$rule = &genIptMarkPersist( $farm, $server );
				$rule = &applyIptRuleAction( $rule, 'replace', $rule_num );
				push ( @rules, $rule );
			}

			# redirect
			$rule = &genIptRedirect( $prev_farm, $server );
			$rule_num =
			  ( $$farm{ lbalg } eq 'prio' )
			  ? &getIptRuleNumber( $rule, $$apply_farm{ name } )
			  : &getIptRuleNumber( $rule, $$apply_farm{ name }, $$server{ id } );
			$rule = &genIptRedirect( $farm, $server );
			$rule = &applyIptRuleAction( $rule, 'replace', $rule_num );
			push ( @rules, $rule );

			if ( $$farm{ nattype } eq 'nat' )    # nat type = nat
			{
				if ( $$farm{ vproto } eq 'sip' )
				{
					$rule = &genIptSourceNat( $farm, $server );
				}
				else
				{
					$rule = &genIptMasquerade( $farm, $server );
				}

				$rule_num =
				  ( $$farm{ lbalg } eq 'prio' )
				  ? &getIptRuleNumber( $rule, $$apply_farm{ name } )
				  : &getIptRuleNumber( $rule, $$apply_farm{ name }, $$server{ id } );

				if ( $$farm{ vproto } eq 'sip' )
				{
					$rule = &genIptSourceNat( $farm, $server );
				}
				else
				{
					$rule = &genIptMasquerade( $farm, $server );
				}

				$rule = &applyIptRuleAction( $rule, 'replace', $rule_num );
				push ( @rules, $rule );
			}
		}

		if ( $fg_enabled eq 'true' )
		{
			if ( $0 !~ /farmguardian/ )
			{
				kill 'CONT' => $fg_pid;
			}
		}

		# apply new rules
		$output = &applyIptRules( @rules );
	}

	return $output;
}

1;
