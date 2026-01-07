# Airflow Helm Chart

Apache Airflow workflow orchestration platform for the Lakehouse, configured for container-based job execution.

## Overview

This Helm chart deploys Apache Airflow as the workflow orchestrator for the Lakehouse architecture. Airflow provides:

- **Workflow Orchestration**: Schedule and monitor data pipelines
- **Container-Based Execution**: Jobs run as Kubernetes Pods via KubernetesExecutor
- **DAG Management**: Define workflows as Directed Acyclic Graphs (DAGs)
- **Web UI**: Monitor and manage workflows via web interface
- **API**: Trigger and manage workflows programmatically

## Contract Compliance

This chart implements the **Workflow Orchestration Contract** (`contracts/workflow-orchestration.md`):

✅ **Orchestrator-Agnostic Jobs**: Jobs defined via YAML specifications, not Airflow-specific code  
✅ **Container-Based Execution**: All jobs run as Kubernetes Pods (KubernetesExecutor)  
✅ **No Business Logic in Orchestrator**: Airflow only triggers jobs, business logic lives in containers  
✅ **GitOps-Ready**: DAGs deployable via GitSync from Git repository  
✅ **Configurable**: All configuration injectable via Helm values  
✅ **Observable**: Prometheus metrics, structured logging, Web UI  

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                      Airflow Platform                        │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  ┌──────────────┐     ┌──────────────┐     ┌────────────┐  │
│  │  Webserver   │     │  Scheduler   │     │ Triggerer  │  │
│  │  (UI/API)    │     │  (DAG runs)  │     │ (Deferred) │  │
│  └──────┬───────┘     └──────┬───────┘     └────────────┘  │
│         │                    │                              │
│         └────────────┬───────┘                              │
│                      │                                       │
│                      ▼                                       │
│              ┌───────────────┐                              │
│              │  PostgreSQL   │                              │
│              │  (Metadata)   │                              │
│              └───────────────┘                              │
│                                                              │
└──────────────────────┬───────────────────────────────────────┘
                       │
                       ▼
        ┌──────────────────────────────┐
        │  Kubernetes Pods (Workers)   │
        │  ┌────────┐  ┌────────┐     │
        │  │ Job 1  │  │ Job 2  │ ... │
        │  └────────┘  └────────┘     │
        └──────────────────────────────┘
```

## Prerequisites

- Kubernetes 1.28+
- Helm 3.8+
- 4GB+ RAM available for minimal deployment
- 16GB+ RAM recommended for production
- Persistent storage for PostgreSQL and DAGs

## Installation

### 1. Add Airflow Helm Repository

```bash
helm repo add apache-airflow https://airflow.apache.org
helm repo update
```

### 2. Install Chart Dependencies

```bash
cd platform/airflow
helm dependency update
```

### 3. Deploy Airflow

**Development Environment:**
```bash
helm install airflow . \
  --namespace lakehouse-platform \
  --create-namespace \
  --values values-dev.yaml
```

**Staging Environment:**
```bash
helm install airflow . \
  --namespace lakehouse-platform \
  --create-namespace \
  --values values-staging.yaml
```

**Production Environment:**
```bash
helm install airflow . \
  --namespace lakehouse-platform \
  --create-namespace \
  --values values-prod.yaml
```

### 4. Verify Deployment

```bash
# Check pod status
kubectl get pods -n lakehouse-platform -l app.kubernetes.io/name=airflow

# Check webserver logs
kubectl logs -n lakehouse-platform -l component=webserver -f

# Check scheduler logs
kubectl logs -n lakehouse-platform -l component=scheduler -f

# Port-forward to access Web UI
kubectl port-forward -n lakehouse-platform svc/airflow-api-server 33443:8080

# Access Web UI at http://localhost:33443
# Default credentials (dev): admin / admin
```

## Configuration

### Environment-Specific Values

| File | Environment | Webserver | Scheduler | PostgreSQL | GitSync | Auth | Metrics |
|------|-------------|-----------|-----------|------------|---------|------|---------|
| `values-dev.yaml` | Development | 1 replica | 1 replica | 2Gi | ❌ | ❌ | ❌ |
| `values-staging.yaml` | Staging | 2 replicas | 2 replicas | 20Gi | ✅ | ✅ | ✅ |
| `values-prod.yaml` | Production | 3 replicas | 3 replicas | 100Gi | ✅ | ✅ | ✅ |

### Key Configuration Options

#### Executor Configuration

```yaml
airflow:
  executor: "KubernetesExecutor"  # Container-based job execution
  
  config:
    kubernetes:
      namespace: lakehouse-platform
      delete_worker_pods: "True"
      delete_worker_pods_on_failure: "False"
