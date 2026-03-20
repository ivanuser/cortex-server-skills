# SQLite — Embedded Relational Database

> Use and manage SQLite for lightweight, serverless, embedded databases. Covers database creation, schema, queries, backup, WAL mode, performance tuning, and CLI usage.

## Safety Rules

- **`DROP TABLE` and `DELETE` without `WHERE` are irreversible** — backup first.
- Never delete the `-wal` or `-shm` files while the database is open — causes corruption.
- Use transactions for bulk operations — individual inserts are ~50x slower.
- Don't use SQLite for high-concurrency write workloads (>10 writers) — use PostgreSQL/MySQL.
- Set `PRAGMA journal_mode=WAL` for concurrent read/write access.
- Always `.backup` before schema migrations.

## Quick Reference

```bash
# Install (usually pre-installed on most Linux distros)
sudo apt install -y sqlite3            # Debian/Ubuntu
sudo dnf install -y sqlite            # RHEL/Rocky
brew install sqlite                    # macOS

# Version check
sqlite3 --version

# Open/create database
sqlite3 mydb.db
sqlite3 :memory:                       # In-memory database

# Open read-only
sqlite3 -readonly mydb.db

# Execute SQL from command line
sqlite3 mydb.db "SELECT * FROM users;"
sqlite3 mydb.db < schema.sql           # Execute SQL file

# Non-interactive with headers and column mode
sqlite3 -header -column mydb.db "SELECT * FROM users LIMIT 10;"

# CSV output
sqlite3 -header -csv mydb.db "SELECT * FROM users;" > users.csv
```

## CLI Commands (dot-commands)

```sql
-- Inside sqlite3 shell:
.help                                  -- Show all dot-commands
.databases                             -- List attached databases
.tables                                -- List tables
.schema                                -- Show all CREATE statements
.schema users                          -- Show CREATE for specific table
.headers on                            -- Show column headers
.mode column                           -- Column-aligned output
.mode csv                              -- CSV output
.mode json                             -- JSON output
.mode markdown                         -- Markdown table output
.width 20 30 15                        -- Set column widths
.output results.txt                    -- Redirect output to file
.output stdout                         -- Reset to terminal
.read script.sql                       -- Execute SQL file
.dump                                  -- Dump entire database as SQL
.dump users                            -- Dump single table
.quit                                  -- Exit
```

## Database & Table Operations

```sql
-- Create table
CREATE TABLE users (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  username TEXT NOT NULL UNIQUE,
  email TEXT NOT NULL,
  age INTEGER DEFAULT 0,
  created_at TEXT DEFAULT (datetime('now')),
  CHECK (age >= 0)
);

-- Create table with foreign key
CREATE TABLE posts (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id INTEGER NOT NULL,
  title TEXT NOT NULL,
  body TEXT,
  created_at TEXT DEFAULT (datetime('now')),
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

-- Enable foreign keys (must be set per connection!)
PRAGMA foreign_keys = ON;

-- Create index
CREATE INDEX idx_users_email ON users(email);
CREATE UNIQUE INDEX idx_users_username ON users(username);
CREATE INDEX idx_posts_user_date ON posts(user_id, created_at DESC);

-- List indexes
.indexes
.indexes users
SELECT * FROM sqlite_master WHERE type='index';

-- Alter table (limited — can add columns, rename)
ALTER TABLE users ADD COLUMN bio TEXT;
ALTER TABLE users RENAME COLUMN bio TO biography;
ALTER TABLE users RENAME TO accounts;

-- Drop table
DROP TABLE IF EXISTS posts;

-- Temporary table (session-scoped)
CREATE TEMP TABLE staging (id INTEGER, data TEXT);
```

## Queries & Data Operations

