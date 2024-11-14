#!/bin/bash
#
# Purpose: Schedule all desired satellite and orbital captures for the 
#          next 24 hours
#   Input parametera:
#     none
#
# Example:
#  ./schedule_24h.sh

echo "$(date +"%x %X") : Start $0"
cmd_path=$(readlink -f ${0//schedule_24h.sh/})
db=${cmd_path}/sat-track.db

# Get update NORAD data, if we need it
norad_data=${cmd_path}/full_norad.tle
norad_names=${cmd_path}/norad_names.txt
## force a new download if our data is > 12 hours old
if [ -e ${norad_data} ]; then
  echo "$(date +"%x %X") : NORAD file exists"
  now_s=$(date +%s)
  file_s=$(date -r ${norad_data} +%s)
  let age_hrs=(now_s-file_s)/3600
  if [ $age_hrs -gt 12 ]; then
      echo "$(date +"%x %X") : Force NORAD download ${age_hrs} hrs > 12 hrs"
      rm -f ${norad_data}
  else
      echo "$(date +"%x %X") : NORAD data is fresh ${age_hrs} hrs <= 12 hrs"
  fi
fi
if [ ! -e ${norad_data} ]; then
  echo "$(date +"%x %X") : Fetching NORAD elements"
  wget -q "http://www.celestrak.org/NORAD/elements/weather.txt" --no-check-certificate -O - >  "${norad_data}.new"
  wget -q "http://www.celestrak.org/NORAD/elements/visible.txt" --no-check-certificate -O - >> "${norad_data}.new" 
  wget -q "http://www.celestrak.org/NORAD/elements/amateur.txt" --no-check-certificate -O - >> "${norad_data}.new" 

  if [ -s "${norad_data}.new" ]; then
      echo "$(date +"%x %X") : NORAD elements aquired"
      mv -f "${norad_data}.new" "${norad_data}"
  else
      echo "$(date +"%x %X") : NORAD elements not available - using old data"
      rm -f "${norad_data}.new"
  fi

  if [ ! -e ${norad_names} ]; then
    touch "${norad_names}"
  fi
  awk '{ print $0; getline; getline; }' "${norad_data}" | tr -d '' > "${norad_names}.tmp"
  if ! cmp -s "${norad_names}" "${norad_names}.tmp"; then
    mv "${norad_names}.tmp" "${norad_names}"
    cat ${cmd_path}/load_norad_names.sql | sed s?CMD_PATH?${cmd_path}? | sqlite3 ${db}
  else
    rm -f "${norad_names}.tmp"
  fi

  echo "$(date +"%x %X") : NORAD elements ready"
fi

sat_list=/tmp/satellites.txt
sat_tle=/tmp/one_sat.tle

# Get current time and 24 hours hence
now_s=$(date +"%s")
end_s=$(date -d "+24 hours" +"%s")

echo "$(date +"%x %X") : Cleaning previously scheduled passes"
# Remove any passes for remainder of day from DB
# (regardless of status)
sqlite3 ${db} "DELETE FROM transits WHERE pass_start >= ${now_s};"

# Remove any 'at' jobs to make way for new jobs
for i in $(atq | awk '{print $1}'); do
  # only remove our own jobs
  at -c "$i" | grep -q "process_transit.sh" 
  if [ $? -eq 0 ]; then
      atrm "$i"
  fi
done

echo "$(date +"%x %X") : Building new schedule"
# Build the new schedule in the DB for each satellite
sqlite3 -separator , ${db} "SELECT sat_name, signal_type FROM satellites;" > ${sat_list}
while IFS=, read -r sat sig_type; do
  # Create a .tle file for just the satellite we care about
  grep "${sat}" $norad_data -A 2 > ${sat_tle}

  if [ -s ${sat_tle} ]; then
    # Schedule the next 24 hours of passes 
    ${cmd_path}/schedule_captures.sh "${sat}" ${sat_tle} ${now_s} ${end_s} ${sig_type}
  else
    echo "$(date +"%x %X") : No NORAD entries for ${sat}!"
  fi
done < ${sat_list}
# clean up the .tle
rm -f ${sat_tle}

echo "$(date +"%x %X") : Resolve conflicts"
conflicts=${cmd_path}/conflicts.txt
${cmd_path}/deconflict.sh
if [ -s ${conflicts} ]; then
    echo "$(date +"%x %X") : Need to resolve conflicts!"
    exit
fi
rm -f ${conflicts}

echo "$(date +"%x %X") : Apply new schedule"
# Now conficts are resolved, schedule the passes of interest
transits=/tmp/transits.txt
sqlite3 -separator , ${db} "SELECT sat_name, pass_start FROM transits WHERE status=\"initial\";" > ${transits}
while IFS=, read -r name start; do
  # Schedule each pass using 'at'
  echo "${cmd_path}/process_transit.sh \"${name}\" ${start} >> ${cmd_path}/process_transit.log 2>&1" | at -t $(date -d @${start} +"%Y%m%d%H%M")
  echo "$(date +"%x %X") : Scheduled \"${name}\" at $(date -d @${start} +"%x %X")"
  #
done < ${transits}
# clean up
rm -f ${transits}

# Flag newly scheduled passes as scheduled
sqlite3 ${db} "UPDATE transits SET status=\"scheduled\" WHERE status=\"initial\" AND pass_start >= ${now_s};"

echo "$(date +"%x %X") : Done $0"

