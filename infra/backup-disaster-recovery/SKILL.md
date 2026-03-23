# Backup & Disaster Recovery — Database and Offsite Protection

> Create reliable backups, sync them offsite, and restore fast with verification.
> A backup is not complete until a restore test succeeds.

## Safety Rules

- Never run destructive restore commands without confirming target environment and host.
- Use `--single-transaction` for InnoDB logical backups to reduce lock impact.
- Encrypt backups before offsite transfer when they contain sensitive data.
- Keep retention policies explicit and tested.
- Every backup workflow must include a restore verification step.

## Quick Reference

```bash
# MySQL backup
mysqldump --single-transaction --routines --triggers --events \
  -u root -p mydb | gzip > /var/backups/mysql/mydb_$(date +%F_%H%M).sql.gz

# PostgreSQL backup
pg_dump -U postgres -d mydb -Fc -f /var/backups/postgres/mydb_$(date +%F_%H%M).dump

# Offsite sync with AWS CLI
aws s3 sync /var/backups s3://<bucket>/server-backups/ --storage-class STANDARD_IA

# Restore checks
gunzip -t /var/backups/mysql/<file>.sql.gz
pg_restore -l /var/backups/postgres/<file>.dump | head -40
```

## Directory Layout

```text
/var/backups/
  mysql/
  postgres/
  manifests/
  logs/
```

## MySQL / MariaDB Backups

### Full logical dump

```bash
mkdir -p /var/backups/mysql /var/backups/logs
OUT="/var/backups/mysql/mydb_$(date +%F_%H%M).sql.gz"
mysqldump --single-transaction --routines --triggers --events \
  --set-gtid-purged=OFF -u root -p mydb | gzip > "$OUT"
echo "$OUT"
```

### Backup all databases

```bash
OUT="/var/backups/mysql/all_$(date +%F_%H%M).sql.gz"
mysqldump --single-transaction --routines --triggers --events \
  -u root -p --all-databases | gzip > "$OUT"
```

### Validate dump

```bash
gunzip -t "$OUT"
zgrep -m1 -E 'Dump completed|MySQL dump' "$OUT"
```

## PostgreSQL Backups

### Custom-format dump (preferred)

```bash
mkdir -p /var/backups/postgres
OUT="/var/backups/postgres/mydb_$(date +%F_%H%M).dump"
pg_dump -U postgres -d mydb -Fc -f "$OUT"
```

### Plain SQL dump

```bash
OUT="/var/backups/postgres/mydb_$(date +%F_%H%M).sql.gz"
pg_dump -U postgres -d mydb | gzip > "$OUT"
```

### Validate dump

```bash
pg_restore -l /var/backups/postgres/<file>.dump | head -60
```

## Offsite Sync

## AWS S3 via AWS CLI

```bash
# One-time bucket policy and credentials should be preconfigured
aws s3 sync /var/backups s3://<bucket>/server-backups/ \
  --exclude "*.tmp" \
  --storage-class STANDARD_IA
```

### Integrity and inventory

```bash
aws s3 ls s3://<bucket>/server-backups/ --recursive | tail -50
sha256sum /var/backups/mysql/*.gz | tail -20
```

## rsync / rclone Alternatives

```bash
# rsync to remote backup host
rsync -avz --delete /var/backups/ backup@backup-host:/srv/backups/server1/

# rclone to object storage
rclone sync /var/backups remote:server-backups/server1
```

## Retention Policy Example

```bash
# Keep daily backups 14 days
find /var/backups/mysql -type f -mtime +14 -name '*.gz' -delete
find /var/backups/postgres -type f -mtime +14 -name '*.dump' -delete
```

## Restore Protocols

### MySQL restore (targeted DB)

```bash
# WARNING: destructive if dropping existing DB
mysql -u root -p -e "DROP DATABASE IF EXISTS mydb; CREATE DATABASE mydb;"
gunzip -c /var/backups/mysql/mydb_<timestamp>.sql.gz | mysql -u root -p mydb
```

### PostgreSQL restore (custom dump)

```bash
# WARNING: destructive if dropping existing DB
sudo -u postgres psql -c "DROP DATABASE IF EXISTS mydb;"
sudo -u postgres psql -c "CREATE DATABASE mydb OWNER appuser;"
sudo -u postgres pg_restore -d mydb /var/backups/postgres/mydb_<timestamp>.dump
```

### PostgreSQL restore (plain SQL)

```bash
gunzip -c /var/backups/postgres/mydb_<timestamp>.sql.gz | sudo -u postgres psql mydb
```

## Post-Restore Verification

```bash
# Basic checks
mysql -u root -p -e "USE mydb; SHOW TABLES;"
sudo -u postgres psql -d mydb -c '\dt'

# App-level checks
curl -fsS http://127.0.0.1:<APP_PORT>/health
```

Success criteria:
- Database objects restored.
- Row counts/sample queries match expectations.
- Application health endpoint returns success.

## Automation Script Skeleton

```bash
#!/usr/bin/env bash
set -euo pipefail
TS=$(date +%F_%H%M)
mkdir -p /var/backups/{mysql,postgres,logs}

mysqldump --single-transaction -u root -p"$MYSQL_PW" mydb | gzip > "/var/backups/mysql/mydb_${TS}.sql.gz"
pg_dump -U postgres -d mydb -Fc -f "/var/backups/postgres/mydb_${TS}.dump"
aws s3 sync /var/backups s3://<bucket>/server-backups/
```

## Troubleshooting

- `Access denied` on DB dump: verify user privileges (`SELECT`, `LOCK TABLES` if needed).
- Slow backups during peak traffic: schedule during lower load and prefer transaction-safe dump flags.
- S3 sync failures: validate IAM policy, region, and clock sync on host.
- Restore fails with missing roles/users: recreate required DB roles before import.
- Backup succeeded but restore failed: treat backup as invalid and investigate before next cycle.
