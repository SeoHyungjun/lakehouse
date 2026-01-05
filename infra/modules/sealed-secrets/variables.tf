variable "chart_version" {
  description = "Version of the Sealed Secrets Helm chart"
  type        = string
  default     = "2.13.3"
}

variable "namespace" {
  description = "Namespace to install Sealed Secrets into"
  type        = string
  default     = "sealed-secrets"
}
