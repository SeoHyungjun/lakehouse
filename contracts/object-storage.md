# Object Storage Contract (S3-Compatible)

This document defines the interface contract for object storage in the Lakehouse architecture.

**Contract Version**: 1.0  
**Last Updated**: 2025-12-27

---

## 1. Purpose

Object storage provides the foundational data layer for the Lakehouse, storing raw data files, Iceberg table data, and metadata.

**Critical Principle**: All object storage access must use **S3-compatible APIs only**. No vendor-specific SDKs are allowed.

---

## 2. Interface Requirements

### 2.1 API Compatibility

**Required**: Full S3 API compatibility

**Minimum Required Operations**:
- Bucket operations: CreateBucket, DeleteBucket, ListBuckets, HeadBucket
- Object operations: PutObject, GetObject, DeleteObject, ListObjects, HeadObject
- Multipart upload: InitiateMultipartUpload, UploadPart, CompleteMultipartUpload, AbortMultipartUpload
- Metadata: GetObjectMetadata, CopyObject

**Optional but Recommended**:
- Versioning: GetBucketVersioning, PutBucketVersioning
- Lifecycle policies: GetBucketLifecycle, PutBucketLifecycle
- Object tagging: GetObjectTagging, PutObjectTagging

### 2.2 Protocol

- **Protocol**: HTTP or HTTPS
- **Default Port**: 9000 (MinIO), 443 (cloud providers)
- **API Version**: AWS S3 API v4 signature

---

## 3. Endpoint Configuration

### 3.1 DNS-Based Endpoints

**All endpoints must use DNS names, never IP addresses.**

**Internal Kubernetes Service** (default):
```yaml
endpoint: http://minio.lakehouse-platform.svc.cluster.local:9000
```

**External Service** (VM or cloud):
```yaml
endpoint: https://s3.us-east-1.amazonaws.com
endpoint: https://storage.company.internal:9000
```

### 3.2 Endpoint Format

```yaml
object_storage:
  endpoint: <protocol>://<dns-name>:<port>
  region: <region-name>  # optional, defaults to "us-east-1"
  path_style: <true|false>  # true for MinIO, false for AWS S3
```

**Path-style vs Virtual-hosted-style**:
- **Path-style**: `http://minio.example.com:9000/bucket-name/object-key`
- **Virtual-hosted**: `http://bucket-name.s3.amazonaws.com/object-key`

MinIO uses path-style by default; AWS S3 uses virtual-hosted-style.

---

## 4. Authentication

### 4.1 Access Key Authentication

**Required Method**: AWS Signature Version 4

**Credentials**:
```yaml
object_storage:
  access_key_id: <ACCESS_KEY>
  secret_access_key: <SECRET_KEY>
```

### 4.2 Credential Management

**Allowed**:
- Kubernetes Secrets
- Environment variables
- External Secrets Manager (e.g., Vault, AWS Secrets Manager)

**Forbidden**:
- Hardcoded credentials in code
- Credentials committed to Git
- Credentials in container images

### 4.3 IAM Roles (Cloud Environments)

**Optional**: For cloud-managed object storage (S3, Azure Blob, GCS)
- Use IAM roles or service accounts when available
- Fall back to access key authentication if IAM is not available

---

## 5. Bucket Naming Conventions

### 5.1 Naming Rules

**Format**: `<project>-<environment>-<purpose>`

**Examples**:
- `lakehouse-dev-raw`: Raw ingestion data (development)
- `lakehouse-prod-warehouse`: Iceberg table data (production)
- `lakehouse-staging-temp`: Temporary processing data (staging)

### 5.2 Bucket Naming Constraints

Follow S3 bucket naming rules:
- 3-63 characters
- Lowercase letters, numbers, hyphens only
- Must start and end with letter or number
- No underscores, no uppercase, no periods (for DNS compatibility)

### 5.3 Bucket Lifecycle

**Bucket creation**:
- Buckets must be created via Terraform or Helm hooks
- No manual bucket creation in production

**Bucket deletion**:
- Must be explicitly approved
- Data retention policies must be followed

---

## 6. Storage Classes and Tiers

### 6.1 Storage Class Support

