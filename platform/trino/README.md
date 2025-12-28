# Trino Helm Chart

Distributed SQL query engine for the Lakehouse platform, providing SQL access to Iceberg tables.

## Overview

This Helm chart deploys Trino as the query engine for the Lakehouse architecture. Trino provides:

- **SQL Interface**: ANSI SQL:2016 compliant query engine
- **Iceberg Integration**: Native support for Apache Iceberg table format
- **Distributed Execution**: Coordinator + worker architecture for parallel query processing
- **Multiple Interfaces**: JDBC, HTTP, Python, CLI access

## Contract Compliance

This chart implements the **Query Engine Contract** (`contracts/query-engine.md`):

✅ **Iceberg-Only Access**: Trino accesses data exclusively through Iceberg tables  
✅ **DNS-Based Endpoints**: All endpoints use DNS names (no hardcoded IPs)  
✅ **Configurable Catalogs**: Catalog backend is injectable via configuration  
✅ **Environment Agnostic**: Works in Kubernetes, VMs, or bare-metal  
✅ **ANSI SQL**: Standard SQL interface for portability  
✅ **Observability**: Prometheus metrics, structured logging, health checks  

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                         Trino Cluster                        │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  ┌──────────────┐                                           │
│  │ Coordinator  │  ← Receives queries, plans execution      │
│  │  (1 replica) │                                           │
│  └──────┬───────┘                                           │
│         │                                                    │
│         ├─────────┬─────────┬─────────┐                    │
│         ▼         ▼         ▼         ▼                    │
│  ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌─────────┐         │
│  │ Worker  │ │ Worker  │ │ Worker  │ │ Worker  │         │
│  │    1    │ │    2    │ │    3    │ │   ...   │         │
│  └────┬────┘ └────┬────┘ └────┬────┘ └────┬────┘         │
│       │           │           │           │                │
└───────┼───────────┼───────────┼───────────┼────────────────┘
        │           │           │           │
        └───────────┴───────────┴───────────┘
                    │
                    ▼
        ┌───────────────────────┐
        │  Iceberg REST Catalog │
        └───────────┬───────────┘
                    │
                    ▼
        ┌───────────────────────┐
        │   MinIO (S3 Storage)  │
        └───────────────────────┘
```

## Prerequisites

- Kubernetes 1.28+
- Helm 3.8+
- Iceberg Catalog deployed (`platform/iceberg-catalog/`)
- MinIO deployed (`platform/minio/`)
- 8GB+ RAM available for minimal deployment
- 32GB+ RAM recommended for production

## Installation

### 1. Add Trino Helm Repository

```bash
helm repo add trino https://trinodb.github.io/charts
helm repo update
```

### 2. Install Chart Dependencies

```bash
cd platform/trino
helm dependency update
```

### 3. Deploy Trino

**Development Environment:**
```bash
helm install trino . \
  --namespace lakehouse-platform \
  --create-namespace \
  --values values-dev.yaml
```

**Staging Environment:**
```bash
helm install trino . \
  --namespace lakehouse-platform \
  --create-namespace \
  --values values-staging.yaml
```

**Production Environment:**
```bash
helm install trino . \
  --namespace lakehouse-platform \
  --create-namespace \
  --values values-prod.yaml
```

### 4. Verify Deployment

```bash
# Check pod status
kubectl get pods -n lakehouse-platform -l app=trino

# Check coordinator logs
kubectl logs -n lakehouse-platform -l app=trino,component=coordinator

# Check worker logs
kubectl logs -n lakehouse-platform -l app=trino,component=worker

# Port-forward to access Web UI
kubectl port-forward -n lakehouse-platform svc/trino 8080:8080

