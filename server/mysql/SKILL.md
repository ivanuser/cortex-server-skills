# MySQL — Relational Database

> Install, configure, and manage MySQL — databases, users, backups, replication, InnoDB tuning, and security hardening.

## Safety Rules

- **Never run `DROP DATABASE` without double-checking** — no undo.
- Always `--single-transaction` for InnoDB dumps to avoid locks.
- Test restores regularly — a backup you've never restored is a hope, not a backup.
- Run `mysql_secure_installation` on every new install.
- Never expose port 3306 to the internet without SSL + firewall.
- Use `BEGIN; ... ROLLBACK;` to preview destructive changes.

## Quick Reference

```bash
# Install (Debian/Ubuntu)
sudo apt update && sudo apt install -y mysql-server

# Install (RHEL/Rocky)
sudo dnf install -y mysql-server

# Service management
sudo systemctl enable --now mysql
sudo systemctl status mysql
sudo systemctl restart mysql

# Secure the installation (set root password, remove anon users, etc.)
sudo mysql_secure_installation

# Connect as root (auth_socket on Ubuntu — no password needed with sudo)
sudo mysql

# Connect with password
mysql -h localhost -u myuser -p mydb

# Check version
mysql --version
mysql -e "SELECT VERSION();"

# Quick operations
sudo mysql -e "CREATE DATABASE mydb CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
sudo mysql -e "SHOW DATABASES;"
sudo mysql -e "SHOW PROCESSLIST;"

# Config file location
mysql --help | grep "Default options" -A 1
# Usually: /etc/mysql/mysql.conf.d/mysqld.cnf or /etc/my.cnf
```

## User & Privilege Management

```sql
-- Create user (localhost only)
CREATE USER 'appuser'@'localhost' IDENTIFIED BY 'strong_password_here';

-- Create user (from any host — use with caution)
CREATE USER 'appuser'@'%' IDENTIFIED BY 'strong_password_here';

-- Create user (specific subnet)
CREATE USER 'appuser'@'10.0.0.%' IDENTIFIED BY 'strong_password_here';

-- Grant all privileges on a database
GRANT ALL PRIVILEGES ON mydb.* TO 'appuser'@'localhost';

-- Grant specific privileges
GRANT SELECT, INSERT, UPDATE, DELETE ON mydb.* TO 'appuser'@'localhost';

-- Read-only user
GRANT SELECT ON mydb.* TO 'readonly'@'localhost';

-- Apply privilege changes
FLUSH PRIVILEGES;

-- View grants
SHOW GRANTS FOR 'appuser'@'localhost';

-- Change password
ALTER USER 'appuser'@'localhost' IDENTIFIED BY 'new_password';

-- Drop user
DROP USER 'appuser'@'localhost';

-- List all users
SELECT User, Host, plugin FROM mysql.user;
```

## Database Operations

```sql
-- Create database
CREATE DATABASE mydb CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- Show databases
SHOW DATABASES;

-- Use a database
USE mydb;

-- Show tables
SHOW TABLES;

-- Show table structure
DESCRIBE tablename;
SHOW CREATE TABLE tablename;

-- Database size
SELECT table_schema AS 'Database',
    ROUND(SUM(data_length + index_length) / 1024 / 1024, 2) AS 'Size (MB)'
FROM information_schema.tables
GROUP BY table_schema
ORDER BY SUM(data_length + index_length) DESC;

-- Table sizes in a database
SELECT table_name,
    ROUND((data_length + index_length) / 1024 / 1024, 2) AS 'Size (MB)',
    table_rows
FROM information_schema.tables
WHERE table_schema = 'mydb'
ORDER BY (data_length + index_length) DESC;
```

## Backup & Restore

### mysqldump

```bash
# Dump single database (InnoDB safe)
mysqldump -u root -p --single-transaction --routines --triggers --events mydb > mydb_$(date +%F).sql

# Dump single database (compressed)
mysqldump -u root -p --single-transaction mydb | gzip > mydb_$(date +%F).sql.gz

# Dump all databases
mysqldump -u root -p --all-databases --single-transaction --routines --triggers --events > all_dbs_$(date +%F).sql

# Dump specific tables
mysqldump -u root -p --single-transaction mydb table1 table2 > tables_backup.sql

# Schema only (no data)
mysqldump -u root -p --no-data mydb > mydb_schema.sql

# Data only (no schema)
mysqldump -u root -p --no-create-info mydb > mydb_data.sql
```

### Restore

```bash
# Restore from SQL file
mysql -u root -p mydb < mydb_backup.sql

# Restore from gzip
gunzip < mydb_backup.sql.gz | mysql -u root -p mydb

# Restore all databases
mysql -u root -p < all_dbs_backup.sql
```

### Automated backup script

