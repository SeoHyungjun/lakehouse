variable "chart_version" {
  description = "Version of the Sealed Secrets Helm chart"
  type        = string
  default     = "2.18.0"
}

variable "namespace" {
  description = "Namespace to install Sealed Secrets into"
  type        = string
  default     = "sealed-secrets"
}

variable "master_key_path" {
  description = "Path to the master key file (optional). If provided, this key will be restored."
  type        = string
  default     = ""
}
