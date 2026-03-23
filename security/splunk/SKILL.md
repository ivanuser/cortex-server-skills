# Splunk — Log Analysis & SIEM

> Install, configure, and manage Splunk Enterprise and Universal Forwarder for log aggregation, search, alerting, and security information & event management (SIEM).

## Safety Rules

- Splunk Enterprise free license is limited to 500 MB/day indexing. Exceeding it blocks searching until license resets.
- Never expose the management port (8089) to the public internet without authentication and TLS.
- Back up `$SPLUNK_HOME/etc/` before upgrades — it contains all configs and apps.
- Splunk indexes are write-heavy — use fast storage (SSD) for `$SPLUNK_HOME/var/lib/splunk/`.
- Default admin password must be changed after first login.
- Universal Forwarders should only send data to trusted indexers — verify `outputs.conf` targets.
- Splunk runs as root by default — consider running as a dedicated `splunk` user in production.

## Quick Reference

```bash
# Start Splunk
sudo /opt/splunk/bin/splunk start --accept-license

# Stop Splunk
sudo /opt/splunk/bin/splunk stop

# Restart Splunk
sudo /opt/splunk/bin/splunk restart

# Check status
sudo /opt/splunk/bin/splunk status

# Show Splunk version
/opt/splunk/bin/splunk version

# Enable boot start (systemd)
sudo /opt/splunk/bin/splunk enable boot-start -systemd-managed 1 -user splunk

# Reload config without restart
sudo /opt/splunk/bin/splunk reload deploy-server

# Check license usage
sudo /opt/splunk/bin/splunk list licenser-usage

# Search from CLI
/opt/splunk/bin/splunk search "index=main error" -maxout 10

# Add a monitor input
/opt/splunk/bin/splunk add monitor /var/log/syslog -index main -sourcetype syslog

# List data inputs
/opt/splunk/bin/splunk list monitor

# Add a forwarding target
/opt/splunk/bin/splunk add forward-server indexer01:9997
```

## Common Ports

| Port | Service | Description |
|------|---------|-------------|
| 8000 | Splunk Web | Web interface (HTTP/HTTPS) |
| 8089 | splunkd | Management / REST API (HTTPS) |
| 9997 | Receiving | Data receiving from forwarders |
| 8088 | HEC | HTTP Event Collector |
| 8191 | KV Store | App key-value store |
| 514 | Syslog | Syslog input (TCP/UDP) |

## Installation — Splunk Enterprise

### From .tgz (Debian/Ubuntu/RHEL)

```bash
# Download from splunk.com (requires account)
# Or use wget with direct link
cd /tmp

# Extract to /opt
sudo tar xzf splunk-*.tgz -C /opt

# Create splunk user
sudo useradd -r -m -d /opt/splunk -s /bin/bash splunk
sudo chown -R splunk:splunk /opt/splunk

# First start (accept license, set admin password)
sudo -u splunk /opt/splunk/bin/splunk start --accept-license --answer-yes \
  --seed-passwd 'YourAdminP@ss123'

# Enable boot start with systemd
sudo /opt/splunk/bin/splunk enable boot-start -systemd-managed 1 -user splunk

# Verify
sudo systemctl status Splunkd
```

### From .deb package

```bash
# Install the .deb
sudo dpkg -i splunk-*.deb

# Start and accept license
sudo /opt/splunk/bin/splunk start --accept-license --seed-passwd 'YourAdminP@ss123'

# Enable boot start
sudo /opt/splunk/bin/splunk enable boot-start -systemd-managed 1 -user splunk
```

## Installation — Docker

