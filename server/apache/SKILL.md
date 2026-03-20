# Apache HTTP Server

> Install, configure, and manage Apache for virtual hosting, PHP apps, WordPress, SSL, reverse proxying, and .htaccess rules.

## Safety Rules

- Always `apachectl configtest` (or `apache2ctl configtest`) before restarting.
- Back up config before changes: `tar czf /tmp/apache-backup-$(date +%F).tar.gz /etc/apache2/`
- Use `graceful` restart when possible — keeps existing connections alive.
- Never allow `AllowOverride All` on root (`/`) — only on specific document roots.
- Disable `ServerTokens` and `ServerSignature` in production.

## Quick Reference

```bash
# Install (Debian/Ubuntu)
sudo apt update && sudo apt install -y apache2

# Install (RHEL/Rocky/Alma) — called httpd
sudo dnf install -y httpd

# Service management
sudo systemctl enable --now apache2
sudo systemctl reload apache2
sudo systemctl status apache2
sudo apachectl graceful              # Graceful restart

# Config validation
sudo apachectl configtest

# List enabled modules
apache2ctl -M

# Enable/disable modules
sudo a2enmod rewrite ssl proxy proxy_http headers
sudo a2dismod autoindex

# Enable/disable sites
sudo a2ensite example.com.conf
sudo a2dissite 000-default.conf

# SSL with certbot
sudo apt install -y certbot python3-certbot-apache
sudo certbot --apache -d example.com -d www.example.com

# Log tail
sudo tail -f /var/log/apache2/error.log
sudo tail -f /var/log/apache2/access.log
```

## Directory Structure (Debian/Ubuntu)

```
/etc/apache2/
├── apache2.conf           # Main config
├── envvars                # Environment variables
├── ports.conf             # Listen ports
├── sites-available/       # All vhost configs
├── sites-enabled/         # Symlinks to active vhosts
├── mods-available/        # All module configs
├── mods-enabled/          # Symlinks to active modules
└── conf-available/        # Additional config fragments
```

## Essential Modules

```bash
# Common set for most deployments
sudo a2enmod rewrite ssl headers expires deflate proxy proxy_http proxy_wstunnel
sudo systemctl restart apache2

# PHP (with PHP-FPM — preferred over mod_php)
sudo apt install -y php8.3-fpm
sudo a2enmod proxy_fcgi setenvif
sudo a2enconf php8.3-fpm
sudo systemctl restart apache2
```

## Virtual Host Configurations

### Static site

```apache
# /etc/apache2/sites-available/example.com.conf
<VirtualHost *:80>
    ServerName example.com
    ServerAlias www.example.com
    DocumentRoot /var/www/example.com/html
    ServerAdmin admin@example.com

    <Directory /var/www/example.com/html>
        Options -Indexes +FollowSymLinks
        AllowOverride None
        Require all granted
    </Directory>

    ErrorLog ${APACHE_LOG_DIR}/example.com-error.log
    CustomLog ${APACHE_LOG_DIR}/example.com-access.log combined
</VirtualHost>
```

### PHP application (with PHP-FPM)

```apache
<VirtualHost *:80>
    ServerName app.example.com
    DocumentRoot /var/www/app/public

    <Directory /var/www/app/public>
        Options -Indexes +FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>

    <FilesMatch \.php$>
        SetHandler "proxy:unix:/run/php/php8.3-fpm.sock|fcgi://localhost"
    </FilesMatch>

    ErrorLog ${APACHE_LOG_DIR}/app-error.log
    CustomLog ${APACHE_LOG_DIR}/app-access.log combined
</VirtualHost>
```

### WordPress

```apache
<VirtualHost *:80>
    ServerName wp.example.com
    DocumentRoot /var/www/wordpress

    <Directory /var/www/wordpress>
        Options -Indexes +FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>

    <FilesMatch \.php$>
        SetHandler "proxy:unix:/run/php/php8.3-fpm.sock|fcgi://localhost"
    </FilesMatch>

    # Block xmlrpc attacks
    <Files xmlrpc.php>
        Require all denied
    </Files>

    # Block wp-config access
    <Files wp-config.php>
        Require all denied
    </Files>

    ErrorLog ${APACHE_LOG_DIR}/wordpress-error.log
    CustomLog ${APACHE_LOG_DIR}/wordpress-access.log combined
</VirtualHost>
```

### Reverse proxy

```apache
<VirtualHost *:80>
    ServerName api.example.com

    ProxyPreserveHost On
    ProxyPass / http://127.0.0.1:3000/
    ProxyPassReverse / http://127.0.0.1:3000/

    RequestHeader set X-Forwarded-Proto "http"
    RequestHeader set X-Real-IP "%{REMOTE_ADDR}e"

    ErrorLog ${APACHE_LOG_DIR}/api-proxy-error.log
    CustomLog ${APACHE_LOG_DIR}/api-proxy-access.log combined
</VirtualHost>
```

### WebSocket proxy

```apache
<VirtualHost *:80>
    ServerName ws.example.com

    RewriteEngine On
    RewriteCond %{HTTP:Upgrade} websocket [NC]
    RewriteCond %{HTTP:Connection} upgrade [NC]
    RewriteRule ^/?(.*) "ws://127.0.0.1:8080/$1" [P,L]

    ProxyPass / http://127.0.0.1:8080/
    ProxyPassReverse / http://127.0.0.1:8080/
</VirtualHost>
```

## SSL / TLS with Certbot

