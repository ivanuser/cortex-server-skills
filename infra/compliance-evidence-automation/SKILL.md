# Compliance Evidence Automation

> Automatically collect, package, and publish audit-ready evidence for SOC2/HIPAA/PCI controls.

## Safety Rules

- Evidence bundles must exclude secrets and PII where not required.
- Timestamp and checksum all artifacts.
- Keep immutable copies for audit history.

## Quick Reference

```bash
# Evidence bundle structure
# /evidence/<control>/<date>/{artifacts,checksums,summary.md}
```

## Collection Workflow

1. Map controls to evidence sources.
2. Collect on schedule (daily/weekly/monthly).
3. Hash/sign bundles.
4. Publish to secure audit repository.

## Common Evidence Sources

- IAM access reviews.
- Patch and vulnerability scan reports.
- Backup and restore test logs.
- Change management records.

## Validation

```bash
# Validate each control has a populated evidence bundle path
# and checksum file for the current reporting window.
```

Success criteria:
- Evidence is complete, timestamped, and reproducible for audit requests.
- Missing-control evidence triggers automatic owner notification.

## Troubleshooting

- Missing evidence for control: add source mapping and owner assignment.
- Inconsistent formats: enforce templates and validation checks in pipeline.
