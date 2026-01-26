# Lakehouse 플랫폼 아키텍처

> 시스템 설계 및 데이터 흐름 설명

**최종 업데이트**: 2026-01-26

---

## 📋 목차

1. [전체 아키텍처](#1-전체-아키텍처)
2. [핵심 컴포넌트](#2-핵심-컴포넌트)
3. [데이터 흐름](#3-데이터-흐름)
4. [디렉토리 구조](#4-디렉토리-구조)
5. [네트워킹](#5-네트워킹)
6. [보안](#6-보안)

---

## 1. 전체 아키텍처

### 1.1 고수준 다이어그램

```
┌──────────────────────────────────────────────────────────┐
│                사용자 / 애플리케이션                        │
│     (Analysts, Engineers, BI Tools, Notebooks)           │
└─────────────────────┬────────────────────────────────────┘
                      │
      ┌───────────────┴───────────────┐
      │                               │
 ┌────▼─────┐                   ┌────▼────┐
 │  Trino   │                   │ Airflow │
 │ (Query)  │◄──────────────────┤  (DAG)  │
 └──┬───┬───┘    SQL Queries    └─────────┘
    │   │
    │   │  ① 메타데이터 조회
    │   │  (테이블 스키마, 파일 위치)
    │   │
    │   │  ┌─────────────────────┐
    │   └──┤ Iceberg REST Catalog│
    │      │  (Metadata Manager) │
    │      └──────────┬──────────┘
    │                 │
    │                 │ ③ 메타데이터 파일 저장
    │                 │    (.avro, .json)
    │                 │
    │      ┌──────────▼──────────┐
    └──────┤      MinIO          │  ② 데이터 파일 읽기/쓰기
           │  (S3 Storage)       │     (.parquet, .orc)
           └─────────────────────┘

데이터 흐름:
───────────
① Trino → Iceberg Catalog: 
   "sales.orders 테이블의 메타데이터 주세요"
   → Iceberg가 스키마, 파티션, 파일 목록 반환

② Trino → MinIO:
   "data/sales/orders/00001.parquet 파일을 읽어주세요"
   → 실제 데이터 파일 직접 읽기/쓰기

③ Iceberg Catalog → MinIO:
   메타데이터 파일 (스냅샷, manifest) 저장

④ Airflow → Trino:
   SQL 쿼리 전송 (INSERT, CREATE TABLE 등)
   → Trino를 통해서만 Iceberg에 접근
```

### 1.2 계층 구조

| 계층 | 역할 | 컴포넌트 |
|------|------|---------|
| **접근 계층** | 사용자 인터페이스 | SQL, API, UI |
| **처리 계층** | 데이터 처리 및 쿼리 | Trino, Airflow |
| **메타데이터 계층** | 스키마 및 카탈로그 관리 | Iceberg Catalog |
| **저장 계층** | 데이터 파일 저장 | MinIO (S3) |
| **관찰성 계층** | 모니터링 및 알림 | Prometheus, Grafana |
| **배포 계층** | GitOps 자동화 | ArgoCD |

---

## 2. 핵심 컴포넌트

### 2.1 MinIO (객체 스토리지)

**역할**: S3 호환 객체 스토리지
**기술**: MinIO v2023+
**포트**: 9000 (API), 9001 (Console)

```yaml
# 환경별 구성
dev:       단일 노드, 10GB
staging:   단일 노드, 50GB, gp3 스토리지
prod:      분산 모드 (4 replicas), 100GB, fast-ssd, HA
```

**데이터 구조**:
```
s3://lakehouse-{env}-raw/          # 원본 데이터
s3://lakehouse-{env}-warehouse/    # Iceberg 테이블
s3://lakehouse-{env}-temp/         # 임시 데이터
s3://lakehouse-{env}-logs/         # 애플리케이션 로그 (prod만)
```

### 2.2 Iceberg Catalog (메타데이터)

**역할**: Apache Iceberg 테이블 메타데이터 관리
**기술**: Tabular Iceberg REST Catalog
**포트**: 8181

**저장 백엔드**:
- **dev**: SQLite (파일 기반)
- **staging/prod**: PostgreSQL (HA)

**주요 기능**:
- 테이블 스키마 관리
- 스냅샷 버전 관리
- Time Travel 지원
- 파티션 진화 (Partition Evolution)

### 2.3 Trino (쿼리 엔진)

**역할**: 분산 SQL 쿼리 엔진
**기술**: Trino v440+
**포트**: 8080

``` yaml
# 환경별 구성
dev:       2 workers, 1GB JVM heap
staging:   3-6 workers (autoscaling), 4GB JVM heap
prod:      5-20 workers (autoscaling), 8GB JVM heap, OAuth2
```

**Iceberg 연동**:
```properties
connector.name=iceberg
iceberg.catalog.type=rest
iceberg.rest.uri=http://iceberg-catalog:8181
iceberg.rest.warehouse=s3://lakehouse-{env}-warehouse/
```

### 2.4 Airflow (워크플로우)

**역할**: 데이터 파이프라인 스케줄링
**기술**: Apache Airflow v3.0+ (KubernetesExecutor)
**포트**: 8080 (Webserver)

**주요 기능**:
- DAG 실행 (KubernetesPodOperator)
- GitSync를 통한 DAG 자동 배포
- PostgreSQL 메타데이터 DB
- 원격 로깅 (S3)

### 2.5 Observability (모니터링)

**역할**: 메트릭 수집 및 시각화
**기술**: Prometheus + Grafana
**포트**: 9090 (Prometheus), 3000 (Grafana)

**대시보드**:
- Lakehouse Overview
- MinIO Metrics
- Trino Query Performance
- Airflow DAG Status
- Kubernetes Resources

### 2.6 ArgoCD (GitOps)

**역할**: Git 기반 자동 배포
**기술**: ArgoCD v2.9+
**포트**: 8080

**관리 대상**:
- 모든 platform 컴포넌트
- 환경별 설정 (env/)
- 자동 sync 및 drift 감지

---

## 3. 데이터 흐름

### 3.1 데이터 쓰기 (Write Flow)

```
1. SQL INSERT/UPDATE
   ↓
2. Trino Query Coordinator
   ↓
3. Iceberg Catalog (메타데이터 업데이트)
   ↓
4. Trino Workers (데이터 파일 생성)
   ↓
5. MinIO (Parquet 파일 저장)
   ↓
6. Iceberg Catalog (스냅샷 커밋)
```

**예시**:
```sql
INSERT INTO sales.orders VALUES (1, 100, DATE '2024-01-01', 1500.00);
```

**생성되는 파일**:
- `s3://lakehouse-{env}-warehouse/sales/orders/data/*.parquet`
- `s3://lakehouse-{env}-warehouse/sales/orders/metadata/*.avro`

### 3.2 데이터 읽기 (Read Flow)

```
1. SQL SELECT
   ↓
2. Trino Query Coordinator
   ↓
3. Iceberg Catalog (메타데이터 조회)
   ↓
4. Iceberg Table (파일 목록 가져오기)
   ↓
5. Trino Workers (MinIO에서 Parquet 파일 읽기)
   ↓
6. 결과 반환
```

### 3.3 Time Travel

```sql
-- 버전 1 시점의 데이터 조회
SELECT * FROM sales.orders FOR VERSION AS OF 1;

-- 2024-01-01 시점의 데이터 조회
SELECT * FROM sales.orders 
FOR TIMESTAMP AS OF TIMESTAMP '2024-01-01 00:00:00';
```

### 3.4 워크플로우 실행

```
1. Airflow Scheduler (cron 확인)
   ↓
2. DAG 트리거
   ↓
3. KubernetesPodOperator (Pod 생성)
   ↓
4. Job Container 실행
   ├─→ Trino로 데이터 조회
   ├─→ 데이터 처리
   └─→ Trino로 결과 저장
   ↓
5. Pod 종료 및 로그 수집
```

---

## 4. 디렉토리 구조

### 4.1 레포지토리 구조

```
lakehouse/
├── contracts/          # API 계약 (인터페이스 규격)
│   └── *.md                - 각 컴포넌트 API 스펙
│
├── docs/               # 사용자 문서
│   ├── README.md           - 문서 구조
│   ├── GETTING_STARTED_KR.md  - 시작 가이드
│   └── ARCHITECTURE_KR.md     - 이 문서
│
├── env/                # 환경별 설정
│   ├── dev/                - 개발 환경
│   │   ├── terraform.tfvars
│   │   ├── minio-values.yaml
│   │   ├── trino-values.yaml
│   │   └── airflow-values.yaml
│   ├── staging/            - 스테이징 환경
│   └── prod/               - 프로덕션 환경
│
├── infra/              # 인프라 코드 (Terraform)
│   ├── main.tf             - 메인 설정
│   ├── variables.tf        - 변수 정의
│   └── modules/            - Terraform 모듈
│       ├── cluster/        - K8s 클러스터
│       ├── network/        - 네트워킹
│       └── storage/        - 스토리지
│
├── platform/           # 플랫폼 컴포넌트 (Helm 차트)
│   ├── minio/              - MinIO 차트
│   ├── iceberg-catalog/    - Iceberg Catalog 차트
│   ├── trino/              - Trino 차트
│   ├── airflow/            - Airflow 차트
│   ├── observability/      - Prometheus + Grafana
│   └── argocd/             - ArgoCD 차트
│
├── scripts/            # 자동화 스크립트
│   ├── bootstrap.sh        - 전체 배포
│   ├── cleanup.sh          - 플랫폼 제거
│   └── validate.sh         - 플랫폼 검증
│
└── tests/              # 테스트
    └── e2e/                - E2E 테스트
```

### 4.2 설정 우선순위

```
1. platform/*/values.yaml       (기본값)
   ↓
2. env/{environment}/*-values.yaml  (환경별 오버라이드)
   ↓
3. Runtime 설정 (Secret, ConfigMap)
```

---

## 5. 네트워킹

### 5.1 서비스 간 통신

**모든 통신은 DNS 기반**:

```yaml
# Trino → Iceberg Catalog
iceberg.rest.uri: http://iceberg-catalog.lakehouse-platform.svc.cluster.local:8181

# Trino → MinIO
s3.endpoint: http://minio.lakehouse-platform.svc.cluster.local:9000

# Iceberg → MinIO
s3.endpoint: http://minio.lakehouse-platform.svc.cluster.local:9000
```

**절대 금지**:
- ❌ IP 주소 하드코딩
- ❌ localhost 참조
- ❌ 환경별 하드코딩

### 5.2 외부 접근

**개발 환경** (포트 포워딩):
```bash
kubectl port-forward -n lakehouse-platform svc/trino 8080:8080
kubectl port-forward -n lakehouse-platform svc/minio 9000:9000
kubectl port-forward -n lakehouse-platform svc/observability-grafana 3000:80
```

**프로덕션** (Ingress):
```yaml
ingress:
  enabled: true
  hosts:
    - trino.lakehouse.example.com
    - minio.lakehouse.example.com
    - grafana.lakehouse.example.com
```

---

## 6. 보안

### 6.1 인증 방식

| 컴포넌트 | 개발 | 프로덕션 |
|---------|------|----------|
| **Trino** | None | OAuth2 |
| **MinIO** | Access Key | Access Key + TLS |
| **Airflow** | Basic Auth | OAuth2 + RBAC |
| **Grafana** | admin/admin | LDAP/OAuth2 |
| **ArgoCD** | admin/auto-generated | SSO |

### 6.2 시크릿 관리

**Sealed Secrets 사용**:
```yaml
# Git에 저장 (암호화됨)
apiVersion: bitnami.com/v1alpha1
kind: SealedSecret
metadata:
  name: minio-creds
spec:
  encryptedData:
    accessKeyId: AgB7Y... (encrypted)
    secretAccessKey: AgC9... (encrypted)
```

상세: [SECRET_MANAGEMENT_KR.md](SECRET_MANAGEMENT_KR.md)

### 6.3 네트워크 정책

```yaml
# 예: Trino만 Iceberg에 접근 가능
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: iceberg-catalog-policy
spec:
  podSelector:
    matchLabels:
      app: iceberg-catalog
  ingress:
    - from:
      - podSelector:
          matchLabels:
            app: trino
```

---

## 핵심 설계 원칙

### 1. 모듈 교체 가능성
- 각 컴포넌트는 명확한 계약(Contract)으로 정의
- MinIO → AWS S3 교체 시 Trino 코드 변경 불필요
- Trino → Spark 교체 시 Iceberg 테이블 그대로 사용

### 2. 환경 독립성
- 동일한 코드 (platform/)
- 다른 설정 (env/)
- 환경별 리소스만 다름

### 3. GitOps 기반
- Git = 단일 진실 공급원
- 수동 kubectl 명령 최소화
- ArgoCD가 자동으로 동기화

### 4. 관찰성 필수
- 모든 컴포넌트: `/health`, `/ready`, `/metrics`
- 구조화된 로깅 (JSON)
- 분산 추적 (향후)

---

## 참고 문서

- **[계약서](../contracts/README.md)** - 각 컴포넌트 API 스펙
- **[시작 가이드](GETTING_STARTED_KR.md)** - 설치 및 사용법
- **[운영 가이드](runbook.md)** - 배포 및 문제 해결

---

**Last Updated**: 2026-01-26  
**Version**: 1.0

[⬆ 맨 위로](#lakehouse-플랫폼-아키텍처)
