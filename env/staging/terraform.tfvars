# Staging Environment Configuration
#
# This file contains environment-specific values for the staging environment.
# All values here override the defaults in infra/variables.tf
#
# Usage:
#   cd infra/
#   terraform plan -var-file=../env/staging/terraform.tfvars
#   terraform apply -var-file=../env/staging/terraform.tfvars

# ============================================================================
# General Configuration
# ============================================================================

environment  = "staging"
project_name = "lakehouse"

tags = {
  Environment = "staging"
  ManagedBy   = "terraform"
  Project     = "lakehouse"
  Owner       = "data-engineering"
  CostCenter  = "engineering"
}

# ============================================================================
# Cluster Configuration
# ============================================================================

cluster_name    = "lakehouse-staging"
cluster_version = "1.28.0"
node_count      = 3  # Multi-node for realistic testing

# Cloud-specific instance type (example for AWS)
# Adjust based on your cloud provider
node_instance_type = "t3.medium"

# ============================================================================
# Network Configuration
# ============================================================================

network_name            = "lakehouse-staging-network"
cidr_block              = "10.1.0.0/16"
enable_dns              = true
enable_private_network  = true  # Private network for staging

# ============================================================================
# Storage Configuration
# ============================================================================

storage_name            = "lakehouse-staging-storage"
storage_class           = "gp3"  # Cloud-specific storage class
enable_object_storage   = true
object_storage_size_gb  = 100  # Moderate size for staging
