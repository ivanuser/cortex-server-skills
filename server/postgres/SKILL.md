# PostgreSQL — Relational Database

> Install, configure, and manage PostgreSQL — databases, users, backups, replication, performance tuning, and monitoring.

## Safety Rules

- **Never run `DROP DATABASE` without confirming** — there's no undo.
- Always test backups with a restore before trusting them.
- Use `BEGIN; ... ROLLBACK;` to preview destructive queries before committing.
- Back up before major version upgrades: `pg_dumpall > /tmp/pg-full-$(date +%F).sql`
- Don't set `shared_buffers` higher than 25% of system RAM.
- Never expose port 5432 to the internet without SSL + `pg_hba.conf` restrictions.

## Quick Reference

```bash
# Install (Debian/Ubuntu — latest from PGDG)
sudo apt install -y postgresql postgresql-contrib

# Install from official PGDG repo (specific version)
sudo sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list'
wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo apt-key add -
sudo apt update && sudo apt install -y postgresql-16

# Service management
sudo systemctl enable --now postgresql
sudo systemctl status postgresql
sudo systemctl restart postgresql

# Connect as superuser
sudo -u postgres psql

# Connect to specific database
psql -h localhost -U myuser -d mydb

# Quick database operations
sudo -u postgres createdb mydb
sudo -u postgres dropdb mydb
sudo -u postgres createuser --interactive myuser

# Check version
psql --version
sudo -u postgres psql -c "SELECT version();"

# List databases / users / tables
sudo -u postgres psql -c "\l"        # Databases
sudo -u postgres psql -c "\du"       # Users/roles
sudo -u postgres psql -d mydb -c "\dt"  # Tables in mydb

# Config file locations
sudo -u postgres psql -c "SHOW config_file;"
sudo -u postgres psql -c "SHOW hba_file;"
sudo -u postgres psql -c "SHOW data_directory;"

# Reload config without restart
sudo -u postgres psql -c "SELECT pg_reload_conf();"
```

## User & Role Management

```sql
-- Create a user with password
CREATE USER appuser WITH PASSWORD 'strong_password_here';

-- Create a database owned by that user
CREATE DATABASE appdb OWNER appuser;

-- Grant privileges
GRANT ALL PRIVILEGES ON DATABASE appdb TO appuser;
GRANT ALL ON SCHEMA public TO appuser;

-- Read-only user
CREATE USER readonly WITH PASSWORD 'readonly_pass';
GRANT CONNECT ON DATABASE appdb TO readonly;
\c appdb
GRANT USAGE ON SCHEMA public TO readonly;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO readonly;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO readonly;

-- Change password
ALTER USER appuser WITH PASSWORD 'new_password';

-- Remove user (must revoke grants + reassign objects first)
REASSIGN OWNED BY olduser TO postgres;
DROP OWNED BY olduser;
DROP USER olduser;
```

### pg_hba.conf (authentication)

```
# /etc/postgresql/16/main/pg_hba.conf
# TYPE  DATABASE        USER            ADDRESS                 METHOD
local   all             postgres                                peer
local   all             all                                     peer
host    all             all             127.0.0.1/32            scram-sha-256
host    all             all             ::1/128                 scram-sha-256
host    appdb           appuser         10.0.0.0/24             scram-sha-256
```

```bash
# Reload after editing pg_hba.conf
sudo systemctl reload postgresql
```

## Backup & Restore

### pg_dump / pg_restore

```bash
# Dump single database (custom format — compressed, most flexible)
pg_dump -h localhost -U postgres -Fc mydb > mydb_$(date +%F).dump

# Dump as plain SQL
pg_dump -h localhost -U postgres mydb > mydb_$(date +%F).sql

# Dump all databases
pg_dumpall -h localhost -U postgres > all_dbs_$(date +%F).sql

# Dump schema only (no data)
pg_dump -h localhost -U postgres --schema-only mydb > mydb_schema.sql

# Dump specific table
pg_dump -h localhost -U postgres -t tablename mydb > table_backup.sql

# Restore from custom format
pg_restore -h localhost -U postgres -d mydb --clean --if-exists mydb.dump

# Restore from SQL
psql -h localhost -U postgres -d mydb < mydb.sql

# Restore to a new database
createdb -h localhost -U postgres newdb
pg_restore -h localhost -U postgres -d newdb mydb.dump
```

### Automated daily backup script

```bash
#!/bin/bash
# /usr/local/bin/pg-backup.sh
BACKUP_DIR="/var/backups/postgresql"
DAYS_TO_KEEP=7
mkdir -p "$BACKUP_DIR"

for db in $(psql -h localhost -U postgres -At -c "SELECT datname FROM pg_database WHERE NOT datistemplate AND datname != 'postgres'"); do
    pg_dump -h localhost -U postgres -Fc "$db" > "$BACKUP_DIR/${db}_$(date +%F_%H%M).dump"
done

find "$BACKUP_DIR" -name "*.dump" -mtime +$DAYS_TO_KEEP -delete
```

