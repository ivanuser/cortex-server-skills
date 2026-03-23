# Wazuh — SIEM / XDR Platform

> Install, configure, and manage Wazuh for threat detection, integrity monitoring, incident response, and regulatory compliance across your infrastructure.

## Safety Rules

- Wazuh manager stores agent keys — protect `/var/ossec/etc/` and back it up regularly.
- The Wazuh API (port 55000) grants full management access — restrict it to trusted networks and use strong credentials.
- Custom rules can generate false positives and alert storms — test in a staging environment first.
- Agent enrollment requires an authentication key — never expose the enrollment token publicly.
- Wazuh dashboard stores sensitive security data — restrict access with authentication and TLS.
- File integrity monitoring (FIM) generates high I/O on large directories — scope it carefully.
- Back up `/var/ossec/` before major upgrades or rule changes.

## Quick Reference

```bash
# Wazuh Manager
sudo systemctl start wazuh-manager
sudo systemctl stop wazuh-manager
sudo systemctl restart wazuh-manager
sudo systemctl status wazuh-manager

# Wazuh Indexer (OpenSearch)
sudo systemctl start wazuh-indexer
sudo systemctl stop wazuh-indexer
sudo systemctl status wazuh-indexer

# Wazuh Dashboard
sudo systemctl start wazuh-dashboard
sudo systemctl stop wazuh-dashboard
sudo systemctl status wazuh-dashboard

# Check Wazuh version
/var/ossec/bin/wazuh-control info

# List connected agents
/var/ossec/bin/agent_control -l

# Check agent status
/var/ossec/bin/agent_control -i <agent_id>

# Restart all agents
/var/ossec/bin/agent_control -R -a

# Test configuration syntax
/var/ossec/bin/wazuh-analysisd -t
/var/ossec/bin/wazuh-logtest

# View alerts
tail -f /var/ossec/logs/alerts/alerts.json
```

## Common Ports

| Port | Service | Description |
|------|---------|-------------|
| 1514 | wazuh-remoted | Agent communication (TCP/UDP) |
| 1515 | wazuh-authd | Agent enrollment |
| 55000 | wazuh-api | Wazuh REST API (HTTPS) |
| 9200 | wazuh-indexer | OpenSearch API (HTTPS) |
| 443 | wazuh-dashboard | Web UI (HTTPS) |

## Installation — All-in-One (Recommended for Single Server)

### Automated installer

```bash
# Download and run the Wazuh installation assistant
curl -sO https://packages.wazuh.com/4.9/wazuh-install.sh
curl -sO https://packages.wazuh.com/4.9/config.yml

# Edit config.yml with your node info
cat > config.yml << 'EOF'
nodes:
  indexer:
    - name: wazuh-indexer
      ip: "127.0.0.1"
  server:
    - name: wazuh-server
      ip: "127.0.0.1"
  dashboard:
    - name: wazuh-dashboard
      ip: "127.0.0.1"
EOF

# Run the installer (all-in-one)
sudo bash wazuh-install.sh -a

# The installer prints the admin password — SAVE IT
# Default user: admin
# Access dashboard at https://<server-ip>:443
```

### Manual installation (Debian/Ubuntu)

```bash
# Add Wazuh repository
curl -s https://packages.wazuh.com/key/GPG-KEY-WAZUH | gpg --dearmor -o /usr/share/keyrings/wazuh.gpg
echo "deb [signed-by=/usr/share/keyrings/wazuh.gpg] https://packages.wazuh.com/4.x/apt/ stable main" \
  | sudo tee /etc/apt/sources.list.d/wazuh.list

sudo apt update

# Install Wazuh manager
sudo apt install -y wazuh-manager
sudo systemctl daemon-reload
sudo systemctl enable --now wazuh-manager

# Install Wazuh indexer (OpenSearch)
sudo apt install -y wazuh-indexer
# Configure /etc/wazuh-indexer/opensearch.yml
sudo systemctl enable --now wazuh-indexer

# Install Wazuh dashboard
sudo apt install -y wazuh-dashboard
# Configure /etc/wazuh-dashboard/opensearch_dashboards.yml
sudo systemctl enable --now wazuh-dashboard
```

## Installation — Docker

