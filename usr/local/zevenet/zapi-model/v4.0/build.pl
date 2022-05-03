#!/usr/bin/perl

# It use the tpl JSON to create the validation model JSON.
# Review:
# 	backslash the typedef regex
#	replace macro by regex
#  	not to allow function option 'function'
#	ask for parameter description
#	check all options are valid

use strict;
no strict 'refs';
use feature "say";

require JSON;

my $DIR = ".";
my $err = system ( "$DIR/format_tpl.sh" );
exit 1 if $err;

require "$DIR/regexp";
require "$DIR/descriptions";

# backslash
open my $fh, '<', "$DIR/regexp";
my $l;
while ( $l = <$fh> )
{
	if ( $l =~ /^\s*our\s+\$(\w+)[\s=]/ )
	{
		${ $1 } =~ s/\\/\\\\/g;
	}

	#~ ${$1} =~ s/\(\?\^:/\(\?:/g;
}
close $fh;

my $jsondir = "$DIR/json";
my $tpldir  = "$DIR/tpl";

if ( -d $jsondir )
{
	say "Clean the $jsondir directory";
	say "";
	system ( "rm -rf $jsondir" );
}
mkdir $jsondir;

opendir ( my $dh, $tpldir );

while ( my $file = readdir ( $dh ) )
{
	next if ( $file =~ /^\./ );
	say "Managing: $file";

	open ( my $tpl_fh, '<', "$tpldir/$file" );
	undef $/;
	my $content = <$tpl_fh>;
	close $tpl_fh;

	if ( $content =~ /\?\?\?/ )
	{
		say "Error ($file): found '???'";
		exit 1;
	}

	$content =~ s/\$(\w+)\b/${$1}/g;

	if ( $content =~ /"function"/ )
	{
		say
		  "Error ($file): found a 'function' parameter in the params list struct that is deprecated";
		exit 1;
	}

	print $content;
	my $json = JSON::decode_json( $content );

	foreach my $p ( keys %{ $json->{ params } } )
	{
		#~ if (!exists $json->{params}->{$p}->{description} ||
		#~#    ! $json->{params}->{$p}->{description})
		#~ {
		#~ say "Error ($file): the parameter '$p' does not have description";
		#~ exit 1;
		#~ }
		my @json_err = grep (
			!/^(depend_on_msg|deprecated|edition|depend_on|description|format_msg|ref|regex|negated_regex|is_regex|length|dyn_values|values|exceptions|interval|non_blank|required)$/,
			keys %{ $json->{ params }->{ $p } } );
		if ( @json_err )
		{
			print
			  "Error ($file): The following options of '$p' are not expected in a validation model: ";
			print "$_, " for ( @json_err );
			say "";
			exit 1;
		}
	}

	open ( my $json_fh, '>', "$jsondir/$file" );
	print $json_fh JSON::to_json( $json,
								  { utf8 => 1, pretty => 1, canonical => 1 } );
	close $json_fh;
}

closedir $dh;

say "";
say "JSON validation structs were created successful: $jsondir";
say "SUCCESS!";
exit 0;

# ??? add automatically MACRO_format: en zcli
# ??? modelar 'values' cuando lo define la API

