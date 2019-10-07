#!/bin/bash

# Migrate pound config file to zhttp config file
for i in $(find /usr/local/zevenet/config/ -name "*pound.cfg");
do
	echo "Migrating config file $i from pound to zhttp"
	sed -i -e 's/pound.socket/proxy.socket/' $i
	sed -i -e 's/pound\/etc/zhttp\/etc/' $i
	mv "$i" "$(echo "$i" | sed s/pound.cfg/proxy.cfg/)"
done
