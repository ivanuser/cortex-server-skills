# Secrets & Environment Management

> Manage `.env` secrets securely, enforce permissions, and rotate compromised credentials with controlled service restarts.

## Safety Rules

- Never commit secrets to git or paste them into incident channels.
- Use file permissions `600` and least-privilege ownership for secret files.
- Rotate compromised secrets immediately and invalidate old credentials.
- Update app config and data-store credentials in a coordinated order.
- Verify service health after each rotation step.

## Quick Reference

```bash
# Create secure .env
install -m 600 -o appuser -g appgroup /dev/null /var/www/myapp/shared/.env

# Validate permissions
stat -c '%a %U %G %n' /var/www/myapp/shared/.env

# Inject variable safely
echo "DATABASE_URL=postgres://user:pass@db:5432/app" | sudo tee -a /var/www/myapp/shared/.env >/dev/null

# Restart app gracefully
pm2 reload ecosystem.config.js --update-env
```

## `.env` File Management

### Create and lock down

```bash
sudo install -d -m 750 -o appuser -g appgroup /var/www/myapp/shared
sudo install -m 600 -o appuser -g appgroup /dev/null /var/www/myapp/shared/.env
```

### Example format

```text
APP_ENV=production
APP_PORT=3000
DATABASE_URL=postgres://appuser:strongpass@127.0.0.1:5432/appdb
REDIS_URL=redis://:strongpass@127.0.0.1:6379/0
```

### Parse safely in shell scripts

```bash
set -a
source /var/www/myapp/shared/.env
set +a
```

## Secrets Rotation Playbook

Scenario: compromised database password.

1. Create new DB credential.
2. Update app secret file.
3. Reload app.
4. Verify connectivity.
5. Revoke old credential.

### PostgreSQL rotation

```bash
# 1) Change DB user password
sudo -u postgres psql -c "ALTER USER appuser WITH PASSWORD 'NEW_STRONG_PASSWORD';"

# 2) Update .env atomically
sudo cp /var/www/myapp/shared/.env /var/www/myapp/shared/.env.bak.$(date +%s)
sudo sed -i 's#^DATABASE_URL=.*#DATABASE_URL=postgres://appuser:NEW_STRONG_PASSWORD@127.0.0.1:5432/appdb#' /var/www/myapp/shared/.env

# 3) Reload app
cd /var/www/myapp/current
pm2 reload ecosystem.config.js --update-env

# 4) Verify
curl -fsS http://127.0.0.1:<PORT>/health
```

### MySQL rotation

```bash
mysql -u root -p -e "ALTER USER 'appuser'@'%' IDENTIFIED BY 'NEW_STRONG_PASSWORD'; FLUSH PRIVILEGES;"
```

## Secret Scanning Hygiene

```bash
# Quick search for obvious leaks before commit
git diff --cached | grep -Ei 'password|secret|api[_-]?key|token' || true
```

## Optional: File Encryption at Rest

```bash
# Encrypt env file backup with gpg
gpg --symmetric --cipher-algo AES256 /var/www/myapp/shared/.env.bak.<timestamp>
```

## Troubleshooting

- App fails after rotation: validate `.env` syntax and service user read permissions.
- Secret updates ignored: process manager may need `--update-env` or full restart.
- DB auth still using old password: check connection pool reuse and recycle workers.
- Accidental git leak: rotate compromised secret immediately and purge history if required.