```bash
# Single-node Splunk Enterprise
docker run -d \
  --name splunk \
  --hostname splunk \
  -p 8000:8000 \
  -p 8089:8089 \
  -p 9997:9997 \
  -p 8088:8088 \
  -e SPLUNK_START_ARGS='--accept-license' \
  -e SPLUNK_PASSWORD='YourAdminP@ss123' \
  -v splunk-var:/opt/splunk/var \
  -v splunk-etc:/opt/splunk/etc \
  --restart unless-stopped \
  splunk/splunk:latest

# Docker Compose
cat > docker-compose.yml << 'EOF'
services:
  splunk:
    image: splunk/splunk:latest
    container_name: splunk
    hostname: splunk
    ports:
      - "8000:8000"
      - "8089:8089"
      - "9997:9997"
      - "8088:8088"
      - "514:514/tcp"
      - "514:514/udp"
    environment:
      SPLUNK_START_ARGS: "--accept-license"
      SPLUNK_PASSWORD: "YourAdminP@ss123"
      SPLUNK_HEC_TOKEN: "your-hec-token-here"
    volumes:
      - splunk-var:/opt/splunk/var
      - splunk-etc:/opt/splunk/etc
    restart: unless-stopped

volumes:
  splunk-var:
  splunk-etc:
EOF

docker compose up -d
```

## Installation — Universal Forwarder

```bash
# Download Universal Forwarder from splunk.com
cd /tmp

# Extract
sudo tar xzf splunkforwarder-*.tgz -C /opt

# Create user
sudo useradd -r -m -d /opt/splunkforwarder -s /bin/bash splunkfwd
sudo chown -R splunkfwd:splunkfwd /opt/splunkforwarder

# Start with admin password
sudo -u splunkfwd /opt/splunkforwarder/bin/splunk start --accept-license \
  --seed-passwd 'FwdP@ss123'

# Configure forwarding target
sudo -u splunkfwd /opt/splunkforwarder/bin/splunk add forward-server \
  indexer01.example.com:9997

# Add monitored files
sudo -u splunkfwd /opt/splunkforwarder/bin/splunk add monitor /var/log/syslog \
  -index main -sourcetype syslog
sudo -u splunkfwd /opt/splunkforwarder/bin/splunk add monitor /var/log/auth.log \
  -index security -sourcetype linux_secure

# Enable boot start
sudo /opt/splunkforwarder/bin/splunk enable boot-start -systemd-managed 1 -user splunkfwd
```

## Configuration Files

### Key configuration file locations

```
$SPLUNK_HOME/etc/
├── system/
│   ├── default/           # Factory defaults (DO NOT EDIT)
│   └── local/             # Your system-level overrides
│       ├── inputs.conf     # Data inputs
│       ├── outputs.conf    # Forwarding targets
│       ├── props.conf      # Field extraction & parsing
│       ├── transforms.conf # Lookups & field transforms
│       ├── server.conf     # Server settings
│       ├── web.conf        # Web UI settings
│       └── authorize.conf  # Roles & capabilities
├── apps/                  # Installed apps
│   └── <app>/local/       # Per-app config overrides
└── deployment-apps/       # Apps pushed by deployment server
```

### inputs.conf — Data Sources

```ini
# Monitor a log file
[monitor:///var/log/syslog]
disabled = false
index = main
sourcetype = syslog
ignoreOlderThan = 7d

# Monitor a directory
[monitor:///var/log/apache2/]
disabled = false
index = web
sourcetype = access_combined
whitelist = \.log$

# TCP syslog input
[tcp://514]
disabled = false
index = syslog
sourcetype = syslog
connection_host = dns

# UDP syslog input
[udp://514]
disabled = false
index = syslog
sourcetype = syslog
connection_host = dns

# Scripted input (run a command every 60s)
[script:///opt/splunk/etc/apps/myapp/bin/collect_metrics.sh]
disabled = false
interval = 60
index = metrics
sourcetype = custom_metrics
```

### outputs.conf — Forwarding

```ini
# Forward to indexer cluster
[tcpout]
defaultGroup = primary_indexers

[tcpout:primary_indexers]
server = indexer01:9997, indexer02:9997
autoLBFrequency = 30
useACK = true

# SSL forwarding
[tcpout:ssl_group]
server = indexer01:9998
sslCertPath = $SPLUNK_HOME/etc/auth/client.pem
sslPassword = password
sslRootCAPath = $SPLUNK_HOME/etc/auth/ca.pem
sslVerifyServerCert = true
```

### props.conf — Parsing Rules

