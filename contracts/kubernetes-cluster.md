# Kubernetes Cluster Contract

This document defines the requirements and expectations for the Kubernetes cluster used in the Lakehouse architecture.

**Contract Version**: 1.0  
**Last Updated**: 2025-12-27

---

## 1. Purpose

Kubernetes serves as the **central orchestration and control plane** for the Lakehouse project.

**Critical Principle**: Kubernetes is NOT a data store or business logic layer.

---

## 2. Cluster Requirements

### 2.1 Kubernetes Version

- **Minimum Version**: 1.28+
- **Rationale**: Ensures compatibility with Apache Iceberg, Trino, and modern Helm charts
- **Upgrade Policy**: Cluster version must be configurable and upgradeable without application code changes

### 2.2 Node Requirements

**Minimum Node Specifications** (for development/testing):
- CPU: 2 cores per node
- Memory: 4GB per node
- Storage: 20GB per node

**Production Specifications**:
- Must be defined per environment in `env/` configuration
- No hardcoded node specifications in application code

### 2.3 Supported Cluster Types

The architecture must support:
- **Local Development**: kind, minikube, k3s
- **Cloud Managed**: EKS, GKE, AKS
- **Self-Managed**: kubeadm, Rancher, OpenShift
- **Bare-Metal**: Any conformant Kubernetes distribution

**Cluster type must be an implementation detail**, not a dependency.

---

## 3. Networking Requirements

### 3.1 DNS Resolution

- **Internal DNS**: CoreDNS or equivalent must be functional
- **Service Discovery**: All services must be discoverable via DNS
- **DNS Format**: `<service-name>.<namespace>.svc.cluster.local`

### 3.2 Service Exposure

Services must be accessible via:
- **ClusterIP**: For internal-only services
- **NodePort**: For development/testing external access
- **LoadBalancer**: For production external access (cloud environments)
- **Ingress**: For HTTP/HTTPS routing

**No hardcoded IP addresses allowed** — all endpoints must use DNS names.

### 3.3 Network Policies

- Network policies are **optional** but recommended for production
- If implemented, policies must be defined in Helm charts
- Default behavior: allow all traffic (for development)

---

## 4. Storage Requirements

### 4.1 Persistent Volumes

- **StorageClass**: Must support dynamic provisioning
- **Access Modes**: ReadWriteOnce (RWO) minimum; ReadWriteMany (RWX) preferred for shared storage
- **Volume Types**: 
  - Local development: hostPath, local-path-provisioner
  - Cloud: EBS, GCE PD, Azure Disk
  - Self-managed: Ceph, NFS, Longhorn

### 4.2 Storage Contract

- Storage backend must be **configurable**
- No assumptions about specific storage providers in application code
- All storage requests via PersistentVolumeClaims (PVCs)

---

## 5. Namespace Strategy

### 5.1 Namespace Isolation

Recommended namespaces:
- `lakehouse-platform`: Core platform services (MinIO, Trino, Iceberg catalog)
- `lakehouse-workflows`: Workflow orchestration (Airflow/Dagster)
- `lakehouse-services`: Custom application services
- `lakehouse-observability`: Monitoring stack (Prometheus, Grafana)

### 5.2 Namespace Rules

- Namespaces must be **configurable** via Helm values
- Cross-namespace communication must use fully qualified DNS names
- No hardcoded namespace assumptions in code

---

## 6. API Access

### 6.1 Kubernetes API Usage

**Allowed**:
- Helm/ArgoCD for deployment and lifecycle management
- Workflow orchestrators (Airflow KubernetesExecutor) for job scheduling
- Operators for platform component management

**Forbidden**:
- Direct Kubernetes API calls from business logic
- Application code depending on Kubernetes-specific features
- Hardcoded kubeconfig paths or cluster endpoints

### 6.2 RBAC Requirements

- All services must use ServiceAccounts
- Principle of least privilege: grant minimum required permissions
- RBAC policies defined in Helm charts

