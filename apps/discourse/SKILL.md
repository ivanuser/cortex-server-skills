# Discourse — Community Forum Platform

> Install, configure, and manage Discourse — Docker deployment, plugins, backups, email, user management, API, and performance tuning.

## Safety Rules

- **Always backup before upgrading**: `./launcher backup app`
- Never modify files inside the container directly — use `app.yml` and rebuild.
- Don't run `./launcher destroy app` without a verified backup.
- Email (SMTP) must work for Discourse to function — signups, notifications, and password resets depend on it.
- Rate-limit API calls — Discourse enforces per-user and global rate limits.

## Quick Reference

```bash
# All commands run from /var/discourse
cd /var/discourse

# Container management
./launcher start app
./launcher stop app
./launcher restart app
./launcher status app

# Rebuild (apply config changes)
./launcher rebuild app

# Backup / restore
./launcher backup app
./launcher restore app <filename>

# Enter container shell
./launcher enter app

# View logs
./launcher logs app
./launcher logs app --tail 100

# Upgrade Discourse
./launcher rebuild app                 # Pulls latest image + rebuilds

# Rails console (inside container)
./launcher enter app
rails c
```

## Installation (Docker — Official Method)

### Prerequisites

```bash
# Ubuntu/Debian — minimum 2GB RAM (4GB+ recommended), 10GB disk
sudo apt update && sudo apt install -y git docker.io
sudo systemctl enable --now docker

# Clone Discourse Docker
sudo -s
git clone https://github.com/discourse/discourse_docker.git /var/discourse
cd /var/discourse
```

### Initial setup

```bash
# Interactive setup wizard
./discourse-setup

# It will ask for:
# - Hostname (forum.example.com)
# - Admin email
# - SMTP server, port, username, password
# - Optional: Let's Encrypt email for SSL
```

### Manual configuration (`/var/discourse/containers/app.yml`)

```yaml
templates:
  - "templates/postgres.template.yml"
  - "templates/redis.template.yml"
  - "templates/web.template.yml"
  - "templates/web.ratelimited.template.yml"
  # Uncomment for SSL:
  # - "templates/web.ssl.template.yml"
  # - "templates/web.letsencrypt.ssl.template.yml"

expose:
  - "80:80"
  - "443:443"

params:
  db_default_text_search_config: "pg_catalog.english"
  db_shared_buffers: "256MB"
  db_work_mem: "40MB"
  version: stable

env:
  LC_ALL: en_US.UTF-8
  LANG: en_US.UTF-8
  LANGUAGE: en_US.UTF-8

  DISCOURSE_DEFAULT_LOCALE: en
  DISCOURSE_HOSTNAME: forum.example.com
  DISCOURSE_DEVELOPER_EMAILS: 'admin@example.com'

  # SMTP (required!)
  DISCOURSE_SMTP_ADDRESS: smtp.mailgun.org
  DISCOURSE_SMTP_PORT: 587
  DISCOURSE_SMTP_USER_NAME: postmaster@mg.example.com
  DISCOURSE_SMTP_PASSWORD: smtp_password_here
  DISCOURSE_SMTP_ENABLE_START_TLS: true
  DISCOURSE_SMTP_DOMAIN: example.com
  DISCOURSE_NOTIFICATION_EMAIL: noreply@example.com

  # Let's Encrypt
  LETSENCRYPT_ACCOUNT_EMAIL: admin@example.com

  # Memory tuning
  UNICORN_WORKERS: 4
  UNICORN_SIDEKIQS: 1
  DISCOURSE_MAX_REQS_PER_IP_PER_MINUTE: 200
  DISCOURSE_MAX_REQS_PER_IP_PER_10_SECONDS: 50

volumes:
  - volume:
      host: /var/discourse/shared/standalone
      guest: /shared
  - volume:
      host: /var/discourse/shared/standalone/log/var-log
      guest: /var/log

hooks:
  after_code:
    - exec:
        cd: $home/plugins
        cmd:
          - git clone https://github.com/discourse/docker_manager.git
```

```bash
# Build and launch
./launcher rebuild app
```

## Plugins

### Adding plugins

Edit `app.yml` hooks section:

```yaml
hooks:
  after_code:
    - exec:
        cd: $home/plugins
        cmd:
          - git clone https://github.com/discourse/docker_manager.git
          - git clone https://github.com/discourse/discourse-solved.git
          - git clone https://github.com/discourse/discourse-voting.git
          - git clone https://github.com/discourse/discourse-assign.git
          - git clone https://github.com/discourse/discourse-data-explorer.git
          - git clone https://github.com/discourse/discourse-chat-integration.git
          - git clone https://github.com/discourse/discourse-calendar.git
```

```bash
# Rebuild to install plugins
./launcher rebuild app
```

