#!/bin/bash
#
# Purpose: Decode an SSTV format WAV file into .png images
#
# Input parameters:
#   1. APT Wav Name
#   2. Satellite Name     [not used]
#   3. Start (Epoch Time) [not used]
#   4. Direction N|S      [not used]

echo "$(date +"%x %X") : Start $0 $1 \"$2\" $3 $4"

cmd_path=$(readlink -f ${0//decode_APT.sh/})
img_dir=${cmd_path}/image

# Get the basic image
root_name=`echo ${1} | sed 's/.*\///' | sed 's/\.wav//'`

echo "$(date +"%x %X") : Pass 1 - pd120_decoder"
png=${img_dir}/${root_name}.1.png
python3 "$HOME/pd120_decoder/pd120_decoder/demod.py" "${1}" "${png}"

echo "$(date +"%x %X") : Pass 2 - sstv"
png=${img_dir}/${root_name}.2.png
sstv -d "${1}" -o "${png}"

echo "$(date +"%x %X") : End $0"
