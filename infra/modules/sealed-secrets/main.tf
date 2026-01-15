# Sealed Secrets Module
# Installs the Sealed Secrets controller via Helm

locals {
  chart_dir = "${path.module}/../../../infra/charts"
  chart_file = "${local.chart_dir}/sealed-secrets-${var.chart_version}.tgz"
  chart_url = "https://github.com/bitnami-labs/sealed-secrets/releases/download/helm-v${var.chart_version}/sealed-secrets-${var.chart_version}.tgz"
}

# Download Helm chart if not already present (with retry logic)
resource "null_resource" "download_chart" {
  provisioner "local-exec" {
    command = <<EOT
      # Create charts directory if it doesn't exist
      mkdir -p ${local.chart_dir}

      # Check if chart already exists
      if [ -f "${local.chart_file}" ]; then
        echo "Chart already exists: ${local.chart_file}"
        exit 0
      fi

      echo "Chart not found, downloading..."

      # Retry 5 times with 30 second timeout and 30 second interval
      for i in {1..5}; do
        echo "Download attempt $i/5..."
        if wget --timeout=30 -O "${local.chart_file}" "${local.chart_url}" 2>&1; then
          echo "Download successful: ${local.chart_file}"
          exit 0
        fi
        echo "Download attempt $i failed"

        # Don't sleep after the last attempt
        if [ $i -lt 5 ]; then
          echo "Waiting 30 seconds before retry..."
          sleep 30
        fi
      done

      echo "Failed to download chart after 5 attempts"
      exit 1
    EOT
  }
}

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

      # Apply the master key only if it exists
      if [ -f "${var.master_key_path}" ]; then
        kubectl apply -f ${var.master_key_path} -n ${var.namespace}
      fi
    EOT

    # We need to ensure kubectl is configured to talk to the correct cluster.
    # In a real environment, we'd rely on KUBECONFIG env var.
    # Here we assume the user has set up the context (which bootstrap.sh does).
  }

  depends_on = [null_resource.download_chart]
}

resource "helm_release" "sealed_secrets" {
  name       = "sealed-secrets"
  chart      = local.chart_file
  version    = var.chart_version
  namespace  = var.namespace
  create_namespace = true

  set {
    name  = "fullnameOverride"
    value = "sealed-secrets-controller"
  }

  # Ensure the controller is available before other resources might need it
  wait = true

  depends_on = [null_resource.download_chart, null_resource.restore_key]
}
