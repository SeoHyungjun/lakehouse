# Infrastructure as Code (Terraform)

This directory contains Terraform configurations for provisioning the Lakehouse infrastructure.

## Directory Structure

```
infra/
├── main.tf                    # Root Terraform configuration
├── variables.tf               # Input variable definitions
├── outputs.tf                 # Output definitions
└── modules/
    ├── cluster/               # Kubernetes cluster provisioning
    │   ├── main.tf
    │   ├── variables.tf
    │   └── outputs.tf
    ├── network/               # Network resources (VPC, DNS, etc.)
    │   ├── main.tf
    │   ├── variables.tf
    │   └── outputs.tf
    └── storage/               # Storage resources (object storage, PVs)
        ├── main.tf
        ├── variables.tf
        └── outputs.tf
```

## Usage

### Prerequisites

- Terraform >= 1.5.0
- Appropriate cloud provider credentials (if deploying to cloud)

### Initialize Terraform

```bash
cd infra/
terraform init
```

### Plan Infrastructure Changes

```bash
terraform plan -var-file=../env/<environment>/terraform.tfvars
```

### Apply Infrastructure Changes

```bash
terraform apply -var-file=../env/<environment>/terraform.tfvars
```

### Destroy Infrastructure

```bash
terraform destroy -var-file=../env/<environment>/terraform.tfvars
```

## Environment Configuration

All environment-specific values must be provided via `.tfvars` files in the `env/` directory.

Example structure:
```
env/
├── dev/
│   └── terraform.tfvars
├── staging/
│   └── terraform.tfvars
└── prod/
    └── terraform.tfvars
```

**NO hardcoded values are allowed in Terraform configurations.**

## Modules

### cluster/

Provisions a Kubernetes cluster. Supports:
- kind (local development)
- Cloud-managed Kubernetes (EKS, GKE, AKS)
- Self-managed Kubernetes

### network/

Provisions network resources:
- VPC/Virtual Network
- Subnets
- DNS zones
- Network policies

### storage/

Provisions storage resources:
- Object storage (S3-compatible)
- Persistent volumes
- Storage classes

## Verification

After creating the structure, verify with:

```bash
terraform init    # Should succeed
terraform validate # Should show "Success! The configuration is valid."
```

## Contract Compliance

This infrastructure layer strictly follows:
- `docs/repo_contract.md` - Repository structure rules
- `contracts/kubernetes-cluster.md` - Cluster requirements
- `contracts/object-storage.md` - Storage requirements

## Implementation Status

- [x] Task 8: Terraform module structure created
- [x] Task 9: Environment abstraction (tfvars examples)
- [x] Task 10: kind cluster module implementation
