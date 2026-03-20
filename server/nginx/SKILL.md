# Nginx — Web Server & Reverse Proxy

> Install, configure, and manage Nginx for static sites, reverse proxying, SSL termination, load balancing, and performance tuning.

## Safety Rules

- Always `nginx -t` before `systemctl reload nginx` — a bad config kills all sites.
- Never expose `/server-status` or stub_status without IP restrictions.
- Back up `/etc/nginx/` before major changes: `tar czf /tmp/nginx-backup-$(date +%F).tar.gz /etc/nginx/`
- Use `reload` not `restart` — reload is zero-downtime.

## Quick Reference

```bash
# Install (Debian/Ubuntu)
sudo apt update && sudo apt install -y nginx

# Install (RHEL/Rocky/Alma)
sudo dnf install -y nginx

# Service management
sudo systemctl enable --now nginx
sudo systemctl reload nginx          # Zero-downtime config reload
sudo systemctl status nginx

# Config validation
sudo nginx -t

# Show compiled modules
nginx -V 2>&1 | tr -- '- ' '\n' | grep _module

# Quick log tail
sudo tail -f /var/log/nginx/access.log
sudo tail -f /var/log/nginx/error.log

# Test a specific config file
sudo nginx -t -c /etc/nginx/nginx.conf

# List active sites
ls -la /etc/nginx/sites-enabled/

# Certbot SSL (install + auto-config)
sudo apt install -y certbot python3-certbot-nginx
sudo certbot --nginx -d example.com -d www.example.com

# Renew all certs (dry run)
sudo certbot renew --dry-run
```

## Installation & Setup

### Install from official repo (latest stable — Debian/Ubuntu)

```bash
sudo apt install -y curl gnupg2 ca-certificates lsb-release
curl -fsSL https://nginx.org/keys/nginx_signing.key | sudo gpg --dearmor -o /usr/share/keyrings/nginx-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/nginx-archive-keyring.gpg] http://nginx.org/packages/ubuntu $(lsb_release -cs) nginx" | sudo tee /etc/nginx/sources.list.d/nginx.list
sudo apt update && sudo apt install -y nginx
```

### Directory structure

```
/etc/nginx/
├── nginx.conf              # Main config
├── sites-available/        # All vhost configs
├── sites-enabled/          # Symlinks to active vhosts
├── conf.d/                 # Additional configs (auto-included)
├── snippets/               # Reusable config fragments
└── mime.types
```

## Virtual Host Configurations

### Static site

```nginx
server {
    listen 80;
    listen [::]:80;
    server_name example.com www.example.com;
    root /var/www/example.com/html;
    index index.html index.htm;

    location / {
        try_files $uri $uri/ =404;
    }

    # Cache static assets
    location ~* \.(css|js|jpg|jpeg|png|gif|ico|svg|woff2?)$ {
        expires 30d;
        add_header Cache-Control "public, immutable";
    }

    access_log /var/log/nginx/example.com.access.log;
    error_log  /var/log/nginx/example.com.error.log;
}
```

### PHP-FPM (WordPress, Laravel, etc.)

```nginx
server {
    listen 80;
    server_name app.example.com;
    root /var/www/app/public;
    index index.php index.html;

    location / {
        try_files $uri $uri/ /index.php?$query_string;
    }

    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/run/php/php8.3-fpm.sock;
        fastcgi_param SCRIPT_FILENAME $realpath_root$fastcgi_script_name;
        include fastcgi_params;
    }

    location ~ /\.ht {
        deny all;
    }
}
```

### Node.js reverse proxy

```nginx
upstream node_app {
    server 127.0.0.1:3000;
    keepalive 64;
}

server {
    listen 80;
    server_name api.example.com;

    location / {
        proxy_pass http://node_app;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header Connection "";
        proxy_read_timeout 90s;
    }
}
```

### WebSocket proxy

```nginx
map $http_upgrade $connection_upgrade {
    default upgrade;
    ''      close;
}

server {
    listen 80;
    server_name ws.example.com;

    location /ws {
        proxy_pass http://127.0.0.1:8080;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection $connection_upgrade;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_read_timeout 3600s;
        proxy_send_timeout 3600s;
    }
}
```

### Load balancing

```nginx
upstream backend {
    least_conn;                          # Or: ip_hash, round-robin (default)
    server 10.0.0.1:8080 weight=3;
    server 10.0.0.2:8080;
    server 10.0.0.3:8080 backup;
    keepalive 32;
}

server {
    listen 80;
    server_name app.example.com;

    location / {
        proxy_pass http://backend;
        proxy_next_upstream error timeout http_502 http_503;
        proxy_connect_timeout 5s;
    }
}
```

## SSL / TLS with Certbot

```bash
# Install certbot
sudo apt install -y certbot python3-certbot-nginx

# Obtain + auto-configure
sudo certbot --nginx -d example.com -d www.example.com

# Obtain cert only (manual config)
sudo certbot certonly --webroot -w /var/www/example.com/html -d example.com

# Auto-renewal (certbot installs a systemd timer by default)
sudo systemctl status certbot.timer
sudo certbot renew --dry-run
```

