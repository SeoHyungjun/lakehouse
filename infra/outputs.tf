# Lakehouse Infrastructure - Output Definitions
#
# This file defines all outputs from the infrastructure provisioning.
# Outputs are used for:
# - Passing values to platform layer (Helm charts)
# - Debugging and verification
# - Integration with GitOps tools

# ============================================================================
# General Outputs
# ============================================================================

output "environment" {
  description = "Environment name"
  value       = var.environment
}

output "project_name" {
  description = "Project name"
  value       = var.project_name
}

# ============================================================================
# Cluster Outputs
# ============================================================================

output "cluster_name" {
  description = "Kubernetes cluster name"
  value       = module.cluster.cluster_name
}

output "cluster_endpoint" {
  description = "Kubernetes API server endpoint"
  value       = module.cluster.cluster_endpoint
  sensitive   = true
}

output "cluster_ca_certificate" {
  description = "Kubernetes cluster CA certificate"
  value       = module.cluster.cluster_ca_certificate
  sensitive   = true
}

output "kubeconfig" {
  description = "Kubeconfig for cluster access"
  value       = module.cluster.kubeconfig
  sensitive   = true
}

output "kubeconfig_path" {
  description = "Path to the kubeconfig file"
  value       = module.cluster.kubeconfig_path
}

# ============================================================================
# Network Outputs
# ============================================================================

# output "network_id" {
#   description = "Network/VPC ID"
#   value       = module.network.network_id
# }

# output "network_cidr" {
#   description = "Network CIDR block"
#   value       = module.network.cidr_block
# }

# output "dns_zone" {
#   description = "DNS zone for service discovery"
#   value       = module.network.dns_zone
# }

# ============================================================================
# Storage Outputs
# ============================================================================

# output "storage_endpoint" {
#   description = "Object storage endpoint (S3-compatible)"
#   value       = module.storage.storage_endpoint
# }

# output "storage_bucket_name" {
#   description = "Primary storage bucket name"
#   value       = module.storage.bucket_name
# }

# output "storage_access_key_id" {
#   description = "Storage access key ID"
#   value       = module.storage.access_key_id
#   sensitive   = true
# }

# output "storage_secret_access_key" {
#   description = "Storage secret access key"
#   value       = module.storage.secret_access_key
#   sensitive   = true
# }

# ============================================================================
# Summary Output
# ============================================================================

# output "infrastructure_summary" {
#   description = "Summary of provisioned infrastructure"
#   value = {
#     environment    = var.environment
#     cluster_name   = module.cluster.cluster_name
#     cluster_version = var.cluster_version
#     network_cidr   = module.network.cidr_block
#     storage_endpoint = module.storage.storage_endpoint
#   }
# }
