# Network Module - Variable Definitions

variable "network_name" {
  description = "Network/VPC name"
  type        = string
}

variable "cidr_block" {
  description = "CIDR block for the network"
  type        = string
}

variable "enable_dns" {
  description = "Enable DNS support"
  type        = bool
  default     = true
}

variable "enable_private_network" {
  description = "Enable private networking"
  type        = bool
  default     = false
}

variable "tags" {
  description = "Tags to apply to network resources"
  type        = map(string)
  default     = {}
}
