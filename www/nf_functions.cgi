###############################################################################
#
#     Zen Load Balancer Software License
#     This file is part of the Zen Load Balancer software package.
#
#     Copyright (C) 2014 SOFINTEL IT ENGINEERING SL, Sevilla (Spain)
#
#     This library is free software; you can redistribute it and/or modify it
#     under the terms of the GNU Lesser General Public License as published
#     by the Free Software Foundation; either version 2.1 of the License, or
#     (at your option) any later version.
#
#     This library is distributed in the hope that it will be useful, but
#     WITHOUT ANY WARRANTY; without even the implied warranty of
#     MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU Lesser
#     General Public License for more details.
#
#     You should have received a copy of the GNU Lesser General Public License
#     along with this library; if not, write to the Free Software Foundation,
#     Inc., 59 Temple Place, Suite 330, Boston, MA 02111-1307 USA
#
###############################################################################

#
sub loadNfModule($modname,$params)
{
	my ( $modname, $params ) = @_;

	my $status  = 0;
	my @modules = `$lsmod`;
	if ( !grep /^$modname /, @modules )
	{
		&logfile( "L4 loadNfModule: $modprobe $modname $params" );
		`$modprobe $modname $params`;
		$status = $?;
	}

	return $status;
}

#
sub removeNfModule($modname,$params)
{
	my ( $modname, $params ) = @_;

	my $status = 0;
	&logfile( "L4 removeNfModule: $modprobe -r $modname" );
	`$modprobe -r $modname`;
	$status = $?;

	return $status;
}

#
sub getIptFilter($type, $desc, @iptables)
{
	my ( $type, $desc, @iptables ) = @_;

	my $output;
	if ( $type eq "farm" )
	{
		@output = grep { / FARM\_$desc\_.* / } @iptables;
	}
	return @output;
}

#
sub getIptList($table,$chain)
{
	my ( $table, $chain ) = @_;

	my $ttable = $table;
	if ( $ttable ne "" )
	{
		$ttable = "-t $ttable";
	}
	my @iptables = `$iptables $ttable -L $chain -n -v --line-numbers`;

	return @iptables;
}

#
sub deleteIptRules($type,$desc,$table,$chain,@allrules)
{
	my ( $type, $desc, $table, $chain, @allrules ) = @_;

	my $status = 0;
	my @rules = &getIptFilter( $type, $desc, @allrules );

	# do not change rules id starting by the end
	@rules = reverse ( @rules );
	foreach my $rule ( @rules )
	{
		my @sprule = split ( "\ ", $rule );
		if ( $type eq "farm" )
		{
			&logfile( "deleteIptRules:: running '$iptables -t $table -D $chain @sprule[0]'" );
			my @run = `$iptables -t $table -D $chain @sprule[0]`;
			&logfile( "deleteIptRules:: delete netfilter rule '$rule'" );
			$status = $status + $?;
		}
	}

	return $status;
}

#
sub getNewMark($fname)
{
	my $found   = "false";
	my $marknum = 0x200;
	my $i;
	tie my @contents, 'Tie::File', "$fwmarksconf";
	for ( $i = 512 ; $i < 1024 && $found eq "false" ; $i++ )
	{
		my $num = sprintf ( "0x%x", $i );
		if ( !grep /^$num/, @contents )
		{
			$found   = "true";
			$marknum = $num;
		}
	}
	untie @contents;

	if ( $found = "true" )
	{
		open ( MARKSFILE, ">>$fwmarksconf" );
		print MARKSFILE "$marknum // FARM\_$fname\_\n";
		close MARKSFILE;
	}

	return $marknum;
}

#
sub delMarks($fname,$mark)
{
	my ( $fname, $mark ) = @_;

	my $status = 0;
	if ( $fname ne "" )
	{
		tie my @contents, 'Tie::File', "$fwmarksconf";
		@contents = grep !/ \/\/ FARM\_$fname\_$/, @contents;
		$status = $?;
		untie @contents;
	}

	if ( $mark ne "" )
	{
		tie my @contents, 'Tie::File', "$fwmarksconf";
		@contents = grep !/^$mark \/\//, @contents;
		$status = $?;
		untie @contents;
	}

	return $status;
}

#
sub renameMarks($fname,$newfname)
{
	my ( $fname, $newfname ) = @_;

	my $status = 0;
	if ( $fname ne "" )
	{
		tie my @contents, 'Tie::File', "$fwmarksconf";
		foreach $line ( @contents )
		{
			$line =~ s/ \/\/ FARM\_$fname\_/ \/\/ FARM\_$newfname\_/;
		}
		$status = $?;
		untie @contents;
	}

	return $status;
}

