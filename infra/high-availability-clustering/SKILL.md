# High Availability & Clustering

> Build fault-tolerant data and traffic layers using replication, sentinel failover, and active health checks.

## Safety Rules

- Test failover procedures in staging before production rollout.
- Replication setup must include backup/restore and rejoin procedures.
- Do not promote replicas manually without split-brain safeguards.
- Keep quorum requirements documented for each cluster type.
- Monitor replication lag continuously.

## Quick Reference

```bash
# PostgreSQL replication status
sudo -u postgres psql -c "SELECT client_addr,state,sync_state,pg_wal_lsn_diff(pg_current_wal_lsn(), replay_lsn) AS lag FROM pg_stat_replication;"

# Mongo replica set status
mongosh --eval 'rs.status()'

# Redis sentinel info
redis-cli -p 26379 SENTINEL masters

# HAProxy backend health
echo "show stat" | socat stdio /run/haproxy/admin.sock | head -40
```

## PostgreSQL Primary/Replica (repmgr outline)

```bash
# Install repmgr package and configure repmgr.conf on all nodes
# On primary: register primary
repmgr -f /etc/repmgr/repmgr.conf primary register

# On replica: clone and register
repmgr -h <primary_ip> -U repmgr -d repmgr -f /etc/repmgr/repmgr.conf standby clone
repmgr -f /etc/repmgr/repmgr.conf standby register
```

Monitor lag:

```sql
SELECT now() - pg_last_xact_replay_timestamp() AS replay_delay;
```

## MongoDB Replica Set

```bash
# On first node
mongosh --eval 'rs.initiate({_id:"rs0",members:[{_id:0,host:"mongo1:27017"},{_id:1,host:"mongo2:27017"},{_id:2,host:"mongo3:27017"}]})'

# Check health
mongosh --eval 'rs.status()'
```

## Redis Sentinel

Example sentinel config:

```text
port 26379
sentinel monitor mymaster 10.0.0.10 6379 2
sentinel down-after-milliseconds mymaster 5000
sentinel failover-timeout mymaster 60000
sentinel parallel-syncs mymaster 1
```

Check failover state:

```bash
redis-cli -p 26379 SENTINEL get-master-addr-by-name mymaster
redis-cli -p 26379 SENTINEL replicas mymaster
```

## Load Balancer Health Checks

### HAProxy example

```text
backend app_backends
  option httpchk GET /health
  http-check expect status 200
  server app1 10.0.1.11:8080 check
  server app2 10.0.1.12:8080 check
```

### Nginx upstream (passive checks)

```text
upstream app_upstream {
  server 10.0.1.11:8080 max_fails=3 fail_timeout=10s;
  server 10.0.1.12:8080 max_fails=3 fail_timeout=10s;
}
```

## Failover Drill Checklist

1. Simulate primary node outage.
2. Confirm automatic promotion/election.
3. Validate application reconnect behavior.
4. Validate data consistency and replication resync.
5. Document RTO/RPO.

## Troubleshooting

- Replication lag growing: check IO, network latency, and long-running transactions.
- Sentinel flapping: tune quorum and down-after threshold.
- LB marks all backends down: verify health endpoint dependencies and timeout values.
- Split brain risk: enforce fencing/manual approval for ambiguous failovers.
