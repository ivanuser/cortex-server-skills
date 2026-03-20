# Nextcloud — Self-Hosted Cloud Platform

> Install, configure, and manage Nextcloud — file sync, sharing, occ administration, upgrades, performance tuning, and integrations.

## Safety Rules

- **Always enable maintenance mode before upgrades**: `sudo -u www-data php occ maintenance:mode --on`
- Back up files AND database before any upgrade or major change.
- Never skip major versions when upgrading (27 → 28 → 29, not 27 → 29).
- Don't edit `config.php` while Nextcloud is running without maintenance mode.
- Test upgrades on a staging instance first if possible.
- Run `occ` commands as the web server user (`www-data` on Debian/Ubuntu).

## Quick Reference

```bash
# occ command prefix (all occ commands use this)
sudo -u www-data php /var/www/nextcloud/occ

# Shorter alias (add to .bashrc)
alias occ="sudo -u www-data php /var/www/nextcloud/occ"

# Status
occ status
occ config:list

# Maintenance mode
occ maintenance:mode --on
occ maintenance:mode --off

# Upgrade
occ upgrade
occ maintenance:repair

# User management
occ user:list
occ user:add --display-name="John Doe" --group="users" john
occ user:delete john
occ user:resetpassword john
occ user:disable john
occ user:enable john

# File operations
occ files:scan --all
occ files:scan --path="john/files"
occ files:cleanup

# App management
occ app:list
occ app:install calendar
occ app:enable calendar
occ app:disable calendar
occ app:update --all

# Background jobs
occ background:cron
occ maintenance:repair
```

## Installation — LAMP Stack

### Prerequisites

```bash
# Install PHP 8.3 + required modules
sudo apt install -y apache2 libapache2-mod-php \
    php8.3 php8.3-gd php8.3-mysql php8.3-curl php8.3-mbstring \
    php8.3-intl php8.3-gmp php8.3-bcmath php8.3-xml php8.3-zip \
    php8.3-imagick php8.3-apcu php8.3-redis php8.3-memcached \
    php8.3-fpm php8.3-opcache

# Install MariaDB
sudo apt install -y mariadb-server
sudo mysql_secure_installation
```

### Database setup

```sql
sudo mysql
CREATE DATABASE nextcloud CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;
CREATE USER 'nextcloud'@'localhost' IDENTIFIED BY 'strong_db_password';
GRANT ALL PRIVILEGES ON nextcloud.* TO 'nextcloud'@'localhost';
FLUSH PRIVILEGES;
EXIT;
```

### Download & Install Nextcloud

```bash
cd /tmp
wget https://download.nextcloud.com/server/releases/latest.tar.bz2
tar -xjf latest.tar.bz2
sudo mv nextcloud /var/www/nextcloud
sudo chown -R www-data:www-data /var/www/nextcloud

# Run web installer or CLI install
sudo -u www-data php /var/www/nextcloud/occ maintenance:install \
    --database "mysql" \
    --database-name "nextcloud" \
    --database-user "nextcloud" \
    --database-pass "strong_db_password" \
    --admin-user "admin" \
    --admin-pass "admin_password" \
    --data-dir "/var/www/nextcloud/data"
```

### Apache virtual host

```apache
# /etc/apache2/sites-available/nextcloud.conf
<VirtualHost *:80>
    ServerName cloud.example.com
    DocumentRoot /var/www/nextcloud

    <Directory /var/www/nextcloud>
        Require all granted
        AllowOverride All
        Options FollowSymLinks MultiViews
        Satisfy Any

        <IfModule mod_dav.c>
            Dav off
        </IfModule>
    </Directory>

    ErrorLog ${APACHE_LOG_DIR}/nextcloud-error.log
    CustomLog ${APACHE_LOG_DIR}/nextcloud-access.log combined
</VirtualHost>
```

```bash
sudo a2ensite nextcloud.conf
sudo a2enmod rewrite headers env dir mime
sudo systemctl restart apache2
```

## Installation — Docker

