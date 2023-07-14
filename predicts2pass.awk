## establish a start and end for each pass
## - note the magic numbers in the Awk script
##   * we assume a gap > 180 seconds (3 minutes) means a different pass
##   * we end a pass 30 seconds after the last predict value over the minimum elevation
BEGIN {
  el=0;
  azs=0;
  azm=0;
  start=0;
  last=0;
} 
{ 
  if (start==0) {
    start=$1;
    azs=$6;
  } 
  if ($5>el) {
    el=$5;
    azm=$6;
  } 
  if ((last!=0)&&($1>(last+180))) {
    printf("%d %d %d %d %d\n",start,(last+30),el,azs, azm);
    el=0;
    start=0;
    azs=0;
    azm=0;
  } 
  last=$1;
}
END {
  printf("%d %d %d %d %d\n",start,(last+30),el,azs,asm);
}