```

#### DAG Deployment via GitSync

```yaml
airflow:
  dags:
    gitSync:
      enabled: true
      repo: "https://github.com/your-org/lakehouse-workflows.git"
      branch: main
      subPath: "workflows/"
      wait: 60  # Sync interval in seconds
```

#### Authentication

```yaml
airflow:
  webserver:
    defaultUser:
      enabled: true
      username: admin
      password: CHANGE_ME
  
  config:
    webserver:
      rbac: "True"
      authenticate: "True"
      auth_backend: "airflow.api.auth.backend.basic_auth"
```

#### Metrics

```yaml
airflow:
  metrics:
    enabled: true
    serviceMonitor:
      enabled: true
      interval: 30s
```

## Usage

### Creating Workflows

#### 1. Job Specification (YAML)

Per `contracts/workflow-orchestration.md`, jobs are defined as orchestrator-agnostic YAML:

```yaml
# workflows/daily_sales_pipeline/jobs/extract_sales.yaml
job:
  name: extract_sales
  description: Extract daily sales data
  
  image: lakehouse/extract:1.0.0
  command: ["python", "extract.py"]
  args: ["--source", "sales", "--date", "{{ ds }}"]
  
  params:
    execution_date: "{{ ds }}"
    source_table: "raw.sales"
  
  env:
    TRINO_ENDPOINT: "http://trino.lakehouse-platform.svc.cluster.local:8080"
    S3_ENDPOINT: "http://minio.lakehouse-platform.svc.cluster.local:9000"
  
  resources:
    cpu: "1000m"
    memory: "2Gi"
  
  retry:
    max_attempts: 3
    delay: "5m"
```

#### 2. Airflow DAG (Adapter)

Convert job specification to Airflow DAG:

```python
# dags/daily_sales_pipeline.py
from airflow import DAG
from airflow.providers.cncf.kubernetes.operators.kubernetes_pod import KubernetesPodOperator
from datetime import datetime, timedelta
import yaml

# Load job specification
with open('/opt/airflow/dags/jobs/extract_sales.yaml') as f:
    job_spec = yaml.safe_load(f)['job']

# Create DAG
dag = DAG(
    dag_id='daily_sales_pipeline',
    description='Daily sales data pipeline',
    schedule_interval='0 2 * * *',  # Daily at 2 AM
    start_date=datetime(2024, 1, 1),
    catchup=False,
    default_args={
        'owner': 'data-team',
        'retries': job_spec['retry']['max_attempts'],
        'retry_delay': timedelta(minutes=5),
    }
)

# Create task from job specification
extract_sales = KubernetesPodOperator(
    task_id=job_spec['name'],
    name=job_spec['name'],
    namespace='lakehouse-platform',
    image=job_spec['image'],
    cmds=job_spec.get('command'),
    arguments=job_spec.get('args'),
    env_vars=job_spec.get('env', {}),
    resources={
        'request_memory': job_spec['resources']['memory'],
        'request_cpu': job_spec['resources']['cpu'],
        'limit_memory': job_spec['resources']['memory'],
        'limit_cpu': job_spec['resources']['cpu'],
    },
    is_delete_operator_pod=True,
    get_logs=True,
    dag=dag
)
```

### Deploying DAGs

#### Option 1: GitSync (Recommended for Production)

1. Commit DAGs to Git repository
2. Configure GitSync in values:
```yaml
airflow:
  dags:
    gitSync:
      enabled: true
      repo: "https://github.com/your-org/lakehouse-workflows.git"
      branch: main
      subPath: "workflows/"
```
3. Airflow automatically syncs DAGs from Git

#### Option 2: Persistent Volume (Development)

1. Copy DAGs to persistent volume:
```bash
kubectl cp dags/ lakehouse-platform/airflow-scheduler-0:/opt/airflow/dags/
```

2. Restart scheduler:
```bash
kubectl rollout restart deployment/airflow-scheduler -n lakehouse-platform
```

### Triggering Workflows

#### Via Web UI

1. Navigate to http://localhost:8081 (or your ingress URL)
2. Login with credentials
3. Find DAG in list
4. Click "Trigger DAG" button

#### Via API

```bash
# Trigger DAG run
curl -X POST "http://airflow.lakehouse-platform.svc.cluster.local:8080/api/v1/dags/daily_sales_pipeline/dagRuns" \
  -H "Content-Type: application/json" \
  -u "admin:admin" \
  -d '{
    "execution_date": "2024-12-27T00:00:00Z",
    "conf": {}
  }'
