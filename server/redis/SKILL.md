# Redis — In-Memory Data Store

> Install, configure, and manage Redis for caching, sessions, pub/sub, queues, and real-time data. Covers persistence, Sentinel HA, clustering, and security.

## Safety Rules

- **`FLUSHALL` wipes everything** — never run in production without confirmation.
- Set `maxmemory` and an eviction policy — Redis will consume all RAM otherwise.
- Always set `requirepass` or configure ACLs — Redis has no auth by default.
- Never bind to `0.0.0.0` without firewall rules or `requirepass`.
- Use `CONFIG REWRITE` after runtime `CONFIG SET` to persist changes.
- Disable dangerous commands in production: `rename-command FLUSHALL ""`

## Quick Reference

```bash
# Install (Debian/Ubuntu)
sudo apt update && sudo apt install -y redis-server

# Install (from official repo — latest)
curl -fsSL https://packages.redis.io/gpg | sudo gpg --dearmor -o /usr/share/keyrings/redis-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/redis-archive-keyring.gpg] https://packages.redis.io/deb $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/redis.list
sudo apt update && sudo apt install -y redis

# Service management
sudo systemctl enable --now redis-server
sudo systemctl status redis-server
sudo systemctl restart redis-server

# Connect
redis-cli
redis-cli -h 10.0.0.1 -p 6379 -a 'password'

# Ping test
redis-cli ping                        # → PONG

# Server info
redis-cli INFO server
redis-cli INFO memory
redis-cli INFO replication
redis-cli INFO stats

# Quick operations
redis-cli SET mykey "hello"
redis-cli GET mykey
redis-cli DEL mykey
redis-cli KEYS "*"                    # WARNING: blocks on large datasets, use SCAN
redis-cli DBSIZE                      # Key count
redis-cli SCAN 0 MATCH "prefix:*" COUNT 100

# Config file
# Debian/Ubuntu: /etc/redis/redis.conf
# RHEL/Rocky: /etc/redis.conf
```

## Configuration

### Essential `/etc/redis/redis.conf` settings

```conf
# Network
bind 127.0.0.1 -::1                   # Localhost only (add IPs if needed)
port 6379
protected-mode yes
tcp-backlog 511
timeout 300                            # Close idle clients after 5min (0=disabled)
tcp-keepalive 300

# Authentication
requirepass your_strong_password_here

# Memory
maxmemory 2gb
maxmemory-policy allkeys-lru           # See eviction policies below

# Persistence (see section below)
save 3600 1 300 100 60 10000           # RDB snapshots
appendonly yes                         # AOF enabled
appendfsync everysec

# Logging
loglevel notice
logfile /var/log/redis/redis-server.log

# Disable dangerous commands in production
rename-command FLUSHDB ""
rename-command FLUSHALL ""
rename-command DEBUG ""
rename-command CONFIG "REDIS_CONFIG_a8f2e1"
```

```bash
# Reload config at runtime (some settings)
redis-cli CONFIG SET maxmemory "4gb"
redis-cli CONFIG REWRITE              # Persist runtime changes to redis.conf
```

## Persistence — RDB vs AOF

### RDB (point-in-time snapshots)

```conf
# In redis.conf — snapshot rules: save <seconds> <min-changes>
save 3600 1                            # After 1 hour if ≥1 key changed
save 300 100                           # After 5 min if ≥100 keys changed
save 60 10000                          # After 1 min if ≥10000 keys changed

dbfilename dump.rdb
dir /var/lib/redis
rdbcompression yes
rdbchecksum yes
```

```bash
# Manual snapshot
redis-cli BGSAVE
redis-cli LASTSAVE                     # Timestamp of last successful save
```

### AOF (append-only file — more durable)

```conf
appendonly yes
appendfilename "appendonly.aof"
appendfsync everysec                   # everysec (recommended), always (slow), no (OS decides)
auto-aof-rewrite-percentage 100
auto-aof-rewrite-min-size 64mb
```

