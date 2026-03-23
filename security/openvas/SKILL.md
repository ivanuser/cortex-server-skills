# OpenVAS / Greenbone — Vulnerability Scanner

> Install, configure, and manage the Greenbone Vulnerability Management (GVM/OpenVAS) stack for network vulnerability scanning, authenticated assessments, and compliance auditing.

## Safety Rules

- Never run scans against networks or hosts you don't own or have written authorization to scan.
- Authenticated scans use stored credentials — protect the credential store and limit access.
- Feed syncs download gigabytes of NVT data — schedule during low-traffic windows.
- Back up `/var/lib/gvm/` before major upgrades.
- GSA (web UI) default admin password is generated at setup — change it immediately.
- Scans can cause service disruption on fragile hosts — use "safe checks" scan configs for production systems.

## Quick Reference

```bash
# Check GVM services status
sudo systemctl status gvmd gsad ospd-openvas

# Start all GVM services
sudo systemctl start ospd-openvas gvmd gsad

# Stop all GVM services
sudo systemctl stop gsad gvmd ospd-openvas

# Restart all services (order matters)
sudo systemctl restart ospd-openvas && sleep 5
sudo systemctl restart gvmd && sleep 3
sudo systemctl restart gsad

# Update NVT feeds
sudo -u _gvm greenbone-feed-sync

# Check feed status
sudo -u _gvm greenbone-feed-sync --type GVMD_DATA --selftest
sudo -u _gvm greenbone-feed-sync --type SCAP --selftest
sudo -u _gvm greenbone-feed-sync --type CERT --selftest

# gvm-cli: list tasks
gvm-cli --gmp-username admin --gmp-password <pass> socket \
  --socketpath /run/gvmd/gvmd.sock \
  --xml '<get_tasks/>'

# gvm-cli: get scan results
gvm-cli --gmp-username admin --gmp-password <pass> socket \
  --socketpath /run/gvmd/gvmd.sock \
  --xml '<get_results task_id="<TASK_UUID>"/>'

# Check GVM version
gvmd --version
openvas --version
gsad --version
```

## Common Ports

| Port | Service | Description |
|------|---------|-------------|
| 9392 | GSA | Greenbone Security Assistant (web UI) |
| 9390 | gvmd | Greenbone Vulnerability Manager daemon |
| 9391 | ospd-openvas | OSP scanner daemon (internal) |

## Installation — Packages (Debian/Ubuntu)

### From Greenbone Community PPA

```bash
# Install prerequisites
sudo apt update
sudo apt install -y software-properties-common

# Add Greenbone Community Edition PPA
sudo add-apt-repository -y ppa:mrazavi/gvm

# Install the full stack
sudo apt update
sudo apt install -y gvm

# Run initial setup (creates admin user, syncs feeds)
sudo gvm-setup

# The setup prints the admin password — SAVE IT
# If you miss it, reset with:
sudo -u _gvm gvmd --user=admin --new-password=<new-password>

# Enable and start services
sudo systemctl enable --now ospd-openvas gvmd gsad

# Verify everything is running
sudo gvm-check-setup
```

### From source (Kali/advanced)

```bash
# Kali Linux has GVM pre-packaged
sudo apt install -y gvm
sudo gvm-setup
sudo gvm-check-setup
```

## Installation — Docker (Recommended)

### Greenbone Community Containers

