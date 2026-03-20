# AWS CLI v2 — Amazon Web Services Command Line Interface

> Install, configure, and use the AWS CLI v2 for managing S3, EC2, IAM, CloudFormation, and other AWS services from the terminal.

## Safety Rules

- Never commit or log AWS credentials — use `~/.aws/credentials` or environment variables only.
- Always confirm the target region and account before destructive operations (`terminate`, `delete`, `rm`).
- Use `--dry-run` on EC2 commands when testing permissions or syntax.
- Prefer IAM roles over long-lived access keys where possible.
- Back up CloudFormation templates before updating stacks.

## Quick Reference

```bash
# Check version
aws --version

# Configure default profile
aws configure

# List S3 buckets
aws s3 ls

# List EC2 instances
aws ec2 describe-instances --query 'Reservations[*].Instances[*].[InstanceId,State.Name,InstanceType,PublicIpAddress]' --output table

# Get current caller identity
aws sts get-caller-identity

# List IAM users
aws iam list-users --output table
```

## Installation

### Install on Linux (x86_64)

```bash
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install
rm -rf aws awscliv2.zip
aws --version
```

### Install on Linux (ARM / aarch64)

```bash
curl "https://awscli.amazonaws.com/awscli-exe-linux-aarch64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install
rm -rf aws awscliv2.zip
```

### Update existing installation

```bash
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install --bin-dir /usr/local/bin --install-dir /usr/local/aws-cli --update
rm -rf aws awscliv2.zip
```

### Install via pip (alternative)

```bash
pip3 install awscli --upgrade --user
```

## Configuration & Profiles

### Initial setup

```bash
# Interactive configuration (sets default profile)
aws configure
# Prompts: Access Key ID, Secret Access Key, Default region, Output format

# Verify
aws sts get-caller-identity
```

### Config files

```
~/.aws/
├── config        # Region, output format, profiles
└── credentials   # Access keys (keep secure!)
```

### Named profiles

```bash
# Create a named profile
aws configure --profile staging

# Use a named profile
aws s3 ls --profile staging

# Set default via environment
export AWS_PROFILE=staging
export AWS_DEFAULT_REGION=us-east-1
```

### Example `~/.aws/config`

```ini
[default]
region = us-east-1
output = json

[profile staging]
region = us-west-2
output = table

[profile prod]
region = us-east-1
output = json
role_arn = arn:aws:iam::123456789012:role/ProductionAdmin
source_profile = default
```

### Environment variable authentication

```bash
export AWS_ACCESS_KEY_ID=AKIAIOSFODNN7EXAMPLE
export AWS_SECRET_ACCESS_KEY=wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY
export AWS_DEFAULT_REGION=us-east-1
```

## S3 — Object Storage

```bash
# List all buckets
aws s3 ls

# List objects in a bucket
aws s3 ls s3://my-bucket/
aws s3 ls s3://my-bucket/prefix/ --recursive --human-readable

# Create a bucket
aws s3 mb s3://my-new-bucket --region us-east-1

# Copy files
aws s3 cp myfile.txt s3://my-bucket/
aws s3 cp s3://my-bucket/myfile.txt ./
aws s3 cp s3://my-bucket/myfile.txt s3://other-bucket/

# Sync directories (like rsync)
aws s3 sync ./local-dir s3://my-bucket/backup/
aws s3 sync s3://my-bucket/backup/ ./local-dir
aws s3 sync ./build s3://my-bucket/ --delete   # Mirror (removes extra files in dest)

# Remove files
aws s3 rm s3://my-bucket/myfile.txt
aws s3 rm s3://my-bucket/prefix/ --recursive   # Delete all under prefix

# Delete a bucket (must be empty)
aws s3 rb s3://my-bucket
aws s3 rb s3://my-bucket --force   # Empty + delete

# Presigned URL (temporary access)
aws s3 presign s3://my-bucket/file.zip --expires-in 3600

# Copy with storage class
aws s3 cp large.zip s3://my-bucket/ --storage-class GLACIER

# Bucket size estimate
aws s3 ls s3://my-bucket --recursive --summarize | tail -2
```

## EC2 — Compute Instances

