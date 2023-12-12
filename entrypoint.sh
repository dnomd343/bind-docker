#!/usr/bin/env sh

set -e

if [[ "$1" == "dig" ]] || [[ "$1" == "rndc" ]] || [[ "$1" == "nslookup" ]] || [[ "$1" == "nsupdate" ]] || [[ "$1" == "tsig-keygen" ]] || [[ "$1" == "ddns-confgen" ]] || [[ "$1" == "rndc-confgen" ]]; then
  exec $@
  echo "Failed to run command -> \`$@\`"
  exit 1
fi

if [ ! -f "/var/bind/named.ca" ]; then
  cp /usr/share/dns-root-hints/named.root /var/bind/named.ca
fi

if [ ! -f "/etc/bind/bind.keys" ]; then
  cp /usr/share/dnssec-root/bind-dnssec-root.keys /etc/bind/bind.keys
fi

named-checkconf

if [ $# -eq 0 ]; then
  exec named -g
else
  exec named $@
fi
