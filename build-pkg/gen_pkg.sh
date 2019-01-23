#!/bin/bash

# Exit at the first error
set -e

BASE_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"
DATE=$(date +%y%m%d_%H%M%S)
arch="amd64"

# Default options
devel="false"

function print_usage_and_exit() {
	echo "Usage: $(basename "$0") <distribution> [options]

	--devel		Debug logs"
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


##### Parse command arguments #####

# Distribution parameter (-i or -u) is not optional show
# how to use the command if no distribution was selected
while [ $# -gt 0 ]; do
	case $1 in
	--devel)
		devel="true"
		;;
	*)
		echo "Invalid option: $1"
		print_usage_and_exit
		;;
	esac

	shift
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
version=$(grep "Version:" DEBIAN/control | cut -d " " -f 2)
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
