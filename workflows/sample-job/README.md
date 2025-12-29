# Sample Workflow Job

Orchestrator-agnostic job specification demonstrating the Workflow Orchestration Contract.

## Overview

This sample job demonstrates:

- **Orchestrator-Agnostic Design**: Job specification works with Airflow, Dagster, or other orchestrators
- **Containerized Execution**: Business logic in container, not orchestrator
- **Parameterized Jobs**: Template variables for dynamic execution
- **No Orchestrator Dependencies**: Job code has no Airflow/Dagster imports
- **Resource Management**: CPU/memory requests and limits
- **Retry Policy**: Automatic retry on failure

## Job Specification

The job specification is defined in `job-spec.yaml` following the Workflow Orchestration Contract.

### Job: `sample_data_ingest`

**Purpose**: Ingest sample data into Iceberg tables via Trino

**What it does**:
1. Connects to Trino
2. Creates an Iceberg table (if not exists)
3. Inserts sample data
4. Validates data was inserted correctly

**Execution**: Runs as a containerized job (no orchestrator-specific code)

## Files

```
workflows/sample-job/
├── README.md                 # This file
├── job-spec.yaml            # Orchestrator-agnostic job specification
├── workflow-spec.yaml       # Sample workflow with scheduling
├── job/                     # Job implementation
│   ├── Dockerfile           # Container image
│   ├── requirements.txt     # Python dependencies
│   └── ingest.py           # Job logic (no orchestrator dependencies)
└── airflow/                 # Airflow-specific adapter (optional)
    └── dag.py              # Airflow DAG that uses job-spec.yaml
```

## Job Specification Format

```yaml
job:
  name: sample_data_ingest
  description: Ingest sample data into Iceberg tables
  
  # Container image
  image: lakehouse/sample-ingest:1.0.0
  
  # Command and arguments
  command: ["python", "ingest.py"]
  args: ["--date", "{{ execution_date }}"]
  
  # Parameters (templated)
  params:
    execution_date: "{{ ds }}"
    target_table: "iceberg.sample.data"
    batch_size: "1000"
  
  # Environment variables
  env:
    TRINO_ENDPOINT: "http://trino.lakehouse-platform.svc.cluster.local:8080"
    ICEBERG_CATALOG: "iceberg"
    S3_ENDPOINT: "http://minio.lakehouse-platform.svc.cluster.local:9000"
  
  # Resources
  resources:
    cpu: "500m"
    memory: "512Mi"
  
  # Retry policy
  retry:
    max_attempts: 3
    delay: "5m"
```

## Running the Job

### With Airflow

```bash
# Copy DAG to Airflow DAGs folder
cp airflow/dag.py /path/to/airflow/dags/

# Trigger job manually
airflow dags trigger sample_data_ingest

# Or wait for scheduled execution (daily at 2 AM UTC)
```

### With Kubernetes (Manual)

```bash
# Build container image
cd job
docker build -t lakehouse/sample-ingest:1.0.0 .

# Run as Kubernetes Job
kubectl create job sample-ingest \
  --image=lakehouse/sample-ingest:1.0.0 \
  --namespace=lakehouse-platform \
  -- python ingest.py --date 2024-12-27
```

### With Docker (Local Testing)

```bash
# Build image
cd job
docker build -t lakehouse/sample-ingest:1.0.0 .

# Run container
docker run --rm \
  -e TRINO_ENDPOINT=http://localhost:8080 \
  -e ICEBERG_CATALOG=iceberg \
  -e S3_ENDPOINT=http://localhost:9000 \
  lakehouse/sample-ingest:1.0.0 \
  python ingest.py --date 2024-12-27
```

## Contract Compliance

This job specification complies with the Workflow Orchestration Contract (`contracts/workflow-orchestration.md`):

✅ **Orchestrator-Agnostic**: Job spec is YAML, works with any orchestrator  
✅ **Containerized**: Business logic in container, not orchestrator  
✅ **No Orchestrator Dependencies**: Job code has no Airflow/Dagster imports  
✅ **Parameterized**: Uses template variables ({{ execution_date }})  
✅ **Resource Management**: CPU/memory requests defined  
✅ **Retry Policy**: Automatic retry configuration  
✅ **Environment Variables**: Configuration via env vars  
✅ **Stateless**: No local state, idempotent execution  
✅ **Logging**: Structured logs to stdout  
✅ **Exit Codes**: 0 for success, non-zero for failure  

## Workflow Specification

The `workflow-spec.yaml` file defines a complete workflow with scheduling:

```yaml
workflow:
  name: sample_data_pipeline
  description: Sample data ingestion pipeline
  
  schedule:
    cron: "0 2 * * *"  # Daily at 2 AM
    timezone: "UTC"
    start_date: "2024-01-01"
  
  jobs:
    - job:
        name: sample_data_ingest
        # ... (job spec from job-spec.yaml)
```

## Switching Orchestrators

To switch from Airflow to Dagster:

1. **No changes to job code** - `ingest.py` remains unchanged
2. **No changes to job spec** - `job-spec.yaml` remains unchanged
3. **Only change adapter** - Create `dagster/repository.py` instead of `airflow/dag.py`

This demonstrates true orchestrator independence!

## Monitoring

### Job Logs

```bash
# Airflow
airflow tasks logs sample_data_ingest sample_data_ingest 2024-12-27

# Kubernetes
kubectl logs -n lakehouse-platform job/sample-ingest
```

### Job Status

```bash
# Airflow
airflow tasks state sample_data_ingest sample_data_ingest 2024-12-27

# Kubernetes
kubectl get jobs -n lakehouse-platform
```

## Troubleshooting

### Job Fails to Connect to Trino

**Problem**: Job cannot connect to Trino

**Solution**:
```bash
# Verify Trino is running
kubectl get pods -n lakehouse-platform -l app=trino

# Check Trino endpoint
kubectl exec -it -n lakehouse-platform <job-pod> -- \
  curl http://trino.lakehouse-platform.svc.cluster.local:8080/v1/info
```

### Job Fails with "Table Already Exists"

**Problem**: Job tries to create table that already exists

**Solution**: Job is idempotent - it uses `CREATE TABLE IF NOT EXISTS`

### Job Retries Exhausted

**Problem**: Job fails after 3 retry attempts

**Solution**:
```bash
# Check job logs for error details
kubectl logs -n lakehouse-platform job/sample-ingest

# Manually re-run job with corrected parameters
airflow tasks run sample_data_ingest sample_data_ingest 2024-12-27
```

## References

- **Workflow Orchestration Contract**: `../../contracts/workflow-orchestration.md`
- **Airflow Documentation**: https://airflow.apache.org/docs/
- **Dagster Documentation**: https://docs.dagster.io/
- **Kubernetes Jobs**: https://kubernetes.io/docs/concepts/workloads/controllers/job/
