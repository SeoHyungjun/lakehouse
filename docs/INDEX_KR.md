# Lakehouse 플랫폼 문서 인덱스

이 문서는 Lakehouse 플랫폼의 모든 문서를 한눈에 볼 수 있도록 정리한 인덱스입니다.

---

## 🚀 시작하기

처음 사용하시는 분은 다음 순서로 문서를 읽어보세요:

1. **[README_KR.md](../README_KR.md)** - 프로젝트 개요 및 빠른 시작
2. **[GETTING_STARTED_KR.md](GETTING_STARTED_KR.md)** - 완벽 시작 가이드 (필독!)
3. **[ARCHITECTURE_KR.md](ARCHITECTURE_KR.md)** - 아키텍처 및 데이터 흐름

---

## 📚 문서 카테고리

### 1. 개요 및 시작 가이드

| 문서 | 설명 | 대상 독자 |
|------|------|----------|
| [README_KR.md](../README_KR.md) | 프로젝트 개요, 주요 특징, 빠른 시작 | 모든 사용자 |
| [GETTING_STARTED_KR.md](GETTING_STARTED_KR.md) | 완벽 시작 가이드 - 설치부터 커스터마이징까지 | 초보자 |
| [ARCHITECTURE_KR.md](ARCHITECTURE_KR.md) | 시스템 아키텍처, 데이터 흐름, 파일 구조 | 개발자, 아키텍트 |

### 2. 운영 가이드

| 문서 | 설명 | 대상 독자 |
|------|------|----------|
| [runbook.md](runbook.md) | 배포, 업그레이드, 롤백, 문제 해결 절차 | 운영자, DevOps |
| [dod-report.md](dod-report.md) | 모든 모듈의 완료 기준(DoD) 검증 보고서 | 품질 관리자, 아키텍트 |
| [definition_of_done.md](definition_of_done.md) | 모듈 완료 기준 정의 | 개발자, 품질 관리자 |

### 3. 계약서 (Contracts)

모든 컴포넌트가 준수해야 하는 인터페이스 정의:

| 문서 | 설명 | 대상 독자 |
|------|------|----------|
| [kubernetes-cluster.md](../contracts/kubernetes-cluster.md) | Kubernetes 클러스터 요구사항 | 인프라 엔지니어 |
| [object-storage.md](../contracts/object-storage.md) | S3 호환 스토리지 인터페이스 | 개발자 |
| [iceberg-catalog.md](../contracts/iceberg-catalog.md) | Iceberg Catalog REST API 스펙 | 개발자 |
| [query-engine.md](../contracts/query-engine.md) | SQL 쿼리 엔진 요구사항 | 개발자 |
| [service-module.md](../contracts/service-module.md) | 서비스 모듈 표준 | 서비스 개발자 |
| [workflow-orchestration.md](../contracts/workflow-orchestration.md) | 워크플로우 오케스트레이션 표준 | 데이터 엔지니어 |

### 4. 컴포넌트별 문서

각 플랫폼 컴포넌트의 상세 문서:

| 컴포넌트 | 문서 위치 | 설명 |
|---------|----------|------|
| **MinIO** | [platform/minio/README.md](../platform/minio/README.md) | 객체 스토리지 설정 및 사용법 |
| **Iceberg Catalog** | [platform/iceberg-catalog/README.md](../platform/iceberg-catalog/README.md) | 메타데이터 카탈로그 설정 |
| **Trino** | [platform/trino/README.md](../platform/trino/README.md) | 쿼리 엔진 설정 및 사용법 |
| **Airflow** | [platform/airflow/README.md](../platform/airflow/README.md) | 워크플로우 오케스트레이션 |
| **Observability** | [platform/observability/README.md](../platform/observability/README.md) | Prometheus + Grafana 설정 |
| **ArgoCD** | [platform/argocd/README.md](../platform/argocd/README.md) | GitOps 배포 자동화 |

### 5. 샘플 및 예제

