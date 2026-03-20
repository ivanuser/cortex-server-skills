# Caddy — Modern Web Server with Automatic HTTPS

> Install, configure, and manage Caddy for web serving, reverse proxying, and automatic TLS. Covers Caddyfile syntax, auto-HTTPS, reverse proxy, file server, load balancing, and API configuration.

## Safety Rules

- Caddy automatically obtains TLS certificates — ensure DNS points to your server before enabling.
- Don't run Caddy and nginx/Apache on the same ports (80/443) simultaneously.
- Test config before reloading: `caddy validate --config /etc/caddy/Caddyfile`.
- The admin API (localhost:2019) can modify running config — restrict access.
- Rate limits apply to Let's Encrypt — don't restart frequently with new domains.

## Quick Reference

```bash
# Install (Debian/Ubuntu)
sudo apt install -y debian-keyring debian-archive-keyring apt-transport-https
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | \
  sudo gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | \
  sudo tee /etc/apt/sources.list.d/caddy-stable.list
sudo apt update && sudo apt install -y caddy

# Install (RHEL/Rocky)
sudo dnf install -y 'dnf-command(copr)'
sudo dnf copr enable @caddy/caddy -y
sudo dnf install -y caddy

# Install (binary — any Linux)
curl -o /usr/local/bin/caddy -L "https://caddyserver.com/api/download?os=linux&arch=amd64"
chmod +x /usr/local/bin/caddy
sudo setcap cap_net_bind_service=+ep /usr/local/bin/caddy

# Service management
sudo systemctl enable --now caddy
sudo systemctl status caddy
sudo systemctl reload caddy            # Graceful reload (preferred)
sudo systemctl restart caddy

# Validate config
caddy validate --config /etc/caddy/Caddyfile

# Format Caddyfile (in-place)
caddy fmt --overwrite /etc/caddy/Caddyfile

# Reload config without restart
caddy reload --config /etc/caddy/Caddyfile

# Run in foreground (dev)
caddy run --config /etc/caddy/Caddyfile
```

## Caddyfile Basics

Config file location: `/etc/caddy/Caddyfile`

### Simple File Server

```
# Serve static files from /var/www/html
:80 {
    root * /var/www/html
    file_server
}

# With directory listing
:8080 {
    root * /srv/files
    file_server browse
}
```

### Automatic HTTPS (the magic)

```
# Just use a domain name — Caddy auto-provisions TLS via Let's Encrypt
example.com {
    root * /var/www/example
    file_server
}

# Multiple domains on same site
example.com, www.example.com {
    root * /var/www/example
    file_server
}
```

### Reverse Proxy

```
# Simple reverse proxy
app.example.com {
    reverse_proxy localhost:3000
}

# With health checks
api.example.com {
    reverse_proxy localhost:8080 {
        health_uri /health
        health_interval 30s
        health_timeout 5s
        health_status 200
    }
}

# WebSocket support (automatic — no extra config needed)
ws.example.com {
    reverse_proxy localhost:8080
}

# Strip path prefix
example.com {
    handle_path /api/* {
        reverse_proxy localhost:8080
    }
    handle {
        root * /var/www/frontend
        file_server
    }
}

# Load balancing
app.example.com {
    reverse_proxy localhost:3001 localhost:3002 localhost:3003 {
        lb_policy round_robin          # or least_conn, random, first, ip_hash
        health_uri /health
        health_interval 10s
        fail_duration 30s
    }
}
```

### Headers & Security

```
example.com {
    header {
        Strict-Transport-Security "max-age=31536000; includeSubDomains"
        X-Content-Type-Options "nosniff"
        X-Frame-Options "DENY"
        -Server                        # Remove Server header
    }
    root * /var/www/example
    file_server
}
```

### Logging

```
example.com {
    log {
        output file /var/log/caddy/access.log {
            roll_size 100mb
            roll_keep 5
            roll_keep_for 720h
        }
        format json
        level INFO
    }
    reverse_proxy localhost:3000
}
```

## Common Patterns

### SPA (Single Page Application)

```
app.example.com {
    root * /var/www/app
    try_files {path} /index.html
    file_server
    encode gzip zstd
}
```

### PHP (with php-fpm)

