#!/bin/bash
# End-to-End Test Runner
# Runs all E2E tests for the Lakehouse platform

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEST_RESULTS_FILE="${SCRIPT_DIR}/test-results.xml"
COVERAGE_DIR="${SCRIPT_DIR}/htmlcov"

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Print banner
print_banner() {
    echo ""
    echo "=========================================="
    echo "  Lakehouse E2E Test Suite"
    echo "=========================================="
    echo ""
}

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    # Check Python
    if ! command -v python3 &> /dev/null; then
        log_error "Python 3 is not installed"
        exit 1
    fi
    log_success "Python: $(python3 --version)"
    
    # Check pytest
    if ! python3 -c "import pytest" 2>/dev/null; then
        log_warn "pytest not installed, installing dependencies..."
        pip install -r "${SCRIPT_DIR}/requirements.txt"
    fi
    log_success "pytest is available"
    
    echo ""
}

# Setup port forwards (optional)
setup_port_forwards() {
    log_info "Setting up port forwards..."
    
    # Kill existing port-forwards
    pkill -f "port-forward.*lakehouse-platform" || true
    sleep 2

    # Port-forward MinIO
    kubectl port-forward -n lakehouse-platform svc/minio 31100:9000 > /dev/null 2>&1 &

    # Port-forward Trino
    kubectl port-forward -n lakehouse-platform svc/trino 31280:8080 > /dev/null 2>&1 &

    # Port-forward Iceberg Catalog
    kubectl port-forward -n lakehouse-platform svc/iceberg-catalog 31881:8181 > /dev/null 2>&1 &

    # Port-forward Sample Service
    kubectl port-forward -n lakehouse-platform svc/sample-service 31882:80 > /dev/null 2>&1 &
    
    # Wait for port-forwards to be ready
    sleep 5
    
    log_success "Port forwards established"
    echo ""
}

# Run tests
run_tests() {
    log_info "Running E2E tests..."
    
    cd "${SCRIPT_DIR}"
    
    # Run pytest with coverage and JUnit XML output
    pytest \
        -v \
        --tb=short \
        --junitxml="${TEST_RESULTS_FILE}" \
        --cov=. \
        --cov-report=html \
        --cov-report=term \
        "$@"
    
    TEST_EXIT_CODE=$?
    
    echo ""
    
    if [ ${TEST_EXIT_CODE} -eq 0 ]; then
        log_success "All tests passed!"
    else
        log_error "Some tests failed"
    fi
    
    return ${TEST_EXIT_CODE}
}

# Print results
print_results() {
    echo ""
    echo "=========================================="
    echo "  Test Results"
    echo "=========================================="
    
    if [ -f "${TEST_RESULTS_FILE}" ]; then
        log_info "JUnit XML: ${TEST_RESULTS_FILE}"
    fi
    
    if [ -d "${COVERAGE_DIR}" ]; then
        log_info "Coverage report: ${COVERAGE_DIR}/index.html"
    fi
    
    echo ""
}

# Cleanup
cleanup() {
    if [ "${CLEANUP_PORT_FORWARDS:-false}" = "true" ]; then
        log_info "Cleaning up port forwards..."
        pkill -f "port-forward.*lakehouse-platform" || true
    fi
}

# Trap cleanup on exit
trap cleanup EXIT

# Main execution
main() {
    print_banner
    check_prerequisites
    
    # Parse arguments
    SETUP_PORT_FORWARDS=false
    CLEANUP_PORT_FORWARDS=false
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --setup-port-forwards)
                SETUP_PORT_FORWARDS=true
                CLEANUP_PORT_FORWARDS=true
                shift
                ;;
            *)
                # Pass remaining args to pytest
                break
                ;;
        esac
    done
    
    # Setup port forwards if requested
    if [ "${SETUP_PORT_FORWARDS}" = "true" ]; then
        setup_port_forwards
    fi
    
    # Run tests
    run_tests "$@"
    TEST_EXIT_CODE=$?
    
    # Print results
    print_results
    
    exit ${TEST_EXIT_CODE}
}

# Run main function
main "$@"
