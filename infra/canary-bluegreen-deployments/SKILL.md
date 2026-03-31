# Canary & Blue/Green Deployments

> Roll out changes gradually, validate live metrics, and rollback automatically when risk signals appear.

## Safety Rules

- Never shift all traffic before health and error checks pass.
- Define rollback thresholds before rollout starts.
- Keep schema changes backward-compatible during transition.

## Quick Reference

```bash
# Canary progression example
# 5% -> 25% -> 50% -> 100%

# Health checks
curl -fsS https://app.example.com/health
```

## Canary Workflow

1. Deploy canary version.
2. Route small traffic slice.
3. Compare error rate, latency, saturation vs baseline.
4. Promote or rollback automatically.

## Blue/Green Workflow

1. Deploy to idle color.
2. Run smoke tests.
3. Switch traffic atomically.
4. Keep previous color hot for quick rollback.

## Metric Gates

Recommended promotion checks per phase:
- Error rate delta vs baseline < 1%.
- p95 latency regression < 10%.
- Saturation (CPU/memory) below safe ceiling.
- Business conversion/event rate stable.

## Rollback Triggers

- 5xx error rate above threshold.
- Latency regression (p95/p99).
- Business KPI regression.

## Validation

```bash
# Health probes
curl -fsS https://app.example.com/health
curl -fsS https://app.example.com/ready

# Optional synthetic
curl -fsS https://app.example.com/login
```

Success criteria:
- Canary phase completes without guardrail breach.
- Rollback path tested at least once per release train.

## Troubleshooting

- Metrics lag causes late rollback: use short-window canary guards plus synthetic checks.
- Session stickiness issues: validate LB affinity configuration.
