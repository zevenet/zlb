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

use Data::Dumper;
use Fcntl qw(:flock SEEK_END);

#
sub loadNfModule    # ($modname,$params)
{
	my ( $modname, $params ) = @_;

	my $status  = 0;
	my $lsmod = &getGlobalConfiguration('lsmod');
	my @modules = `$lsmod`;

	if ( !grep { /^$modname /x } @modules )
	{
		my $modprobe = &getGlobalConfiguration('modprobe');
		my $modprobe_command = "$modprobe $modname $params";

		&zenlog( "L4 loadNfModule: $modprobe_command" );
		system ( "$modprobe_command >/dev/null 2>&1" );
		$status = $?;
	}

	return $status;
}

#
sub removeNfModule    # ($modname)
{
	my $modname = shift;

	my $modprobe = &getGlobalConfiguration('modprobe');
	my $modprobe_command = "$modprobe -r $modname";

	&zenlog( "L4 removeNfModule: $modprobe_command" );

	return system ( "$modprobe_command >/dev/null 2>&1" );
}

#
sub getIptFilter      # ($type, $desc, @iptables)
{
	my ( $type, $desc, @iptables ) = @_;    # input args

	my @selected_rules;

	@selected_rules = grep { / FARM\_$desc\_.* /x } @iptables
	  if ( $type eq 'farm' );

	return @selected_rules;
}

#
sub getIptList                              # ($table,$chain)
{
	my ( $farm_name, $table, $chain ) = @_;

	if ( $table ne '' )
	{
		$table = "--table $table";
	}

	# Get the binary of iptables (iptables or ip6tables)
	my $iptables_bin     = &getBinVersion( $farm_name );
	my $iptables_command = "$iptables_bin $table -L $chain -n -v --line-numbers";

	my @ipt_output = `$iptables_command`;
	&zenlog( "failed: $iptables_command" ) if $?;

	return @ipt_output;
}

#
sub deleteIptRules    # ($type,$desc,$table,$chain,@allrules)
{
	my ( $farm_name, $type, $desc, $table, $chain, @allrules ) = @_;

	my $status = 0;
	my @rules = &getIptFilter( $type, $desc, @allrules );

	# Get the binary of iptables (iptables or ip6tables)
	my $iptables_bin = &getBinVersion( $farm_name );

	# do not change rules id starting by the end
	chomp ( @rules = reverse ( @rules ) );

	foreach my $rule ( @rules )
	{
		my @sprule = split ( ' ', $rule );

		if ( $type eq 'farm' )
		{
			my $iptables_command =
			  "$iptables_bin --table $table --delete $chain $sprule[0]";

			$status = &runIptables( $iptables_command );
		}
	}

	return $status;
}

#
sub getNewMark    # ($farm_name)
{
	my $farm_name = shift;

	my $found;
	my $marknum = 0x200;
	my $fwmarksconf = &getGlobalConfiguration('fwmarksconf');

	tie my @contents, 'Tie::File', "$fwmarksconf";

	for my $i ( 512 .. 1023 )
	{
		# end loop if found
		last if defined $found;

		my $num = sprintf ( "0x%x", $i );
		if ( !grep { /^$num/x } @contents )
		{
			$found   = 'true';
			$marknum = $num;
		}
	}

	untie @contents;

	if ( $found eq 'true' )
	{
		open ( my $marksfile, '>>', "$fwmarksconf" );
		print $marksfile "$marknum // FARM\_$farm_name\_\n";
		close $marksfile;
	}

	return $marknum;
}

