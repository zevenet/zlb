#!/usr/bin/perl

use strict;
use Zevenet::Config;
use Zevenet::Net::Interface;
use Zevenet::Validate;
use Zevenet::Log;
use feature qw( say );
use Config::Tiny;

my $iface_files_dir = "/usr/local/zevenet/config";
my @iface_files;
opendir ( my $dir, $iface_files_dir );
@iface_files =
  grep { /^if_.*_conf/ && -f "$iface_files_dir/$_" } readdir ( $dir );
closedir $dir;

foreach my $file ( @iface_files )
{
	#Parse filename to obtain file
	$file =~ /if_(?<iface>.*)_conf/;
	my $iface = $+{ iface };

	#Trying to read, set the errstr error if in tiny format
	my $iface_file = Config::Tiny->read( "$iface_files_dir/$file" );

#Don't migrate if is in tiny format ( there is no error when reading and the section is defined )
	next
	  if ( !( Config::Tiny->errstr =~ /$iface/ )
		   && defined $iface_file->{ $iface } );

	&zenlog( "Migrating $iface configuration files", "info", "NETWORK" );

	#Is not in Tiny format, if unset, delete file, if set, parse the file
	say "File $file not in tiny format";
	my $if_ref = &_getInterfaceConfig( $iface );

	unlink "$iface_files_dir/$file";

	#Setted
	require Zevenet::Net::Interface;
	&setInterfaceConfig( $if_ref ) if ( defined $if_ref );
}
&zenlog( "Interfaces configuration migration finished", "info", "NETWORK" );

sub _getInterfaceConfig    # \%iface ($if_name, $ip_version)
{
	&zenlog( __FILE__ . ":" . __LINE__ . ":" . ( caller ( 0 ) )[3] . "( @_ )",
			 "debug", "PROFILING" );
	my ( $if_name ) = @_;

	unless ( defined $if_name )
	{
		&zenlog( 'getInterfaceConfig got undefined interface name',
				 'debug2', 'network' );
	}

	#~ &zenlog( "[CALL] getInterfaceConfig( $if_name )" );

	my $ip_version;
	my $if_line;
	my $if_status;
	my $configdir       = &getGlobalConfiguration( 'configdir' );
	my $config_filename = "$configdir/if_${if_name}_conf";

	if ( open my $file, '<', "$config_filename" )
	{
		my @lines = grep { !/^(\s*#|$)/ } <$file>;

		for my $line ( @lines )
		{
			my ( undef, $ip ) = split ';', $line;

			if ( defined $ip )
			{
				$ip_version =
				    ( $ip =~ /:/ )  ? 6
				  : ( $ip =~ /\./ ) ? 4
				  :                   undef;
			}

			if ( defined $ip_version && !$if_line )
			{
				$if_line = $line;
			}
			elsif ( $line =~ /^status=/ )
			{
				$if_status = $line;
				$if_status =~ s/^status=//;
				chomp $if_status;
			}
		}
		close $file;
	}

	# includes !$if_status to avoid warning
	if ( !$if_line && ( !$if_status || $if_status !~ /up/ ) )
	{
		return;
	}

	chomp ( $if_line );
	my @if_params = split ( ';', $if_line );

	# Example: eth0;10.0.0.5;255.255.255.0;up;10.0.0.1;

	require IO::Socket;
	my $socket = IO::Socket::INET->new( Proto => 'udp' );

	my %iface;

	$iface{ name }    = shift @if_params // $if_name;
	$iface{ addr }    = shift @if_params;
	$iface{ mask }    = shift @if_params;
	$iface{ gateway } = shift @if_params;                            # optional
	$iface{ status }  = $if_status;
	$iface{ dev }     = $if_name;
	$iface{ vini }    = undef;
	$iface{ vlan }    = undef;
	$iface{ mac }     = undef;
	$iface{ type }    = &getInterfaceType( $if_name );
	$iface{ parent }  = &getParentInterfaceName( $iface{ name } );
	$iface{ ip_v } =
	  ( $iface{ addr } =~ /:/ ) ? '6' : ( $iface{ addr } =~ /\./ ) ? '4' : 0;
	$iface{ net } =
	  &getAddressNetwork( $iface{ addr }, $iface{ mask }, $iface{ ip_v } );

	if ( $iface{ dev } =~ /:/ )
	{
		( $iface{ dev }, $iface{ vini } ) = split ':', $iface{ dev };
	}

	if ( !$iface{ name } )
	{
		$iface{ name } = $if_name;
	}

	if ( $iface{ dev } =~ /./ )
	{
		# dot must be escaped
		( $iface{ dev }, $iface{ vlan } ) = split '\.', $iface{ dev };
	}

	$iface{ mac } = $socket->if_hwaddr( $iface{ dev } );

	# Interfaces without ip do not get HW addr via socket,
	# in those cases get the MAC from the OS.
	unless ( $iface{ mac } )
	{
		open my $fh, '<', "/sys/class/net/$if_name/address";
		chomp ( $iface{ mac } = <$fh> );
		close $fh;
	}

	# complex check to avoid warnings
	if (
		 (
		      !exists ( $iface{ vini } )
		   || !defined ( $iface{ vini } )
		   || $iface{ vini } eq ''
		 )
		 && $iface{ addr }
	  )
	{
		require Config::Tiny;
		my $float = Config::Tiny->read( &getGlobalConfiguration( 'floatfile' ) );

		$iface{ float } = $float->{ _ }->{ $iface{ name } } // '';
	}

	# for virtual interface, overwrite mask and gw with parent values
	if ( $iface{ type } eq 'vini' )
	{
		my $if_parent = &getInterfaceConfig( $iface{ parent } );
		$iface{ mask }    = $if_parent->{ mask };
		$iface{ gateway } = $if_parent->{ gateway };
	}

	return \%iface;
}
