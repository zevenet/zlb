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

# Param Alive has to be grater than ConnTO in zproxy configuration file.

source /usr/local/zevenet/bin/load_global_conf
load_global_conf

for i in $(find /usr/local/zevenet/config/ -name "*_proxy.cfg");
do
	if [[ ! `grep -E "^Alive " $i` ]]; then
		if [[ ! `grep -E "^ConnTO " $i` ]]; then
			alive_param=`grep -E "^Alive" $i | cut -f3`
			connto_param=`grep -E "^ConnTO" $i | cut -f3`
			if [ $alive_param -le $connto_param ]; then
				alive_param=$((connto_param + 1)) 
				echo "Replacing directive 'Alive' to farm $i"
				sed -Ei "s/^Alive\s+[0-9]+/Alive\t\t$alive_param/" $i
			fi
		fi
	fi
done