```bash
#!/bin/bash
# /usr/local/bin/mysql-backup.sh
BACKUP_DIR="/var/backups/mysql"
DAYS_TO_KEEP=7
MYSQL_USER="backup_user"
MYSQL_PASS="backup_pass"
mkdir -p "$BACKUP_DIR"

for db in $(mysql -u "$MYSQL_USER" -p"$MYSQL_PASS" -Bse "SHOW DATABASES" | grep -Ev "^(information_schema|performance_schema|sys|mysql)$"); do
    mysqldump -u "$MYSQL_USER" -p"$MYSQL_PASS" --single-transaction --routines --triggers "$db" | gzip > "$BACKUP_DIR/${db}_$(date +%F_%H%M).sql.gz"
done

find "$BACKUP_DIR" -name "*.sql.gz" -mtime +$DAYS_TO_KEEP -delete
```

### Binary log backup (point-in-time recovery)

```bash
# Enable binary logging in my.cnf
# [mysqld]
# log-bin = /var/log/mysql/mysql-bin
# binlog_expire_logs_seconds = 604800   # 7 days
# server-id = 1

# List binary logs
mysqlbinlog --list /var/log/mysql/mysql-bin.000001

# Point-in-time recovery
mysqlbinlog --start-datetime="2024-01-15 14:00:00" --stop-datetime="2024-01-15 15:00:00" /var/log/mysql/mysql-bin.000001 | mysql -u root -p
```

## Replication (Source → Replica)

### On source (primary)

Edit `/etc/mysql/mysql.conf.d/mysqld.cnf`:

```ini
[mysqld]
server-id = 1
log-bin = /var/log/mysql/mysql-bin
binlog_do_db = mydb                    # Or omit to replicate all
binlog_format = ROW
```

```sql
-- Create replication user
CREATE USER 'repl'@'10.0.0.%' IDENTIFIED BY 'repl_password';
GRANT REPLICATION SLAVE ON *.* TO 'repl'@'10.0.0.%';
FLUSH PRIVILEGES;

-- Get binary log position
SHOW MASTER STATUS;
-- Note the File and Position values
```

```bash
sudo systemctl restart mysql
```

### On replica

Edit `/etc/mysql/mysql.conf.d/mysqld.cnf`:

```ini
[mysqld]
server-id = 2
relay-log = /var/log/mysql/mysql-relay
read_only = ON
```

```sql
-- Configure replication (use File/Position from source's SHOW MASTER STATUS)
CHANGE REPLICATION SOURCE TO
    SOURCE_HOST='10.0.0.1',
    SOURCE_USER='repl',
    SOURCE_PASSWORD='repl_password',
    SOURCE_LOG_FILE='mysql-bin.000001',
    SOURCE_LOG_POS=154;

START REPLICA;

-- Check replication status
SHOW REPLICA STATUS\G
-- Key fields: Replica_IO_Running: Yes, Replica_SQL_Running: Yes, Seconds_Behind_Source: 0
```

### GTID-based replication (preferred)

Source config:
```ini
[mysqld]
server-id = 1
log-bin = /var/log/mysql/mysql-bin
gtid_mode = ON
enforce_gtid_consistency = ON
```

Replica:
```sql
CHANGE REPLICATION SOURCE TO
    SOURCE_HOST='10.0.0.1',
    SOURCE_USER='repl',
    SOURCE_PASSWORD='repl_password',
    SOURCE_AUTO_POSITION=1;
START REPLICA;
```

## InnoDB Tuning

### Key my.cnf settings (example for 16GB RAM server)

```ini
[mysqld]
# InnoDB Buffer Pool — 70-80% of RAM for dedicated DB server
innodb_buffer_pool_size = 12G
innodb_buffer_pool_instances = 8       # 1 per GB (up to 64)

# Redo Log
innodb_log_file_size = 1G
innodb_log_buffer_size = 64M

# I/O
innodb_io_capacity = 2000             # SSD: 2000+, HDD: 200
innodb_io_capacity_max = 4000
innodb_read_io_threads = 8
innodb_write_io_threads = 8

# Flush behavior
innodb_flush_log_at_trx_commit = 1    # 1=safe, 2=faster (risk 1s data loss)
innodb_flush_method = O_DIRECT        # Avoid double-buffering on Linux

# Misc
innodb_file_per_table = ON
innodb_stats_on_metadata = OFF
innodb_temp_data_file_path = ibtmp1:12M:autoextend:max:5G

# Thread pool (MySQL 8.0 Enterprise, or Percona)
# thread_pool_size = 8

# Query cache (disabled by default in 8.0 — leave off)
# query_cache_type = 0

# Connections
max_connections = 200
wait_timeout = 600
interactive_timeout = 600

# Temp tables
tmp_table_size = 256M
max_heap_table_size = 256M

# Sort / join buffers (per-connection!)
sort_buffer_size = 4M
join_buffer_size = 4M
read_buffer_size = 2M
read_rnd_buffer_size = 2M
```

## Slow Query Log

```ini
# In my.cnf
[mysqld]
slow_query_log = ON
slow_query_log_file = /var/log/mysql/mysql-slow.log
long_query_time = 1                    # Seconds
log_queries_not_using_indexes = ON
```

