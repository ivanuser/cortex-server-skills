# Compliance Scan — NIST 800-53 r5 + CMMC Control Checks

> Scan a Linux server against NIST 800-53 rev 5 and CMMC Level 1/2/3 controls.
> Produces machine-readable JSON output for dashboard consumption.
> Automated scanner: `/usr/local/bin/cortexos-compliance-scan`

## Safety Rules

- All checks are **read-only** — no system changes are made during scanning.
- Remediation commands modify system configuration — review before executing.
- Some checks require root/sudo to read protected files (shadow, audit rules, etc.).
- Compliance is **point-in-time** — re-scan after any system changes.
- Results contain security-sensitive findings — protect `compliance.json` accordingly.
- Never expose compliance data over unencrypted channels.

## Quick Reference

```bash
# Run full compliance scan (outputs to /var/lib/cortexos/dashboard/compliance.json)
sudo cortexos-compliance-scan

# View summary
cat /var/lib/cortexos/dashboard/compliance.json | python3 -c "
import sys,json; d=json.load(sys.stdin)
s=d['summary']
print(f\"Score: {s['score_percent']}% — {s['pass']}/{s['total_controls']} controls passing\")
for f,v in d['families'].items():
    print(f\"  {f}: {v['pass']}/{v['total']} pass\")
"

# View failures only
cat /var/lib/cortexos/dashboard/compliance.json | python3 -c "
import sys,json
for c in json.load(sys.stdin)['controls']:
    if c['status'] == 'fail':
        print(f\"{c['id']} [{c['severity']}] {c['finding']}\")
"
```

## Frameworks Covered

| Framework | Version | Controls Checked |
|-----------|---------|-----------------|
| NIST 800-53 | Rev 5 | 30 controls across 6 families |
| CMMC | 2.0 | Level 1 (17 practices), Level 2 (30 practices) |

## Control Families

| Family | Name | Controls |
|--------|------|----------|
| AC | Access Control | AC-2, AC-3, AC-6, AC-7, AC-8, AC-17 |
| AU | Audit & Accountability | AU-2, AU-3, AU-6, AU-8, AU-9, AU-12 |
| CM | Configuration Management | CM-2, CM-6, CM-7, CM-8 |
| IA | Identification & Authentication | IA-2, IA-5, IA-6 |
| SC | System & Communications Protection | SC-7, SC-8, SC-13, SC-28 |
| SI | System & Information Integrity | SI-2, SI-3, SI-4, SI-5 |

---

## AC — Access Control

### AC-2: Account Management
**CMMC Level:** 1 | **Severity:** High

**What to check:**
```bash
# List all user accounts with login shells
awk -F: '$7 !~ /(nologin|false)/ {print $1, $3, $7}' /etc/passwd

# Check for unauthorized UID 0 accounts (only root should be UID 0)
awk -F: '$3 == 0 && $1 != "root" {print $1}' /etc/passwd

# Accounts with empty/no password
sudo awk -F: '($2 == "" || $2 == "!") && $1 != "*" {print $1}' /etc/shadow

# Check password expiration settings
sudo chage -l <username>

# List accounts that haven't logged in for 90+ days
lastlog | awk 'NR>1 && $0 !~ /Never logged in/ {print $1}'

# Check sudo configuration
sudo cat /etc/sudoers
sudo ls -la /etc/sudoers.d/

# Inactive accounts (no login in 90 days, still enabled)
last -w | head -50
```

**PASS:** Only authorized accounts exist, no extra UID 0, no empty passwords, all accounts have expiration set.
**FAIL:** Unauthorized UID 0 accounts, accounts with no password, no password expiration policy.

**Remediation:**
```bash
# Lock an unauthorized account
sudo passwd -l <username>
# Set password expiration (max 90 days, warn 14 days before)
sudo chage -M 90 -W 14 <username>
# Remove unauthorized UID 0
sudo usermod -u <new_uid> <username>
# Disable inactive account
sudo usermod -L -e 1 <username>
```

---

### AC-3: Access Enforcement
**CMMC Level:** 1 | **Severity:** High

