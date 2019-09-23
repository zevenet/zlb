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

my $q = getCGI();

# Certificates
my $cert_re     = &getValidFormat( 'certificate' );
my $cert_pem_re = &getValidFormat( 'cert_pem' );

if ( $q->path_info =~ qr{^/certificates} )
{
	require Zevenet::API40::Certificate;

	#  GET List SSL certificates
	GET qr{^/certificates$} => \&certificates;

	#  Download SSL certificate
	GET qr{^/certificates/($cert_re)$} => \&download_certificate;

	#  Create CSR certificates
	POST qr{^/certificates$} => \&create_csr;

	#  POST certificates
	POST qr{^/certificates/($cert_pem_re)$} => \&upload_certificate;

	#  DELETE certificate
	DELETE qr{^/certificates/($cert_re)$} => \&delete_certificate;
}

# Farms
my $farm_re    = &getValidFormat( 'farm_name' );
my $service_re = &getValidFormat( 'service' );
my $be_re      = &getValidFormat( 'backend' );
my $fg_name_re = &getValidFormat( 'fg_name' );

if ( $q->path_info =~ qr{^/farms/$farm_re/certificates} )
{
	require Zevenet::API40::Certificate;

	POST qr{^/farms/($farm_re)/certificates$} => \&add_farm_certificate;

	DELETE qr{^/farms/($farm_re)/certificates/($cert_pem_re)$} =>
	  \&delete_farm_certificate;
}

# Farmguardian
if (    $q->path_info =~ qr{^/monitoring/fg}
	 or $q->path_info =~ qr{^/farms/$farm_re(?:/services/$service_re)?/fg} )
{
	require Zevenet::API40::Farm::Guardian;

	POST qr{^/farms/($farm_re)(?:/services/($service_re))?/fg$} =>
	  \&add_farmguardian_farm;
	DELETE qr{^/farms/($farm_re)(?:/services/($service_re))?/fg/($fg_name_re)$} =>
	  \&rem_farmguardian_farm;

	GET qr{^/monitoring/fg$}                  => \&list_farmguardian;
	POST qr{^/monitoring/fg$}                 => \&create_farmguardian;
	GET qr{^/monitoring/fg/($fg_name_re)$}    => \&get_farmguardian;
	PUT qr{^/monitoring/fg/($fg_name_re)$}    => \&modify_farmguardian;
	DELETE qr{^/monitoring/fg/($fg_name_re)$} => \&delete_farmguardian;
}

if ( $q->path_info =~ qr{^/farms/$farm_re/actions} )
{
	require Zevenet::API40::Farm::Action;

	PUT qr{^/farms/($farm_re)/actions$} => \&farm_actions;
}

if ( $q->path_info =~ qr{^/farms/$farm_re.*/backends/$be_re/maintenance} )
{
	require Zevenet::API40::Farm::Action;

	PUT qr{^/farms/($farm_re)/services/($service_re)/backends/($be_re)/maintenance$}
	  => \&service_backend_maintenance;    #  (HTTP only)

	PUT qr{^/farms/($farm_re)/backends/($be_re)/maintenance$} =>
	  \&backend_maintenance;               #  (L4xNAT only)
}

if ( $q->path_info =~ qr{^/farms/$farm_re(?:/services/$service_re)?/backends} )
{
	require Zevenet::API40::Farm::Backend;

	GET qr{^/farms/($farm_re)/backends$} => \&backends;

	POST qr{^/farms/($farm_re)/backends$} => \&new_farm_backend;

	PUT qr{^/farms/($farm_re)/backends/($be_re)$} => \&modify_backends;

	DELETE qr{^/farms/($farm_re)/backends/($be_re)$} => \&delete_backend;

	GET qr{^/farms/($farm_re)/services/($service_re)/backends$} =>
	  \&service_backends;

	POST qr{^/farms/($farm_re)/services/($service_re)/backends$} =>
	  \&new_service_backend;

	PUT qr{^/farms/($farm_re)/services/($service_re)/backends/($be_re)$} =>
	  \&modify_service_backends;

	DELETE qr{^/farms/($farm_re)/services/($service_re)/backends/($be_re)$} =>
	  \&delete_service_backend;
}

if ( $q->path_info =~ qr{^/farms/$farm_re/services} )
{
	require Zevenet::API40::Farm::Service;

	POST qr{^/farms/($farm_re)/services$}                 => \&new_farm_service;
	GET qr{^/farms/($farm_re)/services/($service_re)$}    => \&farm_services;
	PUT qr{^/farms/($farm_re)/services/($service_re)$}    => \&modify_services;
	DELETE qr{^/farms/($farm_re)/services/($service_re)$} => \&delete_service;
}

