# Service Module Contract

This document defines the interface contract for service modules in the Lakehouse architecture.

**Contract Version**: 1.0  
**Last Updated**: 2025-12-27

---

## 1. Purpose

Service modules provide custom application logic and APIs for the Lakehouse, such as data ingestion services, transformation services, API gateways, and custom analytics endpoints.

**Critical Principles**:
- Services must expose **stable, well-defined APIs** (REST or gRPC)
- Services must be **environment-agnostic** (container, VM, bare-metal)
- No hardcoded endpoints or credentials
- No dependency on Kubernetes APIs
- Observability is **mandatory** (logging, metrics, health checks)

---

## 2. Service Requirements

### 2.1 Execution Environment Compatibility

**Required**: Services must run identically in:
- Kubernetes Pods (default)
- Docker containers (local development)
- VM or bare-metal (systemd, direct binary)

**Forbidden**:
- Kubernetes API dependencies in service code
- Container-only assumptions (e.g., hardcoded `/var/run/secrets`)
- Environment-specific logic

### 2.2 12-Factor App Compliance

**Required Principles**:
1. **Codebase**: One codebase tracked in Git
2. **Dependencies**: Explicitly declare dependencies
3. **Config**: Store config in environment variables
4. **Backing Services**: Treat backing services as attached resources
5. **Build, Release, Run**: Strictly separate build and run stages
6. **Processes**: Execute as stateless processes
7. **Port Binding**: Export services via port binding
8. **Concurrency**: Scale out via process model
9. **Disposability**: Fast startup and graceful shutdown
10. **Dev/Prod Parity**: Keep development and production similar
11. **Logs**: Treat logs as event streams (stdout/stderr)
12. **Admin Processes**: Run admin tasks as one-off processes

---

## 3. API Interface

### 3.1 API Protocol

**Supported Protocols**:
- **REST** (HTTP/HTTPS) - Preferred for most services
- **gRPC** - For high-performance, low-latency services

**Choice Criteria**:
- REST: Public APIs, CRUD operations, human-readable
- gRPC: Internal services, streaming, high throughput

### 3.2 REST API Requirements

**HTTP Methods**:
- `GET` - Retrieve resources (idempotent)
- `POST` - Create resources
- `PUT` - Update resources (idempotent)
- `PATCH` - Partial update
- `DELETE` - Delete resources (idempotent)

**Status Codes**:
- `200 OK` - Success
- `201 Created` - Resource created
- `204 No Content` - Success with no response body
- `400 Bad Request` - Invalid request
- `401 Unauthorized` - Authentication required
- `403 Forbidden` - Insufficient permissions
- `404 Not Found` - Resource not found
- `500 Internal Server Error` - Server error
- `503 Service Unavailable` - Service temporarily unavailable

**Content Type**: `application/json` (default)

**Example REST API**:
```
GET    /api/v1/tables                  # List tables
GET    /api/v1/tables/{table_id}       # Get table details
POST   /api/v1/tables                  # Create table
PUT    /api/v1/tables/{table_id}       # Update table
DELETE /api/v1/tables/{table_id}       # Delete table
```

### 3.3 gRPC API Requirements

**Protocol Buffers**: Define service contracts in `.proto` files

**Example gRPC Service**:
```protobuf
syntax = "proto3";

package lakehouse.v1;

service TableService {
  rpc ListTables(ListTablesRequest) returns (ListTablesResponse);
  rpc GetTable(GetTableRequest) returns (Table);
  rpc CreateTable(CreateTableRequest) returns (Table);
  rpc UpdateTable(UpdateTableRequest) returns (Table);
  rpc DeleteTable(DeleteTableRequest) returns (DeleteTableResponse);
}

message ListTablesRequest {
  string namespace = 1;
  int32 page_size = 2;
  string page_token = 3;
}

message ListTablesResponse {
  repeated Table tables = 1;
  string next_page_token = 2;
}

message Table {
  string id = 1;
  string name = 2;
  string namespace = 3;
  string schema = 4;
}
```

### 3.4 API Versioning