**What to check:**
```bash
# Critical file permissions
stat -c '%a %U %G %n' /etc/passwd    # Should be 644 root root
stat -c '%a %U %G %n' /etc/shadow    # Should be 640 root shadow (or 000)
stat -c '%a %U %G %n' /etc/group     # Should be 644 root root
stat -c '%a %U %G %n' /etc/gshadow   # Should be 640 root shadow
ls -la /etc/ssh/                       # sshd_config should be 600

# Check for world-writable files in system directories
find /etc -perm -002 -type f 2>/dev/null
find /usr -perm -002 -type f 2>/dev/null

# Check for SUID/SGID binaries
find / -perm -4000 -type f 2>/dev/null
find / -perm -2000 -type f 2>/dev/null

# Home directory permissions (should be 700 or 750)
ls -la /home/
```

**PASS:** Critical files have correct ownership and permissions, no unexpected world-writable files, SUID list matches baseline.
**FAIL:** /etc/shadow readable by non-root, world-writable system files found, unexpected SUID binaries.

**Remediation:**
```bash
sudo chmod 644 /etc/passwd
sudo chmod 640 /etc/shadow
sudo chown root:shadow /etc/shadow
sudo chmod 600 /etc/ssh/sshd_config
# Remove world-writable bit
sudo chmod o-w <file>
```

---

### AC-6: Least Privilege
**CMMC Level:** 2 | **Severity:** High

**What to check:**
```bash
# Check for NOPASSWD in sudoers
sudo grep -r 'NOPASSWD' /etc/sudoers /etc/sudoers.d/ 2>/dev/null

# Check if root login is enabled
sudo grep -i '^PermitRootLogin' /etc/ssh/sshd_config

# List users in sudo/admin group
getent group sudo wheel adm 2>/dev/null

# Check for ALL=(ALL) ALL grants (overly permissive)
sudo grep -r 'ALL=(ALL)' /etc/sudoers /etc/sudoers.d/ 2>/dev/null
```

**PASS:** No NOPASSWD entries, root login disabled, minimal sudo group membership.
**FAIL:** NOPASSWD found in sudoers, PermitRootLogin is yes, too many sudo users.

**Remediation:**
```bash
# Remove NOPASSWD from sudoers
sudo visudo  # Remove NOPASSWD entries
# Disable root SSH login
sudo sed -i 's/^#*PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
sudo systemctl restart sshd
```

---

### AC-7: Unsuccessful Logon Attempts
**CMMC Level:** 1 | **Severity:** Medium

**What to check:**
```bash
# Check for faillock or pam_tally2 config
grep -r 'pam_faillock\|pam_tally2' /etc/pam.d/ 2>/dev/null

# Check faillock settings
cat /etc/security/faillock.conf 2>/dev/null

# Check current failed attempts
sudo faillock 2>/dev/null || sudo pam_tally2 2>/dev/null

# Check auth log for failed attempts
sudo grep 'Failed password' /var/log/auth.log 2>/dev/null | tail -20
```

**PASS:** Account lockout configured (faillock/pam_tally2), lockout after 3-5 attempts, auto-unlock after 15+ minutes.
**FAIL:** No lockout mechanism configured, unlimited login attempts allowed.

**Remediation:**
```bash
# Install and configure faillock (modern systems)
sudo cat >> /etc/security/faillock.conf << 'EOF'
deny = 5
unlock_time = 900
fail_interval = 900
EOF
# Add to PAM: /etc/pam.d/common-auth
# auth required pam_faillock.so preauth
# auth [default=die] pam_faillock.so authfail
```

---

### AC-8: System Use Notification
**CMMC Level:** 1 | **Severity:** Low

**What to check:**
```bash
# Check login banners
cat /etc/issue
cat /etc/issue.net
cat /etc/motd

# Check SSH banner config
grep -i '^Banner' /etc/ssh/sshd_config
```

**PASS:** Login banner present with authorized use notice, SSH Banner directive set.
**FAIL:** Empty or default banners, no SSH banner configured.

**Remediation:**
```bash
# Set login banner
sudo tee /etc/issue << 'EOF'
**WARNING** This system is for authorized use only. All activity is monitored and logged.
Unauthorized access will be prosecuted to the fullest extent of the law.
EOF
sudo cp /etc/issue /etc/issue.net
# Set SSH banner
echo 'Banner /etc/issue.net' | sudo tee -a /etc/ssh/sshd_config
sudo systemctl restart sshd
```

---

### AC-17: Remote Access
**CMMC Level:** 1 | **Severity:** High

