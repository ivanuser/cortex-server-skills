# CortexOS Server Skills

A curated collection of production-ready reference skills for server administration, application deployment, infrastructure operations, security, and cloud governance.

## Repository Overview

<!-- AUTO-SUMMARY-START -->
Total skills: **73**

Category counts:
- `apps`: 2
- `cloud`: 6
- `infra`: 29
- `runtime`: 5
- `security`: 12
- `server`: 19
<!-- AUTO-SUMMARY-END -->

## Featured Skills

- Observability: [`infra/openobserve`](infra/openobserve/SKILL.md)
- Incident response: [`infra/incident-diagnostics`](infra/incident-diagnostics/SKILL.md)
- BDR: [`infra/backup-disaster-recovery`](infra/backup-disaster-recovery/SKILL.md)
- Deployments: [`infra/zero-downtime-deploy`](infra/zero-downtime-deploy/SKILL.md), [`infra/canary-bluegreen-deployments`](infra/canary-bluegreen-deployments/SKILL.md)
- Security operations: [`security/ssh-hardening-incident-response`](security/ssh-hardening-incident-response/SKILL.md), [`security/automated-compliance-auditing`](security/automated-compliance-auditing/SKILL.md)
- Governance: [`cloud/identity-access-governance`](cloud/identity-access-governance/SKILL.md), [`cloud/tagging-policy-enforcement`](cloud/tagging-policy-enforcement/SKILL.md), [`cloud/finops-cost-optimization`](cloud/finops-cost-optimization/SKILL.md)

## Usage

Each `SKILL.md` is a standalone reference with:
- **Quick reference** — one-liners for common tasks
- **Detailed sections** — organized by operation type
- **Copy-paste configs** — production-ready examples
- **Troubleshooting** — common issues and fixes
- **Safety rules** — what NOT to do

## Structure

```text
apps/
cloud/
infra/
runtime/
security/
server/
```

## Skills Index

<!-- AUTO-INDEX-START -->
_Generated from `manifest.json` by `pwsh ./scripts/generate-readme-index.ps1`._

### apps
| Skill | Title | Description |
|---|---|---|
| [apps/discourse](apps/discourse/SKILL.md) | Discourse — Community Forum Platform | Install, configure, and manage Discourse — Docker deployment, plugins, backups, email, user management, API, and perform |
| [apps/nextcloud](apps/nextcloud/SKILL.md) | Nextcloud — Self-Hosted Cloud Platform | Install, configure, and manage Nextcloud — file sync, sharing, occ administration, upgrades, performance tuning, and int |

### cloud
| Skill | Title | Description |
|---|---|---|
| [cloud/aws-cli](cloud/aws-cli/SKILL.md) | AWS CLI v2 — Amazon Web Services Command Line Interface | Install, configure, and use the AWS CLI v2 for managing S3, EC2, IAM, CloudFormation, and other AWS services from the te |
| [cloud/azure-cli](cloud/azure-cli/SKILL.md) | Azure CLI — Microsoft Azure Command Line Interface | Install, authenticate, and manage Azure resources including VMs, storage accounts, resource groups, and AKS clusters fro |
| [cloud/finops-cost-optimization](cloud/finops-cost-optimization/SKILL.md) | FinOps & Cloud Cost Optimization | Detect waste, right-size resources, and use lower-cost capacity options safely. |
| [cloud/gcloud](cloud/gcloud/SKILL.md) | Google Cloud CLI (gcloud) — GCP Command Line Interface | Install, authenticate, and manage Google Cloud Platform resources including Compute Engine, Cloud Storage, IAM, and App  |
| [cloud/identity-access-governance](cloud/identity-access-governance/SKILL.md) | Identity & Access Governance | Enforce least privilege, periodic access reviews, and break-glass controls across cloud IAM. |
| [cloud/tagging-policy-enforcement](cloud/tagging-policy-enforcement/SKILL.md) | Tagging Policy Enforcement | Enforce required cloud metadata tags for ownership, cost allocation, lifecycle, and compliance. |

