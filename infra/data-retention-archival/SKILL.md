# Data Retention & Archival

> Apply lifecycle policies for operational logs/data while supporting compliance and restoreability.

## Safety Rules

- Never purge data without approved retention policy.
- Separate legal hold data from normal retention workflows.
- Validate restoration from archive storage regularly.

## Quick Reference

```bash
# Typical tiers
# hot (days) -> warm (weeks) -> cold/archive (months/years)
```

## Lifecycle Workflow

1. Classify data by sensitivity and business value.
2. Define retention by class and regulation.
3. Configure lifecycle transitions and expiry.
4. Test retrieval from archive.

## Policy Dimensions

- Retain: how long data stays available.
- Archive: when data moves to cheaper storage.
- Delete: when secure deletion occurs.

## Validation

```bash
# Validate lifecycle transitions and restore path for sampled records.
# Confirm legal-hold tagged datasets are excluded from deletion policies.
```

Success criteria:
- Data transitions occur per policy windows.
- Archived data restore tested and documented.

## Troubleshooting

- Retrieval too slow for incident needs: keep recent index/metadata in warm tier.
- Accidental early deletion: enforce delete protection and approval gates.