**What to check:**
```bash
# SSH configuration audit
sudo sshd -T 2>/dev/null | grep -iE 'permitrootlogin|passwordauthentication|protocol|x11forwarding|maxauthtries|permitemptypasswords|clientaliveinterval|clientalivecountmax|logingracetime|allowusers|allowgroups'

# Alternatively parse config directly
grep -vE '^\s*#|^\s*$' /etc/ssh/sshd_config

# Check for other remote access services
ss -tlnp | grep -E ':23|:21|:5900|:3389'

# Check SSH protocol version (should be 2 only)
grep -i '^Protocol' /etc/ssh/sshd_config
```

**PASS:** PermitRootLogin no, PasswordAuthentication no (key-only), Protocol 2, no telnet/FTP/VNC running, MaxAuthTries ≤5.
**FAIL:** Root login permitted, password auth enabled, telnet/FTP active, insecure protocols in use.

**Remediation:**
```bash
sudo sed -i 's/^#*PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
sudo sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
sudo sed -i 's/^#*MaxAuthTries.*/MaxAuthTries 5/' /etc/ssh/sshd_config
sudo sed -i 's/^#*X11Forwarding.*/X11Forwarding no/' /etc/ssh/sshd_config
sudo systemctl restart sshd
```

---

## AU — Audit & Accountability

### AU-2: Event Logging
**CMMC Level:** 2 | **Severity:** High

**What to check:**
```bash
# Is auditd installed?
dpkg -l auditd 2>/dev/null || rpm -q audit 2>/dev/null

# Is auditd running?
systemctl is-active auditd

# Check audit status
sudo auditctl -s
```

**PASS:** auditd installed, service active/running, audit enabled=1.
**FAIL:** auditd not installed or not running.

**Remediation:**
```bash
sudo apt install -y auditd audispd-plugins   # Debian/Ubuntu
sudo yum install -y audit audit-libs          # RHEL/CentOS
sudo systemctl enable --now auditd
```

---

### AU-3: Content of Audit Records
**CMMC Level:** 2 | **Severity:** Medium

**What to check:**
```bash
# Check audit rules
sudo auditctl -l

# Check persistent rules file
cat /etc/audit/rules.d/*.rules 2>/dev/null
cat /etc/audit/audit.rules 2>/dev/null

# Should have rules for: user/group changes, sudo, login events, file access
sudo auditctl -l | grep -cE 'passwd|shadow|sudoers|login|auth'
```

**PASS:** Audit rules configured for key events (user changes, auth, privileged commands, file access).
**FAIL:** No audit rules or only default rules, missing coverage for key event types.

**Remediation:**
```bash
sudo tee /etc/audit/rules.d/cortexos-compliance.rules << 'EOF'
-w /etc/passwd -p wa -k identity
-w /etc/shadow -p wa -k identity
-w /etc/group -p wa -k identity
-w /etc/sudoers -p wa -k sudoers
-w /var/log/auth.log -p wa -k auth_log
-a always,exit -F arch=b64 -S execve -F euid=0 -k root_commands
-w /etc/ssh/sshd_config -p wa -k sshd_config
EOF
sudo augenrules --load
```

---

### AU-6: Audit Record Review, Analysis, and Reporting
**CMMC Level:** 2 | **Severity:** Medium

**What to check:**
```bash
# Check if log monitoring/analysis tools exist
which logwatch 2>/dev/null && echo "logwatch installed"
which aide 2>/dev/null && echo "AIDE installed"
which ossec 2>/dev/null && echo "OSSEC installed"
dpkg -l rsyslog 2>/dev/null | grep -q '^ii' && echo "rsyslog installed"

# Check for centralized logging config
grep -r '@' /etc/rsyslog.d/ 2>/dev/null
cat /etc/rsyslog.conf 2>/dev/null | grep -E '@@|@[^@]'

# Check if audit logs are being rotated
cat /etc/logrotate.d/audit* 2>/dev/null
```

**PASS:** Log monitoring tool installed (logwatch/AIDE/Wazuh), centralized logging configured or regular review process.
**FAIL:** No monitoring tools, logs not reviewed, no centralized logging.

**Remediation:**
```bash
sudo apt install -y logwatch
sudo logwatch --detail Med --range today --output stdout
# Configure centralized logging in /etc/rsyslog.conf:
# *.* @@syslog-server:514
```

---

### AU-8: Time Stamps
**CMMC Level:** 1 | **Severity:** Medium

