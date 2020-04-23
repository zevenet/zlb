#!/bin/bash

# Migrate certificates files to new directory
mv /usr/local/zevenet/config/{*.pem,*.csr,*.key} /usr/local/zevenet/config/certificates/ 2>/dev/null

# Migrate certificate of farm config file
for i in $(find /usr/local/zevenet/config/ -name "*_proxy.cfg" -o -name "*_pound.cfg");
do
	if grep 'Cert \"\/usr\/local\/zevenet\/config\/\w.*\.pem' $i | grep -qv certificates; then
		echo "Migrating certificate directory of config file"
		sed -i -e 's/Cert \"\/usr\/local\/zevenet\/config/Cert \"\/usr\/local\/zevenet\/config\/certificates/' $i
	fi
done

# Migrate http server certificate
http_conf="/usr/local/zevenet/app/cherokee/etc/cherokee/cherokee.conf"

grep -E "/usr/local/zevenet/config/[^\/]+.pem" $http_conf
if [ $? -eq 0 ]; then
	echo "Migrating certificate of http server"
	perl -E '
use strict;
use Tie::File;
tie my @fh, "Tie::File", "/usr/local/zevenet/app/cherokee/etc/cherokee/cherokee.conf";
foreach my $line (@fh)
{
	if ($line =~ m"/usr/local/zevenet/config/[^/]+\.(pem|csr|key)" )
	{

		unless( $line =~ s"/usr/local/zevenet/config"/usr/local/zevenet/config/certificates"m)
		{
			say "Error modifying: >$line<";
		}
		say "migrated $line";
	}
}
close @fh;
	'
fi

