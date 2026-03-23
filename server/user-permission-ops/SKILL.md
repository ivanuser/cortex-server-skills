# User & Permission Operations — Access, Sudo, Ownership Fixes

> Create users safely, grant least-privilege sudo access, and fix file permission issues without breaking services.

## Safety Rules

- Use `visudo` and `/etc/sudoers.d/` files; never edit `/etc/sudoers` blindly.
- Prefer group-based permissions over broad `chmod 777`.
- Confirm target user/group before recursive `chown`.
- Preserve a root/console path before modifying auth or sudo rules.
- Record access grants and removals for auditability.

## Quick Reference

```bash
# Create user with home + bash
sudo useradd -m -s /bin/bash devuser
sudo passwd devuser

# Add SSH key
sudo install -d -m 700 -o devuser -g devuser /home/devuser/.ssh
sudo tee /home/devuser/.ssh/authorized_keys >/dev/null
sudo chown devuser:devuser /home/devuser/.ssh/authorized_keys
sudo chmod 600 /home/devuser/.ssh/authorized_keys

# Add to sudo group (Ubuntu/Debian)
sudo usermod -aG sudo devuser

# Validate sudo config
sudo visudo -c
```

## User Creation Playbook

```bash
USERNAME=devuser
sudo useradd -m -s /bin/bash "$USERNAME"
sudo passwd "$USERNAME"
sudo chage -M 90 -W 14 "$USERNAME"
id "$USERNAME"
```

Optional expiry for temporary contractors:
```bash
sudo chage -E 2026-12-31 "$USERNAME"
```

## SSH Access Setup

```bash
USER=devuser
PUBKEY='ssh-ed25519 AAAA... user@laptop'
sudo install -d -m 700 -o "$USER" -g "$USER" /home/$USER/.ssh
echo "$PUBKEY" | sudo tee /home/$USER/.ssh/authorized_keys >/dev/null
sudo chown "$USER:$USER" /home/$USER/.ssh/authorized_keys
sudo chmod 600 /home/$USER/.ssh/authorized_keys
```

## Sudoers Management

### Least-privilege command set

```bash
cat <<'EOF' | sudo tee /etc/sudoers.d/devops-deploy
%deploy ALL=(root) NOPASSWD: /bin/systemctl restart myapp, /bin/systemctl status myapp
EOF
sudo chmod 440 /etc/sudoers.d/devops-deploy
sudo visudo -c
```

### Full sudo (when explicitly required)

```bash
sudo usermod -aG sudo devuser      # Debian/Ubuntu
sudo usermod -aG wheel devuser     # RHEL/Rocky
```

## Permission Repair Patterns

### Nginx 403 due to ownership

```bash
sudo chown -R www-data:www-data /var/www/myapp/public
sudo find /var/www/myapp/public -type d -exec chmod 755 {} \;
sudo find /var/www/myapp/public -type f -exec chmod 644 {} \;
```

### App writable directories

```bash
sudo chown -R appuser:appgroup /var/www/myapp/storage
sudo chmod -R u=rwX,g=rX,o= /var/www/myapp/storage
```

### Shared deploy directory with group write

```bash
sudo chgrp -R deploy /var/www/myapp
sudo chmod -R g+rwX /var/www/myapp
sudo find /var/www/myapp -type d -exec chmod g+s {} \;
```

## Access Review and Cleanup

```bash
# List interactive users
awk -F: '$7 !~ /(nologin|false)/ {print $1 ":" $7}' /etc/passwd

# List sudo members
getent group sudo wheel 2>/dev/null

# Lock user quickly
sudo usermod -L <username>

# Remove sudo access
sudo gpasswd -d <username> sudo 2>/dev/null || true
sudo gpasswd -d <username> wheel 2>/dev/null || true
```

## Troubleshooting

- `Permission denied (publickey)`: check key file ownership and modes first.
- `sudo: parse error`: run `visudo -c`, fix invalid file in `/etc/sudoers.d/`.
- App still returns 403 after `chown`: verify parent directory execute bit and SELinux/AppArmor context.
- Recursive permission changes too broad: restore from backup/snapshot and reapply targeted path-only fix.
