# Platform Secrets

This directory contains sealed secrets for the lakehouse-platform namespace.

## Naming Convention

File names follow the pattern: `{service}-{purpose}-sealed-secret.yaml`

Secret names (used in Kubernetes) are derived from the file names without the `-sealed-secret.yaml` suffix.

## Secrets

### Airflow Secrets
| Secret Name | File | Purpose |
|-------------|------|---------|
| `airflow-webserver-secret` | `airflow-webserver-secret-sealed-secret.yaml` | Webserver secret key |
| `airflow-fernet-key` | `airflow-fernet-key-sealed-secret.yaml` | Fernet encryption key |
| `airflow-admin-password` | `airflow-admin-password-sealed-secret.yaml` | Admin user credentials (username, password, email, firstname, lastname) |
| `airflow-db-connection` | `airflow-db-connection-sealed-secret.yaml` | Database connection string |

### Observability Secrets
| Secret Name | File | Purpose |
|-------------|------|---------|
| `grafana-admin-password` | `grafana-admin-password-sealed-secret.yaml` | Grafana admin password (username: admin) |

### Infrastructure Secrets
| Secret Name | File | Purpose |
|-------------|------|---------|
| `postgres-creds` | `postgres-creds-sealed-secret.yaml` | PostgreSQL database credentials (used by Airflow, Iceberg Catalog) |
| `minio-creds` | `minio-creds-sealed-secret.yaml` | MinIO object storage credentials (used by MinIO, Iceberg Catalog, Trino) |

## Deployment

These secrets are automatically deployed by ArgoCD via the `platform-secrets` application.

## Regeneration

To regenerate all sealed secrets:

```bash
./scripts/generate-secrets.sh
```

This script reads values from `.env` and creates new sealed secrets.