```bash
# Clone the Wazuh Docker repository
git clone https://github.com/wazuh/wazuh-docker.git -b v4.9.0
cd wazuh-docker/single-node

# Generate self-signed certificates
docker compose -f generate-indexer-certs.yml run --rm generator

# Start the stack
docker compose up -d

# Default credentials: admin / SecretPassword
# Dashboard: https://localhost:443

# Check status
docker compose ps

# View logs
docker compose logs -f wazuh.manager
```

### Docker multi-node (production)

```bash
cd wazuh-docker/multi-node

# Edit .env for custom passwords and settings
# Generate certificates
docker compose -f generate-indexer-certs.yml run --rm generator

# Start
docker compose up -d
```

## Agent Deployment

### Linux agent (Debian/Ubuntu)

```bash
# Add Wazuh repository (on the agent host)
curl -s https://packages.wazuh.com/key/GPG-KEY-WAZUH | gpg --dearmor -o /usr/share/keyrings/wazuh.gpg
echo "deb [signed-by=/usr/share/keyrings/wazuh.gpg] https://packages.wazuh.com/4.x/apt/ stable main" \
  | sudo tee /etc/apt/sources.list.d/wazuh.list

sudo apt update
sudo apt install -y wazuh-agent

# Configure the agent
sudo sed -i 's/MANAGER_IP/<wazuh-manager-ip>/' /var/ossec/etc/ossec.conf

# Or set manager address directly
cat > /var/ossec/etc/ossec.conf.d/manager.conf << 'EOF'
<ossec_config>
  <client>
    <server>
      <address>192.168.1.100</address>
      <port>1514</port>
      <protocol>tcp</protocol>
    </server>
  </client>
</ossec_config>
EOF

# Start and enable
sudo systemctl daemon-reload
sudo systemctl enable --now wazuh-agent
```

### Linux agent (one-liner with auto-enrollment)

```bash
WAZUH_MANAGER="192.168.1.100" \
WAZUH_REGISTRATION_SERVER="192.168.1.100" \
WAZUH_AGENT_NAME="webserver01" \
WAZUH_AGENT_GROUP="linux,webservers" \
apt install -y wazuh-agent && systemctl enable --now wazuh-agent
```

### Windows agent

```powershell
# Download agent MSI from packages.wazuh.com
# Install with manager address
msiexec.exe /i wazuh-agent-4.9.0-1.msi /q `
  WAZUH_MANAGER="192.168.1.100" `
  WAZUH_AGENT_NAME="winserver01" `
  WAZUH_AGENT_GROUP="windows,servers"

# Start the service
net start WazuhSvc
```

### Manual agent registration

```bash
# On the manager — add agent
/var/ossec/bin/manage_agents -a <agent_ip> -n <agent_name>

# Extract key
/var/ossec/bin/manage_agents -e <agent_id>

# On the agent — import key
/var/ossec/bin/manage_agents -i <key_string>

# Restart agent
sudo systemctl restart wazuh-agent
```

## Agent Group Management

```bash
# Create a group
/var/ossec/bin/agent_groups -a -g webservers

# Assign agent to group
/var/ossec/bin/agent_groups -a -i <agent_id> -g webservers

# List groups
/var/ossec/bin/agent_groups -l

# List agents in a group
/var/ossec/bin/agent_groups -l -g webservers

# Group configuration is in:
# /var/ossec/etc/shared/<group_name>/agent.conf
```

## Configuration — Manager

### Main config file: `/var/ossec/etc/ossec.conf`

### Log collection

```xml
<!-- Collect syslog -->
<localfile>
  <log_format>syslog</log_format>
  <location>/var/log/syslog</location>
</localfile>

<!-- Collect auth logs -->
<localfile>
  <log_format>syslog</log_format>
  <location>/var/log/auth.log</location>
</localfile>

<!-- Collect JSON logs -->
<localfile>
  <log_format>json</log_format>
  <location>/var/log/myapp/app.json</location>
  <label key="app">myapp</label>
</localfile>

<!-- Windows Event Log (on Windows agents) -->
<localfile>
  <log_format>eventchannel</log_format>
  <location>Security</location>
</localfile>

<!-- Remote syslog from network devices -->
<remote>
  <connection>syslog</connection>
  <port>514</port>
  <protocol>tcp</protocol>
  <allowed-ips>192.168.1.0/24</allowed-ips>
