# Memcached — Distributed Memory Cache

> Install, configure, and manage Memcached for high-performance in-memory key-value caching. Covers configuration, stats, slab management, client usage, and monitoring.

## Safety Rules

- **Memcached has no authentication by default** — never expose to the internet without firewall rules.
- Data is ephemeral — Memcached is a cache, not a data store. Expect evictions.
- Never store data you can't regenerate — Memcached will evict items when memory is full.
- Bind to localhost or private IPs only unless using SASL authentication.
- Memcached amplification attacks are real — restrict UDP access (`-U 0` to disable UDP).

## Quick Reference

```bash
# Install (Debian/Ubuntu)
sudo apt update && sudo apt install -y memcached libmemcached-tools

# Install (RHEL/Rocky)
sudo dnf install -y memcached libmemcached

# Service management
sudo systemctl enable --now memcached
sudo systemctl status memcached
sudo systemctl restart memcached

# Quick test
echo "stats" | nc localhost 11211
echo "version" | nc localhost 11211

# Set and get via telnet
# telnet localhost 11211
# set mykey 0 3600 5
# hello
# get mykey
# quit

# memcstat (from libmemcached-tools)
memcstat --servers=localhost
memcflush --servers=localhost           # ⚠ Flush ALL data
```

## Configuration

### Config file: `/etc/memcached.conf` (Debian/Ubuntu) or `/etc/sysconfig/memcached` (RHEL)

#### Debian/Ubuntu — `/etc/memcached.conf`

```conf
# Run as daemon
-d

# Log file
-l 127.0.0.1                          # Listen address (localhost only)
-p 11211                               # TCP port
-U 0                                   # Disable UDP (prevents amplification attacks)
-u memcache                            # Run as user
-m 256                                 # Max memory in MB
-c 1024                                # Max simultaneous connections
-t 4                                   # Number of threads
-I 1m                                  # Max item size (default 1MB, max 128MB)
-P /run/memcached/memcached.pid

# Logging
-v                                     # Verbose (errors + warnings)
# -vv                                  # Very verbose (+ client commands)
# -vvv                                 # Extremely verbose (+ internal state)

# Listen on multiple interfaces
# -l 127.0.0.1,10.0.0.1
# -l 0.0.0.0                          # All interfaces (⚠ requires firewall)
```

#### RHEL/Rocky — `/etc/sysconfig/memcached`

```conf
PORT="11211"
USER="memcached"
MAXCONN="1024"
CACHESIZE="256"
OPTIONS="-l 127.0.0.1 -U 0 -t 4"
```

### SASL Authentication

```bash
# Install SASL support
sudo apt install -y sasl2-bin

# Enable SASL in memcached.conf
# -S                                   # Enable SASL

# Create SASL user
sudo mkdir -p /etc/sasl2
cat <<'EOF' | sudo tee /etc/sasl2/memcached.conf
mech_list: plain
log_level: 5
sasldb_path: /etc/sasl2/memcached-sasldb2
EOF

sudo saslpasswd2 -a memcached -c -f /etc/sasl2/memcached-sasldb2 myuser
sudo chown memcache:memcache /etc/sasl2/memcached-sasldb2

# Restart memcached with -S flag
```

## Stats & Monitoring

### General Stats

```bash
# Via netcat
echo "stats" | nc localhost 11211

# Key stats to monitor:
# curr_connections — active connections
# cmd_get / cmd_set — total get/set commands
# get_hits / get_misses — cache hit/miss
# bytes — current bytes used
# limit_maxbytes — max memory configured
# curr_items — items currently stored
# evictions — items evicted (memory full)
# bytes_read / bytes_written — network I/O

# Calculate hit rate
# hit_rate = get_hits / (get_hits + get_misses) * 100
# Target: >90%

# memcstat for formatted output
memcstat --servers=localhost

# Specific stat groups
echo "stats items" | nc localhost 11211        # Per-slab item stats
echo "stats slabs" | nc localhost 11211        # Slab allocator stats
echo "stats sizes" | nc localhost 11211        # Item size distribution
echo "stats settings" | nc localhost 11211     # Current configuration
echo "stats conns" | nc localhost 11211        # Connection stats
```

### Slab Management

```
Memcached divides memory into slab classes. Each class stores items
of a specific size range. Understanding slabs helps optimize memory usage.

Slab classes grow by factor (default 1.25):
Class 1: 96 bytes
Class 2: 120 bytes
Class 3: 150 bytes
...and so on
```

```bash
# View slab allocation
echo "stats slabs" | nc localhost 11211

# Key slab metrics:
# chunk_size — size of each chunk in this class
# chunks_per_page — chunks per slab page
# total_pages — pages allocated to this class
# used_chunks — chunks containing items
# free_chunks — available chunks
# mem_requested — actual bytes requested by items

# Tune slab factor (default 1.25)
# -f 1.25                             # Growth factor
# Lower factor = more slab classes, less wasted memory per item
# Higher factor = fewer classes, more internal fragmentation

# Slab reassignment (move memory between slab classes)
# Enable: -o slab_reassign,slab_automove
# Or manually:
echo "slabs reassign 6 12" | nc localhost 11211  # Move page from class 6 to 12
```

