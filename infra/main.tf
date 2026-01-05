# Lakehouse Infrastructure - Main Configuration
#
# This is the root Terraform configuration for provisioning the Lakehouse infrastructure.
# It orchestrates the cluster, network, and storage modules.
#
# Usage:
#   terraform init
#   terraform plan -var-file=../env/<environment>/terraform.tfvars
#   terraform apply -var-file=../env/<environment>/terraform.tfvars

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    kind = {
      source  = "tehcyx/kind"
      version = "~> 0.6.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.5.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.12.0"
    }
  }
}

# Module: Kubernetes Cluster
# Provisions a Kubernetes cluster (e.g., kind for local development)
module "cluster" {
  source = "./modules/cluster"
  
  cluster_name    = var.cluster_name
  cluster_version = var.cluster_version
  node_count      = var.node_count
  tags            = var.tags
}

# Provider: Helm
# Configures the Helm provider to use the cluster created above
provider "helm" {
  kubernetes {
    host                   = module.cluster.cluster_endpoint
    client_certificate     = module.cluster.client_certificate
    client_key             = module.cluster.client_key
    cluster_ca_certificate = module.cluster.cluster_ca_certificate
  }
}

# Module: Sealed Secrets
# Installs the Sealed Secrets controller
module "sealed_secrets" {
  source = "./modules/sealed-secrets"
  
  master_key_path = var.master_key_path
  depends_on      = [module.cluster]
}

# Module: Network
# Provisions network resources (VPC, subnets, DNS, etc.)
# module "network" {
#   source = "./modules/network"
#   
#   network_name = var.network_name
#   cidr_block   = var.cidr_block
# }

# Module: Storage
# Provisions storage resources (object storage, persistent volumes, etc.)
# module "storage" {
#   source = "./modules/storage"
#   
#   storage_name = var.storage_name
#   depends_on   = [module.cluster]
# }
