#!/bin/bash

# Migrate zhttp config file to l7 proxy config file
for i in $(find /usr/local/zevenet/config/ -name "*_proxy.cfg");
do
	if grep -Eq 'LogLevel\s+0' $i; then
		echo "Enabling logs for file $i"
		sed -i -E 's/LogLevel\s+0/LogLevel 	5/' $i
	fi
done
