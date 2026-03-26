# Tagging Policy Enforcement

> Enforce required cloud metadata tags for ownership, cost allocation, lifecycle, and compliance.

## Safety Rules

- Do not auto-delete untagged production resources without owner verification.
- Enforce tags at provisioning time whenever possible.
- Keep a break-glass exception path with expiry.

## Quick Reference

```bash
# Example required tags
# Owner, Environment, CostCenter, Service, DataClass
```

## Enforcement Model

1. Define required tag schema.
2. Validate in IaC and CI.
3. Detect untagged resources daily.
4. Auto-remediate low-risk resources; escalate critical ones.

## Reporting

- % resources with full tag compliance.
- Cost visibility by team/service.
- Untagged resource backlog trend.

## Troubleshooting

- Tags missing after deploy: check IaC module defaults and provider-level tag inheritance.
- Cost reports still unattributed: verify billing export includes target tag keys.
