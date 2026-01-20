# Iceberg Catalog Contract

This document defines the interface contract for Apache Iceberg table format and catalog in the Lakehouse architecture.

**Contract Version**: 1.0  
**Last Updated**: 2025-12-27

---

## 1. Purpose

Apache Iceberg provides the table format layer for the Lakehouse, enabling ACID transactions, schema evolution, time travel, and efficient data management on object storage.

**Critical Principles**:
- Iceberg is the **single source of truth** for analytical tables
- All data access must go through Iceberg APIs
- Direct object path access is **forbidden**
- Catalog backend must be **replaceable via configuration only**

---

## 2. Table Format Requirements

### 2.1 Apache Iceberg Specification

**Required**: Apache Iceberg Table Format Specification v2

**Supported Features**:
- ACID transactions
- Schema evolution (add, drop, rename columns)
- Partition evolution (change partitioning without rewriting data)
- Time travel (query historical snapshots)
- Hidden partitioning (automatic partition pruning)
- Snapshot isolation
- Incremental reads

### 2.2 File Formats

**Supported Data File Formats**:
- **Parquet** (preferred, default)
- ORC
- Avro

**Metadata Files**:
- JSON (Iceberg metadata format)

### 2.3 Table Versioning

**Iceberg Format Version**: v2 (default)
- Format v1: Supported for backward compatibility
- Format v2: Required for production (supports row-level deletes, merge-on-read)

---

## 3. Catalog Interface

### 3.1 Catalog Abstraction

The catalog is responsible for:
- Table metadata storage and retrieval
- Namespace (database) management
- Table discovery and listing
- Atomic metadata updates

**Critical Rule**: Catalog backend must be swappable without code changes.

### 3.2 Supported Catalog Backends

**Required Support**:
1. **REST Catalog** (default)
2. **JDBC Catalog** (PostgreSQL, MySQL)
3. **Hive Metastore** (for legacy compatibility)
4. **AWS Glue** (cloud-managed)

**Optional**:
- Nessie Catalog (version control for tables)
- Custom catalog implementations

### 3.3 Catalog Selection

Catalog type must be configurable:
```yaml
iceberg:
  catalog:
    type: rest  # rest | jdbc | hive | glue
    # Configuration specific to catalog type
```

---

## 4. REST Catalog (Default)

### 4.1 REST Catalog Specification

**API**: Iceberg REST Catalog API  
**Protocol**: HTTP/HTTPS  
**Format**: JSON

**Required Endpoints**:
- `GET /v1/config` - Catalog configuration
- `GET /v1/namespaces` - List namespaces
- `POST /v1/namespaces` - Create namespace
- `GET /v1/namespaces/{namespace}/tables` - List tables
- `POST /v1/namespaces/{namespace}/tables` - Create table
- `GET /v1/namespaces/{namespace}/tables/{table}` - Load table metadata
- `POST /v1/namespaces/{namespace}/tables/{table}` - Update table metadata
- `DELETE /v1/namespaces/{namespace}/tables/{table}` - Drop table

### 4.2 REST Catalog Configuration

```yaml
iceberg:
  catalog:
    type: rest
    uri: http://iceberg-catalog.lakehouse-platform.svc.cluster.local:8181
    warehouse: s3://lakehouse/
    credential: <access-token>  # optional
```

**DNS-Based Endpoint**: Required (no hardcoded IPs)

### 4.3 Authentication

**Supported Methods**:
- Bearer token (OAuth 2.0)
- Basic authentication
- No authentication (development only)

**Example**:
```yaml
iceberg:
  catalog:
    type: rest
    uri: https://iceberg-catalog.company.internal
    credential: ${ICEBERG_CATALOG_TOKEN}
```

---

## 5. JDBC Catalog

### 5.1 JDBC Catalog Configuration

```yaml
iceberg:
  catalog:
    type: jdbc
    uri: jdbc:postgresql://postgres.lakehouse-platform.svc.cluster.local:5432/iceberg
    warehouse: s3://lakehouse/
    jdbc:
      username: ${JDBC_USERNAME}
      password: ${JDBC_PASSWORD}
      driver: org.postgresql.Driver
```

### 5.2 Supported Databases

**Required**:
- PostgreSQL 12+
- MySQL 8+

**Optional**:
- SQLite (development/testing only)

### 5.3 Schema Initialization

