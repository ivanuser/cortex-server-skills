# Certbot — Let's Encrypt TLS Certificates

> Install, configure, and manage Certbot for automatic TLS certificate provisioning via Let's Encrypt. Covers nginx/Apache integration, wildcard certificates, auto-renewal, hooks, and DNS challenges.

## Safety Rules

- **Let's Encrypt has rate limits** — 50 certificates per registered domain per week.
- Use `--staging` for testing to avoid hitting rate limits.
- Don't run certbot on multiple servers for the same domain without coordination.
- Wildcard certificates require DNS-01 challenge — not HTTP-01.
- Auto-renewal runs as root — ensure hooks are secure.
- Certificate private keys are sensitive — restrict file permissions.

## Quick Reference

```bash
# Install (Ubuntu/Debian — snap, recommended)
sudo snap install --classic certbot
sudo ln -sf /snap/bin/certbot /usr/bin/certbot

# Install (pip — alternative)
pip3 install certbot certbot-nginx certbot-dns-cloudflare

# Install (apt — may be outdated)
sudo apt install -y certbot python3-certbot-nginx

# Version check
certbot --version

# Get certificate (interactive)
sudo certbot certonly --nginx
sudo certbot certonly --apache

# Test with staging (always test first!)
sudo certbot certonly --nginx --staging -d example.com

# Check certificates
sudo certbot certificates

# Renew all certificates
sudo certbot renew

# Dry run renewal (test)
sudo certbot renew --dry-run
```

## Nginx Integration

### Automatic Configuration

```bash
# Certbot configures nginx automatically
sudo certbot --nginx -d example.com -d www.example.com

# Non-interactive (for scripting)
sudo certbot --nginx \
  -d example.com \
  -d www.example.com \
  --non-interactive \
  --agree-tos \
  --email admin@example.com \
  --redirect
```

### Manual Integration (certonly)

```bash
# Get cert without modifying nginx config
sudo certbot certonly --nginx -d example.com -d www.example.com

# Or use standalone (stops nginx temporarily)
sudo certbot certonly --standalone -d example.com --pre-hook "systemctl stop nginx" --post-hook "systemctl start nginx"

# Or use webroot (nginx keeps running)
sudo certbot certonly --webroot -w /var/www/html -d example.com
```

### Nginx Config (manual setup)

```nginx
server {
    listen 443 ssl http2;
    server_name example.com;

    ssl_certificate /etc/letsencrypt/live/example.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/example.com/privkey.pem;
    ssl_trusted_certificate /etc/letsencrypt/live/example.com/chain.pem;

    # SSL settings
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384;
    ssl_prefer_server_ciphers off;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 1d;
    ssl_stapling on;
    ssl_stapling_verify on;

    # HSTS
    add_header Strict-Transport-Security "max-age=63072000; includeSubDomains" always;

    root /var/www/example;
    index index.html;
}

server {
    listen 80;
    server_name example.com;
    return 301 https://$server_name$request_uri;
}
```

## Apache Integration

```bash
# Automatic configuration
sudo certbot --apache -d example.com -d www.example.com

# Certonly mode
sudo certbot certonly --apache -d example.com

# Non-interactive
sudo certbot --apache \
  -d example.com \
  --non-interactive \
  --agree-tos \
  --email admin@example.com
```

### Apache Config (manual setup)

```apache
<VirtualHost *:443>
    ServerName example.com
    DocumentRoot /var/www/example

    SSLEngine on
    SSLCertificateFile /etc/letsencrypt/live/example.com/fullchain.pem
    SSLCertificateKeyFile /etc/letsencrypt/live/example.com/privkey.pem

    Header always set Strict-Transport-Security "max-age=63072000"
</VirtualHost>

<VirtualHost *:80>
    ServerName example.com
    Redirect permanent / https://example.com/
</VirtualHost>
```

## Wildcard Certificates (DNS-01 Challenge)

### Cloudflare DNS Plugin

```bash
# Install Cloudflare plugin
sudo snap set certbot trust-plugin-with-root=ok
sudo snap install certbot-dns-cloudflare

# Or via pip
pip3 install certbot-dns-cloudflare

# Create credentials file
sudo mkdir -p /etc/letsencrypt
cat <<'EOF' | sudo tee /etc/letsencrypt/cloudflare.ini
dns_cloudflare_api_token = your-cloudflare-api-token-here
EOF
sudo chmod 600 /etc/letsencrypt/cloudflare.ini

# Get wildcard certificate
sudo certbot certonly \
  --dns-cloudflare \
  --dns-cloudflare-credentials /etc/letsencrypt/cloudflare.ini \
  --dns-cloudflare-propagation-seconds 30 \
  -d "example.com" \
  -d "*.example.com"
```

### Route53 DNS Plugin

```bash
sudo snap install certbot-dns-route53

# Requires AWS credentials (IAM user with Route53 access)
sudo certbot certonly \
  --dns-route53 \
  -d "example.com" \
  -d "*.example.com"
```

### Manual DNS Challenge

