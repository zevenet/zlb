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
require Zevenet::ELoad;
sub include;
include 'Zevenet::Certificate::Activation';

=begin nd
Function: 

	Get any of the defined alerts.

Parameters:

	section:	Alert section

Returns:
	
	Alert message or 0 if there are not alerts.
	
=cut

sub getAlert
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );

	my $alert = shift;
	my $message;

	if (    $alert ne 'License'
		 && $alert ne 'Certificate'
		 && $alert ne 'Cluster'
		 && $alert ne 'Package' )
	{
		&zenlog( "There is not any defined alert for $alert", "warning", "Alerts" );
		return 0;
	}

	$message = &getLicenseAlert()     if ( $alert eq "License" );
	$message = &getCertificateAlert() if ( $alert eq "Certificate" );
	$message = &getClusterAlert()     if ( $alert eq "Cluster" );
	$message = &getPackageAlert()     if ( $alert eq "Package" );

	return 0 unless ( defined $message );

	return $message;
}

=begin nd
Function: 

	Check if the license expiration date is approaching.

Parameters:
	none - .

Returns:
	Returns an alert message if the remaining days of expiration
	coincide with any of the configured days.
	
=cut

sub getLicenseAlert
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );

	my $cert_path = &getGlobalConfiguration( 'zlbcertfile_path' );
	my $balancer  = &getHostname();

	my $info = &getCertActivationInfo( $cert_path );
	my @days = split ( ',', &getGlobalConfiguration( 'notifLicenseNumDays' ) );
	my $message;

	foreach my $day ( @days )
	{
		if ( $info->{ days_to_expire } eq $day )
		{
			if ( $day eq 0 )
			{
				$message = "The $balancer balancer license expires today.";
			}
			else
			{
				$message = "The $balancer balancer license will expire in $day days.";
			}
		}
	}

	# if ( defined $message )
	# {
	# 	&zenlog( $message, "INFO", "alert" );
	# }

	return $message;
}

=begin nd
Function: 

	Check if there is any certificate in use with date approaching.

Parameters:
	none - .

Returns:
	Returns an alert message if the remaining days of expiration
	coincide with any of the configured days.
	
=cut

sub getCertificateAlert
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );

	my $balancer = &getHostname();

	my @certs = getPemCertFiles();

	my $cert_dir = &getGlobalConfiguration( 'certdir' );
	my @days = split ( ',', &getGlobalConfiguration( 'notifCertNumDays' ) );
	my $message;

	foreach my $day ( @days )
	{
		foreach my $cert ( @certs )
		{
			my $expiration = &getDateUtc( &getCertExpiration( "$cert_dir\/$cert" ) );
			next if ( !defined $expiration or $expiration eq "" );
			my $daysToExpire = &getCertDaysToExpire( $expiration );

			next unless ( $daysToExpire eq $day );

			include 'Zevenet::System::HTTP';

			my $status = &getFarmCertUsed( $cert );
			if ( $status eq 0 )
			{
				$message .= "The cert $cert used in a farm will expire in $day days.\n";
				next;
			}
			my $status = &getHttpsCertUsed( $cert );
			if ( $status eq 0 )
			{
				$message .=
				  "The cert $cert used in the http server will expire in $day days.\n";
				next;
			}
		}
	}

	# if ( defined $message )
	# {
	# 	&zenlog( $message, "INFO", "alert" );
	# }

	return $message;
}

=begin nd
Function: 

	Check if there is issues in cluster state.

Parameters:
	none - .

Returns:
	Returns an alert message with the issue.
	
=cut

sub getClusterAlert
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );

	include 'Zevenet::API40::System::Cluster';

	my $status = &get_cluster_nodes_status();

	my $message;

	foreach my $node ( @{ $status->{ body }->{ params } } )
	{
		if ( $node->{ status } ne 'ok' && $node->{ status } ne 'not configured' )
		{
			$message .= "The node $node->{ name } status is $node->{ status }\n
						Description: $node->{ message }\n";
		}
	}

	# if ( defined $message )
	# {
	# 	&zenlog( $message, "INFO", "alert" );
	# }

	return $message;
}

=begin nd
Function: 

	Check if there is issues in cluster state.

Parameters:
	none - .

Returns:
	Returns an alert message with the issue.
	
=cut

sub getPackageAlert
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );

	my $balancer = &getHostname();

	require Zevenet::Arrays;
	require Zevenet::System::Packages;

	my $info = &getSystemPackagesUpdatesList();

	my $packages;
	my $hotfixes;
	my $message;

	if ( $info->{ number } > 0 )
	{
		$packages = $info->{ packages };
		my $index;

		# get current index
		$index = &getARRIndex( $packages, 'zevenet' );

		if ( defined $index )
		{
			$message .= "A new zevenet hotfix is avaliable\n";
			splice @{ $packages }, $index, 1;

			# &zenlog( "A new zevenet hotfix is avaliable", "INFO", "alert" );
		}
		$index = &getARRIndex( $packages, 'zevenet-web-gui' );

		if ( defined $index )
		{
			$message .= "A new zevenet-web-gui hotfix is avaliable\n";
			splice @{ $packages }, $index, 1;

			# &zenlog( "A new zevenet-web-gui hotfix is avaliable", "INFO", "alert" );
		}

		$index = &getARRIndex( $packages, 'zproxy' );
		if ( defined $index )
		{
			$message .= "A new zproxy hotfix is avaliable\n";
			splice @{ $packages }, $index, 1;

			# &zenlog( "A new zproxy hotfix is avaliable", "INFO", "alert" );
		}

		$index = &getARRIndex( $packages, 'nftlb' );
		if ( defined $index )
		{
			$message .= "A new nftlb hotfix is avaliable\n";
			splice @{ $packages }, $index, 1;

			# &zenlog( "A new nftlb hotfix is avaliable", "INFO", "alert" );
		}

		my $length = @{ $packages };
		if ( scalar @{ $packages } > 0 )
		{
			$message .= "New package updates are available.\t" . "List:";
			foreach my $package ( @{ $packages } )
			{
				$message .= "\t$package";
			}

			# &zenlog( "New package updates are available", "INFO", "alert" );
		}
	}

	return $message;
}

1;
