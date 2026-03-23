# Zero-Downtime Deploy — Release, Migrate, Rollback

> Deploy application updates with minimal or no user-visible downtime.
> Uses timestamped releases, symlink switching, health checks, and rollback paths.

## Safety Rules

- Never deploy directly into the currently active release directory.
- Build and verify in a new release directory before traffic cutover.
- Database migrations must be backward-compatible with the previous app version.
- Keep at least 2 known-good releases on disk for instant rollback.
- Abort deployment if health checks fail at any stage.

## Quick Reference

```bash
# Create new release
TS=$(date +%Y%m%d_%H%M%S)
REL="/var/www/myapp/releases/$TS"
git clone --depth 1 <repo_url> "$REL"

# Build
cd "$REL"
npm ci && npm run build

# Switch symlink
ln -sfn "$REL" /var/www/myapp/current

# Reload process manager
pm2 reload ecosystem.config.js --update-env

# Verify
curl -fsS http://127.0.0.1:<PORT>/health
```

## Standard Directory Layout

```text
/var/www/myapp/
  releases/
    20260323_153000/
    20260324_101500/
  current -> /var/www/myapp/releases/20260324_101500
  shared/
    .env
    uploads/
```

## Deployment Workflow

1. Pre-flight checks (disk, git, dependencies, health baseline).
2. Create timestamped release directory.
3. Pull code and install dependencies.
4. Run tests/build and static validation.
5. Run safe DB migration.
6. Switch symlink atomically.
7. Reload app process.
8. Run post-deploy health checks.
9. Cleanup old releases with retention.

## Pre-Flight

```bash
set -euo pipefail
df -h
free -h
pm2 status
curl -fsS http://127.0.0.1:<PORT>/health
```

## Symlink Swap Playbook

```bash
APP_ROOT=/var/www/myapp
RELEASES="$APP_ROOT/releases"
CURRENT="$APP_ROOT/current"
TS=$(date +%Y%m%d_%H%M%S)
REL="$RELEASES/$TS"

mkdir -p "$RELEASES"
git clone --depth 1 <repo_url> "$REL"
cd "$REL"
npm ci
npm run build

# Share persistent env/assets
ln -sfn "$APP_ROOT/shared/.env" "$REL/.env"
ln -sfn "$APP_ROOT/shared/uploads" "$REL/uploads"

# Atomic cutover
ln -sfn "$REL" "$CURRENT"
```

## Database Migration Safety

Migration gate:
- Must support rolling forward with old app still reading schema.
- Avoid destructive column drops in same release.

```bash
# Python Alembic
alembic upgrade head

# Laravel
php artisan migrate --force

# Prisma
npx prisma migrate deploy
```

## Process Reload (No Hard Stop)

```bash
# PM2 graceful reload
cd /var/www/myapp/current
pm2 reload ecosystem.config.js --update-env
pm2 save
```

For systemd services:
```bash
sudo systemctl reload myapp || sudo systemctl restart myapp
```

## Verification

```bash
# Local checks
curl -fsS http://127.0.0.1:<PORT>/health
curl -fsS http://127.0.0.1:<PORT>/ready

# Optional external
curl -fsS https://app.example.com/health
```

## Rollback

```bash
APP_ROOT=/var/www/myapp
PREV=$(ls -1dt "$APP_ROOT"/releases/* | sed -n '2p')
ln -sfn "$PREV" "$APP_ROOT/current"
cd "$APP_ROOT/current"
pm2 reload ecosystem.config.js --update-env
curl -fsS http://127.0.0.1:<PORT>/health
```

## Release Retention

```bash
# Keep latest 5 releases
ls -1dt /var/www/myapp/releases/* | tail -n +6 | xargs -r rm -rf
```

## Troubleshooting

- `npm ci` fails on lock mismatch: regenerate lockfile in CI, not on production host.
- Migration fails after symlink switch: rollback symlink first, then diagnose migration state.
- Health endpoint fails but process is up: inspect env symlink and runtime secrets first.
- PM2 reload hangs: check for long shutdown hooks and tune graceful timeout.
