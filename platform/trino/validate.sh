#!/bin/bash
# Trino Helm Chart Validation Script
# Validates contract compliance per contracts/query-engine.md

echo "=========================================="
echo "Trino Helm Chart Validation"
echo "=========================================="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

PASS=0
FAIL=0
WARN=0

# Function to print test results
pass() {
    echo -e "${GREEN}✓${NC} $1"
    ((PASS++))
}

fail() {
    echo -e "${RED}✗${NC} $1"
    ((FAIL++))
}

warn() {
    echo -e "${YELLOW}⚠${NC} $1"
    ((WARN++))
}

echo "1. Chart Structure Validation"
echo "------------------------------"

# Check required files
if [ -f "Chart.yaml" ]; then
    pass "Chart.yaml exists"
else
    fail "Chart.yaml missing"
fi

if [ -f "values.yaml" ]; then
    pass "values.yaml exists"
else
    fail "values.yaml missing"
fi

if [ -f "values-dev.yaml" ]; then
    pass "values-dev.yaml exists"
else
    fail "values-dev.yaml missing"
fi

if [ -f "values-staging.yaml" ]; then
    pass "values-staging.yaml exists"
else
    fail "values-staging.yaml missing"
fi

if [ -f "values-prod.yaml" ]; then
    pass "values-prod.yaml exists"
else
    fail "values-prod.yaml missing"
fi

if [ -f "README.md" ]; then
    pass "README.md exists"
else
    fail "README.md missing"
fi

echo ""
echo "2. Contract Compliance - Iceberg-Only Access"
echo "---------------------------------------------"

# Check that Iceberg connector is configured
if grep -q "connector.name=iceberg" values.yaml; then
    pass "Iceberg connector configured"
else
    fail "Iceberg connector not found in values.yaml"
fi

# Check that no direct S3 connector is present
if grep -q "connector.name=s3" values.yaml values-*.yaml 2>/dev/null; then
    fail "Direct S3 connector found (violates contract)"
else
    pass "No direct S3 connector (contract compliant)"
fi

# Check that no Hive connector for raw files is present
if grep -q "connector.name=hive" values.yaml values-*.yaml 2>/dev/null; then
    warn "Hive connector found (ensure it's for Iceberg metastore, not raw files)"
else
    pass "No Hive connector for raw files"
fi

echo ""
echo "3. Contract Compliance - DNS-Based Endpoints"
echo "---------------------------------------------"

# Check for hardcoded IP addresses
if grep -E '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' values.yaml values-*.yaml 2>/dev/null | grep -v "^#" | grep -v "targetCPUUtilizationPercentage"; then
    fail "Hardcoded IP addresses found (violates contract)"
    ((FAIL++))
else
    pass "No hardcoded IP addresses"
fi

# Check for DNS-based endpoints
if grep -q "svc.cluster.local" values.yaml; then
    pass "DNS-based Kubernetes service endpoints used"
else
    warn "No Kubernetes DNS endpoints found (may be using external DNS)"
fi

# Check Iceberg catalog endpoint
if grep -q "iceberg.rest.uri=http://iceberg-catalog" values.yaml; then
    pass "Iceberg catalog uses DNS endpoint"
else
    fail "Iceberg catalog endpoint not DNS-based"
fi

# Check MinIO endpoint
if grep -q "s3.endpoint=http://minio" values.yaml; then
    pass "MinIO S3 endpoint uses DNS"
else
    fail "MinIO S3 endpoint not DNS-based"
fi

echo ""
echo "4. Contract Compliance - Configuration Injection"
echo "-------------------------------------------------"

# Check for environment variable usage
if grep -q '\${ENV:' values.yaml; then
    pass "Environment variables used for secrets"
else
    fail "No environment variable injection found"
fi

# Check for S3 credentials injection
if grep -q '\${ENV:S3_ACCESS_KEY}' values.yaml; then
    pass "S3 access key uses environment variable"
else
    fail "S3 access key not injected via environment"
fi

if grep -q '\${ENV:S3_SECRET_KEY}' values.yaml; then
    pass "S3 secret key uses environment variable"
else
    fail "S3 secret key not injected via environment"
fi

# Check for hardcoded credentials in production
if grep -q "changeme" values-prod.yaml 2>/dev/null; then
    warn "Default credentials found in production values (should be overridden)"
else
    pass "No default credentials in production values"
fi

echo ""
echo "5. Contract Compliance - Catalog Configuration"
echo "-----------------------------------------------"

# Check catalog type is configurable
if grep -q "iceberg.catalog.type=" values.yaml; then
    pass "Catalog type is configurable"
else
    fail "Catalog type not configurable"
fi

# Check REST catalog support
if grep -q "iceberg.catalog.type=rest" values.yaml; then
    pass "REST catalog supported"
else
    warn "REST catalog not configured (may use other backend)"
fi

# Check warehouse configuration
if grep -q "iceberg.rest.warehouse=" values.yaml || grep -q "iceberg.rest-catalog.warehouse=" values.yaml; then
    pass "Warehouse location configured"
else
    fail "Warehouse location not configured"
