#!/bin/bash
#
# Purpose: Record the audio-stream of a satellite pass using an RTL-SDR dongle
#
# Input parameters:
#   1. WAV filename (to create)
#   2. Frequency MHz
#   3. Duration Seconds
#   4. Gain
#   5. Frequency Offset
#   6. Bias Tee setting usb|gpio0|off
#   7. RTL-SDR dongle device ID
#   8. Expected data format
#

echo "$(date +"%x %X") : Start $0 $1 $2 $3 $4 $5 $6 $7 $8"
cmd_path=$(readlink -f ${0//capture_audio.sh/})

# Let's have some meaningfull names
outfile=$1
freq=$2
duration=$3
gain=$4
freq_offset=$5
bias_tee=$6
dev_id=$7
format=$8

if [ ${gain} == 0 ]; then
    gain=""
else
    gain="-g ${gain}"
fi

case ${bias_tee} in
usb)
    rtl_biast -b 1
    bias_tee=""
    ;;
gpio0)
    bias_tee="-T"
    ;;
*)
    bias_tee=""
    ;;
esac

if [ $dev_id -eq 0 ]; then
    dev_id=""
else
    dev_id="-d ${dev_id}"
fi

# Unfortunately we don't seem to be able to record in a generic way
# - this is driven by the decoders' needs
case ${format} in
APT)
    sample=60k
    rate=11025
    filter="-F 9"
    channels=1
    ;;

CW)
    sample=8k
    rate=8k
    filter=""
    channels=2
    ;;

LRPT)
    sample=288k
    rate=96k
    filter=""
    channels=2
    ;;

SSTV)
    sample=48k
    rate=11025
    filter="-F 9"
    channels=1
    ;;

*)
    sample=48k
    rate=11025
    filter="-F 9"
    channels=1
    ;;
esac

timeout "${duration}" rtl_fm ${dev_id} ${bias_tee} -f "${freq}"M -s ${sample} "${gain}" -E dc -E deemp ${filter} - | \
  sox -t raw -r ${sample} -b 16 ${sox_extra} -c ${channels} -e signed-integer - -t wav "${outfile}" rate ${rate}

# Turn off Bias-Tee if 'usb' was passed in
if [ $6 = usb ]; then
    rtl_biast -b 0
fi

echo "$(date +"%x %X") : End $0"