</remote>
```

### File Integrity Monitoring (FIM)

```xml
<syscheck>
  <disabled>no</disabled>
  <frequency>43200</frequency>  <!-- 12 hours -->
  <scan_on_start>yes</scan_on_start>

  <!-- Directories to monitor -->
  <directories realtime="yes" check_all="yes">/etc,/usr/bin,/usr/sbin</directories>
  <directories realtime="yes" check_all="yes">/bin,/sbin</directories>
  <directories report_changes="yes" check_all="yes">/etc/passwd,/etc/shadow</directories>

  <!-- Directories to ignore -->
  <ignore>/etc/mtab</ignore>
  <ignore>/etc/resolv.conf</ignore>
  <ignore type="sregex">.log$</ignore>

  <!-- Windows paths (on Windows agents) -->
  <directories realtime="yes" check_all="yes">C:\Windows\System32</directories>
  <directories realtime="yes" check_all="yes">C:\Windows\SysWOW64</directories>

  <!-- Registry monitoring (Windows) -->
  <windows_registry>HKEY_LOCAL_MACHINE\Software\Microsoft\Windows\CurrentVersion\Run</windows_registry>
</syscheck>
```

### Vulnerability Detection

```xml
<vulnerability-detection>
  <enabled>yes</enabled>
  <index-status>yes</index-status>
  <feed-update-interval>60m</feed-update-interval>
</vulnerability-detection>
```

## Custom Rules

### Rule file location: `/var/ossec/etc/rules/local_rules.xml`

```xml
<group name="custom,">

  <!-- Alert on SSH brute force (5+ failed logins from same IP) -->
  <rule id="100001" level="10" frequency="5" timeframe="120">
    <if_matched_sid>5710</if_matched_sid>
    <same_source_ip />
    <description>SSH brute force attempt detected from $(srcip)</description>
    <mitre>
      <id>T1110</id>
    </mitre>
  </rule>

  <!-- Alert on new user creation -->
  <rule id="100002" level="8">
    <if_sid>5901</if_sid>
    <description>New user account created: $(dstuser)</description>
    <group>account_created,</group>
  </rule>

  <!-- Alert on sudo usage -->
  <rule id="100003" level="5">
    <if_sid>5401</if_sid>
    <description>Sudo command executed by $(srcuser)</description>
  </rule>

  <!-- Alert on file change in web directory -->
  <rule id="100004" level="7">
    <if_sid>550</if_sid>
    <field name="file">/var/www</field>
    <description>File modified in web directory: $(file)</description>
    <group>web,file_integrity,</group>
  </rule>

</group>
```

### Test rules with wazuh-logtest

```bash
# Interactive log testing
/var/ossec/bin/wazuh-logtest

# Paste a log line and see which rule matches
# Example input:
# Mar 23 10:15:30 server sshd[1234]: Failed password for root from 10.0.0.1 port 22 ssh2
```

## Custom Decoders

### Decoder file: `/var/ossec/etc/decoders/local_decoder.xml`

```xml
<decoder name="myapp">
  <prematch>^myapp: </prematch>
</decoder>

<decoder name="myapp-error">
  <parent>myapp</parent>
  <regex>ERROR user=(\S+) action=(\S+) from=(\S+)</regex>
  <order>dstuser,action,srcip</order>
</decoder>
```

## Wazuh API

```bash
# Authenticate (get JWT token)
TOKEN=$(curl -sk -u admin:SecretPassword \
  -X POST https://localhost:55000/security/user/authenticate \
  | python3 -c "import sys,json; print(json.load(sys.stdin)['data']['token'])")

# List agents
curl -sk -H "Authorization: Bearer $TOKEN" \
  https://localhost:55000/agents?pretty=true

# Get agent details
curl -sk -H "Authorization: Bearer $TOKEN" \
  https://localhost:55000/agents/<agent_id>?pretty=true

# Get manager info
curl -sk -H "Authorization: Bearer $TOKEN" \
  https://localhost:55000/manager/info?pretty=true

# Get active alerts (last hour)
curl -sk -H "Authorization: Bearer $TOKEN" \
  "https://localhost:55000/alerts?pretty=true&limit=20&sort=-timestamp"

