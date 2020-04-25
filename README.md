# service-monitor
This script monitors ssh, rsyslog and network services

During its first run you can initiate golden confiration (Working configuration) as backup and incase of necessity using this script it can be restored to working condition.

This can be scheduled to run using cron and can monitor service.

In case of stopped service then script attempts to start service, if it still fails to start then it will replace its configuration with its golden configuration.
