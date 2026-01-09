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

# Service definitions (namespace:service-name format)
declare -A SERVICES=(
    ["ArgoCD"]="argocd:argocd-server"
    ["Trino"]="lakehouse-platform:trino"
    ["Airflow"]="lakehouse-platform:airflow-api-server"
    ["Grafana"]="lakehouse-platform:observability-grafana"
    ["Prometheus"]="lakehouse-platform:observability-kube-prometh-prometheus"
    ["MinIO"]="lakehouse-platform:minio"
    ["MinIO Console"]="lakehouse-platform:minio-console"
)

# Port mappings (host:container)
declare -A PORTS=(
    ["ArgoCD"]="30044:80"
    ["Trino"]="31280:8080"
    ["Airflow"]="33443:8080"
    ["Grafana"]="32300:80"
    ["Prometheus"]="32990:9090"
    ["MinIO"]="31100:9000"
    ["MinIO Console"]="31101:9001"
)

# Access URLs (replace YOUR_IP with actual machine IP for remote access)
declare -A URLS=(
    ["ArgoCD"]="http://YOUR_IP:30044 (admin: password from argocd-initial-admin-secret)"
    ["Trino"]="http://YOUR_IP:31280"
    ["Airflow"]="http://YOUR_IP:33443"
    ["Grafana"]="http://YOUR_IP:32300"
    ["Prometheus"]="http://YOUR_IP:32990"
    ["MinIO"]="http://YOUR_IP:31100"
    ["MinIO Console"]="http://YOUR_IP:31101"
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
        # Parse namespace and service name from "namespace:service-name" format
        local service_info="${SERVICES[$service]}"
        local namespace=$(echo "$service_info" | cut -d':' -f1)
        local name=$(echo "$service_info" | cut -d':' -f2)

        if kubectl get service "$name" -n "$namespace" &> /dev/null; then
            print_success "$service service found"
        else
            print_warning "$service service not found (namespace: $namespace, name: $name)"
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
        local service_info="${SERVICES[$service]}"
        local namespace=$(echo "$service_info" | cut -d':' -f1)
        local name=$(echo "$service_info" | cut -d':' -f2)

        # All services use 0.0.0.0 for external access
        kubectl port-forward -n "$namespace" "svc/$name" "${PORTS[$service]}" --address 0.0.0.0 &
        sleep 1
    done

    echo ""
    print_success "All port-forwards started!"
    echo ""

    # Get machine IP address
    MACHINE_IP=$(hostname -I | awk '{print $1}')
    if [ -z "$MACHINE_IP" ]; then
        MACHINE_IP="YOUR_IP"
    fi

    # Print URLs
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}  Access URLs${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo ""
    echo -e "${YELLOW}Machine IP: ${MACHINE_IP}${NC}"
    echo ""

    for service in "${!URLS[@]}"; do
        local url="${URLS[$service]}"
        # All services use external IP for browser access
        url="${url//YOUR_IP/$MACHINE_IP}"
        echo -e "${BLUE}•${NC} $service: $url"
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
