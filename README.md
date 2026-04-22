# EKS Hybrid Simulator Platform

OEM별 차량 시뮬레이터 환경을 EKS 클러스터에 자동 프로비저닝하는 Terraform + Helm 기반 플랫폼입니다.

`terraform.tfvars`에 OEM/User 블록을 추가하고 `terraform apply`만 실행하면 ACM 와일드카드 인증서, Route 53 DNS 레코드, Kubernetes namespace, Helm 릴리스가 자동으로 생성됩니다.

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
 ├─ module.helm_release["hyundai/user-c"]  → namespace: sim-hyundai-user-c
 └─ module.helm_release["kia/user-a"]      → namespace: sim-kia-user-a
```

각 User namespace에는 다음 5개 컴포넌트가 배포됩니다:

| 컴포넌트 | 설명 |
|----------|------|
| simulator-server | 시뮬레이션 엔진 (메인 서버) |
| simulator-can | CAN 통신 시뮬레이터 |
| simulator-vehicle | 차량 모델 시뮬레이터 |
| target-android | Android 타겟 디바이스 |
| target-cluster | 클러스터 타겟 |

## 디렉토리 구조

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
├── eks-simulator-helm/      # Helm Chart (5개 컴포넌트 + Ingress + PDB)
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
    └── runbooks/
        ├── full-deployment.md   # 전체 배포 절차
        ├── add-oem-user.md      # OEM/User 추가
        ├── troubleshooting.md   # 장애 진단/해결
        └── teardown.md          # 리소스 정리/삭제
```

## 사전 요구사항

- Terraform >= 1.5
- kubectl, Helm >= 3.12
- AWS CLI v2 (인증 완료)
- EKS 클러스터 (ACTIVE) + AWS Load Balancer Controller
- Route 53 Hosted Zone (`example.com`)
- ECR에 컨테이너 이미지 Push 완료

## 빠른 시작

### 1단계 — 환경 변수 설정

```bash
cd envs/dev
vi terraform.tfvars
```

필수 변경:

```hcl
eks_cluster_name = "<실제 클러스터 이름>"
ecr_registry     = "<ACCOUNT_ID>.dkr.ecr.ap-northeast-2.amazonaws.com"
```

### 2단계 — ACM 인증서 + Helm 배포

```bash
terraform init
terraform plan
terraform apply
```

### 3단계 — ALB DNS 확인 후 Route 53 연결

```bash
# OEM별 ALB DNS 확인
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

## OEM / User 관리

### OEM 추가

`terraform.tfvars`의 `oem_users`에 블록 추가 → `terraform apply`:

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

해당 OEM의 `users` 블록에서 추가/제거 → `terraform apply`:

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

## Hybrid Node 지원

온프레미스/엣지 노드에서 시뮬레이터를 실행하려면:

```hcl
hybrid_node_enabled = true
```

활성화 시 모든 Pod에 `nodeSelector: eks.amazonaws.com/compute-type: hybrid`와 해당 toleration이 적용됩니다.

## 리소스 정리

```bash
cd envs/dev
terraform destroy
```

전체 삭제 절차(노드 그룹, 클러스터, IAM 포함)는 [teardown runbook](docs/runbooks/teardown.md)을 참고하세요.

## 운영 문서

| 문서 | 설명 |
|------|------|
| [GUIDE.md](GUIDE.md) | 고객 전달용 통합 배포/운영 가이드 |
| [full-deployment.md](docs/runbooks/full-deployment.md) | 신규 환경 전체 배포 절차 |
| [add-oem-user.md](docs/runbooks/add-oem-user.md) | OEM/User 추가 변경 관리 |
| [troubleshooting.md](docs/runbooks/troubleshooting.md) | Pod, Ingress, ACM, Terraform 오류 진단 |
| [teardown.md](docs/runbooks/teardown.md) | 리소스 정리/삭제 (순서 보장) |
