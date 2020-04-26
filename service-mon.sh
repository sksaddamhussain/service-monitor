#!/bin/bash -e

SERVICE_HOME=/root/SERVICE_MONITOR_GOLD
mkdir -p $SERVICE_HOME

MODE="$1"

if [ "$MODE" == "init" ]
then
	echo "Initializing golden configuration files"
	cp /etc/ssh/sshd_config /etc/rsyslog.conf /etc/sysconfig/network-scripts/ifcfg-e* /etc/sysconfig/network-scripts/route-e* $SERVICE_HOME/ 
fi


SERVICE_LIST="sshd,rsyslog,network"

SMANAGER=$(ps -p1 | grep "init\|systemd" | awk '{print $4}')

MY_SERVICE=""

CHECK_SERVICE(){
	if [ "$1" == "init" ]
	then
		MY_SERVICE=$(service $2 status | grep -i 'running\|stpped' | awk '{print $3}' | sed 's/[()]//g')
	elif [ "$1" == "systemd" ]
	then
		MY_SERVICE=$(systemctl status $2 | grep -i 'running\|dead' | awk '{print $3}' | sed 's/[()]//g')
	fi
	logger -ip syslog.info "Status of $2 is $MY_SERVICE" -t "service-mon"
}

STOP_START_SERVICE(){
	if [ "$1" == "init" ]
	then
		service $2 stop
		service $2 start
		MY_SERVICE=$(service $2 status | grep -i 'running\|stpped' | awk '{print $3}' | sed 's/[()]//g')
	elif [ "$1" == "systemd" ]
	then
		systemctl stop $2
		systemctl start $2
		MY_SERVICE=$(systemctl status $2 | grep -i 'running\|dead' | awk '{print $3}' | sed 's/[()]//g')
	fi
	logger -ip syslog.info "Attempted restart of $2 and status after restart is $MY_SERVICE" -t "service-mon"
}

logger -ip syslog.info "Initializing scan for services" -t "service-mon"

for SERVICE in `echo $SERVICE_LIST | sed -e 's/,/\n/g'`
do
	CHECK_SERVICE $SMANAGER $SERVICE
	if [ "$MY_SERVICE" != "running" ]
	then
		echo "Service start initiated......"
		STOP_START_SERVICE $SMANAGER $SERVICE
		#sleep 10
		MY_SERVICE="stopped"
		if [ "$MY_SERVICE" != "running" ]
		then
			logger -ip syslog.info "Entering rescue mode for service $SERVICE" -t "service-mon"
			case $SERVICE in
				sshd)
					cat $SERVICE_HOME/sshd_conf > /etc/ssh/test-sshd_conf
					STOP_START_SERVICE $SMANAGER $SERVICE
					;;
				rsyslog)
					cat $SERVICE_HOME/rsyslog.conf > /etc/rsyslog.conf
					STOP_START_SERVICE $SMANAGER $SERVICE
					;;
				network)
					for MYINTERFACE in `ip link show | grep 'eth[[:digit:]]\|enp[[:digit:]]\|ens[[:digit:]]' | awk '{print $2}' | tr -d ':'`
					do
						cat $SERVICE_HOME/ifcfg-$MYINTERFACE > /etc/test-ifcfg-$MYINTERFACE
					done
					STOP_START_SERVICE $SMANAGER $SERVICE
					;;
			esac
			logger -ip syslog.info "Rescue mode for service $SERVICE is completed" -t "service-mon"
		fi
	fi
	#echo -e "My service is $SERVICE and its status is $MY_SERVICE"
	#logger -ip syslog.info "Status of $SERVICE is $MY_SERVICE" -t "service-mon"
done
logger -ip syslog.info "Scan for services is completed" -t "service-mon"
