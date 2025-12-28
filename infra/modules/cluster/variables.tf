# Cluster Module - Variable Definitions

variable "cluster_name" {
  description = "Kubernetes cluster name"
  type        = string
}

variable "cluster_version" {
  description = "Kubernetes version"
  type        = string
}

variable "node_count" {
  description = "Number of worker nodes"
  type        = number
  default     = 3
}

variable "node_instance_type" {
  description = "Instance type for worker nodes"
  type        = string
  default     = ""
}

variable "tags" {
  description = "Tags to apply to cluster resources"
  type        = map(string)
  default     = {}
}
