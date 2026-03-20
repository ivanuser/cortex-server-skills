# Elasticsearch — Search & Analytics Engine

> Install, configure, and manage Elasticsearch for full-text search, log analytics, and real-time data indexing. Covers indices, mappings, cluster health, snapshots, ILM, and Kibana setup.

## Safety Rules

- **Deleting an index is irreversible** — always snapshot before deletion.
- Never set `discovery.type: single-node` in production multi-node clusters.
- Set `action.destructive_requires_name: true` to prevent wildcard index deletes.
- Allocate no more than 50% of RAM to JVM heap (`-Xms` and `-Xmx` must be equal).
- Never exceed 31GB heap — JVM compressed oops optimization breaks above that.
- Disable swapping: `bootstrap.memory_lock: true` or `swapoff -a`.

## Quick Reference

```bash
# Install (Ubuntu/Debian — Elasticsearch 8.x)
wget -qO - https://artifacts.elastic.co/GPG-KEY-elasticsearch | \
  sudo gpg --dearmor -o /usr/share/keyrings/elasticsearch-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/elasticsearch-keyring.gpg] https://artifacts.elastic.co/packages/8.x/apt stable main" | \
  sudo tee /etc/apt/sources.list.d/elastic-8.x.list
sudo apt update && sudo apt install -y elasticsearch

# Install (RHEL/Rocky)
sudo rpm --import https://artifacts.elastic.co/GPG-KEY-elasticsearch
cat <<'EOF' | sudo tee /etc/yum.repos.d/elasticsearch.repo
[elasticsearch]
name=Elasticsearch repository for 8.x packages
baseurl=https://artifacts.elastic.co/packages/8.x/yum
gpgcheck=1
gpgkey=https://artifacts.elastic.co/GPG-KEY-elasticsearch
enabled=1
autorefresh=1
type=rpm-md
EOF
sudo dnf install -y elasticsearch

# Service management
sudo systemctl daemon-reload
sudo systemctl enable --now elasticsearch
sudo systemctl status elasticsearch

# Quick health check
curl -s http://localhost:9200/
curl -s http://localhost:9200/_cluster/health?pretty
curl -s http://localhost:9200/_cat/nodes?v
curl -s http://localhost:9200/_cat/indices?v

# With security enabled (default in 8.x)
curl -s -k -u elastic:password https://localhost:9200/
```

## Configuration

### Essential `/etc/elasticsearch/elasticsearch.yml`

```yaml
# Cluster
cluster.name: my-cluster
node.name: node-1
node.roles: [master, data, ingest]

# Network
network.host: 0.0.0.0
http.port: 9200
transport.port: 9300

# Discovery
discovery.seed_hosts: ["node1:9300", "node2:9300", "node3:9300"]
cluster.initial_master_nodes: ["node-1", "node-2", "node-3"]
# For single-node dev:
# discovery.type: single-node

# Paths
path.data: /var/lib/elasticsearch
path.logs: /var/log/elasticsearch

# Memory
bootstrap.memory_lock: true

# Security (8.x default: enabled)
xpack.security.enabled: true
xpack.security.transport.ssl.enabled: true
xpack.security.http.ssl.enabled: false     # Set true for HTTPS API
```

### JVM Heap — `/etc/elasticsearch/jvm.options.d/heap.options`

```
-Xms4g
-Xmx4g
```

```bash
# Allow memory lock (systemd override)
sudo mkdir -p /etc/systemd/system/elasticsearch.service.d
cat <<'EOF' | sudo tee /etc/systemd/system/elasticsearch.service.d/override.conf
[Service]
LimitMEMLOCK=infinity
EOF
sudo systemctl daemon-reload && sudo systemctl restart elasticsearch
```

## Index Operations

