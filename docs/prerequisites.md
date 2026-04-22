# Prerequisites: 공통 컨트롤러 설치 가이드

> Platform Team이 EKS 클러스터에 **1회** 실행하는 Terraform 코드.
> `platform/` 디렉토리에서 `terraform apply`하면 3개 컨트롤러가 모두 설치됩니다.
> OEM사는 이 컨트롤러가 설치된 클러스터에 자기 사용자만 배포합니다.

## 아키텍처 개요

```
EKS Cluster (Platform Team 관리)
│
│  terraform apply (platform/)  ← 1회 실행
│  ┌─────────────────────────────────────────────────────────┐
│  │ EKS Pod Identity Agent (애드온)                         │
│  │ aws-load-balancer-controller  (Pod Identity + Helm)    │
│  │ external-dns                  (Pod Identity + Helm)    │
│  │ external-secrets-operator     (Pod Identity + Helm)    │
│  └─────────────────────────────────────────────────────────┘
│
│  terraform apply (envs/dev/)   ← OEM사별 실행
│  ┌─────────────────────────────────────────────────────────┐
│  │ sim-hyundai-user-a/  (namespace + Helm release)        │
│  │ sim-hyundai-user-b/                                     │
│  │ sim-kia-user-x/                                         │
│  └─────────────────────────────────────────────────────────┘
```

---

## 사전 요건

### EKS Pod Identity Agent 애드온

Pod Identity는 이 애드온이 클러스터에 설치되어 있어야 합니다.

```bash
aws eks create-addon \
  --cluster-name <CLUSTER_NAME> \
  --addon-name eks-pod-identity-agent

# 확인
aws eks describe-addon \
  --cluster-name <CLUSTER_NAME> \
  --addon-name eks-pod-identity-agent \
  --query 'addon.status'
```

---

## Terraform으로 설치

```bash
cd platform/
cp terraform.tfvars.example terraform.tfvars
# terraform.tfvars 편집: eks_cluster_name, vpc_id, base_domain

terraform init
terraform plan
terraform apply
```

이 한 번의 apply로 아래 3개 컨트롤러가 모두 설치됩니다:

### 1. AWS Load Balancer Controller

| 항목 | 값 |
|------|---|
| Namespace | `kube-system` |
| ServiceAccount | `aws-load-balancer-controller` |
| IAM Role | `{cluster}-alb-controller` |
| IAM 인증 | **Pod Identity** |
| Terraform 파일 | `platform/alb-controller.tf` |

Ingress 리소스를 감시하여 ALB를 자동 생성/관리합니다.

### 2. External-DNS

| 항목 | 값 |
|------|---|
| Namespace | `kube-system` |
| ServiceAccount | `external-dns` |
| IAM Role | `{cluster}-external-dns` |
| IAM 인증 | **Pod Identity** |
| Policy | `sync` (생성/삭제 모두) |
| Terraform 파일 | `platform/external-dns.tf` |

Ingress의 `external-dns.alpha.kubernetes.io/hostname` annotation을 감시하여 Route53 레코드를 자동 생성/삭제합니다. `txtOwnerId`로 소유권을 표시하여 자기가 만든 레코드만 관리합니다.

### 3. External Secrets Operator

| 항목 | 값 |
|------|---|
| Namespace | `external-secrets` |
| ServiceAccount | `external-secrets` |
| IAM Role | `{cluster}-external-secrets` |
| IAM 인증 | **Pod Identity** |
| 접근 범위 | `sim-platform/*` (Secrets Manager + SSM) |
| Terraform 파일 | `platform/external-secrets.tf` |

AWS Secrets Manager / SSM Parameter Store의 시크릿을 Kubernetes Secret으로 자동 동기화합니다.

---

## Pod Identity 동작 원리

```
Pod (SA: external-secrets) 
  → EKS Pod Identity Agent가 자격증명 자동 주입
  → STS AssumeRole (trust: pods.eks.amazonaws.com)
  → IAM Role의 Policy로 Secrets Manager 접근
```

IRSA와 달리 OIDC Provider URL을 trust policy에 넣을 필요 없이,
`aws_eks_pod_identity_association`으로 namespace/SA ↔ IAM Role 매핑만 하면 됩니다.

각 컨트롤러의 Pod Identity 설정 (`modules/pod-identity/main.tf`):

```hcl
# Trust Policy: EKS Pod Identity 서비스만 assume 허용
data "aws_iam_policy_document" "trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole", "sts:TagSession"]
    principals {
      type        = "Service"
      identifiers = ["pods.eks.amazonaws.com"]
    }
  }
}

# Association: 이 클러스터의 이 namespace/SA → 이 IAM Role
resource "aws_eks_pod_identity_association" "this" {
  cluster_name    = var.cluster_name
  namespace       = var.namespace
  service_account = var.service_account_name
  role_arn        = aws_iam_role.this.arn
}
```

---

## OEM별 Route53 Hosted Zone 구조

```
example.com (루트 Hosted Zone)
├── hyundai.example.com NS → Hosted Zone: Z1234 (OEM 전용)
│     ├── user-a.hyundai.example.com A → ALB  (external-dns 자동)
│     ├── user-b.hyundai.example.com A → ALB  (external-dns 자동)
│     └── ...
├── kia.example.com NS → Hosted Zone: Z5678 (OEM 전용)
│     └── user-x.kia.example.com A → ALB
└── ...
```

---

## 설치 확인

```bash
# 컨트롤러 상태
kubectl get deployment -n kube-system aws-load-balancer-controller
kubectl get deployment -n kube-system external-dns
kubectl get deployment -n external-secrets external-secrets

# Pod Identity Association 확인
aws eks list-pod-identity-associations --cluster-name <CLUSTER_NAME>

# 로그
kubectl logs -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller --tail=10
kubectl logs -n kube-system -l app.kubernetes.io/name=external-dns --tail=10
kubectl logs -n external-secrets -l app.kubernetes.io/name=external-secrets --tail=10
```

---

## 설치 순서 체크리스트

```
1. [ ] EKS Pod Identity Agent 애드온 설치
2. [ ] terraform apply (platform/)  → 3개 컨트롤러 일괄 설치
3. [ ] OEM별 Route53 Hosted Zone 생성 + NS 위임
4. [ ] OEM별 ACM 와일드카드 인증서 발급 (*.hyundai.example.com)
5. [ ] OEM사에게 Terraform 배포 가이드 전달
```

---

## OEM사 배포 시 필요한 정보

| 항목 | 예시 | 누가 제공 |
|------|------|----------|
| EKS Cluster Name | `sim-cluster-prod` | Platform Team |
| ECR Registry | `123456789012.dkr.ecr.ap-northeast-2.amazonaws.com` | Platform Team |
| Base Domain | `sim.example.com` | Platform Team |
| ACM Cert ARN | `arn:aws:acm:...:certificate/xxx` | Platform Team (OEM별) |
| OEM ID | `hyundai` | OEM사 |
| User ID 목록 | `user-a`, `user-b`, ... | OEM사 |
