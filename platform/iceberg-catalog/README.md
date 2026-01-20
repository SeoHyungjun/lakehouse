# Iceberg REST Catalog Helm Chart

This Helm chart deploys an Apache Iceberg REST catalog for the Lakehouse platform, providing a catalog interface for managing Iceberg table metadata.

## Overview

The Iceberg catalog is responsible for:
- Table metadata storage and retrieval
- Namespace (database) management
- Table discovery and listing
- Atomic metadata updates
- Integration with S3-compatible object storage

## Contract Compliance

This chart implements the **Iceberg Catalog Contract** (`contracts/iceberg-catalog.md`):

✅ Supports Apache Iceberg Table Format v2  
✅ Catalog backend is configurable (REST/JDBC/Hive/Glue)  
✅ All data access via Iceberg APIs only  
✅ No direct object path access  
✅ Warehouse location configurable per environment  
✅ DNS-based catalog endpoints (no hardcoded IPs)  
✅ Credentials injectable via environment variables

## Supported Catalog Backends

### 1. JDBC Catalog (Default)
Uses a relational database to store catalog metadata.

**Supported Databases**:
- SQLite (development only)
- PostgreSQL 12+ (recommended for production)
- MySQL 8+

**Configuration**:
```yaml
catalog:
  backend: jdbc
  jdbc:
    uri: jdbc:postgresql://postgres:5432/iceberg
    driver: org.postgresql.Driver
    username: iceberg_user
    password: iceberg_password
```

### 2. REST Catalog
Uses Iceberg REST Catalog API specification.

**Configuration**:
```yaml
catalog:
  backend: rest
  # Additional REST-specific configuration
```

### 3. Hive Metastore
Uses Hive Metastore for legacy compatibility.

**Configuration**:
```yaml
catalog:
  backend: hive
  hive:
    uri: thrift://hive-metastore:9083
    confDir: /etc/hive/conf
```

### 4. AWS Glue
Uses AWS Glue Data Catalog (cloud-managed).

**Configuration**:
```yaml
catalog:
  backend: glue
  glue:
    region: us-east-1
    catalogId: "123456789012"
```

## Installation

### Prerequisites

1. Kubernetes cluster (1.28+)
2. Helm 3.x
3. MinIO or S3-compatible storage deployed
4. (Optional) PostgreSQL for JDBC backend

### Install with Default Values (Development)

```bash
# Install in lakehouse-platform namespace
helm install iceberg-catalog ./platform/iceberg-catalog \
  --namespace lakehouse-platform \
  --create-namespace
```

### Install with Environment-Specific Values

```bash
# Development
helm install iceberg-catalog ./platform/iceberg-catalog \
  -f ./platform/iceberg-catalog/values-dev.yaml \
  --namespace lakehouse-platform

# Staging
helm install iceberg-catalog ./platform/iceberg-catalog \
  -f ./platform/iceberg-catalog/values-staging.yaml \
  --namespace lakehouse-platform

# Production
helm install iceberg-catalog ./platform/iceberg-catalog \
  -f ./platform/iceberg-catalog/values-prod.yaml \
  --namespace lakehouse-platform
```

## Configuration

### Key Configuration Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| `replicaCount` | Number of catalog replicas | `1` |
| `catalog.warehouse` | S3 warehouse location | `s3://lakehouse/` |
| `catalog.backend` | Catalog backend type | `jdbc` |
| `catalog.s3.endpoint` | S3 endpoint (DNS-based) | `http://minio.lakehouse-platform.svc.cluster.local:9000` |
| `catalog.s3.accessKeyId` | S3 access key | `admin` |
| `catalog.s3.secretAccessKey` | S3 secret key | `changeme123` |
| `catalog.jdbc.uri` | JDBC connection URI | `jdbc:sqlite:file:/data/iceberg-catalog.db` |
| `persistence.enabled` | Enable persistent storage | `true` |
| `persistence.size` | PVC size | `1Gi` |
| `metrics.enabled` | Enable Prometheus metrics | `false` |

