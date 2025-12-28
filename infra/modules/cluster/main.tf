# Cluster Module - Main Configuration
#
# This module provisions a Kubernetes cluster using kind (Kubernetes IN Docker).
# kind is used for local development and testing environments.
#
# For production environments, this module can be extended to support:
# - EKS (AWS)
# - GKE (Google Cloud)
# - AKS (Azure)
# - Self-managed clusters

terraform {
  required_providers {
    kind = {
      source  = "tehcyx/kind"
      version = "~> 0.6.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.5.0"
    }
  }
}

# kind cluster resource
resource "kind_cluster" "this" {
  name = var.cluster_name

  # Wait for cluster to be ready
  wait_for_ready = true

  # kind-specific configuration
  kind_config {
    kind        = "Cluster"
    api_version = "kind.x-k8s.io/v1alpha4"

    # Control plane node
    node {
      role = "control-plane"

      # Kubernetes version
      image = "kindest/node:v${var.cluster_version}"

      # Port mappings for accessing services from host
      # These allow NodePort services to be accessible on localhost
      extra_port_mappings {
        container_port = 80
        host_port      = 80
        protocol       = "TCP"
      }

      extra_port_mappings {
        container_port = 443
        host_port      = 443
        protocol       = "TCP"
      }

      # kubeadm config patches for control plane
      kubeadm_config_patches = [
        <<-EOT
        kind: InitConfiguration
        nodeRegistration:
          kubeletExtraArgs:
            node-labels: "ingress-ready=true"
        EOT
      ]
    }

    # Worker nodes (if node_count > 1, we create worker nodes)
    # kind always has 1 control plane node, so we create (node_count - 1) workers
    dynamic "node" {
      for_each = range(max(0, var.node_count - 1))
      content {
        role  = "worker"
        image = "kindest/node:v${var.cluster_version}"
      }
    }
  }
}

# Output the kubeconfig for use by other modules
# This is stored in a local file for easy access
resource "local_file" "kubeconfig" {
  content  = kind_cluster.this.kubeconfig
  filename = "${path.root}/.kubeconfig-${var.cluster_name}"

  # Ensure the file has restricted permissions
  file_permission = "0600"
}