```bash
# Cron: daily at 2 AM
echo "0 2 * * * postgres /usr/local/bin/pg-backup.sh" | sudo tee /etc/cron.d/pg-backup
```

## Replication

### Streaming replication (primary → standby)

**On primary:**

```bash
# Create replication user
sudo -u postgres psql -c "CREATE USER replicator WITH REPLICATION ENCRYPTED PASSWORD 'repl_pass';"
```

Edit `pg_hba.conf` on primary:
```
host    replication     replicator      10.0.0.2/32        scram-sha-256
```

Edit `postgresql.conf` on primary:
```
wal_level = replica
max_wal_senders = 5
wal_keep_size = 1GB
```

```bash
sudo systemctl restart postgresql
```

**On standby:**

```bash
# Stop postgres, wipe data dir, base backup from primary
sudo systemctl stop postgresql
sudo -u postgres rm -rf /var/lib/postgresql/16/main/*
sudo -u postgres pg_basebackup -h 10.0.0.1 -U replicator -D /var/lib/postgresql/16/main -Fp -Xs -P -R
sudo systemctl start postgresql
```

The `-R` flag creates `standby.signal` and sets `primary_conninfo` automatically.

```sql
-- Verify on standby
SELECT pg_is_in_recovery();   -- Should return true
```

### Logical replication

```sql
-- On publisher (primary)
ALTER SYSTEM SET wal_level = logical;
-- Restart required

CREATE PUBLICATION my_pub FOR ALL TABLES;
-- Or specific tables:
CREATE PUBLICATION my_pub FOR TABLE users, orders;

-- On subscriber
CREATE SUBSCRIPTION my_sub
    CONNECTION 'host=10.0.0.1 dbname=mydb user=replicator password=repl_pass'
    PUBLICATION my_pub;

-- Check status
SELECT * FROM pg_stat_subscription;
```

## Connection Pooling — PgBouncer

```bash
sudo apt install -y pgbouncer
```

Edit `/etc/pgbouncer/pgbouncer.ini`:

```ini
[databases]
mydb = host=127.0.0.1 port=5432 dbname=mydb

[pgbouncer]
listen_addr = 0.0.0.0
listen_port = 6432
auth_type = scram-sha-256
auth_file = /etc/pgbouncer/userlist.txt
pool_mode = transaction
max_client_conn = 1000
default_pool_size = 20
min_pool_size = 5
reserve_pool_size = 5
server_idle_timeout = 300
```

```bash
# Create userlist.txt (get password hash from PostgreSQL)
sudo -u postgres psql -At -c "SELECT '\"' || usename || '\" \"' || passwd || '\"' FROM pg_shadow WHERE usename = 'appuser';" > /etc/pgbouncer/userlist.txt

sudo systemctl enable --now pgbouncer

# Connect through PgBouncer
psql -h 127.0.0.1 -p 6432 -U appuser -d mydb

# Monitor PgBouncer
psql -h 127.0.0.1 -p 6432 -U pgbouncer pgbouncer -c "SHOW POOLS;"
psql -h 127.0.0.1 -p 6432 -U pgbouncer pgbouncer -c "SHOW STATS;"
```

## Performance Tuning

### Key postgresql.conf settings

```ini
# Memory (adjust to your RAM — example for 16GB server)
shared_buffers = 4GB                  # 25% of RAM
effective_cache_size = 12GB           # 75% of RAM
work_mem = 64MB                       # Per-sort/hash operation
maintenance_work_mem = 512MB          # VACUUM, CREATE INDEX
wal_buffers = 64MB

# Write-Ahead Log
checkpoint_completion_target = 0.9
wal_compression = on
max_wal_size = 2GB
min_wal_size = 512MB

# Query planner
random_page_cost = 1.1               # SSD (4.0 for HDD)
effective_io_concurrency = 200        # SSD (2 for HDD)

# Connections
max_connections = 200                 # Use PgBouncer if you need more

# Logging
log_min_duration_statement = 1000     # Log queries >1s
log_statement = 'ddl'                 # Log DDL statements
log_line_prefix = '%t [%p]: [%l-1] user=%u,db=%d '

# Autovacuum
autovacuum_max_workers = 3
autovacuum_naptime = 30s
autovacuum_vacuum_scale_factor = 0.1
autovacuum_analyze_scale_factor = 0.05
```

```bash
# Apply changes (some need restart, some only reload)
sudo -u postgres psql -c "SELECT pg_reload_conf();"
# Or for changes requiring restart:
sudo systemctl restart postgresql
```

## VACUUM & Maintenance

