# Lakehouse 플랫폼 시작 가이드

> 빠른 설치부터 첫 쿼리 실행까지 - 완벽 가이드

**최종 업데이트**: 2026-01-26

---

## 📋 목차

1. [사전 요구사항](#1-사전-요구사항)
2. [빠른 시작 (5분)](#2-빠른-시작-5분)
3. [첫 번째 쿼리](#3-첫-번째-쿼리)
4. [서비스 접속](#4-서비스-접속)
5. [환경별 배포](#5-환경별-배포)
6. [문제 해결](#6-문제-해결)

---

## 1. 사전 요구사항

### 필수 도구

```bash
# macOS
brew install kubectl helm terraform kind

# Linux (Ubuntu/Debian)
# kubectl 설치
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

# helm 설치
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# terraform 설치
wget https://releases.hashicorp.com/terraform/1.6.0/terraform_1.6.0_linux_amd64.zip
unzip terraform_1.6.0_linux_amd64.zip
sudo mv terraform /usr/local/bin/

# kind 설치
curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.20.0/kind-linux-amd64
chmod +x ./kind
sudo mv ./kind /usr/local/bin/kind
```

### 시스템 요구사항

| 환경 | CPU | 메모리 | 디스크 |
|------|-----|--------|--------|
| **개발 (dev)** | 2 cores | 4 GB | 20 GB |
| **스테이징 (staging)** | 4 cores | 8 GB | 50 GB |
| **프로덕션 (prod)** | 8+ cores | 16+ GB | 100+ GB |

---

## 2. 빠른 시작 (5분)

### Step 1: 저장소 클론

```bash
git clone https://github.com/SeoHyungjun/lakehouse.git
cd lakehouse
```

### Step 2: 개발 환경 배포

```bash
# 전체 플랫폼 자동 배포
./scripts/bootstrap.sh dev
```

이 명령은 다음을 수행합니다:
1. ✅ Kind 클러스터 생성
2. ✅ MinIO (S3 스토리지) 배포
3. ✅ Iceberg Catalog 배포
4. ✅ Trino (쿼리 엔진) 배포
5. ✅ Airflow (워크플로우) 배포
6. ✅ Prometheus + Grafana 배포
7. ✅ ArgoCD (GitOps) 배포

**예상 소요 시간**: 약 5-10분

### Step 3: 배포 확인

```bash
# 모든 Pod 확인
kubectl get pods -n lakehouse-platform

# 모든 Pod가 Running 상태가 될 때까지 대기
kubectl wait --for=condition=Ready pods --all -n lakehouse-platform --timeout=300s
```

---

## 3. 첫 번째 쿼리

### Step 1: Trino CLI 접속

```bash
# Trino 포트 포워딩
kubectl port-forward -n lakehouse-platform svc/trino 8080:8080 &

# Trino CLI 실행
trino --server localhost:8080 --catalog iceberg --schema default
```

### Step 2: 스키마 생성

```sql
-- 새 스키마 생성
CREATE SCHEMA IF NOT EXISTS sales;

-- 사용 중인 스키마 확인
SHOW SCHEMAS;
```

### Step 3: 테이블 생성

```sql
-- 주문 테이블 생성 (Iceberg 형식, Parquet 파일)
CREATE TABLE sales.orders (
    order_id BIGINT,
    customer_id BIGINT,
    order_date DATE,
    amount DECIMAL(10, 2),
    status VARCHAR
)
WITH (
    format = 'PARQUET',
    partitioning = ARRAY['order_date']
);
```

### Step 4: 데이터 삽입

```sql
-- 샘플 데이터 삽입
INSERT INTO sales.orders VALUES
    (1, 100, DATE '2024-01-01', 1500.00, 'completed'),
    (2, 101, DATE '2024-01-02', 2500.00, 'completed'),
    (3, 102, DATE '2024-01-03', 1200.00, 'pending');

-- 데이터 확인
SELECT * FROM sales.orders;
```

### Step 5: 고급 쿼리

```sql
-- 날짜별 매출 집계
SELECT 
    order_date,
    COUNT(*) as order_count,
    SUM(amount) as total_amount
FROM sales.orders
GROUP BY order_date
ORDER BY order_date;

-- Time Travel (과거 시점 조회)
SELECT * FROM sales.orders FOR VERSION AS OF 1;

-- 스냅샷 확인
SELECT * FROM "sales.orders$snapshots";
```

**축하합니다! 🎉** Lakehouse에서 첫 번째 쿼리를 실행했습니다.

---

## 4. 서비스 접속

### 4.1 Trino (쿼리 엔진)

```bash
# 포트 포워딩
kubectl port-forward -n lakehouse-platform svc/trino 8080:8080

# Web UI 접속
open http://localhost:8080

# CLI 접속
trino --server localhost:8080 --catalog iceberg --schema default
```

### 4.2 MinIO (S3 스토리지)

```bash
# 포트 포워딩
kubectl port-forward -n lakehouse-platform svc/minio 9000:9000 9001:9001

# Console 접속
open http://localhost:9001

# 기본 인증 정보 (개발 환경)
# ID: admin
# PW: (kubectl get secret minio-creds -n lakehouse-platform -o jsonpath='{.data.password}' | base64 -d)
```

### 4.3 Airflow (워크플로우)

```bash
# 포트 포워딩
kubectl port-forward -n lakehouse-platform svc/airflow-webserver 8081:8080

# Web UI 접속
open http://localhost:8081

# 기본 인증 정보 (개발 환경)
# ID: admin
# PW: (kubectl get secret airflow-admin-password -n lakehouse-platform -o jsonpath='{.data.password}' | base64 -d)
```

### 4.4 Grafana (모니터링)

```bash
# 포트 포워딩
kubectl port-forward -n lakehouse-platform svc/observability-grafana 3000:80

# Web UI 접속
open http://localhost:3000

# 기본 인증 정보 (개발 환경)
# ID: admin
# PW: admin
```

---

## 5. 환경별 배포

### 5.1 개발 환경 (dev)

```bash
./scripts/bootstrap.sh dev
```

**특징**:
- 단일 노드 (로컬 Kind 클러스터)
- 최소 리소스 (빠른 시작)
- 인증 비활성화
- 로그 레벨: DEBUG

### 5.2 스테이징 환경 (staging)

```bash
./scripts/bootstrap.sh staging
```

**특징**:
- 3개 노드 (HA 테스트)
- 중간 리소스
- 기본 인증 활성화
- Ingress 활성화
- 메트릭 수집

### 5.3 프로덕션 환경 (prod)

```bash
./scripts/bootstrap.sh prod
```

**특징**:
- 5+ 노드 (고가용성)
- 최대 리소스
- TLS/OAuth2 인증
- Pod Anti-Affinity
- 엄격한 보안 정책
- 알림 설정

### 5.4 환경 설정 수정

각 환경의 설정은 `env/{environment}/` 디렉토리에 있습니다:

```bash
# 개발 환경 MinIO 설정 수정
vim env/dev/minio-values.yaml

# 프로덕션 환경 Trino 설정 수정
vim env/prod/trino-values.yaml
```

설정 변경 후 재배포:

```bash
# 특정 컴포넌트만 업데이트
helm upgrade trino platform/trino \
  -n lakehouse-platform \
  -f env/prod/trino-values.yaml

# 또는 전체 재배포
./scripts/bootstrap.sh prod
```

---

## 6. 문제 해결

### 6.1 Pod가 시작되지 않음

```bash
# Pod 상태 확인
kubectl get pods -n lakehouse-platform

# Pod 상세 정보
kubectl describe pod <pod-name> -n lakehouse-platform

# 로그 확인
kubectl logs <pod-name> -n lakehouse-platform

# 이전 로그 확인 (재시작된 경우)
kubectl logs <pod-name> -n lakehouse-platform --previous
```

**일반적인 원인**:
- 리소스 부족 (메모리/CPU)
- 이미지 pull 실패
- ConfigMap/Secret 누락

### 6.2 Trino 쿼리 실패

```bash
# Trino Coordinator 로그
kubectl logs -n lakehouse-platform deployment/trino-coordinator -f

# Trino Worker 로그
kubectl logs -n lakehouse-platform deployment/trino-worker -f

# Web UI에서 실패한 쿼리 확인
# http://localhost:8080 접속 후 Failed Queries 탭
```

**일반적인 원인**:
- Iceberg Catalog 연결 실패
- MinIO 접근 권한 문제
- 메모리 부족

### 6.3 MinIO 접속 불가

```bash
# MinIO Pod 확인
kubectl get pods -n lakehouse-platform -l app=minio

# MinIO 로그
kubectl logs -n lakehouse-platform deployment/minio

# MinIO 서비스 확인
kubectl get svc -n lakehouse-platform minio
```

### 6.4 전체 플랫폼 제거

```bash
# 모든 리소스 제거
./scripts/cleanup.sh dev

# Kind 클러스터까지 제거
kind delete cluster --name lakehouse-dev
```

---

## 다음 단계

### 더 배우기
- **[아키텍처 가이드](ARCHITECTURE_KR.md)** - 시스템 설계 이해
- **[운영 가이드](runbook.md)** - 프로덕션 운영 방법
- **[계약서](../contracts/README.md)** - API 인터페이스 specs

### DAG 개발
- **[Airflow DAG 가이드](AIRFLOW_DAG_ENV_KR.md)** - 워크플로우 개발
- **[샘플 워크플로우](../workflows/sample-job/)** - 예제 코드

### 시크릿 관리
- **[시크릿 관리 가이드](SECRET_MANAGEMENT_KR.md)** - Sealed Secrets 사용법

---

## FAQ

### Q: 로컬에서 가장 빠르게 테스트하려면?
```bash
./scripts/bootstrap.sh dev
```

### Q: 프로덕션 배포는 어떻게?
[운영 가이드](runbook.md)의 "Deployment Procedures" 참조

### Q: MinIO를 AWS S3로 교체하려면?
`env/prod/iceberg-catalog-values.yaml`에서 warehouse 경로만 변경:
```yaml
catalog:
  warehouse: s3://my-aws-bucket/lakehouse/
  s3:
    endpoint: https://s3.amazonaws.com
    region: us-east-1
```

### Q: 리소스를 줄이고 싶다면?
`env/dev/*-values.yaml` 파일에서 `resources.requests` 값 조정

---

**Last Updated**: 2026-01-26  
**Version**: 1.0

[⬆ 맨 위로](#lakehouse-플랫폼-시작-가이드)
