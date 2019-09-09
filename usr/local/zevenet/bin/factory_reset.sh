#!/bin/bash


# load LB variables
source /usr/local/zevenet/bin/load_global_conf
load_global_conf

# vars
IP_MANAGEMENT="192.168.0.99"
GW_MANAGEMENT="192.168.0.5"
NETMASK_MANAGEMENT="255.255.255.0"

GLOBALCONF_TPL=$globalcfg_tpl
CONF_DIR=$configdir
TEMPLATE_DIR=$templatedir

REM_BACKUPS=0
HARD=0
HW=0

# functions
show_usage() {
  echo usage: `basename $0` -i interface_name
  echo "  Mandatory parameters:"
  echo "      -i|--interface, this interface will not be deleted. It is recommended to use this interface only for management purpose."
  echo ""
  echo "  Optional parameters: "
  echo "      --remove-backups, removes the load balancer backups in the reset process"
  echo "      --hard-reset, additionally to the factory reset it removes configuration related to users, activation certificates and backups, RBAC "
  echo "      -hw|--hardware, it's a hard reset but the IP $IP_MANAGEMENT is set by default in the management interface"
  echo ""
  echo "  The factory reset will delete:"
  echo "      *) All the interfaces configuration, excepts the interface received as argument, see -i parameter "
  echo "      *) All farms configuration "
  echo "      *) All SSL certificates "
  echo "      *) Web server SSL certificate"
  echo "      *) Logs "
  echo "      *) Graphs "
  echo "      *) System directories: /opt, /root, /tmp "
  echo "      *) Command history"
  echo "      *) Users and API configuration"
  echo ""
  echo "  The factory reset will keep:"
  echo "      *) Zevenet updates"
  echo "      *) The host name"
  echo "      *) The password for the root user"
  echo ""

  exit 1
}

# script
while [ $# -gt 0 ]; do
	case $1 in
	"-interface"|"-i")
		if_mgmt=$2
		shift
		;;
	"--hard-reset")
		HARD=1
		REM_BACKUPS=1
		;;
	"--remove-backups")
		REM_BACKUPS=1
		;;
	"--hardware"|"-hw")
		REM_BACKUPS=1
		HARD=1
		HW=1
		;;
	*)
		echo "Invalid option: $1"
		show_usage
		exit 1
		;;
	esac
	shift
done


if [ -z "${if_mgmt}" ]; then
  show_usage
fi

if [ ! -d "/sys/class/net/${if_mgmt}" ]; then
        echo "The specified interface has not been found"
        exit 1
fi

# save interface conf file
IF_NAME="if_${if_mgmt}_conf"
IF_CONF="${CONF_DIR}/$IF_NAME"
if [ ! -f "$IF_CONF" ]; then
        echo "The iface ${if_mgmt} has not been found"
        exit 1
fi

echo "Stopping processes"
for AP in $(ps aux | grep zen | grep -v grep | awk '{print $2}')
do
        echo "Stopping processes $AP"
        ps -ef | grep $AP |grep -v grep
        pkill $AP
done

PROC=`ps aux | grep sec |grep -v grep | awk '{print $2}'`
if [ ! -z $PROC ]; then
	kill -9 $PROC
fi


echo "Stopping cron process"
$cron_service stop
echo "Stopping zevenet process"
$zevenet_service stop

# disalbe the zapi
$deluser_bin zapi

if [ $HARD -eq 1 ]
then
	# WARNING: not to stop cherokee process from the API, that kills this script
	echo "Deleting Zevenet certificate"
	rm -fr $zlbcertfile_path
fi

if [ $REM_BACKUPS -eq 1 ]
then
	echo "Deleting backups"
    rm -fr $backupdir/*
fi


#Delete all except: zlb-*, iface management, global.conf and cherokee conf and ssl cert
echo "Cleaning up configuration"

# saving permanent config files
PERMANENT_FILES=($IF_NAME cacrl.crl)
TMP_CONF_DIR="/tmp/config_factorying"

mkdir $TMP_CONF_DIR
for file in "${PERMANENT_FILES[@]}"
do
	cp $CONF_DIR/$file $TMP_CONF_DIR
done


# cleaning up config
rm -fr ${CONF_DIR}/*
mv $TMP_CONF_DIR/* ${CONF_DIR}
rm /etc/cron.d/*

# create local conf dir
mkdir "$localconfig"

# set template
cp $http_server_key_tpl $http_server_key
cp $http_server_cert_tpl $http_server_cert
cp $GLOBALCONF_TPL ${CONF_DIR}/global.conf
cp $snmpdconfig_tpl $snmpdconfig_file
cp $cron_tpl $cron_conf
cp $confhttp_tpl $confhttp
cp $zlb_start_tpl $zlb_start_script && chmod +x $zlb_start_script
cp $zlb_stop_tpl $zlb_stop_script && chmod +x $zlb_stop_script


if [ -d "$TEMPLATE_DIR/rbac_roles" ]; then
	mkdir ${CONF_DIR}/rbac/
	cp -r $TEMPLATE_DIR/rbac_roles ${CONF_DIR}/rbac/roles
fi


if [ $HARD -eq 1 ]; then
	echo "Cleaning apt"
	rm -fr $fileapt
	rm -fr $apt_source_zevenet
	rm -fr $apt_conf_file
	apt-get update
	apt-get clean

	echo "Preparing the firt boot"
	if [ ! -f $first_boot_flag ]; then
			touch $first_boot_flag
	fi
fi


# Set up the management iface
if [ $HW -eq 1 ]; then
	echo "Rewriting interface config file $IF_CONF"
	echo "[${if_mgmt}]" > $IF_CONF
	echo "name=${if_mgmt}" >> $IF_CONF
	echo "addr=$IP_MANAGEMENT" >> $IF_CONF
	echo "mask=$NETMASK_MANAGEMENT" >> $IF_CONF
	echo "gateway=$GW_MANAGEMENT" >> $IF_CONF
	echo "status=up" >> $IF_CONF
else
	sed -i -E 's/status=.*$/status=up/' $IF_CONF
fi


echo "Cleaning up directories"
rm -fr /var/log/*
rm -fr /opt/*
rm -fr /tmp/*
rm -fr $rrdap_dir/$rrd_dir/*
rm -rf /root/.bash_history
rm -rf /root/* {.bashrc}

# restarting the host
echo "Rebooting system"
reboot
