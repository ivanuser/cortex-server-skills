# Azure CLI — Microsoft Azure Command Line Interface

> Install, authenticate, and manage Azure resources including VMs, storage accounts, resource groups, and AKS clusters from the terminal.

## Safety Rules

- Always verify the active subscription before destructive operations: `az account show`.
- Never hardcode credentials — use `az login`, managed identities, or service principals.
- Use `--no-wait` for long operations in scripts, then check status separately.
- Resource groups are the blast radius — deleting one removes everything inside it.
- Use `--dry-run` where supported, or `az deployment group what-if` for ARM templates.

## Quick Reference

```bash
# Check version
az version

# Login
az login

# Current subscription
az account show --output table

# List resource groups
az group list --output table

# List VMs
az vm list --output table

# List storage accounts
az storage account list --output table
```

## Installation

### Install on Debian/Ubuntu

```bash
# One-liner
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash

# Or manually
sudo apt-get install -y ca-certificates curl apt-transport-https lsb-release gnupg
sudo mkdir -p /etc/apt/keyrings
curl -sLS https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor | sudo tee /etc/apt/keyrings/microsoft.gpg > /dev/null
sudo chmod go+r /etc/apt/keyrings/microsoft.gpg
AZ_DIST=$(lsb_release -cs)
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/microsoft.gpg] https://packages.microsoft.com/repos/azure-cli/ $AZ_DIST main" | sudo tee /etc/apt/sources.list.d/azure-cli.list
sudo apt-get update && sudo apt-get install -y azure-cli
```

### Install on RHEL/Rocky/Alma

```bash
sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc
sudo dnf install -y https://packages.microsoft.com/config/rhel/9.0/packages-microsoft-prod.rpm
sudo dnf install -y azure-cli
```

### Install via pip

```bash
pip3 install azure-cli
```

### Update

```bash
az upgrade
```

## Authentication

### Interactive login

```bash
# Browser-based login
az login

# Device code login (headless/SSH)
az login --use-device-code

# Login to a specific tenant
az login --tenant TENANT_ID
```

### Service principal login

```bash
# Create service principal
az ad sp create-for-rbac --name "deploy-sp" --role Contributor \
  --scopes /subscriptions/SUBSCRIPTION_ID

# Login with service principal
az login --service-principal \
  --username APP_ID \
  --password CLIENT_SECRET \
  --tenant TENANT_ID
```

### Subscription management

```bash
# List subscriptions
az account list --output table

# Set active subscription
az account set --subscription "My Subscription"
az account set --subscription SUBSCRIPTION_ID

# Show current subscription
az account show --output table
```

## Resource Groups

```bash
# List resource groups
az group list --output table

# Create a resource group
az group create --name my-rg --location eastus

# Show resource group details
az group show --name my-rg

# List all resources in a group
az resource list --resource-group my-rg --output table

# Delete a resource group (deletes EVERYTHING in it)
az group delete --name my-rg --yes --no-wait

# Tag a resource group
az group update --name my-rg --tags env=dev team=backend
```

## Virtual Machines

```bash
# List VMs
az vm list --output table
az vm list --resource-group my-rg --output table --show-details

# Create a VM (Ubuntu)
az vm create \
  --resource-group my-rg \
  --name my-vm \
  --image Ubuntu2404 \
  --size Standard_B2s \
  --admin-username azureuser \
  --generate-ssh-keys \
  --public-ip-sku Standard

# Create a VM (custom options)
az vm create \
  --resource-group my-rg \
  --name web-server \
  --image Debian12 \
  --size Standard_D2s_v3 \
  --admin-username admin \
  --ssh-key-values ~/.ssh/id_rsa.pub \
  --nsg-rule SSH \
  --custom-data cloud-init.yaml

# Show VM details
az vm show --resource-group my-rg --name my-vm --show-details --output table

# Start / Stop / Restart / Deallocate / Delete
az vm start --resource-group my-rg --name my-vm
az vm stop --resource-group my-rg --name my-vm
az vm restart --resource-group my-rg --name my-vm
az vm deallocate --resource-group my-rg --name my-vm   # Stop + free compute (no charges)
az vm delete --resource-group my-rg --name my-vm --yes

# Resize a VM
az vm resize --resource-group my-rg --name my-vm --size Standard_D4s_v3

# List available VM sizes
az vm list-sizes --location eastus --output table

# List available images
az vm image list --output table                         # Commonly used
az vm image list --all --publisher Canonical --output table | head -30

# Open a port
az vm open-port --resource-group my-rg --name my-vm --port 80 --priority 1010

# Get public IP
az vm show --resource-group my-rg --name my-vm --show-details --query publicIps -o tsv

# Run a command on a VM
az vm run-command invoke --resource-group my-rg --name my-vm \
  --command-id RunShellScript --scripts "apt-get update && apt-get install -y nginx"
```

