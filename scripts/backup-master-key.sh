#!/bin/bash
set -euo pipefail

# ============================================================================
# Backup Master Key Script
# ============================================================================
# This script extracts the Sealed Secrets controller's master key
# from the current cluster and saves it to a file.
#
# This file is critical for reproducing the environment on another machine.
#
# Usage: ./scripts/backup-master-key.sh [environment] [output_path]
# Example: ./scripts/backup-master-key.sh dev
# ============================================================================

ENVIRONMENT="${1:-dev}"
OUTPUT_PATH="${2:-env/${ENVIRONMENT}/master.key}"
NAMESPACE="sealed-secrets"
LABEL_SELECTOR="sealedsecrets.bitnami.com/sealed-secrets-key"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Check connectivity
if ! kubectl cluster-info &> /dev/null; then
    log_error "Cannot connect to Kubernetes cluster."
    exit 1
fi

log_info "Backing up Sealed Secrets master key from namespace '${NAMESPACE}'..."

# Extract key
# We use --dry-run=client -o yaml to strip managed fields and status
if kubectl get secret -n "${NAMESPACE}" -l "${LABEL_SELECTOR}" -o yaml > "${OUTPUT_PATH}"; then
    if [ ! -s "${OUTPUT_PATH}" ]; then
        log_error "Key file is empty. No master key found in cluster?"
        rm -f "${OUTPUT_PATH}"
        exit 1
    fi
    log_info "Master key saved to: ${OUTPUT_PATH}"
    log_warn "KEEP THIS FILE SAFE! Do not commit it to Git."
    log_warn "To restore on another machine, ensure 'master_key_path' in terraform.tfvars points to this file."
else
    log_error "Failed to Extract master key."
    exit 1
fi

# Verify gitignore
if ! grep -q "*.key" .gitignore; then
    log_warn "It looks like *.key is not gitignored. Please check .gitignore!"
fi
