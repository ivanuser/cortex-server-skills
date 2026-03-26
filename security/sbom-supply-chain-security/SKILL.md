# SBOM & Supply Chain Security

> Generate SBOMs, verify signed artifacts, and reduce dependency-chain risk.

## Safety Rules

- Generate SBOM for every release artifact.
- Fail CI on critical vulnerabilities above policy thresholds.
- Verify signature/provenance before deployment.

## Quick Reference

```bash
# Example tools (depending on stack)
syft . -o json > sbom.json
grype sbom:sbom.json
```

## Workflow

1. Generate SBOM (CycloneDX or SPDX).
2. Scan dependencies and images.
3. Verify signatures/provenance.
4. Enforce policy gates in CI.

## Governance

- Store SBOMs with release artifacts.
- Track component ownership and patch SLAs.
- Maintain exception process with expiry dates.

## Troubleshooting

- Scan noise too high: tune ignores with justification and expiration.
- Signature verification failures: validate key trust roots and CI key rotation.
