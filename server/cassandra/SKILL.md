# Cassandra — Distributed NoSQL Database

> Install, configure, and manage Apache Cassandra for high-availability, wide-column data storage. Covers CQL, keyspaces, nodetool, replication, repair, compaction, and backup.

## Safety Rules

- **`DROP KEYSPACE` is irreversible** — always snapshot before dropping.
- Never run `nodetool removenode` on a node that's still alive — use `decommission` instead.
- Avoid `ALLOW FILTERING` in production queries — it causes full cluster scans.
- Don't run `nodetool repair` on all nodes simultaneously — stagger repairs.
- Test schema changes in dev first — Cassandra can't roll back schema migrations.
- Always use `LOCAL_QUORUM` or `QUORUM` consistency for production reads/writes.

## Quick Reference

```bash
# Install (Ubuntu/Debian — Cassandra 4.x or 5.x)
echo "deb [signed-by=/etc/apt/keyrings/apache-cassandra.asc] https://debian.cassandra.apache.org 50x main" | \
  sudo tee /etc/apt/sources.list.d/cassandra.sources.list
curl -o /etc/apt/keyrings/apache-cassandra.asc https://downloads.apache.org/cassandra/KEYS
sudo apt update && sudo apt install -y cassandra

# Install via tarball
wget https://dlcdn.apache.org/cassandra/5.0.3/apache-cassandra-5.0.3-bin.tar.gz
tar xzf apache-cassandra-5.0.3-bin.tar.gz
cd apache-cassandra-5.0.3 && bin/cassandra -f   # Foreground

# Service management
sudo systemctl enable --now cassandra
sudo systemctl status cassandra
sudo systemctl restart cassandra

# Connect via CQL shell
cqlsh
cqlsh 10.0.0.1 9042
cqlsh -u cassandra -p cassandra

# Quick check
nodetool status
nodetool info
nodetool version
```

## Configuration

### Essential `/etc/cassandra/cassandra.yaml`

```yaml
cluster_name: 'MyCluster'
num_tokens: 256
data_file_directories:
  - /var/lib/cassandra/data
commitlog_directory: /var/lib/cassandra/commitlog
saved_caches_directory: /var/lib/cassandra/saved_caches

# Network
listen_address: 10.0.0.1              # This node's IP (NOT 0.0.0.0)
rpc_address: 0.0.0.0                  # Client connections
native_transport_port: 9042
storage_port: 7000

# Seed nodes (for bootstrapping — 2-3 nodes per DC)
seed_provider:
  - class_name: org.apache.cassandra.locator.SimpleSeedProvider
    parameters:
      - seeds: "10.0.0.1,10.0.0.2"

# Snitch (datacenter/rack awareness)
endpoint_snitch: GossipingPropertyFileSnitch

# Compaction/performance
concurrent_reads: 32
concurrent_writes: 32
memtable_allocation_type: heap_buffers
commitlog_sync: periodic
commitlog_sync_period: 10000

# Authentication (enable for production)
authenticator: PasswordAuthenticator
authorizer: CassandraAuthorizer
```

### JVM Settings — `/etc/cassandra/jvm-server.options`

```
-Xms4G
-Xmx4G
-Xmn800M
```

## CQL — Keyspaces & Tables

```sql
-- Create keyspace (SimpleStrategy for single DC)
CREATE KEYSPACE myapp WITH replication = {
  'class': 'SimpleStrategy',
  'replication_factor': 3
};

-- Create keyspace (NetworkTopologyStrategy for multi-DC)
CREATE KEYSPACE myapp WITH replication = {
  'class': 'NetworkTopologyStrategy',
  'dc1': 3,
  'dc2': 2
};

-- Switch keyspace
USE myapp;

-- List keyspaces
DESCRIBE KEYSPACES;
DESCRIBE KEYSPACE myapp;

-- Create table
CREATE TABLE users (
  user_id UUID PRIMARY KEY,
  username TEXT,
  email TEXT,
  created_at TIMESTAMP
);

-- Compound partition key + clustering
CREATE TABLE events (
  tenant_id UUID,
  event_date DATE,
  event_time TIMESTAMP,
  event_type TEXT,
  payload TEXT,
  PRIMARY KEY ((tenant_id, event_date), event_time)
) WITH CLUSTERING ORDER BY (event_time DESC);

-- List tables
DESCRIBE TABLES;
DESCRIBE TABLE users;

-- Alter table
ALTER TABLE users ADD phone TEXT;
ALTER TABLE users DROP phone;

-- Drop table
DROP TABLE users;
DROP KEYSPACE myapp;                   -- ⚠ DESTRUCTIVE
```

## CQL — Data Operations

```sql
-- Insert
INSERT INTO users (user_id, username, email, created_at)
VALUES (uuid(), 'ivan', 'ivan@example.com', toTimestamp(now()));

-- Insert with TTL (auto-expire after 86400 seconds)
INSERT INTO users (user_id, username, email, created_at)
VALUES (uuid(), 'temp_user', 'temp@example.com', toTimestamp(now()))
USING TTL 86400;

-- Select
SELECT * FROM users;
SELECT * FROM users WHERE user_id = 550e8400-e29b-41d4-a716-446655440000;
SELECT * FROM events WHERE tenant_id = ? AND event_date = '2026-03-20'
  ORDER BY event_time DESC LIMIT 50;

-- Update
UPDATE users SET email = 'new@example.com'
WHERE user_id = 550e8400-e29b-41d4-a716-446655440000;

-- Delete
DELETE FROM users WHERE user_id = 550e8400-e29b-41d4-a716-446655440000;

-- Batch (use sparingly — not for bulk loads)
BEGIN BATCH
  INSERT INTO users (user_id, username) VALUES (uuid(), 'alice');
  INSERT INTO users (user_id, username) VALUES (uuid(), 'bob');
APPLY BATCH;

-- Consistency level (per query)
CONSISTENCY QUORUM;
SELECT * FROM users;
CONSISTENCY LOCAL_ONE;

-- Paging
PAGING ON;
PAGING 100;
```

