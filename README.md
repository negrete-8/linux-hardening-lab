# linux-hardening-lab

![Vagrant](https://img.shields.io/badge/Vagrant-1868F2?logo=vagrant&logoColor=white)
![Ubuntu](https://img.shields.io/badge/Ubuntu-22.04-E95420?logo=ubuntu&logoColor=white)
![SSH](https://img.shields.io/badge/SSH-Hardened-success)
![Cowrie](https://img.shields.io/badge/Cowrie-Honeypot-red)

Hands-on lab for deploying a hardened SSH server alongside a Cowrie honeypot in a single Vagrant VM. Real SSH listens on a non-standard port with key-only authentication; attackers hitting the default port 22 are silently redirected to the honeypot for capture and analysis.

## Architecture

```
                    Attacker (Internet / LAN)
                            │
                            ▼
                  ┌─────────────────────┐
                  │  Port 22 (decoy)    │ ──── iptables PREROUTING ────┐
                  └─────────────────────┘                              │
                                                                       ▼
                  ┌─────────────────────┐                  ┌─────────────────────┐
                  │  Port 2222 (real)   │                  │  Port 2223 (Cowrie) │
                  │  Key auth only      │                  │  Honeypot capture   │
                  │  Hardened sshd      │                  │  Logs all attempts  │
                  └─────────────────────┘                  └─────────────────────┘
                            │                                          │
                            ▼                                          ▼
                       Legitimate user                          Attacker session
                                                                logged + analyzed
```

## What's Included

- **`vagrant/Vagrantfile`** — Ubuntu 22.04 VM definition (2 vCPU, 2 GB RAM, private network)
- **`scripts/harden_ssh.sh`** — Automated SSH hardening (port change, key auth, restrictions)
- **`scripts/install_cowrie.sh`** — Automated Cowrie honeypot installation
- **`scripts/redirect_port22.sh`** — iptables rule to route port 22 → Cowrie
- **`docs/lab-guide.md`** — Full step-by-step guide (original methodology)

## Quick Start

```bash
# 1. Boot the VM
cd vagrant && vagrant up

# 2. SSH in and run hardening
vagrant ssh
sudo bash /vagrant/scripts/harden_ssh.sh

# 3. Install Cowrie honeypot
sudo bash /vagrant/scripts/install_cowrie.sh

# 4. Redirect port 22 to Cowrie
sudo bash /vagrant/scripts/redirect_port22.sh

# 5. Test from host
ssh -i key_bastionado -p 2222 vagrant@192.168.56.10  # legit shell
ssh vagrant@192.168.56.10                            # → honeypot
```

## Hardening Applied

| Setting | Value | Purpose |
|---------|-------|---------|
| `Port` | `2222` | Move off well-known port |
| `PermitRootLogin` | `no` | Block root login |
| `PasswordAuthentication` | `no` | Key-only authentication |
| `PubkeyAuthentication` | `yes` | Enable public key auth |
| `PermitEmptyPasswords` | `no` | Block empty passwords |
| `AllowUsers` | `vagrant` | Strict user whitelist |
| `LoginGraceTime` | `60` | Limit login window |
| `MaxAuthTries` | `3` | Anti-bruteforce |
| `Banner` | `none` | Hide custom banner |
| `DebianBanner` | `no` | Hide OS version |

## Forensic Analysis

After attackers hit the honeypot, logs are available at:

```bash
sudo -u cowrie tail -f ~cowrie/cowrie/var/log/cowrie/cowrie.log
sudo -u cowrie cat ~cowrie/cowrie/var/log/cowrie/cowrie.json | jq
```

The JSON log contains structured records of every attacker session — IPs, credentials tried, commands executed and downloaded payloads.

## Learning Outcomes

- SSH server hardening per CIS / NIST guidelines
- Automated infrastructure provisioning with Vagrant
- Cowrie honeypot deployment and configuration
- iptables NAT redirection for traffic capture
- Forensic log analysis

## Related Repositories

- [honeypot](https://github.com/negrete-8/honeypot) — Production-grade multi-service honeypot deployment
- [threat-intelligence](https://github.com/negrete-8/threat-intelligence) — Malware samples and IOCs captured

## Legal Notice

> For educational and authorized testing only. Never deploy against systems you do not own or lack written permission to test.