**Required**: All APIs must be versioned

**URL Versioning** (REST):
```
/api/v1/tables
/api/v2/tables
```

**Package Versioning** (gRPC):
```protobuf
package lakehouse.v1;
package lakehouse.v2;
```

**Version Compatibility**:
- Major version changes: Breaking changes allowed
- Minor version changes: Backward compatible only
- Patch version changes: Bug fixes only

---

## 4. Health Checks (Mandatory)

### 4.1 Liveness Probe

**Endpoint**: `GET /health` or `GET /healthz`

**Purpose**: Indicates if the service is running

**Response**:
```json
{
  "status": "ok",
  "timestamp": "2024-12-27T16:58:00Z"
}
```

**Status Codes**:
- `200 OK` - Service is alive
- `503 Service Unavailable` - Service is not alive (should be restarted)

**Implementation**:
```python
@app.route('/health')
def health():
    return jsonify({"status": "ok", "timestamp": datetime.utcnow().isoformat()}), 200
```

### 4.2 Readiness Probe

**Endpoint**: `GET /ready` or `GET /readyz`

**Purpose**: Indicates if the service is ready to accept traffic

**Response**:
```json
{
  "status": "ready",
  "checks": {
    "database": "ok",
    "s3": "ok",
    "trino": "ok"
  },
  "timestamp": "2024-12-27T16:58:00Z"
}
```

**Status Codes**:
- `200 OK` - Service is ready
- `503 Service Unavailable` - Service is not ready (should not receive traffic)

**Implementation**:
```python
@app.route('/ready')
def ready():
    checks = {
        "database": check_database(),
        "s3": check_s3(),
        "trino": check_trino()
    }
    
    all_ok = all(status == "ok" for status in checks.values())
    status_code = 200 if all_ok else 503
    
    return jsonify({
        "status": "ready" if all_ok else "not_ready",
        "checks": checks,
        "timestamp": datetime.utcnow().isoformat()
    }), status_code
```

### 4.3 Startup Probe (Optional)

**Endpoint**: `GET /startup`

**Purpose**: Indicates if the service has completed initialization

**Use Case**: Services with slow startup (loading large datasets, warming caches)

---

## 5. Observability (Mandatory)

### 5.1 Structured Logging

**Required**: All logs to stdout/stderr in structured format (JSON)

**Log Levels**:
- `DEBUG` - Detailed debugging information
- `INFO` - General informational messages
- `WARN` - Warning messages (potential issues)
- `ERROR` - Error messages (failures)
- `FATAL` - Critical errors (service cannot continue)

**Log Format** (JSON):
```json
{
  "timestamp": "2024-12-27T16:58:00.123Z",
  "level": "INFO",
  "service": "ingestion-service",
  "message": "Processing batch",
  "batch_id": "batch-12345",
  "records": 1000,
  "duration_ms": 234
}
```

**Implementation** (Python):
```python
import logging
import json
from datetime import datetime

class JSONFormatter(logging.Formatter):
    def format(self, record):
        log_data = {
            "timestamp": datetime.utcnow().isoformat() + "Z",
            "level": record.levelname,
            "service": "ingestion-service",
            "message": record.getMessage(),
        }
        if hasattr(record, 'batch_id'):
            log_data['batch_id'] = record.batch_id
        return json.dumps(log_data)

handler = logging.StreamHandler()
handler.setFormatter(JSONFormatter())
logger = logging.getLogger()
logger.addHandler(handler)
logger.setLevel(logging.INFO)
```

### 5.2 Metrics (Prometheus-Compatible)

**Required**: Expose Prometheus-compatible metrics endpoint

**Endpoint**: `GET /metrics`

**Required Metrics**:
- Request count (by endpoint, method, status)
- Request duration (histogram)
- Active requests (gauge)
- Error count (by type)
- Service uptime

