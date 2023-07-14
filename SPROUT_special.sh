#!/bin/bash
#
# Purpose: Perform special schedule edits for SPROUT 
#          On Sundays (in Japan) look for SSTV, else CW.
#   Input parametera:
#   1. Start time to predict passes (seconds since epoch)
#   2. End time to predict passes (seconds since epoch)
#   3. Target signal type : SSTV or CW
#
# Example:
#   ./SPROUT_special.sh 1617422399 1617423210 SSTV

echo "$(date +"%x %X") : Start $0 $1 $2 $3 $4"
# What day of the week is it?
jst_dow_s=$(date --date="TZ==Asia/Tokyo" -d @${1} +"%a")
jst_dow_e=$(date --date="TZ==Asia/Tokyo" -d @${2} +"%a")

dow=${jst_dow_s}
if [ "${jst_dow_e}" = "Sun" ]; then
  dow=${jst_dow_e}
fi

case "${3}" in
  SSTV)
    case "${dow}" in
      Sun)
        rc=0
        ;;
      *)
        rc=1
        ;;
    esac
    ;;
  *)
    case "${dow}" in
      Sun)
        rc=1
        ;;
      *)
        rc=0
        ;;
    esac
    ;;
esac

if [ ${rc} -eq 0 ]; then
    echo "$(date +"%x %X") : ${3} allowed on ${dow}"
else
    echo "$(date +"%x %X") : ${3} disallowed on ${dow}"
fi

echo "$(date +"%x %X") : Done $0 returning ${rc}"
exit ${rc}

