# Identity & Access Governance

> Enforce least privilege, periodic access reviews, and break-glass controls across cloud IAM.

## Safety Rules

- Default deny; grant minimum required actions/resources.
- Remove standing admin access where possible.
- All break-glass usage must be logged and reviewed.

## Quick Reference

```bash
# AWS identify caller
aws sts get-caller-identity

# List attached role policies
aws iam list-attached-role-policies --role-name <role>
```

## Governance Workflow

1. Inventory identities and roles.
2. Detect broad privileges and unused permissions.
3. Right-size policies.
4. Run quarterly access recertification.

## Break-Glass Controls

- Time-bound elevated access.
- MFA required.
- Incident ticket required.

## Review Cadence

- Weekly: detect newly attached broad policies.
- Monthly: remove unused roles/users.
- Quarterly: full access recertification by service owner.

## Validation

```bash
aws iam list-attached-role-policies --role-name <role>
aws iam generate-service-last-accessed-details --arn <role-arn>
```

Success criteria:
- No standing admin rights outside approved break-glass paths.
- Access review evidence retained for audit window.

## Troubleshooting

- Permission denied after tightening policy: add least-privilege allow for exact action/resource.
- Access creep returns: enforce policy-as-code with review gates.