# Restart manager
curl -sk -H "Authorization: Bearer $TOKEN" \
  -X PUT https://localhost:55000/manager/restart

# Get vulnerability inventory for an agent
curl -sk -H "Authorization: Bearer $TOKEN" \
  "https://localhost:55000/vulnerability/<agent_id>?pretty=true&limit=20"

# Get FIM events
curl -sk -H "Authorization: Bearer $TOKEN" \
  "https://localhost:55000/syscheck/<agent_id>?pretty=true&limit=20"
```

## Compliance Checking

### PCI-DSS

```xml
<!-- Enable PCI-DSS mapping in ossec.conf -->
<ruleset>
  <rule_dir>ruleset/rules</rule_dir>
  <decoder_dir>ruleset/decoders</decoder_dir>
</ruleset>

<!-- PCI-DSS rules are built-in — they map to:
  - Req 1: Firewall configuration
  - Req 2: Default passwords
  - Req 5: Malware protection
  - Req 6: Secure systems
  - Req 8: Authentication
  - Req 10: Logging & monitoring
  - Req 11: Security testing
-->
```

### CIS Benchmarks (via SCA)

```xml
<!-- Security Configuration Assessment in ossec.conf -->
<sca>
  <enabled>yes</enabled>
  <scan_on_start>yes</scan_on_start>
  <interval>12h</interval>

  <!-- Built-in policies -->
  <policies>
    <policy>cis_ubuntu22-04.yml</policy>
    <policy>cis_debian12.yml</policy>
    <policy>cis_rhel9.yml</policy>
  </policies>
</sca>
```

### Available compliance frameworks

| Framework | Coverage |
|-----------|----------|
| PCI-DSS | Payment card industry requirements |
| HIPAA | Healthcare data protection |
| GDPR | EU data privacy regulation |
| NIST 800-53 | Federal security controls |
| TSC (SOC 2) | Trust services criteria |
| CIS Benchmarks | OS and application hardening |

## Firewall Configuration

```bash
# Allow agent communication
sudo ufw allow 1514/tcp comment "Wazuh agent comms"

# Allow agent enrollment
sudo ufw allow 1515/tcp comment "Wazuh agent enrollment"

# Allow Wazuh API
sudo ufw allow 55000/tcp comment "Wazuh API"

# Allow Wazuh dashboard
sudo ufw allow 443/tcp comment "Wazuh Dashboard"

# Allow indexer (only if accessed externally)
sudo ufw allow 9200/tcp comment "Wazuh Indexer API"
```

## Troubleshooting

```bash
# Check all Wazuh services
sudo systemctl status wazuh-manager wazuh-indexer wazuh-dashboard

# Manager logs
tail -100 /var/ossec/logs/ossec.log
tail -100 /var/ossec/logs/alerts/alerts.json

# Agent connection issues
# On manager:
/var/ossec/bin/agent_control -l     # List agents and status
cat /var/ossec/logs/ossec.log | grep -i "agent"

# On agent:
cat /var/ossec/logs/ossec.log | grep -i "manager\|connect\|error"

# Test configuration
/var/ossec/bin/wazuh-analysisd -t

# Indexer health
curl -sk -u admin:admin https://localhost:9200/_cluster/health?pretty

# Indexer disk usage
curl -sk -u admin:admin https://localhost:9200/_cat/indices?v&h=index,store.size,docs.count

# Dashboard not loading
sudo journalctl -u wazuh-dashboard --since "30 min ago"
cat /usr/share/wazuh-dashboard/data/wazuh/logs/wazuhapp.log

# Agent not connecting
# 1. Check manager IP in agent config
grep "<address>" /var/ossec/etc/ossec.conf
# 2. Test connectivity
nc -zv <manager-ip> 1514
# 3. Check firewall on manager
sudo ufw status | grep 1514

# High CPU from FIM
# Reduce monitored directories or increase scan interval
grep -A5 "syscheck" /var/ossec/etc/ossec.conf

# Reset admin password (all-in-one install)
# The password is stored in wazuh-install-files.tar
sudo tar -xf wazuh-install-files.tar ./wazuh-install-files/wazuh-passwords.txt
cat wazuh-install-files/wazuh-passwords.txt
```
