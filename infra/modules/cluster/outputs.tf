# Cluster Module - Output Definitions

output "cluster_name" {
  description = "Kubernetes cluster name"
  value       = kind_cluster.this.name
}

output "cluster_endpoint" {
  description = "Kubernetes API server endpoint"
  value       = kind_cluster.this.endpoint
}

output "cluster_ca_certificate" {
  description = "Kubernetes cluster CA certificate"
  value       = kind_cluster.this.cluster_ca_certificate
  sensitive   = true
}

output "kubeconfig" {
  description = "Kubeconfig for cluster access"
  value       = kind_cluster.this.kubeconfig
  sensitive   = true
}

output "kubeconfig_path" {
  description = "Path to the kubeconfig file"
  value       = local_file.kubeconfig.filename
}

output "client_certificate" {
  description = "Client certificate for cluster access"
  value       = kind_cluster.this.client_certificate
  sensitive   = true
}

output "client_key" {
  description = "Client key for cluster access"
  value       = kind_cluster.this.client_key
  sensitive   = true
}
