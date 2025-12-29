"""
Sample Service - REST API for Lakehouse Table Management

This service demonstrates compliance with the Service Module Contract.
It provides a simple REST API for managing tables with health checks,
metrics, and structured logging.
"""

import os
import sys
import signal
import time
import logging
import json
from datetime import datetime
from typing import Dict, Any, List
from flask import Flask, request, jsonify, Response
from prometheus_client import Counter, Histogram, Gauge, generate_latest, CONTENT_TYPE_LATEST
import requests

# Initialize Flask app
app = Flask(__name__)

# Configuration from environment variables
SERVICE_PORT = int(os.getenv('SERVICE_PORT', '8080'))
LOG_LEVEL = os.getenv('LOG_LEVEL', 'INFO')
TRINO_ENDPOINT = os.getenv('TRINO_ENDPOINT', 'http://trino:8080')
S3_ENDPOINT = os.getenv('S3_ENDPOINT', 'http://minio:9000')
ICEBERG_CATALOG_URI = os.getenv('ICEBERG_CATALOG_URI', 'http://iceberg-catalog:8181')

# Service start time
SERVICE_START_TIME = time.time()

# In-memory storage (for demonstration purposes)
# In production, this would be replaced with a database
TABLES_DB: Dict[str, Dict[str, Any]] = {}


# ============================================================================
# Logging Configuration
# ============================================================================

class JSONFormatter(logging.Formatter):
    """Custom JSON formatter for structured logging"""
    
    def format(self, record):
        log_data = {
            "timestamp": datetime.utcnow().isoformat() + "Z",
            "level": record.levelname,
            "service": "sample-service",
            "message": record.getMessage(),
        }
        
        # Add extra fields if present
        if hasattr(record, 'table_id'):
            log_data['table_id'] = record.table_id
        if hasattr(record, 'duration_ms'):
            log_data['duration_ms'] = record.duration_ms
        if hasattr(record, 'status_code'):
            log_data['status_code'] = record.status_code
            
        return json.dumps(log_data)


# Configure logging
handler = logging.StreamHandler(sys.stdout)
handler.setFormatter(JSONFormatter())
logger = logging.getLogger()
logger.addHandler(handler)
logger.setLevel(getattr(logging, LOG_LEVEL.upper()))


# ============================================================================
# Prometheus Metrics
# ============================================================================

# HTTP request metrics
http_requests_total = Counter(
    'http_requests_total',
    'Total HTTP requests',
    ['method', 'endpoint', 'status']
)

http_request_duration = Histogram(
    'http_request_duration_seconds',
    'HTTP request duration in seconds',
    ['method', 'endpoint']
)

http_requests_active = Gauge(
    'http_requests_active',
    'Number of active HTTP requests'
)

# Service uptime metric
service_uptime_seconds = Gauge(
    'service_uptime_seconds',
    'Service uptime in seconds'
)

# Tables metric
tables_total = Gauge(
    'tables_total',
    'Total number of tables'
)


# ============================================================================
# Request Instrumentation
# ============================================================================

@app.before_request
def before_request():
    """Instrument request start"""
    http_requests_active.inc()
    request.start_time = time.time()


@app.after_request
def after_request(response):
    """Instrument request completion"""
    http_requests_active.dec()
    
    # Calculate duration
    duration = time.time() - request.start_time
    
    # Record metrics
    http_request_duration.labels(
        method=request.method,
        endpoint=request.endpoint or 'unknown'
    ).observe(duration)
    
    http_requests_total.labels(
        method=request.method,
        endpoint=request.endpoint or 'unknown',
        status=response.status_code
    ).inc()
    
    # Log request
    logger.info(
        f"{request.method} {request.path} {response.status_code}",
        extra={
            'duration_ms': int(duration * 1000),
            'status_code': response.status_code
        }
    )
    
    return response


# ============================================================================
# Health Check Endpoints
# ============================================================================

@app.route('/health', methods=['GET'])
def health():
    """
    Liveness probe - indicates if the service is running
    
    Returns:
        200 OK if service is alive
        503 Service Unavailable if service is not alive
    """
    return jsonify({
        "status": "ok",
        "timestamp": datetime.utcnow().isoformat() + "Z"
    }), 200


