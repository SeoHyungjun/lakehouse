# Observability Helm Chart

Prometheus + Grafana monitoring stack for the Lakehouse platform, providing comprehensive metrics collection, visualization, and alerting.

## Overview

This Helm chart deploys the kube-prometheus-stack, which includes:

- **Prometheus**: Metrics collection and storage
- **Grafana**: Metrics visualization and dashboards
- **Alertmanager**: Alert routing and notification
- **Node Exporter**: Node-level metrics
- **Kube-State-Metrics**: Kubernetes object metrics
- **Prometheus Operator**: Kubernetes-native Prometheus management

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                   Observability Stack                        │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  ┌──────────────┐     ┌──────────────┐     ┌────────────┐  │
│  │  Prometheus  │────▶│   Grafana    │     │Alertmanager│  │
│  │  (Metrics)   │     │ (Dashboards) │     │  (Alerts)  │  │
│  └──────┬───────┘     └──────────────┘     └────────────┘  │
│         │                                                    │
│         │ Scrapes metrics from:                             │
│         ├─────────────────────────────────┐                │
│         │                                  │                │
└─────────┼──────────────────────────────────┼────────────────┘
          │                                  │
          ▼                                  ▼
  ┌───────────────┐              ┌───────────────────┐
  │ Platform      │              │ Kubernetes        │
  │ Services      │              │ Components        │
  ├───────────────┤              ├───────────────────┤
  │ • MinIO       │              │ • Nodes           │
  │ • Trino       │              │ • Pods            │
  │ • Iceberg     │              │ • Deployments     │
  │ • Airflow     │              │ • Services        │
  └───────────────┘              └───────────────────┘
```

## Prerequisites

- Kubernetes 1.28+
- Helm 3.8+
- 4GB+ RAM available for minimal deployment
- 16GB+ RAM recommended for production
- Persistent storage for Prometheus, Grafana, and Alertmanager

## Installation

### 1. Add Prometheus Community Helm Repository

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
```

### 2. Install Chart Dependencies

```bash
cd platform/observability
helm dependency update
```

### 3. Deploy Observability Stack

**Development Environment:**
```bash
helm install observability . \
  --namespace lakehouse-platform \
  --create-namespace \
  --values values-dev.yaml
```

**Staging Environment:**
```bash
helm install observability . \
  --namespace lakehouse-platform \
  --create-namespace \
  --values values-staging.yaml
```

**Production Environment:**
```bash
helm install observability . \
  --namespace lakehouse-platform \
  --create-namespace \
  --values values-prod.yaml
```

### 4. Verify Deployment

```bash
# Check pod status
kubectl get pods -n lakehouse-platform -l app.kubernetes.io/part-of=kube-prometheus-stack

# Check Prometheus
kubectl get prometheus -n lakehouse-platform

# Check Grafana
kubectl get deployment -n lakehouse-platform -l app.kubernetes.io/name=grafana

# Port-forward to access Grafana UI
kubectl port-forward -n lakehouse-platform svc/observability-grafana 3000:80

# Access Grafana at http://localhost:3000
# Default credentials (dev): admin / admin
```

## Configuration

### Environment-Specific Values

| File | Environment | Prometheus | Grafana | Alertmanager | Retention | Storage |
|------|-------------|------------|---------|--------------|-----------|---------|
| `values-dev.yaml` | Development | 1 replica | 1 replica | 1 replica | 3d | 10Gi |
| `values-staging.yaml` | Staging | 2 replicas | 2 replicas | 2 replicas | 7d | 30Gi |
| `values-prod.yaml` | Production | 3 replicas | 2 replicas | 3 replicas | 30d | 200Gi |

### Key Configuration Options

#### Prometheus Configuration

```yaml
kube-prometheus-stack:
  prometheus:
    prometheusSpec:
      retention: 30d
      retentionSize: "100GB"
      
      storageSpec:
        volumeClaimTemplate:
          spec:
            resources:
              requests:
                storage: 200Gi
      
      # Scrape configs for platform services
      additionalScrapeConfigs:
        - job_name: 'minio'
          static_configs:
            - targets: ['minio:9000']
```

