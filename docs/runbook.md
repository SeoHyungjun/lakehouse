# Lakehouse Platform Operator Runbook

**Version**: 1.0  
**Last Updated**: 2025-12-28  
**Maintainer**: Data Platform Team

## Table of Contents

1. [Overview](#overview)
2. [Prerequisites](#prerequisites)
3. [Deployment Procedures](#deployment-procedures)
4. [Upgrade Procedures](#upgrade-procedures)
5. [Rollback Procedures](#rollback-procedures)
6. [Troubleshooting](#troubleshooting)
7. [Monitoring & Alerts](#monitoring--alerts)
8. [Disaster Recovery](#disaster-recovery)
9. [Common Operations](#common-operations)
10. [Emergency Contacts](#emergency-contacts)

---

## Overview

This runbook provides operational procedures for the Lakehouse platform. It covers:

- **Deployment**: Initial platform deployment and component installation
- **Upgrade**: Version upgrades and configuration changes
- **Rollback**: Reverting changes when issues occur
- **Troubleshooting**: Diagnosing and resolving common issues
- **Operations**: Day-to-day operational tasks

### Architecture Summary

```
┌─────────────────────────────────────────────────────────┐
│                  Lakehouse Platform                      │
├─────────────────────────────────────────────────────────┤
│                                                          │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐             │
│  │  MinIO   │  │ Iceberg  │  │  Trino   │             │
│  │ (Storage)│  │ Catalog  │  │ (Query)  │             │
│  └──────────┘  └──────────┘  └──────────┘             │
│                                                          │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐             │
│  │ Airflow  │  │Prometheus│  │  ArgoCD  │             │
│  │(Workflow)│  │ (Metrics)│  │ (GitOps) │             │
│  └──────────┘  └──────────┘  └──────────┘             │
│                                                          │
└─────────────────────────────────────────────────────────┘
```

---

## Prerequisites

### Required Tools

| Tool | Version | Purpose |
|------|---------|---------|
| kubectl | 1.28+ | Kubernetes cluster management |
| helm | 3.12+ | Helm chart deployment |
| terraform | 1.5+ | Infrastructure provisioning |
| argocd CLI | 2.8+ | ArgoCD management |
| git | 2.40+ | Version control |

### Required Access

- **Kubernetes Cluster**: Admin access to target cluster
- **Git Repository**: Write access to lakehouse repository
- **Cloud Provider**: Appropriate IAM permissions (if using cloud)
- **Secrets Management**: Access to secrets store (Vault, AWS Secrets Manager, etc.)

### Environment Variables

```bash
export KUBECONFIG=~/.kube/config
export ENVIRONMENT=dev  # or staging, prod
export LAKEHOUSE_REPO=https://github.com/your-org/lakehouse.git
```

---

## Deployment Procedures

### 1. Initial Platform Deployment

**Objective**: Deploy the complete Lakehouse platform from scratch

**Prerequisites**:
- Clean Kubernetes cluster
- Git repository cloned
- Environment configuration files ready

**Procedure**:

```bash
# Step 1: Clone repository
git clone ${LAKEHOUSE_REPO}
cd lakehouse

# Step 2: Verify prerequisites
./scripts/bootstrap.sh --check-only

# Step 3: Bootstrap platform
./scripts/bootstrap.sh ${ENVIRONMENT}

# Expected output:
# ✓ Prerequisites checked
# ✓ Infrastructure provisioned
# ✓ ArgoCD installed
# ✓ Applications synced
# ✓ Platform ready
```

**Verification**:

```bash
# Check all pods are running
kubectl get pods -n lakehouse-platform

# Check ArgoCD applications
argocd app list

# Run validation tests
cd tests/e2e
./run_tests.sh
```

**Rollback**: If deployment fails, run cleanup:
```bash
./scripts/cleanup.sh ${ENVIRONMENT}
```

---

### 2. Component-Specific Deployment

#### Deploy MinIO

```bash
helm install minio ./platform/minio \
  --namespace lakehouse-platform \
  --create-namespace \
  --values env/${ENVIRONMENT}/helm-values.yaml \
  --wait --timeout 10m
```

**Verification**:
```bash
kubectl get pods -n lakehouse-platform -l app=minio
kubectl port-forward -n lakehouse-platform svc/minio 9000:9000
curl http://localhost:9000/minio/health/live
```

#### Deploy Iceberg Catalog

```bash
helm install iceberg-catalog ./platform/iceberg-catalog \
  --namespace lakehouse-platform \
  --values env/${ENVIRONMENT}/helm-values.yaml \
  --wait --timeout 10m
```

**Verification**:
```bash
kubectl get pods -n lakehouse-platform -l app=iceberg-catalog
curl http://iceberg-catalog.lakehouse-platform.svc.cluster.local:8181/v1/config
```

#### Deploy Trino

```bash
helm install trino ./platform/trino \
  --namespace lakehouse-platform \
  --values env/${ENVIRONMENT}/helm-values.yaml \
  --wait --timeout 15m
```

**Verification**:
```bash
kubectl get pods -n lakehouse-platform -l app=trino
curl http://trino.lakehouse-platform.svc.cluster.local:8080/v1/info
```

#### Deploy Airflow

```bash
helm install airflow ./platform/airflow \
  --namespace lakehouse-platform \
  --values env/${ENVIRONMENT}/helm-values.yaml \
  --wait --timeout 15m
```

**Verification**:
```bash
kubectl get pods -n lakehouse-platform -l app=airflow
kubectl port-forward -n lakehouse-platform svc/airflow-webserver 8080:8080
# Access http://localhost:8080
```

#### Deploy Observability

```bash
helm install observability ./platform/observability \
  --namespace lakehouse-platform \
  --values env/${ENVIRONMENT}/helm-values.yaml \
  --wait --timeout 10m
```

**Verification**:
```bash
kubectl get pods -n lakehouse-platform -l app=prometheus
kubectl port-forward -n lakehouse-platform svc/prometheus-operated 9090:9090
# Access http://localhost:9090
```

---

## Upgrade Procedures

### 1. Platform Upgrade Strategy

**Upgrade Order** (to minimize downtime):
1. Observability (monitoring first)
2. MinIO (storage layer)
3. Iceberg Catalog (metadata layer)
4. Trino (query engine)
5. Airflow (orchestration)
6. ArgoCD (GitOps)

### 2. Helm Chart Upgrade

**Procedure**:

```bash
# Step 1: Review changes
git diff main origin/main -- platform/<component>

# Step 2: Update local repository
git pull origin main

# Step 3: Dry-run upgrade
helm upgrade <component> ./platform/<component> \
  --namespace lakehouse-platform \
  --values env/${ENVIRONMENT}/helm-values.yaml \
  --dry-run --debug

# Step 4: Perform upgrade
helm upgrade <component> ./platform/<component> \
  --namespace lakehouse-platform \
  --values env/${ENVIRONMENT}/helm-values.yaml \
  --wait --timeout 10m

# Step 5: Verify upgrade
kubectl rollout status deployment/<component> -n lakehouse-platform
```

**Example - Upgrade Trino**:

```bash
# Check current version
helm list -n lakehouse-platform

# Upgrade Trino
helm upgrade trino ./platform/trino \
  --namespace lakehouse-platform \
  --values env/${ENVIRONMENT}/helm-values.yaml \
  --wait --timeout 15m

# Verify
kubectl get pods -n lakehouse-platform -l app=trino
curl http://trino.lakehouse-platform.svc.cluster.local:8080/v1/info
```

### 3. Configuration-Only Changes

**Procedure**:

```bash
# Step 1: Update configuration in Git
vim env/${ENVIRONMENT}/helm-values.yaml
git add env/${ENVIRONMENT}/helm-values.yaml
git commit -m "Update Trino worker count to 10"
git push origin main

# Step 2: Sync via ArgoCD (if using GitOps)
argocd app sync trino

# OR manually upgrade
helm upgrade trino ./platform/trino \
  --namespace lakehouse-platform \
  --values env/${ENVIRONMENT}/helm-values.yaml \
  --reuse-values
```

### 4. Infrastructure Upgrade

**Procedure**:

```bash
# Step 1: Update Terraform configuration
vim env/${ENVIRONMENT}/terraform.tfvars

# Step 2: Plan changes
cd infra
terraform plan -var-file=../env/${ENVIRONMENT}/terraform.tfvars

# Step 3: Apply changes
terraform apply -var-file=../env/${ENVIRONMENT}/terraform.tfvars

# Step 4: Verify cluster
kubectl get nodes
kubectl get pods --all-namespaces
```

---

## Rollback Procedures

### 1. Helm Rollback

**Procedure**:

```bash
# Step 1: List release history
helm history <component> -n lakehouse-platform

# Step 2: Rollback to previous version
helm rollback <component> -n lakehouse-platform

# Step 3: Rollback to specific revision
helm rollback <component> <revision> -n lakehouse-platform

# Step 4: Verify rollback
kubectl rollout status deployment/<component> -n lakehouse-platform
```

**Example - Rollback Trino**:

```bash
# Check history
helm history trino -n lakehouse-platform

# Rollback to previous version
helm rollback trino -n lakehouse-platform

# Verify
kubectl get pods -n lakehouse-platform -l app=trino
```

### 2. Git Rollback

**Procedure**:

```bash
# Step 1: Identify commit to revert
git log --oneline

# Step 2: Revert commit
git revert <commit-hash>

# Step 3: Push revert
git push origin main

# Step 4: Sync ArgoCD
argocd app sync <component>
```

### 3. Kubernetes Deployment Rollback

**Procedure**:

```bash
# Rollback deployment
kubectl rollout undo deployment/<component> -n lakehouse-platform

# Check rollout status
kubectl rollout status deployment/<component> -n lakehouse-platform

# View rollout history
kubectl rollout history deployment/<component> -n lakehouse-platform
```

### 4. Emergency Rollback

**When to use**: Critical production issue, immediate rollback needed

**Procedure**:

```bash
# Step 1: Stop ArgoCD auto-sync
argocd app set <component> --sync-policy none

# Step 2: Rollback Helm release
helm rollback <component> -n lakehouse-platform

# Step 3: Verify service
kubectl get pods -n lakehouse-platform
curl http://<component>:8080/health

# Step 4: Investigate issue
kubectl logs -n lakehouse-platform deployment/<component>

# Step 5: Re-enable auto-sync after fix
argocd app set <component> --sync-policy automated
```

---

## Troubleshooting

### 1. Pod Not Starting

**Symptoms**:
- Pod stuck in `Pending`, `CrashLoopBackOff`, or `ImagePullBackOff`

**Diagnosis**:

```bash
# Check pod status
kubectl get pods -n lakehouse-platform

# Describe pod
kubectl describe pod <pod-name> -n lakehouse-platform

# Check events
kubectl get events -n lakehouse-platform --sort-by='.lastTimestamp'

# Check logs
kubectl logs <pod-name> -n lakehouse-platform
```

**Common Causes & Solutions**:

| Issue | Cause | Solution |
|-------|-------|----------|
| `ImagePullBackOff` | Image not found | Check image name and registry access |
| `CrashLoopBackOff` | Application crash | Check logs for error messages |
| `Pending` | Insufficient resources | Check node resources: `kubectl top nodes` |
| `Pending` | PVC not bound | Check PVC status: `kubectl get pvc -n lakehouse-platform` |

### 2. Service Not Accessible

**Symptoms**:
- Cannot connect to service
- Connection timeout

**Diagnosis**:

```bash
# Check service
kubectl get svc -n lakehouse-platform

# Check endpoints
kubectl get endpoints <service-name> -n lakehouse-platform

# Test from within cluster
kubectl run -it --rm debug --image=curlimages/curl --restart=Never -- \
  curl http://<service-name>.lakehouse-platform.svc.cluster.local:8080/health
```

**Solutions**:
- Verify service selector matches pod labels
- Check pod is running and ready
- Verify network policies allow traffic

### 3. Trino Query Failures

**Symptoms**:
- Queries fail with errors
- Slow query performance

**Diagnosis**:

```bash
# Check Trino coordinator logs
kubectl logs -n lakehouse-platform deployment/trino-coordinator

# Check Trino worker logs
kubectl logs -n lakehouse-platform deployment/trino-worker

# Access Trino UI
kubectl port-forward -n lakehouse-platform svc/trino 8080:8080
# Navigate to http://localhost:8080
```

**Common Issues**:

| Error | Cause | Solution |
|-------|-------|----------|
| "Catalog not found" | Iceberg catalog not configured | Check catalog configuration in Trino |
| "S3 access denied" | Invalid S3 credentials | Verify MinIO credentials in Trino config |
| "Out of memory" | Insufficient worker memory | Increase worker memory or add more workers |

### 4. MinIO Issues

**Symptoms**:
- Cannot write/read objects
- MinIO pods crashing

**Diagnosis**:

```bash
# Check MinIO pods
kubectl get pods -n lakehouse-platform -l app=minio

# Check MinIO logs
kubectl logs -n lakehouse-platform deployment/minio

# Test MinIO health
kubectl port-forward -n lakehouse-platform svc/minio 9000:9000
curl http://localhost:9000/minio/health/live
```

**Solutions**:
- Check PVC is bound and has sufficient space
- Verify MinIO credentials
- Check network connectivity

### 5. Airflow DAG Issues

**Symptoms**:
- DAGs not appearing
- Tasks failing

**Diagnosis**:

```bash
# Check Airflow scheduler logs
kubectl logs -n lakehouse-platform deployment/airflow-scheduler

# Check Airflow webserver logs
kubectl logs -n lakehouse-platform deployment/airflow-webserver

# Access Airflow UI
kubectl port-forward -n lakehouse-platform svc/airflow-webserver 8080:8080
```

**Solutions**:
- Verify DAG syntax: `airflow dags list`
- Check GitSync is pulling DAGs correctly
- Verify Kubernetes executor has permissions

### 6. ArgoCD Sync Issues

**Symptoms**:
- Application out of sync
- Sync fails

**Diagnosis**:

```bash
# Check application status
argocd app get <app-name>

# View sync status
argocd app diff <app-name>

# Check ArgoCD logs
kubectl logs -n argocd deployment/argocd-server
```

**Solutions**:
- Manually sync: `argocd app sync <app-name>`
- Hard refresh: `argocd app sync <app-name> --force`
- Check Git repository is accessible

---

## Monitoring & Alerts

### 1. Key Metrics to Monitor

**Platform Health**:
- Pod status (all pods running)
- Node resource usage (CPU, memory, disk)
- PVC usage

**MinIO**:
- Storage usage
- Request rate
- Error rate

**Trino**:
- Query success rate
- Query duration
- Worker count

**Airflow**:
- DAG success rate
- Task duration
- Scheduler heartbeat

### 2. Accessing Monitoring

**Prometheus**:
```bash
kubectl port-forward -n lakehouse-platform svc/prometheus-operated 9090:9090
# Access http://localhost:9090
```

**Grafana**:
```bash
kubectl port-forward -n lakehouse-platform svc/grafana 3000:3000
# Access http://localhost:3000
# Default credentials: admin / <from secret>
```

### 3. Common Alerts

| Alert | Severity | Action |
|-------|----------|--------|
| PodDown | Critical | Investigate pod logs, restart if needed |
| HighMemoryUsage | Warning | Consider scaling up |
| DiskSpaceLow | Warning | Clean up old data or expand storage |
| TrinoQueryFailureRate | Critical | Check Trino logs and dependencies |
| AirflowDAGFailure | Warning | Check DAG logs and fix issues |

---

## Disaster Recovery

### 1. Backup Procedures

**What to Backup**:
- Git repository (already in Git)
- Kubernetes secrets
- Persistent volume data (MinIO, databases)
- ArgoCD configuration

**Backup Commands**:

```bash
# Backup Kubernetes secrets
kubectl get secrets -n lakehouse-platform -o yaml > secrets-backup.yaml

# Backup PVCs (use velero or cloud provider tools)
velero backup create lakehouse-backup --include-namespaces lakehouse-platform

# Backup MinIO data (use mc mirror)
mc mirror minio/lakehouse-warehouse /backup/lakehouse-warehouse
```

### 2. Restore Procedures

**Full Platform Restore**:

```bash
# Step 1: Provision infrastructure
cd infra
terraform apply -var-file=../env/${ENVIRONMENT}/terraform.tfvars

# Step 2: Restore secrets
kubectl apply -f secrets-backup.yaml

# Step 3: Restore PVCs
velero restore create --from-backup lakehouse-backup

# Step 4: Deploy platform
./scripts/bootstrap.sh ${ENVIRONMENT}

# Step 5: Verify
cd tests/e2e
./run_tests.sh
```

---

## Common Operations

### 1. Scale Components

**Scale Trino Workers**:
```bash
kubectl scale deployment trino-worker -n lakehouse-platform --replicas=10
```

**Scale via Helm**:
```bash
helm upgrade trino ./platform/trino \
  --namespace lakehouse-platform \
  --set server.workers=10 \
  --reuse-values
```

### 2. View Logs

```bash
# View logs for specific pod
kubectl logs <pod-name> -n lakehouse-platform

# Follow logs
kubectl logs -f <pod-name> -n lakehouse-platform

# View logs for all pods in deployment
kubectl logs -n lakehouse-platform deployment/<component>

# View previous pod logs (if crashed)
kubectl logs <pod-name> -n lakehouse-platform --previous
```

### 3. Execute Commands in Pod

```bash
# Execute command
kubectl exec -it <pod-name> -n lakehouse-platform -- /bin/bash

# Run one-off command
kubectl exec <pod-name> -n lakehouse-platform -- ls -la /data
```

### 4. Update Secrets

```bash
# Create/update secret
kubectl create secret generic <secret-name> \
  --from-literal=key=value \
  --namespace lakehouse-platform \
  --dry-run=client -o yaml | kubectl apply -f -

# Restart pods to pick up new secret
kubectl rollout restart deployment/<component> -n lakehouse-platform
```

---

## Emergency Contacts

| Role | Contact | Escalation |
|------|---------|------------|
| Platform Team Lead | platform-lead@example.com | PagerDuty: +1-555-0100 |
| On-Call Engineer | oncall@example.com | PagerDuty: +1-555-0101 |
| Data Engineering Manager | data-mgr@example.com | Email only |
| Infrastructure Team | infra@example.com | Slack: #infrastructure |

**Escalation Path**:
1. On-Call Engineer (immediate)
2. Platform Team Lead (15 minutes)
3. Data Engineering Manager (30 minutes)
4. CTO (1 hour for critical outages)

---

## Appendix

### A. Useful Commands Cheat Sheet

```bash
# Get all resources in namespace
kubectl get all -n lakehouse-platform

# Check resource usage
kubectl top nodes
kubectl top pods -n lakehouse-platform

# Force delete stuck pod
kubectl delete pod <pod-name> -n lakehouse-platform --grace-period=0 --force

# Get pod YAML
kubectl get pod <pod-name> -n lakehouse-platform -o yaml

# Port forward multiple services
kubectl port-forward -n lakehouse-platform svc/trino 8080:8080 &
kubectl port-forward -n lakehouse-platform svc/minio 9000:9000 &
kubectl port-forward -n lakehouse-platform svc/grafana 3000:3000 &
```

### B. Troubleshooting Decision Tree

```
Issue Detected
    │
    ├─ Pod not running?
    │   ├─ Check pod status: kubectl get pods
    │   ├─ Check events: kubectl describe pod
    │   └─ Check logs: kubectl logs
    │
    ├─ Service not accessible?
    │   ├─ Check service: kubectl get svc
    │   ├─ Check endpoints: kubectl get endpoints
    │   └─ Test connectivity from pod
    │
    └─ Performance issue?
        ├─ Check resource usage: kubectl top
        ├─ Check metrics in Grafana
        └─ Scale if needed: kubectl scale
```

---

**Document Version**: 1.0  
**Last Review**: 2025-12-28  
**Next Review**: 2026-01-28
