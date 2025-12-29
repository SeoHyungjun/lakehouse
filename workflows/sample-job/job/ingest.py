"""
Sample Data Ingest Job

This job demonstrates orchestrator-agnostic design:
- No Airflow/Dagster imports
- Configuration via environment variables
- Business logic in containerized job
- Structured logging to stdout
- Exit codes for success/failure
- Idempotent execution

Usage:
    python ingest.py --date 2024-12-27 --table iceberg.sample.data --batch-size 1000
"""

import os
import sys
import argparse
import logging
import json
from datetime import datetime
from typing import Dict, Any, List
import requests

# ============================================================================
# Logging Configuration
# ============================================================================

class JSONFormatter(logging.Formatter):
    """Custom JSON formatter for structured logging"""
    
    def format(self, record):
        log_data = {
            "timestamp": datetime.utcnow().isoformat() + "Z",
            "level": record.levelname,
            "job": "sample_data_ingest",
            "message": record.getMessage(),
        }
        
        if hasattr(record, 'execution_date'):
            log_data['execution_date'] = record.execution_date
        if hasattr(record, 'rows_inserted'):
            log_data['rows_inserted'] = record.rows_inserted
        if hasattr(record, 'duration_seconds'):
            log_data['duration_seconds'] = record.duration_seconds
            
        return json.dumps(log_data)


# Configure logging
handler = logging.StreamHandler(sys.stdout)
handler.setFormatter(JSONFormatter())
logger = logging.getLogger()
logger.addHandler(handler)
log_level = os.getenv('LOG_LEVEL', 'INFO')
logger.setLevel(getattr(logging, log_level.upper()))


# ============================================================================
# Configuration
# ============================================================================

# Trino configuration
TRINO_ENDPOINT = os.getenv('TRINO_ENDPOINT', 'http://trino:8080')
TRINO_CATALOG = os.getenv('TRINO_CATALOG', 'iceberg')
TRINO_SCHEMA = os.getenv('TRINO_SCHEMA', 'sample')

# S3 configuration
S3_ENDPOINT = os.getenv('S3_ENDPOINT', 'http://minio:9000')
S3_BUCKET = os.getenv('S3_BUCKET', 'lakehouse-dev-warehouse')

# Iceberg configuration
ICEBERG_CATALOG_URI = os.getenv('ICEBERG_CATALOG_URI', 'http://iceberg-catalog:8181')


# ============================================================================
# Trino Client
# ============================================================================

class TrinoClient:
    """Simple Trino client for executing SQL queries"""
    
    def __init__(self, endpoint: str, catalog: str, schema: str):
        self.endpoint = endpoint
        self.catalog = catalog
        self.schema = schema
        self.session = requests.Session()
    
    def execute(self, sql: str) -> Dict[str, Any]:
        """Execute SQL query and return results"""
        logger.info(f"Executing SQL: {sql[:100]}...")
        
        headers = {
            'X-Trino-Catalog': self.catalog,
            'X-Trino-Schema': self.schema,
            'X-Trino-User': 'lakehouse-job',
        }
        
        try:
            response = self.session.post(
                f"{self.endpoint}/v1/statement",
                headers=headers,
                data=sql
            )
            response.raise_for_status()
            
            result = response.json()
            
            # Poll for query completion
            while 'nextUri' in result:
                response = self.session.get(result['nextUri'], headers=headers)
                response.raise_for_status()
                result = response.json()
            
            logger.info("SQL execution completed")
            return result
        
        except Exception as e:
            logger.error(f"SQL execution failed: {e}")
            raise
    
    def execute_and_fetch(self, sql: str) -> List[List[Any]]:
        """Execute SQL query and return rows"""
        result = self.execute(sql)
        
        if 'data' in result:
            return result['data']
        return []


# ============================================================================
# Job Logic
# ============================================================================

def create_table_if_not_exists(client: TrinoClient, table: str):
    """Create Iceberg table if it doesn't exist"""
    logger.info(f"Creating table if not exists: {table}")
    
    # Parse table name
    parts = table.split('.')
    if len(parts) != 3:
        raise ValueError(f"Invalid table name: {table}. Expected format: catalog.schema.table")
    
    catalog, schema, table_name = parts
    
    # Create schema if not exists
    create_schema_sql = f"CREATE SCHEMA IF NOT EXISTS {catalog}.{schema}"
    client.execute(create_schema_sql)
    
    # Create table if not exists
    create_table_sql = f"""
    CREATE TABLE IF NOT EXISTS {table} (
        id BIGINT,
        execution_date DATE,
        value VARCHAR,
        amount DECIMAL(10, 2),
        created_at TIMESTAMP
    )
    WITH (
        format = 'PARQUET',
        partitioning = ARRAY['execution_date']
    )
    """
    client.execute(create_table_sql)
    
    logger.info(f"Table {table} is ready")


