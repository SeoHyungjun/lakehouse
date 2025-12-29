# Lakehouse Project – Architecture & Engineering Principles

**English** | [한국어](README_KR.md)


## 1. Project Scope

This project defines a **Lakehouse architecture** that is:

* Kubernetes-based
* Open-source first
* Reproducible via Git
* Modular and easily replaceable
* Deployable across container, cloud, and physical environments

The goal is **long-term maintainability and portability**, not short-term convenience.

---

## 2. Core Architectural Principles

### 2.1 Kubernetes as Orchestration Layer

* Kubernetes is used as the **central orchestration and control plane**
* Kubernetes is **not** treated as a data store or business logic layer
* Not all modules must run inside Kubernetes Pods

---

### 2.2 Execution Location Is an Implementation Detail

Each module may run as:

* A Kubernetes Pod
* An external service (VM or bare-metal)
* A managed cloud service

**Execution location must never affect how other modules interact with it.**

---

### 2.3 Contract-First Module Design

All modules must expose a **stable contract**, independent of implementation:

* REST / gRPC API
* SQL endpoint
* S3-compatible object interface

Other modules must depend **only on the contract**, never on:

* Physical device
* Container runtime
* Deployment method

---

## 3. Networking & Configuration Rules

### 3.1 No IP Address Hardcoding

* IP addresses must **never** appear in configuration files
* All inter-module communication must use:

  * DNS-based endpoints
  * Protocol + Port + Authentication info

Example:

```yaml
object_storage:
  endpoint: http://minio.storage.svc.cluster.local:9000
```

External services must follow the same rule:

```yaml
query_engine:
  endpoint: https://trino.company.internal
```

---

### 3.2 Configuration vs Code Separation

* **Code is immutable**
* **Configuration is environment-specific**

Rules:

* No environment-specific logic in code
* No credentials committed to Git
* Configuration must be injectable via:

  * Helm values
  * Environment variables
  * External config providers

---

## 4. Data & Storage Architecture

### 4.1 Object Storage

* Default object storage: **MinIO**
* All object storage access must use **S3-compatible APIs only**
* No vendor-specific SDKs (AWS, Azure, GCP) are allowed in application code

This ensures easy migration to:

* Amazon S3
* Azure Blob Storage (S3-compatible layer)
* Other compatible object stores

---

### 4.2 Table Format

* **Apache Iceberg** is the canonical table format
* Iceberg is treated as the single source of truth for analytical tables

#### Iceberg Catalog

The catalog backend must be replaceable:

* REST catalog
* JDBC catalog
* Hive Metastore
* Cloud-managed catalogs (e.g., AWS Glue)

Catalog choice must be configuration-only.

---

### 4.3 Query Engine

* **Trino** is used as the query engine
* Trino accesses data **only through Iceberg**
* No direct access to raw object paths outside Iceberg metadata

---

## 5. Workflow Orchestration

### 5.1 Orchestrator Choice

* Default orchestrator: **Airflow**
* Alternative supported: **Dagster**

The system must allow switching orchestrators **without rewriting core jobs**.

---

### 5.2 Orchestrator Abstraction

Workflows must be defined using a **Job Specification**, not orchestrator-specific APIs.

Example:

```yaml
job:
  name: daily_ingest
  image: lakehouse/ingest:1.0
  params:
    execution_date: "{{ ds }}"
```

Rules:

* Orchestrator only triggers jobs
* Business logic lives inside containerized jobs
* No direct dependency on Airflow/Dagster internals

---

## 6. Infrastructure & Deployment

### 6.1 Infrastructure as Code

| Tool                   | Responsibility                                       |
| ---------------------- | ---------------------------------------------------- |
| Terraform              | Provision infrastructure (cluster, network, storage) |
| Helm                   | Package and configure applications                   |
| GitOps (ArgoCD / Flux) | Reconcile desired state                              |

Manual deployment is discouraged.

---

### 6.2 GitOps-First

* Git is the **single source of truth**
* A fresh environment must be bootstrappable from Git alone
* Drift between Git and runtime state is not allowed

---

## 7. Container & Bare-Metal Compatibility

* Containers are the default execution unit
* All services must be runnable as:

  * Containers
  * Standalone binaries (systemd / bare-metal)

Rules:

* No container-only assumptions (e.g., hardcoded paths)
* Startup and configuration must be environment-agnostic

---

## 8. Observability (Mandatory)

All modules must provide:

* Structured logging (stdout)
* Metrics (Prometheus-compatible)
* Health checks (liveness / readiness)

Observability is **not optional**.

---

## 9. Security & Secrets

* Secrets must never be committed to Git
* Secrets must be managed via:

  * Kubernetes Secrets
  * External Secrets Manager
* All network communication must be authenticated

---

## 10. Reproducibility Guarantee

This project must satisfy the following:

* A new environment can be created with:

  ```bash
  git clone
  terraform apply
  argocd sync
  ```
* No undocumented manual steps
* Same Git commit → same system behavior

---

## 11. Non-Goals

This project explicitly does **not** aim to:

* Optimize for single-node performance
* Hardcode infrastructure assumptions
* Tie itself to a specific cloud provider

---

# Guiding Principle (TL;DR)

> **Everything is replaceable.
> Nothing is hardcoded.
> Git defines reality.**

---
