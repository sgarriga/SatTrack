#!/bin/bash
#
# Purpose: Check to see if satellite tracking is 'on' for this date
#   Input parametera:
#   1. Satellite Name
#   2. Start time to predict passes (seconds since epoch)
#   3. End time to predict passes (seconds since epoch)
#
# Example: 
# ./check_cal.sh 'ISS(ZARYA)' 1679363592 1679366889

echo "$(date +"%x %X") : Start $0 $1 $2 $3"

cmd_path=$(readlink -f ${0//check_cal.sh/})
db=${cmd_path}/sat-track.db
sat_name=$1

## set -f/+f avoids * expansion
set -f
IFS=, read -r name start_date end_date <<< $(sqlite3 -separator , ${db} "select * from calendar where sat_name=\"${sat_name}\";")
unset IFS
set +f
if [ -z "$name" ]; then
    echo "No calendar entry for ${sat_name}"
    echo "$(date +"%x %X") : Done $0 returning 1"
    exit 1
fi

# Convert the epoc times to a UTC date
utc_date_s=$(date --date="TZ=UTC" -d @${2} +%F)
utc_date_e=$(date --date="TZ=UTC" -d @${3} +%F)

if [[ "$utc_date_e" < "$start_date" ]]; then
    echo "Pass ends ${utc_date_e}, before ${start_date}"
    echo "$(date +"%x %X") : Done $0 returning 1"
    exit 1
fi
if [[ "$utc_date_s" > "$end_date" ]]; then
    echo "Pass starts ${utc_date_s}, after ${end_date}"
    echo "$(date +"%x %X") : Done $0 returning 1"
    exit 1
fi

echo "$(date +"%x %X") : Done $0 returning 0"
exit 0

