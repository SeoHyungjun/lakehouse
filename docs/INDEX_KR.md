# Lakehouse 플랫폼 문서 인덱스

> 모든 문서를 한눈에 볼 수 있는 네비게이션 가이드

**최종 업데이트**: 2026-01-26

---

## 🚀 처음 사용하시나요?

다음 순서로 읽어보세요:

1. **[README_KR.md](../README_KR.md)** - 프로젝트 개요 (3분)
2. **[GETTING_STARTED_KR.md](GETTING_STARTED_KR.md)** - 빠른 시작 가이드 (10분)
3. **[ARCHITECTURE_KR.md](ARCHITECTURE_KR.md)** - 아키텍처 이해 (15분)

---

## 📚 문서 카테고리

### 1️⃣ 사용자 가이드 (`docs/`)

| 문서 | 내용 | 대상 |
|------|------|------|
| **[README.md](README.md)** | 문서 구조 설명 | 모든 사용자 |
| **[GETTING_STARTED_KR.md](GETTING_STARTED_KR.md)** | 설치 및 시작 가이드 | 초보자 |
| **[ARCHITECTURE_KR.md](ARCHITECTURE_KR.md)** | 시스템 아키텍처 | 개발자/아키텍트 |
| **[runbook.md](runbook.md)** | 배포/운영 절차 | 운영자/DevOps |
| **[SECRET_MANAGEMENT_KR.md](SECRET_MANAGEMENT_KR.md)** | 시크릿 관리 | 보안 담당자 |
| **[AIRFLOW_DAG_ENV_KR.md](AIRFLOW_DAG_ENV_KR.md)** | Airflow DAG 개발 | 데이터 엔지니어 |

### 2️⃣ 계약서 (`contracts/`)

**명확한 인터페이스 규격 - 변경 시 버전 관리 필수**

| 문서 | 내용 | 대상 |
|------|------|------|
| **[README.md](../contracts/README.md)** | 계약서 시스템 설명 | 모든 개발자 |
| **[repository-contract.md](../contracts/repository-contract.md)** | 디렉토리 구조 규칙 | 모든 개발자 |
| **[kubernetes-cluster.md](../contracts/kubernetes-cluster.md)** | K8s 클러스터 요구사항 | 인프라 엔지니어 |
| **[object-storage.md](../contracts/object-storage.md)** | S3 API 인터페이스 | 백엔드 개발자 |
| **[iceberg-catalog.md](../contracts/iceberg-catalog.md)** | Iceberg REST API | 데이터 엔지니어 |
| **[query-engine.md](../contracts/query-engine.md)** | Trino SQL 인터페이스 | 분석가/개발자 |
| **[service-module.md](../contracts/service-module.md)** | 서비스 표준 규격 | 서비스 개발자 |
| **[workflow-orchestration.md](../contracts/workflow-orchestration.md)** | 워크플로우 규격 | 데이터 엔지니어 |

### 3️⃣ 컴포넌트 상세 문서 (`platform/`)

각 Helm 차트별 설정 및 사용법:

| 컴포넌트 | README 위치 |
|---------|-------------|
| **MinIO** | [platform/minio/README.md](../platform/minio/README.md) |
| **Iceberg Catalog** | [platform/iceberg-catalog/README.md](../platform/iceberg-catalog/README.md) |
| **Trino** | [platform/trino/README.md](../platform/trino/README.md) |
| **Airflow** | [platform/airflow/README.md](../platform/airflow/README.md) |
| **Observability** | [platform/observability/README.md](../platform/observability/README.md) |
| **ArgoCD** | [platform/argocd/README.md](../platform/argocd/README.md) |

### 4️⃣ 환경 설정 (`env/`)

| 문서 | 내용 |
|------|------|
| **[env/README.md](../env/README.md)** | 환경별 설정 가이드 (dev/staging/prod) |

---

## 🎯 시나리오별 가이드

### 시나리오 1: 로컬에서 빠르게 테스트

```
1. GETTING_STARTED_KR.md → "빠른 시작" 섹션
2. 명령어 실행: ./scripts/bootstrap.sh dev
3. 첫 쿼리 실행해보기
```

### 시나리오 2: 프로덕션 배포

