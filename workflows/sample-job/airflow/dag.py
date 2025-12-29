"""
Airflow DAG for Sample Data Ingest Job

This DAG demonstrates how to use the orchestrator-agnostic job specification
with Airflow. The job specification (job-spec.yaml) is parsed and converted
to Airflow's KubernetesPodOperator.

Key Points:
- Job logic is in container (ingest.py), not in this DAG
- DAG only handles scheduling and triggering
- Switching to Dagster only requires changing this adapter, not the job code
"""

from datetime import datetime, timedelta
from airflow import DAG
from airflow.providers.cncf.kubernetes.operators.kubernetes_pod import KubernetesPodOperator
from kubernetes.client import models as k8s

# ============================================================================
# DAG Configuration
# ============================================================================

default_args = {
    'owner': 'data-engineering',
    'depends_on_past': False,
    'email': ['data-team@company.com'],
    'email_on_failure': True,
    'email_on_retry': False,
    'retries': 3,
    'retry_delay': timedelta(minutes=5),
    'retry_exponential_backoff': True,
}

# ============================================================================
# DAG Definition
# ============================================================================

with DAG(
    'sample_data_ingest',
    default_args=default_args,
    description='Sample data ingestion job',
    schedule_interval='0 2 * * *',  # Daily at 2 AM UTC
    start_date=datetime(2024, 1, 1),
    catchup=False,
    tags=['sample', 'ingestion', 'iceberg'],
) as dag:
    
    # ========================================================================
    # Job: Sample Data Ingest
    # ========================================================================
    # This uses KubernetesPodOperator to run the containerized job
    # The job specification from job-spec.yaml is translated here
    
    ingest_task = KubernetesPodOperator(
        task_id='ingest_data',
        name='sample-data-ingest',
        namespace='lakehouse-platform',
        
        # Container image (from job-spec.yaml)
        image='lakehouse/sample-ingest:1.0.0',
        
        # Command and arguments (from job-spec.yaml)
        cmds=['python', 'ingest.py'],
        arguments=[
            '--date', '{{ ds }}',
            '--table', 'iceberg.sample.data',
            '--batch-size', '1000',
        ],
        
        # Environment variables (from job-spec.yaml)
        env_vars={
            'TRINO_ENDPOINT': 'http://trino.lakehouse-platform.svc.cluster.local:8080',
            'TRINO_CATALOG': 'iceberg',
            'TRINO_SCHEMA': 'sample',
            'ICEBERG_CATALOG_URI': 'http://iceberg-catalog.lakehouse-platform.svc.cluster.local:8181',
            'S3_ENDPOINT': 'http://minio.lakehouse-platform.svc.cluster.local:9000',
            'S3_BUCKET': 'lakehouse-dev-warehouse',
            'LOG_LEVEL': 'INFO',
        },
        
        # Resources (from job-spec.yaml)
        container_resources=k8s.V1ResourceRequirements(
            requests={
                'cpu': '500m',
                'memory': '512Mi',
            },
            limits={
                'cpu': '1000m',
                'memory': '1Gi',
            },
        ),
        
        # Labels (from job-spec.yaml)
        labels={
            'app': 'lakehouse',
            'component': 'ingestion',
            'environment': 'dev',
            'team': 'data-engineering',
        },
        
        # Kubernetes configuration
        is_delete_operator_pod=True,
        get_logs=True,
        log_events_on_failure=True,
        
        # Retry configuration (from job-spec.yaml)
        # Note: Airflow's retry is at task level, not pod level
        retries=3,
        retry_delay=timedelta(minutes=5),
        retry_exponential_backoff=True,
        max_retry_delay=timedelta(minutes=30),
        
        # Execution timeout (from job-spec.yaml)
        execution_timeout=timedelta(minutes=30),
    )

# ============================================================================
# Notes
# ============================================================================
#
# To switch from Airflow to Dagster:
# 1. Create workflows/sample-job/dagster/repository.py
# 2. Parse job-spec.yaml and create Dagster ops
# 3. No changes to ingest.py or job-spec.yaml needed!
#
# This demonstrates true orchestrator independence.
