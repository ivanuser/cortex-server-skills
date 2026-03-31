# SLO, SLI & Error Budget Operations

> Define reliability targets, monitor burn rate, and gate risky changes when error budgets are exhausted.

## Safety Rules

- Use customer-impact metrics, not only infrastructure metrics.
- Do not set SLO targets without historical baseline data.
- Burn-rate alerts must map to explicit response actions.
- Freeze high-risk deploys when budget is exhausted.

## Quick Reference

```bash
# Example 30-day availability SLO
# SLO: 99.9% => error budget: 0.1% (~43.2 min/month)

# Prometheus success rate (HTTP)
sum(rate(http_requests_total{code!~"5.."}[5m])) / sum(rate(http_requests_total[5m]))
```

## Define SLI/SLO

- Availability SLI: successful requests / total requests.
- Latency SLI: % requests under threshold (e.g., 300ms p95).
- SLO window: rolling 28d or 30d.

## Burn-Rate Alerting

- Fast burn alert: catches severe incidents quickly.
- Slow burn alert: catches chronic degradation.

Example PromQL patterns:

```promql
# 5m error ratio
1 - (
  sum(rate(http_requests_total{code!~"5.."}[5m])) /
  sum(rate(http_requests_total[5m]))
)

# 1h error ratio (slow burn)
1 - (
  sum(rate(http_requests_total{code!~"5.."}[1h])) /
  sum(rate(http_requests_total[1h]))
)
```

## Release Gating

1. Check current error budget consumption.
2. If exhausted, block risky releases.
3. Allow only reliability fixes until budget recovers.

## Incident Policy Hooks

- If fast-burn alert fires: declare incident and page on-call.
- If slow-burn alert fires repeatedly: open reliability ticket and freeze non-critical changes.
- Document consumed budget by service weekly.

## Validation

```bash
# Sanity-check SLI math from API/dashboard exports
# Verify numerator and denominator use same filter set and time window.
```

Success criteria:
- Alert triggers on synthetic outage.
- Release gate blocks when budget threshold is exceeded.

## Troubleshooting

- SLI mismatch across dashboards: verify label filters and denominator consistency.
- Too many false alerts: tune windows and minimum traffic filters.