```bash
# Trigger AOF rewrite (compaction)
redis-cli BGREWRITEAOF

# Fix corrupted AOF
redis-check-aof --fix /var/lib/redis/appendonly.aof
```

### Recommended: Use both RDB + AOF

RDB for fast restarts + periodic backups. AOF for durability. Redis uses AOF on startup if both exist.

## Sentinel (High Availability)

Sentinel monitors Redis instances and handles automatic failover.

### Sentinel config (`/etc/redis/sentinel.conf`)

```conf
port 26379
daemonize yes
logfile /var/log/redis/sentinel.log
dir /var/lib/redis

# Monitor primary — name, host, port, quorum (votes needed for failover)
sentinel monitor mymaster 10.0.0.1 6379 2

# Auth for the monitored instance
sentinel auth-pass mymaster your_strong_password_here

# Timing
sentinel down-after-milliseconds mymaster 5000
sentinel failover-timeout mymaster 60000
sentinel parallel-syncs mymaster 1
```

```bash
# Start sentinel (run on 3+ separate machines)
redis-sentinel /etc/redis/sentinel.conf
# Or:
redis-server /etc/redis/sentinel.conf --sentinel

# Check sentinel status
redis-cli -p 26379 SENTINEL masters
redis-cli -p 26379 SENTINEL replicas mymaster
redis-cli -p 26379 SENTINEL get-master-addr-by-name mymaster
```

## Clustering

### Create a 6-node cluster (3 masters + 3 replicas)

```bash
# Assuming Redis is running on ports 7000-7005 across nodes
redis-cli --cluster create \
    10.0.0.1:7000 10.0.0.2:7001 10.0.0.3:7002 \
    10.0.0.4:7003 10.0.0.5:7004 10.0.0.6:7005 \
    --cluster-replicas 1

# Required redis.conf per node
# cluster-enabled yes
# cluster-config-file nodes.conf
# cluster-node-timeout 5000
```

```bash
# Cluster status
redis-cli -c -h 10.0.0.1 -p 7000 CLUSTER INFO
redis-cli -c -h 10.0.0.1 -p 7000 CLUSTER NODES

# Add a node
redis-cli --cluster add-node 10.0.0.7:7006 10.0.0.1:7000

# Reshard (move hash slots)
redis-cli --cluster reshard 10.0.0.1:7000

# Remove a node
redis-cli --cluster del-node 10.0.0.1:7000 <node-id>

# Fix cluster issues
redis-cli --cluster fix 10.0.0.1:7000
```

## Eviction Policies

Set via `maxmemory-policy`:

| Policy | Description |
|--------|-------------|
| `noeviction` | Return errors when memory is full (default) |
| `allkeys-lru` | Evict least recently used keys — **most common for caching** |
| `allkeys-lfu` | Evict least frequently used keys |
| `allkeys-random` | Evict random keys |
| `volatile-lru` | LRU among keys with TTL set |
| `volatile-lfu` | LFU among keys with TTL set |
| `volatile-ttl` | Evict keys with shortest TTL first |
| `volatile-random` | Random among keys with TTL set |

```bash
redis-cli CONFIG SET maxmemory-policy allkeys-lru
redis-cli CONFIG REWRITE
```

## ACL (Access Control Lists) — Redis 6+

```bash
# List users
redis-cli ACL LIST

# Create a user with limited access
redis-cli ACL SETUSER appuser on >app_password ~app:* &* +@read +@write -@dangerous

# Read-only user
redis-cli ACL SETUSER reader on >reader_pass ~* &* +@read

# Disable default user (after creating admin)
redis-cli ACL SETUSER default off

# Save ACL to file
redis-cli ACL SAVE

# Load ACL from file
redis-cli ACL LOAD
```

ACL file (`/etc/redis/users.acl`):
```
user admin on >admin_pass ~* &* +@all
user appuser on >app_pass ~app:* &* +@read +@write +@connection
user default off
```

## Pub/Sub

