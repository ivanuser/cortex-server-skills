# OpenObserve — Logs, Metrics, Traces Operations

> Deploy and operate OpenObserve for centralized observability.
> Covers ingestion, retention, querying, alerting, and production troubleshooting.

## Safety Rules

- Lock down ingestion endpoints and dashboards with authentication; never expose default admin creds.
- Keep object storage retention aligned with compliance requirements before enabling auto-delete.
- Test alert rules in non-paging channels before promoting to production paging.
- Back up configuration and stream definitions before major upgrades.
- Validate disk/object-store headroom before high-volume ingestion cutovers.

## Quick Reference

```bash
# Docker quick start (dev)
docker run -d --name openobserve -p 5080:5080 \
  -e ZO_ROOT_USER_EMAIL=admin@example.com \
  -e ZO_ROOT_USER_PASSWORD='change-me-now' \
  public.ecr.aws/zinclabs/openobserve:latest

# Health
curl -fsS http://localhost:5080/healthz

# Logs endpoint check (requires auth token/header in production)
curl -I http://localhost:5080/api/default/_search

# Container logs
docker logs -f openobserve
```

## Deployment Patterns

### Single-node (small teams / labs)

- Local disk for quick start.
- Daily backups of config and stream metadata.

### Production baseline

- Object storage backend (S3-compatible).
- Reverse proxy with TLS (Nginx/Caddy).
- Externalized secrets via env manager.
- Alert webhooks to incident channel.

## Configuration Notes

Common environment variables:

```text
ZO_ROOT_USER_EMAIL=admin@example.com
ZO_ROOT_USER_PASSWORD=<strong-password>
ZO_DATA_DIR=/data/openobserve
ZO_LOCAL_MODE=true
```

Production reminders:
- Use strong admin password and rotate periodically.
- Place behind HTTPS and access controls.
- Configure retention by stream to control storage cost.

## Ingestion Operations

Typical ingestion sources:
- App logs (structured JSON recommended).
- Nginx/Apache access logs.
- Container logs.
- OTLP/trace exporters (if enabled in your setup).

Validation checklist:
1. Stream exists in UI/API.
2. New events visible within expected latency.
3. Parsed fields are queryable (timestamp, service, level, host).

## Querying & Dashboards

Operational dashboard starter panels:
- Error rate by service.
- Top noisy hosts/services.
- p95 latency (if metrics/traces available).
- Ingestion volume trend and dropped records.

Saved query practices:
- Prefix with team/service name.
- Include time range defaults and expected cardinality.

## Alerting

Baseline alerts:
- No data from critical service for X minutes.
- Error log spike over baseline.
- Ingestion pipeline failures.
- High storage growth rate.

Rollout process:
1. Create in test channel.
2. Verify signal quality for 24-72h.
3. Tune thresholds and dedupe keys.
4. Promote to paging route.

## Retention & Storage Management

Retention strategy by data class:
- Security logs: longer retention.
- Debug logs: shorter retention.
- High-cardinality noisy streams: aggressive retention and sampling.

Capacity checks:
- Daily ingest volume.
- Compression ratio.
- Object storage growth per stream/team.

## Upgrade Runbook

1. Export current config/stream metadata.
2. Snapshot/backup storage pointers and deployment manifests.
3. Upgrade one environment first (staging).
4. Run smoke tests for ingestion/query/alerts.
5. Promote to production.

## Validation

```bash
# Service health
curl -fsS http://localhost:5080/healthz

# UI reachable
curl -I http://localhost:5080/

# Recent logs exist for a known stream (API auth may be required)
# curl -X POST http://localhost:5080/api/default/_search -d '{...}'
```

Success criteria:
- Service healthy.
- New log events searchable.
- Alert test event delivered to target channel.

## Troubleshooting

- UI loads but no logs: ingestion endpoint/token mismatch or wrong stream name.
- Logs arrive but fields not queryable: malformed JSON or missing parser mapping.
- High query latency: stream cardinality too high or time range too wide.
- Sudden storage spike: debug-level flood or duplicate shippers.
- Alerts not firing: rule disabled, wrong time window, or webhook failure path.
