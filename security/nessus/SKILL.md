# Nessus — Vulnerability Scanner

> Install, configure, and manage Tenable Nessus for vulnerability scanning, compliance auditing, and security assessment of network assets.

## Safety Rules

- Never scan networks or hosts without explicit written authorization.
- Nessus requires a valid license — Essentials (free, 16 IPs), Professional, or Expert.
- Plugin updates download hundreds of megabytes — schedule during maintenance windows.
- Credential scans provide deeper results but use stored passwords — secure the Nessus host.
- Some scan plugins can crash vulnerable services — use "safe checks" for production hosts.
- Back up `/opt/nessus/` before upgrades.
- Port 8834 exposes the full management UI — restrict access by IP or VPN.

## Quick Reference

```bash
# Start Nessus
sudo systemctl start nessusd

# Stop Nessus
sudo systemctl stop nessusd

# Restart Nessus
sudo systemctl restart nessusd

# Check status
sudo systemctl status nessusd

# Enable on boot
sudo systemctl enable nessusd

# Check Nessus version
/opt/nessus/sbin/nessusd --version

# Update plugins from CLI
/opt/nessus/sbin/nessuscli update --all

# Reset admin password
/opt/nessus/sbin/nessuscli chpasswd admin

# List registered users
/opt/nessus/sbin/nessuscli lsuser

# Add a user
/opt/nessus/sbin/nessuscli adduser

# Nessus CLI fix (reset to factory)
/opt/nessus/sbin/nessuscli fix --reset

# Show plugin count
/opt/nessus/sbin/nessuscli update --plugins-only --info
```

## Common Ports

| Port | Service | Description |
|------|---------|-------------|
| 8834 | nessusd | Web UI and REST API (HTTPS) |

## Installation — Debian/Ubuntu

```bash
# Download the .deb package from tenable.com/downloads/nessus
# Requires a Tenable account

# Install
sudo dpkg -i Nessus-*.deb

# Start the service
sudo systemctl start nessusd
sudo systemctl enable nessusd

# Open web UI — https://localhost:8834
# Complete setup wizard:
# 1. Choose license type (Essentials / Professional / Expert)
# 2. Enter activation code from tenable.com
# 3. Create admin user
# 4. Wait for plugin compilation (15-30 minutes)
```

### RHEL/Rocky/Alma

```bash
sudo rpm -ivh Nessus-*.rpm
sudo systemctl start nessusd
sudo systemctl enable nessusd
```

### Offline installation (air-gapped)

```bash
# 1. Download Nessus package + offline activation code from tenable.com
# 2. Install package as above
# 3. Register offline:
/opt/nessus/sbin/nessuscli fetch --register-offline <challenge_code>

# 4. Download plugins bundle from tenable.com (nessus-updates-*.tar.gz)
# 5. Install plugins:
/opt/nessus/sbin/nessuscli update <plugin-archive>.tar.gz

# 6. Restart
sudo systemctl restart nessusd
```

## Web Interface Setup

```
1. Navigate to https://<server-ip>:8834
2. Accept the self-signed certificate warning
3. Select product type:
   - Nessus Essentials (free — up to 16 IPs)
   - Nessus Professional (commercial — unlimited IPs)
   - Nessus Expert (commercial — includes web app scanning)
4. Enter activation code
5. Create administrator account
6. Wait for plugin download and compilation (15-45 min)
```

## Scan Policies

### Built-in scan templates

| Template | Use Case |
|----------|----------|
| Basic Network Scan | General vulnerability assessment |
| Advanced Scan | Full customization of plugins and settings |
| Web Application Tests | OWASP Top 10, XSS, SQLi |
| Credentialed Patch Audit | Authenticated scan for missing patches |
| Malware Scan | Detect known malware on hosts |
| Host Discovery | Find live hosts (no vulnerability checks) |
| PCI Quarterly External Scan | PCI DSS compliance |
| SCAP and OVAL Auditing | DISA STIG / CIS compliance |
| Internal PCI Network Scan | PCI internal network scan |

### Create a custom scan policy (API)

```bash
# List scan templates
curl -sk -H "X-ApiKeys: accessKey=<ACCESS_KEY>;secretKey=<SECRET_KEY>" \
  https://localhost:8834/editor/scan/templates | python3 -m json.tool

# Create a scan
curl -sk -X POST \
  -H "X-ApiKeys: accessKey=<ACCESS_KEY>;secretKey=<SECRET_KEY>" \
  -H "Content-Type: application/json" \
  -d '{
    "uuid": "<template-uuid>",
    "settings": {
      "name": "Weekly Internal Scan",
      "description": "Scan internal network weekly",
      "enabled": true,
      "text_targets": "192.168.1.0/24",
      "launch": "ON_DEMAND"
    }
  }' \
  https://localhost:8834/scans
```

## Running Scans

### Via Web UI

```
1. Go to Scans → New Scan
2. Choose a template
3. Configure:
   - Name and description
   - Targets (IPs, ranges, CIDR, hostnames)
   - Schedule (optional)
   - Credentials (optional — SSH, Windows, SNMP)
   - Plugins to enable/disable
4. Launch scan
```

### Via REST API

