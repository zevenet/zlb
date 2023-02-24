#!/usr/bin/perl
###############################################################################
#
#    ZEVENET Software License
#    This file is part of the ZEVENET Load Balancer software package.
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
use Zevenet::Farm::Backend::Maintenance;


=begin nd
Function: getFarmServerIds

	It returns a list with the backend servers for a farm and service.
	The backends are read from the config file.
	This function is to not use the getFarmservers that does stats checks.

Parameters:
	farmname - Farm name
	service - service backends related (optional)

Returns:
	array ref - list of backends IDs

=cut

sub getFarmServerIds
{
	&zenlog( __FILE__ . q{:} . __LINE__ . q{:} . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my ( $farm_name, $service ) = @_;
	my @servers   = ();
	my $farm_type = &getFarmType( $farm_name );

	if ( $farm_type =~ /http/ )
	{
		require Zevenet::Farm::HTTP::Service;
		my $backendsvs = &getHTTPFarmVS( $farm_name, $service, "backends" );
		@servers = split ( "\n", $backendsvs );
		@servers = 0 .. $#servers if ( @servers );
	}
	elsif ( $farm_type eq "l4xnat" )
	{
		require Zevenet::Farm::L4xNAT::Backend;
		@servers = @{ &getL4FarmServers( $farm_name ) };
		@servers = 0 .. $#servers if ( @servers );
	}
	elsif ( $farm_type eq "datalink" )
	{
		my $configdir     = &getGlobalConfiguration( 'configdir' );
		my $farm_filename = &getFarmFile( $farm_name );
		open my $fh, '<', "$configdir/$farm_filename";
		{
			while ( my $line = <$fh> )
			{
				push @servers, $line if ( $line =~ /^;server;/ );
			}
		}
		close $fh;
		@servers = 0 .. $#servers if ( @servers );
	}

	return \@servers;
}

=begin nd
Function: getFarmServers

	List all farm backends and theirs configuration

Parameters:
	farmname - Farm name
	service - service backends related (optional)

Returns:
	array ref - list of backends

FIXME:
	changes output to hash format

=cut

sub getFarmServers    # ($farm_name, $service)
{
	&zenlog( __FILE__ . q{:} . __LINE__ . q{:} . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my ( $farm_name, $service ) = @_;

	my $farm_type = &getFarmType( $farm_name );
	my $servers;

	if ( $farm_type =~ /http/ )
	{
		require Zevenet::Farm::HTTP::Backend;
		$servers = &getHTTPFarmBackends( $farm_name, $service );
	}
	elsif ( $farm_type eq "l4xnat" )
	{
		require Zevenet::Farm::L4xNAT::Backend;
		$servers = &getL4FarmServers( $farm_name );
	}
	elsif ( $farm_type eq "datalink" )
	{
		require Zevenet::Farm::Datalink::Backend;
		$servers = &getDatalinkFarmBackends( $farm_name );
	}

	return $servers;
}

=begin nd
Function: getFarmServer

	Return the backend with the specified value on the specified parameter.

Parameters:
	backends_ref - Array ref of backends hashes.
	value - Parameter value to match
	param - Parameter to match. Default value "id"

Returns:
	hash ref - bachend hash reference or undef if there aren't backends

=cut

sub getFarmServer    # ( $bcks_ref, $value, $param )
{
	&zenlog( __FILE__ . q{:} . __LINE__ . q{:} . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $bcks_ref = shift;
	my $value    = shift;
	my $param    = shift // "id";

	foreach my $server ( @{ $bcks_ref } )
	{
		# preserve type param number
		if ( $param eq "id" )
		{
			return $server if ( $server->{ $param } == $value );
		}
		else
		{
			return $server if ( $server->{ $param } eq "$value" );
		}
	}

	# Error, not found so return undef
	return;
}

=begin nd
Function: setFarmServer

	Add a new Backend

Parameters:
	farmname - Farm name
	service - service name. For HTTP farms
	id - Backend id, if this id doesn't exist, it will create a new backend
	backend - hash with backend configuration. Depend on the type of farms, the backend can have the following keys:
		ip, port, weight, priority, timeout, max_conns or interface

Returns:
	Scalar - Error code: undef on success or -1 on error

=cut

sub setFarmServer    # $output ($farm_name,$service,$bk_id,$bk_params)
{
	&zenlog( __FILE__ . q{:} . __LINE__ . q{:} . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my ( $farm_name, $service, $ids, $bk ) = @_;

	my $farm_type = &getFarmType( $farm_name );
	my $output    = -1;

	&zenlog(
		"setting 'Server $ids ip:$bk->{ip} port:$bk->{port} max:$bk->{max_conns} weight:$bk->{weight} prio:$bk->{priority} timeout:$bk->{timeout}' for $farm_name farm, $service service of type $farm_type",
		"info", "FARMS"
	);

	if ( $farm_type eq "datalink" )
	{
		require Zevenet::Farm::Datalink::Backend;
		$output =
		  &setDatalinkFarmServer( $ids,
								  $bk->{ ip },
								  $bk->{ interface },
								  $bk->{ weight },
								  $bk->{ priority }, $farm_name );
	}
	elsif ( $farm_type eq "l4xnat" )
	{
		require Zevenet::Farm::L4xNAT::Backend;
		$output =
		  &setL4FarmServer( $farm_name, $ids,
							$bk->{ ip },
							$bk->{ port }      // "",
							$bk->{ weight }    // 1,
							$bk->{ priority }  // 1,
							$bk->{ max_conns } // 0 );
	}
	elsif ( $farm_type eq "http" or $farm_type eq "https" )
	{
		require Zevenet::Farm::HTTP::Backend;
		$output =
		  &setHTTPFarmServer(
							  $ids,
							  $bk->{ ip },
							  $bk->{ port },
							  $bk->{ weight },
							  $bk->{ timeout },
							  $farm_name,
							  $service,
							  $bk->{ priority },
							  $bk->{ connection_limit }
		  );
	}

	# FIXME: include setGSLBFarmNewBackend

	return $output;
}

=begin nd
Function: runFarmServerDelete

	Delete a Backend

Parameters:
	id - Backend id, if this id doesn't exist, it will create a new backend
	farmname - Farm name
	service - service name. For HTTP farms

Returns:
	Scalar - Error code: undef on success or -1 on error

=cut

sub runFarmServerDelete    # ($ids,$farm_name,$service)
{
	&zenlog( __FILE__ . q{:} . __LINE__ . q{:} . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my ( $ids, $farm_name, $service ) = @_;

	my $farm_type = &getFarmType( $farm_name );
	my $output    = -1;

	&zenlog( "running 'ServerDelete $ids' for $farm_name farm $farm_type",
			 "info", "FARMS" );

	if ( $farm_type eq "datalink" )
	{
		require Zevenet::Farm::Datalink::Backend;
		$output = &runDatalinkFarmServerDelete( $ids, $farm_name );
	}
	elsif ( $farm_type eq "l4xnat" )
	{
		require Zevenet::Farm::L4xNAT::Backend;
		$output = &runL4FarmServerDelete( $ids, $farm_name );
	}
	elsif ( $farm_type eq "http" or $farm_type eq "https" )
	{
		require Zevenet::Farm::HTTP::Backend;
		$output = &runHTTPFarmServerDelete( $ids, $farm_name, $service );
	}

	return $output;
}

=begin nd
Function: getFarmBackendAvailableID

	Get next available backend ID

Parameters:
	farmname - farm name

Returns:
	integer - .

=cut

sub getFarmBackendAvailableID
{
	&zenlog( __FILE__ . q{:} . __LINE__ . q{:} . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $farmname = shift;
	my $nbackends;

	if ( &getFarmType( $farmname ) eq 'l4xnat' )
	{
		require Zevenet::Farm::L4xNAT::Backend;
		$nbackends = &getL4FarmBackendAvailableID( $farmname );
	}
	else
	{
		my $backends = &getFarmServers( $farmname );
		$nbackends = $#{ $backends } + 1;
	}

	return $nbackends;
}

=begin nd
Function: setBackendRule

	Add or delete the route rule according to the backend mark.

Parameters:
	action - "add" to create the mark or "del" to remove it.
	farm_ref - farm reference.
	mark - backend mark to apply in the rule.
	farm_type - type of farm (l4xnat, http, https).

Returns:
	integer - 0 if successful, otherwise error.

=cut

sub setBackendRule
{
	&zenlog( __FILE__ . q{:} . __LINE__ . q{:} . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my $action    = shift;
	my $farm_ref  = shift;
	my $mark      = shift;
	my $farm_type = shift // getFarmType( $farm_ref->{ name } );

	return -1
	  if (    $action !~ /add|del/
		   or not defined $farm_ref
		   or $mark eq ""
		   or $mark eq "0x0" );

	require Zevenet::Net::Util;
	require Zevenet::Net::Route;

	my $vip_if_name = &getInterfaceOfIp( $farm_ref->{ vip } );
	my $vip_if      = &getInterfaceConfig( $vip_if_name );
	my $table_if =
	  ( $vip_if->{ type } eq 'virtual' ) ? $vip_if->{ parent } : $vip_if->{ name };

	my $rule = {
				 table  => "table_$table_if",
				 type   => $farm_type,
				 from   => 'all',
				 fwmark => "$mark/0x7fffffff",
	};
	return &setRule( $action, $rule );
}

1;