---

## 7. Execution Location Flexibility

### 7.1 Pod vs. External Service

**Critical Rule**: Not all modules must run inside Kubernetes Pods.

Each module may run as:
- A Kubernetes Pod (default)
- An external VM or bare-metal service
- A managed cloud service

### 7.2 External Service Integration

External services must:
- Be reachable via DNS or configurable endpoint
- Expose the same contract as Pod-based services
- Not require Kubernetes-specific configuration

**Example**: Trino running on a VM must be accessible via `https://trino.company.internal` just as if it were `http://trino.lakehouse-platform.svc.cluster.local`

---

## 8. Observability Integration

### 8.1 Metrics

- Prometheus-compatible metrics endpoint required
- Metrics must be scrapeable via ServiceMonitor (Prometheus Operator) or static config

### 8.2 Logging

- All logs to stdout/stderr (12-factor app principle)
- Structured logging (JSON) preferred
- Log aggregation via cluster-level collectors (Fluentd, Fluent Bit)

### 8.3 Health Checks

All services must implement:
- **Liveness probe**: `/health` or equivalent
- **Readiness probe**: `/ready` or equivalent

---

## 9. Configuration Management

### 9.1 ConfigMaps and Secrets

- **ConfigMaps**: For non-sensitive configuration
- **Secrets**: For credentials, tokens, certificates
- **External Secrets**: Supported via External Secrets Operator (optional)

### 9.2 Configuration Injection

Configuration must be injectable via:
- Helm values
- Environment variables
- Mounted ConfigMaps/Secrets

**No configuration hardcoded in container images.**

---

## 10. Deployment Contract

### 10.1 Helm as Packaging Standard

- All platform components deployed via Helm charts
- Helm charts must be version-controlled in Git
- Chart versions must follow semantic versioning

### 10.2 GitOps Reconciliation

- ArgoCD or Flux for continuous deployment
- Git is the single source of truth
- Manual `kubectl apply` discouraged in production

---

## 11. Cluster Lifecycle

### 11.1 Bootstrapping

A fresh cluster must be bootstrappable via:
```bash
terraform apply    # Provision cluster
argocd sync       # Deploy applications
```

### 11.2 Upgrades

- Cluster upgrades must not require application redeployment
- Application upgrades via GitOps (commit → sync)

### 11.3 Disaster Recovery

- Cluster state must be reproducible from Git
- No undocumented manual steps
- Backup/restore procedures documented in runbook

---

## 12. Non-Requirements

This contract explicitly does **NOT** require:
- Specific cloud provider
- Specific CNI plugin (Calico, Cilium, etc.)
- Specific ingress controller (nginx, Traefik, etc.)
- Specific storage backend

**All infrastructure choices must be configurable.**

---

## 13. Compliance Rules

### 13.1 Contract Stability

Once published, this contract cannot be broken without:
- Major version bump
- Migration guide
- Backward compatibility period

### 13.2 Validation

A cluster is compliant if:
- It passes Kubernetes conformance tests
- DNS resolution works for services
- Dynamic storage provisioning works
- RBAC is functional

---

## 14. Summary

| Aspect | Requirement |
|--------|-------------|
| **Role** | Orchestration and control plane only |
| **Version** | 1.28+ |
| **DNS** | CoreDNS or equivalent, service discovery functional |
| **Storage** | Dynamic provisioning via StorageClass |
| **Networking** | DNS-based endpoints, no hardcoded IPs |
| **API Access** | Via Helm/GitOps only, no direct calls from business logic |
| **Execution** | Pods preferred, external services supported |
| **Observability** | Prometheus metrics, structured logs, health checks |
| **Deployment** | Helm + GitOps (ArgoCD/Flux) |

---

## 15. References

- Kubernetes Documentation: https://kubernetes.io/docs/
- Kubernetes Conformance: https://www.cncf.io/certification/software-conformance/
- 12-Factor App: https://12factor.net/