### infra
| Skill | Title | Description |
|---|---|---|
| [infra/ansible](infra/ansible/SKILL.md) | Ansible — Configuration Management & Automation | Install, configure, and manage Ansible for automating server provisioning, configuration, and deployments. Covers invent |
| [infra/backup-disaster-recovery](infra/backup-disaster-recovery/SKILL.md) | Backup & Disaster Recovery — Database and Offsite Protection | Create reliable backups, sync them offsite, and restore fast with verification. |
| [infra/canary-bluegreen-deployments](infra/canary-bluegreen-deployments/SKILL.md) | Canary & Blue/Green Deployments | Roll out changes gradually, validate live metrics, and rollback automatically when risk signals appear. |
| [infra/capacity-planning-forecasting](infra/capacity-planning-forecasting/SKILL.md) | Capacity Planning & Forecasting | Predict saturation before incidents by modeling growth trends in compute, storage, and traffic. |
| [infra/certbot](infra/certbot/SKILL.md) | Certbot — Let's Encrypt TLS Certificates | Install, configure, and manage Certbot for automatic TLS certificate provisioning via Let's Encrypt. Covers nginx/Apache |
| [infra/chaos-engineering](infra/chaos-engineering/SKILL.md) | Chaos Engineering — Controlled Failure Validation | Inject controlled faults to verify recovery, alerting, and resilience behavior before real incidents happen. |
| [infra/chatops-incident-communication](infra/chatops-incident-communication/SKILL.md) | ChatOps & Incident Communication | Send actionable alerts to team channels and auto-generate postmortems after incidents are resolved. |
| [infra/compliance-evidence-automation](infra/compliance-evidence-automation/SKILL.md) | Compliance Evidence Automation | Automatically collect, package, and publish audit-ready evidence for SOC2/HIPAA/PCI controls. |
| [infra/data-retention-archival](infra/data-retention-archival/SKILL.md) | Data Retention & Archival | Apply lifecycle policies for operational logs/data while supporting compliance and restoreability. |
| [infra/docker-compose](infra/docker-compose/SKILL.md) | Docker Compose — Multi-Container Applications | Install, configure, and manage Docker Compose for defining and running multi-container applications. Covers compose file |
| [infra/gitlab-runner](infra/gitlab-runner/SKILL.md) | GitLab Runner — CI/CD Job Executor | Install, register, and manage GitLab Runner for executing CI/CD pipelines. Covers Docker and Shell executors, configurat |
| [infra/grafana](infra/grafana/SKILL.md) | Grafana — Observability & Dashboards | Install, configure, and manage Grafana for data visualization, dashboards, and alerting. Covers data sources, dashboard  |
| [infra/high-availability-clustering](infra/high-availability-clustering/SKILL.md) | High Availability & Clustering | Build fault-tolerant data and traffic layers using replication, sentinel failover, and active health checks. |
| [infra/incident-diagnostics](infra/incident-diagnostics/SKILL.md) | Incident Diagnostics — System Troubleshooting & Root Cause Analysis | Triage Linux incidents quickly using CPU, memory, disk, process, and network evidence. |
| [infra/infrastructure-drift-remediation](infra/infrastructure-drift-remediation/SKILL.md) | Infrastructure Drift Remediation | Detect and reconcile cloud infrastructure drift against Terraform source of truth. |
| [infra/jenkins](infra/jenkins/SKILL.md) | Jenkins — CI/CD Automation Server | Install, configure, and manage Jenkins for continuous integration and deployment. Covers pipelines, Jenkinsfile, plugins |
| [infra/kubernetes](infra/kubernetes/SKILL.md) | Kubernetes — Container Orchestration | Manage Kubernetes clusters with kubectl — deployments, services, ingress, storage, debugging, Helm, and common troublesh |
| [infra/log-rotation-storage-maintenance](infra/log-rotation-storage-maintenance/SKILL.md) | Log Rotation & Storage Maintenance | Prevent disk exhaustion with logrotate policies, inode diagnostics, and safe Docker cleanup routines. |
| [infra/multi-region-failover](infra/multi-region-failover/SKILL.md) | Multi-Region Failover | Maintain service continuity during regional outages with tested failover and recovery playbooks. |
| [infra/openobserve](infra/openobserve/SKILL.md) | openobserve | OpenObserve observability platform operations |
| [infra/patch-management-os-upgrades](infra/patch-management-os-upgrades/SKILL.md) | Patch Management & OS Upgrades | Apply security updates safely, handle unattended upgrades, and coordinate reboots with minimal service impact. |
| [infra/performance-tuning-stress-testing](infra/performance-tuning-stress-testing/SKILL.md) | Performance Tuning & Stress Testing | Tune kernel and web stack settings, then prove improvement with repeatable load tests. |
| [infra/prometheus](infra/prometheus/SKILL.md) | Prometheus — Monitoring & Alerting | Install, configure, and manage Prometheus for metrics collection, alerting, and monitoring. Covers scrape configuration, |
| [infra/queue-reliability-ops](infra/queue-reliability-ops/SKILL.md) | Queue Reliability Operations | Keep asynchronous systems healthy using retries, DLQs, backpressure, and poison-message handling. |
| [infra/service-dependency-mapping](infra/service-dependency-mapping/SKILL.md) | Service Dependency Mapping | Build and maintain a dependency graph so incident responders can quickly identify blast radius and ownership. |
| [infra/slo-sli-error-budget](infra/slo-sli-error-budget/SKILL.md) | SLO, SLI & Error Budget Operations | Define reliability targets, monitor burn rate, and gate risky changes when error budgets are exhausted. |
| [infra/ssl-certificate-lifecycle](infra/ssl-certificate-lifecycle/SKILL.md) | SSL Certificate Lifecycle Management | Manage TLS from issuance to renewal, emergency replacement, and internal self-signed cert generation. |
| [infra/terraform](infra/terraform/SKILL.md) | Terraform — Infrastructure as Code | Install, configure, and manage Terraform for provisioning cloud and on-prem infrastructure. Covers init, plan, apply, st |
| [infra/zero-downtime-deploy](infra/zero-downtime-deploy/SKILL.md) | Zero-Downtime Deploy — Release, Migrate, Rollback | Deploy application updates with minimal or no user-visible downtime. |