#### Grafana Configuration

```yaml
kube-prometheus-stack:
  grafana:
    adminPassword: CHANGE_ME
    
    persistence:
      enabled: true
      size: 20Gi
    
    # Pre-configured dashboards
    dashboards:
      lakehouse:
        minio:
          gnetId: 13502  # MinIO dashboard
        trino:
          gnetId: 13629  # Trino dashboard
```

#### Alertmanager Configuration

```yaml
kube-prometheus-stack:
  alertmanager:
    config:
      receivers:
        - name: 'production-critical'
          pagerduty_configs:
            - service_key: 'YOUR_KEY'
          slack_configs:
            - channel: '#alerts-critical'
```

## Usage

### Accessing Grafana

#### Via Port-Forward (Development)

```bash
kubectl port-forward -n lakehouse-platform svc/observability-grafana 3000:80
```

Navigate to: `http://localhost:3000`

**Default Credentials:**
- Username: `admin`
- Password: `admin` (dev) or as configured

#### Via Ingress (Staging/Production)

Access via configured ingress hostname:
- Staging: `https://grafana-staging.example.com`
- Production: `https://grafana.company.internal`

### Pre-Configured Dashboards

The observability stack includes pre-configured dashboards for:

1. **Lakehouse Platform**
   - MinIO Dashboard (GrafanaNet ID: 13502)
   - Trino Dashboard (GrafanaNet ID: 13629)
   - Airflow Dashboard (GrafanaNet ID: 13629)

2. **Kubernetes**
   - Cluster Monitoring (GrafanaNet ID: 7249)
   - Node Exporter (GrafanaNet ID: 1860)

### Querying Metrics

#### Prometheus Query Examples

Access Prometheus UI:
```bash
kubectl port-forward -n lakehouse-platform svc/observability-kube-prometheus-prometheus 9090:9090
```

Navigate to: `http://localhost:9090`

**Example Queries:**

```promql
# MinIO metrics
minio_cluster_capacity_usable_total_bytes

# Trino query metrics
trino_queries_total{state="FINISHED"}
rate(trino_query_execution_time_seconds[5m])

# Iceberg catalog metrics
iceberg_catalog_requests_total
rate(iceberg_catalog_request_duration_seconds[5m])

# Airflow metrics
airflow_dag_run_total{state="success"}
airflow_task_instance_duration_seconds

# Kubernetes metrics
kube_pod_status_phase{namespace="lakehouse-platform"}
node_cpu_seconds_total
```

### Creating Custom Dashboards

1. Access Grafana UI
2. Click "+" → "Dashboard"
3. Add panels with Prometheus queries
4. Save dashboard to "Lakehouse" folder

**Example Panel:**
- **Title**: Trino Query Rate
- **Query**: `rate(trino_queries_total[5m])`
- **Visualization**: Graph

### Setting Up Alerts

#### Via Prometheus Rules

Custom alert rules are defined in `values-prod.yaml`:

```yaml
additionalPrometheusRulesMap:
  lakehouse-rules:
    groups:
      - name: lakehouse.rules
        rules:
          - alert: MinIODown
            expr: up{job="minio"} == 0
            for: 5m
            labels:
              severity: critical
```

#### Via Alertmanager

Configure notification channels in Alertmanager config:

```yaml
alertmanager:
  config:
    receivers:
      - name: 'slack-alerts'
        slack_configs:
          - api_url: 'https://hooks.slack.com/services/XXX'
            channel: '#alerts'
            title: '{{ .GroupLabels.alertname }}'
```

## Monitored Services

### Platform Services

| Service | Metrics Endpoint | Job Name | Port |
|---------|------------------|----------|------|
| MinIO | `/minio/v2/metrics/cluster` | `minio` | 9000 |
| Trino Coordinator | `/v1/metrics` | `trino-coordinator` | 9090 |
| Trino Worker | `/v1/metrics` | `trino-worker` | 9090 |
| Iceberg Catalog | `/metrics` | `iceberg-catalog` | 9090 |
| Airflow Webserver | `/metrics` | `airflow-webserver` | 9102 |
| Airflow Scheduler | `/metrics` | `airflow-scheduler` | 9102 |

