# Sample Service

A sample REST API service demonstrating compliance with the Service Module Contract.

## Overview

This service provides a simple REST API for managing tables in the Lakehouse platform. It demonstrates:

- **REST API** with versioned endpoints
- **Health checks** (`/health`, `/ready`)
- **Prometheus metrics** (`/metrics`)
- **Structured JSON logging**
- **Environment-based configuration**
- **12-Factor App compliance**
- **Container and bare-metal compatibility**

## Architecture

```
┌─────────────────────────────────────────┐
│         Sample Service                   │
├─────────────────────────────────────────┤
│                                          │
│  ┌──────────────┐   ┌──────────────┐   │
│  │  REST API    │   │  Health      │   │
│  │  /api/v1/*   │   │  /health     │   │
│  │              │   │  /ready      │   │
│  └──────────────┘   └──────────────┘   │
│                                          │
│  ┌──────────────┐   ┌──────────────┐   │
│  │  Metrics     │   │  Logging     │   │
│  │  /metrics    │   │  JSON stdout │   │
│  └──────────────┘   └──────────────┘   │
│                                          │
└─────────────────────────────────────────┘
```

## API Endpoints

### REST API

- `GET /api/v1/tables` - List all tables
- `GET /api/v1/tables/{table_id}` - Get table details
- `POST /api/v1/tables` - Create a new table
- `PUT /api/v1/tables/{table_id}` - Update a table
- `DELETE /api/v1/tables/{table_id}` - Delete a table

### Health Checks

- `GET /health` - Liveness probe (always returns 200 if service is running)
- `GET /ready` - Readiness probe (checks dependencies)

### Observability

- `GET /metrics` - Prometheus metrics endpoint

## Configuration

Configuration is provided via environment variables:

| Variable | Description | Default |
|----------|-------------|---------|
| `SERVICE_PORT` | HTTP server port | `8080` |
| `LOG_LEVEL` | Logging level (DEBUG, INFO, WARN, ERROR) | `INFO` |
| `TRINO_ENDPOINT` | Trino endpoint URL | `http://trino:8080` |
| `S3_ENDPOINT` | S3 endpoint URL | `http://minio:9000` |
| `ICEBERG_CATALOG_URI` | Iceberg catalog URI | `http://iceberg-catalog:8181` |

## Running Locally

### Prerequisites

- Python 3.11+
- pip

### Install Dependencies

```bash
cd services/sample-service
pip install -r requirements.txt
```

### Run Service

```bash
# Set environment variables
export SERVICE_PORT=8080
export LOG_LEVEL=INFO

# Run service
python app.py
```

### Test Endpoints

```bash
# Health check
curl http://localhost:8080/health

# Readiness check
curl http://localhost:8080/ready

# List tables
curl http://localhost:8080/api/v1/tables

# Create table
curl -X POST http://localhost:8080/api/v1/tables \
  -H "Content-Type: application/json" \
  -d '{"name": "orders", "namespace": "sales", "schema": {"columns": [{"name": "id", "type": "int"}]}}'

# Metrics
curl http://localhost:8080/metrics
```

## Running in Docker

### Build Image

```bash
docker build -t sample-service:latest .
```

### Run Container

```bash
docker run -p 8080:8080 \
  -e SERVICE_PORT=8080 \
  -e LOG_LEVEL=INFO \
  sample-service:latest
```

## Running with Docker Compose

```bash
docker-compose up
```

## Deployment

### Kubernetes (via Helm)

```bash
# Install chart
helm install sample-service ./chart \
  --namespace lakehouse-services \
  --create-namespace

# Upgrade chart
helm upgrade sample-service ./chart \
  --namespace lakehouse-services

# Uninstall chart
helm uninstall sample-service \
  --namespace lakehouse-services
```

### GitOps (via ArgoCD)

The service is automatically deployed via ArgoCD when changes are pushed to Git.

```bash
# Check application status
argocd app get sample-service

# Sync application
argocd app sync sample-service
```

## Development

### Running Tests

```bash
# Unit tests
pytest tests/unit/

# Integration tests
pytest tests/integration/

# All tests with coverage
pytest --cov=app --cov-report=html
```

### Code Quality

```bash
# Linting
pylint app.py

# Type checking
mypy app.py

# Formatting
black app.py
```

## Contract Compliance

This service complies with the Service Module Contract (`contracts/service-module.md`):

✅ **Execution Environment**: Runs in containers, VMs, and bare-metal  
✅ **12-Factor App**: Follows all 12 principles  
✅ **REST API**: Versioned REST API with standard HTTP methods  
✅ **Health Checks**: `/health` and `/ready` endpoints  
✅ **Structured Logging**: JSON logs to stdout  
✅ **Prometheus Metrics**: `/metrics` endpoint  
✅ **Configuration**: Environment variable-based configuration  
✅ **Error Handling**: Standard error response format  
✅ **Security**: Input validation, RBAC support  
✅ **Stateless**: No local state, horizontally scalable  
✅ **Graceful Shutdown**: Handles SIGTERM signal  
✅ **Container Image**: Multi-stage Dockerfile with non-root user  
✅ **Helm Chart**: Kubernetes deployment via Helm  
✅ **GitOps**: ArgoCD deployment support  
✅ **Testing**: Unit and integration tests  
✅ **Documentation**: OpenAPI specification and README  

## Troubleshooting

### Service Not Starting

**Problem:** Service fails to start

**Solution:**
```bash
# Check logs
docker logs <container-id>

# Or in Kubernetes
kubectl logs -n lakehouse-services deployment/sample-service
```

### Health Check Failing

**Problem:** `/ready` returns 503

**Solution:**
```bash
# Check dependency connectivity
curl http://trino:8080/v1/info
curl http://minio:9000/minio/health/live
curl http://iceberg-catalog:8181/v1/config

# Verify environment variables
env | grep -E '(TRINO|S3|ICEBERG)'
```

### Metrics Not Appearing in Prometheus

**Problem:** Prometheus not scraping metrics

**Solution:**
```bash
# Verify ServiceMonitor exists
kubectl get servicemonitor -n lakehouse-services

# Check Prometheus targets
kubectl port-forward -n lakehouse-platform svc/prometheus-operated 9090:9090
# Navigate to http://localhost:9090/targets
```

## References

- **Service Module Contract**: `../../contracts/service-module.md`
- **Platform README**: `../../platform/README.md`
- **Flask Documentation**: https://flask.palletsprojects.com/
- **Prometheus Client**: https://github.com/prometheus/client_python
- **OpenAPI Specification**: https://swagger.io/specification/
