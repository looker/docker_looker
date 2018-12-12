FROM ubuntu:16.04

RUN echo "[INFO]::[installing]::[base packages]" \
    && apt-get update \
    && apt-get install -y --no-install-recommends --no-install-suggests \
        software-properties-common libssl-dev libmcrypt-dev openssl ca-certificates \
        git ntp curl tzdata bzip2 libfontconfig1 phantomjs mysql-client sudo jq \
        fonts-freefont-otf chromium-browser \
    && apt-get autoclean && apt-get clean && apt-get autoremove -y && apt-get clean && rm -rf /var/lib/apt/lists/* \
    && alias chromium='chromium-browser' && sudo ln -s /usr/bin/chromium-browser /usr/bin/chromium

RUN echo "[INFO]::[installing]::[java packages]" \
    && apt-get update \
    && add-apt-repository -y ppa:webupd8team/java \
    && apt-get update \
    && echo oracle-java8-installer shared/accepted-oracle-license-v1-1 boolean true | debconf-set-selections \
    && echo oracle-java8-installer shared/present-oracle-license-v1-1 note | debconf-set-selections \
    && yes | DEBIAN_FRONTEND=noninteractive apt-get install -y  --force-yes --no-install-recommends --no-install-suggests oracle-java8-installer \
    && apt-get remove -y software-properties-common && apt-get remove -y software-properties-common && apt-get autoclean && apt-get clean && apt-get autoremove -y && apt-get clean && rm -rf /var/lib/apt/lists/*

ARG LOOKER_VERSION="6.2"

RUN echo "[INFO]::[configure]::[misc]" \
    && cp /etc/sysctl.conf /etc/sysctl.conf.dist \
    && echo "net.ipv4.tcp_keepalive_time=200" | tee -a /etc/sysctl.conf \
    && echo "net.ipv4.tcp_keepalive_intvl=200" | tee -a /etc/sysctl.conf \
    && echo "net.ipv4.tcp_keepalive_probes=5" | tee -a /etc/sysctl.conf \
    && groupadd -g 1002 "looker" ||  true \
    && useradd -m  -u 1002 -g "looker" "looker" || true\
    && cp /etc/launchd.conf /etc/launchd.conf.dist || true \
    && echo "limit      maxfiles 8192 8192"     | tee -a /etc/launchd.conf \
    && echo "looker     soft     nofile     8192" | tee -a /etc/launchd.conf \
    && echo "looker     hard     nofile     8192" | tee -a /etc/launchd.conf \
    && echo '%looker ALL=(ALL) NOPASSWD:ALL' | tee -a /etc/sudoers

RUN echo "[INFO]::[install]::[looker]" \
    && mkdir -p /home/looker/looker \
    && curl -o /home/looker/looker/looker.jar https://s3.amazonaws.com/download.looker.com/aeHee2HiNeekoh3uIu6hec3W/looker-6.2-latest.jar \
    && curl -o /home/looker/looker/looker-service https://raw.githubusercontent.com/looker/customer-scripts/master/startup_scripts/looker

COPY ./config /tmp/build-configs
RUN echo "[INFO]::[configure]::[looker]" \
    && chmod 0750 /home/looker/looker/looker-service \
    && mv /tmp/build-configs/lookerstart.cfg /home/looker/looker/lookerstart.cfg \
    && mv /tmp/build-configs/database.yml /home/looker/looker/database.yml \
    && mv /tmp/build-configs/provision.yml /home/looker/looker/provision.yml \
    && chown -R looker:looker /home/looker/looker

#
# Move in standard entrypoint script and configure to run through TINI for safety.
#
COPY bin/docker-entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ARG TINI_VERSION="v0.14.0"
ADD https://github.com/krallin/tini/releases/download/${TINI_VERSION}/tini /tini
RUN chmod +x /tini


# /srv is owned by root:root out of the box. Add looker:looker /srv/data because Looker expects to write data to this volume
RUN mkdir /srv/data
RUN chown -R looker:looker /srv/data

USER looker

EXPOSE 9999

ENTRYPOINT ["/tini", "--"]

CMD ["/entrypoint.sh", "/home/looker/looker/looker-service", "start"]
