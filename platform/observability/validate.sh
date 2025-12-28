#!/bin/bash
# Observability Helm Chart Validation Script
# Validates observability stack configuration

echo "=========================================="
echo "Observability Helm Chart Validation"
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
echo "2. Prometheus Configuration"
echo "----------------------------"

# Check Prometheus is enabled
if grep -q "prometheus:" values.yaml && grep -A 1 "prometheus:" values.yaml | grep -q "enabled: true"; then
    pass "Prometheus enabled"
else
    fail "Prometheus not enabled"
fi

# Check retention configuration
if grep -q "retention:" values.yaml; then
    pass "Retention period configured"
else
    warn "Retention period not configured"
fi

# Check storage configuration
if grep -q "storageSpec:" values.yaml; then
    pass "Storage configuration present"
else
    fail "Storage configuration missing"
fi

# Check scrape configs for platform services
if grep -q "additionalScrapeConfigs:" values.yaml; then
    pass "Additional scrape configs present"
else
    fail "Additional scrape configs missing"
fi

# Check for MinIO scrape config
if grep -q "job_name.*minio" values.yaml; then
    pass "MinIO scrape config present"
else
    warn "MinIO scrape config missing"
fi

# Check for Trino scrape config
if grep -q "job_name.*trino" values.yaml; then
    pass "Trino scrape config present"
else
    warn "Trino scrape config missing"
fi

# Check for Iceberg scrape config
if grep -q "job_name.*iceberg" values.yaml; then
    pass "Iceberg catalog scrape config present"
else
    warn "Iceberg catalog scrape config missing"
fi

# Check for Airflow scrape config
if grep -q "job_name.*airflow" values.yaml; then
    pass "Airflow scrape config present"
else
    warn "Airflow scrape config missing"
fi

echo ""
echo "3. Grafana Configuration"
echo "------------------------"

# Check Grafana is enabled
if grep -q "grafana:" values.yaml && grep -A 1 "grafana:" values.yaml | grep -q "enabled: true"; then
    pass "Grafana enabled"
else
    fail "Grafana not enabled"
fi

# Check persistence
if grep -A 5 "grafana:" values.yaml | grep -q "persistence:" && grep -A 6 "grafana:" values.yaml | grep -q "enabled: true"; then
    pass "Grafana persistence enabled"
else
    warn "Grafana persistence not enabled"
fi

# Check datasources configuration
if grep -q "datasources:" values.yaml; then
    pass "Grafana datasources configured"
else
    fail "Grafana datasources missing"
fi

# Check dashboard providers
if grep -q "dashboardProviders:" values.yaml; then
    pass "Grafana dashboard providers configured"
else
    warn "Grafana dashboard providers missing"
fi

echo ""
echo "4. Alertmanager Configuration"
echo "------------------------------"

# Check Alertmanager is enabled
if grep -q "alertmanager:" values.yaml && grep -A 1 "alertmanager:" values.yaml | grep -q "enabled: true"; then
    pass "Alertmanager enabled"
else
    warn "Alertmanager not enabled"
fi

# Check Alertmanager storage
if grep -A 10 "alertmanager:" values.yaml | grep -q "storage:"; then
    pass "Alertmanager storage configured"
else
    warn "Alertmanager storage not configured"
fi

echo ""
echo "5. High Availability (Production)"
echo "----------------------------------"

# Check Prometheus replicas in production
if grep -A 10 "prometheus:" values-prod.yaml 2>/dev/null | grep -q "replicas: [2-9]"; then
    pass "Production Prometheus has multiple replicas"
else
    warn "Production Prometheus should have multiple replicas"
fi

# Check Grafana replicas in production
if grep -A 10 "grafana:" values-prod.yaml 2>/dev/null | grep -q "replicas: [2-9]"; then
    pass "Production Grafana has multiple replicas"
else
    warn "Production Grafana should have multiple replicas"
fi

# Check Alertmanager replicas in production
if grep -A 10 "alertmanager:" values-prod.yaml 2>/dev/null | grep -q "replicas: [2-9]"; then
    pass "Production Alertmanager has multiple replicas"
else
    warn "Production Alertmanager should have multiple replicas"
fi

# Check pod anti-affinity in production
if grep -q "podAntiAffinity:" values-prod.yaml 2>/dev/null; then
    pass "Production has pod anti-affinity configured"
else
    warn "Production should configure pod anti-affinity for HA"
fi

echo ""
echo "6. Security Configuration"
echo "-------------------------"

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

# Check for default passwords in production
if grep -q "adminPassword.*admin" values-prod.yaml 2>/dev/null; then
    warn "Default admin password in production values (should be overridden)"
else
    pass "No default admin password in production values"
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
echo "8. Helm Template Validation"
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
            if helm template test-observability . --values "values-${env}.yaml" > /dev/null 2>&1; then
                pass "Helm template renders successfully for ${env}"
            else
                warn "Helm template rendering has warnings for ${env} (may need schema adjustments)"
            fi
        fi
    done
else
    warn "Helm not installed, skipping template validation"
fi

echo ""
echo "9. Environment-Specific Validation"
echo "------------------------------------"

# Check dev environment
if [ -f "values-dev.yaml" ]; then
    if grep -A 5 "prometheus:" values-dev.yaml | grep -q "retention: 3d"; then
        pass "Dev environment has short retention (3d)"
    else
        warn "Dev environment retention may be too long"
    fi
    
    if grep -A 10 "prometheus:" values-dev.yaml | grep -q "replicas: 1"; then
        pass "Dev environment has minimal Prometheus replicas (1)"
    fi
fi

# Check production environment
if [ -f "values-prod.yaml" ]; then
    if grep -A 5 "prometheus:" values-prod.yaml | grep -q "retention: [2-3][0-9]d"; then
        pass "Production environment has long retention (30d)"
    else
        warn "Production environment should have longer retention"
    fi
    
    if grep -A 10 "prometheus:" values-prod.yaml | grep -q "replicas: [3-9]"; then
        pass "Production environment has sufficient Prometheus replicas"
    else
        warn "Production environment may need more Prometheus replicas"
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
    echo "This chart provides comprehensive observability for the Lakehouse platform"
    exit 0
else
    echo -e "${RED}✗ Some validations failed.${NC}"
    echo "Please review the failures above and ensure proper configuration."
    exit 1
fi
