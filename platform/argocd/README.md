# ArgoCD Helm Chart

GitOps continuous delivery for the Lakehouse platform using ArgoCD.

## Overview

This Helm chart deploys ArgoCD and creates Application manifests for all Lakehouse platform components. ArgoCD provides:

- **GitOps Deployment**: Git as the single source of truth
- **Automated Sync**: Continuous reconciliation of desired state
- **Drift Detection**: Automatic detection and correction of configuration drift
- **Multi-Environment Support**: Manage dev, staging, and production from one place
- **RBAC**: Role-based access control for team collaboration
- **Web UI**: Visual interface for application management

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                        ArgoCD                                │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  ┌──────────────┐     ┌──────────────┐     ┌────────────┐  │
│  │   Server     │     │  Repo Server │     │ Controller │  │
│  │   (UI/API)   │     │ (Git Sync)   │     │  (Sync)    │  │
│  └──────────────┘     └──────────────┘     └─────┬──────┘  │
│                                                    │         │
└────────────────────────────────────────────────────┼─────────┘
                                                     │
                    ┌────────────────────────────────┤
                    │                                │
                    ▼                                ▼
          ┌──────────────────┐           ┌──────────────────┐
          │  Git Repository  │           │   Kubernetes     │
          │  (Source)        │           │   Cluster        │
          ├──────────────────┤           ├──────────────────┤
          │ • MinIO          │           │ • MinIO          │
          │ • Iceberg        │           │ • Iceberg        │
          │ • Trino          │    ═══▶   │ • Trino          │
          │ • Airflow        │           │ • Airflow        │
          │ • Observability  │           │ • Observability  │
          └──────────────────┘           └──────────────────┘
```

## Prerequisites

- Kubernetes 1.28+
- Helm 3.8+
- Git repository with Lakehouse platform code
- 2GB+ RAM available for ArgoCD components

## Installation

### 1. Add ArgoCD Helm Repository

```bash
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update
```

### 2. Install Chart Dependencies

```bash
cd platform/argocd
helm dependency update
```

> **Note**: This command downloads the ArgoCD Helm chart (`.tgz` file) into the `charts/` directory.  
> These `.tgz` files are **NOT committed to Git** (they're in `.gitignore`).  
> Git tracks only the dependency declaration in `Chart.yaml`, following GitOps principles.

### 3. Deploy ArgoCD

**Development Environment:**
```bash
helm install argocd . \
  --namespace argocd \
  --create-namespace \
  --values values-dev.yaml \
  --set repoURL=https://github.com/your-org/lakehouse.git
```

**Staging Environment:**
```bash
helm install argocd . \
  --namespace argocd \
  --create-namespace \
  --values values-staging.yaml \
  --set repoURL=https://github.com/your-org/lakehouse.git
```

**Production Environment:**
```bash
helm install argocd . \
  --namespace argocd \
  --create-namespace \
  --values values-prod.yaml \
  --set repoURL=https://github.com/your-org/lakehouse.git
```

### 4. Get Initial Admin Password

```bash
# Get the initial admin password
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d; echo
```

### 5. Access ArgoCD UI

**Via Port-Forward (Development):**
```bash
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

Navigate to: `https://localhost:8080`

**Via Ingress (Staging/Production):**
- Staging: `https://argocd-staging.example.com`
- Production: `https://argocd.company.internal`

**Login:**
- Username: `admin`
- Password: (from step 4)

### 6. Verify Applications

```bash
# List all applications
kubectl get applications -n argocd

# Check application status
kubectl get application minio -n argocd -o yaml

# View application sync status
argocd app list
```

## Configuration

### Environment-Specific Values

| File | Environment | Server | RepoServer | Controller | Ingress | SSO | Metrics |
|------|-------------|--------|------------|------------|---------|-----|---------|
| `values-dev.yaml` | Development | 1 replica | 1 replica | 1 replica | ❌ | ❌ | ❌ |
| `values-staging.yaml` | Staging | 2 replicas | 2 replicas | 1 replica | ✅ | ❌ | ✅ |
| `values-prod.yaml` | Production | 3 replicas | 3 replicas | 1 replica | ✅ | ✅ | ✅ |

### Application Manifests

This chart creates ArgoCD Application manifests for:

1. **MinIO** (`platform/minio/`)
2. **Iceberg Catalog** (`platform/iceberg-catalog/`)
3. **Trino** (`platform/trino/`)
4. **Airflow** (`platform/airflow/`)
5. **Observability** (`platform/observability/`)

