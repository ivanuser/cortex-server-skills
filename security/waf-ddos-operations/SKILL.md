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

## Rule Tuning Workflow

1. Start in log/challenge mode.
2. Measure blocked vs allowed outcomes.
3. Add exceptions for known-good automated clients.
4. Promote to block once false positives are acceptable.

## Validation

```bash
# Baseline endpoint health
curl -fsS https://app.example.com/health

# Validate protected endpoint behavior (expect challenge/block based on policy)
curl -I https://app.example.com/login
```

Success criteria:
- Attack traffic reduced.
- Legit traffic impact remains within acceptable threshold.

## Troubleshooting

- Legit users blocked: narrow rule scope and add verified allowlists.
- Attack bypassing rules: combine L7 rules with upstream rate limits and caching.