if ( $q->path_info =~ qr{^/farms} )
{
	if ( $ENV{ REQUEST_METHOD } eq 'GET' )
	{
		require Zevenet::API40::Farm::Get;

		##### /farms
		GET qr{^/farms$} => \&farms;

		##### /farms/modules/MODULE
		GET qr{^/farms/modules/summary$} => \&farms_module_summary;
		GET qr{^/farms/modules/lslb$}    => \&farms_lslb;
		GET qr{^/farms/modules/dslb$}    => \&farms_dslb;

		##### /farms/FARM/summary
		GET qr{^/farms/($farm_re)/summary$} => \&farms_name_summary;

		##### /farms/FARM
		GET qr{^/farms/($farm_re)$} => \&farms_name;
	}

	if ( $ENV{ REQUEST_METHOD } eq 'POST' )
	{
		require Zevenet::API40::Farm::Post;
		##### /farms
		POST qr{^/farms$} => \&new_farm;
	}

	if ( $ENV{ REQUEST_METHOD } eq 'PUT' )
	{
		require Zevenet::API40::Farm::Put;

		##### /farms/FARM
		PUT qr{^/farms/($farm_re)$} => \&modify_farm;
	}

	if ( $ENV{ REQUEST_METHOD } eq 'DELETE' )
	{
		require Zevenet::API40::Farm::Delete;

		##### /farms/FARM
		DELETE qr{^/farms/($farm_re)$} => \&delete_farm;
	}
}

# Network Interfaces
my $nic_re  = &getValidFormat( 'nic_interface' );
my $bond_re = &getValidFormat( 'bond_interface' );
my $vlan_re = &getValidFormat( 'vlan_interface' );

if ( $q->path_info =~ qr{^/interfaces/nic} )
{
	require Zevenet::API40::Interface::NIC;

	GET qr{^/interfaces/nic$}                    => \&get_nic_list;
	GET qr{^/interfaces/nic/($nic_re)$}          => \&get_nic;
	PUT qr{^/interfaces/nic/($nic_re)$}          => \&modify_interface_nic;
	DELETE qr{^/interfaces/nic/($nic_re)$}       => \&delete_interface_nic;
	POST qr{^/interfaces/nic/($nic_re)/actions$} => \&actions_interface_nic;
}

if ( $q->path_info =~ qr{^/interfaces/vlan} )
{
	require Zevenet::API40::Interface::VLAN;

	GET qr{^/interfaces/vlan$}                     => \&get_vlan_list;
	POST qr{^/interfaces/vlan$}                    => \&new_vlan;
	GET qr{^/interfaces/vlan/($vlan_re)$}          => \&get_vlan;
	PUT qr{^/interfaces/vlan/($vlan_re)$}          => \&modify_interface_vlan;
	DELETE qr{^/interfaces/vlan/($vlan_re)$}       => \&delete_interface_vlan;
	POST qr{^/interfaces/vlan/($vlan_re)/actions$} => \&actions_interface_vlan;
}

if ( $q->path_info =~ qr{^/interfaces/virtual} )
{
	require Zevenet::API40::Interface::Virtual;

	GET qr{^/interfaces/virtual$}  => \&get_virtual_list;
	POST qr{^/interfaces/virtual$} => \&new_vini;

	my $virtual_re = &getValidFormat( 'virt_interface' );

	GET qr{^/interfaces/virtual/($virtual_re)$}    => \&get_virtual;
	PUT qr{^/interfaces/virtual/($virtual_re)$}    => \&modify_interface_virtual;
	DELETE qr{^/interfaces/virtual/($virtual_re)$} => \&delete_interface_virtual;
	POST qr{^/interfaces/virtual/($virtual_re)/actions$} =>
	  \&actions_interface_virtual;
}

if ( $q->path_info =~ qr{^/interfaces/gateway(?:/ipv([46]))?$} )
{
	require Zevenet::API40::Interface::Gateway;

	GET qr{^/interfaces/gateway(?:/ipv([46]))?$}    => \&get_gateway;
	PUT qr{^/interfaces/gateway(?:/ipv([46]))?$}    => \&modify_gateway;
	DELETE qr{^/interfaces/gateway(?:/ipv([46]))?$} => \&delete_gateway;
}

if ( $q->path_info =~ qr{^/interfaces$} )
{
	require Zevenet::API40::Interface::Generic;

	GET qr{^/interfaces$} => \&get_interfaces;
}

# Statistics
if ( $q->path_info =~ qr{^/stats} )
{
	require Zevenet::API40::Stats;

	# System stats
	GET qr{^/stats$}                => \&stats;
	GET qr{^/stats/system/network$} => \&stats_network;

	# Farm stats
	GET qr{^/stats/farms$}                     => \&all_farms_stats;
	GET qr{^/stats/farms/($farm_re)$}          => \&farm_stats;
	GET qr{^/stats/farms/($farm_re)/backends$} => \&farm_stats;

	# Fixed: make 'service' or 'services' valid requests for compatibility
	# with previous bug.
	GET qr{^/stats/farms/($farm_re)/services?/($service_re)/backends$} =>
	  \&farm_stats;
}