```bash
# Create index with settings
curl -X PUT "localhost:9200/my-index" -H 'Content-Type: application/json' -d '{
  "settings": {
    "number_of_shards": 3,
    "number_of_replicas": 1,
    "refresh_interval": "5s"
  }
}'

# Create index with mapping
curl -X PUT "localhost:9200/logs" -H 'Content-Type: application/json' -d '{
  "mappings": {
    "properties": {
      "timestamp": { "type": "date" },
      "message": { "type": "text" },
      "level": { "type": "keyword" },
      "host": { "type": "keyword" },
      "response_time": { "type": "float" }
    }
  }
}'

# List indices
curl -s "localhost:9200/_cat/indices?v&s=index"

# Get mapping
curl -s "localhost:9200/my-index/_mapping?pretty"

# Get settings
curl -s "localhost:9200/my-index/_settings?pretty"

# Delete index
curl -X DELETE "localhost:9200/my-index"

# Close/open index (save resources)
curl -X POST "localhost:9200/my-index/_close"
curl -X POST "localhost:9200/my-index/_open"

# Index aliases
curl -X POST "localhost:9200/_aliases" -H 'Content-Type: application/json' -d '{
  "actions": [
    { "add": { "index": "logs-2026-03", "alias": "logs-current" } },
    { "remove": { "index": "logs-2026-02", "alias": "logs-current" } }
  ]
}'
```

## Documents — CRUD

```bash
# Index a document (auto-generate ID)
curl -X POST "localhost:9200/my-index/_doc" -H 'Content-Type: application/json' -d '{
  "title": "Hello World",
  "timestamp": "2026-03-20T12:00:00Z"
}'

# Index with specific ID
curl -X PUT "localhost:9200/my-index/_doc/1" -H 'Content-Type: application/json' -d '{
  "title": "First Document"
}'

# Get document
curl -s "localhost:9200/my-index/_doc/1?pretty"

# Search
curl -s "localhost:9200/my-index/_search?q=hello&pretty"

# Search with query DSL
curl -s "localhost:9200/my-index/_search?pretty" -H 'Content-Type: application/json' -d '{
  "query": {
    "bool": {
      "must": [{ "match": { "message": "error" } }],
      "filter": [
        { "term": { "level": "ERROR" } },
        { "range": { "timestamp": { "gte": "now-1h" } } }
      ]
    }
  },
  "size": 20,
  "sort": [{ "timestamp": "desc" }]
}'

# Bulk index
curl -X POST "localhost:9200/_bulk" -H 'Content-Type: application/x-ndjson' -d '
{"index": {"_index": "my-index"}}
{"title": "Doc 1", "timestamp": "2026-03-20T12:00:00Z"}
{"index": {"_index": "my-index"}}
{"title": "Doc 2", "timestamp": "2026-03-20T13:00:00Z"}
'

# Delete document
curl -X DELETE "localhost:9200/my-index/_doc/1"

# Delete by query
curl -X POST "localhost:9200/my-index/_delete_by_query" -H 'Content-Type: application/json' -d '{
  "query": { "range": { "timestamp": { "lt": "now-30d" } } }
}'

# Reindex
curl -X POST "localhost:9200/_reindex" -H 'Content-Type: application/json' -d '{
  "source": { "index": "old-index" },
  "dest": { "index": "new-index" }
}'
```

## Index Lifecycle Management (ILM)

```bash
# Create ILM policy
curl -X PUT "localhost:9200/_ilm/policy/logs-policy" -H 'Content-Type: application/json' -d '{
  "policy": {
    "phases": {
      "hot": {
        "min_age": "0ms",
        "actions": {
          "rollover": { "max_age": "7d", "max_primary_shard_size": "50gb" },
          "set_priority": { "priority": 100 }
        }
      },
      "warm": {
        "min_age": "30d",
        "actions": {
          "shrink": { "number_of_shards": 1 },
          "forcemerge": { "max_num_segments": 1 },
          "set_priority": { "priority": 50 }
        }
      },
      "cold": {
        "min_age": "90d",
        "actions": {
          "set_priority": { "priority": 0 }
        }
      },
      "delete": {
        "min_age": "365d",
        "actions": { "delete": {} }
      }
    }
  }
}'

# Apply policy to index template
curl -X PUT "localhost:9200/_index_template/logs-template" -H 'Content-Type: application/json' -d '{
  "index_patterns": ["logs-*"],
  "template": {
    "settings": {
      "index.lifecycle.name": "logs-policy",
      "index.lifecycle.rollover_alias": "logs"
    }
  }
}'

# Check ILM status
curl -s "localhost:9200/_ilm/status?pretty"
curl -s "localhost:9200/logs-*/_ilm/explain?pretty"
```

## Snapshots & Backup

