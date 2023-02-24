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

# Migrate pound config file to l7 proxy config file
for i in $(find /usr/local/zevenet/config/ -name "*pound.cfg");
do
	echo "Migrating config file $i from pound to l7 proxy"

	sed -i -e 's/pound.socket/proxy.socket/' $i
	sed -i -E 's/^LogLevel\s+0/LogLevel\t5/g' $i

	mv "$i" "$(echo "$i" | sed s/pound.cfg/proxy.cfg/)"
done
