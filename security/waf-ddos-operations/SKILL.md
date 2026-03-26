# WAF & DDoS Operations

> Protect public services with managed and custom WAF rules, emergency blocks, and false-positive tuning.

## Safety Rules

- Start custom rules in log/challenge mode before hard block.
- Keep emergency bypass and rollback procedures documented.
- Coordinate WAF changes with incident communications.

## Quick Reference

```bash
# Validate origin health before WAF changes
curl -fsS https://app.example.com/health
```

## Rule Lifecycle

1. Detect attack pattern.
2. Create scoped mitigation rule.
3. Observe impact and false positives.
4. Promote to block if safe.
5. Retire temporary rule post-incident.

## DDoS Response

- Enable provider managed mitigation.
- Apply geo/rate/challenge controls.
- Protect login and API endpoints first.

## Troubleshooting

- Legit users blocked: narrow rule scope and add verified allowlists.
- Attack bypassing rules: combine L7 rules with upstream rate limits and caching.
