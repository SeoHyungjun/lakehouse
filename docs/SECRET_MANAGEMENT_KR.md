# 비밀 관리 가이드 (Secret Management)

## 개요

이 프로젝트는 **Sealed Secrets**를 사용하여 GitOps 방식으로 비밀(Secret)을 안전하게 관리합니다.
모든 런타임 비밀은 암호화된 `SealedSecret` 매니페스트 형태로 Git에 저장되며, 평문 비밀은 절대 Git에 저장되지 않습니다.

## 주요 원칙

1.  **단일 진실 공급원 (SSOT)**: 비밀 값의 원본은 로컬의 `.env` 파일입니다. (Git 저장 안 됨)
2.  **저장 시 암호화**: Git에는 암호화된 `SealedSecret` 파일만 커밋됩니다.
3.  **GitOps 기반**: ArgoCD가 `SealedSecret`을 배포하면, 컨트롤러가 이를 복호화하여 Kubernetes Secret으로 변환합니다.
4.  **재현 가능성 (Reproducibility)**: 스크립트를 통해 일관된 방식으로 비밀을 생성합니다.
5.  **이식성 (Portability)**: 마스터 키(Master Key)를 백업/복구하여 어떤 환경에서도 동일한 암호화 파일을 사용할 수 있습니다.

## 작업 흐름 (Workflow)

### 1. 초기 설정 (Setup)

**환경 변수 설정:**
예제 파일을 복사하여 실제 비밀 값을 설정합니다.
```bash
cp .env.example .env
vi .env # 실제 값 입력
```

**마스터 키 복구 (Master Key Restore):**
기존 환경을 복제하는 경우, **마스터 키 파일(`master.key`)**을 관리자로부터 전달받아야 합니다.
전달받은 키를 해당 환경 디렉토리에 위치시킵니다.
```bash
# 개발(dev) 환경 예시
cp master.key env/dev/master.key
```
> **주의**: `master.key` 파일은 절대 Git에 커밋하지 마세요. (이미 `.gitignore`에 등록됨)
> 이 키가 있어야 Git에 있는 기존 `SealedSecret` 파일들을 해독할 수 있습니다.

### 2. 인프라 배포

`bootstrap.sh` 또는 Terraform을 통해 클러스터와 Sealed Secrets Controller를 설치합니다.
이때 `env/dev/master.key` 파일이 존재하면 자동으로 해당 키가 적용됩니다.

### 3. 비밀 생성 (Generate Secrets)

`.env` 파일의 내용을 바탕으로 암호화된 매니페스트를 생성합니다.
```bash
./scripts/generate-secrets.sh
```
이 스크립트는:
1. `.env` 파일 읽기
2. 클러스터의 컨트롤러와 통신하여 암호화 키 획득
3. `platform/<component>/templates/` 경로에 `*sealed-secret.yaml` 파일 생성

### 4. 커밋 및 푸시 (Commit & Push)

생성된 `SealedSecret` 파일들을 Git에 올립니다.
```bash
git add platform/*/templates/*sealed-secret.yaml
git commit -m "chore: update sealed secrets"
git push
```

### 5. 배포 확인

ArgoCD가 변경사항을 감지하고 `SealedSecret`을 클러스터에 배포합니다.
컨트롤러가 이를 복호화하여 일반 `Secret`을 생성하고, 애플리케이션이 이를 사용하여 구동됩니다.

## 관리자 가이드: 마스터 키 백업 (Backup)

최초로 환경을 구축한 관리자는 생성된 마스터 키를 백업하여 팀원들과 공유해야 합니다.

```bash
./scripts/backup-master-key.sh [dev|prod]
```
생성된 `env/<env>/master.key` 파일을 안전한 채널(1Password 등)로 공유하세요.

## 디렉토리 구조

*   `.env`: 로컬 비밀 값 저장소 (Gitignored)
*   `.env.example`: 비밀 값 템플릿
*   `scripts/generate-secrets.sh`: 비밀 생성 자동화 스크립트
*   `scripts/backup-master-key.sh`: 마스터 키 백업 스크립트
*   `env/<env>/master.key`: 백업된 마스터 키 (Gitignored)
*   `platform/**/templates/*sealed-secret.yaml`: 암호화된 매니페스트 (Committed)
