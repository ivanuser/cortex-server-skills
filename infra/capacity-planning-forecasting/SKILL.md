# Capacity Planning & Forecasting

> Predict saturation before incidents by modeling growth trends in compute, storage, and traffic.

## Safety Rules

- Forecast using at least 30-90 days of data.
- Distinguish seasonal peaks from long-term growth.
- Include failure-domain capacity (N+1) in plans.

## Quick Reference

```bash
# Key metrics to track
# CPU utilization, memory headroom, disk growth, request rate, queue lag
```

## Workflow

1. Collect historical utilization.
2. Identify peak and p95 trends.
3. Project exhaustion date.
4. Recommend scale-up/out and lead-time actions.

## Output Expectations

- Time-to-saturation by resource.
- Recommended scaling action and deadline.
- Confidence level and assumptions.

## Data Inputs

- 30/60/90-day utilization trends.
- Peak concurrency windows.
- Planned launches/events.
- Incident history tied to saturation events.

## Validation

```bash
# Compare forecast vs actual monthly utilization after rollout.
# Track forecast error and adjust model assumptions.
```

Success criteria:
- Forecast identifies saturation before customer-visible impact.
- Capacity actions completed ahead of predicted exhaustion.

## Troubleshooting

- Forecast misses spikes: include event/launch calendar and anomaly adjustments.
- Overprovisioning persists: combine forecast with rightsizing feedback loop.
