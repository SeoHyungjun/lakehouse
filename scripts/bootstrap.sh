#!/bin/bash
# Lakehouse Platform Bootstrap Script
# 
# This script bootstraps a complete Lakehouse platform from Git.
# Per README.md section 10: Reproducibility Guarantee
#
# Usage:
#   ./scripts/bootstrap.sh [environment]
#
# Arguments:
#   environment - Target environment: dev, staging, or prod (default: dev)
#
# Requirements:
#   - Git
#   - Terraform >= 1.5.0
#   - Helm >= 3.8.0
#   - kubectl >= 1.28.0
#   - kind (for local development)

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
PLATFORM_DIR="${PROJECT_ROOT}/platform"
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

# Error handler
error_exit() {
    log_error "$1"
    exit 1
}

# Print banner
print_banner() {
    echo ""
    echo "=========================================="
    echo "  Lakehouse Platform Bootstrap"
    echo "=========================================="
    echo ""
    echo "Environment: ${ENVIRONMENT}"
    echo "Project Root: ${PROJECT_ROOT}"
    echo ""
}

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    # Check Git
    if ! command -v git &> /dev/null; then
        error_exit "Git is not installed. Please install Git."
    fi
    log_success "Git: $(git --version)"
    
    # Check Terraform
    if ! command -v terraform &> /dev/null; then
        error_exit "Terraform is not installed. Please install Terraform >= 1.5.0"
    fi
    TERRAFORM_VERSION=$(terraform version | head -n1 | awk '{print $2}')
    log_success "Terraform: ${TERRAFORM_VERSION}"
    
    # Check Helm
    if ! command -v helm &> /dev/null; then
        error_exit "Helm is not installed. Please install Helm >= 3.8.0"
    fi
    HELM_VERSION=$(helm version --short)
    log_success "Helm: ${HELM_VERSION}"
    
    # Check kubectl
    if ! command -v kubectl &> /dev/null; then
        error_exit "kubectl is not installed. Please install kubectl >= 1.28.0"
    fi
    KUBECTL_VERSION=$(kubectl version --client --short 2>/dev/null || kubectl version --client)
    log_success "kubectl: ${KUBECTL_VERSION}"
    
    # Check kind (for dev environment)
    if [ "${ENVIRONMENT}" = "dev" ]; then
        if ! command -v kind &> /dev/null; then
            error_exit "kind is not installed. Please install kind for local development."
        fi
        KIND_VERSION=$(kind version)
        log_success "kind: ${KIND_VERSION}"
    fi
    
    echo ""
}

# Validate environment
validate_environment() {
    log_info "Validating environment configuration..."
    
    if [ ! -d "${TERRAFORM_DIR}" ]; then
        error_exit "Terraform directory not found: ${TERRAFORM_DIR}"
    fi
    
    if [ ! -d "${PLATFORM_DIR}" ]; then
        error_exit "Platform directory not found: ${PLATFORM_DIR}"
    fi
    
    # Check for required Terraform files
    if [ ! -f "${TERRAFORM_DIR}/main.tf" ]; then
        error_exit "Terraform main.tf not found in ${TERRAFORM_DIR}"
    fi
    
    # Check for environment-specific variables file
    if [ ! -f "${ENV_VARS_FILE}" ]; then
        error_exit "Environment variables file not found: ${ENV_VARS_FILE}"
    fi
    
    log_success "Environment configuration validated"
    echo ""
}

