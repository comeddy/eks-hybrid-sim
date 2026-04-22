# Runbook: 트러블슈팅

## Overview

Simulator Platform 운영 중 발생할 수 있는 주요 장애 상황에 대한 진단 및 해결 절차입니다.

## When to Use

- Pod가 `Running` 상태가 아닐 때
- Ingress/ALB에 접속이 안 될 때
- ACM 인증서가 발급되지 않을 때
- Terraform apply/plan 실행 시 오류가 발생할 때

## Prerequisites

- [ ] kubectl 접근 가능 (`kubectl get nodes`)
- [ ] AWS CLI 인증 완료
- [ ] Terraform state 접근 가능 (`terraform state list`)

## Procedure

### 1. Pod가 Pending 상태

**진단:**

```bash
# 문제 Pod 확인
kubectl get pods -A -l simulator-platform/oem | grep Pending

# 상세 이벤트 확인
kubectl describe pod <pod-name> -n <namespace> | tail -20
```

**원인별 해결:**

| Events 메시지 | 원인 | 해결 |
|--------------|------|------|
| `didn't match Pod's node affinity/selector` | `hybridNode.enabled=true`인데 Hybrid Node 없음 | `terraform.tfvars`에서 `hybrid_node_enabled = false`로 변경 후 `terraform apply` |
| `Insufficient cpu` / `Insufficient memory` | 노드 리소스 부족 | 노드 그룹 스케일업 (아래 참고) |
| `no nodes available` | 노드 그룹 없음 | 노드 그룹 생성 확인 |

**노드 리소스 부족 시 스케일업:**

```bash
aws eks update-nodegroup-config \
  --cluster-name my-eks-cluster \
  --nodegroup-name <nodegroup-name> \
  --scaling-config minSize=2,maxSize=6,desiredSize=4
```

### 2. Pod가 ImagePullBackOff / ErrImagePull

**진단:**

```bash
kubectl describe pod <pod-name> -n <namespace> | grep -A3 "Warning.*Pull"
```

**원인별 해결:**

| 에러 메시지 | 원인 | 해결 |
|------------|------|------|
| `repository does not exist` | ECR 리포지토리 없음 | `aws ecr create-repository --repository-name <name>` |
| `manifest unknown` | 태그에 해당하는 이미지 없음 | ECR에 올바른 태그로 Push하거나, `terraform.tfvars`에서 태그 수정 |
| `no basic auth credentials` | ECR 인증 실패 | 노드 IAM Role에 `AmazonEC2ContainerRegistryReadOnly` 정책 확인 |

**ECR 이미지 존재 확인:**

```bash
# 리포지토리 목록
aws ecr describe-repositories --query 'repositories[*].repositoryName' --output table

# 특정 리포지토리의 이미지 태그
aws ecr list-images --repository-name simulator-server --query 'imageIds[*].imageTag' --output table
```

**노드 IAM Role 권한 확인:**

```bash
# 노드 그룹의 IAM Role 확인
aws eks describe-nodegroup \
  --cluster-name my-eks-cluster \
  --nodegroup-name <nodegroup-name> \
  --query 'nodegroup.nodeRole'

# 해당 Role의 정책 확인
aws iam list-attached-role-policies --role-name <role-name>
```

### 3. Ingress에 ADDRESS가 없음 (ALB 미생성)

**진단:**

```bash
# Ingress 상태 확인
kubectl get ingress -A -l simulator-platform/oem

# ALB Controller 상태 확인
kubectl get deploy -n kube-system aws-load-balancer-controller

# ALB Controller 로그 확인
kubectl logs -n kube-system deploy/aws-load-balancer-controller --tail=50
```

**원인별 해결:**

