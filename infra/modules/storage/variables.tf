# Storage Module - Variable Definitions

variable "storage_name" {
  description = "Storage resource name"
  type        = string
}

variable "storage_class" {
  description = "Kubernetes storage class"
  type        = string
  default     = "standard"
}

variable "enable_object_storage" {
  description = "Enable object storage provisioning"
  type        = bool
  default     = true
}

variable "object_storage_size_gb" {
  description = "Size of object storage in GB"
  type        = number
  default     = 100
}

variable "tags" {
  description = "Tags to apply to storage resources"
  type        = map(string)
  default     = {}
}
