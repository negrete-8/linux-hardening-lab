#!/bin/bash
# Installs Cowrie SSH/Telnet honeypot on a Debian/Ubuntu host.
# - Creates dedicated 'cowrie' user
# - Clones official Cowrie repo
# - Sets up Python venv and dependencies
# - Configures honeypot listen port and hostname
#
# Run as root: sudo bash install_cowrie.sh

set -euo pipefail

COWRIE_USER="cowrie"
COWRIE_PORT="${COWRIE_PORT:-2223}"
COWRIE_HOSTNAME="${COWRIE_HOSTNAME:-srv-prod01}"

if [[ $EUID -ne 0 ]]; then
  echo "[!] Must run as root" >&2
  exit 1
fi

echo "[+] Installing system dependencies"
apt-get update -y
apt-get install -y git python3-venv python3-pip python3-dev libssl-dev libffi-dev build-essential authbind

echo "[+] Creating user '${COWRIE_USER}'"
if ! id "$COWRIE_USER" &>/dev/null; then
  adduser --disabled-password --gecos "" "$COWRIE_USER"
fi

echo "[+] Cloning Cowrie as ${COWRIE_USER}"
sudo -u "$COWRIE_USER" -H bash <<EOF
set -euo pipefail
cd ~
if [ ! -d cowrie ]; then
  git clone https://github.com/cowrie/cowrie.git
fi
cd cowrie
python3 -m venv cowrie-env
source cowrie-env/bin/activate
pip install --upgrade pip
pip install -e .

# Copy default config and customize
cp -n etc/cowrie.cfg.dist etc/cowrie.cfg

# Patch hostname and listen port
sed -i -E "s/^hostname\s*=.*/hostname = ${COWRIE_HOSTNAME}/" etc/cowrie.cfg
sed -i -E "s/^listen_endpoints\s*=.*/listen_endpoints = tcp:${COWRIE_PORT}:interface=0.0.0.0/" etc/cowrie.cfg

bin/cowrie start
EOF

echo "[OK] Cowrie installed and listening on port ${COWRIE_PORT}"
echo "[+] Logs: /home/${COWRIE_USER}/cowrie/var/log/cowrie/"
echo "[+] Service control: sudo -u ${COWRIE_USER} ~${COWRIE_USER}/cowrie/bin/cowrie {start,stop,status}"