```bash
# Enable at runtime (no restart)
mysql -u root -p -e "SET GLOBAL slow_query_log = 'ON'; SET GLOBAL long_query_time = 1;"

# Analyze slow log
mysqldumpslow -s t /var/log/mysql/mysql-slow.log | head -20

# Or use pt-query-digest (Percona Toolkit)
sudo apt install -y percona-toolkit
pt-query-digest /var/log/mysql/mysql-slow.log
```

## Performance Schema Queries

```sql
-- Top queries by total execution time
SELECT DIGEST_TEXT, COUNT_STAR, 
    ROUND(SUM_TIMER_WAIT/1000000000000, 2) AS total_sec,
    ROUND(AVG_TIMER_WAIT/1000000000, 2) AS avg_ms
FROM performance_schema.events_statements_summary_by_digest
ORDER BY SUM_TIMER_WAIT DESC LIMIT 10;

-- Current running queries
SELECT * FROM performance_schema.events_statements_current
WHERE END_EVENT_ID IS NULL\G

-- Table I/O waits
SELECT OBJECT_SCHEMA, OBJECT_NAME,
    COUNT_READ, COUNT_WRITE, COUNT_FETCH
FROM performance_schema.table_io_waits_summary_by_table
WHERE OBJECT_SCHEMA NOT IN ('mysql', 'performance_schema', 'sys')
ORDER BY COUNT_READ + COUNT_WRITE DESC LIMIT 20;

-- InnoDB buffer pool hit ratio
SHOW STATUS LIKE 'Innodb_buffer_pool_read%';
-- Calculate: 1 - (Innodb_buffer_pool_reads / Innodb_buffer_pool_read_requests)
-- Should be > 99%

-- Connection usage
SHOW STATUS LIKE 'Threads_connected';
SHOW VARIABLES LIKE 'max_connections';
```

## Security Hardening

```bash
# Run the security wizard
sudo mysql_secure_installation
# Answers: Set root password, Remove anonymous users, Disallow root remote login,
#          Remove test database, Reload privilege tables

# Check for accounts without passwords
mysql -u root -p -e "SELECT User, Host FROM mysql.user WHERE authentication_string = '' OR authentication_string IS NULL;"

# Verify bind-address (should be 127.0.0.1 unless needed remotely)
grep bind-address /etc/mysql/mysql.conf.d/mysqld.cnf
```

```sql
-- Require SSL for a user
ALTER USER 'appuser'@'%' REQUIRE SSL;

-- Check SSL status
SHOW VARIABLES LIKE '%ssl%';
\s  -- Shows SSL info in connection status
```

## Monitoring

```sql
-- Active connections
SHOW PROCESSLIST;
SELECT COUNT(*) FROM information_schema.processlist;

-- Kill a query
KILL <process_id>;

-- InnoDB status (detailed engine report)
SHOW ENGINE INNODB STATUS\G

-- Key status variables
SHOW GLOBAL STATUS LIKE 'Uptime';
SHOW GLOBAL STATUS LIKE 'Questions';
SHOW GLOBAL STATUS LIKE 'Slow_queries';
SHOW GLOBAL STATUS LIKE 'Threads%';
SHOW GLOBAL STATUS LIKE 'Innodb_row_lock%';

-- Replication health
SHOW REPLICA STATUS\G
```

## Troubleshooting

```bash
# Check if MySQL is running
sudo systemctl status mysql
mysqladmin -u root -p ping

# Check error log
sudo tail -50 /var/log/mysql/error.log
sudo journalctl -u mysql --since "10 min ago"

# Can't connect as root on Ubuntu (auth_socket)
sudo mysql   # Use sudo, not password

# Too many connections
mysql -u root -p -e "SHOW VARIABLES LIKE 'max_connections';"
mysql -u root -p -e "SHOW STATUS LIKE 'Threads_connected';"
# Increase in my.cnf: max_connections = 500

# InnoDB: Waiting for table metadata lock
# Find blocking query:
SELECT * FROM performance_schema.metadata_locks WHERE LOCK_STATUS = 'GRANTED';

# Disk full — InnoDB needs space for redo logs
df -h /var/lib/mysql/
# Check ibdata1 and ib_logfile sizes
ls -lh /var/lib/mysql/ib*

# Table is marked as crashed (MyISAM)
mysqlcheck -u root -p --repair mydb tablename

# Check all tables
mysqlcheck -u root -p --all-databases --check

# Reset root password (emergency)
sudo systemctl stop mysql
sudo mysqld_safe --skip-grant-tables &
mysql -u root -e "FLUSH PRIVILEGES; ALTER USER 'root'@'localhost' IDENTIFIED BY 'new_password';"
sudo kill $(pgrep mysqld_safe)
sudo systemctl start mysql

# Import large file efficiently
mysql -u root -p --max_allowed_packet=512M mydb < large_dump.sql
```