```bash
# Register snapshot repository (filesystem)
curl -X PUT "localhost:9200/_snapshot/my-backups" -H 'Content-Type: application/json' -d '{
  "type": "fs",
  "settings": { "location": "/mnt/es-backups", "compress": true }
}'
# Note: path.repo must be set in elasticsearch.yml

# Create snapshot
curl -X PUT "localhost:9200/_snapshot/my-backups/snap-$(date +%Y%m%d)?wait_for_completion=true"

# Snapshot specific indices
curl -X PUT "localhost:9200/_snapshot/my-backups/snap-logs" -H 'Content-Type: application/json' -d '{
  "indices": "logs-*",
  "ignore_unavailable": true,
  "include_global_state": false
}'

# List snapshots
curl -s "localhost:9200/_snapshot/my-backups/_all?pretty"

# Restore snapshot
curl -X POST "localhost:9200/_snapshot/my-backups/snap-20260320/_restore" -H 'Content-Type: application/json' -d '{
  "indices": "logs-*",
  "rename_pattern": "(.+)",
  "rename_replacement": "restored-$1"
}'

# Delete snapshot
curl -X DELETE "localhost:9200/_snapshot/my-backups/snap-20260320"
```

## Cluster Health & Management

```bash
# Cluster overview
curl -s "localhost:9200/_cluster/health?pretty"
curl -s "localhost:9200/_cat/nodes?v&h=name,ip,heap.percent,ram.percent,cpu,load_1m,node.role"
curl -s "localhost:9200/_cat/shards?v&s=state"
curl -s "localhost:9200/_cat/allocation?v"

# Unassigned shards (diagnose yellow/red)
curl -s "localhost:9200/_cat/shards?v&h=index,shard,prirep,state,unassigned.reason&s=state"
curl -s "localhost:9200/_cluster/allocation/explain?pretty"

# Cluster settings
curl -s "localhost:9200/_cluster/settings?pretty&include_defaults=true"

# Exclude node from allocation (for maintenance)
curl -X PUT "localhost:9200/_cluster/settings" -H 'Content-Type: application/json' -d '{
  "persistent": { "cluster.routing.allocation.exclude._name": "node-3" }
}'

# Re-enable allocation
curl -X PUT "localhost:9200/_cluster/settings" -H 'Content-Type: application/json' -d '{
  "persistent": { "cluster.routing.allocation.exclude._name": "" }
}'

# Thread pool stats
curl -s "localhost:9200/_cat/thread_pool?v&h=node_name,name,active,rejected,completed"
```

## Kibana Setup

```bash
# Install Kibana
sudo apt install -y kibana             # Same elastic repo

# Config: /etc/kibana/kibana.yml
# server.port: 5601
# server.host: "0.0.0.0"
# elasticsearch.hosts: ["http://localhost:9200"]
# elasticsearch.username: "kibana_system"
# elasticsearch.password: "password"

sudo systemctl enable --now kibana

# Generate enrollment token (ES 8.x)
sudo /usr/share/elasticsearch/bin/elasticsearch-create-enrollment-token -s kibana

# Reset kibana_system password
sudo /usr/share/elasticsearch/bin/elasticsearch-reset-password -u kibana_system
```

## Troubleshooting

```bash
# Elasticsearch won't start
sudo journalctl -u elasticsearch --no-pager -n 50
sudo cat /var/log/elasticsearch/my-cluster.log | tail -100

# Out of disk space — read-only mode
curl -X PUT "localhost:9200/_all/_settings" -H 'Content-Type: application/json' -d '{
  "index.blocks.read_only_allow_delete": null
}'

# JVM heap issues
curl -s "localhost:9200/_nodes/stats/jvm?pretty" | grep -A5 heap

# Circuit breaker tripped
curl -s "localhost:9200/_nodes/stats/breaker?pretty"

# Slow queries — enable slow log
curl -X PUT "localhost:9200/my-index/_settings" -H 'Content-Type: application/json' -d '{
  "index.search.slowlog.threshold.query.warn": "5s",
  "index.search.slowlog.threshold.query.info": "2s"
}'

# Reset elastic password
sudo /usr/share/elasticsearch/bin/elasticsearch-reset-password -u elastic

# Check pending tasks
curl -s "localhost:9200/_cat/pending_tasks?v"
curl -s "localhost:9200/_cluster/health?pretty" | grep -E "status|number_of"
```
