#!/bin/bash
cd ${APP_HOME}

stop_looker() {
  echo "$(date) Stopping" >>/var/log/looker_run.log
  /sbin/setuser looker ${APP_HOME}/looker stop >>/var/log/looker_run.log 2>&1
}

trap 'stop_looker' TERM

echo "$(date) Starting" >>/var/log/looker_run.log
/sbin/setuser looker ${APP_HOME}/looker start >>/var/log/looker_run.log 2>&1

while true
do
  sleep 5
done