```sql
-- Insert
INSERT INTO users (username, email, age) VALUES ('ivan', 'ivan@example.com', 30);
INSERT INTO users (username, email, age) VALUES
  ('alice', 'alice@example.com', 25),
  ('bob', 'bob@example.com', 35);

-- Insert or replace (upsert)
INSERT OR REPLACE INTO users (id, username, email, age)
VALUES (1, 'ivan', 'ivan@new.com', 31);

-- Upsert with ON CONFLICT (SQLite 3.24+)
INSERT INTO users (username, email, age) VALUES ('ivan', 'ivan@new.com', 31)
ON CONFLICT(username) DO UPDATE SET email = excluded.email, age = excluded.age;

-- Select
SELECT * FROM users WHERE age >= 25 ORDER BY username ASC LIMIT 10;
SELECT username, COUNT(*) as post_count
FROM users JOIN posts ON users.id = posts.user_id
GROUP BY users.id HAVING post_count > 5
ORDER BY post_count DESC;

-- Date/time functions
SELECT * FROM users WHERE created_at > datetime('now', '-7 days');
SELECT date('now'), time('now'), datetime('now', 'localtime');
SELECT strftime('%Y-%m', created_at) as month, COUNT(*) FROM posts GROUP BY month;

-- JSON functions (SQLite 3.38+)
SELECT json_extract(metadata, '$.name') FROM configs;
SELECT * FROM users WHERE json_extract(preferences, '$.theme') = 'dark';

-- Update
UPDATE users SET email = 'new@example.com' WHERE username = 'ivan';

-- Delete
DELETE FROM users WHERE age < 18;

-- Window functions
SELECT username, age,
  ROW_NUMBER() OVER (ORDER BY age DESC) as rank,
  AVG(age) OVER () as avg_age
FROM users;

-- CTE (Common Table Expression)
WITH active_users AS (
  SELECT user_id, COUNT(*) as posts
  FROM posts WHERE created_at > datetime('now', '-30 days')
  GROUP BY user_id
)
SELECT u.username, a.posts FROM users u JOIN active_users a ON u.id = a.user_id;
```

## Backup & Restore

```bash
# Method 1: .backup command (safe — handles locking)
sqlite3 mydb.db ".backup /backup/mydb_$(date +%Y%m%d).db"

# Method 2: SQL dump (portable — text-based backup)
sqlite3 mydb.db ".dump" > /backup/mydb_$(date +%Y%m%d).sql

# Restore from SQL dump
sqlite3 newdb.db < /backup/mydb_20260320.sql

# Method 3: Online backup API via CLI
sqlite3 mydb.db "VACUUM INTO '/backup/mydb_vacuum.db';"

# Method 4: Copy file (ONLY safe if no active connections)
cp mydb.db mydb.db.bak
# With WAL mode, must also copy: mydb.db-wal and mydb.db-shm

# Verify backup integrity
sqlite3 /backup/mydb_20260320.db "PRAGMA integrity_check;"

# Automated backup script
cat <<'EOF' > /usr/local/bin/backup-sqlite.sh
#!/bin/bash
DB="$1"
DEST="/backup/sqlite/$(basename "$DB" .db)_$(date +%Y%m%d_%H%M).db"
mkdir -p "$(dirname "$DEST")"
sqlite3 "$DB" ".backup $DEST"
find /backup/sqlite/ -name "*.db" -mtime +30 -delete
EOF
chmod +x /usr/local/bin/backup-sqlite.sh
```

## WAL Mode & Performance

### Enable WAL (Write-Ahead Logging)

```sql
-- WAL mode: allows concurrent reads during writes
PRAGMA journal_mode = WAL;             -- Returns 'wal' if successful
PRAGMA wal_autocheckpoint = 1000;      -- Checkpoint every 1000 pages
PRAGMA busy_timeout = 5000;            -- Wait 5s instead of failing on lock
```

### Performance PRAGMAs

