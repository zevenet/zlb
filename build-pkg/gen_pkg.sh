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

# Exit at the first error
set -e

BASE_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"
DATE=$(date +%y%m%d_%H%M%S)
arch="amd64"

# Default options
devel="false"

function print_usage_and_exit() {
	echo "Usage: $(basename "$0") <distribution> [options]"

	echo "	-d		Debug logs"
	echo "	-v		Indicate package version"
	exit 1
}

function msg() {
	echo -e "\n#### ${1} ####\n"
}

function die() {
	local bldred='\e[1;31m' # Red bold text
	local txtrst='\e[0m'    # Text Reset

	msg "${bldred}Error${txtrst}${1}"
	exit 1
}

# Gets version
function getVersion() {
	# Include aliases.
	bash_aliases_file="/root/.bash_aliases"

	if [ -z ${version} ]; then
		if [ -f $bash_aliases_file ]; then
			shopt -s expand_aliases
			source $bash_aliases_file
			# alias
			version=`zevenet-tag_devel-5.13`
		else
			echo "It has not been possible to obtain the version automatically."
			echo "Please enter the version manually. Example: 5.13.0"
			read manual_version
			if [ -z $manual_version ]; then
				echo "*** aborted ***"
				exit 1
			else
				version=$manual_version
			fi
		fi
	fi
}

##### Parse command arguments #####

# Distribution parameter (-i or -u) is not optional show
# how to use the command if no distribution was selected
# Parse parameters.
while getopts "d:v:h" arg; do
	case $arg in
		d)
		devel="true"
		;;
		v)
		version=$OPTARG
		;;
		h)
		print_usage_and_exit
		;;
		*)
		print_usage_and_exit
		;;
	esac
done



#### Initial setup ####

# Setup a clean environment
cd "$BASE_DIR"
msg "Setting up a clean environment..."
rm -rf workdir
mkdir workdir
rsync -a --exclude "/$(basename "$BASE_DIR")" ../* workdir/
cd workdir

# Set version and package name
getVersion
pkgname_prefix="zevenet_${version}_${arch}"

if [[ "$devel" == "false" ]]; then
	pkgname=${pkgname_prefix}_${distribution}_${DATE}.deb
else
	pkgname=${pkgname_prefix}_DEV_${distribution}_${DATE}.deb
fi

# set version in global.conf tpl
globalconftpl='usr/local/zevenet/share/global.conf.template'
version_string='$version="_VERSION_";'
sed -i "s/$version_string/\$version=\"$version\";/" $globalconftpl


#### Package preparation ####

msg "Preparing package..."

# Remove .keep files
find . -name .keep -exec rm {} \;


# Release or development
if [[ $devel == "false" ]]; then
	msg "Removing warnings and profiling instrumentation..."
	# Don't include API 3
	find -L usr/local/zevenet/bin \
			usr/share/perl5/Zevenet \
			usr/local/zevenet/www/zapi/v3.1 \
			usr/local/zevenet/www/zapi/v4.0 \
			-type f \
			-exec sed --follow-symlinks -i 's/^use warnings.*//' {} \; \
			-exec sed --follow-symlinks -i '/zenlog.*PROFILING/d' {} \;
fi


#### Generate package and clean up ####

msg "Generating .deb package..."
cd "$BASE_DIR"

# Generate package using the most recent debian version
dpkg-deb --build workdir packages/"$pkgname" \
	|| die " generating the package"

msg "Success: package ready"
