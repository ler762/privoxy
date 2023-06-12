#!/bin/bash
# shellcheck disable=SC2086
#   is it possible for $(mktemp -q -d /tmp/LSXXXXXXXX) to return embedded blanks?
#
# get the latest StevenBlack hosts file & update the .action file
#
# grab the file
#    https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts
#      (from main page: https://github.com/StevenBlack/hosts)
# sort/de-duplicate and save it as unified-hosts.txt

umask 003

SCRIPT="block-test.awk"

OSNAME=$(/bin/uname)
#   there's some weirdness I don't understand with bash pattern matching, so use evars
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

numaf=$(grep -E '^actionsfile ' ${P}/${config} | grep -vc 'regression-tests.action')
numafExpected=9
# I should have this many action files
if [ "$numaf" -ne $numafExpected ]; then
   echo "Check ${config}; found ${numaf} actionsfiles and there should be ${numafExpected}"
   exit 3
fi

set -x

TD=$(mktemp -q -d /tmp/UNIXXXXXXX)
stat=$?
if [ $stat -ne 0 ]; then
  echo "barf: unable to create tmp directory, status=${stat}"
  exit 5
fi

# get the new hosts file
URL="https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts"

curl -q -sS $URL > ${TD}/unified-hosts.txt
stat=$?
if [ $stat -ne 0 ]; then
   echo "error $stat: curl $URL"
   exit 10
fi

#  get the title, date, etc. header info from the file
head -12 ${TD}/unified-hosts.txt  > ${TD}/unified-hosts.srt

#  remove leading "0.0.0.0 ", leading/trailing spaces, comments and blank lines
sed  -e 's/^0\.0\.0\.0 //'  \
     -e 's/^  *//'  \
     -e 's/  *$//'  \
     -e 's/#.*$//'  \
     -e '/^$/d'    ${TD}/unified-hosts.txt |\
 ./fqdnsort     >> ${TD}/unified-hosts.srt

# save the original Privoxy config
cp -p ${P}/${config}  ${TD}/config-original

# stop using the to-be-updated action file & all others after it
# and turn off privoxy logging
sed \
 -e 's/^actionsfile unified/#actionsfile unified/' \
 -e 's/^actionsfile lightswitch/#actionsfile lightswitch/' \
 -e 's/^actionsfile 1hosts/#actionsfile 1hosts/' \
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

echo "{ +block{unified hosts file} }"    > ${TD}/unified-hosts.new
gawk -f $SCRIPT ${TD}/unified-hosts.srt >> ${TD}/unified-hosts.new

date +'%s  %c' >> ${TD}/timestamp.txt

# restore the original Privoxy config
mv ${TD}/config-original  ${P}/${config}

# so how long did it take?
gawk -f elapsed.awk ${TD}/timestamp.txt

if [ 0 = 1 ]; then
if [ "${DISPLAY:-blank}" != "blank" ] ; then
if [ "$WINDOWS" = 1 ]; then
  new=$(cygpath -wal ${TD}/unified-hosts.new)
  old=$(cygpath -wal ${P}/unified-hosts.action)
  /cygdrive/c/MyProgs/Winmerge/WinmergeU.exe  ${new}  ${old}
elif [ "$LINUX" = 1 ]; then
  meld  ${TD}/unified-hosts.new  ${P}/unified-hosts.action
else
  echo "WTF? Not Windows -or- Linux??"
  exit 1
fi
fi
fi

mv ${P}/unified-hosts.action  ${P}/unified-hosts.old
mv ${TD}/unified-hosts.new    ${P}/unified-hosts.action
