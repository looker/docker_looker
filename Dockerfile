FROM ubuntu:latest
# The ubuntu:latest tag points to the "latest LTS"
# We use Ubuntu Linux (LTS releases) for our internal Looker hosting, and recommend it for customers who do not have a Linux preference.

ARG LOOKER_VERSION="6.12"
ARG LOOKER_LICENSE_KEY="REPLACE-WITH-LOOKER-LICENSE-KEY"
ARG LOOKER_LICENSE_EMAIL="your.company@email.com"

RUN echo "[INFO]::[installing]::[base packages]" \
    && ln -snf /usr/share/zoneinfo/America/Los_Angeles /etc/localtime && echo "America/Los_Angeles" > /etc/timezone \
    && apt-get update \
    && apt-get install -y --no-install-recommends --no-install-suggests \
    software-properties-common libssl-dev libmcrypt-dev openssl ca-certificates \
    git ntp curl tzdata bzip2 libfontconfig1 phantomjs mysql-client sudo jq \
    fonts-freefont-otf chromium-browser openjdk-8-jdk \
    && apt-get autoclean && apt-get clean && apt-get autoremove -y && apt-get clean && rm -rf /var/lib/apt/lists/* \
    && alias chromium='chromium-browser' && sudo ln -s /usr/bin/chromium-browser /usr/bin/chromium

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

RUN echo "[INFO]::[download]::[looker]" \
    && mkdir -p /home/looker/looker \
    && curl -X POST -H 'Content-Type: application/json' \
    -d '{"lic": "'${LOOKER_LICENSE_KEY}'", "email": "'${LOOKER_LICENSE_EMAIL}'", "latest": "specific", "specific": "looker-'${LOOKER_VERSION}'-latest.jar"}' \
    https://apidownload.looker.com/download | jq .url | xargs curl -o /home/looker/looker/looker.jar

RUN echo "[INFO]::[install]::[looker]" \
    && curl -o /home/looker/looker/looker-service https://raw.githubusercontent.com/looker/customer-scripts/master/startup_scripts/looker

COPY ./config /tmp/build-configs

RUN echo "[INFO]::[configure]::[looker]" \
    && chmod 0750 /home/looker/looker/looker-service \
    && mv /tmp/build-configs/lookerstart.cfg /home/looker/looker/lookerstart.cfg \
    && mv /tmp/build-configs/database.yml /home/looker/looker/database.yml \
    && mv /tmp/build-configs/provision.yml /home/looker/looker/provision.yml \
    && chown -R looker:looker /home/looker/looker

# Move in standard entrypoint script and configure to run through TINI for safety.
COPY bin/docker-entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENV TINI_VERSION v0.18.0
ADD https://github.com/krallin/tini/releases/download/${TINI_VERSION}/tini /tini
RUN chmod +x /tini

# /srv is owned by root:root out of the box. Add looker:looker /srv/data because Looker expects to write data to this volume
RUN mkdir /srv/data
RUN chown -R looker:looker /srv/data

USER looker

EXPOSE 9999

ENTRYPOINT ["/tini", "--"]

CMD ["/entrypoint.sh", "/home/looker/looker/looker-service", "start"]
