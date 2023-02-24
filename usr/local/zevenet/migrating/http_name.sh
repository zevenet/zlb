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

source /usr/local/zevenet/bin/load_global_conf
load_global_conf

name="Name"

for i in $(find /usr/local/zevenet/config/ -name "*_proxy.cfg" -or -name "*_pound.cfg");
do
	echo "Checking Name directive in farm config file: $i"
	grep "^Name.*" $i &>/dev/null
	if [[ $? != 0 ]];then
		echo "Adding directive 'Name' to farm config file: $i" 
		fname=`echo $i | cut -d"_" -f1 | cut -d"/" -f6`
		sed -i "/^Group/ a$name\t\t$fname" $i
	fi
done