```bash
# Create working directory
mkdir -p ~/greenbone && cd ~/greenbone

# Create docker-compose.yml
cat > docker-compose.yml << 'EOF'
services:
  vulnerability-tests:
    image: greenbone/vulnerability-tests
    environment:
      STORAGE_PATH: /var/lib/openvas/22.04/vt-data/nasl
    volumes:
      - vt_data_vol:/var/lib/openvas/22.04/vt-data/nasl

  notus-data:
    image: greenbone/notus-data
    volumes:
      - notus_data_vol:/var/lib/notus

  scap-data:
    image: greenbone/scap-data
    volumes:
      - scap_data_vol:/var/lib/gvm/scap-data

  cert-bund-data:
    image: greenbone/cert-bund-data
    volumes:
      - cert_data_vol:/var/lib/gvm/cert-data

  dfn-cert-data:
    image: greenbone/dfn-cert-data
    volumes:
      - cert_data_vol:/var/lib/gvm/cert-data

  data-objects:
    image: greenbone/data-objects
    volumes:
      - data_objects_vol:/var/lib/gvm/data-objects/gvmd

  report-formats:
    image: greenbone/report-formats
    volumes:
      - data_objects_vol:/var/lib/gvm/data-objects/gvmd

  gpg-data:
    image: greenbone/gpg-data
    volumes:
      - gpg_data_vol:/etc/openvas/gnupg

  redis-server:
    image: greenbone/redis-server
    restart: on-failure
    volumes:
      - redis_socket_vol:/run/redis/

  pg-gvm:
    image: greenbone/pg-gvm:stable
    restart: on-failure
    volumes:
      - psql_data_vol:/var/lib/postgresql
      - psql_socket_vol:/var/run/postgresql

  gvmd:
    image: greenbone/gvmd:stable
    restart: on-failure
    volumes:
      - gvmd_data_vol:/var/lib/gvm
      - scap_data_vol:/var/lib/gvm/scap-data/
      - cert_data_vol:/var/lib/gvm/cert-data
      - data_objects_vol:/var/lib/gvm/data-objects/gvmd
      - vt_data_vol:/var/lib/openvas/22.04/vt-data/nasl
      - psql_data_vol:/var/lib/postgresql
      - psql_socket_vol:/var/run/postgresql
      - gvmd_socket_vol:/run/gvmd
    depends_on:
      pg-gvm:
        condition: service_started

  gsa:
    image: greenbone/gsa:stable
    restart: on-failure
    ports:
      - "9392:80"
    volumes:
      - gvmd_socket_vol:/run/gvmd
    depends_on:
      - gvmd

  ospd-openvas:
    image: greenbone/ospd-openvas:stable
    restart: on-failure
    hostname: ospd-openvas.local
    cap_add:
      - NET_ADMIN
      - NET_RAW
    security_opt:
      - apparmor=unconfined
    volumes:
      - gpg_data_vol:/etc/openvas/gnupg
      - vt_data_vol:/var/lib/openvas/22.04/vt-data/nasl
      - notus_data_vol:/var/lib/notus
      - ospd_openvas_socket_vol:/run/ospd
      - redis_socket_vol:/run/redis/
    depends_on:
      redis-server:
        condition: service_started

  notus-scanner:
    image: greenbone/notus-scanner:stable
    restart: on-failure
    volumes:
      - notus_data_vol:/var/lib/notus
      - gpg_data_vol:/etc/openvas/gnupg
    depends_on:
      - ospd-openvas

volumes:
  gpg_data_vol:
  scap_data_vol:
  cert_data_vol:
  data_objects_vol:
  gvmd_data_vol:
  psql_data_vol:
  vt_data_vol:
  notus_data_vol:
  psql_socket_vol:
  gvmd_socket_vol:
  ospd_openvas_socket_vol:
  redis_socket_vol:
EOF

# Start the stack
docker compose up -d

# Wait for feed sync to complete (can take 30+ minutes first time)
docker compose logs -f gvmd 2>&1 | grep -i "sync"

# Set admin password
docker compose exec -u gvmd gvmd gvmd --user=admin --new-password=<password>
```

## Feed Management

```bash
# --- Package install ---
# Full sync (NVTs + SCAP + CERT + GVMD_DATA)
sudo -u _gvm greenbone-feed-sync

# Sync specific feed type
sudo -u _gvm greenbone-feed-sync --type NVT
sudo -u _gvm greenbone-feed-sync --type SCAP
sudo -u _gvm greenbone-feed-sync --type CERT
sudo -u _gvm greenbone-feed-sync --type GVMD_DATA

# --- Docker install ---
# Pull latest feed containers
docker compose pull vulnerability-tests notus-data scap-data cert-bund-data dfn-cert-data data-objects report-formats
docker compose up -d

# Verify NVT count (should be 70,000+)
gvm-cli --gmp-username admin --gmp-password <pass> socket \
  --socketpath /run/gvmd/gvmd.sock \
  --xml '<get_feeds/>'
```

### Troubleshooting Feed Sync

