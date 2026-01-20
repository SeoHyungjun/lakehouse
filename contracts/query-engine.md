# Query Engine Contract (Trino)

This document defines the interface contract for the SQL query engine in the Lakehouse architecture.

**Contract Version**: 1.0  
**Last Updated**: 2025-12-27

---

## 1. Purpose

Trino provides the SQL query interface for the Lakehouse, enabling interactive and batch analytics on Iceberg tables stored in object storage.

**Critical Principles**:
- Trino accesses data **only through Iceberg tables**
- No direct access to raw object paths
- SQL endpoint must be **configurable**
- No Trino-specific SQL extensions in shared/portable code

---

## 2. Query Engine Requirements

### 2.1 Trino Version

**Minimum Version**: Trino 400+  
**Recommended**: Trino 430+ (latest stable)

**Rationale**: Full support for Iceberg v2 features (row-level deletes, merge-on-read)

### 2.2 Deployment Architecture

**Coordinator**:
- Single coordinator node (HA optional for production)
- Handles query parsing, planning, orchestration
- Does not process data

**Workers**:
- Multiple worker nodes (scalable)
- Execute query tasks
- Process data in parallel

**Minimum Configuration** (development):
- 1 coordinator (2 CPU, 4GB RAM)
- 2 workers (2 CPU, 4GB RAM each)

**Production Configuration**:
- Configurable per environment
- No hardcoded resource specifications

---

## 3. Interface Requirements

### 3.1 SQL over HTTP

**Protocol**: HTTP/HTTPS  
**Default Port**: 8080 (HTTP), 8443 (HTTPS)

**Endpoint Format**:
```
http://<trino-host>:<port>/v1/statement
```

**Example**:
```
http://trino.lakehouse-platform.svc.cluster.local:8080/v1/statement
```

### 3.2 JDBC Compatibility

**JDBC URL Format**:
```
jdbc:trino://<host>:<port>/<catalog>/<schema>
```

**Examples**:
```
jdbc:trino://trino.lakehouse-platform.svc.cluster.local:8080/iceberg/sales
jdbc:trino://trino.company.internal:8443/iceberg/default
```

**JDBC Driver**: `io.trino:trino-jdbc`

### 3.3 Client Libraries

**Supported Clients**:
- JDBC driver (Java, Python via JayDeBeApi)
- Python: `trino-python-client`
- Go: `trino-go-client`
- CLI: `trino-cli`
- Web UI: `http://<trino-host>:8080/ui/`

---

## 4. Endpoint Configuration

### 4.1 DNS-Based Endpoints

**All endpoints must use DNS names, never IP addresses.**

**Internal Kubernetes Service**:
```yaml
trino:
  endpoint: http://trino.lakehouse-platform.svc.cluster.local:8080
  catalog: iceberg
```

**External Service** (VM or cloud):
```yaml
trino:
  endpoint: https://trino.company.internal:8443
  catalog: iceberg
```

### 4.2 Configuration Schema

```yaml
trino:
  # Endpoint (required)
  endpoint: http://trino.lakehouse-platform.svc.cluster.local:8080
  
  # Catalog (required)
  catalog: iceberg
  
  # Schema (optional, defaults to 'default')
  schema: sales
  
  # Authentication (optional)
  user: ${TRINO_USER}
  password: ${TRINO_PASSWORD}
  
  # TLS (optional)
  use_ssl: false
  verify_ssl: true
```

---

## 5. Catalog Configuration (Iceberg)

### 5.1 Iceberg Connector

**Required Connector**: `iceberg`

**Connector Configuration** (`catalog/iceberg.properties`):
```properties
connector.name=iceberg
iceberg.catalog.type=rest
iceberg.rest.uri=http://iceberg-catalog.lakehouse-platform.svc.cluster.local:8181
iceberg.rest.warehouse=s3://lakehouse/

# S3 configuration (references object-storage contract)
fs.native-s3.enabled=true
s3.endpoint=http://minio.lakehouse-platform.svc.cluster.local:9000
s3.path-style-access=true
s3.aws-access-key=${ENV:S3_ACCESS_KEY}
s3.aws-secret-key=${ENV:S3_SECRET_KEY}
```

### 5.2 Catalog Type Support

**Required Support**:
- REST catalog (default)
- JDBC catalog
- Hive Metastore catalog
- AWS Glue catalog

**Configuration must be injectable** (no hardcoded catalog type).

### 5.3 Multiple Catalogs (Optional)

Trino can connect to multiple catalogs:
```properties
# catalog/iceberg.properties
connector.name=iceberg
iceberg.catalog.type=rest
...

# catalog/iceberg_prod.properties
connector.name=iceberg
iceberg.catalog.type=glue
...
```

