# Grafana — Observability & Dashboards

> Install, configure, and manage Grafana for data visualization, dashboards, and alerting. Covers data sources, dashboard provisioning, alerts, plugins, and API usage.

## Safety Rules

- Change the default admin password immediately after install.
- Don't expose Grafana directly to the internet without authentication and HTTPS.
- API keys and service accounts have full access — treat them as secrets.
- Dashboard provisioning overwrites manual changes — use provisioned OR manual, not both.
- Test alert notification channels before relying on them.

## Quick Reference

```bash
# Install (Ubuntu/Debian — official repo)
sudo apt install -y apt-transport-https software-properties-common wget
wget -q -O - https://apt.grafana.com/gpg.key | \
  sudo gpg --dearmor -o /usr/share/keyrings/grafana.gpg
echo "deb [signed-by=/usr/share/keyrings/grafana.gpg] https://apt.grafana.com stable main" | \
  sudo tee /etc/apt/sources.list.d/grafana.list
sudo apt update && sudo apt install -y grafana

# Install (RHEL/Rocky)
cat <<'EOF' | sudo tee /etc/yum.repos.d/grafana.repo
[grafana]
name=grafana
baseurl=https://rpm.grafana.com
repo_gpgcheck=1
enabled=1
gpgcheck=1
gpgkey=https://rpm.grafana.com/gpg.key
sslverify=1
EOF
sudo dnf install -y grafana

# Service management
sudo systemctl enable --now grafana-server
sudo systemctl status grafana-server
sudo systemctl restart grafana-server

# Web UI: http://localhost:3000
# Default login: admin / admin (change immediately!)

# Reset admin password
sudo grafana-cli admin reset-admin-password new_password
```

## Configuration

### `/etc/grafana/grafana.ini`

```ini
[server]
http_addr = 0.0.0.0
http_port = 3000
domain = grafana.example.com
root_url = https://grafana.example.com/
serve_from_sub_path = false

[database]
type = sqlite3
path = grafana.db
# For production: use PostgreSQL or MySQL
# type = postgres
# host = localhost:5432
# name = grafana
# user = grafana
# password = secret

[security]
admin_user = admin
admin_password = strong_password
secret_key = your_secret_key_here
disable_gravatar = true
cookie_secure = true
cookie_samesite = strict

[users]
allow_sign_up = false
allow_org_create = false
auto_assign_org = true
auto_assign_org_role = Viewer

[auth.anonymous]
enabled = false

[smtp]
enabled = true
host = smtp.gmail.com:587
user = alerts@example.com
password = app_password
from_address = alerts@example.com
from_name = Grafana

[log]
mode = console file
level = info
```

## Data Sources

### Add via UI: Configuration → Data Sources → Add

### Add via API

```bash
# Prometheus data source
curl -X POST http://admin:password@localhost:3000/api/datasources \
  -H 'Content-Type: application/json' \
  -d '{
    "name": "Prometheus",
    "type": "prometheus",
    "url": "http://localhost:9090",
    "access": "proxy",
    "isDefault": true
  }'

# PostgreSQL
curl -X POST http://admin:password@localhost:3000/api/datasources \
  -H 'Content-Type: application/json' \
  -d '{
    "name": "PostgreSQL",
    "type": "postgres",
    "url": "localhost:5432",
    "database": "myapp",
    "user": "grafana",
    "secureJsonData": { "password": "db_password" },
    "jsonData": { "sslmode": "disable", "postgresVersion": 1500 }
  }'

# Elasticsearch
curl -X POST http://admin:password@localhost:3000/api/datasources \
  -H 'Content-Type: application/json' \
  -d '{
    "name": "Elasticsearch",
    "type": "elasticsearch",
    "url": "http://localhost:9200",
    "database": "logs-*",
    "jsonData": {
      "esVersion": "8.0.0",
      "timeField": "@timestamp",
      "logMessageField": "message",
      "logLevelField": "level"
    }
  }'

# List data sources
curl -s http://admin:password@localhost:3000/api/datasources | jq '.[].name'
```

## Dashboard Provisioning

### File-Based Provisioning

```yaml
# /etc/grafana/provisioning/datasources/prometheus.yml
apiVersion: 1
datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://localhost:9090
    isDefault: true
    editable: false
```

```yaml
# /etc/grafana/provisioning/dashboards/default.yml
apiVersion: 1
providers:
  - name: default
    orgId: 1
    folder: ''
    type: file
    disableDeletion: false
    updateIntervalSeconds: 30
    options:
      path: /var/lib/grafana/dashboards
      foldersFromFilesStructure: true
```

```bash
# Place dashboard JSON files in the provisioned path
sudo mkdir -p /var/lib/grafana/dashboards
# Copy exported dashboard JSONs here
```

### Export & Import Dashboards

