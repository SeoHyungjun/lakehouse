# Workflow Orchestration Contract

This document defines the interface contract for workflow orchestration in the Lakehouse architecture.

**Contract Version**: 1.0  
**Last Updated**: 2025-12-27

---

## 1. Purpose

Workflow orchestration manages the scheduling, execution, and monitoring of data pipelines and batch jobs in the Lakehouse.

**Critical Principles**:
- Orchestrator must be **replaceable** (Airflow ↔ Dagster ↔ others)
- Workflows defined via **orchestrator-agnostic job specifications**
- Orchestrator **only triggers jobs**, does not contain business logic
- Business logic lives inside **containerized jobs**
- No direct dependency on orchestrator internals in job code

---

## 2. Orchestrator Requirements

### 2.1 Supported Orchestrators

**Default**: Apache Airflow  
**Alternative**: Dagster  
**Future Support**: Prefect, Temporal, Argo Workflows

**Critical Rule**: Switching orchestrators must not require rewriting core job logic.

### 2.2 Orchestrator Responsibilities

**Allowed**:
- Schedule jobs (cron, interval, event-driven)
- Trigger job execution
- Monitor job status
- Retry failed jobs
- Send notifications
- Manage dependencies between jobs
- Provide UI for monitoring

**Forbidden**:
- Contain business logic
- Direct data processing
- Direct database access (except for orchestrator metadata)
- Hardcoded credentials or endpoints

---

## 3. Job Specification Format

### 3.1 Job Specification Schema

**Format**: YAML or JSON

**Required Fields**:
```yaml
job:
  # Job metadata
  name: <job-name>                    # Required: Unique job identifier
  description: <description>          # Optional: Human-readable description
  
  # Execution
  image: <container-image>            # Required: Container image to run
  command: [<cmd>]                    # Optional: Override container entrypoint
  args: [<args>]                      # Optional: Arguments to command
  
  # Parameters
  params:                             # Optional: Job parameters (key-value)
    <key>: <value>
  
  # Environment
  env:                                # Optional: Environment variables
    <key>: <value>
  
  # Resources
  resources:                          # Optional: Resource requests/limits
    cpu: <cpu-request>
    memory: <memory-request>
    
  # Retry policy
  retry:                              # Optional: Retry configuration
    max_attempts: <number>
    delay: <duration>
```

### 3.2 Example Job Specification

```yaml
job:
  name: daily_sales_ingest
  description: Ingest daily sales data from source system
  
  image: lakehouse/ingest:1.2.0
  command: ["python", "ingest.py"]
  args: ["--source", "sales", "--date", "{{ execution_date }}"]
  
  params:
    execution_date: "{{ ds }}"
    source_table: "raw.sales"
    target_table: "iceberg.sales.orders"
  
  env:
    TRINO_ENDPOINT: "http://trino.lakehouse-platform.svc.cluster.local:8080"
    ICEBERG_CATALOG: "iceberg"
    S3_ENDPOINT: "http://minio.lakehouse-platform.svc.cluster.local:9000"
  
  resources:
    cpu: "1000m"
    memory: "2Gi"
  
  retry:
    max_attempts: 3
    delay: "5m"
```

### 3.3 Templating

**Supported Template Variables**:
- `{{ execution_date }}` - Job execution date (ISO 8601)
- `{{ ds }}` - Execution date (YYYY-MM-DD format)
- `{{ ts }}` - Execution timestamp
- `{{ prev_execution_date }}` - Previous execution date
- `{{ next_execution_date }}` - Next execution date
- `{{ params.<key> }}` - Custom parameters

**Templating Engine**: Jinja2 (compatible with Airflow and Dagster)

---

## 4. Workflow Specification Format

### 4.1 Workflow Schema

**Format**: YAML or JSON

```yaml
workflow:
  # Workflow metadata
  name: <workflow-name>               # Required: Unique workflow identifier
  description: <description>          # Optional: Human-readable description
  
  # Schedule
  schedule:                           # Optional: Scheduling configuration
    cron: <cron-expression>           # Cron schedule
    timezone: <timezone>              # Timezone (e.g., UTC, America/New_York)
    start_date: <date>                # Start date
    end_date: <date>                  # Optional: End date
  
  # Jobs
  jobs:                               # Required: List of jobs in workflow
    - job: <job-spec>                 # Job specification
      depends_on: [<job-names>]       # Optional: Job dependencies
```

### 4.2 Example Workflow Specification

