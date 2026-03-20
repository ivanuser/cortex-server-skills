# Prometheus — Monitoring & Alerting

> Install, configure, and manage Prometheus for metrics collection, alerting, and monitoring. Covers scrape configuration, targets, Alertmanager, recording rules, PromQL, and exporters.

## Safety Rules

- **Prometheus stores data locally** — disk fills up if retention isn't configured.
- Don't scrape targets too frequently (<5s) — it overloads both Prometheus and targets.
- Recording rules can amplify cardinality — test before production.
- Alert routing mistakes mean missed pages — always test alertmanager config.
- Prometheus is not for long-term storage (>30d) — use Thanos or Cortex for that.
- Relabeling mistakes can drop all metrics — validate config before reload.

## Quick Reference

```bash
# Install (binary — latest)
PROM_VERSION="2.53.0"
wget "https://github.com/prometheus/prometheus/releases/download/v${PROM_VERSION}/prometheus-${PROM_VERSION}.linux-amd64.tar.gz"
tar xzf prometheus-${PROM_VERSION}.linux-amd64.tar.gz
sudo mv prometheus-${PROM_VERSION}.linux-amd64/{prometheus,promtool} /usr/local/bin/
sudo mkdir -p /etc/prometheus /var/lib/prometheus

# Install via apt (community packages)
sudo apt install -y prometheus

# Service management (if using systemd — see below)
sudo systemctl enable --now prometheus
sudo systemctl status prometheus
sudo systemctl reload prometheus       # Graceful config reload

# Quick test
curl -s http://localhost:9090/-/healthy
curl -s http://localhost:9090/api/v1/status/config | jq .

# Validate config
promtool check config /etc/prometheus/prometheus.yml
promtool check rules /etc/prometheus/rules/*.yml

# Reload config without restart
curl -X POST http://localhost:9090/-/reload
# Or: kill -HUP $(pgrep prometheus)

# Web UI: http://localhost:9090
```

### Systemd Service

```bash
cat <<'EOF' | sudo tee /etc/systemd/system/prometheus.service
[Unit]
Description=Prometheus
Wants=network-online.target
After=network-online.target

[Service]
User=prometheus
Group=prometheus
Type=simple
ExecStart=/usr/local/bin/prometheus \
  --config.file=/etc/prometheus/prometheus.yml \
  --storage.tsdb.path=/var/lib/prometheus \
  --storage.tsdb.retention.time=30d \
  --storage.tsdb.retention.size=50GB \
  --web.listen-address=0.0.0.0:9090 \
  --web.enable-lifecycle \
  --web.enable-admin-api
ExecReload=/bin/kill -HUP $MAINPID
Restart=always

[Install]
WantedBy=multi-user.target
EOF

sudo useradd --no-create-home --shell /bin/false prometheus
sudo chown -R prometheus:prometheus /etc/prometheus /var/lib/prometheus
sudo systemctl daemon-reload && sudo systemctl enable --now prometheus
```

## Configuration

### `/etc/prometheus/prometheus.yml`

```yaml
global:
  scrape_interval: 15s                 # Default scrape frequency
  evaluation_interval: 15s             # Rule evaluation frequency
  scrape_timeout: 10s
  external_labels:
    cluster: production
    region: us-east-1

# Alertmanager targets
alerting:
  alertmanagers:
    - static_configs:
        - targets: ['localhost:9093']

# Rule files
rule_files:
  - /etc/prometheus/rules/*.yml

# Scrape configs
scrape_configs:
  # Prometheus itself
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  # Node Exporter (system metrics)
  - job_name: 'node'
    static_configs:
      - targets:
          - '10.0.0.1:9100'
          - '10.0.0.2:9100'
          - '10.0.0.3:9100'
        labels:
          env: production

  # Application metrics
  - job_name: 'myapp'
    metrics_path: /metrics
    scheme: https
    tls_config:
      insecure_skip_verify: true
    static_configs:
      - targets: ['app1:8080', 'app2:8080']

  # File-based service discovery
  - job_name: 'dynamic'
    file_sd_configs:
      - files:
          - /etc/prometheus/targets/*.json
        refresh_interval: 30s

  # Docker service discovery
  - job_name: 'docker'
    docker_sd_configs:
      - host: unix:///var/run/docker.sock
    relabel_configs:
      - source_labels: [__meta_docker_container_name]
        target_label: container
```

