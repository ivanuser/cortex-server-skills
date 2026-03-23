# SSH Hardening & Incident Response

> Secure SSH access and respond quickly to brute-force or credential compromise events.
> Focuses on key-based auth, least privilege, and verifiable lock-down steps.

## Safety Rules

- Keep an active root/console session open while changing SSH settings.
- Validate SSH config with `sshd -t` before reloading.
- Roll out SSH changes in two phases for remote hosts to avoid lockout.
- Store emergency break-glass access separately and audit usage.
- Treat suspected key compromise as an incident requiring immediate rotation.

## Quick Reference

```bash
# Backup and edit
sudo cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak.$(date +%s)
sudoedit /etc/ssh/sshd_config

# Validate and reload
sudo sshd -t
sudo systemctl reload sshd

# Check effective settings
sudo sshd -T | egrep 'permitrootlogin|passwordauthentication|pubkeyauthentication|port|maxauthtries'

# Review auth failures
sudo grep -E 'Failed password|Invalid user' /var/log/auth.log | tail -100
```

## Baseline Hardened `sshd_config`

```text
Port 22
Protocol 2
PermitRootLogin no
PasswordAuthentication no
KbdInteractiveAuthentication no
PubkeyAuthentication yes
PermitEmptyPasswords no
MaxAuthTries 4
LoginGraceTime 30
X11Forwarding no
AllowUsers deploy opsadmin
```

Notes:
- Keep `Port 22` unless there is a clear policy reason to change it.
- If changing port, update firewall and monitoring together.

## Enforce Ed25519 Keys

```bash
# Generate on client machine
ssh-keygen -t ed25519 -a 100 -C "deploy@prod"

# Install key
ssh-copy-id -i ~/.ssh/id_ed25519.pub deploy@server
```

Restrict weak key types if required:
```text
PubkeyAcceptedAlgorithms ssh-ed25519,rsa-sha2-512,rsa-sha2-256
```

## Brute-Force Detection

```bash
# Top source IPs with failed auth
sudo grep 'Failed password' /var/log/auth.log \
 | awk '{print $(NF-3)}' | sort | uniq -c | sort -nr | head -20

# Invalid usernames attempted
sudo grep 'Invalid user' /var/log/auth.log \
 | awk '{print $8}' | sort | uniq -c | sort -nr | head -20
```

## Containment Playbook (Suspected Compromise)

1. Restrict ingress to trusted admin IPs temporarily.
2. Disable password auth if still enabled.
3. Rotate affected SSH keys and remove unknown authorized keys.
4. Force user credential reset for impacted accounts.
5. Review command history, sudo logs, and recent service changes.

```bash
# Disable password auth quickly
sudo sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
sudo sshd -t && sudo systemctl reload sshd

# Lock suspicious account
sudo usermod -L <username>

# Remove unauthorized key
sudo sed -i '/<fingerprint_or_comment>/d' /home/<user>/.ssh/authorized_keys
```

## Optional Fail2ban

```bash
sudo apt-get install -y fail2ban
cat <<'EOF' | sudo tee /etc/fail2ban/jail.d/sshd.local
[sshd]
enabled = true
maxretry = 5
findtime = 10m
bantime = 1h
EOF
sudo systemctl restart fail2ban
sudo fail2ban-client status sshd
```

## Forensic Pointers

```bash
sudo last -a | head -40
sudo lastb -a | head -40
sudo journalctl -u ssh -S "24 hours ago" --no-pager | tail -200
```

## Troubleshooting

- Locked out after config change: restore backup config from console and reload sshd.
- `sshd -t` fails: fix syntax first; do not restart until validation passes.
- Key auth still failing: check ownership and mode (`~/.ssh` `700`, `authorized_keys` `600`).
- Unexpected auth prompts: verify `AuthenticationMethods` and disabled keyboard-interactive auth.