```
site.example.com {
    root * /var/www/site
    php_fastcgi unix//run/php/php8.2-fpm.sock
    file_server
}
```

### Redirect HTTP to HTTPS + www to non-www

```
www.example.com {
    redir https://example.com{uri} permanent
}

example.com {
    root * /var/www/example
    file_server
}
```

### Basic Authentication

```
admin.example.com {
    basicauth {
        admin $2a$14$hashhere          # Generate: caddy hash-password
    }
    reverse_proxy localhost:8080
}
```

```bash
# Generate password hash
caddy hash-password
# Enter password interactively, get bcrypt hash
```

### Rate Limiting (with caddy-ratelimit plugin)

```
example.com {
    rate_limit {
        zone dynamic {
            key {remote_host}
            events 100
            window 1m
        }
    }
    reverse_proxy localhost:3000
}
```

### Wildcard Certificates (DNS challenge)

```
*.example.com {
    tls {
        dns cloudflare {env.CF_API_TOKEN}
    }

    @app host app.example.com
    handle @app {
        reverse_proxy localhost:3000
    }

    @api host api.example.com
    handle @api {
        reverse_proxy localhost:8080
    }

    handle {
        respond "Not found" 404
    }
}
```

## TLS Configuration

```
# Custom TLS settings
example.com {
    tls admin@example.com {
        protocols tls1.2 tls1.3
        curves x25519 secp256r1
    }
    reverse_proxy localhost:3000
}

# Self-signed cert (dev/internal)
localhost:8443 {
    tls internal
    reverse_proxy localhost:3000
}

# Custom certificate files
example.com {
    tls /path/to/cert.pem /path/to/key.pem
    reverse_proxy localhost:3000
}
```

## Admin API

```bash
# Caddy exposes a JSON API on localhost:2019

# Get current config
curl -s http://localhost:2019/config/ | jq .

# Update config via API
curl -X POST "http://localhost:2019/load" \
  -H "Content-Type: application/json" \
  -d @caddy.json

# Add route dynamically
curl -X POST "http://localhost:2019/config/apps/http/servers/srv0/routes" \
  -H "Content-Type: application/json" \
  -d '{"match": [{"host": ["new.example.com"]}], "handle": [{"handler": "reverse_proxy", "upstreams": [{"dial": "localhost:4000"}]}]}'

# Stop Caddy via API
curl -X POST http://localhost:2019/stop

# Disable admin API (in Caddyfile global options)
# {
#     admin off
# }
```

## Global Options

```
{
    # Email for ACME/Let's Encrypt
    email admin@example.com

    # Use staging CA for testing (avoids rate limits)
    # acme_ca https://acme-staging-v02.api.letsencrypt.org/directory

    # Disable admin API
    # admin off

    # Custom log
    log {
        output file /var/log/caddy/caddy.log
        level WARN
    }

    # Default SNI
    default_sni example.com
}

example.com {
    reverse_proxy localhost:3000
}
```

## Environment Variables

```bash
# Use env vars in Caddyfile
# {$ENV_NAME} or {$ENV_NAME:default}

# Example:
# api.example.com {
#     reverse_proxy localhost:{$APP_PORT:3000}
# }

# Set via systemd override
sudo systemctl edit caddy
# [Service]
# Environment="APP_PORT=3000"
# Environment="CF_API_TOKEN=your-token"
```

## Troubleshooting

```bash
# Check if Caddy is running
sudo systemctl status caddy
curl -s http://localhost:2019/config/ | jq .version

# Config syntax error
caddy validate --config /etc/caddy/Caddyfile
caddy fmt /etc/caddy/Caddyfile         # Often reveals issues

# Port already in use
sudo ss -tlnp | grep -E ':80|:443'
# Stop conflicting server (nginx, apache)

# TLS certificate issues
# Check Caddy logs
sudo journalctl -u caddy --no-pager -n 50

# Certificate storage location
ls ~/.local/share/caddy/                # User mode
ls /var/lib/caddy/.local/share/caddy/   # Systemd service

# DNS not resolving (ACME challenge fails)
dig +short example.com
# Must point to this server's public IP

# Permission denied on low ports
sudo setcap cap_net_bind_service=+ep $(which caddy)

# Logs
sudo journalctl -u caddy -f            # Follow logs
```
