# Lakehouse 플랫폼

> 현대적인 데이터 레이크하우스 플랫폼 - Kubernetes 네이티브, 벤더 중립적, 프로덕션 준비 완료

[English](README.md) | **한국어**

---

## 📋 목차

- [개요](#개요)
- [주요 특징](#주요-특징)
- [빠른 시작](#빠른-시작)
- [아키텍처](#아키텍처)
- [문서](#문서)
- [프로젝트 구조](#프로젝트-구조)
- [기여하기](#기여하기)
- [라이선스](#라이선스)

---

## 개요

Lakehouse는 **데이터 레이크**와 **데이터 웨어하우스**의 장점을 결합한 현대적인 데이터 플랫폼입니다. Apache Iceberg, Trino, MinIO를 기반으로 구축되어 있으며, Kubernetes에서 실행되도록 설계되었습니다.

### 왜 Lakehouse인가?

- 🏢 **데이터 웨어하우스의 성능**: SQL 쿼리로 빠른 분석
- 💰 **데이터 레이크의 경제성**: 저렴한 객체 스토리지 사용
- 🔒 **ACID 트랜잭션**: Apache Iceberg로 데이터 무결성 보장
- 🔄 **Time Travel**: 과거 시점의 데이터 조회 가능
- 🚀 **확장성**: Kubernetes 기반 무한 확장

---

## 주요 특징

### 🎯 핵심 컴포넌트

| 컴포넌트 | 역할 | 기술 스택 |
|---------|------|----------|
| **객체 스토리지** | 실제 데이터 파일 저장 | MinIO (S3 호환) |
| **메타데이터 관리** | 테이블 스키마 및 메타데이터 | Apache Iceberg REST Catalog |
| **쿼리 엔진** | SQL 쿼리 실행 | Trino |
| **워크플로우** | 데이터 파이프라인 스케줄링 | Apache Airflow |
| **모니터링** | 메트릭 수집 및 시각화 | Prometheus + Grafana |
| **GitOps** | 배포 자동화 | ArgoCD |

### ✨ 주요 기능

- ✅ **완전 자동화 배포**: 한 번의 명령으로 전체 플랫폼 설치
- ✅ **환경별 설정**: 개발/스테이징/프로덕션 환경 분리
- ✅ **고가용성(HA)**: 프로덕션 환경에서 무중단 운영
- ✅ **벤더 중립적**: 특정 클라우드에 종속되지 않음
- ✅ **완벽한 관찰성**: 모든 컴포넌트의 메트릭 및 로그 수집
- ✅ **보안**: TLS, OAuth2, RBAC 지원
- ✅ **테스트 완료**: E2E 테스트로 검증된 안정성

---

## 빠른 시작

### 사전 요구사항

다음 도구들이 설치되어 있어야 합니다:

```bash
# macOS
brew install kubectl helm terraform kind

# Linux
# kubectl, helm, terraform, kind 설치
# 자세한 내용은 docs/GETTING_STARTED_KR.md 참조
```

### 5분 안에 시작하기

```bash
# 1. 저장소 클론
git clone https://github.com/your-org/lakehouse.git
cd lakehouse

# 2. 개발 환경 배포
./scripts/bootstrap.sh dev

# 3. 서비스 접속
kubectl port-forward -n lakehouse-platform svc/trino 8080:8080 &
kubectl port-forward -n lakehouse-platform svc/minio 9000:9000 &
kubectl port-forward -n lakehouse-platform svc/grafana 3000:3000 &

# 4. 첫 번째 쿼리 실행
trino --server localhost:8080 --catalog iceberg --schema default
```

**축하합니다! 🎉** Lakehouse 플랫폼이 실행 중입니다.

자세한 가이드는 **[시작 가이드](docs/GETTING_STARTED_KR.md)**를 참조하세요.

---

## 아키텍처

### 전체 아키텍처

```
┌─────────────────────────────────────────────────────────┐
│                  사용자 / 애플리케이션                     │
└────────────────────┬────────────────────────────────────┘
                     │
         ┌───────────┴───────────┐
         │                       │
    ┌────▼─────┐          ┌─────▼────┐
    │  Trino   │          │ Airflow  │
    │ (쿼리)    │          │(워크플로우)│
    └────┬─────┘          └─────┬────┘
         │                      │
         └──────────┬───────────┘
                    │
            ┌───────▼────────┐
            │ Iceberg Catalog│
            │  (메타데이터)   │
            └───────┬────────┘
                    │
            ┌───────▼────────┐
            │     MinIO      │
            │  (데이터 저장)  │
            └────────────────┘
```

### 데이터 흐름

1. **데이터 저장**: 사용자 → Trino → Iceberg Catalog → MinIO
2. **데이터 조회**: SQL 쿼리 → Trino → Iceberg Catalog → MinIO
3. **워크플로우**: Airflow → Kubernetes Job → Trino/MinIO

자세한 아키텍처는 **[아키텍처 가이드](docs/ARCHITECTURE_KR.md)**를 참조하세요.

---

## 문서

### 📚 주요 문서

| 문서 | 설명 |
|------|------|
| **[시작 가이드](docs/GETTING_STARTED_KR.md)** | 처음 사용자를 위한 완벽 가이드 (필독!) |
| **[아키텍처 가이드](docs/ARCHITECTURE_KR.md)** | 시스템 아키텍처 및 데이터 흐름 |
| **[운영 가이드](docs/runbook.md)** | 배포, 업그레이드, 롤백, 문제 해결 |
| **[DoD 보고서](docs/dod-report.md)** | 모든 모듈의 완료 기준 검증 |

### 📋 계약서 (Contracts)

모든 컴포넌트는 명확한 인터페이스 계약을 따릅니다:

- [Kubernetes 클러스터](contracts/kubernetes-cluster.md)
- [객체 스토리지 (S3)](contracts/object-storage.md)
- [Iceberg 카탈로그](contracts/iceberg-catalog.md)
- [쿼리 엔진](contracts/query-engine.md)
- [서비스 모듈](contracts/service-module.md)
- [워크플로우 오케스트레이션](contracts/workflow-orchestration.md)

---

## 프로젝트 구조

```
lakehouse/
├── contracts/              # 📋 컴포넌트 인터페이스 정의
├── docs/                   # 📚 문서
│   ├── GETTING_STARTED_KR.md    # 시작 가이드 (한글)
│   ├── ARCHITECTURE_KR.md       # 아키텍처 가이드 (한글)
│   ├── runbook.md               # 운영 가이드
│   └── dod-report.md            # DoD 검증 보고서
├── env/                    # ⚙️  환경별 설정 파일
│   ├── dev/                     # 개발 환경
│   ├── staging/                 # 스테이징 환경
│   └── prod/                    # 프로덕션 환경
├── infra/                  # 🏗️  인프라 코드 (Terraform)
├── platform/               # 🎯 플랫폼 컴포넌트 (Helm 차트)
│   ├── minio/                   # MinIO
│   ├── iceberg-catalog/         # Iceberg Catalog
│   ├── trino/                   # Trino
│   ├── airflow/                 # Airflow
│   ├── observability/           # Prometheus + Grafana
│   └── argocd/                  # ArgoCD
├── scripts/                # 🔧 자동화 스크립트
│   ├── bootstrap.sh             # 전체 플랫폼 배포
│   ├── cleanup.sh               # 플랫폼 제거
│   └── validate.sh              # 플랫폼 검증
├── services/               # 🚀 샘플 서비스
│   └── sample-service/          # REST API 샘플
├── tests/                  # ✅ 테스트 코드
│   ├── e2e/                     # E2E 테스트
│   └── compatibility/           # 호환성 테스트
└── workflows/              # 🔄 샘플 워크플로우
    └── sample-job/              # 데이터 파이프라인 샘플
```

---

## 사용 예시

### 테이블 생성 및 데이터 삽입

```sql
-- Trino 접속
trino --server localhost:8080 --catalog iceberg --schema default

-- 스키마 생성
CREATE SCHEMA sales;

-- 테이블 생성
CREATE TABLE sales.orders (
  order_id BIGINT,
  customer_id BIGINT,
  order_date DATE,
  amount DECIMAL(10, 2)
)
WITH (
  format = 'PARQUET',
  partitioning = ARRAY['order_date']
);

-- 데이터 삽입
INSERT INTO sales.orders VALUES
  (1, 100, DATE '2024-01-01', 1500.00),
  (2, 101, DATE '2024-01-02', 2500.00);

-- 조회
SELECT * FROM sales.orders;

-- Time Travel (과거 시점 조회)
SELECT * FROM sales.orders FOR TIMESTAMP AS OF TIMESTAMP '2024-01-01 12:00:00';
```

### Airflow DAG 예시

```python
# workflows/sample-job/airflow/dag.py
from airflow import DAG
from airflow.providers.cncf.kubernetes.operators.kubernetes_pod import KubernetesPodOperator
from datetime import datetime

with DAG(
    'daily_sales_pipeline',
    start_date=datetime(2024, 1, 1),
    schedule_interval='@daily',
    catchup=False
) as dag:
    
    ingest_task = KubernetesPodOperator(
        task_id='ingest_sales_data',
        name='ingest-sales',
        namespace='lakehouse-platform',
        image='lakehouse/ingest-job:1.0',
        cmds=['python', 'ingest.py'],
        arguments=['--date', '{{ ds }}']
    )
```

---

## 환경별 배포

### 개발 환경

```bash
# 로컬 Kind 클러스터에 배포
./scripts/bootstrap.sh dev

# 특징:
# - 단일 노드
# - 최소 리소스
# - 간단한 인증
```

### 스테이징 환경

```bash
# 스테이징 클러스터에 배포
./scripts/bootstrap.sh staging

# 특징:
# - 3개 노드 (HA)
# - 중간 리소스
# - 외부 접속 (Ingress)
# - 자동 스케일링
```

### 프로덕션 환경

```bash
# 프로덕션 클러스터에 배포
./scripts/bootstrap.sh prod

# 특징:
# - 5+ 노드 (고가용성)
# - 최대 리소스
# - TLS/OAuth2 인증
# - 엄격한 보안 정책
# - 알림 및 모니터링
```

---

## 커스터마이징

### 리소스 조정

```yaml
# env/prod/helm-values.yaml
trino:
  server:
    workers: 10  # 워커 수 증가
  worker:
    resources:
      requests:
        memory: 16Gi  # 메모리 증가
        cpu: 8000m
```

### 새 카탈로그 추가

```yaml
# env/prod/helm-values.yaml
trino:
  additionalCatalogs:
    # PostgreSQL 카탈로그 추가
    postgresql: |
      connector.name=postgresql
      connection-url=jdbc:postgresql://postgres:5432/mydb
      connection-user=user
      connection-password=password
```

### 인증 활성화

```yaml
# env/prod/helm-values.yaml
trino:
  auth:
    enabled: true
    type: oauth2
  tls:
    enabled: true
```

자세한 커스터마이징 방법은 **[시작 가이드](docs/GETTING_STARTED_KR.md#7-커스터마이징-가이드)**를 참조하세요.

---

## 모니터링

### Grafana 대시보드

```bash
# Grafana 접속
kubectl port-forward -n lakehouse-platform svc/grafana 3000:3000
# http://localhost:3000 접속
# ID: admin, PW: admin (개발 환경)
```

**기본 제공 대시보드**:
- Lakehouse Overview (전체 시스템 개요)
- MinIO Metrics (스토리지 메트릭)
- Trino Metrics (쿼리 성능)
- Airflow Metrics (워크플로우 상태)

### 주요 메트릭

- **시스템**: Pod 상태, 리소스 사용량, 네트워크 트래픽
- **MinIO**: 버킷 사용량, API 요청 수, 에러율
- **Trino**: 실행 중인 쿼리, 쿼리 성공률, 평균 실행 시간
- **Airflow**: DAG 실행 상태, Task 성공률, 스케줄러 지연

---

## 문제 해결

### Pod가 시작되지 않음

```bash
# Pod 상태 확인
kubectl get pods -n lakehouse-platform

# 상세 정보 확인
kubectl describe pod <pod-name> -n lakehouse-platform

# 로그 확인
kubectl logs <pod-name> -n lakehouse-platform
```

### Trino 쿼리 실패

```bash
# Trino 로그 확인
kubectl logs -n lakehouse-platform deployment/trino-coordinator

# Trino UI 접속
kubectl port-forward -n lakehouse-platform svc/trino 8080:8080
# http://localhost:8080 접속
```

### MinIO 접속 불가

```bash
# MinIO Pod 상태
kubectl get pods -n lakehouse-platform -l app=minio

# 포트 포워딩
kubectl port-forward -n lakehouse-platform svc/minio 9000:9000
```

더 많은 문제 해결 방법은 **[운영 가이드](docs/runbook.md#troubleshooting)**를 참조하세요.

---

## 운영

### 업그레이드

```bash
# Git에서 최신 변경사항 가져오기
git pull origin main

# Dry-run으로 변경사항 확인
helm upgrade trino ./platform/trino \
  --namespace lakehouse-platform \
  --values env/prod/helm-values.yaml \
  --dry-run --debug

# 실제 업그레이드
helm upgrade trino ./platform/trino \
  --namespace lakehouse-platform \
  --values env/prod/helm-values.yaml \
  --wait --timeout 10m
```

### 롤백

```bash
# Helm 히스토리 확인
helm history trino -n lakehouse-platform

# 이전 버전으로 롤백
helm rollback trino -n lakehouse-platform
```

### 백업

```bash
# Kubernetes 리소스 백업
kubectl get all -n lakehouse-platform -o yaml > backup.yaml

# MinIO 데이터 백업
mc mirror minio/lakehouse-warehouse /backup/lakehouse-warehouse
```

자세한 운영 절차는 **[운영 가이드](docs/runbook.md)**를 참조하세요.

---

## FAQ

### Q: 로컬에서 빠르게 테스트하려면?

```bash
./scripts/bootstrap.sh dev
```

### Q: 프로덕션 환경으로 배포하려면?

```bash
./scripts/bootstrap.sh prod
```

### Q: MinIO를 AWS S3로 교체하려면?

`env/prod/helm-values.yaml`에서 Iceberg Catalog 설정만 변경하면 됩니다:

```yaml
icebergCatalog:
  config:
    warehouse: s3://my-aws-bucket/lakehouse/
    s3:
      endpoint: https://s3.amazonaws.com
      region: us-east-1
```

### Q: 전체 플랫폼을 제거하려면?

```bash
./scripts/cleanup.sh dev
```

더 많은 FAQ는 **[시작 가이드](docs/GETTING_STARTED_KR.md#10-faq)**를 참조하세요.

---

## 기여하기

이 프로젝트에 기여하고 싶으시다면:

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

### 개발 가이드라인

- 모든 코드는 계약(contracts)을 준수해야 합니다
- 새로운 기능은 테스트 코드와 함께 제출해야 합니다
- 문서를 업데이트해야 합니다

---

## 라이선스

이 프로젝트는 Apache 2.0 라이선스를 따릅니다. 자세한 내용은 [LICENSE](LICENSE) 파일을 참조하세요.

---

## 감사의 말

이 프로젝트는 다음 오픈소스 프로젝트들을 기반으로 합니다:

- [Apache Iceberg](https://iceberg.apache.org/) - 테이블 포맷
- [Trino](https://trino.io/) - 분산 SQL 쿼리 엔진
- [MinIO](https://min.io/) - S3 호환 객체 스토리지
- [Apache Airflow](https://airflow.apache.org/) - 워크플로우 오케스트레이션
- [Prometheus](https://prometheus.io/) - 모니터링
- [Grafana](https://grafana.com/) - 시각화
- [ArgoCD](https://argoproj.github.io/cd/) - GitOps

---

## 연락처

- **이슈**: [GitHub Issues](https://github.com/your-org/lakehouse/issues)
- **토론**: [GitHub Discussions](https://github.com/your-org/lakehouse/discussions)
- **이메일**: lakehouse@example.com

---

## 추가 리소스

### 공식 문서

- [Apache Iceberg 문서](https://iceberg.apache.org/docs/latest/)
- [Trino 문서](https://trino.io/docs/current/)
- [MinIO 문서](https://min.io/docs/minio/kubernetes/upstream/)
- [Airflow 문서](https://airflow.apache.org/docs/)

### 커뮤니티

- [Iceberg Slack](https://apache-iceberg.slack.com/)
- [Trino Slack](https://trino.io/slack.html)
- [Airflow Slack](https://apache-airflow.slack.com/)

---

**Happy Data Engineering! 🚀**

---

<div align="center">

Made with ❤️ by the Lakehouse Team

[⬆ 맨 위로](#lakehouse-플랫폼)

</div>
