#!/bin/bash
cd ${APP_HOME}

download_looker() {
  echo "$(date) Downloading ${LOOKER_VERSION}.jar" >>/var/log/looker_run.log
  curl --silent -o ${APP_HOME}/looker.jar $(cat looker_jar_loc.txt)/${LOOKER_VERSION}.jar 
  chown looker:looker ${APP_HOME}/looker.jar  
}

check_looker() {
  if [ -e "${APP_HOME}/looker.jar" ]
  then
    echo "$(date) Checking ${LOOKER_VERSION}.jar.md5" >>/var/log/looker_run.log
    echo "$(curl --silent $(cat looker_jar_loc.txt)/${LOOKER_VERSION}.jar.md5)  looker.jar" > /tmp/looker_md5
    md5sum -c /tmp/looker_md5 >>/var/log/looker_run.log 2>&1
    ret_status=$?
    if [ $ret_status -ne 0 ]
    then
      echo "$(date) md5 does not match" >>/var/log/looker_run.log
    fi
    rm /tmp/looker_md5
    return $ret_status
  else
    echo "$(date) ${APP_HOME}/looker.jar does not exist" >>/var/log/looker_run.log
    return 1
  fi
}

check_looker
if [ $? -ne 0 ]
then
  download_looker
fi

echo "$(date) Starting" >>/var/log/looker_run.log
/sbin/setuser looker ${APP_HOME}/looker start >>/var/log/looker_run.log 2>&1

stop_looker() {
  echo "$(date) Stopping" >>/var/log/looker_run.log
  /sbin/setuser looker ${APP_HOME}/looker stop >>/var/log/looker_run.log 2>&1
}

trap 'stop_looker' TERM

while true
do
  sleep 5
done