# Repository Contract

This document defines the mandatory repository structure and ownership rules.
All implementations must strictly follow this contract.

---

## 1. Top-Level Directory Structure

repo-root/
├── infra/              # Terraform only (cloud / cluster provisioning)
├── platform/           # Cluster-level components (Helm-based)
├── services/           # Application & data-processing services
├── workflows/          # Orchestrator-agnostic job specifications
├── contracts/          # API, data, and interface contracts
├── env/                # Environment-specific configuration
├── docs/               # Architecture & engineering documentation
└── README.md

---

## 2. Directory Responsibilities

### infra/
- Terraform only
- Provisions cluster, network, storage
- Must not contain application logic

### platform/
- Helm charts for shared platform components
- Examples: MinIO, Trino
- No business logic allowed

### services/
- Custom application logic
- Each service must be independently buildable
- Must not depend on Kubernetes internals

### workflows/
- Orchestrator-agnostic job definitions
- No Airflow/Dagster-specific code allowed

### contracts/
- Public interfaces between modules
- API schemas, data contracts, protocol definitions

### env/
- Environment-specific configuration only
- No secrets, no code

---

## 3. Dependency Rules

- infra/ must not depend on any other directory
- services/ may depend only on contracts/
- workflows/ may reference services only via image names
- Circular dependencies are forbidden

---

## 4. Enforcement Rule

If a directory’s responsibility is unclear,
the implementation is considered invalid.