### Environment-Specific Configurations

#### Development (`values-dev.yaml`)
- **Backend**: SQLite (file-based, no external DB)
- **Replicas**: 1
- **Resources**: Minimal (256Mi RAM, 100m CPU)
- **Metrics**: Disabled

#### Staging (`values-staging.yaml`)
- **Backend**: PostgreSQL
- **Replicas**: 2 (HA testing)
- **Resources**: Medium (512Mi RAM, 250m CPU)
- **Metrics**: Enabled
- **Anti-affinity**: Preferred (spread across nodes)

#### Production (`values-prod.yaml`)
- **Backend**: PostgreSQL with HA
- **Replicas**: 3 (high availability)
- **Resources**: High (1Gi RAM, 500m CPU)
- **Metrics**: Enabled
- **Anti-affinity**: Required (strict node distribution)
- **Tolerations**: Node failure handling

## Usage

### Accessing the Catalog

The catalog is accessible via DNS within the cluster:

```
http://iceberg-catalog.lakehouse-platform.svc.cluster.local:8181
```

### Health Checks

```bash
# Check catalog health
curl http://iceberg-catalog.lakehouse-platform.svc.cluster.local:8181/v1/config

# Expected response: JSON configuration
```

### Creating a Namespace

```bash
# Using REST API
curl -X POST http://iceberg-catalog:8181/v1/namespaces \
  -H "Content-Type: application/json" \
  -d '{"namespace": ["sales"], "properties": {"owner": "data-team"}}'
```

### Creating a Table

Tables are typically created via query engines (Trino, Spark) that connect to this catalog:

```sql
-- Via Trino
CREATE TABLE sales.orders (
  order_id BIGINT,
  customer_id BIGINT,
  order_date DATE,
  amount DECIMAL(10,2)
) WITH (
  format = 'PARQUET',
  partitioning = ARRAY['months(order_date)']
);
```

## Integration with Other Components

### MinIO (Object Storage)
The catalog connects to MinIO for storing table data and metadata:

```yaml
catalog:
  warehouse: s3://lakehouse/
  s3:
    endpoint: http://minio.lakehouse-platform.svc.cluster.local:9000
```

### Trino (Query Engine)
Trino connects to this catalog to query Iceberg tables:

```yaml
# Trino catalog configuration
connector.name=iceberg
iceberg.catalog.type=rest
iceberg.rest.uri=http://iceberg-catalog.lakehouse-platform.svc.cluster.local:8181
```

### PostgreSQL (Metadata Backend)
For production deployments, use PostgreSQL:

```bash
# Initialize PostgreSQL schema
kubectl exec -it postgres-0 -- psql -U postgres -d iceberg -f /init/iceberg-schema.sql
```

## Observability

### Metrics

When `metrics.enabled=true`, Prometheus metrics are exposed on port 9090:

```
iceberg_catalog_requests_total{operation="load_table", status="success"}
iceberg_catalog_request_duration_seconds{operation="commit", quantile="0.99"}
iceberg_table_size_bytes{namespace="sales", table="orders"}
```

### Logs

Structured JSON logs are written to stdout:

```bash
# View logs
kubectl logs -n lakehouse-platform deployment/iceberg-catalog -f
```

## Security

### Credentials Management

**Development**: Credentials in values files (acceptable for local dev)

**Production**: Use external secrets management:

```yaml
# Example: External Secrets Operator
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: iceberg-catalog-s3
spec:
  secretStoreRef:
    name: aws-secrets-manager
  target:
    name: iceberg-catalog-s3
  data:
  - secretKey: accessKeyId
    remoteRef:
      key: lakehouse/s3/access-key
  - secretKey: secretAccessKey
    remoteRef:
      key: lakehouse/s3/secret-key
```

### Network Policies

