# ChatOps & Incident Communication

> Send actionable alerts to team channels and auto-generate postmortems after incidents are resolved.

## Safety Rules

- Never post secrets, tokens, or raw credential material to chat channels.
- Include enough context to act: host, service, severity, timestamp, runbook link.
- Deduplicate noisy alerts to avoid alert fatigue.
- Route critical incidents to paging flow, not chat-only channels.
- Keep postmortems factual and timeline-based.

## Quick Reference

```bash
# Slack webhook alert
curl -X POST -H "Content-type: application/json" \
  --data '{"text":"[SEV2] api-prod high memory on host-01"}' \
  "$SLACK_WEBHOOK_URL"

# Capture last 50 app log lines
tail -n 50 /var/log/myapp/error.log

# Capture recent commands for incident notes
history | tail -n 50
```

## Webhook Alert Payloads

### Slack basic payload

```json
{
  "text": "[SEV2] Deployment succeeded: api-prod v2026.03.23.1"
}
```

### Detailed JSON example

```json
{
  "service": "api-prod",
  "severity": "SEV2",
  "event": "high_memory",
  "host": "api-01",
  "ts": "2026-03-23T20:15:00Z",
  "metrics": {
    "mem_used_percent": 94,
    "load_1m": 7.2
  },
  "action": "autoscaled + restarted worker pool"
}
```

## Alerting Script Skeleton

```bash
#!/usr/bin/env bash
set -euo pipefail
MSG="$1"
curl -X POST -H "Content-type: application/json" \
  --data "{\"text\":\"$MSG\"}" \
  "$SLACK_WEBHOOK_URL"
```

## Automated Postmortem Generation

Collect:
- Incident summary and impact window.
- Last 50 error log lines.
- CPU/memory snapshot around event.
- Commands executed and outcome.
- Root cause and prevention action items.

### Markdown template

```markdown
# Incident Report: <incident-id>

## Summary
- Service:
- Severity:
- Impact:

## Timeline (UTC)
- HH:MM detected
- HH:MM mitigation started
- HH:MM recovered

## Evidence
- Error log tail:
  <paste last 50 lines here>
- Metrics snapshot:
  - CPU:
  - Memory:

## Actions Taken
1. ...
2. ...

## Root Cause

## Preventive Actions
1. ...
2. ...
```

## Command Bundle for Incident Artifacts

```bash
OUT="/tmp/incident-$(date +%Y%m%d_%H%M%S)"
mkdir -p "$OUT"
tail -n 50 /var/log/myapp/error.log > "$OUT/error_tail.txt" 2>/dev/null || true
top -b -n1 > "$OUT/top.txt"
free -h > "$OUT/memory.txt"
df -h > "$OUT/disk.txt"
journalctl -p err -n 100 --no-pager > "$OUT/journal_errors.txt"
history | tail -n 50 > "$OUT/commands.txt" 2>/dev/null || true
```

## Troubleshooting

- Webhook returns 4xx: verify URL/token and JSON encoding.
- Alerts too noisy: add cooldowns and event deduplication keys.
- Missing logs in postmortem: verify log path and service permissions.
- Team missed alert: route critical severities to pager/on-call integration.