JDBC catalog requires database schema initialization:
```sql
CREATE TABLE iceberg_tables (
  catalog_name VARCHAR(255) NOT NULL,
  table_namespace VARCHAR(255) NOT NULL,
  table_name VARCHAR(255) NOT NULL,
  metadata_location TEXT,
  previous_metadata_location TEXT,
  PRIMARY KEY (catalog_name, table_namespace, table_name)
);

CREATE TABLE iceberg_namespace_properties (
  catalog_name VARCHAR(255) NOT NULL,
  namespace VARCHAR(255) NOT NULL,
  property_key VARCHAR(255),
  property_value TEXT,
  PRIMARY KEY (catalog_name, namespace, property_key)
);
```

---

## 6. Hive Metastore Catalog

### 6.1 Hive Metastore Configuration

```yaml
iceberg:
  catalog:
    type: hive
    uri: thrift://hive-metastore.lakehouse-platform.svc.cluster.local:9083
    warehouse: s3://lakehouse/
    hive:
      conf_dir: /etc/hive/conf  # optional
```

### 6.2 Hive Metastore Requirements

**Minimum Version**: Hive 2.3+  
**Recommended**: Hive 3.1+

**Thrift Protocol**: Required

### 6.3 Hive Metastore Limitations

- No native support for Iceberg v2 features in older Hive versions
- Recommended for legacy compatibility only
- Prefer REST or JDBC catalog for new deployments

---

## 7. AWS Glue Catalog

### 7.1 AWS Glue Configuration

```yaml
iceberg:
  catalog:
    type: glue
    warehouse: s3://lakehouse-prod-warehouse/
    glue:
      region: us-east-1
      catalog_id: ${AWS_ACCOUNT_ID}  # optional
```

### 7.2 AWS Glue Authentication

**Supported Methods**:
- IAM roles (preferred)
- Access key / secret key

**Example with IAM Role**:
```yaml
iceberg:
  catalog:
    type: glue
    warehouse: s3://lakehouse-prod-warehouse/
    glue:
      region: us-east-1
      # IAM role attached to service account
```

### 7.3 AWS Glue Limitations

- Cloud-specific (AWS only)
- Not portable to other environments
- Use only when required by organizational policy

---

## 8. Warehouse Location

### 8.1 Warehouse Path

**Format**: `s3://<bucket>/<prefix>/`

**Examples**:
```yaml
# Development
warehouse: s3://lakehouse/

# Production with prefix
warehouse: s3://lakehouse-prod-warehouse/iceberg/

# Multi-tenant
warehouse: s3://lakehouse-prod-warehouse/tenant-a/
```

### 8.2 Warehouse Structure

```
s3://lakehouse/
  sales/                    # namespace (database)
    orders/                 # table
      metadata/
        v1.metadata.json
        v2.metadata.json
        snap-123.avro
      data/
        year=2024/
          month=12/
            00000-0-data.parquet
            00001-0-data.parquet
    customers/
      metadata/
      data/
```

### 8.3 Warehouse Configuration

Warehouse location must be:
- Configurable per environment
- Accessible via S3-compatible API (per object storage contract)
- No hardcoded paths in code

---

## 9. Namespace (Database) Management

### 9.1 Namespace Naming

**Format**: Lowercase, alphanumeric, underscores allowed

**Examples**:
- `sales`
- `marketing`
- `data_engineering`

**Multi-level Namespaces** (optional):
- `sales.us_east`
- `sales.eu_west`

### 9.2 Namespace Properties

```yaml
namespace: sales
properties:
  owner: data-team
  description: Sales department data
  location: s3://lakehouse-prod-warehouse/sales/
```

### 9.3 Namespace Operations

**Required Operations**:
- Create namespace
- Drop namespace
- List namespaces
- Get namespace properties
- Update namespace properties

---

## 10. Table Management

### 10.1 Table Naming

**Format**: Lowercase, alphanumeric, underscores allowed

**Examples**:
- `orders`
- `customer_profiles`
- `daily_sales_summary`

**Fully Qualified Table Name**: `<namespace>.<table>`
- `sales.orders`
- `marketing.campaigns`

### 10.2 Table Schema

**Schema Definition**:
```json
{
  "type": "struct",
  "fields": [
    {"id": 1, "name": "order_id", "required": true, "type": "long"},
    {"id": 2, "name": "customer_id", "required": true, "type": "long"},
    {"id": 3, "name": "order_date", "required": true, "type": "date"},
    {"id": 4, "name": "amount", "required": true, "type": "decimal(10,2)"},
    {"id": 5, "name": "status", "required": false, "type": "string"}
  ]
}
```

### 10.3 Schema Evolution

**Supported Operations**:
- Add column (append)
- Drop column
- Rename column
- Update column type (compatible changes only)
- Reorder columns

**Example**:
```sql
-- Add column
ALTER TABLE sales.orders ADD COLUMN shipping_address STRING;

-- Rename column
ALTER TABLE sales.orders RENAME COLUMN amount TO total_amount;

-- Drop column
ALTER TABLE sales.orders DROP COLUMN status;
```

