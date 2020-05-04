# service-monitor
Introduction:
This script monitors sshd, rsyslog and network services for RHEL 6/7 and CentOS 6/7 systems.

During its first run it will create backup of configuration for service configuration files like /etc/ssh/sshd_config, /etc/rsyslog.conf, /etc/sysconfig/network-scripts/ifcfg-<network interface> and /etc/sysconfig/network-scripts/route-<network interface> files as Golden configuration and stores in /root/SERVICE_MONITOR_GOLD/
  
For later run/script executions it will check for availibility of its Golden configuration files, if exists then it will monitor services like sshd, rsyslog and network - If any of them found stopped then it will attempt to start the service.

If service starts during first attempt then script will continue to check next service status.

If service doesn't start after first attempt then script will replace service configuration with backed up Golden configuration and then starts the service.

# Script usage
Syntax:
service-mon.sh [mode] [service]

Mode:

  init    : Creates Golden configuration at any point of time [Ad-Hoc request for creating Golden configuration from working configuration] # This will replaces if any Golden configuration is already present in the directory.

  Example:

    # service-mon.sh init

recover   : This mode is used to recover any/all of the above listed services with Golden Configuration then restarts its services accordingly

  Examples:

    # service-mon.sh recover sshd

    # service-mon.sh recover rsyslog

    # service-mon.sh recover network

    # service-mon.sh recover all  # This is used to recover all services (sshd, rsyslog and network) based on its Golden configuration

# How to run service-mon in service monitoring mode?

To run service-mon.sh in Service monitoring mode below is the exmaple

  Example:
  
    # service-mon.sh
    
Incase of any queries feel free to contact "Saddam Hussain Shaik" <sksaddamhussain@gmail.com>