```ini
# Define timestamp extraction
[mysourcetype]
TIME_FORMAT = %Y-%m-%d %H:%M:%S
TIME_PREFIX = timestamp=
MAX_TIMESTAMP_LOOKAHEAD = 30
LINE_BREAKER = ([\r\n]+)
SHOULD_LINEMERGE = false
TRUNCATE = 10000

# Extract fields with regex
[access_combined]
EXTRACT-client_ip = ^(?P<client_ip>\d+\.\d+\.\d+\.\d+)
EXTRACT-status = \s(?P<status>\d{3})\s
```

### transforms.conf — Field Transforms

```ini
# Define a lookup
[my_lookup]
filename = my_lookup.csv
max_matches = 1

# Route events to different indexes
[route_by_source]
REGEX = ^/var/log/secure
DEST_KEY = _MetaData:Index
FORMAT = security
```

## Search (SPL) Basics

```spl
-- Basic search
index=main error | head 20

-- Time-bounded search
index=main sourcetype=syslog earliest=-1h latest=now

-- Stats
index=web sourcetype=access_combined | stats count by status

-- Top values
index=main | top 10 sourcetype

-- Timechart
index=main error | timechart span=1h count

-- Search with field extraction
index=main sourcetype=syslog | rex "Failed password for (?<username>\w+)" | stats count by username

-- Transaction (group related events)
index=web | transaction session_id maxpause=30m

-- Alerts: failed SSH logins in last 15 minutes
index=security sourcetype=linux_secure "Failed password" earliest=-15m
| stats count by src_ip
| where count > 5

-- Dashboard search: top error sources
index=main level=ERROR earliest=-24h
| stats count by host, sourcetype
| sort -count
| head 20

-- Subsearch
index=web status=500
| stats count by client_ip
| where count > 100
| fields client_ip
| map search="index=web client_ip=$client_ip$ | head 5"
```

## Index Management

```bash
# Create an index via CLI
/opt/splunk/bin/splunk add index security \
  -homePath /opt/splunk/var/lib/splunk/security/db \
  -coldPath /opt/splunk/var/lib/splunk/security/colddb \
  -thawedPath /opt/splunk/var/lib/splunk/security/thaweddb \
  -maxDataSize auto_high_volume

# Or via indexes.conf ($SPLUNK_HOME/etc/system/local/indexes.conf)
cat >> /opt/splunk/etc/system/local/indexes.conf << 'EOF'
[security]
homePath = $SPLUNK_DB/security/db
coldPath = $SPLUNK_DB/security/colddb
thawedPath = $SPLUNK_DB/security/thaweddb
maxTotalDataSizeMB = 51200
frozenTimePeriodInSecs = 7776000

[web]
homePath = $SPLUNK_DB/web/db
coldPath = $SPLUNK_DB/web/colddb
thawedPath = $SPLUNK_DB/web/thaweddb
maxTotalDataSizeMB = 102400
frozenTimePeriodInSecs = 15552000
EOF

# List indexes
/opt/splunk/bin/splunk list index

# Show index sizes
/opt/splunk/bin/splunk search "| dbinspect index=* | stats sum(sizeOnDiskMB) by index"
```

## User & Role Management

```bash
# Add a user
/opt/splunk/bin/splunk add user analyst -role user -password 'P@ssw0rd' -full-name "Security Analyst"

# Add a role with capabilities
/opt/splunk/bin/splunk add role security_analyst

# Edit roles in authorize.conf ($SPLUNK_HOME/etc/system/local/authorize.conf)
cat >> /opt/splunk/etc/system/local/authorize.conf << 'EOF'
[role_security_analyst]
importRoles = user
srchIndexesAllowed = main;security;web
srchIndexesDefault = security
srchMaxTime = 86400
cumulativeSrchJobsQuota = 10
EOF

# List users
/opt/splunk/bin/splunk list user
```

## HTTP Event Collector (HEC)

