#!/bin/bash
#
# Purpose: Check to see if this is an ARISS SSTV Broadcast date
#   Input parametera:
#   1. Start time to predict passes (seconds since epoch)
#   2. End time to predict passes (seconds since epoch)
#   3. Target signal type : SSTV only
#
# Example: 
#  ./ISS_ZARYA_special.sh 1679363592 1679366889 SSTV

echo "$(date +"%x %X") : Start $0 $1 $2 $3"

# Convert the epoc times to a UTC date
utc_date_s=$(date --date="TZ=UTC" -d @${1} +%F)
utc_date_e=$(date --date="TZ=UTC" -d @${2} +%F)

echo $(date +"%x %X") : "Checking ARISS dates $utc_date_s and $utc_date_e"

if [ "${3}" != "SSTV" ]; then
    echo "$(date +"%x %X") : Only SSTV currently supported for ISS (ZARYA)"
    echo "$(date +"%x %X") : Done $0 returning 1"
    exit 1
fi

if [ ! -e $HOME/.ariss_dates ]; then
    echo "$(date +"%x %X") : No ${HOME}/.ariss_dates file"
    echo "$(date +"%x %X") : Done $0 returning 1"
    exit 1
fi

# Look for either of those dates in the config file
match=$(grep -m 1 -E "^${utc_date_s}|^${utc_date_e}" $HOME/.ariss_dates)
if [ ! -z "$match" ]; then
    echo "$(date +"%x %X") : ARISS Schedule date : $match"
    echo "$(date +"%x %X") : Done $0 $1 returning 0"
    exit 0
else
    if [ $utc_date_s == $utc_date_e ]; then
         echo "$(date +"%x %X") : $utc_date_s is not an ARISS SSTV date"
    else
         echo "$(date +"%x %X") : $utc_date_s & $utc_date_e are not ARISS SSTV dates"
    fi
    echo "$(date +"%x %X") : Done $0 returning 1"
    exit 1
fi

