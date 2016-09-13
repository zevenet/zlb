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
sub getL4FarmsPorts($farmtype)
{
	my ( $farmtype ) = @_;

	my $first  = 1;
	my $fports = "";
	my @files  = &getFarmList();
	if ( $#files > -1 )
	{
		foreach $file ( @files )
		{
			my $fname  = &getFarmName( $file );
			my $ftype  = &getFarmType( $fname );
			my $fproto = &getFarmProto( $fname );
			if ( $ftype eq "l4xnat" && $fproto eq $farmtype )
			{
				my $fport = &getFarmVip( "vipp", $fname );
				if ( &validL4ExtPort( $fproto, $fport ) )
				{
					if ( $first == 1 )
					{
						$fports = $fport;
						$first  = 0;
					}
					else
					{
						$fports = "$fports,$fport";
					}
				}
			}
		}
	}
	return $fports;
}

#
sub loadL4Modules($vproto)
{
	my ( $vproto ) = @_;

	my $status = 0;
	my $fports = &getL4FarmsPorts( $vproto );
	if ( $vproto eq "sip" )
	{
		&removeNfModule( "nf_nat_sip",       "" );
		&removeNfModule( "nf_conntrack_sip", "" );
		&loadNfModule( "nf_conntrack_sip", "ports=$fports" );
		&loadNfModule( "nf_nat_sip",       "" );

		#$status = &ReloadNfModule("nf_conntrack_sip","ports=$fports");
	}
	elsif ( $vproto eq "ftp" )
	{
		&removeNfModule( "nf_nat_ftp",       "" );
		&removeNfModule( "nf_conntrack_ftp", "" );
		&loadNfModule( "nf_conntrack_ftp", "ports=$fports" );
		&loadNfModule( "nf_nat_ftp",       "" );

		#&loadNfModule("nf_nat_ftp","");
		#$status = &ReloadNfModule("nf_conntrack_ftp","ports=$fports");
	}
	elsif ( $vproto eq "tftp" )
	{
		&removeNfModule( "nf_nat_tftp",       "" );
		&removeNfModule( "nf_conntrack_tftp", "" );
		&loadNfModule( "nf_conntrack_tftp", "ports=$fports" );
		&loadNfModule( "nf_nat_tftp",       "" );

		#&loadNfModule("nf_nat_tftp","");
		#$status = &ReloadNfModule("nf_conntrack_tftp","ports=$fports");
	}
	return $status;
}

#
sub validL4ExtPort($fproto,$ports)
{
	my ( $fproto, $ports ) = @_;

	my $status = 0;
	if ( $fproto eq "sip" || $fproto eq "ftp" || $fproto eq "tftp" )
	{
		if ( $ports =~ /\d+/ || $ports =~ /((\d+),(\d+))+/ )
		{
			$status = 1;
		}
	}
	return $status;
}

#
sub runL4FarmRestart($fname,$writeconf,$type)
{
	my ( $fname, $writeconf, $type ) = @_;

	my $alg         = &getFarmAlgorithm( $fname );
	my $fbootstatus = &getFarmBootStatus( $fname );
	my $output      = 0;
	my $pidfile     = "/var/run/l4sd.pid";

	if ( $alg eq "leastconn" && $fbootstatus eq "up" && $writeconf eq "false" && $type eq "hot" && -e "$pidfile" )
	{
		open FILE, "<$pidfile";
		my $pid = <FILE>;
		close FILE;
		kill USR1, $pid;
		$output = $?;
	}
	else
	{
		&runFarmStop( $fname, $writeconf );
		$output = &runFarmStart( $fname, $writeconf );
	}

	return $output;
}

#
sub _runL4FarmRestart($fname,$writeconf,$type)
{
	my ( $fname, $writeconf, $type ) = @_;

	my $alg         = &getFarmAlgorithm( $fname );
	my $fbootstatus = &getFarmBootStatus( $fname );
	my $output      = 0;
	my $pidfile     = "/var/run/l4sd.pid";

	if ( $alg eq "leastconn" && $fbootstatus eq "up" && $writeconf eq "false" && $type eq "hot" && -e "$pidfile" )
	{
		open FILE, "<$pidfile";
		my $pid = <FILE>;
		close FILE;
		kill '-USR1', $pid;
		$output = $?;
	}
	else
	{
		&_runFarmStop( $fname, $writeconf );
		$output = &_runFarmStart( $fname, $writeconf );
	}

	return $output;
}

#
sub sendL4ConfChange($fname)
{
	my ( $fname ) = @_;

	my $alg         = &getFarmAlgorithm( $fname );
	my $fbootstatus = &getFarmBootStatus( $fname );
	my $output      = 0;
	my $pidfile     = "/var/run/l4sd.pid";

	if ( $alg eq "leastconn" && -e "$pidfile" )
	{
		open FILE, "<$pidfile";
		my $pid = <FILE>;
		close FILE;
		kill USR1, $pid;
		$output = $?;
	}
	else
	{
		&logfile( "Running L4 restart for $fname" );
		&_runL4FarmRestart( $fname, "false", "" );
	}

	return $output;
}

# do not remove this
1
