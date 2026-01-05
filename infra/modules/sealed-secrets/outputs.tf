output "namespace" {
  description = "Namespace where Sealed Secrets is installed"
  value       = var.namespace
}

output "controller_name" {
  description = "Name of the Sealed Secrets controller release"
  value       = helm_release.sealed_secrets.name
}
