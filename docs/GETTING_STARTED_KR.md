# Lakehouse 플랫폼 완벽 가이드

**버전**: 1.0  
**최종 업데이트**: 2025-12-28  
**대상 독자**: Lakehouse 플랫폼을 처음 접하는 개발자 및 운영자

---

## 📚 목차

1. [프로젝트 개요](#1-프로젝트-개요)
2. [빠른 시작 (5분 안에 실행하기)](#2-빠른-시작-5분-안에-실행하기)
3. [아키텍처 이해하기](#3-아키텍처-이해하기)
4. [디렉토리 구조 완벽 가이드](#4-디렉토리-구조-완벽-가이드)
5. [환경별 설정 방법](#5-환경별-설정-방법)
6. [각 컴포넌트 상세 설명](#6-각-컴포넌트-상세-설명)
7. [커스터마이징 가이드](#7-커스터마이징-가이드)
8. [문제 해결 가이드](#8-문제-해결-가이드)
9. [운영 가이드](#9-운영-가이드)
10. [FAQ](#10-faq)

---

## 1. 프로젝트 개요

### 1.1 Lakehouse란?

Lakehouse는 **데이터 레이크**와 **데이터 웨어하우스**의 장점을 결합한 현대적인 데이터 플랫폼입니다.

**핵심 특징**:
- 📦 **객체 스토리지 기반**: 저렴한 비용으로 대용량 데이터 저장
- 🔍 **SQL 쿼리 지원**: 데이터 웨어하우스처럼 SQL로 데이터 분석
- 🔄 **ACID 트랜잭션**: Apache Iceberg를 통한 데이터 무결성 보장
- 🚀 **확장성**: Kubernetes 기반으로 무한 확장 가능
- 🔧 **벤더 중립적**: 특정 클라우드에 종속되지 않음

### 1.2 이 프로젝트가 제공하는 것

```
┌─────────────────────────────────────────────────────────┐
│                  Lakehouse Platform                      │
├─────────────────────────────────────────────────────────┤
│                                                          │
│  데이터 저장     │  MinIO (S3 호환 객체 스토리지)        │
│  메타데이터 관리  │  Iceberg Catalog (테이블 메타데이터)  │
│  쿼리 엔진       │  Trino (SQL 쿼리 실행)                │
│  워크플로우      │  Airflow (데이터 파이프라인 스케줄링)  │
│  모니터링       │  Prometheus + Grafana                 │
│  배포 자동화     │  ArgoCD (GitOps)                     │
│                                                          │
└─────────────────────────────────────────────────────────┘
```

### 1.3 왜 이 프로젝트를 사용해야 하나?

✅ **완전 자동화**: 한 번의 명령으로 전체 플랫폼 배포  
✅ **프로덕션 준비 완료**: 모든 컴포넌트가 HA(고가용성) 지원  
✅ **쉬운 커스터마이징**: 환경별 설정 파일로 간단하게 수정  
✅ **완벽한 문서화**: 모든 절차가 상세히 문서화됨  
✅ **테스트 완료**: E2E 테스트로 검증된 안정성  

---

## 2. 빠른 시작 (5분 안에 실행하기)

### 2.1 사전 요구사항

다음 도구들이 설치되어 있어야 합니다:

```bash
# macOS
brew install kubectl helm terraform kind

# Linux (Ubuntu/Debian)
# kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

# helm
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# terraform
wget https://releases.hashicorp.com/terraform/1.6.0/terraform_1.6.0_linux_amd64.zip
unzip terraform_1.6.0_linux_amd64.zip
sudo mv terraform /usr/local/bin/

# kind
curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.20.0/kind-linux-amd64
chmod +x ./kind
sudo mv ./kind /usr/local/bin/kind
```

**버전 확인**:
```bash
kubectl version --client
helm version
terraform version
kind version
```

### 2.2 프로젝트 클론

```bash
# Git 저장소 클론
git clone https://github.com/your-org/lakehouse.git
cd lakehouse

# 디렉토리 구조 확인
ls -la
```

### 2.3 개발 환경 배포 (로컬)

```bash
# 한 번의 명령으로 전체 플랫폼 배포
./scripts/bootstrap.sh dev

# 예상 소요 시간: 5-10분
# 완료되면 다음과 같은 메시지가 표시됩니다:
# ✓ Infrastructure provisioned
# ✓ ArgoCD installed
# ✓ Applications synced
# ✓ Platform ready
```

### 2.4 플랫폼 접속

```bash
# 1. Trino (SQL Query Engine)
# 접속: http://localhost:8080
kubectl port-forward -n lakehouse-platform svc/trino 8080:8080 &

# 2. Airflow (Workflow Orchestration)
# 접속: http://localhost:8081 (admin / admin)
kubectl port-forward -n lakehouse-platform svc/airflow-webserver 8081:8080 &

# 3. ArgoCD (GitOps Dashboard)
# 접속: http://localhost:8082 (admin / 패스워드 확인 필요)
# 패스워드 확인: kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d; echo
kubectl port-forward -n argocd svc/argocd-server 8082:80 &

# 4. MinIO (Object Storage)
# 접속: http://127.0.0.1:9001 (admin / changeme123)
# 주의: macOS에서는 localhost 대신 127.0.0.1을 명시해야 접속이 원활할 수 있습니다.
kubectl port-forward -n lakehouse-platform svc/minio 9000:9000 9001:9001 --address 127.0.0.1 &

# 5. Grafana (Dashboard)
# 접속: http://localhost:3000 (admin / admin)
kubectl port-forward -n lakehouse-platform svc/observability-grafana 3000:80 &
```

### 2.5 첫 번째 쿼리 실행

```bash
# Trino CLI 설치
brew install trino  # macOS
# 또는
wget https://repo1.maven.org/maven2/io/trino/trino-cli/428/trino-cli-428-executable.jar
mv trino-cli-428-executable.jar trino
chmod +x trino

# Trino 접속
./trino --server localhost:8080 --catalog iceberg --schema default

# SQL 쿼리 실행
trino> SHOW SCHEMAS;
trino> CREATE SCHEMA test;
trino> CREATE TABLE test.users (id INT, name VARCHAR);
trino> INSERT INTO test.users VALUES (1, 'Alice'), (2, 'Bob');
trino> SELECT * FROM test.users;
```

**축하합니다! 🎉 Lakehouse 플랫폼이 정상적으로 실행되고 있습니다.**

---

## 3. 아키텍처 이해하기

### 3.1 전체 아키텍처

```
┌─────────────────────────────────────────────────────────────┐
│                     사용자/애플리케이션                        │
└────────────────────┬────────────────────────────────────────┘
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

### 3.2 데이터 흐름

**1. 데이터 저장**:
```
데이터 → Trino → Iceberg Catalog → MinIO
                  (메타데이터 등록)   (실제 파일 저장)
```

**2. 데이터 조회**:
```
SQL 쿼리 → Trino → Iceberg Catalog → MinIO
                   (메타데이터 조회)  (파일 읽기)
```

**3. 워크플로우 실행**:
```
스케줄 → Airflow → Kubernetes Job → Trino/MinIO
                   (컨테이너 실행)    (데이터 처리)
```

### 3.3 각 컴포넌트의 역할

| 컴포넌트 | 역할 | 비유 |
|---------|------|------|
| **MinIO** | 실제 데이터 파일 저장 | 도서관의 서고 |
| **Iceberg Catalog** | 테이블 메타데이터 관리 | 도서관의 카탈로그 |
| **Trino** | SQL 쿼리 실행 | 도서관 사서 |
| **Airflow** | 데이터 파이프라인 스케줄링 | 자동화 시스템 |
| **Prometheus** | 메트릭 수집 | 모니터링 카메라 |
| **Grafana** | 메트릭 시각화 | 모니터링 화면 |
| **ArgoCD** | GitOps 배포 자동화 | 자동 배포 로봇 |

---

## 4. 디렉토리 구조 완벽 가이드

### 4.1 전체 구조

```
lakehouse/
├── contracts/              # 📋 각 컴포넌트의 인터페이스 정의
├── docs/                   # 📚 문서
├── env/                    # ⚙️  환경별 설정 파일
├── infra/                  # 🏗️  인프라 코드 (Terraform)
├── platform/               # 🎯 플랫폼 컴포넌트 (Helm 차트)
├── scripts/                # 🔧 자동화 스크립트
├── services/               # 🚀 샘플 서비스
├── tests/                  # ✅ 테스트 코드
└── workflows/              # 🔄 샘플 워크플로우
```

### 4.2 각 디렉토리 상세 설명

#### 📋 `contracts/` - 컴포넌트 인터페이스 정의

**목적**: 각 컴포넌트가 지켜야 할 규칙을 정의

```
contracts/
├── kubernetes-cluster.md      # Kubernetes 클러스터 요구사항
├── object-storage.md          # S3 호환 스토리지 인터페이스
├── iceberg-catalog.md         # Iceberg 카탈로그 REST API
├── query-engine.md            # SQL 쿼리 엔진 요구사항
├── service-module.md          # 서비스 모듈 표준
└── workflow-orchestration.md  # 워크플로우 오케스트레이션 표준
```

**언제 수정하나요?**
- 새로운 컴포넌트를 추가할 때
- 기존 컴포넌트의 인터페이스를 변경할 때

**예시**: MinIO를 다른 S3 호환 스토리지로 교체하려면 `object-storage.md`의 요구사항만 만족하면 됩니다.

#### ⚙️ `env/` - 환경별 설정 파일

**목적**: 개발/스테이징/프로덕션 환경별로 다른 설정 사용

```
env/
├── dev/
│   ├── terraform.tfvars    # 개발 환경 인프라 설정
│   └── helm-values.yaml    # 개발 환경 Helm 값
├── staging/
│   ├── terraform.tfvars    # 스테이징 환경 인프라 설정
│   └── helm-values.yaml    # 스테이징 환경 Helm 값
└── prod/
    ├── terraform.tfvars    # 프로덕션 환경 인프라 설정
    └── helm-values.yaml    # 프로덕션 환경 Helm 값
```

**주요 차이점**:

| 설정 | 개발(dev) | 스테이징(staging) | 프로덕션(prod) |
|------|----------|------------------|---------------|
| 노드 수 | 1 | 3 | 5+ |
| 메모리 | 512Mi | 1-2Gi | 4-16Gi |
| 복제본 | 1 | 2 | 3 |
| 인증 | 비활성화 | 활성화 | 필수 |
| TLS | 비활성화 | 활성화 | 필수 |

#### 🏗️ `infra/` - 인프라 코드

**목적**: Terraform으로 Kubernetes 클러스터 생성

```
infra/
├── main.tf              # 메인 Terraform 설정
├── variables.tf         # 변수 정의
├── outputs.tf           # 출력 값
└── modules/
    └── cluster/         # Kubernetes 클러스터 모듈
        ├── main.tf
        ├── variables.tf
        └── outputs.tf
```

**수정 방법**:
```bash
# 1. 변수 수정
vim env/dev/terraform.tfvars

# 2. 변경사항 확인
cd infra
terraform plan -var-file=../env/dev/terraform.tfvars

# 3. 적용
terraform apply -var-file=../env/dev/terraform.tfvars
```

#### 🎯 `platform/` - 플랫폼 컴포넌트

**목적**: 각 컴포넌트의 Helm 차트

```
platform/
├── minio/              # MinIO (객체 스토리지)
├── iceberg-catalog/    # Iceberg Catalog
├── trino/              # Trino (쿼리 엔진)
├── airflow/            # Airflow (워크플로우)
├── observability/      # Prometheus + Grafana
└── argocd/             # ArgoCD (GitOps)
```

**각 컴포넌트 구조**:
```
platform/minio/
├── Chart.yaml          # Helm 차트 메타데이터
├── values.yaml         # 기본 설정 값
├── values-dev.yaml     # 개발 환경 값
├── values-staging.yaml # 스테이징 환경 값
├── values-prod.yaml    # 프로덕션 환경 값
├── templates/          # Kubernetes 매니페스트 템플릿
│   ├── deployment.yaml
│   ├── service.yaml
│   └── ...
└── README.md           # 컴포넌트 문서
```

#### 🔧 `scripts/` - 자동화 스크립트

```
scripts/
├── bootstrap.sh        # 전체 플랫폼 배포
├── cleanup.sh          # 플랫폼 제거
└── validate.sh         # 플랫폼 검증
```

**사용법**:
```bash
# 배포
./scripts/bootstrap.sh dev

# 검증
./scripts/validate.sh

# 제거
./scripts/cleanup.sh dev
```

---

## 5. 환경별 설정 방법

### 5.1 개발 환경 (dev)

**특징**: 로컬 개발, 최소 리소스, 빠른 반복

**설정 파일**: `env/dev/helm-values.yaml`

```yaml
# MinIO 설정
minio:
  replicas: 1                    # 단일 복제본
  resources:
    requests:
      memory: 512Mi               # 최소 메모리
      cpu: 250m
  rootUser: minioadmin            # 간단한 인증
  rootPassword: minioadmin

# Trino 설정
trino:
  server:
    workers: 2                    # 워커 2개
  coordinator:
    resources:
      requests:
        memory: 1Gi
```

**수정 방법**:
```bash
# 1. 설정 파일 수정
vim env/dev/helm-values.yaml

# 2. 변경사항 적용
helm upgrade minio ./platform/minio \
  --namespace lakehouse-platform \
  --values env/dev/helm-values.yaml

# 3. 확인
kubectl get pods -n lakehouse-platform
```

### 5.2 스테이징 환경 (staging)

**특징**: 프로덕션 유사 환경, 중간 리소스, HA 설정

**주요 변경사항**:
```yaml
minio:
  replicas: 4                     # HA를 위한 4개 복제본
  persistence:
    size: 50Gi                    # 더 큰 스토리지
  ingress:
    enabled: true                 # 외부 접속 활성화
    hosts:
      - minio-staging.example.com

trino:
  server:
    workers: 3
    autoscaling:
      enabled: true               # 자동 스케일링
      minReplicas: 3
      maxReplicas: 10
```

### 5.3 프로덕션 환경 (prod)

**특징**: 최대 리소스, 엄격한 보안, 완전한 HA

**주요 변경사항**:
```yaml
minio:
  replicas: 8                     # 최대 HA
  resources:
    requests:
      memory: 4Gi                 # 대용량 메모리
      cpu: 2000m
  affinity:
    podAntiAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:  # 엄격한 분산 배치
        - labelSelector:
            matchLabels:
              app: minio
          topologyKey: kubernetes.io/hostname

trino:
  auth:
    enabled: true                 # 인증 필수
    type: oauth2
  tls:
    enabled: true                 # TLS 필수
```

---

## 6. 각 컴포넌트 상세 설명

### 6.1 MinIO (객체 스토리지)

**역할**: 실제 데이터 파일을 저장하는 S3 호환 스토리지

**주요 설정**:

```yaml
# env/dev/helm-values.yaml
minio:
  mode: standalone              # 또는 distributed
  replicas: 1                   # 복제본 수
  
  persistence:
    enabled: true
    size: 10Gi                  # 스토리지 크기
    storageClass: standard      # 스토리지 클래스
  
  buckets:
    - name: lakehouse-dev-warehouse
      policy: none
```

**커스터마이징 예시**:

**1. 스토리지 크기 변경**:
```yaml
minio:
  persistence:
    size: 100Gi  # 10Gi → 100Gi로 증가
```

**2. 분산 모드로 변경**:
```yaml
minio:
  mode: distributed
  replicas: 4  # 최소 4개 필요
```

**3. 새 버킷 추가**:
```yaml
minio:
  buckets:
    - name: lakehouse-dev-warehouse
    - name: lakehouse-dev-logs        # 새 버킷
    - name: lakehouse-dev-backups     # 백업용 버킷
```

**적용**:
```bash
helm upgrade minio ./platform/minio \
  --namespace lakehouse-platform \
  --values env/dev/helm-values.yaml
```

### 6.2 Iceberg Catalog (메타데이터 관리)

**역할**: 테이블 메타데이터(스키마, 파티션 등) 관리

**주요 설정**:

```yaml
icebergCatalog:
  replicaCount: 1
  
  config:
    warehouse: s3://lakehouse-dev-warehouse/
    s3:
      endpoint: http://minio.lakehouse-platform.svc.cluster.local:9000
      accessKeyId: minioadmin
      secretAccessKey: minioadmin
```

**커스터마이징 예시**:

**1. 외부 S3 사용**:
```yaml
icebergCatalog:
  config:
    warehouse: s3://my-aws-bucket/lakehouse/
    s3:
      endpoint: https://s3.amazonaws.com
      region: us-east-1
      # 실제 환경에서는 Secret 사용
      accessKeyIdSecret: aws-credentials
      secretAccessKeySecret: aws-credentials
```

**2. HA 설정**:
```yaml
icebergCatalog:
  replicaCount: 3  # 3개 복제본
  affinity:
    podAntiAffinity:
      preferredDuringSchedulingIgnoredDuringExecution:
        - weight: 100
          podAffinityTerm:
            labelSelector:
              matchLabels:
                app: iceberg-catalog
            topologyKey: kubernetes.io/hostname
```

### 6.3 Trino (쿼리 엔진)

**역할**: SQL 쿼리를 실행하여 데이터 조회/분석

**주요 설정**:

```yaml
trino:
  server:
    workers: 2                    # 워커 노드 수
    autoscaling:
      enabled: false              # 자동 스케일링
  
  coordinator:
    resources:
      requests:
        memory: 1Gi
        cpu: 500m
  
  worker:
    resources:
      requests:
        memory: 1Gi
        cpu: 500m
```

**커스터마이징 예시**:

**1. 워커 수 증가**:
```yaml
trino:
  server:
    workers: 10  # 2 → 10으로 증가 (더 많은 병렬 처리)
```

**2. 자동 스케일링 활성화**:
```yaml
trino:
  server:
    workers: 5
    autoscaling:
      enabled: true
      minReplicas: 5
      maxReplicas: 20
      targetCPUUtilizationPercentage: 70
```

**3. 메모리 증가**:
```yaml
trino:
  coordinator:
    resources:
      requests:
        memory: 8Gi    # 1Gi → 8Gi
        cpu: 4000m     # 500m → 4000m
  worker:
    resources:
      requests:
        memory: 16Gi   # 대용량 쿼리 처리
        cpu: 8000m
```

**4. 새 카탈로그 추가**:
```yaml
trino:
  additionalCatalogs:
    iceberg: |
      connector.name=iceberg
      iceberg.catalog.type=rest
      iceberg.rest-catalog.uri=http://iceberg-catalog:8181
    
    # PostgreSQL 카탈로그 추가
    postgresql: |
      connector.name=postgresql
      connection-url=jdbc:postgresql://postgres:5432/mydb
      connection-user=user
      connection-password=password
```

### 6.4 Airflow (워크플로우 오케스트레이션)

**역할**: 데이터 파이프라인 스케줄링 및 실행

**주요 설정**:

```yaml
airflow:
  executor: KubernetesExecutor   # Kubernetes에서 작업 실행
  
  webserver:
    replicas: 1
  
  scheduler:
    replicas: 1
  
  dags:
    gitSync:
      enabled: false              # Git에서 DAG 동기화
      repo: https://github.com/your-org/dags.git
      branch: main
```

**커스터마이징 예시**:

**1. GitSync 활성화** (DAG를 Git에서 자동 동기화):
```yaml
airflow:
  dags:
    gitSync:
      enabled: true
      repo: https://github.com/your-org/lakehouse-dags.git
      branch: main
      subPath: dags
      wait: 60  # 60초마다 동기화
```

**2. HA 설정**:
```yaml
airflow:
  webserver:
    replicas: 3  # 웹서버 3개
  scheduler:
    replicas: 2  # 스케줄러 2개 (HA)
```

**3. 원격 로깅 설정** (S3에 로그 저장):
```yaml
airflow:
  config:
    logging:
      remote_logging: true
      remote_base_log_folder: s3://lakehouse-logs/airflow
      remote_log_conn_id: aws_default
```

### 6.5 Observability (모니터링)

**역할**: 시스템 메트릭 수집 및 시각화

**주요 설정**:

```yaml
observability:
  prometheus:
    retention: 3d                 # 메트릭 보관 기간
    storageSize: 10Gi             # 스토리지 크기
    replicas: 1
  
  grafana:
    replicas: 1
    adminPassword: admin
```

**커스터마이징 예시**:

**1. 보관 기간 연장**:
```yaml
observability:
  prometheus:
    retention: 30d    # 3일 → 30일
    storageSize: 100Gi  # 스토리지도 증가
```

**2. 알림 설정**:
```yaml
observability:
  alertmanager:
    enabled: true
    config:
      receivers:
        - name: 'team-email'
          email_configs:
            - to: 'team@example.com'
              from: 'alertmanager@example.com'
              smarthost: 'smtp.gmail.com:587'
```

**3. 커스텀 대시보드 추가**:
```yaml
observability:
  grafana:
    dashboardProviders:
      dashboardproviders.yaml:
        apiVersion: 1
        providers:
          - name: 'custom'
            folder: 'Custom Dashboards'
            type: file
            options:
              path: /var/lib/grafana/dashboards/custom
```

---

## 7. 커스터마이징 가이드

### 7.1 리소스 크기 조정

**시나리오**: 쿼리가 느리거나 메모리 부족 오류 발생

**해결 방법**:

```yaml
# env/prod/helm-values.yaml
trino:
  coordinator:
    resources:
      requests:
        memory: 16Gi    # 기존 8Gi에서 증가
        cpu: 8000m      # 기존 4000m에서 증가
      limits:
        memory: 32Gi
        cpu: 16000m
  
  worker:
    resources:
      requests:
        memory: 32Gi    # 대용량 쿼리 처리
        cpu: 16000m
```

**적용**:
```bash
helm upgrade trino ./platform/trino \
  --namespace lakehouse-platform \
  --values env/prod/helm-values.yaml
```

### 7.2 새로운 환경 추가

**시나리오**: QA 환경 추가

**1. 환경 디렉토리 생성**:
```bash
mkdir -p env/qa
```

**2. 설정 파일 복사 및 수정**:
```bash
# 스테이징 설정을 기반으로 시작
cp env/staging/terraform.tfvars env/qa/
cp env/staging/helm-values.yaml env/qa/

# 환경 이름 변경
vim env/qa/terraform.tfvars
# environment = "qa"
# cluster_name = "lakehouse-qa"

vim env/qa/helm-values.yaml
# 필요한 리소스 조정
```

**3. 배포**:
```bash
./scripts/bootstrap.sh qa
```

### 7.3 새로운 카탈로그 추가

**시나리오**: PostgreSQL 데이터베이스를 Trino에서 쿼리하고 싶음

**방법**:

```yaml
# env/dev/helm-values.yaml
trino:
  additionalCatalogs:
    # 기존 Iceberg 카탈로그
    iceberg: |
      connector.name=iceberg
      iceberg.catalog.type=rest
      iceberg.rest-catalog.uri=http://iceberg-catalog:8181
    
    # 새로운 PostgreSQL 카탈로그
    postgresql: |
      connector.name=postgresql
      connection-url=jdbc:postgresql://postgres.default.svc.cluster.local:5432/mydb
      connection-user=postgres
      connection-password=password
    
    # MySQL 카탈로그도 추가 가능
    mysql: |
      connector.name=mysql
      connection-url=jdbc:mysql://mysql.default.svc.cluster.local:3306
      connection-user=root
      connection-password=password
```

**사용**:
```sql
-- PostgreSQL 테이블 조회
SELECT * FROM postgresql.public.users;

-- Iceberg와 PostgreSQL 조인
SELECT 
  i.order_id,
  p.user_name
FROM iceberg.sales.orders i
JOIN postgresql.public.users p ON i.user_id = p.id;
```

### 7.4 인증 설정

**시나리오**: 프로덕션 환경에서 인증 활성화

**Trino OAuth2 인증**:

```yaml
# env/prod/helm-values.yaml
trino:
  auth:
    enabled: true
    type: oauth2
  
  additionalConfigFiles:
    oauth2.properties: |
      http-server.authentication.type=oauth2
      http-server.authentication.oauth2.issuer-url=https://your-oauth-provider.com
      http-server.authentication.oauth2.client-id=trino-client
      http-server.authentication.oauth2.client-secret=secret
```

**Airflow RBAC**:

```yaml
# env/prod/helm-values.yaml
airflow:
  config:
    webserver:
      rbac: true
      authenticate: true
      auth_backend: airflow.contrib.auth.backends.google_auth
```

### 7.5 TLS/SSL 설정

**시나리오**: HTTPS로 서비스 노출

**1. cert-manager 설치**:
```bash
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.yaml
```

**2. ClusterIssuer 생성**:
```yaml
# tls/cluster-issuer.yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: admin@example.com
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
    - http01:
        ingress:
          class: nginx
```

**3. Ingress에 TLS 설정**:
```yaml
# env/prod/helm-values.yaml
trino:
  ingress:
    enabled: true
    ingressClassName: nginx
    annotations:
      cert-manager.io/cluster-issuer: letsencrypt-prod
    hosts:
      - trino.example.com
    tls:
      - secretName: trino-tls
        hosts:
          - trino.example.com
```

---

## 8. 문제 해결 가이드

### 8.1 Pod가 시작되지 않음

**증상**: Pod가 `Pending`, `CrashLoopBackOff`, `ImagePullBackOff` 상태

**진단**:
```bash
# Pod 상태 확인
kubectl get pods -n lakehouse-platform

# Pod 상세 정보
kubectl describe pod <pod-name> -n lakehouse-platform

# 로그 확인
kubectl logs <pod-name> -n lakehouse-platform

# 이전 로그 (크래시된 경우)
kubectl logs <pod-name> -n lakehouse-platform --previous
```

**해결 방법**:

**1. ImagePullBackOff**:
```bash
# 이미지 이름 확인
kubectl describe pod <pod-name> -n lakehouse-platform | grep Image

# 해결: 올바른 이미지 이름으로 수정
vim platform/minio/values.yaml
# image:
#   repository: minio/minio  # 올바른 이미지
#   tag: latest
```

**2. CrashLoopBackOff**:
```bash
# 로그에서 오류 확인
kubectl logs <pod-name> -n lakehouse-platform

# 일반적인 원인:
# - 설정 오류: values.yaml 확인
# - 리소스 부족: resources.requests 증가
# - 의존성 문제: 다른 서비스가 준비되지 않음
```

**3. Pending (리소스 부족)**:
```bash
# 노드 리소스 확인
kubectl top nodes

# 해결: 노드 추가 또는 리소스 요청 감소
vim env/dev/helm-values.yaml
# resources:
#   requests:
#     memory: 256Mi  # 512Mi에서 감소
```

### 8.2 Trino 쿼리 실패

**증상**: 쿼리 실행 시 오류 발생

**진단**:
```bash
# Trino 로그 확인
kubectl logs -n lakehouse-platform deployment/trino-coordinator

# Trino UI 접속
kubectl port-forward -n lakehouse-platform svc/trino 8080:8080
# http://localhost:8080 접속하여 쿼리 상태 확인
```

**일반적인 오류와 해결**:

**1. "Catalog 'iceberg' not found"**:
```yaml
# 원인: Iceberg 카탈로그 설정 누락
# 해결: values.yaml에 카탈로그 추가
trino:
  additionalCatalogs:
    iceberg: |
      connector.name=iceberg
      iceberg.catalog.type=rest
      iceberg.rest-catalog.uri=http://iceberg-catalog:8181
```

**2. "S3 access denied"**:
```yaml
# 원인: MinIO 인증 정보 오류
# 해결: 올바른 credentials 설정
trino:
  additionalCatalogs:
    iceberg: |
      hive.s3.aws-access-key=minioadmin
      hive.s3.aws-secret-key=minioadmin
```

**3. "Out of memory"**:
```yaml
# 원인: 메모리 부족
# 해결: 워커 메모리 증가
trino:
  worker:
    resources:
      requests:
        memory: 8Gi  # 증가
```

### 8.3 MinIO 접속 불가

**증상**: MinIO에 연결할 수 없음

**진단**:
```bash
# MinIO Pod 상태
kubectl get pods -n lakehouse-platform -l app=minio

# MinIO 로그
kubectl logs -n lakehouse-platform deployment/minio

# 서비스 확인
kubectl get svc -n lakehouse-platform minio
```

**해결**:

**1. 포트 포워딩으로 접속**:
```bash
kubectl port-forward -n lakehouse-platform svc/minio 9000:9000
# http://localhost:9000 접속
```

**2. Ingress 설정** (외부 접속):
```yaml
minio:
  ingress:
    enabled: true
    ingressClassName: nginx
    hosts:
      - minio.example.com
```

### 8.4 Airflow DAG가 보이지 않음

**증상**: Airflow UI에 DAG가 표시되지 않음

**진단**:
```bash
# Airflow 스케줄러 로그
kubectl logs -n lakehouse-platform deployment/airflow-scheduler

# DAG 파일 확인
kubectl exec -it -n lakehouse-platform deployment/airflow-scheduler -- ls /opt/airflow/dags
```

**해결**:

**1. GitSync 활성화**:
```yaml
airflow:
  dags:
    gitSync:
      enabled: true
      repo: https://github.com/your-org/dags.git
      branch: main
      subPath: dags
```

**2. DAG 파일 직접 복사**:
```bash
# DAG 파일을 ConfigMap으로 생성
kubectl create configmap airflow-dags \
  --from-file=dags/ \
  -n lakehouse-platform

# Airflow에 마운트
# values.yaml에 추가:
airflow:
  extraVolumes:
    - name: dags
      configMap:
        name: airflow-dags
  extraVolumeMounts:
    - name: dags
      mountPath: /opt/airflow/dags
```

---

## 9. 운영 가이드

### 9.1 일상적인 운영 작업

#### 모니터링

**1. 전체 시스템 상태 확인**:
```bash
# 모든 Pod 상태
kubectl get pods -n lakehouse-platform

# 리소스 사용량
kubectl top nodes
kubectl top pods -n lakehouse-platform

# ArgoCD 애플리케이션 상태
argocd app list
```

**2. Grafana 대시보드**:
```bash
kubectl port-forward -n lakehouse-platform svc/grafana 3000:3000
# http://localhost:3000 접속
# 기본 대시보드:
# - Lakehouse Overview
# - MinIO Metrics
# - Trino Metrics
# - Airflow Metrics
```

#### 로그 확인

```bash
# 특정 컴포넌트 로그
kubectl logs -n lakehouse-platform deployment/trino-coordinator

# 실시간 로그 추적
kubectl logs -f -n lakehouse-platform deployment/trino-coordinator

# 여러 Pod의 로그 (label selector 사용)
kubectl logs -n lakehouse-platform -l app=trino --tail=100
```

#### 스케일링

**수동 스케일링**:
```bash
# Trino 워커 증가
kubectl scale deployment trino-worker -n lakehouse-platform --replicas=10

# 또는 Helm으로
helm upgrade trino ./platform/trino \
  --namespace lakehouse-platform \
  --set server.workers=10 \
  --reuse-values
```

**자동 스케일링 설정**:
```yaml
trino:
  server:
    autoscaling:
      enabled: true
      minReplicas: 5
      maxReplicas: 20
      targetCPUUtilizationPercentage: 70
```

### 9.2 업그레이드

**안전한 업그레이드 절차**:

```bash
# 1. 현재 상태 백업
kubectl get all -n lakehouse-platform -o yaml > backup-$(date +%Y%m%d).yaml

# 2. Git에서 최신 변경사항 가져오기
git pull origin main

# 3. Dry-run으로 변경사항 확인
helm upgrade trino ./platform/trino \
  --namespace lakehouse-platform \
  --values env/prod/helm-values.yaml \
  --dry-run --debug

# 4. 실제 업그레이드
helm upgrade trino ./platform/trino \
  --namespace lakehouse-platform \
  --values env/prod/helm-values.yaml \
  --wait --timeout 10m

# 5. 롤아웃 상태 확인
kubectl rollout status deployment/trino-coordinator -n lakehouse-platform

# 6. 검증
./scripts/validate.sh
```

**롤백** (문제 발생 시):
```bash
# Helm 히스토리 확인
helm history trino -n lakehouse-platform

# 이전 버전으로 롤백
helm rollback trino -n lakehouse-platform

# 특정 리비전으로 롤백
helm rollback trino 3 -n lakehouse-platform
```

### 9.3 백업 및 복구

**백업**:

```bash
# 1. Kubernetes 리소스 백업
kubectl get all -n lakehouse-platform -o yaml > k8s-backup.yaml

# 2. Helm 릴리스 백업
helm list -n lakehouse-platform -o yaml > helm-backup.yaml

# 3. MinIO 데이터 백업 (mc 클라이언트 사용)
mc mirror minio/lakehouse-warehouse /backup/lakehouse-warehouse

# 4. Iceberg 메타데이터 백업
kubectl exec -n lakehouse-platform deployment/iceberg-catalog -- \
  pg_dump -U postgres catalog > iceberg-backup.sql
```

**복구**:

```bash
# 1. 인프라 재생성
cd infra
terraform apply -var-file=../env/prod/terraform.tfvars

# 2. 플랫폼 재배포
./scripts/bootstrap.sh prod

# 3. MinIO 데이터 복구
mc mirror /backup/lakehouse-warehouse minio/lakehouse-warehouse

# 4. Iceberg 메타데이터 복구
kubectl exec -i -n lakehouse-platform deployment/iceberg-catalog -- \
  psql -U postgres catalog < iceberg-backup.sql
```

### 9.4 보안 관리

**Secret 관리**:

```bash
# Secret 생성
kubectl create secret generic minio-credentials \
  --from-literal=accesskey=AKIAIOSFODNN7EXAMPLE \
  --from-literal=secretkey=wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY \
  -n lakehouse-platform

# Secret 사용
# values.yaml:
minio:
  existingSecret: minio-credentials
```

**RBAC 설정**:

```yaml
# rbac.yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: lakehouse-developer
  namespace: lakehouse-platform
rules:
- apiGroups: [""]
  resources: ["pods", "pods/log"]
  verbs: ["get", "list", "watch"]
- apiGroups: ["apps"]
  resources: ["deployments"]
  verbs: ["get", "list"]

---
apiVersion: rbac.authorization.k8s.io/v1
kind:RoleBinding
metadata:
  name: lakehouse-developer-binding
  namespace: lakehouse-platform
subjects:
- kind: User
  name: developer@example.com
roleRef:
  kind: Role
  name: lakehouse-developer
  apiGroup: rbac.authorization.k8s.io
```

---

## 10. FAQ

### Q1: 로컬 개발 환경에서 시작하려면?

**A**: 다음 명령어만 실행하면 됩니다:

```bash
git clone https://github.com/your-org/lakehouse.git
cd lakehouse
./scripts/bootstrap.sh dev
```

5-10분 후 전체 플랫폼이 실행됩니다.

### Q2: 프로덕션 환경으로 배포하려면?

**A**: 환경 설정만 변경하면 됩니다:

```bash
# 1. 프로덕션 설정 검토
vim env/prod/terraform.tfvars
vim env/prod/helm-values.yaml

# 2. 배포
./scripts/bootstrap.sh prod
```

### Q3: MinIO를 AWS S3로 교체하려면?

**A**: Iceberg Catalog 설정만 변경하면 됩니다:

```yaml
# env/prod/helm-values.yaml
icebergCatalog:
  config:
    warehouse: s3://my-aws-bucket/lakehouse/
    s3:
      endpoint: https://s3.amazonaws.com
      region: us-east-1
      accessKeyIdSecret: aws-credentials
      secretAccessKeySecret: aws-credentials
```

Trino는 자동으로 AWS S3를 사용합니다.

### Q4: Trino 워커를 더 추가하려면?

**A**: 설정 파일에서 숫자만 변경:

```yaml
# env/prod/helm-values.yaml
trino:
  server:
    workers: 20  # 5 → 20으로 증가
```

```bash
helm upgrade trino ./platform/trino \
  --namespace lakehouse-platform \
  --values env/prod/helm-values.yaml
```

### Q5: 새로운 테이블을 만들려면?

**A**: Trino에서 SQL로 생성:

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
```

### Q6: Airflow DAG를 추가하려면?

**A**: Git 저장소에 DAG 파일 추가:

```python
# dags/my_pipeline.py
from airflow import DAG
from airflow.providers.cncf.kubernetes.operators.kubernetes_pod import KubernetesPodOperator
from datetime import datetime

with DAG(
    'my_pipeline',
    start_date=datetime(2024, 1, 1),
    schedule_interval='@daily',
    catchup=False
) as dag:
    
    task = KubernetesPodOperator(
        task_id='process_data',
        name='process-data',
        namespace='lakehouse-platform',
        image='lakehouse/my-job:1.0',
        cmds=['python', 'process.py'],
        arguments=['--date', '{{ ds }}']
    )
```

Git에 푸시하면 자동으로 Airflow에 나타납니다.

### Q7: 메모리 부족 오류가 발생하면?

**A**: 리소스 증가:

```yaml
# env/prod/helm-values.yaml
trino:
  worker:
    resources:
      requests:
        memory: 16Gi  # 기존 8Gi에서 증가
        cpu: 8000m
```

### Q8: 모니터링 대시보드를 보려면?

**A**: Grafana 접속:

```bash
kubectl port-forward -n lakehouse-platform svc/grafana 3000:3000
# http://localhost:3000 접속
# ID: admin, PW: admin (개발 환경)
```

### Q9: 전체 플랫폼을 제거하려면?

**A**: 클린업 스크립트 실행:

```bash
./scripts/cleanup.sh dev
# 확인 메시지에 'yes' 입력
```

### Q10: 설정을 변경했는데 적용이 안 되면?

**A**: Helm 업그레이드 실행:

```bash
helm upgrade <component> ./platform/<component> \
  --namespace lakehouse-platform \
  --values env/dev/helm-values.yaml
```

---

## 부록 A: 명령어 치트 시트

### Kubernetes

```bash
# Pod 목록
kubectl get pods -n lakehouse-platform

# Pod 상세 정보
kubectl describe pod <pod-name> -n lakehouse-platform

# 로그 확인
kubectl logs <pod-name> -n lakehouse-platform
kubectl logs -f <pod-name> -n lakehouse-platform  # 실시간

# Pod 내부 접속
kubectl exec -it <pod-name> -n lakehouse-platform -- /bin/bash

# 리소스 사용량
kubectl top nodes
kubectl top pods -n lakehouse-platform

# 포트 포워딩
kubectl port-forward -n lakehouse-platform svc/trino 8080:8080
```

### Helm

```bash
# 릴리스 목록
helm list -n lakehouse-platform

# 릴리스 상태
helm status trino -n lakehouse-platform

# 업그레이드
helm upgrade trino ./platform/trino \
  --namespace lakehouse-platform \
  --values env/dev/helm-values.yaml

# 롤백
helm rollback trino -n lakehouse-platform

# 히스토리
helm history trino -n lakehouse-platform

# 삭제
helm uninstall trino -n lakehouse-platform
```

### ArgoCD

```bash
# 애플리케이션 목록
argocd app list

# 애플리케이션 상태
argocd app get trino

# 동기화
argocd app sync trino

# 차이점 확인
argocd app diff trino
```

### Terraform

```bash
# 초기화
terraform init

# 계획
terraform plan -var-file=../env/dev/terraform.tfvars

# 적용
terraform apply -var-file=../env/dev/terraform.tfvars

# 제거
terraform destroy -var-file=../env/dev/terraform.tfvars
```

---

## 부록 B: 추가 리소스

### 공식 문서

- **Apache Iceberg**: https://iceberg.apache.org/docs/latest/
- **Trino**: https://trino.io/docs/current/
- **MinIO**: https://min.io/docs/minio/kubernetes/upstream/
- **Apache Airflow**: https://airflow.apache.org/docs/
- **Prometheus**: https://prometheus.io/docs/
- **Grafana**: https://grafana.com/docs/

### 커뮤니티

- **Iceberg Slack**: https://apache-iceberg.slack.com/
- **Trino Slack**: https://trino.io/slack.html
- **Airflow Slack**: https://apache-airflow.slack.com/
## 8. 문제 해결 가이드

### 8.1 Observability 설치 실패 (CRD Too Long Error)

**증상**:
ArgoCD에서 `observability` 애플리케이션이 `Sync Failed` 또는 `Missing` 상태로 멈춰있고, 상세 에러에 `metadata.annotations: Too long: must have at most 262144 bytes` 메시지가 나타남.

**원인**:
`kube-prometheus-stack` 차트에 포함된 CRD(Custom Resource Definitions) 파일들의 크기가 Kubernetes의 클라이언트 사이드 적용 제한(256KB)을 초과하여 발생합니다.

**해결 방법**:

**방법 1: ArgoCD 설정 확인 (권장)**
`observability-application.yaml` 파일에 `ServerSideApply=true` 옵션이 설정되어 있는지 확인합니다. 이 옵션은 클라이언트 사이드 제한을 우회합니다.

```yaml
    syncOptions:
      - ServerSideApply=true
```

**방법 2: 수동 설치 (즉시 해결)**
ArgoCD가 계속 실패할 경우, 로컬 터미널에서 Helm으로 직접 설치하여 문제를 우회할 수 있습니다.

```bash
# 로컬에서 직접 Helm 차트 설치
helm upgrade --install observability platform/observability \
  -f platform/observability/values.yaml \
  -f env/dev/observability-values.yaml \
  --namespace lakehouse-platform \
  --create-namespace
```
설치가 완료되면 ArgoCD가 자동으로 리소스를 인식하여 `Synced` 상태로 변경됩니다.

### 8.2 포트 포워딩 연결 끊김 (Broken Pipe)

**증상**:
`kubectl port-forward` 사용 중 `E1231 ... error: broken pipe` 에러가 발생하며 연결이 끊어짐.

**해결 방법**:
MinIO와 같이 웹 소켓이나 리다이렉션이 많은 통신의 경우 `localhost` 대신 `127.0.0.1`을 명시적으로 사용하세요.

```bash
kubectl port-forward svc/minio -n lakehouse-platform 9000:9000 --address 127.0.0.1
```

### 학습 자료

- **Iceberg 튜토리얼**: https://iceberg.apache.org/docs/latest/spark-getting-started/
- **Trino 쿼리 가이드**: https://trino.io/docs/current/sql.html
- **Airflow 튜토리얼**: https://airflow.apache.org/docs/apache-airflow/stable/tutorial.html

---

**이 가이드에 대한 피드백이나 질문이 있으시면 GitHub Issues에 등록해주세요!**

**Happy Data Engineering! 🚀**