```bash
# Subscribe to a channel (blocks and listens)
redis-cli SUBSCRIBE news alerts

# Subscribe with pattern
redis-cli PSUBSCRIBE "user:*"

# Publish a message
redis-cli PUBLISH news "Breaking: Redis is fast"

# Check active channels
redis-cli PUBSUB CHANNELS
redis-cli PUBSUB NUMSUB news alerts
```

## Monitoring & Diagnostics

```bash
# Real-time command monitor (shows all commands — USE IN DEV ONLY)
redis-cli MONITOR

# Server stats
redis-cli INFO all

# Memory usage
redis-cli INFO memory
redis-cli MEMORY USAGE mykey          # Bytes used by a specific key
redis-cli MEMORY DOCTOR               # Memory health check

# Key stats
redis-cli DBSIZE                      # Total keys
redis-cli INFO keyspace

# Latency check
redis-cli --latency                   # Continuous latency test
redis-cli --latency-history           # Latency over time

# Big keys (find memory hogs — scans entire keyspace)
redis-cli --bigkeys

# Slow log
redis-cli SLOWLOG GET 10              # Last 10 slow commands
redis-cli CONFIG SET slowlog-log-slower-than 10000  # μs (10ms)
redis-cli CONFIG SET slowlog-max-len 128

# Connected clients
redis-cli CLIENT LIST
redis-cli CLIENT INFO
redis-cli INFO clients

# Kill a specific client
redis-cli CLIENT KILL ID <client-id>
```

## Common Patterns

### Session store

```bash
# Set session with TTL (30 minutes)
redis-cli SET "session:abc123" '{"user_id": 42, "role": "admin"}' EX 1800

# Check TTL
redis-cli TTL "session:abc123"
```

### Rate limiting (sliding window)

```bash
# Using sorted set — add timestamp, count within window
redis-cli ZADD "ratelimit:user:42" $(date +%s) "$(date +%s%N)"
redis-cli ZRANGEBYSCORE "ratelimit:user:42" $(($(date +%s) - 60)) +inf
redis-cli ZREMRANGEBYSCORE "ratelimit:user:42" -inf $(($(date +%s) - 60))
```

### Queue (simple FIFO)

```bash
redis-cli LPUSH myqueue "job1" "job2" "job3"
redis-cli RPOP myqueue                # → "job1"
redis-cli BRPOP myqueue 30           # Blocking pop (30s timeout)
redis-cli LLEN myqueue
```

## Troubleshooting

```bash
# Check if Redis is running
sudo systemctl status redis-server
redis-cli ping

# Check logs
sudo tail -50 /var/log/redis/redis-server.log

# Can't connect — check bind address
grep "^bind" /etc/redis/redis.conf

# Memory issues
redis-cli INFO memory | grep used_memory_human
redis-cli INFO memory | grep maxmemory
redis-cli MEMORY DOCTOR

# High latency — check if persistence is blocking
redis-cli INFO persistence | grep -E "rdb_|aof_"
# Large AOF rewrites or RDB saves can cause latency spikes

# Too many connections
redis-cli INFO clients | grep connected_clients
redis-cli CONFIG GET maxclients

# Keyspace notifications (for debugging)
redis-cli CONFIG SET notify-keyspace-events KEA
redis-cli SUBSCRIBE __keyevent@0__:expired   # Watch expired keys

# Check if a key exists and its type
redis-cli EXISTS mykey
redis-cli TYPE mykey
redis-cli OBJECT ENCODING mykey

# Redis running but not accepting commands — OOM
# Check: dmesg | grep -i oom
# Fix: increase maxmemory or set an eviction policy

# Disable transparent hugepages (causes latency)
echo never | sudo tee /sys/kernel/mm/transparent_hugepage/enabled
# Add to /etc/rc.local or systemd for persistence

# Overcommit memory warning
echo "vm.overcommit_memory = 1" | sudo tee -a /etc/sysctl.conf
sudo sysctl vm.overcommit_memory=1
```
