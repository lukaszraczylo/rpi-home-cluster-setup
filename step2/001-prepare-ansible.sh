#!/bin/bash

AVAILABLE_HOSTS=$(grep "\." pi-hosts.txt | awk '{print $2}' | cut -d "=" -f2)
for HOST in $AVAILABLE_HOSTS; do
  echo "Working on host $HOST"
  ssh -t root@$HOST 'setup-ntp -c chrony; setup-apkrepos -f; apk update; apk add python3'
done