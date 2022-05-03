#!/bin/bash

###############################################################################
#
#    Zevenet Software License
#    This file is part of the Zevenet Load Balancer software package.
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

#Replace default snmpd Log Level -Lsd to -LS6d

snmpd_conf="/lib/systemd/system/snmpd.service"

if [[ `grep " -Lsd " $snmpd_conf` ]]; then
	echo -n "Replacing Snmpd Log Level "
	sed -i -e 's/ -Lsd / -LS6d /' $snmpd_conf
	if [ $? == 0 ]; then
		echo " OK";
	else
		echo " ERROR";
	fi
fi

