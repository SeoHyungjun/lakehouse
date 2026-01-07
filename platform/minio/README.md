# MinIO Helm Chart

S3-compatible object storage for the Lakehouse platform.

## Overview

This Helm chart deploys MinIO as the default object storage backend for the Lakehouse architecture. MinIO provides S3-compatible API access, enabling seamless migration to cloud-based object storage (AWS S3, Azure Blob, GCS) without code changes.

## Contract Compliance

This chart implements the **Object Storage Contract** defined in `contracts/object-storage.md`.

**Key Contract Requirements:**
- ✅ S3-compatible API (AWS S3 API v4 signature)
- ✅ DNS-based endpoint (no hardcoded IPs)
- ✅ Access key authentication
- ✅ Configurable via environment variables
- ✅ Path-style access support
- ✅ Prometheus metrics endpoint
- ✅ Health check endpoints

## Architecture

### Deployment Modes

**Standalone Mode** (Development):
- Single MinIO instance
- Single persistent volume
- Suitable for dev/test environments

**Distributed Mode** (Production):
- Multiple MinIO instances (4+ nodes)
- Erasure coding for data protection
- High availability and fault tolerance

### Components

1. **MinIO Server**: S3-compatible object storage server
2. **Persistent Storage**: PVC for data persistence
3. **Service**: ClusterIP service for internal access
4. **Ingress** (optional): External access via ingress controller

## Prerequisites

- Kubernetes 1.28+
- Helm 3.x
- Persistent Volume provisioner (for persistent storage)
- 10Gi+ available storage (dev), 100Gi+ (prod)

## Installation

### 1. Update Dependencies

```bash
cd platform/minio
helm dependency update
```

This will download the upstream MinIO chart (v5.0.14) from https://charts.min.io/.

### 2. Install Chart

**Development Environment:**
```bash
helm install minio . \
  -n lakehouse \
  --create-namespace \
  --values ../../env/dev/minio-values.yaml
```

**Staging Environment:**
```bash
helm install minio . \
  -n lakehouse \
  --create-namespace \
  --values ../../env/staging/minio-values.yaml
```

**Production Environment:**
```bash
helm install minio . \
  -n lakehouse \
  --create-namespace \
  --values ../../env/prod/minio-values.yaml
```

### 3. Verify Installation

```bash
# Check pods are running
kubectl get pods -n lakehouse -l app=minio

# Check service
kubectl get svc -n lakehouse minio

# Check PVC
kubectl get pvc -n lakehouse -l app=minio
```

## Configuration

### Default Values

The default `values.yaml` provides baseline configuration:
- **Mode**: Standalone
- **Replicas**: 1
- **Storage**: 10Gi
- **Resources**: 512Mi memory, 250m CPU (requests)
- **Credentials**: admin/changeme123 (MUST be overridden)

### Environment-Specific Overrides

Create environment-specific values in `env/{dev,staging,prod}/minio-values.yaml`:

**Development** (`env/dev/minio-values.yaml`):
```yaml
mode: standalone
replicas: 1
persistence:
  size: 10Gi
resources:
  requests:
    memory: 512Mi
    cpu: 250m
rootUser: admin
rootPassword: dev-password-123
```

**Production** (`env/prod/minio-values.yaml`):
```yaml
mode: distributed
replicas: 4
persistence:
  size: 100Gi
  storageClass: fast-ssd
resources:
  requests:
    memory: 2Gi
    cpu: 1000m
  limits:
    memory: 4Gi
    cpu: 2000m
rootUser: ${MINIO_ROOT_USER}
rootPassword: ${MINIO_ROOT_PASSWORD}
metrics:
  serviceMonitor:
    enabled: true
```

### Key Configuration Options

