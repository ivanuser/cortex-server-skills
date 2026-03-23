# Log Rotation & Storage Maintenance

> Prevent disk exhaustion with logrotate policies, inode diagnostics, and safe Docker cleanup routines.

## Safety Rules

- Prefer retention and compression over ad-hoc log deletion.
- Back up critical logs before truncating large active files.
- Diagnose inode exhaustion with `df -i` before assuming block storage is full.
- Run destructive Docker cleanup only after validating active containers/volumes.
- Never prune named volumes that contain persistent production data unless explicitly approved.

## Quick Reference

```bash
# Disk and inode status
df -h
df -ih

# Largest paths
sudo du -xh /var --max-depth=2 | sort -h | tail -40

# Validate logrotate configs
sudo logrotate -d /etc/logrotate.conf

# Force one rotation cycle (test)
sudo logrotate -f /etc/logrotate.conf

# Safe docker cleanup (preview)
docker system df
docker ps -a
docker volume ls
```

## Logrotate for Custom Apps

### Node.js app logs

Create `/etc/logrotate.d/myapp-node`:

```text
/var/log/myapp/*.log {
  daily
  rotate 14
  compress
  delaycompress
  missingok
  notifempty
  copytruncate
  create 0640 www-data adm
}
```

### Python app logs

Create `/etc/logrotate.d/myapp-python`:

```text
/var/log/myapi/*.log {
  size 100M
  rotate 10
  compress
  delaycompress
  missingok
  notifempty
  copytruncate
  create 0640 appuser adm
}
```

Validate:

```bash
sudo logrotate -d /etc/logrotate.conf
sudo logrotate -f /etc/logrotate.conf
```

## Inode Exhaustion Diagnostics

Symptoms:
- `No space left on device` while `df -h` still shows free space.

```bash
df -ih
sudo find /var -xdev -type f | wc -l
sudo find /var/log -xdev -type f | wc -l
sudo find /tmp -xdev -type f | wc -l
```

Find directories with massive file counts:

```bash
for d in /var/log /tmp /var/tmp /var/lib/docker; do
  echo "== $d ==";
  sudo find "$d" -xdev -type f 2>/dev/null | sed 's|/[^/]*$||' | sort | uniq -c | sort -nr | head -20;
done
```

## Disk Recovery Checklist

1. Run `df -h` and `df -ih`.
2. Identify top offenders (`du -xh` + file count hot spots).
3. Rotate/vacuum logs and clean package caches.
4. Clean Docker artifacts if host runs containers.
5. Recheck disk and inode health.

```bash
sudo journalctl --vacuum-time=7d
sudo apt-get clean 2>/dev/null || sudo dnf clean all 2>/dev/null || true
```

## Docker Cleanup (Safe Procedure)

### Inspect before prune

```bash
docker ps -a
docker images
docker volume ls
docker system df
```

### Conservative cleanup

```bash
docker container prune -f
docker image prune -f
docker builder prune -f
```

### Aggressive cleanup (with caution)

```bash
# Removes unused images, stopped containers, unused networks, and dangling volumes
docker system prune -a --volumes -f
```

Run only when:
- You confirmed persistent data is in active named volumes still attached to running services.
- You have recent backups/snapshots.

## Monitoring and Alerts

```bash
# Suggested thresholds
# Disk usage alert: >85%
# Inode usage alert: >80%
```

## Troubleshooting

- Logs not rotating: check ownership/mode and run `logrotate -d`.
- App missing logs after rotation: use `copytruncate` or send proper reopen signal.
- Disk still full after cleanup: check deleted-but-open files via `lsof +L1`.
- Docker prune broke service: recreate from compose and restore required volumes from backup.
