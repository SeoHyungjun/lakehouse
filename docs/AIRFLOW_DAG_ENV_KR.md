# Airflow DAG 환경변수 가이드

이 문서는 Lakehouse Platform에서 Airflow DAG 개발 시 사용할 수 있는 환경변수들을 설명합니다.

**버전**: 1.0
**마지막 업데이트**: 2026-01-19

---

## 1. 개요

Airflow KubernetesExecutor를 사용하는 경우, DAG에서 컨테이너 작업을 실행할 때 다음 환경변수들이 자동으로 주입됩니다.

**비밀 정보는 모두 Kubernetes Secret을 통해 안전하게 관리됩니다.**

---

## 2. 환경변수 목록

| 환경변수 | 설명 | Secret |
|---------|------|--------|
| `MINIO_ENDPOINT_URL` | MinIO 엔드포인트 URL | `minio-creds` |
| `AWS_ACCESS_KEY_ID` | MinIO/S3 액세스 키 | `minio-creds` |
| `AWS_SECRET_ACCESS_KEY` | MinIO/S3 시크릿 키 | `minio-creds` |
| `TRINO_ENDPOINT_URL` | Trino 엔드포인트 URL | `airflow-secrets` |
| `TRINO_CATALOG` | Trino 카탈로그 (예: `iceberg`) | `airflow-secrets` |
| `TRINO_SCHEMA` | Trino 스키마 | `airflow-secrets` |
| `POSTGRES_USERNAME` | PostgreSQL 사용자명 | `postgres-creds` |
| `POSTGRES_PASSWORD` | PostgreSQL 비밀번호 | `postgres-creds` |
| `KDP_REQUEST_URL` | KDP 요청 URL | `airflow-secrets` |
| `KDP_REGION` | KDP 리전 | `airflow-secrets` |
| `OPT_TYPE` | 옵티마이제이션 타입 | `airflow-secrets` |
| `TOKEN_URL` | OAuth 토큰 URL | `airflow-secrets` |
| `OAUTH_USERNAME` | OAuth 사용자명 | `airflow-secrets` |
| `OAUTH_CLIENT_ID` | OAuth 클라이언트 ID | `airflow-secrets` |
| `OAUTH_CLIENT_SECRET` | OAuth 클라이언트 시크릿 | `airflow-secrets` |
| `OAUTH_PASSWORD` | OAuth 비밀번호 | `airflow-secrets` |

---

## 3. DAG 사용 예제

환경변수는 KubernetesPodOperator로 실행되는 컨테이너에 자동으로 주입됩니다.

```python
from datetime import datetime, timedelta
from airflow import DAG
from airflow.providers.cncf.kubernetes.operators.kubernetes_pod import KubernetesPodOperator

default_args = {
    'owner': 'airflow',
    'depends_on_past': False,
    'start_date': datetime(2024, 1, 1),
    'retries': 1,
    'retry_delay': timedelta(minutes=5),
}

with DAG(
    dag_id='example_dag',
    default_args=default_args,
    description='DAG 예제',
    schedule_interval='@daily',
    catchup=False,
) as dag:

    task = KubernetesPodOperator(
        task_id='example_task',
        name='example-task',
        namespace='lakehouse-platform',
        image='python:3.11',
        cmds=['python', '-c'],
        arguments=['''
            import os
            print(f"MinIO Endpoint: {os.getenv('MINIO_ENDPOINT_URL')}")
            print(f"Trino Endpoint: {os.getenv('TRINO_ENDPOINT_URL')}")
            print(f"Trino Catalog: {os.getenv('TRINO_CATALOG')}")
            print(f"Trino Schema: {os.getenv('TRINO_SCHEMA')}")
        '''],
        # 환경변수는 자동으로 주입됩니다 - 별도 설정 불필요
        get_logs=True,
    )
```

---

## 4. 참고

- **환경변수**: [platform/airflow/values.yaml](../platform/airflow/values.yaml#L236)에서 설정됩니다
- **예제 DAG**: [workflows/sample-job/airflow/dag.py](../workflows/sample-job/airflow/dag.py)
- **문서**: [Workflow Orchestration Contract](../contracts/workflow-orchestration.md)
