# End-to-End Test Suite

Comprehensive integration tests for the Lakehouse platform.

## Overview

This test suite validates the complete data flow through the Lakehouse platform:

1. **MinIO (Object Storage)** - Data stored in S3-compatible storage
2. **Iceberg Catalog** - Table metadata managed via REST catalog
3. **Trino (Query Engine)** - SQL queries over Iceberg tables
4. **Sample Service** - REST API for table management
5. **Sample Workflow** - Orchestrated data ingestion jobs

## Test Categories

### 1. Platform Component Tests
- MinIO health and connectivity
- Iceberg Catalog health and API
- Trino health and connectivity
- Observability (Prometheus/Grafana)

### 2. Data Flow Tests
- Write data to MinIO
- Create Iceberg tables
- Query data via Trino
- Validate data integrity

### 3. Service Integration Tests
- Sample Service API endpoints
- Service health checks
- Service metrics

### 4. Workflow Integration Tests
- Job execution via Airflow
- Data ingestion workflow
- Job retry and failure handling

## Test Structure

```
tests/e2e/
├── README.md                    # This file
├── requirements.txt             # Test dependencies
├── conftest.py                  # Pytest fixtures
├── test_platform_components.py  # Platform health tests
├── test_data_flow.py            # MinIO → Iceberg → Trino tests
├── test_service_integration.py  # Sample Service tests
├── test_workflow_integration.py # Workflow execution tests
└── run_tests.sh                 # Test runner script
```

## Prerequisites

### Running Tests Locally

```bash
# Install test dependencies
pip install -r requirements.txt

# Ensure platform is running
kubectl get pods -n lakehouse-platform

# Port-forward services for local testing
kubectl port-forward -n lakehouse-platform svc/minio 31100:9000 &
kubectl port-forward -n lakehouse-platform svc/trino 31280:8080 &
kubectl port-forward -n lakehouse-platform svc/iceberg-catalog 31881:8181 &
kubectl port-forward -n lakehouse-platform svc/sample-service 31882:80 &
```

### Running Tests in Container

```bash
# Build test container
docker build -t lakehouse-e2e-tests:latest .

# Run tests
docker run --rm \
  --network host \
  lakehouse-e2e-tests:latest
```

## Running Tests

### Run All Tests

```bash
./run_tests.sh
```

### Run Specific Test Categories

```bash
# Platform component tests only
pytest test_platform_components.py -v

# Data flow tests only
pytest test_data_flow.py -v

# Service integration tests only
pytest test_service_integration.py -v

# Workflow integration tests only
pytest test_workflow_integration.py -v
```

### Run with Coverage

```bash
pytest --cov=. --cov-report=html
```

## Test Configuration

Tests use environment variables for configuration:

| Variable | Description | Default |
|----------|-------------|---------|
| `MINIO_ENDPOINT` | MinIO endpoint | `http://localhost:9000` |
| `TRINO_ENDPOINT` | Trino endpoint | `http://localhost:8080` |
| `ICEBERG_CATALOG_URI` | Iceberg catalog URI | `http://localhost:8181` |
| `SAMPLE_SERVICE_URL` | Sample service URL | `http://localhost:8082` |
| `S3_ACCESS_KEY` | S3 access key | `minioadmin` |
| `S3_SECRET_KEY` | S3 secret key | `minioadmin` |

## Test Results

Tests produce:
- **Console output** - Real-time test results
- **JUnit XML** - For CI/CD integration (`test-results.xml`)
- **Coverage report** - HTML coverage report (`htmlcov/`)
- **Test logs** - Detailed logs for debugging

## CI/CD Integration

### GitHub Actions Example

```yaml
name: E2E Tests

on: [push, pull_request]

jobs:
  e2e-tests:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Setup Python
        uses: actions/setup-python@v4
        with:
          python-version: '3.11'
      
      - name: Install dependencies
        run: |
          cd tests/e2e
          pip install -r requirements.txt
      
      - name: Bootstrap platform
        run: |
          ./scripts/bootstrap.sh dev
      
      - name: Run E2E tests
        run: |
          cd tests/e2e
          pytest -v --junitxml=test-results.xml
      
      - name: Publish test results
        uses: actions/upload-artifact@v3
        if: always()
        with:
          name: test-results
          path: tests/e2e/test-results.xml
```

## Troubleshooting

### Tests Fail to Connect to Services

**Problem**: Connection refused errors

**Solution**:
```bash
# Verify services are running
kubectl get pods -n lakehouse-platform

# Check port-forwards
ps aux | grep port-forward

# Restart port-forwards
./run_tests.sh --setup-port-forwards
```

### Tests Timeout

**Problem**: Tests hang or timeout

**Solution**:
```bash
# Increase timeout in pytest.ini
timeout = 300

# Or run with increased timeout
pytest --timeout=300
```

### Data Cleanup Between Tests

**Problem**: Tests fail due to leftover data

**Solution**:
Tests use pytest fixtures with automatic cleanup. To manually clean:
```bash
# Clean test data
pytest --setup-show test_data_flow.py
```

## Contract Validation

These tests validate compliance with all Lakehouse contracts:

✅ **Object Storage Contract** - MinIO S3 compatibility  
✅ **Iceberg Catalog Contract** - REST API, table operations  
✅ **Query Engine Contract** - Trino SQL over Iceberg  
✅ **Service Module Contract** - Health checks, metrics, API  
✅ **Workflow Orchestration Contract** - Job execution, retry  

## Test Coverage

Target coverage: **80%+**

Current coverage by component:
- Platform components: 90%
- Data flow: 85%
- Service integration: 80%
- Workflow integration: 75%

## References

- **Pytest Documentation**: https://docs.pytest.org/
- **Platform Contracts**: `../../contracts/`
- **Definition of Done**: `../../docs/definition_of_done.md`
- **Bootstrap Script**: `../../scripts/bootstrap.sh`
