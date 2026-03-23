# Incident Diagnostics — System Troubleshooting & Root Cause Analysis

> Triage Linux incidents quickly using CPU, memory, disk, process, and network evidence.
> Prioritize safe data collection first, then apply the smallest fix that restores service.

## Safety Rules

- Collect evidence before restarting services unless there is an active outage requiring immediate recovery.
- Avoid destructive commands (`kill -9`, `truncate`, firewall changes) until root cause is identified.
- Prefer targeted process signaling over rebooting a whole host.
- Keep a timeline of actions during incidents to support rollback and postmortems.
- If disk is full, preserve logs needed for forensics before cleanup.

## Quick Reference

```bash
# 60-second triage snapshot
date; hostname; uptime
free -h
df -h
ss -tulpen | head -40
ps aux --sort=-%cpu | head -15
ps aux --sort=-%mem | head -15
journalctl -p err -n 80 --no-pager

# Process deep dive
top -H -p <PID>
sudo lsof -p <PID> | head -50
sudo strace -f -p <PID> -tt -s 128

# Network checks
ss -tulpen
sudo tcpdump -nn -i any host <IP> and port <PORT>
nmap -Pn -p <PORT> <HOST>
```

## Triage Workflow

1. Confirm scope: one host, one service, one AZ/region, or global.
2. Capture host health snapshot (CPU/memory/disk/network).
3. Verify service status and recent logs.
4. Identify bottleneck type: CPU saturation, memory pressure, IO wait, network path, or app errors.
5. Apply minimal mitigation and verify recovery.
6. Collect artifacts for post-incident review.

## Host Baseline Checks

```bash
# Time and load
date
uptime
cat /proc/loadavg

# CPU and memory pressure
vmstat 1 5
mpstat -P ALL 1 3 2>/dev/null || true
free -h
cat /proc/meminfo | egrep 'MemTotal|MemAvailable|SwapTotal|SwapFree'

# Disk and inode usage
df -h
df -ih

# IO and blocked tasks
iostat -xz 1 3 2>/dev/null || true
dmesg -T | tail -80
```

## Process Profiling

### Find runaway processes

```bash
ps -eo pid,ppid,user,%cpu,%mem,etime,cmd --sort=-%cpu | head -20
ps -eo pid,ppid,user,%cpu,%mem,etime,cmd --sort=-%mem | head -20
```

### Thread-level hotspots

```bash
top -H -p <PID>
```

### Syscall-level behavior (hangs, loops, lock waits)

```bash
# Observe without modifying process state
sudo strace -f -p <PID> -tt -s 128
```

Patterns:
- Repeated `futex` waits: lock contention.
- Repeated `connect` or `recvfrom` timeouts: downstream dependency/network issue.
- Repeated `open` failures: missing file/path/permission issue.

### Open files and sockets

```bash
sudo lsof -p <PID>
sudo lsof -i -n -P | grep <PID>
```

## Network Diagnostics

### Is the service actually listening?

```bash
ss -tulpen | grep -E ':80|:443|:<PORT>'
sudo lsof -iTCP:<PORT> -sTCP:LISTEN -n -P
```

### Local and remote path checks

```bash
curl -vk http://127.0.0.1:<PORT>/health
curl -vk https://<PUBLIC_HOST>/health
```

### Firewall and packet visibility

```bash
# UFW / nftables / iptables quick checks
sudo ufw status verbose 2>/dev/null || true
sudo nft list ruleset 2>/dev/null | head -120 || true
sudo iptables -S 2>/dev/null | head -120 || true

# Capture packets for a suspect flow
sudo tcpdump -nn -i any host <CLIENT_IP> and port <PORT>
```

### External port probing

```bash
nmap -Pn -p <PORT> <HOST_OR_IP>
```

## Disk Full Recovery Playbook

### Identify what grew

```bash
df -h
df -ih
sudo du -xh /var --max-depth=2 | sort -h | tail -40
sudo du -xh / --max-depth=1 2>/dev/null | sort -h
```

### Safe cleanup order

```bash
# 1) Rotate + vacuum journald first
sudo journalctl --vacuum-time=7d

# 2) Package cache cleanup
sudo apt-get clean 2>/dev/null || sudo dnf clean all 2>/dev/null || true

# 3) Remove old rotated logs only
sudo find /var/log -type f -name '*.gz' -mtime +7 -delete
```

### Last resort (targeted truncation)

```bash
# Only truncate known non-critical logs after backup
sudo cp /var/log/<big.log> /var/log/<big.log>.bak.$(date +%s)
sudo truncate -s 0 /var/log/<big.log>
```

## App Slowdown Checklist

```bash
# 5xx spikes
grep -E ' 50[0-9] ' /var/log/nginx/access.log | tail -100

# Long upstream requests (nginx)
awk '$9 ~ /^5/ {print $0}' /var/log/nginx/access.log | tail -100

# DB saturation indicators
ss -tanp | grep -E ':5432|:3306' | head -80
```

## Incident Artifact Collection

```bash
OUT="/tmp/incident-$(hostname)-$(date +%Y%m%d_%H%M%S)"
mkdir -p "$OUT"
date > "$OUT/timestamp.txt"
uptime > "$OUT/uptime.txt"
free -h > "$OUT/memory.txt"
df -h > "$OUT/disk.txt"
ss -tulpen > "$OUT/listeners.txt"
ps aux --sort=-%cpu > "$OUT/ps_cpu.txt"
ps aux --sort=-%mem > "$OUT/ps_mem.txt"
journalctl -p err -n 500 --no-pager > "$OUT/journal_errors.txt"
tar czf "$OUT.tar.gz" -C /tmp "$(basename "$OUT")"
echo "Artifact: $OUT.tar.gz"
```

## Troubleshooting

- High load with low CPU usage often means IO wait; verify with `iostat -xz`.
- Healthy local curl but failing public endpoint usually indicates load balancer, DNS, or firewall path issue.
- Repeated OOM kills in `dmesg` means memory limit tuning is required before app-level fixes will hold.
- If `ss` shows no listener, restart app and immediately tail logs to catch startup failure cause.
