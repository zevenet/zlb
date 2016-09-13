#!/bin/bash

IFS='.' read -a DEBVERSION < /etc/debian_version
if [ $DEBVERSION != 8 ]; then
	echo "Zevenet Load Balancer installation only available for Debian Jessie, currently."
	exit 1
fi

if [ "`grep dhcp /etc/network/interfaces`" != "" ]; then
	echo "Zevenet Load Balancer doesn't support DHCP network configurations yet. Please configure a static IP address in the file /etc/network/interfaces."
	exit 1
fi

DSTDIR="/usr/local/zenloadbalancer"
CURDIR=`pwd`

# Install dependencies
apt-get install make rrdtool libnet-netmask-perl libnet-ssh-perl libexpect-perl expect libproc-daemon-perl libnetwork-ipv4addr-perl librrds-perl libio-interface-perl libdata-validate-ip-perl rsync libpcap0.8 ntpdate liblinux-inotify2-perl iputils-arping openssl unzip snmpd conntrack pound ucarp gdnsd libgd-perl apt-transport-https

# Install some perl dependencies not available in Debian
perl -MCPAN -e 'install GD::3DBarGrapher'
perl -MCPAN -e 'install Net::SSH::Expect'

# Apply some configuration etc/ symbolic links
ln -sf "$CURDIR" "$DSTDIR"
ln -sf "$CURDIR/etc/cron.d/zenloadbalancer" "/etc/cron.d/zenloadbalancer"
ln -sf "$CURDIR/etc/init.d/zenloadbalancer" "/etc/init.d/zenloadbalancer"
ln -sf "$CURDIR/etc/init.d/minihttpd" "/etc/init.d/minihttpd"
ln -sf "$CURDIR/etc/logrotate.d/zenloadbalancer" "/etc/logrotate.d/zenloadbalancer"

# Migrate network interfaces configuration to zevenet compliant


# Setup zenloadbalancer service at boot time
update-rc.d zenloadbalancer defaults