**What to check:**
```bash
# Check NTP synchronization
timedatectl status
timedatectl show-timesync 2>/dev/null

# Check chrony or ntpd
systemctl is-active chronyd 2>/dev/null || systemctl is-active ntp 2>/dev/null || systemctl is-active systemd-timesyncd 2>/dev/null

# Check NTP sources
chronyc sources 2>/dev/null || ntpq -p 2>/dev/null

# Verify time sync status
timedatectl | grep -i 'synchronized'
```

**PASS:** NTP service running (chrony/ntp/systemd-timesyncd), time synchronized = yes.
**FAIL:** No NTP configured, time not synchronized.

**Remediation:**
```bash
sudo apt install -y chrony
sudo systemctl enable --now chronyd
# Or use systemd-timesyncd:
sudo timedatectl set-ntp true
```

---

### AU-9: Protection of Audit Information
**CMMC Level:** 2 | **Severity:** Medium

**What to check:**
```bash
# Check log file permissions
stat -c '%a %U %G %n' /var/log/auth.log 2>/dev/null
stat -c '%a %U %G %n' /var/log/syslog 2>/dev/null
stat -c '%a %U %G %n' /var/log/audit/audit.log 2>/dev/null
ls -la /var/log/audit/ 2>/dev/null

# Check if logs are append-only or immutable
lsattr /var/log/audit/audit.log 2>/dev/null

# Check audit log rotation/max size config
grep -E 'max_log_file|num_logs|space_left' /etc/audit/auditd.conf 2>/dev/null
```

**PASS:** Log files owned by root/adm, permissions 640 or stricter, audit logs in /var/log/audit/ protected.
**FAIL:** Logs world-readable, wrong ownership, no size/rotation management.

**Remediation:**
```bash
sudo chmod 640 /var/log/auth.log /var/log/syslog
sudo chown root:adm /var/log/auth.log /var/log/syslog
sudo chmod 600 /var/log/audit/audit.log
```

---

### AU-12: Audit Record Generation
**CMMC Level:** 2 | **Severity:** High

**What to check:**
```bash
# Check rsyslog is running
systemctl is-active rsyslog

# Check journald is running
systemctl is-active systemd-journald

# Check rsyslog config captures key facilities
grep -vE '^\s*#|^\s*$' /etc/rsyslog.conf | head -30

# Verify journald persistence
grep -i 'Storage' /etc/systemd/journald.conf 2>/dev/null
ls -la /var/log/journal/ 2>/dev/null
```

**PASS:** rsyslog or journald active, persistent storage configured, key facilities logged.
**FAIL:** Neither rsyslog nor journald running, volatile storage only, missing log facilities.

**Remediation:**
```bash
sudo systemctl enable --now rsyslog
# Make journald persistent:
sudo mkdir -p /var/log/journal
sudo sed -i 's/#Storage=auto/Storage=persistent/' /etc/systemd/journald.conf
sudo systemctl restart systemd-journald
```

---

## CM — Configuration Management

### CM-2: Baseline Configuration
**CMMC Level:** 2 | **Severity:** Medium

**What to check:**
```bash
# Capture package baseline
dpkg -l 2>/dev/null | wc -l || rpm -qa 2>/dev/null | wc -l

# Capture service baseline
systemctl list-unit-files --type=service --state=enabled --no-pager | wc -l

# Check for configuration management tools
which ansible 2>/dev/null || which puppet 2>/dev/null || which chef-client 2>/dev/null

# Check if baseline was ever captured
ls -la /var/lib/cortexos/baseline/ 2>/dev/null
```

**PASS:** Package and service inventory available, baseline snapshot exists or config management tool in use.
**FAIL:** No baseline documented, no config management tooling.

**Remediation:**
```bash
sudo mkdir -p /var/lib/cortexos/baseline
dpkg -l > /var/lib/cortexos/baseline/packages-$(date +%F).txt
systemctl list-unit-files --type=service --state=enabled > /var/lib/cortexos/baseline/services-$(date +%F).txt
```

---

### CM-6: Configuration Settings
**CMMC Level:** 2 | **Severity:** Medium

