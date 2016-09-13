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

use Net::SSH qw(ssh sshopen2);
use Net::SSH::Expect;
use Sys::Hostname;

my $host = hostname();

print "
    <!--Content INI-->
        <div id=\"page-content\">

                <!--Content Header INI-->
                        <h2>Settings::Cluster</h2>
                <!--Content Header END-->
";

if ( $action =~ /Cancel/ )
{
	unlink ( $filecluster );
	undef ( $vipcl );
}

#action save
if ( $action eq "Save" || $action eq "Save VIP" || $action eq "Configure cluster type" )
{

	#create new configuration cluster file
	open FO, "> $filecluster";
	print FO "MEMBERS\:$lhost\:$lip\:$rhost\:$rip\n";
	print FO "IPCLUSTER\:$vipcl:$ifname\n";
	print FO "TYPECLUSTER\:$typecl\n";
	print FO "CABLE\:$cable\n";
	print FO "IDCLUSTER\:$idcluster\n";
	print FO "DEADRATIO\:$deadratio\n";
	close FO;
}

#if ($vipcl =~ /Disabled/ || $typecl =~ /Disabled/)
#        {
#my @eject = `pkill -9f zeninotify.pl`;
#my @eject = `/etc/init.d/zenloadbalancer stop`;
#if ($? == 0)
#        {
#        &successmsg("Zen Inotify stopped on local")
#        }
#
#my @eject = `pkill -9 ucarp`;
#if ($? == 0)
#	{
#	&successmsg("Zen Ucarp stopped on local")
#	}
#	&successmsg("Stopping cluster service on localhost");
#	my @eject = `pkill -9
#	#my @eject = `/etc/init.d/zenloadbalancer stop`;
#        unlink($filecluster);
#	$vipcl="";
#	&successmsg("Cluster service stopped  on this host, please, now connect to GUI remote host  and stop cluster service");
#        }