```bash
# List instances (formatted)
aws ec2 describe-instances \
  --query 'Reservations[*].Instances[*].[InstanceId,State.Name,InstanceType,PublicIpAddress,Tags[?Key==`Name`].Value|[0]]' \
  --output table

# Launch an instance
aws ec2 run-instances \
  --image-id ami-0abcdef1234567890 \
  --instance-type t3.micro \
  --key-name my-keypair \
  --security-group-ids sg-0123456789abcdef0 \
  --subnet-id subnet-0123456789abcdef0 \
  --count 1 \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=my-server}]'

# Dry run (test permissions without launching)
aws ec2 run-instances --image-id ami-0abcdef1234567890 --instance-type t3.micro --dry-run

# Stop / Start / Reboot / Terminate
aws ec2 stop-instances --instance-ids i-0123456789abcdef0
aws ec2 start-instances --instance-ids i-0123456789abcdef0
aws ec2 reboot-instances --instance-ids i-0123456789abcdef0
aws ec2 terminate-instances --instance-ids i-0123456789abcdef0

# Get instance status
aws ec2 describe-instance-status --instance-ids i-0123456789abcdef0

# List AMIs (your account)
aws ec2 describe-images --owners self --output table

# List available key pairs
aws ec2 describe-key-pairs --output table

# Create a key pair
aws ec2 create-key-pair --key-name my-key --query 'KeyMaterial' --output text > my-key.pem
chmod 400 my-key.pem

# Security groups
aws ec2 describe-security-groups --output table
aws ec2 authorize-security-group-ingress --group-id sg-xxx --protocol tcp --port 22 --cidr 0.0.0.0/0
```

## IAM — Identity & Access Management

```bash
# List users
aws iam list-users --output table

# Create a user
aws iam create-user --user-name deploy-bot

# Create access key for a user
aws iam create-access-key --user-name deploy-bot

# Attach a managed policy
aws iam attach-user-policy --user-name deploy-bot \
  --policy-arn arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess

# List attached policies
aws iam list-attached-user-policies --user-name deploy-bot

# List roles
aws iam list-roles --output table

# List groups
aws iam list-groups --output table

# Get account summary
aws iam get-account-summary

# Delete access key
aws iam delete-access-key --user-name deploy-bot --access-key-id AKIAXXXXXXXX

# Delete user (detach policies first)
aws iam detach-user-policy --user-name deploy-bot --policy-arn arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess
aws iam delete-user --user-name deploy-bot
```

## CloudFormation — Infrastructure as Code

```bash
# Validate a template
aws cloudformation validate-template --template-body file://template.yaml

# Create a stack
aws cloudformation create-stack \
  --stack-name my-stack \
  --template-body file://template.yaml \
  --parameters ParameterKey=Env,ParameterValue=prod \
  --capabilities CAPABILITY_IAM

# Update a stack
aws cloudformation update-stack \
  --stack-name my-stack \
  --template-body file://template.yaml \
  --parameters ParameterKey=Env,ParameterValue=prod

# List stacks
aws cloudformation list-stacks --stack-status-filter CREATE_COMPLETE UPDATE_COMPLETE --output table

# Describe stack events (troubleshooting)
aws cloudformation describe-stack-events --stack-name my-stack --output table | head -40

# Stack outputs
aws cloudformation describe-stacks --stack-name my-stack \
  --query 'Stacks[0].Outputs' --output table

# Delete a stack
aws cloudformation delete-stack --stack-name my-stack

# Wait for stack completion
aws cloudformation wait stack-create-complete --stack-name my-stack
aws cloudformation wait stack-update-complete --stack-name my-stack
```

## Useful Patterns

```bash
# Get all regions
aws ec2 describe-regions --query 'Regions[*].RegionName' --output text

# Estimate monthly cost (requires Cost Explorer enabled)
aws ce get-cost-and-usage \
  --time-period Start=2026-03-01,End=2026-03-31 \
  --granularity MONTHLY --metrics "BlendedCost" \
  --output table

# Export all running instance IPs
aws ec2 describe-instances \
  --filters "Name=instance-state-name,Values=running" \
  --query 'Reservations[*].Instances[*].PublicIpAddress' \
  --output text

# Tail CloudWatch logs
aws logs tail /aws/lambda/my-function --follow

# SSM Session Manager (SSH alternative)
aws ssm start-session --target i-0123456789abcdef0
```

## Troubleshooting

```bash
# Debug API calls
aws s3 ls --debug 2>&1 | head -50

# Check credential chain
aws sts get-caller-identity

# Expired credentials?
aws configure list

# Region not set?
aws configure get region

# Permission denied — check policy
aws iam simulate-principal-policy \
  --policy-source-arn arn:aws:iam::123456789012:user/myuser \
  --action-names s3:GetObject \
  --resource-arns arn:aws:s3:::my-bucket/*
```
