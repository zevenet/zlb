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

require "/usr/local/zenloadbalancer/www/functions.cgi";

sub setSnmpdStatus($snmpd_status)
{
	# get 'true' string to start, or a 'false' string to stop
	my ( $snmpd_status ) = @_;
	my $return_code = -1;

	if ( $snmpd_status eq 'true' )
	{
		$return_code = system ( "/etc/init.d/snmpd start > /dev/null" );
	}
	elsif ( $snmpd_status eq 'false' )
	{
		$return_code = system ( "/etc/init.d/snmpd stop > /dev/null" );
	}
	else
	{
		&logfile( "SNMP requested state is invalid" );
		return $return_code;
	}

	# returns 0 = DONE SUCCESSFULLY
	return $return_code;
}

sub getSnmpdStatus()
{
	my $status = `$pidof snmpd`;
	my $return_code;

	# if not empty pid
	if ( $status ne '' )
	{
		$return_code = "true";
	}
	else
	{
		$return_code = "false";
	}

	return $return_code;
}

sub getSnmpdConfig()
{
	tie my @config_file, 'Tie::File', $snmpdconfig_file;

	## agentAddress line ##
	# agentAddress udp:127.0.0.1:161
	my ( undef, $snmpd_ip, $snmpd_port ) = split ( /:/, $config_file[0] );

	## rocommunity line ##
	# rocommunity public 0.0.0.0/0
	my ( undef, $snmpd_community, $snmpd_scope ) = split ( /\s+/, $config_file[1] );

	# Close file
	untie @config_file;

	return ( $snmpd_ip, $snmpd_port, $snmpd_community, $snmpd_scope );
}

sub setSnmpdConfig($snmpd_ip, $snmpd_port, $snmpd_community, $snmpd_scope)
{
	my ( $snmpd_ip, $snmpd_port, $snmpd_community, $snmpd_scope ) = @_;

	# Open config file
	tie my @config_file, 'Tie::File', $snmpdconfig_file;

	if ( $snmpd_ip eq '*' )
	{
		$snmpd_ip = '0.0.0.0';
	}

	# example: agentAddress  udp:127.0.0.1:161
	$config_file[0] = "agentAddress udp:$snmpd_ip:$snmpd_port";

	# example: rocommunity public  0.0.0.0/0
	$config_file[1] = "rocommunity $snmpd_community $snmpd_scope";
	
	# needed for Disk information
	# example:  includeAllDisks 10% for all partitions and disks
	$config_file[2] = "includeAllDisks 10% for all partitions and disks";

	# Close config file
	untie @config_file;
}

sub setSnmpdIp($snmpd_ip)
{
	my ( $snmpd_ip ) = @_;

	# Open config file
	tie my @config_file, 'Tie::File', $snmpdconfig_file;

	# get port number from first line
	my ( undef, undef, $port ) = split ( ':', $config_file[0] );

	## rewrite agentAddress line ##
	# example: agentAddress  udp:127.0.0.1:161
	if ( $snmpd_ip eq '*' )
	{
		$snmpd_ip = '0.0.0.0';
	}
	$config_file[0] = "agentAddress udp:$snmpd_ip:$port";

	# Close config file
	untie @config_file;
}

sub getSnmpdIp()
{
	# example: agentAddress  udp:127.0.0.1:161
	# Open config file
	tie my @config_file, 'Tie::File', $snmpdconfig_file;

	# get snmp ip from the first line
	my ( undef, $snmpd_ip, undef ) = split ( ':', $config_file[0] );

	# Close config file
	untie @config_file;

	return $snmpd_ip;
}

sub getSnmpdPort()
{
	tie my @config_file, 'Tie::File', $snmpdconfig_file;

	# get snmp port from the first line
	# example: agentAddress udp:127.0.0.1:161
	my ( undef, undef, $port ) = split ( ':', $config_file[0] );

	# Close file
	untie @config_file;

	return $port;
}

sub setSnmpdService($snmpd_enabled)
{
	my ( $snmpd_enabled ) = @_;
	my $return_code = -1;

	# verify valid input
	if ( $snmpd_enabled ne 'true' && $snmpd_enabled ne 'false' )
	{
		&logfile( "SNMP Service: status not available" );
		return $return_code;
	}

	# change snmpd status
	if ( &setSnmpdStatus( $snmpd_enabled ) != 0 )
	{
		&logfile( "SNMP Status change failed" );
		return $return_code;
	}

	# perform runlevel change
	if ( $snmpd_enabled eq 'true' )
	{
		$return_code = system ( "$insserv snmpd" );
	}
	else
	{
		$return_code = system ( "$insserv -r snmpd" );
	}

	# show message if failed
	if ( $return_code != 0 )
	{
		&logfile( "SNMP runlevel setup failed" );
	}
	return $return_code;
}

sub applySnmpChanges($snmpd_enabled, $snmpd_port, $snmpd_community, $snmpd_scope)
{
	my ( $snmpd_enabled, $snmpd_port, $snmpd_community, $snmpd_scope ) = @_;
	my $return_code = -1;

	## setting up valiables ##
	# if checkbox not checked set as false instead of undefined
	if ( !defined ( $snmpd_enabled ) )
	{
		$snmpd_enabled = 'false';
	}

	# read current management IP
	my $snmpd_ip = &GUIip();
	if ( $snmpd_ip eq '*' )
	{
		$snmpd_ip = '0.0.0.0';
	}

	## validating some input values ##
	# check port
	if ( !&isValidPortNumber( $snmpd_port ) )
	{
		&logfile( "SNMP: Port out of range" );
		return $return_code;
	}

	# if $snmpd_scope is not a valid ip or subnet
	my ( $ip, $subnet ) = split ( '/', $snmpd_scope );
	if ( &ipisok( $ip ) eq 'false' )
	{
		&logfile( "SNMP: Invalid ip or subnet with access" );
		return $return_code;
	}
	if ( &isnumber( $subnet ) eq 'false' || $subnet < 0 || $subnet > 32 )
	{
		&logfile( "SNMP: Invalid subnet with access" );
		return $return_code;
	}

	# get config values of snmp server
	my ( $cf_snmpd_enabled, $cf_snmpd_ip, $cf_snmpd_port, $cf_snmpd_community, $cf_snmpd_scope ) = ( &getSnmpdStatus(), &getSnmpdConfig() );

	my $conf_changed = 'false';

	# configuration/service status logic
	# setup config file if requested configuration changes
	if (   $cf_snmpd_ip ne $snmpd_ip
		|| $cf_snmpd_port ne $snmpd_port
		|| $cf_snmpd_community ne $snmpd_community
		|| $cf_snmpd_scope ne $snmpd_scope )
	{
		&setSnmpdConfig( $snmpd_ip, $snmpd_port, $snmpd_community, $snmpd_scope );
		$conf_changed = 'true';
	}

	# if the desired snmp status is different to the current status => switch service
	if ( $snmpd_enabled ne $cf_snmpd_enabled )
	{
		if ( &setSnmpdService( $snmpd_enabled ) )
		{
			&logfile( "SNMP failed setting the service" );
			return $return_code;
		}
	}

	# if snmp is on and want it on loading new configuration => restart server
	elsif ( $snmpd_enabled eq 'true' && $cf_snmpd_enabled eq 'true' && $conf_changed eq 'true' )
	{
		if ( &setSnmpdStatus( 'false' ) || &setSnmpdStatus( 'true' ) )
		{
			&logfile( "SNMP failed restarting the server" );
			return $return_code;
		}
	}
	return 0;
}

# do not remove this
1