if ( -e $filecluster )
{

	#get cluster's members data
	@clmembers = &getClusterMembersData( $host, $filecluster );
	$lhost = @clmembers[0];
	if ( @clmembers[1] !~ /^$/ )
	{
		$lip = @clmembers[1];
	}
	if ( @clmembers[2] !~ /^$/ )
	{
		$rhost = @clmembers[2];
	}
	if ( @clmembers[3] !~ /^$/ )
	{
		$rip = @clmembers[3];
	}

	#get cluster's VIP data
	@clvipdata = &getClusterVIPData( $filecluster );
	if ( @clvipdata ne -1 )
	{
		$vipcl  = @clvipdata[0];
		$ifname = @clvipdata[1];
	}
	elsif ( !$vipcl =~ /^$/ )
	{
		@clvipdata = split ( ":", $vipcl );
		if ( @clvipdata[1] !~ /^$/ && @clvipdata[2] !~ /^$/ )
		{
			$ifname = "@clvipdata[1]:@clvipdata[2]";
		}
		$vipcl = @clvipdata[0];
	}

	#get cluster's type and status
	@cltypestatus = &getClusterTypeStatus( $filecluster );
	if ( @cltypestatus ne -1 )
	{
		$typecl   = @cltypestatus[0];
		$clstatus = @cltypestatus[1];
	}

	#get cluster's cable link data
	$cable = &getClusterCableLink( $filecluster );

	#get cluster's ID
	$idcluster = &getClusterID( $filecluster );
	if ( $idcluster eq -1 )
	{
		$idcluster = 1;
	}

	#get cluster's DEADRATIO
	$deadratio = &getClusterDEADRATIO( $filecluster );
	if ( $deadratio eq -1 )
	{
		$deadratio = 2;
	}

	#action sync cluster
	if ( $action eq "Force sync cluster from master to backup" )
	{
		open FT, ">$configdir/sync_cl";
		close FT;
		sleep ( 2 );
		unlink ( "$configdir/sync_cl" );
		&successmsg( "Cluster synced manually" );
	}

	#action Test failover
	if ( $action eq "Test failover" )
	{
		setLocalNodeForceFail();
	}

	if ( $action eq "Force node as backup for maintenance" )
	{
		if ( $cable eq "Crossover cord" )
		{
			$ignoreifstate = "--ignoreifstate";
		}
		else
		{
			$ignoreifstate = "";
		}
		@rifname = split ( ":", $ifname );
		@eject = system ( "pkill -9 ucarp" );
		sleep ( 5 );
		&successmsg( "Demoting the node to backup for maintenance, please wait and don't stop the process" );
		&logfile( "$ucarp $ignoreifstate -r $deadratio --interface=@rifname[0] --srcip=$lip --vhid=$idcluster --pass=secret --addr=$vipcl -k 100 --upscript=/usr/local/zenloadbalancer/app/zenlatency/zenlatency-start.pl --downscript=/usr/local/zenloadbalancer/app/zenlatency/zenlatency-stop.pl -B -f local6" );
		@eject = system ( "$ucarp $ignoreifstate -r $deadratio --interface=@rifname[0] --srcip=$lip --vhid=$idcluster --pass=secret --addr=$vipcl -k 100 --upscript=/usr/local/zenloadbalancer/app/zenlatency/zenlatency-start.pl --downscript=/usr/local/zenloadbalancer/app/zenlatency/zenlatency-stop.pl -B -f local6" );
		sleep ( 10 );
	}

	if ( $action eq "Return node from maintenance" )
	{
		if ( $cable eq "Crossover cord" )
		{
			$ignoreifstate = "--ignoreifstate";
		}
		else
		{
			$ignoreifstate = "";
		}
		@rifname = split ( ":", $ifname );
		@eject = system ( "pkill -9 ucarp" );
		sleep ( 5 );
		&successmsg( "Returning the node from maintenance, please wait and not stop the process" );
		if ( $typecl =~ /^equal$/ )
		{
			&logfile( "$ucarp $ignoreifstate -r $deadratio --interface=@rifname[0] --srcip=$lip --vhid=$idcluster --pass=secret --addr=$vipcl --upscript=/usr/local/zenloadbalancer/app/zenlatency/zenlatency-start.pl --downscript=/usr/local/zenloadbalancer/app/zenlatency/zenlatency-stop.pl -B -f local6" );
			my @eject = system ( "$ucarp $ignoreifstate -r $deadratio --interface=@rifname[0] --srcip=$lip --vhid=$idcluster --pass=secret --addr=$vipcl --upscript=/usr/local/zenloadbalancer/app/zenlatency/zenlatency-start.pl --downscript=/usr/local/zenloadbalancer/app/zenlatency/zenlatency-stop.pl -B -f local6" );
		}
		elsif ( $typecl =~ /$lhost-$rhost/ )
		{
			&logfile( "$ucarp $ignoreifstate -r $deadratio --interface=@rifname[0] --srcip=$lip -P --vhid=$idcluster --pass=secret --addr=$vipcl --upscript=/usr/local/zenloadbalancer/app/zenlatency/zenlatency-start.pl --downscript=/usr/local/zenloadbalancer/app/zenlatency/zenlatency-stop.pl -B -f local6" );
			my @eject = system ( "$ucarp $ignoreifstate -r $deadratio --interface=@rifname[0] --srcip=$lip -P --vhid=$idcluster --pass=secret --addr=$vipcl --upscript=/usr/local/zenloadbalancer/app/zenlatency/zenlatency-start.pl --downscript=/usr/local/zenloadbalancer/app/zenlatency/zenlatency-stop.pl -B -f local6" );
		}
		else
		{
			&logfile( "$ucarp $ignoreifstate -r $deadratio --interface=@rifname[0] -k 50 --srcip=$lip --vhid=$idcluster --pass=secret --addr=$vipcl --upscript=/usr/local/zenloadbalancer/app/zenlatency/zenlatency-start.pl --downscript=/usr/local/zenloadbalancer/app/zenlatency/zenlatency-stop.pl -B -f local6" );
			my $eject = system ( "$ucarp $ignoreifstate -r $deadratio --interface=@rifname[0] -k 50 --srcip=$lip --vhid=$idcluster --pass=secret --addr=$vipcl --upscript=/usr/local/zenloadbalancer/app/zenlatency/zenlatency-start.pl --downscript=/usr/local/zenloadbalancer/app/zenlatency/zenlatency-stop.pl -B -f local6" );
		}
		sleep ( 10 );
	}

	#action test rsa
	if ( $action eq "Test RSA connections" && $lhost && $rhost && $lip && $rip )
	{
		chomp ( $rip );
		$user = "root";

		#sshopen2("root\@$rip", *READER, *WRITER, "ls") || die "ssh: $!";
		@eject = `$ssh -o \"ConnectTimeout=10\" -o \"StrictHostKeyChecking=no\" root\@$rip \'$pen_bin\' 2>&1 `;

		#@eject = system("ssh root\@$rip 'touch /tmp/kk' 2>&1 ");
		if ( $? == 0 )
		{
			&successmsg( "RSA connection from $lhost ($lip) to $rhost ($rip) is OK" );
		}
		else
		{
			&errormsg( "RSA connection from $lhost ($lip) to $rhost ($rip) not works" );
		}

	}

	#action configure connection
	if ( $action eq "Configure RSA connection between nodes" && $lhost !~ /^\$/ && $lip !~ /^$/ && $rhost !~ /^$/ && $rip !~ /^\$/ && $vipcl !~ /^$/ )
	{
		###########################################
		#my $user = "root";
		#my $host = "$rip";
		chomp ( $rip );
		chomp ( $pass );

		# 1) create ssh object
		my $ssh = Net::SSH::Expect->new(
			host                         => "$rip",
			user                         => 'root',
			password                     => "$pass",
			raw_pty                      => 1,
			restart_timeout_upon_receive => 1
		);
		eval {

			# 2) logon to the SSH server using those credentials.
			# test the login output to make sure we had success
			$ssh->run_ssh() or die "SSH process couldn't start: $!";
			my $eject = $ssh->peek( 5 );
			if ( $eject =~ /yes/ )
			{
				$ssh->read_all();
				$ssh->send( "yes" );
			}
			my $sshstat = $ssh->waitfor( 'password', 10 );
			my $sshpasswrong = "false";
			if ( $sshstat eq 1 )
			{
				$ssh->read_all();
				$ssh->send( $pass );
				$sshstat = $ssh->waitfor( 'password', 10 );
				if ( $sshstat eq 1 )
				{
					$ssh->read_all();
					$sshpasswrong = "true";
				}
				else
				{
					$ssh->read_all();
				}
			}
			else
			{
				$ssh->read_all();

				#There were an old RSA communication, we have to delete it
				my $eject = $ssh->exec( "rm -f /root/.ssh/authorized_keys" );
			}
			$error = "false";
			if ( $sshstat eq 1 )
			{
				if ( $sshpasswrong eq "true" )
				{
					&errormsg( "Login on $rhost ($rip) has failed, wrong password could be a cause..." );
				}
				else
				{
					&errormsg( "Login on $rhost ($rip) has failed, timeout on ssh connection could be a cause..." );
				}
				$error = "true";
			}
			else
			{

				#Check if can exec commands through ssh
				my $checkcommand = "date > /dev/null";
				$ssh->send( $checkcommand );    # using send() instead of exec()
				my $line;
				my $ind = 0;
				my @sshoutput;
				while ( defined ( $line = $ssh->read_line() ) )
				{
					@sshoutput[$ind] = $line;
					$ind++;
				}

				#The first line is the command echoed
				#The second line is stderr output
				$ssh->read_all();               #There is the prompt in the input stream, we remove it
				@sshoutput[1] =~ s/^\s+//;
				@sshoutput[1] =~ s/\s+$//;
				if ( @sshoutput[1] !~ /^$/ )
				{
					&errormsg( "Login on $rhost ($rip) ok, but can not execute commands" );
					$error = "true";
				}
			}
		};
		$err_out = $@;
		if ( $err_out =~ /^$/ && $error eq "false" )
		{
			&successmsg( "Running process for configure RSA comunication" );
			&logfile( "Deleting old RSA key on $lhost ($lip)" );
			unlink glob ( "/root/.ssh/id_rsa*" );
			&logfile( "Creating new RSA keys on $lhost ($lip)" );
			@eject = `$sshkeygen -t rsa -f /root/.ssh/id_rsa -N \"\"`;
			open FR, "/root/.ssh/id_rsa.pub";
			while ( <FR> )
			{
				$rsa_pass = $_;
			}
			chomp ( $rsa_pass );
			close FR;

			# - now you know you're logged in - #
			# run command
			&logfile( "Copying new RSA key from $lhost ($lip) to $rhost ($rip)" );
			my $eject = $ssh->exec( "rm -f /root/.ssh/authorized_keys; mkdir -p /root/.ssh/; echo $rsa_pass \>\> /root/.ssh/authorized_keys" );

			$ssh->read_all();    #Clean the ssh buffer
			my $rhostname = $ssh->exec( "hostname" );
			@rhostname = split ( "\ ", $rhostname );
			$rhostname = @rhostname[0];
			chomp ( $rhostname );
			@ifcl = split ( ":", $ifname );
			$ifcl = @ifcl[0];
			my $ripeth0 = $ssh->exec( "ip addr show $ifcl | grep $ifcl\$ | cut -d'/' -f1 | sed  's/\ //g' | sed 's/inet//g' " );
			@ripeth0 = split ( "\ ", $ripeth0 );
			$ripeth0 = @ripeth0[0];
			chomp ( $ripeth0 );

			$modified = "false";
			if ( $rhostname ne $rhost )
			{
				$rhost = $rhostname;
				&errormsg( "Remote hostname is not OK, modified to $rhostname" );
				$modified = "true";
			}

			if ( $ripeth0 ne $rip )
			{
				$rip = $ripeth0;
				&errormsg( "Remote ip on eth0 is not OK, modified to $ripeth0" );
				$modified = "true";
			}

			if ( $modified eq "true" )
			{
				open FO, "> $filecluster";
				print FO "MEMBERS\:$lhost\:$lip\:$rhost\:$rip\n";
				print FO "IPCLUSTER\:$vipcl\:$ifname\n";
				print FO "CABLE\:$cable\n";
				close FO;
			}

			# closes the ssh connection
			$ssh->close();

			#connect to remote host without password
			my $user = "root";
			my $host = "$rip";
			chomp ( $rip );
			$hosts = "$user\@$rip";
			chomp ( $hosts );

			#deleting remote id_rsa key
			&logfile( "Deleting old RSA key on $rhost" );
			ssh( $hosts, "rm -rf /root/.ssh/id_rsa*" );

			#creating new remote id_rsa key
			&logfile( "Creating new remote RSA key on $rhost" );
			ssh( $hosts, "$sshkeygen -t rsa -f /root/.ssh/id_rsa -N \"\" &> /dev/null" );

			#copying id_rsa remote key to local
			&logfile( "Copying new RSA key from $rhost to $lhost" );
			@eject = `$scp $hosts:/root/.ssh/id_rsa.pub /tmp/`;

			#open file
			use File::Copy;
			move( "/tmp/id_rsa.pub", "/root/.ssh/authorized_keys" );

			#open file and copy to other
			&logfile( "Enabled RSA communication between cluster hosts" );
			&successmsg( "Enabled RSA communication between cluster hosts" );

			#run zeninotify for syncronization directories
		}
		else
		{
			&errormsg( "RSA communication with $rhost ($rip) has failed..." );
			$ssh->close();
		}
	}

	#action configure cluster ucarp
	if ( $action eq "Configure cluster type" && $typecl !~ /^$/ )
	{

		if ( $cable eq "Crossover cord" )
		{
			$ignoreifstate = "--ignoreifstate";
		}
		else
		{
			$ignoreifstate = "";
		}
		@ifname = split ( ":", $ifname );
		@eject = `$ssh -o \"ConnectTimeout=10\" -o \"StrictHostKeyChecking=no\" root\@$rip \'$pen_bin\' 2>&1 `;
		if ( $? == 0 )
		{

			#remote execution
			my $ssh = Net::SSH::Expect->new(
				host    => "$rip",
				user    => 'root',
				raw_pty => 1
			);

			#local execution
			$ssh->run_ssh() or die "SSH process couldn't start: $!";
			my $eject = $ssh->exec( "pkill -9 ucarp" );
			chomp ( $rip );
			$user = "root";
			my @eject = `pkill -9 ucarp`;

			#set cluster to UP on cluster file
			&clstatusUP();
			&logfile( "Sending $filecluster to $rip" );
			my @eject = `$scp $filecluster root\@$rip\:$filecluster`;

			if ( $typecl =~ /^equal$/ )
			{
				&successmsg( "Running Zen latency Service and Zen inotify Service, please wait and not stop the process" );
				&logfile( "running on local: $ucarp -r $deadratio $ignoreifstate --interface=@ifname[0] --srcip=$lip --vhid=$idcluster --pass=secret --addr=$vipcl --upscript=/usr/local/zenloadbalancer/app/zenlatency/zenlatency-start.pl --downscript=/usr/local/zenloadbalancer/app/zenlatency/zenlatency-stop.pl -B -f local6" );
				my @eject = system ( "$ucarp -r $deadratio $ignoreifstate --interface=@ifname[0] --srcip=$lip --vhid=$idcluster --pass=secret --addr=$vipcl --upscript=/usr/local/zenloadbalancer/app/zenlatency/zenlatency-start.pl --downscript=/usr/local/zenloadbalancer/app/zenlatency/zenlatency-stop.pl -B -f local6" );
				sleep ( 10 );
				&logfile( "running on remote: $ucarp -r $deadratio $ignoreifstate --interface=@ifname[0] --srcip=$rip --vhid=$idcluster --pass=secret --addr=$vipcl --upscript=/usr/local/zenloadbalancer/app/zenlatency/zenlatency-start.pl --downscript=/usr/local/zenloadbalancer/app/zenlatency/zenlatency-stop.pl -B -f local6" );
				my $eject = $ssh->exec( "$ucarp -r $deadratio $ignoreifstate --interface=@ifname[0] --srcip=$rip --vhid=$idcluster --pass=secret --addr=$vipcl --upscript=/usr/local/zenloadbalancer/app/zenlatency/zenlatency-start.pl --downscript=/usr/local/zenloadbalancer/app/zenlatency/zenlatency-stop.pl -B -f local6" );
				sleep ( 10 );
				&successmsg( "Cluster configured on mode $lhost or $rhost can be masters" );
				&successmsg( "Reload here <a href=\"index.cgi?id=$id\"><img src=\"img/icons/small/arrow_refresh.png\"></a> to apply changes" );
			}
			if ( $typecl =~ /$lhost-$rhost/ )
			{
				&successmsg( "Running Zen latency Service and Zen inotify Service, please wait" );
				my @eject = system ( "$ucarp -r $deadratio $ignoreifstate --interface=@ifname[0] --srcip=$lip -P --vhid=$idcluster --pass=secret --addr=$vipcl --upscript=/usr/local/zenloadbalancer/app/zenlatency/zenlatency-start.pl --downscript=/usr/local/zenloadbalancer/app/zenlatency/zenlatency-stop.pl -B -f local6" );
				sleep ( 5 );
				my $eject = $ssh->exec( "$ucarp -r $deadratio $ignoreifstate --interface=@ifname[0] -k 50 --srcip=$rip --vhid=$idcluster --pass=secret --addr=$vipcl --upscript=/usr/local/zenloadbalancer/app/zenlatency/zenlatency-start.pl --downscript=/usr/local/zenloadbalancer/app/zenlatency/zenlatency-stop.pl -B -f local6" );
				sleep ( 10 );
				&successmsg( "Cluster configured on mode $lhost master and $rhost backup automatic failover" );
				&successmsg( "Reload here <a href=\"index.cgi?id=$id\"><img src=\"img/icons/small/arrow_refresh.png\"></a> to apply changes" );
			}

			if ( $typecl =~ /Disabled/ )
			{
				&successmsg( "Disabling Zen latency Service and Zen inotify Service, please wait" );
				my $eject = $ssh->exec( "pkill -9f zeninotify.pl" );
				my @eject = `pkill -9f zeninotify.pl`;
				my $eject = $ssh->exec( "pkill -9 ucarp" );
				my @eject = `pkill -9 ucarp`;
				unlink ( $filecluster );
				my $eject = $ssh->exec( "rm $filecluster" );
				my $eject = $ssh->exec( "rm -f /root/.ssh/authorized_keys" );
				my $eject = `rm -rf /root/.ssh/authorized_keys`;
				&successmsg( "Cluster disabled on $lhost and $rhost" );
				undef $rhost;
				undef $lhost;
				undef $vipcl;
				undef $rip;
				undef $lip;
				undef $clstatus;
			}
			$ssh->close();
		}
		else
		{
			if ( $typecl =~ /Disabled/ )
			{
				&successmsg( "Disabling Zen latency Service and Zen inotify Service, please wait" );

				#remote execution
				my $ssh = Net::SSH::Expect->new(
					host    => "$rip",
					user    => 'root',
					raw_pty => 1
				);

				#local execution
				$ssh->run_ssh() or die "SSH process couldn't start: $!";

				my $eject = $ssh->exec( "pkill -9f zeninotify.pl" );
				$ssh->close();
				my @eject = `pkill -9f zeninotify.pl`;
				unlink ( $filecluster );
				my $eject = $ssh->exec( "rm $filecluster" );
				&successmsg( "Cluster disabled on $lhost and $rhost" );
				undef $rhost;
				undef $lhost;
				undef $vipcl;
				undef $rip;
				undef $lip;
				undef $clstatus;
			}
			else
			{
				&errormsg( "Error connecting between $lip and $rip, please configure the RSA connectiong first" );
			}
		}
	}

}

