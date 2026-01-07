# Lakehouse Platform Scripts

Automation scripts for bootstrapping, managing, and validating the Lakehouse platform.

## Overview

This directory contains scripts that implement the **Reproducibility Guarantee** from `README.md` section 10:

> A new environment can be created with:
> ```bash
> git clone
> terraform apply
> argocd sync
> ```

## Scripts

### 1. `bootstrap.sh`

**Purpose**: Bootstrap a complete Lakehouse platform from Git.

**Usage:**
```bash
./scripts/bootstrap.sh [environment]
```

**Arguments:**
- `environment` - Target environment: `dev`, `staging`, or `prod` (default: `dev`)

**What it does:**
1. Checks prerequisites (Git, Terraform, Helm, kubectl, kind)
2. Validates environment configuration
3. Provisions infrastructure with Terraform
4. Configures kubectl context
5. Installs ArgoCD
6. Waits for ArgoCD to be ready
7. Retrieves ArgoCD admin password
8. Syncs all ArgoCD applications
9. Verifies deployment

**Example:**
```bash
# Bootstrap development environment
./scripts/bootstrap.sh dev

# Bootstrap production environment
./scripts/bootstrap.sh prod
```

**Prerequisites:**
- Git
- Terraform >= 1.5.0
- Helm >= 3.8.0
- kubectl >= 1.28.0
- kind (for local development)

**Output:**
- Provisioned Kubernetes cluster
- Installed ArgoCD
- Deployed all platform components (MinIO, Iceberg, Trino, Airflow, Observability)
- ArgoCD admin credentials

---

### 2. `cleanup.sh`

**Purpose**: Tear down the Lakehouse platform.

**Usage:**
```bash
./scripts/cleanup.sh [environment]
```

**Arguments:**
- `environment` - Target environment: `dev`, `staging`, or `prod` (default: `dev`)

**What it does:**
1. Confirms cleanup (requires user confirmation)
2. Deletes all ArgoCD applications
3. Uninstalls ArgoCD
4. Deletes platform namespace
5. Destroys infrastructure with Terraform

**Example:**
```bash
# Cleanup development environment
./scripts/cleanup.sh dev

# Cleanup production environment (requires confirmation)
./scripts/cleanup.sh prod
```

**Warning:** This is a destructive operation. All data will be lost.

---

### 3. `validate.sh`

**Purpose**: Validate the Lakehouse platform deployment.

**Usage:**
```bash
./scripts/validate.sh [environment]
```

**Arguments:**
- `environment` - Target environment: `dev`, `staging`, or `prod` (default: `dev`)

**What it does:**
1. Checks cluster connection
2. Validates ArgoCD installation
3. Checks ArgoCD application status
4. Validates platform namespace
5. Verifies platform components (MinIO, Iceberg, Trino, Airflow, Observability)

**Example:**
```bash
# Validate development environment
./scripts/validate.sh dev

# Validate production environment
./scripts/validate.sh prod
```

**Output:**
- Validation summary with pass/warn/fail counts
- Detailed status of each component

---

## Quick Start

### Bootstrap a Fresh Environment

```bash
# 1. Clone the repository
git clone https://github.com/your-org/lakehouse.git
cd lakehouse

# 2. Make scripts executable
chmod +x scripts/*.sh

# 3. Bootstrap the platform
./scripts/bootstrap.sh dev
```

### Validate Deployment

```bash
./scripts/validate.sh dev
```

### Access Services

**ArgoCD:**
```bash
kubectl port-forward svc/argocd-server -n argocd 30044:443
# Navigate to: https://localhost:30044
# Username: admin
# Password: (from bootstrap output)
```

**Grafana:**
```bash
kubectl port-forward svc/observability-grafana -n lakehouse-platform 32300:80
# Navigate to: http://localhost:32300
# Username: admin
# Password: admin (dev) or as configured
```

**Trino:**
```bash
kubectl port-forward svc/trino -n lakehouse-platform 31280:8080
# Navigate to: http://localhost:31280
```

### Cleanup Environment

```bash
./scripts/cleanup.sh dev
```

---

## Environment-Specific Configuration

Each script supports three environments:

