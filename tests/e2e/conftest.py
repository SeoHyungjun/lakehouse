"""
Pytest configuration and fixtures for E2E tests
"""

import os
import pytest
import requests
from minio import Minio
from typing import Generator

# ============================================================================
# Test Configuration
# ============================================================================

# Service endpoints
MINIO_ENDPOINT = os.getenv('MINIO_ENDPOINT', 'localhost:9000')
TRINO_ENDPOINT = os.getenv('TRINO_ENDPOINT', 'http://localhost:8080')
ICEBERG_CATALOG_URI = os.getenv('ICEBERG_CATALOG_URI', 'http://localhost:8181')
SAMPLE_SERVICE_URL = os.getenv('SAMPLE_SERVICE_URL', 'http://localhost:8082')

# S3 credentials
S3_ACCESS_KEY = os.getenv('S3_ACCESS_KEY', 'minioadmin')
S3_SECRET_KEY = os.getenv('S3_SECRET_KEY', 'minioadmin')

# Test configuration
TEST_BUCKET = 'test-bucket'
TEST_NAMESPACE = 'test'
TEST_TABLE_PREFIX = 'test_table_'


# ============================================================================
# Fixtures
# ============================================================================

@pytest.fixture(scope='session')
def minio_client() -> Generator[Minio, None, None]:
    """
    MinIO client fixture
    
    Provides a configured MinIO client for tests
    """
    client = Minio(
        MINIO_ENDPOINT,
        access_key=S3_ACCESS_KEY,
        secret_key=S3_SECRET_KEY,
        secure=False
    )
    
    yield client


@pytest.fixture(scope='session')
def trino_session() -> Generator[requests.Session, None, None]:
    """
    Trino session fixture
    
    Provides a configured requests session for Trino queries
    """
    session = requests.Session()
    session.headers.update({
        'X-Trino-User': 'test-user',
        'X-Trino-Catalog': 'iceberg',
        'X-Trino-Schema': TEST_NAMESPACE,
    })
    
    yield session
    
    session.close()


@pytest.fixture(scope='session')
def iceberg_session() -> Generator[requests.Session, None, None]:
    """
    Iceberg Catalog session fixture
    
    Provides a configured requests session for Iceberg Catalog API
    """
    session = requests.Session()
    session.headers.update({
        'Content-Type': 'application/json',
    })
    
    yield session
    
    session.close()


@pytest.fixture(scope='session')
def service_session() -> Generator[requests.Session, None, None]:
    """
    Sample Service session fixture
    
    Provides a configured requests session for Sample Service API
    """
    session = requests.Session()
    session.headers.update({
        'Content-Type': 'application/json',
    })
    
    yield session
    
    session.close()


@pytest.fixture(scope='function')
def test_bucket(minio_client: Minio) -> Generator[str, None, None]:
    """
    Test bucket fixture
    
    Creates a test bucket and cleans it up after the test
    """
    bucket_name = TEST_BUCKET
    
    # Create bucket if it doesn't exist
    if not minio_client.bucket_exists(bucket_name):
        minio_client.make_bucket(bucket_name)
    
    yield bucket_name
    
    # Cleanup: Remove all objects in bucket
    try:
        objects = minio_client.list_objects(bucket_name, recursive=True)
        for obj in objects:
            minio_client.remove_object(bucket_name, obj.object_name)
    except Exception:
        pass  # Ignore cleanup errors


@pytest.fixture(scope='function')
def test_table_name() -> str:
    """
    Test table name fixture
    
    Generates a unique table name for each test
    """
    import uuid
    return f"{TEST_TABLE_PREFIX}{uuid.uuid4().hex[:8]}"


@pytest.fixture(scope='function')
def cleanup_table(trino_session: requests.Session, test_table_name: str) -> Generator[None, None, None]:
    """
    Cleanup table fixture
    
    Drops the test table after the test completes
    """
    yield
    
    # Cleanup: Drop table
    try:
        drop_sql = f"DROP TABLE IF EXISTS iceberg.{TEST_NAMESPACE}.{test_table_name}"
        response = trino_session.post(
            f"{TRINO_ENDPOINT}/v1/statement",
            data=drop_sql
        )
        response.raise_for_status()
    except Exception:
        pass  # Ignore cleanup errors


# ============================================================================
# Pytest Configuration
# ============================================================================

def pytest_configure(config):
    """
    Pytest configuration hook
    """
    # Add custom markers
    config.addinivalue_line(
        "markers", "platform: mark test as platform component test"
    )
    config.addinivalue_line(
        "markers", "dataflow: mark test as data flow test"
    )
    config.addinivalue_line(
        "markers", "service: mark test as service integration test"
    )
    config.addinivalue_line(
        "markers", "workflow: mark test as workflow integration test"
    )
    config.addinivalue_line(
        "markers", "slow: mark test as slow running"
    )


def pytest_collection_modifyitems(config, items):
    """
    Modify test collection
    """
    # Add timeout marker to all tests
    for item in items:
        if 'timeout' not in item.keywords:
            item.add_marker(pytest.mark.timeout(60))  # 60 second default timeout
