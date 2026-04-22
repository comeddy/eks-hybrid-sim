# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

EKS Hybrid Simulator Platform - OEM별 차량 시뮬레이터 환경을 EKS 클러스터에 자동 프로비저닝하는 Terraform + Helm 기반 플랫폼. `terraform.tfvars`에 OEM/User 블록을 추가하고 `terraform apply`하면 ACM 인증서, Route 53 DNS, Kubernetes namespace, Helm 릴리스가 자동 생성됨.

## Commands

```bash
# 작업 디렉토리 (환경별 wrapper)
cd envs/dev

# 초기화
terraform init

# 변경사항 미리보기
terraform plan

# 배포 (1차: ACM + Helm, 2차: Route53 Alias 추가 후 재실행)
terraform apply

# 전체 리소스 삭제
terraform destroy

# 특정 모듈만 재배포
terraform apply -replace='module.simulator_platform.module.helm_release["hyundai/user-a"].helm_release.simulator'

# Helm 릴리스 상태 확인
helm list -A

# Pod 상태 확인
kubectl get pods -A -l simulator-platform/oem

# Helm 차트 로컬 렌더링 테스트
helm template test ./eks-simulator-helm --set userId=test,oemId=test,imageRegistry=test
```

## Architecture

### Two-Phase Apply Pattern

배포는 2단계로 진행됨:
1. **1차 apply**: ACM 와일드카드 인증서 + Helm 릴리스 배포 (ALB가 자동 프로비저닝됨)
2. **2차 apply**: `alb_dns_overrides`에 ALB DNS를 입력한 후 Route53 와일드카드 Alias 레코드 생성

ALB DNS는 Ingress 생성 후에만 알 수 있으므로 이 분리가 필요함.

### Module Orchestration (main.tf)

```
module.acm[oem_id]          → OEM별 ACM 와일드카드 인증서 (*.hyundai.example.com)
module.route53[oem_id]      → OEM별 Route53 와일드카드 Alias → ALB
module.helm_release[oem/user] → User별 namespace + Helm release
```

의존성: `helm_release` → `acm` (cert ARN 참조), `route53` → `acm`

### Key Data Transform (locals.tf)

`oem_user_flat`: nested `oem_users` map을 `"oem_id/user_id"` 키의 flat map으로 변환하여 `for_each`에서 사용. 모든 user-level 속성(image tag, replicas 등)이 이 flat map에 포함됨.

### Helm Chart (eks-simulator-helm/)

각 User namespace에 배포되는 6개 컴포넌트:
- **nginx-proxy**: 진입점, Ingress backend
- **simulator-server**: 시뮬레이션 엔진 (유일하게 replicas 조절 가능)
- **simulator-can**: CAN 통신 시뮬레이터
- **simulator-vehicle**: 차량 모델 시뮬레이터
- **target-android**: Android 타겟 디바이스
- **target-cluster**: 클러스터 타겟

같은 OEM의 모든 User Ingress는 `alb.ingress.kubernetes.io/group.name: ajt-{oemId}`로 하나의 ALB를 공유함.

### Environment Wrapper Pattern (envs/dev/)

`envs/dev/backend.tf`는 루트 모듈(`../../`)을 참조하는 thin wrapper. 모든 변수를 pass-through하며, `terraform.tfvars`는 이 디렉토리에 위치. `terraform.tfvars`는 `.gitignore`에 포함되므로 `.tfvars.example`을 복사하여 사용.

## Key Conventions

- **Namespace 명명**: `sim-{oem_id}-{user_id}` (예: `sim-hyundai-user-a`)
- **FQDN 패턴**: `{user_id}.{oem_id}.{base_domain}` (예: `user-a.hyundai.example.com`)
- **Helm release 이름**: `{oem_id}-{user_id}`
- **Label selector**: `simulator-platform/oem`, `simulator-platform/user`
- **이미지 경로**: `{ecr_registry}/{component}:{tag}`
- **ALB group**: `ajt-{oemId}` (OEM별 ALB 공유)

## Terraform Provider Versions

- Terraform >= 1.5.0
- AWS provider >= 5.40
- Helm provider >= 2.12 (v3 형식: `set = [{ name, value }]` 리스트 문법 사용)
- Kubernetes provider >= 2.27

## Hybrid Node

`hybrid_node_enabled = true` 시 모든 Pod에 `nodeSelector: eks.amazonaws.com/compute-type: hybrid`와 toleration이 적용됨. Hybrid Node가 클러스터에 등록되어 있지 않으면 Pod가 Pending 상태가 됨.

## ACM Certificate Validation

`aws_acm_certificate_validation` 리소스는 현재 주석 처리됨. 도메인 NS 위임이 완료되지 않으면 Terraform이 무한 대기하므로, DNS 검증 레코드만 자동 생성하고 실제 검증 완료는 외부에서 확인해야 함.

## Operational Runbooks

- `docs/runbooks/full-deployment.md` - 신규 환경 전체 배포 절차
- `docs/runbooks/add-oem-user.md` - OEM/User 추가 변경 관리
- `docs/runbooks/troubleshooting.md` - Pod, Ingress, ACM, Terraform 오류 진단
- `docs/runbooks/teardown.md` - 리소스 정리/삭제 (순서 보장)

## Auto-Sync Rules

다음 이벤트 발생 시 문서를 자동으로 업데이트해야 합니다:

1. **Terraform 모듈 변경 시**: `modules/` 하위 `.tf` 파일 수정 → `docs/architecture.md`의 해당 모듈 섹션 업데이트
2. **Helm Chart 변경 시**: `eks-simulator-helm/` 하위 파일 수정 → `docs/architecture.md`의 컴포넌트 섹션 업데이트
3. **변수 추가/변경 시**: `variables.tf` 또는 `values.yaml` 변경 → `README.md`의 설정 옵션 테이블 동기화
4. **Runbook 추가 시**: `docs/runbooks/` 에 새 파일 → `CLAUDE.md`의 Operational Runbooks 섹션에 링크 추가
5. **Plan 모드 종료 시**: 아키텍처 결정이 변경되었으면 `docs/decisions/`에 ADR 작성 검토

### 문서 품질 기준

- 모든 Terraform output은 `docs/architecture.md`에 문서화
- 새로운 모듈은 자체 `CLAUDE.md` 포함 필수
- Helm values 변경은 `README.md` 설정 테이블과 동기화
