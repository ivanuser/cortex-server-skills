# DNS Operations

> Perform safe DNS changes with rollback strategy, propagation verification, and outage-aware execution.

## Safety Rules

- Lower TTL before planned migrations.
- Never delete existing records until replacement is validated.
- Validate authoritative and resolver views before closing change.

## Quick Reference

```bash
dig app.example.com A +short
dig app.example.com CNAME +short
dig @1.1.1.1 app.example.com +short
```

## Change Workflow

1. Plan record change and rollback record.
2. Lower TTL.
3. Apply change.
4. Verify from multiple resolvers/regions.
5. Restore TTL if stable.

## Troubleshooting

- Record updated in provider but not globally: propagation/TTL cache delay.
- Intermittent resolution: mixed record sets or stale NS delegation.
