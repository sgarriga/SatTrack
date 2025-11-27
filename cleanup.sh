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
wav_dir=${cmd_path}/www/wav
if [ -d ${wav_dir} ]; then
  find ${wav_dir} -maxdepth 1 -mtime +${days} -type f -name "*.wav" -exec rm -f {} \;
fi

# Remove old images
img_dir=${cmd_path}/www/img
if [ -d ${img_dir} ]; then
  find ${img_dir} -maxdepth 2 -mtime +${days} -type f \( -name "*.jpg" -o -name "*.bmp" -o -name "*.qpsk" -o -name "*.png" -o -name "*.txt" \) -exec rm -f {} \;
fi

echo "$(date +"%x %X") : Cleaning logs over ${days} days old"
find ${img_dir} -maxdepth 1 -mtime +${days} -type f -name "*.log" -exec rm -f {} \;

echo "$(date +"%x %X") : Done $0"

