# Development Environment Configuration
#
# This file contains environment-specific values for the development environment.
# All values here override the defaults in infra/variables.tf
#
# Usage:
#   cd infra/
#   terraform plan -var-file=../env/dev/terraform.tfvars
#   terraform apply -var-file=../env/dev/terraform.tfvars

# ============================================================================
# General Configuration
# ============================================================================

environment  = "dev"
project_name = "lakehouse"

tags = {
  Environment = "development"
  ManagedBy   = "terraform"
  Project     = "lakehouse"
  Owner       = "data-engineering"
}

# ============================================================================
# Cluster Configuration
# ============================================================================

cluster_name    = "lakehouse-dev"
cluster_version = "1.28.0"
node_count      = 1  # Single node for local development

# For kind (local development), instance type is not applicable
node_instance_type = ""

# ============================================================================
# Network Configuration
# ============================================================================

network_name            = "lakehouse-dev-network"
cidr_block              = "10.0.0.0/16"
enable_dns              = true
enable_private_network  = false  # Allow external access for development

# ============================================================================
# Storage Configuration
# ============================================================================

storage_name            = "lakehouse-dev-storage"
storage_class           = "standard"
enable_object_storage   = true
object_storage_size_gb  = 10  # Small size for development

# ============================================================================
# Secret Configuration
# ============================================================================
# Path to the backup master key.
# Terraform will use this key to restore the sealed-secrets controller state.
# Default: "" (Generates a new key on cluster creation)
master_key_path = "../env/dev/master.key"