**What to check:**
```bash
# Kernel security parameters
sysctl net.ipv4.ip_forward                           # Should be 0 (unless router)
sysctl net.ipv4.conf.all.accept_redirects             # Should be 0
sysctl net.ipv4.conf.all.send_redirects               # Should be 0
sysctl net.ipv4.conf.all.accept_source_route           # Should be 0
sysctl net.ipv4.conf.all.log_martians                  # Should be 1
sysctl net.ipv4.tcp_syncookies                         # Should be 1
sysctl net.ipv6.conf.all.accept_redirects              # Should be 0
sysctl kernel.randomize_va_space                       # Should be 2 (full ASLR)
sysctl kernel.dmesg_restrict                           # Should be 1
sysctl kernel.kptr_restrict                            # Should be 2
sysctl fs.suid_dumpable                                # Should be 0
```

**PASS:** All security sysctl parameters set to recommended values, ASLR enabled, ICMP redirects disabled.
**FAIL:** IP forwarding enabled unnecessarily, ASLR disabled, insecure kernel parameters.

**Remediation:**
```bash
sudo tee /etc/sysctl.d/99-cortexos-hardening.conf << 'EOF'
net.ipv4.ip_forward = 0
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.all.log_martians = 1
net.ipv4.tcp_syncookies = 1
net.ipv6.conf.all.accept_redirects = 0
kernel.randomize_va_space = 2
kernel.dmesg_restrict = 1
kernel.kptr_restrict = 2
fs.suid_dumpable = 0
EOF
sudo sysctl --system
```

---

### CM-7: Least Functionality
**CMMC Level:** 2 | **Severity:** Medium

**What to check:**
```bash
# Check for unnecessary services running
systemctl list-units --type=service --state=running --no-pager | grep -iE 'telnet|ftp|rsh|rlogin|tftp|xinetd|avahi|cups'

# Check for open ports
ss -tlnp | awk 'NR>1 {print $4, $6}'

# Check for unnecessary packages
dpkg -l | grep -iE 'telnet-server|vsftpd|rsh-server|xinetd' 2>/dev/null

# List listening services and their ports
ss -tlnp
```

**PASS:** No unnecessary services (telnet, FTP, rsh), only required ports open, no xinetd services.
**FAIL:** Unnecessary services running, unexpected ports open, legacy protocols available.

**Remediation:**
```bash
# Disable unnecessary services
sudo systemctl stop <service> && sudo systemctl disable <service>
# Remove unnecessary packages
sudo apt remove --purge telnetd vsftpd xinetd
```

---

### CM-8: System Component Inventory
**CMMC Level:** 1 | **Severity:** Low

**What to check:**
```bash
# Software inventory
dpkg -l 2>/dev/null | wc -l || rpm -qa 2>/dev/null | wc -l

# Hardware inventory
lscpu | head -15
free -h
lsblk
ip link show | grep -E '^[0-9]'

# OS information
cat /etc/os-release
uname -a
```

**PASS:** System can generate software and hardware inventory on demand.
**FAIL:** Inventory commands fail or return incomplete data. (Informational — typically passes.)

**Remediation:**
```bash
# Document inventory
mkdir -p /var/lib/cortexos/inventory
dpkg -l > /var/lib/cortexos/inventory/software-$(date +%F).txt
lshw -short > /var/lib/cortexos/inventory/hardware-$(date +%F).txt 2>/dev/null
```

---

## IA — Identification & Authentication

### IA-2: Identification and Authentication (Organizational Users)
**CMMC Level:** 1 | **Severity:** High

**What to check:**
```bash
# Check for shared/generic accounts
awk -F: '$7 !~ /(nologin|false)/ && $3 >= 1000 {print $1, $3}' /etc/passwd

# Check for duplicate UIDs
awk -F: '{print $3}' /etc/passwd | sort | uniq -d

# Check for duplicate usernames
awk -F: '{print $1}' /etc/passwd | sort | uniq -d

# Verify all interactive accounts require authentication
sudo awk -F: '$2 == "" || $2 == "!" {print $1}' /etc/shadow
```

**PASS:** All accounts are unique, no shared accounts, no duplicate UIDs, all require authentication.
**FAIL:** Shared accounts detected, duplicate UIDs found, accounts without passwords.

**Remediation:**
```bash
# Set password on passwordless account
sudo passwd <username>
# Lock generic/shared account
sudo passwd -l <username>
```

---

### IA-5: Authenticator Management
**CMMC Level:** 1 | **Severity:** High

