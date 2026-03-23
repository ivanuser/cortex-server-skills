# cloudflare-install — Cloudflare Tunnel Setup

Install and configure Cloudflare Tunnel (cloudflared) to expose services securely without opening ports.

## Safety Rules

- Treat tunnel tokens and tunnel credential files as secrets.
- Never expose admin interfaces without Cloudflare Access policies.
- Validate ingress rules before restarting the service to avoid downtime.
- Use least-privilege DNS scope for API tokens used with tunnel DNS routing.
- Keep a local rollback copy of `/etc/cloudflared/config.yml` before major changes.

## Quick Reference

```bash
# Install (Debian/Ubuntu)
sudo apt-get update && sudo apt-get install -y cloudflared

# Version check
cloudflared --version

# Login and create tunnel
cloudflared tunnel login
cloudflared tunnel create my-tunnel

# Install as service (token-based)
sudo cloudflared service install YOUR_TUNNEL_TOKEN

# Service operations
sudo systemctl status cloudflared
sudo systemctl restart cloudflared

# Validate ingress config
cloudflared tunnel ingress validate
```

## Installation

### Quick Install (Debian/Ubuntu)

```bash
# Add Cloudflare GPG key
sudo mkdir -p --mode=0755 /usr/share/keyrings
curl -fsSL https://pkg.cloudflare.com/cloudflare-public-v2.gpg | sudo tee /usr/share/keyrings/cloudflare-public-v2.gpg >/dev/null

# Add repository
echo 'deb [signed-by=/usr/share/keyrings/cloudflare-public-v2.gpg] https://pkg.cloudflare.com/cloudflared any main' | sudo tee /etc/apt/sources.list.d/cloudflared.list

# Install
sudo apt-get update && sudo apt-get install -y cloudflared

# Verify
cloudflared --version
```

### Other Install Methods

### Direct Binary (any Linux)
```bash
curl -L https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64 -o /usr/local/bin/cloudflared
chmod +x /usr/local/bin/cloudflared
cloudflared --version
```

### ARM64 (Raspberry Pi, etc.)
```bash
curl -L https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-arm64 -o /usr/local/bin/cloudflared
chmod +x /usr/local/bin/cloudflared
```

### Docker
```bash
docker run -d --name cloudflared --restart unless-stopped \
  cloudflare/cloudflared:latest tunnel --no-autoupdate run \
  --token YOUR_TUNNEL_TOKEN
```

## Register as System Service

After getting your tunnel token from the Cloudflare Zero Trust dashboard:

```bash
# Install as service with your tunnel token
sudo cloudflared service install YOUR_TUNNEL_TOKEN

# This creates:
#   /etc/systemd/system/cloudflared.service
#   /etc/cloudflared/config.yml (with token)

# Verify service
sudo systemctl status cloudflared
sudo systemctl enable cloudflared
```

## Login & Authenticate (Alternative Method)

If you don't have a tunnel token yet:

```bash
# Login to Cloudflare (opens browser)
cloudflared tunnel login

# Creates ~/.cloudflared/cert.pem

# Create a named tunnel
cloudflared tunnel create my-tunnel

# This creates:
#   ~/.cloudflared/<TUNNEL_UUID>.json (tunnel credentials)
```

## Where to Get Your Tunnel Token

1. Go to https://one.dash.cloudflare.com (Zero Trust dashboard)
2. Navigate to: Networks → Tunnels
3. Click "Create a tunnel"
4. Choose "Cloudflared" connector
5. Copy the install command — it contains your token
6. The token is the long base64 string after `service install`

## Verify Installation

```bash
# Check service running
sudo systemctl status cloudflared

# Check tunnel connectivity
cloudflared tunnel info

# Check logs
sudo journalctl -u cloudflared -f

# Test specific tunnel
cloudflared tunnel run --url http://localhost:8080
```

## Uninstall

```bash
# Stop and remove service
sudo cloudflared service uninstall

# Remove package
sudo apt-get remove -y cloudflared

# Clean up
sudo rm -rf /etc/cloudflared ~/.cloudflared
sudo rm -f /etc/apt/sources.list.d/cloudflared.list
```

## Troubleshooting

- **"failed to connect"** — check DNS resolution, firewall not blocking outbound 443
- **"no such host"** — tunnel might be deleted in Cloudflare dashboard
- **Service won't start** — check token is correct: `sudo cat /etc/cloudflared/config.yml`
- **Ingress rule errors** — run `cloudflared tunnel ingress validate` and confirm catch-all rule is last
- **Tunnel shows "down"** — restart service: `sudo systemctl restart cloudflared`
