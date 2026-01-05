#!/bin/bash
set -euo pipefail

# ============================================================================
# Secret Generation Script
# ============================================================================
# This script reads secrets from .env, generates Kubernetes Secrets,
# and seals them using kubeseal.
#
# The output is SealedSecret manifests stored in the platform/ directory.
# These manifests are safe to commit to Git.
#
# Usage: ./scripts/generate-secrets.sh
# ============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
ENV_FILE="${ROOT_DIR}/.env"

# Configuration
SEALED_SECRETS_CONTROLLER="sealed-secrets-controller"
SEALED_SECRETS_NAMESPACE="sealed-secrets"
PLATFORM_NAMESPACE="lakehouse-platform"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# 1. Validation
if [ ! -f "$ENV_FILE" ]; then
    log_error ".env file not found at ${ENV_FILE}"
    echo "Please copy .env.example to .env and fill in your secrets."
    exit 1
fi

if ! command -v kubeseal &> /dev/null; then
    log_error "kubeseal binary not found. Please install via brew install kubeseal or download from GitHub."
    exit 1
fi

# Load env vars
set -a
source "$ENV_FILE"
set +a

# Helper function
generate_sealed_secret() {
    local secret_name=$1
    local output_file=$2
    local namespace=$3 # Target namespace for the secret
    shift 3
    local literal_args=("$@")

    log_info "Sealing secret '${secret_name}'..."

    mkdir -p "$(dirname "${output_file}")"

    kubectl create secret generic "${secret_name}" \
        --dry-run=client \
        --namespace "${namespace}" \
        -o yaml \
        "${literal_args[@]}" \
        | kubeseal \
            --controller-name "${SEALED_SECRETS_CONTROLLER}" \
            --controller-namespace "${SEALED_SECRETS_NAMESPACE}" \
            --format yaml \
            > "${output_file}"

    if [ $? -eq 0 ]; then
        log_info "Generated ${output_file}"
    else
        log_error "Failed to generate ${output_file}"
        exit 1
    fi
}

# 2. Generate Secrets

# --- MinIO ---
generate_sealed_secret "minio-creds" \
    "${ROOT_DIR}/platform/minio/templates/sealed-secret.yaml" \
    "${PLATFORM_NAMESPACE}" \
    --from-literal=rootUser="${MINIO_ROOT_USER}" \
    --from-literal=rootPassword="${MINIO_ROOT_PASSWORD}" \
    --from-literal=accessKeyId="${MINIO_ROOT_USER}" \
    --from-literal=secretAccessKey="${MINIO_ROOT_PASSWORD}"

# --- Postgres (Shared) ---
# Used by Airflow and Catalog
generate_sealed_secret "postgres-creds" \
    "${ROOT_DIR}/platform/iceberg-catalog/templates/postgres-sealed-secret.yaml" \
    "${PLATFORM_NAMESPACE}" \
    --from-literal=username="${POSTGRES_USER}" \
    --from-literal=password="${POSTGRES_PASSWORD}" \
    --from-literal=postgres-password="${POSTGRES_PASSWORD}"

# --- Airflow ---
generate_sealed_secret "airflow-webserver-secret" \
    "${ROOT_DIR}/platform/airflow/templates/webserver-sealed-secret.yaml" \
    "${PLATFORM_NAMESPACE}" \
    --from-literal=webserver-secret-key="${AIRFLOW_WEBSERVER_SECRET_KEY}"

generate_sealed_secret "airflow-fernet-key" \
    "${ROOT_DIR}/platform/airflow/templates/fernet-sealed-secret.yaml" \
    "${PLATFORM_NAMESPACE}" \
    --from-literal=fernet-key="${AIRFLOW_FERNET_KEY}"

# Airflow DB Connection String (to avoid inline password in values)
# Note: Hostname assumes release name 'airflow' and namespace 'lakehouse-platform'
AIRFLOW_DB_HOST="airflow-postgresql.lakehouse-platform"
AIRFLOW_CONN_STRING="postgresql://${POSTGRES_USER}:${POSTGRES_PASSWORD}@${AIRFLOW_DB_HOST}:5432/airflow"

generate_sealed_secret "airflow-db-connection" \
    "${ROOT_DIR}/platform/airflow/templates/db-connection-sealed-secret.yaml" \
    "${PLATFORM_NAMESPACE}" \
    --from-literal=connection="${AIRFLOW_CONN_STRING}"


log_info "All secrets generated successfully!"
echo "Don't forget to commit the new SealedSecret YAML files."
