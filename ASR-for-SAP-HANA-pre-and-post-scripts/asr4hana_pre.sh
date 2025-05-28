#### asr4hana_pre.sh

#!/bin/bash
set -x
# Define the path to the DEFAULT.PFL file
PROFILE_PATH="/usr/sap/*/SYS/profile/DEFAULT.PFL"

for profile in $(ls $PROFILE_PATH 2>/dev/null); do
  dbname=$(grep -E "^dbs/hdb/dbname" "$profile" | awk -F'=' '{print $2}'| tr '[:upper:]' '[:lower:]' | tr -d ' ')
  if [ -n "$dbname" ]; then
    echo "dbname found in $profile: $dbname"
    break # exit once the dbname is found
  fi
done
   # Use the SID variable in the hdbsql command
    sudo su - "${dbname}adm" -c "hdbsql -U SYSTEMDB \"BACKUP DATA FOR FULL SYSTEM CREATE SNAPSHOT COMMENT 'internal DB snapshot';\""
    # hand over process to ASR at this point
    exit 0