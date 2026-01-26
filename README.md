# Lakehouse Platform

> Modern data lakehouse platform - Kubernetes-native, vendor-neutral, production-ready

**English** | [한국어](README_KR.md)

---

## Overview

A modern data lakehouse platform combining the best of **data lakes** and **data warehouses**, built on Apache Iceberg, Trino, and MinIO, designed to run on Kubernetes.

### Why Lakehouse?

- 🏢 **Warehouse Performance**: Fast analytics with SQL queries
- 💰 **Lake Economics**: Cost-effective object storage
- 🔒 **ACID Transactions**: Data integrity with Apache Iceberg
- 🔄 **Time Travel**: Query historical data snapshots
- 🚀 **Scalability**: Kubernetes-based infinite scaling

---

## Quick Start

```bash
# 1. Clone repository
git clone https://github.com/SeoHyungjun/lakehouse.git
cd lakehouse

# 2. Deploy development environment
./scripts/bootstrap.sh dev

# 3. Access services
kubectl port-forward -n lakehouse-platform svc/trino 8080:8080 &
kubectl port-forward -n lakehouse-platform svc/minio 9000:9000 &

# 4. Run your first query
trino --server localhost:8080 --catalog iceberg --schema default
```

**See detailed guide**: [Getting Started](docs/GETTING_STARTED_KR.md) (Korean)

---

## Core Components

| Component | Role | Technology |
|-----------|------|------------|
| **Object Storage** | Data file storage | MinIO (S3-compatible) |
| **Metadata Management** | Table schema & metadata | Apache Iceberg REST Catalog |
| **Query Engine** | SQL query execution | Trino |
| **Workflow** | Pipeline scheduling | Apache Airflow |
| **Monitoring** | Metrics & visualization | Prometheus + Grafana |
| **GitOps** | Deployment automation | ArgoCD |

---

## Architecture

```
┌─────────────────────────────────────────┐
│      Users / Applications               │
└──────────────┬──────────────────────────┘
               │
    ┌──────────┴──────────┐
    │                     │
┌───▼────┐          ┌────▼────┐
│ Trino  │◄─────────┤ Airflow │
│(Query) │   SQL    │(Workflow)│
└─┬───┬──┘          └─────────┘
  │   │
  │   │  ① Metadata
  │   └──┤ Iceberg Catalog│
  │      │  (Metadata)    │
  │      └───────┬────────┘
  │              │ ③ Metadata files
  │      ┌───────▼────────┐
  └──────┤     MinIO      │ ② Data files
         │ (Data Storage) │
         └────────────────┘

① Trino queries Iceberg Catalog for table metadata
② Trino reads/writes data files directly from/to MinIO  
③ Iceberg Catalog stores metadata files in MinIO
④ Airflow sends SQL queries to Trino only
```
      │ (Data Storage) │
      └────────────────┘
```

---

## Project Structure

```
lakehouse/
├── contracts/          # 📋 Component interface contracts (API specs)
├── docs/               # 📚 Documentation
├── env/                # ⚙️  Environment-specific configurations
│   ├── dev/
│   ├── staging/
│   └── prod/
├── infra/              # 🏗️  Infrastructure code (Terraform)
├── platform/           # 🎯 Platform components (Helm charts)
│   ├── minio/
│   ├── iceberg-catalog/
│   ├── trino/
│   ├── airflow/
│   ├── observability/
│  └── argocd/
├── scripts/            # 🔧 Automation scripts
├── services/           # 🚀 Custom services
├── workflows/          # 🔄 Workflow jobs
└── tests/              # ✅ Tests
```

---

## Documentation

### Core Documents
- **[Documentation Guide](docs/README.md)** - Documentation structure
- **[Getting Started](docs/GETTING_STARTED_KR.md)** - Quick start guide (Korean)
- **[Architecture](docs/ARCHITECTURE_KR.md)** - System design (Korean)
- **[Runbook](docs/runbook.md)** - Operations guide

### Contracts
- **[Contracts Overview](contracts/README.md)** - Contract system
- **[Repository Contract](contracts/repository-contract.md)** - Directory structure rules
- **[Kubernetes Cluster](contracts/kubernetes-cluster.md)** - Cluster requirements
- **[Object Storage](contracts/object-storage.md)** - S3 API interface
- **[Iceberg Catalog](contracts/iceberg-catalog.md)** - Catalog REST API
- **[Query Engine](contracts/query-engine.md)** - Trino SQL interface
- **[Service Module](contracts/service-module.md)** - Service standards
- **[Workflow Orchestration](contracts/workflow-orchestration.md)** - Orchestration spec

---

## Deployment

### Development
```bash
./scripts/bootstrap.sh dev
# Single node, minimal resources, local Kind cluster
```

### Staging
```bash
./scripts/bootstrap.sh staging
# 3 nodes (HA), moderate resources, external access
```

### Production
```bash
./scripts/bootstrap.sh prod
# 5+ nodes (HA), maximum resources, TLS/OAuth2, strict security
```

---

## Core Principles

> **Everything is replaceable.  
> Nothing is hardcoded.  
> Git defines reality.**

### 1. Contract-First Design
All modules expose stable contracts, independent of implementation.

### 2. No IP Hardcoding
All inter-module communication uses DNS-based endpoints.

### 3. Configuration vs Code
- Code is immutable
- Configuration is environment-specific and injectable

### 4. GitOps-First
Git is the single source of truth. Any environment should be reproducible from Git alone.

### 5. Observability Mandatory
All modules must provide:
- Structured logging (stdout)
- Metrics (Prometheus-compatible)
- Health checks (liveness/readiness)

**See full principles**: [Architecture Document](README.md)

---

## License

Apache 2.0 License - See [LICENSE](LICENSE) file for details

---

## Acknowledgments

Built on these amazing open-source projects:
- [Apache Iceberg](https://iceberg.apache.org/)
- [Trino](https://trino.io/)
- [MinIO](https://min.io/)
- [Apache Airflow](https://airflow.apache.org/)
- [Prometheus](https://prometheus.io/) / [Grafana](https://grafana.com/)
- [ArgoCD](https://argoproj.github.io/cd/)

---

**Happy Data Engineering! 🚀**
</ Made with ❤️ by the Lakehouse Team

[⬆ Back to top](#lakehouse-platform)

</div>
