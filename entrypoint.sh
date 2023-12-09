#!/usr/bin/env sh

set -e

if [ ! -f "/var/bind/named.ca" ]; then
  cp /usr/share/dns-root-hints/named.root /var/bind/named.ca
fi

if [ ! -f "/etc/bind/bind.keys" ]; then
  cp /usr/share/dnssec-root/bind-dnssec-root.keys /etc/bind/bind.keys
fi

named-checkconf
exec named -f -g