```

#### Via CLI

```bash
# Exec into scheduler pod
kubectl exec -it -n lakehouse-platform airflow-scheduler-0 -- /bin/bash

# Trigger DAG
airflow dags trigger daily_sales_pipeline

# Backfill historical runs
airflow dags backfill daily_sales_pipeline \
  --start-date 2024-12-01 \
  --end-date 2024-12-27
```

## Observability

### Metrics

Airflow exposes Prometheus metrics via StatsD exporter.

**Key Metrics:**
- `airflow_dag_run_duration_seconds` - DAG run duration
- `airflow_task_instance_duration_seconds` - Task duration
- `airflow_dag_run_total{state="success"}` - Successful DAG runs
- `airflow_dag_run_total{state="failed"}` - Failed DAG runs
- `airflow_scheduler_heartbeat` - Scheduler health

**Grafana Dashboard:**
- Import dashboard ID: 13629 (Airflow official dashboard)

### Logging

Airflow logs are output to stdout and optionally to remote storage (S3).

**View Logs:**
```bash
# Webserver logs
kubectl logs -n lakehouse-platform -l component=webserver -f

# Scheduler logs
kubectl logs -n lakehouse-platform -l component=scheduler -f

# Worker logs (via Web UI)
# Navigate to DAG > Task > Logs
```

**Remote Logging (Production):**
```yaml
airflow:
  config:
    logging:
      remote_logging: "True"
      remote_base_log_folder: "s3://lakehouse-prod-logs/airflow"
      remote_log_conn_id: "aws_default"
```

### Web UI

Access the Airflow Web UI for workflow monitoring:

```bash
kubectl port-forward -n lakehouse-platform svc/airflow-api-server 33443:8080
```

Navigate to: `http://localhost:33443`

**Features:**
- DAG list and status
- Task execution history
- Logs viewer
- Manual trigger interface
- Dependency graph visualization
- Connection and variable management

### Health Checks

```bash
# Check webserver health
curl http://airflow-webserver.lakehouse-platform.svc.cluster.local:8080/health

# Check scheduler health
kubectl exec -n lakehouse-platform airflow-scheduler-0 -- \
  airflow jobs check --job-type SchedulerJob
```

## Scaling

### Manual Scaling

```bash
# Scale webserver
kubectl scale deployment airflow-webserver \
  --replicas=3 \
  -n lakehouse-platform

# Scale scheduler
kubectl scale deployment airflow-scheduler \
  --replicas=2 \
  -n lakehouse-platform
```

### Worker Autoscaling

KubernetesExecutor automatically creates/destroys worker pods based on task queue.

**Configuration:**
```yaml
airflow:
  config:
    kubernetes:
      worker_pods_creation_batch_size: 10  # Create up to 10 pods at once
```

## Troubleshooting

### Common Issues

#### 1. DAGs Not Appearing in Web UI

**Symptoms:**
- DAGs folder is empty in Web UI
- "No DAGs found" message

**Solution:**
```bash
# Check DAG folder
kubectl exec -n lakehouse-platform airflow-scheduler-0 -- ls -la /opt/airflow/dags

# Check scheduler logs for DAG parsing errors
kubectl logs -n lakehouse-platform -l component=scheduler | grep -i "error"

# Manually trigger DAG parsing
kubectl exec -n lakehouse-platform airflow-scheduler-0 -- \
  airflow dags list
```

#### 2. Tasks Stuck in "Queued" State

**Symptoms:**
- Tasks remain in "queued" state indefinitely
- No worker pods created

**Solution:**
```bash
# Check scheduler is running
kubectl get pods -n lakehouse-platform -l component=scheduler

# Check scheduler logs
kubectl logs -n lakehouse-platform -l component=scheduler

# Verify KubernetesExecutor configuration
kubectl exec -n lakehouse-platform airflow-scheduler-0 -- \
  airflow config get-value core executor

# Check for pod creation errors
kubectl get events -n lakehouse-platform --sort-by='.lastTimestamp'
```

#### 3. Worker Pods Failing

**Symptoms:**
- Worker pods crash or fail to start
- Tasks fail with "Pod returned a failure"

**Solution:**
```bash
# Check worker pod logs
kubectl logs -n lakehouse-platform <worker-pod-name>

# Describe worker pod for events
kubectl describe pod -n lakehouse-platform <worker-pod-name>

# Verify image exists
kubectl run test --image=<job-image> --rm -it -- /bin/sh

# Check resource limits
kubectl describe pod -n lakehouse-platform <worker-pod-name> | grep -A 5 "Limits"
```

