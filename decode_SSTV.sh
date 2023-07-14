#!/bin/bash
#
# Purpose: Decode an SSTV format WAV file into .png images
#
# Input parameters:
#   1. APT Wav Name
#   2. Satellite Name
#   3. Start (Epoch Time)
#   4. Direction N|S

echo "$(date +"%x %X") : Start $0 $1 \"$2\" $3 $4"

cmd_path=$(readlink -f ${0//decode_APT.sh/})
img_dir=${cmd_path}/image

# Get the basic image
root_name=`echo ${1} | sed s/.&\/// | sed s/\.wav//`

#
png=${img_dir}/${root_name}.png
python3 "$HOME/pd120_decoder/pd120_decoder/demod.py" "${1}" "${png}"
#
echo "$(date +"%x %X") : Pass 2"
png=${img_dir}/${root_name}.2.png
sstv -d "${1}" "${png}"

echo "$(date +"%x %X") : End $0"
