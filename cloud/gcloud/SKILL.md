# Google Cloud CLI (gcloud) — GCP Command Line Interface

> Install, authenticate, and manage Google Cloud Platform resources including Compute Engine, Cloud Storage, IAM, and App Engine deployments.

## Safety Rules

- Never commit service account key files — use `gcloud auth` or Workload Identity instead.
- Always verify the active project before destructive operations: `gcloud config get-value project`.
- Use `--quiet` flag in scripts to skip confirmation prompts (only when you're sure).
- Prefer `gcloud auth application-default login` for local dev over service account keys.
- Delete unused service account keys regularly.

## Quick Reference

```bash
# Check version
gcloud version

# Current configuration
gcloud config list

# Active account and project
gcloud auth list
gcloud config get-value project

# List compute instances
gcloud compute instances list

# List storage buckets
gcloud storage ls

# Interactive SSH to an instance
gcloud compute ssh my-instance --zone us-central1-a
```

## Installation

### Install on Debian/Ubuntu

```bash
# Add Google Cloud repo
sudo apt-get install -y apt-transport-https ca-certificates gnupg curl
curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo gpg --dearmor -o /usr/share/keyrings/cloud.google.gpg
echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" | sudo tee /etc/apt/sources.list.d/google-cloud-sdk.list
sudo apt-get update && sudo apt-get install -y google-cloud-cli
```

### Install on RHEL/Rocky/Alma

```bash
sudo tee /etc/yum.repos.d/google-cloud-sdk.repo << 'EOF'
[google-cloud-cli]
name=Google Cloud CLI
baseurl=https://packages.cloud.google.com/yum/repos/cloud-sdk-el9-x86_64
enabled=1
gpgcheck=1
repo_gpgcheck=0
gpgkey=https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg
EOF
sudo dnf install -y google-cloud-cli
```

### Install via script (any Linux)

```bash
curl https://sdk.cloud.google.com | bash
exec -l $SHELL   # Restart shell
gcloud init
```

### Update gcloud

```bash
gcloud components update
```

## Authentication & Configuration

### Interactive login

```bash
# Login with browser (user account)
gcloud auth login

# Set default project
gcloud config set project my-project-id

# Set default region/zone
gcloud config set compute/region us-central1
gcloud config set compute/zone us-central1-a

# Full interactive setup
gcloud init
```

### Application Default Credentials (for local dev)

```bash
gcloud auth application-default login
# Creates ~/.config/gcloud/application_default_credentials.json
```

### Service account authentication

```bash
# Activate service account
gcloud auth activate-service-account --key-file=service-account-key.json

# Verify
gcloud auth list
```

### Configuration profiles

```bash
# Create a new configuration
gcloud config configurations create staging
gcloud config set project my-staging-project
gcloud config set compute/zone us-west1-a

# Switch configurations
gcloud config configurations activate staging
gcloud config configurations activate default

# List configurations
gcloud config configurations list
```

## Compute Engine — Virtual Machines

```bash
# List instances
gcloud compute instances list

# Create an instance
gcloud compute instances create my-vm \
  --zone=us-central1-a \
  --machine-type=e2-medium \
  --image-family=ubuntu-2404-lts-amd64 \
  --image-project=ubuntu-os-cloud \
  --boot-disk-size=20GB \
  --tags=http-server,https-server

# Create with startup script
gcloud compute instances create web-server \
  --zone=us-central1-a \
  --machine-type=e2-small \
  --image-family=debian-12 \
  --image-project=debian-cloud \
  --metadata-from-file=startup-script=startup.sh

# SSH into instance
gcloud compute ssh my-vm --zone=us-central1-a

# SCP files
gcloud compute scp ./local-file.txt my-vm:~/remote-file.txt --zone=us-central1-a

# Stop / Start / Delete
gcloud compute instances stop my-vm --zone=us-central1-a
gcloud compute instances start my-vm --zone=us-central1-a
gcloud compute instances delete my-vm --zone=us-central1-a

# Resize machine type (must be stopped)
gcloud compute instances set-machine-type my-vm \
  --zone=us-central1-a --machine-type=e2-standard-4

# Describe an instance
gcloud compute instances describe my-vm --zone=us-central1-a

# List available machine types
gcloud compute machine-types list --filter="zone:us-central1-a" | head -30

# List images
gcloud compute images list --filter="family:ubuntu" | head -20

# Firewall rules
gcloud compute firewall-rules list
gcloud compute firewall-rules create allow-http \
  --allow=tcp:80 --target-tags=http-server --source-ranges=0.0.0.0/0
gcloud compute firewall-rules delete allow-http
```

## Cloud Storage — Buckets & Objects

```bash
# List buckets
gcloud storage ls

# Create a bucket
gcloud storage buckets create gs://my-unique-bucket --location=us-central1

# List objects
gcloud storage ls gs://my-bucket/
gcloud storage ls gs://my-bucket/** --long

# Upload / Download
gcloud storage cp ./local-file.txt gs://my-bucket/
gcloud storage cp gs://my-bucket/remote-file.txt ./
gcloud storage cp -r ./my-dir gs://my-bucket/backup/

# Sync (like rsync)
gcloud storage rsync ./local-dir gs://my-bucket/backup/ --recursive
gcloud storage rsync gs://my-bucket/backup/ ./local-dir --recursive --delete-unmatched-destination-objects

# Remove objects
gcloud storage rm gs://my-bucket/file.txt
gcloud storage rm gs://my-bucket/prefix/** --recursive

# Delete a bucket
gcloud storage rm gs://my-bucket --recursive   # Empty + delete

# Bucket info
gcloud storage buckets describe gs://my-bucket

# Set public access
gcloud storage buckets add-iam-policy-binding gs://my-bucket \
  --member=allUsers --role=roles/storage.objectViewer

# Generate signed URL
gcloud storage sign-url gs://my-bucket/file.zip --duration=1h
```

## IAM — Identity & Access Management

```bash
# List service accounts
gcloud iam service-accounts list

# Create a service account
gcloud iam service-accounts create deploy-sa \
  --display-name="Deployment Service Account"

# Grant a role to a service account
gcloud projects add-iam-policy-binding my-project \
  --member="serviceAccount:deploy-sa@my-project.iam.gserviceaccount.com" \
  --role="roles/storage.admin"

# List IAM policy for the project
gcloud projects get-iam-policy my-project --format=json

# Create a service account key (prefer Workload Identity instead)
gcloud iam service-accounts keys create key.json \
  --iam-account=deploy-sa@my-project.iam.gserviceaccount.com

# List roles
gcloud iam roles list --filter="stage:GA" | head -30

# List keys for a service account
gcloud iam service-accounts keys list \
  --iam-account=deploy-sa@my-project.iam.gserviceaccount.com

# Delete a service account
gcloud iam service-accounts delete deploy-sa@my-project.iam.gserviceaccount.com
```

## App Engine — Deploy Web Apps

```bash
# Initialize App Engine (once per project)
gcloud app create --region=us-central

# Deploy
gcloud app deploy

# Deploy with specific version
gcloud app deploy --version=v2 --no-promote

# Browse the app
gcloud app browse

# View logs
gcloud app logs tail -s default

# List versions
gcloud app versions list

# Route traffic
gcloud app services set-traffic default --splits=v1=0.5,v2=0.5

# Delete old version
gcloud app versions delete v1

# Describe app
gcloud app describe
```

### Example `app.yaml` (Python)

```yaml
runtime: python312
entrypoint: gunicorn -b :$PORT main:app

instance_class: F2
automatic_scaling:
  min_instances: 0
  max_instances: 5

env_variables:
  ENV: production
```

## Useful Patterns

```bash
# List all projects
gcloud projects list

# Switch project
gcloud config set project other-project-id

# List available zones/regions
gcloud compute zones list
gcloud compute regions list

# Get project billing info
gcloud billing accounts list

# Export all instance IPs
gcloud compute instances list --format="value(networkInterfaces[0].accessConfigs[0].natIP)"

# List all APIs enabled
gcloud services list --enabled

# Enable an API
gcloud services enable compute.googleapis.com
gcloud services enable storage.googleapis.com

# Cloud SQL instances
gcloud sql instances list

# GKE clusters
gcloud container clusters list
```

## Troubleshooting

```bash
# Check active configuration
gcloud config list

# Verbose mode
gcloud compute instances list --verbosity=debug

# Re-authenticate
gcloud auth login --force

# Clear application default credentials
gcloud auth application-default revoke

# Quota errors — check quotas
gcloud compute project-info describe --format="table(quotas)"

# API not enabled
gcloud services enable compute.googleapis.com

# Check project permissions
gcloud projects get-iam-policy $(gcloud config get-value project) \
  --flatten="bindings[].members" \
  --filter="bindings.members:$(gcloud config get-value account)" \
  --format="table(bindings.role)"
```