| Parameter | Description | Default |
|-----------|-------------|---------|
| `mode` | Deployment mode: `standalone` or `distributed` | `standalone` |
| `replicas` | Number of MinIO instances (distributed mode) | `1` |
| `persistence.enabled` | Enable persistent storage | `true` |
| `persistence.size` | PVC size | `10Gi` |
| `persistence.storageClass` | Storage class name | `""` (default) |
| `rootUser` | MinIO root username | `admin` |
| `rootPassword` | MinIO root password | `changeme123` |
| `buckets` | List of buckets to create on startup | `[{name: lakehouse}]` |
| `service.type` | Service type | `ClusterIP` |
| `service.port` | S3 API port | `9000` |
| `service.consolePort` | Web console port | `9001` |
| `ingress.enabled` | Enable ingress | `false` |
| `metrics.serviceMonitor.enabled` | Enable Prometheus ServiceMonitor | `false` |

## Usage

### Accessing MinIO

**From within Kubernetes cluster:**
```bash
# DNS endpoint (contract-compliant)
endpoint: http://minio:9000

# Full service name
endpoint: http://minio.lakehouse.svc.cluster.local:9000
```

**From outside cluster (port-forward):**
```bash
kubectl port-forward -n lakehouse-platform svc/minio 31100:9000 &
kubectl port-forward -n lakehouse-platform svc/minio-console 31101:9001 &

# S3 API: http://localhost:31100
# Web Console: http://localhost:31101
```

### S3 Client Configuration

**Python (Boto3):**
```python
import boto3

s3_client = boto3.client(
    's3',
    endpoint_url='http://minio.lakehouse.svc.cluster.local:9000',
    aws_access_key_id='admin',
    aws_secret_access_key='changeme123',
    region_name='us-east-1'
)

# List buckets
response = s3_client.list_buckets()
print(response['Buckets'])
```

**MinIO Client (mc):**
```bash
# Configure alias
mc alias set lakehouse http://localhost:9000 admin changeme123

# List buckets
mc ls lakehouse

# Create bucket
mc mb lakehouse/my-bucket

# Upload file
mc cp myfile.txt lakehouse/my-bucket/
```

**AWS CLI:**
```bash
aws s3 ls \
  --endpoint-url http://localhost:9000 \
  --profile minio

# Configure profile in ~/.aws/credentials
[minio]
aws_access_key_id = admin
aws_secret_access_key = changeme123
```

### Bucket Management

Buckets can be created automatically on startup:

```yaml
buckets:
  - name: lakehouse-dev-raw
    policy: none
    purge: false
  - name: lakehouse-dev-warehouse
    policy: none
    purge: false
  - name: lakehouse-dev-temp
    policy: none
    purge: false
```

## Monitoring

### Metrics

MinIO exposes Prometheus metrics at `/minio/v2/metrics/cluster`.

**Enable ServiceMonitor:**
```yaml
metrics:
  serviceMonitor:
    enabled: true
```

**Key Metrics:**
- `minio_s3_requests_total`: Total S3 requests
- `minio_s3_errors_total`: Total S3 errors
- `minio_s3_traffic_sent_bytes`: Bytes sent
- `minio_s3_traffic_received_bytes`: Bytes received
- `minio_cluster_capacity_usable_total_bytes`: Total usable capacity
- `minio_cluster_capacity_usable_free_bytes`: Free capacity

### Health Checks

**Liveness Probe:**
```bash
curl http://minio:9000/minio/health/live
```

**Readiness Probe:**
```bash
curl http://minio:9000/minio/health/ready
```

### Logs

```bash
# View MinIO logs
kubectl logs -n lakehouse -l app=minio -f

# View specific pod
kubectl logs -n lakehouse minio-0 -f
```

## Security

### Credentials Management

**DO NOT** commit credentials to Git. Use one of:

1. **Kubernetes Secrets:**
```bash
kubectl create secret generic minio-credentials \
  -n lakehouse \
  --from-literal=rootUser=admin \
  --from-literal=rootPassword=secure-password
```

2. **Environment Variables:**
```yaml
rootUser: ${MINIO_ROOT_USER}
rootPassword: ${MINIO_ROOT_PASSWORD}
```

3. **External Secrets Manager:**
```yaml
# Use External Secrets Operator
externalSecrets:
  enabled: true
  secretStore: vault
  secretPath: /lakehouse/minio
```

### TLS Configuration