fi

echo ""
echo "6. Observability Requirements"
echo "------------------------------"

# Check metrics configuration
if grep -q "metrics:" values.yaml; then
    pass "Metrics configuration present"
else
    fail "Metrics configuration missing"
fi

# Check ServiceMonitor support
if grep -q "serviceMonitor:" values.yaml; then
    pass "ServiceMonitor configuration present"
else
    warn "ServiceMonitor configuration missing (Prometheus Operator integration)"
fi

# Check health checks
if grep -q "livenessProbe:" values.yaml; then
    pass "Liveness probe configured"
else
    fail "Liveness probe missing"
fi

if grep -q "readinessProbe:" values.yaml; then
    pass "Readiness probe configured"
else
    fail "Readiness probe missing"
fi

# Check for /v1/info endpoint
if grep -q "/v1/info" values.yaml; then
    pass "Health check endpoint /v1/info configured"
else
    warn "Health check endpoint not explicitly configured"
fi

echo ""
echo "7. Security Configuration"
echo "-------------------------"

# Check TLS support
if grep -q "tls:" values.yaml; then
    pass "TLS configuration present"
else
    warn "TLS configuration missing"
fi

# Check authentication support
if grep -q "auth:" values.yaml; then
    pass "Authentication configuration present"
else
    warn "Authentication configuration missing"
fi

# Check access control
if grep -q "accessControl:" values.yaml; then
    pass "Access control configuration present"
else
    warn "Access control configuration missing"
fi

# Check pod security context
if grep -q "podSecurityContext:" values.yaml; then
    pass "Pod security context configured"
else
    warn "Pod security context missing"
fi

if grep -q "runAsNonRoot: true" values.yaml; then
    pass "Runs as non-root user"
else
    warn "May run as root (security risk)"
fi

echo ""
echo "8. Resource Configuration"
echo "-------------------------"

# Check resource requests/limits
if grep -q "resources:" values.yaml; then
    pass "Resource requests/limits configured"
else
    fail "Resource configuration missing"
fi

# Check memory configuration
if grep -q "memory:" values.yaml; then
    pass "Memory limits configured"
else
    fail "Memory limits missing"
fi

# Check CPU configuration
if grep -q "cpu:" values.yaml; then
    pass "CPU limits configured"
else
    fail "CPU limits missing"
fi

# Check autoscaling support
if grep -q "autoscaling:" values.yaml; then
    pass "Autoscaling configuration present"
else
    warn "Autoscaling not configured"
fi

echo ""
echo "9. Helm Template Validation"
echo "----------------------------"

# Check if helm is available
if command -v helm &> /dev/null; then
    # Update dependencies
    if helm dependency update . &> /dev/null; then
        pass "Helm dependencies updated"
    else
        warn "Failed to update Helm dependencies (may need internet connection)"
    fi
    
    # Validate template rendering for each environment
    for env in dev staging prod; do
        if [ -f "values-${env}.yaml" ]; then
            if helm template test-trino . --values "values-${env}.yaml" > /dev/null 2>&1; then
                pass "Helm template renders successfully for ${env}"
            else
                fail "Helm template rendering failed for ${env}"
            fi
        fi
    done
else
    warn "Helm not installed, skipping template validation"
fi

echo ""
echo "10. Environment-Specific Validation"
echo "------------------------------------"

# Check dev environment
if [ -f "values-dev.yaml" ]; then
    if grep -q "workers: 2" values-dev.yaml; then
        pass "Dev environment has minimal workers (2)"
    else
        warn "Dev environment worker count may be too high"
    fi
    
    if grep -q "enabled: false" values-dev.yaml | head -1 > /dev/null; then
        pass "Dev environment has features disabled for simplicity"
    fi
fi

# Check production environment
if [ -f "values-prod.yaml" ]; then
    if grep -q "workers: [5-9]" values-prod.yaml || grep -q "workers: [1-9][0-9]" values-prod.yaml; then
        pass "Production environment has sufficient workers"
    else
        warn "Production environment may need more workers"
    fi
    
    if grep -q "autoscaling:" values-prod.yaml && grep -q "enabled: true" values-prod.yaml; then
        pass "Production environment has autoscaling enabled"
    else
        warn "Production environment should enable autoscaling"
    fi
    
    if grep -q "tls:" values-prod.yaml && grep -q "enabled: true" values-prod.yaml; then
        pass "Production environment has TLS enabled"
    else
        warn "Production environment should enable TLS"
    fi
fi

echo ""
echo "=========================================="
echo "Validation Summary"
echo "=========================================="
echo -e "${GREEN}Passed:${NC} $PASS"
echo -e "${YELLOW}Warnings:${NC} $WARN"
echo -e "${RED}Failed:${NC} $FAIL"
echo ""

if [ $FAIL -eq 0 ]; then
    echo -e "${GREEN}✓ All critical validations passed!${NC}"
    echo "This chart is compliant with contracts/query-engine.md"
    exit 0
else
    echo -e "${RED}✗ Some validations failed.${NC}"
    echo "Please review the failures above and ensure contract compliance."
    exit 1
fi