# Graphs
if ( $q->path_info =~ qr{^/graphs} )
{
	require Zevenet::API40::Graph;

	my $frequency_re = &getValidFormat( 'graphs_frequency' );
	my $system_id_re = &getValidFormat( 'graphs_system_id' );

	#  GET possible graphs
	GET qr{^/graphs$} => \&possible_graphs;

	##### /graphs/system
	#  GET all possible system graphs
	GET qr{^/graphs/system$} => \&get_all_sys_graphs;

	#  GET system graphs
	GET qr{^/graphs/system/($system_id_re)$} => \&get_sys_graphs;

	#  GET frequency system graphs
	GET qr{^/graphs/system/($system_id_re)/($frequency_re)$} =>
	  \&get_frec_sys_graphs;

	##### /graphs/system/disk

	# $disk_re includes 'root' at the beginning
	my $disk_re = &getValidFormat( 'mount_point' );

	GET qr{^/graphs/system/disk$} => \&list_disks;

	# keep before next request
	GET qr{^/graphs/system/disk/($disk_re)/($frequency_re)$} =>
	  \&graph_disk_mount_point_freq;

	GET qr{^/graphs/system/disk/($disk_re)$} => \&graphs_disk_mount_point_all;

	##### /graphs/interfaces

	#  GET all posible interfaces graphs
	GET qr{^/graphs/interfaces$} => \&get_all_iface_graphs;

	#  GET interfaces graphs
	GET qr{^/graphs/interfaces/($nic_re|$vlan_re)$} => \&get_iface_graphs;

	#  GET frequency interfaces graphs
	GET qr{^/graphs/interfaces/($nic_re)/($frequency_re)$} =>
	  \&get_frec_iface_graphs;

	##### /graphs/farms

	#  GET all posible farm graphs
	GET qr{^/graphs/farms$} => \&get_all_farm_graphs;

	#  GET farm graphs
	GET qr{^/graphs/farms/($farm_re)$} => \&get_farm_graphs;

	#  GET frequency farm graphs
	GET qr{^/graphs/farms/($farm_re)/($frequency_re)$} => \&get_frec_farm_graphs;
}

# System
if ( $q->path_info =~ qr{^/system/dns} )
{
	require Zevenet::API40::System::Service::DNS;

	GET qr{^/system/dns$}  => \&get_dns;
	POST qr{^/system/dns$} => \&set_dns;
}

if ( $q->path_info =~ qr{^/system/snmp} )
{
	require Zevenet::API40::System::Service::SNMP;

	GET qr{^/system/snmp$}  => \&get_snmp;
	POST qr{^/system/snmp$} => \&set_snmp;
}

if ( $q->path_info =~ qr{^/system/ntp} )
{
	require Zevenet::API40::System::Service::NTP;

	GET qr{^/system/ntp$}  => \&get_ntp;
	POST qr{^/system/ntp$} => \&set_ntp;
}

if ( $q->path_info =~ qr{^/system/users} )
{
	require Zevenet::API40::System::User;

	GET qr{^/system/users$}  => \&get_system_user;    #  GET users
	POST qr{^/system/users$} => \&set_system_user;    #  POST users
}

if ( $q->path_info =~ qr{^/system/log} )
{
	require Zevenet::API40::System::Log;

	GET qr{^/system/logs$} => \&get_logs;

	my $logs_re = &getValidFormat( 'log' );
	GET qr{^/system/logs/($logs_re)$} => \&download_logs;

	GET qr{^/system/logs/($logs_re)/lines/(\d+)$} => \&show_logs;

}

if ( $q->path_info =~ qr{^/system/backup} )
{
	require Zevenet::API40::System::Backup;

	GET qr{^/system/backup$}  => \&get_backup;       #  GET list backups
	POST qr{^/system/backup$} => \&create_backup;    #  POST create backups

	my $backup_re = &getValidFormat( 'backup' );
	GET qr{^/system/backup/($backup_re)$} =>
	  \&download_backup;                             #  GET download backups
	PUT qr{^/system/backup/($backup_re)$} => \&upload_backup; #  PUT  upload backups
	DELETE qr{^/system/backup/($backup_re)$} => \&del_backup; #  DELETE  backups
	POST qr{^/system/backup/($backup_re)/actions$} =>
	  \&apply_backup;                                         #  POST  apply backups
}

if (
	 $q->path_info =~ qr{^/system/(?:version|info|license|supportsave|language)} )
{
	require Zevenet::API40::System::Info;

	GET qr{^/system/version$}     => \&get_version;
	GET qr{^/system/info$}        => \&get_system_info;
	GET qr{^/system/supportsave$} => \&get_supportsave;

	my $license_re = &getValidFormat( 'license_format' );
	GET qr{^/system/license/($license_re)$} => \&get_license;

	POST qr{^/system/language$} => \&set_language;
}

if ( $q->path_info =~ qr{/ciphers$} )
{
	require Zevenet::API40::Certificate;

	GET qr{^/ciphers$} => \&ciphers_available;
}

##### Load modules dynamically #######################################
my $routes_path = &getGlobalConfiguration( 'zlibdir' ) . '/API40/Routes';
opendir ( my $dir, $routes_path );
foreach my $file ( readdir $dir )
{
	next if $file !~ /\w\.pm$/;

	my $module = "$routes_path/$file";

	unless ( eval { require $module; } )
	{
		&zenlog( $@, "error", "SYSTEM" );
		die $@;
	}
}

1;
