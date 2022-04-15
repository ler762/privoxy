#!/bin/bash
# get the latest lightswitch05 hosts file & update the .action file
#
# grab the files
#    https://www.github.developerdan.com/hosts/lists/ads-and-tracking-extended.txt
#    https://www.github.developerdan.com/hosts/lists/tracking-aggressive-extended.txt
# de-duplicate, and save as lightswitch-hosts.txt

umask 000

SCRIPT="block-test.awk"

OSNAME=$(/bin/uname)
#   there's some weirdness with bash pattern matching, so use evars
cygwinMatch="^CYGWIN"
linuxMatch="^Linux"
if [[ "$OSNAME" =~ $cygwinMatch ]]; then
    # windows/cygwin machine
  P="/cygdrive/c/MyProgs/Privoxy.307"
    #  privoxy config & action files are here
  config="config.txt"
  WINDOWS=1;  LINUX=0
elif [[ "$OSNAME" =~ $linuxMatch ]]; then
    # linux machine
  P="/etc/privoxy"
  config="config"
  WINDOWS=0;  LINUX=1
else
  echo "WTF? Not Linux or Cygwin: $OSNAME   DIE!!!"
  exit 1
fi

numaf=`egrep '^actionsfile ' ${P}/${config} | grep -v 'regression-tests.action' | wc -l`
# I should have 7 action files
if [ $numaf -ne 7 ]; then
   echo "Check ${P}/${config}; ${numaf} actionsfiles and there should be 7."
   exit 5
fi

set -x

TD=$(mktemp -q -d /tmp/LSXXXXXXXX)
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
head -10 ${TD}/ads-and-tracking-extended.txt     > ${TD}/lightswitch-hosts.srt
head -10 ${TD}/tracking-aggressive-extended.txt >> ${TD}/lightswitch-hosts.srt

#  remove leading "0.0.0.0 ", leading/trailing spaces, comments and blank lines
sed  -e 's/^0\.0\.0\.0 //'  \
     -e 's/^  *//'  \
     -e 's/  *$//'  \
     -e 's/#.*$//'  \
     -e '/^$/d'  ${TD}/ads-and-tracking-extended.txt  ${TD}/tracking-aggressive-extended.txt |\
 ./fqdnsort   >> ${TD}/lightswitch-hosts.srt

# save the original Privoxy config
cp -p ${P}/${config}  ${TD}/config-original

# stop using the to-be-updated action file & all others after it
# and turn off privoxy logging
sed \
 -e 's/^actionsfile lightswitch/#actionsfile lightswitch/' \
 -e 's/^actionsfile unified/#actionsfile unified/' \
 -e 's/^actionsfile unblock/#actionsfile unblock/' \
 -e 's/^debug /#debug /' \
 ${P}/${config}  > ${TD}/config.new

mv ${TD}/config.new  ${P}/${config}

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
gawk -f $SCRIPT ${TD}/lightswitch-hosts.srt >> ${TD}/lightswitch-hosts.new

date +'%s  %c' >> ${TD}/timestamp.txt

# restore the original Privoxy config
mv ${TD}/config-original  ${P}/${config}

# so how long did it take?
gawk -f elapsed.awk ${TD}/timestamp.txt

if [ $WINDOWS = 1 ]; then
  new=$(cygpath -wal ${TD}/lightswitch-hosts.new)
  old=$(cygpath -wal ${P}/lightswitch-hosts.action)
  /cygdrive/c/MyProgs/Winmerge/WinmergeU.exe  ${new}  ${old}
elif [ $LINUX = 1 ]; then
  meld  ${TD}/lightswitch-hosts.new  ${P}/lightswitch-hosts.action
else
  echo "WTF? Not Windows -or- Linux??"
  exit 1
fi