### Removing a plugin

Remove the `git clone` line from `app.yml`, then `./launcher rebuild app`.

### List installed plugins (Rails console)

```bash
./launcher enter app
rails c
Discourse.plugins.each { |p| puts "#{p.name} - #{p.metadata.version}" }
```

## Backup & Restore

```bash
# Create backup
./launcher backup app
# Backups stored in: /var/discourse/shared/standalone/backups/default/

# List backups
ls -la /var/discourse/shared/standalone/backups/default/

# Restore from backup
./launcher restore app backup-filename.tar.gz

# Download backup via API
curl -H "Api-Key: YOUR_API_KEY" -H "Api-Username: system" \
    "https://forum.example.com/admin/backups" | jq '.[] | .filename'

# Automated daily backups (in admin panel)
# Settings → Backups → backup_frequency: 1 (daily)
# Settings → Backups → s3_backup_bucket (optional S3 offsite)
```

### Manual database backup (inside container)

```bash
./launcher enter app
su - postgres -c "pg_dump discourse > /shared/backups/discourse-manual-$(date +%F).sql"
```

## Upgrades

### Standard upgrade (recommended)

```bash
cd /var/discourse
git pull                               # Update launcher scripts
./launcher rebuild app                 # Pull latest + rebuild
```

### Web-based upgrade

Navigate to `/admin/upgrade` in your Discourse admin panel — uses Docker Manager plugin.

### Upgrade plugins only

```bash
./launcher enter app
cd /var/www/discourse
RAILS_ENV=production bundle exec rake plugin:pull_compatible_all
```

## Sidekiq (Background Jobs)

```bash
# Check Sidekiq status (in Rails console)
./launcher enter app
rails c
Sidekiq::Stats.new.to_s
Sidekiq::Queue.all.map { |q| "#{q.name}: #{q.size}" }
Sidekiq::RetrySet.new.size
Sidekiq::DeadSet.new.size

# Clear failed jobs
Sidekiq::RetrySet.new.clear
Sidekiq::DeadSet.new.clear

# Process stuck jobs
Sidekiq::Queue.new("default").each { |job| puts job.klass }
```

### Web dashboard

Navigate to `/sidekiq` in admin panel for real-time Sidekiq monitoring.

## Email Configuration & Testing

```bash
# Test SMTP from inside container
./launcher enter app
rails c
Email::Sender.new(
  UserNotifications.signup(User.find_by(username: 'admin'), { email_token: "test" }),
  :signup
).send

# Or use the admin panel:
# Admin → Email → Send Test Email

# Check email logs
# Admin → Email → Sent / Skipped / Bounced

# Common SMTP settings for popular providers:

# Mailgun
DISCOURSE_SMTP_ADDRESS: smtp.mailgun.org
DISCOURSE_SMTP_PORT: 587

# SendGrid
DISCOURSE_SMTP_ADDRESS: smtp.sendgrid.net
DISCOURSE_SMTP_PORT: 587
DISCOURSE_SMTP_USER_NAME: apikey
DISCOURSE_SMTP_PASSWORD: SG.xxxx

# AWS SES
DISCOURSE_SMTP_ADDRESS: email-smtp.us-east-1.amazonaws.com
DISCOURSE_SMTP_PORT: 587
```

## User Management

### Rails console

```bash
./launcher enter app
rails c

# Create admin user
u = User.create!(username: 'newadmin', email: 'admin@example.com', password: 'temp_password', active: true, approved: true)
u.grant_admin!
u.activate

# Reset password
u = User.find_by(username: 'john')
u.password = 'new_password'
u.save!

# Suspend a user
u = User.find_by(username: 'spammer')
u.suspended_till = 100.years.from_now
u.suspended_at = Time.now
u.save!

# Delete a user and their posts
UserDestroyer.new(Discourse.system_user).destroy(User.find_by(username: 'spammer'), delete_posts: true)

# List admins
User.where(admin: true).pluck(:username, :email)
```

### API user management

```bash
# Create user via API
curl -X POST "https://forum.example.com/users.json" \
    -H "Api-Key: YOUR_API_KEY" \
    -H "Api-Username: system" \
    -F "name=John Doe" \
    -F "email=john@example.com" \
    -F "username=john" \
    -F "password=temp_password_123!" \
    -F "active=true" \
    -F "approved=true"

# Suspend user
curl -X PUT "https://forum.example.com/admin/users/{user_id}/suspend.json" \
    -H "Api-Key: YOUR_API_KEY" \
    -H "Api-Username: system" \
    -F "suspend_until=2030-01-01" \
    -F "reason=Spamming"
```

## API Usage

