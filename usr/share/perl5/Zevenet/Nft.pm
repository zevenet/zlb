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
use warnings;

=begin nd
Function: getNlbPid

	Return the nftlb pid

Parameters:
	none

Returns:
	Integer - PID if successful or -1 on failure

=cut

sub getNlbPid
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );

	my $nlbpidfile = &getNlbPidFile();
	my $nlbpid     = -1;

	if ( !-f "$nlbpidfile" )
	{
		return -1;
	}

	open my $fd, '<', "$nlbpidfile";
	$nlbpid = <$fd>;
	close $fd;

	if ( $nlbpid eq "" )
	{
		return -1;
	}

	return $nlbpid;
}

=begin nd
Function: getNlbPidFile

	Return the nftlb pid file

Parameters:
	none

Returns:
	String - Pid file path or -1 on failure

=cut

sub getNlbPidFile
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );

	my $piddir     = &getGlobalConfiguration( 'piddir' );
	my $nlbpidfile = "$piddir/nftlb.pid";

	return $nlbpidfile;
}

=begin nd
Function: startNlb

	Launch the nftlb daemon and create the PID file. Do
	nothing if already is launched.

Parameters:
	none

Returns:
	Integer - return PID on success or <= 0 on failure

=cut

sub startNlb
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $nftlbd     = &getGlobalConfiguration( 'zbindir' ) . "/nftlbd";
	my $pidof      = &getGlobalConfiguration( 'pidof' );
	my $nlbpidfile = &getNlbPidFile();
	my $nlbpid     = &getNlbPid();

	if ( $nlbpid eq "-1" )
	{
		&logAndRun( "$nftlbd start" );

		#required to wait at startup to ensure the process is up
		sleep 1;

		$nlbpid = &logAndGet( "$pidof nftlb" );
		if ( $nlbpid eq "" )
		{
			return -1;
		}

		open my $fd, '>', "$nlbpidfile";
		print $fd "$nlbpid";
		close $fd;
	}

	return $nlbpid;
}

=begin nd
Function: stopNlb

	Stop the nftlb daemon. Do nothing if is already stopped.

Parameters:
	none

Returns:
	Integer - return PID on success or <= 0 on failure

=cut

sub stopNlb
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );

	my $nftlbd = &getGlobalConfiguration( 'zbindir' ) . "/nftlbd";
	my $nlbpid = &getNlbPid();

	if ( $nlbpid ne "-1" )
	{
		&logAndRun( "$nftlbd stop" );
	}

	return $nlbpid;
}

=begin nd
Function: httpNlbRequest

	Send an action to nftlb

Parameters:
	self - hash that includes hash_keys:
		file, file where the HTTP body response of the nftlb is saved
		method, HTTP verb for nftlb request
		uri, HTTP URI for nftlb request
		body, body to use in POST and PUT requests
		check, if this parameter is defined is a flag to not print error if
				the request is used to check if a element exists.

Returns:
	Integer - return code of the request command

=cut

sub httpNlbRequest
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $self     = shift;
	my $curl_cmd = &getGlobalConfiguration( 'curl_bin' );
	my $body     = "";

	my $pid = &startNlb();
	if ( $pid <= 0 )
	{
		return -1;
	}

	chomp ( $curl_cmd );
	return -1 if ( $curl_cmd eq "" );

	$body = qq(-d'$self->{ body }')
	  if ( defined $self->{ body } && $self->{ body } ne "" );

	my $execmd =
	  qq($curl_cmd -w "%{http_code}" --noproxy "*" -s -H "Key: HoLa" -X "$self->{ method }" $body http://127.0.0.1:27$self->{ uri });

	my $file = "/tmp/nft_$$";
	$file = $self->{ file }
	  if ( defined $self->{ file } && $self->{ file } =~ /(?:ipds)/ );

	# Send output to a file to get only the http code by the standard output
	$execmd = $execmd . " -o $file";

	my $output = &logAndGet( $execmd );
	if ( $output !~ /^2/ )    # err
	{
		my $tag = ( exists $self->{ check } ) ? 'debug' : 'error';
		&zenlog( "cmd failed: $execmd", $tag, 'system' ) if ( !&debug );
		if ( open ( my $fh, '<', $file ) )
		{
			local $/ = undef;
			my $err = <$fh>;
			&zenlog( "(code: $output): $err", $tag, 'system' );
			close $fh;
		}
		else
		{
			&zenlog( "The file '$file' could not be opened", 'error', 'system' );
		}
		return -1;
	}

	# filter ipds params into the configuration file
	if (    defined $self->{ file }
		 && $self->{ file } ne ""
		 && !-z "$file"
		 && $file !~ /ipds/ )
	{
		require Zevenet::Farm::L4xNAT::Config;
		&writeL4NlbConfigFile( $file, $self->{ file } );
	}

	return 0;
}

=begin nd
Function: execNft

	Execute the nft command

Parameters:
	action		- "add", "delete", "check" or "flush"
	table		- type and name of the table to be used (ej "netdev foo")
	chain_def	- name and definition of the chain to be used
	rule		- rule or pattern in case of deletion

Returns:
	Integer - 0 on success or != 0 on failure. In case of check action,

=cut

sub execNft
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $action    = shift;
	my $table     = shift;
	my $chain_def = shift;
	my $rule      = shift;

	my $nft   = &getGlobalConfiguration( 'nft_bin' );
	my $chain = "";
	( $chain ) = $chain_def =~ /^([\w\-\.\d]+)\s*.*$/;
	my $output = 0;

	if ( $action eq "add" )
	{
		&logAndRun( "$nft add table $table" );
		&logAndRun( "$nft add chain $table $chain_def" );
		$output = &logAndRun( "$nft add rule $table $chain $rule" );
	}
	elsif ( $action eq "delete" )
	{
		if ( !defined $chain || $chain eq "" )
		{
			&zenlog( "Deleting cluster table $table" );
			$output = &logAndRun( "$nft delete table $table" );
		}
		elsif ( !defined $rule || $rule eq "" )
		{
			$output = &logAndRun( "$nft delete chain $table $chain" );
		}
		else
		{
			my @rules = @{ &logAndGet( "$nft -a list chain $table $chain", 'array' ) };
			foreach my $r ( @rules )
			{
				my ( $handle ) = $r =~ / $rule.* \# handle (\d)$/;
				if ( $handle ne "" )
				{
					$output = &logAndRun( "$nft delete rule $table $chain handle $handle" );
					last;
				}
			}
		}
	}
	elsif ( $action eq "check" )
	{
		if ( !defined $chain || $chain eq "" )
		{
			$output = 1;
			my @rules = @{ &logAndGet( "$nft list table $table", 'array' ) };
			$output = 0 if ( scalar @rules == 0 );
			return $output;
		}
		else
		{
			my @rules = @{ &logAndGet( "$nft list chain $table $chain", 'array' ) };
			foreach my $r ( @rules )
			{
				if ( $r =~ / $rule / )
				{
					$output = 1;
					last;
				}
			}
		}
	}
	elsif ( $action eq "flush" )
	{
		&logAndRun( "$nft add table $table" );
		&logAndRun( "$nft add chain $table $chain_def" );
		$output = &logAndRun( "$nft flush chain $table $chain" );
	}

	return $output;
}

1;

