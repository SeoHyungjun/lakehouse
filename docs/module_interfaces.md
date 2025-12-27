# Module Interface Definitions

This document defines mandatory interfaces for all major modules.
All modules must be replaceable without changing consumers.

---

## 1. Object Storage Module

Interface:
- S3-compatible API
- DNS-based endpoint
- Access key authentication

Rules:
- No vendor-specific SDK usage
- No direct filesystem access
- Configuration via environment variables only

---

## 2. Table Format Module (Iceberg)

Interface:
- Apache Iceberg table format
- External catalog backend

Rules:
- All reads/writes via Iceberg APIs
- No direct object path access
- Catalog must be replaceable (REST / JDBC / Hive / Glue)

---

## 3. Query Engine Module (Trino)

Interface:
- SQL over HTTP
- JDBC-compatible endpoint

Rules:
- Queries operate on Iceberg tables only
- No engine-specific SQL extensions in shared code
- Endpoint must be configurable

---

## 4. Workflow Orchestration Module

Interface:
- Job specification (YAML or JSON)
- External trigger mechanism

Rules:
- Orchestrator contains no business logic
- Jobs must be container-based
- Orchestrator-specific APIs inside jobs are forbidden

---

## 5. Service Module

Interface:
- REST or gRPC API
- /health and /ready endpoints

Rules:
- No hardcoded endpoints or credentials
- No dependency on Kubernetes APIs
- Must run identically in container and bare-metal environments

---

## 6. Contract Stability Rule

Once a contract is published,
it cannot be broken without versioning and migration.
