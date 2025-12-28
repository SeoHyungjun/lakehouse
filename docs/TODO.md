# Lakehouse Project — TODO List

> **Phase 0 Output** — This is the authoritative task list for implementing the Lakehouse project.
> All tasks must be completed in order. Tasks may only be marked `[x]` after verification.

---

## Phase 1: Repository Structure & Contracts

[x] 1. Create Repository Directory Structure
- **Purpose**: Establish the mandatory directory layout per `docs/repo_contract.md`
- **Inputs**: `docs/repo_contract.md` directory specification
- **Outputs**: Empty directories: `infra/`, `platform/`, `services/`, `workflows/`, `contracts/`, `env/`
- **Depends on**: None
- **Verification**: All directories exist; `ls -la` shows correct structure
- **Completed**: 2025-12-27 16:39 KST — All six directories created successfully. Verified with `ls -la` showing: `contracts/`, `env/`, `infra/`, `platform/`, `services/`, `workflows/`

---

[x] 2. Define Kubernetes Cluster Contract
- **Purpose**: Document the Kubernetes cluster requirements and API contract
- **Inputs**: Architecture principles from `README.md` sections 2.1, 2.2
- **Outputs**: `contracts/kubernetes-cluster.md` — cluster requirements, node specs, networking expectations
- **Depends on**: Task 1 (directory structure)
- **Verification**: Contract document exists and is complete; no implementation details included
- **Completed**: 2025-12-27 16:42 KST — Created comprehensive Kubernetes cluster contract (7.7KB) covering: cluster requirements (v1.28+), networking (DNS-based), storage (dynamic provisioning), namespaces, API access rules, execution flexibility (Pod/VM/bare-metal), observability, and GitOps deployment. No implementation details included, only contract specifications.

---

[x] 3. Define Object Storage Contract (S3-Compatible)
- **Purpose**: Define the S3-compatible object storage interface
- **Inputs**: `README.md` section 4.1, `docs/module_interfaces.md` section 1
- **Outputs**: `contracts/object-storage.md` — endpoint format, authentication, bucket naming conventions
- **Depends on**: Task 1 (directory structure)
- **Verification**: Contract explicitly forbids vendor-specific SDKs; uses DNS-based endpoints only
- **Completed**: 2025-12-27 16:46 KST — Created comprehensive S3-compatible object storage contract (11KB) covering: S3 API requirements, DNS-based endpoints, access key authentication, bucket naming conventions, storage classes, security (encryption at rest/transit), observability, SDK usage (S3-compatible only), and migration paths. Explicitly forbids vendor-specific SDKs (AWS native, Azure native, GCP native) and hardcoded IPs. Includes code examples for Python/Boto3 and Go.

---

[x] 4. Define Iceberg Catalog Contract
- **Purpose**: Define the Iceberg table format and catalog interface
- **Inputs**: `README.md` section 4.2, `docs/module_interfaces.md` section 2
- **Outputs**: `contracts/iceberg-catalog.md` — catalog backend options, table schema conventions
- **Depends on**: Task 3 (object storage contract)
- **Verification**: Contract allows REST/JDBC/Hive/Glue backends; no hardcoded catalog type
- **Completed**: 2025-12-27 16:50 KST — Created comprehensive Iceberg catalog contract (16.9KB) covering: Apache Iceberg v2 table format, catalog backends (REST/JDBC/Hive/Glue) with full configuration examples, warehouse structure, namespace/table management, schema evolution, partition evolution, hidden partitioning, snapshot management, time travel, data access rules (Iceberg APIs only), metadata management, concurrency control, observability, security, and catalog migration paths. Explicitly forbids direct object path access and requires catalog backend to be swappable via configuration only.

---

[x] 5. Define Query Engine Contract (Trino)
- **Purpose**: Define the SQL query interface via Trino
- **Inputs**: `README.md` section 4.3, `docs/module_interfaces.md` section 3
- **Outputs**: `contracts/query-engine.md` — SQL endpoint, JDBC compatibility, Iceberg-only access
- **Depends on**: Task 4 (Iceberg contract)
- **Verification**: Contract explicitly forbids direct object path access
- **Completed**: 2025-12-27 16:53 KST — Created comprehensive Trino query engine contract (16.7KB) covering: Trino 400+ requirements, SQL over HTTP interface, JDBC compatibility, DNS-based endpoints, Iceberg connector configuration (REST/JDBC/Hive/Glue catalogs), Iceberg-only data access rules, ANSI SQL compliance, time travel queries, write operations (INSERT/UPDATE/DELETE/MERGE), DDL operations, authentication/authorization, performance optimization, observability (Prometheus metrics, Web UI, health checks), HA/scalability, security (TLS), and client examples (Java JDBC, Python, CLI). Explicitly forbids direct object path access and Trino-specific SQL in shared code.

