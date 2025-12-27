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

[ ] 8. Create Terraform Module Structure
- **Purpose**: Set up Terraform directory layout for infrastructure provisioning
- **Inputs**: `docs/repo_contract.md` section on `infra/`
- **Outputs**: `infra/` with modules: `cluster/`, `network/`, `storage/`; root `main.tf`, `variables.tf`, `outputs.tf`
- **Depends on**: Task 1 (directory structure)
- **Verification**: `terraform init` succeeds in `infra/`

---

[ ] 9. Define Terraform Variables & Environment Abstraction
- **Purpose**: Create environment-agnostic Terraform configuration
- **Inputs**: `README.md` sections 3.2, 6.2 (configuration vs code, GitOps-first)
- **Outputs**: `infra/variables.tf` with environment inputs; `env/` with example tfvars files
- **Depends on**: Task 8 (Terraform structure)
- **Verification**: No hardcoded values in Terraform; all values injectable

---

[ ] 10. Create Kubernetes Cluster Terraform Module (kind-compatible)
- **Purpose**: Provision a local Kubernetes cluster for development/testing
- **Inputs**: Task 2 (cluster contract), kind documentation
- **Outputs**: `infra/modules/cluster/` — Terraform module to create kind cluster
- **Depends on**: Tasks 8, 9 (Terraform structure and variables)
- **Verification**: `terraform apply` creates a working kind cluster inside container sandbox

---

## Phase 3: Platform Layer (Helm Charts)

[ ] 11. Create Platform Helm Chart Structure
- **Purpose**: Set up Helm chart layout for platform components
- **Inputs**: `docs/repo_contract.md` section on `platform/`
- **Outputs**: `platform/` with subdirectories for each component (ready for Helm charts)
- **Depends on**: Task 1 (directory structure)
- **Verification**: Directory structure matches Helm chart conventions

---

[ ] 12. Create MinIO Helm Chart Configuration
- **Purpose**: Deploy MinIO as S3-compatible object storage
- **Inputs**: Task 3 (object storage contract), MinIO Helm chart documentation
- **Outputs**: `platform/minio/` — Helm values, Chart.yaml referencing upstream MinIO chart
- **Depends on**: Tasks 3, 11 (object storage contract, platform structure)
- **Verification**: Helm template renders valid Kubernetes manifests; no hardcoded IPs

---

[ ] 13. Create Iceberg Catalog Helm Chart Configuration
- **Purpose**: Deploy Iceberg REST catalog
- **Inputs**: Task 4 (Iceberg contract), Apache Iceberg REST catalog documentation
- **Outputs**: `platform/iceberg-catalog/` — Helm values, deployment configuration
- **Depends on**: Tasks 4, 11, 12 (Iceberg contract, platform structure, MinIO)
- **Verification**: Helm template renders; catalog connects to MinIO via DNS endpoint

---

[ ] 14. Create Trino Helm Chart Configuration
- **Purpose**: Deploy Trino query engine with Iceberg connector
- **Inputs**: Task 5 (query engine contract), Trino Helm chart documentation
- **Outputs**: `platform/trino/` — Helm values, Iceberg connector configuration
- **Depends on**: Tasks 5, 11, 13 (query engine contract, platform structure, Iceberg catalog)
- **Verification**: Helm template renders; Trino configured to use Iceberg catalog only

---

[ ] 15. Create Airflow Helm Chart Configuration
- **Purpose**: Deploy Airflow as workflow orchestrator
- **Inputs**: Task 6 (orchestration contract), Airflow Helm chart documentation
- **Outputs**: `platform/airflow/` — Helm values, KubernetesExecutor configuration
- **Depends on**: Tasks 6, 11 (orchestration contract, platform structure)
- **Verification**: Helm template renders; Airflow configured for container-based jobs

---

## Phase 4: Observability Stack

[ ] 16. Create Observability Helm Chart Configuration
- **Purpose**: Deploy Prometheus + Grafana for metrics and monitoring
- **Inputs**: `README.md` section 8 (observability requirements)
- **Outputs**: `platform/observability/` — Prometheus, Grafana Helm configurations
- **Depends on**: Task 11 (platform structure)
- **Verification**: Helm template renders; scrape configs target platform services

---

## Phase 5: GitOps Configuration

[ ] 17. Create ArgoCD Application Manifests
- **Purpose**: Define GitOps deployment structure using ArgoCD
- **Inputs**: `README.md` section 6.1, 6.2 (IaC, GitOps-first)
- **Outputs**: `platform/argocd/` — ArgoCD Application manifests for all platform components
- **Depends on**: Tasks 12-16 (all platform Helm charts)
- **Verification**: ArgoCD can sync from Git; drift detection works

---

[ ] 18. Create Bootstrap Script
- **Purpose**: Create reproducible setup script per `README.md` section 10
- **Inputs**: `README.md` section 10 (reproducibility guarantee)
- **Outputs**: `scripts/bootstrap.sh` — executes `terraform apply` + `argocd sync`
- **Depends on**: Tasks 10, 17 (Terraform cluster, ArgoCD manifests)
- **Verification**: Fresh environment bootstraps with `git clone` + `./scripts/bootstrap.sh`

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
