# SSL Certificate Lifecycle Management

> Manage TLS from issuance to renewal, emergency replacement, and internal self-signed cert generation.

## Safety Rules

- Renew before expiry windows; do not wait for outage conditions.
- Test certificate and chain from client perspective after every renewal.
- Respect Let's Encrypt rate limits; use staging for repeated testing.
- Keep private keys readable only by service accounts/root.
- Track cert ownership and renewal mechanism per domain.

## Quick Reference

```bash
# Inspect live cert
echo | openssl s_client -connect domain.com:443 -servername domain.com 2>/dev/null \
 | openssl x509 -noout -dates -issuer -subject

# Certbot dry run
sudo certbot renew --dry-run

# Force renew specific cert
sudo certbot renew --cert-name domain.com --force-renewal

# Nginx config test + reload
sudo nginx -t && sudo systemctl reload nginx
```

## SSL Debugging

### Check chain, protocol, and expiry

```bash
echo | openssl s_client -connect domain.com:443 -servername domain.com -showcerts
echo | openssl s_client -connect domain.com:443 -servername domain.com 2>/dev/null \
  | openssl x509 -noout -dates -serial -fingerprint -sha256
```

### Verify trust chain locally

```bash
openssl verify -CAfile /etc/ssl/certs/ca-certificates.crt /etc/letsencrypt/live/domain.com/fullchain.pem
```

## Certbot Renewal Operations

```bash
sudo certbot certificates
sudo certbot renew --dry-run
sudo certbot renew
```

## Forced Renewal and Revocation Handling

```bash
# Renew specific cert immediately
sudo certbot renew --cert-name domain.com --force-renewal

# If cert is compromised, revoke then reissue
sudo certbot revoke --cert-path /etc/letsencrypt/live/domain.com/cert.pem
sudo certbot certonly --nginx -d domain.com -d www.domain.com
```

Rate-limit hygiene:
- Use staging endpoint in tests.
- Avoid repeated failed issuance loops.

## Self-Signed Certificates (Internal Traffic)

### Generate key + cert

```bash
sudo mkdir -p /etc/ssl/internal
sudo openssl req -x509 -nodes -newkey rsa:4096 -days 825 \
  -keyout /etc/ssl/internal/internal.key \
  -out /etc/ssl/internal/internal.crt \
  -subj "/C=US/ST=NA/L=NA/O=Internal/CN=internal.service.local"
sudo chmod 600 /etc/ssl/internal/internal.key
sudo chmod 644 /etc/ssl/internal/internal.crt
```

### Optional SAN config

```bash
cat <<'EOF' | sudo tee /tmp/internal-san.cnf
[ req ]
default_bits       = 4096
distinguished_name = req_distinguished_name
x509_extensions    = v3_req
prompt             = no

[ req_distinguished_name ]
CN = internal.service.local

[ v3_req ]
subjectAltName = @alt_names

[ alt_names ]
DNS.1 = internal.service.local
DNS.2 = api.internal.service.local
EOF
```

## Renewal Hooks

```bash
# Deploy hook example to reload web server after successful renewal
sudo certbot renew --deploy-hook "systemctl reload nginx"
```

## Troubleshooting

- Browser still shows old cert: verify load balancer/cdn cache and SNI host mapping.
- `unable to get local issuer certificate`: chain file misconfigured; use `fullchain.pem`.
- Renewal fails HTTP-01: confirm `.well-known/acme-challenge` reachability.
- TLS handshake timeout: check firewall and listener binding on port 443.
