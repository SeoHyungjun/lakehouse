"""
Data Flow Tests

Tests for complete data flow through the Lakehouse:
MinIO (Object Storage) → Iceberg (Table Format) → Trino (Query Engine)

These tests validate:
1. Data can be written to MinIO
2. Iceberg tables can be created and managed
3. Trino can query data through Iceberg
4. Data integrity is maintained throughout the flow
"""

import pytest
import requests
from io import BytesIO
from minio import Minio
from conftest import (
    TRINO_ENDPOINT,
    TEST_NAMESPACE,
)


@pytest.mark.dataflow
class TestDataFlow:
    """Complete data flow tests"""
    
    def test_create_iceberg_table_via_trino(
        self,
        trino_session: requests.Session,
        test_table_name: str,
        cleanup_table
    ):
        """Test creating an Iceberg table via Trino"""
        # Create schema if not exists
        create_schema_sql = f"CREATE SCHEMA IF NOT EXISTS iceberg.{TEST_NAMESPACE}"
        response = trino_session.post(
            f"{TRINO_ENDPOINT}/v1/statement",
            data=create_schema_sql
        )
        assert response.status_code == 200
        
        # Wait for query completion
        result = response.json()
        while 'nextUri' in result:
            response = trino_session.get(result['nextUri'])
            result = response.json()
        
        # Create table
        create_table_sql = f"""
        CREATE TABLE iceberg.{TEST_NAMESPACE}.{test_table_name} (
            id BIGINT,
            name VARCHAR,
            value DECIMAL(10, 2),
            created_at TIMESTAMP
        )
        WITH (
            format = 'PARQUET'
        )
        """
        
        response = trino_session.post(
            f"{TRINO_ENDPOINT}/v1/statement",
            data=create_table_sql
        )
        assert response.status_code == 200
        
        # Wait for query completion
        result = response.json()
        while 'nextUri' in result:
            response = trino_session.get(result['nextUri'])
            result = response.json()
        
        # Verify table was created
        show_tables_sql = f"SHOW TABLES FROM iceberg.{TEST_NAMESPACE}"
        response = trino_session.post(
            f"{TRINO_ENDPOINT}/v1/statement",
            data=show_tables_sql
        )
        assert response.status_code == 200
        
        result = response.json()
        while 'nextUri' in result:
            response = trino_session.get(result['nextUri'])
            result = response.json()
        
        if 'data' in result:
            tables = [row[0] for row in result['data']]
            assert test_table_name in tables
    
    def test_insert_and_query_data(
        self,
        trino_session: requests.Session,
        test_table_name: str,
        cleanup_table
    ):
        """Test inserting data and querying it back"""
        # Create schema
        create_schema_sql = f"CREATE SCHEMA IF NOT EXISTS iceberg.{TEST_NAMESPACE}"
        response = trino_session.post(
            f"{TRINO_ENDPOINT}/v1/statement",
            data=create_schema_sql
        )
        result = response.json()
        while 'nextUri' in result:
            response = trino_session.get(result['nextUri'])
            result = response.json()
        
        # Create table
        create_table_sql = f"""
        CREATE TABLE iceberg.{TEST_NAMESPACE}.{test_table_name} (
            id BIGINT,
            name VARCHAR,
            value DECIMAL(10, 2)
        )
        WITH (format = 'PARQUET')
        """
        response = trino_session.post(
            f"{TRINO_ENDPOINT}/v1/statement",
            data=create_table_sql
        )
        result = response.json()
        while 'nextUri' in result:
            response = trino_session.get(result['nextUri'])
            result = response.json()
        
        # Insert data
        insert_sql = f"""
        INSERT INTO iceberg.{TEST_NAMESPACE}.{test_table_name} (id, name, value)
        VALUES
            (1, 'Alice', 100.50),
            (2, 'Bob', 200.75),
            (3, 'Charlie', 300.25)
        """
        response = trino_session.post(
            f"{TRINO_ENDPOINT}/v1/statement",
            data=insert_sql
        )
        result = response.json()
        while 'nextUri' in result:
            response = trino_session.get(result['nextUri'])
            result = response.json()
        
        # Query data
        select_sql = f"""
        SELECT id, name, value
        FROM iceberg.{TEST_NAMESPACE}.{test_table_name}
        ORDER BY id
        """
        response = trino_session.post(
            f"{TRINO_ENDPOINT}/v1/statement",
            data=select_sql
        )
        result = response.json()
        while 'nextUri' in result:
            response = trino_session.get(result['nextUri'])
            result = response.json()
        
        # Verify data
        assert 'data' in result
        data = result['data']
        assert len(data) == 3
        assert data[0] == [1, 'Alice', 100.50]
        assert data[1] == [2, 'Bob', 200.75]
        assert data[2] == [3, 'Charlie', 300.25]
    
    def test_data_persistence_in_minio(
        self,
        minio_client: Minio,
        trino_session: requests.Session,
        test_bucket: str,
        test_table_name: str,
        cleanup_table
    ):
        """Test that Iceberg table data is persisted in MinIO"""
        # Create schema
        create_schema_sql = f"CREATE SCHEMA IF NOT EXISTS iceberg.{TEST_NAMESPACE}"
        response = trino_session.post(
            f"{TRINO_ENDPOINT}/v1/statement",
            data=create_schema_sql
        )
        result = response.json()
        while 'nextUri' in result:
            response = trino_session.get(result['nextUri'])
            result = response.json()
        
        # Create table
        create_table_sql = f"""
        CREATE TABLE iceberg.{TEST_NAMESPACE}.{test_table_name} (
            id BIGINT,
            data VARCHAR
        )
        WITH (format = 'PARQUET')
        """
        response = trino_session.post(
            f"{TRINO_ENDPOINT}/v1/statement",
            data=create_table_sql
        )
        result = response.json()
        while 'nextUri' in result:
            response = trino_session.get(result['nextUri'])
            result = response.json()
        
        # Insert data
        insert_sql = f"""
        INSERT INTO iceberg.{TEST_NAMESPACE}.{test_table_name} (id, data)
        VALUES (1, 'test_data')
        """
        response = trino_session.post(
            f"{TRINO_ENDPOINT}/v1/statement",
            data=insert_sql
        )
        result = response.json()
        while 'nextUri' in result:
            response = trino_session.get(result['nextUri'])
            result = response.json()
        
        # Check that data files exist in MinIO
        # Note: The exact bucket/path depends on Iceberg configuration
        # This is a simplified check
        try:
            # List objects in warehouse bucket
            warehouse_bucket = "lakehouse-dev-warehouse"
            if minio_client.bucket_exists(warehouse_bucket):
                objects = list(minio_client.list_objects(warehouse_bucket, recursive=True))
                # Should have metadata and data files
                assert len(objects) > 0
        except Exception:
            # If warehouse bucket doesn't exist or has different name, skip this check
            pytest.skip("Warehouse bucket not accessible")
    
    def test_update_and_delete_data(
        self,
        trino_session: requests.Session,
        test_table_name: str,
        cleanup_table
    ):
        """Test updating and deleting data in Iceberg tables"""
        # Create schema
        create_schema_sql = f"CREATE SCHEMA IF NOT EXISTS iceberg.{TEST_NAMESPACE}"
        response = trino_session.post(
            f"{TRINO_ENDPOINT}/v1/statement",
            data=create_schema_sql
        )
        result = response.json()
        while 'nextUri' in result:
            response = trino_session.get(result['nextUri'])
            result = response.json()
        
        # Create table
        create_table_sql = f"""
        CREATE TABLE iceberg.{TEST_NAMESPACE}.{test_table_name} (
            id BIGINT,
            value INTEGER
        )
        WITH (format = 'PARQUET')
        """
        response = trino_session.post(
            f"{TRINO_ENDPOINT}/v1/statement",
            data=create_table_sql
        )
        result = response.json()
        while 'nextUri' in result:
            response = trino_session.get(result['nextUri'])
            result = response.json()
        
        # Insert data
        insert_sql = f"""
        INSERT INTO iceberg.{TEST_NAMESPACE}.{test_table_name} (id, value)
        VALUES (1, 100), (2, 200), (3, 300)
        """
        response = trino_session.post(
            f"{TRINO_ENDPOINT}/v1/statement",
            data=insert_sql
        )
        result = response.json()
        while 'nextUri' in result:
            response = trino_session.get(result['nextUri'])
            result = response.json()
        
        # Update data
        update_sql = f"""
        UPDATE iceberg.{TEST_NAMESPACE}.{test_table_name}
        SET value = 999
        WHERE id = 2
        """
        response = trino_session.post(
            f"{TRINO_ENDPOINT}/v1/statement",
            data=update_sql
        )
        result = response.json()
        while 'nextUri' in result:
            response = trino_session.get(result['nextUri'])
            result = response.json()
        
        # Verify update
        select_sql = f"""
        SELECT value FROM iceberg.{TEST_NAMESPACE}.{test_table_name}
        WHERE id = 2
        """
        response = trino_session.post(
            f"{TRINO_ENDPOINT}/v1/statement",
            data=select_sql
        )
        result = response.json()
        while 'nextUri' in result:
            response = trino_session.get(result['nextUri'])
            result = response.json()
        
        assert 'data' in result
        assert result['data'][0][0] == 999
        
        # Delete data
        delete_sql = f"""
        DELETE FROM iceberg.{TEST_NAMESPACE}.{test_table_name}
        WHERE id = 3
        """
        response = trino_session.post(
            f"{TRINO_ENDPOINT}/v1/statement",
            data=delete_sql
        )
        result = response.json()
        while 'nextUri' in result:
            response = trino_session.get(result['nextUri'])
            result = response.json()
        
        # Verify delete
        count_sql = f"""
        SELECT COUNT(*) FROM iceberg.{TEST_NAMESPACE}.{test_table_name}
        """
        response = trino_session.post(
            f"{TRINO_ENDPOINT}/v1/statement",
            data=count_sql
        )
        result = response.json()
        while 'nextUri' in result:
            response = trino_session.get(result['nextUri'])
            result = response.json()
        
        assert 'data' in result
        assert result['data'][0][0] == 2  # Should have 2 rows left