# Access Web UI at http://localhost:8080/ui/
```

## Configuration

### Environment-Specific Values

| File | Environment | Workers | Memory/Worker | Autoscaling | TLS | Auth |
|------|-------------|---------|---------------|-------------|-----|------|
| `values-dev.yaml` | Development | 2 | 2Gi | ❌ | ❌ | ❌ |
| `values-staging.yaml` | Staging | 3-6 | 4Gi | ✅ | ✅ | ✅ |
| `values-prod.yaml` | Production | 5-20 | 16Gi | ✅ | ✅ | ✅ |

### Key Configuration Options

#### Server Configuration

```yaml
server:
  workers: 2  # Number of worker nodes
  
  coordinator:
    jvm:
      maxHeapSize: "4G"
    resources:
      requests:
        memory: 4Gi
        cpu: 1000m
  
  worker:
    jvm:
      maxHeapSize: "4G"
    resources:
      requests:
        memory: 4Gi
        cpu: 1000m
    
    autoscaling:
      enabled: true
      minReplicas: 2
      maxReplicas: 10
      targetCPUUtilizationPercentage: 70
```

#### Iceberg Catalog Configuration

```yaml
additionalCatalogs:
  iceberg: |
    connector.name=iceberg
    iceberg.catalog.type=rest
    iceberg.rest.uri=http://iceberg-catalog.lakehouse-platform.svc.cluster.local:8181
    iceberg.rest.warehouse=s3://lakehouse-dev-warehouse/
    
    # S3 configuration
    fs.native-s3.enabled=true
    s3.endpoint=http://minio.lakehouse-platform.svc.cluster.local:9000
    s3.path-style-access=true
    s3.aws-access-key=${ENV:S3_ACCESS_KEY}
    s3.aws-secret-key=${ENV:S3_SECRET_KEY}
```

**Supported Catalog Types:**
- `rest` - REST catalog (default)
- `jdbc` - JDBC catalog (PostgreSQL, MySQL)
- `hive` - Hive Metastore
- `glue` - AWS Glue

#### Authentication

```yaml
auth:
  enabled: true
  type: PASSWORD  # PASSWORD, LDAP, OAUTH2
  
  oauth2:
    enabled: true
    issuer: https://auth.company.internal
```

#### Security (TLS)

```yaml
security:
  tls:
    enabled: true
    port: 8443
    keystorePath: /etc/trino/keystore.jks
```

#### Metrics

```yaml
metrics:
  enabled: true
  serviceMonitor:
    enabled: true
    interval: 30s
```

## Usage

### Connecting to Trino

#### JDBC (Java)

```java
String url = "jdbc:trino://trino.lakehouse-platform.svc.cluster.local:8080/iceberg/default";
Properties props = new Properties();
props.setProperty("user", "data-engineer");

Connection conn = DriverManager.getConnection(url, props);
```

#### Python (trino-python-client)

```python
from trino.dbapi import connect

conn = connect(
    host='trino.lakehouse-platform.svc.cluster.local',
    port=8080,
    user='data-engineer',
    catalog='iceberg',
    schema='default'
)

cursor = conn.cursor()
cursor.execute("SELECT * FROM orders LIMIT 10")
rows = cursor.fetchall()
```

#### CLI

```bash
# Install Trino CLI
curl -o trino https://repo1.maven.org/maven2/io/trino/trino-cli/440/trino-cli-440-executable.jar
chmod +x trino

# Connect to Trino
./trino --server http://trino.lakehouse-platform.svc.cluster.local:8080 \
        --catalog iceberg \
        --schema default \
        --user data-engineer
```

### Example Queries

#### Schema Discovery

```sql
-- List catalogs
SHOW CATALOGS;

-- List schemas
SHOW SCHEMAS FROM iceberg;

-- List tables
SHOW TABLES FROM iceberg.sales;

-- Describe table
DESCRIBE iceberg.sales.orders;
```

#### Data Queries

```sql
-- Simple SELECT
SELECT * FROM iceberg.sales.orders LIMIT 10;

-- Aggregation
SELECT 
  status,
  COUNT(*) as order_count,
  SUM(amount) as total_amount
FROM iceberg.sales.orders
GROUP BY status;

-- Time travel
SELECT * FROM iceberg.sales.orders 
FOR TIMESTAMP AS OF TIMESTAMP '2024-12-01 00:00:00';
```

#### Write Operations

```sql
-- INSERT
INSERT INTO iceberg.sales.orders 
VALUES (1, 100, DATE '2024-12-27', 99.99, 'completed');

-- UPDATE (Iceberg v2)
UPDATE iceberg.sales.orders 
SET status = 'shipped' 
WHERE order_id = 1;