### File-Based Service Discovery

```json
// /etc/prometheus/targets/webservers.json
[
  {
    "targets": ["10.0.0.1:9100", "10.0.0.2:9100"],
    "labels": {
      "env": "production",
      "role": "webserver"
    }
  }
]
```

## PromQL — Query Basics

```promql
# Instant vector (current values)
up                                     # Is target up? (1=yes, 0=no)
node_cpu_seconds_total                 # CPU time
http_requests_total                    # Total HTTP requests

# Filtering by label
http_requests_total{method="GET"}
http_requests_total{status=~"5.."}     # Regex match (5xx errors)
http_requests_total{job!="test"}       # Not equal

# Range vector (values over time)
http_requests_total[5m]                # Last 5 minutes of samples

# Rate (per-second rate of counter increase)
rate(http_requests_total[5m])          # Requests per second
irate(http_requests_total[5m])         # Instant rate (last 2 samples)

# Aggregations
sum(rate(http_requests_total[5m]))                          # Total RPS
sum by (method)(rate(http_requests_total[5m]))              # RPS per method
avg by (instance)(rate(node_cpu_seconds_total{mode!="idle"}[5m])) # CPU per host

# Histogram quantiles
histogram_quantile(0.99, rate(http_request_duration_seconds_bucket[5m]))   # p99 latency
histogram_quantile(0.50, rate(http_request_duration_seconds_bucket[5m]))   # p50 (median)

# Math
(node_memory_MemTotal_bytes - node_memory_MemAvailable_bytes) / node_memory_MemTotal_bytes * 100
# → Memory usage percentage

# Predict disk full in 4 hours
predict_linear(node_filesystem_avail_bytes{mountpoint="/"}[1h], 4*3600) < 0

# Top 5 by CPU usage
topk(5, rate(node_cpu_seconds_total{mode!="idle"}[5m]))

# Count instances
count(up == 1)                         # Healthy instances
count by (job)(up)                     # Instances per job
```

## Recording Rules

```yaml
# /etc/prometheus/rules/recording.yml
groups:
  - name: node_rules
    interval: 15s
    rules:
      - record: instance:node_cpu_utilisation:rate5m
        expr: |
          1 - avg by (instance) (
            rate(node_cpu_seconds_total{mode="idle"}[5m])
          )

      - record: instance:node_memory_utilisation:ratio
        expr: |
          (node_memory_MemTotal_bytes - node_memory_MemAvailable_bytes)
          / node_memory_MemTotal_bytes

      - record: job:http_requests:rate5m
        expr: sum by (job)(rate(http_requests_total[5m]))
```

## Alerting Rules

```yaml
# /etc/prometheus/rules/alerts.yml
groups:
  - name: critical_alerts
    rules:
      - alert: InstanceDown
        expr: up == 0
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "Instance {{ $labels.instance }} down"
          description: "{{ $labels.instance }} of job {{ $labels.job }} has been down for more than 5 minutes."

      - alert: HighCPU
        expr: instance:node_cpu_utilisation:rate5m > 0.9
        for: 10m
        labels:
          severity: warning
        annotations:
          summary: "High CPU on {{ $labels.instance }}"
          description: "CPU usage is {{ humanize $value }}%"

      - alert: DiskSpaceLow
        expr: |
          (node_filesystem_avail_bytes{mountpoint="/"} / node_filesystem_size_bytes{mountpoint="/"}) < 0.1
        for: 15m
        labels:
          severity: critical
        annotations:
          summary: "Disk space < 10% on {{ $labels.instance }}"

      - alert: HighErrorRate
        expr: |
          sum(rate(http_requests_total{status=~"5.."}[5m]))
          / sum(rate(http_requests_total[5m])) > 0.05
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "Error rate > 5%"
```

## Alertmanager

