#!/bin/bash
# Purpose: Decode an LRPT format WAV file into one or more .jpg images
#
# Input parameters:
#   1. LRPT Wav Name
#   2. Satellite Name
#   3. Start (Epoch Time)
#   4. Direction N|S

echo "$(date +"%x %X") : Start $0 $1 \"$2\" $3 $4"

cmd_path=$(readlink -f ${0//decode_LRPT.sh/})
img_dir=${cmd_path}/image

echo "$(date +"%x %X") : Create base image"

root_name=`echo ${1} | sed 's/.*\///' | sed 's/\.wav//'`
qpsk=${img_dir}/${root_name}.qpsk
bmp=${img_dir}/${root_name}.bmp
img=${img_dir}/${root_name}.png

# Extract ymbols to a .qpsk file
meteor_demod -B -o "${qpsk}" "${1}"
if [ $? -eq 0 ]; then
  echo "$(date +"%x %X") : Error generating QPSK"
fi

# Use .qpsk to generate a bitmap image
medet_arm "${qpsk}" "${bmp}" -cd
if [ -e  "${bmp}" ]; then
  rm -f "${qpsk}"
  # Convert the bitpap to a .png
  convert "${bmp}" "${png}"
  if [ $? -eq 0 ]; then
    rm -f "${bmp}"
  else
    echo "$(date +"%x %X") : Error converting bitmap"
  fi
else
  echo "$(date +"%x %X") : Unable to generate bitmap"
fi

echo "$(date +"%x %X") : Done $0"