```sql
-- Recommended production settings (set per connection)
PRAGMA journal_mode = WAL;
PRAGMA synchronous = NORMAL;           -- Safe with WAL (vs FULL which is slower)
PRAGMA cache_size = -64000;            -- 64MB cache (negative = KB)
PRAGMA temp_store = MEMORY;            -- Temp tables in RAM
PRAGMA mmap_size = 268435456;          -- 256MB memory-mapped I/O
PRAGMA foreign_keys = ON;
PRAGMA busy_timeout = 5000;

-- Check current settings
PRAGMA journal_mode;
PRAGMA synchronous;
PRAGMA cache_size;
PRAGMA page_size;                      -- Usually 4096
PRAGMA page_count;                     -- Total pages

-- Database size
SELECT page_count * page_size as size_bytes FROM pragma_page_count(), pragma_page_size();
```

### Optimize Bulk Operations

```sql
-- Bulk insert (60x faster with transaction)
BEGIN TRANSACTION;
INSERT INTO users (username, email) VALUES ('user1', 'u1@test.com');
INSERT INTO users (username, email) VALUES ('user2', 'u2@test.com');
-- ... thousands more ...
COMMIT;

-- Even faster with prepared statements (application code):
-- Disable journal sync temporarily for initial data load ONLY
PRAGMA synchronous = OFF;
PRAGMA journal_mode = MEMORY;
BEGIN; /* bulk inserts */ COMMIT;
PRAGMA synchronous = NORMAL;
PRAGMA journal_mode = WAL;
```

### VACUUM & Optimization

```sql
-- Reclaim unused space (rewrites entire DB)
VACUUM;

-- VACUUM into new file
VACUUM INTO 'compacted.db';

-- Analyze tables (update query planner stats)
ANALYZE;

-- Optimize (runs analyze + other optimizations)
PRAGMA optimize;                       -- Run on connection close
```

## Query Analysis

```sql
-- Explain query plan (check index usage)
EXPLAIN QUERY PLAN SELECT * FROM users WHERE email = 'ivan@example.com';
-- Look for "SCAN" (bad) vs "SEARCH" (good, using index)

-- Full explain (bytecode — advanced)
EXPLAIN SELECT * FROM users WHERE email = 'ivan@example.com';

-- Check table info
PRAGMA table_info(users);
PRAGMA table_xinfo(users);             -- Including hidden columns
PRAGMA index_list(users);
PRAGMA index_info(idx_users_email);

-- Database stats
SELECT type, name, tbl_name FROM sqlite_master ORDER BY type, name;
```

## Attach Multiple Databases

```sql
-- Attach another database
ATTACH DATABASE '/path/to/other.db' AS other;

-- Query across databases
SELECT u.username, o.data
FROM main.users u JOIN other.extra_data o ON u.id = o.user_id;

-- Copy table between databases
INSERT INTO other.users SELECT * FROM main.users;

-- Detach
DETACH DATABASE other;
```

## Troubleshooting

```bash
# Database locked errors
sqlite3 mydb.db "PRAGMA busy_timeout = 10000;"
# Check for stale WAL locks:
ls -la mydb.db*                        # .db, .db-wal, .db-shm

# Find what process has the DB open
fuser mydb.db
lsof mydb.db

# Integrity check
sqlite3 mydb.db "PRAGMA integrity_check;"
sqlite3 mydb.db "PRAGMA quick_check;"  # Faster, less thorough

# Recover corrupted database
sqlite3 corrupt.db ".dump" | sqlite3 recovered.db
# Or:
sqlite3 corrupt.db ".recover" | sqlite3 recovered.db  # SQLite 3.29+

# Database too large / slow
sqlite3 mydb.db "SELECT name, SUM(pgsize) as size FROM dbstat GROUP BY name ORDER BY size DESC;"
sqlite3 mydb.db "VACUUM;"             # Reclaim space
sqlite3 mydb.db "ANALYZE;"            # Update stats

# WAL file growing too large
sqlite3 mydb.db "PRAGMA wal_checkpoint(TRUNCATE);"

# Foreign keys not enforcing
# Must enable per connection: PRAGMA foreign_keys = ON;
# Check: PRAGMA foreign_keys;

# Max database size: 281 TB (theoretical)
# Max row size: 1 billion bytes (practical limit is lower)
```