Restrict access to the catalog:

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: iceberg-catalog
spec:
  podSelector:
    matchLabels:
      app.kubernetes.io/name: iceberg-catalog
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app.kubernetes.io/name: trino
    ports:
    - protocol: TCP
      port: 8181
```

## Troubleshooting

### Catalog Not Starting

**Symptom**: Pod in CrashLoopBackOff

**Check**:
```bash
kubectl logs -n lakehouse-platform deployment/iceberg-catalog
```

**Common Causes**:
1. **Invalid JDBC URI**: Verify database connectivity
2. **Missing S3 credentials**: Check secret configuration
3. **Insufficient resources**: Increase memory/CPU limits

### Cannot Connect to MinIO

**Symptom**: Errors like "Connection refused" or "Unknown host"

**Check**:
```bash
# Verify MinIO service exists
kubectl get svc -n lakehouse-platform minio

# Test connectivity from catalog pod
kubectl exec -it deployment/iceberg-catalog -- curl http://minio.lakehouse-platform.svc.cluster.local:9000
```

**Fix**: Ensure MinIO is deployed and DNS resolution works

### PostgreSQL Connection Errors

**Symptom**: "Connection to PostgreSQL failed"

**Check**:
```bash
# Verify PostgreSQL is running
kubectl get pods -n lakehouse-platform -l app=postgresql

# Test connection
kubectl exec -it deployment/iceberg-catalog -- \
  psql -h postgres.lakehouse-platform.svc.cluster.local -U iceberg_user -d iceberg
```

**Fix**: Initialize PostgreSQL schema:
```sql
CREATE DATABASE iceberg;
-- Run schema initialization from contracts/iceberg-catalog.md
```

### Table Metadata Not Found

**Symptom**: "Table does not exist" errors

**Check**:
```bash
# List namespaces
curl http://iceberg-catalog:8181/v1/namespaces

# List tables in namespace
curl http://iceberg-catalog:8181/v1/namespaces/sales/tables
```

**Fix**: Ensure tables are created via proper Iceberg APIs (not direct file writes)

## Validation

### Helm Template Validation

```bash
# Render templates without installing
helm template iceberg-catalog ./platform/iceberg-catalog \
  -f ./platform/iceberg-catalog/values-dev.yaml

# Validate against Kubernetes API
helm template iceberg-catalog ./platform/iceberg-catalog \
  -f ./platform/iceberg-catalog/values-dev.yaml | kubectl apply --dry-run=client -f -
```

### Contract Compliance Validation

```bash
# Verify no hardcoded IPs
grep -r "endpoint.*[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}" values*.yaml
# Should return no results

# Verify DNS-based endpoints
grep "endpoint.*svc.cluster.local" values*.yaml
# Should show MinIO DNS endpoint

# Verify warehouse is configurable
grep "warehouse:" values*.yaml
# Should show different values per environment
```

## Upgrading

```bash
# Upgrade to new version
helm upgrade iceberg-catalog ./platform/iceberg-catalog \
  -f ./platform/iceberg-catalog/values-prod.yaml \
  --namespace lakehouse-platform

# Rollback if needed
helm rollback iceberg-catalog --namespace lakehouse-platform
```

## Uninstallation

```bash
helm uninstall iceberg-catalog --namespace lakehouse-platform
```

**Warning**: This does NOT delete table data in S3. Metadata in the catalog backend will be lost unless backed up.

## References

- [Apache Iceberg Documentation](https://iceberg.apache.org/docs/latest/)
- [Iceberg REST Catalog API](https://github.com/apache/iceberg/blob/main/open-api/rest-catalog-open-api.yaml)
- [Iceberg Catalog Contract](../../contracts/iceberg-catalog.md)
- [Object Storage Contract](../../contracts/object-storage.md)
- [Tabular REST Catalog Image](https://hub.docker.com/r/tabulario/iceberg-rest)

## License

This chart is part of the Lakehouse project and follows the same license.