#### 4. Database Connection Issues

**Symptoms:**
- Webserver/scheduler crash on startup
- "Can't connect to database" errors

**Solution:**
```bash
# Check PostgreSQL is running
kubectl get pods -n lakehouse-platform -l app.kubernetes.io/name=postgresql

# Check PostgreSQL logs
kubectl logs -n lakehouse-platform -l app.kubernetes.io/name=postgresql

# Test database connection
kubectl exec -n lakehouse-platform airflow-scheduler-0 -- \
  airflow db check

# Reset database (CAUTION: destroys all metadata)
kubectl exec -n lakehouse-platform airflow-scheduler-0 -- \
  airflow db reset --yes
```

### Debug Commands

```bash
# Check all Airflow resources
kubectl get all -n lakehouse-platform -l app.kubernetes.io/name=airflow

# Exec into scheduler
kubectl exec -n lakehouse-platform -it airflow-scheduler-0 -- /bin/bash

# List DAGs
kubectl exec -n lakehouse-platform airflow-scheduler-0 -- \
  airflow dags list

# Test DAG
kubectl exec -n lakehouse-platform airflow-scheduler-0 -- \
  airflow dags test daily_sales_pipeline 2024-12-27

# Check connections
kubectl exec -n lakehouse-platform airflow-scheduler-0 -- \
  airflow connections list

# Check variables
kubectl exec -n lakehouse-platform airflow-scheduler-0 -- \
  airflow variables list
```

## Upgrading

### Upgrade Airflow Version

1. Update `Chart.yaml`:
```yaml
appVersion: "2.9.0"
```

2. Update `values.yaml`:
```yaml
airflow:
  images:
    airflow:
      tag: "2.9.0-python3.11"
```

3. Apply upgrade:
```bash
helm upgrade airflow . \
  --namespace lakehouse-platform \
  --values values-prod.yaml
```

### Database Migration

Airflow automatically runs database migrations on startup. For manual migration:

```bash
kubectl exec -n lakehouse-platform airflow-scheduler-0 -- \
  airflow db upgrade
```

### Rollback

```bash
# View release history
helm history airflow -n lakehouse-platform

# Rollback to previous version
helm rollback airflow -n lakehouse-platform
```

## Security

### Credentials Management

**Development:**
- Credentials in `values-dev.yaml` (acceptable for local testing)

**Staging/Production:**
- Use Kubernetes Secrets
- Use External Secrets Operator
- Use cloud provider secret managers

**Example with External Secrets:**
```yaml
airflow:
  extraEnvFrom:
    - secretRef:
        name: airflow-secrets  # Managed by External Secrets Operator
```

### RBAC Configuration

```yaml
airflow:
  config:
    webserver:
      rbac: "True"
      auth_backend: "airflow.api.auth.backend.basic_auth"
```

### Network Policies

Recommended network policies for production:

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: airflow-scheduler-egress
spec:
  podSelector:
    matchLabels:
      component: scheduler
  policyTypes:
    - Egress
  egress:
    - to:
        - podSelector:
            matchLabels:
              app.kubernetes.io/name: postgresql
      ports:
        - protocol: TCP
          port: 5432
```

## Contract Validation

This chart is compliant with `contracts/workflow-orchestration.md` if:

✅ Workflows defined via **orchestrator-agnostic job specifications** (YAML)  
✅ Jobs run as **containers** (KubernetesExecutor)  
✅ No **orchestrator-specific APIs** in job code  
✅ Orchestrator **only triggers jobs**, contains no business logic  
✅ Job specifications stored in **Git**  
✅ Configuration **injectable** via environment variables  
✅ Supports **retry policies** and error handling  
✅ Provides **metrics** and **logging**  

## References

- **Apache Airflow Documentation**: https://airflow.apache.org/docs/
- **Airflow Helm Chart**: https://airflow.apache.org/docs/helm-chart/
- **KubernetesExecutor**: https://airflow.apache.org/docs/apache-airflow/stable/executor/kubernetes.html
- **Workflow Orchestration Contract**: `contracts/workflow-orchestration.md`
- **Best Practices**: https://airflow.apache.org/docs/apache-airflow/stable/best-practices.html

## Support

For issues or questions:
1. Check the troubleshooting section above
2. Review Airflow logs: `kubectl logs -n lakehouse-platform -l app.kubernetes.io/name=airflow`
3. Check Web UI: `http://localhost:8081` (via port-forward)
4. Consult Airflow documentation: https://airflow.apache.org/docs/