## Nodetool — Cluster Operations

```bash
# Cluster status
nodetool status                        # Node states (UN=Up Normal, DN=Down)
nodetool info                          # This node's info
nodetool describecluster               # Cluster topology
nodetool ring                          # Token ring

# Performance
nodetool tpstats                       # Thread pool stats
nodetool compactionstats               # Running compactions
nodetool tablestats myapp.users        # Per-table stats
nodetool proxyhistograms               # Request latency histograms
nodetool tablehistograms myapp users   # Table-level latency

# Gossip
nodetool gossipinfo                    # Gossip state
nodetool statusgossip                  # Is gossip enabled?

# Repair (run regularly — at least once within gc_grace_seconds)
nodetool repair myapp                  # Full repair of keyspace
nodetool repair myapp users            # Single table
nodetool repair -pr myapp              # Primary range only (faster, run on each node)

# Compaction
nodetool compact myapp users           # Force major compaction
nodetool compactionstats               # Check progress
nodetool setcompactionthroughput 64    # MB/s limit

# Cleanup (after adding nodes — removes data no longer owned)
nodetool cleanup myapp

# Flush memtables to SSTables
nodetool flush myapp
nodetool drain                         # Flush all + stop accepting writes (pre-shutdown)
```

## Backup & Restore

```bash
# Snapshot (instant, hard-links SSTables)
nodetool snapshot myapp -t snap_$(date +%Y%m%d)
# Snapshots stored in: /var/lib/cassandra/data/myapp/<table>/snapshots/

# List snapshots
nodetool listsnapshots

# Clear snapshots
nodetool clearsnapshot -t snap_20260320 myapp
nodetool clearsnapshot --all           # Remove all snapshots

# Backup: copy snapshot files off the node
tar czf /backup/cassandra_myapp_$(date +%Y%m%d).tar.gz \
  /var/lib/cassandra/data/myapp/*/snapshots/snap_$(date +%Y%m%d)/

# Restore from snapshot
sudo systemctl stop cassandra
# Clear commitlog and data
sudo rm -rf /var/lib/cassandra/commitlog/*
# Copy snapshot SSTables back to table directories
sudo cp /backup/snapshots/snap_20260320/*.db /var/lib/cassandra/data/myapp/users-<id>/
sudo chown -R cassandra:cassandra /var/lib/cassandra
sudo systemctl start cassandra
nodetool refresh myapp users           # Load new SSTables without restart

# Incremental backup (enable in cassandra.yaml: incremental_backups: true)
# Flushed SSTables hard-linked to: data/<ks>/<table>/backups/
```

## Users & Security

```sql
-- Default superuser: cassandra/cassandra — CHANGE IT
ALTER USER cassandra WITH PASSWORD 'new_strong_password';

-- Create users
CREATE ROLE admin WITH PASSWORD = 'admin_pass' AND SUPERUSER = true AND LOGIN = true;
CREATE ROLE appuser WITH PASSWORD = 'app_pass' AND LOGIN = true;
CREATE ROLE readonly WITH LOGIN = true AND PASSWORD = 'read_pass';

-- Grant permissions
GRANT ALL ON KEYSPACE myapp TO appuser;
GRANT SELECT ON KEYSPACE myapp TO readonly;
GRANT MODIFY ON TABLE myapp.users TO appuser;

-- List permissions
LIST ALL PERMISSIONS OF appuser;
LIST ALL PERMISSIONS ON myapp.users;

-- Revoke
REVOKE MODIFY ON TABLE myapp.users FROM appuser;

-- Drop role
DROP ROLE readonly;
```

## Monitoring

```bash
# JMX (default port 7199)
nodetool tpstats                       # Thread pools — watch for pending/blocked
nodetool cfstats                       # All table stats (verbose)
nodetool gcstats                       # GC pressure

# Logs
sudo tail -100 /var/log/cassandra/system.log
sudo grep -i "error\|warn\|exception" /var/log/cassandra/system.log | tail -20

# Dropped messages (critical — data loss indicator)
nodetool tpstats | grep -i dropped

# Heap usage
nodetool info | grep -i heap
```

## Troubleshooting

```bash
# Node won't start
sudo journalctl -u cassandra --no-pager -n 50
cat /var/log/cassandra/system.log | tail -100

# Node stuck joining
nodetool status                        # Check if another node is also bootstrapping
# Only one node can bootstrap at a time

# Zombie node (shows as DN but already removed)
nodetool removenode <host-id>          # Only for truly dead nodes!

# Tombstone warnings
nodetool tablestats myapp.users | grep -i tombstone
# High tombstone counts → adjust gc_grace_seconds or fix delete patterns

# Read timeouts
# Increase read_request_timeout in cassandra.yaml
# Check nodetool proxyhistograms for latency percentiles

# Disk space
nodetool status                        # Check Load column
df -h /var/lib/cassandra
nodetool compact myapp                 # Reclaim space (temporarily needs 2x)

# SSTable count too high
nodetool tablestats myapp.users | grep "SSTable count"
nodetool compact myapp users           # Force compaction
```
