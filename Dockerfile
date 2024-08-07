FROM alpine:3.20
RUN apk add --no-cache bind bind-tools && update-dns-root-hints && \
    rm -f /usr/share/dns-root-hints/*.cache && \
    rm -f /usr/share/dnssec-root/bind.keys && \
    rm -rf /etc/bind/* /var/bind/* && \
    rm -rf /etc/periodic/
COPY named.conf /etc/bind/named.conf
COPY entrypoint.sh /named
ENTRYPOINT ["/named"]
