# syntax=docker/dockerfile:1

FROM alpine:3.24

ARG BIND_VERSION=9.20.27

LABEL org.opencontainers.image.vendor="Dnomd343"
LABEL org.opencontainers.image.authors="dnomd343@gmail.com"
LABEL org.opencontainers.image.source="https://github.com/dnomd343/bind-docker.git"

RUN apk add --no-cache --no-logfile \
      "bind~${BIND_VERSION}" \
      "bind-tools~${BIND_VERSION}" \
      "bind-dnssec-root~${BIND_VERSION}" \
      "bind-dnssec-tools~${BIND_VERSION}" && \
    \
    # fetch the latest root hints
    update-dns-root-hints && \
    \
    # remove build-only root hints updater dependencies
    sed -i '/^P:dns-root-hints$/,/^$/ { /^D:curl gpgv$/d; }' /lib/apk/db/installed && \
    apk del --no-cache --no-logfile curl gpgv && \
    [ "$(grep -Exc 'P:(curl|gpgv)' /lib/apk/db/installed)" -eq 0 ] && \
    \
    # remove default configurations
    rm -rf /etc/bind/* /var/bind/* && \
    \
    # clean up unnecessary files
    rm /usr/bin/update-dns-root-hints && \
    rm /etc/group- /etc/passwd- /etc/shadow- /etc/periodic/monthly/dns-root-hints

RUN --mount=type=bind,source=named.conf,target=/tmp/named.conf,ro \
    --mount=type=bind,source=entrypoint.sh,target=/tmp/entrypoint.sh,ro \
    \
    cp /tmp/named.conf /etc/bind/named.conf && \
    cp /tmp/entrypoint.sh /named

ENTRYPOINT ["/named"]
