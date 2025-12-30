#!/bin/bash
# Lakehouse Platform Cleanup Script
#
# This script tears down the Lakehouse platform.
#
# Usage:
#   ./scripts/cleanup.sh [environment]
#
# Arguments:
#   environment - Target environment: dev, staging, or prod (default: dev)

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
ENVIRONMENT="${1:-dev}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
TERRAFORM_DIR="${PROJECT_ROOT}/infra"
ENV_VARS_FILE="${PROJECT_ROOT}/env/${ENVIRONMENT}/terraform.tfvars"
ARGOCD_NAMESPACE="argocd"
PLATFORM_NAMESPACE="lakehouse-platform"

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
    echo "  Lakehouse Platform Cleanup"
    echo "=========================================="
    echo ""
    echo "Environment: ${ENVIRONMENT}"
    echo ""
    echo "WARNING: This will delete all resources!"
    echo ""
}

# Confirm cleanup
confirm_cleanup() {
    read -p "Are you sure you want to cleanup ${ENVIRONMENT}? (yes/no): " -r
    echo
    if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
        log_info "Cleanup cancelled"
        exit 0
    fi
}

# Delete ArgoCD applications
delete_applications() {
    log_info "Deleting ArgoCD applications..."
    
    if kubectl get namespace "${ARGOCD_NAMESPACE}" &> /dev/null; then
        kubectl delete applications --all -n "${ARGOCD_NAMESPACE}" --wait=false || true
        log_success "ArgoCD applications deleted"
    else
        log_warn "ArgoCD namespace not found, skipping application deletion"
    fi
    
    echo ""
}

# Delete ArgoCD
delete_argocd() {
    log_info "Deleting ArgoCD..."
    
    if helm list -n "${ARGOCD_NAMESPACE}" | grep -q argocd; then
        helm uninstall argocd -n "${ARGOCD_NAMESPACE}" --wait || true
        log_success "ArgoCD uninstalled"
    else
        log_warn "ArgoCD not found, skipping"
    fi
    
    # Delete namespace
    if kubectl get namespace "${ARGOCD_NAMESPACE}" &> /dev/null; then
        kubectl delete namespace "${ARGOCD_NAMESPACE}" --wait=false || true
        log_success "ArgoCD namespace deleted"
    fi
    
    echo ""
}

# Delete platform namespace
delete_platform_namespace() {
    log_info "Deleting platform namespace..."
    
    if kubectl get namespace "${PLATFORM_NAMESPACE}" &> /dev/null; then
        kubectl delete namespace "${PLATFORM_NAMESPACE}" --wait=false || true
        log_success "Platform namespace deleted"
    else
        log_warn "Platform namespace not found"
    fi
    
    echo ""
}

# Destroy infrastructure
destroy_infrastructure() {
    log_info "Destroying infrastructure with Terraform..."
    
    if [ -d "${TERRAFORM_DIR}" ]; then
        cd "${TERRAFORM_DIR}"
        
        # Destroy Terraform resources
        terraform destroy -var-file="${ENV_VARS_FILE}" -auto-approve || log_error "Terraform destroy failed"
        
        log_success "Infrastructure destroyed"
        
        cd "${PROJECT_ROOT}"
    else
        log_warn "Terraform directory not found: ${TERRAFORM_DIR}"
    fi
    
    echo ""
}

# Main execution
main() {
    print_banner
    confirm_cleanup
    
    delete_applications
    delete_argocd
    delete_platform_namespace
    destroy_infrastructure
    
    log_success "Cleanup completed successfully!"
}

# Run main function
main "$@"
