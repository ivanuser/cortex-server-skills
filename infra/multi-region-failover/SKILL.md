# Multi-Region Failover

> Maintain service continuity during regional outages with tested failover and recovery playbooks.

## Safety Rules

- Failover plans must be tested regularly, not documented-only.
- Validate replication lag before declaring region readiness.
- Avoid split-brain by enforcing single-writer controls.

## Quick Reference

```bash
# DNS failover check
dig app.example.com +short

# Health probe secondary region
curl -fsS https://secondary.example.com/health
```

## Failover Runbook

1. Confirm primary region incident.
2. Validate secondary dependencies (DB/cache/queue).
3. Shift traffic via DNS/LB.
4. Monitor error rate and latency.
5. Communicate status to stakeholders.

## Failback Runbook

1. Validate primary stability.
2. Re-sync data.
3. Shift traffic gradually back.
4. Monitor and close incident.

## Troubleshooting

- Slow DNS cutover: lower TTL ahead of planned failover drills.
- Secondary healthy but app broken: missing secrets/config drift between regions.
