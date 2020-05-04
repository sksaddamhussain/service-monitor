#!/bin/bash -e

SERVICE_HOME=/root/SERVICE_MONITOR_GOLD
mkdir -p $SERVICE_HOME

MODE=""
RECOVER_SER=""
MODE="$1"
RECOVER_SER="$2"

SERVICEMON_INIT(){
        logger -ip syslog.info "Service Monitoring has initiated backup of service files" -t "service-mon"
        logger -ip syslog.info "Performing cleanup if any files already exists in Golden Configurations inventory" -t "service-mon"
	rm -rf $SERVICE_HOME
	mkdir -p $SERVICE_HOME
	cp -r /etc/ssh/sshd_config /etc/rsyslog.conf /etc/sysconfig/network-scripts/ifcfg-e* /etc/sysconfig/network-scripts/route-e* $SERVICE_HOME/ 
        logger -ip syslog.info "Service Monitoring has completed backup of service files" -t "service-mon"
}

if [ -d $SERVICE_HOME ]
then
	CONFIG_ARRAY=("rsyslog.conf" "sshd_config")
	NETWORK_LIST=`ls "/etc/sysconfig/network-scripts/" | grep -e "^ifcfg-e" -e "^route-e"`
	CONFIG_ARRAY=("${CONFIG_ARRAY[@]}" "$NETWORK_LIST")
	for SERCONFIGS in ${CONFIG_ARRAY[*]}
	do
		#echo "Config element : ${SERCONFIGS}"
		if [ -f ${SERVICE_HOME}/${SERCONFIGS} ]
		then
			echo "Configuration file ${SERVICE_HOME}/${SERCONFIGS} exists"
		else
			echo "Configuration file ${SERVICE_HOME}/${SERCONFIGS} doesn't exists"
			logger -ip syslog.info "Configuration file ${SERVICE_HOME}/${SERCONFIGS} doesn't exists request is initiated for backup" -t "service-mon"
			SERVICEMON_INIT
			break
		fi
	done
else
	logger -ip syslog.info "Service Monitoring cannot find Golden Configurations inventory of service files" -t "service-mon"
	SERVICEMON_INIT
fi

SERVICE_LIST="sshd,rsyslog,network"

SMANAGER=$(ps -p1 | grep "init\|systemd" | awk '{print $4}')

MY_SERVICE=""

CHECK_SERVICE(){
	if [ "$1" == "init" ]
	then
		if [ "$2" == "network" ]
		then
			MY_INT_LIST=(`ip link show | grep 'eth[[:digit:]]\|enp[[:digit:]]\|ens[[:digit:]]' | awk '{print $2}' | tr -d ':'`)
			MY_COUNTER=0
			for MY_INT in ${MY_INT_LIST[*]}
			do
				INT_STATUS=`ip -4 a s ${MY_INT} | grep inet | wc -l`
				((MY_COUNTER=MY_COUNTER+INT_STATUS))
			done
			if [ "$MY_COUNTER" == "${#MY_INT_LIST[*]}" ]
			then
				MY_SERVICE="running"
			else
				MY_SERVICE="stopped"
			fi
		else
                        MY_SERVICE_STATUS=$(service $2 status | grep -i 'running' | wc -l)
                        if [ "${MY_SERVICE_STATUS}" == "1" ]
                        then    
                                MY_SERVICE="running"
                        else    
                                MY_SERVICE="stopped"
                        fi
		fi
	elif [ "$1" == "systemd" ]
	then
		MY_SERVICE=$(systemctl status $2 | grep -i 'running\|dead\|Active (exited)' | awk '{print $3}' | sed 's/[()]//g')
		if [ "$MY_SERVICE" == "running" ] || [ "$MY_SERVICE" == "exited" ]
		then
			MY_SERVICE="running"
		fi
	fi
	logger -ip syslog.info "Status of $2 is $MY_SERVICE" -t "service-mon"
}

STOP_START_SERVICE(){
	if [ "$1" == "init" ]
	then
		service $2 stop
		service $2 start
		CHECK_SERVICE $1 $2
		#MY_SERVICE=$(service $2 status | grep -i 'running\|stopped' | awk '{print $3}' | sed 's/[()]//g')
	elif [ "$1" == "systemd" ]
	then
		systemctl stop $2
		systemctl start $2
		CHECK_SERVICE $1 $2
		#MY_SERVICE=$(systemctl status $2 | grep -i 'running\|dead' | awk '{print $3}' | sed 's/[()]//g')
	fi
	logger -ip syslog.info "Attempted restart of $2 and status after restart is $MY_SERVICE" -t "service-mon"
}