```yaml
# docker-compose.yml
version: '3.8'

services:
  db:
    image: mariadb:11
    restart: always
    command: --transaction-isolation=READ-COMMITTED --log-bin=binlog --binlog-format=ROW
    volumes:
      - db_data:/var/lib/mysql
    environment:
      MYSQL_ROOT_PASSWORD: root_password
      MYSQL_DATABASE: nextcloud
      MYSQL_USER: nextcloud
      MYSQL_PASSWORD: db_password

  redis:
    image: redis:7-alpine
    restart: always
    command: redis-server --requirepass redis_password

  app:
    image: nextcloud:29-apache
    restart: always
    ports:
      - "8080:80"
    volumes:
      - nextcloud_data:/var/www/html
    environment:
      MYSQL_HOST: db
      MYSQL_DATABASE: nextcloud
      MYSQL_USER: nextcloud
      MYSQL_PASSWORD: db_password
      REDIS_HOST: redis
      REDIS_HOST_PASSWORD: redis_password
      NEXTCLOUD_ADMIN_USER: admin
      NEXTCLOUD_ADMIN_PASSWORD: admin_password
      NEXTCLOUD_TRUSTED_DOMAINS: cloud.example.com
    depends_on:
      - db
      - redis

  cron:
    image: nextcloud:29-apache
    restart: always
    volumes:
      - nextcloud_data:/var/www/html
    entrypoint: /cron.sh
    depends_on:
      - app

volumes:
  db_data:
  nextcloud_data:
```

```bash
docker compose up -d
```

## Cron Setup

```bash
# Switch from AJAX to cron (required for production)
sudo -u www-data php occ background:cron

# Add system cron job
echo "*/5 * * * * www-data php -f /var/www/nextcloud/cron.php" | sudo tee /etc/cron.d/nextcloud

# For Docker, use the cron container (see docker-compose above)
# Or:
docker exec -u www-data nextcloud-app php cron.php
```

## Upgrade Process

```bash
# 1. Enable maintenance mode
occ maintenance:mode --on

# 2. Backup database
mysqldump -u nextcloud -p nextcloud > ~/nextcloud-db-backup-$(date +%F).sql

# 3. Backup files
sudo tar czf ~/nextcloud-files-backup-$(date +%F).tar.gz /var/www/nextcloud/

# 4. Download new version
cd /tmp
wget https://download.nextcloud.com/server/releases/nextcloud-29.0.0.tar.bz2
tar -xjf nextcloud-29.0.0.tar.bz2

# 5. Replace files (keep config + data)
sudo rsync -a --delete \
    --exclude config/ \
    --exclude data/ \
    --exclude themes/ \
    --exclude apps/ \
    /tmp/nextcloud/ /var/www/nextcloud/

# 6. Fix permissions
sudo chown -R www-data:www-data /var/www/nextcloud

# 7. Run upgrade
occ upgrade

# 8. Disable maintenance mode
occ maintenance:mode --off

# 9. Update apps
occ app:update --all

# For Docker: just pull new image + docker compose up -d
docker compose pull && docker compose up -d
docker compose exec --user www-data app php occ upgrade
```

## Performance Tuning

### PHP OPcache (`/etc/php/8.3/fpm/conf.d/10-opcache.ini` or similar)

```ini
opcache.enable=1
opcache.memory_consumption=128
opcache.interned_strings_buffer=16
opcache.max_accelerated_files=10000
opcache.revalidate_freq=1
opcache.save_comments=1
```

### APCu cache (`/etc/php/8.3/fpm/conf.d/20-apcu.ini`)

```ini
apc.enabled=1
apc.shm_size=128M
apc.enable_cli=1
```

### Redis caching (add to `config.php`)

```php
'memcache.local' => '\OC\Memcache\APCu',
'memcache.distributed' => '\OC\Memcache\Redis',
'memcache.locking' => '\OC\Memcache\Redis',
'redis' => [
    'host' => '127.0.0.1',
    'port' => 6379,
    'password' => 'redis_password',
    'dbindex' => 0,
    'timeout' => 1.5,
],
```

### PHP-FPM pool tuning (`/etc/php/8.3/fpm/pool.d/www.conf`)

```ini
pm = dynamic
pm.max_children = 120
pm.start_servers = 12
pm.min_spare_servers = 6
pm.max_spare_servers = 18
pm.max_requests = 500
```

### config.php performance entries

```php
'default_phone_region' => 'US',
'filelocking.enabled' => true,
'enable_previews' => true,
'preview_max_x' => 2048,
'preview_max_y' => 2048,
'jpeg_quality' => 60,

// Chunked uploads
'chunk_size' => 10485760,  // 10MB

// Faster file checks
'filesystem_check_changes' => 0,
```

## External Storage