Each Application is configured with:
- **Automated Sync**: Automatically syncs changes from Git
- **Self-Heal**: Automatically corrects drift
- **Retry Logic**: Retries failed syncs with exponential backoff
- **Namespace Creation**: Creates target namespace if it doesn't exist

### Key Configuration Options

#### Git Repository

```yaml
repoURL: "https://github.com/your-org/lakehouse.git"
targetRevision: main  # or staging, dev
environment: prod     # Selects values-{environment}.yaml
```

#### Sync Policy

```yaml
applications:
  minio:
    enabled: true
    syncPolicy:
      prune: true      # Delete resources not in Git
      selfHeal: true   # Correct drift automatically
```

#### Project Configuration

```yaml
project: lakehouse
platformNamespace: lakehouse-platform
argocdNamespace: argocd
```

## Usage

### Accessing ArgoCD

#### CLI

Install ArgoCD CLI:
```bash
# macOS
brew install argocd

# Linux
curl -sSL -o argocd https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
chmod +x argocd
sudo mv argocd /usr/local/bin/
```

Login:
```bash
argocd login localhost:8080 --username admin --password <password>
```

#### Web UI

Navigate to ArgoCD URL and login with admin credentials.

### Managing Applications

#### View Applications

```bash
# List all applications
argocd app list

# Get application details
argocd app get minio

# View application sync status
argocd app sync-status minio
```

#### Sync Applications

```bash
# Sync a single application
argocd app sync minio

# Sync all applications
argocd app sync --all

# Sync with prune (delete resources not in Git)
argocd app sync minio --prune
```

#### Manual Sync (Disable Auto-Sync)

```bash
# Disable auto-sync
argocd app set minio --sync-policy none

# Enable auto-sync
argocd app set minio --sync-policy automated
```

#### Rollback

```bash
# View application history
argocd app history minio

# Rollback to previous version
argocd app rollback minio <revision-id>
```

### Drift Detection

ArgoCD automatically detects drift between Git and cluster state.

**View Drift:**
```bash
# Check if application is out of sync
argocd app diff minio

# View differences
argocd app manifests minio --source live
```

**Auto-Heal:**
If `selfHeal: true`, ArgoCD automatically corrects drift.

### Multi-Environment Management

Deploy different environments from the same Git repository:

```bash
# Development
helm install argocd . \
  --set environment=dev \
  --set targetRevision=main

# Staging
helm install argocd . \
  --set environment=staging \
  --set targetRevision=staging

# Production
helm install argocd . \
  --set environment=prod \
  --set targetRevision=main
```

Each environment uses its own `values-{environment}.yaml` file.

## Application Dependencies

Applications are deployed in the following order:

1. **MinIO** (no dependencies)
2. **Iceberg Catalog** (depends on MinIO)
3. **Trino** (depends on Iceberg Catalog)
4. **Airflow** (independent)
5. **Observability** (independent, monitors all)

ArgoCD handles dependencies through sync waves and hooks.

## Observability

### Metrics

ArgoCD exposes Prometheus metrics:

```bash
# Port-forward to metrics endpoint
kubectl port-forward -n argocd svc/argocd-metrics 8082:8082

# View metrics
curl http://localhost:8082/metrics
```

**Key Metrics:**
- `argocd_app_sync_total` - Total sync operations
- `argocd_app_health_status` - Application health status
- `argocd_app_sync_status` - Application sync status

### Logs

```bash
# Server logs
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-server -f

# Controller logs
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-application-controller -f

# Repo server logs
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-repo-server -f
```

### Health Checks

```bash
# Check ArgoCD server health
kubectl exec -n argocd deployment/argocd-server -- \
  argocd version

# Check application health
argocd app get minio --show-operation
```

## Troubleshooting

### Common Issues

#### 1. Application Stuck in "Progressing" State

**Symptoms:**
- Application shows "Progressing" for extended period
- Resources not being created

**Solution:**
```bash
# Check application events
kubectl describe application minio -n argocd

# Check sync operation
argocd app get minio --show-operation

# Force sync
argocd app sync minio --force
```

#### 2. Application Out of Sync

**Symptoms:**
- Application shows "OutOfSync" status
- Changes in Git not reflected in cluster

**Solution:**
```bash
# View differences
argocd app diff minio

# Sync application
argocd app sync minio

# If auto-sync is enabled, check sync policy
kubectl get application minio -n argocd -o yaml | grep -A 5 syncPolicy
```

#### 3. Repository Connection Failed

**Symptoms:**
- "Unable to connect to repository" error
- Applications cannot sync

