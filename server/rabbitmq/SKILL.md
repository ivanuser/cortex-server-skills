# RabbitMQ — Message Broker

> Install, configure, and manage RabbitMQ for message queuing, pub/sub, and event-driven architectures. Covers exchanges, queues, bindings, users, vhosts, management plugin, and clustering.

## Safety Rules

- **Purging a queue deletes all messages** — cannot be recovered.
- Don't delete exchanges or queues in production without verifying no active consumers/producers.
- Always set queue `x-max-length` or `x-max-length-bytes` to prevent unbounded growth.
- Use durable queues and persistent messages for data that must survive restarts.
- Erlang cookie must match on all cluster nodes — mismatch = connection failure.
- Default `guest` user only works from localhost — create real users for production.

## Quick Reference

```bash
# Install (Ubuntu/Debian — latest via Cloudsmith)
# Install Erlang first
curl -1sLf 'https://dl.cloudsmith.io/public/rabbitmq/rabbitmq-erlang/setup.deb.sh' | sudo bash
sudo apt install -y erlang-base erlang-asn1 erlang-crypto erlang-eldap \
  erlang-ftp erlang-inets erlang-mnesia erlang-os-mon erlang-parsetools \
  erlang-public-key erlang-runtime-tools erlang-snmp erlang-ssl \
  erlang-syntax-tools erlang-tftp erlang-tools erlang-xmerl

# Install RabbitMQ
curl -1sLf 'https://dl.cloudsmith.io/public/rabbitmq/rabbitmq-server/setup.deb.sh' | sudo bash
sudo apt install -y rabbitmq-server

# Install (RHEL/Rocky)
sudo dnf install -y erlang rabbitmq-server

# Service management
sudo systemctl enable --now rabbitmq-server
sudo systemctl status rabbitmq-server
sudo systemctl restart rabbitmq-server

# Enable management plugin (web UI + HTTP API)
sudo rabbitmq-plugins enable rabbitmq_management

# Quick status
sudo rabbitmqctl status
sudo rabbitmqctl cluster_status
sudo rabbitmqctl list_queues
sudo rabbitmqctl list_exchanges
sudo rabbitmqctl list_connections
```

## Configuration

### Config file: `/etc/rabbitmq/rabbitmq.conf`

```ini
# Listeners
listeners.tcp.default = 5672
management.tcp.port = 15672
management.tcp.ip = 0.0.0.0

# Memory limit (40% of system RAM or absolute)
vm_memory_high_watermark.relative = 0.4
# vm_memory_high_watermark.absolute = 2GB

# Disk free limit (stop accepting messages below this)
disk_free_limit.absolute = 2GB

# Default user (change or delete in production)
default_user = admin
default_pass = strong_password
default_vhost = /

# Logging
log.file.level = info
log.dir = /var/log/rabbitmq
log.file = rabbit.log

# Heartbeat (seconds — 0 disables)
heartbeat = 60

# Max message size
max_message_size = 134217728           # 128MB

# Connection limits
channel_max = 2047
```

### Environment variables: `/etc/rabbitmq/rabbitmq-env.conf`

```bash
RABBITMQ_NODENAME=rabbit@hostname
RABBITMQ_NODE_PORT=5672
RABBITMQ_DIST_PORT=25672
# RABBITMQ_MNESIA_DIR=/var/lib/rabbitmq/mnesia
```

## Users & Permissions

```bash
# List users
sudo rabbitmqctl list_users

# Add user
sudo rabbitmqctl add_user appuser app_password

# Set user tags (management, administrator, monitoring, policymaker)
sudo rabbitmqctl set_user_tags appuser management
sudo rabbitmqctl set_user_tags admin administrator

# Change password
sudo rabbitmqctl change_password appuser new_password

# Delete user
sudo rabbitmqctl delete_user guest     # Remove default guest user

# Set permissions (configure, write, read — regex patterns)
# Grant full access to vhost /
sudo rabbitmqctl set_permissions -p / appuser ".*" ".*" ".*"

# Limit to specific queues
sudo rabbitmqctl set_permissions -p / appuser "^app\." "^app\." "^app\."

# List permissions
sudo rabbitmqctl list_permissions -p /
sudo rabbitmqctl list_user_permissions appuser
```