### Kubernetes Components

- **Nodes**: CPU, memory, disk, network metrics
- **Pods**: Resource usage, restarts, status
- **Deployments**: Replica status, rollout status
- **Services**: Endpoint availability
- **Persistent Volumes**: Usage, capacity

## Observability

### Prometheus Metrics

Prometheus itself exposes metrics at `/metrics`:

```bash
kubectl port-forward -n lakehouse-platform svc/observability-kube-prometheus-prometheus 9090:9090
curl http://localhost:9090/metrics
```

**Key Metrics:**
- `prometheus_tsdb_storage_blocks_bytes` - Storage usage
- `prometheus_tsdb_head_samples_appended_total` - Samples ingested
- `prometheus_rule_evaluation_duration_seconds` - Rule evaluation time

### Grafana Metrics

Grafana exposes metrics at `/metrics`:

```bash
kubectl port-forward -n lakehouse-platform svc/observability-grafana 3000:80
curl http://localhost:3000/metrics
```

### Health Checks

**Prometheus:**
```bash
kubectl exec -n lakehouse-platform prometheus-observability-kube-prometheus-prometheus-0 -- \
  wget -qO- http://localhost:9090/-/healthy
```

**Grafana:**
```bash
kubectl exec -n lakehouse-platform deployment/observability-grafana -- \
  wget -qO- http://localhost:3000/api/health
```

## Scaling

### Prometheus Scaling

#### Vertical Scaling

Increase resources in values:

```yaml
kube-prometheus-stack:
  prometheus:
    prometheusSpec:
      resources:
        requests:
          memory: 8Gi
          cpu: 4000m
```

#### Horizontal Scaling (HA)

Increase replicas:

```yaml
kube-prometheus-stack:
  prometheus:
    prometheusSpec:
      replicas: 3
```

### Grafana Scaling

```yaml
kube-prometheus-stack:
  grafana:
    replicas: 3
```

### Storage Scaling

Increase PVC size:

```yaml
kube-prometheus-stack:
  prometheus:
    prometheusSpec:
      storageSpec:
        volumeClaimTemplate:
          spec:
            resources:
              requests:
                storage: 500Gi
```

## Troubleshooting

### Common Issues

#### 1. Prometheus Not Scraping Targets

**Symptoms:**
- Targets show as "down" in Prometheus UI
- No metrics from platform services

**Solution:**
```bash
# Check Prometheus targets
kubectl port-forward -n lakehouse-platform svc/observability-kube-prometheus-prometheus 9090:9090
# Navigate to http://localhost:9090/targets

# Verify service endpoints
kubectl get endpoints -n lakehouse-platform minio
kubectl get endpoints -n lakehouse-platform trino

# Check Prometheus logs
kubectl logs -n lakehouse-platform prometheus-observability-kube-prometheus-prometheus-0
```

#### 2. Grafana Cannot Connect to Prometheus

**Symptoms:**
- Dashboards show "No data"
- Datasource test fails

**Solution:**
```bash
# Check Prometheus service
kubectl get svc -n lakehouse-platform -l app.kubernetes.io/name=prometheus

# Test connection from Grafana pod
kubectl exec -n lakehouse-platform deployment/observability-grafana -- \
  wget -qO- http://observability-kube-prometheus-prometheus:9090/-/healthy

# Check Grafana datasource configuration
kubectl exec -n lakehouse-platform deployment/observability-grafana -- \
  cat /etc/grafana/provisioning/datasources/datasources.yaml
```

#### 3. Prometheus Running Out of Storage

**Symptoms:**
- Prometheus pod crashes with OOM
- Metrics gaps in Grafana

**Solution:**
```bash
# Check storage usage
kubectl exec -n lakehouse-platform prometheus-observability-kube-prometheus-prometheus-0 -- \
  df -h /prometheus

# Reduce retention period
# Update values.yaml:
# retention: 7d  # Instead of 30d

# Or increase storage
# Update values.yaml:
# storage: 500Gi  # Instead of 200Gi
```

#### 4. Alertmanager Not Sending Alerts

**Symptoms:**
- Alerts firing in Prometheus but not received
- No notifications in Slack/PagerDuty