**Example Metrics**:
```
# HELP http_requests_total Total HTTP requests
# TYPE http_requests_total counter
http_requests_total{method="GET",endpoint="/api/v1/tables",status="200"} 1234

# HELP http_request_duration_seconds HTTP request duration
# TYPE http_request_duration_seconds histogram
http_request_duration_seconds_bucket{method="GET",endpoint="/api/v1/tables",le="0.1"} 800
http_request_duration_seconds_bucket{method="GET",endpoint="/api/v1/tables",le="0.5"} 1200
http_request_duration_seconds_bucket{method="GET",endpoint="/api/v1/tables",le="1.0"} 1230
http_request_duration_seconds_bucket{method="GET",endpoint="/api/v1/tables",le="+Inf"} 1234
http_request_duration_seconds_sum{method="GET",endpoint="/api/v1/tables"} 123.45
http_request_duration_seconds_count{method="GET",endpoint="/api/v1/tables"} 1234

# HELP http_requests_active Active HTTP requests
# TYPE http_requests_active gauge
http_requests_active 5

# HELP service_uptime_seconds Service uptime in seconds
# TYPE service_uptime_seconds counter
service_uptime_seconds 86400
```

**Implementation** (Python with prometheus_client):
```python
from prometheus_client import Counter, Histogram, Gauge, generate_latest, CONTENT_TYPE_LATEST
from flask import Response

# Define metrics
http_requests_total = Counter(
    'http_requests_total',
    'Total HTTP requests',
    ['method', 'endpoint', 'status']
)

http_request_duration = Histogram(
    'http_request_duration_seconds',
    'HTTP request duration',
    ['method', 'endpoint']
)

http_requests_active = Gauge(
    'http_requests_active',
    'Active HTTP requests'
)

@app.route('/metrics')
def metrics():
    return Response(generate_latest(), mimetype=CONTENT_TYPE_LATEST)

# Instrument endpoints
@app.before_request
def before_request():
    http_requests_active.inc()
    request.start_time = time.time()

@app.after_request
def after_request(response):
    http_requests_active.dec()
    duration = time.time() - request.start_time
    http_request_duration.labels(
        method=request.method,
        endpoint=request.endpoint
    ).observe(duration)
    http_requests_total.labels(
        method=request.method,
        endpoint=request.endpoint,
        status=response.status_code
    ).inc()
    return response
```

### 5.3 Distributed Tracing (Optional but Recommended)

**Protocol**: OpenTelemetry

**Trace Context Propagation**: W3C Trace Context headers
- `traceparent`: `00-{trace-id}-{span-id}-{flags}`
- `tracestate`: Vendor-specific state

**Implementation**: Instrument HTTP/gRPC calls with trace context

---

## 6. Configuration Management

### 6.1 Configuration Sources

**Required**: All configuration must be injectable via:
1. **Environment variables** (preferred)
2. **Configuration files** (mounted as volumes)
3. **Command-line arguments**

**Forbidden**:
- Hardcoded configuration in code
- Configuration in container images
- Configuration committed to Git (except defaults)

### 6.2 Configuration Schema

**Example** (YAML):
```yaml
service:
  name: ingestion-service
  port: 8080
  log_level: INFO

trino:
  endpoint: ${TRINO_ENDPOINT}
  catalog: iceberg
  schema: default

s3:
  endpoint: ${S3_ENDPOINT}
  access_key: ${S3_ACCESS_KEY}
  secret_key: ${S3_SECRET_KEY}
  bucket: lakehouse-dev-warehouse

iceberg:
  catalog_uri: ${ICEBERG_CATALOG_URI}
  warehouse: s3://lakehouse-dev-warehouse/
```

### 6.3 Environment Variable Naming

**Convention**: `<SERVICE>_<COMPONENT>_<PROPERTY>`

**Examples**:
- `INGESTION_SERVICE_PORT=8080`
- `TRINO_ENDPOINT=http://trino:8080`
- `S3_ACCESS_KEY=minioadmin`
- `LOG_LEVEL=INFO`

### 6.4 Secrets Management

**Allowed**:
- Kubernetes Secrets (mounted as environment variables or files)
- External Secrets Manager (Vault, AWS Secrets Manager)

**Forbidden**:
- Hardcoded secrets in code
- Secrets in container images
- Secrets committed to Git