#
sub delMarks    # ($farm_name,$mark)
{
	my ( $farm_name, $mark ) = @_;

	my $status = 0;
	my $fwmarksconf = &getGlobalConfiguration('fwmarksconf');

	if ( $farm_name ne "" )
	{
		require Tie::File;
		tie my @contents, 'Tie::File', "$fwmarksconf";
		@contents = grep { !/ \/\/ FARM\_$farm_name\_$/x } @contents;
		$status = $?;    # FIXME
		untie @contents;
	}

	if ( $mark ne "" )
	{
		require Tie::File;
		tie my @contents, 'Tie::File', "$fwmarksconf";
		@contents = grep { !/^$mark \/\//x } @contents;
		$status = $?;    # FIXME
		untie @contents;
	}

	return $status;    # FIXME
}

#
sub renameMarks        # ($farm_name,$newfname)
{
	my ( $farm_name, $newfname ) = @_;

	my $status = 0;

	if ( $farm_name ne "" )
	{
		my $fwmarksconf = &getGlobalConfiguration('fwmarksconf');
		tie my @contents, 'Tie::File', "$fwmarksconf";
		foreach my $line ( @contents )
		{
			$line =~ s/ \/\/ FARM\_$farm_name\_/ \/\/ FARM\_$newfname\_/x;
		}
		$status = $?;    # FIXME
		untie @contents;
	}

	return $status;      # FIXME
}

#
sub genIptMarkPersist    # ($farm_name,$vip,$vport,$protocol,$ttl,$index,$mark)
{
	# remove the first line when all calls to this function are passing
	# structure references
	my ( $farm_name, $vip, $vport, $protocol, $ttl, $index, $mark ) = @_;

	my $farm   = shift;    # input: first argument can be a farm reference
	my $server = shift;    # input: second argument can be a server reference
	my $rule;              # output: iptables rule template string
   	if ( defined $farm )
    	{
        	$farm_name = $$farm{ name };
    	}

   	if ( defined $farm )
	{
		$farm_name = $$farm{ name };
	}

	if ( defined $index )
	{
		$farm   = &getL4FarmStruct( $farm_name );
		$server = $$farm{ servers }[$index];
	}

	my $layer = '';
	if ( $$farm{ proto } ne 'all' )
	{
		$layer = "--protocol $$farm{ proto } -m multiport --dports $$farm{ vport }";
	}

	# Get the binary of iptables (iptables or ip6tables)
	my $iptables_bin = &getBinVersion( $farm_name );

	$rule = "$iptables_bin --table mangle --::ACTION_TAG:: PREROUTING "
	  . "--destination $$farm{ vip } "

	  #~ . "$layer "

	  . "--match recent --name \"\_$$farm{ name }\_$$server{ tag }\_sessions\" --rcheck --seconds $$farm{ ttl } "

	  #~ . "--match state ! --state NEW "    # new
	  . "$layer "
	  . "--match comment --comment ' FARM\_$$farm{ name }\_$$server{ id }\_ ' "
	  . "--jump MARK --set-xmark $$server{ tag } ";    # new
	    #~ . "--jump MARK --set-mark $$server{ tag } ";	# old

	#~ &zenlog( $rule );
	return $rule;
}

#
sub genIptMark # ($farm_name,$lbalg,$vip,$vport,$protocol,$index,$mark,$value,$prob)
{
	# remove the first line when all calls to this function are passing
	# structure references
	my ( $farm_name, $lbalg, $vip, $vport, $protocol, $index, $mark, $value, $prob )
	  = @_;

	my $farm   = shift;    # input: first argument should be a farm reference
	my $server = shift;    # input: second argument should be a server reference
	my $rule;              # output: iptables rule template string

	if ( defined $farm )
	{
		$farm_name = $$farm{ name };
	}

	# for compatibility with previous function call
	if ( defined $index )
	{
		$farm   = &getL4FarmStruct( $farm_name );
		$server = $$farm{ servers }[$index];
	}

	my $layer;
	if ( $$farm{ proto } ne 'all' )
	{
		$layer = "--protocol $$farm{ proto } -m multiport --dports $$farm{ vport }";
	}

	# Get the binary of iptables (iptables or ip6tables)
	my $iptables_bin = &getBinVersion( $farm_name );

	# Every rule starts with:
	# table, chain, destination(farm ip) and port(if required) definition
	$rule = "$iptables_bin --table mangle --::ACTION_TAG:: PREROUTING "

	  #~ . "--destination $$farm{ vip } "
	  #~ . "$layer "
	  ;

	if ( $$farm{ lbalg } eq 'weight' )
	{
		$rule .= "--match statistic --mode random --probability $$server{ prob } ";
	}

	if ( $$farm{ lbalg } eq 'leastconn' )
	{
		$rule .= "--match condition --condition '\_$$farm{ name }\_$$server{ tag }\_' ";
	}

	#~ if ( $$farm{ lbalg } eq 'prio' )
	#~ {
	#~ $rule = $rule;
	#~ }

	# include for every rule:
	# - match new packets/connections
	# - add comment with farm name and backend id number
	# - set mark
	$rule = $rule

	  #~ . "--match state --state NEW "    # new
	  . "--destination $$farm{ vip } "
	  . "$layer "
	  . "--match comment --comment ' FARM\_$$farm{ name }\_$$server{ id }\_ ' "
	  . "--jump MARK --set-xmark $$server{ tag } ";    # new
	    #~ . "--jump MARK --set-mark $$server{ tag } ";	# old

	#~ &zenlog( $rule );
	return $rule;
}

#
sub genIptRedirect    # ($farm_name,$index,$rip,$protocol,$mark,$persist)
{
	# remove the first line when all calls to this function are passing
	# structure references
	my ( $farm_name, $index, $vip, $vport, $protocol, $mark, $persist ) = @_;

	my $farm   = shift;    # input: first argument can be a farm reference
	my $server = shift;    # input: second argument can be a server reference

	if ( defined $farm )
	{
		$farm_name = $$farm{ name };
	}

	if ( defined $vip )
	{
		$farm   = &getL4FarmStruct( $farm_name );
		$server = $$farm{ servers }[$index];
	}

	my $layer = '';
	if ( $$farm{ proto } ne "all" )
	{
		$layer = "--protocol $$farm{ proto }";
	}

	my $persist_match = '';
	if ( $$farm{ persist } ne "none" )
	{
		$persist_match =
		  "--match recent --name \"\_$$farm{ name }\_$$server{ tag }\_sessions\" --set";
	}

	my $connlimit_match = '';
	if ( $$server{ max_conns } )
	{
		$connlimit_match .= "--match connlimit --connlimit-upto $$server{ max_conns } --connlimit-daddr";
	}

	# Get the binary of iptables (iptables or ip6tables)
	my $iptables_bin = &getBinVersion( $farm_name );

	# output: iptables rule template string
	my $rule =
	    "$iptables_bin --table nat --::ACTION_TAG:: PREROUTING "
	  . "--match mark --mark $$server{ tag } "
	  . "$persist_match "
	  . "$connlimit_match "
	  . "--match comment --comment ' FARM\_$$farm{ name }\_$$server{ id }\_ ' "
	  . "--jump DNAT $layer --to-destination $$server{ rip } ";

	return $rule;
}

#
sub genIptSourceNat    # ($farm_name,$vip,$index,$protocol,$mark)
{
	# remove the first line when all calls to this function are passing
	# structure references
	my ( $farm_name, $vip, $index, $protocol, $mark ) = @_;

	my $farm   = shift;    # input: first argument can be a farm reference
	my $server = shift;    # input: second argument can be a server reference

	if ( defined $farm )
	{
		$farm_name = $$farm{ name };
	}

	if ( defined $index )
	{
		$farm   = &getL4FarmStruct( $farm_name );
		$server = $$farm{ servers }[$index];
	}

	my $layer = '';
	if ( $$farm{ proto } ne "all" )
	{
		$layer = "--protocol $$farm{ proto }";
	}

	# Get the binary of iptables (iptables or ip6tables)
	my $iptables_bin = &getBinVersion( $farm_name );
	my $nat_params   = "--jump SNAT --to-source $$server{ vip }";

	if ( eval { require Zevenet::Net::Floating; } )
	{
		$nat_params = &getFloatingSnatParams( $server );
	}

	# output: iptables rule template string
	my $rule =
	    "$iptables_bin --table nat --::ACTION_TAG:: POSTROUTING "
	  . "$layer "
	  . "--match mark --mark $$server{ tag } "
	  . "--match comment --comment ' FARM\_$$farm{ name }\_$$server{ id }\_ ' "
	  . "$nat_params ";

	return $rule;
}

#
sub genIptMasquerade    # ($farm_name,$index,$protocol,$mark)
{
	# remove the first line when all calls to this function are passing
	# structure references
	my ( $farm_name, $index, $protocol, $mark ) = @_;

	my $farm   = shift;    # input: first argument can be a farm reference
	my $server = shift;    # input: second argument can be a server reference

	if ( defined $farm )
	{
		$farm_name = $$farm{ name };
	}

	if ( defined $protocol )
	{
		$farm   = &getL4FarmStruct( $farm_name );
		$server = $$farm{ servers }[$index];
	}

	my $layer = '';
	if ( $$farm{ proto } ne "all" )
	{
		$layer = "--protocol $$farm{ proto }";
	}

	# Get the binary of iptables (iptables or ip6tables)
	my $iptables_bin = &getBinVersion( $farm_name );
	my $nat_params   = "--jump MASQUERADE";

	if ( eval { require Zevenet::Net::Floating; } )
	{
		$nat_params = &getFloatingMasqParams( $farm, $server );
	}

	# output: iptables rule template string
	my $rule =
	    "$iptables_bin --table nat --::ACTION_TAG:: POSTROUTING "
	  . "$layer "
	  . "--match mark --mark $$server{ tag } "
	  . "--match comment --comment ' FARM\_$$farm{ name }\_$$server{ id }\_ ' "
	  . "$nat_params ";

	return $rule;
}

# insert restore mark on top of
sub getIptStringConnmarkRestore
{
	my $farm_name = shift;    # farmname

	# Get the binary of iptables (iptables or ip6tables)
	my $iptables_bin = &getBinVersion( $farm_name );

	return "$iptables_bin --table mangle --::ACTION_TAG:: PREROUTING "
	  . "--jump CONNMARK --restore-mark ";

	#~ . "--nfmask 0xffffffff --ctmask 0xffffffff "
}

# append restore mark at the end of
sub getIptStringConnmarkSave
{
	my $farm_name = shift;    # farmname

	# Get the binary of iptables (iptables or ip6tables)
	my $iptables_bin = &getBinVersion( $farm_name );

	return
	    "$iptables_bin --table mangle --::ACTION_TAG:: PREROUTING "
	  . "--match state --state NEW "
	  . "--jump CONNMARK --save-mark ";

	#~ . "--nfmask 0xffffffff --ctmask 0xffffffff "
}

sub setIptConnmarkRestore
{
	my $farm_name   = shift;    # farmname
	my $switch      = shift;    # 'true' or not true value
	$switch ||= 'false';

	my $return_code = -1;       # return value

	## lock iptables use ##
	my $iptlock = &getGlobalConfiguration('iptlock');
	open ( my $ipt_lockfile, '>', $iptlock );

	unless ( $ipt_lockfile )
	{
		&zenlog("Could not open $iptlock: $!");
		return 1;
	}

	my $rule = &getIptStringConnmarkRestore( $farm_name );
	my $restore_on = ( &runIptables( &applyIptRuleAction( $rule, 'check' ) ) == 0 );

	# if want to set it on but not already on
	if ( $switch eq 'true' && !$restore_on )
	{
		$return_code = &runIptables( &applyIptRuleAction( $rule, 'insert' ) );
	}

	# if want to turn it off, is on and only one farm needs it
	elsif (    $switch ne 'true'
			&& $restore_on
			&& &getNumberOfFarmTypeRunning( 'l4xnat' ) == 0 )
	{
		$return_code = &runIptables( &applyIptRuleAction( $rule, 'delete' ) );
	}

	## unlock iptables use ##
	&setIptUnlock( $ipt_lockfile );
	close $ipt_lockfile;

	return $return_code;
}

sub setIptConnmarkSave
{
	my $farm_name   = shift;    # farmname
	my $switch      = shift;    # 'true' or not true value
	$switch ||= 'false';

	my $return_code = -1;       # return value

	## lock iptables use ##
	my $iptlock = &getGlobalConfiguration('iptlock');
	open ( my $ipt_lockfile, '>', $iptlock );

	unless ( $ipt_lockfile )
	{
		&zenlog("Could not open $iptlock: $!");
		return 1;
	}

	my $rule = &getIptStringConnmarkSave( $farm_name );
	my $restore_on = ( &runIptables( &applyIptRuleAction( $rule, 'check' ) ) == 0 );

	# if want to set it on but not already on
	if ( $switch eq 'true' && !$restore_on )
	{
		$return_code = &runIptables( &applyIptRuleAction( $rule, 'append' ) );
	}

	# if want to turn it off, is on and only one farm needs it
	elsif (    $switch ne 'true'
			&& $restore_on
			&& &getNumberOfFarmTypeRunning( 'l4xnat' ) == 0 )
	{
		$return_code = &runIptables( &applyIptRuleAction( $rule, 'delete' ) );
	}

	## unlock iptables use ##
	&setIptUnlock( $ipt_lockfile );
	close $ipt_lockfile;

	return $return_code;
}

sub applyIptRuleAction
{
	my $rule    = shift;    # rule string with ::ACTION_TAG:: instead of action
	my $action  = shift;    # must be append|check|delete|insert|replace
	my $rulenum = shift;    # input: optional (required for replace)

	# return the action requested if not supported
	return $action if $action !~ /append|check|delete|insert|replace/x;

	if ( $action =~ /insert|replace|delete/ && $rulenum > 0 )
	{
		my @rule_args = split ( ' ', $rule );

		# include rule number in 5th position in the string
		splice @rule_args, 5, 0, $rulenum;
		$rule = ( $action eq 'delete' )
		  ? join ( ' ', @rule_args[0 .. 5] )    # delete rule number
		  : join ( ' ', @rule_args );           # include rule number
	}
	elsif ( $action eq 'replace' )
	{
		&zenlog( 'Error: Iptables \'replace\' action requires a rule number' );
	}

	# applied for any accepted action
	$rule =~ s/::ACTION_TAG::/$action/x;

	# error control
	if ( $rule =~ /::ACTION_TAG::/ )
	{
		&zlog( "Invalid action:$action (rulenum:$rulenum) in rule:$rule" );
	}

	return $rule;
}

sub getIptRuleNumber
{
	my (
		 $rule,         # rule string
		 $farm_name,    # farm name string
		 $index         # backend index number. OPTIONAL
	) = @_;

	# debugging
	( defined ( $rule ) && $rule ne '' )
	  or &zenlog( ( caller ( 0 ) )[3] . ' $rule invalid' );
	( defined ( $farm_name ) && !ref $farm_name )
	  or &zenlog( ( caller ( 0 ) )[3] . ' $farm_name invalid' );
	( defined ( $index ) && !ref $index )
	  or &zenlog( ( caller ( 0 ) )[3] . ' $index invalid' );

	my $rule_num;      # output: rule number for requested rule

	# read rule table and chain
	my @rule_args = split / +/, $rule;    # divide rule by blanks
	my $table     = $rule_args[2];        # second argument of iptables is the table
	my $chain     = $rule_args[4];        # forth argument of iptables is the chain

	my @server_line;
	my $filter;

	# Get the binary of iptables (iptables or ip6tables)
	my $iptables_bin = &getBinVersion( $farm_name );

	my $ipt_cmd =
	  "$iptables_bin --numeric --line-number --table $table --list $chain";

	# define filter with or without index paramenter
	if ( defined ( $index ) )
	{
		# get backend tag
		@server_line = &getL4FarmServers( $farm_name );

		#~ &zenlog("index:$index server_lines:@server_lines");
		@server_line = grep { /^$index;/ } @server_line;
		$filter = ( split ';', $server_line[0] )[3];
	}
	else
	{
		$filter = "FARM\_$farm_name\_";
	}

	## lock iptables use ##
	my $iptlock = &getGlobalConfiguration('iptlock');
	open my $ipt_lockfile, '>', $iptlock;
	&setIptLock( $ipt_lockfile );

	# pick rule by farm and optionally server id
	my @rules = grep { /$filter/ } `$ipt_cmd`;

	if ( !@rules && &debug() )
	{
		&zlog(
			"index:$index farm_name:$farm_name filter:$filter server:$server_line[0] server list:"
			  . &getFarmServers( $farm_name ) )
		  if not defined $filter;
		&zlog( "filter:$filter iptables command:$ipt_cmd" );
		&zlog( "rules:@rules" );
	}

	## unlock iptables use ##
	&setIptUnlock( $ipt_lockfile );
	close $ipt_lockfile;

	chomp ( @rules );

	# only for marking tags, when ip persistance is enabled
	if ( scalar @rules > 1 )
	{
		if ( $rule =~ /--match recent/ )    # for persistence rules
		{
			@rules = grep { /recent: CHECK/ } @rules;
		}
		else                                # for non persistence rules
		{
			@rules = grep { !/recent: CHECK/ } @rules;
		}
	}

	# take the first value (rule number)
	# e.g.: 1    DNAT       all  --  0.0.0.0/0 ...
	# if no rule was found: return -1
	if ( @rules )
	{
		$rule_num = ( split / +/, $rules[0] )[0];
	}
	else
	{
		$rule_num = -1;
	}

	# error control
	if ( $rule_num == -1 )
	{
		&zlog(
			"Invalid rule number:$rule_num for farm:$farm_name (backend:$index) with filter:$filter and rule:$rule"
		);
	}

	return $rule_num;
}

# apply every rule in the input
sub applyIptRules
{
	my @rules       = @_;    # input: rule array
	my $return_code = 0;     # output:

	foreach my $rule ( @rules )
	{
		# skip cycle if $rule empty
		next if not $rule or $rule !~ /ip6?tables/;

		$return_code = &runIptables( $rule );
		last if $return_code;
	}

	return $return_code;     # FIXME: make a proper return code control
}

sub setIptRuleCheck
{
	my $rule = shift;        # input: iptables rule string

	return &applyIptRules( &getIptRuleCheck( $rule ) );
}

sub getIptRuleCheck
{
	my $rule = shift;        # input: iptables rule string

	return &applyIptRuleAction( $rule, 'check' );
}

sub getIptRuleInsert
{
	my $farm     = shift;    # input: farm struc reference
	my $server   = shift;    # input: server struc reference
	my $rule     = shift;    # input: iptables rule string
	my $rule_num = shift;    # input(optional): possition to insert the rule

	my $farm_name = $$farm{ name };

	# Get the binary of iptables (iptables or ip6tables)
	my $iptables_bin = &getBinVersion( $farm_name );

	if ( ( not defined $rule_num ) || $rule_num eq '' )
	{
		# by default insert in 2nd position to skip CONNMARK rule if applies
		$rule_num = 2;

		# do not insert a rule on a position higher than this, iptable will fail
		my $rule_max_position;

		{    # calculate rule_max_position
			    # read rule table and chain
			my @rule_args = split / +/, $rule;
			my $table     = $rule_args[2];       # second argument of iptables is the table
			my $chain     = $rule_args[4];       # forth argument of iptables is the chain

			## lock iptables use ##
			my $iptlock = &getGlobalConfiguration('iptlock');
			open my $ipt_lockfile, '>', $iptlock;
			&setIptLock( $ipt_lockfile );

			my @rule_list = `$iptables_bin -n --line-number --table $table --list $chain`;

			## unlock iptables use ##
			&setIptUnlock( $ipt_lockfile );
			close $ipt_lockfile;

			$rule_max_position = ( scalar @rule_list ) - 1;

			if ( $table eq 'mangle' && $rule =~ /--match recent/ )
			{

				@rule_args = split / +/, $rule_list[-1];
				my $recent_rule_num = $rule_args[0];

				#~ $rule_num = $recent_rule_num if $recent_rule_num > $rule_num;
				$rule_num = $recent_rule_num;    #
			}
		}

		my $rulenum = $rule_max_position if $rule_max_position < $rule_num;
	}

	# if the rule does not exist
	if ( &setIptRuleCheck( $rule ) != 0 )        # 256
	{
		$rule = &applyIptRuleAction( $rule, 'insert', $rule_num );
		return $rule;
	}
	else                                         # if the rule exist replace it.
	{
		$rule = &setIptRuleReplace( $farm, $server, $rule );
	}

	return;    # do not return a rule if the rule already exist
}

sub setIptRuleDelete
{
	my $rule = shift;    # input: iptables rule string

	return &applyIptRules( &getIptRuleDelete( $rule ) );
}

sub getIptRuleDelete
{
	my $rule = shift;    # input: iptables rule string

	# some regex magic to extract farm name and backend index
	$rule =~ m/ FARM_(.+)_(.+)_ /;
	my $farm_name = $1;
	my $index     = $2;

	&zlog( "catched farm name:$farm_name and backend:$index for rule:$rule" )
	  if ( !defined $farm_name || !defined $index );

	my $rule_num = &getIptRuleNumber( $rule, $farm_name, $index );

	&zlog(
		"catched rule number:$rule_num farm name:$farm_name and backend:$index for rule:$rule"
	) if ( !defined $farm_name || !defined $index );

	# if the rule exist
	if ( $rule_num != -1 )
	{
		$rule = &applyIptRuleAction( $rule, 'delete', $rule_num );
	}
	else
	{
		&zenlog( "Delete: rule not found: $rule" );

	  #~ my @rule_args = split / +/, $rule;
	  #~ my $table     = $rule_args[2];       # second argument of iptables is the table
	  #~ my $chain     = $rule_args[4];       # forth argument of iptables is the chain
	}

	return $rule;
}

sub setIptRuleReplace    # $return_code ( \%farm, \%server, $rule)
{
	my $farm   = shift;    # input: farm struc reference
	my $server = shift;    # input: server struc reference
	my $rule   = shift;    # input: iptables rule string

	#~ &zlog();
	return &applyIptRules( &getIptRuleReplace( $farm, $server, $rule ) );
}

sub getIptRuleReplace      # $return_code ( \%farm, \%server, $rule)
{
	my $farm   = shift;    # input: farm struc reference
	my $server = shift;    # input: server struc reference
	my $rule   = shift;    # input: iptables rule string
	my $rule_num;          # position to insert the rule

	# if the rule exist
	$rule_num = &getIptRuleNumber( $rule, $$farm{ name }, $$server{ id } );

	return &applyIptRuleAction( $rule, 'replace', $rule_num );
}

sub setIptRuleAppend       # $return_code (\%farm, \%server, $rule)
{
	my $rule = shift;      # input: iptables rule string

	return &applyIptRules( &getIptRuleAppend( $rule ) );
}

sub getIptRuleAppend       # $return_code (\%farm, \%server, $rule)
{
	my $rule = shift;      # input: iptables rule string

	# if the rule does not exist
	#~ if ( &setIptRuleCheck( $rule ) != 0 )
	#~ {
	return &applyIptRuleAction( $rule, 'append' );

	#~ }

	#~ return;
}

sub getIptRulesStruct
{
	return {
			 t_mangle   => [],
			 t_nat      => [],
			 t_mangle_p => [],
			 t_snat     => [],
	};
}

# Get the binary of iptables (for IPv4 or IPv6)
sub getBinVersion    # ($farm_name)
{
	# Variables
	my $farm_name = shift;

	require Zevenet::Net::Validate;
	my $binary = &getGlobalConfiguration('iptables');
	my $vip = &getFarmVip( "vip", $farm_name );
	my $ipv = &ipversion( $vip );

	# Check the type of binary to use
	if ( $ipv == 4 )
	{
		$binary = &getGlobalConfiguration('iptables');
	}
	elsif ( $ipv == 6 )
	{
		$binary = &getGlobalConfiguration('ip6tables');
	}

	# Return $iptables or $ip6tables
	return $binary;
}

#lock iptables
sub setIptLock    # ($lockfile)
{
	my $ipt_lockfile = shift;
	require Zevenet::Debug;

	if ( flock ( $ipt_lockfile, LOCK_EX ) )
	{
		&zenlog( "Success locking IPTABLES" ) if &debug == 3;
	}
	else
	{
		&zenlog( "Cannot lock iptables: $!" );
	}
}

#unlock iptables
sub setIptUnlock    # ($lockfile)
{
	my $ipt_lockfile = shift;

	if ( flock ( $ipt_lockfile, LOCK_UN ) )
	{
		&zenlog( "Success unlocking IPTABLES" ) if &debug == 3;
	}
	else
	{
		&zenlog( "Cannot unlock iptables: $!" );
	}
}

# log and run the command string input parameter returning execution error code
sub iptSystem
{
	my $command = shift;    # command string to log and run
	my $return_code;

	my $program = ( split '/', $0 )[-1];
	$program = "$ENV{'SCRIPT_NAME'}" if $program eq '-e';
	$program .= ' ';

	## lock iptables use ##
	my $iptlock = &getGlobalConfiguration('iptlock');
	my $open_rc = open ( my $ipt_lockfile, '>', $iptlock );

	if ( $open_rc )
	{
		&setIptLock( $ipt_lockfile );
	}
	else
	{
		&zenlog( $program . "Cannot open $iptlock: $!" );
	}

	$return_code = system ( "$command >/dev/null 2>&1" );    # run

	## unlock iptables use ##
	if ( $open_rc )
	{
		&setIptUnlock( $ipt_lockfile );
		close $ipt_lockfile;
	}

	if ( $return_code )
	{
		if ( grep ( /--check/, $command ) || grep ( /-C /, $command ) )
		{
			&zenlog( $program . "Not found line: $command" )
			  if &debug == 2;    # show in logs if failed
		}
		else
		{
			&zenlog( $program . "failed: $command" );    # show in logs if failed
		}
	}

	# returning error code from execution
	return $return_code;
}

sub runIptables
{
	my $command = shift;    # command string to log and run

	my $checking = grep { /--check/ } $command;
	my $return_code = system ( "$command >/dev/null 2>&1" );

	if ( $return_code )
	{
		if ( $checking )
		{
			&zenlog( "Previous iptables line not found" ) if &debug > 1;
		}
		else
		{
			zenlog("return_code: $return_code rule: $command");

			for my $retry ( 1 .. 2 )
			{
				&zenlog( "Previous command failed! Retrying..." );
				$return_code = system ( "$command >/dev/null 2>&1" );
				zenlog("Retry ($retry) ... return_code: $return_code rule: $command");
				last unless $return_code;
			}
		}
	}

	# returning error code from execution
	return $return_code;
}

1;
