#!/bin/bash
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

