# Terraform — Infrastructure as Code

> Install, configure, and manage Terraform for provisioning cloud and on-prem infrastructure. Covers init, plan, apply, state management, workspaces, modules, providers, and import.

## Safety Rules

- **`terraform destroy` deletes real infrastructure** — always review the plan first.
- Never edit `.tfstate` files manually — use `terraform state` commands.
- Store state remotely (S3, GCS, Terraform Cloud) for team environments — local state causes conflicts.
- Always run `terraform plan` before `apply` to review changes.
- Lock state files in CI/CD — concurrent applies corrupt state.
- Sensitive values in state are stored in plaintext — encrypt state backend.
- Use `-target` sparingly — it can leave state inconsistent.

## Quick Reference

```bash
# Install (official HashiCorp repo — Ubuntu/Debian)
wget -O- https://apt.releases.hashicorp.com/gpg | \
  sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | \
  sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update && sudo apt install -y terraform

# Install (binary — any Linux)
TERRAFORM_VERSION="1.9.0"
wget "https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_amd64.zip"
unzip terraform_${TERRAFORM_VERSION}_linux_amd64.zip
sudo mv terraform /usr/local/bin/
terraform --version

# Enable tab completion
terraform -install-autocomplete

# Core workflow
terraform init                         # Initialize — download providers/modules
terraform plan                         # Preview changes
terraform apply                        # Apply changes (with confirmation)
terraform apply -auto-approve          # Apply without confirmation (⚠ CI only)
terraform destroy                      # Destroy all managed resources (⚠)
```

## Project Structure

```
project/
├── main.tf                # Primary resources
├── variables.tf           # Input variable declarations
├── outputs.tf             # Output values
├── providers.tf           # Provider configuration
├── terraform.tfvars       # Variable values (don't commit secrets)
├── backend.tf             # State backend config
├── versions.tf            # Required provider versions
└── modules/
    └── vpc/
        ├── main.tf
        ├── variables.tf
        └── outputs.tf
```

## Providers

```hcl
# versions.tf — pin provider versions
terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0"
    }
  }
}

# providers.tf
provider "aws" {
  region  = var.aws_region
  profile = "default"

  default_tags {
    tags = {
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  }
}
```

## Variables & Outputs

```hcl
# variables.tf
variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"

  validation {
    condition     = can(regex("^t[23]\\.", var.instance_type))
    error_message = "Only t2 or t3 instances allowed."
  }
}

variable "allowed_cidrs" {
  description = "CIDR blocks for ingress"
  type        = list(string)
  default     = ["10.0.0.0/8"]
}

variable "tags" {
  description = "Resource tags"
  type        = map(string)
  default     = {}
}

variable "db_password" {
  description = "Database password"
  type        = string
  sensitive   = true
}

# outputs.tf
output "instance_ip" {
  description = "Public IP of the instance"
  value       = aws_instance.web.public_ip
}

output "db_endpoint" {
  description = "Database endpoint"
  value       = aws_db_instance.main.endpoint
  sensitive   = true
}
```

```bash
# Set variables
terraform apply -var="aws_region=us-west-2" -var="instance_type=t3.small"

# Via environment variables
export TF_VAR_aws_region="us-west-2"
export TF_VAR_db_password="secret"

# Via file
terraform apply -var-file="production.tfvars"
```

## State Management

```bash
# List all resources in state
terraform state list

# Show specific resource
terraform state show aws_instance.web

# Move resource (rename without recreate)
terraform state mv aws_instance.web aws_instance.app

# Remove resource from state (unmanage — doesn't destroy)
terraform state rm aws_instance.legacy

# Import existing resource into state
terraform import aws_instance.web i-1234567890abcdef0
terraform import aws_s3_bucket.data my-bucket-name

# Pull remote state locally
terraform state pull > state_backup.json

# Push local state to remote
terraform state push state_backup.json

# Force unlock (if state is stuck locked)
terraform force-unlock <LOCK_ID>
```

### Remote State Backend

```hcl
# backend.tf — S3 backend
terraform {
  backend "s3" {
    bucket         = "my-terraform-state"
    key            = "prod/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-locks"
    encrypt        = true
  }
}

# backend.tf — Local backend (default)
terraform {
  backend "local" {
    path = "terraform.tfstate"
  }
}
```

