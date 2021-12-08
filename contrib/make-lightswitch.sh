#!/bin/sh
# get the latest lightswitch05 hosts file & update the .action file
#
# grab the files
#    https://www.github.developerdan.com/hosts/lists/ads-and-tracking-extended.txt
#    https://www.github.developerdan.com/hosts/lists/tracking-aggressive-extended.txt
# de-duplicate, and save as lightswitch-hosts.txt

umask 000

SCRIPT="block-test.awk"

set -x

TD=`mktemp -q -d /tmp/LSXXXXXXXX`
stat=$?
if [ $stat -ne 0 ]; then
  echo "barf: unable to create tmp directory, status=${stat}"
  exit 1
fi

# get the new hosts file
curl -q -sS https://www.github.developerdan.com/hosts/lists/ads-and-tracking-extended.txt  > ${TD}/ads-and-tracking-extended.txt
stat=$?
if [ $stat -ne 0 ]; then
   echo "error $stat: curl https://www.github.developerdan.com/hosts/lists/ads-and-tracking-extended.txt"
   exit 10
fi
curl -q -sS https://www.github.developerdan.com/hosts/lists/tracking-aggressive-extended.txt > ${TD}/tracking-aggressive-extended.txt
stat=$?
if [ $stat -ne 0 ]; then
   echo "error $stat: curl https://www.github.developerdan.com/hosts/lists/tracking-aggressive-extended.txt"
   exit 11
fi

#  get the title, date, etc. header info from the files
head -10 ${TD}/ads-and-tracking-extended.txt     > ${TD}/lightswitch-hosts.txt
head -10 ${TD}/tracking-aggressive-extended.txt >> ${TD}/lightswitch-hosts.txt

#  remove leading "0.0.0.0 ", leading/trailing spaces, comments and blank lines
sed  -e 's/^0\.0\.0\.0 //'  \
     -e 's/^  *//'  \
     -e 's/  *$//'  \
     -e 's/#.*$//'  \
     -e '/^$/d'  ${TD}/ads-and-tracking-extended.txt  ${TD}/tracking-aggressive-extended.txt |\
fqdnsort >> ${TD}/lightswitch-hosts.txt

# save the original Privoxy config
cp -p config.txt config-original.txt

# stop using the to-be-updated action file & all others after it
# and turn off privoxy logging
sed \
 -e 's/^actionsfile lightswitch/#actionsfile lightswitch/' \
 -e 's/^actionsfile unified/#actionsfile unified/' \
 -e 's/^actionsfile unblock/#actionsfile unblock/' \
 -e 's/^debug /#debug /'     config.txt > config.new

mv config.new config.txt

# get Privoxy to re-read it's config
curl -q -sS --proxy 127.0.0.1:8118 --referer http://config.privoxy.org/ http://config.privoxy.org/show-status > /dev/null
stat=$?
if [ $stat -ne 0 ]; then
   echo "error $stat: curl -q -sS --proxy 127.0.0.1:8118 --referer http://config.privoxy.org/ http://config.privoxy.org/show-status"
   echo "\'sudo systemctl start privoxy\'  to start Privoxy"
   exit 20
fi

# see how long it takes to make the new .action file
date +'%s  %c' > ${TD}/timestamp.txt

echo "{ +block{new lightswitch hosts file} }"> ${TD}/lightswitch-hosts.new
gawk -f $SCRIPT ${TD}/lightswitch-hosts.txt >> ${TD}/lightswitch-hosts.new

date +'%s  %c' >> ${TD}/timestamp.txt

# restore the original Privoxy config
mv config-original.txt config.txt

# so how long did it take?
gawk -f elapsed.awk ${TD}/timestamp.txt

meld  lightswitch-hosts.new  /etc/privoxy/lightswitch-hosts.action

