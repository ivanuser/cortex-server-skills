# Performance Tuning & Stress Testing

> Tune kernel and web stack settings, then prove improvement with repeatable load tests.

## Safety Rules

- Benchmark before and after each tuning change; no blind edits.
- Apply one change set at a time to isolate impact.
- Keep rollback copies of config files.
- Stress test in staging first when possible.
- Stop tests immediately if error rate spikes or dependency saturation occurs.

## Quick Reference

```bash
# Baseline
nproc
uptime
ss -s

# Sysctl preview
sysctl net.core.somaxconn
sysctl net.ipv4.tcp_tw_reuse

# Nginx workers from core count
grep -E 'worker_processes|worker_connections' /etc/nginx/nginx.conf

# Simple load test
ab -n 1000 -c 50 http://127.0.0.1/
```

## Kernel Tuning (`/etc/sysctl.d/99-performance.conf`)

```text
net.core.somaxconn = 65535
net.ipv4.tcp_max_syn_backlog = 8192
net.ipv4.ip_local_port_range = 1024 65535
net.ipv4.tcp_fin_timeout = 15
net.ipv4.tcp_tw_reuse = 1
fs.file-max = 2097152
```

Apply and verify:

```bash
sudo sysctl --system
sysctl net.core.somaxconn net.ipv4.tcp_tw_reuse fs.file-max
```

## Nginx Tuning

Recommended baseline:

```text
worker_processes auto;
events {
  worker_connections 4096;
  multi_accept on;
}
```

Capacity estimate:
- max connections ~= `worker_processes * worker_connections`

Validate/reload:

```bash
sudo nginx -t
sudo systemctl reload nginx
```

## File Descriptor Limits

```bash
ulimit -n
sudo grep -E 'nofile' /etc/security/limits.conf /etc/security/limits.d/* 2>/dev/null
```

## Load Testing

### Apache Bench

```bash
ab -n 5000 -c 100 http://127.0.0.1/
ab -n 5000 -c 100 -k https://app.example.com/
```

### Siege

```bash
siege -c50 -t60S http://127.0.0.1/
```

Capture:
- requests/sec
- p95 response time
- error rate
- CPU/memory usage during test

## Compare Before vs After

```bash
# Save outputs for comparison
ab -n 5000 -c 100 http://127.0.0.1/ > /tmp/ab_before.txt
# ... tuning changes ...
ab -n 5000 -c 100 http://127.0.0.1/ > /tmp/ab_after.txt
```

## Troubleshooting

- Higher throughput but rising 5xx: backend dependency is saturating; tune DB/pool next.
- Connection resets under load: check file descriptor limits and upstream keepalive config.
- No improvement after sysctl changes: verify values actually loaded (`sysctl <key>`).
- Latency spikes at high concurrency: inspect GC pauses, DB slow queries, and queue depth.
