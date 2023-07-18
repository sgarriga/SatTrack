#!/bin/bash
#
# Purpose: Resolve conflicting satellite and orbital captures
#   Input parametera:
#     none
#
# Example:
#  ./deconflict.sh

echo "$(date +"%x %X") : Start $0"
cmd_path=$(readlink -f ${0//deconflict.sh/})
db=${cmd_path}/sat-track.db

conflicts=${cmd_path}/conflicts.txt

sql="SELECT t1.sat_name, t1.pass_start, t1.pass_end, t1.signal_type, t2.sat_name, t2.pass_start, t2.pass_end, t2.signal_type FROM transits t1, transits t2 WHERE t1.status=\"initial\" AND t2.status=\"initial\" AND t2.device == t1.device AND t2.sat_name != t1.sat_name AND t2.pass_start >= t1.pass_start AND t2.pass_start <= t1.pass_end;" 

sqlite3 -separator , ${db} "${sql}" > ${conflicts}
let pass=1
conflict_cnt=$(wc -l < ${conflicts})
while [ -s "${conflicts}" ]; do

    echo "$(date +"%x %X") : Pass ${pass}, ${conflict_cnt} conflicts"
    while IFS=, read -r t1_sat_name t1_pass_start t1_pass_end t1_signal_type t2_sat_name t2_pass_start t2_pass_end t2_signal_type; do

      # Always prefer SSTV
      if [[ ( "${t1_signal_type}" = "SSTV" ) && ( "${t2_signal_type}" != "SSTV" ) ]]; then
          sqlite3  ${db} "DELETE FROM transits WHERE sat_name=\"${t2_sat_name}\" AND pass_start=${t2_pass_start};"
          continue;
      fi
      if [[ ( "${t2_signal_type}" = "SSTV" ) && ( "${t1_signal_type}" != "SSTV" ) ]]; then
          sqlite3  ${db} "DELETE FROM transits WHERE sat_name=\"${t1_sat_name}\" AND pass_start=${t1_pass_start};"
          continue;
      fi

      # Prefer APT to LRPT
      if [[ ("${t1_signal_type}" = "APT" ) && ( "${t2_signal_type}" = "LRPT" ) ]]; then
          sqlite3  ${db} "DELETE FROM transits WHERE sat_name=\"${t2_sat_name}\" AND pass_start=${t2_pass_start};"
          continue;
      fi
      if [[ ( "${t2_signal_type}" = "APT" ) && ( "${t1_signal_type}" = "LRPT" ) ]]; then
          sqlite3  ${db} "DELETE FROM transits WHERE sat_name=\"${t1_sat_name}\" AND pass_start=${t1_pass_start};"
          continue;
      fi

      # Prefer longer pass
      let d1=t1_pass_end-t1_pass_start
      let d2=t2_pass_end-t2_pass_start
      if [[ $d1 -lt $d2 ]]; then
          sqlite3  ${db} "DELETE FROM transits WHERE sat_name=\"${t1_sat_name}\" AND pass_start=${t1_pass_start};"
          continue;
      fi
      if [[ $d1 -gt $d2 ]]; then
          sqlite3  ${db} "DELETE FROM transits WHERE sat_name=\"${t2_sat_name}\" AND pass_start=${t2_pass_start};"
          continue;
      fi

      # Prefer earlier pass
      if [[ $t1_pass_start -lt $t2_pass_start ]]; then
          sqlite3  ${db} "DELETE FROM transits WHERE sat_name=\"${t2_sat_name}\" AND pass_start=${t2_pass_start};"
          continue;
      fi
      if [[ $t1_pass_start -gt $t2_pass_start ]]; then
          sqlite3  ${db} "DELETE FROM transits WHERE sat_name=\"${t1_sat_name}\" AND pass_start=${t1_pass_start};"
          continue;
      fi

      # If we get here, it's probably going to need a manual tweak,
      # but we keep going

    done < ${conflicts}

    # We've done all we can for that pass through the DB, so let's 
    # rebuild the list of conflicts and try again

    sqlite3 -separator , ${db} "${sql}" > ${conflicts}

    # make sure we're not just looping
    cnt=$(wc -l < ${conflicts})
    if [[ $cnt -ge $conflict_cnt ]]; then
        echo "$(date +"%x %X") : Manual conflict resolution needed!"
        break
    fi
    let conflict_cnt=cnt
    
    let pass=pass+1
done

if [[ $conflict_cnt -eq 0 ]]; then
    rm -d ${conflicts}
fi

echo "$(date +"%x %X") : Done $0"