```
1. env/README.md → 프로덕션 설정 확인
2. SECRET_MANAGEMENT_KR.md → 시크릿 설정
3. runbook.md → 배포 절차 따라하기
4. runbook.md → 모니터링 설정
```

### 시나리오 3: Airflow DAG 개발

```
1. contracts/workflow-orchestration.md → 워크플로우 규격 확인
2. AIRFLOW_DAG_ENV_KR.md → DAG 개발 가이드
3. platform/airflow/README.md → Airflow 설정
```

### 시나리오 4: 문제 해결

```
1. runbook.md → "Troubleshooting" 섹션
2. 해당 컴포넌트 README 확인 (platform/*/README.md)
3. GitHub Issues 검색
```

### 시나리오 5: 새 서비스 개발

```
1. contracts/service-module.md → 서비스 표준 확인
2. services/sample-service/ → 샘플 참조
3. 개발 후 테스트
```

---

## 🔍 주제별 빠른 찾기

### 설치 & 배포
- ⚡ 빠른 시작: [GETTING_STARTED_KR.md](GETTING_STARTED_KR.md)
- 🏗️ 프로덕션 배포: [runbook.md - Deployment](runbook.md)
- ⚙️ 환경 설정: [env/README.md](../env/README.md)

### 아키텍처
- 📐 전체 구조: [ARCHITECTURE_KR.md](ARCHITECTURE_KR.md)
- 🔄 데이터 흐름: [ARCHITECTURE_KR.md - 데이터 흐름](ARCHITECTURE_KR.md)
- 📁 디렉토리 규칙: [contracts/repository-contract.md](../contracts/repository-contract.md)

### 개발
- 📋 계약서 목록: [contracts/README.md](../contracts/README.md)
- ✈️ DAG 개발: [AIRFLOW_DAG_ENV_KR.md](AIRFLOW_DAG_ENV_KR.md)
- 🔐 시크릿 관리: [SECRET_MANAGEMENT_KR.md](SECRET_MANAGEMENT_KR.md)

### 운영
- 🚀 배포/업그레이드: [runbook.md](runbook.md)
- 📊 모니터링: [platform/observability/README.md](../platform/observability/README.md)
- 🔧 문제 해결: [runbook.md - Troubleshooting](runbook.md)

### 사용법
- 💻 SQL 쿼리: [platform/trino/README.md](../platform/trino/README.md)
- 📦 데이터 저장: [platform/minio/README.md](../platform/minio/README.md)
- 📊 테이블 관리: [platform/iceberg-catalog/README.md](../platform/iceberg-catalog/README.md)

---

## ✅ 체크리스트

### 초기 설정 (개발 환경)
- [ ] 사전 요구사항 설치 (kubectl, helm, kind)
- [ ] `git clone` 실행
- [ ] `./scripts/bootstrap.sh dev` 실행
- [ ] 서비스 접속 확인 (Trino, MinIO)
- [ ] 첫 번째 쿼리 실행

### 프로덕션 배포
- [ ] `env/prod/` 설정 검토
- [ ] 시크릿 설정 ([SECRET_MANAGEMENT_KR.md](SECRET_MANAGEMENT_KR.md))
- [ ] TLS/인증 활성화
- [ ] 리소스 크기 확인
- [ ] 백업 전략 수립
- [ ] 모니터링/알림 설정
- [ ] `./scripts/bootstrap.sh prod` 실행
- [ ] 검증 테스트 실행

---

## 🆘 도움말

### 문서를 찾을 수 없나요?
1. 이 페이지에서 `Ctrl+F` 검색
2. [docs/README.md](README.md)에서 문서 구조 확인
3. GitHub에서 Issue 생성

### 문제가 해결되지 않나요?
- 📖 [runbook.md - Troubleshooting](runbook.md)
- 🐛 [GitHub Issues](https://github.com/SeoHyungjun/lakehouse/issues)
- 💬 [GitHub Discussions](https://github.com/SeoHyungjun/lakehouse/discussions)

---

## 📝 문서 기여

문서 개선 제안:
1. 오타/오류 발견 → GitHub Issue
2. 새 가이드 추가 → Pull Request
3. 번역 개선 → Pull Request

---

**Last Updated**: 2026-01-26  
**Version**: 1.0

[⬆ 맨 위로](#lakehouse-플랫폼-문서-인덱스)
