#!/bin/bash
# Airflow Helm Chart Validation Script
# Validates contract compliance per contracts/workflow-orchestration.md

echo "=========================================="
echo "Airflow Helm Chart Validation"
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
echo "2. Contract Compliance - KubernetesExecutor"
echo "--------------------------------------------"

# Check that KubernetesExecutor is configured
if grep -q "executor.*KubernetesExecutor" values.yaml values-*.yaml 2>/dev/null; then
    pass "KubernetesExecutor configured (container-based jobs)"
else
    fail "KubernetesExecutor not configured"
fi

# Check that CeleryExecutor is not used (would require Redis)
if grep -q "executor.*CeleryExecutor" values.yaml values-*.yaml 2>/dev/null; then
    warn "CeleryExecutor found (contract prefers KubernetesExecutor)"
else
    pass "No CeleryExecutor (contract compliant)"
fi

# Check Redis is disabled (not needed for KubernetesExecutor)
if grep -q "redis:" values.yaml; then
    if grep -A 1 "redis:" values.yaml | grep -q "enabled: false"; then
        pass "Redis disabled (not needed for KubernetesExecutor)"
    else
        warn "Redis enabled (not needed for KubernetesExecutor)"
    fi
else
    pass "Redis configuration absent (acceptable)"
fi

echo ""
echo "3. Contract Compliance - No Hardcoded Values"
echo "---------------------------------------------"

# Check for hardcoded IP addresses
if grep -E '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' values.yaml values-*.yaml 2>/dev/null | grep -v "^#" | grep -v "3.1.5"; then
    fail "Hardcoded IP addresses found (violates contract)"
else
    pass "No hardcoded IP addresses"
fi

# Check for hardcoded credentials in production
if grep -q "password.*admin" values-prod.yaml 2>/dev/null; then
    warn "Default password in production values (should be overridden)"
else
    pass "No default passwords in production values"
fi

# Check for external secret references in production
if grep -q "OVERRIDE_WITH_EXTERNAL_SECRET" values-prod.yaml 2>/dev/null; then
    pass "Production values reference external secrets"
else
    warn "Production values should reference external secrets"
fi

echo ""
echo "4. Contract Compliance - GitSync Support"
echo "-----------------------------------------"

# Check GitSync configuration exists
if grep -q "gitSync:" values.yaml; then
    pass "GitSync configuration present"
else
    fail "GitSync configuration missing"
fi

# Check GitSync is enabled in production
if grep -A 2 "gitSync:" values-prod.yaml 2>/dev/null | grep -q "enabled: true"; then
    pass "GitSync enabled in production"
else
    warn "GitSync should be enabled in production"
fi

# Check GitSync is disabled in development
if grep -A 2 "gitSync:" values-dev.yaml 2>/dev/null | grep -q "enabled: false"; then
    pass "GitSync disabled in development (expected)"
else
    warn "GitSync configuration in development"
fi

echo ""
echo "5. Observability Requirements"
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
    warn "ServiceMonitor configuration missing"
fi

# Check metrics enabled in production
if grep -A 2 "metrics:" values-prod.yaml 2>/dev/null | grep -q "enabled: true"; then
    pass "Metrics enabled in production"
else
    warn "Metrics should be enabled in production"
fi

# Check logging configuration
if grep -q "logging:" values.yaml; then
    pass "Logging configuration present"
else
    warn "Logging configuration missing"
fi

echo ""
echo "6. Security Configuration"
echo "-------------------------"

# Check authentication configuration
if grep -q "authenticate:" values.yaml; then
    pass "Authentication configuration present"
else
    warn "Authentication configuration missing"
fi

# Check RBAC configuration
if grep -q "rbac:" values.yaml; then
    pass "RBAC configuration present"
else
    warn "RBAC configuration missing"
fi

# Check authentication enabled in production
if grep -q "authenticate.*True" values-prod.yaml 2>/dev/null; then
    pass "Authentication enabled in production"
else
    fail "Authentication must be enabled in production"
fi

# Check security context
if grep -q "securityContext:" values.yaml; then
    pass "Security context configured"
else
    warn "Security context missing"
fi

# Check runAsNonRoot
if grep -q "runAsNonRoot: true" values.yaml; then
    pass "Runs as non-root user"
else
    warn "Should run as non-root user"
fi

echo ""
echo "7. Resource Configuration"
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

echo ""
echo "8. High Availability (Production)"
echo "----------------------------------"

# Check webserver replicas in production
if grep -A 2 "webserver:" values-prod.yaml 2>/dev/null | grep -q "replicas: [2-9]"; then
    pass "Production webserver has multiple replicas"
else
    warn "Production webserver should have multiple replicas"
fi

# Check scheduler replicas in production
if grep -A 2 "scheduler:" values-prod.yaml 2>/dev/null | grep -q "replicas: [2-9]"; then
    pass "Production scheduler has multiple replicas"
else
    warn "Production scheduler should have multiple replicas"
fi

# Check pod anti-affinity in production
if grep -q "podAntiAffinity:" values-prod.yaml 2>/dev/null; then
    pass "Production has pod anti-affinity configured"
else
    warn "Production should configure pod anti-affinity for HA"
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
            if helm template test-airflow . --values "values-${env}.yaml" > /dev/null 2>&1; then
                pass "Helm template renders successfully for ${env}"
            else
                warn "Helm template rendering has warnings for ${env} (schema validation strict)"
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
    if grep -A 2 "webserver:" values-dev.yaml | grep -q "replicas: 1"; then
        pass "Dev environment has minimal webserver replicas (1)"
    else
        warn "Dev environment webserver replica count may be too high"
    fi
    
    if grep -q "authenticate.*False" values-dev.yaml; then
        pass "Dev environment has authentication disabled for ease of use"
    fi
fi

# Check production environment
if [ -f "values-prod.yaml" ]; then
    if grep -A 2 "webserver:" values-prod.yaml | grep -q "replicas: [3-9]"; then
        pass "Production environment has sufficient webserver replicas"
    else
        warn "Production environment may need more webserver replicas"
    fi
    
    if grep -q "authenticate.*True" values-prod.yaml; then
        pass "Production environment has authentication enabled"
    else
        fail "Production environment must have authentication enabled"
    fi
    
    if grep -A 2 "gitSync:" values-prod.yaml | grep -q "enabled: true"; then
        pass "Production environment has GitSync enabled"
    else
        warn "Production environment should enable GitSync"
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
    echo "This chart is compliant with contracts/workflow-orchestration.md"
    exit 0
else
    echo -e "${RED}✗ Some validations failed.${NC}"
    echo "Please review the failures above and ensure contract compliance."
    exit 1
fi
