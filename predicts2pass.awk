## establish a start and end for each pass
##
## our input is 'predict' samples which are above the minimum elevation
## - this simplifies things here
##
## - note the magic numbers below
##   * we assume a gap > 180 seconds (3 minutes) means a different pass
##   * we end a pass 30 seconds after the past 'predict' sample
##
BEGIN {
  max_elev=0;
  azimuth_at_start=0;
  azimuth_at_max_elev=0;
  predict_start=0;
  last_time=0;
} 
{ 
  # it's the start of a new set of predictions
  if (predict_start==0) {
    predict_start=$1;
    azimuth_at_start=$6;
  } 

  # keep track of the highest elevation for this set
  if ($5>max_elev) {
    max_elev=$5;
    azimuth_at_max_elev=$6;
  } 

  # a gap of over 3 minutes means this is a new pass
  if ((last_time!=0)&&($1>(last_time+180))) {
    # print the accumulated pass details adding 30 seconds
    printf("%d %d %d %d %d\n",predict_start,(last_time+30),max_elev,azimuth_at_start, azimuth_at_max_elev);

    # reset for a new pass
    max_elev=0;
    predict_start=0;
    azimuth_at_start=0;
    azimuth_at_max_elev=0;
  } 

  # keep track of the last prediction timestamp
  last_time=$1;
}
END {
  # print the accumulated pass details adding 30 seconds
  printf("%d %d %d %d %d\n",predict_start,(last_time+30),max_elev,azimuth_at_start,asm);
}

