#!/usr/bin/env sh

set -e

case "${1:-}" in
  arpaname|delv|dig|dnstap-read|host|mdig|nslookup|\
  ddns-confgen|nsupdate|rndc|rndc-confgen|tsig-keygen|\
  dnssec-cds|dnssec-dsfromkey|dnssec-ksr|dnssec-signzone|dnssec-verify|nsec3hash|\
  dnssec-importkey|dnssec-keyfromlabel|dnssec-keygen|dnssec-revoke|dnssec-settime|\
  named-checkzone|named-compilezone|named-journalprint|named-rrchecker)
    exec "$@"
    ;;
esac

[ -f /var/bind/named.ca ] ||
  cp /usr/share/dns-root-hints/named.root /var/bind/named.ca

[ -f /etc/bind/bind.keys ] ||
  cp /usr/share/dnssec-root/bind-dnssec-root.keys /etc/bind/bind.keys

[ "${1:-}" = named-checkconf ] && exec "$@"

[ "$#" -gt 0 ] || set -- -u named -g
exec named "$@"
