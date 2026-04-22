# EKS Hybrid Simulator Platform

[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Terraform](https://img.shields.io/badge/Terraform-%3E%3D1.5-purple.svg)](https://www.terraform.io/)
[![Helm](https://img.shields.io/badge/Helm-%3E%3D3.12-blue.svg)](https://helm.sh/)
[![English](https://img.shields.io/badge/lang-English-blue)](#english) [![Korean](https://img.shields.io/badge/lang-한국어-green)](#한국어)

Automated per-OEM, per-user vehicle simulator provisioning on Amazon EKS using Terraform + Helm.

OEM별 차량 시뮬레이터 환경을 EKS 클러스터에 자동 프로비저닝하는 Terraform + Helm 기반 플랫폼입니다.

---

# English

## Overview

EKS Hybrid Simulator Platform provisions isolated vehicle simulator environments for each OEM and user on Amazon EKS. Add an OEM/User block to `terraform.tfvars` and run `terraform apply` to automatically create ACM wildcard certificates, Route 53 DNS records, Kubernetes namespaces, and Helm releases.

## Architecture

```
terraform apply
 │
 ├─ module.acm["hyundai"]              → *.hyundai.example.com  ACM certificate + DNS validation
 ├─ module.acm["kia"]                  → *.kia.example.com      ACM certificate + DNS validation
 │
 ├─ module.route53["hyundai"]          → *.hyundai.example.com  A (Alias) → ALB
 ├─ module.route53["kia"]              → *.kia.example.com      A (Alias) → ALB
 │
 ├─ module.helm_release["hyundai/user-a"]  → namespace: sim-hyundai-user-a
 ├─ module.helm_release["hyundai/user-b"]  → namespace: sim-hyundai-user-b
 └─ module.helm_release["kia/user-a"]      → namespace: sim-kia-user-a
```

Each user namespace deploys 6 components:

| Component | Description |
|-----------|-------------|
| nginx-proxy | Reverse proxy, Ingress backend |
| simulator-server | Main simulation engine |
| simulator-can | CAN bus communication simulator |
| simulator-vehicle | Vehicle model simulator |
| target-android | Android target device |
| target-cluster | Cluster target |

## Prerequisites

- Terraform >= 1.5
- kubectl, Helm >= 3.12
- AWS CLI v2 (authenticated)
- EKS cluster (ACTIVE) + AWS Load Balancer Controller
- Route 53 Hosted Zone
- Container images pushed to ECR

## Installation

### Step 1 -- Configure environment variables

```bash
cd envs/dev
cp terraform.tfvars.example terraform.tfvars
vi terraform.tfvars
```

Required values:

```hcl
eks_cluster_name = "<cluster-name>"
ecr_registry     = "<ACCOUNT_ID>.dkr.ecr.ap-northeast-2.amazonaws.com"
```

### Step 2 -- Deploy ACM certificates + Helm releases

```bash
terraform init
terraform plan
terraform apply
```

### Step 3 -- Connect Route 53 after ALB provisioning

```bash
kubectl get ingress -A -l simulator-platform/oem=hyundai \
  -o jsonpath='{.items[0].status.loadBalancer.ingress[0].hostname}'
```

Add ALB DNS to `terraform.tfvars` and re-apply:

```hcl
alb_dns_overrides = {
  hyundai = "<hyundai ALB DNS>"
  kia     = "<kia ALB DNS>"
}
```

```bash
terraform apply
```

### Verification

```bash
terraform output user_endpoints
kubectl get pods -A -l simulator-platform/oem
curl -k https://user-a.hyundai.example.com/health
```

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
│   └── helm-release/        # Per-user namespace + Helm release
│
├── eks-simulator-helm/      # Helm Chart (6 components + Ingress + PDB)
│   ├── Chart.yaml
│   ├── values.yaml
│   ├── templates/
│   └── examples/            # Per-environment values override examples
│
├── envs/
│   └── dev/
│       ├── backend.tf       # Root module wrapper
│       └── terraform.tfvars # DEV environment variables
│
└── docs/
    ├── architecture.md      # Architecture documentation
    ├── onboarding.md        # Onboarding guide
    ├── decisions/           # Architecture Decision Records
    └── runbooks/
        ├── full-deployment.md
        ├── add-oem-user.md
        ├── troubleshooting.md
        └── teardown.md
```

## Usage

### Add an OEM

Add a block to `oem_users` in `terraform.tfvars`:

```hcl
oem_users = {
  hyundai = { ... }   # existing
  toyota = {           # new
    users = {
      user-a = {}
      user-b = { simulator_server_tag = "v3.0.0" }
    }
  }
}
```

### Add/Remove a user

Add or remove entries in the OEM's `users` block:

```hcl
hyundai = {
  users = {
    user-a = { ... }
    user-d = { simulator_server_replicas = 2 }   # add
    # user-c removed → auto-destroyed on apply
  }
}
```

### User configuration options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `simulator_can_tag` | string | `"latest"` | CAN simulator image tag |
| `simulator_server_tag` | string | `"latest"` | Server image tag |
| `simulator_vehicle_tag` | string | `"latest"` | Vehicle model image tag |
| `target_android_tag` | string | `"latest"` | Android target image tag |
| `target_cluster_tag` | string | `"latest"` | Cluster target image tag |
| `simulator_server_replicas` | number | `1` | Server pod replica count |

### Hybrid Node support

Run simulators on on-premises/edge nodes:

```hcl
hybrid_node_enabled = true
```

Applies `nodeSelector: eks.amazonaws.com/compute-type: hybrid` and matching toleration to all pods.

## Testing

```bash
# Format check
terraform fmt -check -recursive .

# Validate
cd envs/dev && terraform validate

# Helm lint
helm lint ./eks-simulator-helm

# Helm render test
helm template test ./eks-simulator-helm --set userId=test,oemId=test,imageRegistry=test
```

## Teardown

```bash
cd envs/dev
terraform destroy
```

See [teardown runbook](docs/runbooks/teardown.md) for full cleanup including node groups, cluster, and IAM.

## Documentation

| Document | Description |
|----------|-------------|
| [GUIDE.md](GUIDE.md) | Customer delivery guide |
| [Architecture](docs/architecture.md) | Architecture documentation |
| [Onboarding](docs/onboarding.md) | New developer onboarding |
| [Full Deployment](docs/runbooks/full-deployment.md) | Complete deployment procedure |
| [Add OEM/User](docs/runbooks/add-oem-user.md) | OEM/User change management |
| [Troubleshooting](docs/runbooks/troubleshooting.md) | Pod, Ingress, ACM, Terraform diagnostics |
| [Teardown](docs/runbooks/teardown.md) | Resource cleanup/deletion |

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/my-feature`)
3. Commit changes (`git commit -m "Add my feature"`)
4. Push to the branch (`git push origin feature/my-feature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License. See [LICENSE](LICENSE) for details.

## Contact

- Maintainer: comeddy
- GitHub: [comeddy/eks-hybrid-sim](https://github.com/comeddy/eks-hybrid-sim)

---

# 한국어

## 개요

EKS Hybrid Simulator Platform은 OEM별/사용자별 격리된 차량 시뮬레이터 환경을 Amazon EKS에 프로비저닝합니다. `terraform.tfvars`에 OEM/User 블록을 추가하고 `terraform apply`만 실행하면 ACM 와일드카드 인증서, Route 53 DNS 레코드, Kubernetes namespace, Helm 릴리스가 자동으로 생성됩니다.

## 아키텍처

```
terraform apply
 │
 ├─ module.acm["hyundai"]              → *.hyundai.example.com  ACM 인증서 + DNS 검증
 ├─ module.acm["kia"]                  → *.kia.example.com      ACM 인증서 + DNS 검증
 │
 ├─ module.route53["hyundai"]          → *.hyundai.example.com  A (Alias) → ALB
 ├─ module.route53["kia"]              → *.kia.example.com      A (Alias) → ALB
 │
 ├─ module.helm_release["hyundai/user-a"]  → namespace: sim-hyundai-user-a
 ├─ module.helm_release["hyundai/user-b"]  → namespace: sim-hyundai-user-b
 └─ module.helm_release["kia/user-a"]      → namespace: sim-kia-user-a
```

각 User namespace에는 6개 컴포넌트가 배포됩니다:

| 컴포넌트 | 설명 |
|----------|------|
| nginx-proxy | 리버스 프록시, Ingress 백엔드 |
| simulator-server | 시뮬레이션 엔진 (메인 서버) |
| simulator-can | CAN 통신 시뮬레이터 |
| simulator-vehicle | 차량 모델 시뮬레이터 |
| target-android | Android 타겟 디바이스 |
| target-cluster | 클러스터 타겟 |

## 사전 요구사항

- Terraform >= 1.5
- kubectl, Helm >= 3.12
- AWS CLI v2 (인증 완료)
- EKS 클러스터 (ACTIVE) + AWS Load Balancer Controller
- Route 53 Hosted Zone
- ECR에 컨테이너 이미지 Push 완료

## 설치

### 1단계 -- 환경 변수 설정

```bash
cd envs/dev
cp terraform.tfvars.example terraform.tfvars
vi terraform.tfvars
```

필수 변경:

```hcl
eks_cluster_name = "<실제 클러스터 이름>"
ecr_registry     = "<ACCOUNT_ID>.dkr.ecr.ap-northeast-2.amazonaws.com"
```

### 2단계 -- ACM 인증서 + Helm 배포

```bash
terraform init
terraform plan
terraform apply
```

### 3단계 -- ALB DNS 확인 후 Route 53 연결

```bash
kubectl get ingress -A -l simulator-platform/oem=hyundai \
  -o jsonpath='{.items[0].status.loadBalancer.ingress[0].hostname}'
```

`terraform.tfvars`에 ALB DNS를 추가 후 재적용:

```hcl
alb_dns_overrides = {
  hyundai = "<hyundai ALB DNS>"
  kia     = "<kia ALB DNS>"
}
```

```bash
terraform apply
```

### 검증

```bash
terraform output user_endpoints
kubectl get pods -A -l simulator-platform/oem
curl -k https://user-a.hyundai.example.com/health
```

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
│   └── helm-release/        # User별 namespace + Helm 릴리스 배포
│
├── eks-simulator-helm/      # Helm Chart (6개 컴포넌트 + Ingress + PDB)
│   ├── Chart.yaml
│   ├── values.yaml
│   ├── templates/
│   └── examples/            # 환경별 values 오버라이드 예시
│
├── envs/
│   └── dev/
│       ├── backend.tf       # Root module wrapper
│       └── terraform.tfvars # DEV 환경 변수
│
└── docs/
    ├── architecture.md      # 아키텍처 문서
    ├── onboarding.md        # 온보딩 가이드
    ├── decisions/           # 아키텍처 결정 기록
    └── runbooks/
        ├── full-deployment.md
        ├── add-oem-user.md
        ├── troubleshooting.md
        └── teardown.md
```

## 사용법

### OEM 추가

`terraform.tfvars`의 `oem_users`에 블록 추가:

```hcl
oem_users = {
  hyundai = { ... }   # 기존
  toyota = {           # 신규
    users = {
      user-a = {}
      user-b = { simulator_server_tag = "v3.0.0" }
    }
  }
}
```

### User 추가/삭제

해당 OEM의 `users` 블록에서 추가/제거:

```hcl
hyundai = {
  users = {
    user-a = { ... }
    user-d = { simulator_server_replicas = 2 }   # 추가
    # user-c 삭제 → apply 시 자동 제거
  }
}
```

### User 설정 옵션

| 옵션 | 타입 | 기본값 | 설명 |
|------|------|--------|------|
| `simulator_can_tag` | string | `"latest"` | CAN 시뮬레이터 이미지 태그 |
| `simulator_server_tag` | string | `"latest"` | 서버 이미지 태그 |
| `simulator_vehicle_tag` | string | `"latest"` | 차량 모델 이미지 태그 |
| `target_android_tag` | string | `"latest"` | Android 타겟 이미지 태그 |
| `target_cluster_tag` | string | `"latest"` | 클러스터 타겟 이미지 태그 |
| `simulator_server_replicas` | number | `1` | Server Pod 레플리카 수 |

### Hybrid Node 지원

온프레미스/엣지 노드에서 시뮬레이터 실행:

```hcl
hybrid_node_enabled = true
```

모든 Pod에 `nodeSelector: eks.amazonaws.com/compute-type: hybrid`와 해당 toleration이 적용됩니다.

## 테스트

```bash
# 포맷 검사
terraform fmt -check -recursive .

# 유효성 검사
cd envs/dev && terraform validate

# Helm 차트 Lint
helm lint ./eks-simulator-helm

# Helm 렌더링 테스트
helm template test ./eks-simulator-helm --set userId=test,oemId=test,imageRegistry=test
```

## 리소스 정리

```bash
cd envs/dev
terraform destroy
```

전체 삭제 절차(노드 그룹, 클러스터, IAM 포함)는 [teardown runbook](docs/runbooks/teardown.md)을 참고하십시오.

## 운영 문서

| 문서 | 설명 |
|------|------|
| [GUIDE.md](GUIDE.md) | 고객 전달용 통합 배포/운영 가이드 |
| [아키텍처](docs/architecture.md) | 아키텍처 문서 |
| [온보딩](docs/onboarding.md) | 신규 개발자 온보딩 |
| [전체 배포](docs/runbooks/full-deployment.md) | 신규 환경 전체 배포 절차 |
| [OEM/User 추가](docs/runbooks/add-oem-user.md) | OEM/User 추가 변경 관리 |
| [장애 진단](docs/runbooks/troubleshooting.md) | Pod, Ingress, ACM, Terraform 오류 진단 |
| [리소스 정리](docs/runbooks/teardown.md) | 리소스 정리/삭제 (순서 보장) |

## 기여 방법

1. 저장소를 Fork합니다.
2. 기능 브랜치를 생성합니다. (`git checkout -b feature/my-feature`)
3. 변경 사항을 커밋합니다. (`git commit -m "Add my feature"`)
4. 브랜치에 Push합니다. (`git push origin feature/my-feature`)
5. Pull Request를 생성합니다.

## 라이선스

이 프로젝트는 MIT 라이선스 하에 배포됩니다. 자세한 내용은 [LICENSE](LICENSE)를 참고하십시오.

## 연락처

- 관리자: comeddy
- GitHub: [comeddy/eks-hybrid-sim](https://github.com/comeddy/eks-hybrid-sim)
