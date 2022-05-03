#!/bin/bash

#Add DH param to 2048 in cherokee conf

cherokee_conf="/usr/local/zevenet/app/cherokee/etc/cherokee/cherokee.conf"

if [[ ! `grep "^vserver\!1\!ssl_dh_length.*" $cherokee_conf` ]]; then
	echo "DH param not found in cherokee conf, adding"
	sed -i '/server!user = root/a vserver!1!ssl_dh_length = 2048' $cherokee_conf
fi


