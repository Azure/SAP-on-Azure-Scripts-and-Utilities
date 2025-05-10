#### asr4hana_pre.sh

# The handle `<sid>` is a placeholder for your SAP HANA system identifier.  You will need the hdbuserstore SYSTEMDB key created already for user `<sid>`adm to access HANA and execute the hdbsql command.  

    #!/bin/bash
    # pre-script to prepare HANA for data snapshots
    # replace the `<sid>` with your 3-letter system identifier
        echo "Starting pre script as user root"
        sudo su - `<sid>`adm -c "hdbsql -U SYSTEMDB \"BACKUP DATA FOR FULL SYSTEM CREATE SNAPSHOT COMMENT 'internal DB snapshot';\""
    # hand over process to ASR at this point
    exit 0