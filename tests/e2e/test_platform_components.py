"""
Platform Component Tests

Tests for platform component health and connectivity:
- MinIO (Object Storage)
- Iceberg Catalog
- Trino (Query Engine)
- Sample Service
- Observability (Prometheus/Grafana)
"""

import pytest
import requests
from minio import Minio
from conftest import (
    MINIO_ENDPOINT,
    TRINO_ENDPOINT,
    ICEBERG_CATALOG_URI,
    SAMPLE_SERVICE_URL,
)


@pytest.mark.platform
class TestMinIO:
    """MinIO (Object Storage) tests"""
    
    def test_minio_health(self, minio_client: Minio):
        """Test MinIO health endpoint"""
        # MinIO doesn't have a standard health endpoint, but we can test bucket listing
        try:
            buckets = minio_client.list_buckets()
            assert buckets is not None
        except Exception as e:
            pytest.fail(f"MinIO health check failed: {e}")
    
    def test_minio_bucket_operations(self, minio_client: Minio):
        """Test MinIO bucket create/list/delete operations"""
        test_bucket = "test-health-bucket"
        
        # Create bucket
        if not minio_client.bucket_exists(test_bucket):
            minio_client.make_bucket(test_bucket)
        
        # Verify bucket exists
        assert minio_client.bucket_exists(test_bucket)
        
        # List buckets
        buckets = minio_client.list_buckets()
        bucket_names = [b.name for b in buckets]
        assert test_bucket in bucket_names
        
        # Cleanup
        minio_client.remove_bucket(test_bucket)
    
    def test_minio_object_operations(self, minio_client: Minio, test_bucket: str):
        """Test MinIO object put/get/delete operations"""
        object_name = "test-object.txt"
        content = b"Hello, Lakehouse!"
        
        # Put object
        from io import BytesIO
        minio_client.put_object(
            test_bucket,
            object_name,
            BytesIO(content),
            len(content)
        )
        
        # Get object
        response = minio_client.get_object(test_bucket, object_name)
        data = response.read()
        assert data == content
        
        # Delete object
        minio_client.remove_object(test_bucket, object_name)


@pytest.mark.platform
class TestIcebergCatalog:
    """Iceberg Catalog tests"""
    
    def test_iceberg_health(self, iceberg_session: requests.Session):
        """Test Iceberg Catalog health endpoint"""
        response = iceberg_session.get(f"{ICEBERG_CATALOG_URI}/v1/config")
        assert response.status_code == 200
        
        config = response.json()
        assert 'defaults' in config or 'overrides' in config
    
    def test_iceberg_list_namespaces(self, iceberg_session: requests.Session):
        """Test Iceberg Catalog list namespaces"""
        response = iceberg_session.get(f"{ICEBERG_CATALOG_URI}/v1/namespaces")
        assert response.status_code == 200
        
        data = response.json()
        assert 'namespaces' in data
    
    def test_iceberg_create_namespace(self, iceberg_session: requests.Session):
        """Test Iceberg Catalog create namespace"""
        namespace = "test_namespace"
        
        # Create namespace
        response = iceberg_session.post(
            f"{ICEBERG_CATALOG_URI}/v1/namespaces",
            json={
                "namespace": [namespace],
                "properties": {}
            }
        )
        assert response.status_code in [200, 409]  # 200 created, 409 already exists
        
        # List namespaces
        response = iceberg_session.get(f"{ICEBERG_CATALOG_URI}/v1/namespaces")
        assert response.status_code == 200
        
        data = response.json()
        namespaces = [ns[0] if isinstance(ns, list) else ns for ns in data['namespaces']]
        assert namespace in namespaces


@pytest.mark.platform
class TestTrino:
    """Trino (Query Engine) tests"""
    
    def test_trino_health(self):
        """Test Trino health endpoint"""
        response = requests.get(f"{TRINO_ENDPOINT}/v1/info")
        assert response.status_code == 200
        
        info = response.json()
        assert 'nodeVersion' in info
        assert 'coordinator' in info
    
    def test_trino_query_execution(self, trino_session: requests.Session):
        """Test Trino query execution"""
        # Simple SELECT query
        sql = "SELECT 1 as test_value"
        
        response = trino_session.post(
            f"{TRINO_ENDPOINT}/v1/statement",
            data=sql
        )
        assert response.status_code == 200
        
        result = response.json()
        assert 'id' in result
        
        # Poll for results
        while 'nextUri' in result:
            response = trino_session.get(result['nextUri'])
            assert response.status_code == 200
            result = response.json()
        
        # Verify results
        if 'data' in result:
            assert result['data'] == [[1]]
    
    def test_trino_iceberg_catalog(self, trino_session: requests.Session):
        """Test Trino can access Iceberg catalog"""
        # Show schemas in Iceberg catalog
        sql = "SHOW SCHEMAS FROM iceberg"
        
        response = trino_session.post(
            f"{TRINO_ENDPOINT}/v1/statement",
            data=sql
        )
        assert response.status_code == 200
        
        result = response.json()
        
        # Poll for results
        while 'nextUri' in result:
            response = trino_session.get(result['nextUri'])
            assert response.status_code == 200
            result = response.json()
        
        # Should have at least 'information_schema' schema
        assert 'data' in result
        schemas = [row[0] for row in result['data']]
        assert 'information_schema' in schemas


@pytest.mark.platform
class TestSampleService:
    """Sample Service tests"""
    
    def test_service_health(self):
        """Test Sample Service health endpoint"""
        response = requests.get(f"{SAMPLE_SERVICE_URL}/health")
        assert response.status_code == 200
        
        data = response.json()
        assert data['status'] == 'ok'
        assert 'timestamp' in data
    
    def test_service_ready(self):
        """Test Sample Service readiness endpoint"""
        response = requests.get(f"{SAMPLE_SERVICE_URL}/ready")
        # May return 200 or 503 depending on dependencies
        assert response.status_code in [200, 503]
        
        data = response.json()
        assert 'status' in data
        assert 'checks' in data
    
    def test_service_metrics(self):
        """Test Sample Service metrics endpoint"""
        response = requests.get(f"{SAMPLE_SERVICE_URL}/metrics")
        assert response.status_code == 200
        
        # Verify Prometheus metrics format
        metrics_text = response.text
        assert 'http_requests_total' in metrics_text
        assert 'http_request_duration_seconds' in metrics_text


@pytest.mark.platform
@pytest.mark.slow
class TestObservability:
    """Observability stack tests"""
    
    def test_prometheus_health(self):
        """Test Prometheus health endpoint"""
        # This test requires Prometheus to be accessible
        # Skip if not available
        prometheus_url = "http://localhost:9090"
        
        try:
            response = requests.get(f"{prometheus_url}/-/healthy", timeout=5)
            assert response.status_code == 200
        except requests.exceptions.ConnectionError:
            pytest.skip("Prometheus not accessible")
    
    def test_grafana_health(self):
        """Test Grafana health endpoint"""
        # This test requires Grafana to be accessible
        # Skip if not available
        grafana_url = "http://localhost:3000"
        
        try:
            response = requests.get(f"{grafana_url}/api/health", timeout=5)
            assert response.status_code == 200
            
            data = response.json()
            assert data['database'] == 'ok'
        except requests.exceptions.ConnectionError:
            pytest.skip("Grafana not accessible")