### 10.4 Partitioning

**Partition Transforms**:
- Identity: `partition by (region)`
- Year: `partition by years(order_date)`
- Month: `partition by months(order_date)`
- Day: `partition by days(order_date)`
- Hour: `partition by hours(event_time)`
- Bucket: `partition by bucket(10, customer_id)`
- Truncate: `partition by truncate(5, user_id)`

**Hidden Partitioning**: Users query by `order_date`, Iceberg handles partition pruning automatically.

### 10.5 Partition Evolution

**Critical Feature**: Change partitioning without rewriting data

**Example**:
```sql
-- Initial partitioning by year
CREATE TABLE sales.orders (...) PARTITION BY years(order_date);

-- Evolve to partition by month (no data rewrite)
ALTER TABLE sales.orders SET PARTITION SPEC months(order_date);
```

---

## 11. Snapshot Management

### 11.1 Snapshots

Each write operation creates a new snapshot:
- Snapshot ID (unique)
- Timestamp
- Parent snapshot ID
- Manifest list location

### 11.2 Time Travel

**Query Historical Data**:
```sql
-- Query as of specific timestamp
SELECT * FROM sales.orders TIMESTAMP AS OF '2024-12-01 00:00:00';

-- Query specific snapshot
SELECT * FROM sales.orders VERSION AS OF 123456789;
```

### 11.3 Snapshot Retention

**Default Retention**:
- Keep last 7 days of snapshots
- Configurable per table

**Snapshot Expiration**:
```sql
-- Expire snapshots older than 7 days
CALL iceberg.system.expire_snapshots('sales.orders', TIMESTAMP '2024-12-20 00:00:00');
```

---

## 12. Data Access Rules

### 12.1 Iceberg API Only

**Required**: All data reads and writes must use Iceberg APIs

**Allowed**:
- Iceberg Java/Python/Rust libraries
- Query engines with Iceberg connectors (Trino, Spark, Flink)
- Iceberg table metadata access

**Forbidden**:
- Direct S3 path access (e.g., `s3://bucket/table/data/file.parquet`)
- Bypassing Iceberg metadata
- Manual file manipulation

### 12.2 Write Operations

**Supported Write Modes**:
- Append (add new data)
- Overwrite (replace all data)
- Overwrite partitions (replace specific partitions)
- Delete (row-level deletes, Iceberg v2)
- Update (row-level updates, Iceberg v2)
- Merge (upsert, Iceberg v2)

### 12.3 Read Operations

**Supported Read Modes**:
- Full table scan
- Partition pruning (automatic)
- Column pruning (automatic)
- Snapshot reads (time travel)
- Incremental reads (read only new data since last snapshot)

---

## 13. Metadata Management

### 13.1 Metadata Files

**Metadata File Types**:
- Table metadata JSON (version history, schema, partition spec)
- Manifest lists (list of manifest files)
- Manifest files (list of data files with statistics)
- Snapshot metadata

### 13.2 Metadata Location

**Stored in**: Object storage (S3-compatible)

**Example**:
```
s3://lakehouse/sales/orders/metadata/
  v1.metadata.json
  v2.metadata.json
  v3.metadata.json
  snap-123-1-abc.avro
  snap-124-1-def.avro
```

### 13.3 Metadata Caching

**Catalog Responsibility**: Cache table metadata for performance

**Invalidation**: On table updates

---

## 14. Concurrency and Isolation

### 14.1 Optimistic Concurrency Control

Iceberg uses optimistic concurrency:
- Multiple readers: Always allowed
- Multiple writers: Serialized via atomic metadata updates
- Conflict resolution: Last writer wins (with retry)

### 14.2 Isolation Levels

**Snapshot Isolation**: Each query sees a consistent snapshot of the table

**Serializable**: Writes are serialized via catalog atomic operations

---

## 15. Observability

### 15.1 Metrics

**Catalog Metrics**:
- Table metadata requests (count, latency)
- Catalog operation errors
- Active connections

**Table Metrics**:
- Number of snapshots
- Table size (bytes)
- Number of data files
- Number of rows (approximate)

**Prometheus Format**:
```
iceberg_catalog_requests_total{operation="load_table", status="success"}
iceberg_catalog_request_duration_seconds{operation="commit", quantile="0.99"}
iceberg_table_size_bytes{namespace="sales", table="orders"}
iceberg_table_snapshots_total{namespace="sales", table="orders"}
```

### 15.2 Logging

**Required Logs**:
- Table creation, updates, deletions
- Schema evolution operations
- Snapshot commits
- Catalog errors

