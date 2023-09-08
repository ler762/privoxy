/^The current time is: / {
   if ( btime == "" ) btime = $5
   else               etime = $5
   isDOS = 1
   next
}
/^Enter the new time/ { next }
{ # no leading "The current time is: " so it must be a unix seconds since epoch
       if ( NR == 1 ) btime = $1
  else if ( NR == 2 ) etime = $1
  else {
    printf("WTF!?? shere should be only a start and end time\n")
    exit
  }
}
END {
   if ( isDOS ) {
     n = split(btime, b, ":")   # get HH MM SS.CC
     i = split(b[3], sms, ".")  # get SS CC
     b[3] = sms[1];  b[4] = sms[2]

     n = split(etime, e, ":")   # get HH MM SS.CC
     i = split(e[3], sms, ".")  # get SS CC
     e[3] = sms[1];  e[4] = sms[2]

     btime = b[1]*60*60 + b[2]*60 + b[3] + b[4]/100
     etime = e[1]*60*60 + e[2]*60 + e[3] + e[4]/100
   }
   printf("Elapsed time: %05.2f seconds\n", etime - btime)
}

