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

#get real ip from cluster on this host
sub clrip()
{
	use Sys::Hostname;
	my $host = hostname();
	open FR, "<$filecluster";
	my $lmembers = <FR>;
	close FR;

	my @lmembers = split ( ":", $lmembers );
	chomp ( @lmembers );
	my $lhost = @lmembers[1];
	my $lip   = @lmembers[2];
	my $rhost = @lmembers[3];
	my $rip   = @lmembers[4];

	if ( $host eq $lhost )
	{
		return $lip;
	}
	else
	{
		return $rip;
	}

}

#configure UP status on cluster file
sub clstatusUP()
{
	use Tie::File;
	tie @contents, 'Tie::File', "$filecluster";
	for ( @contents )
	{
		if ( $_ =~ /^TYPECLUSTER/ )
		{
			@clline = split ( ":", $_ );
			$_ = "@clline[0]:@clline[1]:UP";
		}
	}
	untie @contents;
}

#get cluster virtual ip
sub clvip()
{
	open FR, "<$filecluster";
	@clfile = <FR>;
	close FR;

	$lcluster = @clfile[1];
	chomp ( $lcluster );
	@lcluster = split ( ":", $lcluster );
	return @lcluster[1];
}

#is zeninotify running?
sub activenode()
{
	my @eject = `$pidof -x zeninotify.pl`;
	if ( @eject )
	{
		return "true";
	}
	else
	{
		return "false";
	}

}

#get data of cluster's members
sub getClusterMembersData($cllhost,$clfile)
{
	( $cllhost, $clfile ) = @_;
	my @output   = -1;
	my $line     = -1;
	my $cl_lhost = "";
	my $cl_lip   = "";
	my $cl_rhost = "";
	my $cl_rip   = "";

	open FR, "$clfile";
	foreach ( <FR> )
	{
		if ( $_ =~ /^MEMBERS/ )
		{
			$line = $_;
		}
	}
	close FR;
	my @cl_members = split ( ":", $line );
	if ( $cllhost eq @cl_members[1] )
	{
		$cl_lhost = @cl_members[1];
		$cl_lip   = @cl_members[2];
		$cl_rhost = @cl_members[3];
		$cl_rip   = @cl_members[4];
	}
	elsif ( $cllhost eq @cl_members[3] )
	{
		$cl_rhost = @cl_members[1];
		$cl_rip   = @cl_members[2];
		$cl_lhost = @cl_members[3];
		$cl_lip   = @cl_members[4];
	}
	elsif ( @cl_members[1] =~ /^$/ )
	{
		$cl_lhost = $cllhost;
	}
	chomp ( $cl_lhost );
	chomp ( $cl_rhost );
	chomp ( $cl_lip );
	chomp ( $cl_rip );
	if ( !$cl_lhost =~ /^$/ )
	{
		@output = ( $cl_lhost, $cl_lip, $cl_rhost, $cl_rip );
	}
	return @output;
}

#get data of cluster's Virtual IP
sub getClusterVIPData($clfile)
{
	( $clfile ) = @_;
	my @output = -1;
	my $line   = -1;
	open FR, "$clfile";
	foreach ( <FR> )
	{
		if ( $_ =~ /^IPCLUSTER/ )
		{
			$line = $_;
		}
	}
	close FR;
	my @cl_VIPdata = split ( ":", $line );
	my $cl_VIP     = @cl_VIPdata[1];
	my $cl_ifname  = "@cl_VIPdata[2]:@cl_VIPdata[3]";

	chomp ( $cl_ifname );
	chomp ( $cl_VIP );
	if ( !$cl_ifname =~ /^$/ )
	{
		@output = ( $cl_VIP, $cl_ifname );
	}

	return @output;
}

#get cluster type and cluster status
sub getClusterTypeStatus($clfile)
{
	( $clfile ) = @_;
	my @output = -1;
	my $line   = -1;
	open FR, "$clfile";
	foreach ( <FR> )
	{
		if ( $_ =~ /^TYPECLUSTER/ )
		{
			$line = $_;
		}
	}
	close FR;
	my @cl_typestatusdata = split ( ":", $line );
	my $cl_type           = @cl_typestatusdata[1];
	my $cl_status         = @cl_typestatusdata[2];
	chomp ( $cl_type );
	chomp ( $cl_status );
	if ( !$cl_type =~ /^$/ )
	{
		@output = ( $cl_type, $cl_status );
	}
	return @output;
}

#get cluster cable link
sub getClusterCableLink($clfile)
{
	( $clfile ) = @_;
	my $output = -1;
	my $line   = -1;
	open FR, "$clfile";
	foreach ( <FR> )
	{
		if ( $_ =~ /^CABLE/ )
		{
			$line = $_;
		}
	}
	close FR;
	my @cl_cabledata = split ( ":", $line );
	my $cl_cable = @cl_cabledata[1];
	chomp ( $cl_cable );
	if ( !$cl_cable =~ /^$/ )
	{
		$output = $cl_cable;
	}
	return $output;
}

#get cluster ID
sub getClusterID($clfile)
{
	( $clfile ) = @_;
	my $output = -1;
	my $line   = -1;
	open FR, "$clfile";
	foreach ( <FR> )
	{
		if ( $_ =~ /^IDCLUSTER/ )
		{
			$line = $_;
		}
	}
	close FR;
	my @cl_iddata = split ( ":", $line );
	my $cl_id = @cl_iddata[1];
	chomp ( $cl_id );
	if ( !$cl_id =~ /^$/ )
	{
		$output = $cl_id;
	}
	return $output;
}

#get cluster DEADRATIO
sub getClusterDEADRATIO($clfile)
{
	( $clfile ) = @_;
	my $output = -1;
	my $line   = -1;
	open FR, "$clfile";
	foreach ( <FR> )
	{
		if ( $_ =~ /^DEADRATIO/ )
		{
			$line = $_;
		}
	}
	close FR;
	my @cl_iddata = split ( ":", $line );
	my $cl_id = @cl_iddata[1];
	chomp ( $cl_id );
	if ( !$cl_id =~ /^$/ )
	{
		$output = $cl_id;
	}
	return $output;

}

#force local node failover
sub setLocalNodeForceFail()
{
	$piducarp = `pidof ucarp`;
	@eject    = system ( "kill -SIGUSR2 $piducarp" );
}

# do not remove this
1