**Query Syntax**:
```sql
SELECT * FROM iceberg.sales.orders;
SELECT * FROM iceberg_prod.sales.orders;
```

---

## 6. Data Access Rules

### 6.1 Iceberg Tables Only

**Critical Rule**: Trino must access data **only through Iceberg tables**.

**Allowed**:
```sql
SELECT * FROM iceberg.sales.orders;
SELECT * FROM iceberg.sales.customers WHERE region = 'us-east';
```

**Forbidden**:
```sql
-- Direct S3 path access (NOT ALLOWED)
SELECT * FROM s3."s3://lakehouse/sales/orders/data/*.parquet";
```

### 6.2 No Direct Object Path Access

- No Hive connector for raw Parquet/ORC files
- No direct file system access
- All queries must reference Iceberg tables via catalog

### 6.3 Schema Discovery

**List Catalogs**:
```sql
SHOW CATALOGS;
```

**List Schemas** (namespaces):
```sql
SHOW SCHEMAS FROM iceberg;
```

**List Tables**:
```sql
SHOW TABLES FROM iceberg.sales;
```

**Describe Table**:
```sql
DESCRIBE iceberg.sales.orders;
SHOW CREATE TABLE iceberg.sales.orders;
```

---

## 7. SQL Dialect and Compatibility

### 7.1 Standard SQL

**Required**: ANSI SQL:2016 compliance

**Supported Features**:
- SELECT, INSERT, UPDATE, DELETE, MERGE
- JOINs (INNER, LEFT, RIGHT, FULL OUTER, CROSS)
- Subqueries, CTEs (WITH clause)
- Window functions
- Aggregations (GROUP BY, HAVING)
- Set operations (UNION, INTERSECT, EXCEPT)

### 7.2 Iceberg-Specific Operations

**Time Travel**:
```sql
-- Query as of timestamp
SELECT * FROM iceberg.sales.orders FOR TIMESTAMP AS OF TIMESTAMP '2024-12-01 00:00:00';

-- Query as of snapshot
SELECT * FROM iceberg.sales.orders FOR VERSION AS OF 123456789;
```

**Incremental Reads**:
```sql
-- Read changes since snapshot
SELECT * FROM iceberg.sales.orders 
FOR VERSION AS OF 123456789
WHERE $file_modified_time > TIMESTAMP '2024-12-01 00:00:00';
```

**Metadata Queries**:
```sql
-- Table snapshots
SELECT * FROM iceberg.sales."orders$snapshots";

-- Table files
SELECT * FROM iceberg.sales."orders$files";

-- Table history
SELECT * FROM iceberg.sales."orders$history";
```

### 7.3 Write Operations

**INSERT**:
```sql
INSERT INTO iceberg.sales.orders VALUES (1, 100, DATE '2024-12-27', 99.99, 'completed');
INSERT INTO iceberg.sales.orders SELECT * FROM staging.orders;
```

**UPDATE** (Iceberg v2):
```sql
UPDATE iceberg.sales.orders SET status = 'shipped' WHERE order_id = 1;
```

**DELETE** (Iceberg v2):
```sql
DELETE FROM iceberg.sales.orders WHERE order_date < DATE '2023-01-01';
```

**MERGE** (Iceberg v2):
```sql
MERGE INTO iceberg.sales.orders AS target
USING staging.orders AS source
ON target.order_id = source.order_id
WHEN MATCHED THEN UPDATE SET status = source.status
WHEN NOT MATCHED THEN INSERT VALUES (source.order_id, source.customer_id, source.order_date, source.amount, source.status);
```

### 7.4 DDL Operations

**Create Table**:
```sql
CREATE TABLE iceberg.sales.orders (
  order_id BIGINT,
  customer_id BIGINT,
  order_date DATE,
  amount DECIMAL(10,2),
  status VARCHAR
)
WITH (
  format = 'PARQUET',
  partitioning = ARRAY['month(order_date)']
);
```

**Drop Table**:
```sql
DROP TABLE iceberg.sales.orders;
```

**Alter Table** (Schema Evolution):
```sql
ALTER TABLE iceberg.sales.orders ADD COLUMN shipping_address VARCHAR;
ALTER TABLE iceberg.sales.orders RENAME COLUMN amount TO total_amount;
ALTER TABLE iceberg.sales.orders DROP COLUMN status;
```

**Optimize Table**:
```sql
-- Compact small files
ALTER TABLE iceberg.sales.orders EXECUTE optimize;

-- Expire old snapshots
ALTER TABLE iceberg.sales.orders EXECUTE expire_snapshots(retention_threshold => '7d');

-- Remove orphan files
ALTER TABLE iceberg.sales.orders EXECUTE remove_orphan_files(older_than => '3d');
```

### 7.5 Forbidden SQL Extensions

