# Advanced Database Tuning

> Improve database performance with slow query analysis, vacuum strategy, and connection pooling.

## Safety Rules

- Benchmark changes before/after; avoid tuning blindly.
- Add indexes based on query patterns, not assumptions.
- Run heavy maintenance windows during low traffic where possible.
- Validate pool settings against DB max connections.
- Keep rollback steps for config changes.

## Quick Reference

```bash
# MySQL slow query log state
mysql -e "SHOW VARIABLES LIKE 'slow_query_log'; SHOW VARIABLES LIKE 'long_query_time';"

# Parse MySQL slow queries
mysqldumpslow -s t -t 20 /var/log/mysql/mysql-slow.log

# PostgreSQL dead tuples
sudo -u postgres psql -c "SELECT relname,n_live_tup,n_dead_tup FROM pg_stat_user_tables ORDER BY n_dead_tup DESC LIMIT 20;"

# PgBouncer stats
psql -h 127.0.0.1 -p 6432 -U pgbouncer pgbouncer -c "SHOW POOLS;"
```

## MySQL Slow Query Log Analysis

Enable:

```sql
SET GLOBAL slow_query_log = 'ON';
SET GLOBAL long_query_time = 0.5;
SET GLOBAL log_queries_not_using_indexes = 'ON';
```

Persist in `mysqld.cnf`:

```text
slow_query_log = 1
slow_query_log_file = /var/log/mysql/mysql-slow.log
long_query_time = 0.5
log_queries_not_using_indexes = 1
```

Analyze:

```bash
mysqldumpslow -s c -t 20 /var/log/mysql/mysql-slow.log
mysqldumpslow -s t -t 20 /var/log/mysql/mysql-slow.log
```

## PostgreSQL Vacuum & Analyze

Monitor bloat indicators:

```sql
SELECT schemaname,relname,n_live_tup,n_dead_tup,
       round((n_dead_tup::numeric / nullif(n_live_tup,0))*100,2) AS dead_pct
FROM pg_stat_user_tables
ORDER BY n_dead_tup DESC
LIMIT 20;
```

Remediate:

```sql
VACUUM (ANALYZE) public.orders;
```

Autovacuum checks:

```sql
SHOW autovacuum;
SHOW autovacuum_naptime;
SHOW autovacuum_vacuum_scale_factor;
```

## Connection Pooling

### PgBouncer baseline

```text
[databases]
appdb = host=127.0.0.1 port=5432 dbname=appdb

[pgbouncer]
listen_addr = 0.0.0.0
listen_port = 6432
auth_type = md5
pool_mode = transaction
default_pool_size = 50
max_client_conn = 1000
```

### ProxySQL baseline (MySQL)

- Route read traffic to replicas.
- Enforce per-user connection limits.

## Index Tuning Workflow

1. Identify top slow query patterns.
2. Inspect explain plans.
3. Add targeted index.
4. Re-run query/load tests.
5. Monitor write overhead impact.

## Troubleshooting

- Slow log empty despite latency: verify `long_query_time` and file path permissions.
- `VACUUM` not helping: inspect blocking long transactions.
- Pooling errors under spikes: increase pool sizes carefully and verify DB `max_connections`.
- Query improved but writes degraded: reassess index count and composite index order.