```yaml
workflow:
  name: daily_sales_pipeline
  description: Daily sales data pipeline
  
  schedule:
    cron: "0 2 * * *"                 # Daily at 2 AM
    timezone: "UTC"
    start_date: "2024-01-01"
  
  jobs:
    - job:
        name: extract_sales
        image: lakehouse/extract:1.0
        params:
          source: "sales_db"
          execution_date: "{{ ds }}"
      depends_on: []
    
    - job:
        name: transform_sales
        image: lakehouse/transform:1.0
        params:
          input_table: "raw.sales"
          output_table: "iceberg.sales.orders"
          execution_date: "{{ ds }}"
      depends_on: ["extract_sales"]
    
    - job:
        name: generate_report
        image: lakehouse/report:1.0
        params:
          table: "iceberg.sales.orders"
          execution_date: "{{ ds }}"
      depends_on: ["transform_sales"]
```

---

## 5. Job Execution Interface

### 5.1 Container-Based Execution

**Required**: All jobs must run as containers

**Execution Environment**:
- Kubernetes Pod (default)
- Docker container (local development)
- Any container runtime

**Job Exit Codes**:
- `0` - Success
- `1-255` - Failure (job will be retried if retry policy is configured)

### 5.2 Job Input/Output

**Input**:
- Environment variables
- Command-line arguments
- Configuration files (mounted as volumes)

**Output**:
- Stdout/stderr (captured by orchestrator)
- Exit code
- Metrics (optional, via Prometheus pushgateway)

**No shared state between jobs** (except via data storage: Iceberg tables, object storage).

### 5.3 Job Communication

**Forbidden**:
- Direct job-to-job communication
- Shared mutable storage
- Orchestrator API calls from within jobs

**Allowed**:
- Read/write to Iceberg tables
- Read/write to object storage
- Query via Trino
- Publish metrics

---

## 6. Orchestrator-Specific Adapters

### 6.1 Airflow Adapter

**Responsibility**: Convert job specifications to Airflow DAGs

**Implementation**:
```python
# airflow_adapter.py
from airflow import DAG
from airflow.providers.cncf.kubernetes.operators.kubernetes_pod import KubernetesPodOperator
import yaml

def create_dag_from_spec(spec_file):
    with open(spec_file) as f:
        spec = yaml.safe_load(f)
    
    workflow = spec['workflow']
    
    dag = DAG(
        dag_id=workflow['name'],
        description=workflow.get('description', ''),
        schedule_interval=workflow['schedule']['cron'],
        start_date=workflow['schedule']['start_date'],
        catchup=False
    )
    
    tasks = {}
    for job_spec in workflow['jobs']:
        job = job_spec['job']
        task = KubernetesPodOperator(
            task_id=job['name'],
            name=job['name'],
            image=job['image'],
            cmds=job.get('command'),
            arguments=job.get('args'),
            env_vars=job.get('env', {}),
            dag=dag
        )
        tasks[job['name']] = task
    
    # Set dependencies
    for job_spec in workflow['jobs']:
        job = job_spec['job']
        if 'depends_on' in job_spec:
            for dep in job_spec['depends_on']:
                tasks[dep] >> tasks[job['name']]
    
    return dag
```

### 6.2 Dagster Adapter

**Responsibility**: Convert job specifications to Dagster pipelines

**Implementation**:
```python
# dagster_adapter.py
from dagster import job, op, In, Out, schedule
import yaml

def create_pipeline_from_spec(spec_file):
    with open(spec_file) as f:
        spec = yaml.safe_load(f)
    
    workflow = spec['workflow']
    
    @job(name=workflow['name'], description=workflow.get('description', ''))
    def pipeline():
        ops = {}
        for job_spec in workflow['jobs']:
            job_def = job_spec['job']
            
            @op(name=job_def['name'])
            def execute_job(context):
                # Execute container via Kubernetes
                # Implementation details...
                pass
            
            ops[job_def['name']] = execute_job
        
        # Wire dependencies
        # Implementation details...
    
    return pipeline
```

### 6.3 Adapter Contract

**All adapters must**:
- Parse job specification YAML/JSON
- Create orchestrator-specific objects (DAGs, pipelines)
- Map job parameters to orchestrator context
- Handle dependencies
- Configure retry policies
- Capture logs and metrics

**Adapters must NOT**:
- Modify job business logic
- Add orchestrator-specific code to jobs
- Hardcode configuration

---

## 7. Scheduling and Triggers

### 7.1 Schedule Types

**Cron-based**:
```yaml
schedule:
  cron: "0 2 * * *"                   # Daily at 2 AM
  timezone: "UTC"
```

