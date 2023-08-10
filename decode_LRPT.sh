#!/bin/bash
# Purpose: Decode an LRPT format WAV file into one or more .png images
#
# Input parameters:
#   1. LRPT Wav Name
#   2. Satellite Name
#   3. Start (Epoch Time)
#   4. Direction N|S

echo "$(date +"%x %X") : Start $0 $1 \"$2\" $3 $4"

cmd_path=$(readlink -f ${0//decode_LRPT.sh/})
img_dir=${cmd_path}/www/img

echo "$(date +"%x %X") : Create base image"

root_name=`echo ${1} | sed 's/.*\///' | sed 's/\.wav//'`
qpsk=${img_dir}/work/${root_name}.qpsk
bmp=${img_dir}/${root_name}.bmp
img=${img_dir}/${root_name}.png

# Extract symbols to a .qpsk file
meteor_demod --quiet --batch --output "${qpsk}" "${1}"
if [ $? -ne 0 ]; then
  echo "$(date +"%x %X") : Error generating QPSK"
fi

# Use .qpsk to generate a bitmap image
medet_arm "${qpsk}" "${bmp}" -cd -q
if [ -e "${bmp}" ]; then
  rm -f "${qpsk}"
  # Convert the bitmap to a .png
  convert "${bmp}" "${png}"
  if [ $? -eq 0 ]; then
    rm -f "${bmp}"
  else
    echo "$(date +"%x %X") : Error converting bitmap"
  fi
else
  echo "$(date +"%x %X") : Unable to generate bitmap"
fi

# Clean up useless files
## < 2Kb is not a useful image
find ${img_dir} -type f -name "${root_name}*png" -size -2k -delete

## 1 pixel high is not a useful image
for img in ${img_dir}/${root_name}*png; do
    if file ${img} | grep -q " x 1,"; then
        rm ${img}
    fi

    # since we're keeping the file, create a thumbnail
    thumb=`echo "${img}" | sed "s?img?&/thumb?"`
    convert -thumbnail 300 "${img}" "${thumb}"
done

echo "$(date +"%x %X") : Done $0"

