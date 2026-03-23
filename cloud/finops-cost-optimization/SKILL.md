# FinOps & Cloud Cost Optimization

> Detect waste, right-size resources, and use lower-cost capacity options safely.

## Safety Rules

- Tag resources before cleanup to avoid deleting critical assets.
- Require dry-run/report mode before destructive deletion.
- Validate business-hour and production exclusions for automation.
- Right-size only after reviewing sustained utilization windows.
- Spot instances should run only interruption-tolerant workloads.

## Quick Reference

```bash
# AWS unattached EBS
aws ec2 describe-volumes --filters Name=status,Values=available --query 'Volumes[*].[VolumeId,Size,CreateTime]' --output table

# AWS unassociated Elastic IPs
aws ec2 describe-addresses --query 'Addresses[?AssociationId==null].[PublicIp,AllocationId]' --output table

# AWS old snapshots
aws ec2 describe-snapshots --owner-ids self --query 'Snapshots[*].[SnapshotId,StartTime,VolumeSize]' --output table

# GCP unattached disks
gcloud compute disks list --filter='users=[]' --format='table(name,zone,sizeGb,status)'
```

## Zombie Resource Hunting

### AWS candidates

```bash
aws ec2 describe-volumes --filters Name=status,Values=available
aws ec2 describe-addresses --query 'Addresses[?AssociationId==null]'
aws ec2 describe-snapshots --owner-ids self
```

### GCP candidates

```bash
gcloud compute disks list --filter='users=[]'
gcloud compute addresses list --filter='status=RESERVED'
```

## Safe Cleanup Workflow

1. Export candidate list with owner/tag metadata.
2. Notify owners and enforce grace period.
3. Snapshot/backup if needed.
4. Delete resources in controlled batches.

```bash
# Example delete unattached EBS volume
aws ec2 delete-volume --volume-id vol-xxxxxxxx
```

## Right-Sizing Recommendations

Prometheus query examples:

```promql
avg_over_time(node_cpu_seconds_total{mode="idle"}[7d])
avg_over_time(node_memory_MemAvailable_bytes[7d]) / avg_over_time(node_memory_MemTotal_bytes[7d])
```

Heuristic:
- CPU < 20% and memory < 40% for 14 days => consider downsize one class.
- CPU > 70% sustained => consider upsize or horizontal scale.

## Spot Instance Orchestration

Use cases:
- Async workers
- Batch jobs
- Non-critical queues

Guardrails:
- Multi-AZ mixed pools
- Interruption handling hooks
- Idempotent job processing

## Reporting Template

Track monthly:
- Detected waste ($)
- Realized savings ($)
- Reserved/spot coverage (%)
- Cost per service/team

## Troubleshooting

- False-positive zombie resources: check for delayed attachment workflows and IaC ownership.
- Savings plans ineffective: verify instance family/region match against committed plans.
- Spot interruptions hurting SLAs: move critical queues to on-demand fallback pool.
