# Kubernetes Cluster Module (kind)

This Terraform module provisions a local Kubernetes cluster using [kind](https://kind.sigs.k8s.io/) (Kubernetes IN Docker).

## Purpose

- **Development/Testing**: Provides a local Kubernetes cluster for development and testing
- **CI/CD**: Can be used in CI pipelines for integration testing
- **Learning**: Ideal for learning Kubernetes without cloud costs

## Prerequisites

- **Docker**: kind requires Docker to be running
  ```bash
  docker ps  # Verify Docker is running
  ```
- **kind**: Optionally install kind CLI for manual cluster management
  ```bash
  brew install kind  # macOS
  ```

## Features

- **Configurable node count**: Single-node or multi-node clusters
- **Kubernetes version control**: Specify exact Kubernetes version
- **Port mappings**: Exposes ports 80 and 443 for ingress
- **Kubeconfig generation**: Automatically creates kubeconfig file
- **Ingress-ready**: Control plane labeled for ingress controller

## Usage

### Basic Usage

```hcl
module "cluster" {
  source = "./modules/cluster"
  
  cluster_name    = "my-cluster"
  cluster_version = "1.28.0"
  node_count      = 1
  tags            = {
    Environment = "dev"
  }
}
```

### Multi-Node Cluster

```hcl
module "cluster" {
  source = "./modules/cluster"
  
  cluster_name    = "my-cluster"
  cluster_version = "1.28.0"
  node_count      = 3  # 1 control plane + 2 workers
  tags            = {
    Environment = "staging"
  }
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| cluster_name | Kubernetes cluster name | string | - | yes |
| cluster_version | Kubernetes version (must be 1.28+) | string | - | yes |
| node_count | Number of nodes (1 control plane + N-1 workers) | number | 3 | no |
| node_instance_type | Not used for kind (cloud-specific) | string | "" | no |
| tags | Tags to apply to resources | map(string) | {} | no |

## Outputs

| Name | Description | Sensitive |
|------|-------------|-----------|
| cluster_name | Kubernetes cluster name | no |
| cluster_endpoint | Kubernetes API server endpoint | yes |
| cluster_ca_certificate | Cluster CA certificate | yes |
| kubeconfig | Complete kubeconfig content | yes |
| kubeconfig_path | Path to kubeconfig file | no |
| client_certificate | Client certificate | yes |
| client_key | Client key | yes |

## Accessing the Cluster

After creating the cluster, you can access it using:

```bash
# Using the generated kubeconfig
export KUBECONFIG=$(terraform output -raw kubeconfig_path)
kubectl get nodes

# Or using kind CLI
kind get clusters
kubectl cluster-info --context kind-<cluster-name>
```

## Port Mappings

The cluster is configured with the following port mappings:

- **Port 80**: HTTP traffic (for ingress)
- **Port 443**: HTTPS traffic (for ingress)

These allow you to access services via `localhost:80` and `localhost:443`.

## Node Configuration

### Control Plane Node
- **Role**: control-plane
- **Image**: kindest/node:v{cluster_version}
- **Labels**: ingress-ready=true
- **Ports**: 80, 443 mapped to host

### Worker Nodes
- **Role**: worker
- **Image**: kindest/node:v{cluster_version}
- **Count**: node_count - 1

## Kubernetes Version Support

Supported Kubernetes versions:
- **Minimum**: 1.28.0
- **Recommended**: 1.28.0 or later
- **Compatibility**: Must match available kindest/node images

Check available versions: https://hub.docker.com/r/kindest/node/tags

## Cluster Lifecycle

### Create Cluster
```bash
terraform apply -var-file=../env/dev/terraform.tfvars
```

### Destroy Cluster
```bash
terraform destroy -var-file=../env/dev/terraform.tfvars
```

### Recreate Cluster
```bash
terraform destroy -var-file=../env/dev/terraform.tfvars
terraform apply -var-file=../env/dev/terraform.tfvars
```

## Troubleshooting

### Docker Not Running
```
Error: Cannot connect to the Docker daemon
```
**Solution**: Start Docker Desktop or Docker daemon

### Port Already in Use
```
Error: port 80 is already allocated
```
**Solution**: Stop services using ports 80/443 or modify port mappings

### Cluster Creation Timeout
```
Error: timeout waiting for cluster to be ready
```
**Solution**: Increase Docker resources (CPU/Memory) or check Docker logs

## Contract Compliance

This module complies with:
- `contracts/kubernetes-cluster.md` - Kubernetes cluster contract
- Minimum version: 1.28+
- DNS-based service discovery
- Dynamic storage provisioning (via kind's default storage class)
- No hardcoded IP addresses

## Limitations

- **Local only**: kind is for local development, not production
- **Docker required**: Cannot run without Docker
- **Resource constraints**: Limited by host machine resources
- **Networking**: Uses Docker networking (not production-grade)

## Future Enhancements

This module can be extended to support:
- **Cloud providers**: EKS, GKE, AKS
- **Custom CNI**: Calico, Cilium, etc.
- **Custom storage**: Longhorn, Rook, etc.
- **HA control plane**: Multiple control plane nodes

## References

- [kind Documentation](https://kind.sigs.k8s.io/)
- [kind Configuration](https://kind.sigs.k8s.io/docs/user/configuration/)
- [Terraform kind Provider](https://registry.terraform.io/providers/tehcyx/kind/latest/docs)
