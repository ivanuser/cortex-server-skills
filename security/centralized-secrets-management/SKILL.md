# Centralized Secrets Management

> Move secrets from local files to managed secret backends with rotation and access auditing.

## Safety Rules

- Never hardcode secrets in source control or container images.
- Grant read access by role with least privilege.
- Rotate credentials on a schedule and on incident triggers.

## Quick Reference

```bash
# Example pattern
# app -> secret manager (Vault/AWS/GCP) -> short-lived credential
```

## Migration Workflow

1. Inventory existing secrets and usage paths.
2. Create secret paths and access policies.
3. Update app to fetch secrets at startup/runtime.
4. Rotate old static credentials out.

## Rotation Pattern

- Create new credential.
- Update secret manager value/version.
- Reload apps gracefully.
- Revoke old credential.

## Troubleshooting

- App startup failures after migration: missing IAM role/policy mapping.
- Secret version drift: pin and monitor active secret versions per environment.