```bash
# Check disk space (feeds need ~10GB)
df -h /var/lib/gvm/

# Check feed lock files
ls -la /var/lib/gvm/.feed-*

# Remove stale lock (only if sync isn't actually running)
sudo rm /var/lib/gvm/.feed-*.lock

# Check feed sync logs
sudo journalctl -u greenbone-feed-sync --since "1 hour ago"

# Verify network connectivity to feed server
curl -I https://feed.community.greenbone.net/

# If behind proxy
export http_proxy=http://proxy:port
export https_proxy=http://proxy:port
sudo -E -u _gvm greenbone-feed-sync
```

## Scanning Operations

### Create a scan target

```bash
# Via gvm-cli
gvm-cli --gmp-username admin --gmp-password <pass> socket \
  --socketpath /run/gvmd/gvmd.sock \
  --xml '<create_target>
    <name>Internal Network</name>
    <hosts>192.168.1.0/24</hosts>
    <port_list id="33d0cd82-57c6-11e1-8ed1-406186ea4fc5"/>
  </create_target>'
# The port_list ID above is "All IANA assigned TCP" (built-in)

# Common built-in port lists:
# 33d0cd82-57c6-11e1-8ed1-406186ea4fc5  All IANA assigned TCP
# 4a4717fe-57d2-11e1-9a26-406186ea4fc5  All IANA assigned TCP and UDP
# 730ef368-57e2-11e1-a90f-406186ea4fc5  All TCP and Nmap top 100 UDP
```

### Create a scan task

```bash
# Get scan config IDs
gvm-cli --gmp-username admin --gmp-password <pass> socket \
  --socketpath /run/gvmd/gvmd.sock \
  --xml '<get_configs/>'

# Common built-in scan configs:
# daba56c8-73ec-11df-a475-002264764cea  Full and fast
# 698f691e-7489-11df-9d8c-002264764cea  Full and fast ultimate
# 085569ce-73ed-11df-83c3-002264764cea  Full and very deep
# 2d3f051c-55ba-11e3-bf43-406186ea4fc5  Host Discovery
# bbca7412-a950-11e3-9109-406186ea4fc5  System Discovery

# Create task
gvm-cli --gmp-username admin --gmp-password <pass> socket \
  --socketpath /run/gvmd/gvmd.sock \
  --xml '<create_task>
    <name>Weekly Internal Scan</name>
    <config id="daba56c8-73ec-11df-a475-002264764cea"/>
    <target id="<TARGET_UUID>"/>
    <scanner id="08b69003-5fc2-4037-a479-93b440211c73"/>
  </create_task>'
# Scanner ID above is the default OpenVAS scanner
```

### Start / stop / monitor scans

```bash
# Start a scan task
gvm-cli --gmp-username admin --gmp-password <pass> socket \
  --socketpath /run/gvmd/gvmd.sock \
  --xml '<start_task task_id="<TASK_UUID>"/>'

# Check task status
gvm-cli --gmp-username admin --gmp-password <pass> socket \
  --socketpath /run/gvmd/gvmd.sock \
  --xml '<get_tasks task_id="<TASK_UUID>"/>'

# Stop a running scan
gvm-cli --gmp-username admin --gmp-password <pass> socket \
  --socketpath /run/gvmd/gvmd.sock \
  --xml '<stop_task task_id="<TASK_UUID>"/>'
```

### Authenticated scanning (SSH credentials)

```bash
# Create SSH credential
gvm-cli --gmp-username admin --gmp-password <pass> socket \
  --socketpath /run/gvmd/gvmd.sock \
  --xml '<create_credential>
    <name>Linux SSH Key</name>
    <type>usk</type>
    <login>scanuser</login>
    <key>
      <private><![CDATA[-----BEGIN OPENSSH PRIVATE KEY-----
...key content...
-----END OPENSSH PRIVATE KEY-----]]></private>
    </key>
  </create_credential>'

# Create target with credential
gvm-cli --gmp-username admin --gmp-password <pass> socket \
  --socketpath /run/gvmd/gvmd.sock \
  --xml '<create_target>
    <name>Authenticated Linux Hosts</name>
    <hosts>192.168.1.10,192.168.1.11</hosts>
    <ssh_credential id="<CREDENTIAL_UUID>"/>
    <port_list id="33d0cd82-57c6-11e1-8ed1-406186ea4fc5"/>
  </create_target>'
```

## Reports