**Interval-based**:
```yaml
schedule:
  interval: "1h"                      # Every hour
```

**Event-driven** (optional):
```yaml
schedule:
  trigger: "s3_file_arrival"          # Trigger on S3 file arrival
  source: "s3://lakehouse-dev-raw/sales/"
```

### 7.2 Manual Triggers

**Required**: Support manual job execution via UI or API

**API Endpoint** (orchestrator-specific):
```bash
# Airflow
curl -X POST "http://airflow:8080/api/v1/dags/daily_sales_pipeline/dagRuns" \
  -H "Content-Type: application/json" \
  -d '{"execution_date": "2024-12-27T00:00:00Z"}'

# Dagster
curl -X POST "http://dagster:3000/graphql" \
  -H "Content-Type: application/json" \
  -d '{"query": "mutation { launchPipelineExecution(executionParams: {selector: {pipelineName: \"daily_sales_pipeline\"}}) { run { runId } } }"}'
```

### 7.3 Backfill Support

**Required**: Support backfilling historical runs

**Example**:
```bash
# Backfill for date range
airflow dags backfill daily_sales_pipeline \
  --start-date 2024-12-01 \
  --end-date 2024-12-27
```

---

## 8. Dependency Management

### 8.1 Job Dependencies

**Dependency Types**:
- Sequential: Job B runs after Job A completes
- Parallel: Jobs run concurrently
- Conditional: Job runs based on condition

**Example**:
```yaml
jobs:
  - job:
      name: job_a
    depends_on: []
  
  - job:
      name: job_b
    depends_on: ["job_a"]
  
  - job:
      name: job_c
    depends_on: ["job_a"]          # Parallel with job_b
  
  - job:
      name: job_d
    depends_on: ["job_b", "job_c"] # Waits for both
```

### 8.2 Cross-Workflow Dependencies

**Optional**: Support dependencies between workflows

**Example**:
```yaml
workflow:
  name: downstream_pipeline
  
  dependencies:
    - workflow: "upstream_pipeline"
      wait_for_completion: true
```

---

## 9. Retry and Error Handling

### 9.1 Retry Policy

**Configuration**:
```yaml
retry:
  max_attempts: 3                     # Maximum retry attempts
  delay: "5m"                         # Delay between retries
  exponential_backoff: true           # Optional: Exponential backoff
  backoff_multiplier: 2               # Optional: Backoff multiplier
```

### 9.2 Failure Handling

**On Job Failure**:
- Log error details
- Send notification (email, Slack, PagerDuty)
- Mark job as failed
- Stop downstream jobs (default) or continue (optional)

**Notification Configuration**:
```yaml
notifications:
  on_failure:
    - type: email
      recipients: ["data-team@company.com"]
    - type: slack
      channel: "#data-alerts"
```

---

## 10. Monitoring and Observability

### 10.1 Metrics

**Required Metrics**:
- Job execution count (success, failure)
- Job duration (p50, p95, p99)
- Job queue length
- Active jobs
- Failed jobs (last 24h)

**Prometheus Format**:
```
workflow_job_executions_total{job="daily_sales_ingest", status="success"}
workflow_job_duration_seconds{job="daily_sales_ingest", quantile="0.99"}
workflow_jobs_active{workflow="daily_sales_pipeline"}
workflow_jobs_failed_total{workflow="daily_sales_pipeline"}
```

### 10.2 Logging

**Required Logs**:
- Job start/completion events
- Job failures with error messages
- Retry attempts
- Dependency resolution

**Log Format**: Structured JSON

**Example**:
```json
{
  "timestamp": "2024-12-27T02:00:00Z",
  "workflow": "daily_sales_pipeline",
  "job": "extract_sales",
  "status": "success",
  "duration_seconds": 45.2,
  "execution_date": "2024-12-27"
}
```

### 10.3 UI Requirements

**Required Features**:
- Workflow list and status
- Job execution history
- Logs viewer
- Manual trigger interface
- Dependency graph visualization

---

## 11. Security

### 11.1 Authentication

**Orchestrator UI/API**:
- Password authentication
- LDAP/AD integration
- OAuth 2.0 / SSO

### 11.2 Authorization

**Role-Based Access Control (RBAC)**:
- Admin: Full access
- Developer: Create/edit workflows, trigger jobs
- Viewer: Read-only access

**Example** (Airflow):
```python
# webserver_config.py
AUTH_ROLE_PUBLIC = 'Viewer'
AUTH_ROLES_MAPPING = {
    "data-engineers": ["Admin"],
    "analysts": ["Developer"],
    "viewers": ["Viewer"]
}
```

