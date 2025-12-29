#!/bin/bash
# Test script for Sample Service
# Verifies health endpoints and basic API functionality

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
SERVICE_URL="${SERVICE_URL:-http://localhost:8080}"

PASS=0
FAIL=0

# Test functions
pass() {
    echo -e "${GREEN}✓${NC} $1"
    ((PASS++))
}

fail() {
    echo -e "${RED}✗${NC} $1"
    ((FAIL++))
}

echo "=========================================="
echo "Sample Service Tests"
echo "=========================================="
echo "Service URL: ${SERVICE_URL}"
echo ""

# Test 1: Health endpoint
echo "1. Testing /health endpoint..."
RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" "${SERVICE_URL}/health")
if [ "${RESPONSE}" = "200" ]; then
    pass "Health endpoint returns 200"
else
    fail "Health endpoint returned ${RESPONSE}, expected 200"
fi

# Test 2: Ready endpoint
echo "2. Testing /ready endpoint..."
RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" "${SERVICE_URL}/ready")
if [ "${RESPONSE}" = "200" ] || [ "${RESPONSE}" = "503" ]; then
    pass "Ready endpoint returns ${RESPONSE}"
else
    fail "Ready endpoint returned ${RESPONSE}, expected 200 or 503"
fi

# Test 3: Metrics endpoint
echo "3. Testing /metrics endpoint..."
RESPONSE=$(curl -s "${SERVICE_URL}/metrics")
if echo "${RESPONSE}" | grep -q "http_requests_total"; then
    pass "Metrics endpoint returns Prometheus metrics"
else
    fail "Metrics endpoint does not return expected metrics"
fi

# Test 4: List tables (empty)
echo "4. Testing GET /api/v1/tables..."
RESPONSE=$(curl -s "${SERVICE_URL}/api/v1/tables")
if echo "${RESPONSE}" | grep -q '"tables"'; then
    pass "List tables endpoint works"
else
    fail "List tables endpoint failed"
fi

# Test 5: Create table
echo "5. Testing POST /api/v1/tables..."
RESPONSE=$(curl -s -X POST "${SERVICE_URL}/api/v1/tables" \
    -H "Content-Type: application/json" \
    -d '{"name": "test_table", "namespace": "test", "schema": {"columns": [{"name": "id", "type": "int"}]}}')
if echo "${RESPONSE}" | grep -q '"id":"test.test_table"'; then
    pass "Create table endpoint works"
else
    fail "Create table endpoint failed"
fi

# Test 6: Get table
echo "6. Testing GET /api/v1/tables/test.test_table..."
RESPONSE=$(curl -s "${SERVICE_URL}/api/v1/tables/test.test_table")
if echo "${RESPONSE}" | grep -q '"name":"test_table"'; then
    pass "Get table endpoint works"
else
    fail "Get table endpoint failed"
fi

# Test 7: Update table
echo "7. Testing PUT /api/v1/tables/test.test_table..."
RESPONSE=$(curl -s -X PUT "${SERVICE_URL}/api/v1/tables/test.test_table" \
    -H "Content-Type: application/json" \
    -d '{"schema": {"columns": [{"name": "id", "type": "int"}, {"name": "name", "type": "string"}]}}')
if echo "${RESPONSE}" | grep -q '"name":"test_table"'; then
    pass "Update table endpoint works"
else
    fail "Update table endpoint failed"
fi

# Test 8: Delete table
echo "8. Testing DELETE /api/v1/tables/test.test_table..."
RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" -X DELETE "${SERVICE_URL}/api/v1/tables/test.test_table")
if [ "${RESPONSE}" = "204" ]; then
    pass "Delete table endpoint works"
else
    fail "Delete table endpoint returned ${RESPONSE}, expected 204"
fi

# Test 9: Get non-existent table (404)
echo "9. Testing GET /api/v1/tables/nonexistent..."
RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" "${SERVICE_URL}/api/v1/tables/nonexistent")
if [ "${RESPONSE}" = "404" ]; then
    pass "Non-existent table returns 404"
else
    fail "Non-existent table returned ${RESPONSE}, expected 404"
fi

echo ""
echo "=========================================="
echo "Test Summary"
echo "=========================================="
echo -e "${GREEN}Passed:${NC} ${PASS}"
echo -e "${RED}Failed:${NC} ${FAIL}"
echo ""

if [ ${FAIL} -eq 0 ]; then
    echo -e "${GREEN}✓ All tests passed!${NC}"
    exit 0
else
    echo -e "${RED}✗ Some tests failed.${NC}"
    exit 1
fi