-- DELETE (Iceberg v2)
DELETE FROM iceberg.sales.orders 
WHERE order_date < DATE '2023-01-01';

-- MERGE (Iceberg v2)
MERGE INTO iceberg.sales.orders AS target
USING staging.orders AS source
ON target.order_id = source.order_id
WHEN MATCHED THEN UPDATE SET status = source.status
WHEN NOT MATCHED THEN INSERT VALUES (source.*);
```

#### Table Maintenance

```sql
-- Compact small files
ALTER TABLE iceberg.sales.orders EXECUTE optimize;

-- Expire old snapshots (keep 7 days)
ALTER TABLE iceberg.sales.orders 
EXECUTE expire_snapshots(retention_threshold => '7d');

-- Remove orphan files
ALTER TABLE iceberg.sales.orders 
EXECUTE remove_orphan_files(older_than => '3d');
```

## Observability

### Metrics

Trino exposes Prometheus metrics at `/v1/metrics` (via JMX exporter).

**Key Metrics:**
- `trino_queries_total{state="FINISHED"}` - Total completed queries
- `trino_query_execution_time_seconds{quantile="0.99"}` - Query latency (p99)
- `trino_memory_pool_bytes{pool="general"}` - Memory usage
- `trino_active_workers` - Active worker count

**Grafana Dashboard:**
- Import dashboard ID: 12345 (Trino official dashboard)

### Logging

Trino logs are output to stdout in JSON format.

**View Logs:**
```bash
# Coordinator logs
kubectl logs -n lakehouse-platform -l app=trino,component=coordinator -f

# Worker logs
kubectl logs -n lakehouse-platform -l app=trino,component=worker -f
```

### Web UI

Access the Trino Web UI for live query monitoring:

```bash
kubectl port-forward -n lakehouse-platform svc/trino 8080:8080
```

Navigate to: `http://localhost:8080/ui/`

**Features:**
- Live query monitoring
- Query history
- Cluster status
- Worker nodes status
- Resource utilization

### Health Checks

**Liveness Probe:** `GET /v1/info`  
**Readiness Probe:** `GET /v1/info/state`

```bash
# Check health
curl http://trino.lakehouse-platform.svc.cluster.local:8080/v1/info

# Check readiness
curl http://trino.lakehouse-platform.svc.cluster.local:8080/v1/info/state
```

## Scaling

### Manual Scaling

```bash
# Scale workers
kubectl scale deployment trino-worker \
  --replicas=5 \
  -n lakehouse-platform
```

### Autoscaling

Enable HorizontalPodAutoscaler in values:

```yaml
server:
  worker:
    autoscaling:
      enabled: true
      minReplicas: 2
      maxReplicas: 10
      targetCPUUtilizationPercentage: 70
```

## Troubleshooting

### Common Issues

#### 1. Trino Cannot Connect to Iceberg Catalog

**Symptoms:**
- Queries fail with "Catalog not found"
- Coordinator logs show connection errors

**Solution:**
```bash
# Verify Iceberg catalog is running
kubectl get pods -n lakehouse-platform -l app=iceberg-catalog

# Check catalog endpoint
kubectl exec -n lakehouse-platform -it trino-coordinator-0 -- \
  curl http://iceberg-catalog.lakehouse-platform.svc.cluster.local:8181/v1/config

# Verify catalog configuration
kubectl exec -n lakehouse-platform -it trino-coordinator-0 -- \
  cat /etc/trino/catalog/iceberg.properties
```

#### 2. Queries Fail with "Out of Memory"

**Symptoms:**
- Queries fail with OOM errors
- Workers are killed by Kubernetes

**Solution:**
```yaml
# Increase worker memory
server:
  worker:
    jvm:
      maxHeapSize: "8G"
    resources:
      limits:
        memory: 16Gi

# Enable spill to disk
server:
  worker:
    config:
      general:
        experimental.spill-enabled: true
        experimental.spiller-spill-path: /tmp/trino-spill
```

#### 3. Slow Query Performance

**Symptoms:**
- Queries take longer than expected
- High CPU usage on workers