```bash
# Enable HEC
/opt/splunk/bin/splunk http-event-collector enable

# Create a token
/opt/splunk/bin/splunk http-event-collector create myapp \
  -index main -sourcetype myapp_events

# Send data to HEC
curl -k https://localhost:8088/services/collector \
  -H "Authorization: Splunk <HEC_TOKEN>" \
  -d '{"event": "Hello from HEC", "sourcetype": "manual", "index": "main"}'

# Send structured event
curl -k https://localhost:8088/services/collector \
  -H "Authorization: Splunk <HEC_TOKEN>" \
  -d '{
    "time": 1711152000,
    "host": "webserver01",
    "source": "myapp",
    "sourcetype": "json",
    "index": "main",
    "event": {"level": "error", "message": "Connection timeout", "code": 504}
  }'
```

## SSL/TLS Configuration

### Enable HTTPS for Splunk Web

```ini
# $SPLUNK_HOME/etc/system/local/web.conf
[settings]
enableSplunkWebSSL = true
privKeyPath = etc/auth/splunkweb/privkey.pem
serverCert = etc/auth/splunkweb/cert.pem
sslPassword = password
httpport = 8000
```

### Enable SSL for forwarder receiving

```ini
# $SPLUNK_HOME/etc/system/local/inputs.conf
[splunktcp-ssl:9998]
disabled = false

[SSL]
serverCert = $SPLUNK_HOME/etc/auth/server.pem
sslPassword = password
requireClientCert = false
```

## Deployment Server

```bash
# Enable deployment server in server.conf
cat >> /opt/splunk/etc/system/local/server.conf << 'EOF'
[deployment]
pass4SymmKey = myDeploymentKey
EOF

# Create a server class
# $SPLUNK_HOME/etc/system/local/serverclass.conf
cat > /opt/splunk/etc/system/local/serverclass.conf << 'EOF'
[serverClass:linux_servers]
whitelist.0 = *linux*

[serverClass:linux_servers:app:linux_inputs]
restartSplunkd = true
EOF

# Place apps in deployment-apps/
mkdir -p /opt/splunk/etc/deployment-apps/linux_inputs/local
cat > /opt/splunk/etc/deployment-apps/linux_inputs/local/inputs.conf << 'EOF'
[monitor:///var/log/syslog]
index = main
sourcetype = syslog
EOF

# Reload deployment server
/opt/splunk/bin/splunk reload deploy-server

# List deployment clients
/opt/splunk/bin/splunk search "| rest /services/deployment/server/clients" \
  | head 20
```

## Firewall Configuration

```bash
# Allow Splunk Web
sudo ufw allow 8000/tcp comment "Splunk Web UI"

# Allow management API
sudo ufw allow 8089/tcp comment "Splunk Management API"

# Allow data receiving from forwarders
sudo ufw allow 9997/tcp comment "Splunk Receiving"

# Allow HEC
sudo ufw allow 8088/tcp comment "Splunk HEC"

# Allow syslog
sudo ufw allow 514/tcp comment "Syslog TCP"
sudo ufw allow 514/udp comment "Syslog UDP"
```

## Troubleshooting

```bash
# Check Splunk status
/opt/splunk/bin/splunk status

# View internal logs
tail -100 /opt/splunk/var/log/splunk/splunkd.log
tail -100 /opt/splunk/var/log/splunk/web_service.log

# Check license usage
/opt/splunk/bin/splunk search "| rest /services/licenser/usage/license_usage \
  | fields slaves_usage_bytes quota" | head 5

# Check disk usage by index
/opt/splunk/bin/splunk search "| dbinspect index=* \
  | stats sum(rawSize) as raw_bytes, sum(sizeOnDiskMB) as disk_mb by index"

# Port conflicts
sudo ss -tlnp | grep -E '8000|8089|9997|8088'

# Restart a stuck process
/opt/splunk/bin/splunk stop
sleep 5
/opt/splunk/bin/splunk start

# Check forwarder connectivity
/opt/splunk/bin/splunk list forward-server

# Debug forwarder connection
/opt/splunk/bin/splunk search "index=_internal source=*metrics.log group=tcpin_connections" \
  | head 20

# Validate config files
/opt/splunk/bin/splunk btool inputs list --debug | head 50
/opt/splunk/bin/splunk btool props list --debug | head 50

# Check indexer clustering status
/opt/splunk/bin/splunk show cluster-status
```
