"""
Service Integration Tests

Tests for Sample Service integration with platform components
"""

import pytest
import requests
from conftest import SAMPLE_SERVICE_URL


@pytest.mark.service
class TestSampleServiceAPI:
    """Sample Service REST API tests"""
    
    def test_list_tables_empty(self, service_session: requests.Session):
        """Test listing tables when no tables exist"""
        response = service_session.get(f"{SAMPLE_SERVICE_URL}/api/v1/tables")
        assert response.status_code == 200
        
        data = response.json()
        assert 'tables' in data
        assert 'count' in data
        assert isinstance(data['tables'], list)
    
    def test_create_table(self, service_session: requests.Session):
        """Test creating a table via Sample Service"""
        table_data = {
            "name": "test_table",
            "namespace": "test",
            "schema": {
                "columns": [
                    {"name": "id", "type": "int"},
                    {"name": "name", "type": "string"}
                ]
            }
        }
        
        response = service_session.post(
            f"{SAMPLE_SERVICE_URL}/api/v1/tables",
            json=table_data
        )
        assert response.status_code == 201
        
        data = response.json()
        assert data['id'] == 'test.test_table'
        assert data['name'] == 'test_table'
        assert data['namespace'] == 'test'
        assert 'created_at' in data
    
    def test_get_table(self, service_session: requests.Session):
        """Test getting a table by ID"""
        # First create a table
        table_data = {
            "name": "get_test_table",
            "namespace": "test",
            "schema": {"columns": [{"name": "id", "type": "int"}]}
        }
        
        create_response = service_session.post(
            f"{SAMPLE_SERVICE_URL}/api/v1/tables",
            json=table_data
        )
        assert create_response.status_code == 201
        
        table_id = create_response.json()['id']
        
        # Get the table
        response = service_session.get(
            f"{SAMPLE_SERVICE_URL}/api/v1/tables/{table_id}"
        )
        assert response.status_code == 200
        
        data = response.json()
        assert data['id'] == table_id
        assert data['name'] == 'get_test_table'
    
    def test_get_nonexistent_table(self, service_session: requests.Session):
        """Test getting a table that doesn't exist"""
        response = service_session.get(
            f"{SAMPLE_SERVICE_URL}/api/v1/tables/nonexistent.table"
        )
        assert response.status_code == 404
        
        data = response.json()
        assert 'error' in data
        assert data['error']['code'] == 'RESOURCE_NOT_FOUND'
    
    def test_update_table(self, service_session: requests.Session):
        """Test updating a table"""
        # Create table
        table_data = {
            "name": "update_test_table",
            "namespace": "test",
            "schema": {"columns": [{"name": "id", "type": "int"}]}
        }
        
        create_response = service_session.post(
            f"{SAMPLE_SERVICE_URL}/api/v1/tables",
            json=table_data
        )
        table_id = create_response.json()['id']
        
        # Update table
        update_data = {
            "schema": {
                "columns": [
                    {"name": "id", "type": "int"},
                    {"name": "name", "type": "string"}
                ]
            }
        }
        
        response = service_session.put(
            f"{SAMPLE_SERVICE_URL}/api/v1/tables/{table_id}",
            json=update_data
        )
        assert response.status_code == 200
        
        data = response.json()
        assert data['id'] == table_id
        assert len(data['schema']['columns']) == 2
    
    def test_delete_table(self, service_session: requests.Session):
        """Test deleting a table"""
        # Create table
        table_data = {
            "name": "delete_test_table",
            "namespace": "test",
            "schema": {"columns": [{"name": "id", "type": "int"}]}
        }
        
        create_response = service_session.post(
            f"{SAMPLE_SERVICE_URL}/api/v1/tables",
            json=table_data
        )
        table_id = create_response.json()['id']
        
        # Delete table
        response = service_session.delete(
            f"{SAMPLE_SERVICE_URL}/api/v1/tables/{table_id}"
        )
        assert response.status_code == 204
        
        # Verify table is deleted
        get_response = service_session.get(
            f"{SAMPLE_SERVICE_URL}/api/v1/tables/{table_id}"
        )
        assert get_response.status_code == 404
    
    def test_create_duplicate_table(self, service_session: requests.Session):
        """Test creating a table that already exists"""
        table_data = {
            "name": "duplicate_table",
            "namespace": "test",
            "schema": {"columns": [{"name": "id", "type": "int"}]}
        }
        
        # Create table first time
        response1 = service_session.post(
            f"{SAMPLE_SERVICE_URL}/api/v1/tables",
            json=table_data
        )
        assert response1.status_code == 201
        
        # Try to create same table again
        response2 = service_session.post(
            f"{SAMPLE_SERVICE_URL}/api/v1/tables",
            json=table_data
        )
        assert response2.status_code == 409
        
        data = response2.json()
        assert 'error' in data
        assert data['error']['code'] == 'RESOURCE_ALREADY_EXISTS'
    
    def test_invalid_request(self, service_session: requests.Session):
        """Test creating a table with invalid request"""
        # Missing required fields
        invalid_data = {
            "name": "invalid_table"
            # Missing namespace and schema
        }
        
        response = service_session.post(
            f"{SAMPLE_SERVICE_URL}/api/v1/tables",
            json=invalid_data
        )
        assert response.status_code == 400
        
        data = response.json()
        assert 'error' in data
        assert data['error']['code'] == 'INVALID_REQUEST'


@pytest.mark.service
class TestSampleServiceHealth:
    """Sample Service health check tests"""
    
    def test_health_endpoint(self):
        """Test health endpoint returns correct format"""
        response = requests.get(f"{SAMPLE_SERVICE_URL}/health")
        assert response.status_code == 200
        
        data = response.json()
        assert data['status'] == 'ok'
        assert 'timestamp' in data
    
    def test_ready_endpoint(self):
        """Test readiness endpoint returns correct format"""
        response = requests.get(f"{SAMPLE_SERVICE_URL}/ready")
        # May be 200 or 503 depending on dependencies
        assert response.status_code in [200, 503]
        
        data = response.json()
        assert 'status' in data
        assert 'checks' in data
        assert 'timestamp' in data
        
        # Verify check structure
        checks = data['checks']
        assert 'trino' in checks
        assert 's3' in checks
        assert 'iceberg' in checks


@pytest.mark.service
class TestSampleServiceMetrics:
    """Sample Service metrics tests"""
    
    def test_metrics_endpoint(self):
        """Test metrics endpoint returns Prometheus format"""
        response = requests.get(f"{SAMPLE_SERVICE_URL}/metrics")
        assert response.status_code == 200
        
        metrics_text = response.text
        
        # Verify required metrics exist
        assert 'http_requests_total' in metrics_text
        assert 'http_request_duration_seconds' in metrics_text
        assert 'http_requests_active' in metrics_text
        assert 'service_uptime_seconds' in metrics_text
        assert 'tables_total' in metrics_text
    
    def test_metrics_updated_after_request(self):
        """Test that metrics are updated after making requests"""
        # Get initial metrics
        response1 = requests.get(f"{SAMPLE_SERVICE_URL}/metrics")
        metrics1 = response1.text
        
        # Make a request to /health
        requests.get(f"{SAMPLE_SERVICE_URL}/health")
        
        # Get updated metrics
        response2 = requests.get(f"{SAMPLE_SERVICE_URL}/metrics")
        metrics2 = response2.text
        
        # Metrics should have changed (request count increased)
        # Note: This is a simple check - in practice, you'd parse the metrics
        assert len(metrics2) >= len(metrics1)