**What to check:**
```bash
# Password quality config (pam_pwquality)
cat /etc/security/pwquality.conf 2>/dev/null
grep -r 'pam_pwquality\|pam_cracklib' /etc/pam.d/ 2>/dev/null

# Password aging policy in login.defs
grep -E '^PASS_MAX_DAYS|^PASS_MIN_DAYS|^PASS_MIN_LEN|^PASS_WARN_AGE' /etc/login.defs

# Check all user password aging
sudo chage -l root
for u in $(awk -F: '$3>=1000 && $7!~/nologin|false/ {print $1}' /etc/passwd); do
  echo "=== $u ===" && sudo chage -l "$u" 2>/dev/null
done

# Check for password history enforcement (pam_unix remember)
grep -r 'remember=' /etc/pam.d/ 2>/dev/null
```

**PASS:** Password complexity enforced (minlen ≥ 12, minclass ≥ 3), max age ≤ 90 days, history ≥ 5, warning ≥ 14 days.
**FAIL:** No complexity requirements, passwords never expire, no history enforcement.

**Remediation:**
```bash
# Set password policy in login.defs
sudo sed -i 's/^PASS_MAX_DAYS.*/PASS_MAX_DAYS 90/' /etc/login.defs
sudo sed -i 's/^PASS_MIN_DAYS.*/PASS_MIN_DAYS 1/' /etc/login.defs
sudo sed -i 's/^PASS_WARN_AGE.*/PASS_WARN_AGE 14/' /etc/login.defs

# Configure password complexity
sudo tee /etc/security/pwquality.conf << 'EOF'
minlen = 12
minclass = 3
maxrepeat = 3
dcredit = -1
ucredit = -1
lcredit = -1
ocredit = -1
EOF
```

---

### IA-6: Authenticator Feedback
**CMMC Level:** 1 | **Severity:** Low

**What to check:**
```bash
# Check if password input is masked (not echoed) — verify PAM config
grep -r 'pam_unix' /etc/pam.d/common-password 2>/dev/null

# Check SSH doesn't echo passwords
grep -i 'PrintLastLog' /etc/ssh/sshd_config 2>/dev/null

# Ensure no DISPLAY_LAST_LOGIN override that leaks info
grep -i 'LASTLOG_ENAB\|FAIL_DELAY' /etc/login.defs 2>/dev/null
```

**PASS:** Password input is obscured during entry, no password echoing configured.
**FAIL:** Password echoing enabled. (Rare on standard Linux.)

**Remediation:**
Standard Linux PAM handles this by default. No changes typically needed.

---

## SC — System & Communications Protection

### SC-7: Boundary Protection
**CMMC Level:** 1 | **Severity:** High

**What to check:**
```bash
# Check if firewall is active
sudo ufw status verbose 2>/dev/null || sudo iptables -L -n 2>/dev/null | head -20

# Check default policy
sudo ufw status 2>/dev/null | grep -i 'Default'
sudo iptables -L INPUT -n 2>/dev/null | head -1

# List firewall rules
sudo ufw status numbered 2>/dev/null || sudo iptables -L -n --line-numbers 2>/dev/null

# Check for nftables
sudo nft list ruleset 2>/dev/null | head -20
```

**PASS:** Firewall active, default deny inbound, only required ports open, rules documented.
**FAIL:** No firewall active, default allow policy, excessive open ports.

**Remediation:**
```bash
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow ssh
sudo ufw enable
```

---

### SC-8: Transmission Confidentiality and Integrity
**CMMC Level:** 2 | **Severity:** Medium

**What to check:**
```bash
# SSH encryption algorithms
sudo sshd -T 2>/dev/null | grep -i 'ciphers'
sudo sshd -T 2>/dev/null | grep -i 'macs'
sudo sshd -T 2>/dev/null | grep -i 'kexalgorithms'

# Check for weak ciphers
sudo sshd -T 2>/dev/null | grep -i 'ciphers' | grep -iE 'arcfour|blowfish|3des|cbc'

# Check TLS configuration (if web services present)
openssl s_client -connect localhost:443 </dev/null 2>/dev/null | grep -E 'Protocol|Cipher'
```

**PASS:** Only strong ciphers (AES-256, ChaCha20), no CBC/3DES/RC4, strong MACs and KEX algorithms.
**FAIL:** Weak ciphers available, CBC mode enabled, insecure MAC algorithms.

**Remediation:**
```bash
sudo tee -a /etc/ssh/sshd_config << 'EOF'
Ciphers aes256-gcm@openssh.com,chacha20-poly1305@openssh.com,aes256-ctr
MACs hmac-sha2-512-etm@openssh.com,hmac-sha2-256-etm@openssh.com
KexAlgorithms curve25519-sha256,curve25519-sha256@libssh.org,diffie-hellman-group16-sha512
EOF
sudo systemctl restart sshd
```