@app.route('/ready', methods=['GET'])
def ready():
    """
    Readiness probe - indicates if the service is ready to accept traffic
    
    Checks connectivity to:
    - Trino
    - MinIO (S3)
    - Iceberg Catalog
    
    Returns:
        200 OK if service is ready
        503 Service Unavailable if service is not ready
    """
    checks = {
        "trino": check_trino(),
        "s3": check_s3(),
        "iceberg": check_iceberg()
    }
    
    all_ok = all(status == "ok" for status in checks.values())
    status_code = 200 if all_ok else 503
    
    return jsonify({
        "status": "ready" if all_ok else "not_ready",
        "checks": checks,
        "timestamp": datetime.utcnow().isoformat() + "Z"
    }), status_code


def check_trino() -> str:
    """Check Trino connectivity"""
    try:
        response = requests.get(f"{TRINO_ENDPOINT}/v1/info", timeout=2)
        return "ok" if response.status_code == 200 else "error"
    except Exception:
        return "error"


def check_s3() -> str:
    """Check S3 (MinIO) connectivity"""
    try:
        response = requests.get(f"{S3_ENDPOINT}/minio/health/live", timeout=2)
        return "ok" if response.status_code == 200 else "error"
    except Exception:
        return "error"


def check_iceberg() -> str:
    """Check Iceberg Catalog connectivity"""
    try:
        response = requests.get(f"{ICEBERG_CATALOG_URI}/v1/config", timeout=2)
        return "ok" if response.status_code == 200 else "error"
    except Exception:
        return "error"


# ============================================================================
# Metrics Endpoint
# ============================================================================

@app.route('/metrics', methods=['GET'])
def metrics():
    """
    Prometheus metrics endpoint
    
    Returns:
        Prometheus-formatted metrics
    """
    # Update uptime metric
    service_uptime_seconds.set(time.time() - SERVICE_START_TIME)
    
    # Update tables metric
    tables_total.set(len(TABLES_DB))
    
    return Response(generate_latest(), mimetype=CONTENT_TYPE_LATEST)


# ============================================================================
# REST API Endpoints
# ============================================================================

@app.route('/api/v1/tables', methods=['GET'])
def list_tables():
    """
    List all tables
    
    Returns:
        200 OK with list of tables
    """
    tables = list(TABLES_DB.values())
    
    logger.info(f"Listed {len(tables)} tables")
    
    return jsonify({
        "tables": tables,
        "count": len(tables)
    }), 200


@app.route('/api/v1/tables/<table_id>', methods=['GET'])
def get_table(table_id: str):
    """
    Get table details
    
    Args:
        table_id: Table identifier
    
    Returns:
        200 OK with table details
        404 Not Found if table doesn't exist
    """
    table = TABLES_DB.get(table_id)
    
    if not table:
        logger.warning(f"Table not found: {table_id}", extra={'table_id': table_id})
        return jsonify({
            "error": {
                "code": "RESOURCE_NOT_FOUND",
                "message": f"Table '{table_id}' not found",
                "details": {"table_id": table_id},
                "timestamp": datetime.utcnow().isoformat() + "Z"
            }
        }), 404
    
    logger.info(f"Retrieved table: {table_id}", extra={'table_id': table_id})
    
    return jsonify(table), 200


@app.route('/api/v1/tables', methods=['POST'])
def create_table():
    """
    Create a new table
    
    Request body:
        {
            "name": "orders",
            "namespace": "sales",
            "schema": {"columns": [...]}
        }
    
    Returns:
        201 Created with table details
        400 Bad Request if validation fails
    """
    data = request.get_json()
    
    # Validate request
    if not data:
        return jsonify({
            "error": {
                "code": "INVALID_REQUEST",
                "message": "Request body is required",
                "timestamp": datetime.utcnow().isoformat() + "Z"
            }
        }), 400
    
    # Validate required fields
    required_fields = ['name', 'namespace', 'schema']
    missing_fields = [field for field in required_fields if field not in data]
    
    if missing_fields:
        return jsonify({
            "error": {
                "code": "INVALID_REQUEST",
                "message": f"Missing required fields: {', '.join(missing_fields)}",
                "details": {"missing_fields": missing_fields},
                "timestamp": datetime.utcnow().isoformat() + "Z"
            }
        }), 400
    
    # Generate table ID
    table_id = f"{data['namespace']}.{data['name']}"
    
    # Check if table already exists
    if table_id in TABLES_DB:
        return jsonify({
            "error": {
                "code": "RESOURCE_ALREADY_EXISTS",
                "message": f"Table '{table_id}' already exists",
                "details": {"table_id": table_id},
                "timestamp": datetime.utcnow().isoformat() + "Z"
            }
        }), 409
    
    # Create table
    table = {
        "id": table_id,
        "name": data['name'],
        "namespace": data['namespace'],
        "schema": data['schema'],
        "created_at": datetime.utcnow().isoformat() + "Z",
        "updated_at": datetime.utcnow().isoformat() + "Z"
    }
    
    TABLES_DB[table_id] = table
    
    logger.info(f"Created table: {table_id}", extra={'table_id': table_id})
    
    return jsonify(table), 201


