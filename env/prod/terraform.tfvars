# Production Environment Configuration
#
# This file contains environment-specific values for the production environment.
# Production uses maximum resources, HA, and strict security settings.
#
# Usage:
#   cd infra/
#   terraform plan -var-file=../env/prod/terraform.tfvars
#   terraform apply -var-file=../env/prod/terraform.tfvars

# ============================================================================
# General Configuration
# ============================================================================

environment  = "prod"
project_name = "lakehouse"

tags = {
  Environment = "production"
  ManagedBy   = "terraform"
  Project     = "lakehouse"
  Owner       = "data-engineering"
  CostCenter  = "data-platform"
  Compliance  = "required"
}

# ============================================================================
# Cluster Configuration
# ============================================================================

cluster_name    = "lakehouse-prod"
cluster_version = "1.28.0"
node_count      = 5  # HA with 5 nodes for production

# Cloud-specific instance type (adjust for your cloud provider)
node_instance_type = "t3.xlarge"  # AWS example - larger instances for production

# ============================================================================
# Network Configuration
# ============================================================================

network_name            = "lakehouse-prod-network"
cidr_block              = "10.2.0.0/16"
enable_dns              = true
enable_private_network  = true  # Strict private network for production

# ============================================================================
# Storage Configuration
# ============================================================================

storage_name            = "lakehouse-prod-storage"
storage_class           = "io2"  # High-performance SSD for production
enable_object_storage   = true
object_storage_size_gb  = 500  # Large size for production workloads