---

### SC-13: Cryptographic Protection
**CMMC Level:** 2 | **Severity:** Medium

**What to check:**
```bash
# Check OpenSSL version and FIPS mode
openssl version
cat /proc/sys/crypto/fips_enabled 2>/dev/null

# List available crypto algorithms
openssl ciphers -v 'HIGH:!aNULL:!MD5' 2>/dev/null | head -20

# Check SSH host key types
ls -la /etc/ssh/ssh_host_*_key.pub
for f in /etc/ssh/ssh_host_*_key.pub; do ssh-keygen -l -f "$f" 2>/dev/null; done

# Check for weak keys
find /etc/ssh/ -name '*_key' -exec ssh-keygen -l -f {} \; 2>/dev/null
```

**PASS:** Modern crypto algorithms, RSA keys ≥ 2048 bits, Ed25519 preferred, no deprecated algorithms.
**FAIL:** Weak keys (<2048 bit RSA), deprecated crypto in use, FIPS required but not enabled.

**Remediation:**
```bash
# Regenerate weak SSH keys
sudo ssh-keygen -t ed25519 -f /etc/ssh/ssh_host_ed25519_key -N ""
sudo ssh-keygen -t rsa -b 4096 -f /etc/ssh/ssh_host_rsa_key -N ""
sudo systemctl restart sshd
```

---

### SC-28: Protection of Information at Rest
**CMMC Level:** 2 | **Severity:** Medium

**What to check:**
```bash
# Check for disk encryption (LUKS)
lsblk -f | grep -i 'crypto\|luks'
sudo dmsetup status 2>/dev/null | grep -i crypt

# Check for encrypted partitions
sudo blkid | grep -i 'crypto_LUKS'

# Check swap encryption
swapon --show
cat /etc/crypttab 2>/dev/null
```

**PASS:** Root or data partitions encrypted with LUKS, swap encrypted or disabled.
**FAIL:** No disk encryption detected. (May be N/A for VMs with encrypted storage backend.)

**Remediation:**
```bash
# Disk encryption must be set up at install time.
# For new installs, choose full-disk encryption option.
# For swap: sudo cryptsetup -d /dev/urandom create cryptswap /dev/sdXN
```

---

## SI — System & Information Integrity

### SI-2: Flaw Remediation
**CMMC Level:** 1 | **Severity:** High

**What to check:**
```bash
# Check for pending security updates
apt list --upgradable 2>/dev/null | grep -i security || yum check-update --security 2>/dev/null

# Total pending updates
apt list --upgradable 2>/dev/null | wc -l

# Check unattended-upgrades
dpkg -l unattended-upgrades 2>/dev/null | grep -q '^ii' && echo "installed" || echo "not installed"
cat /etc/apt/apt.conf.d/20auto-upgrades 2>/dev/null

# Current kernel vs available
uname -r
apt list --installed 2>/dev/null | grep linux-image | tail -3

# Last update timestamp
stat -c '%Y' /var/cache/apt/pkgcache.bin 2>/dev/null
```

**PASS:** ≤5 pending updates, unattended-upgrades enabled, kernel current, regular update cadence.
**FAIL:** 20+ pending updates, no automatic updates, kernel outdated, no recent apt update.

**Remediation:**
```bash
sudo apt update && sudo apt upgrade -y
sudo apt install -y unattended-upgrades
sudo dpkg-reconfigure -plow unattended-upgrades
```

---

### SI-3: Malicious Code Protection
**CMMC Level:** 1 | **Severity:** Medium

**What to check:**
```bash
# Check for antivirus
which clamscan 2>/dev/null && echo "ClamAV installed"
dpkg -l clamav 2>/dev/null | grep -q '^ii' && echo "ClamAV package present"
systemctl is-active clamav-freshclam 2>/dev/null

# Check ClamAV database age
ls -la /var/lib/clamav/ 2>/dev/null
sudo freshclam --version 2>/dev/null

# Check for other AV solutions
which rkhunter 2>/dev/null && echo "rkhunter installed"
which chkrootkit 2>/dev/null && echo "chkrootkit installed"
```

