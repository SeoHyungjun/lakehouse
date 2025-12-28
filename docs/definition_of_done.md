# Definition of Done (DoD)

This document defines when a module is considered complete.
If any item is missing, the work is not done.

---

## 1. Build & Deployment

- Buildable as a container image
- Deployable via Helm (if applicable)
- Removable without impacting other modules

---

## 2. Configuration

- No hardcoded IPs or endpoints
- All configuration injectable
- Secrets externalized

---

## 3. Portability

- Runs on Kubernetes
- Runs on VM or bare-metal
- No container-only assumptions

---

## 4. Observability

- Structured logs to stdout
- Metrics endpoint exposed
- Health checks implemented

---

## 5. Interface Compliance

- Fully complies with contracts/ 
- No reliance on internal implementations of other modules

---

## 6. Reproducibility

- Works in a fresh environment
- No undocumented manual steps
- Same config produces same behavior

---

## 7. Automatic Failure Conditions

Any of the following immediately fails DoD:
- Hardcoded IP addresses
- Direct cloud vendor SDK usage
- Orchestrator-specific logic inside jobs
- Shared mutable storage between modules

---

## 8. Final Rule

If replacing this module requires changes to other modules,
it is not done.