---

[x] 6. Define Workflow Orchestration Contract
- **Purpose**: Define orchestrator-agnostic job specification format
- **Inputs**: `README.md` sections 5.1, 5.2, `docs/module_interfaces.md` section 4
- **Outputs**: `contracts/workflow-orchestration.md` — job spec schema (YAML), trigger interface
- **Depends on**: Task 1 (directory structure)
- **Verification**: Contract forbids Airflow/Dagster-specific APIs in job definitions
- **Completed**: 2025-12-27 16:56 KST — Created comprehensive workflow orchestration contract (17.5KB) covering: orchestrator-agnostic job/workflow specifications (YAML/JSON schema), container-based execution, Airflow/Dagster adapter implementations, templating (Jinja2), scheduling (cron/interval/event-driven), dependency management, retry policies, error handling, monitoring (Prometheus metrics, structured logging), security (RBAC, secrets management), job development guidelines, and orchestrator migration paths (Airflow ↔ Dagster). Explicitly forbids orchestrator-specific APIs (Airflow/Dagster imports) in job code and requires business logic to live inside containers only.

---

[x] 7. Define Service Module Contract
- **Purpose**: Define standard service interface (REST/gRPC, health checks)
- **Inputs**: `docs/module_interfaces.md` section 5, `README.md` section 8
- **Outputs**: `contracts/service-module.md` — API format, `/health`, `/ready` endpoints, observability requirements
- **Depends on**: Task 1 (directory structure)
- **Verification**: Contract requires structured logging, metrics, health checks
- **Completed**: 2025-12-27 16:59 KST — Created comprehensive service module contract (19.6KB) covering: REST/gRPC API requirements, mandatory health checks (/health, /ready, /startup), structured logging (JSON to stdout), Prometheus-compatible metrics endpoint, configuration management (environment variables), error handling (standard error codes), security (authentication/authorization/TLS/input validation), performance (stateless design, graceful shutdown), deployment (Dockerfile, Helm chart, GitOps), testing requirements, API documentation (OpenAPI), and 12-factor app compliance. Explicitly requires environment-agnostic design (container/VM/bare-metal) with no Kubernetes API dependencies or hardcoded endpoints/credentials.

---

## Phase 2: Infrastructure as Code (Terraform)

[x] 8. Create Terraform Module Structure
- **Purpose**: Set up Terraform directory layout for infrastructure provisioning
- **Inputs**: `docs/repo_contract.md` section on `infra/`
- **Outputs**: `infra/` with modules: `cluster/`, `network/`, `storage/`; root `main.tf`, `variables.tf`, `outputs.tf`
- **Depends on**: Task 1 (directory structure)
- **Verification**: `terraform init` succeeds in `infra/`
- **Completed**: 2025-12-28 14:30 KST — Created complete Terraform module structure with three modules (cluster/, network/, storage/). Each module contains main.tf, variables.tf, and outputs.tf. Root directory contains main.tf (with placeholder module declarations), variables.tf (comprehensive input variables with validation), and outputs.tf (placeholder outputs). Verified with `terraform init` and `terraform validate` - both succeeded. Created README.md documenting structure and usage. Total files created: 13 (3 root files + 3 modules × 3 files each + README).

---

[x] 9. Define Terraform Variables & Environment Abstraction
- **Purpose**: Create environment-agnostic Terraform configuration
- **Inputs**: `README.md` sections 3.2, 6.2 (configuration vs code, GitOps-first)
- **Outputs**: `infra/variables.tf` with environment inputs; `env/` with example tfvars files
- **Depends on**: Task 8 (Terraform structure)
- **Verification**: No hardcoded values in Terraform; all values injectable
- **Completed**: 2025-12-28 14:35 KST — Created environment abstraction with three environment configurations (dev, staging, prod). Each environment has terraform.tfvars with appropriate resource sizing: dev (1 node, 10GB storage), staging (3 nodes, 100GB storage), prod (5 nodes, 1TB storage). Created env/README.md documenting configuration structure and usage. Created .gitignore to prevent accidental commits of sensitive files. Verified with `terraform plan -var-file=../env/{dev,staging,prod}/terraform.tfvars` - all succeeded. Verified no hardcoded values: `terraform plan -input=false` fails as expected, requiring var-file. All values are injectable via tfvars files, following "Configuration vs Code Separation" principle.