@app.route('/api/v1/tables/<table_id>', methods=['PUT'])
def update_table(table_id: str):
    """
    Update a table
    
    Args:
        table_id: Table identifier
    
    Request body:
        {
            "schema": {"columns": [...]}
        }
    
    Returns:
        200 OK with updated table details
        404 Not Found if table doesn't exist
    """
    table = TABLES_DB.get(table_id)
    
    if not table:
        return jsonify({
            "error": {
                "code": "RESOURCE_NOT_FOUND",
                "message": f"Table '{table_id}' not found",
                "details": {"table_id": table_id},
                "timestamp": datetime.utcnow().isoformat() + "Z"
            }
        }), 404
    
    data = request.get_json()
    
    if not data:
        return jsonify({
            "error": {
                "code": "INVALID_REQUEST",
                "message": "Request body is required",
                "timestamp": datetime.utcnow().isoformat() + "Z"
            }
        }), 400
    
    # Update table
    if 'schema' in data:
        table['schema'] = data['schema']
    
    table['updated_at'] = datetime.utcnow().isoformat() + "Z"
    
    logger.info(f"Updated table: {table_id}", extra={'table_id': table_id})
    
    return jsonify(table), 200


@app.route('/api/v1/tables/<table_id>', methods=['DELETE'])
def delete_table(table_id: str):
    """
    Delete a table
    
    Args:
        table_id: Table identifier
    
    Returns:
        204 No Content if deleted successfully
        404 Not Found if table doesn't exist
    """
    if table_id not in TABLES_DB:
        return jsonify({
            "error": {
                "code": "RESOURCE_NOT_FOUND",
                "message": f"Table '{table_id}' not found",
                "details": {"table_id": table_id},
                "timestamp": datetime.utcnow().isoformat() + "Z"
            }
        }), 404
    
    del TABLES_DB[table_id]
    
    logger.info(f"Deleted table: {table_id}", extra={'table_id': table_id})
    
    return '', 204


# ============================================================================
# Error Handlers
# ============================================================================

@app.errorhandler(404)
def not_found(error):
    """Handle 404 errors"""
    return jsonify({
        "error": {
            "code": "RESOURCE_NOT_FOUND",
            "message": "The requested resource was not found",
            "timestamp": datetime.utcnow().isoformat() + "Z"
        }
    }), 404


@app.errorhandler(500)
def internal_error(error):
    """Handle 500 errors"""
    logger.error(f"Internal server error: {error}")
    return jsonify({
        "error": {
            "code": "INTERNAL_ERROR",
            "message": "An internal server error occurred",
            "timestamp": datetime.utcnow().isoformat() + "Z"
        }
    }), 500


# ============================================================================
# Graceful Shutdown
# ============================================================================

def graceful_shutdown(signum, frame):
    """Handle graceful shutdown on SIGTERM"""
    logger.info("Received SIGTERM, shutting down gracefully")
    
    # Close any open connections
    # Finish processing in-flight requests
    # Exit cleanly
    
    logger.info("Shutdown complete")
    sys.exit(0)


# Register signal handler
signal.signal(signal.SIGTERM, graceful_shutdown)


# ============================================================================
# Main Entry Point
# ============================================================================

if __name__ == '__main__':
    logger.info(f"Starting Sample Service on port {SERVICE_PORT}")
    logger.info(f"Log level: {LOG_LEVEL}")
    logger.info(f"Trino endpoint: {TRINO_ENDPOINT}")
    logger.info(f"S3 endpoint: {S3_ENDPOINT}")
    logger.info(f"Iceberg catalog URI: {ICEBERG_CATALOG_URI}")
    
    # Run Flask app
    app.run(
        host='0.0.0.0',
        port=SERVICE_PORT,
        debug=False  # Never use debug mode in production
    )
