#### asr4hana_post.sh

#!/bin/bash
# Define the path to the DEFAULT.PFL file
PROFILE_PATH="/usr/sap/*/SYS/profile/DEFAULT.PFL"

for profile in $(ls $PROFILE_PATH 2>/dev/null); do
  dbname=$(grep -E "^dbs/hdb/dbname" "$profile" | awk -F'=' '{print $2}'| tr '[:upper:]' '[:lower:]' | tr -d ' ')
  if [ -n "$dbname" ]; then
    echo "dbname found in $profile: $dbname"
    break # exit once the dbname is found
  fi
done
    # Step 1: Capture the BACKUP_ID into a shell-variable
    BACKUP_ID=$(su - "${dbname}adm" -c "hdbsql -U SYSTEMDB -a -x \
    \"SELECT BACKUP_ID FROM M_BACKUP_CATALOG WHERE ENTRY_TYPE_NAME = 'data snapshot' AND STATE_NAME = 'prepared' AND COMMENT = 'internal DB snapshot' LIMIT 1\"")
    export BACKUP_ID
    # Step 2: Use the BACKUP_ID to confirm the snapshot (marked as SUCCESSFUL) in the backup catalog
    su - "${dbname}adm" -c "hdbsql -U SYSTEMDB \"BACKUP DATA FOR FULL SYSTEM CLOSE SNAPSHOT BACKUP_ID $BACKUP_ID SUCCESSFUL 'internal DB snapshot'\""