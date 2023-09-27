# Linux Always-on-Diagnostics for SLES

The Linux Always-on-Diagnostics for SLES is constantly collecting log data and network captures to diagnose errors with NFS shares.

## /opt/sap-aod/aod.cfg

The configuration file is available in /opt/sap-aod/aod.cfg and customers can update the configuration according to their requirements.

Default values for the configuration files are:

```
AOD_TMPDIR="/tmp"
AOD_INSTALLROOT="/opt"
AOD_PERSISTENT_LOGDIR="/tmp/sap-aod-logs/"
AOD_TMPFS_SZ="256M"

AOD_NFS_PORT="2049"
AOD_TCPDUMP_BIN="/usr/sbin/tcpdump"
AOD_TCPDUMP_BUFSZ_KB="10240"
AOD_TCPDUMP_SNAPLEN_BYTES=65536
AOD_TCPDUMP_PCAPSZ_MB="2"
AOD_TCPDUMP_MAX_PCAPS="100"

AOD_LOG_LOOP_SLEEP_SEC="60"
AOD_NUM_LOGS_RETAINED="180"

AOD_NW_PROBE_ENABLE=1
AOD_NW_PROBE_TIMEOUT_SEC=3
AOD_NW_PROBE_SLEEP_SEC=60
AOD_NW_CAPTURE_ENABLE=0
```

## Enable automatic collection

To enable the automatic collection use the systemctl command:

```
sudo systemctl enable aod
```

You can check the status using:

```
sudo systemctl status aod
```
