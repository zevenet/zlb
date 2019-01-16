#!/usr/bin/perl

require Config::Tiny;
require Zevenet::Log;

my $bl_dir  = "/usr/local/zevenet/config/ipds/blacklists";
my $bl_conf = "$bl_dir/lists.conf";
my $err     = 0;

# remove testing list
my $bl = Config::Tiny->read( $bl_conf );

if ( exists $bl->{ test } and $bl->{ test }->{ farms } =~ /\bprueba\b/ )
{
	print "Removing the blacklist 'test'\n";
	&zenlog( "Removing the blacklist 'test'" );
	$err++ unless ( unlink "${bl_dir}/lists/test.conf" );
	delete $bl->{ test };
	$err++ unless ( $bl->write( $bl_conf ) );
}

exit $err;
