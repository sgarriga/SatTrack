#!/bin/bash
#
# Purpose: Create a DB entry for any passes of a specified satellite in
#          a given window
#   Input parametera:
#   1. Satellite Name - as in .tle file
#   2. TLE file - may be full or for single satellite
#   3. Start time to predict passes (seconds since epoch)
#   4. End time to predict passes (seconds since epoch)
#   5. Desired signal type
#
# Example:
#   ./schedule_captures.sh "NOAA 18" some.tle 1617422399 1617423725 APT

cmd_path=$(readlink -f ${0//schedule_captures.sh/})
db=${cmd_path}/sat-track.db

# map inputs to sane var names
sat_name=$1
tle_file=$2
start_s=$3
end_s=$4
sig_type=$5

echo "$(date +"%x %X") : Start $0 $1 $2 $3 $4 $4"

# Get full satellite details from DB
## set -f/+f avoids * expansion
set -f
IFS=, read -r sat_name freq freq_offset gain sig_type dev_id bias_tee sun_min sat_min <<< $(sqlite3 -separator , ${db} "select * from satellites where name=\"${sat_name}\" AND signal_type=\"${sig_type}\";")
unset IFS
set +f

# Check for any special restrictions
safe_sat=$(echo ${1/ /_} | tr -d '()')
sat_script=${cmd_path}/${safe_sat}_special.sh
if [ -x ${sat_script} ]; then
    ${sat_script} ${start_s} ${end_s} ${sig_type}
    if [ $? -ne 0 ]; then
        echo "$(date +"%x %X") : Done $0"
        exit
    fi
#else
#    echo "$(date +"%x %X") : No ${sat_script} found"
fi

# come up with prediction start/end timings for pass
## drop every predicted point below our minimum elevation and
## determine start & end of passes (and some other info)
transits=/tmp/transits.txt
predict -t $tle_file -f "${sat_name}" "${start_s}" "${end_s}" | \
  awk -v min="${sat_min}" '{if($5>=min){print $0}}' | \
  awk -f  ${cmd_path}/predicts2pass.awk > ${transits}
if [ ! -s ${transits} ]; then
  echo "$(date +"%x %X") : No predicted passes for ${sat_name} with elevation over ${sat_min} degrees"
  exit
fi

# echo "$(date +"%x %X") : ==="
# cat ${transits}
# echo "$(date +"%x %X") : ==="

## load each pass (or transit) into DB - but don't schedule job yet
while read -r start stop max_el init_az max_az; do

    # travel direction
    if [[ (${init_az} < 90 ) || (${init_az} > 270) ]]; then
      dir="Southbound"
    else
      dir="Northbound"
    fi

    time1=$(date -d @${start} +"%Y/%m/%d %H:%M:%S UTC")
    time2=$(date -d @${stop} +"%Y/%m/%d %H:%M:%S UTC")
    echo "$(date +"%x %X") : Scheduling capture for: ${sat_name} ${time1} - ${time2}"

    sql="INSERT OR REPLACE INTO transits (sat_name, pass_start, pass_end, max_elev, pass_start_azimuth, direction, azimuth_at_max, device, signal_type) VALUES (\"${sat_name}\", ${start}, ${stop}, ${max_el}, ${init_az}, \"${dir}\", ${max_az}, ${dev_id}, \"${sig_type}\");"
    sqlite3 ${db} "${sql}"
done < ${transits}
rm -f ${transits}

echo "$(date +"%x %X") : Done $0"
