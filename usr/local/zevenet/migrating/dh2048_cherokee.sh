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

#Add DH param to 2048 in cherokee conf

cherokee_conf="/usr/local/zevenet/app/cherokee/etc/cherokee/cherokee.conf"

if [[ ! `grep "^vserver\!1\!ssl_dh_length.*" $cherokee_conf` ]]; then
	echo "DH param not found in cherokee conf, adding"
	sed -i '/server!user = root/a vserver!1!ssl_dh_length = 2048' $cherokee_conf
fi