**Not Allowed in Shared/Portable Code**:
- Trino-specific functions (use ANSI SQL equivalents)
- Connector-specific syntax
- Proprietary extensions

**Rationale**: Ensures portability if query engine is replaced.

---

## 8. Authentication and Authorization

### 8.1 Authentication Methods

**Supported**:
- No authentication (development only)
- Password authentication
- LDAP
- Kerberos
- OAuth 2.0 / JWT

**Configuration** (`config.properties`):
```properties
# Password authentication
http-server.authentication.type=PASSWORD

# LDAP
http-server.authentication.type=LDAP
authentication.ldap.url=ldaps://ldap.company.internal

# OAuth 2.0
http-server.authentication.type=OAUTH2
http-server.authentication.oauth2.issuer=https://auth.company.internal
```

### 8.2 Authorization

**Access Control**:
- System-level access control (file-based or connector-based)
- Catalog-level permissions
- Schema-level permissions
- Table-level permissions
- Column-level permissions (optional)

**Example** (`access-control.properties`):
```properties
access-control.name=file
security.config-file=/etc/trino/rules.json
```

**Rules File** (`rules.json`):
```json
{
  "catalogs": [
    {
      "catalog": "iceberg",
      "allow": ["user:data-engineer", "group:analytics"]
    }
  ],
  "schemas": [
    {
      "catalog": "iceberg",
      "schema": "sales",
      "owner": "user:sales-team"
    }
  ]
}
```

### 8.3 Credential Management

**Allowed**:
- Environment variables
- Kubernetes Secrets
- External secrets manager

**Forbidden**:
- Hardcoded credentials in configuration files committed to Git
- Credentials in container images

---

## 9. Performance and Optimization

### 9.1 Query Optimization

**Automatic Optimizations**:
- Predicate pushdown (filter pushdown to Iceberg)
- Partition pruning (via Iceberg hidden partitioning)
- Column pruning (read only required columns)
- Join reordering
- Cost-based optimization

### 9.2 Caching

**Metadata Caching**:
- Iceberg metadata cached by Trino
- Configurable TTL

**Data Caching** (optional):
- Alluxio or similar distributed cache
- Caches frequently accessed data

### 9.3 Resource Management

**Memory Configuration**:
```properties
query.max-memory=50GB
query.max-memory-per-node=10GB
query.max-total-memory-per-node=12GB
```

**Concurrency**:
```properties
query.max-concurrent-queries=100
```

**Spill to Disk** (for large queries):
```properties
experimental.spill-enabled=true
experimental.spiller-spill-path=/tmp/trino-spill
```

---

## 10. Observability

### 10.1 Metrics

**Required Metrics**:
- Query count (total, running, queued, failed)
- Query latency (p50, p95, p99)
- Data scanned (bytes)
- Rows processed
- Active workers
- Memory usage
- CPU usage

**Prometheus Endpoint**: `/v1/metrics` (via JMX exporter)

**Example Metrics**:
```
trino_queries_total{state="FINISHED"}
trino_query_execution_time_seconds{quantile="0.99"}
trino_memory_pool_bytes{pool="general"}
trino_active_workers
```

### 10.2 Logging

**Required Logs**:
- Query logs (query text, user, duration, status)
- Error logs (failed queries, reasons)
- Audit logs (DDL operations, access patterns)

**Log Format**: JSON (structured logging)

**Log Levels**:
- INFO: Query execution, completion
- WARN: Slow queries, resource warnings
- ERROR: Failed queries, system errors

### 10.3 Web UI

**Endpoint**: `http://<trino-host>:8080/ui/`

**Features**:
- Live query monitoring
- Query history
- Cluster status
- Worker nodes status
- Resource utilization

### 10.4 Health Checks

**Liveness Probe**: `GET /v1/info`  
**Readiness Probe**: `GET /v1/info/state` (returns `ACTIVE` when ready)

**Example Response**:
```json
{
  "nodeVersion": {
    "version": "430"
  },
  "environment": "production",
  "coordinator": true,
  "starting": false
}
```

---

## 11. High Availability and Scalability

### 11.1 Coordinator HA (Optional)

**Production Recommendation**: Single coordinator with fast failover

**HA Options**:
- Active-passive with shared state
- Load balancer with health checks
- Kubernetes StatefulSet with readiness probes

### 11.2 Worker Scaling

**Horizontal Scaling**:
- Add/remove worker nodes dynamically
- Kubernetes HorizontalPodAutoscaler (HPA)
- Scale based on query queue length or CPU usage

**Auto-scaling Configuration**:
```yaml
autoscaling:
  enabled: true
  minReplicas: 2
  maxReplicas: 10
  targetCPUUtilizationPercentage: 70
```

### 11.3 Fault Tolerance

