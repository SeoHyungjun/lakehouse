#!/bin/bash
#
# Port-forward script for all Lakehouse platform services
#
# This script forwards all necessary ports to access the platform locally.
# Run with: ./scripts/port-forward-all.sh
#
# Stop all port-forwards: Ctrl+C or killall kubectl

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Service definitions
declare -A SERVICES=(
    ["ArgoCD"]="argocd svc/argocd-server 30044:443"
    ["Trino"]="lakehouse-platform svc/trino 31280:8080"
    ["Airflow"]="lakehouse-platform svc/airflow-api-server 33443:8080"
    ["Grafana"]="lakehouse-platform svc/observability-grafana 32300:80"
    ["Prometheus"]="lakehouse-platform svc/observability-kube-prometheus-prometheus 32990:9090"
    ["MinIO"]="lakehouse-platform svc/minio 31100:9000"
    ["MinIO Console"]="lakehouse-platform svc/minio-console 31101:9001"
)

# URLs for services
declare -A URLS=(
    ["ArgoCD"]="https://localhost:30044"
    ["Trino"]="http://localhost:31280/ui/"
    ["Airflow"]="http://localhost:33443"
    ["Grafana"]="http://localhost:32300"
    ["Prometheus"]="http://localhost:32990"
    ["MinIO S3"]="http://localhost:31100"
    ["MinIO Console"]="http://localhost:31101"
)

# Function to print colored output
print_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    print_error "kubectl is not installed or not in PATH"
    exit 1
fi

# Check if services exist
check_services() {
    print_info "Checking services availability..."
    local all_ready=true

    for service in "${!SERVICES[@]}"; do
        local namespace=$(echo "${SERVICES[$service]}" | awk '{print $1}')
        local name=$(echo "${SERVICES[$service]}" | awk '{print $2}')

        if kubectl get service "$name" -n "$namespace" &> /dev/null; then
            print_success "$service service found"
        else
            print_warning "$service service not found (namespace: $namespace)"
            all_ready=false
        fi
    done

    if [ "$all_ready" = false ]; then
        print_warning "Some services are not available. Check your deployment."
    fi
}

# Cleanup function to kill background processes on exit
cleanup() {
    print_info "Stopping all port-forwards..."
    jobs -p | xargs -r kill 2>/dev/null || true
    wait 2>/dev/null || true
    print_success "All port-forwards stopped"
}

# Set trap to cleanup on script exit
trap cleanup EXIT INT TERM

# Main execution
main() {
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}  Lakehouse Platform Port-Forwarding${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo ""

    check_services
    echo ""

    print_info "Starting port-forwards..."
    echo ""

    # Start port-forward for each service
    for service in "${!SERVICES[@]}"; do
        print_info "Starting $service..."
        kubectl port-forward -n ${SERVICES[$service]} &
        sleep 1
    done

    echo ""
    print_success "All port-forwards started!"
    echo ""

    # Print URLs
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}  Access URLs${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo ""

    for service in "${!URLS[@]}"; do
        echo -e "${BLUE}•${NC} $service: ${URLS[$service]}"
    done

    echo ""
    print_info "Press Ctrl+C to stop all port-forwards"
    print_info "Or run: killall kubectl"
    echo ""

    # Wait for all background jobs
    wait
}

# Run main function
main "$@"
