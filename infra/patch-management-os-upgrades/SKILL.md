# Patch Management & OS Upgrades

> Apply security updates safely, handle unattended upgrades, and coordinate reboots with minimal service impact.

## Safety Rules

- Patch in stages (dev, staging, production) for critical systems.
- Use noninteractive apt only with known package prompts and prechecks.
- Snapshot or backup before major package upgrades.
- Reboot only after validating service dependencies and failover coverage.
- Record patched packages and reboot windows for audit trails.

## Quick Reference

```bash
# Update package metadata
sudo apt-get update

# Safe noninteractive upgrade
sudo DEBIAN_FRONTEND=noninteractive apt-get upgrade -y

# Full upgrade (if needed for dependencies/kernel)
sudo DEBIAN_FRONTEND=noninteractive apt-get dist-upgrade -y

# Check if reboot required
test -f /var/run/reboot-required && echo "reboot required"

# List security updates (Ubuntu)
apt list --upgradable 2>/dev/null | grep -i security
```

## Unattended Upgrades (Debian/Ubuntu)

```bash
sudo apt-get install -y unattended-upgrades apt-listchanges
sudo dpkg-reconfigure -plow unattended-upgrades
```

Recommended config checks:

```bash
sudo grep -E 'Unattended-Upgrade|Allowed-Origins|Automatic-Reboot' \
  /etc/apt/apt.conf.d/50unattended-upgrades \
  /etc/apt/apt.conf.d/20auto-upgrades
```

## Manual Patch Runbook

1. Check host health and free disk.
2. Refresh package indexes.
3. Apply upgrades noninteractively.
4. Validate core services.
5. Reboot if required and revalidate.

```bash
df -h
free -h
sudo apt-get update
sudo DEBIAN_FRONTEND=noninteractive apt-get upgrade -y
sudo systemctl --failed
```

## Handling Interactive Prompts

```bash
sudo DEBIAN_FRONTEND=noninteractive \
  apt-get -o Dpkg::Options::="--force-confdef" \
          -o Dpkg::Options::="--force-confold" \
          upgrade -y
```

Use with caution:
- `--force-confold` keeps local configs.
- Review `.dpkg-dist` / `.dpkg-old` files after patching.

## Reboot Orchestration

### Single host

```bash
if [ -f /var/run/reboot-required ]; then
  sudo shutdown -r +5 "Scheduled post-patch reboot"
fi
```

### Rolling restart pattern

1. Drain node from load balancer.
2. Patch node.
3. Reboot if required.
4. Validate health checks.
5. Re-add node to pool.
6. Continue to next node.

## Post-Patch Validation

```bash
uname -r
systemctl is-system-running
systemctl --failed
curl -fsS http://127.0.0.1:<PORT>/health
```

## Troubleshooting

- Apt lock errors: check for concurrent apt process (`ps aux | grep apt`).
- Broken dependencies: run `sudo apt --fix-broken install`.
- Boot issues after kernel update: use previous kernel from boot menu and investigate dkms/modules.
- Services fail post-reboot: compare package changelog and validate config syntax before restart.