### runtime
| Skill | Title | Description |
|---|---|---|
| [runtime/golang](runtime/golang/SKILL.md) | Go (Golang) — Runtime & Build Environment | Install Go, manage modules, build/run/test programs, cross-compile for multiple platforms, and deploy Go services with s |
| [runtime/java](runtime/java/SKILL.md) | Java — OpenJDK Runtime & Build Tools | Install OpenJDK, configure JAVA_HOME, manage builds with Maven and Gradle, set up Tomcat, and deploy Spring Boot applica |
| [runtime/nodejs](runtime/nodejs/SKILL.md) | Node.js — JavaScript Runtime Environment | Install Node.js via NVM, manage packages with npm/yarn/pnpm, run production apps with PM2, and configure server-side Jav |
| [runtime/python](runtime/python/SKILL.md) | Python — Runtime Environment & Package Management | Install Python, manage virtual environments, use pip/pyenv, run ASGI/WSGI servers with uvicorn/gunicorn, and deploy Pyth |
| [runtime/rust](runtime/rust/SKILL.md) | Rust — Systems Programming Language & Cargo Build System | Install Rust via rustup, manage projects with Cargo, build/test/run programs, cross-compile for multiple targets, create |

### security
| Skill | Title | Description |
|---|---|---|
| [security/automated-compliance-auditing](security/automated-compliance-auditing/SKILL.md) | Automated Compliance & Auditing (SecOps) | Continuously validate host and cloud posture using benchmark scans, network diffing, and IAM policy checks. |
| [security/centralized-secrets-management](security/centralized-secrets-management/SKILL.md) | Centralized Secrets Management | Move secrets from local files to managed secret backends with rotation and access auditing. |
| [security/compliance-scan](security/compliance-scan/SKILL.md) | Compliance Scan — NIST 800-53 r5 + CMMC Control Checks | Scan a Linux server against NIST 800-53 rev 5 and CMMC Level 1/2/3 controls. |
| [security/container-runtime-hardening](security/container-runtime-hardening/SKILL.md) | Container Runtime Hardening | Reduce container attack surface using least privilege, runtime controls, and policy enforcement. |
| [security/nessus](security/nessus/SKILL.md) | Nessus — Vulnerability Scanner | Install, configure, and manage Tenable Nessus for vulnerability scanning, compliance auditing, and security assessment o |
| [security/openvas](security/openvas/SKILL.md) | OpenVAS / Greenbone — Vulnerability Scanner | Install, configure, and manage the Greenbone Vulnerability Management (GVM/OpenVAS) stack for network vulnerability scan |
| [security/sbom-supply-chain-security](security/sbom-supply-chain-security/SKILL.md) | SBOM & Supply Chain Security | Generate SBOMs, verify signed artifacts, and reduce dependency-chain risk. |
| [security/secrets-environment-management](security/secrets-environment-management/SKILL.md) | Secrets & Environment Management | Manage `.env` secrets securely, enforce permissions, and rotate compromised credentials with controlled service restarts |
| [security/splunk](security/splunk/SKILL.md) | Splunk — Log Analysis & SIEM | Install, configure, and manage Splunk Enterprise and Universal Forwarder for log aggregation, search, alerting, and secu |
| [security/ssh-hardening-incident-response](security/ssh-hardening-incident-response/SKILL.md) | SSH Hardening & Incident Response | Secure SSH access and respond quickly to brute-force or credential compromise events. |
| [security/waf-ddos-operations](security/waf-ddos-operations/SKILL.md) | WAF & DDoS Operations | Protect public services with managed and custom WAF rules, emergency blocks, and false-positive tuning. |
| [security/wazuh](security/wazuh/SKILL.md) | Wazuh — SIEM / XDR Platform | Install, configure, and manage Wazuh for threat detection, integrity monitoring, incident response, and regulatory compl |

