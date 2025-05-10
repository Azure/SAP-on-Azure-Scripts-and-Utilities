#### asr4hana_post.sh

    #!/bin/bash
    # post-script to confirm completion of storage/data snapshots
    # replace the `<sid>` with your 3-letter system identifier
        echo "Starting post script as user root"
    # Step 1: Capture the BACKUP_ID into a shell-variable
    BACKUP_ID=$(su - `<sid>`adm -c "hdbsql -U SYSTEMDB -a -x \
    \"SELECT BACKUP_ID FROM M_BACKUP_CATALOG WHERE ENTRY_TYPE_NAME = 'data snapshot' AND STATE_NAME = 'prepared' AND COMMENT = 'internal DB snapshot' LIMIT 1\"")
    export BACKUP_ID
    # Step 2: Use the BACKUP_ID to confirm the snapshot (marked as SUCCESSFUL) in the backup catalog
    #
    su - `<sid>`adm -c "hdbsql -U SYSTEMDB \"BACKUP DATA FOR FULL SYSTEM CLOSE SNAPSHOT BACKUP_ID $BACKUP_ID SUCCESSFUL 'internal DB snapshot'\""