**Solution:**
```bash
# Check repository credentials
kubectl get secret -n argocd | grep repo

# Test repository connection
argocd repo list

# Add repository manually
argocd repo add https://github.com/your-org/lakehouse.git \
  --username <username> \
  --password <token>
```

#### 4. Sync Fails with "Resource Already Exists"

**Symptoms:**
- Sync fails with resource conflict
- Resources exist but not managed by ArgoCD

**Solution:**
```bash
# Delete conflicting resources
kubectl delete <resource-type> <resource-name> -n lakehouse-platform

# Or adopt existing resources
argocd app sync minio --replace
```

### Debug Commands

```bash
# Check all ArgoCD resources
kubectl get all -n argocd

# Check application status
kubectl get applications -n argocd

# View application manifest
kubectl get application minio -n argocd -o yaml

# Check ArgoCD server logs
kubectl logs -n argocd deployment/argocd-server --tail=100

# Check controller logs
kubectl logs -n argocd deployment/argocd-application-controller --tail=100

# Exec into ArgoCD server
kubectl exec -n argocd -it deployment/argocd-server -- /bin/bash
```

## Security

### RBAC Configuration

ArgoCD supports role-based access control:

**Roles:**
- **Admin**: Full access to all applications and settings
- **Developer**: Can view and sync applications
- **Viewer**: Read-only access

**Configure in values:**
```yaml
argo-cd:
  configs:
    rbac:
      policy.csv: |
        p, role:developer, applications, sync, */*, allow
        g, developers-group, role:developer
```

### SSO Integration

Production deployment supports SSO via Dex:

```yaml
argo-cd:
  dex:
    enabled: true
  
  configs:
    dex.config: |
      connectors:
        - type: oidc
          id: google
          name: Google
          config:
            issuer: https://accounts.google.com
            clientID: $OIDC_CLIENT_ID
            clientSecret: $OIDC_CLIENT_SECRET
```

### Repository Credentials

**HTTPS with Token:**
```bash
argocd repo add https://github.com/your-org/lakehouse.git \
  --username <username> \
  --password <personal-access-token>
```

**SSH:**
```bash
argocd repo add git@github.com:your-org/lakehouse.git \
  --ssh-private-key-path ~/.ssh/id_rsa
```

## GitOps Workflow

### 1. Make Changes in Git

```bash
# Update Helm values
vim platform/minio/values-prod.yaml

# Commit and push
git add platform/minio/values-prod.yaml
git commit -m "Increase MinIO storage to 200Gi"
git push origin main
```

### 2. ArgoCD Detects Changes

ArgoCD polls Git repository (default: every 3 minutes) and detects changes.

### 3. Automatic Sync

If auto-sync is enabled, ArgoCD automatically applies changes to the cluster.

### 4. Verify Deployment

```bash
# Check sync status
argocd app get minio

# View application in UI
# Navigate to ArgoCD UI and view minio application
```

## Upgrading

### Upgrade ArgoCD Version

1. Update `Chart.yaml`:
```yaml
dependencies:
  - name: argo-cd
    version: "5.52.0"  # New version
```

2. Update dependencies:
```bash
helm dependency update .
```

3. Apply upgrade:
```bash
helm upgrade argocd . \
  --namespace argocd \
  --values values-prod.yaml
```

### Rollback

```bash
# View release history
helm history argocd -n argocd

# Rollback to previous version
helm rollback argocd -n argocd
```

## Contract Compliance

This chart implements GitOps per `README.md` sections 6.1 and 6.2:

✅ **Git as Single Source of Truth**: All configuration in Git  
✅ **Automated Deployment**: ArgoCD syncs from Git automatically  
✅ **Drift Detection**: Detects and corrects configuration drift  
✅ **Multi-Environment**: Supports dev, staging, production  
✅ **Reproducible**: Fresh environment bootstrappable from Git  
✅ **RBAC**: Role-based access control for team collaboration  
✅ **Observability**: Metrics, logs, and health checks  

## References

- **ArgoCD Documentation**: https://argo-cd.readthedocs.io/
- **ArgoCD Helm Chart**: https://github.com/argoproj/argo-helm/tree/main/charts/argo-cd
- **GitOps Principles**: https://opengitops.dev/
- **ArgoCD Best Practices**: https://argo-cd.readthedocs.io/en/stable/user-guide/best_practices/

## Support

For issues or questions:
1. Check the troubleshooting section above
2. Review ArgoCD logs: `kubectl logs -n argocd -l app.kubernetes.io/name=argocd-server`
3. Check application status: `argocd app get <app-name>`
4. Access ArgoCD UI for visual debugging
5. Consult ArgoCD documentation: https://argo-cd.readthedocs.io/
