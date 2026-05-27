#!/bin/bash
# Redirects all incoming TCP traffic on port 22 to the Cowrie honeypot port.
# Real SSH must already be moved to a different port (default: 2222).
#
# Run as root: sudo bash redirect_port22.sh

set -euo pipefail

HONEYPOT_PORT="${HONEYPOT_PORT:-2223}"

if [[ $EUID -ne 0 ]]; then
  echo "[!] Must run as root" >&2
  exit 1
fi

echo "[+] Adding iptables NAT rule: port 22 -> ${HONEYPOT_PORT}"
iptables -t nat -C PREROUTING -p tcp --dport 22 -j REDIRECT --to-port "$HONEYPOT_PORT" 2>/dev/null \
  || iptables -t nat -A PREROUTING -p tcp --dport 22 -j REDIRECT --to-port "$HONEYPOT_PORT"

echo "[+] Current NAT PREROUTING rules:"
iptables -t nat -L PREROUTING -n -v --line-numbers | grep -E "(Chain|22|${HONEYPOT_PORT})"

echo
echo "[OK] Port 22 now silently redirects to honeypot on ${HONEYPOT_PORT}."
echo "[!] To make persistent across reboots, install iptables-persistent:"
echo "    apt-get install -y iptables-persistent && netfilter-persistent save"
