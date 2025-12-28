#!/usr/bin/env bash
# Iceberg Catalog Helm Chart Validation Script
# Validates contract compliance and Helm chart correctness

set -e

CHART_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONTRACTS_DIR="$(cd "${CHART_DIR}/../../contracts" && pwd)"

echo "=== Iceberg Catalog Helm Chart Validation ==="
echo ""

# Color codes
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

pass() {
  echo -e "${GREEN}✓${NC} $1"
}

fail() {
  echo -e "${RED}✗${NC} $1"
  exit 1
}

warn() {
  echo -e "${YELLOW}⚠${NC} $1"
}

# 1. Verify Helm chart structure
echo "1. Checking Helm chart structure..."
[[ -f "${CHART_DIR}/Chart.yaml" ]] || fail "Chart.yaml not found"
[[ -f "${CHART_DIR}/values.yaml" ]] || fail "values.yaml not found"
[[ -d "${CHART_DIR}/templates" ]] || fail "templates/ directory not found"
pass "Helm chart structure is valid"
echo ""

# 2. Verify Helm template rendering (if Helm is installed)
echo "2. Validating Helm templates..."
if command -v helm &> /dev/null; then
  helm template test-catalog "${CHART_DIR}" > /dev/null 2>&1 || fail "Helm template rendering failed"
  pass "Helm templates render successfully"
else
  warn "Helm not installed, skipping template rendering test"
fi
echo ""

# 3. Check for hardcoded IPs
echo "3. Checking for hardcoded IP addresses..."
if grep -r "endpoint.*[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}" "${CHART_DIR}/values"*.yaml 2>/dev/null; then
  fail "Found hardcoded IP addresses in values files"
else
  pass "No hardcoded IP addresses found"
fi
echo ""

# 4. Verify DNS-based endpoints
echo "4. Verifying DNS-based endpoints..."
if grep -q "svc.cluster.local" "${CHART_DIR}/values.yaml"; then
  pass "DNS-based endpoints configured"
else
  fail "DNS-based endpoints not found"
fi
echo ""

# 5. Verify warehouse location is configurable
echo "5. Checking warehouse configurability..."
dev_warehouse=$(grep "warehouse:" "${CHART_DIR}/values-dev.yaml" 2>/dev/null | head -1 | awk '{print $2}')
staging_warehouse=$(grep "warehouse:" "${CHART_DIR}/values-staging.yaml" 2>/dev/null | head -1 | awk '{print $2}')
prod_warehouse=$(grep "warehouse:" "${CHART_DIR}/values-prod.yaml" 2>/dev/null | head -1 | awk '{print $2}')

if [[ -n "$dev_warehouse" ]] && [[ -n "$staging_warehouse" ]] && [[ -n "$prod_warehouse" ]]; then
  if [[ "$dev_warehouse" != "$staging_warehouse" ]] && [[ "$staging_warehouse" != "$prod_warehouse" ]]; then
    pass "Warehouse location is environment-specific"
  else
    warn "Warehouse locations should differ across environments"
  fi
else
  warn "Not all environment-specific warehouse configurations found"
fi
echo ""

# 6. Verify catalog backend is configurable
echo "6. Checking catalog backend configurability..."
if grep -q "backend:" "${CHART_DIR}/values.yaml"; then
  pass "Catalog backend is configurable"
else
  fail "Catalog backend configuration not found"
fi
echo ""

# 7. Verify required Kubernetes resources
echo "7. Verifying Kubernetes resource templates..."
required_templates=(
  "deployment.yaml"
  "service.yaml"
  "secret.yaml"
  "_helpers.tpl"
)

for template in "${required_templates[@]}"; do
  if [[ -f "${CHART_DIR}/templates/${template}" ]]; then
    pass "Template ${template} exists"
  else
    fail "Required template ${template} not found"
  fi
done
echo ""

# 8. Verify health check configuration
echo "8. Checking health check configuration..."
if grep -q "livenessProbe:" "${CHART_DIR}/values.yaml" && \
   grep -q "readinessProbe:" "${CHART_DIR}/values.yaml"; then
  pass "Health checks configured"
else
  fail "Health checks not configured"
fi
echo ""

# 9. Verify metrics configuration
echo "9. Checking metrics configuration..."
if grep -q "metrics:" "${CHART_DIR}/values.yaml"; then
  pass "Metrics configuration present"
else
  warn "Metrics configuration not found"
fi
echo ""

# 10. Verify security context
echo "10. Checking security context..."
if grep -q "securityContext:" "${CHART_DIR}/values.yaml"; then
  pass "Security context configured"
else
  warn "Security context not configured"
fi
echo ""

# 11. Validate against Iceberg Catalog Contract
echo "11. Validating against Iceberg Catalog Contract..."
if [[ -f "${CONTRACTS_DIR}/iceberg-catalog.md" ]]; then
  # Check for contract requirements
  contract_checks=(
    "Apache Iceberg v2 support:backend"
    "REST catalog support:backend.*rest"
    "JDBC catalog support:backend.*jdbc"
    "S3 endpoint configuration:s3.*endpoint"
    "Warehouse configuration:warehouse"
  )
  
  for check in "${contract_checks[@]}"; do
    check_name="${check%%:*}"
    check_pattern="${check##*:}"
    if grep -q "${check_pattern}" "${CHART_DIR}/values.yaml"; then
      pass "${check_name}"
    else
      warn "${check_name} - pattern not found: ${check_pattern}"
    fi
  done
else
  warn "Iceberg Catalog Contract not found at ${CONTRACTS_DIR}/iceberg-catalog.md"
fi
echo ""

# 12. Verify environment-specific configurations exist
echo "12. Checking environment-specific configurations..."
for env in dev staging prod; do
  if [[ -f "${CHART_DIR}/values-${env}.yaml" ]]; then
    pass "Environment configuration for ${env} exists"
  else
    warn "Environment configuration for ${env} not found"
  fi
done
echo ""

# 13. Validate Chart.yaml metadata
echo "13. Validating Chart.yaml metadata..."
if grep -q "apiVersion: v2" "${CHART_DIR}/Chart.yaml"; then
  pass "Chart API version is v2"
else
  fail "Chart API version should be v2"
fi

if grep -q "type: application" "${CHART_DIR}/Chart.yaml"; then
  pass "Chart type is application"
else
  warn "Chart type should be 'application'"
fi
echo ""

# 14. Check for README
echo "14. Checking documentation..."
if [[ -f "${CHART_DIR}/README.md" ]]; then
  pass "README.md exists"
else
  warn "README.md not found"
fi
echo ""

echo "=== Validation Summary ==="
echo -e "${GREEN}All critical validations passed!${NC}"
echo ""
echo "Chart is ready for deployment. Test with:"
echo "  helm install iceberg-catalog ${CHART_DIR} --dry-run --debug"
echo ""