**Solution:**
```sql
-- Check query execution plan
EXPLAIN SELECT * FROM iceberg.sales.orders WHERE status = 'completed';

-- Verify partition pruning is working
EXPLAIN ANALYZE SELECT * FROM iceberg.sales.orders 
WHERE order_date >= DATE '2024-01-01';

-- Optimize table (compact small files)
ALTER TABLE iceberg.sales.orders EXECUTE optimize;
```

#### 4. Workers Not Joining Cluster

**Symptoms:**
- Workers show as "starting" in Web UI
- Coordinator logs show "No workers available"

**Solution:**
```bash
# Check worker logs
kubectl logs -n lakehouse-platform -l app=trino,component=worker

# Verify discovery URI
kubectl exec -n lakehouse-platform -it trino-worker-0 -- \
  cat /etc/trino/config.properties | grep discovery.uri

# Restart workers
kubectl rollout restart deployment/trino-worker -n lakehouse-platform
```

### Debug Commands

```bash
# Check all Trino resources
kubectl get all -n lakehouse-platform -l app=trino

# Describe coordinator pod
kubectl describe pod -n lakehouse-platform -l app=trino,component=coordinator

# Exec into coordinator
kubectl exec -n lakehouse-platform -it trino-coordinator-0 -- /bin/bash

# View Trino configuration
kubectl exec -n lakehouse-platform -it trino-coordinator-0 -- \
  cat /etc/trino/config.properties

# View catalog configuration
kubectl exec -n lakehouse-platform -it trino-coordinator-0 -- \
  cat /etc/trino/catalog/iceberg.properties

# Check JVM heap usage
kubectl exec -n lakehouse-platform -it trino-coordinator-0 -- \
  jstat -gc 1
```

## Upgrading

### Upgrade Trino Version

1. Update `Chart.yaml`:
```yaml
appVersion: "450"  # New version
```

2. Update `values.yaml`:
```yaml
image:
  tag: "450"
```

3. Apply upgrade:
```bash
helm upgrade trino . \
  --namespace lakehouse-platform \
  --values values-prod.yaml
```

### Rollback

```bash
# View release history
helm history trino -n lakehouse-platform

# Rollback to previous version
helm rollback trino -n lakehouse-platform
```

## Security

### Credentials Management

**Development:**
- Credentials in `values-dev.yaml` (acceptable for local testing)

**Staging/Production:**
- Use Kubernetes Secrets
- Use External Secrets Operator
- Use cloud provider secret managers (AWS Secrets Manager, Azure Key Vault, GCP Secret Manager)

**Example with External Secrets:**
```yaml
env:
  - name: S3_ACCESS_KEY
    valueFrom:
      secretKeyRef:
        name: trino-s3-credentials  # Managed by External Secrets Operator
        key: accessKeyId
```

### Network Policies

Recommended network policies for production:

```yaml
# Allow coordinator to access Iceberg catalog
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: trino-coordinator-egress
spec:
  podSelector:
    matchLabels:
      app: trino
      component: coordinator
  policyTypes:
    - Egress
  egress:
    - to:
        - podSelector:
            matchLabels:
              app: iceberg-catalog
      ports:
        - protocol: TCP
          port: 8181
```

## Contract Validation

This chart is compliant with `contracts/query-engine.md` if:

✅ Trino accesses data **only through Iceberg tables**  
✅ No direct S3 path queries  
✅ Endpoints use **DNS names** (no hardcoded IPs)  
✅ Catalog configuration is **injectable**  
✅ Supports **ANSI SQL** (portable queries)  
✅ Exposes **Prometheus metrics**  
✅ Provides **health check endpoints**  
✅ Configuration is **environment-agnostic**  

## References

- **Trino Documentation**: https://trino.io/docs/current/
- **Trino Iceberg Connector**: https://trino.io/docs/current/connector/iceberg.html
- **Trino Helm Chart**: https://github.com/trinodb/charts
- **Query Engine Contract**: `contracts/query-engine.md`
- **Iceberg Catalog Contract**: `contracts/iceberg-catalog.md`
- **Object Storage Contract**: `contracts/object-storage.md`

## Support

For issues or questions:
1. Check the troubleshooting section above
2. Review Trino logs: `kubectl logs -n lakehouse-platform -l app=trino`
3. Check Web UI: `http://localhost:8080/ui/` (via port-forward)
4. Consult Trino documentation: https://trino.io/docs/
