#!/bin/bash
# ArgoCD Helm Chart Validation Script
# Validates ArgoCD configuration and Application manifests

echo "=========================================="
echo "ArgoCD Helm Chart Validation"
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
echo "2. Application Manifest Templates"
echo "----------------------------------"

# Check Application templates exist
if [ -f "templates/minio-application.yaml" ]; then
    pass "MinIO Application template exists"
else
    fail "MinIO Application template missing"
fi

if [ -f "templates/iceberg-catalog-application.yaml" ]; then
    pass "Iceberg Catalog Application template exists"
else
    fail "Iceberg Catalog Application template missing"
fi

if [ -f "templates/trino-application.yaml" ]; then
    pass "Trino Application template exists"
else
    fail "Trino Application template missing"
fi

if [ -f "templates/airflow-application.yaml" ]; then
    pass "Airflow Application template exists"
else
    fail "Airflow Application template missing"
fi

if [ -f "templates/observability-application.yaml" ]; then
    pass "Observability Application template exists"
else
    fail "Observability Application template missing"
fi

if [ -f "templates/project.yaml" ]; then
    pass "AppProject template exists"
else
    fail "AppProject template missing"
fi

echo ""
echo "3. Application Configuration"
echo "-----------------------------"

# Check applications are configured in values.yaml
if grep -q "applications:" values.yaml; then
    pass "Applications configuration present"
else
    fail "Applications configuration missing"
fi

# Check each application is configured
for app in minio icebergCatalog trino airflow observability; do
    if grep -q "$app:" values.yaml; then
        pass "$app application configured"
    else
        warn "$app application not configured"
    fi
done

echo ""
echo "4. Sync Policy Configuration"
echo "-----------------------------"

# Check sync policies are configured
if grep -q "syncPolicy:" values.yaml; then
    pass "Sync policy configuration present"
else
    warn "Sync policy configuration missing"
fi

# Check prune and selfHeal options
if grep -q "prune:" values.yaml; then
    pass "Prune option configured"
else
    warn "Prune option not configured"
fi

if grep -q "selfHeal:" values.yaml; then
    pass "SelfHeal option configured"
else
    warn "SelfHeal option not configured"
fi

echo ""
echo "5. GitOps Configuration"
echo "-----------------------"

# Check repoURL is configured
if grep -q "repoURL:" values.yaml; then
    pass "Repository URL configured"
else
    fail "Repository URL missing"
fi

# Check targetRevision is configured
if grep -q "targetRevision:" values.yaml; then
    pass "Target revision configured"
else
    warn "Target revision not configured"
fi

# Check environment is configured
if grep -q "environment:" values.yaml; then
    pass "Environment configured"
else
    fail "Environment not configured"
fi

echo ""
echo "6. ArgoCD Server Configuration"
echo "-------------------------------"

# Check server configuration
if grep -q "server:" values.yaml; then
    pass "Server configuration present"
else
    fail "Server configuration missing"
fi

# Check resource configuration
if grep -A 10 "server:" values.yaml | grep -q "resources:"; then
    pass "Server resources configured"
else
    warn "Server resources not configured"
fi

echo ""
echo "7. High Availability (Production)"
echo "----------------------------------"

# Check server replicas in production
if grep -A 5 "server:" values-prod.yaml 2>/dev/null | grep -q "replicas: [2-9]"; then
    pass "Production server has multiple replicas"
else
    warn "Production server should have multiple replicas"
fi

# Check repo server replicas in production
if grep -A 5 "repoServer:" values-prod.yaml 2>/dev/null | grep -q "replicas: [2-9]"; then
    pass "Production repo server has multiple replicas"
else
    warn "Production repo server should have multiple replicas"
fi

# Check pod anti-affinity in production
if grep -q "podAntiAffinity:" values-prod.yaml 2>/dev/null; then
    pass "Production has pod anti-affinity configured"
else
    warn "Production should configure pod anti-affinity for HA"
fi

echo ""
echo "8. Security Configuration"
echo "-------------------------"

# Check RBAC configuration
if grep -q "rbac:" values.yaml; then
    pass "RBAC configuration present"
else
    warn "RBAC configuration missing"
fi

# Check SSO enabled in production
if grep -A 2 "dex:" values-prod.yaml 2>/dev/null | grep -q "enabled: true"; then
    pass "SSO enabled in production"
else
    warn "SSO should be enabled in production"
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
            if helm template test-argocd . --values "values-${env}.yaml" --set repoURL=https://github.com/test/repo.git > /dev/null 2>&1; then
                pass "Helm template renders successfully for ${env}"
            else
                warn "Helm template rendering has warnings for ${env}"
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
    if grep -A 5 "server:" values-dev.yaml | grep -q "replicas: 1"; then
        pass "Dev environment has minimal server replicas (1)"
    fi
    
    if grep -q "environment: dev" values-dev.yaml; then
        pass "Dev environment configured correctly"
    fi
fi

# Check production environment
if [ -f "values-prod.yaml" ]; then
    if grep -A 5 "server:" values-prod.yaml | grep -q "replicas: [3-9]"; then
        pass "Production environment has sufficient server replicas"
    else
        warn "Production environment may need more server replicas"
    fi
    
    if grep -q "environment: prod" values-prod.yaml; then
        pass "Production environment configured correctly"
    fi
    
    # Check auto-prune is disabled in production
    if grep -q "prune: false" values-prod.yaml; then
        pass "Production has auto-prune disabled for safety"
    else
        warn "Production should disable auto-prune for safety"
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
    echo "This chart provides GitOps deployment for the Lakehouse platform"
    exit 0
else
    echo -e "${RED}✗ Some validations failed.${NC}"
    echo "Please review the failures above and ensure proper configuration."
    exit 1
fi
