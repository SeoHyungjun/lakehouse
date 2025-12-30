# Platform Helm Charts

This directory contains Helm chart configurations for all platform-level components in the Lakehouse architecture.

## Overview

The platform layer provides shared infrastructure services that support data processing and orchestration. All components are deployed via Helm charts following Kubernetes-native patterns.

## Directory Structure

```
platform/
├── minio/              # S3-compatible object storage
├── iceberg-catalog/    # Apache Iceberg REST catalog
├── trino/              # Distributed SQL query engine
├── airflow/            # Workflow orchestration
├── observability/      # Prometheus + Grafana monitoring
└── argocd/             # GitOps continuous delivery
```

## Components

### 1. MinIO (`minio/`)
- **Purpose**: S3-compatible object storage for data lake
- **Contract**: `contracts/object-storage.md`
- **Upstream Chart**: https://charts.min.io/
- **Key Features**:
  - Standalone or distributed mode
  - DNS-based endpoint access
  - Automatic bucket creation
  - Prometheus metrics support

### 2. Iceberg Catalog (`iceberg-catalog/`)
- **Purpose**: Apache Iceberg table metadata management
- **Contract**: `contracts/iceberg-catalog.md`
- **Image**: `tabulario/iceberg-rest`
- **Key Features**:
  - REST catalog API
  - Configurable backends (JDBC/REST/Hive/Glue)
  - S3 integration via DNS endpoints
  - Swappable catalog implementations

### 3. Trino (`trino/`)
- **Purpose**: Distributed SQL query engine
- **Contract**: `contracts/query-engine.md`
- **Upstream Chart**: https://trinodb.github.io/charts
- **Key Features**:
  - Iceberg connector pre-configured
  - Coordinator + worker architecture
  - SQL over HTTP interface
  - JDBC compatibility

### 4. Airflow (`airflow/`)
- **Purpose**: Workflow orchestration platform
- **Contract**: `contracts/workflow-orchestration.md`
- **Upstream Chart**: https://airflow.apache.org
- **Key Features**:
  - KubernetesExecutor for container-based jobs
  - PostgreSQL metadata database
  - DAG persistence
  - GitSync support (optional)

### 5. Observability (`observability/`)
- **Purpose**: Metrics collection and visualization
- **Upstream Chart**: https://prometheus-community.github.io/helm-charts
- **Key Features**:
  - Prometheus for metrics collection
  - Grafana for visualization
  - Alertmanager for alerting
  - Pre-configured scrape configs for all platform services

### 6. ArgoCD (`argocd/`)
- **Purpose**: GitOps continuous delivery
- **Upstream Chart**: https://argoproj.github.io/argo-helm
- **Key Features**:
  - Declarative GitOps deployment
  - Drift detection and auto-sync
  - ApplicationSet controller
  - RBAC configuration

## Helm Chart Conventions

All charts follow these conventions:

### Standard Files
- `Chart.yaml`: Chart metadata and dependencies
- `values.yaml`: Default configuration values
- `templates/`: Kubernetes manifest templates (for custom charts)

### Configuration Hierarchy
1. **Default values**: `values.yaml` in chart directory
2. **Environment overrides**: `env/{dev,staging,prod}/platform-values.yaml`
3. **Runtime overrides**: `--set` flags or additional values files

### Upstream Chart Usage
Charts that reference upstream Helm charts (MinIO, Trino, Airflow, Observability, ArgoCD) use the `dependencies` field in `Chart.yaml`. Custom values override upstream defaults.

### Helm Dependency Management

**Important**: Helm chart dependency `.tgz` files are **NOT committed to Git**.

```yaml
# Chart.yaml declares dependencies
dependencies:
  - name: argo-cd
    version: "5.51.0"
    repository: https://argoproj.github.io/argo-helm
```

Dependencies are downloaded automatically:
```bash
# Download dependencies (creates charts/*.tgz files)
helm dependency update .

# These .tgz files are in .gitignore
# Git tracks only the declaration in Chart.yaml
```