**Query Retry**:
- Automatic retry on transient failures
- Configurable retry policy

**Worker Failure**:
- Query re-scheduled to healthy workers
- Graceful degradation

---

## 12. Security

### 12.1 Encryption in Transit

**Required for Production**: TLS 1.2+

**Configuration**:
```properties
http-server.https.enabled=true
http-server.https.port=8443
http-server.https.keystore.path=/etc/trino/keystore.jks
http-server.https.keystore.key=${ENV:KEYSTORE_PASSWORD}
```

### 12.2 Encryption at Rest

**Data Encryption**: Handled by object storage (S3 SSE)  
**Metadata Encryption**: Handled by Iceberg catalog

Trino does not store data at rest (query engine only).

### 12.3 Network Policies

**Recommended**:
- Restrict coordinator access to authorized clients only
- Workers communicate only with coordinator
- Coordinator accesses Iceberg catalog and object storage

---

## 13. Configuration Management

### 13.1 Configuration Files

**Required Files**:
- `config.properties` - Coordinator/worker configuration
- `jvm.config` - JVM settings
- `log.properties` - Logging configuration
- `node.properties` - Node identification
- `catalog/iceberg.properties` - Iceberg connector configuration

### 13.2 Configuration Injection

**All configuration must be injectable via**:
- Helm values
- Environment variables
- ConfigMaps (Kubernetes)

**No hardcoded values in container images.**

### 13.3 Example Configuration (config.properties)

```properties
coordinator=true
node-scheduler.include-coordinator=false
http-server.http.port=8080
discovery.uri=http://localhost:8080

query.max-memory=50GB
query.max-memory-per-node=10GB
```

---

## 14. Client Connection Examples

### 14.1 JDBC (Java)

```java
import java.sql.*;

String url = "jdbc:trino://trino.lakehouse-platform.svc.cluster.local:8080/iceberg/sales";
Properties props = new Properties();
props.setProperty("user", "data-engineer");

Connection conn = DriverManager.getConnection(url, props);
Statement stmt = conn.createStatement();
ResultSet rs = stmt.executeQuery("SELECT * FROM orders LIMIT 10");

while (rs.next()) {
    System.out.println(rs.getLong("order_id"));
}
```

### 14.2 Python (trino-python-client)

```python
from trino.dbapi import connect

conn = connect(
    host='trino.lakehouse-platform.svc.cluster.local',
    port=8080,
    user='data-engineer',
    catalog='iceberg',
    schema='sales'
)

cursor = conn.cursor()
cursor.execute("SELECT * FROM orders LIMIT 10")
rows = cursor.fetchall()

for row in rows:
    print(row)
```

### 14.3 CLI

```bash
trino --server http://trino.lakehouse-platform.svc.cluster.local:8080 \
      --catalog iceberg \
      --schema sales \
      --user data-engineer
```

---

## 15. Migration and Portability

### 15.1 Query Engine Replacement

**If replacing Trino with another engine** (e.g., Spark SQL, Presto):
1. Ensure new engine supports Iceberg connector
2. Update endpoint configuration
3. Verify SQL compatibility (ANSI SQL)
4. No application code changes if SQL is portable

### 15.2 Portability Guidelines

**To ensure portability**:
- Use ANSI SQL only (avoid Trino-specific functions)
- Reference tables via catalog.schema.table
- No direct connector access in application code

---

## 16. Compliance Rules

### 16.1 Contract Stability

Once published, this contract cannot be broken without:
- Major version bump
- Migration guide
- Backward compatibility period

### 16.2 Validation Checklist

A query engine implementation is compliant if:
- ✅ Exposes SQL over HTTP interface
- ✅ JDBC-compatible endpoint
- ✅ Accesses data only through Iceberg tables
- ✅ No direct object path access
- ✅ Endpoint is DNS-based (no hardcoded IPs)
- ✅ Configuration injectable via environment variables
- ✅ Supports ANSI SQL

### 16.3 Automatic Failure Conditions

**Contract is violated if**:
- Direct S3 path queries (bypassing Iceberg)
- Hardcoded endpoint IP addresses
- Trino-specific SQL in shared application code
- Hardcoded catalog configuration

---

## 17. Default Implementation

**Default**: Trino 430+  
**Alternatives**: Presto, Spark SQL, Dremio (must support Iceberg)

**Switching query engines must require only configuration changes and SQL compatibility verification.**

---

## 18. References

- Trino Documentation: https://trino.io/docs/current/
- Trino Iceberg Connector: https://trino.io/docs/current/connector/iceberg.html
- Trino JDBC Driver: https://trino.io/docs/current/client/jdbc.html
- Trino Security: https://trino.io/docs/current/security.html
- Trino Performance Tuning: https://trino.io/docs/current/admin/tuning.html
