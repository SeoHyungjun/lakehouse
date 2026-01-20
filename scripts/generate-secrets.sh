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

# ==============================================================================
# Platform Secrets (lakehouse-platform namespace)
# Stored in platform/secrets/
#
# Naming Convention: {service}-{purpose}-sealed-secret.yaml
# ==============================================================================

log_info "Generating platform secrets..."

# --- Airflow Secrets ---

# Airflow Webserver Secret Key
generate_sealed_secret "airflow-webserver-secret" \
    "${ROOT_DIR}/platform/secrets/airflow-webserver-secret-sealed-secret.yaml" \
    "${PLATFORM_NAMESPACE}" \
    --from-literal=webserver-secret-key="${AIRFLOW_WEBSERVER_SECRET_KEY}"

# Airflow Fernet Key for encryption
generate_sealed_secret "airflow-fernet-key" \
    "${ROOT_DIR}/platform/secrets/airflow-fernet-key-sealed-secret.yaml" \
    "${PLATFORM_NAMESPACE}" \
    --from-literal=fernet-key="${AIRFLOW_FERNET_KEY}"

# Airflow Admin User Credentials
# Airflow 3.0.2 requires: admin-user, admin-password
# Optional: admin-email, admin-firstname, admin-lastname
generate_sealed_secret "airflow-admin-password" \
    "${ROOT_DIR}/platform/secrets/airflow-admin-password-sealed-secret.yaml" \
    "${PLATFORM_NAMESPACE}" \
    --from-literal=admin-user="${AIRFLOW_ADMIN_USER}" \
    --from-literal=admin-password="${AIRFLOW_ADMIN_PASSWORD}" \
    ${AIRFLOW_ADMIN_EMAIL:+--from-literal=admin-email="${AIRFLOW_ADMIN_EMAIL}"} \
    ${AIRFLOW_ADMIN_FIRSTNAME:+--from-literal=admin-firstname="${AIRFLOW_ADMIN_FIRSTNAME}"} \
    ${AIRFLOW_ADMIN_LASTNAME:+--from-literal=admin-lastname="${AIRFLOW_ADMIN_LASTNAME}"}

# Airflow Database Connection String
# Note: Hostname assumes release name 'airflow' and namespace 'lakehouse-platform'
AIRFLOW_DB_HOST="airflow-postgresql.lakehouse-platform"
AIRFLOW_CONN_STRING="postgresql://${POSTGRES_USER}:${POSTGRES_PASSWORD}@${AIRFLOW_DB_HOST}:5432/airflow"

generate_sealed_secret "airflow-db-connection" \
    "${ROOT_DIR}/platform/secrets/airflow-db-connection-sealed-secret.yaml" \
    "${PLATFORM_NAMESPACE}" \
    --from-literal=connection="${AIRFLOW_CONN_STRING}"

# --- Observability Secrets ---

# Grafana Admin User Credentials
generate_sealed_secret "grafana-admin-password" \
    "${ROOT_DIR}/platform/secrets/grafana-admin-password-sealed-secret.yaml" \
    "${PLATFORM_NAMESPACE}" \
    --from-literal=admin-password="${GRAFANA_ADMIN_PASSWORD}" \
    --from-literal=admin-user="${GRAFANA_ADMIN_USER}"

# --- Infrastructure Secrets ---

# PostgreSQL Database Credentials
# Used by: Airflow, Iceberg Catalog
generate_sealed_secret "postgres-creds" \
    "${ROOT_DIR}/platform/secrets/postgres-creds-sealed-secret.yaml" \
    "${PLATFORM_NAMESPACE}" \
    --from-literal=username="${POSTGRES_USER}" \
    --from-literal=password="${POSTGRES_PASSWORD}" \
    --from-literal=postgres-password="${POSTGRES_PASSWORD}"

