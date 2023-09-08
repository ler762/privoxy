#!/bin/bash
./make-pgl.sh
printf "\n\n\n"

./make-unified.sh
printf "\n\n\n"

./make-lightswitch.sh
printf "\n\n\n"

./make-1hosts.sh
printf "\n\n\n"

echo "finished $(date)" 