| 상태 | 원인 | 해결 |
|------|------|------|
| Controller deploy 없음 | ALB Controller 미설치 | GUIDE.md 섹션 2.2 참고하여 설치 |
| Controller CrashLoop | IAM 권한 부족 | ServiceAccount에 IAM Policy 연결 확인 |
| Controller 정상이나 ALB 없음 | Ingress annotation 오류 | `kubectl get ingress <name> -n <ns> -o yaml`로 annotations 확인 |

### 4. ACM 인증서가 PENDING_VALIDATION

**진단:**

```bash
# 인증서 상태 확인
aws acm describe-certificate \
  --certificate-arn <ARN> \
  --query 'Certificate.{Status:Status,ValidationMethod:DomainValidationOptions[0].ValidationMethod,ValidationStatus:DomainValidationOptions[0].ValidationStatus}'

# DNS 검증 레코드 확인
aws acm describe-certificate \
  --certificate-arn <ARN> \
  --query 'Certificate.DomainValidationOptions[0].ResourceRecord'
```

**원인별 해결:**

| 상태 | 원인 | 해결 |
|------|------|------|
| ValidationStatus: PENDING | DNS 레코드는 있지만 도메인 NS 미위임 | 도메인 등록 기관에서 Route 53 네임서버 설정 |
| DNS 레코드 없음 | Route 53에 CNAME 미생성 | `terraform apply`로 재생성 |

**Route 53 네임서버 확인:**

```bash
aws route53 get-hosted-zone --id <ZONE_ID> --query 'DelegationSet.NameServers'
```

이 네임서버를 도메인 등록 기관(가비아, Route 53 Registrar 등)에 설정합니다.

### 5. Terraform Apply 오류

**`Error: Unsupported block type`:**
- Helm provider v3 호환성 문제입니다.
- `set` 블록은 `set = [{ name = "key", value = "val" }]` 형식이어야 합니다.
- `kubernetes` 블록은 `kubernetes = { ... }` 형식이어야 합니다.

**`Error: reading EKS Cluster: couldn't find resource`:**

```bash
# 클러스터 존재 확인
aws eks list-clusters --region ap-northeast-2

# terraform.tfvars의 eks_cluster_name 값과 일치하는지 확인
grep eks_cluster_name envs/dev/terraform.tfvars
```

**`Error: no matching Route 53 Hosted Zone found`:**

```bash
# Hosted Zone 확인
aws route53 list-hosted-zones --query 'HostedZones[*].{Name:Name,Id:Id}'

# terraform.tfvars의 base_domain과 일치하는지 확인
grep base_domain envs/dev/terraform.tfvars
```

**State lock 오류:**

```bash
# 강제 unlock (주의: 다른 사람이 apply 중이 아닌지 확인)
terraform force-unlock <LOCK_ID>
```

### 6. Helm Release 실패 (atomic rollback)

**진단:**

```bash
# Helm 릴리스 히스토리
helm history <release-name> -n <namespace>

# 실패한 릴리스의 상세
helm status <release-name> -n <namespace>
```

**해결:**

```bash
# 이전 revision으로 롤백
helm rollback <release-name> <revision> -n <namespace>

# 또는 Terraform으로 재배포
terraform apply -replace='module.simulator_platform.module.helm_release["<oem>/<user>"].helm_release.simulator'
```

## Verification

장애 해결 후 공통 점검:

- [ ] `kubectl get pods -A -l simulator-platform/oem` — 모든 Pod Running
- [ ] `kubectl get ingress -A` — 모든 Ingress에 ADDRESS 할당
- [ ] `helm list -A` — 모든 릴리스 deployed 상태
- [ ] `terraform plan` — `No changes` 출력

## Notes

- Last verified: 2026-04-19
- Pod 이벤트는 기본 1시간 후 만료됩니다. 장애 발생 직후 `kubectl describe`를 실행하세요.
- Terraform state가 실제 리소스와 불일치할 경우: `terraform refresh` → `terraform plan`으로 확인
- 긴급 상황에서 Terraform 없이 Helm만으로 롤백 가능합니다
