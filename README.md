# EKS Hybrid Simulator Platform

[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Version](https://img.shields.io/badge/version-0.1.0-brightgreen.svg)](https://github.com/comeddy/eks-hybrid-sim/releases)
[![Terraform](https://img.shields.io/badge/Terraform-%3E%3D1.5-purple.svg)](https://www.terraform.io/)
[![Helm](https://img.shields.io/badge/Helm-%3E%3D3.12-blue.svg)](https://helm.sh/)
[![English](https://img.shields.io/badge/lang-English-blue.svg)](#english)
[![한국어](https://img.shields.io/badge/lang-한국어-green.svg)](#한국어)

Automated per-OEM, per-user vehicle simulator provisioning on Amazon EKS with Terraform and Helm.

OEM별 차량 시뮬레이터 환경을 EKS 클러스터에 자동 프로비저닝하는 Terraform + Helm 기반 플랫폼입니다.

---

# English

## Overview

The EKS Hybrid Simulator Platform automates provisioning of isolated vehicle simulator environments for each OEM and user on Amazon EKS. It eliminates manual Kubernetes resource management by providing a declarative Terraform configuration where adding an OEM/User block to `terraform.tfvars` and running `terraform apply` creates all required infrastructure: ACM certificates, Route 53 DNS records, Kubernetes namespaces, and Helm releases. The platform also supports running simulators on on-premises or edge nodes via EKS Hybrid Nodes.

## Features

- **Declarative OEM/User Management** -- Add an OEM/User block to `terraform.tfvars` and run `terraform apply` to provision the entire stack automatically
- **Automated ACM Certificates** -- Per-OEM wildcard TLS certificates (`*.{oem}.{domain}`) with Route 53 DNS validation
- **OEM-Shared ALB** -- All users under the same OEM share a single Application Load Balancer via Ingress `group.name` annotation, reducing cost and complexity
- **Hybrid Node Support** -- Run simulator pods on on-premises or edge nodes by toggling a single boolean variable
- **Per-User Namespace Isolation** -- Each user gets a dedicated Kubernetes namespace (`sim-{oem}-{user}`) with 6 independent simulator components

## Prerequisites

- Terraform >= 1.5.0
- Helm >= 3.12
- kubectl (latest)
- AWS CLI v2 (authenticated)
- EKS cluster (ACTIVE) with AWS Load Balancer Controller installed
- Route 53 Hosted Zone for the base domain
- Container images pushed to Amazon ECR

## Installation

```bash
# Clone the repository
git clone https://github.com/comeddy/eks-hybrid-sim.git
cd eks-hybrid-sim

# Set up the development environment
cd envs/dev
cp terraform.tfvars.example terraform.tfvars

# Edit configuration (required: eks_cluster_name, ecr_registry)
vi terraform.tfvars

# Initialize Terraform
terraform init

# Preview changes
terraform plan

# Phase 1: Deploy ACM certificates and Helm releases
terraform apply

# Check ALB DNS after Ingress creation
kubectl get ingress -A -l simulator-platform/oem=hyundai \
  -o jsonpath='{.items[0].status.loadBalancer.ingress[0].hostname}'

# Add ALB DNS to terraform.tfvars (alb_dns_overrides block)
vi terraform.tfvars

# Phase 2: Create Route 53 DNS records
terraform apply
```

## Usage

Verify the deployment:

```bash
# View all user endpoints
terraform output user_endpoints
# {
#   "hyundai/user-a" = "https://user-a.hyundai.example.com"
#   "hyundai/user-b" = "https://user-b.hyundai.example.com"
#   "kia/user-a"     = "https://user-a.kia.example.com"
# }

# Check pod status across all namespaces
kubectl get pods -A -l simulator-platform/oem
# NAMESPACE              NAME                                READY   STATUS
# sim-hyundai-user-a     hyundai-user-a-simulator-server-0   1/1     Running
# sim-hyundai-user-a     hyundai-user-a-nginx-proxy-0        1/1     Running
# ...

# Check Helm release status
helm list -A

# Verify a specific user endpoint
curl -k https://user-a.hyundai.example.com/health
```

Add a new OEM with users:

```hcl
# terraform.tfvars
oem_users = {
  hyundai = {
    users = {
      user-a = {}
      user-b = { simulator_server_tag = "v2.0.0" }
    }
  }
  toyota = {  # New OEM
    users = {
      user-a = {}
      user-b = { simulator_server_replicas = 2 }
    }
  }
}
```

```bash
# Apply changes to provision the new OEM
terraform apply
```

Remove a user by deleting the entry from the `users` block and running `terraform apply`. Terraform destroys the associated namespace and all resources automatically.

## Configuration

### Global Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `aws_region` | AWS region | `ap-northeast-2` |
| `base_domain` | Base domain name | `example.com` |
| `route53_zone_id` | Route 53 Hosted Zone ID (auto-detected if omitted) | `""` |
| `eks_cluster_name` | EKS cluster name | Required |
| `ecr_registry` | ECR registry URL | Required |
| `helm_chart_path` | Local Helm chart path | `../eks-simulator-helm` |
| `hybrid_node_enabled` | Enable Hybrid Node scheduling | `true` |
| `alb_dns_overrides` | Per-OEM ALB DNS name overrides (Phase 2) | `null` |
| `alb_zone_id` | ALB Hosted Zone ID | `ZWKZPGTI48KDX` |

### Per-User Variables

Defined inside the `oem_users` map for each user:

| Variable | Description | Default |
|----------|-------------|---------|
| `simulator_can_tag` | CAN simulator image tag | `latest` |
| `simulator_server_tag` | Server image tag | `latest` |
| `simulator_vehicle_tag` | Vehicle model image tag | `latest` |
| `target_android_tag` | Android target image tag | `latest` |
| `target_cluster_tag` | Cluster target image tag | `latest` |
| `simulator_server_replicas` | Server pod replica count | `1` |

## Project Structure

```
eks-hybrid-sim/
├── main.tf                  # Module orchestration (ACM → Route53 → Helm)
├── variables.tf             # Input variable definitions
├── outputs.tf               # Outputs (endpoints, ARNs, namespaces)
├── locals.tf                # oem_users → flat map transform
├── providers.tf             # AWS / Kubernetes / Helm providers
├── versions.tf              # Terraform & provider version constraints
├── GUIDE.md                 # Customer delivery guide
│
├── modules/
│   ├── acm/                 # Per-OEM ACM wildcard certificate + DNS validation
│   ├── route53/             # Per-OEM wildcard DNS A(Alias) → ALB
│   └── helm-release/        # Per-user namespace + Helm release deployment
│
├── eks-simulator-helm/      # Helm chart (6 components + Ingress + PDB)
│   ├── Chart.yaml
│   ├── values.yaml
│   ├── templates/
│   └── examples/            # Per-environment values override examples
│
├── envs/
│   └── dev/
│       ├── backend.tf       # Root module wrapper
│       └── terraform.tfvars # DEV environment variables (gitignored)
│
├── docs/
│   ├── architecture.md      # Architecture documentation (bilingual)
│   ├── onboarding.md        # Developer onboarding guide
│   ├── decisions/           # Architecture Decision Records
│   └── runbooks/            # Operational runbooks
│
├── scripts/
│   ├── setup.sh             # Project setup for new developers
│   └── install-hooks.sh     # Git hooks installer
│
└── tests/                   # Project structure validation tests
    ├── run-all.sh
    ├── hooks/
    ├── structure/
    └── fixtures/
```

## Testing

```bash
# Run all project structure validation tests (81 TAP-format tests)
bash tests/run-all.sh

# Terraform format check
terraform fmt -check -recursive .

# Terraform validation (requires init)
cd envs/dev && terraform validate

# Helm chart lint
helm lint ./eks-simulator-helm

# Helm template render test
helm template test ./eks-simulator-helm \
  --set userId=test,oemId=test,imageRegistry=test

# Run hook tests only
bash tests/hooks/test-hooks.sh

# Run structure tests only
bash tests/structure/test-plugin-structure.sh
```

## Contributing

1. Fork the repository.
2. Create a feature branch:
   ```bash
   git checkout -b feature/my-feature
   ```
3. Commit changes using [Conventional Commits](https://www.conventionalcommits.org/):
   ```bash
   git commit -m "feat: add new simulator component"
   git commit -m "fix: resolve ALB DNS resolution timeout"
   git commit -m "docs: update deployment runbook"
   ```
4. Push to the branch:
   ```bash
   git push origin feature/my-feature
   ```
5. Open a Pull Request against the `main` branch.

## License

This project is licensed under the MIT License. See [LICENSE](LICENSE) for details.

## Contact

- Maintainer: [comeddy](https://github.com/comeddy)
- Issues: [GitHub Issues](https://github.com/comeddy/eks-hybrid-sim/issues)

---

# 한국어

## 개요

EKS Hybrid Simulator Platform은 OEM별/사용자별 격리된 차량 시뮬레이터 환경을 Amazon EKS에 자동 프로비저닝합니다. `terraform.tfvars`에 OEM/User 블록을 추가하고 `terraform apply`를 실행하면 ACM 인증서, Route 53 DNS 레코드, Kubernetes 네임스페이스, Helm 릴리스 등 필요한 모든 인프라가 자동 생성되어 수동 Kubernetes 리소스 관리가 불필요합니다. EKS Hybrid Node를 통해 온프레미스 또는 엣지 노드에서 시뮬레이터를 실행하는 것도 지원합니다.

## 주요 기능

- **선언적 OEM/User 관리** -- `terraform.tfvars`에 OEM/User 블록을 추가하고 `terraform apply`를 실행하면 전체 스택이 자동으로 프로비저닝됩니다
- **ACM 인증서 자동화** -- OEM별 와일드카드 TLS 인증서 (`*.{oem}.{domain}`)와 Route 53 DNS 검증을 자동 처리합니다
- **OEM별 ALB 공유** -- 같은 OEM의 모든 사용자가 Ingress `group.name` 어노테이션을 통해 단일 ALB를 공유하여 비용과 복잡성을 줄입니다
- **Hybrid Node 지원** -- 단일 boolean 변수 토글로 시뮬레이터 Pod를 온프레미스 또는 엣지 노드에서 실행합니다
- **사용자별 네임스페이스 격리** -- 각 사용자에게 전용 Kubernetes 네임스페이스 (`sim-{oem}-{user}`)와 6개의 독립 시뮬레이터 컴포넌트가 할당됩니다

## 사전 요구 사항

- Terraform >= 1.5.0
- Helm >= 3.12
- kubectl (최신 버전)
- AWS CLI v2 (인증 완료)
- EKS 클러스터 (ACTIVE) + AWS Load Balancer Controller 설치 완료
- 기본 도메인의 Route 53 Hosted Zone
- Amazon ECR에 컨테이너 이미지 Push 완료

## 설치 방법

```bash
# 저장소 클론
git clone https://github.com/comeddy/eks-hybrid-sim.git
cd eks-hybrid-sim

# 개발 환경 설정
cd envs/dev
cp terraform.tfvars.example terraform.tfvars

# 설정 편집 (필수: eks_cluster_name, ecr_registry)
vi terraform.tfvars

# Terraform 초기화
terraform init

# 변경사항 미리보기
terraform plan

# 1단계: ACM 인증서 + Helm 릴리스 배포
terraform apply

# Ingress 생성 후 ALB DNS 확인
kubectl get ingress -A -l simulator-platform/oem=hyundai \
  -o jsonpath='{.items[0].status.loadBalancer.ingress[0].hostname}'

# terraform.tfvars에 ALB DNS 추가 (alb_dns_overrides 블록)
vi terraform.tfvars

# 2단계: Route 53 DNS 레코드 생성
terraform apply
```

## 사용법

배포 결과를 확인합니다:

```bash
# 모든 사용자 엔드포인트 조회
terraform output user_endpoints
# {
#   "hyundai/user-a" = "https://user-a.hyundai.example.com"
#   "hyundai/user-b" = "https://user-b.hyundai.example.com"
#   "kia/user-a"     = "https://user-a.kia.example.com"
# }

# 전체 네임스페이스의 Pod 상태 확인
kubectl get pods -A -l simulator-platform/oem
# NAMESPACE              NAME                                READY   STATUS
# sim-hyundai-user-a     hyundai-user-a-simulator-server-0   1/1     Running
# sim-hyundai-user-a     hyundai-user-a-nginx-proxy-0        1/1     Running
# ...

# Helm 릴리스 상태 확인
helm list -A

# 특정 사용자 엔드포인트 검증
curl -k https://user-a.hyundai.example.com/health
```

새 OEM과 사용자를 추가합니다:

```hcl
# terraform.tfvars
oem_users = {
  hyundai = {
    users = {
      user-a = {}
      user-b = { simulator_server_tag = "v2.0.0" }
    }
  }
  toyota = {  # 신규 OEM
    users = {
      user-a = {}
      user-b = { simulator_server_replicas = 2 }
    }
  }
}
```

```bash
# 변경사항 적용하여 신규 OEM 프로비저닝
terraform apply
```

사용자를 제거하려면 `users` 블록에서 해당 항목을 삭제하고 `terraform apply`를 실행합니다. Terraform이 관련 네임스페이스와 모든 리소스를 자동으로 삭제합니다.

## 환경 설정

### 전역 변수

| 변수 | 설명 | 기본값 |
|------|------|--------|
| `aws_region` | AWS 리전 | `ap-northeast-2` |
| `base_domain` | 기본 도메인 이름 | `example.com` |
| `route53_zone_id` | Route 53 Hosted Zone ID (생략 시 자동 조회) | `""` |
| `eks_cluster_name` | EKS 클러스터 이름 | 필수 |
| `ecr_registry` | ECR 레지스트리 URL | 필수 |
| `helm_chart_path` | 로컬 Helm 차트 경로 | `../eks-simulator-helm` |
| `hybrid_node_enabled` | Hybrid Node 스케줄링 활성화 | `true` |
| `alb_dns_overrides` | OEM별 ALB DNS 이름 오버라이드 (2단계) | `null` |
| `alb_zone_id` | ALB Hosted Zone ID | `ZWKZPGTI48KDX` |

### 사용자별 변수

`oem_users` 맵 내 각 사용자에 대해 정의합니다:

| 변수 | 설명 | 기본값 |
|------|------|--------|
| `simulator_can_tag` | CAN 시뮬레이터 이미지 태그 | `latest` |
| `simulator_server_tag` | 서버 이미지 태그 | `latest` |
| `simulator_vehicle_tag` | 차량 모델 이미지 태그 | `latest` |
| `target_android_tag` | Android 타겟 이미지 태그 | `latest` |
| `target_cluster_tag` | 클러스터 타겟 이미지 태그 | `latest` |
| `simulator_server_replicas` | 서버 Pod 레플리카 수 | `1` |

## 프로젝트 구조

```
eks-hybrid-sim/
├── main.tf                  # 모듈 오케스트레이션 (ACM → Route53 → Helm)
├── variables.tf             # 입력 변수 정의
├── outputs.tf               # 출력값 (endpoints, ARNs, namespaces)
├── locals.tf                # oem_users → flat map 변환
├── providers.tf             # AWS / Kubernetes / Helm provider
├── versions.tf              # Terraform & provider 버전 제약
├── GUIDE.md                 # 고객 전달용 통합 가이드
│
├── modules/
│   ├── acm/                 # OEM별 ACM 와일드카드 인증서 + DNS 검증
│   ├── route53/             # OEM별 와일드카드 DNS A(Alias) → ALB
│   └── helm-release/        # 사용자별 네임스페이스 + Helm 릴리스 배포
│
├── eks-simulator-helm/      # Helm 차트 (6개 컴포넌트 + Ingress + PDB)
│   ├── Chart.yaml
│   ├── values.yaml
│   ├── templates/
│   └── examples/            # 환경별 values 오버라이드 예시
│
├── envs/
│   └── dev/
│       ├── backend.tf       # 루트 모듈 래퍼
│       └── terraform.tfvars # DEV 환경 변수 (gitignored)
│
├── docs/
│   ├── architecture.md      # 아키텍처 문서 (이중언어)
│   ├── onboarding.md        # 개발자 온보딩 가이드
│   ├── decisions/           # 아키텍처 결정 기록
│   └── runbooks/            # 운영 Runbook
│
├── scripts/
│   ├── setup.sh             # 신규 개발자용 프로젝트 설정
│   └── install-hooks.sh     # Git 훅 설치 스크립트
│
└── tests/                   # 프로젝트 구조 검증 테스트
    ├── run-all.sh
    ├── hooks/
    ├── structure/
    └── fixtures/
```

## 테스트

```bash
# 전체 프로젝트 구조 검증 테스트 실행 (81개 TAP 형식 테스트)
bash tests/run-all.sh

# Terraform 포맷 검사
terraform fmt -check -recursive .

# Terraform 유효성 검사 (init 필요)
cd envs/dev && terraform validate

# Helm 차트 Lint
helm lint ./eks-simulator-helm

# Helm 템플릿 렌더링 테스트
helm template test ./eks-simulator-helm \
  --set userId=test,oemId=test,imageRegistry=test

# 훅 테스트만 실행
bash tests/hooks/test-hooks.sh

# 구조 테스트만 실행
bash tests/structure/test-plugin-structure.sh
```

## 기여 방법

1. 저장소를 Fork합니다.
2. 기능 브랜치를 생성합니다:
   ```bash
   git checkout -b feature/my-feature
   ```
3. [Conventional Commits](https://www.conventionalcommits.org/) 형식으로 커밋합니다:
   ```bash
   git commit -m "feat: add new simulator component"
   git commit -m "fix: resolve ALB DNS resolution timeout"
   git commit -m "docs: update deployment runbook"
   ```
4. 브랜치에 Push합니다:
   ```bash
   git push origin feature/my-feature
   ```
5. `main` 브랜치를 대상으로 Pull Request를 생성합니다.

## 라이선스

이 프로젝트는 MIT 라이선스 하에 배포됩니다. 자세한 내용은 [LICENSE](LICENSE)를 참고하십시오.

## 연락처

- 관리자: [comeddy](https://github.com/comeddy)
- 이슈: [GitHub Issues](https://github.com/comeddy/eks-hybrid-sim/issues)

<!-- harness-eval-badge:start -->
![Harness Score](https://img.shields.io/badge/harness-6.9%2F10-orange)
![Harness Grade](https://img.shields.io/badge/grade-C-orange)
![Last Eval](https://img.shields.io/badge/eval-2026--04--22-blue)
<!-- harness-eval-badge:end -->