```bash
# Install
sudo apt install -y certbot python3-certbot-apache

# Obtain + auto-configure
sudo certbot --apache -d example.com -d www.example.com

# Certificate only (no Apache config changes)
sudo certbot certonly --webroot -w /var/www/example.com/html -d example.com

# Check renewal timer
sudo systemctl status certbot.timer
sudo certbot renew --dry-run
```

### Manual SSL vhost

```apache
<VirtualHost *:443>
    ServerName example.com
    DocumentRoot /var/www/example.com/html

    SSLEngine on
    SSLCertificateFile /etc/letsencrypt/live/example.com/fullchain.pem
    SSLCertificateKeyFile /etc/letsencrypt/live/example.com/privkey.pem

    # Modern SSL config
    SSLProtocol all -SSLv3 -TLSv1 -TLSv1.1
    SSLHonorCipherOrder off
    SSLSessionTickets off

    Header always set Strict-Transport-Security "max-age=63072000; includeSubDomains; preload"
</VirtualHost>

# HTTP → HTTPS redirect
<VirtualHost *:80>
    ServerName example.com
    Redirect permanent / https://example.com/
</VirtualHost>
```

## mod_rewrite & .htaccess

### Common .htaccess rules

```apache
# Force HTTPS
RewriteEngine On
RewriteCond %{HTTPS} off
RewriteRule ^(.*)$ https://%{HTTP_HOST}%{REQUEST_URI} [L,R=301]

# Remove trailing slash
RewriteCond %{REQUEST_FILENAME} !-d
RewriteRule ^(.*)/$ /$1 [L,R=301]

# Pretty URLs (Laravel/WordPress style)
RewriteEngine On
RewriteCond %{REQUEST_FILENAME} !-f
RewriteCond %{REQUEST_FILENAME} !-d
RewriteRule ^(.*)$ index.php/$1 [L]

# Block specific user agents
RewriteCond %{HTTP_USER_AGENT} (bot|crawler|spider) [NC]
RewriteRule .* - [F,L]

# Custom error pages
ErrorDocument 404 /errors/404.html
ErrorDocument 500 /errors/500.html

# Directory listing off
Options -Indexes

# Block .env and hidden files
<FilesMatch "^\.">
    Require all denied
</FilesMatch>
```

## Security Hardening

```apache
# /etc/apache2/conf-available/security.conf

# Hide Apache version
ServerTokens Prod
ServerSignature Off

# Prevent clickjacking
Header always set X-Frame-Options "SAMEORIGIN"
Header always set X-Content-Type-Options "nosniff"
Header always set X-XSS-Protection "1; mode=block"
Header always set Referrer-Policy "strict-origin-when-cross-origin"

# Disable TRACE method
TraceEnable Off

# Limit request body size (10MB)
LimitRequestBody 10485760
```

```bash
sudo a2enconf security
sudo systemctl reload apache2
```

## MPM Tuning

### Check current MPM

```bash
apachectl -V | grep MPM
# Or
apache2ctl -M | grep mpm
```

### Event MPM (recommended for most workloads)

```apache
# /etc/apache2/mods-available/mpm_event.conf
<IfModule mpm_event_module>
    StartServers             2
    MinSpareThreads         25
    MaxSpareThreads         75
    ThreadLimit             64
    ThreadsPerChild         25
    MaxRequestWorkers      150
    MaxConnectionsPerChild 10000
</IfModule>
```

```bash
# Switch to event MPM
sudo a2dismod mpm_prefork
sudo a2enmod mpm_event
sudo systemctl restart apache2
```

## Log Rotation

Apache uses logrotate by default (`/etc/logrotate.d/apache2`):

```
/var/log/apache2/*.log {
    daily
    missingok
    rotate 14
    compress
    delaycompress
    notifempty
    create 640 root adm
    sharedscripts
    postrotate
        if invoke-rc.d apache2 status > /dev/null 2>&1; then
            invoke-rc.d apache2 reload > /dev/null
        fi
    endscript
}
```

### Custom log format

```apache
LogFormat "%h %l %u %t \"%r\" %>s %b \"%{Referer}i\" \"%{User-Agent}i\" %D" detailed
CustomLog ${APACHE_LOG_DIR}/access.log detailed
```

`%D` = request time in microseconds.

## Log Analysis

```bash
# Top 20 IPs
awk '{print $1}' /var/log/apache2/access.log | sort | uniq -c | sort -rn | head -20

# Status code breakdown
awk '{print $9}' /var/log/apache2/access.log | sort | uniq -c | sort -rn

# Largest responses
awk '{print $10, $7}' /var/log/apache2/access.log | sort -rn | head -20

# 404 errors
awk '$9 == 404 {print $7}' /var/log/apache2/access.log | sort | uniq -c | sort -rn | head -20
```

## Troubleshooting

```bash
# Config syntax check
sudo apachectl configtest

# Check what's listening on port 80/443
sudo ss -tlnp | grep -E ':80|:443'

# Check loaded modules
apache2ctl -M 2>/dev/null | sort

# Debug virtual host resolution
apache2ctl -S

# SELinux (RHEL) — allow network connect for proxy
sudo setsebool -P httpd_can_network_connect 1

# Permission issues — check ownership
ls -la /var/www/example.com/
sudo chown -R www-data:www-data /var/www/example.com/

# AH01630: client denied by server configuration
# → Check <Directory> Require directives — likely missing "Require all granted"

# AH00124: Request exceeded the limit of 10 internal redirects
# → Infinite RewriteRule loop in .htaccess — add RewriteCond to exclude target

# Module not found
sudo apt list --installed 2>/dev/null | grep libapache2-mod

# Check error log for startup failures
sudo journalctl -u apache2 --since "5 min ago"
sudo tail -30 /var/log/apache2/error.log
```
