# Automated Compliance & Auditing (SecOps)

> Continuously validate host and cloud posture using benchmark scans, network diffing, and IAM policy checks.

## Safety Rules

- Run scanners in read-only mode by default.
- Store scan outputs securely; reports may contain sensitive topology details.
- Baseline and diff logic must be versioned and tamper-evident.
- Treat findings as triage inputs; verify before destructive remediation.
- Separate high-risk auto-remediation behind approval gates.

## Quick Reference

```bash
# OpenSCAP scan example
oscap xccdf eval --profile xccdf_org.ssgproject.content_profile_cis \
  --results /tmp/oscap-results.xml \
  /usr/share/xml/scap/ssg/content/ssg-ubuntu2204-ds.xml

# Trivy config scan
trivy config /etc --severity HIGH,CRITICAL

# Baseline nmap
nmap -Pn -sV -p- <public_ip> -oN /var/lib/security/baseline.nmap
```

## CIS Benchmark Scanning

### OpenSCAP

```bash
sudo apt-get install -y openscap-scanner scap-security-guide || true
oscap info /usr/share/xml/scap/ssg/content/ssg-ubuntu2204-ds.xml
```

### Trivy host/config

```bash
trivy fs --security-checks config,vuln /
```

## Network Diffing

1. Capture known-good external port baseline.
2. Run scheduled scans.
3. Diff current vs baseline.
4. Alert on newly exposed ports/services.

```bash
nmap -Pn -sV -p- <public_ip> -oN /var/lib/security/scans/current.nmap
diff -u /var/lib/security/baseline.nmap /var/lib/security/scans/current.nmap || true
```

## IAM Privilege Escalation Detection

### AWS

```bash
# Find principals with AdministratorAccess
aws iam list-attached-user-policies --user-name <user>
aws iam list-attached-role-policies --role-name <role>
```

Heuristic checks:
- Wildcard `Action: "*"`.
- Wildcard `Resource: "*"`.
- IAM write actions on compute identities.

### GCP

```bash
gcloud projects get-iam-policy <project-id> --format=json
```

Search for broad roles like `roles/owner` attached to service accounts.

## Scheduling Strategy

- Daily: network diff + IAM broad policy check.
- Weekly: full CIS/benchmark scan.
- Monthly: exception review and closure.

## Troubleshooting

- Scanner fails after OS update: refresh benchmark content packages.
- Too many false positives: tune profile/severity and add documented exceptions.
- Nmap diff noisy: normalize service banners or use focused port ranges for drift alerts.
- IAM APIs rate-limited: cache snapshots and batch queries by account/project.
