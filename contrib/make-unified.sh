#!/bin/sh
# get the latest StevenBlack hosts file & update the .action file
#
# grab the file
#    https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts
#      (from main page: https://github.com/StevenBlack/hosts)
# and save it as unified-hosts.txt

SCRIPT="block-test_new.awk"

set -x

# get the new hosts file
curl -q -sS https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts > unified-hosts.txt
stat=$?
if [ $stat -ne 0 ]; then
   echo "error $stat: curl https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts"
   exit
fi

#  get the title, date, etc. header info from the file
head -14 unified-hosts.txt > unified-hosts.srt

#  remove leading "0.0.0.0 ", leading/trailing spaces and blank lines
sed  -e 's/^0\.0\.0\.0 //'  \
     -e 's/^  *//'  \
     -e 's/  *$//'  \
     -e '/^$/d'    unified-hosts.txt |\
  fqdnsort      >> unified-hosts.srt


# save the original Privoxy config.txt
cp -p config.txt config-original.txt

# stop using the to-be-updated action file & all others after it
# and turn off privoxy logging
sed -e 's/^actionsfile unified/#actionsfile unified/' \
    -e 's/^actionsfile unblock/#actionsfile unblock/' \
    -e 's/^debug /#debug /'     config.txt > config.new

mv config.new config.txt

# get Privoxy to re-read it's config
curl -q -sS --proxy 127.0.0.1:8118 --referer http://p.p/ http://p.p/show-status > /dev/null

# see how long it takes to make the new .action file
date +%s > timestamp.txt

echo "{ +block{new unified hosts file} }"> unified-hosts.new
gawk -f $SCRIPT unified-hosts.srt       >> unified-hosts.new

date +%s >> timestamp.txt

# restore the original Privoxy config
mv config-original.txt config.txt

# so how long did it take?
gawk -f elapsed.awk timestamp.txt

/cygdrive/c/MyProgs/Winmerge/WinmergeU.exe  unified-hosts.new  unified-hosts.action

