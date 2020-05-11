# Disclaimer

Docker is not currently a supported configuration for Looker. This information is
offered since many Looker customers have expressed interest, but is not guaranteed
in any way.

# Acknowledgements

This image is based upon the Phusion Baseimage available at https://github.com/phusion/baseimage-docker.

The loading of the Oracle JDK is copied from https://github.com/sgr-io/docker-java-oracle.

# Philosphy

## Persistent Storage

Docker is normally used to run processes that don't need to persist data in the image. Looker is not
designed for this, and so the looker directory, usually `/home/looker/looker`, is used to stored and
save critical data across reboots. In particular, the `models` and `models-user-*` directories are
used to store the LookML files, the local git repos associated with them, and the keys needed to
connect to the remote git repos.

The information about users and groups, saved looks, dashboards, and almost anything else not in the
LookML files is stored in a database repository. Most Looker instances use an embedded HyperSQL
database in order to store this information. (Some larger instances and all clustered instances use
a MySQL instance to store this information.) The HyperSQL files are in the `.db` directory.

In order to provide persistent storage, we are using Docker's "Volume" facility. The Docker volume
is specified on the startup command line. A volume should only be used with one Looker instance at
a time. It should not be shared amongst multiple Looker instances.

## Clean Shutdown

Docker does not always shut down running processes cleanly. This means that there is a possiblity
that the persistent storage will be left in a corrupt state. Simple Docker servers are only supposed
to run a single process, not run daemon services. Looker does not fit into this model very well.

The Phusion Baseimage is a basic Ubuntu Docker image that is designed to handle Unix services in a
cleaner manner. Phusion provides a simplified "init" process called my\_init. This allows, for
example, cron jobs to run in the background to clean up log files. This allows us to write
a service handler to allow Looker to shut down gracefully.

# Design Notes

## Running the Looker Service

In Phusion, services are started by the scripts in `/etc/service/<service name>/run`. The run script
should not exit. When the instance is being shut down, the TERM signal is sent to this process.
The Looker start script exits so it does not run continuously. It isn't around to receive the TERM
signal.

The run script, found in `templates/looker_run.sh`, is copied into `/etc/service/looker/run`. This
script calls the standard Looker start script as `/home/looker/looker/looker start`. Then the script
goes into an infitinite loop. A `trap` statement is used to catch the TERM signal. When that signal
is received the script runs `/home/looker/looker/looker stop`.

Also in this script is code that automatically gets the latest revision of Looker. If there is already
a downloaded looker.jar file, the md5 of the most recent release is compared and the new verson is
downloaded if they don't match. If there is not looker.jar - usually on first run with a new
volume - the latest is downloaded.

The file `/var/log/looker_run.log` can be monitored to see what is happening with this run script.

If you want to stop Looker manually, download a new revision, and the restart without restarting
the entire container then you can connect to the container and do the following...

Run `ps -ef`. The output will look like this...

```
UID        PID  PPID  C STIME TTY          TIME CMD
root         1     0  0 19:58 ?        00:00:00 /usr/bin/python3 -u /sbin/my_init -- /bin/bash -l
root         8     1  0 19:58 ?        00:00:00 /usr/bin/runsvdir -P /etc/service
root         9     1  0 19:58 ?        00:00:00 /bin/bash -l
root        10     8  0 19:58 ?        00:00:00 runsv looker
root        11     8  0 19:58 ?        00:00:00 runsv cron
root        12     8  0 19:58 ?        00:00:00 runsv syslog-ng
root        13     8  0 19:58 ?        00:00:00 runsv sshd
root        14     8  0 19:58 ?        00:00:00 runsv syslog-forwarder
root        15    14  0 19:58 ?        00:00:00 tail -F -n 0 /var/log/syslog
root        16    10  0 19:58 ?        00:00:00 /bin/bash ./run
root        17    12  0 19:58 ?        00:00:00 syslog-ng -F -p /var/run/syslog-ng.pid --no-caps
root        18    11  0 19:58 ?        00:00:00 /usr/sbin/cron -f
looker      84     1 24 19:58 ?        00:01:07 java -Dcom.sun.akuma.Daemon=daemonized -XX:+UseG1GC
root       407    16  0 20:03 ?        00:00:00 sleep 5
root       408     9  0 20:03 ?        00:00:00 ps -ef
```


Notice the command `runsv looker` with PID 10 in the listing above. That it the process that runs the
`/etc/service/looker/run` script. Now notice the process `/bin/bash ./run`. It's PPID (Parent PID) is
10 so we know it is the run script itself. It's PID is 16. The java process with PID 84 and run by
the user looker is the Looker server itself.

We can use the command `kill -TERM 16` in order to send the TERM signal to the run script. We can use
the command `kill -TERM $(cat /etc/service/looker/supervise/pid)` to run this without manually
finding the PID. Do this and notice that the java process is stopped.

The run script continues running now. If it is shut down the the process `runsv looker` will notice
and automatically restart it. So `kill -HUP $(cat /etc/service/looker/supervise/pid)` can be
used to terminate the run script altogether. `runsv looker` restarts it, which causes the check and
possible download of looker.jar to happen again, then Looker is started. Running `ps -ef` again will
show that the java process and the `/bin/bash ./run` process have new PIDs.

# Building and Running Looker with Docker

## Building the Looker Image

We are assuming that Docker 1.9 is installed...

```
git clone git@github.com:looker/docker_looker.git
cd docker_looker
docker build -t looker:latest .
```

## Running Looker

```
docker run -d --rm -t \
  --mount source=looker1,target=/home/looker/looker \
  -p 9999:9999 \
  -p 19999:19999 \
  looker:latest
```

### Interactive for Testing

```
docker run --rm -it \
  --mount source=looker1,target=/home/looker/looker \
  -p 9999:9999 \
  -p 19999:19999 \
  looker:latest /sbin/my_init -- /bin/bash -l
```

### Stopping a Running Container

```
# obtain the id of the running container
docker ps
CONTAINER ID        IMAGE               COMMAND                  CREATED             STATUS              PORTS                                              NAMES
b9346ff139c4        looker:latest       "/sbin/my_init -- ..."   20 minutes ago      Up 20 minutes       0.0.0.0:9999->9999/tcp, 0.0.0.0:19999->19999/tcp   ecstatic_wozniak

# stop the container
docker stop b9346ff139c4
```

# Misc

## Rendering 

Chromium is used as a rendering engine for Looker. Chromium stores temporary files/cache inside the /dev/shm folder. By default, Docker only provisions 64 MB for the /dev mount point. If you are running into rendering issues, particularly for large dashboards or PNG/Visualization formats, it may be due to the limited space available in that folder. The solution is to create a new volume in memory and mount /dev/shm 

```
- emptyDir:
    medium: Memory
  name: dshm
```

Alternatively, the shm size can be specified as a runtime argument:

```
--shm-size=1g
```

## Useful Stuff

When you have gone through several updates of the Docker image, the old images build up
in your local image repository. They can potentially take up a lot of space.
This command will clean out intermediate images that are no longer needed.
```
docker rmi $(docker images | grep "none" | awk '/ / { print $3 }')
```
This hint came from https://gist.github.com/bastman/5b57ddb3c11942094f8d0a97d461b430
