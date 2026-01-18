#!/usr/bin/env sh

set -e

tools="arpaname ddns-confgen delv dig dnssec-cds dnssec-dsfromkey dnssec-importkey dnssec-keyfromlabel dnssec-keygen dnssec-ksr dnssec-revoke dnssec-settime dnssec-signzone dnssec-verify dnstap-read host mdig named-checkconf named-checkzone named-compilezone named-journalprint named-rrchecker nsec3hash nslookup nsupdate rndc rndc-confgen tsig-keygen"
for item in $tools; do
  if [ "$1" = "$item" ]; then
    exec $@
    echo "Failed to run command -> \`$@\`"
    exit 1
  fi
done

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
