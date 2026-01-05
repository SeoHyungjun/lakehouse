# Sealed Secrets Module
# Installs the Sealed Secrets controller via Helm

# Restore Master Key (Optional)
# If a master key path is provided, apply it before installing the controller.
# The controller will pick up the existing key upon startup.
resource "null_resource" "restore_key" {
  count = var.master_key_path != "" ? 1 : 0

  triggers = {
    key_hash = fileexists(var.master_key_path) ? filesha256(var.master_key_path) : "new"
  }

  provisioner "local-exec" {
    command = <<EOT
      # Create namespace if it doesn't exist
      kubectl create namespace ${var.namespace} --dry-run=client -o yaml | kubectl apply -f -
      
      # Apply the master key
      kubectl apply -f ${var.master_key_path} -n ${var.namespace}
    EOT
    
    # We need to ensure kubectl is configured to talk to the correct cluster.
    # In a real environment, we'd rely on KUBECONFIG env var.
    # Here we assume the user has set up the context (which bootstrap.sh does).
  }
}

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
  
  depends_on = [null_resource.restore_key]
}
