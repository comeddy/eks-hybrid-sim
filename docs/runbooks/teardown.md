# Runbook: 리소스 정리 / 삭제

## Overview

Simulator Platform의 전체 또는 일부 리소스를 안전하게 삭제하는 절차입니다. Terraform 관리 리소스와 수동 생성 리소스(EKS 클러스터, 노드 그룹 등)를 구분하여 정리합니다.

## When to Use

- 환경(dev/staging)을 완전히 철거할 때
- 특정 OEM 또는 User만 제거할 때
- 비용 절감을 위해 테스트 환경을 정리할 때
- 환경 재구축 전 기존 리소스를 삭제할 때

## Prerequisites

- [ ] Terraform state 접근 가능 (`terraform state list`)
- [ ] kubectl 접근 가능
- [ ] AWS CLI 인증 완료
- [ ] **중요:** 삭제 대상 환경이 맞는지 재확인 (prod 환경 오삭제 주의)

## Procedure

### 1. 특정 User만 제거

가장 영향 범위가 작은 삭제입니다.

**Step 1:** `terraform.tfvars`에서 해당 User 블록을 삭제합니다.

```hcl
hyundai = {
  users = {
    user-a = { ... }
    user-b = { ... }
    # user-c = { ... }   ← 삭제
  }
}
```

**Step 2:** Plan으로 삭제 대상 확인

```bash
cd envs/dev
terraform plan
```

**예상 출력:**

```
Plan: 0 to add, 0 to change, 2 to destroy.
  # module.simulator_platform.module.helm_release["hyundai/user-c"].helm_release.simulator will be destroyed
  # module.simulator_platform.module.helm_release["hyundai/user-c"].kubernetes_namespace_v1.this will be destroyed
```

**Step 3:** Apply

```bash
terraform apply
```

**검증:**

```bash
kubectl get namespaces | grep sim-hyundai-user-c
# 결과 없음이어야 함
```

---

### 2. 특정 OEM 전체 제거

해당 OEM의 모든 User + ACM 인증서 + Route 53 레코드가 삭제됩니다.

**Step 1:** `terraform.tfvars`에서 해당 OEM 블록을 삭제합니다.

```hcl
oem_users = {
  hyundai = { ... }   # 유지
  # kia = { ... }     ← 전체 삭제
}
```

`alb_dns_overrides`에서도 제거:

```hcl
alb_dns_overrides = {
  hyundai = "..."
  # kia = "..."       ← 제거
}
```

**Step 2:** Plan → Apply

```bash
terraform plan    # destroy 대상 확인
terraform apply
```

---

### 3. Terraform 관리 리소스 전체 삭제

Helm 릴리스 + ACM 인증서 + Route 53 레코드 + namespace를 모두 삭제합니다.

```bash
cd envs/dev
terraform destroy
```

**주의:** `yes`를 입력하기 전에 삭제 대상 리소스 목록을 반드시 확인하세요.

**검증:**

```bash
# Terraform state 비어있는지 확인
terraform state list
# 결과 없음이어야 함

# Namespace 삭제 확인
kubectl get namespaces -l managed-by=terraform
# 결과 없음이어야 함

# Helm 릴리스 삭제 확인
helm list -A | grep sim-
# 결과 없음이어야 함
```

---

### 4. EKS 노드 그룹 삭제

Terraform 외부에서 생성한 노드 그룹을 삭제합니다.

```bash
# 노드 그룹 목록 확인
aws eks list-nodegroups --cluster-name my-eks-cluster

# 노드 그룹 삭제
aws eks delete-nodegroup \
  --cluster-name my-eks-cluster \
  --nodegroup-name my-node-group

# 삭제 완료 대기 (~5분)
aws eks wait nodegroup-deleted \
  --cluster-name my-eks-cluster \
  --nodegroup-name my-node-group

echo "Node group deleted"
```

---

### 5. EKS 클러스터 삭제

**반드시 노드 그룹 삭제가 완료된 후에 실행합니다.**

```bash
# 클러스터 삭제
aws eks delete-cluster --name my-eks-cluster

# 삭제 완료 대기 (~10분)
aws eks wait cluster-deleted --name my-eks-cluster

echo "EKS cluster deleted"
```

---

### 6. IAM 역할 정리

```bash
# 클러스터 역할 정책 분리 후 삭제
aws iam detach-role-policy --role-name my-cluster-role --policy-arn arn:aws:iam::aws:policy/AmazonEKSClusterPolicy
aws iam detach-role-policy --role-name my-cluster-role --policy-arn arn:aws:iam::aws:policy/AmazonEKSVPCResourceController
aws iam delete-role --role-name my-cluster-role

# 노드 역할 정책 분리 후 삭제
aws iam detach-role-policy --role-name my-node-role --policy-arn arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy
aws iam detach-role-policy --role-name my-node-role --policy-arn arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy
aws iam detach-role-policy --role-name my-node-role --policy-arn arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly
aws iam delete-role --role-name my-node-role
```

---

### 7. Route 53 Hosted Zone 삭제 (선택)

Hosted Zone 삭제 전 모든 레코드(NS, SOA 제외)를 먼저 삭제해야 합니다.

```bash
# 잔존 레코드 확인
aws route53 list-resource-record-sets --hosted-zone-id <ZONE_ID> \
  --query "ResourceRecordSets[?Type!='NS' && Type!='SOA']"

# Hosted Zone 삭제 (레코드가 NS/SOA만 남은 경우)
aws route53 delete-hosted-zone --id <ZONE_ID>
```

---

### 8. Terraform State / Lock 파일 정리

```bash
cd envs/dev
rm -rf .terraform/
rm -f .terraform.lock.hcl
rm -f terraform.tfstate terraform.tfstate.backup
```

## Verification

전체 정리 후 최종 확인:

- [ ] `terraform state list` — 빈 결과
- [ ] `kubectl get namespaces -l managed-by=terraform` — 빈 결과
- [ ] `helm list -A` — simulator 관련 릴리스 없음
- [ ] `aws eks list-clusters` — 클러스터 없음 (전체 삭제 시)
- [ ] `aws acm list-certificates` — simulator 관련 인증서 없음
- [ ] `aws iam list-roles` — simulator 관련 역할 없음

## Rollback

삭제는 되돌릴 수 없습니다. 재구축이 필요한 경우:

1. `full-deployment.md` Runbook을 따라 처음부터 배포합니다.
2. ECR 이미지는 삭제하지 않았다면 그대로 사용 가능합니다.
3. Terraform state는 로컬 삭제 시 복구 불가 — S3 backend 사용을 권장합니다.

## Notes

- Last verified: 2026-04-19
- **삭제 순서가 중요합니다**: Terraform destroy → 노드 그룹 → 클러스터 → IAM → Route 53
- 노드 그룹이 남아있는 상태에서 클러스터를 삭제하면 실패합니다
- S3 backend 사용 시 DynamoDB lock 테이블도 별도 정리 필요
- 프로덕션 환경 삭제 전 반드시 팀 리더 승인을 받으세요