```bash
# Export dashboard via API
DASHBOARD_UID="abc123"
curl -s "http://admin:password@localhost:3000/api/dashboards/uid/${DASHBOARD_UID}" | \
  jq '.dashboard' > dashboard.json

# Import dashboard via API
curl -X POST http://admin:password@localhost:3000/api/dashboards/db \
  -H 'Content-Type: application/json' \
  -d "{
    \"dashboard\": $(cat dashboard.json),
    \"overwrite\": true,
    \"folderId\": 0
  }"

# Import from Grafana.com (community dashboards)
curl -X POST http://admin:password@localhost:3000/api/dashboards/import \
  -H 'Content-Type: application/json' \
  -d '{
    "dashboard": { "id": null },
    "overwrite": true,
    "inputs": [{ "name": "DS_PROMETHEUS", "type": "datasource", "pluginId": "prometheus", "value": "Prometheus" }],
    "pluginId": "prometheus",
    "folderId": 0,
    "dashboardId": 1860
  }'
# Dashboard 1860 = Node Exporter Full
# Dashboard 3662 = Prometheus 2.0 Stats
# Dashboard 763  = Redis Dashboard
```

## Alerts

### Grafana Alerting (Unified Alerting — Grafana 9+)

```bash
# Create alert rule via API
curl -X POST http://admin:password@localhost:3000/api/v1/provisioning/alert-rules \
  -H 'Content-Type: application/json' \
  -d '{
    "title": "High CPU Alert",
    "condition": "C",
    "data": [
      {
        "refId": "A",
        "queryType": "",
        "datasourceUid": "prometheus-uid",
        "model": {
          "expr": "instance:node_cpu_utilisation:rate5m",
          "refId": "A"
        }
      },
      {
        "refId": "C",
        "queryType": "",
        "datasourceUid": "-100",
        "model": {
          "type": "threshold",
          "conditions": [{
            "evaluator": { "type": "gt", "params": [0.9] }
          }],
          "refId": "C"
        }
      }
    ],
    "for": "5m",
    "folderUID": "alerts"
  }'

# Contact points (notification channels)
curl -X POST http://admin:password@localhost:3000/api/v1/provisioning/contact-points \
  -H 'Content-Type: application/json' \
  -d '{
    "name": "Slack Alerts",
    "type": "slack",
    "settings": {
      "url": "https://hooks.slack.com/services/xxx/yyy/zzz",
      "recipient": "#alerts"
    }
  }'

# List alert rules
curl -s http://admin:password@localhost:3000/api/v1/provisioning/alert-rules | jq '.[].title'
```

## Plugins

```bash
# List installed plugins
sudo grafana-cli plugins ls

# Install plugin
sudo grafana-cli plugins install grafana-clock-panel
sudo grafana-cli plugins install grafana-piechart-panel
sudo grafana-cli plugins install grafana-worldmap-panel
sudo grafana-cli plugins install alexanderzobnin-zabbix-app
sudo grafana-cli plugins install redis-datasource

# Install specific version
sudo grafana-cli plugins install grafana-clock-panel 2.1.0

# Update all plugins
sudo grafana-cli plugins update-all

# Remove plugin
sudo grafana-cli plugins remove grafana-clock-panel

# Restart after plugin changes
sudo systemctl restart grafana-server
```

## API Reference

```bash
# Authentication — use API key or basic auth
# Create API key: Configuration → API Keys → Add

# With API key
curl -s -H "Authorization: Bearer eyJrIjoi..." http://localhost:3000/api/org

# Organizations
curl -s http://admin:password@localhost:3000/api/org | jq .

# Users
curl -s http://admin:password@localhost:3000/api/org/users | jq .

# Create user
curl -X POST http://admin:password@localhost:3000/api/admin/users \
  -H 'Content-Type: application/json' \
  -d '{"name":"Ivan","email":"ivan@example.com","login":"ivan","password":"password","OrgId":1}'

# Folders
curl -s http://admin:password@localhost:3000/api/folders | jq .

# Create folder
curl -X POST http://admin:password@localhost:3000/api/folders \
  -H 'Content-Type: application/json' \
  -d '{"title": "Infrastructure"}'

# Search dashboards
curl -s "http://admin:password@localhost:3000/api/search?query=node" | jq '.[].title'

# Annotations (mark events on dashboards)
curl -X POST http://admin:password@localhost:3000/api/annotations \
  -H 'Content-Type: application/json' \
  -d "{
    \"text\": \"Deployment v2.1.0\",
    \"tags\": [\"deploy\"],
    \"time\": $(date +%s)000
  }"

# Health check
curl -s http://localhost:3000/api/health | jq .
```

## Troubleshooting

```bash
# Grafana won't start
sudo journalctl -u grafana-server --no-pager -n 50
sudo cat /var/log/grafana/grafana.log | tail -100

# Reset admin password
sudo grafana-cli admin reset-admin-password newpassword

# Database locked (SQLite)
sudo systemctl stop grafana-server
sudo sqlite3 /var/lib/grafana/grafana.db "PRAGMA integrity_check;"
sudo systemctl start grafana-server

# Plugin issues
sudo grafana-cli plugins ls
ls -la /var/lib/grafana/plugins/

# Data source connection test
# UI: Configuration → Data Sources → Test
# Or check Grafana logs for connection errors

# Dashboard not loading
# Check browser console for errors
# Verify data source is configured and working

# Permission issues
sudo chown -R grafana:grafana /var/lib/grafana
sudo chmod 640 /etc/grafana/grafana.ini

# Port already in use
sudo ss -tlnp | grep 3000
```
