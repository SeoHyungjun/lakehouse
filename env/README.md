# Environment Configuration

This directory contains environment-specific configuration files for the Lakehouse infrastructure.

## Directory Structure

```
env/
├── dev/
│   ├── terraform.tfvars       # Development Terraform configuration
│   ├── helm-values.yaml       # Development Helm values overrides
│   └── minio-values.yaml      # Development MinIO-specific values
├── staging/
│   ├── terraform.tfvars       # Staging Terraform configuration
│   ├── helm-values.yaml       # Staging Helm values overrides
│   └── minio-values.yaml      # Staging MinIO-specific values
└── prod/
    ├── terraform.tfvars       # Production Terraform configuration
    ├── helm-values.yaml       # Production Helm values overrides
    └── minio-values.yaml      # Production MinIO-specific values
```

## Purpose

Following the principle of **Configuration vs Code Separation** (README.md section 3.2):

- **Code is immutable** - Infrastructure code in `infra/` does not change between environments
- **Configuration is environment-specific** - Only values in this directory change

## Usage

### Apply Configuration to an Environment

```bash
cd ../infra/

# Development
terraform plan -var-file=../env/dev/terraform.tfvars
terraform apply -var-file=../env/dev/terraform.tfvars

# Staging
terraform plan -var-file=../env/staging/terraform.tfvars
terraform apply -var-file=../env/staging/terraform.tfvars

# Production
terraform plan -var-file=../env/prod/terraform.tfvars
terraform apply -var-file=../env/prod/terraform.tfvars
```

### Apply Helm Values to Platform Components

```bash
# Install MinIO with environment-specific values
helm install minio ./platform/minio \
  --namespace lakehouse-platform \
  --create-namespace \
  --values env/dev/helm-values.yaml

# Install Trino with environment-specific values
helm install trino ./platform/trino \
  --namespace lakehouse-platform \
  --values env/dev/helm-values.yaml

# Install all components with environment-specific values
# Development
helm install argocd ./platform/argocd \
  --namespace argocd \
  --create-namespace \
  --values env/dev/helm-values.yaml \
  --set repoURL=https://github.com/your-org/lakehouse.git \
  --set environment=dev

# Staging
helm install argocd ./platform/argocd \
  --namespace argocd \
  --create-namespace \
  --values env/staging/helm-values.yaml \
  --set repoURL=https://github.com/your-org/lakehouse.git \
  --set environment=staging

# Production
helm install argocd ./platform/argocd \
  --namespace argocd \
  --create-namespace \
  --values env/prod/helm-values.yaml \
  --set repoURL=https://github.com/your-org/lakehouse.git \
  --set environment=prod
```

## Environment Characteristics

### Development (`dev/`)
- **Purpose**: Local development and testing
- **Cluster**: Single-node (kind or minimal cloud cluster)
- **Resources**: Minimal (cost-optimized)
- **Network**: Public access allowed for debugging
- **Storage**: Small (10 GB)

### Staging (`staging/`)
- **Purpose**: Pre-production testing and validation
- **Cluster**: Multi-node (3 nodes)
- **Resources**: Moderate (realistic production-like)
- **Network**: Private network
- **Storage**: Moderate (100 GB)

### Production (`prod/`)
- **Purpose**: Production workloads
- **Cluster**: Multi-node with high availability (5+ nodes)
- **Resources**: Production-grade (high performance)
- **Network**: Private network with strict security
- **Storage**: Large (1000+ GB)

## Configuration Rules

### ✅ Allowed in tfvars files:
- Environment name
- Resource sizing (node count, instance types)
- Network configuration (CIDR blocks, DNS settings)
- Storage configuration (size, storage class)
- Tags and metadata

### ❌ NOT allowed in tfvars files:
- Secrets or credentials (use secret management tools)
- Application code or logic
- Hardcoded IP addresses (use DNS names)
- Environment-specific business logic

## Adding a New Environment

To add a new environment (e.g., `test`):

1. Create a new directory:
   ```bash
   mkdir -p env/test/
   ```

2. Copy an existing tfvars file as a template:
   ```bash
   cp env/dev/terraform.tfvars env/test/terraform.tfvars
   ```

3. Update the values in `env/test/terraform.tfvars`:
   - Set `environment = "test"`
   - Adjust resource sizing as needed
   - Update tags and metadata

4. Apply the configuration:
   ```bash
   cd infra/
   terraform plan -var-file=../env/test/terraform.tfvars
   terraform apply -var-file=../env/test/terraform.tfvars
   ```

## GitOps Integration

These configuration files are part of the GitOps workflow:

- All tfvars files are committed to Git
- Changes to configuration trigger infrastructure updates
- Git is the single source of truth (README.md section 6.2)

## Security Notes

- **Never commit secrets** to these files
- Use Terraform variables for sensitive values and provide them via:
  - Environment variables (`TF_VAR_*`)
  - Secret management tools (Vault, AWS Secrets Manager, etc.)
  - Encrypted tfvars files (using tools like SOPS or git-crypt)

## Verification

To verify that no hardcoded values exist in the infrastructure code:

```bash
cd ../infra/

# Check that all required variables are defined
terraform validate

# Verify that plan requires var-file
terraform plan  # Should prompt for variables or fail
```

All values must be injectable via these tfvars files.
