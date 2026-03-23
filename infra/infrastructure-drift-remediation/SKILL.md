# Infrastructure Drift Remediation

> Detect and reconcile cloud infrastructure drift against Terraform source of truth.

## Safety Rules

- Run `terraform plan` before any apply; never skip review.
- Use remote state locking for shared environments.
- Auto-apply only in approved workspaces with blast-radius controls.
- Validate drift source (manual change vs expected emergency action) before overwrite.
- Keep audit logs of plans/applies and actor identity.

## Quick Reference

```bash
# Init and refresh
terraform init
terraform plan -refresh-only

# Detect drift against desired config
terraform plan

# Reconcile
terraform apply
```

## Drift Detection Workflow

1. Pull latest IaC code from main branch.
2. Run `terraform init` with backend lock.
3. Run `terraform plan -detailed-exitcode`.
4. Exit code `2` indicates drift or pending changes.
5. Classify changes (authorized/manual/unknown).

```bash
terraform plan -detailed-exitcode
echo $?   # 0 no change, 2 drift/change, 1 error
```

## Scheduled Checks

Use cron/CI:

```bash
cd /infra/live/prod
terraform init -input=false
terraform plan -input=false -detailed-exitcode -out=tfplan || RC=$?
if [ "${RC:-0}" = "2" ]; then
  echo "Drift detected"
fi
```

## Automated Reconciliation Guardrails

- Require drift scope summary (resource count, criticality).
- Block apply if IAM/network perimeter changes exceed threshold.
- Require human approval for deletes or replacements on critical resources.

```bash
terraform show -json tfplan > /tmp/tfplan.json
```

## GitOps Enforcement Pattern

1. Drift detected.
2. Open incident/change ticket.
3. If unauthorized manual change, apply Terraform to converge.
4. If emergency/manual fix is valid, codify it in Terraform and re-plan.

## Troubleshooting

- Constant drift noise: check non-deterministic fields and provider-computed attributes.
- Lock contention: verify stale lock cleanup and backend availability.
- Apply fails due to missing permissions: validate CI role policies for target resources.
- Partial apply interruption: rerun plan immediately and resolve intermediate state.
