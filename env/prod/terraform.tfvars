# Production Environment Configuration
#
# This file contains environment-specific values for the production environment.
# All values here override the defaults in infra/variables.tf
#
# Usage:
#   cd infra/
#   terraform plan -var-file=../env/prod/terraform.tfvars
#   terraform apply -var-file=../env/prod/terraform.tfvars
#
# IMPORTANT: Review all changes carefully before applying to production!

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
  Criticality = "high"
  Backup      = "required"
}

# ============================================================================
# Cluster Configuration
# ============================================================================

cluster_name    = "lakehouse-prod"
cluster_version = "1.28.0"
node_count      = 5  # Multi-node for high availability

# Cloud-specific instance type (example for AWS)
# Adjust based on your cloud provider and workload requirements
node_instance_type = "m5.xlarge"

# ============================================================================
# Network Configuration
# ============================================================================

network_name            = "lakehouse-prod-network"
cidr_block              = "10.2.0.0/16"
enable_dns              = true
enable_private_network  = true  # Private network for production security

# ============================================================================
# Storage Configuration
# ============================================================================

storage_name            = "lakehouse-prod-storage"
storage_class           = "gp3"  # Cloud-specific storage class with better performance
enable_object_storage   = true
object_storage_size_gb  = 1000  # Large size for production workloads