```sql
-- Manual vacuum (reclaims space for reuse)
VACUUM VERBOSE mytable;

-- Full vacuum (reclaims space to OS — locks table!)
VACUUM FULL mytable;

-- Analyze (update planner statistics)
ANALYZE mytable;

-- Vacuum + analyze
VACUUM ANALYZE;

-- Reindex
REINDEX TABLE mytable;
REINDEX DATABASE mydb;

-- Check table bloat
SELECT schemaname, tablename,
    pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) as total_size,
    pg_size_pretty(pg_relation_size(schemaname||'.'||tablename)) as table_size
FROM pg_tables
WHERE schemaname = 'public'
ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC
LIMIT 20;
```

## Monitoring Queries

```sql
-- Active connections by state
SELECT state, count(*) FROM pg_stat_activity GROUP BY state;

-- Currently running queries (exclude idle)
SELECT pid, now() - pg_stat_activity.query_start AS duration, query, state
FROM pg_stat_activity
WHERE state != 'idle'
ORDER BY duration DESC;

-- Kill a query
SELECT pg_cancel_backend(pid);         -- Graceful
SELECT pg_terminate_backend(pid);      -- Force

-- Database sizes
SELECT datname, pg_size_pretty(pg_database_size(datname))
FROM pg_database ORDER BY pg_database_size(datname) DESC;

-- Table sizes (top 20)
SELECT relname, pg_size_pretty(pg_total_relation_size(relid))
FROM pg_catalog.pg_statio_user_tables
ORDER BY pg_total_relation_size(relid) DESC LIMIT 20;

-- Index usage (find unused indexes)
SELECT schemaname, tablename, indexrelname, idx_scan,
    pg_size_pretty(pg_relation_size(indexrelid)) as index_size
FROM pg_stat_user_indexes
WHERE idx_scan = 0
ORDER BY pg_relation_size(indexrelid) DESC;

-- Cache hit ratio (should be >99%)
SELECT
    sum(heap_blks_read) as heap_read,
    sum(heap_blks_hit) as heap_hit,
    round(sum(heap_blks_hit) / (sum(heap_blks_hit) + sum(heap_blks_read))::numeric, 4) as ratio
FROM pg_statio_user_tables;

-- Replication lag (on standby)
SELECT now() - pg_last_xact_replay_timestamp() AS replication_lag;

-- Lock contention
SELECT pid, mode, relation::regclass, page, tuple
FROM pg_locks WHERE NOT granted;

-- Long-running transactions
SELECT pid, now() - xact_start AS duration, query
FROM pg_stat_activity
WHERE xact_start IS NOT NULL
ORDER BY xact_start ASC LIMIT 10;
```

## Extensions

```sql
-- List available extensions
SELECT name, default_version, comment FROM pg_available_extensions ORDER BY name;

-- Common useful extensions
CREATE EXTENSION IF NOT EXISTS pg_stat_statements;   -- Query performance stats
CREATE EXTENSION IF NOT EXISTS uuid-ossp;            -- UUID generation
CREATE EXTENSION IF NOT EXISTS pgcrypto;             -- Cryptographic functions
CREATE EXTENSION IF NOT EXISTS pg_trgm;              -- Trigram text search
CREATE EXTENSION IF NOT EXISTS hstore;               -- Key-value store
CREATE EXTENSION IF NOT EXISTS citext;               -- Case-insensitive text
CREATE EXTENSION IF NOT EXISTS tablefunc;            -- Crosstab queries

-- pg_stat_statements — top slow queries
SELECT query, calls, total_exec_time / 1000 as total_sec,
    mean_exec_time / 1000 as mean_sec, rows
FROM pg_stat_statements
ORDER BY total_exec_time DESC LIMIT 20;
```

## Troubleshooting

```bash
# Check if PostgreSQL is running
sudo systemctl status postgresql
pg_isready -h localhost

# Check logs
sudo tail -50 /var/log/postgresql/postgresql-16-main.log

# Can't connect — check listen address
sudo -u postgres psql -c "SHOW listen_addresses;"
# Set to '*' or specific IP in postgresql.conf, then restart

# Authentication failed — check pg_hba.conf
sudo cat /etc/postgresql/16/main/pg_hba.conf

# Too many connections
sudo -u postgres psql -c "SELECT count(*) FROM pg_stat_activity;"
sudo -u postgres psql -c "SHOW max_connections;"

# Disk space issues
sudo -u postgres psql -c "SELECT pg_size_pretty(pg_database_size('mydb'));"
df -h /var/lib/postgresql/

# Bloated tables — check dead tuples
SELECT relname, n_dead_tup, n_live_tup,
    round(n_dead_tup::numeric / greatest(n_live_tup, 1) * 100, 2) as dead_pct
FROM pg_stat_user_tables
ORDER BY n_dead_tup DESC LIMIT 20;

# WAL files consuming disk
sudo du -sh /var/lib/postgresql/16/main/pg_wal/
# If too large, check replication slots:
SELECT slot_name, active FROM pg_replication_slots;
-- Drop inactive slots to release WAL:
SELECT pg_drop_replication_slot('slot_name');

# Slow queries — enable logging
ALTER SYSTEM SET log_min_duration_statement = 500;  -- ms
SELECT pg_reload_conf();
```