if [ "$MODE" == "init" ]
then
	echo "Initializing golden configuration files"
	SERVICEMON_INIT

elif [ "$MODE" == "recover" ]
then
	if [ "$RECOVER_SER" == "sshd" ] || [ "$RECOVER_SER" == "rsyslog" ] || [ "$RECOVER_SER" == "network" ] || [ "$RECOVER_SER" == "all" ]
	then
		logger -ip syslog.info "Manual Service recovery mode for service(s) $RECOVER_SER is initiated" -t "service-mon"
		case $RECOVER_SER in
			sshd)
				cat $SERVICE_HOME/sshd_config > /etc/ssh/sshd_config
				STOP_START_SERVICE $SMANAGER $RECOVER_SER
				;;
			rsyslog)
				cat $SERVICE_HOME/rsyslog.conf > /etc/rsyslog.conf
				STOP_START_SERVICE $SMANAGER $RECOVER_SER
				;;
			network)
				for MYINTERFACE in `ip link show | grep 'eth[[:digit:]]\|enp[[:digit:]]\|ens[[:digit:]]' | awk '{print $2}' | tr -d ':'`
				do
					cat $SERVICE_HOME/ifcfg-$MYINTERFACE > /etc/sysconfig/network-scripts/ifcfg-$MYINTERFACE
                                        if [ -f "$SERVICE_HOME/route-$MYINTERFACE" ]
                                        then
                                                cat $SERVICE_HOME/route-$MYINTERFACE > /etc/sysconfig/network-scripts/route-$MYINTERFACE
                                        fi
				done
				STOP_START_SERVICE $SMANAGER $RECOVER_SER
				;;
			all)
                                cat $SERVICE_HOME/sshd_config > /etc/ssh/sshd_config
                                STOP_START_SERVICE $SMANAGER sshd
                                cat $SERVICE_HOME/rsyslog.conf > /etc/rsyslog.conf
                                STOP_START_SERVICE $SMANAGER rsyslog
                                for MYINTERFACE in `ip link show | grep 'eth[[:digit:]]\|enp[[:digit:]]\|ens[[:digit:]]' | awk '{print $2}' | tr -d ':'`
                                do
                                        cat $SERVICE_HOME/ifcfg-$MYINTERFACE > /etc/sysconfig/network-scripts/ifcfg-$MYINTERFACE
                                        if [ -f "$SERVICE_HOME/route-$MYINTERFACE" ]
                                        then
	                                        cat $SERVICE_HOME/route-$MYINTERFACE > /etc/sysconfig/network-scripts/route-$MYINTERFACE
                                        fi

                                done
                                STOP_START_SERVICE $SMANAGER network
                                ;;
		esac
		logger -ip syslog.info "Manual Service recovery mode for service(s) $RECOVER_SER is completed" -t "service-mon"
	else
		echo -e "Supported services are listed below:\nsshd\nnetwork\nrsyslog\n\nYou can choose anyone or if you want to recover all services then use keywork 'all'"
	fi

elif [ "$MODE" == "" ]
then
	logger -ip syslog.info "Initializing scan for services" -t "service-mon"

	for SERVICE in `echo $SERVICE_LIST | sed -e 's/,/\n/g'`
	do
		CHECK_SERVICE $SMANAGER $SERVICE
		if [ "$MY_SERVICE" != "running" ]
		then
			echo "Service start initiated......"
			STOP_START_SERVICE $SMANAGER $SERVICE
			#sleep 10
			#MY_SERVICE="stopped"
			if [ "$MY_SERVICE" != "running" ]
			then
				logger -ip syslog.info "Entering rescue mode for service $SERVICE" -t "service-mon"
				case $SERVICE in
					sshd)
						cat $SERVICE_HOME/sshd_config > /etc/ssh/sshd_config
						STOP_START_SERVICE $SMANAGER $SERVICE
						;;
					rsyslog)
						cat $SERVICE_HOME/rsyslog.conf > /etc/rsyslog.conf
						STOP_START_SERVICE $SMANAGER $SERVICE
						;;
					network)
						for MYINTERFACE in `ip link show | grep 'eth[[:digit:]]\|enp[[:digit:]]\|ens[[:digit:]]' | awk '{print $2}' | tr -d ':'`
						do
							cat $SERVICE_HOME/ifcfg-$MYINTERFACE > /etc/sysconfig/network-scripts/ifcfg-$MYINTERFACE
							if [ -f "$SERVICE_HOME/route-$MYINTERFACE" ]
							then
								cat $SERVICE_HOME/route-$MYINTERFACE > /etc/sysconfig/network-scripts/route-$MYINTERFACE
							fi
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
else
	echo "Invalid option selected...."
fi