## Virtual Hosts

```bash
# List vhosts
sudo rabbitmqctl list_vhosts

# Create vhost
sudo rabbitmqctl add_vhost myapp
sudo rabbitmqctl add_vhost staging

# Set permissions for user on vhost
sudo rabbitmqctl set_permissions -p myapp appuser ".*" ".*" ".*"

# Delete vhost (⚠ deletes all queues/exchanges in it)
sudo rabbitmqctl delete_vhost staging

# Set vhost limits
sudo rabbitmqctl set_vhost_limits -p myapp '{"max-connections": 100, "max-queues": 50}'
sudo rabbitmqctl clear_vhost_limits -p myapp
```

## Exchanges, Queues & Bindings

### Via `rabbitmqadmin` CLI (install from management plugin)

```bash
# Download rabbitmqadmin
wget http://localhost:15672/cli/rabbitmqadmin
chmod +x rabbitmqadmin
sudo mv rabbitmqadmin /usr/local/bin/

# Declare exchange
rabbitmqadmin declare exchange name=events type=topic durable=true
rabbitmqadmin declare exchange name=notifications type=fanout durable=true
rabbitmqadmin declare exchange name=tasks type=direct durable=true

# Exchange types:
# direct  — route by exact routing key match
# topic   — route by routing key pattern (*.log, audit.#)
# fanout  — broadcast to all bound queues
# headers — route by message headers

# Declare queue
rabbitmqadmin declare queue name=email_queue durable=true
rabbitmqadmin declare queue name=log_queue durable=true \
  arguments='{"x-max-length": 100000, "x-message-ttl": 86400000}'

# Queue arguments:
# x-max-length        — max messages in queue
# x-max-length-bytes  — max total bytes
# x-message-ttl       — message TTL in ms
# x-dead-letter-exchange — DLX for rejected/expired messages
# x-queue-type        — classic, quorum, or stream

# Bind queue to exchange
rabbitmqadmin declare binding source=events destination=email_queue routing_key="user.signup"
rabbitmqadmin declare binding source=events destination=log_queue routing_key="*.log"

# List everything
rabbitmqadmin list exchanges
rabbitmqadmin list queues
rabbitmqadmin list bindings

# Publish a message
rabbitmqadmin publish exchange=events routing_key="user.signup" payload='{"email":"test@example.com"}'

# Get messages (without consuming)
rabbitmqadmin get queue=email_queue count=5 ackmode=ack_requeue_true

# Purge queue (⚠ deletes all messages)
rabbitmqadmin purge queue name=email_queue

# Delete
rabbitmqadmin delete queue name=old_queue
rabbitmqadmin delete exchange name=old_exchange
```

### Dead Letter Exchange (DLX)

```bash
# Create DLX
rabbitmqadmin declare exchange name=dlx type=fanout durable=true
rabbitmqadmin declare queue name=dead_letters durable=true
rabbitmqadmin declare binding source=dlx destination=dead_letters

# Create queue with DLX
rabbitmqadmin declare queue name=work_queue durable=true \
  arguments='{"x-dead-letter-exchange": "dlx", "x-message-ttl": 300000}'
```

## Policies

```bash
# Set policy (applies to queues matching pattern)
# HA policy — mirror queues to 2 nodes
sudo rabbitmqctl set_policy ha-all "^ha\." \
  '{"ha-mode":"exactly","ha-params":2,"ha-sync-mode":"automatic"}' \
  --priority 1 --apply-to queues

# TTL policy — expire messages after 1 hour
sudo rabbitmqctl set_policy ttl-1h "^temp\." \
  '{"message-ttl": 3600000}' \
  --priority 1 --apply-to queues

# Max length policy
sudo rabbitmqctl set_policy max-length "^bounded\." \
  '{"max-length": 50000}' \
  --priority 1 --apply-to queues

# List policies
sudo rabbitmqctl list_policies

# Delete policy
sudo rabbitmqctl clear_policy ha-all
```