```bash
# Manual (interactive — you add TXT record yourself)
sudo certbot certonly \
  --manual \
  --preferred-challenges dns \
  -d "example.com" \
  -d "*.example.com"

# Certbot will say:
# "Please deploy a DNS TXT record under _acme-challenge.example.com with value: <hash>"
# Add the TXT record, wait for propagation, then press Enter

# Verify TXT record propagation
dig -t TXT _acme-challenge.example.com +short
```

## Auto-Renewal

```bash
# Certbot sets up auto-renewal automatically via:
# - snap timer (snap install)
# - systemd timer (apt install)
# - cron job

# Check timer
sudo systemctl list-timers | grep certbot
# Or: sudo snap timer certbot

# Manual cron (if needed)
echo "0 0,12 * * * root certbot renew --quiet" | sudo tee /etc/cron.d/certbot

# Test renewal
sudo certbot renew --dry-run

# Force renewal (even if not expiring)
sudo certbot renew --force-renewal --cert-name example.com
```

## Hooks — Pre/Post/Deploy

```bash
# Hooks run during renewal

# Reload nginx after renewal
sudo certbot renew \
  --deploy-hook "systemctl reload nginx"

# Set hook permanently in renewal config
sudo cat /etc/letsencrypt/renewal/example.com.conf
# Add under [renewalparams]:
# renew_hook = systemctl reload nginx

# Or create hook scripts
sudo mkdir -p /etc/letsencrypt/renewal-hooks/{pre,post,deploy}

# Pre-hook: runs before renewal attempt
cat <<'EOF' | sudo tee /etc/letsencrypt/renewal-hooks/pre/stop-haproxy.sh
#!/bin/bash
# Only needed for standalone mode
systemctl stop haproxy
EOF

# Post-hook: runs after renewal attempt (success or failure)
cat <<'EOF' | sudo tee /etc/letsencrypt/renewal-hooks/post/start-haproxy.sh
#!/bin/bash
systemctl start haproxy
EOF

# Deploy-hook: runs ONLY after successful renewal
cat <<'EOF' | sudo tee /etc/letsencrypt/renewal-hooks/deploy/reload-services.sh
#!/bin/bash
systemctl reload nginx
# Combine cert+key for HAProxy
cat /etc/letsencrypt/live/example.com/fullchain.pem \
    /etc/letsencrypt/live/example.com/privkey.pem \
    > /etc/haproxy/certs/example.com.pem
systemctl reload haproxy
EOF

sudo chmod +x /etc/letsencrypt/renewal-hooks/deploy/reload-services.sh
```

## Certificate Management

```bash
# List all certificates
sudo certbot certificates

# Certificate files (symlinks to latest version)
ls -la /etc/letsencrypt/live/example.com/
# cert.pem       — server certificate
# chain.pem      — intermediate certificate(s)
# fullchain.pem  — cert.pem + chain.pem (use this for most servers)
# privkey.pem    — private key

# Delete certificate
sudo certbot delete --cert-name example.com

# Revoke certificate
sudo certbot revoke --cert-path /etc/letsencrypt/live/example.com/cert.pem

# Expand certificate (add domains)
sudo certbot certonly --expand -d example.com -d www.example.com -d api.example.com

# Update email
sudo certbot update_account --email newemail@example.com
```

## Staging / Testing

```bash
# Always test with staging first!
sudo certbot certonly --nginx --staging -d test.example.com

# Staging issues fake certs (not trusted by browsers)
# but doesn't count against rate limits

# Check staging cert
openssl x509 -in /etc/letsencrypt/live/test.example.com/cert.pem -text -noout | grep Issuer
# Should show: (STAGING) Artificial Apricot R3

# Clean up staging cert
sudo certbot delete --cert-name test.example.com

# Then get real cert
sudo certbot certonly --nginx -d test.example.com
```

## Troubleshooting

```bash
# Certificate not renewing
sudo certbot renew --dry-run -v
sudo cat /var/log/letsencrypt/letsencrypt.log | tail -100

# HTTP-01 challenge failing
# Verify .well-known/acme-challenge is accessible:
curl -I http://example.com/.well-known/acme-challenge/test
# Nginx: ensure port 80 is open and location /.well-known is not blocked

# DNS-01 challenge failing
dig -t TXT _acme-challenge.example.com +short
# Wait for propagation (increase --dns-*-propagation-seconds)

# Rate limit hit
# Wait or use different subdomain / registered domain
# Use staging for testing: --staging

# Permission issues
sudo ls -la /etc/letsencrypt/live/
sudo ls -la /etc/letsencrypt/archive/
# Directories should be owned by root with 0755 (live) and 0700 (archive)

# Certificate expired
sudo certbot renew --force-renewal --cert-name example.com
sudo systemctl reload nginx

# Port 80 already in use (standalone mode)
sudo ss -tlnp | grep :80
# Use webroot or nginx plugin instead of standalone

# Cert exists but nginx/apache can't read it
# Check nginx user can traverse /etc/letsencrypt/live/
sudo chmod 0755 /etc/letsencrypt/{live,archive}

# Check certificate expiry
echo | openssl s_client -servername example.com -connect example.com:443 2>/dev/null | \
  openssl x509 -noout -dates
```