```bash
# Generate API key: Admin → API → New API Key

# List latest topics
curl -s -H "Api-Key: YOUR_API_KEY" -H "Api-Username: system" \
    "https://forum.example.com/latest.json" | jq '.topic_list.topics[:5] | .[].title'

# Create a topic
curl -X POST "https://forum.example.com/posts.json" \
    -H "Api-Key: YOUR_API_KEY" \
    -H "Api-Username: system" \
    -F "title=Hello from the API" \
    -F "raw=This is the post body with **markdown** support." \
    -F "category=1"

# Reply to a topic
curl -X POST "https://forum.example.com/posts.json" \
    -H "Api-Key: YOUR_API_KEY" \
    -H "Api-Username: system" \
    -F "topic_id=42" \
    -F "raw=This is a reply."

# Search
curl -s -H "Api-Key: YOUR_API_KEY" -H "Api-Username: system" \
    "https://forum.example.com/search.json?q=keyword" | jq '.posts[:5] | .[].blurb'

# Get user info
curl -s -H "Api-Key: YOUR_API_KEY" -H "Api-Username: system" \
    "https://forum.example.com/admin/users/{user_id}.json" | jq '{username, email, trust_level, active}'

# List categories
curl -s "https://forum.example.com/categories.json" | jq '.category_list.categories[] | {id, name, slug}'

# Site statistics
curl -s -H "Api-Key: YOUR_API_KEY" -H "Api-Username: system" \
    "https://forum.example.com/admin/dashboard.json" | jq '.global_reports'
```

## Category Management

```bash
# Create category via API
curl -X POST "https://forum.example.com/categories.json" \
    -H "Api-Key: YOUR_API_KEY" \
    -H "Api-Username: system" \
    -H "Content-Type: application/json" \
    -d '{
        "name": "General Discussion",
        "color": "0088CC",
        "text_color": "FFFFFF",
        "slug": "general",
        "permissions": {"everyone": 1}
    }'

# Update category
curl -X PUT "https://forum.example.com/categories/1.json" \
    -H "Api-Key: YOUR_API_KEY" \
    -H "Api-Username: system" \
    -H "Content-Type: application/json" \
    -d '{"name": "Updated Category Name"}'

# List categories with subcategories
curl -s "https://forum.example.com/categories.json?include_subcategories=true" | jq '.category_list.categories[] | {id, name, subcategory_ids}'
```

## Performance Tuning

### app.yml environment

```yaml
env:
  # Workers (1 per 2GB RAM)
  UNICORN_WORKERS: 4

  # Sidekiq processes
  UNICORN_SIDEKIQS: 1

  # Database
  db_shared_buffers: "512MB"
  db_work_mem: "40MB"

  # Rate limiting
  DISCOURSE_MAX_REQS_PER_IP_PER_MINUTE: 200
  DISCOURSE_MAX_REQS_PER_IP_PER_10_SECONDS: 50
  DISCOURSE_MAX_ASSET_REQS_PER_IP_PER_10_SECONDS: 200

  # CDN (offload static assets)
  DISCOURSE_CDN_URL: https://cdn.example.com
```

### Admin panel settings

```
# Search "performance" in admin settings
# Key settings:
# - anon_cache_duration: 60 (seconds)
# - enable_page_caching: true
# - redirect_users_to_top_page: true (for new users)
```

## Troubleshooting

```bash
# Container won't start
cd /var/discourse
./launcher logs app | tail -50
./launcher rebuild app                 # Full rebuild often fixes issues

# Check container status
docker ps -a | grep discourse

# Enter container for debugging
./launcher enter app

# Check disk space (Discourse needs room)
df -h /var/discourse/shared/

# SMTP not working — test from container
./launcher enter app
rails c
TestMailer.test_email('your@email.com').deliver_now

# 502 Bad Gateway — Unicorn not ready
./launcher logs app | grep -i unicorn
# May need more RAM or fewer UNICORN_WORKERS

# Database issues
./launcher enter app
su - postgres -c "psql discourse -c 'SELECT pg_database_size(current_database()) / 1024 / 1024 AS size_mb;'"

# Rebuild from clean state (keeps data)
./launcher cleanup
./launcher rebuild app

# Safe mode (disable plugins/themes)
# Visit: https://forum.example.com/safe-mode

# Reset admin password
./launcher enter app
rake admin:create
# Or:
rails c
u = User.find_by(email: 'admin@example.com')
u.password = 'new_password'
u.save!

# Sidekiq queue backed up
./launcher enter app
rails c
Sidekiq::Queue.all.map { |q| "#{q.name}: #{q.size}" }
# If stuck, restart:
./launcher restart app

# Container running out of disk
docker system prune -a --volumes       # WARNING: removes ALL unused Docker data
# Or just clean Discourse-specific:
./launcher cleanup
```