| 문서 | 설명 | 대상 독자 |
|------|------|----------|
| [services/sample-service/README.md](../services/sample-service/README.md) | REST API 샘플 서비스 | 서비스 개발자 |
| [workflows/sample-job/README.md](../workflows/sample-job/README.md) | 데이터 파이프라인 샘플 | 데이터 엔지니어 |

### 6. 테스트

| 문서 | 설명 | 대상 독자 |
|------|------|----------|
| [tests/e2e/README.md](../tests/e2e/README.md) | E2E 테스트 가이드 | QA, 개발자 |
| [tests/compatibility/bare-metal-validation-report.md](../tests/compatibility/bare-metal-validation-report.md) | 베어메탈 호환성 검증 보고서 | 운영자 |

### 7. 환경 설정

| 문서 | 설명 | 대상 독자 |
|------|------|----------|
| [env/README.md](../env/README.md) | 환경별 설정 가이드 (dev/staging/prod) | 모든 사용자 |

---

## 📖 사용 시나리오별 가이드

### 시나리오 1: 처음 시작하는 경우

```
1. README_KR.md 읽기 (5분)
   ↓
2. GETTING_STARTED_KR.md의 "빠른 시작" 따라하기 (10분)
   ↓
3. 첫 번째 쿼리 실행해보기
   ↓
4. ARCHITECTURE_KR.md로 아키텍처 이해하기
```

### 시나리오 2: 프로덕션 배포

```
1. GETTING_STARTED_KR.md의 "환경별 설정" 읽기
   ↓
2. env/README.md에서 프로덕션 설정 확인
   ↓
3. runbook.md의 "배포 절차" 따라하기
   ↓
4. runbook.md의 "모니터링" 설정
```

### 시나리오 3: 문제 해결

```
1. GETTING_STARTED_KR.md의 "문제 해결 가이드" 확인
   ↓
2. runbook.md의 "Troubleshooting" 섹션 참조
   ↓
3. 해당 컴포넌트의 README.md 확인
```

### 시나리오 4: 커스터마이징

```
1. GETTING_STARTED_KR.md의 "커스터마이징 가이드" 읽기
   ↓
2. 해당 컴포넌트의 README.md 확인
   ↓
3. contracts/ 에서 인터페이스 확인
   ↓
4. env/ 에서 환경별 설정 수정
```

### 시나리오 5: 새 서비스 개발

```
1. contracts/service-module.md 읽기
   ↓
2. services/sample-service/README.md 참조
   ↓
3. definition_of_done.md로 완료 기준 확인
```

### 시나리오 6: 워크플로우 개발

```
1. contracts/workflow-orchestration.md 읽기
   ↓
2. workflows/sample-job/README.md 참조
   ↓
3. Airflow DAG 작성
```

---

## 🔍 주제별 빠른 찾기

### 설치 및 배포