```bash
# Launch a scan
curl -sk -X POST \
  -H "X-ApiKeys: accessKey=<ACCESS_KEY>;secretKey=<SECRET_KEY>" \
  https://localhost:8834/scans/<scan_id>/launch

# Get scan status
curl -sk \
  -H "X-ApiKeys: accessKey=<ACCESS_KEY>;secretKey=<SECRET_KEY>" \
  https://localhost:8834/scans/<scan_id> | python3 -m json.tool

# Pause a scan
curl -sk -X POST \
  -H "X-ApiKeys: accessKey=<ACCESS_KEY>;secretKey=<SECRET_KEY>" \
  https://localhost:8834/scans/<scan_id>/pause

# Stop a scan
curl -sk -X POST \
  -H "X-ApiKeys: accessKey=<ACCESS_KEY>;secretKey=<SECRET_KEY>" \
  https://localhost:8834/scans/<scan_id>/stop

# List all scans
curl -sk \
  -H "X-ApiKeys: accessKey=<ACCESS_KEY>;secretKey=<SECRET_KEY>" \
  https://localhost:8834/scans | python3 -m json.tool
```

## Credentials for Authenticated Scans

### SSH

```
Scans → New Scan → Credentials tab → SSH
- Authentication method: password or public key
- Username: scanuser
- Password or SSH private key
- Elevate privileges via: sudo / su / pbrun
```

### Windows

```
Scans → New Scan → Credentials tab → Windows
- Authentication method: Password
- Username: DOMAIN\scanuser
- Password: ********
- Or use NTLMv2, Kerberos
```

### SNMP

```
Scans → New Scan → Credentials tab → SNMP
- Community string: public (v1/v2c)
- Or SNMPv3: username, auth protocol (SHA/MD5), privacy protocol (AES/DES)
```

## Reports

### Export via Web UI

```
1. Scans → click completed scan
2. Export button (top right)
3. Choose format:
   - Nessus (XML) — for import into other tools
   - PDF — executive / detailed report
   - HTML — web-viewable report
   - CSV — for spreadsheet analysis
```

### Export via API

```bash
# Request export
curl -sk -X POST \
  -H "X-ApiKeys: accessKey=<ACCESS_KEY>;secretKey=<SECRET_KEY>" \
  -H "Content-Type: application/json" \
  -d '{"format": "csv"}' \
  https://localhost:8834/scans/<scan_id>/export

# Response includes a file_id — poll for completion
curl -sk \
  -H "X-ApiKeys: accessKey=<ACCESS_KEY>;secretKey=<SECRET_KEY>" \
  https://localhost:8834/scans/<scan_id>/export/<file_id>/status

# Download when ready
curl -sk \
  -H "X-ApiKeys: accessKey=<ACCESS_KEY>;secretKey=<SECRET_KEY>" \
  https://localhost:8834/scans/<scan_id>/export/<file_id>/download \
  -o scan_results.csv

# Available formats: csv, html, nessus (XML), pdf
```

## Plugin Management

```bash
# Update plugins online
/opt/nessus/sbin/nessuscli update --all

# Update plugins from a file (offline)
/opt/nessus/sbin/nessuscli update /tmp/all-2.0.tar.gz

# Check plugin feed info
/opt/nessus/sbin/nessuscli update --plugins-only --info

# Force plugin recompilation
sudo systemctl stop nessusd
rm -rf /opt/nessus/var/nessus/plugins-cache
sudo systemctl start nessusd
```

## Compliance Scanning

```
1. Create new scan → Compliance tab
2. Available audit files:
   - CIS Benchmarks (Linux, Windows, macOS, network devices)
   - DISA STIGs
   - PCI DSS requirements
   - HIPAA controls
   - Custom .audit files
3. Upload custom .audit files or select built-in ones
4. Credential scan required for compliance checks
```

## API Key Management

```bash
# Generate API keys (Web UI)
# Settings → My Account → API Keys → Generate

# Or via API with session token
# 1. Create session
curl -sk -X POST \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"<password>"}' \
  https://localhost:8834/session

# 2. Use the returned token
curl -sk -H "X-Cookie: token=<session_token>" \
  https://localhost:8834/session/keys

# Test API key access
curl -sk \
  -H "X-ApiKeys: accessKey=<ACCESS_KEY>;secretKey=<SECRET_KEY>" \
  https://localhost:8834/server/status
```

## Firewall Configuration

```bash
# Allow Nessus Web UI
sudo ufw allow 8834/tcp comment "Nessus Web UI"

# Restrict to specific networks
sudo ufw allow from 192.168.1.0/24 to any port 8834 proto tcp comment "Nessus from LAN"
```

## Troubleshooting

```bash
# Check service status
sudo systemctl status nessusd
sudo journalctl -u nessusd --since "30 min ago"

# View Nessus logs
tail -100 /opt/nessus/var/nessus/logs/nestusd.messages
tail -100 /opt/nessus/var/nessus/logs/backend.log
tail -100 /opt/nessus/var/nessus/logs/www_server.log

# Check port binding
sudo ss -tlnp | grep 8834

# Plugin compilation stuck — reset
sudo systemctl stop nessusd
rm -rf /opt/nessus/var/nessus/plugins-cache
sudo systemctl start nessusd

# Reset to factory defaults (nuclear option)
/opt/nessus/sbin/nessuscli fix --reset

# License issues
/opt/nessus/sbin/nessuscli fetch --register <activation-code>

# Check disk space (plugins need ~5GB)
du -sh /opt/nessus/

# Certificate issues
# Nessus uses a self-signed cert by default
# Replace with custom cert:
# Copy cert.pem and key.pem to /opt/nessus/com/nessus/CA/
# Restart nessusd

# Web UI not loading
# Check if nessusd is still compiling plugins
# Look for "Plugin compilation complete" in logs
grep -i "compilation" /opt/nessus/var/nessus/logs/nestusd.messages
```
