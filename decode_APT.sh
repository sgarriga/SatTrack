#!/bin/bash
#
# Purpose: Decode an APT format WAV file into one or more .jpg images
#
# Input parameters:
#   1. APT Wav Name
#   2. Satellite Name
#   3. Start (Epoch Time)
#   4. Direction N|S

echo "$(date +"%x %X") : Start $0 $1 \"$2\" $3 $4"

cmd_path=$(readlink -f ${0//decode_APT.sh/})
img_dir=${cmd_path}/image

if [ "${4}" = "Northbound" ]; then
  ns="-N"
else
  ns="-S"
fi

echo "$(date +"%x %X") : Create base image"
comment="${2} : $(date -d @${3} +"%Y/%m/%d %H:%M:%S UTC")"
# Get the basic image
root_name=`echo ${1} | sed 's/.*\///' | sed 's/\.wav//'`
img=${img_dir}/${root_name}.png
err=${img_dir}/${root_name}.err
wxtoimg "${ns}" -o -C "${comment}" -t n -i PNG $1 ${img} 2>&1 | tee "${err}"
if grep -q "wxtoimg: warning: couldn.t find telemetry data" "${err}"; then
  rm -f "${img}" "${err}" 
  echo "$(date +"%x %X") : No telemetry data detected"
  echo "$(date +"%x %X") : End $0"
  exit
fi
rm -f "${err}" 

echo "$(date +"%x %X") : Create overlay map"
# Create overlay
tle_file=${cmd_path}/full_norad.tle
overlay=${img_dir}/${root_name}-map.png
wxmap -q -T "${2}" -H ${tle_file} -o ${3} ${overlay}

echo "$(date +"%x %X") : Create overlay image"
# Create image with overlay
img=${img_dir}/${root_name}.1.png
wxtoimg "${ns}" -o -m "${overlay}" -c -A -I -t n -i PNG "${1}" "${img}"

# Now get all the enhancements we can
for enh in ZA MB MD BD CC EC HE HF JF JJ LC TA WV WV-old NO veg ice sea sea-day HVC HVC-precip HVCT HVCT-precip MCIR MCIR-precip MCIR-anaglyph MSA MSA-precip MSA-anaglyph anaglyph canaglyph therm fire class invert bw histeq contrast; do

  echo "$(date +"%x %X") : Create ${enh} + overlay image"
  img=${img_dir}/${root_name}.${enh}.png
  err=${img_dir}/${root_name}.${enh}.err
  wxtoimg "${ns}" -o -m "${overlay}" -c -A -I -e "${enh}" -t n -i PNG "${1}" "${img}" 2>&1 | tee "${err}"
  if grep -q "wxtoimg: warning: couldn.t find telemetry data" "${err}"; then
    rm -f "${img}"
  fi
  rm -f "${err}"

done

# Maybe create thumbnails?

# Clean up the overlay
rm -f "${overlay}"

echo "$(date +"%x %X") : End $0"