```bash
# List reports
gvm-cli --gmp-username admin --gmp-password <pass> socket \
  --socketpath /run/gvmd/gvmd.sock \
  --xml '<get_reports/>'

# Get report details (XML)
gvm-cli --gmp-username admin --gmp-password <pass> socket \
  --socketpath /run/gvmd/gvmd.sock \
  --xml '<get_reports report_id="<REPORT_UUID>" details="1"/>'

# Export as PDF
# Report format IDs:
# c402cc3e-b531-11e1-9163-406186ea4fc5  PDF
# a994b278-1f62-11e1-96ac-406186ea4fc5  XML
# 77bd6c4a-1f62-11e1-abf0-406186ea4fc5  HTML

gvm-cli --gmp-username admin --gmp-password <pass> socket \
  --socketpath /run/gvmd/gvmd.sock \
  --xml '<get_reports report_id="<REPORT_UUID>"
    format_id="c402cc3e-b531-11e1-9163-406186ea4fc5"/>' \
  | base64 -d > report.pdf
```

## Schedule Recurring Scans

```bash
# Create a schedule (weekly on Sunday at 02:00 UTC)
gvm-cli --gmp-username admin --gmp-password <pass> socket \
  --socketpath /run/gvmd/gvmd.sock \
  --xml '<create_schedule>
    <name>Weekly Sunday 2AM</name>
    <icalendar>BEGIN:VCALENDAR
VERSION:2.0
BEGIN:VEVENT
DTSTART:20260101T020000Z
RRULE:FREQ=WEEKLY;BYDAY=SU
DURATION:PT12H
END:VEVENT
END:VCALENDAR</icalendar>
    <timezone>UTC</timezone>
  </create_schedule>'

# Attach schedule to task
gvm-cli --gmp-username admin --gmp-password <pass> socket \
  --socketpath /run/gvmd/gvmd.sock \
  --xml '<modify_task task_id="<TASK_UUID>">
    <schedule id="<SCHEDULE_UUID>"/>
  </modify_task>'
```

## User Management

```bash
# Create a user
gvm-cli --gmp-username admin --gmp-password <pass> socket \
  --socketpath /run/gvmd/gvmd.sock \
  --xml '<create_user>
    <name>analyst</name>
    <password>SecureP@ss123</password>
    <role id="57e1be8b-55d7-11e1-83f0-406186ea4fc5"/>
  </create_user>'

# Built-in roles:
# 7a8cb5b4-b74d-11e2-8187-406186ea4fc5  Admin
# 57e1be8b-55d7-11e1-83f0-406186ea4fc5  User
# 5f8fd09e-55d7-11e1-83f0-406186ea4fc5  Observer

# Change user password
sudo -u _gvm gvmd --user=analyst --new-password=NewP@ss456
```

## Troubleshooting

```bash
# Check all GVM services
sudo systemctl status ospd-openvas gvmd gsad

# View logs
sudo journalctl -u gvmd --since "30 min ago" --no-pager
sudo journalctl -u ospd-openvas --since "30 min ago" --no-pager
sudo journalctl -u gsad --since "30 min ago" --no-pager

# Docker logs
docker compose logs gvmd --tail 50
docker compose logs ospd-openvas --tail 50

# Check scanner connectivity
gvm-cli --gmp-username admin --gmp-password <pass> socket \
  --socketpath /run/gvmd/gvmd.sock \
  --xml '<get_scanners/>'

# Verify ospd-openvas socket exists
ls -la /run/ospd/ospd-openvas.sock

# PostgreSQL issues
sudo -u postgres psql -c "SELECT pg_database_size('gvmd');"

# Reset admin password
sudo -u _gvm gvmd --user=admin --new-password=admin

# Check Redis connectivity (used by OpenVAS scanner)
redis-cli -s /run/redis/redis.sock ping

# Rebuild NVT cache after feed update
sudo -u _gvm gvmd --rebuild

# Memory issues (GVM needs ~4GB RAM minimum)
free -h
```

## Firewall Configuration

```bash
# Allow GSA web interface
sudo ufw allow 9392/tcp comment "OpenVAS GSA Web UI"

# Allow gvmd (only if remote management needed)
sudo ufw allow 9390/tcp comment "GVM Manager Daemon"

# For Docker, ensure the bridge network is accessible
sudo ufw allow from 172.16.0.0/12 to any comment "Docker networks"
```