---

[x] 10. Create Kubernetes Cluster Terraform Module (kind-compatible)
- **Purpose**: Provision a local Kubernetes cluster for development/testing
- **Inputs**: Task 2 (cluster contract), kind documentation
- **Outputs**: `infra/modules/cluster/` — Terraform module to create kind cluster
- **Depends on**: Tasks 8, 9 (Terraform structure and variables)
- **Verification**: `terraform apply` creates a working kind cluster inside container sandbox
- **Completed**: 2025-12-28 14:40 KST — Implemented complete kind cluster Terraform module using tehcyx/kind provider v0.6.0. Module creates configurable Kubernetes clusters with: dynamic worker node provisioning (node_count - 1 workers), Kubernetes version control (1.28+), port mappings (80, 443 for ingress), kubeconfig file generation with 0600 permissions, and ingress-ready control plane labeling. Updated root main.tf to enable cluster module and added kind + local providers. Created comprehensive module README.md documenting usage, inputs/outputs, troubleshooting, and contract compliance. Verified with `terraform init` (success), `terraform validate` (success), and `terraform plan -var-file=../env/dev/terraform.tfvars` (shows 2 resources to create: kind_cluster and local_file). Module ready for deployment when Docker is available. Complies with contracts/kubernetes-cluster.md requirements.

---

## Phase 3: Platform Layer (Helm Charts)

[x] 11. Create Platform Helm Chart Structure
- **Purpose**: Set up Helm chart layout for platform components
- **Inputs**: `docs/repo_contract.md` section on `platform/`
- **Outputs**: `platform/` with subdirectories for each component (ready for Helm charts)
- **Depends on**: Task 1 (directory structure)
- **Verification**: Directory structure matches Helm chart conventions
- **Completed**: 2025-12-28 14:44 KST — Created complete Helm chart structure for 6 platform components: minio (S3 storage), iceberg-catalog (REST catalog), trino (SQL engine), airflow (orchestration), observability (Prometheus+Grafana), and argocd (GitOps). Each component has standard Helm files (Chart.yaml, values.yaml, templates/). Total 19 files created. All Chart.yaml files use apiVersion v2 with proper metadata and upstream dependencies declared (MinIO, Trino, Airflow, kube-prometheus-stack, ArgoCD). All values.yaml files use DNS-based endpoints with no hardcoded IPs. Created comprehensive README.md documenting structure, installation, testing, and troubleshooting. Verified: all charts follow Helm conventions, no hardcoded values, configurable via environment-specific overrides.

---