**Enable TLS for production:**
```yaml
tls:
  enabled: true
  certSecret: minio-tls-cert
```

Create TLS secret:
```bash
kubectl create secret tls minio-tls-cert \
  -n lakehouse \
  --cert=tls.crt \
  --key=tls.key
```

## Troubleshooting

### Pod Not Starting

```bash
# Check pod status
kubectl describe pod -n lakehouse minio-0

# Check events
kubectl get events -n lakehouse --sort-by='.lastTimestamp'

# Check PVC
kubectl get pvc -n lakehouse
```

**Common Issues:**
- Insufficient storage: Increase PVC size or provision more storage
- Resource limits: Adjust CPU/memory requests/limits
- Image pull errors: Check network connectivity

### Connection Refused

```bash
# Check service
kubectl get svc -n lakehouse minio

# Test connectivity from within cluster
kubectl run -it --rm debug --image=busybox --restart=Never -n lakehouse -- sh
wget -O- http://minio:9000/minio/health/live
```

### Bucket Not Created

```bash
# Check MinIO logs
kubectl logs -n lakehouse minio-0 | grep -i bucket

# Manually create bucket via mc
mc mb lakehouse/my-bucket
```

### Performance Issues

```bash
# Check resource usage
kubectl top pod -n lakehouse minio-0

# Check disk I/O
kubectl exec -n lakehouse minio-0 -- df -h

# Enable debug logging
kubectl set env deployment/minio -n lakehouse MINIO_LOG_LEVEL=debug
```

## Upgrade

### Upgrade Chart

```bash
# Update dependencies
helm dependency update

# Upgrade release
helm upgrade minio . -n lakehouse \
  --values ../../env/prod/minio-values.yaml
```

### Rollback

```bash
# View history
helm history minio -n lakehouse

# Rollback to previous version
helm rollback minio -n lakehouse
```

## Uninstall

```bash
# Uninstall chart
helm uninstall minio -n lakehouse

# Delete PVCs (WARNING: This deletes all data!)
kubectl delete pvc -n lakehouse -l app=minio
```

## Contract Validation

### Verification Checklist

✅ **S3 API Compatibility:**
```bash
# Test S3 operations
aws s3 ls --endpoint-url http://localhost:9000
aws s3 mb s3://test-bucket --endpoint-url http://localhost:9000
aws s3 cp test.txt s3://test-bucket/ --endpoint-url http://localhost:9000
```

✅ **DNS-Based Endpoint:**
```bash
# Verify no hardcoded IPs
grep -r "192\.168\|10\.\|172\." values.yaml
# Should return empty
```

✅ **Metrics Endpoint:**
```bash
curl http://localhost:9000/minio/v2/metrics/cluster
```

✅ **Health Checks:**
```bash
curl http://localhost:9000/minio/health/live
curl http://localhost:9000/minio/health/ready
```

## Migration Path

### From MinIO to AWS S3

1. Update endpoint configuration:
```yaml
object_storage:
  endpoint: https://s3.us-east-1.amazonaws.com
  region: us-east-1
  path_style: false
  access_key_id: ${AWS_ACCESS_KEY_ID}
  secret_access_key: ${AWS_SECRET_ACCESS_KEY}
```

2. No code changes required (S3-compatible API)

### From MinIO to Azure Blob

1. Enable Azure Blob S3-compatible API
2. Update endpoint:
```yaml
object_storage:
  endpoint: https://${ACCOUNT}.blob.core.windows.net
  access_key_id: ${AZURE_STORAGE_ACCOUNT}
  secret_access_key: ${AZURE_STORAGE_KEY}
```

## References

- [MinIO Documentation](https://min.io/docs/)
- [MinIO Helm Chart](https://github.com/minio/minio/tree/master/helm/minio)
- [S3 API Reference](https://docs.aws.amazon.com/s3/)
- [Object Storage Contract](../../contracts/object-storage.md)

## Support

For issues specific to this chart, check:
1. MinIO logs: `kubectl logs -n lakehouse -l app=minio`
2. Helm release status: `helm status minio -n lakehouse`
3. Contract compliance: `contracts/object-storage.md`