```bash
# Install
ALERT_VERSION="0.27.0"
wget "https://github.com/prometheus/alertmanager/releases/download/v${ALERT_VERSION}/alertmanager-${ALERT_VERSION}.linux-amd64.tar.gz"
tar xzf alertmanager-${ALERT_VERSION}.linux-amd64.tar.gz
sudo mv alertmanager-${ALERT_VERSION}.linux-amd64/{alertmanager,amtool} /usr/local/bin/
sudo mkdir -p /etc/alertmanager

# UI: http://localhost:9093
```

### `/etc/alertmanager/alertmanager.yml`

```yaml
global:
  smtp_smarthost: 'smtp.gmail.com:587'
  smtp_from: 'alerts@example.com'
  smtp_auth_username: 'alerts@example.com'
  smtp_auth_password: 'app_password'

route:
  receiver: 'default'
  group_by: ['alertname', 'instance']
  group_wait: 30s
  group_interval: 5m
  repeat_interval: 4h

  routes:
    - match:
        severity: critical
      receiver: 'pagerduty'
      repeat_interval: 1h

    - match:
        severity: warning
      receiver: 'slack'

receivers:
  - name: 'default'
    email_configs:
      - to: 'oncall@example.com'

  - name: 'slack'
    slack_configs:
      - api_url: 'https://hooks.slack.com/services/xxx/yyy/zzz'
        channel: '#alerts'
        title: '{{ .GroupLabels.alertname }}'
        text: '{{ range .Alerts }}{{ .Annotations.description }}{{ end }}'

  - name: 'pagerduty'
    pagerduty_configs:
      - service_key: 'your-pagerduty-key'

inhibit_rules:
  - source_match:
      severity: 'critical'
    target_match:
      severity: 'warning'
    equal: ['alertname', 'instance']
```

```bash
# Validate alertmanager config
amtool check-config /etc/alertmanager/alertmanager.yml

# Manage silences
amtool silence add alertname=HighCPU instance="web1:9100" --duration=2h --comment="Maintenance"
amtool silence query
amtool silence expire <silence-id>

# Test alert routing
amtool config routes test --config.file=/etc/alertmanager/alertmanager.yml severity=critical
```

## Common Exporters

```bash
# Node Exporter (system metrics) — install on every host
NODE_VERSION="1.8.0"
wget "https://github.com/prometheus/node_exporter/releases/download/v${NODE_VERSION}/node_exporter-${NODE_VERSION}.linux-amd64.tar.gz"
tar xzf node_exporter-${NODE_VERSION}.linux-amd64.tar.gz
sudo mv node_exporter-${NODE_VERSION}.linux-amd64/node_exporter /usr/local/bin/
# Listens on :9100/metrics

# Blackbox Exporter (probe HTTP/TCP/ICMP)
# Port: 9115

# MySQL Exporter — port 9104
# PostgreSQL Exporter — port 9187
# Redis Exporter — port 9121
# Nginx Exporter — port 9113
```

## Troubleshooting

```bash
# Check config
promtool check config /etc/prometheus/prometheus.yml

# Check targets
curl -s http://localhost:9090/api/v1/targets | jq '.data.activeTargets[] | {job: .labels.job, instance: .labels.instance, health: .health}'

# Scrape errors
curl -s http://localhost:9090/api/v1/targets | jq '.data.activeTargets[] | select(.health=="down")'

# TSDB status (cardinality, memory)
curl -s http://localhost:9090/api/v1/status/tsdb | jq .

# Disk usage
du -sh /var/lib/prometheus/

# High cardinality (too many time series)
curl -s http://localhost:9090/api/v1/status/tsdb | jq '.data.seriesCountByMetricName[:10]'

# Logs
sudo journalctl -u prometheus --no-pager -n 50

# Query API
curl -s 'http://localhost:9090/api/v1/query?query=up' | jq .
curl -s 'http://localhost:9090/api/v1/query_range?query=rate(http_requests_total[5m])&start=2026-03-20T00:00:00Z&end=2026-03-20T12:00:00Z&step=60s' | jq .
```
