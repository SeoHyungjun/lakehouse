# Secret Management Contract

## Overview

This project uses a stricter GitOps workflow for secret management. All runtime secrets are encrypted using [Sealed Secrets](https://github.com/bitnami-labs/sealed-secrets) and managed via ArgoCD. Plaintext secrets are never stored in Git.

## Principles

1.  **Single Source of Truth**: The `.env` file (local only) is the source of truth for secret values.
2.  **Encryption at Rest**: Only `SealedSecret` manifests are committed to Git.
3.  **GitOps Driven**: ArgoCD applies `SealedSecrets`, and the controller decrypts them into Kubernetes `Secrets`.
4.  **Reproducibility**: The secret generation process is scripted and deterministic.

## Workflow

### 1. Setup

Copy the example environment file:
```bash
cp .env.example .env
```
Fill in the required values in `.env`.

### 2. Infrastructure Bootstrap

Ensure the Sealed Secrets controller is running:
```bash
# Usually handled by bootstrap.sh
cd infra
terraform init
terraform apply
```

### 3. Generate Secrets

Run the generation script:
```bash
./scripts/generate-secrets.sh
```
This script will:
1.  Read values from `.env`.
2.  Connect to the cluster to fetch the sealing certificate.
3.  Generate `SealedSecret` YAML files in `platform/<component>/templates/`.

### 4. Commit and Push

Commit the generated manifests:
```bash
git add platform/*/templates/*sealed-secret.yaml
git commit -m "chore: update sealed secrets"
git push
```

### 5. Deployment

ArgoCD will automatically sync the new `SealedSecret` manifests. The Sealed Secrets controller will decrypt them into standard Kubernetes Secrets, which are then mounted by applications.

## Directory Structure

*   `.env`: Local secret values (Gitignored).
*   `.env.example`: Template for required secrets.
*   `scripts/generate-secrets.sh`: Automation script.
*   `platform/**/templates/*sealed-secret.yaml`: Encrypted manifests (Committed).