### server
| Skill | Title | Description |
|---|---|---|
| [server/advanced-database-tuning](server/advanced-database-tuning/SKILL.md) | Advanced Database Tuning | Improve database performance with slow query analysis, vacuum strategy, and connection pooling. |
| [server/apache](server/apache/SKILL.md) | Apache HTTP Server | Install, configure, and manage Apache for virtual hosting, PHP apps, WordPress, SSL, reverse proxying, and .htaccess rul |
| [server/caddy](server/caddy/SKILL.md) | Caddy — Modern Web Server with Automatic HTTPS | Install, configure, and manage Caddy for web serving, reverse proxying, and automatic TLS. Covers Caddyfile syntax, auto |
| [server/cassandra](server/cassandra/SKILL.md) | Cassandra — Distributed NoSQL Database | Install, configure, and manage Apache Cassandra for high-availability, wide-column data storage. Covers CQL, keyspaces,  |
| [server/cloudflare-install](server/cloudflare-install/SKILL.md) | cloudflare-install — Cloudflare Tunnel Setup | Install and configure Cloudflare Tunnel (cloudflared) to expose services securely without opening ports. |
| [server/cloudflare-ops](server/cloudflare-ops/SKILL.md) | cloudflare-ops — Cloudflare Tunnel Operations | Manage Cloudflare Tunnels, DNS routing, and service exposure after cloudflared is installed. |
| [server/dns-operations](server/dns-operations/SKILL.md) | DNS Operations | Perform safe DNS changes with rollback strategy, propagation verification, and outage-aware execution. |
| [server/elasticsearch](server/elasticsearch/SKILL.md) | Elasticsearch — Search & Analytics Engine | Install, configure, and manage Elasticsearch for full-text search, log analytics, and real-time data indexing. Covers in |
| [server/haproxy](server/haproxy/SKILL.md) | HAProxy — High Availability Load Balancer | Install, configure, and manage HAProxy for TCP/HTTP load balancing, SSL termination, health checks, and traffic manageme |
| [server/memcached](server/memcached/SKILL.md) | Memcached — Distributed Memory Cache | Install, configure, and manage Memcached for high-performance in-memory key-value caching. Covers configuration, stats,  |
| [server/mongodb](server/mongodb/SKILL.md) | MongoDB — Document Database | Install, configure, and manage MongoDB for document storage. Covers collections, indexes, replica sets, sharding, backup |
| [server/mysql](server/mysql/SKILL.md) | MySQL — Relational Database | Install, configure, and manage MySQL — databases, users, backups, replication, InnoDB tuning, and security hardening. |
| [server/nginx](server/nginx/SKILL.md) | Nginx — Web Server & Reverse Proxy | Install, configure, and manage Nginx for static sites, reverse proxying, SSL termination, load balancing, and performanc |
| [server/postgres](server/postgres/SKILL.md) | PostgreSQL — Relational Database | Install, configure, and manage PostgreSQL — databases, users, backups, replication, performance tuning, and monitoring. |
| [server/rabbitmq](server/rabbitmq/SKILL.md) | RabbitMQ — Message Broker | Install, configure, and manage RabbitMQ for message queuing, pub/sub, and event-driven architectures. Covers exchanges,  |
| [server/redis](server/redis/SKILL.md) | Redis — In-Memory Data Store | Install, configure, and manage Redis for caching, sessions, pub/sub, queues, and real-time data. Covers persistence, Sen |
| [server/sqlite](server/sqlite/SKILL.md) | SQLite — Embedded Relational Database | Use and manage SQLite for lightweight, serverless, embedded databases. Covers database creation, schema, queries, backup |
| [server/user-permission-ops](server/user-permission-ops/SKILL.md) | User & Permission Operations — Access, Sudo, Ownership Fixes | Create users safely, grant least-privilege sudo access, and fix file permission issues without breaking services. |
| [server/wireguard](server/wireguard/SKILL.md) | WireGuard — Modern VPN | Install, configure, and manage WireGuard for fast, secure VPN tunnels. Covers key generation, server/client setup, peer  |
<!-- AUTO-INDEX-END -->

## Authoring

- Use [`SKILL_TEMPLATE.md`](SKILL_TEMPLATE.md) as the baseline structure for new skills.
- Validate consistency across the repo:

```powershell
pwsh ./scripts/validate-skills.ps1
```

```bash
./scripts/validate-skills.sh
```

Validator checks include:
- Required skill sections (`Safety Rules`, `Quick Reference`, `Troubleshooting`)
- Presence of code blocks and validation guidance
- `manifest.json` license field
- Minimum manifest description quality (rejects very short descriptions)

- Optional strict mode (fails on warnings too):

```powershell
pwsh ./scripts/validate-skills.ps1 -Strict
```

```bash
./scripts/validate-skills.sh --strict
```

- Regenerate README summary + full index from manifest:

```powershell
pwsh ./scripts/generate-readme-index.ps1
```

```bash
./scripts/generate-readme-index.sh
```