def generate_sample_data(execution_date: str, batch_size: int) -> List[Dict[str, Any]]:
    """Generate sample data for ingestion"""
    logger.info(f"Generating {batch_size} sample records for {execution_date}")
    
    data = []
    for i in range(batch_size):
        data.append({
            'id': i + 1,
            'execution_date': execution_date,
            'value': f'sample_value_{i}',
            'amount': round((i + 1) * 10.5, 2),
            'created_at': datetime.utcnow().isoformat()
        })
    
    return data


def insert_data(client: TrinoClient, table: str, data: List[Dict[str, Any]]):
    """Insert data into Iceberg table"""
    logger.info(f"Inserting {len(data)} rows into {table}")
    
    start_time = datetime.utcnow()
    
    # Build INSERT statement
    values = []
    for row in data:
        values.append(
            f"({row['id']}, DATE '{row['execution_date']}', '{row['value']}', "
            f"{row['amount']}, TIMESTAMP '{row['created_at']}')"
        )
    
    # Insert in batches of 100 to avoid query size limits
    batch_size = 100
    for i in range(0, len(values), batch_size):
        batch = values[i:i + batch_size]
        insert_sql = f"""
        INSERT INTO {table} (id, execution_date, value, amount, created_at)
        VALUES {', '.join(batch)}
        """
        client.execute(insert_sql)
    
    duration = (datetime.utcnow() - start_time).total_seconds()
    
    logger.info(
        f"Inserted {len(data)} rows",
        extra={
            'rows_inserted': len(data),
            'duration_seconds': duration
        }
    )


def validate_data(client: TrinoClient, table: str, execution_date: str, expected_count: int):
    """Validate that data was inserted correctly"""
    logger.info(f"Validating data in {table} for {execution_date}")
    
    # Count rows for execution date
    count_sql = f"""
    SELECT COUNT(*) as count
    FROM {table}
    WHERE execution_date = DATE '{execution_date}'
    """
    result = client.execute_and_fetch(count_sql)
    
    actual_count = result[0][0] if result else 0
    
    if actual_count != expected_count:
        raise ValueError(
            f"Data validation failed: expected {expected_count} rows, "
            f"found {actual_count} rows"
        )
    
    logger.info(f"Data validation passed: {actual_count} rows")


def run_job(execution_date: str, table: str, batch_size: int):
    """Main job execution logic"""
    logger.info(
        f"Starting job",
        extra={'execution_date': execution_date}
    )
    
    try:
        # Initialize Trino client
        client = TrinoClient(TRINO_ENDPOINT, TRINO_CATALOG, TRINO_SCHEMA)
        
        # Create table if not exists
        create_table_if_not_exists(client, table)
        
        # Generate sample data
        data = generate_sample_data(execution_date, batch_size)
        
        # Insert data
        insert_data(client, table, data)
        
        # Validate data
        validate_data(client, table, execution_date, batch_size)
        
        logger.info("Job completed successfully")
        return 0  # Success
    
    except Exception as e:
        logger.error(f"Job failed: {e}")
        return 1  # Failure


# ============================================================================
# Main Entry Point
# ============================================================================

def main():
    """Main entry point"""
    parser = argparse.ArgumentParser(description='Sample data ingest job')
    parser.add_argument('--date', required=True, help='Execution date (YYYY-MM-DD)')
    parser.add_argument('--table', required=True, help='Target table (catalog.schema.table)')
    parser.add_argument('--batch-size', type=int, default=1000, help='Number of rows to insert')
    
    args = parser.parse_args()
    
    logger.info(f"Job configuration:")
    logger.info(f"  Execution date: {args.date}")
    logger.info(f"  Target table: {args.table}")
    logger.info(f"  Batch size: {args.batch_size}")
    logger.info(f"  Trino endpoint: {TRINO_ENDPOINT}")
    logger.info(f"  S3 endpoint: {S3_ENDPOINT}")
    
    # Run job
    exit_code = run_job(args.date, args.table, args.batch_size)
    
    sys.exit(exit_code)


if __name__ == '__main__':
    main()
