# Lakehouse Infrastructure - Variable Definitions
#
# This file defines all input variables for the infrastructure.
# All values should be provided via environment-specific tfvars files in env/<environment>/
#
# NO hardcoded values are allowed in this configuration.

# ============================================================================
# General Configuration
# ============================================================================

variable "environment" {
  description = "Environment name (e.g., dev, staging, prod)"
  type        = string

  validation {
    condition     = can(regex("^(dev|staging|prod|test)$", var.environment))
    error_message = "Environment must be one of: dev, staging, prod, test"
  }
}

variable "project_name" {
  description = "Project name for resource naming and tagging"
  type        = string
  default     = "lakehouse"

  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.project_name))
    error_message = "Project name must contain only lowercase letters, numbers, and hyphens"
  }
}

variable "tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
}

# ============================================================================
# Cluster Configuration
# ============================================================================

variable "cluster_name" {
  description = "Kubernetes cluster name"
  type        = string
  default     = ""
}

variable "cluster_version" {
  description = "Kubernetes version (must be 1.28+)"
  type        = string
  default     = "1.28.0"

  validation {
    condition     = can(regex("^1\\.(2[8-9]|[3-9][0-9])\\..*$", var.cluster_version))
    error_message = "Cluster version must be 1.28 or higher"
  }
}

variable "node_count" {
  description = "Number of worker nodes in the cluster"
  type        = number
  default     = 3

  validation {
    condition     = var.node_count >= 1 && var.node_count <= 100
    error_message = "Node count must be between 1 and 100"
  }
}

variable "node_instance_type" {
  description = "Instance type for worker nodes (cloud-specific)"
  type        = string
  default     = ""
}

# ============================================================================
# Network Configuration
# ============================================================================

variable "network_name" {
  description = "Network/VPC name"
  type        = string
  default     = ""
}

variable "cidr_block" {
  description = "CIDR block for the network"
  type        = string
  default     = "10.0.0.0/16"

  validation {
    condition     = can(cidrhost(var.cidr_block, 0))
    error_message = "CIDR block must be a valid IPv4 CIDR notation"
  }
}

variable "enable_dns" {
  description = "Enable DNS support in the network"
  type        = bool
  default     = true
}

variable "enable_private_network" {
  description = "Enable private networking (no public IPs)"
  type        = bool
  default     = false
}

# ============================================================================
# Storage Configuration
# ============================================================================

variable "storage_name" {
  description = "Storage resource name"
  type        = string
  default     = ""
}

variable "storage_class" {
  description = "Kubernetes storage class for persistent volumes"
  type        = string
  default     = "standard"
}

variable "enable_object_storage" {
  description = "Enable object storage provisioning (e.g., S3, MinIO)"
  type        = bool
  default     = true
}

variable "object_storage_size_gb" {
  description = "Size of object storage in GB (if applicable)"
  type        = number
  default     = 100

  validation {
    condition     = var.object_storage_size_gb >= 1
    error_message = "Object storage size must be at least 1 GB"
  }
}

variable "master_key_path" {
  description = "Path to the sealed secrets master key file (optional). If provided, this key will be restored."
  type        = string
  default     = ""
}
