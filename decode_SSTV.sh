#!/bin/bash
#
# Purpose: Decode an SSTV format WAV file into BMP images
#
# Input parameters:
#   1. APT Wav Name
#   2. Satellite Name     [not used]
#   3. Start (Epoch Time) [not used]
#   4. Direction N|S      [not used]

echo "$(date +"%x %X") : Start $0 $1 \"$2\" $3 $4"

cmd_path=$(readlink -f ${0//decode_SSTV.sh/})
img_dir=${cmd_path}/www/img

# Get the base name
root_name=`echo ${1} | sed 's/.*\///' | sed 's/\.wav//'`

bmp=${img_dir}/${root_name}.bmp
slowrx-cli -o "${bmp}" "${1}" 

echo "$(date +"%x %X") : End $0"
