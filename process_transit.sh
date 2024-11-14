#!/bin/bash
#
# Purpose: Receive and decode a specific satellite pass
#
# Input parameters:
#   1. Satellite Name
#   2. Start (Epoch Time)

echo "$(date +"%x %X") : Start $0 \"$1\" $2"

cmd_path=$(readlink -f ${0//process_transit.sh/})
db=${cmd_path}/sat-track.db
wav_dir=${cmd_path}/www/wav

# Get transit details from DB into a variable
set -f
sql="SELECT * FROM transits WHERE sat_name=\"${1}\" AND pass_start=${2} AND status=\"scheduled\";"
pass_row=$(sqlite3 -separator , ${db} "${sql}")
set +f
if [ -z "${pass_row}" ]; then
    ts=$(date -d @${2} +"%H:%M:%S")
    echo "$(date +"%x %X") : No pass found for ${1} @ ${ts}"
    exit
fi

# split the variable 
IFS=, read -r sat_name pass_start pass_end max_elev pass_start_azimuth direction azimuth_at_max device sig_type status <<< "${pass_row}"
unset IFS

timestamp=$(TZ=UTC printf '%(%Y%m%d%H%M%S)T' $pass_start)
outfile=$(echo ${sat_name/ /_}-${timestamp} | tr -d "()")
duration=$(($pass_end - $pass_start))

# Get satellite details from DB into a variable
set -f
sql="SELECT * FROM satellites WHERE sat_name=\"${1}\" AND signal_type=\"${sig_type}\";"
sat_row=$(sqlite3 -separator , ${db} "${sql}")
set +f
if [ -z "${sat_row}" ]; then
    echo "$(date +"%x %X") : No definition for ${1}!"
    exit
fi

# split the variable 
IFS=, read -r sat_name freq gain sig_type dev_id bias_tee sun_min sat_min cal <<< "${sat_row}"
unset IFS

# mark pass active
sql="UPDATE transits SET status=\"active\" WHERE sat_name=\"${1}\" AND pass_start=${2} AND status=\"scheduled\";"
sqlite3 ${db} "${sql}"

${cmd_path}/capture_audio.sh ${wav_dir}/${outfile}.wav ${freq} ${duration} ${gain} ${bias_tee} ${dev_id} ${sig_type}

case ${sig_type} in
APT|LRPT|SSTV|CW)
    ${cmd_path}/decode_${sig_type}.sh ${wav_dir}/${outfile}.wav "${1}" ${2} ${direction}
    ;;

*)
    # Nothing more to do
    ;;
esac

# mark pass complete
sql="UPDATE transits SET status=\"complete\" WHERE sat_name=\"${1}\" AND pass_start=${2} AND status=\"active\";"
sqlite3 ${db} "${sql}"

echo "$(date +"%x %X") : End $0"
echo
echo "========================================================================"
echo
