# Service Dependency Mapping

> Build and maintain a dependency graph so incident responders can quickly identify blast radius and ownership.

## Safety Rules

- Treat dependency maps as operational assets and keep them versioned.
- Mark critical path dependencies explicitly.
- Validate map changes after major architecture updates.

## Quick Reference

```bash
# Example data sources
ss -tulpen
systemctl list-units --type=service
```

## Mapping Workflow

1. Inventory services and owners.
2. Capture inbound/outbound dependencies (DB, cache, queue, APIs).
3. Assign criticality and recovery priority.
4. Publish graph and review monthly.

## Incident Use

- Find upstream cause for downstream failures.
- Identify safe rollback boundaries.
- Prioritize restoration by user impact.

## Troubleshooting

- Map stale after deployments: enforce map update as release checklist item.
- Unknown dependencies: add network flow collection during normal operation.
