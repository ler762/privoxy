#!/bin/sh
# get the latest lightswitch05 hosts file & update the .action file
#
# grab the files
#    https://www.github.developerdan.com/hosts/lists/ads-and-tracking-extended.txt
#    https://www.github.developerdan.com/hosts/lists/tracking-aggressive-extended.txt
# de-duplicate, and save as lightswitch-hosts.txt

TIMING="no"
#  just do a timing run?  (vs. create a new action file)

SCRIPT="block-test_new.awk"
# SCRIPT="block-test_new.awk  --profile=lightswitchProfile.txt"

########################################################################
if [ $TIMING != "yes" ]; then

set -x

# get the new hosts file
curl -q -sS https://www.github.developerdan.com/hosts/lists/ads-and-tracking-extended.txt  > ads-and-tracking-extended.txt
stat=$?
if [ $stat -ne 0 ]; then
   echo "error $stat: curl https://www.github.developerdan.com/hosts/lists/ads-and-tracking-extended.txt"
   exit
fi
curl -q -sS https://www.github.developerdan.com/hosts/lists/tracking-aggressive-extended.txt > tracking-aggressive-extended.txt
stat=$?
if [ $stat -ne 0 ]; then
   echo "error $stat: curl https://www.github.developerdan.com/hosts/lists/tracking-aggressive-extended.txt"
   exit
fi

#  get the title, date, etc. header info from the files
head -10 ads-and-tracking-extended.txt     > lightswitch-hosts.txt
head -10 tracking-aggressive-extended.txt >> lightswitch-hosts.txt

#  remove leading "0.0.0.0 ", leading/trailing spaces, comments and blank lines
sed  -e 's/^0\.0\.0\.0 //'  \
     -e 's/^  *//'  \
     -e 's/  *$//'  \
     -e 's/#.*$//'  \
     -e '/^$/d'  ads-and-tracking-extended.txt  tracking-aggressive-extended.txt |\
fqdnsort >> lightswitch-hosts.txt

fi  # endif $TIMING != "yes"
########################################################################


# save the original Privoxy config.txt
cp -p config.txt config-original.txt

# stop using the to-be-updated action file & all others after it
# and turn off privoxy logging
sed -e 's/^actionsfile lightswitch/#actionsfile lightswitch/' \
    -e 's/^actionsfile unified/#actionsfile unified/' \
    -e 's/^actionsfile unblock/#actionsfile unblock/' \
    -e 's/^debug /#debug /'     config.txt > config.new

mv config.new config.txt

# get Privoxy to re-read it's config
curl -q -sS --proxy 127.0.0.1:8118 --referer http://p.p/ http://p.p/show-status > /dev/null

# see how long it takes to make the new .action file
date +%s > timestamp.txt

echo "{ +block{new lightswitch hosts file} }"> lightswitch-hosts.new
gawk -f $SCRIPT lightswitch-hosts.txt       >> lightswitch-hosts.new

date +%s >> timestamp.txt

# restore the original Privoxy config
mv config-original.txt config.txt

# so how long did it take?
gawk -f elapsed.awk timestamp.txt

if [ $TIMING != "yes" ]; then

/cygdrive/c/MyProgs/Winmerge/WinmergeU.exe  lightswitch-hosts.new  lightswitch-hosts.action

fi # endif $TIMING != "yes"

