# Sealed Secrets Module
# Installs the Sealed Secrets controller via Helm

resource "helm_release" "sealed_secrets" {
  name       = "sealed-secrets"
  repository = "https://bitnami-labs.github.io/sealed-secrets"
  chart      = "sealed-secrets"
  version    = var.chart_version
  namespace  = var.namespace
  create_namespace = true

  set {
    name  = "fullnameOverride"
    value = "sealed-secrets-controller"
  }

  # Ensure the controller is available before other resources might need it
  wait = true
}
