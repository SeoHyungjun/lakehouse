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

# Helper to remove finalizers
remove_finalizers() {
    local resource_type=$1
    local namespace=$2
    
    log_info "Removing finalizers from ${resource_type} in ${namespace}..."
    
    # Get all resources of type and patch them
    kubectl get "${resource_type}" -n "${namespace}" -o name 2>/dev/null | while read -r resource; do
        log_info "Patching finalizers for ${resource}..."
        kubectl patch "${resource}" -n "${namespace}" -p '{"metadata":{"finalizers":[]}}' --type=merge || true
    done
}

# Delete ArgoCD applications
delete_applications() {
    log_info "Deleting ArgoCD applications..."
    
    if kubectl get namespace "${ARGOCD_NAMESPACE}" &> /dev/null; then
        # Try graceful deletion first
        kubectl delete applications --all -n "${ARGOCD_NAMESPACE}" --timeout=30s --wait=true 2>/dev/null || true
        
        # Force remove finalizers if still lingering
        remove_finalizers "applications.argoproj.io" "${ARGOCD_NAMESPACE}"
        
        log_success "ArgoCD applications deleted"
    else
        log_warn "ArgoCD namespace not found, skipping application deletion"
    fi
    
    echo ""
}

# Delete ArgoCD
delete_argocd() {
    log_info "Deleting ArgoCD..."
    
    # Try Helm uninstall
    if helm list -n "${ARGOCD_NAMESPACE}" | grep -q argocd; then
        helm uninstall argocd -n "${ARGOCD_NAMESPACE}" --timeout=2m --wait || true
    fi
    
    # Force cleanup custom resources if Helm failed to clear them
    if kubectl get namespace "${ARGOCD_NAMESPACE}" &> /dev/null; then
        remove_finalizers "appprojects.argoproj.io" "${ARGOCD_NAMESPACE}"
        remove_finalizers "applicationsets.argoproj.io" "${ARGOCD_NAMESPACE}"
        
        # Delete namespace with timeout
        kubectl delete namespace "${ARGOCD_NAMESPACE}" --timeout=60s --wait=true 2>/dev/null || true
        
        # If namespace still exists (Terminating), create a background cleaner to force it
        if kubectl get namespace "${ARGOCD_NAMESPACE}" &> /dev/null; then
             log_warn "Namespace stuck in Terminating. Attempting force cleanup..."
             kubectl get namespace "${ARGOCD_NAMESPACE}" -o json | tr -d "\n" | sed "s/\"kubernetes\"//g" | kubectl replace --raw "/api/v1/namespaces/${ARGOCD_NAMESPACE}/finalize" -f - || true
        fi
    fi
    
    log_success "ArgoCD cleanup completed"
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
        # We use force cleanup so we don't worry about lingering resources
        log_info "Running terraform destroy..."
        if ! terraform destroy -var-file="${ENV_VARS_FILE}" -auto-approve; then
            log_warn "Terraform destroy failed or timed out. Forcing cluster deletion..."
            kind delete cluster --name "lakehouse-${ENVIRONMENT}" || true
        fi
        
        # Clean up local state files to ensure fresh start
        log_info "Cleaning up local Terraform state and config files..."
        rm -f terraform.tfstate*
        rm -f .terraform.tfstate.lock.info
        rm -f .kubeconfig-lakehouse-${ENVIRONMENT}
        
        # Go back to project root and remove symlinked kubeconfig if exists
        cd "${PROJECT_ROOT}"
        rm -f ".kubeconfig-lakehouse-${ENVIRONMENT}"
        
        log_success "Infrastructure destroyed and local state cleaned"
    else
        log_warn "Terraform directory not found: ${TERRAFORM_DIR}"
    fi
    
    echo ""
}

# Main execution
main() {
    print_banner
    confirm_cleanup
    
    # In DEV environment, we prioritize speed and clean slate
    # So we skip graceful deletion of apps and namespaces which often hang
    # and go straight to destroying the infrastructure (cluster).
    if [ "${ENVIRONMENT}" == "dev" ]; then
        log_info "DEV environment detected. Performing FORCE cleanup..."
        destroy_infrastructure
    else
        # For non-dev environments, try graceful cleanup first
        delete_applications
        delete_argocd
        delete_platform_namespace
        destroy_infrastructure
    fi
    
    log_success "Cleanup completed successfully!"
}

# Run main function
main "$@"