# Step 1: Provision infrastructure with Terraform
provision_infrastructure() {
    log_info "Step 1: Provisioning infrastructure with Terraform..."

    cd "${TERRAFORM_DIR}"

    # Initialize Terraform
    log_info "Initializing Terraform..."
    terraform init || error_exit "Terraform init failed"

    # Validate Terraform configuration
    log_info "Validating Terraform configuration..."
    terraform validate || error_exit "Terraform validation failed"

    if [ "${ENVIRONMENT}" = "dev" ]; then
        # For dev environment, apply in two stages to avoid rate limits:
        # 1. Create cluster first
        # 2. Pull and load images
        # 3. Apply remaining resources

        log_info "Applying cluster resources..."
        terraform apply -var-file="${ENV_VARS_FILE}" -target=module.cluster.kind_cluster.this -auto-approve || error_exit "Terraform apply (cluster) failed"

        # Pre-load required Docker images to avoid rate limits
        log_info "Pre-loading Docker images to avoid rate limits..."

        # Define required images
        IMAGES=(
            # Infrastructure components
            "docker.io/bitnami/sealed-secrets-controller:0.34.0"
            "docker.io/bitnami/postgresql@sha256:9c706432c2c75663aad68eef7eb73e40b5736ad888c8c45b5b09df2c3f31f78b"
            "quay.io/argoproj/argocd:v2.9.3"
            "quay.io/minio/minio:RELEASE.2023-09-30T07-02-29Z"
            "quay.io/minio/mc:RELEASE.2023-09-29T16-41-22Z"

            # Platform components
            "docker.io/tabulario/iceberg-rest:1.6.0"
            "docker.io/trinodb/trino:440"
            "docker.io/apache/airflow:3.1.5-python3.13"

            # Observability components (Prometheus, Grafana, etc.)
            "quay.io/prometheus/prometheus:v2.48.0"
            "docker.io/grafana/grafana:10.2.2"
            "quay.io/kiwigrid/k8s-sidecar:1.25.2"
            "docker.io/library/busybox:1.31.1"
            "docker.io/curlimages/curl:7.85.0"
            "quay.io/prometheus/alertmanager:v0.26.0"
            "quay.io/prometheus/node-exporter:v1.7.0"
            "quay.io/prometheus-operator/prometheus-operator:v0.70.0"
            "quay.io/prometheus-operator/prometheus-config-reloader:v0.70.0"
        )

        # Pull images that don't exist locally
        for image in "${IMAGES[@]}"; do
            # Normalize image name for comparison (remove docker.io/ and library/)
            image_name=$(echo "$image" | sed 's|docker.io/||' | sed 's|library/||')
            if ! docker images --format '{{.Repository}}:{{.Tag}}' | grep -q "$image_name"; then
                log_info "Pulling $image..."
                docker pull "$image" || log_warn "Failed to pull $image"
            else
                log_info "$image already exists, skipping pull"
            fi
        done

        # Load images into kind cluster
        for image in "${IMAGES[@]}"; do
            log_info "Loading $image into kind cluster..."
            kind load docker-image "$image" --name "lakehouse-${ENVIRONMENT}" || log_warn "Failed to load $image"
        done

        log_success "Docker images pre-loaded"

        # Apply remaining resources
        log_info "Applying remaining infrastructure resources..."
        terraform apply -var-file="${ENV_VARS_FILE}" -auto-approve || error_exit "Terraform apply (remaining) failed"
    else
        # For non-dev environments, apply everything at once
        log_info "Planning Terraform changes..."
        terraform plan -var-file="${ENV_VARS_FILE}" -out=tfplan || error_exit "Terraform plan failed"

        log_info "Applying Terraform changes..."
        terraform apply tfplan || error_exit "Terraform apply failed"

        # Clean up plan file
        rm -f tfplan
    fi

    log_success "Infrastructure provisioned successfully"
    echo ""

    cd "${PROJECT_ROOT}"
}