# MinIO Object Storage Credentials
# Used by: MinIO itself, Iceberg Catalog, Trino, Airflow DAGs
generate_sealed_secret "minio-creds" \
    "${ROOT_DIR}/platform/secrets/minio-creds-sealed-secret.yaml" \
    "${PLATFORM_NAMESPACE}" \
    --from-literal=rootUser="${MINIO_ROOT_USER}" \
    --from-literal=rootPassword="${MINIO_ROOT_PASSWORD}" \
    --from-literal=accessKeyId="${MINIO_ROOT_USER}" \
    --from-literal=secretAccessKey="${MINIO_ROOT_PASSWORD}" \
    --from-literal=MINIO_ENDPOINT_URL="${AIRFLOW_MINIO_ENDPOINT_URL}" \
    --from-literal=MINIO_BUCKET="${AIRFLOW_MINIO_BUCKET}"

# --- Airflow DAG Connections ---

# Airflow Connections for DAGs (PostgreSQL, AWS S3/MinIO)
# Loaded from .env file - see .env.example for format
# NOTE: AIRFLOW_CONN_AWS_DEFAULT __extra__ needs to be URL encoded for Airflow to parse correctly
# Convert JSON extra to URL-encoded format
AIRFLOW_CONN_AWS_DEFAULT_ENCODED=$(python3 -c "
import urllib.parse
import json
# Parse the connection URL
conn_str = '${AIRFLOW_CONN_AWS_DEFAULT}'
# Split into base and extra parts
if '__extra__=' in conn_str:
    base, extra = conn_str.split('__extra__=', 1)
    # URL encode the extra JSON
    extra_encoded = urllib.parse.quote(extra, safe='')
    encoded_url = base + '__extra__=' + extra_encoded
else:
    encoded_url = conn_str
print(encoded_url)
")

generate_sealed_secret "airflow-connections" \
    "${ROOT_DIR}/platform/secrets/airflow-connections-sealed-secret.yaml" \
    "${PLATFORM_NAMESPACE}" \
    --from-literal=AIRFLOW_CONN_POSTGRES_DEFAULT="${AIRFLOW_CONN_POSTGRES_DEFAULT}" \
    --from-literal=AIRFLOW_CONN_AWS_DEFAULT="${AIRFLOW_CONN_AWS_DEFAULT_ENCODED}"

# Airflow GitSync Credentials
# Used by GitSync to pull DAGs from lakehouse-dags repository
# Include both naming conventions for compatibility with different GitSync versions
generate_sealed_secret "git-sync-cred" \
    "${ROOT_DIR}/platform/secrets/git-sync-cred-sealed-secret.yaml" \
    "${PLATFORM_NAMESPACE}" \
    --from-literal=GITSYNC_USERNAME="${GITHUB_USERNAME}" \
    --from-literal=GITSYNC_PASSWORD="${GITHUB_TOKEN}" \
    --from-literal=GIT_SYNC_USERNAME="${GITHUB_USERNAME}" \
    --from-literal=GIT_SYNC_PASSWORD="${GITHUB_TOKEN}"

# Airflow DAG Environment Variables
# Used by DAGs for external service connections
# Infrastructure variables: AIRFLOW_ prefix (AIRFLOW_TRINO_*, AIRFLOW_POSTGRES_*)
# External service variables (KDP, OAuth, AZURE): system prefix (KDP_*, AZURE_*)
generate_sealed_secret "airflow-secrets" \
    "${ROOT_DIR}/platform/secrets/airflow-secrets-sealed-secret.yaml" \
    "${PLATFORM_NAMESPACE}" \
    --from-literal=AIRFLOW_TRINO_ENDPOINT_URL="${AIRFLOW_TRINO_ENDPOINT_URL}" \
    --from-literal=AIRFLOW_TRINO_CATALOG="${AIRFLOW_TRINO_CATALOG}" \
    --from-literal=AIRFLOW_TRINO_SCHEMA="${AIRFLOW_TRINO_SCHEMA}" \
    --from-literal=AIRFLOW_POSTGRES_HOST="${AIRFLOW_POSTGRES_HOST}" \
    --from-literal=AIRFLOW_POSTGRES_PORT="${AIRFLOW_POSTGRES_PORT}" \
    --from-literal=AIRFLOW_POSTGRES_DATABASE="${AIRFLOW_POSTGRES_DATABASE}" \
    --from-literal=AIRFLOW_POSTGRES_USERNAME="${AIRFLOW_POSTGRES_USERNAME}" \
    --from-literal=AIRFLOW_POSTGRES_PASSWORD="${AIRFLOW_POSTGRES_PASSWORD}" \
    --from-literal=KDP_REQUEST_URL="${KDP_REQUEST_URL}" \
    --from-literal=KDP_REGION="${KDP_REGION}" \
    --from-literal=KDP_OPT_TYPE="${KDP_OPT_TYPE}" \
    --from-literal=KDP_TOKEN_URL="${KDP_TOKEN_URL}" \
    --from-literal=KDP_OAUTH_USERNAME="${KDP_OAUTH_USERNAME}" \
    --from-literal=KDP_OAUTH_CLIENT_ID_PROD="${KDP_OAUTH_CLIENT_ID_PROD}" \
    --from-literal=KDP_OAUTH_CLIENT_SECRET_PROD="${KDP_OAUTH_CLIENT_SECRET_PROD}" \
    --from-literal=KDP_OAUTH_PASSWORD_PROD="${KDP_OAUTH_PASSWORD_PROD}" \
    --from-literal=KDP_OAUTH_CLIENT_ID_DEV="${KDP_OAUTH_CLIENT_ID_DEV}" \
    --from-literal=KDP_OAUTH_CLIENT_SECRET_DEV="${KDP_OAUTH_CLIENT_SECRET_DEV}" \
    --from-literal=KDP_OAUTH_PASSWORD_DEV="${KDP_OAUTH_PASSWORD_DEV}" \
    --from-literal=KDP_OAUTH_USERNAME_USER2="${KDP_OAUTH_USERNAME_USER2}" \
    --from-literal=KDP_OAUTH_CLIENT_ID_USER2_PROD="${KDP_OAUTH_CLIENT_ID_USER2_PROD}" \
    --from-literal=KDP_OAUTH_CLIENT_SECRET_USER2_PROD="${KDP_OAUTH_CLIENT_SECRET_USER2_PROD}" \
    --from-literal=KDP_OAUTH_PASSWORD_USER2_PROD="${KDP_OAUTH_PASSWORD_USER2_PROD}" \
    --from-literal=KDP_OAUTH_CLIENT_ID_USER2_DEV="${KDP_OAUTH_CLIENT_ID_USER2_DEV}" \
    --from-literal=KDP_OAUTH_CLIENT_SECRET_USER2_DEV="${KDP_OAUTH_CLIENT_SECRET_USER2_DEV}" \
    --from-literal=KDP_OAUTH_PASSWORD_USER2_DEV="${KDP_OAUTH_PASSWORD_USER2_DEV}" \
    --from-literal=AZURE_CONNECTION_STRING="${AZURE_CONNECTION_STRING}" \
    --from-literal=AZURE_CONTAINER_NAME="${AZURE_CONTAINER_NAME}" \


# ==============================================================================
# ArgoCD Repository Secret (argocd namespace)
# ==============================================================================
# Used by ArgoCD to pull platform manifests from Git repository
# This secret needs special labels for ArgoCD to recognize it as a repository

log_info "Creating ArgoCD repository secret..."

# Create temporary secret file with labels
TEMP_SECRET=$(mktemp)
cat > "$TEMP_SECRET" <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: lakehouse-repo-cred
  namespace: argocd
  labels:
    argocd.argoproj.io/secret-type: repository
stringData:
  type: git
  url: https://github.sec.samsung.net/ProductivityAI/lakehouse.git
  username: ${GITHUB_USERNAME}
  password: ${GITHUB_TOKEN}
EOF

# Seal the secret
kubeseal \
    --controller-name "${SEALED_SECRETS_CONTROLLER}" \
    --controller-namespace "${SEALED_SECRETS_NAMESPACE}" \
    --format yaml \
    < "$TEMP_SECRET" \
    > "${ROOT_DIR}/platform/secrets/argocd-repo-cred-sealed-secret.yaml"

# Clean up
rm -f "$TEMP_SECRET"

if [ $? -eq 0 ]; then
    log_info "Generated ${ROOT_DIR}/platform/secrets/argocd-repo-cred-sealed-secret.yaml"
else
    log_error "Failed to generate argocd-repo-cred sealed secret"
    exit 1
fi


log_info "All secrets generated successfully!"
echo "Don't forget to commit the new SealedSecret YAML files."