**MinIO**:
- Standard (default)
- Tiering to cloud (optional)

**AWS S3**:
- STANDARD
- INTELLIGENT_TIERING
- GLACIER (for archival)

**Azure Blob**:
- Hot
- Cool
- Archive

### 6.2 Storage Class Configuration

Storage class must be configurable per bucket:
```yaml
buckets:
  - name: lakehouse-prod-warehouse
    storage_class: STANDARD
  - name: lakehouse-prod-archive
    storage_class: GLACIER
```

---

## 7. Data Organization

### 7.1 Object Key Structure

**Recommended Pattern**: `<namespace>/<table>/<partition>/<file>`

**Example**:
```
lakehouse-prod-warehouse/
  sales/
    orders/
      year=2024/
        month=12/
          data-001.parquet
          data-002.parquet
    customers/
      region=us-east/
        data-001.parquet
```

### 7.2 File Formats

**Supported**:
- Parquet (preferred for Iceberg tables)
- ORC
- Avro
- JSON (for metadata)
- CSV (for raw ingestion)

**Forbidden**:
- Proprietary formats that require vendor-specific tools

---

## 8. Performance Requirements

### 8.1 Throughput

**Minimum**:
- Read: 100 MB/s per client
- Write: 50 MB/s per client

**Production**:
- Read: 1 GB/s aggregate
- Write: 500 MB/s aggregate

### 8.2 Latency

**Target**:
- First-byte latency: < 100ms (p99)
- List operations: < 500ms (p99)

### 8.3 Concurrency

**Minimum**:
- 100 concurrent connections
- 1000 requests per second

---

## 9. Security Requirements

### 9.1 Encryption at Rest

**Required for Production**:
- Server-side encryption (SSE)
- Encryption key management via KMS or equivalent

**MinIO**: SSE-S3 or SSE-KMS  
**AWS S3**: SSE-S3, SSE-KMS, or SSE-C  
**Azure Blob**: Storage Service Encryption

### 9.2 Encryption in Transit

**Required**:
- TLS 1.2 or higher for production
- HTTP allowed for local development only

### 9.3 Access Control

**Bucket Policies**:
- Principle of least privilege
- No public read/write access unless explicitly required

**IAM Policies** (cloud):
- Service-specific IAM roles
- No wildcard permissions in production

---

## 10. Observability

### 10.1 Metrics

**Required Metrics**:
- Request count (by operation type)
- Error rate (4xx, 5xx)
- Request latency (p50, p95, p99)
- Throughput (bytes read/written)
- Active connections

**Prometheus Format**:
```
s3_requests_total{operation="GetObject", status="200"}
s3_request_duration_seconds{operation="GetObject", quantile="0.99"}
s3_bytes_transferred_total{operation="PutObject"}
```

### 10.2 Logging

**Required Logs**:
- Access logs (who accessed what, when)
- Error logs (failed requests, reasons)
- Audit logs (bucket creation, deletion, policy changes)

**Log Format**: Structured JSON

### 10.3 Health Checks

**Endpoint**: `/minio/health/live` (MinIO) or equivalent

**Health Check Operations**:
- ListBuckets (verify API is responsive)
- HeadBucket on a known bucket (verify access)

---

## 11. Backup and Disaster Recovery

### 11.1 Backup Strategy

**Required**:
- Versioning enabled for critical buckets
- Cross-region replication (for production)
- Regular backup snapshots

**Backup Frequency**:
- Development: Optional
- Staging: Daily
- Production: Continuous replication + daily snapshots

### 11.2 Recovery Objectives

**RTO** (Recovery Time Objective): < 4 hours  
**RPO** (Recovery Point Objective): < 1 hour

---

## 12. SDK and Client Libraries

### 12.1 Allowed SDKs

**S3-compatible SDKs only**:
- AWS SDK for S3 (configured with custom endpoint)
- MinIO SDK
- Boto3 (Python, with custom endpoint)
- aws-sdk-go (Go, with custom endpoint)
- AWS SDK for Java (with custom endpoint)

### 12.2 SDK Configuration