## Key Operations (Protocol)

```bash
# Using nc/telnet (text protocol)
# SET: store a value
# set <key> <flags> <exptime> <bytes>
# <data>
echo -e "set mykey 0 3600 5\r\nhello\r" | nc localhost 11211

# GET: retrieve value
echo "get mykey" | nc localhost 11211

# Multiple get
echo "get key1 key2 key3" | nc localhost 11211

# ADD: store only if key doesn't exist
echo -e "add newkey 0 3600 5\r\nworld\r" | nc localhost 11211

# REPLACE: store only if key exists
echo -e "replace mykey 0 3600 7\r\nbye bye\r" | nc localhost 11211

# APPEND/PREPEND
echo -e "append mykey 0 0 6\r\n world\r" | nc localhost 11211

# DELETE
echo "delete mykey" | nc localhost 11211

# INCREMENT/DECREMENT (numeric values)
echo -e "set counter 0 0 1\r\n0\r" | nc localhost 11211
echo "incr counter 1" | nc localhost 11211     # → 1
echo "incr counter 10" | nc localhost 11211    # → 11
echo "decr counter 5" | nc localhost 11211     # → 6

# TOUCH: update expiration without fetching
echo "touch mykey 7200" | nc localhost 11211

# FLUSH ALL (⚠ clears everything)
echo "flush_all" | nc localhost 11211

# Delayed flush (flush in 30 seconds)
echo "flush_all 30" | nc localhost 11211
```

## Client Libraries

### Python (pymemcache)

```python
from pymemcache.client.base import Client

client = Client('localhost:11211')

# Basic operations
client.set('key', 'value', expire=3600)
result = client.get('key')             # → b'value'

# Multiple operations
client.set_many({'k1': 'v1', 'k2': 'v2'}, expire=3600)
results = client.get_many(['k1', 'k2'])

# Delete
client.delete('key')

# Increment/decrement
client.set('counter', '0')
client.incr('counter', 1)
client.decr('counter', 1)

# CAS (Check-And-Set) for atomic updates
result, cas_token = client.gets('key')
client.cas('key', 'new_value', cas_token, expire=3600)
```

### Node.js (memjs)

```javascript
const memjs = require('memjs');
const client = memjs.Client.create('localhost:11211');

// Set
await client.set('key', 'value', { expires: 3600 });

// Get
const { value } = await client.get('key');
console.log(value.toString());         // → 'value'

// Delete
await client.delete('key');

// Close
client.close();
```

### CLI tools (libmemcached)

```bash
# memccat — get values
memccat --servers=localhost mykey

# memccp — copy file to memcached
memccp --servers=localhost --expire=3600 /path/to/file

# memcrm — delete key
memcrm --servers=localhost mykey

# memcflush — flush all
memcflush --servers=localhost

# memcslap — benchmark
memcslap --servers=localhost --concurrency=10 --test=set
memcslap --servers=localhost --concurrency=10 --test=get
```

## Multi-Server Setup

```bash
# Consistent hashing (client-side distribution)
# Memcached servers don't communicate — clients distribute keys

# Start multiple instances
memcached -d -m 256 -p 11211 -l 10.0.0.1
memcached -d -m 256 -p 11211 -l 10.0.0.2
memcached -d -m 256 -p 11211 -l 10.0.0.3

# Python client with multiple servers
from pymemcache.client.hash import HashClient
client = HashClient([
    ('10.0.0.1', 11211),
    ('10.0.0.2', 11211),
    ('10.0.0.3', 11211),
])
```

## Troubleshooting

```bash
# Memcached not responding
sudo systemctl status memcached
sudo ss -tlnp | grep 11211
echo "version" | nc -w 2 localhost 11211

# High eviction rate
echo "stats" | nc localhost 11211 | grep evictions
# Fix: increase memory (-m), reduce TTLs, or cache fewer things

# Low hit rate
echo "stats" | nc localhost 11211 | grep -E "get_hits|get_misses"
# Check if keys are expiring too fast or clients are using wrong keys

# Memory usage
echo "stats" | nc localhost 11211 | grep -E "bytes |limit_maxbytes"

# Connection count
echo "stats" | nc localhost 11211 | grep curr_connections
# If hitting limit, increase -c (max connections)

# Check logs
sudo journalctl -u memcached --no-pager -n 50

# Items by slab class (find wasted memory)
echo "stats items" | nc localhost 11211 | grep -E "number|evicted"

# Segfaults or crashes
# Check: dmesg | grep -i memcached
# Try disabling large pages: -L (disable) in config

# Restart with verbose logging for debugging
sudo systemctl stop memcached
memcached -vv -m 256 -p 11211 -l 127.0.0.1 -u memcache
# Watch output, then Ctrl+C and restart normally
```