**Log Format**: Structured JSON

### 15.3 Health Checks

**Catalog Health**:
- `/health` endpoint (REST catalog)
- Database connectivity check (JDBC catalog)
- Thrift connection check (Hive Metastore)

---

## 16. Security

### 16.1 Catalog Authentication

**REST Catalog**: Bearer token or basic auth  
**JDBC Catalog**: Database username/password  
**Hive Metastore**: Kerberos or simple auth  
**AWS Glue**: IAM roles or access keys

### 16.2 Authorization

**Table-Level Access Control**:
- Read permissions
- Write permissions
- Admin permissions (schema changes, table drops)

**Implementation**:
- Catalog-level authorization (if supported)
- Query engine authorization (Trino, Spark)

### 16.3 Encryption

**Metadata Encryption**:
- At rest: Encrypted via object storage (S3 SSE)
- In transit: TLS for catalog communication

**Data Encryption**:
- At rest: Encrypted via object storage
- In transit: TLS for S3 access

---

## 17. Configuration Schema

### 17.1 Complete Configuration Example (REST Catalog)

```yaml
iceberg:
  catalog:
    type: rest
    uri: http://iceberg-catalog.lakehouse-platform.svc.cluster.local:8181
    warehouse: s3://lakehouse/
    credential: ${ICEBERG_CATALOG_TOKEN}
    
  # Object storage configuration (references object-storage contract)
  io:
    s3:
      endpoint: http://minio.lakehouse-platform.svc.cluster.local:9000
      access_key_id: ${S3_ACCESS_KEY}
      secret_access_key: ${S3_SECRET_KEY}
      path_style_access: true
```

### 17.2 Complete Configuration Example (JDBC Catalog)

```yaml
iceberg:
  catalog:
    type: jdbc
    uri: jdbc:postgresql://postgres.lakehouse-platform.svc.cluster.local:5432/iceberg
    warehouse: s3://lakehouse/
    jdbc:
      username: ${JDBC_USERNAME}
      password: ${JDBC_PASSWORD}
      driver: org.postgresql.Driver
      
  io:
    s3:
      endpoint: http://minio.lakehouse-platform.svc.cluster.local:9000
      access_key_id: ${S3_ACCESS_KEY}
      secret_access_key: ${S3_SECRET_KEY}
      path_style_access: true
```

---

## 18. Migration and Portability

### 18.1 Catalog Migration

**From REST to JDBC**:
1. Export table metadata from REST catalog
2. Initialize JDBC catalog schema
3. Import table metadata to JDBC catalog
4. Update configuration
5. No data movement required (metadata only)

**From JDBC to AWS Glue**:
1. Export table metadata from JDBC
2. Register tables in AWS Glue
3. Update configuration
4. No data movement required

### 18.2 Portability Validation

**Test**: Application must work with:
- REST catalog (local)
- JDBC catalog (PostgreSQL)
- AWS Glue (cloud)

Without changing application code (configuration only).

---

## 19. Compliance Rules

### 19.1 Contract Stability

Once published, this contract cannot be broken without:
- Major version bump
- Migration guide
- Backward compatibility period

### 19.2 Validation Checklist

An Iceberg catalog implementation is compliant if:
- ✅ Supports Apache Iceberg Table Format v2
- ✅ Catalog backend is configurable (REST/JDBC/Hive/Glue)
- ✅ All data access via Iceberg APIs only
- ✅ No direct object path access
- ✅ Warehouse location configurable
- ✅ DNS-based catalog endpoints (no hardcoded IPs)
- ✅ Credentials injectable via environment variables

### 19.3 Automatic Failure Conditions

**Contract is violated if**:
- Direct S3 path access bypassing Iceberg metadata
- Hardcoded catalog type in application code
- Hardcoded warehouse location
- Catalog endpoint with hardcoded IP address

---

## 20. Default Implementation

**Default Catalog**: REST Catalog (Iceberg REST Catalog reference implementation)  
**Default Backend**: PostgreSQL (for JDBC catalog)  
**Alternatives**: JDBC (MySQL), Hive Metastore, AWS Glue, Nessie

**Switching catalog backends must require only configuration changes, no code changes.**

---

## 21. References

- Apache Iceberg Documentation: https://iceberg.apache.org/docs/latest/
- Iceberg Table Spec: https://iceberg.apache.org/spec/
- Iceberg REST Catalog API: https://github.com/apache/iceberg/blob/main/open-api/rest-catalog-open-api.yaml
- Iceberg JDBC Catalog: https://iceberg.apache.org/docs/latest/jdbc/
- Iceberg AWS Glue: https://iceberg.apache.org/docs/latest/aws/