# Step 2: Configure kubectl context
configure_kubectl() {
    log_info "Step 2: Configuring kubectl context..."
    
    if [ "${ENVIRONMENT}" = "dev" ]; then
        # For kind cluster
        CLUSTER_NAME="lakehouse-${ENVIRONMENT}"
        
        # Get kubeconfig from kind
        kind get kubeconfig --name "${CLUSTER_NAME}" > /dev/null 2>&1 || \
            error_exit "Failed to get kubeconfig from kind cluster"
        
        # Set context
        kubectl config use-context "kind-${CLUSTER_NAME}" || \
            error_exit "Failed to set kubectl context"
    else
        # For cloud clusters, kubeconfig should be set by Terraform output
        log_warn "For ${ENVIRONMENT}, ensure kubeconfig is configured via Terraform output"
    fi
    
    # Verify cluster connection
    log_info "Verifying cluster connection..."
    kubectl cluster-info || error_exit "Cannot connect to Kubernetes cluster"
    
    log_success "kubectl configured successfully"
    echo ""
}

# Step 3: Install ArgoCD
install_argocd() {
    log_info "Step 3: Installing ArgoCD..."
    
    cd "${PLATFORM_DIR}/argocd"
    
    # Add ArgoCD Helm repository
    log_info "Adding ArgoCD Helm repository..."
    helm repo add argo https://argoproj.github.io/argo-helm 2>/dev/null || true
    helm repo update
    
    # Update Helm dependencies
    log_info "Updating Helm dependencies..."
    helm dependency update .
    
    # Step 1: Install ArgoCD Core (without Applications) to setup CRDs
    log_info "Installing ArgoCD Core (skipping applications for CRD setup)..."
    helm upgrade --install argocd . \
        --namespace "${ARGOCD_NAMESPACE}" \
        --create-namespace \
        --values "values-${ENVIRONMENT}.yaml" \
        --set installApps=false \
        --wait \
        --timeout 10m || error_exit "ArgoCD Core installation failed"

    # Step 2: Install Applications
    log_info "Installing ArgoCD Applications..."
    helm upgrade --install argocd . \
        --namespace "${ARGOCD_NAMESPACE}" \
        --values "values-${ENVIRONMENT}.yaml" \
        --set installApps=true \
        --wait \
        --timeout 5m || error_exit "ArgoCD Application installation failed"
    
    log_success "ArgoCD installed successfully"
    echo ""
    
    cd "${PROJECT_ROOT}"
}

# Step 4: Wait for ArgoCD to be ready
wait_for_argocd() {
    log_info "Step 4: Waiting for ArgoCD to be ready..."
    
    # Wait for ArgoCD server deployment
    kubectl rollout status deployment/argocd-server -n "${ARGOCD_NAMESPACE}" --timeout=300s || error_exit "ArgoCD server not ready"
    
    # Wait for ArgoCD application controller (StatefulSet)
    kubectl rollout status statefulset/argocd-application-controller -n "${ARGOCD_NAMESPACE}" --timeout=300s || error_exit "ArgoCD controller not ready"
    
    # Wait for ArgoCD repo server
    kubectl rollout status deployment/argocd-repo-server -n "${ARGOCD_NAMESPACE}" --timeout=300s || error_exit "ArgoCD repo server not ready"
    
    log_success "ArgoCD is ready"
    echo ""
}

# Step 5: Get ArgoCD admin password
get_argocd_password() {
    log_info "Step 5: Retrieving ArgoCD admin password..."
    
    # Wait for secret to be created
    sleep 5
    
    ARGOCD_PASSWORD=$(kubectl -n "${ARGOCD_NAMESPACE}" get secret argocd-initial-admin-secret \
        -o jsonpath="{.data.password}" 2>/dev/null | base64 -d || echo "")
    
    if [ -z "${ARGOCD_PASSWORD}" ]; then
        log_warn "Could not retrieve ArgoCD password automatically"
        log_info "Retrieve it manually with:"
        log_info "  kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath=\"{.data.password}\" | base64 -d"
    else
        log_success "ArgoCD admin password retrieved"
        echo ""
        echo "=========================================="
        echo "  ArgoCD Credentials"
        echo "=========================================="
        echo "Username: admin"
        echo "Password: ${ARGOCD_PASSWORD}"
        echo "=========================================="
        echo ""
    fi
}

