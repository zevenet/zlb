#!/bin/bash

if_mgmt=$1

CONF_DIR="/usr/local/zevenet/config";
TEMPLATE_DIR="/usr/local/zevenet/share";


show_usage() {
  echo usage: `basename $0`  interface_name
  exit 1
}

if [ -z "${if_mgmt}" ]; then
  show_usage
fi

if [ ! -d "/sys/class/net/${if_mgmt}" ]; then
        echo "Specified interface does not exist"
fi
echo "Stopping processes"
for AP in $(ps aux | grep zen | grep -v grep | awk '{print $2}')
do
        echo "Parando el proceso  $AP"
        ps -ef | grep $AP |grep -v grep
        pkill $AP
done
kill -9 `ps aux | grep sec |grep -v grep | awk '{print $2}'`

echo "Stopping cron process"
/etc/init.d/cron stop
echo "Stopping cherokee process"
/etc/init.d/cherokee stop
echo "Stopping zevenet process"
/etc/init.d/zevenet stop

echo "Deleting configuration files"
rm -fr /var/log/*
rm -fr /opt/*
rm -fr /tmp/*
rm -fr /usr/local/zevenet/logs/*
rm -fr /usr/local/zevenet/www/zlbcertfile.pem
rm -fr /usr/local/zevenet/app/zenrrd/rrd/*
rm -fr /usr/local/zevenet/www/img/graphs/*

read -p "Do you want to delete the backups [N|y]? " -n 1 -r
if [[ $REPLY =~ ^[Yy]$ ]]
then
    rm -fr /usr/local/zevenet/backups/*
fi

mv ${CONF_DIR}/zencert* /tmp/
rm -fr ${CONF_DIR}
mv /tmp/zencert* $CONF_DIR

#borrar todo excpeto: zencert*, zlb-*, global.conf, if_eth0_conf

# Reseting global.conf
cp /usr/local/zevenet/share/global.conf.template ${CONF_DIR}/global.conf

echo "Deleting cherokee configuration"
SERVER=`grep "server!bind!1!interface =" /usr/local/zevenet/app/cherokee/etc/cherokee/cherokee.conf`
sed -i "s/$SERVER/\#server\!bind\!1\!interface = \;/g" /usr/local/zevenet/app/cherokee/etc/cherokee/cherokee.conf
PORT=`grep "server!bind!1!port =" /usr/local/zevenet/app/cherokee/etc/cherokee/cherokee.conf`
sed -i "s/$PORT/server\!bind\!1\!port = 444/g" /usr/local/zevenet/app/cherokee/etc/cherokee/cherokee.conf

echo "#make your own script in your favorite language, it will be called" > ${CONF_DIR}/zlb-start
echo "#at the end of the procedure /etc/init.d/zenloadbalacer start" >> ${CONF_DIR}/zlb-start
echo "#and replicated to the other node if zen cluster is running." >> ${CONF_DIR}/zlb-start

echo "#make your own script in your favorite language, it will be called" > ${CONF_DIR}/zlb-stop
echo "#at the end of the procedure /etc/init.d/zenloadbalacer stop" >> ${CONF_DIR}/zlb-stop
echo "#and replicated to the other node if zen cluster is running." >> ${CONF_DIR}/zlb-stop


echo "Cleaning apt"
rm -fr /etc/apt/sources.list
apt-get update
apt-get clean


echo "Preparing the firt boot"
if [ ! -f /etc/firstzlbboot ]; then
        touch /etc/firstzlbboot
fi

echo "Creating interface config file  if_${if_mgmt}_conf"x
echo "status=up" > ${CONF_DIR}/if_${if_mgmt}_conf
echo "${if_mgmt};192.168.0.99;255.255.255.0;;" >> ${CONF_DIR}/if_${if_mgmt}_conf

echo "Deleting the root's home"
rm -rf /root/.bash_history
rm -rf /root/* {.bashrc}
