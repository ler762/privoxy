#!/bin/sh
# get the latest StevenBlack hosts file & update the .action file
#
# grab the file
#    https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts
#      (from main page: https://github.com/StevenBlack/hosts)
# and save it as unified-hosts.txt

umask 000

SCRIPT="block-test.awk"

set -x

TD=`mktemp -q -d /tmp/UNIXXXXXXX`
stat=$?
if [ $stat -ne 0 ]; then
  echo "barf: unable to create tmp directory, status=${stat}"
  exit 1
fi

# get the new hosts file
curl -q -sS https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts > ${TD}/unified-hosts.txt
stat=$?
if [ $stat -ne 0 ]; then
   echo "error $stat: curl https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts"
   exit 10
fi

#  get the title, date, etc. header info from the file
head -14 ${TD}/unified-hosts.txt > ${TD}/unified-hosts.srt

#  remove leading "0.0.0.0 ", leading/trailing spaces and blank lines
sed  -e 's/^0\.0\.0\.0 //'  \
     -e 's/^  *//'  \
     -e 's/  *$//'  \
     -e '/^$/d'    ${TD}/unified-hosts.txt |\
  fqdnsort      >> ${TD}/unified-hosts.srt


# save the original Privoxy config
cp -p config.txt config-original.txt

# stop using the to-be-updated action file & all others after it
# and turn off privoxy logging
sed \
 -e 's/^actionsfile unified/#actionsfile unified/' \
 -e 's/^actionsfile unblock/#actionsfile unblock/' \
 -e 's/^debug /#debug /'     config.txt > config.new

mv config.new config.txt

# get Privoxy to re-read it's config
curl -q -sS --proxy 127.0.0.1:8118  http://config.privoxy.org/show-status > /dev/null
stat=$?
if [ $stat -ne 0 ]; then
   echo "error $stat: curl -q -sS --proxy 127.0.0.1:8118  http://config.privoxy.org/show-status"
   echo "\'sudo systemctl start privoxy\'  to start Privoxy"
   exit 20
fi

# see how long it takes to make the new .action file
date +'%s  %c' > ${TD}/timestamp.txt

echo "{ +block{new unified hosts file} }"> ${TD}/unified-hosts.new
gawk -f $SCRIPT ${TD}/unified-hosts.srt >> ${TD}/unified-hosts.new

date +'%s  %c' >> ${TD}/timestamp.txt

# restore the original Privoxy config
mv config-original.txt config.txt

# so how long did it take?
gawk -f elapsed.awk ${TD}/timestamp.txt

meld  unified-hosts.new  /etc/privoxy/unified-hosts.action

