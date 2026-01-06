# Platform Secrets

This directory contains sealed secrets for the lakehouse-platform namespace.

## Secrets

- `minio-creds` - MinIO root credentials
- `postgres-creds` - PostgreSQL database credentials
- `airflow-webserver-secret` - Airflow webserver secret key
- `airflow-fernet-key` - Airflow Fernet encryption key
- `airflow-admin-password` - Airflow admin password (username: admin)
- `airflow-db-connection` - Airflow database connection string
- `grafana-admin-password` - Grafana admin password (username: admin)

## Deployment

These secrets are automatically deployed by ArgoCD via the `platform-secrets` application.

## Regeneration

To regenerate all sealed secrets:

```bash
./scripts/generate-secrets.sh
```

This script reads values from `.env` and creates new sealed secrets.