```bash
# Initialize backend (after changing backend config)
terraform init -migrate-state

# Reconfigure backend
terraform init -reconfigure
```

## Workspaces

```bash
# List workspaces
terraform workspace list

# Create workspace
terraform workspace new staging
terraform workspace new production

# Switch workspace
terraform workspace select staging

# Show current workspace
terraform workspace show

# Delete workspace
terraform workspace delete staging

# Use workspace in config
# terraform.workspace returns the current workspace name
```

```hcl
# Use workspace for environment separation
resource "aws_instance" "web" {
  ami           = var.ami_id
  instance_type = terraform.workspace == "production" ? "t3.large" : "t3.micro"

  tags = {
    Name        = "web-${terraform.workspace}"
    Environment = terraform.workspace
  }
}
```

## Modules

```hcl
# Using a module
module "vpc" {
  source = "./modules/vpc"

  vpc_cidr    = "10.0.0.0/16"
  environment = var.environment
}

# Using remote module (Terraform Registry)
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.0.0"

  name = "my-vpc"
  cidr = "10.0.0.0/16"

  azs             = ["us-east-1a", "us-east-1b"]
  public_subnets  = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnets = ["10.0.10.0/24", "10.0.20.0/24"]

  enable_nat_gateway = true
}

# Using Git module
module "app" {
  source = "git::https://github.com/org/terraform-modules.git//modules/app?ref=v1.2.0"
}

# Reference module outputs
resource "aws_instance" "web" {
  subnet_id = module.vpc.public_subnets[0]
}
```

## Common Patterns

### Data Sources

```hcl
# Look up existing resources
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]  # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-*-24.04-amd64-server-*"]
  }
}

data "aws_vpc" "default" {
  default = true
}

resource "aws_instance" "web" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t3.micro"
  vpc_security_group_ids = [aws_security_group.web.id]
}
```

### Count & For Each

```hcl
# Count
resource "aws_instance" "web" {
  count         = 3
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t3.micro"
  tags = { Name = "web-${count.index}" }
}

# For each (map)
variable "instances" {
  default = {
    web  = "t3.micro"
    api  = "t3.small"
    worker = "t3.medium"
  }
}

resource "aws_instance" "app" {
  for_each      = var.instances
  ami           = data.aws_ami.ubuntu.id
  instance_type = each.value
  tags = { Name = each.key }
}
```

### Lifecycle Rules

```hcl
resource "aws_instance" "web" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t3.micro"

  lifecycle {
    create_before_destroy = true       # Zero-downtime replacement
    prevent_destroy       = true       # Block accidental deletion
    ignore_changes        = [tags]     # Don't track tag changes
  }
}
```

## CLI Commands Reference

```bash
# Format code
terraform fmt                          # Current directory
terraform fmt -recursive               # All subdirectories

# Validate syntax
terraform validate

# Show current state
terraform show

# Graph dependencies (outputs DOT format)
terraform graph | dot -Tpng > graph.png

# Taint resource (force recreation on next apply)
terraform taint aws_instance.web       # Deprecated — use -replace
terraform apply -replace="aws_instance.web"

# Output values
terraform output
terraform output instance_ip
terraform output -json

# Console (interactive expression evaluation)
terraform console

# Providers
terraform providers                    # List required providers
terraform providers lock               # Generate lock file
```

## Troubleshooting

```bash
# Verbose logging
export TF_LOG=DEBUG                    # TRACE, DEBUG, INFO, WARN, ERROR
export TF_LOG_PATH="terraform.log"
terraform apply

# State locked
terraform force-unlock <LOCK_ID>

# Provider version conflicts
terraform init -upgrade                # Update providers to latest allowed

# Resource drift (config doesn't match real state)
terraform plan -refresh-only           # Detect drift without planning changes
terraform apply -refresh-only          # Update state to match reality

# Dependency issues
terraform plan -out=plan.tfplan        # Save plan
terraform show plan.tfplan             # Inspect plan
terraform apply plan.tfplan            # Apply saved plan

# Destroy specific resource only
terraform destroy -target=aws_instance.web

# Clean up
rm -rf .terraform/                     # Remove providers/modules cache
rm terraform.tfstate.backup            # Remove backup state
terraform init                         # Re-initialize
```
