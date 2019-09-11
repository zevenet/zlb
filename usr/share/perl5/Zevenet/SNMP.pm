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

=begin nd
Function: setSnmpdStatus

	Start or stop the SNMP service.

Parameters:
	snmpd_status - 'true' to start, or 'stop' to stop the SNMP service.

Returns:
	scalar - 0 on success, non-zero on failure.

See Also:
	zapi/v3/system.cgi, <setSnmpdStatus>
=cut

sub setSnmpdStatus    # ($snmpd_status)
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );

	# get 'true' string to start, or a 'false' string to stop
	my ( $snmpd_status ) = @_;

	my $return_code = -1;
	my $systemctl   = &getGlobalConfiguration( 'systemctl' );
	my $updatercd   = &getGlobalConfiguration( 'updatercd' );
	my $snmpd_srv   = &getGlobalConfiguration( 'snmpd_service' );

	if ( $snmpd_status eq 'true' )
	{
		&zenlog( "Starting snmp service", "info", "SYSTEM" );
		my @run = system ( "$updatercd snmpd enable" );

		if ( -f $systemctl )
		{
			$return_code = system ( "$systemctl start snmpd > /dev/null" );
		}
		else
		{
			$return_code = system ( "$snmpd_srv start > /dev/null" );
		}
	}
	elsif ( $snmpd_status eq 'false' )
	{
		&zenlog( "Stopping snmp service", "info", "SYSTEM" );
		my @run = system ( "$updatercd snmpd disable" );

		if ( -f $systemctl )
		{
			$return_code = system ( "$systemctl stop snmpd > /dev/null" );
		}
		else
		{
			$return_code = system ( "$snmpd_srv stop > /dev/null" );
		}
	}
	else
	{
		&zenlog( "SNMP requested state is invalid", "warning", "SYSTEM" );
		return -1;
	}

	# returns 0 = DONE SUCCESSFULLY
	return $return_code;
}

=begin nd
Function: getSnmpdStatus

	Get if the SNMP service is running.

Parameters:
	none - .

Returns:
	string - Boolean. 'true' if it is running, or 'false' if it is not runnig.

See Also:
	zapi/v3/system.cgi
=cut

sub getSnmpdStatus    # ()
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $pidof       = &getGlobalConfiguration( 'pidof' );
	my $status      = `$pidof snmpd`;
	my $return_code = $?;

	# if not empty pid
	if ( $return_code == 0 )
	{
		$return_code = "true";
	}
	else
	{
		$return_code = "false";
	}

	return $return_code;
}

=begin nd
Function: getSnmpdConfig

	Get the configuration of the SNMP service.

	Returns this hash reference:

		$snmpd_conf = {
					   ip        => $snmpd_ip,
					   port      => $snmpd_port,
					   community => $snmpd_community,
					   scope     => $snmpd_scope,
		};

Parameters:
	none - .

Returns:
	scalar - Hash reference with SNMP configuration.

See Also:
	zapi/v3/system.cgi
=cut

sub getSnmpdConfig    # ()
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	require Tie::File;

	my $snmpdconfig_file = &getGlobalConfiguration( 'snmpdconfig_file' );

	tie my @config_file, 'Tie::File', $snmpdconfig_file;

	## agentAddress line ##
	# agentAddress udp:127.0.0.1:161
	my ( undef, $snmpd_ip, $snmpd_port ) = split ( /:/, $config_file[0] );

	## rocommunity line ##
	# rocommunity public 0.0.0.0/0
	my ( undef, $snmpd_community, $snmpd_scope ) =
	  split ( /\s+/, $config_file[1] );

	$snmpd_ip = '*' if ( $snmpd_ip eq '0.0.0.0' );

	# Close file
	untie @config_file;

	my %snmpd_conf = (
					   ip        => $snmpd_ip,
					   port      => $snmpd_port,
					   community => $snmpd_community,
					   scope     => $snmpd_scope,
	);

	return \%snmpd_conf;
}

=begin nd
Function: setSnmpdConfig

	Store SNMP configuration.

Parameters:
	snmpd_conf - Hash reference with SNMP configuration.

Returns:
	integer - 0 on success, or -1 on failure.

See Also:
	zapi/v3/system.cgi
=cut

sub setSnmpdConfig    # ($snmpd_conf)
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my ( $snmpd_conf ) = @_;

	my $snmpdconfig_file = &getGlobalConfiguration( 'snmpdconfig_file' );

	my $ip = $snmpd_conf->{ ip };
	$ip = '0.0.0.0' if ( $snmpd_conf->{ ip } eq '*' );

	return -1 if ref $snmpd_conf ne 'HASH';

	# Open config file
	open my $config_file, '>', $snmpdconfig_file;

	if ( !$config_file )
	{
		&zenlog( "Could not open $snmpdconfig_file: $!", "warning", "SYSTEM" );
		return -1;
	}

	# example: agentAddress  udp:127.0.0.1:161
	# example: rocommunity public  0.0.0.0/0
	print $config_file "agentAddress udp:$ip:$snmpd_conf->{port}\n";
	print $config_file
	  "rocommunity $snmpd_conf->{community} $snmpd_conf->{scope}\n";
	print $config_file "includeAllDisks 10%\n";
	print $config_file "#zenlb\n";

	# Close config file
	close $config_file;

	return 0;
}

1;