- **로컬 개발 환경**: [GETTING_STARTED_KR.md - 빠른 시작](GETTING_STARTED_KR.md#2-빠른-시작-5분-안에-실행하기)
- **프로덕션 배포**: [runbook.md - Deployment](runbook.md#deployment-procedures)
- **환경별 설정**: [env/README.md](../env/README.md)

### 아키텍처 이해

- **전체 아키텍처**: [ARCHITECTURE_KR.md - 전체 아키텍처](ARCHITECTURE_KR.md#전체-아키텍처-다이어그램)
- **데이터 흐름**: [ARCHITECTURE_KR.md - 데이터 흐름](ARCHITECTURE_KR.md#데이터-흐름-시나리오)
- **파일 구조**: [ARCHITECTURE_KR.md - 파일 시스템](ARCHITECTURE_KR.md#파일-시스템-구조)

### 사용법

- **SQL 쿼리**: [GETTING_STARTED_KR.md - 첫 번째 쿼리](GETTING_STARTED_KR.md#25-첫-번째-쿼리-실행)
- **테이블 생성**: [README_KR.md - 사용 예시](../README_KR.md#테이블-생성-및-데이터-삽입)
- **워크플로우**: [workflows/sample-job/README.md](../workflows/sample-job/README.md)

### 운영

- **모니터링**: [runbook.md - Monitoring](runbook.md#monitoring--alerts)
- **업그레이드**: [runbook.md - Upgrade](runbook.md#upgrade-procedures)
- **롤백**: [runbook.md - Rollback](runbook.md#rollback-procedures)
- **백업**: [runbook.md - Disaster Recovery](runbook.md#disaster-recovery)

### 문제 해결

- **Pod 문제**: [runbook.md - Pod Not Starting](runbook.md#1-pod-not-starting)
- **Trino 문제**: [runbook.md - Trino Query Failures](runbook.md#3-trino-query-failures)
- **MinIO 문제**: [runbook.md - MinIO Issues](runbook.md#4-minio-issues)
- **Airflow 문제**: [runbook.md - Airflow DAG Issues](runbook.md#5-airflow-dag-issues)

### 커스터마이징

- **리소스 조정**: [GETTING_STARTED_KR.md - 리소스 크기 조정](GETTING_STARTED_KR.md#71-리소스-크기-조정)
- **새 환경 추가**: [GETTING_STARTED_KR.md - 새로운 환경 추가](GETTING_STARTED_KR.md#72-새로운-환경-추가)
- **카탈로그 추가**: [GETTING_STARTED_KR.md - 새로운 카탈로그 추가](GETTING_STARTED_KR.md#73-새로운-카탈로그-추가)
- **인증 설정**: [GETTING_STARTED_KR.md - 인증 설정](GETTING_STARTED_KR.md#74-인증-설정)

---

## 📋 체크리스트

### 초기 설정 체크리스트

- [ ] 사전 요구사항 설치 (kubectl, helm, terraform, kind)
- [ ] 저장소 클론
- [ ] 개발 환경 배포 (`./scripts/bootstrap.sh dev`)
- [ ] 서비스 접속 확인 (Trino, MinIO, Grafana)
- [ ] 첫 번째 쿼리 실행
- [ ] 문서 읽기 (README_KR.md, GETTING_STARTED_KR.md)

### 프로덕션 배포 체크리스트

- [ ] 프로덕션 설정 검토 (`env/prod/`)
- [ ] 보안 설정 (TLS, OAuth2, RBAC)
- [ ] 리소스 크기 확인
- [ ] 백업 전략 수립
- [ ] 모니터링 및 알림 설정
- [ ] 재해 복구 계획 수립
- [ ] 배포 실행
- [ ] E2E 테스트 실행
- [ ] 운영 문서 검토 (runbook.md)

### 개발 체크리스트

- [ ] 계약서(contracts) 확인
- [ ] 샘플 코드 참조
- [ ] 완료 기준(DoD) 확인
- [ ] 테스트 코드 작성
- [ ] 문서 업데이트

---

## 🆘 도움이 필요하신가요?

### 문서를 찾을 수 없나요?

1. 이 인덱스 파일에서 Ctrl+F로 검색
2. [GETTING_STARTED_KR.md의 FAQ](GETTING_STARTED_KR.md#10-faq) 확인
3. [runbook.md의 Troubleshooting](runbook.md#troubleshooting) 확인

### 여전히 해결되지 않나요?

- **GitHub Issues**: 버그 리포트 또는 기능 요청
- **GitHub Discussions**: 질문 및 토론
- **이메일**: lakehouse@example.com

---

## 📝 문서 기여

문서 개선에 기여하고 싶으시다면:

1. 오타나 오류를 발견하면 GitHub Issue 생성
2. 새로운 예제나 가이드 추가 시 Pull Request
3. 번역 개선 제안

---

## 🔄 문서 업데이트 이력

| 날짜 | 변경 내용 | 작성자 |
|------|----------|--------|
| 2025-12-28 | 초기 문서 세트 작성 | Lakehouse Team |
| 2025-12-28 | 한글 문서 추가 (README_KR, GETTING_STARTED_KR, ARCHITECTURE_KR) | Lakehouse Team |

---

**Happy Documentation Reading! 📚**

[⬆ 맨 위로](#lakehouse-플랫폼-문서-인덱스)