---

## 7. Error Handling

### 7.1 Error Response Format

**REST API Error Response**:
```json
{
  "error": {
    "code": "RESOURCE_NOT_FOUND",
    "message": "Table 'sales.orders' not found",
    "details": {
      "namespace": "sales",
      "table": "orders"
    },
    "timestamp": "2024-12-27T16:58:00Z",
    "request_id": "req-12345"
  }
}
```

### 7.2 Error Codes

**Standard Error Codes**:
- `INVALID_REQUEST` - Malformed request
- `AUTHENTICATION_FAILED` - Authentication failed
- `AUTHORIZATION_FAILED` - Insufficient permissions
- `RESOURCE_NOT_FOUND` - Resource does not exist
- `RESOURCE_ALREADY_EXISTS` - Resource already exists
- `INTERNAL_ERROR` - Internal server error
- `SERVICE_UNAVAILABLE` - Service temporarily unavailable

### 7.3 Retry Guidance

**Include Retry-After Header** (for 503 responses):
```
HTTP/1.1 503 Service Unavailable
Retry-After: 60
```

---

## 8. Security

### 8.1 Authentication

**Supported Methods**:
- API keys (for service-to-service)
- JWT tokens (for user authentication)
- mTLS (for high-security environments)

**Example** (API Key):
```
GET /api/v1/tables
Authorization: Bearer <api-key>
```

**Example** (JWT):
```
GET /api/v1/tables
Authorization: Bearer <jwt-token>
```

### 8.2 Authorization

**Implement Role-Based Access Control (RBAC)**:
- Admin: Full access
- Developer: Read/write access
- Viewer: Read-only access

**Example**:
```python
from functools import wraps
from flask import request, jsonify

def require_role(role):
    def decorator(f):
        @wraps(f)
        def decorated_function(*args, **kwargs):
            token = request.headers.get('Authorization')
            user_role = verify_token(token)  # Verify JWT and extract role
            
            if user_role != role:
                return jsonify({"error": "Insufficient permissions"}), 403
            
            return f(*args, **kwargs)
        return decorated_function
    return decorator

@app.route('/api/v1/tables', methods=['POST'])
@require_role('admin')
def create_table():
    # Only admins can create tables
    pass
```

### 8.3 TLS/HTTPS

**Required for Production**: All services must support TLS

**Configuration**:
```yaml
service:
  tls:
    enabled: true
    cert_file: /etc/certs/tls.crt
    key_file: /etc/certs/tls.key
```

### 8.4 Input Validation

**Required**: Validate all user inputs

**Example**:
```python
from marshmallow import Schema, fields, ValidationError

class CreateTableSchema(Schema):
    name = fields.Str(required=True, validate=lambda x: len(x) <= 255)
    namespace = fields.Str(required=True)
    schema = fields.Dict(required=True)

@app.route('/api/v1/tables', methods=['POST'])
def create_table():
    try:
        data = CreateTableSchema().load(request.json)
    except ValidationError as e:
        return jsonify({"error": e.messages}), 400
    
    # Process valid data
    pass
```

---

## 9. Performance and Scalability

### 9.1 Stateless Design

**Required**: Services must be stateless

**No Local State**:
- No in-memory session storage
- No local file storage (use object storage)
- No local caching (use distributed cache like Redis)

**Horizontal Scaling**: Services must support multiple replicas

### 9.2 Resource Limits

**Define Resource Requests and Limits**:
```yaml
resources:
  requests:
    cpu: "500m"
    memory: "512Mi"
  limits:
    cpu: "1000m"
    memory: "1Gi"
```

### 9.3 Graceful Shutdown

**Required**: Handle SIGTERM signal gracefully

**Implementation**:
```python
import signal
import sys

def graceful_shutdown(signum, frame):
    logger.info("Received SIGTERM, shutting down gracefully")
    # Close database connections
    # Finish processing in-flight requests
    # Exit cleanly
    sys.exit(0)

signal.signal(signal.SIGTERM, graceful_shutdown)
```

---

## 10. Deployment

### 10.1 Container Image