**PASS:** ClamAV or equivalent installed, definitions updated within 7 days, freshclam running.
**FAIL:** No antivirus installed, definitions outdated, freshclam not running.

**Remediation:**
```bash
sudo apt install -y clamav clamav-daemon
sudo freshclam
sudo systemctl enable --now clamav-freshclam
sudo systemctl enable --now clamav-daemon
```

---

### SI-4: System Monitoring
**CMMC Level:** 2 | **Severity:** Medium

**What to check:**
```bash
# Check for monitoring tools
systemctl is-active cortexos-stats.timer 2>/dev/null && echo "CortexOS monitoring active"
which nagios 2>/dev/null || which zabbix_agentd 2>/dev/null || which node_exporter 2>/dev/null
dpkg -l prometheus-node-exporter 2>/dev/null | grep -q '^ii' && echo "node_exporter installed"

# Check if system stats are being collected
ls -la /var/lib/cortexos/dashboard/stats.json 2>/dev/null
cat /var/lib/cortexos/dashboard/stats.json 2>/dev/null | python3 -c "import sys,json; print(json.load(sys.stdin).get('ts','no data'))" 2>/dev/null

# Check for intrusion detection
systemctl is-active aide 2>/dev/null || systemctl is-active ossec 2>/dev/null || systemctl is-active wazuh-agent 2>/dev/null
```

**PASS:** Monitoring system active (CortexOS/Prometheus/Zabbix), stats recent (<5 min), IDS present.
**FAIL:** No monitoring tools running, stale data, no intrusion detection.

**Remediation:**
```bash
# CortexOS monitoring should already be installed via cortex-server-os
sudo systemctl enable --now cortexos-stats.timer
# For additional monitoring:
sudo apt install -y prometheus-node-exporter
sudo systemctl enable --now prometheus-node-exporter
```

---

### SI-5: Security Alerts, Advisories, and Directives
**CMMC Level:** 1 | **Severity:** Low

**What to check:**
```bash
# Check for security notification config
cat /etc/apt/apt.conf.d/50unattended-upgrades 2>/dev/null | grep -i 'mail\|notify'

# Check if apticron or similar is installed
which apticron 2>/dev/null && echo "apticron installed"
dpkg -l apt-listchanges 2>/dev/null | grep -q '^ii' && echo "apt-listchanges installed"

# Check for update-notifier
dpkg -l update-notifier-common 2>/dev/null | grep -q '^ii' && echo "update-notifier installed"

# Check needrestart
which needrestart 2>/dev/null && echo "needrestart installed"
```

**PASS:** Update notification tool installed, email notifications configured for security updates.
**FAIL:** No update notification mechanism in place.

**Remediation:**
```bash
sudo apt install -y apticron apt-listchanges
# Configure email in /etc/apticron/apticron.conf
# Set EMAIL="admin@example.com"
```

---

## Output Format

The scanner outputs JSON to `/var/lib/cortexos/dashboard/compliance.json`:

```json
{
  "scan_time": "2026-03-23T13:00:00Z",
  "framework": "NIST-800-53-r5",
  "summary": {
    "total_controls": 30,
    "pass": 22,
    "fail": 5,
    "partial": 2,
    "na": 1,
    "score_percent": 73
  },
  "cmmc": {
    "level1": { "total": 17, "pass": 15, "score": 88 },
    "level2": { "total": 30, "pass": 22, "score": 73 }
  },
  "families": {
    "AC": { "pass": 4, "fail": 1, "total": 6 },
    "AU": { "pass": 5, "fail": 1, "total": 6 }
  },
  "controls": [
    {
      "id": "AC-2",
      "family": "AC",
      "title": "Account Management",
      "status": "fail",
      "severity": "high",
      "cmmc_level": 1,
      "finding": "Found 2 accounts with no password set",
      "evidence": "Users: test, deploy",
      "remediation": "Set passwords or lock accounts: passwd -l <user>"
    }
  ],
  "ts": 1234567890
}
```

## Automated Scanning

The compliance scanner runs on a 6-hour timer via systemd:

- **Service:** `cortexos-compliance.service` (Type=oneshot)
- **Timer:** `cortexos-compliance.timer` (OnBootSec=5min, OnUnitActiveSec=6h)

```bash
# Check timer status
systemctl status cortexos-compliance.timer
# Trigger manual scan
sudo systemctl start cortexos-compliance.service
# View next run time
systemctl list-timers cortexos-compliance.timer
```