### SSL hardening snippet (`/etc/nginx/snippets/ssl-params.conf`)

```nginx
ssl_protocols TLSv1.2 TLSv1.3;
ssl_ciphers 'ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384';
ssl_prefer_server_ciphers off;
ssl_session_timeout 1d;
ssl_session_cache shared:SSL:10m;
ssl_session_tickets off;
ssl_stapling on;
ssl_stapling_verify on;
resolver 1.1.1.1 8.8.8.8 valid=300s;
resolver_timeout 5s;
```

## Security Headers

```nginx
# Add to server or http block
add_header X-Frame-Options "SAMEORIGIN" always;
add_header X-Content-Type-Options "nosniff" always;
add_header X-XSS-Protection "1; mode=block" always;
add_header Referrer-Policy "strict-origin-when-cross-origin" always;
add_header Content-Security-Policy "default-src 'self'; script-src 'self'; style-src 'self' 'unsafe-inline'" always;
add_header Strict-Transport-Security "max-age=63072000; includeSubDomains; preload" always;
add_header Permissions-Policy "camera=(), microphone=(), geolocation=()" always;
```

## Rate Limiting

```nginx
# In http block
limit_req_zone $binary_remote_addr zone=api:10m rate=10r/s;
limit_req_zone $binary_remote_addr zone=login:10m rate=1r/s;

# In server/location block
location /api/ {
    limit_req zone=api burst=20 nodelay;
    limit_req_status 429;
    proxy_pass http://backend;
}

location /login {
    limit_req zone=login burst=3;
    limit_req_status 429;
    proxy_pass http://backend;
}
```

## Performance Tuning

### Main context (`/etc/nginx/nginx.conf`)

```nginx
worker_processes auto;                     # Match CPU cores
worker_rlimit_nofile 65535;

events {
    worker_connections 4096;
    multi_accept on;
    use epoll;
}

http {
    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 65;
    keepalive_requests 1000;
    types_hash_max_size 2048;
    client_max_body_size 64m;

    # Gzip
    gzip on;
    gzip_vary on;
    gzip_proxied any;
    gzip_comp_level 4;
    gzip_min_length 256;
    gzip_types text/plain text/css application/json application/javascript text/xml application/xml application/xml+rss text/javascript image/svg+xml;

    # Open file cache
    open_file_cache max=10000 inactive=20s;
    open_file_cache_valid 30s;
    open_file_cache_min_uses 2;
    open_file_cache_errors on;
}
```

## Log Analysis

```bash
# Top 20 IPs by request count
awk '{print $1}' /var/log/nginx/access.log | sort | uniq -c | sort -rn | head -20

# Top 20 requested URLs
awk '{print $7}' /var/log/nginx/access.log | sort | uniq -c | sort -rn | head -20

# HTTP status code breakdown
awk '{print $9}' /var/log/nginx/access.log | sort | uniq -c | sort -rn

# Requests per second (last 1000 lines)
tail -1000 /var/log/nginx/access.log | awk '{print $4}' | cut -d: -f1-3 | uniq -c | sort -rn | head

# 5xx errors
grep ' 5[0-9][0-9] ' /var/log/nginx/access.log | tail -20

# Slow responses (>5s) — requires $request_time in log format
awk '($NF > 5.0)' /var/log/nginx/access.log | tail -20
```

### Custom log format with timing

```nginx
log_format detailed '$remote_addr - $remote_user [$time_local] '
                    '"$request" $status $body_bytes_sent '
                    '"$http_referer" "$http_user_agent" '
                    'rt=$request_time urt=$upstream_response_time';

access_log /var/log/nginx/access.log detailed;
```

## Enable/Disable Sites

```bash
# Enable a site
sudo ln -s /etc/nginx/sites-available/example.com /etc/nginx/sites-enabled/
sudo nginx -t && sudo systemctl reload nginx

# Disable a site
sudo rm /etc/nginx/sites-enabled/example.com
sudo nginx -t && sudo systemctl reload nginx
```

## Troubleshooting

```bash
# Config syntax check
sudo nginx -t

# Check which process owns port 80
sudo ss -tlnp | grep ':80'

# Debug a specific request
curl -I -H "Host: example.com" http://127.0.0.1/

# Check worker process count
ps aux | grep nginx | grep -c worker

# SELinux blocking? (RHEL/Rocky)
sudo setsebool -P httpd_can_network_connect 1

# Permission denied on socket?
ls -la /run/php/php8.3-fpm.sock
# Ensure nginx user (www-data) matches FPM pool listen.owner

# 502 Bad Gateway — upstream is down
sudo systemctl status php8.3-fpm   # or your upstream service
sudo journalctl -u nginx --since "5 min ago"

# 413 Request Entity Too Large
# Increase client_max_body_size in server or http block

# Test with specific Host header
curl -vk -H "Host: example.com" https://127.0.0.1/
```
