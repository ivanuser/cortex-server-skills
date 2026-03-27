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

## Rollback Triggers

- 5xx error rate above threshold.
- Latency regression (p95/p99).
- Business KPI regression.

## Troubleshooting

- Metrics lag causes late rollback: use short-window canary guards plus synthetic checks.
- Session stickiness issues: validate LB affinity configuration.
