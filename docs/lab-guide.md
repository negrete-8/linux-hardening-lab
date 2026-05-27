# SSH Hardening + Cowrie Honeypot — Lab Guide

End-to-end walkthrough: deploy a Vagrant VM, harden its SSH service, install a Cowrie honeypot, redirect attacker traffic, and analyze captured sessions.

## Prerequisites

- VirtualBox installed
- Vagrant installed
- SSH client (OpenSSH on Linux/macOS or built-in on Windows 10+)

---

## 1. Infrastructure Deployment (Vagrant)

Create a folder for the lab and add a `Vagrantfile`:

```ruby
Vagrant.configure("2") do |config|
  config.vm.box = "ubuntu/jammy64"
  config.vm.network "private_network", ip: "192.168.56.10"
  config.vm.hostname = "srv-seguro"
  config.vm.provider "virtualbox" do |vb|
    vb.memory = "2048"
    vb.cpus = 2
  end
end
```

Boot the VM:

```bash
vagrant up
vagrant ssh
```

You are now logged into the Ubuntu guest as user `vagrant`.

---

## 2. SSH Service Hardening

### 2.1. Key Management (Host → Guest)

On the **host**, generate an SSH key pair:

```bash
ssh-keygen -t rsa -b 4096 -f key_bastionado
```

Copy the public key content to the VM:

```bash
# Inside the VM:
sudo nano /home/vagrant/.ssh/authorized_keys
# Paste the contents of key_bastionado.pub, replacing existing keys
```

### 2.2. Configure `sshd_config`

Edit `/etc/ssh/sshd_config` and apply the following directives:

```ini
Port 2222
PermitRootLogin no
PubkeyAuthentication yes
PasswordAuthentication no
PermitEmptyPasswords no
AllowUsers vagrant
LoginGraceTime 60
MaxAuthTries 3
Banner none
DebianBanner no
```

| Directive | Effect |
|-----------|--------|
| `Port 2222` | Move SSH off the well-known port 22 |
| `PermitRootLogin no` | Block direct root login |
| `PasswordAuthentication no` | Allow only public key authentication |
| `PermitEmptyPasswords no` | Reject accounts with blank passwords |
| `AllowUsers vagrant` | Strict allowlist of accounts |
| `LoginGraceTime 60` | 60-second window to complete authentication |
| `MaxAuthTries 3` | Limit auth attempts per connection |
| `Banner none` / `DebianBanner no` | Hide custom banner and OS version from clients |

### 2.3. Apply and Verify

```bash
sudo systemctl restart ssh
sudo systemctl status ssh
sudo ss -tlnp | grep 2222
```

From the **host**, test the connection:

```bash
ssh -i key_bastionado -p 2222 vagrant@192.168.56.10
```

---

## 3. Honeypot Deployment

### 3.1. System Dependencies

```bash
sudo apt update && sudo apt upgrade -y
sudo apt install -y git python3-venv python3-pip python3-dev libssl-dev libffi-dev build-essential
```

### 3.2. Install Cowrie

Create a dedicated unprivileged user and clone Cowrie:

```bash
sudo adduser --disabled-password --gecos "" cowrie
sudo su - cowrie
git clone https://github.com/cowrie/cowrie.git
cd cowrie
python3 -m venv cowrie-env
source cowrie-env/bin/activate
pip install --upgrade pip
pip install -e .
```

### 3.3. Configure the Decoy

Customize `etc/cowrie.cfg`:

- `hostname` → a tempting target name (e.g. `srv-prod01`)
- `listen_endpoints` → `tcp:2223:interface=0.0.0.0`

Start the honeypot:

```bash
bin/cowrie start
```

### 3.4. Port Redirection

Back on the host shell (exit the `cowrie` user with `exit`):

```bash
sudo iptables -t nat -A PREROUTING -p tcp --dport 22 -j REDIRECT --to-port 2223
sudo iptables -t nat -L PREROUTING -n -v
```

Any connection to port 22 now silently lands in the honeypot, while legitimate users continue to use port 2222.

---

## 4. Audit & Analysis

### 4.1. Simulated Attack (from the Host)

Legitimate session (hardened SSH on port 2222):

```bash
ssh -i key_bastionado -p 2222 vagrant@192.168.56.10
```

Attacker session (port 22 → honeypot):

```bash
ssh vagrant@192.168.56.10
# Enter any password — Cowrie always accepts and drops you in the fake shell
```

### 4.2. Forensic Analysis

Inside the VM:

```bash
sudo -u cowrie bash
cd ~/cowrie/var/log/cowrie

# Plain-text log
less cowrie.log

# Structured JSON log (one event per line)
cat cowrie.json | jq '.'
```

The JSON log captures:
- Source IP and connection metadata
- Username + password attempts
- Every command executed in the fake shell
- SHA-256 hashes of any uploaded / downloaded files
- Session start / end timestamps

### 4.3. Useful Queries

```bash
# Most attempted credentials
jq -r '.username + ":" + .password' cowrie.json | sort | uniq -c | sort -rn | head

# Source IPs by frequency
jq -r '.src_ip' cowrie.json | sort | uniq -c | sort -rn | head

# Commands executed in fake shell
jq -r 'select(.eventid == "cowrie.command.input") | .input' cowrie.json | sort -u
```

---

## Next Steps

- Forward Cowrie events to an external SIEM (Splunk, Wazuh, ELK)
- Set up Telegram or Slack alerts for high-value events (file uploads, exotic commands)
- Auto-submit captured ELF samples to MalwareBazaar
- Extend with web honeypot (Flask) or fake Redis/Docker services