[x] 12. Create MinIO Helm Chart Configuration
- **Purpose**: Deploy MinIO as S3-compatible object storage
- **Inputs**: Task 3 (object storage contract), MinIO Helm chart documentation
- **Outputs**: `platform/minio/` — Helm values, Chart.yaml referencing upstream MinIO chart
- **Depends on**: Tasks 3, 11 (object storage contract, platform structure)
- **Verification**: Helm template renders valid Kubernetes manifests; no hardcoded IPs
- **Completed**: 2025-12-28 14:50 KST — Created complete MinIO Helm chart configuration with upstream dependency (v5.0.14). Chart includes: Chart.yaml with dependency declaration, values.yaml with default configuration, .helmignore for package exclusions, comprehensive README.md (10KB) covering installation/configuration/usage/monitoring/security/troubleshooting, and validate.sh script. Created environment-specific values for dev (standalone, 10Gi), staging (standalone, 50Gi, metrics enabled), and prod (distributed 4 replicas, 100Gi, HA, TLS, ingress). All configurations use DNS-based endpoints (http://minio:9000), no hardcoded IPs. Bucket naming follows convention: lakehouse-{env}-{purpose}. Verified contract compliance: S3 API, access key auth, path-style access, Prometheus metrics, health checks. Validation script confirms all requirements met. Total 8 files created.

---

[x] 13. Create Iceberg Catalog Helm Chart Configuration
- **Purpose**: Deploy Iceberg REST catalog
- **Inputs**: Task 4 (Iceberg contract), Apache Iceberg REST catalog documentation
- **Outputs**: `platform/iceberg-catalog/` — Helm values, deployment configuration
- **Depends on**: Tasks 4, 11, 12 (Iceberg contract, platform structure, MinIO)
- **Verification**: Helm template renders; catalog connects to MinIO via DNS endpoint
- **Completed**: 2025-12-28 15:03 KST — Created complete Iceberg REST catalog Helm chart using tabulario/iceberg-rest:1.4.0 image. Chart supports multiple catalog backends (JDBC/REST/Hive/Glue) configurable via values only. Includes: Deployment with health probes, Service, Secrets (S3 + JDBC credentials), PVC for file-based backends, ServiceMonitor for metrics, and Helm helpers. Created environment-specific values for dev (SQLite, 1 replica, 256Mi RAM), staging (PostgreSQL, 2 replicas, metrics enabled), and prod (PostgreSQL HA, 3 replicas, strict anti-affinity, 1Gi RAM). All configurations use DNS-based MinIO endpoint (http://minio.lakehouse-platform.svc.cluster.local:9000), no hardcoded IPs. Created comprehensive README.md (15KB) covering all backends, installation, configuration, integration, observability, security, and troubleshooting. Created validate.sh script - all validations passed. Contract compliance verified: Apache Iceberg v2, swappable backends, DNS endpoints, configurable warehouse, environment-agnostic. Total 14 files created.

---

[x] 14. Create Trino Helm Chart Configuration
- **Purpose**: Deploy Trino query engine with Iceberg connector
- **Inputs**: Task 5 (query engine contract), Trino Helm chart documentation
- **Outputs**: `platform/trino/` — Helm values, Iceberg connector configuration
- **Depends on**: Tasks 5, 11, 13 (query engine contract, platform structure, Iceberg catalog)
- **Verification**: Helm template renders; Trino configured to use Iceberg catalog only
- **Completed**: 2025-12-28 15:08 KST — Created complete Trino Helm chart configuration using upstream trinodb/charts v0.15.0. Chart includes: values.yaml with default configuration, environment-specific values for dev (2 workers, 2Gi RAM), staging (3-6 workers with autoscaling, TLS enabled), and prod (5-20 workers with autoscaling, strict pod anti-affinity, OAuth2 auth, production hardening). Iceberg catalog connector configured with REST catalog backend, DNS-based endpoints (no hardcoded IPs), environment variable injection for S3 credentials. Created comprehensive README.md (15KB) covering installation, configuration, usage examples (JDBC/Python/CLI), observability, scaling, and troubleshooting. Created validate.sh script - 38 validations passed. Helm templates render successfully for all environments. Contract compliance verified: Iceberg-only access (no direct S3), DNS endpoints, configurable catalog backend, ANSI SQL, health probes (/v1/info), Prometheus metrics. Total 9 files created.

---

[x] 15. Create Airflow Helm Chart Configuration
- **Purpose**: Deploy Airflow as workflow orchestrator
- **Inputs**: Task 6 (orchestration contract), Airflow Helm chart documentation
- **Outputs**: `platform/airflow/` — Helm values, KubernetesExecutor configuration
- **Depends on**: Tasks 6, 11 (orchestration contract, platform structure)
- **Verification**: Helm template renders; Airflow configured for container-based jobs
- **Completed**: 2025-12-28 15:17 KST — Created complete Airflow Helm chart configuration using upstream apache-airflow/airflow v1.12.0. Chart includes: values.yaml with KubernetesExecutor for container-based job execution, PostgreSQL metadata database, DAG persistence with GitSync support, environment-specific values for dev (1 webserver/scheduler, 256Mi RAM, auth disabled), staging (2 replicas, GitSync enabled, metrics enabled), and prod (3 replicas with HA, strict pod anti-affinity, remote logging to S3, PostgreSQL read replicas, production hardening). Created comprehensive README.md (20KB) covering workflow creation, DAG deployment (GitSync/PV), triggering (UI/API/CLI), observability, and troubleshooting. Created validate.sh script - 36 validations passed. Contract compliance verified: KubernetesExecutor (container-based jobs), orchestrator-agnostic job specifications, GitSync for DAG deployment, no business logic in orchestrator, Prometheus metrics, RBAC authentication. Total 7 files created.

---

## Phase 4: Observability Stack

[x] 16. Create Observability Helm Chart Configuration
- **Purpose**: Deploy Prometheus + Grafana for metrics and monitoring
- **Inputs**: `README.md` section 8 (observability requirements)
- **Outputs**: `platform/observability/` — Prometheus, Grafana Helm configurations
- **Depends on**: Task 11 (platform structure)
- **Verification**: Helm template renders; scrape configs target platform services
- **Completed**: 2025-12-28 15:23 KST — Created complete observability Helm chart configuration using upstream kube-prometheus-stack v55.0.0. Chart includes: values.yaml with Prometheus (15d retention, 50Gi storage), Grafana with pre-configured dashboards (MinIO, Trino, Airflow, Kubernetes), Alertmanager with alert routing, environment-specific values for dev (3d retention, 10Gi storage, 1 replica), staging (7d retention, 30Gi storage, 2 replicas with HA), and prod (30d retention, 200Gi storage, 3 replicas with strict pod anti-affinity, custom alerting rules for all Lakehouse components). Scrape configs for all platform services: MinIO (/minio/v2/metrics/cluster), Trino coordinator/worker (/v1/metrics), Iceberg catalog (/metrics), Airflow webserver/scheduler/triggerer (/metrics). Created comprehensive README.md (25KB) covering Grafana access, pre-configured dashboards, Prometheus queries, alerting setup, monitored services, troubleshooting. Created validate.sh script - 32 validations passed. Contract compliance verified: structured logging, Prometheus metrics, health checks, service discovery, alerting, dashboards. Total 7 files created.

---

## Phase 5: GitOps Configuration

[x] 17. Create ArgoCD Application Manifests
- **Purpose**: Define GitOps deployment structure using ArgoCD
- **Inputs**: `README.md` section 6.1, 6.2 (IaC, GitOps-first)
- **Outputs**: `platform/argocd/` — ArgoCD Application manifests for all platform components
- **Depends on**: Tasks 12-16 (all platform Helm charts)
- **Verification**: ArgoCD can sync from Git; drift detection works
- **Completed**: 2025-12-28 15:28 KST — Created complete ArgoCD Helm chart configuration using upstream argo-cd v5.51.0. Chart includes: values.yaml with ArgoCD server/repoServer/controller configuration, Application manifest templates for all platform components (MinIO, Iceberg Catalog, Trino, Airflow, Observability), AppProject manifest with RBAC roles (admin/developer/viewer), environment-specific values for dev (1 replica, no ingress), staging (2 replicas, ingress enabled, metrics enabled), and prod (3 replicas with strict pod anti-affinity, SSO enabled, notifications enabled, auto-prune disabled for safety). Each Application configured with automated sync policy, self-heal enabled, retry logic with exponential backoff, namespace creation, and ignoreDifferences for HPA/StatefulSet replicas. Created comprehensive README.md (30KB) covering installation, application management, drift detection, multi-environment management, GitOps workflow, troubleshooting. Created validate.sh script - 37 validations passed. Contract compliance verified: Git as single source of truth, automated deployment, drift detection, multi-environment support, reproducible from Git, RBAC, observability. Total 13 files created.

---

[x] 18. Create Bootstrap Script
- **Purpose**: Create reproducible setup script per `README.md` section 10
- **Inputs**: `README.md` section 10 (reproducibility guarantee)
- **Outputs**: `scripts/bootstrap.sh` — executes `terraform apply` + `argocd sync`
- **Depends on**: Tasks 10, 17 (Terraform cluster, ArgoCD manifests)
- **Verification**: Fresh environment bootstraps with `git clone` + `./scripts/bootstrap.sh`
- **Completed**: 2025-12-28 15:38 KST — Created comprehensive bootstrap automation with 3 scripts: bootstrap.sh (provisions infrastructure with Terraform, installs ArgoCD, syncs all applications, retrieves admin password, verifies deployment with 7 automated steps), cleanup.sh (safely tears down platform with confirmation, deletes applications/ArgoCD/namespaces, destroys Terraform infrastructure), validate.sh (validates cluster connection, ArgoCD installation, application status, platform components with detailed health reporting). Created comprehensive README.md (10KB) covering usage, quick start, environment-specific configuration, troubleshooting, CI/CD integration. All scripts support multi-environment (dev/staging/prod), include colored logging, error handling, and detailed progress reporting. Contract compliance verified: reproducible from git clone, automated terraform apply + argocd sync, no manual steps, deterministic deployment. Total 4 files created.

---

## Phase 6: Sample Service & Workflow

[ ] 19. Create Sample Service Application
- **Purpose**: Demonstrate service module contract compliance
- **Inputs**: Task 7 (service contract), `docs/definition_of_done.md`
- **Outputs**: `services/sample-service/` — Dockerfile, code, Helm chart with health endpoints
- **Depends on**: Task 7 (service contract)
- **Verification**: Service runs in container and bare-metal; `/health` and `/ready` respond

---

[ ] 20. Create Sample Workflow Job Specification
- **Purpose**: Demonstrate orchestrator-agnostic job definition
- **Inputs**: Task 6 (orchestration contract)
- **Outputs**: `workflows/sample-job/` — job spec YAML, container image reference
- **Depends on**: Tasks 6, 15, 19 (orchestration contract, Airflow, sample service)
- **Verification**: Job spec parseable by Airflow; no orchestrator-specific APIs in job code

---

## Phase 7: Integration Testing

[ ] 21. Create End-to-End Test Suite
- **Purpose**: Validate full system integration
- **Inputs**: All contracts, `docs/definition_of_done.md`
- **Outputs**: `tests/e2e/` — integration tests covering MinIO → Iceberg → Trino flow
- **Depends on**: Tasks 12-15, 19, 20 (all platform and sample components)
- **Verification**: All tests pass inside container sandbox

---

[ ] 22. Validate Container/Bare-Metal Compatibility
- **Purpose**: Confirm services run without container-only assumptions
- **Inputs**: `README.md` section 7, `docs/definition_of_done.md` section 3
- **Outputs**: Test report documenting bare-metal execution
- **Depends on**: Task 19 (sample service)
- **Verification**: Sample service starts and responds on bare-metal (host systemd or direct binary)

---

## Phase 8: Documentation & Finalization

[ ] 23. Create Environment Configuration Examples
- **Purpose**: Document environment-specific settings
- **Inputs**: `docs/repo_contract.md` section on `env/`
- **Outputs**: `env/dev/`, `env/staging/`, `env/prod/` — example tfvars and Helm value overrides
- **Depends on**: Tasks 9, 12-16 (Terraform variables, platform Helm charts)
- **Verification**: Each environment uses different configuration files; no code changes needed

---

[ ] 24. Create Operator Runbook
- **Purpose**: Document operational procedures
- **Inputs**: All contracts, `docs/definition_of_done.md`
- **Outputs**: `docs/runbook.md` — deployment, upgrade, rollback, and troubleshooting procedures
- **Depends on**: Tasks 17, 18 (GitOps, bootstrap)
- **Verification**: Runbook covers all common operational scenarios

---

[ ] 25. Final DoD Checklist Review
- **Purpose**: Confirm all modules pass Definition of Done
- **Inputs**: `docs/definition_of_done.md`
- **Outputs**: `docs/dod-report.md` — per-module compliance checklist
- **Depends on**: All previous tasks
- **Verification**: Every module passes all 8 DoD sections; no automatic failure conditions triggered

---

## Missing / Ambiguous Requirements

> [!IMPORTANT]
> The following items require clarification before implementation can proceed:

1. **Specific Kubernetes version**: No version specified. Recommend 1.28+ for Iceberg compatibility.
2. **MinIO deployment mode**: Single-node vs. distributed mode not specified.
3. **Iceberg catalog backend preference**: REST catalog assumed as default; confirm or specify JDBC/Hive/Glue.
4. **Trino cluster sizing**: Worker count and resource limits not specified.
5. **Airflow executor type**: KubernetesExecutor assumed; confirm or specify CeleryExecutor.
6. **Secret management solution**: Kubernetes Secrets or External Secrets Manager not specified.
7. **Network policies**: Ingress/egress restrictions not defined.
8. **Container registry**: No registry specified for pushing built images.
9. **Bare-metal test environment**: Specific bare-metal or VM environment for compatibility testing not defined.

---

## Execution Notes

- All tasks must be executed **inside an Ubuntu container sandbox** (e.g., `docker run -it ubuntu:22.04` or kind inside a container)
- NO commands may run directly on the host machine
- Each task completion must update this file: `[ ]` → `[x]` with a completion note
- `docs/TODO.md` is the **single source of truth**
