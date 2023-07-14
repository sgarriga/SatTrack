#!/bin/bash
#
# Purpose: Decode a CW format WAV file into .txt
#
# Input parameters:
#   1. APT Wav Name
#   2. Satellite Name
#   3. Start (Epoch Time)
#   4. Direction N|S

echo "$(date +"%x %X") : Start $0 $1 \"$2\" $3 $4"

cmd_path=$(readlink -f ${0//decode_CW.sh/})
img_dir=${cmd_path}/image

comment="${2} : $(date -d @${3} +"%Y/%m/%d %H:%M:%S UTC")"

# Get the basic image
root_name=`echo ${1} | sed s/.&\/// | sed s/\.wav//`
txt=${img_dir}/${root_name}.txt

morse2ascii "%{1}" > "${txt}"

echo "$(date +"%x %X") : End $0"
