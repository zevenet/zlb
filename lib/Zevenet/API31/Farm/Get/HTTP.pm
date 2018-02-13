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
use Zevenet::Farm::HTTP::Config;
use Zevenet::Farm::HTTP::Service;

# GET /farms/<farmname> Request info of a http|https Farm
sub farms_name_http # ( $farmname )
{
	my $farmname = shift;

	my @out_s;
	my @out_cn;
	my $connto          = 0 + &getFarmConnTO( $farmname );
	my $timeout         = 0 + &getHTTPFarmTimeout( $farmname );
	my $alive           = 0 + &getHTTPFarmBlacklistTime( $farmname );
	my $client          = 0 + &getFarmClientTimeout( $farmname );
	my $conn_max        = 0 + &getHTTPFarmMaxConn( $farmname );
	my $rewritelocation = 0 + &getFarmRewriteL( $farmname );
	my $httpverb        = 0 + &getFarmHttpVerb( $farmname );

	if    ( $rewritelocation == 0 ) { $rewritelocation = "disabled"; }
	elsif ( $rewritelocation == 1 ) { $rewritelocation = "enabled"; }
	elsif ( $rewritelocation == 2 ) { $rewritelocation = "enabled-backends"; }

	if    ( $httpverb == 0 ) { $httpverb = "standardHTTP"; }
	elsif ( $httpverb == 1 ) { $httpverb = "extendedHTTP"; }
	elsif ( $httpverb == 2 ) { $httpverb = "standardWebDAV"; }
	elsif ( $httpverb == 3 ) { $httpverb = "MSextWebDAV"; }
	elsif ( $httpverb == 4 ) { $httpverb = "MSRPCext"; }

	my $type    = &getFarmType( $farmname );
	my $certname;
	my $cipher  = '';
	my $ciphers = 'all';
	my @cnames;

	if ( $type eq "https" )
	{
		require Zevenet::Farm::HTTP::HTTPS;

		if ( eval { require Zevenet::Farm::HTTP::HTTPS::Ext; } )
		{
			@cnames = &getFarmCertificatesSNI( $farmname );
		}
		else
		{
			@cnames = ( &getFarmCertificate( $farmname ) );
		}

		for ( my $i = 0 ; $i < scalar @cnames ; $i++ )
		{
			push @out_cn, { file => $cnames[$i], id => $i + 1 };
		}

		$cipher  = &getFarmCipherList( $farmname );
		$ciphers = &getFarmCipherSet( $farmname );
		chomp ( $ciphers );

		# adapt "ciphers" to required interface values
		if ( $ciphers eq "cipherglobal" )
		{
			$ciphers = "all";
		}
		elsif ( $ciphers eq "ciphercustom" )
		{
			$ciphers = "customsecurity";
		}
		elsif ( $ciphers eq "cipherpci" )
		{
			$ciphers = "highsecurity";
		}
	}

	my $vip   = &getFarmVip( "vip",  $farmname );
	my $vport = 0 + &getFarmVip( "vipp", $farmname );

	my $err414 = &getFarmErr( $farmname, "414" );
	my $err500 = &getFarmErr( $farmname, "500" );
	my $err501 = &getFarmErr( $farmname, "501" );
	my $err503 = &getFarmErr( $farmname, "503" );

	my $status = &getFarmVipStatus( $farmname );

	my $output_params = {
						  status              => $status,
						  restimeout          => $timeout,
						  contimeout          => $connto,
						  resurrectime        => $alive,
						  reqtimeout          => $client,
						  rewritelocation     => $rewritelocation,
						  httpverb            => $httpverb,
						  listener            => $type,
						  vip                 => $vip,
						  vport               => $vport,
						  error500            => $err500,
						  error414            => $err414,
						  error501            => $err501,
						  error503            => $err503
	};

	my $EE = eval { require Zevenet::HTTP::Ext; } ? 1 : undef;

	if ( $EE )
	{
		$output_params->{ ignore_100_continue } =
		  ( &getHTTPFarm100Continue( $farmname ) ) ? "true" : "false";
	}

	if ( $type eq "https" )
	{
		$output_params->{ certlist } = \@out_cn;
		$output_params->{ ciphers }  = $ciphers;
		$output_params->{ cipherc }  = $cipher;
		$output_params->{ disable_sslv2 } = ( &getHTTPFarmDisableSSL($farmname, "SSLv2") )? "true": "false";
		$output_params->{ disable_sslv3 } = ( &getHTTPFarmDisableSSL($farmname, "SSLv3") )? "true": "false";
		$output_params->{ disable_tlsv1 } = ( &getHTTPFarmDisableSSL($farmname, "TLSv1") )? "true": "false";
		$output_params->{ disable_tlsv1_1 } = ( &getHTTPFarmDisableSSL($farmname, "TLSv1_1") )? "true": "false";
		$output_params->{ disable_tlsv1_2 } = ( &getHTTPFarmDisableSSL($farmname, "TLSv1_2") )? "true": "false";
	}

	# Services
	my $services = &getHTTPFarmVS( $farmname, '', '' );
	my @serv = split ( ' ', $services );

	foreach my $s ( @serv )
	{
		my $serviceStruct = &getHTTPServiceStruct ( $farmname, $s );

		# Remove backend status 'undefined', it is for news api versions
		foreach my $be (@{$serviceStruct->{ 'backends' }})
		{
			$be->{ 'status' } = 'up'  if ($be->{ 'status' } eq 'undefined');
		}

		push @out_s, $serviceStruct;
	}

	my $body = {
				 description => "List farm $farmname",
				 params      => $output_params,
				 services    => \@out_s,
	};

	if ( eval{ require Zevenet::IPDS::Core; } )
	{
		$body->{ ipds } = &getIPDSfarmsRules( $farmname );
	}

	&httpResponse({ code => 200, body => $body });
}

1;