**Why?**
- ✅ **GitOps Principle**: Git stores declarations, not binaries
- ✅ **Reproducibility**: Same Chart.yaml → same dependencies
- ✅ **Repository Size**: Keeps Git repo small
- ✅ **Version Control**: Only track version numbers, not binary diffs

## Installation

### Prerequisites
- Kubernetes cluster (v1.28+)
- Helm 3.x installed
- kubectl configured

### Install Individual Component

```bash
# Update Helm dependencies (for charts with upstream dependencies)
cd platform/minio
helm dependency update

# Install chart
helm install minio . -n lakehouse --create-namespace

# Install with custom values
helm install minio . -n lakehouse \
  --values ../../env/dev/minio-values.yaml
```

### Install All Components

```bash
# Install in dependency order
helm install minio ./minio -n lakehouse --create-namespace
helm install iceberg-catalog ./iceberg-catalog -n lakehouse
helm install trino ./trino -n lakehouse
helm install airflow ./airflow -n lakehouse
helm install observability ./observability -n lakehouse
helm install argocd ./argocd -n argocd --create-namespace
```

### Verify Installation

```bash
# Check all pods are running
kubectl get pods -n lakehouse

# Check services
kubectl get svc -n lakehouse

# Check Helm releases
helm list -n lakehouse
```

## Testing

### Validate Chart Templates

```bash
# Render templates without installing
helm template minio ./minio

# Validate rendered manifests
helm template minio ./minio | kubectl apply --dry-run=client -f -

# Lint chart
helm lint ./minio
```

### Verify Helm Conventions

```bash
# Check Chart.yaml exists
ls -la */Chart.yaml

# Check values.yaml exists
ls -la */values.yaml

# Verify no hardcoded IPs (should return empty)
grep -r "192.168\|10\.\|172\." */values.yaml
```

## Verification Criteria

Per Task 11 requirements, the platform structure must:

✅ **Directory Structure**: Matches Helm chart conventions
- Each component has its own subdirectory
- Standard files: `Chart.yaml`, `values.yaml`
- `templates/` directory for custom manifests

✅ **Helm Compatibility**: All charts are valid Helm charts
- `Chart.yaml` follows apiVersion v2 format
- Dependencies properly declared
- Values files use valid YAML

✅ **Contract Compliance**: Charts reference their contracts
- MinIO → `contracts/object-storage.md`
- Iceberg → `contracts/iceberg-catalog.md`
- Trino → `contracts/query-engine.md`
- Airflow → `contracts/workflow-orchestration.md`

✅ **No Hardcoded Values**: All values are configurable
- No hardcoded IPs or endpoints
- DNS-based service discovery
- Environment-specific values in `env/` directory

## Environment-Specific Configuration

Environment overrides should be placed in:
- `env/dev/platform-values.yaml`
- `env/staging/platform-values.yaml`
- `env/prod/platform-values.yaml`

Example override structure:
```yaml
# env/dev/minio-values.yaml
mode: standalone
replicas: 1
persistence:
  size: 10Gi
```

## Troubleshooting

### Helm Dependency Issues
```bash
# Update dependencies
helm dependency update ./minio

# List dependencies
helm dependency list ./minio
```

### Template Rendering Errors
```bash
# Debug template rendering
helm template minio ./minio --debug

# Show computed values
helm get values minio -n lakehouse
```

### Chart Installation Failures
```bash
# Check Helm release status
helm status minio -n lakehouse

# View release history
helm history minio -n lakehouse

# Rollback to previous version
helm rollback minio 1 -n lakehouse
```

## Next Steps

After completing this task:
- [ ] Task 12: Create MinIO Helm Chart Configuration
- [ ] Task 13: Create Iceberg Catalog Helm Chart Configuration
- [ ] Task 14: Create Trino Helm Chart Configuration
- [ ] Task 15: Create Airflow Helm Chart Configuration
- [ ] Task 16: Create Observability Helm Chart Configuration
- [ ] Task 17: Create ArgoCD Application Manifests

## References

- [Helm Chart Best Practices](https://helm.sh/docs/chart_best_practices/)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- Repository Contract: `docs/repo_contract.md`
- Platform Contracts: `contracts/`
