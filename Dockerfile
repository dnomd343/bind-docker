FROM alpine:3.23

RUN apk add --no-cache bind bind-tools bind-dnssec-root bind-dnssec-tools && \

    # fetch the latest root hints
    update-dns-root-hints && \

    # remove default configurations
    rm -rf /etc/bind/ /var/bind/* && \

    # clean up unnecessary files
    rm /etc/group- /etc/passwd- /etc/shadow- /var/log/apk.log /etc/periodic/monthly/dns-root-hints

COPY named.conf /etc/bind/named.conf
COPY entrypoint.sh /named
ENTRYPOINT ["/named"]