#
sub genIptMarkReturn($fname,$vip,$vport,$proto,$index,$state)
{
	my ( $fname, $vip, $vport, $proto, $index, $state ) = @_;

	my $rule;

	#	if ($state !~ /^up$/){
	#		return $rule;
	#	}

	$rule = "$iptables -t mangle -A PREROUTING -d $vip -p $proto -m multiport --dports $vport -j RETURN -m comment --comment ' FARM\_$fname\_$index\_ '";

	return $rule;

}

#
sub genIptMarkPersist($fname,$vip,$vport,$proto,$ttl,$index,$mark,$state)
{
	my ( $fname, $vip, $vport, $proto, $ttl, $index, $mark, $state ) = @_;

	my $rule;

	#	if ($state !~ /^up$/){
	#		return $rule;
	#	}

	my $layer = "";
	if ( $proto ne "all" )
	{
		$layer = "-p $proto -m multiport --dports $vport";
	}

	$rule = "$iptables -t mangle -A PREROUTING -m recent --name \"\_$fname\_$mark\_sessions\" --rcheck --seconds $ttl -d $vip $layer -j MARK --set-mark $mark -m comment --comment ' FARM\_$fname\_$index\_ '";

	return $rule;
}

#
sub genIptMark($fname,$nattype,$lbalg,$vip,$vport,$proto,$index,$mark,$value,$state,$prob)
{
	my ( $fname, $nattype, $lbalg, $vip, $vport, $proto, $index, $mark, $value, $state, $prob ) = @_;

	my $rule;

	my $layer = "";
	if ( $proto ne "all" )
	{
		$layer = "-p $proto -m multiport --dports $vport";
	}

	if ( $lbalg eq "weight" )
	{
		if ( $prob == 0 )
		{
			$prob = $value;
		}
		#~ &logfile("prob:$prob value:$value");
		#~ $prob = $value / $prob;
		$rule = "$iptables -t mangle -I PREROUTING -m statistic --mode random --probability $prob -d $vip $layer -j MARK --set-mark $mark -m comment --comment ' FARM\_$fname\_$index\_ '";
	}

	if ( $lbalg eq "leastconn" )
	{
		$rule = "$iptables -t mangle -I PREROUTING -m condition --condition '\_$fname\_$mark\_' -d $vip $layer -j MARK --set-mark $mark -m comment --comment ' FARM\_$fname\_$index\_ '";
	}

	if ( $lbalg eq "prio" )
	{
		$rule = "$iptables -t mangle -I PREROUTING -d $vip $layer -j MARK --set-mark $mark -m comment --comment ' FARM\_$fname\_$index\_ '";
	}

	return $rule;
}

#
sub genIptRedirect($fname,$nattype,$index,$rip,$proto,$mark,$value,$persist,$state)
{
	my ( $fname, $nattype, $index, $rip, $proto, $mark, $value, $persist, $state ) = @_;

	my $rule;

	my $layer = "";
	if ( $proto ne "all" )
	{
		$layer = "-p $proto";
	}

	if ( $persist ne "none" )
	{
		$persist = "-m recent --name \"\_$fname\_$mark\_sessions\" --set";
	}
	else
	{
		$persist = "";
	}

	$rule = "$iptables -t nat -A PREROUTING -m mark --mark $mark -j DNAT $layer --to-destination $rip $persist -m comment --comment ' FARM\_$fname\_$index\_ '";

	return $rule;
}

#
sub genIptSourceNat($fname,$vip,$nattype,$index,$proto,$mark,$state)
{
	my ( $fname, $vip, $nattype, $index, $proto, $mark, $state ) = @_;

	my $rule;

	#	if ($state !~ /^up$/){
	#		return $rule;
	#	}

	my $layer = "";
	if ( $proto ne "all" )
	{
		$layer = "-p $proto";
	}

	$rule = "$iptables -t nat -A POSTROUTING -m mark --mark $mark -j SNAT $layer --to-source $vip -m comment --comment ' FARM\_$fname\_$index\_ '";

	return $rule;
}

#
sub genIptMasquerade($fname,$nattype,$index,$proto,$mark,$state)
{
	my ( $fname, $nattype, $index, $proto, $mark, $state ) = @_;

	my $rule;

	#	if ($state !~ /^up$/){
	#		return $rule;
	#	}

	my $layer = "";
	if ( $proto ne "all" )
	{
		$layer = "-p $proto";
	}

	$rule = "$iptables -t nat -A POSTROUTING -m mark --mark $mark -j MASQUERADE $layer -m comment --comment ' FARM\_$fname\_$index\_ '";

	return $rule;
}

# do not remove this
1