# Step 6: Sync ArgoCD applications
sync_argocd_applications() {
    log_info "Step 6: Syncing ArgoCD applications..."
    
    # Wait a bit for Applications to be created
    sleep 10
    
    # Check if argocd CLI is available
    if command -v argocd &> /dev/null; then
        log_info "Using ArgoCD CLI to sync applications..."
        
        # Port-forward to ArgoCD server
        kubectl port-forward svc/argocd-server -n "${ARGOCD_NAMESPACE}" 30044:443 > /dev/null 2>&1 &
        PORT_FORWARD_PID=$!

        # Wait for port-forward to be ready
        log_info "Waiting for port-forward to be ready..."
        for i in {1..30}; do
            if curl -k -s https://localhost:30044/healthz > /dev/null 2>&1; then
                break
            fi
            sleep 1
        done

        # Login to ArgoCD
        log_info "Logging in to ArgoCD..."
        ARGOCD_OPTS="--grpc-web" argocd login localhost:30044 \
            --username admin \
            --password "${ARGOCD_PASSWORD}" \
            --insecure || log_warn "ArgoCD CLI login failed"

        # Sync all applications
        log_info "Syncing all applications..."
        argocd app sync --all || log_warn "Some applications failed to sync"
        
        # Kill port-forward
        kill ${PORT_FORWARD_PID} 2>/dev/null || true
    else
        log_warn "ArgoCD CLI not found. Applications will sync automatically."
        log_info "Install ArgoCD CLI for manual control:"
        log_info "  brew install argocd  # macOS"
        log_info "  Or download from: https://github.com/argoproj/argo-cd/releases"
    fi
    
    log_success "ArgoCD applications synced"
    echo ""
}

# Step 7: Verify deployment
verify_deployment() {
    log_info "Step 7: Verifying deployment..."
    
    # Check ArgoCD applications
    log_info "Checking ArgoCD applications..."
    kubectl get applications -n "${ARGOCD_NAMESPACE}" || log_warn "No applications found"
    
    # Check platform namespace
    log_info "Checking platform namespace..."
    kubectl get namespace "${PLATFORM_NAMESPACE}" || log_warn "Platform namespace not found"
    
    # Check pods in platform namespace
    log_info "Checking platform pods..."
    kubectl get pods -n "${PLATFORM_NAMESPACE}" || log_warn "No pods found in platform namespace"
    
    log_success "Deployment verification complete"
    echo ""
}

# Print next steps
print_next_steps() {
    echo ""
    echo "=========================================="
    echo "  Bootstrap Complete!"
    echo "=========================================="
    echo ""
    echo "Next steps:"
    echo ""
    echo "1. Access ArgoCD UI:"
    echo "   kubectl port-forward svc/argocd-server -n argocd 30044:443"
    echo "   Navigate to: https://localhost:30044"
    echo "   Username: admin"
    echo "   Password: ${ARGOCD_PASSWORD:-<see above>}"
    echo ""
    echo "2. Access Grafana (once observability is synced):"
    echo "   kubectl port-forward svc/observability-grafana -n lakehouse-platform 32300:80"
    echo "   Navigate to: http://localhost:32300"
    echo ""
    echo "3. Check application status:"
    echo "   kubectl get applications -n argocd"
    echo "   argocd app list"
    echo ""
    echo "4. View platform components:"
    echo "   kubectl get all -n lakehouse-platform"
    echo ""
    echo "=========================================="
    echo ""
}

# Main execution
main() {
    print_banner
    check_prerequisites
    validate_environment
    
    # Execute bootstrap steps
    provision_infrastructure
    configure_kubectl
    install_argocd
    wait_for_argocd
    get_argocd_password
    sync_argocd_applications
    verify_deployment
    
    print_next_steps
    
    log_success "Lakehouse platform bootstrap completed successfully!"
}

# Run main function
main "$@"
