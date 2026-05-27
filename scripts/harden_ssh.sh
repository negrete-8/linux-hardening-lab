#!/bin/bash
# Hardens the SSH server on a Debian/Ubuntu host.
# - Moves SSH from port 22 to 2222
# - Disables password authentication
# - Restricts allowed users
# - Hides banner / OS version
#
# Run as root: sudo bash harden_ssh.sh

set -euo pipefail

SSHD_CONFIG="/etc/ssh/sshd_config"
BACKUP="${SSHD_CONFIG}.bak.$(date +%s)"
ALLOWED_USER="${ALLOWED_USER:-vagrant}"
SSH_PORT="${SSH_PORT:-2222}"

if [[ $EUID -ne 0 ]]; then
  echo "[!] Must run as root" >&2
  exit 1
fi

echo "[+] Backing up sshd_config to $BACKUP"
cp "$SSHD_CONFIG" "$BACKUP"

echo "[+] Applying hardening directives"
# Remove any existing copies of the directives we manage
sed -i -E '/^[#[:space:]]*(Port|PermitRootLogin|PubkeyAuthentication|PasswordAuthentication|PermitEmptyPasswords|AllowUsers|LoginGraceTime|MaxAuthTries|Banner|DebianBanner)[[:space:]]/d' "$SSHD_CONFIG"

cat >> "$SSHD_CONFIG" <<EOF

# --- Hardening applied $(date -Iseconds) ---
Port ${SSH_PORT}
PermitRootLogin no
PubkeyAuthentication yes
PasswordAuthentication no
PermitEmptyPasswords no
AllowUsers ${ALLOWED_USER}
LoginGraceTime 60
MaxAuthTries 3
Banner none
DebianBanner no
EOF

echo "[+] Validating new sshd_config"
sshd -t

echo "[+] Restarting ssh service"
systemctl restart ssh

echo "[+] Verifying service is listening on port ${SSH_PORT}"
ss -tlnp | grep ":${SSH_PORT}" || {
  echo "[!] SSH not listening on ${SSH_PORT} — check 'systemctl status ssh'" >&2
  exit 2
}

echo "[OK] SSH hardened. Connect with:"
echo "     ssh -i <key> -p ${SSH_PORT} ${ALLOWED_USER}@<host>"
echo "[!] Make sure your public key is in ~${ALLOWED_USER}/.ssh/authorized_keys before logging out!"
