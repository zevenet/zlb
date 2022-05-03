#!/bin/bash

# Migrate pound config file to l7 proxy config file
for i in $(find /usr/local/zevenet/config/ -name "*pound.cfg");
do
	echo "Migrating config file $i from pound to l7 proxy"

	sed -i -e 's/pound.socket/proxy.socket/' $i
	sed -i -E 's/^LogLevel\s+0/LogLevel\t5/g' $i

	mv "$i" "$(echo "$i" | sed s/pound.cfg/proxy.cfg/)"
done