```bash
# Enable the external storage app
occ app:enable files_external

# Add an S3 mount
occ files_external:create /s3-backup amazons3 amazons3::accesskey \
    --config bucket=mybucket \
    --config region=us-east-1 \
    --config key=AKIAIOSFODNN7EXAMPLE \
    --config secret=wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY

# List external mounts
occ files_external:list

# Supported backends: local, sftp, smb, amazons3, swift, dav
```

## LDAP Integration

```bash
occ app:enable user_ldap

# Configure LDAP (can also be done in admin UI)
occ ldap:set-config s01 ldapHost "ldap://10.0.0.5"
occ ldap:set-config s01 ldapPort 389
occ ldap:set-config s01 ldapBase "dc=example,dc=com"
occ ldap:set-config s01 ldapAgentName "cn=admin,dc=example,dc=com"
occ ldap:set-config s01 ldapAgentPassword "admin_password"
occ ldap:set-config s01 ldapLoginFilter "(&(objectClass=inetOrgPerson)(uid=%uid))"
occ ldap:set-config s01 ldapUserFilter "(objectClass=inetOrgPerson)"
occ ldap:set-config s01 ldapUserDisplayName "cn"
occ ldap:set-config s01 ldapEmailAttribute "mail"

# Test connection
occ ldap:test-config s01
occ ldap:show-config s01
```

## Email Configuration (config.php)

```php
'mail_smtpmode' => 'smtp',
'mail_smtpsecure' => 'tls',
'mail_sendmailmode' => 'smtp',
'mail_from_address' => 'cloud',
'mail_domain' => 'example.com',
'mail_smtphost' => 'smtp.example.com',
'mail_smtpport' => 587,
'mail_smtpauth' => true,
'mail_smtpname' => 'cloud@example.com',
'mail_smtppassword' => 'smtp_password',
```

```bash
# Test email
occ notification:test-push admin
```

## Backup & Restore

### Full backup

```bash
#!/bin/bash
# /usr/local/bin/nextcloud-backup.sh
NC_DIR="/var/www/nextcloud"
BACKUP_DIR="/var/backups/nextcloud"
DATE=$(date +%F_%H%M)
mkdir -p "$BACKUP_DIR"

# Enable maintenance mode
sudo -u www-data php "$NC_DIR/occ" maintenance:mode --on

# Backup database
mysqldump -u nextcloud -p'db_password' nextcloud > "$BACKUP_DIR/db_$DATE.sql"

# Backup Nextcloud directory
sudo tar czf "$BACKUP_DIR/nextcloud_$DATE.tar.gz" -C /var/www nextcloud/

# Disable maintenance mode
sudo -u www-data php "$NC_DIR/occ" maintenance:mode --off

# Cleanup old backups (keep 7 days)
find "$BACKUP_DIR" -mtime +7 -delete
```

## Troubleshooting

```bash
# Check Nextcloud status
occ status
occ check

# Scan for warnings
occ maintenance:repair
occ db:add-missing-indices
occ db:convert-filecache-bigint

# Fix file permissions
sudo chown -R www-data:www-data /var/www/nextcloud/
sudo find /var/www/nextcloud/ -type f -exec chmod 0640 {} \;
sudo find /var/www/nextcloud/ -type d -exec chmod 0750 {} \;

# Stuck in maintenance mode
sudo -u www-data php occ maintenance:mode --off
# Or edit config.php: 'maintenance' => false,

# Trusted domains error
occ config:system:set trusted_domains 1 --value="cloud.example.com"

# File scan after manual upload
occ files:scan --all
occ files:scan --path="admin/files"

# Check cron execution
occ background:cron
grep -i cron /var/log/syslog | tail -5

# Clear all caches
occ maintenance:repair
occ files:cleanup
redis-cli -a redis_password FLUSHDB   # Redis cache only

# Check PHP modules
php -m | grep -iE "gd|curl|xml|zip|mbstring|intl|apcu|redis|imagick|opcache"

# Large log file
tail -100 /var/www/nextcloud/data/nextcloud.log
occ log:manage --level 2              # Set to warning (0=debug, 1=info, 2=warn, 3=error)

# Connection refused to database
sudo systemctl status mariadb
mysql -u nextcloud -p -e "SELECT 1;"

# "Internal Server Error" — check PHP and Nextcloud logs
sudo tail -30 /var/log/apache2/nextcloud-error.log
sudo tail -30 /var/www/nextcloud/data/nextcloud.log
```
