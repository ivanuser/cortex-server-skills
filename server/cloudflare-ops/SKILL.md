# cloudflare-ops — Cloudflare Tunnel Operations

Manage Cloudflare Tunnels, DNS routing, and service exposure after cloudflared is installed.

## Tunnel Management

### List Tunnels
```bash
# Via CLI (requires login)
cloudflared tunnel list

# Check running tunnel info
cloudflared tunnel info
```

### Create a New Tunnel
```bash
# Create tunnel
cloudflared tunnel create my-tunnel

# Output: Created tunnel my-tunnel with id <UUID>
# Credentials file: ~/.cloudflared/<UUID>.json
```

### Delete a Tunnel
```bash
# Must stop the tunnel first
cloudflared tunnel delete my-tunnel

# Force delete (even if connections exist)
cloudflared tunnel delete -f my-tunnel
```

## Route DNS to Tunnel

```bash
# Route a subdomain through the tunnel
cloudflared tunnel route dns my-tunnel myapp.example.com

# This creates a CNAME: myapp.example.com → <UUID>.cfargotunnel.com
```

## Config File Setup

### Single Service
```yaml
# /etc/cloudflared/config.yml
tunnel: <TUNNEL_UUID>
credentials-file: /root/.cloudflared/<TUNNEL_UUID>.json

ingress:
  - hostname: myapp.example.com
    service: http://localhost:8080
  - service: http_status:404
```

### Multiple Services (one tunnel)
```yaml
# /etc/cloudflared/config.yml
tunnel: <TUNNEL_UUID>
credentials-file: /root/.cloudflared/<TUNNEL_UUID>.json

ingress:
  # Web app
  - hostname: app.example.com
    service: http://localhost:3000
  
  # API
  - hostname: api.example.com
    service: http://localhost:8080
  
  # SSH (browser-based)
  - hostname: ssh.example.com
    service: ssh://localhost:22
  
  # Dashboard
  - hostname: dashboard.example.com
    service: http://localhost:18789
  
  # Catch-all (required — must be last)
  - service: http_status:404
```

### With Origin Certificates (internal HTTPS)
```yaml
ingress:
  - hostname: secure.example.com
    service: https://localhost:8443
    originRequest:
      noTLSVerify: true  # Skip cert validation for self-signed
```

### WebSocket Support
```yaml
ingress:
  - hostname: ws.example.com
    service: http://localhost:18789
    originRequest:
      connectTimeout: 30s
      noHappyEyeballs: true  # Recommended for WebSocket
```

## Expose CortexOS Server

```yaml
# Expose the CortexOS gateway + dashboard
ingress:
  - hostname: cortexos.example.com
    service: http://localhost:18789
    originRequest:
      connectTimeout: 30s
  - service: http_status:404
```

Then add the hostname to gateway config:
```bash
# Add to allowedOrigins
openclaw config set gateway.controlUi.allowedOrigins '["http://localhost:18789","https://cortexos.example.com"]'
```

## Quick Tunnel (Temporary)

```bash
# Instant public URL — no config needed, expires when stopped
cloudflared tunnel --url http://localhost:8080

# Output: https://random-name.trycloudflare.com
# Great for testing/demos
```

## Service Operations

```bash
# Start/stop/restart
sudo systemctl start cloudflared
sudo systemctl stop cloudflared
sudo systemctl restart cloudflared

# Enable on boot
sudo systemctl enable cloudflared

# Check status
sudo systemctl status cloudflared

# View logs
sudo journalctl -u cloudflared -f
sudo journalctl -u cloudflared --since "1 hour ago"

# Check metrics
curl -s http://localhost:60123/metrics 2>/dev/null | grep cloudflared_tunnel
```

## Access Control (Zero Trust)

Configure in Cloudflare Zero Trust dashboard (one.dash.cloudflare.com):

### Application Policies
1. Access → Applications → Add an application
2. Choose "Self-hosted"
3. Set domain (e.g., dashboard.example.com)
4. Add policies:
   - Allow: specific emails, email domains, IP ranges
   - Require: one-time pin, identity provider

### SSH Browser Rendering
```yaml
# In config.yml — enables browser-based SSH
ingress:
  - hostname: ssh.example.com
    service: ssh://localhost:22
```
Then in Zero Trust: Access → Applications → add SSH app with browser rendering enabled.

## Update cloudflared

```bash
# Debian/Ubuntu
sudo apt-get update && sudo apt-get upgrade cloudflared

# Binary install
curl -L https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64 -o /usr/local/bin/cloudflared

# Restart after update
sudo systemctl restart cloudflared
```

## Monitoring

```bash
# Check tunnel health from Cloudflare's perspective
# Go to: one.dash.cloudflare.com → Networks → Tunnels
# Shows: status (healthy/degraded/down), connections, origin IPs

# Local metrics
cloudflared tunnel info

# Connection count
ss -tunap | grep cloudflared | wc -l
```

## Troubleshooting

- **502 Bad Gateway** — origin service is down. Check: `curl -v http://localhost:<port>`
- **Tunnel shows "inactive"** — cloudflared not running. Check: `systemctl status cloudflared`
- **DNS not resolving** — CNAME might not exist. Check: `dig myapp.example.com`
- **"connection refused"** — wrong port in config. Verify service is listening: `ss -tlnp`
- **WebSocket not working** — add `noHappyEyeballs: true` to originRequest
- **Slow connections** — check if origin is binding to IPv6. Force IPv4: `service: http://127.0.0.1:<port>`
- **Config not loading** — validate: `cloudflared tunnel ingress validate`
- **Multiple tunnels fighting** — check no duplicate configs: `ls /etc/cloudflared/`

## Safety Rules

- **Always have a catch-all rule** as the last ingress entry (`service: http_status:404`)
- **Don't expose admin panels** without Zero Trust access policies
- **Use noTLSVerify only for self-signed certs** — not for production origins
- **Quick tunnels are temporary** — don't use for production
- **Back up credentials files** — `~/.cloudflared/<UUID>.json` is needed to run the tunnel
