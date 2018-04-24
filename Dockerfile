FROM phusion/baseimage:0.9.22

RUN apt-get update && apt-get -y install \
  ca-certificates \
  curl \
  phantomjs=2.1.1+dfsg-1 \
  libc6-dev \
  libfontconfig1 \
  mysql-client \
  tzdata \
  && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Give children processes 1 minute to timeout
ENV KILL_PROCESS_TIMEOUT=60
# Give all other processes (such as those which have been forked) 2 minutes to timeout
ENV KILL_ALL_PROCESSES_TIMEOUT=120


#FROM sgrio/java-oracle:jdk_8
## start from https://github.com/sgr-io/docker-java-oracle/blob/master/jdk/Dockerfile
ENV DEBIAN_FRONTEND noninteractive

ENV VERSION 8
ENV UPDATE 171
ENV BUILD 11
ENV SIG 512cd62ec5174c3487ac17c61aaa89e8

ENV JAVA_HOME /usr/lib/jvm/java-${VERSION}-oracle
ENV JRE_HOME ${JAVA_HOME}/jre

# install of ca-certificates and curl moved to single RUN apt... command above
#RUN apt-get update && apt-get install ca-certificates curl \
#  -y --no-install-recommends && \
RUN  curl --silent --location --retry 3 --cacert /etc/ssl/certs/GeoTrust_Global_CA.pem \
  --header "Cookie: oraclelicense=accept-securebackup-cookie;" \
  http://download.oracle.com/otn-pub/java/jdk/"${VERSION}"u"${UPDATE}"-b"${BUILD}"/"${SIG}"/jdk-"${VERSION}"u"${UPDATE}"-linux-x64.tar.gz \
  | tar xz -C /tmp && \
  mkdir -p /usr/lib/jvm && mv /tmp/jdk1.${VERSION}.0_${UPDATE} "${JAVA_HOME}" && \
  apt-get autoclean && apt-get --purge -y autoremove && \
  rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

RUN update-alternatives --install "/usr/bin/java" "java" "${JRE_HOME}/bin/java" 1 && \
  update-alternatives --install "/usr/bin/javaws" "javaws" "${JRE_HOME}/bin/javaws" 1 && \
  update-alternatives --install "/usr/bin/javac" "javac" "${JAVA_HOME}/bin/javac" 1 && \
  update-alternatives --set java "${JRE_HOME}/bin/java" && \
  update-alternatives --set javaws "${JRE_HOME}/bin/javaws" && \
  update-alternatives --set javac "${JAVA_HOME}/bin/javac"
## end from https://github.com/sgr-io/docker-java-oracle/blob/master/jdk/Dockerfile

ENV ROOT_HOME /root
ENV USER_HOME /home/looker
ENV APP_HOME $USER_HOME/looker

# Unneeded - already Etc/UTC
# RUN echo Etc/UTC > /etc/timezone 

RUN groupadd looker && useradd -m -g looker -s /bin/bash looker

# Replace content of policy-rc.d in order to allow services to start.
# See here: https://askubuntu.com/questions/365911/why-the-services-do-not-start-at-installation
COPY templates/policy-rc.d /usr/sbin/policy-rc.d
COPY templates/90-looker.conf /etc/sysctl.d/90-looker.conf
RUN chmod 644 /etc/sysctl.d/90-looker.conf

RUN echo "looker     soft     nofile     4096\nlooker     hard     nofile     4096" >> /etc/security/limits.conf

RUN mkdir -p $APP_HOME
WORKDIR $APP_HOME
COPY \
  templates/provision.yml \
  templates/lookerstart.cfg \
  templates/looker_jar_loc.txt \
  $APP_HOME/

ENV LOOKER_VERSION looker-latest

RUN mkdir /etc/service/looker
COPY templates/looker_run.sh /etc/service/looker/run
RUN chmod +x /etc/service/looker/run

RUN set -a && \
  curl https://raw.githubusercontent.com/looker/customer-scripts/master/startup_scripts/looker > $APP_HOME/looker

RUN \ 
  curl `cat $APP_HOME/looker_jar_loc.txt`/looker-latest.jar > $APP_HOME/looker.jar

RUN \
  chown -R looker:looker $USER_HOME && \
  chmod 0755 $APP_HOME/looker

VOLUME "$APP_HOME"
 
# Confifure cron to manage log files
RUN /bin/bash -c "set -o pipefail && echo $'9 1 * * * find $APP_HOME/log -name \'looker.log.????????\' -mtime +7 -exec gzip \'{}\' \; > /dev/null\n\
29 1 * * * find $APP_HOME/log -name \'looker.log.????????.gz\' -mtime +28 -exec rm -f \'{}\' \; > /dev/null'\
  | crontab -u looker -" 

# ENV INTERNODE_PORT 1551
# EXPOSE 1551

# ENV QUEUE_PORT 61616
# EXPOSE 61616

ENV PORT 9999
EXPOSE 9999

ENV API_PORT 19999
EXPOSE 19999

CMD ["/sbin/my_init"]