## Clustering

```bash
# On node 2 — join cluster (node 1 = rabbit@node1)
sudo rabbitmqctl stop_app
sudo rabbitmqctl reset
sudo rabbitmqctl join_cluster rabbit@node1
sudo rabbitmqctl start_app

# Erlang cookie must match on all nodes
# Location: /var/lib/rabbitmq/.erlang.cookie
# Copy from node1 to all other nodes, then restart

# Check cluster status
sudo rabbitmqctl cluster_status

# Remove node from cluster
sudo rabbitmqctl forget_cluster_node rabbit@node3

# Change cluster node type
sudo rabbitmqctl stop_app
sudo rabbitmqctl change_cluster_node_type disc    # or ram
sudo rabbitmqctl start_app
```

### Quorum Queues (recommended for HA)

```bash
# Quorum queues replace classic mirrored queues (RabbitMQ 3.8+)
rabbitmqadmin declare queue name=critical_queue durable=true \
  arguments='{"x-queue-type": "quorum"}'

# Quorum queues are replicated across cluster nodes via Raft consensus
# They automatically elect leaders and handle failover
```

## Management API

```bash
# Base URL: http://localhost:15672/api/

# Overview
curl -s -u admin:password http://localhost:15672/api/overview | jq .

# List queues with details
curl -s -u admin:password http://localhost:15672/api/queues | jq '.[].name'

# Queue details
curl -s -u admin:password http://localhost:15672/api/queues/%2F/email_queue | jq .

# Publish message via API
curl -X POST -u admin:password http://localhost:15672/api/exchanges/%2F/events/publish \
  -H 'Content-Type: application/json' \
  -d '{"properties":{},"routing_key":"test","payload":"hello","payload_encoding":"string"}'

# Health check
curl -s -u admin:password http://localhost:15672/api/health/checks/alarms
curl -s -u admin:password http://localhost:15672/api/health/checks/local-alarms
```

## Monitoring

```bash
# Queue depths
sudo rabbitmqctl list_queues name messages consumers

# Connections
sudo rabbitmqctl list_connections user peer_host state

# Channels
sudo rabbitmqctl list_channels connection number consumer_count

# Memory breakdown
sudo rabbitmqctl status | grep -A 20 "Memory"
sudo rabbitmqctl eval 'rabbit_vm:memory().'

# Alarms
sudo rabbitmqctl list_alarms

# Enable Prometheus plugin
sudo rabbitmq-plugins enable rabbitmq_prometheus
# Metrics at: http://localhost:15692/metrics
```

## Troubleshooting

```bash
# RabbitMQ won't start
sudo journalctl -u rabbitmq-server --no-pager -n 50
sudo cat /var/log/rabbitmq/rabbit@$(hostname).log | tail -100

# Erlang cookie mismatch
sudo cat /var/lib/rabbitmq/.erlang.cookie
# Must be identical across all cluster nodes

# Memory alarm (RabbitMQ blocking publishers)
sudo rabbitmqctl status | grep -A5 "memory"
# Increase vm_memory_high_watermark or add RAM

# Disk alarm
df -h /var/lib/rabbitmq
# Free space or increase disk_free_limit

# Queue stuck / growing
sudo rabbitmqctl list_queues name messages consumers
# Check if consumers are connected and processing

# Reset node (⚠ loses all data)
sudo rabbitmqctl stop_app
sudo rabbitmqctl reset
sudo rabbitmqctl start_app

# Connection refused
sudo ss -tlnp | grep -E '5672|15672'
sudo rabbitmqctl status | grep listeners

# Unresponsive management UI
sudo rabbitmq-plugins disable rabbitmq_management
sudo rabbitmq-plugins enable rabbitmq_management
```