| Environment | Description | Terraform Dir | Terraform Vars | ArgoCD Values |
|-------------|-------------|---------------|----------------|---------------|
| `dev` | Local development (kind) | `infra/` | `env/dev/terraform.tfvars` | `values-dev.yaml` |
| `staging` | Pre-production testing | `infra/` | `env/staging/terraform.tfvars` | `values-staging.yaml` |
| `prod` | Production | `infra/` | `env/prod/terraform.tfvars` | `values-prod.yaml` |

---

## Troubleshooting

### Bootstrap Fails at Terraform Step

**Problem:** Terraform apply fails

**Solution:**
```bash
# Check Terraform configuration
cd infra
terraform validate

# View detailed error with environment-specific vars
terraform plan -var-file=../env/dev/terraform.tfvars

# Fix configuration and re-run bootstrap
cd ..
./scripts/bootstrap.sh dev
```

### ArgoCD Applications Not Syncing

**Problem:** Applications stuck in "OutOfSync" state

**Solution:**
```bash
# Check application status
kubectl get applications -n argocd

# View application details
kubectl describe application minio -n argocd

# Force sync
kubectl patch application minio -n argocd \
  --type merge \
  --patch '{"operation":{"initiatedBy":{"username":"admin"},"sync":{"revision":"HEAD"}}}'

# Or use ArgoCD CLI
argocd app sync minio
```

### Validation Fails

**Problem:** `validate.sh` reports failures

**Solution:**
```bash
# Check pod status
kubectl get pods -n lakehouse-platform

# Check pod logs
kubectl logs -n lakehouse-platform <pod-name>

# Check events
kubectl get events -n lakehouse-platform --sort-by='.lastTimestamp'

# Re-sync applications
argocd app sync --all
```

### Cleanup Fails

**Problem:** Resources not being deleted

**Solution:**
```bash
# Force delete namespace
kubectl delete namespace lakehouse-platform --force --grace-period=0

# Manually delete finalizers
kubectl patch namespace lakehouse-platform \
  -p '{"metadata":{"finalizers":[]}}' \
  --type=merge

# Re-run cleanup
./scripts/cleanup.sh dev
```

---

## Script Development

### Adding a New Script

1. Create script in `scripts/` directory
2. Make it executable: `chmod +x scripts/new-script.sh`
3. Follow the existing script structure:
   - Use `set -euo pipefail` for safety
   - Include colored logging functions
   - Add error handling
   - Document usage in header comment
4. Update this README

### Testing Scripts

```bash
# Test in development environment first
./scripts/bootstrap.sh dev
./scripts/validate.sh dev
./scripts/cleanup.sh dev

# Test idempotency (should succeed twice)
./scripts/bootstrap.sh dev
./scripts/bootstrap.sh dev
```

---

## CI/CD Integration

These scripts can be integrated into CI/CD pipelines:

**GitHub Actions Example:**
```yaml
name: Deploy Lakehouse

on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Setup Tools
        run: |
          # Install Terraform, Helm, kubectl
          
      - name: Bootstrap Platform
        run: |
          ./scripts/bootstrap.sh staging
      
      - name: Validate Deployment
        run: |
          ./scripts/validate.sh staging
```

---

## Contract Compliance

These scripts implement the **Reproducibility Guarantee** per `README.md` section 10:

✅ **Git Clone**: Repository contains all configuration  
✅ **Terraform Apply**: Infrastructure provisioned automatically  
✅ **ArgoCD Sync**: Applications deployed automatically  
✅ **No Manual Steps**: Fully automated bootstrap  
✅ **Deterministic**: Same Git commit → same system behavior  

---

## References

- **Main README**: `../README.md`
- **Terraform Modules**: `../infra/modules/`
- **Platform Helm Charts**: `../platform/`
- **ArgoCD Applications**: `../platform/argocd/templates/`

---

## Support

For issues or questions:
1. Check the troubleshooting section above
2. Review script output for detailed error messages
3. Check Kubernetes events: `kubectl get events --all-namespaces --sort-by='.lastTimestamp'`
4. Validate Terraform: `cd infra && terraform validate`
5. Validate Helm charts: `helm template <chart>` in `platform/<component>/`
