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

## Data Consistency Checks

- Validate replication lag is within RPO target.
- Confirm write target is singular (no dual-primary drift).
- Run key read/write smoke tests in active region.

## Validation

```bash
# DNS and endpoint checks from multiple resolvers
dig @1.1.1.1 app.example.com +short
dig @8.8.8.8 app.example.com +short
curl -fsS https://app.example.com/health
```

Success criteria:
- Failover completes within RTO target.
- No data-loss beyond agreed RPO.

## Troubleshooting

- Slow DNS cutover: lower TTL ahead of planned failover drills.
- Secondary healthy but app broken: missing secrets/config drift between regions.