**Solution:**
```bash
# Check Alertmanager status
kubectl port-forward -n lakehouse-platform svc/observability-kube-prometheus-alertmanager 9093:9093
# Navigate to http://localhost:9093

# Check Alertmanager logs
kubectl logs -n lakehouse-platform alertmanager-observability-kube-prometheus-alertmanager-0

# Test alert routing
kubectl exec -n lakehouse-platform alertmanager-observability-kube-prometheus-alertmanager-0 -- \
  amtool config routes test --config.file=/etc/alertmanager/config/alertmanager.yaml
```

### Debug Commands

```bash
# Check all observability resources
kubectl get all -n lakehouse-platform -l app.kubernetes.io/part-of=kube-prometheus-stack

# Check Prometheus configuration
kubectl get prometheus -n lakehouse-platform -o yaml

# Check ServiceMonitors
kubectl get servicemonitor -n lakehouse-platform

# Check PrometheusRules
kubectl get prometheusrule -n lakehouse-platform

# Exec into Prometheus pod
kubectl exec -n lakehouse-platform -it prometheus-observability-kube-prometheus-prometheus-0 -- /bin/sh

# Check Prometheus config
kubectl exec -n lakehouse-platform prometheus-observability-kube-prometheus-prometheus-0 -- \
  cat /etc/prometheus/config_out/prometheus.env.yaml
```

## Upgrading

### Upgrade kube-prometheus-stack Version

1. Update `Chart.yaml`:
```yaml
dependencies:
  - name: kube-prometheus-stack
    version: "56.0.0"  # New version
```

2. Update dependencies:
```bash
helm dependency update .
```

3. Apply upgrade:
```bash
helm upgrade observability . \
  --namespace lakehouse-platform \
  --values values-prod.yaml
```

### Rollback

```bash
# View release history
helm history observability -n lakehouse-platform

# Rollback to previous version
helm rollback observability -n lakehouse-platform
```

## Security

### Credentials Management

**Development:**
- Default admin password acceptable for local testing

**Staging/Production:**
- Use external secrets for Grafana admin password
- Use LDAP/OAuth for authentication

**Example with External Secrets:**
```yaml
kube-prometheus-stack:
  grafana:
    admin:
      existingSecret: grafana-admin-credentials
      userKey: admin-user
      passwordKey: admin-password
```

### Network Policies

Recommended network policies for production:

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: prometheus-ingress
spec:
  podSelector:
    matchLabels:
      app.kubernetes.io/name: prometheus
  policyTypes:
    - Ingress
  ingress:
    - from:
        - podSelector:
            matchLabels:
              app.kubernetes.io/name: grafana
      ports:
        - protocol: TCP
          port: 9090
```

## Contract Compliance

This chart provides observability for all Lakehouse platform services per `README.md` section 8:

✅ **Structured Logging**: All services log to stdout  
✅ **Prometheus Metrics**: All services expose `/metrics` endpoint  
✅ **Health Checks**: All services have liveness/readiness probes  
✅ **Service Discovery**: Automatic scraping via ServiceMonitors  
✅ **Alerting**: Custom alerts for platform-specific issues  
✅ **Dashboards**: Pre-configured dashboards for all services  

## References

- **kube-prometheus-stack**: https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack
- **Prometheus Documentation**: https://prometheus.io/docs/
- **Grafana Documentation**: https://grafana.com/docs/
- **Alertmanager Documentation**: https://prometheus.io/docs/alerting/latest/alertmanager/
- **PromQL Guide**: https://prometheus.io/docs/prometheus/latest/querying/basics/
- **Grafana Dashboards**: https://grafana.com/grafana/dashboards/

## Support

For issues or questions:
1. Check the troubleshooting section above
2. Review Prometheus logs: `kubectl logs -n lakehouse-platform prometheus-observability-kube-prometheus-prometheus-0`
3. Check Grafana logs: `kubectl logs -n lakehouse-platform deployment/observability-grafana`
4. Access Prometheus UI: `http://localhost:9090` (via port-forward)
5. Access Grafana UI: `http://localhost:3000` (via port-forward)