### 11.3 Secrets Management

**Job Secrets**:
- Kubernetes Secrets (mounted as environment variables)
- External Secrets Manager (Vault, AWS Secrets Manager)

**Forbidden**:
- Hardcoded secrets in job specifications
- Secrets in container images
- Secrets in Git

---

## 12. Configuration Management

### 12.1 Orchestrator Configuration

**All configuration must be injectable via**:
- Helm values
- Environment variables
- ConfigMaps (Kubernetes)

**No hardcoded values in orchestrator deployment.**

### 12.2 Job Specification Storage

**Storage Location**: Git repository

**Directory Structure**:
```
workflows/
  daily_sales_pipeline/
    workflow.yaml
    jobs/
      extract_sales.yaml
      transform_sales.yaml
      generate_report.yaml
  weekly_report_pipeline/
    workflow.yaml
    jobs/
      ...
```

### 12.3 Version Control

**Required**: All workflow specifications in Git

**Deployment**:
- GitOps: Orchestrator syncs workflows from Git
- CI/CD: Workflows deployed via pipeline

---

## 13. Job Development Guidelines

### 13.1 Job Container Requirements

**Dockerfile Example**:
```dockerfile
FROM python:3.11-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install -r requirements.txt

COPY ingest.py .

ENTRYPOINT ["python", "ingest.py"]
```

### 13.2 Job Code Structure

**Example** (Python):
```python
# ingest.py
import os
import sys
from datetime import datetime

def main():
    # Read configuration from environment
    execution_date = os.getenv('EXECUTION_DATE')
    trino_endpoint = os.getenv('TRINO_ENDPOINT')
    
    # Business logic
    print(f"Starting ingestion for {execution_date}")
    
    # Connect to Trino (via contract)
    # Read from source
    # Write to Iceberg table
    
    print("Ingestion completed successfully")
    return 0

if __name__ == "__main__":
    sys.exit(main())
```

### 13.3 Forbidden Practices

**DO NOT**:
- Import Airflow/Dagster libraries in job code
- Call orchestrator APIs from jobs
- Use orchestrator-specific context objects
- Share state via orchestrator metadata database

**DO**:
- Use environment variables for configuration
- Use command-line arguments for parameters
- Communicate via data (Iceberg tables, object storage)
- Log to stdout/stderr

---

## 14. Migration and Portability

### 14.1 Orchestrator Migration

**From Airflow to Dagster**:
1. Keep job specifications unchanged
2. Implement Dagster adapter
3. Deploy Dagster
4. Migrate workflow specifications (if needed)
5. Test workflows in Dagster
6. Switch orchestrator endpoint
7. Decommission Airflow

**No job code changes required.**

### 14.2 Portability Validation

**Test**: Workflow must run on:
- Airflow (default)
- Dagster (alternative)

Without changing job container images or business logic.

---

## 15. Compliance Rules

### 15.1 Contract Stability

Once published, this contract cannot be broken without:
- Major version bump
- Migration guide
- Backward compatibility period

### 15.2 Validation Checklist

A workflow orchestration implementation is compliant if:
- ✅ Workflows defined via orchestrator-agnostic job specifications (YAML/JSON)
- ✅ Jobs run as containers
- ✅ No orchestrator-specific APIs in job code
- ✅ Orchestrator only triggers jobs, contains no business logic
- ✅ Job specifications stored in Git
- ✅ Configuration injectable via environment variables
- ✅ Supports retry policies and error handling

### 15.3 Automatic Failure Conditions

**Contract is violated if**:
- Orchestrator-specific code (Airflow/Dagster imports) in job logic
- Business logic in orchestrator DAG/pipeline definitions
- Hardcoded credentials in job specifications
- Direct orchestrator API calls from jobs

---

## 16. Default Implementation

**Default**: Apache Airflow with KubernetesExecutor  
**Alternative**: Dagster with Kubernetes run launcher  
**Future**: Prefect, Temporal, Argo Workflows

**Switching orchestrators must require only adapter implementation, no job code changes.**

---

## 17. References

- Apache Airflow Documentation: https://airflow.apache.org/docs/
- Airflow KubernetesExecutor: https://airflow.apache.org/docs/apache-airflow/stable/executor/kubernetes.html
- Dagster Documentation: https://docs.dagster.io/
- Dagster Kubernetes: https://docs.dagster.io/deployment/guides/kubernetes
- Workflow Specification Best Practices: https://12factor.net/