## Storage Accounts

```bash
# List storage accounts
az storage account list --output table

# Create a storage account
az storage account create \
  --name mystorageaccount \
  --resource-group my-rg \
  --location eastus \
  --sku Standard_LRS \
  --kind StorageV2

# Get connection string
az storage account show-connection-string --name mystorageaccount --resource-group my-rg

# Get account keys
az storage account keys list --account-name mystorageaccount --resource-group my-rg --output table

# Create a blob container
az storage container create --name mycontainer --account-name mystorageaccount

# Upload a blob
az storage blob upload \
  --account-name mystorageaccount \
  --container-name mycontainer \
  --file ./local-file.txt \
  --name remote-file.txt

# List blobs
az storage blob list --account-name mystorageaccount --container-name mycontainer --output table

# Download a blob
az storage blob download \
  --account-name mystorageaccount \
  --container-name mycontainer \
  --name remote-file.txt \
  --file ./downloaded.txt

# Delete a blob
az storage blob delete --account-name mystorageaccount --container-name mycontainer --name remote-file.txt

# Generate SAS token
az storage blob generate-sas \
  --account-name mystorageaccount \
  --container-name mycontainer \
  --name file.zip \
  --permissions r \
  --expiry 2026-12-31T00:00:00Z \
  --output tsv

# Delete storage account
az storage account delete --name mystorageaccount --resource-group my-rg --yes
```

## AKS — Azure Kubernetes Service

```bash
# List clusters
az aks list --output table

# Create a cluster
az aks create \
  --resource-group my-rg \
  --name my-cluster \
  --node-count 3 \
  --node-vm-size Standard_B2s \
  --enable-managed-identity \
  --generate-ssh-keys

# Get kubeconfig credentials
az aks get-credentials --resource-group my-rg --name my-cluster

# Verify connection
kubectl get nodes

# Scale node pool
az aks scale --resource-group my-rg --name my-cluster --node-count 5

# Upgrade cluster
az aks get-upgrades --resource-group my-rg --name my-cluster --output table
az aks upgrade --resource-group my-rg --name my-cluster --kubernetes-version 1.29.0

# Show cluster info
az aks show --resource-group my-rg --name my-cluster --output table

# Delete cluster
az aks delete --resource-group my-rg --name my-cluster --yes --no-wait

# Add a node pool
az aks nodepool add \
  --resource-group my-rg \
  --cluster-name my-cluster \
  --name gpupool \
  --node-count 1 \
  --node-vm-size Standard_NC6 \
  --labels workload=gpu
```

## Useful Patterns

```bash
# List all locations
az account list-locations --output table

# Find resources by tag
az resource list --tag env=prod --output table

# Export ARM template from resource group
az group export --name my-rg > template.json

# Deploy ARM template
az deployment group create \
  --resource-group my-rg \
  --template-file template.json \
  --parameters @parameters.json

# What-if (dry run for deployments)
az deployment group what-if \
  --resource-group my-rg \
  --template-file template.json

# Query with JMESPath
az vm list --query "[?powerState=='VM running'].{Name:name, RG:resourceGroup}" --output table

# Cost info (requires Cost Management)
az consumption usage list --start-date 2026-03-01 --end-date 2026-03-20 --output table
```

## Troubleshooting

```bash
# Check CLI version
az version

# Debug mode
az vm list --debug

# Clear cached login
az logout
az login

# Token refresh issues
az account get-access-token

# Check available extensions
az extension list-available --output table

# Install an extension
az extension add --name aks-preview

# Reset credentials
az ad sp credential reset --id APP_ID
```
