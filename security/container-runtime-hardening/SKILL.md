# Container Runtime Hardening

> Reduce container attack surface using least privilege, runtime controls, and policy enforcement.

## Safety Rules

- Do not run containers as root unless unavoidable.
- Drop unused Linux capabilities by default.
- Enforce read-only filesystem where possible.

## Quick Reference

```bash
# Inspect running container privileges
docker inspect <container_id> | grep -E 'Privileged|CapAdd|ReadonlyRootfs'
```

## Hardening Baseline

- `USER` non-root in image.
- `readOnlyRootFilesystem: true` where possible.
- `no-new-privileges` enabled.
- seccomp/apparmor profiles enforced.
- minimal base images and pinned digests.

## Policy Controls

- Block privileged containers.
- Require signed images from trusted registries.
- Disallow hostPath mounts for sensitive paths.

## Troubleshooting

- App breaks under read-only FS: mount explicit writable paths only.
- Capability drops break networking: add only required capability, not `ALL`.