print " <div class=\"container_12\">
       <div class=\"grid_12\">
       <div class=\"box-header\"> Cluster configuration </div>
       <div class=\"box stats\">
	";

opendir ( DIR, "$configdir" );
@files = grep ( /^if.*\:.*$/, readdir ( DIR ) );
closedir ( DIR );

#vip cluster form

#cluster information

print "<b>Cluster status <a href=\"index.cgi?id=$id\"><img src=\"img/icons/small/arrow_refresh.png\" title=\"Refresh\"></a>:</b><br>";

print "<div id=\"page-header\"></div>";
$error = "false";

#if (($rhost && $lhost && $rip && $lip && $rip && $vipcl)){
if ( ( $rhost && $lhost && $rip && $lip && $rip && $vipcl && $clstatus ) )
{

	#zenlatency is running on local:
	my @ucarppidl = `$pidof -x ucarp`;
	print "Zen latency ";
	if ( @ucarppidl[0] =~ /^[0-9]/ )
	{
		print "is <b>UP</b>\n";
	}
	else
	{
		print "is <b>DOWN</b>\n";
		$error = "true";
	}
	print "on <b>$lhost $lip</b>";

	print " | ";

	#zenlatency is running on remote?:
	my @ucarppidr = `ssh -o \"ConnectTimeout=10\" -o \"StrictHostKeyChecking=no\" root\@$rip \"pidof -x ucarp \" 2>&1`;
	print "Zen latency ";
	if ( @ucarppidr[0] =~ /^[0-9]/ )
	{
		print "is <b>UP</b>\n";
	}
	else
	{
		print "is <b>DOWN</b>\n";
		$error = "true";
	}
	print "on <b>$rhost $rip</b>";

	if ( $error eq "false" )
	{
		print " <img src=\"/img/icons/small/accept.png\">";
	}
	else
	{
		print " <img src=\"/img/icons/small/exclamation.png\">";
	}

	print "<br>";

	$vipclrun  = "false";
	$vipclrun2 = "false";
	$activecl  = "false";
	my @vipwhereis = `$ip_bin addr list`;
	if ( grep ( /$vipcl/, @vipwhereis ) )
	{
		$vipclrun = $lhost;
		print "Cluster IP <b>$vipcl</b> is active on <b>$vipclrun</b> ";
		$activecl = $lhost;
	}

	my @vipwhereis2 = `ssh -o \"ConnectTimeout=10\" -o \"StrictHostKeyChecking=no\" root\@$rip \"$ip_bin addr list\" 2>/dev/null`;
	if ( grep ( /$vipcl\//, @vipwhereis2 ) )
	{
		$vipclrun2 = $rhost;
		print "Cluster is active on $vipclrun2</b>";
		$activecl = $rhost;
	}

	if ( ( $vipclrun eq "false" && $vipclrun2 eq "false" ) || ( $vipclrun ne "false" && $vipclrun2 ne "false" ) )
	{
		print " <img src=\"/img/icons/small/exclamation.png\">";
		$activecl = "false";
		$error    = "true";
	}
	else
	{
		print " <img src=\"/img/icons/small/accept.png\">";
	}

	print "<br>";

	#where is zeninotify
	my @zeninopidl = `$pidof -x zeninotify.pl`;
	print "Zen Inotify is running on ";
	$zeninorun  = "false";
	$zeninorun2 = "false";
	$activeino  = "false";
	$activeino1 = "false";
	$activeino2 = "false";
	if ( @zeninopidl[0] =~ /^[0-9]/ )
	{
		print "<b>$lhost</b>\n";
		$zeninorun  = "true";
		$activeino  = $lhost;
		$activeino1 = $lhost;
	}

	my @zeninopidr = `ssh -o \"ConnectTimeout=10\" -o \"StrictHostKeyChecking=no\" root\@$rip "pidof -x zeninotify.pl " 2>/dev/null `;
	if ( @zeninopidr[0] =~ /^[0-9]/ )
	{
		print "<b>$rhost</b>\n";
		$zeninorun  = "true";
		$activeino  = $rhost;
		$activeino2 = $rhost;
	}

	if ( $activeino2 ne "false" && $activeino1 ne "false" )
	{

		#print "<b>$rhost and $lhost</b>\n";
		$zeninorun = "false";
	}

	if ( @zeninopidr[0] =~ /^[0-9]/ && @zeninopidl[0] =~ /^[0-9]/ )
	{
		$error = "true";
	}
	if ( ( $zeninorun eq "false" && $zeninorun2 eq "false" ) || ( $zeninorun ne "false" && $zeninorun2 ne "false" ) )
	{
		print " <img src=\"/img/icons/small/exclamation.png\">";
		$activeino = "false";
		$error     = "true";
	}
	else
	{
		if ( $activeino eq $activecl )
		{
			print " <img src=\"/img/icons/small/accept.png\">";
		}
		else
		{
			print " <img src=\"/img/icons/small/exclamation.png\">";
			$error = "true";
		}
	}

}
else
{
	print "Cluster not configured!";
	$error = "true";
}

print "<br><b>Global status:</b>";
if ( $error eq "false" )
{
	print " <img src=\"/img/icons/small/accept.png\">";
	if ( &activenode() eq "true" )
	{
		print "<br><br>";

		#form form manual sync on cluster
		print "<form method=\"get\" action=\"index.cgi\">";
		print "<input type=\"submit\" value=\"Force sync cluster from master to backup\" name=\"action\" class=\"button small\">";
		print "<input type=\"hidden\" name=\"id\" value=\"$id\">";
		print "</form>";

	}

}
else
{
	print " <img src=\"/img/icons/small/exclamation.png\">";
}

print "<br>";
print "<div id=\"page-header\"></div>";

#cluster form

if ( $error eq "true" )
{

	print "<form method=\"get\" action=\"index.cgi\">";
	print "<b>Virtual IP for Cluster, or create new virtual <a href=\"index.cgi?id=3-2\">here</a>.</b> <font size=\"1\">*Virtual ips with status up are listed only</font>";
	print "<br>";
	print "<select name=\"vipcl\">\n";

	#print "<option value=\"Disabled\">--Disabled--</option>";
	#files with vip interface:
	#search virtual active interfaces.

	foreach $file ( @files )
	{
		open FINT, "$configdir\/$file";
		while ( <FINT> )
		{
			@data = split ( ":", $_ );
			chomp ( $vipcl );
			chomp ( @data[2] );
			if ( $vipcl eq @data[2] )
			{
				print "<option value=\"@data[2]:@data[0]:@data[1]\" selected=\"selected\">@data[0]:@data[1] @data[2]</option>";
			}
			else
			{
				print "<option value=\"@data[2]:@data[0]:@data[1]\">@data[0]:@data[1] @data[2]</option>";
			}
		}
		close FINT;
	}
	print "</select>";
	print "<input type=\"hidden\" name=\"id\" value=\"$id\">";
	print "<br>";
	print "<br>";
	print "<input type=\"submit\" value=\"Save VIP\" name=\"action\" class=\"button small\">";
	print "</form>";
	print "<br>";

	#locate real interface for vipcl
	opendir ( DIR, "$configdir" );
	@files = grep ( /^if.*\:.*$/, readdir ( DIR ) );
	closedir ( DIR );
	foreach $file ( @files )
	{
		open FINT, "$configdir\/$file";
		while ( <FINT> )
		{
			@line = split ( ":", $_ );
			if ( @line[2] eq $vipcl )
			{
				$ifnamet = @line[0];

				#$tips=&listactiveips();
				@totalips = split ( "\ ", &listactiveips() );
				foreach $tips ( @totalips )
				{
					if ( $tips =~ /^$ifnamet\-/ )
					{
						@iface = split ( "\-\>", $tips );
						$iface = @iface[0];
						chomp ( $ifnamet );
						if ( $lip =~ /^$/ )
						{
							$lip = @iface[1];
							chomp ( $lip );
						}
					}

				}

			}
		}

		close FINT;
	}

	if ( $lhost =~ /^$/ )
	{
		$lhost = hostname();
	}
	if ( $vipcl !~ /^$/ )
	{
		print "<form method=\"get\" action=\"index.cgi\">";
		print "<b>Local hostname.</b>";
		print "<br>";
		print " <input type=\"text\" name=\"lhost\" value=\"$lhost\" size=12>";
		print "<b> $iface IP</b>";
		print " <input type=\"text\" name=\"lip\" value=\"$lip\" size=12>";
		print "<br>";
		print "<br>";

		#
		print "<b>Remote hostname.</b>";
		print "<br>";
		print " <input type=\"text\" name=\"rhost\" value=\"$rhost\" size=12>";
		print "<b> $iface IP</b>";
		print " <input type=\"text\" name=\"rip\" value=\"$rip\" size=12>";
		print "<br>";
		print "<br>";

		print "<b>Cluster ID (1-255).</b>";
		print "<br>";
		print " <input type=\"text\" name=\"idcluster\" value=\"$idcluster\" size=12>";
		print "<br>";
		print "<br>";

		print "<b>Dead ratio.</b>";
		print "<br>";
		print " <input type=\"text\" name=\"deadratio\" value=\"$deadratio\" size=12>";
		print "<br>";
		print "<br>";

		print "<input type=\"hidden\" name=\"vipcl\"value=\"$vipcl\">";
		print "<input type=\"hidden\" name=\"typecl\"value=\"$typecl\">";
		print "<input type=\"hidden\" name=\"clstatus\"value=\"$clstatus\">";
		print "<input type=\"hidden\" name=\"ifname\"value=\"$ifname\">";
		print "<input type=\"hidden\" name=\"id\" value=\"$id\">";
		print "<input type=\"submit\" value=\"Save\" name=\"action\" class=\"button small\">";

		#print "<input type=\"submit\" value=\"Test RSA connections\" name=\"action\" class=\"button small\">";
		print "</form>";
	}
	print "<br>";

	if ( $rhost !~ /^$/ && $lhost !~ /^$/ && $rip !~ /^$/ && $lip !~ /^$/ && $vipcl !~ /^$/ )
	{
		print "<form method=\"post\" action=\"index.cgi\">";
		print "<b>Remote Hostname root password.</b><font size=\"1\">*This value will no be remembered</font>";
		print "<br>";
		print "<input type=\"password\" name=\"pass\"value=\"\" size=12>";
		print "<input type=\"hidden\" name=\"id\" value=\"$id\">";
		print "<br>";
		print "<br>";
		print "<input type=\"submit\" value=\"Configure RSA connection between nodes\" name=\"actionpost\" class=\"button small\">";
		print "</form>";
		print "<br>";

	}
}

if ( $rhost !~ /^$/ && $lhost !~ /^$/ && $rip !~ /^$/ && $lip !~ /^$/ && $vipcl !~ /^$/ )
{

	#form for run and stop ucarp service
	print "<form method=\"get\" action=\"index.cgi\">";
	print "<b>Cluster type:</b>";
	print "<div id=\"page-header\"></div>";

	# print "<br>";
	print "<select name=\"typecl\">\n";
	if ( $activecl eq "$lhost" || $clstatus eq "" )
	{

		if ( $typecl =~ /^$/ )
		{
			print "<option value=\"Disabled\" selected=\"selected\">--Disable cluster on all hosts--</option>";
		}
		else
		{
			print "<option value=\"Disabled\">--Disable cluster on all hosts--</option>";
		}

		if ( $typecl eq "$lhost-$rhost" )
		{
			print "<option value=\"$lhost-$rhost\" selected=\"selected\">$lhost master and $rhost backup automatic failback</option>";
		}
		elsif ( $typecl eq "$rhost-$lhost" )
		{
			print "<option value=\"$rhost-$lhost\" selected=\"selected\">$rhost master and $lhost backup automatic failback</option>";
		}
		else
		{
			print "<option value=\"$lhost-$rhost\">$lhost master and $rhost backup automatic failback</option>";
		}
		if ( $typecl =~ /^equal/ )
		{
			print "<option value=\"equal\" selected=\"selected\">$lhost or $rhost can be masters</option>";
		}
		else
		{
			print "<option value=\"equal\">$lhost or $rhost can be masters</option>";
		}
	}
	else
	{
		print "<option value=\"Disabled\" selected=\"selected\">--Disable cluster on all hosts--</option>";
	}
	print "</select>";
	print "<br>";
	print "<br>";
	if ( $cable eq "Crossover cord" )
	{
		$checked = "checked";
	}
	else
	{
		$checked = "";
	}
	print "<input type=\"checkbox\" name=\"cable\" value=\"Crossover cord\" $checked />&nbsp;Use crossover patch cord";
	print "<input type=\"hidden\" name=\"id\" value=\"$id\">";
	print "<input type=\"hidden\" name=\"lhost\" value=\"$lhost\">";
	print "<input type=\"hidden\" name=\"rhost\" value=\"$rhost\">";
	print "<input type=\"hidden\" name=\"lip\" value=\"$lip\">";
	print "<input type=\"hidden\" name=\"rip\" value=\"$rip\">";
	print "<input type=\"hidden\" name=\"vipcl\" value=\"$vipcl\">";
	print "<input type=\"hidden\" name=\"ifname\" value=\"$ifname\">";
	print "<input type=\"hidden\" name=\"cable\" value=\"$cable\">";
	print "<input type=\"hidden\" name=\"idcluster\" value=\"$idcluster\">";
	print "<input type=\"hidden\" name=\"deadratio\" value=\"$deadratio\">";
	print "<br>";
	print "<br>";
	print "<input type=\"submit\" value=\"Configure cluster type\" name=\"action\" class=\"button small\">";

	if ( $clstatus !~ /^$/ )
	{
		print "<input type=\"submit\" value=\"Test RSA connections\" name=\"action\" class=\"button small\">";
	}
	if ( $activecl eq "$lhost" )
	{
		print "<input type=\"submit\" value=\"Test failover\" name=\"action\" class=\"button small\">";
	}
	if ( `ps aux | grep "ucarp" | grep "\\-k 100" | grep -v grep` )
	{
		print "<input type=\"submit\" value=\"Return node from maintenance\" name=\"action\" class=\"button small\">";
	}
	else
	{
		print "<input type=\"submit\" value=\"Force node as backup for maintenance\" name=\"action\" class=\"button small\">";
	}
	print "</form>";
	print "<br>";
}

#print "<input type=\"submit\" value=\"Test connection\" name=\"action\" class=\"button small\">";

print "<div id=\"page-header\"></div>";

####
if ( $vipcl !~ /^$/ && $clstatus eq "" )
{
	print "<form method=\"get\" action=\"index.cgi\">";
	print "<input type=\"hidden\" name=\"clstatus\"value=\"$clstatus\">";
	print "<input type=\"hidden\" name=\"id\" value=\"$id\">";
	print "<input type=\"submit\" value=\"Cancel\" name=\"action\" class=\"button small\">";
	print "</form>";
}

print "</div></div></div>";
print "<br class=\"cl\" >";

print "        </div>
    <!--Content END-->
  </div>
</div>
";
