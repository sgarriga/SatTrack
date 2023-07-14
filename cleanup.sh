#!/bin/bash
#
# Purpose: Clean up DB entries and files for orbital captures over
#          7 days old
#   Input parametera:
#     none
#
# Example:
#  ./cleanup.sh

echo "$(date +"%x %X") : Start $0"
cmd_path=$(readlink -f ${0//cleanup.sh/})
db=${cmd_path}/sat-track.db
days=7


echo "$(date +"%x %X") : Cleaning passes over ${days} days old"

# Remove old passes from DB
end_s=$(date -d "-${days} days" +"%s")
sqlite3 ${db} "DELETE FROM transits WHERE pass_start < ${end_s};"

# Remove old recordings
if [ -d ${cmd_path}/wavs ]; then
  find ${cmd_path}/wavs -maxdepth 1 -mtime +${days} -type f -name "*.wav" -exec rm -f {} \;
fi

# Remove old images
if [ -d ${cmd_path}/image ]; then
  find ${cmd_path}/image -maxdepth 1 -mtime +${days} -type f \( -name "*.jpg" -o -name "*.bmp" -o -name "*.qpsk" -o -name "*.png" \) -exec rm -f {} \;
fi

echo "$(date +"%x %X") : Done $0"

