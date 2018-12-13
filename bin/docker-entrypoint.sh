#!/usr/bin/env bash

setHostname() {
    # If we're in ECS land, lets get host name from the meta data on the ec2 node
    if [[ ! -z "${ECS_CONTAINER_METADATA_FILE}" ]]; then
        _HOSTNAME=$(curl -s -XGET http://169.254.169.254/latest/meta-data/local-hostname)
    else
        _HOSTNAME=${HOSTNAME:-$(hostname)}
    fi

    sudo hostname ${_HOSTNAME}
}

_HOSTNAME=""
setHostname

echo "hostname:[${_HOSTNAME}]"

# dynamic looker args created at run time for the container.
# this is needed for proper clustering.
if [[ "$(cat /home/looker/looker/lookerstart.cfg)" != *"--hostname"* ]]; then
    echo "[Appending hostname]::[${_HOSTNAME}]::[/home/looker/looker/lookerstart.cfg]"
    echo "" >> /home/looker/looker/lookerstart.cfg
    echo "LOOKERARGS=\"\${LOOKERARGS} --hostname=${_HOSTNAME}\"" >> /home/looker/looker/lookerstart.cfg
fi

# the exit process isn't cleaning itself up, so we'll purge these if we see them.
if [[ -f "/home/looker/looker/.deploying" ]]; then
    echo "Removing [/home/looker/looker/.deploying] file"
    rm /home/looker/looker/.deploying
fi

if [[ -f "/home/looker/looker/.starting" ]]; then
    echo "Removing [/home/looker/looker/.starting] file"
    rm /home/looker/looker/.starting
fi

echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
echo "starting up container for [looker] service"

echo "[startup args configured]++++++++++++++++++++++++++++++++++++++"
cat /home/looker/looker/lookerstart.cfg

echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
echo "Permisssion the volume mount"

echo "[chown -R looker:looker /srv/data/looker]++++++++++++++++++++++"
# /srv is owned by root:root out of the box. Add looker:looker /srv/data because Looker expects to write data to this volume
sudo chown -R looker:looker /srv/data

exec $@