**Dockerfile Best Practices**:
```dockerfile
# Use official base image
FROM python:3.11-slim

# Set working directory
WORKDIR /app

# Install dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY . .

# Create non-root user
RUN useradd -m -u 1000 appuser && chown -R appuser:appuser /app
USER appuser

# Expose port
EXPOSE 8080

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD curl -f http://localhost:8080/health || exit 1

# Run application
CMD ["python", "app.py"]
```

### 10.2 Helm Chart

**Required**: Package service as Helm chart

**Chart Structure**:
```
charts/ingestion-service/
  Chart.yaml
  values.yaml
  templates/
    deployment.yaml
    service.yaml
    configmap.yaml
    secret.yaml
    serviceaccount.yaml
```

### 10.3 GitOps Deployment

**Required**: Deploy via ArgoCD or Flux

**ArgoCD Application**:
```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: ingestion-service
  namespace: argocd
spec:
  project: lakehouse
  source:
    repoURL: https://github.com/company/lakehouse
    targetRevision: main
    path: services/ingestion-service/chart
  destination:
    server: https://kubernetes.default.svc
    namespace: lakehouse-services
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

---

## 11. Testing

### 11.1 Unit Tests

**Required**: Minimum 80% code coverage

**Example** (Python with pytest):
```python
def test_create_table():
    response = client.post('/api/v1/tables', json={
        "name": "orders",
        "namespace": "sales",
        "schema": {"columns": [...]}
    })
    assert response.status_code == 201
    assert response.json['name'] == 'orders'
```

### 11.2 Integration Tests

**Required**: Test integration with backing services (Trino, S3, Iceberg)

### 11.3 Health Check Tests

**Required**: Verify health endpoints

```python
def test_health_endpoint():
    response = client.get('/health')
    assert response.status_code == 200
    assert response.json['status'] == 'ok'

def test_ready_endpoint():
    response = client.get('/ready')
    assert response.status_code == 200
    assert response.json['status'] == 'ready'
```

---

## 12. Documentation

### 12.1 API Documentation

**Required**: OpenAPI (Swagger) specification for REST APIs

**Example** (OpenAPI 3.0):
```yaml
openapi: 3.0.0
info:
  title: Ingestion Service API
  version: 1.0.0
paths:
  /api/v1/tables:
    get:
      summary: List tables
      responses:
        '200':
          description: Success
          content:
            application/json:
              schema:
                type: array
                items:
                  $ref: '#/components/schemas/Table'
components:
  schemas:
    Table:
      type: object
      properties:
        id:
          type: string
        name:
          type: string
        namespace:
          type: string
```

### 12.2 README

**Required**: Service README with:
- Service description
- API endpoints
- Configuration options
- Development setup
- Deployment instructions

---

## 13. Compliance Rules

### 13.1 Contract Stability

Once published, this contract cannot be broken without:
- Major version bump
- Migration guide
- Backward compatibility period

### 13.2 Validation Checklist

A service module is compliant if:
- ✅ Exposes REST or gRPC API
- ✅ Implements `/health` and `/ready` endpoints
- ✅ Structured logging to stdout (JSON)
- ✅ Prometheus-compatible `/metrics` endpoint
- ✅ Configuration via environment variables
- ✅ No hardcoded endpoints or credentials
- ✅ No Kubernetes API dependencies
- ✅ Runs identically in container and bare-metal
- ✅ Stateless design (horizontally scalable)
- ✅ Graceful shutdown on SIGTERM

### 13.3 Automatic Failure Conditions

**Contract is violated if**:
- No health check endpoints
- No metrics endpoint
- Hardcoded credentials or endpoints
- Kubernetes API dependencies in service code
- Container-only assumptions (cannot run on bare-metal)

---

## 14. References

- 12-Factor App: https://12factor.net/
- OpenAPI Specification: https://swagger.io/specification/
- Prometheus Client Libraries: https://prometheus.io/docs/instrumenting/clientlibs/
- gRPC Documentation: https://grpc.io/docs/
- OpenTelemetry: https://opentelemetry.io/