**Example (Python/Boto3)**:
```python
import boto3

s3_client = boto3.client(
    's3',
    endpoint_url='http://minio.lakehouse-platform.svc.cluster.local:9000',
    aws_access_key_id='ACCESS_KEY',
    aws_secret_access_key='SECRET_KEY',
    region_name='us-east-1'
)
```

**Example (Go)**:
```go
import "github.com/aws/aws-sdk-go/aws"
import "github.com/aws/aws-sdk-go/aws/session"
import "github.com/aws/aws-sdk-go/service/s3"

sess := session.Must(session.NewSession(&aws.Config{
    Endpoint:         aws.String("http://minio.lakehouse-platform.svc.cluster.local:9000"),
    Region:           aws.String("us-east-1"),
    S3ForcePathStyle: aws.Bool(true),
}))

s3Client := s3.New(sess)
```

### 12.3 Forbidden SDKs

**NOT ALLOWED**:
- Azure Blob Storage SDK (native)
- Google Cloud Storage SDK (native)
- Any vendor-specific SDK that doesn't support S3 API

**Exception**: If using Azure Blob or GCS, use their S3-compatible gateway or API.

---

## 13. Migration and Portability

### 13.1 Migration Path

**From MinIO to AWS S3**:
1. Update endpoint configuration
2. Update credentials
3. No code changes required

**From AWS S3 to Azure Blob**:
1. Enable Azure Blob S3-compatible API
2. Update endpoint and credentials
3. No code changes required

### 13.2 Portability Validation

**Test**: Application must work with:
- MinIO (local)
- AWS S3 (cloud)
- Azure Blob Storage (S3-compatible mode)

Without changing application code.

---

## 14. Configuration Schema

### 14.1 Complete Configuration Example

```yaml
object_storage:
  # Endpoint (required)
  endpoint: http://minio.lakehouse-platform.svc.cluster.local:9000
  
  # Region (optional, defaults to us-east-1)
  region: us-east-1
  
  # Path style (required for MinIO, optional for S3)
  path_style: true
  
  # Authentication (required)
  access_key_id: ${S3_ACCESS_KEY}
  secret_access_key: ${S3_SECRET_KEY}
  
  # TLS (optional, defaults to false for http, true for https)
  use_ssl: false
  verify_ssl: true
  
  # Buckets (optional, for reference)
  buckets:
    raw: lakehouse-dev-raw
    warehouse: lakehouse-dev-warehouse
    temp: lakehouse-dev-temp
```

### 14.2 Environment Variable Injection

```bash
export S3_ENDPOINT="http://minio.lakehouse-platform.svc.cluster.local:9000"
export S3_REGION="us-east-1"
export S3_ACCESS_KEY="minioadmin"
export S3_SECRET_KEY="minioadmin"
export S3_PATH_STYLE="true"
```

---

## 15. Compliance Rules

### 15.1 Contract Stability

Once published, this contract cannot be broken without:
- Major version bump
- Migration guide
- Backward compatibility period

### 15.2 Validation Checklist

An object storage implementation is compliant if:
- ✅ Exposes S3-compatible API
- ✅ Uses DNS-based endpoint (no hardcoded IPs)
- ✅ Supports access key authentication
- ✅ No vendor-specific SDK required
- ✅ Configuration injectable via environment variables
- ✅ Supports required S3 operations (PutObject, GetObject, ListObjects, etc.)

### 15.3 Automatic Failure Conditions

**Contract is violated if**:
- Hardcoded IP addresses in configuration
- Vendor-specific SDK usage (AWS SDK without custom endpoint, Azure native SDK, etc.)
- Direct filesystem access instead of S3 API
- Credentials hardcoded in code or committed to Git

---

## 16. Default Implementation

**Default**: MinIO  
**Alternatives**: AWS S3, Azure Blob Storage (S3-compatible), Google Cloud Storage (S3-compatible), Ceph, SeaweedFS

**Switching implementations must require only configuration changes, no code changes.**

---

## 17. References

- AWS S3 API Reference: https://docs.aws.amazon.com/s3/
- MinIO Documentation: https://min.io/docs/
- S3 API Compatibility: https://docs.min.io/docs/minio-server-limits-per-tenant.html
- Boto3 S3 Client: https://boto3.amazonaws.com/v1/documentation/api/latest/reference/services/s3.html
